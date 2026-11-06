import importlib.util
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent

def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

fix = load('lyra485_fix', 'reparar_compilacion_485.py')
installer = load('lyra485_install', 'configurar_cache_mpv_481.py')

SOURCE = """import 'package:universal_platform/universal_platform.dart';
library just_audio_media_kit;
import 'package:media_kit/media_kit.dart';
// LYRA_483_CACHE_ON_DISK
class MediaKitPlayer {}
"""
INSTALL_SOURCE = """library just_audio_media_kit;
import 'src/set_property.dart';
class MediaKitPlayer {
  Future<void> ready() => _readyCompleter.future;
  void start() { setProperty(_player, 'prefetch-playlist', 'yes'); }
}
"""

class HotfixTests(unittest.TestCase):
    def test_correct_import_order(self):
        result, changed = fix.correct_player(SOURCE)
        self.assertTrue(changed)
        self.assertLess(result.index('library '), result.index('import '))

    def test_idempotent(self):
        result, _ = fix.correct_player(SOURCE)
        again, changed = fix.correct_player(result)
        self.assertFalse(changed)
        self.assertEqual(result, again)

    def test_missing_marker_safe(self):
        with self.assertRaises(ValueError):
            fix.correct_player(SOURCE.replace(fix.MARKER, 'NO_PATCH'))

    def test_add_analyzer(self):
        result, changed = fix.exclude_vendor('include: package:flutter_lints/flutter.yaml\n')
        self.assertTrue(changed)
        self.assertIn('analyzer:\n  exclude:', result)

    def test_existing_analyzer(self):
        result, _ = fix.exclude_vendor('analyzer:\n  exclude:\n    - build/**\n')
        self.assertIn('    - build/**', result)
        self.assertIn('    - third_party/just_audio_media_kit/**', result)

    def test_future_installer_preserves_library_first(self):
        result = installer.patch_source(INSTALL_SOURCE)
        self.assertLess(result.index('library '), result.index("import 'package:universal_platform"))
        self.assertIn("cache-on-disk', 'no'", result)

if __name__ == '__main__':
    unittest.main()
