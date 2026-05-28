FROM python:3.12-slim
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install pandas numpy biopython scipy
COPY data/ /data/
RUN mkdir -p /app
