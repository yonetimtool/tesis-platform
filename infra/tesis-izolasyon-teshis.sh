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
# Kullanım (sunucuda, infra/ içinde):
#   ./tesis-izolasyon-teshis.sh
set -euo pipefail

COMPOSE="docker compose -f docker-compose.prod.yml --env-file .env.prod"
PSQL="$COMPOSE exec -T db psql -U ${POSTGRES_USER:-tesis_owner} -d ${POSTGRES_DB:-tesis} -A -t"

echo "=== 1) API HANGİ VERİTABANI KULLANICISIYLA BAĞLANIYOR? ==="
echo "    (superuser ya da BYPASSRLS ise TÜM politikalar süstür)"
$COMPOSE exec -T api python - <<'PY'
import re
from app.config import settings
u = settings.database_url
kullanici = re.sub(r"^.*://([^:]+):.*$", r"\1", u)
print(f"    baglanti kullanicisi : {kullanici}")
print(f"    BEKLENEN             : app_rw")
PY

echo
echo "=== 2) UYGULAMA ROLÜ RLS'İ ATLAYABİLİYOR MU? ==="
$PSQL -c "SELECT '    app_rw superuser=' || rolsuper || '  bypassrls=' || rolbypassrls
          FROM pg_roles WHERE rolname='app_rw';"
echo "    BEKLENEN: ikisi de f"

echo
echo "=== 3) RLS HER TENANT TABLOSUNDA AÇIK VE ZORLANMIŞ MI? ==="
$PSQL -c "
SELECT '    KORUMASIZ: ' || c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN information_schema.columns col
  ON col.table_name=c.relname AND col.table_schema='public'
WHERE n.nspname='public' AND c.relkind='r' AND col.column_name='tenant_id'
  AND NOT (c.relrowsecurity AND c.relforcerowsecurity);"
echo "    BEKLENEN: hiç satır yok"

echo
echo "=== 4) PLATFORM ROLÜNDE (admin) KAÇ HESAP VAR? ==="
echo "    (yalnız platform sahibi olmalı; bir tesis yöneticisi burada"
echo "     görünüyorsa panel konsolunu açabilir — 3. neden budur)"
$PSQL -c "
SELECT '    ' || u.email || '   tesis=' || t.ad
FROM app_user u JOIN tenant t ON t.id=u.tenant_id
WHERE u.role='admin' AND u.is_active;"

echo
echo "=== 5) KULLANICILAR TESİSLERE NASIL DAĞILMIŞ? ==="
echo "    (şikâyet edilen ekranda görünen kişiler TEK tenant'ta ise"
echo "     sızıntı YOKTUR — 2. neden budur: kayıtlar yanlış tesiste)"
$PSQL -c "
SELECT '    ' || t.ad || '  (' || t.slug || ')  kullanici=' || count(u.id)
FROM tenant t LEFT JOIN app_user u ON u.tenant_id=t.id
GROUP BY t.id, t.ad, t.slug HAVING count(u.id) > 1
ORDER BY count(u.id) DESC LIMIT 20;"

echo
echo "=== 6) CANLI ÇAPRAZ-TESİS DENEMESİ ==="
echo "    Aşağıdakini kendi hesabınızla çalıştırın; dönen tenant SAYISI 1"
echo "    olmalıdır (kendi tesisiniz):"
cat <<'IPUCU'
      TOKEN=$(curl -s -X POST https://api.yonetiyor.com/auth/login \
        -H 'Content-Type: application/json' \
        -d '{"tenant_slug":"<SLUG>","email":"<EPOSTA>","password":"<PAROLA>"}' \
        | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
      curl -s https://api.yonetiyor.com/users?limit=200 \
        -H "Authorization: Bearer $TOKEN" > /tmp/liste.json
      # Dönen kullanıcıların kaç FARKLI tesise ait olduğunu say:
      #   (id'leri veritabanında kontrol et)
IPUCU

echo
echo "=== SONUÇ NASIL OKUNUR ==="
echo "  * 1-3 beklendiği gibi ve 5'te tek tesis çok kullanıcılı  -> VERİ DÜZENİ"
echo "  * 4'te tesis yöneticisi 'admin' görünüyor                -> ROL"
echo "  * 1-3'ten biri beklenenden farklı                        -> GERÇEK SIZINTI"
