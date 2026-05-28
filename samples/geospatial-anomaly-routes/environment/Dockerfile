FROM python:3.12-slim

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir pandas numpy scipy matplotlib seaborn

COPY data/trajectories.csv /data/trajectories.csv
RUN mkdir -p /output
