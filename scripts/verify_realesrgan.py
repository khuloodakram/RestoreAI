#!/usr/bin/env python3
"""Run a real Real-ESRGAN NCNN inference smoke test on Linux GitHub Actions."""
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import urllib.request
import zipfile
import zlib

API = 'https://api.github.com/repos/xinntao/Real-ESRGAN-ncnn-vulkan/releases/latest'
ROOT = Path(os.environ.get('RUNNER_TEMP', tempfile.gettempdir())) / 'restoreai-check'


def download(url, path):
    request = urllib.request.Request(url, headers={'User-Agent': 'RestoreAI-verification', 'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(request, timeout=120) as response, path.open('wb') as out:
        shutil.copyfileobj(response, out)


def make_png(path, width=48, height=48):
    def chunk(tag, data):
        return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag + data) & 0xffffffff)
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            rows.extend(((x * 5 + y) % 256, (y * 7 + x) % 256, (x * 3 + y * 2) % 256))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows))) + chunk(b'IEND', b''))


def png_size(path):
    data = path.read_bytes()
    if not data.startswith(b'\x89PNG\r\n\x1a\n') or len(data) < 24:
        raise RuntimeError('Output is not a valid PNG header')
    return struct.unpack('!II', data[16:24])


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    meta_path = ROOT / 'release.json'
    download(API, meta_path)
    release = json.loads(meta_path.read_text())
    assets = release.get('assets', [])
    candidates = [a for a in assets if a['name'].lower().endswith('.zip') and ('ubuntu' in a['name'].lower() or 'linux' in a['name'].lower()) and 'source' not in a['name'].lower()]
    if not candidates:
        raise RuntimeError('No Linux release ZIP found; assets: ' + ', '.join(a['name'] for a in assets))
    asset = sorted(candidates, key=lambda a: ('ubuntu' not in a['name'].lower(), a['name']))[0]
    print('Release:', release.get('tag_name'), 'Asset:', asset['name'], flush=True)
    archive = ROOT / 'release.zip'
    download(asset['browser_download_url'], archive)
    
    models_archive = ROOT / 'models-release.zip'
    models_url = (
        'https://github.com/xinntao/Real-ESRGAN/releases/'
        'download/v0.2.5.0/'
        'realesrgan-ncnn-vulkan-20220424-ubuntu.zip'
    )
    download(models_url, models_archive)

    unpack = ROOT / 'unpacked'
    unpack.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        for member in z.infolist():
            dest = (unpack / member.filename).resolve()
            if not dest.is_relative_to(unpack.resolve()):
                raise RuntimeError('Unsafe archive path')
            if member.file_size > 500_000_000:
                raise RuntimeError('Unexpectedly large file')
        z.extractall(unpack)
        
    with zipfile.ZipFile(models_archive) as z:
        for member in z.infolist():
            dest = (unpack / member.filename).resolve()
            if not dest.is_relative_to(unpack.resolve()):
                raise RuntimeError('Unsafe model archive path')
            if member.file_size > 500_000_000:
                raise RuntimeError('Unexpectedly large model file')
        z.extractall(unpack)

    executables = [p for p in unpack.rglob('realesrgan-ncnn-vulkan') if p.is_file()]
    if not executables:
        raise RuntimeError('Executable missing from official Linux archive')
    exe = executables[0]
    exe.chmod(exe.stat().st_mode | 0o111)
    # Official release bundles differ: choose a real matched .param/.bin pair.
    pairs = []
    for param in unpack.rglob('*.param'):
        binary = param.with_suffix('.bin')
        if binary.is_file():
            pairs.append(param)
    print('Available model pairs:', [str(p.relative_to(unpack)) for p in pairs], flush=True)
    if not pairs:
        raise RuntimeError('No matching NCNN .param/.bin model files in archive')
    preferred = ('realesrgan-x4plus', 'realesrnet-x4plus', 'realesr-animevideov3', 'realesrgan-x4plus-anime')
    selected = next((p for name in preferred for p in pairs if p.stem == name), None)
    if selected is None:
        raise RuntimeError('No recognized Real-ESRGAN model found; inspect available model pairs above')
    model_dir = selected.parent
    model_name = selected.stem
    print('Selected model:', model_name, flush=True)
    src = ROOT / 'input.png'
    dst = ROOT / 'enhanced.png'
    make_png(src)
    command = [str(exe), '-i', str(src), '-o', str(dst), '-n', model_name, '-m', str(model_dir), '-s', '4', '-g', '0', '-t', '32', '-v']
    print('Executing:', ' '.join(command), flush=True)
    result = subprocess.run(command, cwd=exe.parent, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
    print(result.stdout[-12000:], flush=True)
    if result.returncode != 0:
        raise RuntimeError(f'Inference failed with exit code {result.returncode}')
    if not dst.is_file() or dst.stat().st_size < 100:
        raise RuntimeError('No meaningful output image produced')
    dims = png_size(dst)
    if dims != (192, 192):
        raise RuntimeError(f'Unexpected output dimensions: {dims}')
    print('PASS: Real-ESRGAN NCNN produced a 192x192 PNG from a 48x48 input.', flush=True)


if __name__ == '__main__':
    main()
