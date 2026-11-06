"""Pruebas autocontenidas para el instalador de caché Lyra 4.8.3."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('configurar_cache_mpv_481.py')
spec = importlib.util.spec_from_file_location('cache_lyra', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

SOURCE = """import 'src/set_property.dart';
class MediaKitPlayer {
  final _readyCompleter = Completer<void>();
  Future<void> ready() => _readyCompleter.future;
  static final _logger = Logger('MediaKitPlayer');
  late final Player _player;
  MediaKitPlayer() {
    _player = Player();
    setProperty(_player, 'prefetch-playlist', 'yes');
  }
}
"""


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.project = self.root / 'Lyra'
        self.project.mkdir()
        self.package = self.root / 'plugin-2.1.0'
        self.package.mkdir()
        (self.package / 'pubspec.yaml').write_text('name: just_audio_media_kit\nversion: 2.1.0\n')
        (self.project / 'pubspec.yaml').write_text('name: lyra_music\ndependencies:\n  just_audio_media_kit: ^2.1.0\n')
        (self.project / '.dart_tool').mkdir()
        (self.project / '.dart_tool/package_config.json').write_text(json.dumps({
            'packages': [{'name': 'just_audio_media_kit', 'rootUri': self.package.as_uri()}]
        }))

    def tearDown(self):
        self.tmp.cleanup()

    def add_plugin_source(self, path='lib/src/mediakit_player.dart', content=SOURCE):
        src = self.package / path
        src.parent.mkdir(parents=True, exist_ok=True)
        src.write_text(content)
        return src

    def test_current_version_210_uses_src_set_property(self):
        self.add_plugin_source('lib/mediakit_player.dart', SOURCE)
        patched = module.patch_source(SOURCE)
        self.assertIn("await setProperty(_player, 'cache-on-disk', 'no')", patched)
        self.assertIn('LYRA_483_CACHE_ON_DISK', patched)

    def test_legacy_import_remains_compatible(self):
        legacy = SOURCE.replace("import 'src/set_property.dart';", "import 'set_property.dart';")
        self.assertIn('cache-on-disk', module.patch_source(legacy))

    def test_missing_import_rejected(self):
        invalid = SOURCE.replace("import 'src/set_property.dart';", "")
        with self.assertRaises(RuntimeError):
            module.patch_source(invalid)

    def test_locates_source_in_src(self):
        src = self.add_plugin_source()
        self.assertEqual(module.locate_player_source(self.package), src)

    def test_locates_source_elsewhere(self):
        src = self.add_plugin_source('lib/backend/native_player.dart')
        self.assertEqual(module.locate_player_source(self.package), src)

    def test_install_and_restore_without_mutating_pub_cache(self):
        src = self.add_plugin_source('lib/backend/native_player.dart')
        original = src.read_text()
        module.apply(self.project)
        patched = (self.project / 'third_party/just_audio_media_kit/lib/backend/native_player.dart').read_text()
        self.assertIn(module.MARKER, patched)
        self.assertIn('await setProperty', patched)
        self.assertIn('await _readyCompleter.future;', patched)
        self.assertIn('dependency_overrides:', (self.project / 'pubspec.yaml').read_text())
        self.assertEqual(src.read_text(), original)
        self.assertTrue(module.status(self.project).startswith('ACTIVADO'))
        module.restore(self.project)
        self.assertEqual((self.project / 'pubspec.yaml').read_text(),
                         'name: lyra_music\ndependencies:\n  just_audio_media_kit: ^2.1.0\n')
        self.assertIn('NO ACTIVADO', module.status(self.project))

    def test_existing_overrides_preserved(self):
        self.add_plugin_source()
        pubspec = self.project / 'pubspec.yaml'
        original = pubspec.read_text() + '\ndependency_overrides:\n  example_dependency:\n    path: example\n'
        pubspec.write_text(original)
        module.apply(self.project)
        module.restore(self.project)
        self.assertEqual(pubspec.read_text(), original)

    def test_unknown_api_fails_without_modifications(self):
        self.add_plugin_source(content='class MediaKitPlayer { Future<void> ready() async {} }\n')
        with self.assertRaises(RuntimeError):
            module.apply(self.project)
        self.assertFalse((self.project / 'third_party/just_audio_media_kit').exists())
        self.assertFalse((self.project / module.BACKUP_REL).exists())
        self.assertNotIn('dependency_overrides', (self.project / 'pubspec.yaml').read_text())

    def test_missing_class_fails_safely(self):
        self.add_plugin_source(content='class OtherPlayer {}\n')
        with self.assertRaises(RuntimeError):
            module.apply(self.project)
        self.assertFalse((self.project / module.BACKUP_REL).exists())

    def test_repeated_install_idempotent(self):
        self.add_plugin_source()
        module.apply(self.project)
        before = (self.project / 'pubspec.yaml').read_text()
        module.apply(self.project)
        self.assertEqual((self.project / 'pubspec.yaml').read_text(), before)


if __name__ == '__main__':
    unittest.main()
