#!/usr/bin/env python3
"""(P154 / Asama 5) DAIREDE HER ROLDEN TEK AKTIF HESAP — YAYIN ONCESI KONTROL.

===========================================================================
NICIN VAR
===========================================================================
Goc `0049_daire_rol_tekilligi` `(unit_id, rol_tipi) WHERE bitis IS NULL`
uzerinde benzersiz bir indeks kuruyor: bir dairede en fazla BIR MALIK ve
BIR KIRACI. Ayni rolden iki aktif sakin varsa goc DURUR — bilincli
olarak, cunku sessizce satir atmak veri kaybi olurdu.

MALIK + KIRACI BIRLIKTELIGI IHLAL DEGILDIR ve bu betik onu LISTELEMEZ:
`borclandirma.hedef_sec`in `kiraci_oncelikli` kurali tam olarak o durumu
cozmek icin var.

ROLSUZ (NULL) SATIRLAR: PostgreSQL benzersiz indekste NULL'lari
catistirmaz, yani rolsuz coklu sakin veritabanindan GECER. Uygulama
katmani (`units.daire_rolu_dolu_mu`) onu reddeder; bu betik de bilgi
amaciyla AYRI bir bolumde gosterir — goc onlar yuzunden DURMAZ.

Bu betik AYNI SORGUYU salt okunur kosar. Amaci, "migrate" komutunu
calistirmadan ONCE cevabi ogrenmek: goc sirasinda ogrenmek, yarim kalmis
bir yayin demektir.

UYGULAMA MAKINESINDEN URETIME ERISIM YOK (yalniz 80/443). Bu yuzden
uretimdeki durumu yalnizca ORADA kosulan bu betik gosterebilir.

===========================================================================
KULLANIM
===========================================================================
    # Uretim sunucusunda, compose dizininde:
    docker compose -f docker-compose.prod.yml exec -T api \\
        python /app/../infra/scripts/daire_tek_hesap_onkontrol.py

    # ya da dogrudan bir DSN ile:
    OWNER_DSN='postgresql://...' python daire_tek_hesap_onkontrol.py

Cikis kodu 0 = temiz (goc kosabilir) · 1 = ihlal var · 2 = baglanamadi.

===========================================================================
IHLAL BULUNURSA NE YAPILIR
===========================================================================
HESAP SILINMEZ (kilitli kural 1). Fazla bag KAPATILIR:

    UPDATE unit_resident SET bitis = now()
     WHERE id = '<asagida-listelenen-bag-id>';

Kisi giris yapmaya devam eder; yalnizca o daireye bagli gorunmez.
HANGI bagin kapatilacagi bir VERI karari — bu betik secim YAPMAZ ve
yapmamali: yanlis kisiyi daireden dusurmek, aidatin kime yazilacagini
degistirir.

BAZEN DOGRU DUZELTME KAPATMAK DEGIL ROLU DUZELTMEKTIR: iki "malik"ten
biri gercekte kiraciysa `rol_tipi` guncellemek hem ihlali kaldirir hem
veriyi dogru yapar (seed'de aynen boyle yapildi).
"""
from __future__ import annotations

import os
import sys

#: GOCU DURDURAN ihlal: ayni dairede ayni ROLDEN birden fazla aktif bag.
SORGU = """
SELECT t.ad          AS tesis,
       u.no          AS daire,
       ur.id         AS bag_id,
       au.ad         AS kisi,
       au.telefon    AS telefon,
       ur.rol_tipi   AS rol_tipi,
       ur.created_at AS baglandi
  FROM unit_resident ur
  JOIN unit u    ON u.id = ur.unit_id
  JOIN tenant t  ON t.id = ur.tenant_id
  JOIN app_user au ON au.id = ur.user_id
 WHERE ur.bitis IS NULL
   AND ur.rol_tipi IS NOT NULL
   AND (ur.unit_id, ur.rol_tipi) IN (
        SELECT unit_id, rol_tipi FROM unit_resident
         WHERE bitis IS NULL AND rol_tipi IS NOT NULL
         GROUP BY unit_id, rol_tipi
        HAVING count(*) > 1
   )
 ORDER BY t.ad, u.no, ur.rol_tipi, ur.created_at;
"""

#: GOCU DURDURMAZ ama uygulama katmani reddeder — operator bilsin.
SORGU_ROLSUZ = """
SELECT t.ad, u.no, count(*)
  FROM unit_resident ur
  JOIN unit u   ON u.id = ur.unit_id
  JOIN tenant t ON t.id = ur.tenant_id
 WHERE ur.bitis IS NULL AND ur.rol_tipi IS NULL
 GROUP BY t.ad, u.no
HAVING count(*) > 1
 ORDER BY t.ad, u.no;
"""


def main() -> int:
    dsn = os.getenv("OWNER_DSN")
    if not dsn:
        # Uygulama ayarlarindan tureyen varsayilan: betigin api
        # konteynerinden calistirilmasi en olagan durum.
        try:
            sys.path.insert(0, "/app")
            from app.config import settings  # type: ignore

            dsn = settings.owner_dsn
        except Exception:
            print("OWNER_DSN verilmedi ve app.config okunamadi.", file=sys.stderr)
            return 2

    try:
        import psycopg
    except ImportError:
        print("psycopg kurulu degil.", file=sys.stderr)
        return 2

    # OWNER BAGLANTISI SART: RLS altinda calisan `app_rw`, tenant baglami
    # kurulmadan HICBIR satir gormez ve betik "temiz" derdi — en tehlikeli
    # yanlis cevap.
    try:
        conn = psycopg.connect(dsn, connect_timeout=10)
    except Exception as exc:
        print(f"Veritabanina baglanilamadi: {exc}", file=sys.stderr)
        return 2

    with conn, conn.cursor() as cur:
        cur.execute(SORGU)
        satirlar = cur.fetchall()
        cur.execute(SORGU_ROLSUZ)
        rolsuz = cur.fetchall()

    if rolsuz:
        print("BILGI — rolsuz (rol_tipi NULL) coklu sakin (gocu DURDURMAZ,")
        print("       ama uygulama katmani yeni atamalari reddeder):")
        for tesis, daire, adet in rolsuz:
            print(f"  {tesis} / {daire}: {adet} rolsuz aktif sakin")
        print()

    if not satirlar:
        print("TEMIZ — hicbir dairede AYNI ROLDEN birden fazla aktif hesap yok.")
        print("Goc 0049 kosabilir.")
        return 0

    print(f"IHLAL: {len(satirlar)} bag, ayni rolden coklu hesabi olan dairelerde.\n")
    print(f"{'TESIS':<20} {'DAIRE':<8} {'KISI':<22} {'TELEFON':<15} {'ROL':<8} BAG ID")
    print("-" * 100)
    for tesis, daire, bag_id, kisi, telefon, rol, _ in satirlar:
        print(
            f"{(tesis or '')[:19]:<20} {(daire or '')[:7]:<8} {(kisi or '')[:21]:<22} "
            f"{(telefon or '')[:14]:<15} {(rol or '-')[:7]:<8} {bag_id}"
        )
    print(
        "\nHer daire icin BIRINI birakip digerlerini kapatin:\n"
        "  UPDATE unit_resident SET bitis = now() WHERE id = '<bag-id>';\n"
        "HESAP SILINMEZ — kisi giris yapmaya devam eder."
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
