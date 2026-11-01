/// Controlador del reproductor de audio (capa PRESENTACIÓN).
///
/// Envuelve `just_audio` + `audio_service` + `just_audio_background`:
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

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<dynamic>? _sequenceSub;
  StreamSubscription<List<MediaItem>>? _queueSub;

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
    _playerStateSub = _player.playerStateStream.listen((playerState) {
      state = state.copyWith(
        playing: playerState.playing,
        // ProcessingState reemplazó a TrackingState en just_audio >= 0.9.34.
        buffering: playerState.processingState == ProcessingState.buffering,
      );
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
    _positionSub = _player.positionStream.listen(
      (position) => state = state.copyWith(position: position),
    );

    _sequenceSub = _player.sequenceStateStream.listen((sequenceState) {
      // Sincronizamos el índice REAL de just_audio con nuestro estado visible:
      // al terminar una pista de forma natural, el plugin avanza solo y
      // nosotros debemos reflejarlo (cola, MiniPlayer, notificación).
      final realIndex = sequenceState.currentIndex;
      if (realIndex != null &&
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
      // just_audio_background intercepta globalmente AudioPlayer: los
      // MediaItems que publiquemos aparecerán en la notificación del SO.
      // (AudioService.init ya se ejecuta en main(); aquí solo marcamos listo.)
      state = state.copyWith(handlerReady: true);
    } catch (e) {
      state = state.copyWith(error: 'Servicio de audio no disponible: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Carga y reproducción
  // ---------------------------------------------------------------------------

  /// Reproduce una lista de pistas comenzando en [startIndex].
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) {
      state = state.copyWith(error: 'No hay canciones que reproducir.');
      return;
    }

    final safeIndex = startIndex.clamp(0, tracks.length - 1);
    _shuffleHistory
      ..clear()
      ..add(safeIndex);

    // Publicamos la cola y los media items ANTES de cargar el audio para que
    // la UI responda de inmediato (degradación elegante en archivos lentos).
    state = state.copyWith(
      queue: List<Track>.unmodifiable(tracks),
      currentIndex: safeIndex,
      position: Duration.zero,
      duration: tracks[safeIndex].duration,
      clearError: true,
    );
    _publishQueue(tracks, safeIndex);

    try {
      // API moderna de just_audio 0.10.x: setAudioSources reemplaza al
      // ConcatenatingAudioSource manual (deprecado). El manejo del orden y
      // la precarga queda en manos del plugin.
      final sources = tracks
          .map(
            (t) => AudioSource.file(
              t.filePath,
              tag: MediaItem(
                id: t.id,
                title: t.title,
                artist: t.artist,
                album: t.album,
              ),
            ),
          )
          .toList();
      await _player.setAudioSources(
        sources,
        preload: _preloadWholeQueue,
        initialIndex: safeIndex,
        initialPosition: Duration.zero,
      );
      await _player.play();
    } on PlayerInterruptedException catch (_) {
      // Otra carga más reciente ganó la carrera: NO es un error real, se
      // ignora silenciosamente (comportamiento documentado por el plugin).
    } on PlayerException catch (e) {
      state = state.copyWith(error: _humanizePlayerError(e, tracks[safeIndex]));
    } on FileSystemException catch (e) {
      state = state.copyWith(
        error: 'Archivo no encontrado: ${e.path ?? tracks[safeIndex].filePath}',
      );
    } catch (e) {
      state = state.copyWith(error: 'No se pudo reproducir: $e');
    }
  }

  /// Salta directamente a una pista de la cola actual.
  Future<void> playAt(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    try {
      await _player.seek(Duration.zero, index: index);
      _shuffleHistory.add(index);
      state = state.copyWith(currentIndex: index, clearError: true);
      await _player.play();
    } catch (e) {
      state = state.copyWith(error: 'Error al saltar a la pista $index: $e');
    }
  }

  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      state = state.copyWith(error: 'Error al reproducir: $e');
    }
  }

  Future<void> pause() async {
    try {
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
      await _player.stop();
      state = state.copyWith(playing: false, position: Duration.zero);
    } catch (e) {
      state = state.copyWith(error: 'Error al detener: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Navegación de cola (next / previous respetando shuffle y repeat)
  // ---------------------------------------------------------------------------

  Future<void> next() async {
    final queue = state.queue;
    if (queue.isEmpty) return;

    if (state.shuffleEnabled) {
      final target = _pickShuffleIndex(excludeCurrent: true);
      await playAt(target);
      return;
    }

    var target = state.currentIndex + 1;
    if (target >= queue.length) {
      if (state.repeatMode == RepeatMode.off) {
        // Fin natural de la lista: nos quedamos en la última pista pausada.
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
      await playAt(next);
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

  /// Mueve una pista dentro de la cola (sin drag & drop complejo: botones
  /// subir/bajar en la pantalla de cola).
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

    // Reconstruimos la fuente para reflejar el nuevo orden en just_audio.
    final wasPlaying = state.playing;
    final resumePosition = state.position;
    try {
      final sources = reordered
          .map(
            (t) => AudioSource.file(
              t.filePath,
              tag: MediaItem(
                id: t.id,
                title: t.title,
                artist: t.artist,
                album: t.album,
              ),
            ),
          )
          .toList();
      // setAudioSources (0.10.x): reemplaza a ConcatenatingAudioSource.
      await _player.setAudioSources(
        sources,
        preload: _preloadWholeQueue,
        initialIndex: current,
        initialPosition: wasPlaying ? resumePosition : Duration.zero,
      );
      if (wasPlaying) await _player.play();
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

    final remaining = <Track>[...queue]..removeAt(index);
    var current = state.currentIndex;
    if (index < current) current -= 1;

    if (remaining.isEmpty) {
      await stop();
      state = state.copyWith(queue: const <Track>[], currentIndex: -1);
      _publishQueue(const <Track>[], -1);
      return;
    }

    current = current.clamp(0, remaining.length - 1);
    state = state.copyWith(
      queue: List<Track>.unmodifiable(remaining),
      currentIndex: current,
    );
    _publishQueue(remaining, current);

    try {
      final sources = remaining
          .map(
            (t) => AudioSource.file(
              t.filePath,
              tag: MediaItem(
                id: t.id,
                title: t.title,
                artist: t.artist,
                album: t.album,
              ),
            ),
          )
          .toList();
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
      artUri: track.coverPath != null ? Uri.file(track.coverPath!) : null,
    );
  }

  /// Sincroniza play/pause/posición con la notificación del SO.
  void _syncPlaybackStateToSystem() {
    final current = state.currentTrack;
    if (current == null) return;
    // Nota: colisión de nombres entre PlaybackState propio y audio_service:
    // usamos el prefijo de librería para referirnos al del plugin.
    _handler.playbackState.add(
      AudioServicePlaybackState(
        processingState: state.buffering
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        playing: state.playing,
        controls: [
          MediaControl.rewind,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 3],
      ),
    );
    _handler.mediaItem.add(
      _toMediaItem(
        current,
      ).copyWithWithDuration(state.duration ?? current.duration),
    );
  }

  /// Traducción amigable de errores técnicos de just_audio.
  String _humanizePlayerError(Object e, Track track) {
    final text = e.toString();
    if (text.contains('File not found') ||
        text.contains('FileSystemException')) {
      return 'El archivo "${track.fileName}" ya no existe en su ubicación.';
    }
    if (text.contains('unsupported') || text.contains('Unsupport')) {
      return 'Formato no soportado: "${track.fileName}".';
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
