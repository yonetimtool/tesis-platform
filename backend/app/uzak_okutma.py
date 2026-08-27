"""(P160) UZAK OKUTMA ALARMI — okutma noktadan esikten uzakta yapildi.

===========================================================================
NEDEN BU ALARM VAR
===========================================================================
`0052` esigi bir tesis ayari yapti ama esik YALNIZCA PANEL HARITASINI
etkiliyordu: yonetici "esigi koydum, artik uyari alirim" bekliyor ve
yaniliyordu. Bu modul o boslugu kapatir.

Mevcut alarmlarin hicbiri bu olayi anlatmiyor: `kacirilan_tur` (tur
yapilmadi), `eksik_checkpoint` (nokta hic okutulmadi), `gecikmis_okutma`
(okutma gecikti). Uzak okutma bunlarin hicbiri DEGIL — okutma YAPILDI,
ZAMANINDA yapildi, ama noktadan uzakta yapildi.

===========================================================================
NEREDE URETILIR: OKUTMA ANINDA, ZAMANLAYICIDA DEGIL
===========================================================================
Tur alarmlari zamanlayicida uretilir cunku olculen sey ZAMANIN GECMESIDIR
— kimse bir sey yapmadigi icin kimse tetiklemez. Burada tam tersi: olay
zaten bir ISTEKTIR ve karar icin gereken her sey (okutma koordinati, nokta
koordinati, esik) o anda elimizdedir. Zamanlayiciya birakmak, alarmi
dakikalarca geciktirmek ve ayni veriyi ikinci kez okumak olurdu.

Yazma, okutma INSERT'i ile AYNI transaction icindedir: okutma geri
alinirsa alarm da geri alinir. "Olmayan bir okutma icin alarm" uretmek,
yoneticiyi var olmayan bir olaya yollamakti.

===========================================================================
ALARM URETILMEYEN UC DURUM — hepsi bilincli
===========================================================================
1. KONUM YOKSA (`konum_durumu != 'var'`): karsilastirilacak bir sey yok.
   Konumsuz okutma ayri bir konudur (P34) ve panelde ayrica sayilir.
2. NOKTANIN KOORDINATI YOKSA: nokta nerede oldugunu soylemiyor. "Uzak"
   diyebilmek icin bir REFERANS gerekir; olmayan referansa gore uzaklik
   olcmek uydurmakti.
3. OLCUM BELIRSIZSE (`dogruluk > esik`): ±100 m hatayla olculmus bir
   mesafenin 50 m esigini gecip gecmedigi BILINEMEZ. Alarm uretmek,
   olcum hatasini ihlal diye raporlamak ve birinin telefonunu caldirmak
   olurdu — haritada renk degistirmekten cok daha agir bir iddia.

===========================================================================
DIL: OLCUM DILI, SUCLAMA DEGIL
===========================================================================
Metin "su nokta {mesafe} m uzaktan okutuldu (esik {esik} m)" der. "Ihlal",
"supheli" DEMEZ: olcum bunu tasimaz ve gorevliyi suclamak panelin isi
degil. Gorevlinin ADI push metnine GIRMEZ — kayit zaten kimin okuttugunu
tutuyor ve yonetici bakabilir; bir kisinin adini alarm bildirimine
koymak, olayin kendisinden once kisiyi hedef gostermekti.

===========================================================================
KIME GIDER — DEGISTI (urun karari)
===========================================================================
Ilk surumde push YALNIZ yonetime gidiyordu; gerekce "bildirim bir olcum
bildirir, uyari cezasi degil; kisiyi dogrudan titretmek onu sanik
konumuna koyar" idi. KARAR DEGISTI (Kerem): gorevli de bildirim alir.

Karsi gerekce daha guclu: okutmayi yapan kisi, okutmasinin noktadan uzak
kaydedildigini OGRENMEZSE duzeltemez de. Bildirimi yalnizca yonetime
gondermek, kisiyi haberi olmadan bir listeye yazmak olurdu — haber
vermek, sessizce raporlamaktan daha durust.

IN-APP SATIR ZATEN GORUNUYORDU: `notifications._YONETIM_GOZU` icinde
`security` var, yani gorevli `user_id IS NULL` satirlarini okuyabiliyor.
Bu yuzden KISIYE OZEL IKINCI BIR SATIR YAZILMIYOR — yazsaydik gorevlinin
listesinde AYNI olay iki kez gorunurdu. Eksik olan yalnizca PUSH'tu.
"""
from __future__ import annotations

import json
import logging
import uuid

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from .ceviri import VARSAYILAN_DIL
from .mesafe import esik_sonucu, mesafe_metre
from .models import Checkpoint, ScanEvent, Tenant
from .push_metinleri import push_govdesi
from .scheduler.notify import dispatch_external

logger = logging.getLogger("uzak_okutma")

#: Bildirim kimligi = `notification.tip` = `data.tip` (tek deger).
TIP = "uzak_okutma"

#: Alarmi ROL olarak alanlar. Gorevli AYRICA KISI olarak hedeflenir
#: (asagida): rol yayinina birakmak, o vardiyada olmayan tum guvenlik
#: personelini de titretirdi — `gecikmis_okutma`daki ayni ayrim.
ALARM_ROLLERI: tuple[str, ...] = ("admin", "yonetici", "guvenlik_amiri")

#: (P181 Bölüm 10.2) YÖNETİM push kısması penceresi (dakika). Aynı görevlinin
#: bu süre içindeki TEKRAR uzak-okutmalarında yönetime PUSH atılmaz (in-app
#: kaydı her zaman yazılır; görevliye her seferinde push gider). GPS'i bozuk /
#: hile denen bir görevli 26 noktada 26 push yerine ilk olayda 1 push üretir;
#: toplam sayı vardiya özetinden okunur. İlk olay her zaman gerçek-zamanlı.
_YONETIM_THROTTLE_DK = 30


