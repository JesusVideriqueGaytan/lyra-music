/// Fuentes de reproducción de Lyra.
///
/// MusicBrainz describe grabaciones, no proporciona flujos de audio. Un
/// proveedor debe entregar una fuente multimedia reproducible y autorizada.
/// En esta iteración solo hay un adaptador para enlaces HTTPS directos que el
/// usuario conoce y está autorizado a reproducir. No extraemos audio de páginas
/// de video, servicios de suscripción ni medios con restricciones técnicas.
library;

import 'package:lyra_music/features/player/domain/models/track.dart';

abstract class AudioSourceProvider {
  const AudioSourceProvider();

  String get id;
  String get displayName;

  /// Comprueba que el identificador no es una página web ni una fuente que
  /// este adaptador no esté preparado para utilizar.
  Uri validate(String input);

  /// Produce una pista que comparte cola/reproductor con la biblioteca local.
  Track createTrack({
    required String url,
    required String title,
    required String artist,
    String album = 'Enlace de audio',
  });
}

class DirectAudioSourceProvider extends AudioSourceProvider {
  const DirectAudioSourceProvider();

  @override
  String get id => 'direct-https';

  @override
  String get displayName => 'Enlace directo HTTPS';

  @override
  Uri validate(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException(
        'Introduce un enlace HTTPS directo a un archivo o flujo de audio.',
      );
    }

    final host = uri.host.toLowerCase();
    const websiteHosts = <String>{
      'youtube.com',
      'youtu.be',
      'music.youtube.com',
      'open.spotify.com',
      'spotify.com',
    };
    if (websiteHosts.any((base) => host == base || host.endsWith('.$base'))) {
      throw const FormatException(
        'Este enlace apunta a una página de una plataforma musical, no a '
        'una fuente de audio autorizada. Utiliza su reproductor oficial.',
      );
    }

    return uri;
  }

  @override
  Track createTrack({
    required String url,
    required String title,
    required String artist,
    String album = 'Enlace de audio',
  }) {
    final uri = validate(url);
    final displayTitle = title.trim().isEmpty ? 'Audio en línea' : title.trim();
    final displayArtist = artist.trim().isEmpty
        ? 'Fuente proporcionada por el usuario'
        : artist.trim();
    return Track(
      id: 'remote:${uri.toString()}',
      title: displayTitle,
      artist: displayArtist,
      album: album,
      filePath: uri.toString(),
    );
  }
}

/// Punto de extensión para proveedores autorizados futuros. No instala ni
/// ejecuta complementos comunitarios sin aprobación/aislamiento.
const List<AudioSourceProvider> builtInAudioSourceProviders = [
  DirectAudioSourceProvider(),
];
