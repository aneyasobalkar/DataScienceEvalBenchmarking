FROM python:3.12-slim

WORKDIR /app

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install pandas numpy scipy matplotlib astropy

COPY data/ /data/
RUN mkdir -p /output/plots
