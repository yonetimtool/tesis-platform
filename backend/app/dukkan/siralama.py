"""(DUKKAN F3) SIRALAMA PUANI — TEK YAZMA YOLU.

===========================================================================
NEDEN SUTUNDA, NEDEN HER OKUMADA HESAPLANMIYOR
===========================================================================
Kategori sayfasinda 20 isletme listelenirken her biri icin yorum toplami
ve yanit hizi hesaplamak N+1 uretir. Sayfa ISR ile onbelleklendigi icin
bu maliyet her yenilemede odenir.

Puan `isletme.siralama_puani` sutununda durur ve BU FONKSIYON TEK YAZMA
YOLUDUR. Ikinci bir yazma yolu acilirsa puan sessizce ayrisir — P192'nin
"tek defter" dersinin buradaki karsiligi.

===========================================================================
FORMUL (docs/dukkan/03-guven-ve-fraud.md §2.2b)
===========================================================================
    yorum_bileseni = (A_ort × A_sayi × 1.0 + B_ort × B_sayi × 0.3)
                     / (A_sayi × 1.0 + B_sayi × 0.3)
    guven_carpani  = min(1, (A_sayi + 0.3 × B_sayi) / 5)

A = DOGRULANMIS yorum (platform uzerinden is), B = DAVETLI yorum.

`0.3`: bir davetli yorum, dogrulanmis bir yorumun UCTE BIRI kadar agirlik
tasir. Sifir yapmak Katman B'yi anlamsiz kilardi (o zaman hic
toplamayalim); bire esitlemek davet kotasini TEK savunma hatti birakirdi.

`guven_carpani` ayri duruyor ve sunu cozuyor: tek bir 5 yildizli yorumu
olan isletme, 40 yorumlu 4,6 ortalamali isletmenin USTUNE CIKMAMALI. Az
sayida yorum ortalamayi yukseltmez, GUVENI dusurur.

===========================================================================
YENI ISLETME BILESENI — "zengin daha zengin" dongusunu kirmak
===========================================================================
Puan yalniz gecmis basariya baglansaydi, yeni bir isletme HIC gorunmeden
olurdu ve arz tarafi buyumezdi. Kucuk ve AZALAN bir yenilik bileseni var:
ilk 30 gunde etkili, sonra sifirlaniyor.

RASTGELELIK KULLANILMADI ve bu bilincli: rastgele bir bilesen, ayni
sorgunun iki cagrisinda FARKLI sira uretir; ISR ile onbelleklenmis bir
sayfada bu "sira degisip duruyor" sikayetine ve sayfalama tutarsizligina
yol acar (bkz. `arama.py` ikincil siralama anahtari notu). Yerine
DETERMINISTIK bir yas fonksiyonu kullaniliyor.
"""
from __future__ import annotations

import uuid

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

#: Davetli yorumun agirlik carpani (Katman B).
B_AGIRLIK = 0.3
#: Guven carpaninin doyum noktasi: bu kadar (agirlikli) yorumda 1.0 olur.
GUVEN_DOYUM = 5
#: Yeni isletme bileseninin omru.
YENILIK_GUN = 30

