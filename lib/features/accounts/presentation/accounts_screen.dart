/// Conexión opcional a la biblioteca personal de YouTube Music.
/// No guarda ni exporta cabeceras/cookies; sesión solo en memoria.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';
import 'package:lyra_music/features/ytmusic/presentation/ytmusic_controller.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});
  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  String? _playError;
  String? _playingId;

  Future<void> _connectClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      if (mounted) setState(() => _playError = 'El portapapeles está vacío.');
      return;
    }
    // El portapapeles puede contener cookies sensibles: vaciarlo tras leer.
    await Clipboard.setData(const ClipboardData(text: ''));
    if (!mounted) return;
    await ref.read(ytMusicControllerProvider.notifier).connectFromHeaders(text);
  }

  Future<void> _play(YtMusicSong song) async {
    if (_playingId != null) return;
    setState(() {
      _playingId = song.videoId;
      _playError = null;
    });
    try {
      final track = Track(
        id: 'ytmusic:${song.videoId}',
        title: song.title,
        artist: song.artist,
        album: song.album,
        filePath: 'https://music.youtube.com/watch?v=${song.videoId}',
        artworkUrl: song.thumbnail,
      );
      if (!mounted) return;
      await ref.read(audioPlayerControllerProvider.notifier).playQueue([track]);
      if (!mounted) return;
      final error = ref.read(audioPlayerControllerProvider).error;
      if (error != null) setState(() => _playError = error);
    } catch (_) {
      if (mounted) {
        setState(
          () => _playError =
              'Esta pista no está disponible para reproducirse en Lyra.',
        );
      }
    } finally {
      if (mounted) setState(() => _playingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ytMusicControllerProvider);
    final controller = ref.read(ytMusicControllerProvider.notifier);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas y servicios'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/preferences'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text('Tu música, tus cuentas', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          const Text(
            'Lyra no necesita una cuenta para escuchar archivos propios ni guardar favoritos y playlists. La sincronización en línea es experimental.',
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite_border_rounded),
              title: const Text('Mi colección sin cuenta'),
              subtitle: const Text(
                'Favoritos, listas, historial y estadísticas',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.go('/my-music'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.music_note_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sincronizar biblioteca en línea',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      if (state.connected)
                        const Icon(Icons.check_circle_rounded),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.connected
                        ? 'Sesión conectada en este dispositivo.'
                        : 'Conexión avanzada de solo lectura. Usa datos temporales de una sesión existente del navegador; no es un inicio de sesión normal y puede dejar de funcionar.',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'La sesión nunca se guarda en disco: se borra al cerrar o desconectar Lyra. No compartas las cabeceras, cookies ni tokens con nadie.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!state.connected)
                        FilledButton.icon(
                          onPressed: state.loading ? null : _connectClipboard,
                          icon: const Icon(Icons.content_paste_rounded),
                          label: const Text('Importar sesión temporal'),
                        )
                      else ...[
                        FilledButton.icon(
                          onPressed: state.loading
                              ? null
                              : controller.refreshLibrary,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Actualizar biblioteca'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.disconnect,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Desconectar'),
                        ),
                      ],
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse('https://music.youtube.com/'),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Abrir YouTube Music'),
                      ),
                    ],
                  ),
                  if (state.loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      state.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  if (_playError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _playError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (state.connected) ...[
            const SizedBox(height: 18),
            Text(
              'Tus playlists (${state.playlists.length})',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (state.playlists.isEmpty && !state.loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No se encontraron playlists. La interfaz de YouTube Music podría haber cambiado o tu biblioteca está vacía.',
                ),
              ),
            for (final playlist in state.playlists)
              Card(
                child: ListTile(
                  leading: _Thumbnail(playlist.thumbnail),
                  title: Text(
                    playlist.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: state.loading
                      ? null
                      : () => controller.loadPlaylist(playlist.id),
                ),
              ),
            if (state.selectedPlaylistId != null) ...[
              const SizedBox(height: 16),
              Text(
                'Canciones de la playlist',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (state.playlistSongs.isEmpty && !state.loading)
                const Text(
                  'Esta lista no devolvió canciones o requiere actualizar el adaptador.',
                ),
              for (final song in state.playlistSongs)
                Card(
                  child: ListTile(
                    leading: _Thumbnail(song.thumbnail),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _playingId == song.videoId
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    onTap: () => _play(song),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail(this.url);
  final String? url;
  @override
  Widget build(BuildContext context) => url == null
      ? const SizedBox.square(
          dimension: 48,
          child: Icon(Icons.music_note_rounded),
        )
      : ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.network(
            url!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, trace) => const SizedBox.square(
              dimension: 48,
              child: Icon(Icons.music_note_rounded),
            ),
          ),
        );
}
