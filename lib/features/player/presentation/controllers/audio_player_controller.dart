/// Controlador del reproductor de audio (capa PRESENTACIÓN).
///
/// Envuelve `just_audio` + `audio_service` (Linux: audio_service_mpris):
///  - Estado de reproducción (playing/paused/loading/error) expuesto a la UI.
///  - Cola de reproducción con shuffle real y modos de repetición.
///  - Controles de sistema (notificación / pantalla de bloqueo) mediante un
///    `BaseAudioHandler` que delega en este mismo controller.
///
/// Diseño clave: el handler de audio_service se construye ANTES del
/// AudioPlayer interno, porque el callback `onQueueChanged` puede dispararse
/// durante `setAudioSource`, cuando `state` aún no existe (build() de Riverpod
/// todavía no terminó). Por eso el handler usa getters nulos-seguros.
library;

import 'dart:async';
import 'dart:io' show FileSystemException;
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart' as audio_service;

// Import selectivo: evitamos la colisión de nombres con nuestro propio
// PlaybackState trayendo SOLO los símbolos necesarios del plugin.
import 'package:audio_service/audio_service.dart'
    show
        MediaItem,
        BaseAudioHandler,
        QueueHandler,
        MediaControl,
        MediaAction,
        AudioProcessingState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:lyra_music/core/performance/performance_controller.dart'
    show currentTierProvider;
import 'package:lyra_music/core/performance/performance_tier.dart'
    show PerformanceTier;
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/player/domain/models/radio_queue_window.dart';
import 'package:lyra_music/features/library/presentation/controllers/music_collection_controller.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_audio_resolver.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';

/// Alias explícito: el PlaybackState de audio_service colisiona con el nuestro.
typedef AudioServicePlaybackState = audio_service.PlaybackState;

/// Modos de repetición de la cola.
enum RepeatMode { off, all, one }

/// Extensión con iconos/labels para la UI (evita switch duplicados).
extension RepeatModeUi on RepeatMode {
  String get label => switch (this) {
    RepeatMode.off => 'Repetir desactivado',
    RepeatMode.all => 'Repetir toda la cola',
    RepeatMode.one => 'Repetir canción actual',
  };
}

/// Estado inmutable consumido por MiniPlayer, NowPlayingScreen y cola.
class PlaybackState {
  const PlaybackState({
    this.queue = const <Track>[],
    this.autoRadio = false,
    this.currentIndex = -1,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration,
    this.volume = 1.0,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.error,
    this.handlerReady = false,
  });

  /// Cola visible (orden original; el orden aleatorio lo gestiona just_audio).
  final List<Track> queue;

  /// True cuando la cola actual contiene canciones sugeridas automáticamente.
  final bool autoRadio;

  /// Índice de la pista activa; -1 si no hay nada cargado.
  final int currentIndex;

  /// Canción actual o null si la cola está vacía.
  Track? get currentTrack => (currentIndex >= 0 && currentIndex < queue.length)
      ? queue[currentIndex]
      : null;

  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration? duration;
  final double volume;
  final bool shuffleEnabled;
  final RepeatMode repeatMode;

  /// Mensaje legible del último error de reproducción (null = sin errores).
  final String? error;

  /// True cuando el servicio de audio (notificación/bloqueo) está listo.
  final bool handlerReady;

  PlaybackState copyWith({
    List<Track>? queue,
    bool? autoRadio,
    int? currentIndex,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? shuffleEnabled,
    RepeatMode? repeatMode,
    String? error,
    bool clearError = false,
    bool? handlerReady,
  }) {
    return PlaybackState(
      queue: queue ?? this.queue,
      autoRadio: autoRadio ?? this.autoRadio,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      // Si hay un nuevo valor de error se guarda; si clearError=true se limpia.
      error: clearError ? null : (error ?? this.error),
      handlerReady: handlerReady ?? this.handlerReady,
    );
  }
}

/// Handler de audio_service que delega todos los comandos en el controller.
///
/// No posee el AudioPlayer: solo reenvía acciones para que aparezcan en la
/// notificación y la pantalla de bloqueo del sistema operativo.
class LyraAudioHandler extends BaseAudioHandler with QueueHandler {
  LyraAudioHandler();

  /// Inyectado tras la construcción (circularidad handler <-> controller).
  AudioPlayerController? controller;

  @override
  Future<void> play() async => await controller?.play();

  @override
  Future<void> pause() async => await controller?.pause();

  @override
  Future<void> seek(Duration position) async =>
      await controller?.seek(position);

  @override
  Future<void> skipToNext() async => await controller?.next();

  @override
  Future<void> skipToPrevious() async => await controller?.previous();

  @override
  Future<void> skipToQueueItem(int index) async =>
      await controller?.playAt(index);

  @override
  Future<void> stop() async => await controller?.stop();
}

/// Provider singleton del handler (debe sobrevivir a los rebuilds del
/// notifier; se destruye explícitamente en `ref.onDispose`).
final lyraAudioHandlerProvider = Provider<LyraAudioHandler>((ref) {
  return LyraAudioHandler();
});

