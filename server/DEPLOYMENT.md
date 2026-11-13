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

## Optional pretrained LaMa restoration (experimental)

Install `pip install -r server/requirements-lama.txt` on a compatible GPU runtime, then set `RESTOREAI_RESTORE_ENGINE=lama` before starting the API. The first request may download pretrained LaMa weights; provision network access and persistent model cache. The default `opencv` engine is intentionally retained for existing installations. With `lama`, the automatic mask detector still limits quality: missed scratches remain and false positives can alter facial details. A future manual mask editor and portrait validation are required before claiming professional scratch restoration. If LaMa cannot load, the API reports an error instead of silently returning an OpenCV result. Do not run this in production without checking model licensing, security, and photo privacy.

## Optional precise scratch mask

`POST /enhance` with `mode=restore` also accepts multipart `mask` as a grayscale PNG **with exactly the same pixel dimensions as the uploaded image**. White pixels (>127) are repaired; black pixels are untouched. When omitted, the experimental automatic detector is used. This makes it possible to repair scratches missed by automatic detection without changing unrelated facial features. The Flutter UI does not yet include a manual mask painter; this API option is intended for the upcoming editor and controlled tests. Never commit users' personal photos or masks to a public repository.
