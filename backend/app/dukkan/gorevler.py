"""(DUKKAN F3) ZAMANLANMIS ISLER.

===========================================================================
NEDEN KENDI `_async_calistir` KOPYASI
===========================================================================
Yonetiyor'un `tasks.py`indeki sarmalayici bitiste `app.db.engine`i
dispose ediyor — YONETIYOR havuzunu. Dukkan'in AYRI bir engine'i var
(`dukkan_app` roluyle) ve dispose edilmezse P187'de olculen kusur
BIREBIR tekrarlanir:

  asyncpg baglantilari olusturuldugu event loop'a BAGLIDIR; loop
  kapaninca havuzdaki baglantilar olu loop'a bagli kalir, temiz
  kapatilamaz ve PG'de 'idle in transaction' olarak BIRIKIR.

Prod'da bu 90/100 baglantiyla olculdu. Ayni tuzaga ikinci bir havuzla
yeniden dusmemek icin sarmalayici KOPYALANDI — paylasmak, Yonetiyor
engine'ini dispose edip Dukkan'inkini acik birakmak olurdu.
"""
from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import TypeVar

from ..celery_app import celery_app

_T = TypeVar("_T")


def _dukkan_async_calistir(fabrika: Callable[[], Awaitable[_T]]) -> _T:
    """Async gorevi kendi loop'unda kosar ve DUKKAN engine'ini dispose eder."""
    import asyncio

    from .veritabani import engine

    async def _sar() -> _T:
        try:
            return await fabrika()
        finally:
            await engine.dispose()

    return asyncio.run(_sar())


@celery_app.task(name="dukkan.siralama_yenile")
def siralama_yenile() -> dict:
    """Tum gorunur isletmelerin siralama puanini yeniden hesaplar.

    Doner: {"islenen": n}

    ==================================================================
    NEDEN GECELIK GEREKLI
    ==================================================================
    Formulun `yenilik` bileseni ZAMANA bagli ve kendiliginden soner —
    ama puan bir SUTUNDA saklandigi icin yeniden hesaplanmadikca ESKI
    deger kalir. Bu is olmasa, bir yil once onaylanmis bir isletme
    sonsuza dek "yeni isletme" puani tasirdi ve listenin ustunde
    kalirdi.

    IDEMPOTENT: ayni girdiyle ayni sonucu uretir; daha sik kosmak zarar
    vermez.
    """
    async def _calis() -> int:
        from .siralama import tum_puanlari_hesapla
        from .veritabani import SessionLocal

        async with SessionLocal() as s:
            async with s.begin():
                return await tum_puanlari_hesapla(s)

    return {"islenen": _dukkan_async_calistir(_calis)}


