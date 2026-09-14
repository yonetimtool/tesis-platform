#!/usr/bin/env bash
# (P232) IMAJ ESKIYKEN TEST KOSMAYI ENGELLEYEN SARMALAYICI.
#
# =============================================================================
# NEDEN AYRI BIR BETIK
# =============================================================================
# `guvenli-derle.sh` BIR kusuru kapatti: kosan takimin altindan konteyner
# cekmek. Ama IKINCI bir kusur ayni seansta IKI KEZ tekrarladi ve o betik
# onu GORMEZ:
#
#   kaynagi degistir (ya da kirma deneyinden geri al) -> DERLEMEYI UNUT ->
#   testi kosur -> konteyner ESKI KODLA cevap verir.
#
# Sonuc her iki yonde de yanlis: P230 §4'te DUZELTILMIS kodu "kirmizi"
# raporladi (uc sahte kirmizi, sebebini bulmak ayrica zaman aldi); burada
# ise geri alinmis bir KIRMA DENEYI hala kirikmis gibi gorundu.
#
# Testin kendisi bunu fark edemez: konteyner saglikli, uclar cevap
# veriyor, yalnizca KOD ESKI.
#
# =============================================================================
# NASIL OLCULUYOR: ICERIK OZETI, ZAMAN DAMGASI DEGIL
# =============================================================================
# Ilk yazim ZAMAN DAMGASI karsilastiriyordu ve HEMEN yanlis pozitif
# verdi: kirma deneyinden `cp` ile geri alinan dosyanin ICERIGI eski
# haliyle AYNI oldugu icin Docker katman onbellegi tuttu ve imajdaki
# mtime eski kaldi; kaynak "167 sn daha yeni" gorundu, oysa KOD AYNIYDI.
#
# Yanlis pozitif zararlidir: engel guvenilmez olunca `--zorla`
# aliskanligi dogar ve engel yok demektir.
#
# Sorulan asil soru zaten "kod ayni mi": icerik ozeti onu DOGRUDAN
# yanitlar ve geri almalara, dokunmalara, saat farklarina duyarsizdir.
set -euo pipefail
cd "$(dirname "$0")"

ZORLA=0
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --zorla) ZORLA=1 ;;
    *) ARGS+=("$arg") ;;
  esac
done

if [ "$ZORLA" -eq 0 ]; then
  # YOL ONEKI ONCE ATILIR, SONRA SIRALANIR.
  #
  # Ilk denemede `sort` FARKLI onekler uzerinde calisiyordu
  # (`backend/app/...` ve `app/...`), yani ayni dosyalar FARKLI SIRADA
  # ozetleniyor ve toplam hep ayrisiyordu — tek tek dosyalar birebir
  # ayni oldugu halde. Ikinci yanlis pozitif; olcumle yakalandi.
  # `awk` ile "hash yol" NORMALLESTIRILIR: `sha1sum` ciktisindaki iki
  # bosluk ve yol oneki iki tarafta farkli; ham `sed` ile duzeltmek
  # ucuncu bir yanlis pozitif uretmisti.
  #
  # KONTEYNER KOKU `/app`: `COPY app ./app` + `COPY tests ./tests`, yani
  # dizinler `/app/app` ve `/app/tests`. Ilk yazim `cd /` diyordu ve
  # `tests` bulunamiyordu — sessizce EKSIK bir kume ozetleniyordu.
  YEREL=$(cd ../backend && find app tests -type f -name '*.py' \
    -exec sha1sum {} + 2>/dev/null \
    | awk '{print $1, $2}' | sort | sha1sum | cut -d' ' -f1)
  IMAJ=$(docker compose exec -T api sh -c "
    cd /app && find app tests -type f -name '*.py' \
      -exec sha1sum {} + 2>/dev/null \
      | awk '{print \$1, \$2}' | sort | sha1sum | cut -d' ' -f1" 2>/dev/null || true)
  if [ -z "${YEREL:-}" ] || [ -z "${IMAJ:-}" ]; then
    echo "!! tazelik OKUNAMADI — fail-closed, test kosulmadi." >&2
    echo "   Yine de kosmak icin: $0 ${ARGS[*]} --zorla" >&2
    exit 2
  fi
  if [ "$YEREL" != "$IMAJ" ]; then
    echo "!! IMAJ BAYAT — kaynak imajdan YENI." >&2
    echo "   Test ESKI KODU olcerdi; sonuc her iki yonde de yaniltici olur." >&2
    echo "   Once: ./guvenli-derle.sh api" >&2
    exit 1
  fi
fi

exec docker compose exec -T api pytest "${ARGS[@]}"
