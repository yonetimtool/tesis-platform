#!/usr/bin/env bash
# CANLI YUZEY DOGRULAMA — depodaki yapilandirma degil, KOSAN dagitim.
#
# NEDEN VAR (P126 sonrasi olay): `app.xn--ynetiyor-n4a.com` gunlerce P120
# yer tutucusunu sundu. Depodaki `Caddyfile` P126.1'den beri DOGRUYDU
# (`app.` -> admin-web), `alan-adi-denetimi.py` yesildi, testler yesildi —
# cunku hepsi DEPOYU olcuyordu. Kacan sey suydu:
#
#   Caddyfile prod'a bir BIND-MOUNT ile giriyor (`./Caddyfile:/etc/caddy/
#   Caddyfile:ro`). `docker compose up -d` bagli dosyanin ICERIGI degisti
#   diye kabi YENIDEN OLUSTURMAZ — servis tanimi ayni kaldigi surece Caddy
#   eski yapilandirmayla calismaya devam eder. Yani `git pull` + `up -d`
#   API'yi ve paneli gunceller, CADDY'i GUNCELLEMEZ.
#
# Bu betik o bosluğu kapatir: konaklara GERCEKTEN istek atar ve her birinin
# beklenen YUZEYI sundugunu dogrular. Kimlik gerektirmez (oturumsuz
# davranis zaten ayirt edici: yer tutucu `/login`de 404 verir, uygulama 200).
#
# KULLANIM:
#   bash infra/canli-yuzey-dogrula.sh                 # genel DNS uzerinden
#   SUNUCU_IP=185.248.57.150 bash infra/...           # DNS yayilmadan once
#                                                      (curl --resolve)
#
# CIKIS KODU: herhangi bir denetim duserse 1.
set -uo pipefail

PORTAL="${PORTAL_DOMAIN:-xn--ynetiyor-n4a.com}"
PORTAL_ESKI="${PORTAL_DOMAIN_ESKI:-yonetio.site}"
PANEL_YENI="${PANEL_DOMAIN_YENI:-panel.$PORTAL}"
PANEL_ESKI="${PANEL_DOMAIN:-panel.$PORTAL_ESKI}"
API="${API_DOMAIN:-api.$PORTAL_ESKI}"
SUNUCU_IP="${SUNUCU_IP:-}"

hata=0
gecen=0

# curl'u tek yerde kur: `--resolve` YALNIZ SUNUCU_IP verildiginde eklenir.
# Boylece ayni betik hem DNS yayildiktan sonra hem de sunucunun kendi
# uzerinden (DNS'i beklemeden) kosabilir.
iste() { # iste <konak> <yol> [-I]
	local konak="$1" yol="$2"
	local -a ek=()
	[ -n "$SUNUCU_IP" ] && ek=(--resolve "$konak:443:$SUNUCU_IP")
	curl -s --max-time 15 "${ek[@]}" "https://$konak$yol" "${@:3}"
}

durum() { # durum <konak> <yol>
	local konak="$1" yol="$2"
	local -a ek=()
	[ -n "$SUNUCU_IP" ] && ek=(--resolve "$konak:443:$SUNUCU_IP")
	curl -s -o /dev/null --max-time 15 "${ek[@]}" \
		-w "%{http_code} %{redirect_url}" "https://$konak$yol"
}

denetle() { # denetle <ad> <beklenen> <gercek>
	local ad="$1" beklenen="$2" gercek="$3"
	if [[ "$gercek" == *"$beklenen"* ]]; then
		printf 'OK   %-52s %s\n' "$ad" "$gercek"
		gecen=$((gecen + 1))
	else
		printf 'HATA %-52s beklenen:%s  gercek:%s\n' "$ad" "$beklenen" "$gercek"
		hata=$((hata + 1))
	fi
}

echo "== KOSAN DAGITIM (${SUNUCU_IP:-genel DNS})"

