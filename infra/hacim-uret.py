#!/usr/bin/env python3
"""HACIM URETICI — semadan turetilen sentetik veri (tur 78).

NEDEN: tur 77'nin tarama olcumu YALNIZ 8 tabloya hacim yaziyordu
(`hacim-verisi.sql`, elle yazili). Kalan ~40 tablo BOS kaldigi icin onlarin
uzerinden gecen uclarda "bulgu yok" sonucu KANIT DEGILDI — bos tabloda tam
tarama 0 satir okur ve olcum sessiz kalir.

Bu betik semayi KENDISI okur ve eksik tablolar icin INSERT uretir:
  * FK bagimliliklarina gore TOPOLOJIK siralar (ebeveyn once),
  * FK kolonlarina ebeveyn id'lerinden deger secer (dizi indeksiyle — satir
    basina alt sorgu O(N*M) olurdu),
  * enum kolonlarina gercek etiketleri, zaman kolonlarina ACIKCA dagitilmis
    damgalar yazar (kolon varsayilanini `now()` kullanmak tek ifadedeki TUM
    satirlara ayni damgayi verir; tur 77'de 50 bin satir ayni `odeme_zamani`i
    paylasip olcumu bozmustu),
  * `ON CONFLICT DO NOTHING` kullanir — bilesik TEKILLIK kisitlari yuzunden
    istenen satir sayisina ulasilamayabilir ve bu bir hata DEGILDIR,
  * "bitis/cikis/son" tipi zaman kolonlarina "baslangic/giris"tan SONRAKI bir
    damga yazar (`ck_etkinlik_bitis` gibi CHECK kisitlari bunu ister).

SINIR: rastgele CHECK kisitlarini genel bir uretici SAGLAYAMAZ. Bu yuzden
uretilen dosya `ON_ERROR_STOP` KULLANMAZ; kisiti karsilanamayan tablo ATLANIR
ve `tarama-olcumu.sh` atlananlari LISTELER. "Bulgu yok" o tablolar icin kanit
DEGILDIR — sessiz kalmasin diye acikca yazilir.

Cikti stdout'a yazilir; `infra/tarama-olcumu.sh` bunu `hacim-verisi.sql`den
SONRA yukler.

KULLANIM (konteyner disindan):
    cd infra && python3 hacim-uret.py > hacim-verisi-ek.sql
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

INFRA = Path(__file__).resolve().parent
DB = os.environ.get("OLCUM_DB", "hacim")
ADET = int(os.environ.get("HACIM_ADET", "20000"))
TENANT = "11111111-1111-1111-1111-111111111111"

#: Elle yazilan temel dosyanin doldurdugu tablolar — tekrar doldurulmaz.
TEMEL = set(
    re.findall(r"INSERT INTO (\w+)", (INFRA / "hacim-verisi.sql").read_text("utf-8"))
)

#: Hicbir kosulda doldurulmayanlar (gerekce ile).
ATLA = {
    # Alembic'in kendi tablosu.
    "alembic_version",
    # KVKK: append-only denetim kaydi; hacim TEMEL dosyada zaten var.
    "audit_log",
    # tenant/app_user/unit/checkpoint TEMEL dosyada kuruluyor (referans veri).
    "tenant",
}


def psql(sql: str) -> str:
    r = subprocess.run(
        ["docker", "compose", "exec", "-T", "db", "psql", "-U",
         os.environ["POSTGRES_USER"], "-d", DB, "-Atc", sql],
        capture_output=True, text=True, cwd=INFRA,
    )
    if r.returncode != 0:
        sys.exit(f"psql hatasi: {r.stderr[:400]}")
    return r.stdout


def satirlar(sql: str) -> list[list[str]]:
    return [s.split("\t") for s in psql(sql).strip().splitlines() if s]


# --------------------------------------------------------------------------- #
tablolar = [t[0] for t in satirlar(
    "select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace "
    "where n.nspname='public' and c.relkind='r' order by c.relname"
)]

kolonlar: dict[str, list[tuple[str, str, str, str, str]]] = {}
for t in tablolar:
    kolonlar[t] = [
        (r[0], r[1], r[2], r[3], r[4])
        for r in satirlar(
            "select column_name||chr(9)||data_type||chr(9)||is_nullable||chr(9)||"
            f"coalesce(column_default,'')||chr(9)||udt_name from "
            f"information_schema.columns where table_schema='public' "
            f"and table_name='{t}' order by ordinal_position"
        )
    ]

# FK: (tablo, kolon) -> (ebeveyn_tablo, ebeveyn_kolon)
#
# `information_schema.constraint_column_usage` KULLANILMAZ: bilesik FK'larda
# kolon CIFTLESMESINI korumaz. `(olusturan_user_id, tenant_id) REFERENCES
# app_user(id, tenant_id)` kisitinda adla eslestirmek `tenant_id`yi
# `app_user.tenant_id`ye, `olusturan_user_id`yi de HICBIR SEYE baglar (ilk
# uretimde tam olarak bu oldu: FK kolonuna `gen_random_uuid()` yazildi).
# Dogru esleme `pg_constraint.conkey`/`confkey` SIRALARINDAN gelir.
fk: dict[tuple[str, str], tuple[str, str]] = {}
for r in satirlar(
    "select c.conrelid::regclass::text||chr(9)||a.attname||chr(9)||"
    "c.confrelid::regclass::text||chr(9)||fa.attname "
    "from pg_constraint c "
    "join pg_namespace n on n.oid=c.connamespace "
    "join unnest(c.conkey) with ordinality k(attnum, ord) on true "
    "join unnest(c.confkey) with ordinality fk_(attnum, ord) on fk_.ord=k.ord "
    "join pg_attribute a on a.attrelid=c.conrelid and a.attnum=k.attnum "
    "join pg_attribute fa on fa.attrelid=c.confrelid and fa.attnum=fk_.attnum "
    "where c.contype='f' and n.nspname='public'"
):
    fk[(r[0], r[1])] = (r[2], r[3])

enumlar: dict[str, list[str]] = {}
for r in satirlar(
    "select t.typname||chr(9)||string_agg(e.enumlabel,',' order by e.enumsortorder) "
    "from pg_type t join pg_enum e on e.enumtypid=t.oid "
    "join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' "
    "group by t.typname"
):
    enumlar[r[0]] = r[1].split(",")


def bagimliliklar(t: str) -> set[str]:
    return {p for (tt, _c), (p, _pc) in fk.items() if tt == t and p != t}


# Topolojik sira (ebeveyn once). Dongu olursa kalanlar sona eklenir.
sirali: list[str] = []
kalan = [t for t in tablolar if t not in ATLA]
while kalan:
    hazir = [t for t in kalan if bagimliliklar(t) <= set(sirali) | TEMEL | ATLA]
    if not hazir:
        sirali.extend(kalan)
        break
    sirali.extend(sorted(hazir))
    kalan = [t for t in kalan if t not in hazir]


#: "bitis" anlamli kolon adlari — CHECK kisitlari bunlarin "baslangic"tan
#: SONRA olmasini ister (orn. `ck_etkinlik_bitis`).
_SON_EKLER = ("bitis", "cikis", "son", "teslim", "tamamlanma", "kapanis")


#: ALAN-OZEL ipuclari. Genel uretici bir CHECK kisitini "cozemez"; kisitin
#: bekledigi degeri BILMEK gerekir. Bunlar olcum ilk kosumunda tek tek
#: bulundu (ck_*_ceviri_dil, ck_vehicle_pass_plaka).
_IPUCU = {
    # Ceviri tablolarinda dil, mobil UI'nin 7 dilinden biri olmali.
    "dil": "(ARRAY['tr','en','ar','ru','de','fr','es'])[1 + g % 7]",
    "kaynak_dil": "'tr'",
    # Plaka formati: 2 hane + 1-3 harf + 2-4 hane.
    "plaka": "'34'||chr(65 + g % 26)||chr(65 + (g/26)::int % 26)||lpad((g % 9999)::text,4,'0')",
}


def _zaman(ad: str) -> str:
    temel = "now() - (g || ' minutes')::interval"
    if any(x in ad for x in _SON_EKLER):
        return f"({temel} + interval '1 hour')"
    return temel


def ifade(t: str, kolon: tuple[str, str, str, str, str], ctes: dict[str, str]) -> str | None:
    ad, tip, nullable, varsayilan, udt = kolon
    # tenant_id HER ZAMAN sabit tenant: olcum tek kiracilidir ve bilesik
    # FK'larda ebeveyn satirinin tenant'i ile UYUSMAK zorundadir.
    if ad == "tenant_id":
        return f"'{TENANT}'"
    if ad in _IPUCU:
        return _IPUCU[ad]
    if (t, ad) in fk:
        ptab, pcol = fk[(t, ad)]
        if ptab == "tenant":
            return f"'{TENANT}'"
        takma = f"p_{ptab}_{pcol}"
        ctes[takma] = (
            f"{takma} AS (SELECT array_agg({pcol} ORDER BY {pcol}) ids FROM {ptab})"
        )
        return f"{takma}.ids[1 + g % greatest(array_length({takma}.ids,1),1)]"
    if nullable == "YES" or varsayilan:
        # Zaman kolonlari varsayilanli olsa da ACIKCA dagitilir (tur 77 tuzagi).
        if udt in ("timestamptz", "timestamp") and (
            "zaman" in ad or ad.endswith("_at")
        ):
            return _zaman(ad)
        return None
    if udt in enumlar:
        return f"'{enumlar[udt][0]}'::{udt}"
    if udt in ("timestamptz", "timestamp"):
        return _zaman(ad)
    if udt in ("time", "timetz"):
        # `time` kolonlari (vardiya/rezervasyon saatleri). "bitis" anlamli
        # olanlar 2 saat SONRA olmali (ck_rezervasyon_aralik gibi kisitlar).
        saat = "(g % 20)::int"
        if any(x in ad for x in _SON_EKLER):
            return f"make_time({saat} + 2, 0, 0)"
        return f"make_time({saat}, 0, 0)"
    if udt == "date":
        return "(now() - (g || ' days')::interval)::date"
    if udt in ("int2", "int4", "int8", "numeric", "float4", "float8"):
        return "g"
    if udt == "bool":
        return "false"
    if udt == "uuid":
        return "gen_random_uuid()"
    if udt == "jsonb":
        return "'{}'::jsonb"
    return f"'{ad[:8]}-'||g"


print("-- URETILDI: infra/hacim-uret.py (tur 78). ELLE DUZENLEMEYIN.")
print("-- Temel dosyanin doldurdugu tablolar atlanir; kalanlar semadan turetilir.")
# ON_ERROR_STOP KULLANILMAZ: karsilanamayan CHECK kisiti olan tablo ATLANSIN,
# tum yukleme durmasin (bkz. dosya basindaki SINIR notu).
uretilen = 0
for t in sirali:
    if t in TEMEL:
        continue
    ctes: dict[str, str] = {}
    parcalar: list[tuple[str, str]] = []
    for k in kolonlar[t]:
        e = ifade(t, k, ctes)
        if e is not None:
            parcalar.append((k[0], e))
    if not parcalar:
        continue
    cte_sql = ("WITH " + ", ".join(sorted(ctes.values())) + "\n  ") if ctes else ""
    kaynak = ", ".join([f"generate_series(1,{ADET}) g"] + sorted(ctes))
    print(f"\nINSERT INTO {t} ({', '.join(a for a, _ in parcalar)})")
    print(f"  {cte_sql}SELECT {', '.join(e for _, e in parcalar)}")
    print(f"  FROM {kaynak}")
    print("  ON CONFLICT DO NOTHING;")
    uretilen += 1
print("\nANALYZE;")
print(f"-- {uretilen} tablo icin uretildi (hedef {ADET} satir/tablo).",
      file=sys.stderr)
