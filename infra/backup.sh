#!/usr/bin/env bash
# =========================================================================
# Yonetio — gecelik sifreli Postgres yedegi.
#   pg_dump (db container) | gzip | gpg (AES256 simetrik) -> $BACKUP_DIR
#   Son 14 yedek tutulur; eskiler silinir.
#
# Cron (bkz. RUNBOOK-PROD.md) — her gece 03:15:
#   15 3 * * *  /opt/yonetio/tesis-platform/infra/backup.sh >> /var/log/yonetio-backup.log 2>&1
#
# Geri yukleme: bu dosyanin sonundaki "GERI YUKLEME" bolumune bakin.
# =========================================================================
set -euo pipefail

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$INFRA_DIR/.env.prod}"
COMPOSE_FILE="$INFRA_DIR/docker-compose.prod.yml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "HATA: $ENV_FILE yok. .env.prod olusturun." >&2
  exit 1
fi
# .env.prod'daki degiskenleri yukle (yorumlar ve bos satirlar guvenli).
set -a; # shellcheck disable=SC1090
source "$ENV_FILE"; set +a

: "${POSTGRES_USER:?}"; : "${POSTGRES_DB:?}"; : "${BACKUP_GPG_PASSPHRASE:?}"
BACKUP_DIR="${BACKUP_DIR:-/opt/yonetio/backups}"
RETENTION="${BACKUP_RETENTION:-14}"
mkdir -p "$BACKUP_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/yonetio-db-$STAMP.sql.gz.gpg"
COMPOSE=(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE")

echo "[$(date -Is)] yedek basliyor -> $OUT"
# -T: TTY yok (cron). pg_dump plain SQL -> gzip -> gpg simetrik.
"${COMPOSE[@]}" exec -T db \
    pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  | gzip -9 \
  | gpg --batch --yes --symmetric --cipher-algo AES256 \
        --passphrase "$BACKUP_GPG_PASSPHRASE" -o "$OUT"

# Bozuk/kismi dosya birakma: boyut 0 ise sil ve hata ver.
if [[ ! -s "$OUT" ]]; then
  echo "HATA: yedek bos, siliniyor." >&2; rm -f "$OUT"; exit 1
fi
echo "[$(date -Is)] yedek tamam ($(du -h "$OUT" | cut -f1))"

# Rotasyon: en yeni $RETENTION disindakileri sil.
ls -1t "$BACKUP_DIR"/yonetio-db-*.sql.gz.gpg 2>/dev/null \
  | tail -n +"$((RETENTION + 1))" | xargs -r rm -f
echo "[$(date -Is)] rotasyon tamam (son $RETENTION tutuldu)"

# -------------------------------------------------------------------------
# GERI YUKLEME (canliya) — DIKKAT: mevcut veriyi EZER.
#   gpg --batch --decrypt --passphrase "$BACKUP_GPG_PASSPHRASE" YEDEK.sql.gz.gpg \
#     | gunzip \
#     | docker compose -f docker-compose.prod.yml --env-file .env.prod \
#         exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
#
# MinIO (foto) yedegi: MinIO verisi `miniodata` docker volume'unda. Gecelik
# arsiv icin (ornek cron):
#   docker run --rm -v yonetio-prod_miniodata:/data -v "$BACKUP_DIR":/backup alpine \
#     tar czf /backup/yonetio-minio-$(date +\%Y\%m\%d).tar.gz -C /data .
# (Volume adi: `docker volume ls | grep miniodata`.) Restore: ters yon (tar xzf).
# -------------------------------------------------------------------------