@celery_app.task(name="dukkan.reklam_bakimi")
def reklam_bakimi() -> dict:
    """Suresi bitenleri dusurur, hatirlatma ve yer-acildi bildirimi yollar.

    Doner: {"biten": n, "hatirlatma": n, "yer_acildi": n}

    ==================================================================
    UC IS TEK GOREVDE — VE BU BILINCLI
    ==================================================================
    Ucu de AYNI OLAYIN sonuclari: bir reklamin suresi bitiyor. Ayri
    gorevlere bolseydim, "reklam dustu ama bekleyene haber gitmedi" gibi
    yarim bir durum mumkun olurdu (biri kosar, oteki hata alir). Tek
    islem, tek transaction.

    ==================================================================
    SURESI BITEN REKLAM SILINMEZ
    ==================================================================
    `durum='bitti'` yapilir. Silmek, "gecen ay hangi reklam yayindaydi"
    sorusunu cevapsiz birakirdi — o soru bir faturada ya da itirazda
    sorulur.

    ==================================================================
    OTOMATIK YENILEME YOK — KARAR, EKSIKLIK DEGIL
    ==================================================================
    Sessizce kart cekmek en cok sikayet ureten seydir; ustelik iptal ve
    kismi iade akisi gerektirir. Isletme yenilemeyi KENDI yapar; biz
    yalniz HATIRLATIRIZ (7 gun ve 1 gun kala).

    IDEMPOTENT: hatirlatma `bildirim` tablosunda ayni gun ayni tip icin
    tekrar yazilmaz; yer-acildi bildirimi `bildirildi_at` ile bir kez.
    """
    async def _calis() -> dict:
        from sqlalchemy import text as _text

        from .bildirim import bildir
        from .veritabani import SessionLocal

        sonuc = {"biten": 0, "hatirlatma": 0, "yer_acildi": 0}
        async with SessionLocal() as s:
            async with s.begin():
                # ------------------------------------------------------ #
                # 1. SURESI BITENLER
                # ------------------------------------------------------ #
                bitenler = (
                    await s.execute(
                        _text("UPDATE reklam SET durum='bitti', "
                              " updated_at=now() "
                              "WHERE durum='yayinda' AND bitis <= now() "
                              "RETURNING id, isletme_id")
                    )
                ).mappings().all()
                sonuc["biten"] = len(bitenler)

                # ------------------------------------------------------ #
                # 2. HATIRLATMA — 7 ve 1 gun kala
                # ------------------------------------------------------ #
                # `bildirim` tablosunda AYNI GUN ayni reklam icin kayit
                # varsa tekrar yazilmiyor: gorev gunde birden fazla
                # kosarsa kullanici ayni uyariyi birkac kez almasin.
                yaklasanlar = (
                    await s.execute(
                        _text("""
                            SELECT r.id, r.bitis, r.isletme_id,
                                   i.sahip_kullanici_id, i.ad AS isletme_ad,
                                   (r.bitis::date - now()::date) AS kalan_gun
                            FROM reklam r
                            JOIN isletme i ON i.id = r.isletme_id
                            WHERE r.durum = 'yayinda'
                              AND (r.bitis::date - now()::date) IN (7, 1)
                              AND NOT EXISTS (
                                    SELECT 1 FROM bildirim b
                                     WHERE b.kullanici_id = i.sahip_kullanici_id
                                       AND b.tip = 'dukkan_reklam_bitiyor'
                                       AND b.veri->>'reklam_id' = r.id::text
                                       AND b.created_at::date = now()::date)
                        """)
                    )
                ).mappings().all()
                for r in yaklasanlar:
                    await bildir(
                        s, kullanici_id=r["sahip_kullanici_id"],
                        tip="dukkan_reklam_bitiyor",
                        baslik="Reklamın bitiyor",
                        govde=f"{r['isletme_ad']} reklamı "
                              f"{r['kalan_gun']} gün sonra bitiyor.",
                        # `isletme_id` ZORUNLU: hedef yol onunla
                        # uretiliyor (web `/panel/{id}/reklam`, mobil
                        # panel + sekme). Olmazsa bildirime dokunmak
                        # kullaniciyi isletme SECIMINE dusururdu.
                        veri={"reklam_id": str(r["id"]),
                              "isletme_id": str(r["isletme_id"]),
                              "kalan_gun": int(r["kalan_gun"])},
                    )
                sonuc["hatirlatma"] = len(yaklasanlar)

                # ------------------------------------------------------ #
                # 3. YER ACILDI — bekleme listesine haber
                # ------------------------------------------------------ #
                # SIRAYLA DEGIL, YER ACILAN BOLGEYE gore: bir bolgede yer
                # acildiginda o bolgenin SIRADAKI ILK isletmesine gider.
                # Hepsine gondermek, birinin alacagi tek yer icin
                # herkesi kosturmak olurdu.
                #
                # `bildirildi_at` ile BIR KEZ: haber gonderilen isletme
                # satin almazsa yeri kimse almaz — bu bilincli. Sirayi
                # otomatik kaydirmak, "haberim olmadi" diyen isletmeyi
                # sessizce atlamak demekti. Yer bos kalirsa bir sonraki
                # kosumda ikinci sıradakine gider (asagidaki NOT EXISTS
                # yalniz BILDIRILMEMISLERI aliyor ve ilk sirayi seciyor).
                bekleyenler = (
                    await s.execute(
                        _text("""
                            SELECT DISTINCT ON (bw.kategori_id, bw.kapsam,
                                   COALESCE(bw.mahalle_id, bw.ilce_id, bw.il_id))
                                   bw.id, bw.isletme_id, i.sahip_kullanici_id,
                                   i.ad AS isletme_ad
                            FROM reklam_bekleme bw
                            JOIN isletme i ON i.id = bw.isletme_id
                            WHERE bw.durum = 'bekliyor'
                              AND bw.bildirildi_at IS NULL
                            ORDER BY bw.kategori_id, bw.kapsam,
                                     COALESCE(bw.mahalle_id, bw.ilce_id, bw.il_id),
                                     bw.created_at
                        """)
                    )
                ).mappings().all()

                from .reklam import KAPSAM_SUTUNU, slot_durumu

                acilan = 0
                for b in bekleyenler:
                    kayit = (
                        await s.execute(
                            _text("SELECT kapsam, kategori_id, mahalle_id, "
                                  " ilce_id, il_id FROM reklam_bekleme "
                                  "WHERE id = :i"),
                            {"i": b["id"]},
                        )
                    ).mappings().one()
                    kapsam = kayit["kapsam"]
                    bolge_id = kayit[KAPSAM_SUTUNU[kapsam]]
                    d = await slot_durumu(
                        s, kapsam=kapsam, bolge_id=bolge_id,
                        kategori_id=kayit["kategori_id"])
                    if d["bos"] <= 0:
                        continue
                    await bildir(
                        s, kullanici_id=b["sahip_kullanici_id"],
                        tip="dukkan_reklam_yer_acildi",
                        baslik="Beklediğin bölgede yer açıldı",
                        govde=f"{b['isletme_ad']} için sıraya girdiğin "
                              "bölgede reklam yeri açıldı.",
                        veri={"bekleme_id": str(b["id"]),
                              "isletme_id": str(b["isletme_id"])},
                    )
                    await s.execute(
                        _text("UPDATE reklam_bekleme SET durum='yer_acildi', "
                              " bildirildi_at=now(), updated_at=now() "
                              "WHERE id = :i"),
                        {"i": b["id"]},
                    )
                    acilan += 1
                sonuc["yer_acildi"] = acilan
        return sonuc

    return _dukkan_async_calistir(_calis)


