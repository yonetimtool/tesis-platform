#!/usr/bin/env bash
# (P253 A2) HARITA KARO DOSYASI — Turkiye PMTiles kesitini indir ve MinIO'ya koy.
#
# Yilda 1-2 kez yeterli (yeni yollar, binalar). Ayrintilar: docs/harita-karo.md
#
# KULLANIM (depo kokunde):
#   bash docs/karo-guncelle.sh                 # dev  (infra/docker-compose.yml)
#   ORTAM=prod bash docs/karo-guncelle.sh      # prod (infra/docker-compose.prod.yml + .env.prod)
#   TARIH=20261003 bash docs/karo-guncelle.sh  # belirli bir Protomaps derlemesi
#
# Ne yapar:
#   1. Protomaps'in gunluk dunya derlemesinden Turkiye + sinir payini
#      (boylam 25.0-45.5, enlem 35.3-42.6, z0-15) KESER — dunyanin tamami
#      (~140 GB) INMEZ, yalniz gereken araliklar (~1,8 GB).
#   2. Dosyayi SURUMLU adla (`turkiye-<tarih>.pmtiles`) `karo` kovasina koyar,
#      `Cache-Control: public, max-age=31536000, immutable` ile: istemciler
#      ayni araligi bir daha indirmez; yeni surum YENI AD oldugu icin bayat
#      onbellek sorunu olmaz.
#   3. Sonunda yapilacak TEK adimi yazar: `HARITA_KARO_DOSYASI` degiskenini
#      yeni ada cevirip api'yi yeniden olusturmak. Istemciler adresi
#      `GET /ozellikler`ten alir — uygulama guncellemesi GEREKMEZ.
#   Eski dosya SILINMEZ: acik istemciler bir sure onu okumaya devam eder.
#   Bir sonraki guncellemede elle silinebilir (betik listesini yazar).
set -euo pipefail

ORTAM="${ORTAM:-dev}"
TARIH="${TARIH:-}"
BBOX="25.0,35.3,45.5,42.6"
AZAMI_ZOOM=15
PMTILES_SURUM="1.31.2"
KOK="$(cd "$(dirname "$0")/.." && pwd)"
IS="$(mktemp -d)"
trap 'rm -rf "$IS"' EXIT

if [ "$ORTAM" = prod ]; then
  COMPOSE=(docker compose -f "$KOK/infra/docker-compose.prod.yml" --env-file "$KOK/infra/.env.prod")
else
  COMPOSE=(docker compose -f "$KOK/infra/docker-compose.yml")
fi

# 1) pmtiles araci (tek ikili, surum sabit).
curl -sSL -o "$IS/p.tgz" \
  "https://github.com/protomaps/go-pmtiles/releases/download/v${PMTILES_SURUM}/go-pmtiles_${PMTILES_SURUM}_Linux_x86_64.tar.gz"
tar -xzf "$IS/p.tgz" -C "$IS" pmtiles

# 2) En yeni derleme (ya da TARIH).
if [ -z "$TARIH" ]; then
  TARIH="$(curl -sS https://build-metadata.protomaps.dev/builds.json \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)[-1]["key"].split(".")[0])')"
fi
AD="turkiye-${TARIH}.pmtiles"
echo ">> derleme: ${TARIH}  ->  ${AD}"
"$IS/pmtiles" extract "https://build.protomaps.com/${TARIH}.pmtiles" "$IS/$AD" \
  --bbox="$BBOX" --maxzoom="$AZAMI_ZOOM"
"$IS/pmtiles" verify "$IS/$AD"
echo ">> boyut: $(stat -c %s "$IS/$AD") bayt"

# 3) MinIO'ya koy (minio-init ile ayni kimlik ve ag).
"${COMPOSE[@]}" run --rm -v "$IS:/k:ro" --entrypoint /bin/sh minio-init -c "
  mc alias set local http://minio:9000 \"\$MINIO_ROOT_USER\" \"\$MINIO_ROOT_PASSWORD\" >/dev/null
  mc mb -p local/karo >/dev/null 2>&1 || true
  mc anonymous set download local/karo >/dev/null
  mc cp --attr 'Cache-Control=public, max-age=31536000, immutable;Content-Type=application/vnd.pmtiles' /k/$AD local/karo/$AD
  echo '>> kovadaki dosyalar:'; mc ls local/karo
"

cat <<SON

TAMAM. Son adim — sunucunun istemcilere verdigi adresi cevir:
  infra/.env$([ "$ORTAM" = prod ] && echo .prod)  ->  HARITA_KARO_DOSYASI=${AD}
  ${COMPOSE[*]} up -d --force-recreate api
Dogrulama:  curl -s <api>/ozellikler   ->  harita_karo_url ...${AD}
SON