# --- app.* : TESIS CALISMA ALANI ----------------------------------------- #
# `/login` AYIRT EDICIDIR: yer tutucu bir `file_server`dir ve olmayan yol
# icin 404 doner; uygulama giris sayfasini 200 ile cizer.
denetle "app.$PORTAL /login" "200" "$(durum "app.$PORTAL" /login)"
# Govde de olculur: 200 tek basina yetmez — her yolu index'e dusuren bir
# catch-all da 200 dondururdu. Next.js sayfasi `_next` varliklarina baglidir.
denetle "app.$PORTAL /login govde" "_next" \
	"$(iste "app.$PORTAL" /login | grep -o '_next' | head -1)"
# Oturumsuz kok: middleware `/login`e yollar (307). Yer tutucu 200 verirdi.
denetle "app.$PORTAL / (oturumsuz)" "307" "$(durum "app.$PORTAL" /)"
# YER TUTUCU GITTI MI: P120 sayfasinin basligi hicbir yerde gorunmemeli.
denetle "app.$PORTAL yer tutucu YOK" "yok" \
	"$(iste "app.$PORTAL" / | grep -q 'yakında' && echo VAR || echo yok)"

# --- panel.* : PLATFORM YUZEYI (P125) ------------------------------------ #
for p in "$PANEL_YENI" "$PANEL_ESKI"; do
	denetle "$p / (oturumsuz)" "/login" "$(durum "$p" /)"
	denetle "$p /login" "200" "$(durum "$p" /login)"
	# TESIS rotasi PANELDE de once oturum kapisina takilir; oturum varken
	# yuzey kapisi devreye girer (bkz. admin-web/tests/middleware.test.ts).
	# Oturumsuz olcum yine de degerli: sayfa CIZILMEDEN kesiliyor mu?
	denetle "$p /dues -> login" "/login" "$(durum "$p" /dues)"
done

# --- kok + www : TANITIM SAYFASI ----------------------------------------- #
for k in "$PORTAL" "www.$PORTAL" "$PORTAL_ESKI" "www.$PORTAL_ESKI"; do
	denetle "$k /" "200" "$(durum "$k" /)"
	# Hukuki sayfalar UYGULAMADAN gelir (tek kaynak) — statik kopyadan degil.
	denetle "$k /gizlilik" "200" "$(durum "$k" /gizlilik)"
	# Bilinmeyen yol 404 OLMALI: her yola 200 donen bir kok, App Store
	# incelemesinde "park sayfasi" olarak gorunur (P120'de yasandi).
	denetle "$k /olmayan-yol" "404" "$(durum "$k" /olmayan-yol)"
done

# --- api.* : SEMA UYUMU --------------------------------------------------- #
# `/health` semanin beklenen goc basiyla ayni olup olmadigini soyler. Prod'a
# `migrate` kosulmadan `api` dagitildiginda bu alan `false` doner (P124'te
# tam olarak bu yasandi) — dagitim sonrasi bakilacak ilk yer burasidir.
denetle "$API /health" "200" "$(durum "$API" /health)"
denetle "$API /health sema uyumlu" '"uyumlu":true' \
	"$(iste "$API" /health | tr -d ' ')"

echo
if [ "$hata" -eq 0 ]; then
	echo "TUMU GECTI ($gecen denetim)"
else
	echo "$hata DENETIM DUSTU ($gecen gecti)"
	echo
	echo "EN SIK SEBEP: Caddy eski yapilandirmayla kosuyor. Caddyfile bir"
	echo "bind-mount'tur ve \`up -d\` onu YENIDEN YUKLEMEZ. Sunucuda:"
	echo "  cd ~/tesis-platform/infra && git -C .. pull"
	echo "  docker compose -f docker-compose.prod.yml --env-file .env.prod \\"
	echo "      exec caddy caddy reload --config /etc/caddy/Caddyfile"
fi
exit $((hata > 0))
