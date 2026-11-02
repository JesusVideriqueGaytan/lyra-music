/// Artistas seguidos en el dispositivo; independiente de cuentas externas.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lyra_music/features/ytmusic/data/ytmusic_client.dart';

const _key = 'lyra.favorite_artists.v1';

class FavoriteArtistsController extends Notifier<Map<String, YtMusicArtist>> {
  SharedPreferences? _prefs;
  bool _edited = false;

  @override
  Map<String, YtMusicArtist> build() {
    unawaited(_load());
    return {};
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final items = jsonDecode(_prefs?.getString(_key) ?? '[]') as List;
      if (_edited) return;
      state = {
        for (final item in items.whereType<Map>())
          if (item['id'] is String && item['name'] is String)
            item['id'] as String: YtMusicArtist(
              id: item['id'] as String,
              name: item['name'] as String,
              thumbnail: item['thumbnail'] as String?,
            ),
      };
    } catch (_) {
      /* Preferencias corruptas no impiden iniciar Lyra. */
    }
  }

  bool isFollowing(String id) => state.containsKey(id);

  Future<void> toggle(YtMusicArtist artist) async {
    _edited = true;
    final next = {...state};
    if (next.containsKey(artist.id)) {
      next.remove(artist.id);
    } else {
      next[artist.id] = artist;
    }
    state = next;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(
      _key,
      jsonEncode([
        for (final value in state.values)
          {'id': value.id, 'name': value.name, 'thumbnail': value.thumbnail},
      ]),
    );
  }
}

final favoriteArtistsProvider =
    NotifierProvider<FavoriteArtistsController, Map<String, YtMusicArtist>>(
      FavoriteArtistsController.new,
    );
