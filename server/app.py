"""RestoreAI GPU FastAPI service using pretrained Real-ESRGAN x4plus weights."""
import io
import secrets
import os
import threading
from pathlib import Path

import cv2
import numpy as np
import torch
from basicsr.archs.rrdbnet_arch import RRDBNet
from fastapi import FastAPI, File, Form, HTTPException, UploadFile, Header
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
_lama_model = None


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




def detect_scratch_mask(image):
    """Conservative automatic thin bright-scratch mask; not a learned detector.

    Avoid aggressive masks on faces: detection can confuse highlights and hair.
    """
    rgb = np.asarray(image.convert("RGB"))
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    # A round opening removes thin highlights in any orientation. Restrict
    # candidates to bright pixels that differ substantially from their vicinity.
    # This is conservative: false positives can damage facial details.
    background = cv2.morphologyEx(gray, cv2.MORPH_OPEN,
                                  cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))
    candidates = cv2.subtract(gray, background)
    mask = ((candidates > 38) & (gray > 135)).astype(np.uint8) * 255
    # Only retain narrow connected components of meaningful length.
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    clean = np.zeros_like(mask)
    for i in range(1, count):
        x, y, w, h, area = stats[i]
        if 10 <= area <= 1500 and max(w, h) >= 12 and area / max(w * h, 1) < 0.48:
            clean[labels == i] = 255
    return cv2.dilate(clean, np.ones((3, 3), np.uint8), iterations=1)


def restore_visible_scratches(image, mask=None):
    if mask is None:
        mask = detect_scratch_mask(image)
    if not np.any(mask):
        return image
    rgb = np.asarray(image.convert('RGB'))
    repaired = cv2.inpaint(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), mask, 3, cv2.INPAINT_TELEA)
    return Image.fromarray(cv2.cvtColor(repaired, cv2.COLOR_BGR2RGB))


def restore_with_lama(image, mask=None):
    """Optional pretrained LaMa inpainting. Never silently substitute OpenCV."""
    global _lama_model
    if mask is None:
        mask = detect_scratch_mask(image)
    if not np.any(mask):
        return image
    if _lama_model is None:
        try:
            from simple_lama_inpainting import SimpleLama
        except ImportError as exc:
            raise RuntimeError('LaMa dependency missing') from exc
        _lama_model = SimpleLama()
    return _lama_model(image.convert('RGB'), Image.fromarray(mask, mode='L'))

@app.get("/health")
def health():
    return {"status": "ok", "gpu": torch.cuda.is_available(),
            "weights_found": WEIGHTS.is_file(), "model_loaded": _model is not None,
            "version": "0.5.0",
            "restoration_engine": os.getenv("RESTOREAI_RESTORE_ENGINE", "opencv")}


@app.post("/enhance")
async def enhance(image: UploadFile = File(...), mode: str = Form("enhance"),
                  mask: UploadFile | None = File(None),
                  authorization: str | None = Header(None)):
    required_token = os.getenv('RESTOREAI_API_TOKEN', '')
    if required_token and not secrets.compare_digest(
            authorization or '', 'Bearer ' + required_token):
        raise HTTPException(401, 'Unauthorized')
    if mode not in ("enhance", "restore"):
        raise HTTPException(422, "Unsupported mode")
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

    custom_mask = None
    if mask is not None:
        if mode != "restore":
            raise HTTPException(422, "Mask requires restore mode")
        raw_mask = await mask.read(MAX_BYTES + 1)
        if not raw_mask or len(raw_mask) > MAX_BYTES:
            raise HTTPException(413, "Invalid mask size")
        try:
            with Image.open(io.BytesIO(raw_mask)) as opened_mask:
                if opened_mask.width * opened_mask.height > MAX_PIXELS:
                    raise HTTPException(413, "Mask exceeds 2 megapixels")
                opened_mask.load()
                oriented_mask = ImageOps.exif_transpose(opened_mask)
                if oriented_mask.size != rgb.size:
                    raise HTTPException(422, "Mask dimensions must match source image")
                custom_mask = np.asarray(oriented_mask.convert("L"))
                custom_mask = np.where(custom_mask > 127, 255, 0).astype(np.uint8)
        except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
            raise HTTPException(400, "Invalid mask image")

    try:
        with _lock:
            if mode == 'restore':
                engine = os.getenv('RESTOREAI_RESTORE_ENGINE', 'opencv').lower()
                if engine == 'lama':
                    source = restore_with_lama(rgb, custom_mask)
                elif engine == 'opencv':
                    source = restore_visible_scratches(rgb, custom_mask)
                else:
                    raise RuntimeError('Unknown restoration engine')
            else:
                source = rgb
            enhanced = enhance_tiled(source)
        output = io.BytesIO()
        enhanced.save(output, format="PNG")
        return Response(output.getvalue(), media_type="image/png",
                        headers={"Cache-Control": "no-store"})
    except RuntimeError as exc:
        if "out of memory" in str(exc).lower():
            torch.cuda.empty_cache()
            raise HTTPException(503, "GPU memory exhausted")
        raise HTTPException(503, "AI model is unavailable")