SQL = text(
    """
    WITH y AS (
        SELECT
          count(*) FILTER (WHERE kaynak = 'platform' AND durum = 'yayinda')
            AS a_sayi,
          COALESCE(avg(puan) FILTER
            (WHERE kaynak = 'platform' AND durum = 'yayinda'), 0) AS a_ort,
          count(*) FILTER (WHERE kaynak = 'davet' AND durum = 'yayinda')
            AS b_sayi,
          COALESCE(avg(puan) FILTER
            (WHERE kaynak = 'davet' AND durum = 'yayinda'), 0) AS b_ort
        FROM yorum WHERE isletme_id = :i
    ),
    p AS (
        SELECT i.id,
               i.dogrulama_seviyesi,
               i.onaylandi_at,
               -- PROFIL EKSIKSIZLIGI: dolu alan orani. Eksiksiz profil
               -- kullaniciya daha cok bilgi verir ve daha iyi bir sonuc
               -- oldugu icin yukari cikmali.
               ( (i.aciklama IS NOT NULL AND btrim(i.aciklama) <> '')::int
               + (i.whatsapp IS NOT NULL)::int
               + (i.adres_mahalle_id IS NOT NULL)::int
               + (EXISTS (SELECT 1 FROM isletme_calisma_saati s
                          WHERE s.isletme_id = i.id))::int
               )::numeric / 4 AS profil,
               (SELECT count(*) FROM isletme_hizmet_alani ha
                 WHERE ha.isletme_id = i.id) AS alan_sayisi
        FROM isletme i WHERE i.id = :i
    )
    UPDATE isletme SET
      ortalama_puan = CASE
          WHEN (SELECT a_sayi + b_sayi FROM y) = 0 THEN NULL
          ELSE ROUND(
            ((SELECT a_ort * a_sayi + b_ort * b_sayi * :b FROM y)
             / NULLIF((SELECT a_sayi + b_sayi * :b FROM y), 0))::numeric, 2)
        END,
      yorum_sayisi = (SELECT a_sayi + b_sayi FROM y),
      siralama_puani = ROUND((
          -- 1) YORUM (0..5 -> 0..50 puan), guven carpaniyla olceklenir.
          COALESCE(
            ((SELECT a_ort * a_sayi + b_ort * b_sayi * :b FROM y)
             / NULLIF((SELECT a_sayi + b_sayi * :b FROM y), 0))
            * LEAST(1.0, (SELECT a_sayi + b_sayi * :b FROM y) / :doyum)
            * 10, 0)
          -- 2) DOGRULAMA SEVIYESI: belge dogrulanmis isletme yukari.
          + (SELECT dogrulama_seviyesi FROM p) * 8
          -- 3) PROFIL EKSIKSIZLIGI (0..10)
          + (SELECT profil FROM p) * 10
          -- 4) HIZMET ALANI GENISLIGI — DOYUMLU (0..5).
          --    Logaritmik degil ama tavanli: 20 mahalle secen ile 400
          --    mahalle secen arasinda fark OLMAMALI, yoksa "her yere
          --    gidiyorum" diyen isletme haksiz avantaj kazanir.
          + LEAST(5.0, (SELECT alan_sayisi FROM p)::numeric / 4)
          -- 5) YENILIK (0..6), 30 gunde DOGRUSAL SONER. Deterministik:
          --    rastgelelik ISR onbellekli sayfada sirayi oynatirdi.
          + GREATEST(0, 6 * (1 - EXTRACT(EPOCH FROM
              (now() - COALESCE((SELECT onaylandi_at FROM p), now())))
              / (:yenilik * 86400.0)))
      )::numeric, 4),
      updated_at = now()
    WHERE id = :i
    """
)


async def siralama_puani_hesapla(db: AsyncSession, isletme_id: uuid.UUID) -> None:
    """Bir isletmenin puanini ve yorum ozetini yeniden hesaplar.

    Doner: None. TEK YAZMA YOLU — `siralama_puani`, `ortalama_puan` ve
    `yorum_sayisi` baska hicbir yerde guncellenmemeli.

    Cagrilma anlari: moderasyon onayi, profil guncellemesi, hizmet alani
    degisikligi, (F5'te) yorum yayina girmesi. Ayrica gecelik toplu
    yeniden hesap `yenilik` bileseninin sonmesini yansitir.
    """
    await db.execute(SQL, {"i": isletme_id, "b": B_AGIRLIK,
                           "doyum": GUVEN_DOYUM, "yenilik": YENILIK_GUN})


async def tum_puanlari_hesapla(db: AsyncSession) -> int:
    """Gorunur tum isletmelerin puanini yeniden hesaplar. Doner: sayi.

    NEDEN GECELIK GEREKLI: `yenilik` bileseni ZAMANA bagli ve kendiliginden
    soner — ama sutunda saklandigi icin yeniden hesaplanmadikca ESKI deger
    kalir. Gecelik is olmasa, 30 gun once onaylanmis bir isletme sonsuza
    dek yenilik puani tasirdi.
    """
    idler = [
        r[0] for r in (
            await db.execute(
                text("SELECT id FROM isletme WHERE durum = 'onayli'")
            )
        ).all()
    ]
    for i in idler:
        await siralama_puani_hesapla(db, i)
    return len(idler)