/// Notifier principal del reproductor.
class AudioPlayerController extends Notifier<PlaybackState> {
  static const String _mediaIdPrefix = 'lyra.local.track';

  late final LyraAudioHandler _handler;
  late final AudioPlayer _player;
  final math.Random _random = math.Random();

  /// Suscripción al stream de finalización de pista (para repeat off/one).
  StreamSubscription<void>? _completedSub;

  bool _singleSourceQueue = false;
  int _radioRequestGeneration = 0;
  final RadioQueueWindow _radioWindow = const RadioQueueWindow();
  final Set<String> _radioSeen = <String>{};
  final Set<String> _radioPlayed = <String>{};
  final List<Track> _radioRecentlyPlayed = <Track>[];
  final Set<String> _radioFailedSeeds = <String>{};
  List<Track> _radioPending = <Track>[];
  Future<void>? _radioFetchFuture;
  int _switchGeneration = 0;
  String? _lastRecordedStart;
  String? _lastPositionTrack;
  Duration? _lastPosition;
  Duration _pendingListen = Duration.zero;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<PlayerException>? _playerErrorSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<dynamic>? _sequenceSub;
  StreamSubscription<List<MediaItem>>? _queueSub;
  DateTime _lastSystemPositionUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  /// Historial de índices reproducidos para implementar shuffle SIN modificar
  /// la cola visible (el usuario siempre ve el orden original).
  final List<int> _shuffleHistory = <int>[];

  @override
  PlaybackState build() {
    _handler = ref.read(lyraAudioHandlerProvider);
    // just_audio 0.10.x NO expone androidWakeMode en el constructor: el wake
    // lock se configura vía audioLoadConfiguration si se necesita. Lo dejamos
    // en los valores por defecto multiplataforma (funciona en Linux desktop).
    // NOTA: `useLazyPreparation` es INMUTABLE tras la construcción del player;
    // la precarga granular por tier se aplica después vía setAudioSources(preload:).
    _player = AudioPlayer(
      handleInterruptions: true,
      androidApplyAudioAttributes: true,
    );
    _handler.controller = this;

    // Suscripciones a streams de just_audio -> estado inmutable de Riverpod.
    _playerErrorSub = _player.errorStream.listen((error) {
      final track = state.currentTrack;
      if (track == null) return;
      state = state.copyWith(
        playing: false,
        buffering: false,
        error: _humanizePlayerError(error, track),
      );
    });
    _playerStateSub = _player.playerStateStream.listen((playerState) {
      state = state.copyWith(
        playing: playerState.playing,
        // ProcessingState reemplazó a TrackingState en just_audio >= 0.9.34.
        buffering: playerState.processingState == ProcessingState.buffering,
      );
      if (playerState.playing &&
          playerState.processingState == ProcessingState.ready &&
          state.currentTrack != null &&
          _lastRecordedStart != state.currentTrack!.id) {
        _lastRecordedStart = state.currentTrack!.id;
        ref
            .read(musicCollectionProvider.notifier)
            .recordStarted(state.currentTrack!);
      }
      _rememberActiveDuration();
      _syncPlaybackStateToSystem();
    });

    // Lógica de repetición al FINALIZAR una pista naturalmente:
    //  - one -> reiniciar la misma pista desde 0.
    //  - off + última pista -> detener (just_audio se queda en completed).
    //  - all / pistas intermedias -> just_audio avanza solo y sequenceState-
    //    Stream sincroniza el índice en la UI.
    _completedSub = _player.processingStateStream.listen((processing) {
      if (processing == ProcessingState.completed) {
        _onTrackCompleted();
      }
    });

    // Solo emitimos posición cada ~500 ms en tier bajo para ahorrar CPU;
    // el ProgressBar escucha además el stream crudo para suavizar el slider.
    _positionSub = _player.positionStream.listen((position) {
      final track = state.currentTrack;
      if (track != null &&
          state.playing &&
          _lastPositionTrack == track.id &&
          _lastPosition != null) {
        final delta = position - _lastPosition!;
        // No contar saltos del usuario, rebobinados o tiempos enormes.
        if (delta > Duration.zero && delta < const Duration(seconds: 3)) {
          _pendingListen += delta;
          if (_pendingListen >= const Duration(seconds: 5)) {
            ref
                .read(musicCollectionProvider.notifier)
                .addListening(track, _pendingListen);
            _pendingListen = Duration.zero;
          }
        }
      }
      if (track?.id != _lastPositionTrack) _pendingListen = Duration.zero;
      _lastPositionTrack = track?.id;
      _lastPosition = position;
      state = state.copyWith(position: position);
      // No publicar sobre D-Bus cada frame: basta con informar cada 2 s.
      final now = DateTime.now();
      if (now.difference(_lastSystemPositionUpdate) >=
          const Duration(seconds: 2)) {
        _lastSystemPositionUpdate = now;
        _syncPlaybackStateToSystem();
      }
    });

    _sequenceSub = _player.sequenceStateStream.listen((sequenceState) {
      // Sincronizamos el índice REAL de just_audio con nuestro estado visible:
      // al terminar una pista de forma natural, el plugin avanza solo y
      // nosotros debemos reflejarlo (cola, MiniPlayer, notificación).
      final realIndex = sequenceState.currentIndex;
      if (!_singleSourceQueue &&
          realIndex != null &&
          realIndex >= 0 &&
          realIndex < state.queue.length &&
          realIndex != state.currentIndex) {
        _shuffleHistory.add(realIndex);
        state = state.copyWith(currentIndex: realIndex);
      }
      // La duración de la pista activa se lee directo del player
      // (ya no existe `IndexedAudioSource.initialized` en 0.10.x).
      final d = _player.duration;
      if (d != null && d != state.duration) {
        state = state.copyWith(duration: d);
      }
      _rememberActiveDuration();
      _syncPlaybackStateToSystem();
    });

    // Duración conocida al cargar cada item de la cola.
    _queueSub = _handler.queue.listen((queue) {
      if (queue.isEmpty) return;
      final updated = <Track>[...state.queue];
      for (var i = 0; i < queue.length && i < updated.length; i++) {
        final d = queue[i].duration;
        if (d != null && updated[i].duration == null) {
          updated[i] = updated[i].copyWith(duration: d);
        }
      }
      state = state.copyWith(queue: updated);
    });

    ref.onDispose(() async {
      await _playerStateSub?.cancel();
      await _playerErrorSub?.cancel();
      await _positionSub?.cancel();
      await _sequenceSub?.cancel();
      await _queueSub?.cancel();
      await _completedSub?.cancel();
      _handler.controller = null;
      await _player.dispose();
    });

    // El resto de inicialización (servicio de audio) es asíncrona:
    // devolvemos estado vacío y exponemos waitUntilReady() para main().
    unawaited(_initAudioService());
    return const PlaybackState();
  }

