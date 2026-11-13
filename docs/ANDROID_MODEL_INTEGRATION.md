# Android NCNN integration — release gate

The current Android MethodChannel handler is a **stub**, not a working AI engine. No model weights, JNI library, or image processing implementation are present. Never distribute this APK as an offline AI restoration release.

## Required deliverables

1. Confirm exact Real-ESRGAN model variant and model weights source. Record license and SHA-256 for each model asset. Review third-party notices.
2. Compile ncnn with Android NDK for arm64-v8a, with Vulkan support only if verified on a device. Package native libraries and their licenses.
3. Convert or obtain a compatible ncnn param/bin pair for the **same** network architecture. Validate layer names, input normalization, RGB/BGR handling and output shape against a known reference.
4. Implement JNI to decode an image, honor EXIF rotation, split large inputs into overlapping tiles, run inference, stitch tiles without seams, and encode a new file. Validate output pixel budget and handle allocation failures.
5. Update `MainActivity.kt` to return `isAvailable=true` only after loading the actual model successfully. Process must return a path only after a real output image has been decoded and verified.
6. Replace the remote HTTPS-only Flutter enhancement action with a local engine call; make the UI show unsupported status until model assets are available. Never upload image data in offline mode.
7. Test on Galaxy S22+ in airplane mode with a fixed set of images, including portraits, text, old photos, and scratched photos. Measure RAM, latency, temperature and identity fidelity.
8. Run `python3 scripts/check_android_offline_assets.py --require-model` during the production build. **This must fail until verified model assets exist.**

## Release conditions

- APK includes real, licensed inference model files and native runtime.
- Processing runs with networking disabled and produces a new, decodable image.
- Before/after clearly shows a genuine difference, with no invented scratch-removal claims.
- Build, unit tests and on-device tests pass.
- The optional scratch-removal stage must have its own mask and evaluation.

## Important distinction

A GitHub Actions success for the current prototype only proves that the app builds and its tests pass. It does not prove that offline inference works. Do not flip the engine availability flag just to enable the Enhance button.
