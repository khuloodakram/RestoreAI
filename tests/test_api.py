import io
import unittest
from unittest.mock import patch
from fastapi.testclient import TestClient
from PIL import Image
from server.app import app

client = TestClient(app)


def png():
    image = Image.new('RGB', (16, 16), 'red')
    buf = io.BytesIO()
    image.save(buf, format='PNG')
    return buf.getvalue()


class APITests(unittest.TestCase):
    def test_health_schema(self):
        r = client.get('/health')
        self.assertEqual(r.status_code, 200)
        self.assertIn('ready', r.json())

    def test_reject_nonimage(self):
        r = client.post('/enhance', files={'image': ('a.txt', b'hello', 'text/plain')})
        self.assertEqual(r.status_code, 415)

    def test_missing_model(self):
        with patch('server.app.health', return_value={'ready': False}):
            r = client.post('/enhance', files={'image': ('a.png', png(), 'image/png')})
        self.assertEqual(r.status_code, 503)

    def test_corrupt_image(self):
        with patch('server.app.health', return_value={'ready': True}):
            r = client.post('/enhance', files={'image': ('a.png', b'bad', 'image/png')})
        self.assertEqual(r.status_code, 400)


if __name__ == '__main__':
    unittest.main()
