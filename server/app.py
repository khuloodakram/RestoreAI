"""RestoreAI prototype API. Run only behind a private HTTPS tunnel for testing."""
import io
import os
import subprocess
import tempfile
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image, UnidentifiedImageError

app = FastAPI(title="RestoreAI API", version="0.3.0")
MODEL_ROOT = Path(os.getenv("RESTOREAI_MODEL_ROOT", "/tmp/restoreai-check/unpacked"))
MAX_BYTES = 8 * 1024 * 1024
MAX_PIXELS = 1_000_000  # x4 output up to 16 million pixels


def model_files():
    return (MODEL_ROOT / "realesrgan-ncnn-vulkan",
            MODEL_ROOT / "models" / "realesrgan-x4plus.param",
            MODEL_ROOT / "models" / "realesrgan-x4plus.bin")


@app.get("/health")
def health():
    return {"ready": all(p.is_file() for p in model_files()), "model": "realesrgan-x4plus"}


@app.post("/enhance")
async def enhance(image: UploadFile = File(...)):
    if image.content_type not in ("image/png", "image/jpeg"):
        raise HTTPException(415, "JPEG or PNG required")
    data = await image.read(MAX_BYTES + 1)
    if not data:
        raise HTTPException(400, "Empty image")
    if len(data) > MAX_BYTES:
        raise HTTPException(413, "Image must be 8 MB or less")
    if not health()["ready"]:
        raise HTTPException(503, "AI model files are not installed")
    try:
        with Image.open(io.BytesIO(data)) as original:
            original.load()
            if original.width * original.height > MAX_PIXELS:
                raise HTTPException(413, "Image must be 1 megapixel or less")
            rgb = original.convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(400, "Invalid or corrupt image")

    with tempfile.TemporaryDirectory(prefix="restoreai-") as temp:
        src, dst = Path(temp) / "input.png", Path(temp) / "enhanced.png"
        rgb.save(src)
        exe, param, _ = model_files()
        command = [str(exe), "-i", str(src), "-o", str(dst),
                   "-n", param.stem, "-m", str(param.parent), "-s", "4", "-g", "0", "-t", "32"]
        try:
            result = subprocess.run(command, cwd=exe.parent, capture_output=True, text=True, timeout=240)
        except subprocess.TimeoutExpired:
            raise HTTPException(504, "AI processing timed out")
        if result.returncode != 0 or not dst.is_file():
            raise HTTPException(502, "AI inference failed on the server")
        try:
            with Image.open(dst) as output:
                output.verify()
            return Response(content=dst.read_bytes(), media_type="image/png",
                            headers={"Cache-Control": "no-store"})
        except (UnidentifiedImageError, OSError):
            raise HTTPException(502, "AI returned an invalid image")
