import importlib.util
from pathlib import Path
import json
import tempfile
import unittest

script = Path(__file__).with_name('diagnosticar_config_mpv_482.py')
spec = importlib.util.spec_from_file_location('cache482', script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Cache482Tests(unittest.TestCase):
    def create_project(self, root: Path, active: bool):
        (root / '.dart_tool').mkdir()
        vendor = root / 'third_party/just_audio_media_kit'
        source = vendor / 'lib/src/mediakit_player.dart'
        source.parent.mkdir(parents=True)
        source.write_text('Future<void> ready() async {\n'
                          "  await setProperty(_player, 'cache-on-disk', 'no');\n"
                          '}', encoding='utf-8')
        (root / 'pubspec.yaml').write_text(
            'name: lyra_music\ndependency_overrides:\n'
            '  just_audio_media_kit:\n'
            '    path: third_party/just_audio_media_kit\n'
            if active else 'name: lyra_music\n', encoding='utf-8')
        config = {'packages': [{'name': 'just_audio_media_kit',
                  'rootUri': '../third_party/just_audio_media_kit'}]}
        (root / '.dart_tool/package_config.json').write_text(
            json.dumps(config), encoding='utf-8')

    def test_active_patch(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            self.create_project(root, True)
            active, lines = module.diagnosis(root)
            self.assertTrue(active)
            self.assertIn('el parche está resuelto', '\n'.join(lines))

    def test_missing_override(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            self.create_project(root, False)
            active, lines = module.diagnosis(root)
            self.assertFalse(active)
            self.assertIn('NO', '\n'.join(lines))

    def test_not_resolved(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'pubspec.yaml').write_text('name: lyra_music\n')
            active, lines = module.diagnosis(root)
            self.assertFalse(active)
            self.assertIn('flutter pub get', '\n'.join(lines))


if __name__ == '__main__':
    unittest.main()