#: Ust uste kac basarisiz cekimden sonra abonelik durur.
#:
#: Sonsuza kadar denemek hem bankada hem kullanicida gurultu yaratir ve
#: bazi bankalar tekrarlayan reddi supheli islem sayar. Uc, "gecici bir
#: sorun" (limit dolu, kart yenilendi) ile "gercekten bitti" arasini
#: ayirmaya yetecek kadar; sayilar ilk ay olculup ayarlanmali.
ABONELIK_AZAMI_DENEME = 3


@celery_app.task(name="dukkan.abonelik_cekimi")
def abonelik_cekimi() -> dict:
    """Vadesi gelen abonelikleri saklanan kartla ceker.

    Doner: {"denenen": n, "basarili": n, "basarisiz": n, "durduruldu": n}

    ==================================================================
    OTOMATIK YENILEME VARSAYILAN DEGIL — BU GOREV YALNIZ ACIKCA
    ISTENENLERI ISLER
    ==================================================================
    `abonelik` satiri ancak isletme satin alirken "otomatik yenile"
    dediginde ve SAKLI KART verdiginde dogar (F8b/F8c karari: sessizce
    kart cekmek en cok sikayet ureten seydir). Bu gorev o satirlari
    isler; baska hicbir reklami yenilemez.

    ==================================================================
    SAGLAYICI BAGLI DEGILSE HICBIR SEY YAPMAZ
    ==================================================================
    Cekim denemeden once `yapilandirildi_mi()` sorulur. Denemek ve
    "yapilandirilmadi" ile basarisiz saymak, `basarisiz_sayi` sayacini
    bosuna sisirir ve abonelikleri KULLANICININ HATASI OLMADAN
    durdururdu.

    ==================================================================
    BASARISIZ CEKIM SESSIZ DEGIL
    ==================================================================
    Her basarisizlikta isletme sahibine bildirim gider. Ucuncu denemede
    abonelik durur ve bu da AYRICA bildirilir — reklamin neden
    yenilenmedigini ay sonunda kesfetmesin.
    """
    async def _calis() -> dict:
        from sqlalchemy import text as _text

        from ..odeme import odeme_saglayicisi
        from .bildirim import bildir
        from .veritabani import SessionLocal

        sonuc = {"denenen": 0, "basarili": 0, "basarisiz": 0,
                 "durduruldu": 0, "atlandi": 0}
        saglayici = odeme_saglayicisi()
        if not saglayici.yapilandirildi_mi():
            # SAYAC SISIRILMEZ: bu bizim eksigimiz, kullanicinin degil.
            sonuc["atlandi"] = 1
            return sonuc

        async with SessionLocal() as s:
            async with s.begin():
                vadesi_gelenler = (
                    await s.execute(
                        _text("""
                            SELECT a.id, a.isletme_id, a.paket_id, a.kapsam,
                                   a.mahalle_id, a.ilce_id, a.il_id,
                                   a.kategori_id, a.basarisiz_sayi,
                                   oy.kart_token, oy.kullanici_token,
                                   p.gun, p.fiyat_kurus, p.kdv_orani,
                                   i.sahip_kullanici_id, i.ad AS isletme_ad
                            FROM abonelik a
                            JOIN reklam_paketi p ON p.id = a.paket_id
                            JOIN isletme i ON i.id = a.isletme_id
                            LEFT JOIN odeme_yontemi oy
                                   ON oy.id = a.odeme_yontemi_id
                                  AND oy.durum = 'aktif'
                            WHERE a.durum = 'aktif'
                              AND a.sonraki_cekim <= now()
                            ORDER BY a.sonraki_cekim
                            LIMIT 200
                        """)
                    )
                ).mappings().all()

                from ..odeme import KURUS_UST_SINIRI
                from .odeme_akisi import _kdv_hesapla
                from .reklam import KAPSAM_SUTUNU, reklam_ac

                for a in vadesi_gelenler:
                    sonuc["denenen"] += 1
                    if not a["kart_token"]:
                        # Kart silinmis: abonelik DURDURULUR, cunku
                        # cekilecek bir sey yok. Sessizce beklemek,
                        # kullanicinin fark etmedigi bir olu kayit olurdu.
                        await s.execute(
                            _text("UPDATE abonelik SET durum='duraklatildi', "
                                  " son_hata='kart_yok', updated_at=now() "
                                  "WHERE id = :i"), {"i": a["id"]})
                        await bildir(
                            s, kullanici_id=a["sahip_kullanici_id"],
                            tip="dukkan_abonelik_durdu",
                            baslik="Otomatik yenileme durdu",
                            govde=f"{a['isletme_ad']} icin kayitli kart "
                                  "bulunamadi.",
                            veri={"abonelik_id": str(a["id"]),
                                  "isletme_id": str(a["isletme_id"])})
                        sonuc["durduruldu"] += 1
                        continue

                    if a["fiyat_kurus"] > KURUS_UST_SINIRI:
                        continue
                    _kdv, toplam = _kdv_hesapla(a["fiyat_kurus"],
                                                a["kdv_orani"])
                    siparis_no = f"DK-AB-{uuid_hex()}"
                    cekim = saglayici.sakli_kartla_cek(
                        kart_token=a["kart_token"],
                        kullanici_token=a["kullanici_token"] or "",
                        tutar_kurus=toplam,
                        aciklama=f"Dukkan reklam yenileme {a['gun']} gun",
                        siparis_no=siparis_no,
                    )

                    # SATIN ALMA SATIRI HER DURUMDA: basarisiz deneme de
                    # bir kayittir ve "neden cekilmedi" sorusunu yanitlar.
                    satin_alma_id = (
                        await s.execute(
                            _text("""
                                INSERT INTO reklam_satin_alma
                                  (isletme_id, paket_id, tutar_kurus,
                                   kdv_orani, kdv_kurus, toplam_kurus,
                                   saglayici, saglayici_islem_id,
                                   siparis_no, durum, hata, saglayici_kodu,
                                   odendi_at)
                                VALUES (:i, :p, :t, :ko, :kk, :top, :sg,
                                        :iid, :sip, :d, :h, :sk,
                                        CASE WHEN :d='basarili' THEN now() END)
                                RETURNING id
                            """),
                            {"i": a["isletme_id"], "p": a["paket_id"],
                             "t": a["fiyat_kurus"], "ko": a["kdv_orani"],
                             "kk": _kdv, "top": toplam,
                             "sg": cekim.saglayici, "iid": cekim.islem_id,
                             "sip": siparis_no,
                             "d": "basarili" if cekim.basarili
                                  else "reddedildi",
                             "h": cekim.hata, "sk": cekim.saglayici_kodu},
                        )
                    ).scalar_one()

                    if cekim.basarili:
                        bolge_id = a[KAPSAM_SUTUNU[a["kapsam"]]]
                        try:
                            reklam_id = await reklam_ac(
                                s, isletme_id=a["isletme_id"],
                                paket_id=a["paket_id"], kapsam=a["kapsam"],
                                bolge_id=bolge_id,
                                kategori_id=a["kategori_id"], gun=a["gun"])
                        except Exception:
                            # SLOT DOLMUS OLABILIR: para alindi, reklam
                            # acilamadi. Satir `reklam_id IS NULL` kalir
                            # ve SAHIPSIZ TAHSILAT indeksinde GORUNUR —
                            # iade edilecek para odur.
                            reklam_id = None
                        if reklam_id is not None:
                            await s.execute(
                                _text("UPDATE reklam_satin_alma "
                                      "SET reklam_id = :r, updated_at=now() "
                                      "WHERE id = :i"),
                                {"r": reklam_id, "i": satin_alma_id})
                        await s.execute(
                            _text("UPDATE abonelik SET basarisiz_sayi=0, "
                                  " son_hata=NULL, "
                                  " sonraki_cekim = now() + "
                                  "   make_interval(days => :g), "
                                  " updated_at=now() WHERE id = :i"),
                            {"g": a["gun"], "i": a["id"]})
                        sonuc["basarili"] += 1
                        continue

                    # ---------------- BASARISIZ ------------------------ #
                    yeni_sayi = a["basarisiz_sayi"] + 1
                    durdu = yeni_sayi >= ABONELIK_AZAMI_DENEME
                    await s.execute(
                        _text("UPDATE abonelik SET basarisiz_sayi = :n, "
                              " son_hata = :h, durum = :d, "
                              # BIR GUN SONRA TEKRAR: ayni gun icinde
                              # tekrar denemek, limiti dolu bir kartta
                              # ayni sonucu verir ve bankada gurultu
                              # yaratir.
                              " sonraki_cekim = now() + interval '1 day', "
                              " updated_at=now() WHERE id = :i"),
                        {"n": yeni_sayi, "h": cekim.hata,
                         "d": "iptal" if durdu else "odeme_basarisiz",
                         "i": a["id"]})
                    await bildir(
                        s, kullanici_id=a["sahip_kullanici_id"],
                        tip="dukkan_abonelik_durdu" if durdu
                            else "dukkan_odeme_basarisiz",
                        baslik="Yenileme odemesi alinamadi",
                        govde=(f"{a['isletme_ad']} reklaminin yenileme "
                               "odemesi alinamadi."
                               + (" Otomatik yenileme durduruldu."
                                  if durdu else "")),
                        veri={"abonelik_id": str(a["id"]),
                              "isletme_id": str(a["isletme_id"]),
                              "deneme": yeni_sayi})
                    sonuc["basarisiz"] += 1
                    if durdu:
                        sonuc["durduruldu"] += 1
        return sonuc

    return _dukkan_async_calistir(_calis)


def uuid_hex() -> str:
    import uuid as _uuid

    return _uuid.uuid4().hex[:16].upper()
