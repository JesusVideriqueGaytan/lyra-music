/// Ruta de caché usada habitualmente por libmpv en Linux.
///
/// Lyra solo prepara la carpeta si falta; NO modifica las opciones de
/// libmpv, ya que just_audio_media_kit no expone `cache-on-disk`.
library;

String? linuxMpvCacheDirectory(Map<String, String> environment) {
  final mpvHome = environment['MPV_HOME']?.trim() ?? '';
  if (mpvHome.startsWith('/')) return mpvHome;
  final xdg = environment['XDG_CACHE_HOME']?.trim() ?? '';
  if (xdg.startsWith('/')) return '$xdg/mpv';
  final home = environment['HOME']?.trim() ?? '';
  if (home.startsWith('/')) return '$home/.cache/mpv';
  return null;
}
