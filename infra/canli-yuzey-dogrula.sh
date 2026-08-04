#!/usr/bin/env bash
# CANLI YUZEY DOGRULAMA — depodaki yapilandirma degil, KOSAN dagitim.
#
# NEDEN VAR (P126 sonrasi olay): `app.yönetiyor.com` gunlerce once P120 yer
# tutucusunu, sonra da CIPLAK 404 sundu. Depodaki `Caddyfile` P126.1'den beri
# DOGRUYDU (`app.` -> admin-web), `alan-adi-denetimi.py` yesildi, testler
# yesildi — hepsi DEPOYU olcuyordu. Kimse KOSAN yapilandirmayi olcmuyordu.
#
# NEREDEN KOSULUR — VARSAYILAN 127.0.0.1 (SUNUCUNUN KENDISI):
#   Genel IP'ye disaridan degil de AG ICINDEN gidildiginde pfSense
#   hairpin'i istegi ALAKASIZ bir nginx'e dusurebiliyor. O nginx bizim
#   yiginimiz degildir; ondan gelen 404'leri "altyapi bozuk" diye okumak
#   YANLIS TESHIS uretir (bir kez uretti: 23 sahte basarisizlik). Bu yuzden
#   olcum varsayilan olarak KABIN ICINDEN/SUNUCUDAN, 127.0.0.1 uzerinden
#   yapilir; disaridan olcum ACIKCA istenmelidir.
#
# KULLANIM:
#   bash infra/canli-yuzey-dogrula.sh                 # sunucuda: 127.0.0.1
#   HEDEF=dns bash infra/canli-yuzey-dogrula.sh       # genel DNS uzerinden
#   HEDEF=185.248.57.150 bash infra/...               # belirli bir IP
#   HEDEF_PORT=8443 bash infra/...                    # yerel Caddy denemesi
#
# CIKIS KODU: herhangi bir denetim duserse 1.
set -uo pipefail

PORTAL="${PORTAL_DOMAIN:-xn--ynetiyor-n4a.com}"
PORTAL_ESKI="${PORTAL_DOMAIN_ESKI:-yonetio.site}"
PANEL_YENI="${PANEL_DOMAIN_YENI:-panel.$PORTAL}"
PANEL_ESKI="${PANEL_DOMAIN:-panel.$PORTAL_ESKI}"
API="${API_DOMAIN:-api.$PORTAL_ESKI}"
HEDEF="${HEDEF:-127.0.0.1}"
HEDEF_PORT="${HEDEF_PORT:-443}"

hata=0
gecen=0

# `--resolve` konagi HEDEF'e sabitler; `HEDEF=dns` ise cozumleme DNS'e birakilir.
kur_curl() { # kur_curl <konak>
	CURL_EK=()
	[ "$HEDEF" != "dns" ] && CURL_EK=(--resolve "$1:$HEDEF_PORT:$HEDEF")
	# Yerel deneme (local_certs) icin sertifika dogrulamasi kapatilir; 443'te
	# ACIK BIRAKILIR — gecersiz sertifika gercek bir arizadir.
	[ "$HEDEF_PORT" != "443" ] && CURL_EK+=(-k)
}

adres() { printf 'https://%s%s%s' "$1" "$([ "$HEDEF_PORT" = 443 ] || echo ":$HEDEF_PORT")" "$2"; }

durum() { # durum <konak> <yol>
	kur_curl "$1"
	curl -s -o /dev/null --max-time 15 "${CURL_EK[@]}" \
		-w "%{http_code} %{redirect_url}" "$(adres "$1" "$2")"
}

basliklar() { # basliklar <konak> <yol>
	kur_curl "$1"
	curl -sI --max-time 15 "${CURL_EK[@]}" "$(adres "$1" "$2")" |
		tr -d '\r' | tr 'A-Z' 'a-z'
}

denetle() { # denetle <ad> <beklenen> <gercek>
	local ad="$1" beklenen="$2" gercek="$3"
	if [[ "$gercek" == *"$beklenen"* ]]; then
		printf 'OK   %-50s %s\n' "$ad" "${gercek:0:60}"
		gecen=$((gecen + 1))
	else
		printf 'HATA %-50s beklenen:%s  gercek:%s\n' "$ad" "$beklenen" "${gercek:0:80}"
		hata=$((hata + 1))
	fi
}

# --- TESHIS: cevabi KIM verdi? -------------------------------------------- #
# Uc ayirt edici imza var ve ucu de FARKLI bir arizaya isaret eder:
#
#  1. `x-powered-by: next.js` -> istek admin-web'e ULASTI (vekil calisiyor).
#  2. `server: caddy` + `x-frame-options` VAR ama `strict-transport-security`
#     YOK -> cevabi Caddy KENDISI uretti (file_server 404). Caddy, ic hata
#     yanitlarinda `header {...}` blogunu (snippet) uygulamaz ama tek satirlik
#     `header`i uygular; bu imza YEREL OLARAK URETILIP DOGRULANDI. Anlami:
#     app.* icin hâlâ YER TUTUCU/`file_server` blogu kosuyor = ESKI YAPILANDIRMA.
#  3. Hicbiri yok / `server: nginx` -> cevap BIZIM Caddy'mizden gelmiyor
#     (ag ici hairpin baska bir sunucuya dusuyor). Bu bir DAGITIM arizasi
#     DEGILDIR; olcumun yeri yanlistir.
teshis() { # teshis <konak> <yol>
	local b
	b="$(basliklar "$1" "$2")"
	if [[ "$b" == *"x-powered-by: next.js"* ]]; then
		echo "admin-web"
	elif [[ "$b" == *"server: caddy"* && "$b" != *"strict-transport-security"* ]]; then
		echo "caddy-kendisi(ESKI-YAPILANDIRMA-IMZASI)"
	elif [[ "$b" == *"server: caddy"* || "$b" == *"via: 1.1 caddy"* ]]; then
		echo "caddy(vekil)"
	elif [[ -z "$b" ]]; then
		echo "YANIT-YOK"
	else
		echo "BIZIM-DEGIL($(printf '%s' "$b" | sed -n 's/^server: //p' | head -1))"
	fi
}

