# RestoreAI — offline-first engineering plan

Status: **research and foundation only**. No native AI model is integrated into the Android APK yet.

## Product constraints

- Android phone first; reference device: Samsung Galaxy S22+ with 8 GB RAM.
- No image upload or remote inference in offline mode.
- Preserve original images; outputs go to a separate file.
- Arabic and English UI; clear errors and processing progress.
- Never label bicubic resizing as AI enhancement, or claim scratch removal from super-resolution alone.

## Candidate review (research, not device benchmarks)

| Candidate | Job | Mobile strategy | Risk | Decision |
|---|---|---|---|---|
| Real-ESRGAN general-x4v3 | General upscaling/denoise | ncnn Vulkan, tiled | Hallucinated texture; model availability/packaging | **First device spike** |
| Real-ESRGAN x4plus | Stronger general SR baseline | ncnn Vulkan, tiled | Memory, heat, time | Compare after lightweight model |
| Real-ESRNet x4plus | More conservative SR | ncnn Vulkan | Less dramatic perceived detail | Fidelity baseline |
| OpenCV inpainting | Thin scratches with a good mask | Native OpenCV or lightweight equivalent | Bad mask smears eyes/hair | Keep as reliable V2-style baseline |
| LaMa | Mask-guided inpainting | ONNX Runtime mobile experiment | Memory, mask quality, latency | Optional advanced experiment |
| CodeFormer / GFPGAN | Face restoration | Quantized/mobile conversion experiment | Alters identity, heavy dependencies | **Not default**; opt-in only |

Official references:
- https://github.com/xinntao/Real-ESRGAN
- https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan
- https://github.com/Tencent/ncnn
- https://github.com/advimman/lama
- https://github.com/sczhou/CodeFormer
- https://github.com/TencentARC/GFPGAN
- https://onnxruntime.ai/docs/execution-providers/mobile.html

## Architecture

Flutter UI -> OfflineRestoreEngine contract -> Android MethodChannel -> native C++ ncnn Vulkan + image tiling.
A separate restoration stage handles scratch masks and inpainting. Never use a Colab URL in the offline pipeline.

Recommended order:
1. Validate on-device Vulkan support and CPU fallback behavior.
2. Package **licensed** ncnn binaries and verified model files for arm64-v8a.
3. Implement native load/process/save, tiling, memory guard, cancellation, progress.
4. Add before/after slider, output save/share, error handling.
5. Compare original, V2, LaMa, and mobile outputs on the same fixed photo set.
6. Only enable the corresponding UI mode after real device evidence.

## Acceptance gates (not yet met)

- Airplane-mode image processing works with no network permission or network calls.
- At least 10 test images: portraits, scratched photos, noisy photos, large images.
- No overwrite; orientation and colors preserved; output decodes correctly.
- Time, peak RAM, APK size, and battery/thermal behavior measured on S22+.
- Record qualitative face fidelity and scratch-removal quality against V2/V3.
- No silent crashes, OOM, black output, or false-success result.
- Run Flutter tests and Android APK build in GitHub Actions.

## Research caveats

Upstream ncnn Vulkan desktop releases are **not** Android binaries. A working Linux Vulkan test does not prove the Android JNI integration. LaMa requires a scratch mask; super-resolution does not replace scratch removal. CodeFormer can change facial identity. Device speed and model size are **unknown** until tested.

## Next engineering task

Implement an Android arm64-v8a native inference spike behind `OfflineRestoreEngine`, with a real model artifact, license review, reproducible build, and measured output. Until then the contract intentionally reports unavailable.
