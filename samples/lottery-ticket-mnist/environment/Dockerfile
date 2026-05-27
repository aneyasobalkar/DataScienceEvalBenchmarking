FROM python:3.12-slim

WORKDIR /app

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install CPU-only PyTorch to keep image size manageable
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir numpy

# Pre-download MNIST so the container works offline at runtime
RUN python - <<'PYEOF'
import os, urllib.request, gzip, shutil

os.makedirs('/data/MNIST/raw', exist_ok=True)
base = 'https://ossci-datasets.s3.amazonaws.com/mnist/'
files = [
    'train-images-idx3-ubyte.gz',
    'train-labels-idx1-ubyte.gz',
    't10k-images-idx3-ubyte.gz',
    't10k-labels-idx1-ubyte.gz',
]
for fname in files:
    gz_path  = f'/data/MNIST/raw/{fname}'
    out_path = gz_path[:-3]
    urllib.request.urlretrieve(base + fname, gz_path)
    with gzip.open(gz_path, 'rb') as fi, open(out_path, 'wb') as fo:
        shutil.copyfileobj(fi, fo)
    os.remove(gz_path)
    print(f'Downloaded {fname[:-3]}')
PYEOF

RUN mkdir -p /output
