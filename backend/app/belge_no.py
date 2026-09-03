"""(P167 Asama 4) MERKEZI BELGE NUMARASI — tek uretim yeri.

Brief'in zorunlu ilkesi: "Belge numaralandirma MERKEZI olsun, her modul
kendi numarasini uretmesin."

BU MODUL O TEK YERDIR. `finans.py`, `borclandirma_uc.py` ve ileride
eklenecek her modul numarayi BURADAN ister; kendi bicimini uydurmaz.

===========================================================================
BICIM: <ON EK>-<YIL>-<ALTI HANE>
===========================================================================
    TAH-2026-000123     tahsilat
    GID-2026-000045     gider

UC PARCA, UCU DE BIR SORUYU CEVAPLIYOR:
  * ON EK — "bu ne belgesi?" Ekstre ve rapor ciktilarinda tur, satiri
    acmadan okunur.
  * YIL   — seri YILLIK (Turkiye'de fis numaralari boyle tutulur) ve yil
    numaranin icinde olmazsa iki farkli yilin 123'u ayirt edilemez.
  * ALTI HANE — sifirla doldurulmus. Metin siralamasi SAYI siralamasiyla
    ayni olsun diye: "TAH-2026-9" ile "TAH-2026-10" alfabetik siralamada
    ters duserdi ve ekstreler yanlis sirada cikardi. Alti hane bir tesis
    icin bir yilda 999.999 belgeye yeter; asilirsa numara uzar (kesilmez).

===========================================================================
KULLANICI KENDI NUMARASINI YAZABILIR
===========================================================================
Brief'in gider/gelir modallarinda "Belge No" alani var. Kullanici bir sey
yazdiysa O KULLANILIR — merkezi uretim, kullanicinin elindeki gercek
faturanin numarasini yazmasini engellemek icin degil, BOS BIRAKILDIGINDA
tutarli bir seri uretmek icindir.

Benzersizligi veritabani kisiti (`uq_hareket_belge_no`) korur: kullanici
elle var olan bir numarayi yazarsa istek 409 ile reddedilir — sessizce
ikinci bir kopya olusmaz.
"""
from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .errors import APIError

#: Belge turu -> on ek. Kume BURADA kapali: veritabani `tip` sutununu
#: serbest metin tutuyor (yeni tur eklemek `ALTER TYPE` gerektirmesin) ama
#: uygulamanin tanidigi turler sinirli olmali — yoksa bir yazim hatasi
#: sessizce YENI bir seri baslatirdi.
ON_EKLER: dict[str, str] = {
    "tahsilat": "TAH",
    "gider": "GID",
    "gelir": "GEL",
    "virman": "VIR",
    "iade": "IAD",
    "acilis": "ACL",
    "borclandirma": "BRC",
    # Iptal (ters kayit) KENDI SERISINI kullanir: iptal edilen belgeyle
    # ayni numarayi tasisaydi defterde iki satir ayni belgeye isaret eder
    # ve "hangisi gecerli" sorusu numaradan cevaplanamazdi.
    "iptal": "IPT",
    # (P167 §6.2) KARAR DEFTERI. Brief karar numarasini ZORUNLU alan
    # olarak isaretlemiyor ("Konu*" yildizli, "No" degil) — yani numarayi
    # kullanicidan beklemek yerine URETMEK gerekiyor.
    #
    # Ayri bir sayac YAZILMADI: Asama 4'un zorunlu ilkesi "belge
    # numaralandirma MERKEZI olsun, her modul kendi numarasini
    # uretmesin". Karar defteri de bir belge serisidir; kendi sayacini
    # acsaydik, yil donumu sifirlamasi ve islem-geri-alma davranisi iki
    # ayri yerde yasar ve biri gunun birinde otekinden ayrisirdi.
    "karar": "KRR",
}