  /// Persist a newly discovered real duration once per track. This repairs
  /// older personal playlists that were saved before the catalog included
  /// durations. Never guess durations from a different (previous) source.
  void _rememberActiveDuration() {
    final current = state.currentTrack;
    final duration = _player.duration;
    if (current == null ||
        duration == null ||
        duration <= Duration.zero ||
        current.duration == duration ||
        _player.processingState != ProcessingState.ready ||
        _lastRecordedStart != current.id)
      return;
    final enriched = current.copyWith(duration: duration);
    if (state.autoRadio) {
      final historyIndex = _radioRecentlyPlayed.indexWhere(
        (item) => item.id == enriched.id,
      );
      if (historyIndex >= 0) _radioRecentlyPlayed[historyIndex] = enriched;
    }
    final updated = <Track>[...state.queue];
    updated[state.currentIndex] = enriched;
    state = state.copyWith(
      queue: List<Track>.unmodifiable(updated),
      duration: duration,
    );
    ref.read(musicCollectionProvider.notifier).enrichTracks([enriched]);
  }

  Future<void>? _readyFuture;

  /// Precarga de cola completa solo en tiers high/ultra (la detección de
  // hardware puede haber terminado DESPUÉS de construir el AudioPlayer, por
  // eso recalculamos el modo de carga antes de cada setAudioSources).
  bool get _preloadWholeQueue {
    final tier = ref.read(currentTierProvider);
    return tier == PerformanceTier.high || tier == PerformanceTier.ultra;
  }

  /// Espera a que el handler de audio_service esté registrado. Usado en
  /// `main()` y en tests para arrancar de forma determinista.
  Future<void> waitUntilReady() => _readyFuture ??= _initAudioService();

  Future<void> _initAudioService() async {
    try {
      // AudioService.init se registra en main() cuando hay plataforma MPRIS.
      // Este indicador solo declara que el controlador puede aceptar órdenes.
      state = state.copyWith(handlerReady: true);
    } catch (e) {
      state = state.copyWith(error: 'Servicio de audio no disponible: $e');
    }
  }

