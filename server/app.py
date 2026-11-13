"""RestoreAI GPU FastAPI service using pretrained Real-ESRGAN x4plus weights."""
import io
import os
import threading
from pathlib import Path

import numpy as np
import torch
from basicsr.archs.rrdbnet_arch import RRDBNet
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image, ImageOps, UnidentifiedImageError

app = FastAPI(title="RestoreAI API", version="0.4.0")
WEIGHTS = Path(os.getenv("RESTOREAI_WEIGHTS", "/content/Real-ESRGAN/weights/RealESRGAN_x4plus.pth"))
MAX_BYTES = 8 * 1024 * 1024
MAX_PIXELS = 2_000_000
TILE = 192
PAD = 16
_lock = threading.Lock()
_model = None


def get_model():
    global _model
    if _model is None:
        if not torch.cuda.is_available():
            raise RuntimeError("CUDA GPU required")
        if not WEIGHTS.is_file():
            raise RuntimeError("Model weights missing")
        net = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64,
                      num_block=23, num_grow_ch=32, scale=4)
        checkpoint = torch.load(WEIGHTS, map_location="cpu", weights_only=True)
        state = checkpoint.get("params_ema", checkpoint.get("params", checkpoint))
        net.load_state_dict(state, strict=True)
        _model = net.eval().to("cuda")
    return _model


def enhance_tiled(image):
    source = np.asarray(image, dtype=np.float32) / 255.0
    height, width = source.shape[:2]
    result = np.empty((height * 4, width * 4, 3), dtype=np.uint8)
    net = get_model()
    with torch.inference_mode():
        for y in range(0, height, TILE):
            for x in range(0, width, TILE):
                y_end, x_end = min(y + TILE, height), min(x + TILE, width)
                y0, x0 = max(0, y - PAD), max(0, x - PAD)
                y1, x1 = min(height, y_end + PAD), min(width, x_end + PAD)
                patch = source[y0:y1, x0:x1]
                tensor = torch.from_numpy(patch.transpose(2, 0, 1).copy())
                tensor = tensor.unsqueeze(0).to("cuda")
                prediction = net(tensor).squeeze(0).clamp(0, 1)
                pixels = prediction.permute(1, 2, 0).mul(255).round()
                pixels = pixels.to(torch.uint8).cpu().numpy()
                result[y*4:y_end*4, x*4:x_end*4] = pixels[
                    (y-y0)*4:(y_end-y0)*4, (x-x0)*4:(x_end-x0)*4
                ]
    return Image.fromarray(result, mode="RGB")


@app.get("/health")
def health():
    return {"status": "ok", "gpu": torch.cuda.is_available(),
            "weights_found": WEIGHTS.is_file(), "model_loaded": _model is not None,
            "version": "0.4.0"}


@app.post("/enhance")
async def enhance(image: UploadFile = File(...)):
    if image.content_type not in ("image/png", "image/jpeg", "image/webp"):
        raise HTTPException(415, "JPEG, PNG or WebP required")
    data = await image.read(MAX_BYTES + 1)
    if not data:
        raise HTTPException(400, "Empty image")
    if len(data) > MAX_BYTES:
        raise HTTPException(413, "Image exceeds 8 MB")
    try:
        Image.MAX_IMAGE_PIXELS = MAX_PIXELS
        with Image.open(io.BytesIO(data)) as opened:
            opened.load()
            if opened.width * opened.height > MAX_PIXELS:
                raise HTTPException(413, "Image exceeds 2 megapixels")
            rgb = ImageOps.exif_transpose(opened).convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
        raise HTTPException(400, "Invalid image")

    try:
        with _lock:
            enhanced = enhance_tiled(rgb)
        output = io.BytesIO()
        enhanced.save(output, format="PNG")
        return Response(output.getvalue(), media_type="image/png",
                        headers={"Cache-Control": "no-store"})
    except RuntimeError as exc:
        if "out of memory" in str(exc).lower():
            torch.cuda.empty_cache()
            raise HTTPException(503, "GPU memory exhausted")
        raise HTTPException(503, "AI model is unavailable")
