"""INDEKS KAPSAMI — yabanci anahtarlar indeksli mi? (tur 76)

NEDEN: Postgres bir yabanci anahtar tanimlarken referans EDEN taraf icin
indeks OLUSTURMAZ (referans EDILEN taraf zaten unique olmak zorunda). Indeks
yoksa:
  * ust satir silinince RI tetigi referans eden tabloyu SEQ SCAN eder
    (`delete_tenant` 47 tabloya dokunur),
  * o kolon uzerinden yapilan her join/filtre veri buyudukce dogrusal yavaslar.
Bu, veri kucukken GORUNMEYEN ve buyudukce aniden ortaya cikan bir sinif.

OLCUM SONUCU (0008 semasi, 108 yabanci anahtar):
  * 69'unun kolon KUMESINI tam kapsayan bir indeksi var,
  * 39'unun ONCU kolonunu kapsayan bir indeksi var (hepsi
    `(<x>_id, tenant_id)` bicimi bilesik FK; `(<x>_id)` uzerindeki tek-kolon
    indeks RI sorgusunda KULLANILIR, kalan kolon filtreyle elenir),
  * **0 tanesi indekssiz.**
Yani burada bir kusur YOK; bu dosya durumu KILITLER.

DEGISMEZ: her yabanci anahtar icin, o tablodaki en az bir indeksin ILK kolonu
FK kolonlarindan biri olmali. Yeni bir FK indekssiz eklenirse test kirilir.

TUZAK (tur 76'da tam olarak bu yasandi, kayda geciyor): `pg_index.indkey` bir
`int2vector`'dur ve dizi olarak **0-TABANLIDIR**. `(indkey::int2[])[1:n]`
yazmak ILK kolonu ATLAR. Bu off-by-one ile ilk olcum "108 FK'nin 78'i
indekssiz" dedi — tamamen uydurma bir sayi, ama tamamen makul gorunuyordu.
Yakalanmasinin tek yolu tek bir satiri `pg_indexes` ile ELDE dogrulamak oldu
(`scan_event`'te `ix_scan_tenant ON (tenant_id)` apacik duruyordu). Dogru
dilim: `[0:n-1]`.
"""
from __future__ import annotations

import os

import pytest

#: Bundan az yabanci anahtar gorulurse sorgu bozulmustur ve kontrol BOSA GECER.
TABAN_FK = int(os.getenv("INDEKS_TABAN_FK", "80"))

SORGU = """
SELECT d.tablo,
       d.kolon_ad,
       d.conname,
       d.tam,
       d.onculu
FROM (
  SELECT fk.*,
         EXISTS (SELECT 1 FROM pg_index i
                 WHERE i.indrelid = fk.conrelid
                   AND (SELECT array_agg(k ORDER BY k)
                        FROM unnest((i.indkey::int2[])[0:fk.n - 1]) k) = fk.kume
                ) AS tam,
         EXISTS (SELECT 1 FROM pg_index i
                 WHERE i.indrelid = fk.conrelid
                   AND (i.indkey::int2[])[0] = ANY (fk.conkey)
                ) AS onculu
  FROM (
    SELECT c.conrelid,
           c.conname,
           c.conrelid::regclass::text AS tablo,
           array_length(c.conkey, 1)  AS n,
           c.conkey,
           (SELECT array_agg(k ORDER BY k) FROM unnest(c.conkey) k) AS kume,
           (SELECT string_agg(a.attname, ',' ORDER BY x.ord)
            FROM unnest(c.conkey) WITH ORDINALITY x(attnum, ord)
            JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = x.attnum
           ) AS kolon_ad
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE c.contype = 'f' AND n.nspname = 'public'
  ) fk
) d
ORDER BY d.tablo, d.conname
"""


@pytest.fixture
def fkler(owner_conn):
    return owner_conn.execute(SORGU).fetchall()


def test_fk_sayisi_makul(fkler):
    assert len(fkler) >= TABAN_FK, (
        f"yalniz {len(fkler)} yabanci anahtar goruldu; beklenen en az {TABAN_FK}. "
        f"Sorgu bozulduysa asagidaki kontrol BOSA GECER."
    )


def test_her_fk_en_az_oncu_kolon_indeksine_sahip(fkler):
    indekssiz = [
        f"{tablo}({kolon_ad}) [{conname}]"
        for tablo, kolon_ad, conname, _tam, onculu in fkler
        if not onculu
    ]
    assert not indekssiz, (
        f"{len(indekssiz)} yabanci anahtarin ONCU kolonunu kapsayan indeksi YOK "
        f"— ust satir silinince RI tetigi bu tablolari seq scan eder:\n  "
        + "\n  ".join(indekssiz)
    )


def test_kapsam_dagilimi_kayitli(fkler):
    """Dagilim degistiginde gorunur olsun (kilit degil, gozlem)."""
    tam = sum(1 for *_x, t, _o in fkler if t)
    kismi = sum(1 for *_x, t, o in fkler if not t and o)
    print(f"\n[indeks kapsami] FK={len(fkler)} tam={tam} kismi={kismi} yok={len(fkler) - tam - kismi}")
    # Tam kapsanan FK sayisi DUSMEMELI: bir indeksin silinmesi ya da kolon
    # sirasinin degismesi tam kapsami kismiye cevirebilir ve bu sessiz olurdu.
    assert tam >= 60, f"tam kapsanan FK sayisi {tam}, beklenen >= 60"