#: (P211 §3) SERININ KABUL ETTIGI YIL ARALIGI — `ck_belge_sayaci_yil`
#: (goc 0058) ile AYNI. Burada da olmasi sart: kisitin tek basina durmasi,
#: gecersiz bir tarihin 500 olarak donmesi demekti.
#:
#: OLCULDU: `POST /dues/payments` `odeme_zamani=9999-12-31` ile 500 donuyordu
#: (`CheckViolationError: ck_belge_sayaci_yil`). Kullanicinin yil alanina
#: fazladan bir hane yazmasi, "sunucu hatasi" olarak geri geliyordu.
YIL_ALT, YIL_UST = 2000, 2200

#: En az kac hane. Asilirsa numara uzar — KESILMEZ; kesmek iki farkli
#: belgeye ayni numarayi vermek olurdu.
_HANE = 6


class BilinmeyenBelgeTuru(ValueError):
    """Kod hatasi — kullanici girdisiyle olusmaz."""


async def belge_no_uret(
    db: AsyncSession,
    tenant_id: uuid.UUID,
    tip: str,
    tarih: date | None = None,
) -> str:
    """Sirada bir sonraki belge numarasini uret ve DON.

    ATOMIK VE KILITSIZ: artirma tek `INSERT ... ON CONFLICT DO UPDATE`
    ifadesiyle yapiliyor. "Once SELECT sonra UPDATE" yazsaydik iki es
    zamanli fis AYNI numarayi alabilirdi — ve bu ancak aylar sonra bir
    mutabakatta fark edilirdi.

    ISLEME BAGLI: cagiran islem geri alinirsa numara da geri alinir, yani
    seride bosluk kalmaz. (Postgres `SEQUENCE` bunu YAPMAZ; sayaci tablo
    olarak tutmanin sebeplerinden biri de budur — bkz. goc 0058.)

    `tarih` VERILIRSE ONUN YILI kullanilir, bugunun degil: gecmis tarihli
    bir fis girildiginde numara o yilin serisine ait olmali. Aksi halde
    2026 defterine 2027 numarali bir belge duserdi.
    """
    onek = ON_EKLER.get(tip)
    if onek is None:
        raise BilinmeyenBelgeTuru(tip)
    yil = (tarih or date.today()).year
    if not YIL_ALT <= yil <= YIL_UST:
        # ANLASILIR 422: kisit veritabaninda zaten var, ama oraya varmadan
        # once soylenmeli. TEK YERDE: belge numarasi alan HER akis (tahsilat,
        # gider, virman, iade, karar defteri...) ayni kapidan geciyor.
        raise APIError(
            422, "validation_error", "belge_yili_araligi_disi",
            yil=yil, alt=YIL_ALT, ust=YIL_UST,
        )

    sonuc = await db.execute(
        text(
            """
            INSERT INTO belge_sayaci (tenant_id, tip, yil, son_no)
            VALUES (:tenant_id, :tip, :yil, 1)
            ON CONFLICT (tenant_id, tip, yil)
            DO UPDATE SET son_no = belge_sayaci.son_no + 1,
                          updated_at = now()
            RETURNING son_no
            """
        ),
        {"tenant_id": str(tenant_id), "tip": tip, "yil": yil},
    )
    sira = int(sonuc.scalar_one())
    return f"{onek}-{yil}-{sira:0{_HANE}d}"


async def belge_no_ata(
    db: AsyncSession,
    tenant_id: uuid.UUID,
    tip: str,
    mevcut: str | None,
    tarih: date | None = None,
) -> str:
    """Kullanicinin yazdigi numarayi KORU, yoksa merkezi seriden uret.

    Merkezi uretimin amaci kullaniciyi engellemek degil; elinde gercek bir
    fatura numarasi olan kisi onu yazabilmeli. Bos birakildiginda ise
    numara UYDURULMAZ, seriden alinir.

    BOSLUK "yazilmis" SAYILMAZ: `"   "` gibi bir deger, kullanicinin bir
    sey yazdigini degil alani yanlislikla tikladigini gosterir.
    """
    temiz = (mevcut or "").strip()
    if temiz:
        return temiz
    return await belge_no_uret(db, tenant_id, tip, tarih)
