FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Bagimliliklar (asyncpg + psycopg[binary] wheel'leri ile gelir; ek apt gerekmez).
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama + testler + scriptler.
COPY pyproject.toml .
COPY app ./app
COPY tests ./tests
COPY scripts ./scripts

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
