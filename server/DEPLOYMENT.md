# RestoreAI backend deployment (development)

The Flutter client requires a **stable HTTPS endpoint**. A temporary Google Colab tunnel is suitable only for testing, not for production availability.

## GPU runtime prerequisites

- Linux with an NVIDIA CUDA GPU and compatible PyTorch
- Python 3.11 (recommended for BasicSR compatibility)
- Real-ESRGAN x4plus checkpoint, obtained from the official Real-ESRGAN release
- BasicSR with RRDBNet import available, plus the packages in `server/requirements.txt`
- NumPy, torch, torchvision versions compatible with your CUDA/BasicSR setup

Install the GPU stack according to the host's CUDA version. The existing Colab BasicSR workaround may be needed; do not assume unpinned BasicSR installs on all Python versions.

Set `RESTOREAI_WEIGHTS` to the absolute checkpoint path, then start:

```bash
RESTOREAI_WEIGHTS=/models/RealESRGAN_x4plus.pth \
  uvicorn server.app:app --host 127.0.0.1 --port 8000
```

Expose the app through a trusted HTTPS reverse proxy with rate limits, request-size limits and authentication before public use. Do not expose an unauthenticated GPU endpoint to the internet.

## Endpoints

- `GET /health` returns GPU and weights availability; it is not a full inference check.
- `POST /enhance` accepts multipart field `image`, JPEG/PNG/WebP, max 8 MB, max 2 megapixels. Returns PNG with 4x width and height. Optional multipart field `mode` accepts `enhance` (default) or `restore`. `restore` applies conservative automatic bright-scratch detection and OpenCV inpainting before Real-ESRGAN upscaling; it is **not** a generative restoration model, and deep or facial scratches may remain.

Real-ESRGAN performs **super-resolution**, not guaranteed scratch removal or face restoration. A separate restoration pipeline needs validation.

## Flutter configuration

Build the Android app with a real trusted HTTPS base URL:

```bash
flutter build apk --release --dart-define=RESTOREAI_API_URL=https://YOUR-HTTPS-DOMAIN.example
```

Without that value, the Enhance button stays disabled. Never put private tokens or credentials in `--dart-define` or source code. The app currently saves output in its private application documents directory, not the system gallery.

## Release blockers

- Choose and configure a reliable GPU host and HTTPS domain
- Add authentication, privacy policy, upload retention controls, abuse prevention
- Verify inference with real test photos, including scratch and face-quality cases; synthetic scratch regression tests are not proof of portrait quality
- Test Android networking, save/export and user experience on physical devices
- Configure Android release signing and distribution
