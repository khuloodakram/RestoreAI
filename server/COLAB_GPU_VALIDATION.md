# RestoreAI — Colab GPU validation (experimental)

This is a **manual GPU validation**, not a continuously hosted service. Run from a GPU-enabled Google Colab runtime with a compatible Python/PyTorch/BasicSR environment. Do not claim scratch restoration quality based on mocked CI tests.

## 1. Prepare the repository and pretrained weights

In a Colab cell:

```python
!git clone https://github.com/khuloodakram/RestoreAI.git
%cd RestoreAI
!git fetch origin feature/bilingual-ui
!git checkout feature/bilingual-ui
!pip install -r server/requirements.txt -r server/requirements-lama.txt
```

Install a compatible BasicSR / torch / torchvision stack separately, following `server/DEPLOYMENT.md`. BasicSR may need the previously documented compatibility workaround. Download the official Real-ESRGAN x4plus checkpoint to a known location and set `RESTOREAI_WEIGHTS`. Verify the checkpoint provenance before using it.

## 2. Compare both restoration engines on a real scratched image

Upload a **non-sensitive** source photo to Colab as `/content/scratched.png`. In a new cell:

```python
import os, time
from pathlib import Path
from PIL import Image
from server.app import restore_visible_scratches, restore_with_lama, enhance_tiled

source = Image.open('/content/scratched.png').convert('RGB')
for label, fn in [('opencv', restore_visible_scratches), ('lama', restore_with_lama)]:
    started = time.perf_counter()
    restored = fn(source)
    restored.save(f'/content/{label}_restored.png')
    print(label, 'seconds:', round(time.perf_counter() - started, 2))
    # Optional: upscaling may be expensive for large images.
    if source.width * source.height <= 250_000:
        enhance_tiled(restored).save(f'/content/{label}_upscaled.png')
```

Compare `scratched.png`, `opencv_restored.png`, and `lama_restored.png` at 100% zoom. Check **face shape, eyes, hair, text, remaining scratches and invented details**. If automatic scratch detection misses damage, LaMa will also miss it: LaMa only fills pixels marked by the mask. Save and compare the masks with:

```python
from server.app import detect_scratch_mask
Image.fromarray(detect_scratch_mask(source)).save('/content/detected_mask.png')
```

## 3. Test the actual API

```python
import os
os.environ['RESTOREAI_RESTORE_ENGINE'] = 'lama'
from fastapi.testclient import TestClient
from server.app import app
client = TestClient(app)
with open('/content/scratched.png', 'rb') as f:
    result = client.post('/enhance', files={'image': ('scratched.png', f, 'image/png')}, data={'mode':'restore'}, timeout=240)
print('status:', result.status_code, 'type:', result.headers.get('content-type'))
if result.status_code == 200:
    Path('/content/api_restored.png').write_bytes(result.content)
else:
    print(result.text[:500])
```

**Do not expose the Colab server publicly without authentication**. Colab sessions expire and are unsuitable for a production backend. Before public release: provision a persistent HTTPS GPU server, protect uploads, define retention/deletion, rate-limit requests, and test Android against that real endpoint.
