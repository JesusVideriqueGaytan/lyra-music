"""Pruebas sin Flutter: seguridad, reversión y alcance del parche MPV."""
import json
import tempfile
from pathlib import Path
import unittest
from configurar_cache_mpv_481 import apply, restore, patch_source, override_pubspec, status

SAMPLE_SOURCE = '''import 'dart:async';
import 'set_property.dart';
class MediaKitPlayer {
  Future<void> ready() => _readyCompleter.future;
}
'''


class CacheAdapterPatchTests(unittest.TestCase):
    def test_source_uses_only_native_linux_option(self):
        text = patch_source(SAMPLE_SOURCE)
        self.assertIn('UniversalPlatform.isLinux', text)
        self.assertIn("setProperty(_player, 'cache-on-disk', 'no')", text)
        self.assertNotIn("setProperty(_player, 'cache', 'no')", text)
        self.assertIn('await _readyCompleter.future;', text)

    def test_refuse_unknown_upstream_api(self):
        with self.assertRaises(RuntimeError):
            patch_source('Future<void> ready() async {}')

    def test_adds_override_to_existing_section(self):
        pubspec = 'name: lyra_music\ndependency_overrides:\n  foo: any\nflutter:\n  assets: []\n'
        patched = override_pubspec(pubspec)
        self.assertIn('dependency_overrides:\n  just_audio_media_kit:\n    path: third_party/just_audio_media_kit\n', patched)
        self.assertIn('  foo: any', patched)

    def test_install_restore_and_idempotence(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            project = base / 'Lyra'
            project.mkdir()
            plugin = base / 'pub-cache' / 'just_audio_media_kit-2.1.0'
            (plugin / 'lib' / 'src').mkdir(parents=True)
            (plugin / 'pubspec.yaml').write_text('name: just_audio_media_kit\nversion: 2.1.0\n')
            (plugin / 'lib' / 'src' / 'mediakit_player.dart').write_text(SAMPLE_SOURCE)
            (plugin / 'lib' / 'src' / 'set_property.dart').write_text('')
            (project / 'pubspec.yaml').write_text('name: lyra_music\ndependencies:\n  just_audio_media_kit: ^2.1.0\n')
            config = project / '.dart_tool'
            config.mkdir()
            (config / 'package_config.json').write_text(json.dumps({
                'configVersion': 2,
                'packages': [{'name': 'just_audio_media_kit', 'rootUri': plugin.as_uri()}],
            }))
            apply(project)
            self.assertIn('configuración de caché activada', status(project))
            self.assertEqual(
                (plugin / 'lib/src/mediakit_player.dart').read_text(), SAMPLE_SOURCE,
                'El paquete global nunca debe modificarse.',
            )
            apply(project)
            restore(project)
            self.assertNotIn('path: third_party/just_audio_media_kit', (project / 'pubspec.yaml').read_text())
            self.assertFalse((project / '.lyra481_pubspec_original').exists())


if __name__ == '__main__':
    unittest.main()
