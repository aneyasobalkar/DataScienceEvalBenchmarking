FROM python:3.12-slim

WORKDIR /app

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir pandas numpy matplotlib scikit-learn scipy seaborn

COPY data/ /data/
RUN mkdir -p /output/plots