  // Fuente unificada para archivos locales y flujos HTTPS. Las referencias
  // remotas se resuelven de nuevo inmediatamente antes de reproducir.
  AudioSource _audioSourceFor(Track track) {
    final tag = MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
    );
    if (track.isRemote) {
      return AudioSource.uri(Uri.parse(track.filePath), tag: tag);
    }
    return AudioSource.file(track.filePath, tag: tag);
  }

  /// Las URLs de los proveedores pueden caducar. No las guardamos en listas
  /// o favoritos: recuperamos una nueva URL al seleccionar cada canción.
  Future<AudioSource> _sourceForPlayback(Track track) async {
    if (!track.id.startsWith('ytmusic:')) return _audioSourceFor(track);
    final videoId = track.id.substring('ytmusic:'.length);
    if (videoId.isEmpty) throw StateError('Identificador de canción vacío.');
    final stream = await const YtMusicAudioResolver().resolve(
      YtMusicSong(
        videoId: videoId,
        title: track.title,
        artist: track.artist,
        album: track.album,
        thumbnail: track.artworkUrl,
      ),
    );
    // Cabeceras del extractor deben viajar hasta el reproductor. Las URL
    // temporales y cabeceras jamás se guardan en favoritos/historial.
    return AudioSource.uri(
      stream.uri,
      headers: stream.headers.isEmpty ? null : stream.headers,
      tag: MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
      ),
    );
  }

  /// Update the 30-slot visible window without touching MPV's active source.
  /// The already-played IDs are retained for the whole radio session so the
  /// provider cannot reintroduce a song after it has left the visible queue.
  void _balanceRadioWindow() {
    if (!state.autoRadio || !_singleSourceQueue || state.queue.isEmpty) return;
    final before = state.queue;
    final previousIndex = state.currentIndex;
    final snapshot = _radioWindow.rebalance(
      before,
      previousIndex,
      _radioPending,
      recent: _radioRecentlyPlayed,
      playedIds: _radioPlayed,
    );
    _radioPending = snapshot.pending;
    if (snapshot.queue.length == before.length &&
        snapshot.currentIndex == previousIndex &&
        _sameTrackIds(before, snapshot.queue))
      return;
    state = state.copyWith(
      queue: List<Track>.unmodifiable(snapshot.queue),
      currentIndex: snapshot.currentIndex,
    );
    _publishQueue(state.queue, state.currentIndex);
  }

  void _markRadioPlayed(Track track) {
    if (!state.autoRadio) return;
    _radioPlayed.add(track.id);
    if (_radioRecentlyPlayed.isNotEmpty &&
        _radioRecentlyPlayed.last.id == track.id)
      return;
    _radioRecentlyPlayed.removeWhere((item) => item.id == track.id);
    _radioRecentlyPlayed.add(track);
    if (_radioRecentlyPlayed.length > 10) _radioRecentlyPlayed.removeAt(0);
  }

  static bool _sameTrackIds(List<Track> first, List<Track> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i].id != second[i].id) return false;
    }
    return true;
  }

  Track _radioTrack(YtMusicSong song) => Track(
    id: 'ytmusic:${song.videoId}',
    title: song.title,
    artist: song.artist,
    artistId: song.artistId,
    album: song.album,
    filePath: 'https://music.youtube.com/watch?v=${song.videoId}',
    artworkUrl: song.thumbnail,
    duration: song.duration,
  );

  /// Load more only when necessary. In the UI there are at most ten tracks
  /// recently heard (including the current) and twenty to play next.
  Future<void> _ensureRadio({bool force = false}) {
    if (!state.autoRadio || !_singleSourceQueue) return Future<void>.value();
    _balanceRadioWindow();
    final available = _radioWindow.bufferedAhead(
      state.queue,
      state.currentIndex,
      _radioPending,
    );
    if (!force && available >= 8) return Future<void>.value();
    if (_radioFetchFuture != null) return _radioFetchFuture!;
    final generation = _radioRequestGeneration;
    final future = _fetchRadioBatch(generation);
    _radioFetchFuture = future;
    return future.whenComplete(() {
      if (identical(_radioFetchFuture, future)) _radioFetchFuture = null;
    });
  }

  Future<void> _fetchRadioBatch(int generation) async {
    if (state.queue.isEmpty) return;
    // Use the newest visible suggestion as the next seed; if the provider
    // repeats its recommendations, try one older seed instead of looping.
    final candidates = state.queue.reversed
        .where((t) => t.id.startsWith('ytmusic:'))
        .where((t) => !_radioFailedSeeds.contains(t.id))
        .take(2)
        .toList();
    for (final seed in candidates) {
      try {
        final suggestions = await const YtMusicClient().getRadioSongs(
          seed.id.substring('ytmusic:'.length),
        );
        if (generation != _radioRequestGeneration || !state.autoRadio) return;
        final unique = _radioWindow.uniqueSuggestions(
          suggestions.map(_radioTrack),
          _radioSeen,
        );
        _radioPending.addAll(unique);
        if (unique.isNotEmpty) {
          _balanceRadioWindow();
          return;
        }
        _radioFailedSeeds.add(seed.id);
      } catch (_) {
        if (generation != _radioRequestGeneration || !state.autoRadio) return;
        _radioFailedSeeds.add(seed.id);
      }
    }
    // No new tracks could be obtained. Keep the playable existing queue.
  }

  void _flushListening() {
    if (_pendingListen > Duration.zero && state.currentTrack != null) {
      ref
          .read(musicCollectionProvider.notifier)
          .addListening(state.currentTrack!, _pendingListen);
      _pendingListen = Duration.zero;
    }
  }

  Future<void> _loadSingleIndex(int index, int generation) async {
    final track = state.queue[index];
    final source = await _sourceForPlayback(track);
    if (generation != _switchGeneration) return;
    await _player.setAudioSource(source);
    if (generation != _switchGeneration) return;
    // No esperes el Future de play(): solo finaliza al pausar o terminar.
    unawaited(
      _player.play().catchError((Object e, StackTrace _) {
        state = state.copyWith(error: _humanizePlayerError(e, track));
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Carga y reproducción
  // ---------------------------------------------------------------------------

  /// Reproduce una lista de pistas comenzando en [startIndex].
  Future<void> playQueue(
    List<Track> tracks, {
    int startIndex = 0,
    bool enableRadio = true,
  }) async {
    if (tracks.isEmpty) {
      state = state.copyWith(error: 'No hay canciones que reproducir.');
      return;
    }

    final generation = ++_switchGeneration;
    _flushListening();
    // Detener el audio ANTES de resolver el próximo flujo remoto (que puede
    // tardar varios segundos). Nunca mezclar la pista vieja con la nueva.
    await _player.stop();
    if (generation != _switchGeneration) return;
    final safeIndex = startIndex.clamp(0, tracks.length - 1);
    _singleSourceQueue = tracks.any((t) => t.id.startsWith('ytmusic:'));
    _lastRecordedStart = null;
    _lastPosition = null;
    _pendingListen = Duration.zero;
    _shuffleHistory
      ..clear()
      ..add(safeIndex);

    final isSingleOnlineRadio = _radioWindow.shouldStartRadio(
      tracks,
      enabled: enableRadio,
    );
    _radioPending = <Track>[];
    _radioFetchFuture = null;
    _radioSeen..clear();
    _radioPlayed..clear();
    _radioRecentlyPlayed.clear();
    _radioFailedSeeds.clear();
    if (isSingleOnlineRadio) {
      _radioSeen.add(tracks.first.id);
      _radioPlayed.add(tracks.first.id);
      _radioRecentlyPlayed.add(tracks.first);
    }

    // Publicamos la cola y los media items ANTES de cargar el audio para que
    // la UI responda de inmediato (degradación elegante en archivos lentos).
    state = state.copyWith(
      queue: List<Track>.unmodifiable(tracks),
      autoRadio: isSingleOnlineRadio,
      currentIndex: safeIndex,
      playing: false,
      buffering: true,
      position: Duration.zero,
      duration: tracks[safeIndex].duration,
      clearError: true,
    );
    _publishQueue(tracks, safeIndex);
    _syncPlaybackStateToSystem();

    // Si se seleccionó una sola canción en línea, crear automáticamente una
    // radio de recomendaciones reales. Las playlists explícitas se respetan.
    ++_radioRequestGeneration;
    if (isSingleOnlineRadio) {
      unawaited(_ensureRadio(force: true));
    }

    try {
      if (_singleSourceQueue) {
        await _loadSingleIndex(safeIndex, generation);
        return;
      }
      // API moderna de just_audio 0.10.x: setAudioSources reemplaza al
      // ConcatenatingAudioSource manual (deprecado). El manejo del orden y
      // la precarga queda en manos del plugin.
      final sources = tracks.map((t) => _audioSourceFor(t)).toList();
      await _player.setAudioSources(
        sources,
        preload: _preloadWholeQueue,
        initialIndex: safeIndex,
        initialPosition: Duration.zero,
      );
      // just_audio completa el Future de play() cuando la reproducción se
      // detiene o termina, NO cuando empieza. No bloquear la interfaz ni el
      // spinner de la búsqueda durante toda la canción.
      unawaited(
        _player.play().catchError((Object e, StackTrace stack) {
          state = state.copyWith(
            error: _humanizePlayerError(e, tracks[safeIndex]),
          );
        }),
      );
    } on PlayerInterruptedException catch (_) {
      // Otra carga más reciente ganó la carrera: NO es un error real, se
      // ignora silenciosamente (comportamiento documentado por el plugin).
    } on PlayerException catch (e) {
      if (generation != _switchGeneration) return;
      state = state.copyWith(error: _humanizePlayerError(e, tracks[safeIndex]));
    } on FileSystemException catch (e) {
      state = state.copyWith(
        error: 'Archivo no encontrado: ${e.path ?? tracks[safeIndex].filePath}',
      );
    } catch (e) {
      if (generation != _switchGeneration) return;
      state = state.copyWith(error: _humanizePlayerError(e, tracks[safeIndex]));
    }
  }

  /// Salta directamente a una pista de la cola actual.
  Future<void> playAt(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final generation = ++_switchGeneration;
    _flushListening();
    try {
      _lastRecordedStart = null;
      if (_singleSourceQueue) {
        await _player.stop();
        if (generation != _switchGeneration) return;
        state = state.copyWith(
          currentIndex: index,
          position: Duration.zero,
          playing: false,
          buffering: true,
          duration: state.queue[index].duration,
          clearError: true,
        );
        _lastPosition = null;
        _publishQueue(state.queue, index);
        if (state.autoRadio) {
          _markRadioPlayed(state.queue[index]);
          _balanceRadioWindow();
          unawaited(_ensureRadio());
        }
        // Recalculate index after trimming radio history.
        await _loadSingleIndex(state.currentIndex, generation);
        return;
      }
      await _player.seek(Duration.zero, index: index);
      if (generation != _switchGeneration) return;
      _shuffleHistory.add(index);
      state = state.copyWith(currentIndex: index, clearError: true);
      // play() finishes when playback ends, so do not await here.
      unawaited(
        _player.play().catchError((Object e, StackTrace _) {
          state = state.copyWith(
            error: _humanizePlayerError(e, state.queue[index]),
          );
        }),
      );
    } catch (e) {
      if (generation != _switchGeneration) return;
      state = state.copyWith(
        error: _humanizePlayerError(e, state.queue[index]),
      );
    }
  }

  Future<void> play() async {
    try {
      unawaited(
        _player.play().catchError((Object e, StackTrace _) {
          state = state.copyWith(
            error: 'No se pudo iniciar el audio. Prueba otra pista.',
          );
        }),
      );
    } catch (e) {
      state = state.copyWith(
        error: 'No se pudo iniciar el audio. Prueba otra pista.',
      );
    }
  }

  Future<void> pause() async {
    try {
      _flushListening();
      await _player.pause();
    } catch (e) {
      state = state.copyWith(error: 'Error al pausar: $e');
    }
  }

  /// Play/Pause conmutables (botón principal del MiniPlayer y NowPlaying).
  Future<void> togglePlayPause() async {
    if (state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      state = state.copyWith(position: position);
      _syncPlaybackStateToSystem();
    } catch (e) {
      state = state.copyWith(error: 'Error al buscar posición: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    try {
      await _player.setVolume(clamped);
      state = state.copyWith(volume: clamped);
    } catch (e) {
      state = state.copyWith(error: 'Error al ajustar volumen: $e');
    }
  }

  Future<void> stop() async {
    try {
      ++_radioRequestGeneration;
      ++_switchGeneration;
      _flushListening();
      await _player.stop();
      state = state.copyWith(playing: false, position: Duration.zero);
      _syncPlaybackStateToSystem();
    } catch (e) {
      state = state.copyWith(error: 'Error al detener: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Navegación de cola (next / previous respetando shuffle y repeat)
  // ---------------------------------------------------------------------------

  Future<void> next() async {
    if (state.queue.isEmpty) return;

    if (state.autoRadio) await _ensureRadio();
    final queue = state.queue;
    if (state.shuffleEnabled) {
      final target = _pickShuffleIndex(excludeCurrent: true);
      if (target != state.currentIndex) await playAt(target);
      return;
    }

    var target = state.currentIndex + 1;
    if (target >= queue.length) {
      if (state.repeatMode == RepeatMode.off || state.autoRadio) {
        // Radio exhausted or list completed: stop without inventing tracks.
        await stop();
        return;
      }
      target = 0; // repeat=all vuelve al principio.
    }
    await playAt(target);
  }

  Future<void> previous() async {
    final queue = state.queue;
    if (queue.isEmpty) return;

    // Convención de apps de música: si llevamos >3 s, reinicia la pista.
    if (state.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }

    if (state.shuffleEnabled && _shuffleHistory.length > 1) {
      // Retroceder = deshacer el último salto del historial de shuffle.
      _shuffleHistory.removeLast();
      final previous = _shuffleHistory.last;
      _shuffleHistory.removeLast();
      await playAt(previous);
      return;
    }

    var target = state.currentIndex - 1;
    if (target < 0) {
      if (state.repeatMode == RepeatMode.all) {
        target = queue.length - 1;
      } else {
        await seek(Duration.zero);
        return;
      }
    }
    await playAt(target);
  }

  /// Selección aleatoria evitando repetir la pista actual.
  int _pickShuffleIndex({required bool excludeCurrent}) {
    final length = state.queue.length;
    if (length <= 1) return 0;
    if (state.autoRadio) {
      final fresh = <int>[
        for (var i = 0; i < length; i++)
          if ((!excludeCurrent || i != state.currentIndex) &&
              !_radioPlayed.contains(state.queue[i].id))
            i,
      ];
      if (fresh.isNotEmpty) return fresh[_random.nextInt(fresh.length)];
      // Never automatically replay an already heard song in radio mode.
      return state.currentIndex;
    }
    int candidate;
    do {
      candidate = _random.nextInt(length);
    } while (excludeCurrent && candidate == state.currentIndex);
    return candidate;
  }

  // ---------------------------------------------------------------------------
  // Shuffle / Repeat
  // ---------------------------------------------------------------------------

  Future<void> toggleShuffle() async {
    final enabled = !state.shuffleEnabled;
    state = state.copyWith(shuffleEnabled: enabled);

    if (enabled && state.queue.length > 1) {
      // Empezamos una nueva "ruta" aleatoria desde la pista actual.
      _shuffleHistory
        ..clear()
        ..add(state.currentIndex);
      final next = _pickShuffleIndex(excludeCurrent: true);
      if (next != state.currentIndex) await playAt(next);
    } else if (!enabled && state.queue.isNotEmpty) {
      // Al desactivar, volvemos a la posición natural de la cola visible.
      final natural = state.currentIndex;
      await playAt(natural);
    }
  }

  /// Ciclo off -> all -> one -> off (interacción estándar de reproductores).
  void toggleRepeat() {
    final nextMode = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
    // repeat=one lo implementamos manualmente en _onCompletion para evitar
    // comportamientos distintos entre plataformas de LoopMode de just_audio.
  }

  // ---------------------------------------------------------------------------
  // Gestión de cola editable (reordenar básico, quitar pista)
  // ---------------------------------------------------------------------------

  /// Encola una canción inmediatamente después de la actual.
  /// No interrumpe la reproducción activa ni resuelve el flujo por adelantado.
  Future<void> playNext(Track track) async {
    if (state.queue.isEmpty || state.currentIndex < 0) {
      await playQueue([track]);
      return;
    }
    final insertIndex = state.currentIndex + 1;
    // En colas locales el motor administra la secuencia real; insertar allí
    // primero evita una divergencia entre la cola visible y just_audio.
    if (!_singleSourceQueue) {
      if (track.id.startsWith('ytmusic:')) {
        // Cambiar a una cola híbrida requeriría reconstruir el motor mientras
        // suena la pista. En lugar de cortar el audio, no prometer el encolado.
        state = state.copyWith(
          error:
              'No se puede insertar una fuente online en esta cola local todavía.',
        );
        return;
      }
      try {
        await _player.insertAudioSource(insertIndex, _audioSourceFor(track));
      } catch (_) {
        state = state.copyWith(
          error: 'No se pudo agregar la canción a la cola.',
        );
        return;
      }
    }
    final updated = <Track>[...state.queue]..insert(insertIndex, track);
    if (state.autoRadio) _radioSeen.add(track.id);
    state = state.copyWith(
      queue: List<Track>.unmodifiable(updated),
      clearError: true,
    );
    _publishQueue(updated, state.currentIndex);
    if (state.autoRadio) _balanceRadioWindow();
  }

  /// Reordena la cola por arrastre; el índice activo sigue a su pista.
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    final queue = state.queue;
    if (oldIndex < 0 ||
        oldIndex >= queue.length ||
        newIndex < 0 ||
        newIndex >= queue.length ||
        oldIndex == newIndex) {
      return;
    }

    final reordered = <Track>[...queue];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    // Ajustamos el índice de la pista activa para que siga señalando la misma.
    var current = state.currentIndex;
    if (current == oldIndex) {
      current = newIndex;
    } else if (oldIndex < current && newIndex >= current) {
      current -= 1;
    } else if (oldIndex > current && newIndex <= current) {
      current += 1;
    }

    state = state.copyWith(
      queue: List<Track>.unmodifiable(reordered),
      currentIndex: current,
    );
    _publishQueue(reordered, current);

    if (_singleSourceQueue) return; // La pista activa ya está cargada.
    // Reconstruimos la fuente para reflejar el nuevo orden en just_audio.
    final wasPlaying = state.playing;
    final resumePosition = state.position;
    try {
      final sources = reordered.map((t) => _audioSourceFor(t)).toList();
      // setAudioSources (0.10.x): reemplaza a ConcatenatingAudioSource.
      await _player.setAudioSources(
        sources,
        preload: _preloadWholeQueue,
        initialIndex: current,
        initialPosition: wasPlaying ? resumePosition : Duration.zero,
      );
      if (wasPlaying) {
        unawaited(
          _player.play().catchError((Object e, StackTrace _) {
            state = state.copyWith(
              error: 'No se pudo reanudar la cola reordenada.',
            );
          }),
        );
      }
    } on PlayerInterruptedException catch (_) {
      // Cancelado por una carga más nueva: se ignora.
    } catch (e) {
      state = state.copyWith(error: 'Error al reordenar la cola: $e');
    }
  }

  /// Elimina una pista de la cola.
  Future<void> removeFromQueue(int index) async {
    final queue = state.queue;
    if (index < 0 || index >= queue.length) return;

    final wasActive = index == state.currentIndex;
    final remaining = <Track>[...queue]..removeAt(index);
    var current = state.currentIndex;
    if (index < current) current -= 1;

    if (remaining.isEmpty) {
      await stop();
      state = state.copyWith(
        queue: const <Track>[],
        autoRadio: false,
        currentIndex: -1,
      );
      _publishQueue(const <Track>[], -1);
      return;
    }

    current = current.clamp(0, remaining.length - 1);
    state = state.copyWith(
      queue: List<Track>.unmodifiable(remaining),
      currentIndex: current,
    );
    _publishQueue(remaining, current);

    if (_singleSourceQueue) {
      // The live remote source does not depend on the visible queue. Keep
      // playing when a different track is removed.
      if (!wasActive) {
        if (state.autoRadio) unawaited(_ensureRadio());
        return;
      }
      final generation = ++_switchGeneration;
      await _player.stop();
      if (generation != _switchGeneration) return;
      await _loadSingleIndex(current, generation);
      return;
    }
    try {
      final sources = remaining.map((t) => _audioSourceFor(t)).toList();
      // setAudioSources (0.10.x): reemplaza a ConcatenatingAudioSource.
      await _player.setAudioSources(
        sources,
        preload: _preloadWholeQueue,
        initialIndex: current,
      );
      if (state.playing) await _player.play();
    } on PlayerInterruptedException catch (_) {
      // Cancelado por una carga más nueva: se ignora.
    } catch (e) {
      state = state.copyWith(error: 'Error al quitar la pista: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Integración con el sistema (notificación / bloqueo)
  // ---------------------------------------------------------------------------

  /// Reacciona al fin natural de una pista respetando el modo de repetición.
  void _onTrackCompleted() {
    if (_singleSourceQueue) {
      if (state.repeatMode == RepeatMode.one) {
        unawaited(playAt(state.currentIndex));
      } else if (state.currentIndex < state.queue.length - 1 ||
          state.repeatMode == RepeatMode.all) {
        unawaited(next());
      }
      return;
    }
    switch (state.repeatMode) {
      case RepeatMode.one:
        // Reiniciar la misma pista desde el principio.
        unawaited(
          _player
              .seek(Duration.zero, index: state.currentIndex)
              .then((_) => _player.play()),
        );
      case RepeatMode.all:
        // just_audio avanza solo; si era la última pista, envolver a la 0.
        if (state.currentIndex >= state.queue.length - 1) {
          unawaited(playAt(0));
        }
      case RepeatMode.off:
        // Al final de la cola: detener limpiamente (queda en completed).
        if (state.currentIndex >= state.queue.length - 1) {
          unawaited(_player.pause());
        }
    }
  }

  /// Publica la cola en el handler del sistema. `queue` es un BehaviorSubject
  /// propio de BaseAudioHandler (no existe como getter en el controller), por
  /// eso accedemos vía `_handler.queue`.
  void _publishQueue(List<Track> tracks, int currentIndex) {
    final items = tracks.map(_toMediaItem).toList();
    _handler.queue.value = items;
    if (currentIndex >= 0 && currentIndex < items.length) {
      _handler.mediaItem.add(items[currentIndex]);
    }
  }

  MediaItem _toMediaItem(Track track) {
    return MediaItem(
      id: '$_mediaIdPrefix:${track.id}',
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      // artUri como file:// permite que la notificación muestre portadas
      // locales cuando existan (Fase 2.x: extracción de metadatos ID3).
      artUri: track.artworkUrl != null
          ? Uri.tryParse(track.artworkUrl!)
          : (track.coverPath != null ? Uri.file(track.coverPath!) : null),
    );
  }

  /// Sincroniza play/pause/posición con la notificación del SO.
  void _syncPlaybackStateToSystem() {
    final current = state.currentTrack;
    if (current == null) return;
    // Nota: colisión de nombres entre PlaybackState propio y audio_service:
    // usamos el prefijo de librería para referirnos al del plugin.
    _handler.playbackState.add(systemPlaybackState(state));
    _handler.mediaItem.add(
      _toMediaItem(
        current,
      ).copyWithWithDuration(state.duration ?? current.duration),
    );
  }

  /// Traducción amigable de errores técnicos de just_audio.
  String _humanizePlayerError(Object e, Track track) {
    final text = e.toString();
    if (e is UnavailableAudioException) return e.reason;
    if (text.contains('403') && track.id.startsWith('ytmusic:')) {
      return 'El proveedor rechazó el audio (HTTP 403). '
          'No es un problema de volumen ni de tus archivos locales.';
    }
    if (text.contains('File not found') ||
        text.contains('FileSystemException')) {
      return 'El archivo "${track.fileName}" ya no existe en su ubicación.';
    }
    if (text.contains('unsupported') || text.contains('Unsupport')) {
      return 'Formato no soportado: "${track.fileName}".';
    }
    if (track.id.startsWith('ytmusic:')) {
      return 'No se pudo abrir el audio de “${track.title}”. '
          'El enlace del proveedor puede haber caducado, estar restringido '
          'o requerir autenticación. Prueba otra canción.';
    }
    return 'Error de reproducción en "${track.title}": $e';
  }
}

/// Provider del controlador. `keepAlive` implícito: nunca se recolecta
/// mientras exista el ProviderScope raíz (reproducción continua).
final audioPlayerControllerProvider =
    NotifierProvider<AudioPlayerController, PlaybackState>(
      AudioPlayerController.new,
    );

// Helper local para adjuntar duración descubierta en runtime.
extension on MediaItem {
  MediaItem copyWithWithDuration(Duration? duration) {
    if (duration == null) return this;
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
    );
  }
}

/// Construye el estado de controles publicado al sistema operativo.
///
/// Función pura, compartida y comprobable sin iniciar audio ni D-Bus.
AudioServicePlaybackState systemPlaybackState(PlaybackState state) {
  final hasTrack = state.currentTrack != null;
  return AudioServicePlaybackState(
    processingState: !hasTrack
        ? AudioProcessingState.idle
        : state.buffering
        ? AudioProcessingState.buffering
        : AudioProcessingState.ready,
    playing: state.playing,
    updatePosition: state.position,
    updateTime: DateTime.now(),
    queueIndex: hasTrack ? state.currentIndex : null,
    controls: hasTrack
        ? <MediaControl>[
            MediaControl.skipToPrevious,
            if (state.playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ]
        : <MediaControl>[],
    systemActions: hasTrack
        ? const <MediaAction>{MediaAction.seek}
        : const <MediaAction>{},
    androidCompactActionIndices: hasTrack
        ? const <int>[0, 1, 2]
        : const <int>[],
  );
}
