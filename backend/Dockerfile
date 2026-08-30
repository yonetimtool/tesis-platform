FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# (P190 §6) ffmpeg: RTSP kameradan SUNUCU tarafinda tek kare (JPEG) cekmek
# icin (`GET /cameras/{id}/kare`). Kimlik bilgili RTSP adresi istemciye
# gitmez; kareyi sunucu ceker. Imaj buyur (~+250 MB) — bilincli takas.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Bagimliliklar (asyncpg + psycopg[binary] wheel'leri ile gelir; ek apt gerekmez).
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama + testler + scriptler.
COPY pyproject.toml .
COPY app ./app
COPY tests ./tests
COPY scripts ./scripts

EXPOSE 8000

# (P39) ISCI SAYISI ENV ILE: tek isci, olcumde ana ekran demetini 10 es
# zamanli kullanicida p95 ~2 sn'ye cikariyordu (istekler tek olay
# dongusunde sirayla isleniyor). `API_WORKERS` varsayilani 1'dir —
# gelistirmede tek surec hata ayiklamayi kolaylastirir; prod'da
# scaling-runbook.md'deki formulle verilir.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers ${API_WORKERS:-1}"]
