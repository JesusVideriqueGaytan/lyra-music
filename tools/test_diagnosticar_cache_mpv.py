import tempfile
from pathlib import Path
import unittest
from diagnosticar_cache_mpv import cache_location, check_writable


class CachePathTests(unittest.TestCase):
    def test_xdg_directory_is_used(self):
        self.assertEqual(cache_location({'XDG_CACHE_HOME': '/tmp/foo'}), Path('/tmp/foo/mpv'))

    def test_home_fallback(self):
        self.assertEqual(cache_location({'HOME': '/home/test'}), Path('/home/test/.cache/mpv'))

    def test_mpv_home_priority(self):
        self.assertEqual(cache_location({'MPV_HOME': '/tmp/mpv-home', 'HOME': '/home/user'}), Path('/tmp/mpv-home'))

    def test_writability_does_not_leave_temp_files(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'mpv'
            writable, _ = check_writable(path)
            self.assertTrue(writable)
            self.assertEqual(list(path.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
