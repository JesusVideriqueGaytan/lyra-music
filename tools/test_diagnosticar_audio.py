"""Pruebas locales del reintento HTTP; no llama a YouTube."""
import io
import unittest
from urllib.error import HTTPError

from diagnosticar_audio import probe_url


class FakeResponse:
    def __init__(self, status=206, payload=b'audio'):
        self.status = status
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def read(self, _n):
        return self.payload


def forbidden():
    return HTTPError('https://example.invalid/', 403, 'Forbidden', {}, io.BytesIO())


class ProbeRetryTests(unittest.TestCase):
    def test_403_then_206_reuses_url(self):
        sleeps, urls = [], []
        def fake_open(req, timeout=15):
            urls.append(req.full_url)
            if len(urls) == 1:
                raise forbidden()
            return FakeResponse()
        url = 'https://rr1---sn-test.googlevideo.com/videoplayback?fake=signed'
        self.assertTrue(probe_url(url, {'Range': 'bytes=0-10239'},
                                  opener=fake_open, sleeper=sleeps.append))
        self.assertEqual(urls, [url, url])
        self.assertEqual(sleeps, [6])

    def test_second_403_stops(self):
        sleeps, calls = [], []
        def fake_open(req, timeout=15):
            calls.append(req)
            raise forbidden()
        self.assertFalse(probe_url('https://rr.googlevideo.com/a', {},
                                   opener=fake_open, sleeper=sleeps.append))
        self.assertEqual(len(calls), 2)
        self.assertEqual(sleeps, [6])

    def test_other_host_does_not_wait(self):
        sleeps, calls = [], []
        def fake_open(req, timeout=15):
            calls.append(req)
            raise forbidden()
        self.assertFalse(probe_url('https://example.invalid/a', {},
                                   opener=fake_open, sleeper=sleeps.append))
        self.assertEqual(len(calls), 1)
        self.assertEqual(sleeps, [])

    def test_rejects_empty_body(self):
        self.assertFalse(probe_url('https://example.invalid/a', {},
                                   opener=lambda *_a, **_k: FakeResponse(payload=b'')))


if __name__ == '__main__':
    unittest.main()
