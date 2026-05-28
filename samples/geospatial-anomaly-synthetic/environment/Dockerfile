FROM python:3.12-slim

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir pandas numpy matplotlib scipy scikit-learn folium

COPY data/ /data/
RUN mkdir -p /output/plots
