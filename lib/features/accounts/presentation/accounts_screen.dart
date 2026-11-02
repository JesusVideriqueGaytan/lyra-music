/// Conexión opcional a la biblioteca personal de YouTube Music.
/// No guarda ni exporta cabeceras/cookies; sesión solo en memoria.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:lyra_music/shared/widgets/lyra_section_banner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lyra_music/features/player/presentation/controllers/audio_player_controller.dart';
import 'package:lyra_music/features/player/domain/models/track.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';
import 'package:lyra_music/features/accounts/youtube/youtube_playlist_controller.dart';
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
      if (mounted)
        setState(
          () => _playError =
              'Esta pista no está disponible para reproducirse en Lyra.',
        );
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
          const LyraSectionBanner(
            icon: Icons.account_circle_outlined,
            eyebrow: 'CUENTAS',
            title: 'Tus servicios conectados',
            subtitle: 'Mantén el control de tus datos y sesiones.',
          ),
          const SizedBox(height: 18),
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
          const _GoogleYouTubeAccountCard(),
          const SizedBox(height: 14),
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
                          'YouTube Music · método experimental',
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
                        : 'Para playlists específicas de YouTube Music, esta opción avanzada usa datos de una sesión existente del navegador. No equivale al acceso oficial con Google y puede dejar de funcionar.',
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

/// Google OAuth es distinto de la sesión privada de YouTube Music.
/// Este panel muestra solo playlists accesibles mediante YouTube Data API.
/// La conexión permanece en memoria y no requiere copiar cookies.
class _GoogleYouTubeAccountCard extends ConsumerWidget {
  const _GoogleYouTubeAccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(youtubeAccountProvider);
    final notifier = ref.read(youtubeAccountProvider.notifier);
    final theme = Theme.of(context);
    final desktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final configured = youtubeDesktopClientId.isNotEmpty;
    final canConnect = desktop && configured;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_circle_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Conectar cuenta de Google',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (state.connected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Inicio de sesión en el navegador para consultar las '
              'playlists de YouTube disponibles mediante la API oficial. '
              'Esto no autoriza reproducir audio ni da acceso completo '
              'a la biblioteca privada de YouTube Music.',
            ),
            if (!desktop) ...[
              const SizedBox(height: 10),
              const Text(
                'Esta conexión OAuth está preparada para escritorio. '
                'En Android e iOS se necesita Google Sign-In nativo.',
              ),
            ],
            if (desktop && !configured) ...[
              const SizedBox(height: 12),
              Text(
                'Falta configurar LYRA_GOOGLE_DESKTOP_CLIENT_ID. '
                'Crea un cliente OAuth de tipo Aplicación de escritorio, '
                'habilita YouTube Data API v3 y configura la pantalla de '
                'consentimiento de Google.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://console.cloud.google.com/auth/clients'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Configurar Google Cloud'),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!state.connected)
                  FilledButton.icon(
                    onPressed: !canConnect || state.connecting
                        ? null
                        : notifier.connect,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      state.connecting
                          ? 'Conectando…'
                          : 'Iniciar sesión con Google',
                    ),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: state.loading ? null : notifier.refreshPlaylists,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar playlists'),
                  ),
                  OutlinedButton.icon(
                    onPressed: notifier.disconnect,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Desconectar Google'),
                  ),
                ],
              ],
            ),
            if (state.loading || state.connecting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (state.connected) ...[
              const SizedBox(height: 18),
              Text(
                'Playlists de YouTube (${state.playlists.length})',
                style: theme.textTheme.titleMedium,
              ),
              if (state.playlists.isEmpty && !state.loading)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'No se encontraron playlists visibles '
                    'a través de YouTube Data API.',
                  ),
                ),
              for (final playlist in state.playlists)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _Thumbnail(playlist.thumbnail),
                  title: Text(playlist.title),
                  subtitle: Text('${playlist.videoCount} elementos'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => notifier.loadPlaylist(playlist.id),
                ),
              if (state.selectedPlaylistId != null) ...[
                const Divider(),
                Row(
                  children: [
                    Text(
                      'Contenido de la lista',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: notifier.closePlaylist,
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
                for (final video in state.videos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _Thumbnail(video.thumbnail),
                    title: Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(video.channel),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
