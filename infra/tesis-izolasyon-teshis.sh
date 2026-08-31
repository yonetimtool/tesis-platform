#!/usr/bin/env bash
# (P192) TESİS İZOLASYONU — PROD TEŞHİSİ
#
# "Bir tesisin yöneticisi başka tesislerin kullanıcılarını görüyor"
# şikâyetinin ÜÇ olası nedeni vardır ve üçünün çözümü FARKLIDIR:
#
#   1. GERÇEK SIZINTI  — RLS kapalı / uygulama superuser ile bağlanıyor.
#   2. VERİ DÜZENİ     — o kişiler GERÇEKTEN aynı tesiste (aynı tenant'a
#                        kaydolmuşlar). Sızıntı yok; kayıtlar taşınmalı.
#   3. ROL             — o yönetici `admin` (PLATFORM) rolünde; platform
#                        konsolu zaten tesisler arasıdır.
#
# Bu betik hangisinin doğru olduğunu söyler. HİÇBİR ŞEY DEĞİŞTİRMEZ.
#
# Kullanım (PROD sunucusunda, infra/ içinde):
#   ./tesis-izolasyon-teshis.sh
#
# Geliştirme yığınında denemek için:
#   COMPOSE_DOSYA=docker-compose.yml ENV_DOSYA= ./tesis-izolasyon-teshis.sh
#
# NEDEN DEĞİŞKEN: koşulmamış bir teşhis betiği kendisi bir risktir. Prod'da
# ilk kez çalıştırılan bir betiğin bir yazım hatası yüzünden patlaması, en
# çok ihtiyaç duyulan anda elinizde araç bırakmamak demektir. Dosya adları
# değişkenleştirildi ki betik geliştirme yığınında AYNEN denenebilsin.
set -euo pipefail

COMPOSE_DOSYA="${COMPOSE_DOSYA-docker-compose.prod.yml}"
ENV_DOSYA="${ENV_DOSYA-.env.prod}"

COMPOSE=(docker compose -f "$COMPOSE_DOSYA")
if [ -n "$ENV_DOSYA" ]; then
  if [ ! -f "$ENV_DOSYA" ]; then
    echo "HATA: $ENV_DOSYA yok. Prod sunucusunda mısınız?" >&2
    echo "      (dev icin: COMPOSE_DOSYA=docker-compose.yml ENV_DOSYA= $0)" >&2
    exit 2
  fi
  COMPOSE+=(--env-file "$ENV_DOSYA")
  # Kullanici/veritabani adlari .env dosyasinda yasar; kabuk ortamindan
  # okumak prod'da BOS gelir ve psql yanlis kullaniciyla baglanirdi.
  DB_KULLANICI="$(grep -E '^POSTGRES_USER=' "$ENV_DOSYA" | cut -d= -f2- || true)"
  DB_AD="$(grep -E '^POSTGRES_DB=' "$ENV_DOSYA" | cut -d= -f2- || true)"
fi
DB_KULLANICI="${DB_KULLANICI:-tesis_owner}"
DB_AD="${DB_AD:-tesis}"

psql_calistir() {
  "${COMPOSE[@]}" exec -T db psql -U "$DB_KULLANICI" -d "$DB_AD" -A -t -c "$1"
}

echo "=== 1) API HANGİ VERİTABANI KULLANICISIYLA BAĞLANIYOR? ==="
echo "    (superuser ya da BYPASSRLS ise TÜM politikalar süstür)"
"${COMPOSE[@]}" exec -T api python - <<'PY'
import re
from app.config import settings
u = settings.database_url
kullanici = re.sub(r"^.*://([^:]+):.*$", r"\1", u)
print(f"    baglanti kullanicisi : {kullanici}")
print(f"    BEKLENEN             : app_rw")
PY

echo
echo "=== 2) UYGULAMA ROLÜ RLS'İ ATLAYABİLİYOR MU? ==="
psql_calistir "SELECT '    app_rw superuser=' || rolsuper || '  bypassrls=' || rolbypassrls
          FROM pg_roles WHERE rolname='app_rw';"
echo "    BEKLENEN: ikisi de f"