echo "== KOSAN DAGITIM  hedef=$HEDEF port=$HEDEF_PORT"
echo

# --- app.* : TESIS CALISMA ALANI ----------------------------------------- #
# EN AYIRT EDICI OLCUM BASLIKTIR, DURUM KODU DEGIL: yer tutucu da 200
# dondurebilir (P120'de donduruyordu), Next.js 404 da 404'tur. "Istek
# admin-web'e ULASTI mi" sorusunu yalniz `x-powered-by` yanitlar.
denetle "app.$PORTAL /login KIME gidiyor" "admin-web" "$(teshis "app.$PORTAL" /login)"
denetle "app.$PORTAL /login" "200" "$(durum "app.$PORTAL" /login)"
# Oturumsuz kok: middleware `/login`e yollar. BU KAPI CADDY'DE DEGIL
# UYGULAMADADIR ve oyle kalmali: oturumu olan bir kullanici `/` ye
# geldiginde kendi rolunun baslangicina gider (`/aidatim`, `/ziyaretciler`...).
# Caddy'ye sabit bir `/login` yonlendirmesi koymak, oturumlu kullaniciyi da
# giris ekranina atardi — calisan bir akisi kirmak olurdu.
denetle "app.$PORTAL / -> /login (oturumsuz)" "/login" "$(durum "app.$PORTAL" /)"

# --- panel.* : PLATFORM YUZEYI (P125) ------------------------------------ #
for p in "$PANEL_YENI" "$PANEL_ESKI"; do
	denetle "$p /login KIME gidiyor" "admin-web" "$(teshis "$p" /login)"
	denetle "$p / (oturumsuz)" "/login" "$(durum "$p" /)"
	denetle "$p /login" "200" "$(durum "$p" /login)"
	denetle "$p /dues -> login" "/login" "$(durum "$p" /dues)"
done

# --- kok + www : TANITIM SAYFASI ----------------------------------------- #
for k in "$PORTAL" "www.$PORTAL" "$PORTAL_ESKI" "www.$PORTAL_ESKI"; do
	denetle "$k /" "200" "$(durum "$k" /)"
	# Hukuki sayfalar UYGULAMADAN gelir (tek kaynak), statik kopyadan degil.
	denetle "$k /gizlilik KIME gidiyor" "admin-web" "$(teshis "$k" /gizlilik)"
	# Bilinmeyen yol 404 OLMALI: her yola 200 donen bir kok, App Store
	# incelemesinde "park sayfasi" olarak gorunur (P120'de yasandi).
	denetle "$k /olmayan-yol" "404" "$(durum "$k" /olmayan-yol)"
done

# --- api.* : SEMA UYUMU --------------------------------------------------- #
# `migrate` kosulmadan `api` dagitildiginda bu alan `false` doner (P124).
denetle "$API /health" "200" "$(durum "$API" /health)"
kur_curl "$API"
denetle "$API /health sema uyumlu" '"uyumlu":true' \
	"$(curl -s --max-time 15 "${CURL_EK[@]}" "$(adres "$API" /health)" | tr -d ' ')"

echo
if [ "$hata" -eq 0 ]; then
	echo "TUMU GECTI ($gecen denetim)"
	exit 0
fi

echo "$hata DENETIM DUSTU ($gecen gecti)"
echo
if [ "$HEDEF" != "127.0.0.1" ]; then
	echo "ONCE OLCUMUN YERINI SORGULA: hedef $HEDEF. Ag ici hairpin genel IP'yi"
	echo "alakasiz bir sunucuya dusurebiliyor. Sunucuda 127.0.0.1 ile tekrarla."
	echo
fi
cat <<'IPUCU'
"caddy-kendisi(ESKI-YAPILANDIRMA-IMZASI)" gorduyseniz teshis KESINDIR:
Caddy hâlâ eski yapilandirmayla kosuyor (app.* icin file_server blogu).
Caddyfile bir BIND-MOUNT'tur; `up -d` onu YENIDEN YUKLEMEZ. Sunucuda:

  cd /opt/yonetio/tesis-platform && git pull && cd infra
  C="docker compose -f docker-compose.prod.yml --env-file .env.prod"
  $C exec caddy caddy validate --config /etc/caddy/Caddyfile
  $C exec caddy caddy reload   --config /etc/caddy/Caddyfile

Kosan ve bagli yapilandirmayi KARSILASTIRMAK icin: bash infra/caddy-teshis.sh
IPUCU
exit 1
