FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev libgeos-dev libproj-dev && \
    rm -rf /var/lib/apt/lists/*
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install pandas numpy geopandas libpysal esda matplotlib \
    scipy seaborn mapclassify
COPY data/ /data/
RUN mkdir -p /output/plots