echo
echo "=== 3) RLS HER TENANT TABLOSUNDA AÇIK VE ZORLANMIŞ MI? ==="
# SESSIZ KALMAZ: bos cikti "tamam mi, sorgu mu patladi?" sorusunu cevapsiz
# birakirdi — teshiste belirsizlik en kotu ciktidir.
KORUMASIZ="$(psql_calistir "SELECT coalesce(string_agg(x.relname, ', '), '') FROM (SELECT DISTINCT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN information_schema.columns col ON col.table_name=c.relname AND col.table_schema='public' WHERE n.nspname='public' AND c.relkind='r' AND col.column_name='tenant_id' AND NOT (c.relrowsecurity AND c.relforcerowsecurity)) x;" | tr -d '\r' | sed 's/^ *//;s/ *$//')"
TOPLAM_TABLO="$(psql_calistir "SELECT count(DISTINCT c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN information_schema.columns col ON col.table_name=c.relname AND col.table_schema='public' WHERE n.nspname='public' AND c.relkind='r' AND col.column_name='tenant_id';" | tr -d '[:space:]')"
if [ -z "$KORUMASIZ" ]; then
  echo "    TAMAM: $TOPLAM_TABLO tenant tablosunun HEPSINDE RLS acik + zorlanmis"
else
  echo "    !!! KUSUR — RLS acik/zorlanmis DEGIL: $KORUMASIZ"
fi

echo
echo "=== 4) PLATFORM ROLÜNDE (admin) KAÇ HESAP VAR? ==="
echo "    (yalnız platform sahibi olmalı; bir tesis yöneticisi burada"
echo "     görünüyorsa panel konsolunu açabilir — 3. neden budur)"
psql_calistir "
SELECT '    ' || u.email || '   tesis=' || t.ad
FROM app_user u JOIN tenant t ON t.id=u.tenant_id
WHERE u.role='admin' AND u.is_active;"

echo
echo "=== 5) KULLANICILAR TESİSLERE NASIL DAĞILMIŞ? ==="
echo "    (şikâyet edilen ekranda görünen kişiler TEK tenant'ta ise"
echo "     sızıntı YOKTUR — 2. neden budur: kayıtlar yanlış tesiste)"
psql_calistir "
SELECT '    ' || t.ad || '  (' || t.slug || ')  kullanici=' || count(u.id)
FROM tenant t LEFT JOIN app_user u ON u.tenant_id=t.id
GROUP BY t.id, t.ad, t.slug HAVING count(u.id) > 1
ORDER BY count(u.id) DESC LIMIT 20;"

echo
echo "=== 6) CANLI ÇAPRAZ-TESİS DENEMESİ ==="
# TALIMAT DEGIL, OLCUM: kimlik verilirse betik gercekten giris yapar,
# `/users` cagirir ve DONEN kullanicilarin KAC FARKLI tesise ait oldugunu
# VERITABANINDAN sayar. 1'den buyukse sizinti KANITLANMIS olur.
if [ -n "${SLUG:-}" ] && [ -n "${EPOSTA:-}" ] && [ -n "${PAROLA:-}" ]; then
  API="${API_URL:-https://api.yonetiyor.com}"
  echo "    hesap: $EPOSTA @ $SLUG  ($API)"
  GOVDE="$(python3 -c '
import json, os
print(json.dumps({
    "tenant_slug": os.environ["SLUG"],
    "email": os.environ["EPOSTA"],
    "password": os.environ["PAROLA"],
}))')"
  JETON="$(curl -sS -X POST "$API/auth/login" -H 'Content-Type: application/json' \
    --data-binary "$GOVDE" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null || true)"
  if [ -z "$JETON" ]; then
    echo "    !!! Giris basarisiz (slug/eposta/parola?) — olcum yapilamadi"
  else
    IDLER="$(curl -sS "$API/users?limit=200" -H "Authorization: Bearer $JETON" \
      | python3 -c '
import sys, json
d = json.load(sys.stdin)
idler = [u["id"] for u in d.get("items", [])]
print(",".join("\x27" + i + "\x27" for i in idler) if idler else "\x27\x27")' 2>/dev/null || echo "''")"
    ADET="$(printf %s "$IDLER" | tr ',' '\n' | grep -c "'" || true)"
    echo "    donen kullanici sayisi: $ADET"
    psql_calistir "SELECT '    gorunen kayitlarin tesisleri: ' || coalesce(string_agg(DISTINCT t.ad, ', '), '(yok)') FROM app_user u JOIN tenant t ON t.id = u.tenant_id WHERE u.id::text IN ($IDLER);"
    SAYI="$(psql_calistir "SELECT count(DISTINCT u.tenant_id) FROM app_user u WHERE u.id::text IN ($IDLER);" | tr -d '[:space:]')"
    if [ "$SAYI" = "1" ]; then
      echo "    TAMAM: tek tesis — capraz-tesis sizintisi YOK"
    else
      echo "    !!! KUSUR — donen kayitlar $SAYI FARKLI tesise ait: SIZINTI"
    fi
  fi
else
  echo "    (atlandi) Calistirmak icin KENDI hesabinizla:"
  echo "      SLUG=<tesis-slug> EPOSTA=<eposta> PAROLA=<parola> $0"
  echo "    Parola yalnizca giris icin kullanilir, HICBIR YERE yazilmaz."
fi

echo
echo "=== SONUÇ NASIL OKUNUR ==="
echo "  * 1-3 beklendiği gibi ve 5'te tek tesis çok kullanıcılı  -> VERİ DÜZENİ"
echo "  * 4'te tesis yöneticisi 'admin' görünüyor                -> ROL"
echo "  * 1-3'ten biri beklenenden farklı                        -> GERÇEK SIZINTI"