async def uzak_okutma_alarmi(
    db: AsyncSession,
    *,
    scan: ScanEvent,
    checkpoint: Checkpoint,
) -> bool:
    """Okutma esik disindaysa alarm yazar. Donus: alarm uretildi mi.

    Cagiran okutma INSERT'inden SONRA, ayni transaction icinde cagirir.
    """
    # --- 1. konum yoksa karsilastirma da yok ---
    if scan.konum_durumu != "var" or scan.gps_lat is None or scan.gps_lng is None:
        return False
    # --- 2. noktanin referansi yoksa "uzak" denemez ---
    if checkpoint.gps_lat is None or checkpoint.gps_lng is None:
        return False

    esik = (await db.execute(select(Tenant.okutma_mesafe_esigi_m))).scalar_one_or_none()
    if esik is None:  # tenant satiri yoksa (olmamali) sessizce gec
        return False

    mesafe = mesafe_metre(
        float(scan.gps_lat), float(scan.gps_lng),
        float(checkpoint.gps_lat), float(checkpoint.gps_lng),
    )
    dogruluk = float(scan.gps_dogruluk_m) if scan.gps_dogruluk_m is not None else None
    # --- 3. belirsiz olcum alarm uretmez ---
    if esik_sonucu(mesafe, int(esik), dogruluk) != "disinda":
        return False

    veri = {"nokta": checkpoint.ad, "mesafe": mesafe, "esik": int(esik)}
    # Eski kolon: guncellenmemis istemciler icin Turkce ozet (bkz. 0008).
    mesaj = push_govdesi(TIP, VARSAYILAN_DIL, veri)
    # (P181 Bölüm 10.2) `guard`: YALNIZ in-app mesaj_veri'ye yazılır (push
    # params'ına DEĞİL) → yönetim push kısması aşağıda bu görevliyi sorgular.
    # Push metni/params görüntü verisidir; kimlik oraya sızmaz.
    mesaj_veri = {**veri, "guard": str(scan.guard_id) if scan.guard_id is not None else None}
    # DEDUP OKUTMA BASINA: bir okutma TEK bir olaydir. `gecikmis_okutma`
    # tekrar eder cunku orada olculen sey SUREN bir eksikliktir; burada
    # olay anlik ve tekrarlamak ayni seyi iki kez bildirmekti.
    dedup = f"{TIP}:{scan.id}"
    sonuc = await db.execute(
        text(
            "INSERT INTO notification (tenant_id, tip, checkpoint_id, dedup_key, "
            "mesaj, mesaj_kimlik, mesaj_veri) "
            "VALUES (:t, 'uzak_okutma', :cp, :dk, :m, :mk, CAST(:mv AS jsonb)) "
            "ON CONFLICT (tenant_id, dedup_key) DO NOTHING"
        ),
        {
            "t": str(scan.tenant_id), "cp": str(checkpoint.id), "dk": dedup,
            "m": mesaj, "mk": TIP, "mv": json.dumps(mesaj_veri),
        },
    )
    if sonuc.rowcount == 0:
        return False  # bu okutma icin zaten bildirildi

    logger.warning(
        "FAR_SCAN tenant=%s checkpoint=%s scan=%s mesafe=%s esik=%s",
        scan.tenant_id, checkpoint.id, scan.id, mesafe, esik,
    )
    # (P181 Bölüm 10.2) YÖNETİM PUSH KISMASI (batching): aynı görevli son
    # `_YONETIM_THROTTLE_DK` dk içinde zaten uzak-okutma alarmı ürettiyse
    # yönetime TEKRAR push atma — in-app kaydı yukarıda YAZILDI, görevliye push
    # aşağıda HER ZAMAN gider, toplam sayı vardiya özetinden okunur. Böylece
    # GPS'i bozuk bir görevli yönetimi 26 push'la sel altında bırakmaz; İLK
    # olay yine gerçek-zamanlı gider (yeni bir bütünlük sorununu geç bildirmeyiz).
    yonetim_push = True
    if scan.guard_id is not None:
        onceki = (
            await db.execute(
                text(
                    "SELECT 1 FROM notification "
                    "WHERE tenant_id = :t AND tip = 'uzak_okutma' AND dedup_key <> :dk "
                    "AND mesaj_veri->>'guard' = :g "
                    "AND created_at >= now() - make_interval(mins => :w) LIMIT 1"
                ),
                {"t": str(scan.tenant_id), "dk": dedup,
                 "g": str(scan.guard_id), "w": _YONETIM_THROTTLE_DK},
            )
        ).first()
        yonetim_push = onceki is None

    # PUSH EK GONDERIMDIR: hatasi kaydi kirmaz (dispatch_external kendi
    # icinde yutar) — in-app bildirim her halukarda yazilmistir.
    tenant = uuid.UUID(str(scan.tenant_id))
    data = {"tip": TIP, "checkpoint_id": str(checkpoint.id)}
    # (P181 Bölüm 10.3) TEK CAGRI — kisi (gorevli, eylemi duzeltebilecek kisi)
    # + rol (yonetim) BIRLIKTE, token bazinda dedup: gorevli ayni zamanda
    # yonetici ise TEK push. (P181 10.2) Yonetim rolu YALNIZ kisilmadiginda
    # gonderilir; gorevli her seferinde hedeflenir.
    dispatch_external(
        TIP,
        tenant_id=tenant,
        target_user_ids=[uuid.UUID(str(scan.guard_id))] if scan.guard_id is not None else None,
        target_roles=ALARM_ROLLERI if yonetim_push else None,
        params=veri,
        data=data,
    )
    return True
