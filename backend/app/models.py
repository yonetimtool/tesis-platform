"""SQLAlchemy modelleri — /contracts/db migration'inin BIRE BIR aynasi.

ONEMLI:
  * DDL'in tek dogruluk kaynagi /contracts/db/migrations'tir. Bu modeller YALNIZCA
    sorgu (ORM) icindir. Bunlardan migration URETILMEZ, autogenerate CALISTIRILMAZ.
  * Native enum tipleri (user_role, gun_tipi, patrol_window_durum) migration
    tarafindan olusturulur => burada create_type=False ile referans verilir.
  * Cross-tenant FK engeli icin composite FK (id, tenant_id) -> (id, tenant_id);
    bu yuzden her parent tabloda UNIQUE (id, tenant_id) bulunur.

Mirror dogrulamasi: kolon adlari/tipleri ve kisitlar 0001_initial_schema.py ile
eslesir.
"""
from __future__ import annotations

import uuid

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    Numeric,
    SmallInteger,
    Text,
    Time,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import ENUM, JSONB, TIMESTAMP, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


# --- native enum tipleri (migration olusturur; SQLAlchemy yeniden olusturmaz) ---
USER_ROLE = ENUM(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
    # (P35) Guvenlik amiri: guvenligi DIS BIR SIRKET yurutuyorsa vardiya ve
    # tur penceresini kuran kisi site yoneticisi DEGIL bu roldur.
    "guvenlik_amiri",
    # (P128, goc 0032) Denetci: tesisin mali gozetimi. SALT-OKUMA — hicbir
    # mutasyon ucu bu role acik degildir (yapisal test: tests/
    # test_denetci_salt_okuma.py).
    "denetci",
    name="user_role", create_type=False,
)
GUVENLIK_MODU = ENUM(
    "yonetim_ici", "dis_sirket",
    name="guvenlik_modu", create_type=False,
)
GUN_TIPI = ENUM(
    "her_gun", "hafta_ici", "hafta_sonu", "resmi_tatil",
    name="gun_tipi", create_type=False,
)
PATROL_WINDOW_DURUM = ENUM(
    "bekliyor", "tamamlandi", "kacirildi",
    name="patrol_window_durum", create_type=False,
)
CEVIRI_DURUM = ENUM(
    "hazir", "bekliyor", "hata",
    name="ceviri_durum", create_type=False,
)
KONUM_DURUMU = ENUM(
    "var", "izin_yok", "servis_kapali", "zaman_asimi", "bilinmiyor",
    name="konum_durumu", create_type=False,
)
UYARI_KANAL = ENUM(
    "webhook", "manuel", name="uyari_kanal", create_type=False,
)
UYARI_DURUM = ENUM(
    "gonderildi", "basarisiz", "manuel_bekliyor", "manuel_yapildi",
    name="uyari_durum", create_type=False,
)
NOTIFICATION_TIP = ENUM(
    "kacirilan_tur", "eksik_checkpoint", "gecikmis_okutma",
    "peyzaj_yaklasan", "peyzaj_kacirilan",
    "talep_is_emri", "talep_cozuldu", "talep_reddedildi", "is_emri_atandi",
    # (P147) Sakinin KENDI olaylarinin geri donusu.
    "kargo", "ziyaretci", "rezervasyon", "sikayet_cozuldu",
    name="notification_tip", create_type=False,
)
ASSET_KATEGORI = ENUM(
    "ekipman", "arac", "alet", "diger",
    name="asset_kategori", create_type=False,
)
ASSET_DURUM = ENUM(
    "musait", "zimmetli", "bakimda",
    name="asset_durum", create_type=False,
)
COMPLAINT_DURUM = ENUM(
    "acik", "is_emri", "cozuldu", "reddedildi", "geri_alindi",
    name="complaint_durum", create_type=False,
)
# (P154, goc 0043) Ek turu: not mu, dosya mi.
EK_TURU = ENUM("not", "dosya", name="ek_turu", create_type=False)
# COMPLAINT_KATEGORI KALDIRILDI (kategori artik task_category FK).
TASK_ONCELIK = ENUM(
    "dusuk", "orta", "yuksek", name="task_oncelik", create_type=False,
)
RESIDENT_ROL = ENUM(
    "malik", "kiraci",
    name="resident_rol", create_type=False,
)
DUES_YONTEM = ENUM(
    "elden", "havale", "kart", "diger",
    name="dues_yontem", create_type=False,
)
BUDGET_TIP = ENUM(
    "gelir", "gider",
    name="budget_tip", create_type=False,
)
BUDGET_KAYNAK = ENUM(
    "manuel", "aidat_odeme",
    name="budget_kaynak", create_type=False,
)
DUES_DURUM = ENUM(
    "basarili", "bekliyor", "iptal",
    name="dues_durum", create_type=False,
)
DEVICE_PLATFORM = ENUM(
    "android", "ios", "web",
    name="device_platform", create_type=False,
)
# (visitor_durum kaldirildi — ziyaretci artik LOG-ONLY, onay/red akisi yok.)
KARGO_DURUM = ENUM(
    "bekliyor", "teslim_alindi",
    name="kargo_durum", create_type=False,
)
ACCESS_REQUEST_DURUM = ENUM(
    "bekliyor", "onaylandi", "reddedildi",
    name="access_request_durum", create_type=False,
)
REZERVASYON_DURUM = ENUM(
    "onaylandi", "iptal",
    name="rezervasyon_durum", create_type=False,
)
KATILIM_DURUM = ENUM(
    "katiliyorum", "katilmiyorum",
    name="katilim_durum", create_type=False,
)
# Kamera yayin turu: hls/mp4 istemcide OYNAR, rtsp saklanir ama oynatilamaz
# (API cikisinda oynatilabilir=false).
CAMERA_TUR = ENUM(
    "hls", "mp4", "rtsp",
    name="camera_tur", create_type=False,
)
INTEGRATION_CHANNEL = ENUM(
    "webhook", "megaphone", "smarthome",
    name="integration_channel", create_type=False,
)
# ---------------------- P27 "Tanimlar" katmani enum'lari -------------------- #
GELIR_GIDER_TIP = ENUM(
    "gelir", "gider", "her_ikisi",
    name="gelir_gider_tip", create_type=False,
)
#: Dagitim sekli — SIMDILIK IKI DEGER. "arsa_payi"/"kisi_sayisi" BILEREK yok:
#: enum'a koyup P28'de uygulamamak, SECILEBILIR ama YANLIS BORCLANDIRAN bir
#: secenek gosterirdi. Genisleme tek satirdir (ALTER TYPE ... ADD VALUE).
GELIR_GIDER_DAGITIM = ENUM(
    "bagimsiz_bolumlere_esit", "tipe_gore",
    name="gelir_gider_dagitim", create_type=False,
)
BAKIYE_YON = ENUM("borc", "alacak", name="bakiye_yon", create_type=False)
#: Borcun KIME yazilacagi (P28) — kural TANIMDA durur, borclandirma aninda
#: secilmez; aksi halde ayni kalem farkli aylarda farkli kisiye yazilabilirdi.
BORC_HEDEF_KURALI = ENUM(
    "kiraci_oncelikli", "malik", name="borc_hedef_kurali", create_type=False
)
HAREKET_TIP = ENUM(
    "tahsilat", "gider", "gelir", "virman", "iade", "acilis",
    # (P154 / Asama 10, goc 0047) TERS KAYIT. `iade`den AYRI: iade
    # musteriye para donusudur (gercek hareket), iptal bir KAYIT
    # DUZELTMESIDIR. Ikisini ayni tiple yazmak "bu ay ne kadar iade
    # verdik" sorusunu yanlis yanitlardi.
    "iptal",
    name="hareket_tip", create_type=False,
)
HAREKET_YON = ENUM("giris", "cikis", name="hareket_yon", create_type=False)
TALEP_ONCELIK = ENUM(
    "dusuk", "normal", "yuksek", "acil",
    name="talep_oncelik", create_type=False,
)
MESAJ_KANAL = ENUM("sms", "eposta", name="mesaj_kanal", create_type=False)
MESAJ_AMAC = ENUM(
    "pazarlama", "operasyonel", name="mesaj_amac", create_type=False
)
MESAJ_DURUM = ENUM(
    "kuyrukta", "gonderildi", "iletildi", "okundu", "basarisiz",
    name="mesaj_durum", create_type=False,
)
ICRA_DURUM = ENUM(
    "acik", "takipte", "tahsil_edildi", "kapandi",
    name="icra_durum", create_type=False,
)
BORCLANDIRMA_KAYNAK = ENUM(
    "tekil", "toplu", "sayac", "ice_aktarim",
    name="borclandirma_kaynak", create_type=False,
)
SAYAC_TIP = ENUM(
    "su", "elektrik", "dogalgaz", "isi", "diger",
    name="sayac_tip", create_type=False,
)

UNIT_COMPLAINT_KATEGORI = ENUM(
    # `goruntu_kirliligi` 0013'te eklendi (P22g) — hurda arac, dagilmis esya,
    # cop yigini; otopark baglamindan da bildirilebilir.
    "gurultu", "kapi_onu_ayakkabi", "zarar_verme", "goruntu_kirliligi",
    "diger",
    name="unit_complaint_kategori", create_type=False,
)
KOD_AMACI = ENUM(
    "kayit", "giris", "hesap_silme", name="kod_amaci", create_type=False,
)
KAYIT_DURUM = ENUM(
    "telefon_bekliyor", "onay_bekliyor", "onaylandi", "reddedildi",
    name="kayit_durum", create_type=False,
)
UNIT_COMPLAINT_DURUM = ENUM(
    "acik", "kapali", "geri_alindi",
    name="unit_complaint_durum", create_type=False,
)
GECIS_KAYNAK = ENUM(
    "manuel", "anpr",
    name="gecis_kaynak", create_type=False,
)
ANPR_OLAY_DURUM = ENUM(
    "islendi", "onay_bekliyor", "yok_sayildi", "hata",
    name="anpr_olay_durum", create_type=False,
)
ANPR_YON = ENUM(
    "giris", "cikis", "bilinmiyor",
    name="anpr_yon", create_type=False,
)
VIOLATION_KAYNAK = ENUM(
    "kamera", "manuel", "devriye",
    name="violation_kaynak", create_type=False,
)
VIOLATION_DURUM = ENUM(
    "yeni", "inceleniyor", "kapatildi",
    name="violation_durum", create_type=False,
)


def _pk() -> Mapped[uuid.UUID]:
    return mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )


def _created_at() -> Mapped["str"]:
    return mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=text("now()")
    )


# --------------------------------------------------------------------------- #
class Tenant(Base):
    __tablename__ = "tenant"
    __table_args__ = (
        UniqueConstraint("slug", name="uq_tenant_slug"),
    )

    id: Mapped[uuid.UUID] = _pk()
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    #: (P148) Sakinin uygulamada ELLE yazdigi tesis kodu. `slug`tan AYRI:
    #: slug teknik bir tanimlayici (URL/oturum), bu ise kullaniciya
    #: verilen kisa koddur ve karistirilabilir harf icermez.
    kayit_kodu: Mapped[str] = mapped_column(Text, nullable=False)
    # Login tenant'i bu slug ile belirler (bkz. /contracts/auth.md §1.1).
    slug: Mapped[str] = mapped_column(Text, nullable=False)
    timezone: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'Europe/Istanbul'")
    )
    # Onboarding: admin acinca false; BIRINCIL yonetici ilk giriste
    # adlandirinca true.
    kurulum_tamamlandi: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    #: (P154 / Asama 7.3) Kurulum sihirbazinda BILINCLI ATLANAN adimlarin
    #: kodlari. TAMAMLANMA burada TUTULMAZ — o her istekte VERIDEN sayilir
    #: (bkz. routers/kurulum.py); ikinci bir dogruluk kaynagi, yonetici tek
    #: blogunu silince "tamamlandi" demeye devam ederdi.
    #:
    #: Atlama ise veriden TURETILEMEZ: "bu sitede NFC yok" ile "henuz
    #: eklemedim" verisel olarak aynidir (ikisi de sifir satir), kullanici
    #: icin degil.
    kurulum_atlanan: Mapped[list] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )
    # Tesisin yonetim maili (tenant seviyesi; kisisel veya ortak olabilir —
    # anlamsal kisit yok). Yonetici iletisim kartinda tum uyelere gorunur.
    yonetim_email: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Dis Hizmetler bolumu notu (yonetici serbest metni; tum roller okur).
    dis_hizmet_notu: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Otopark kapasitesi (G4). NULL = tanimsiz -> /parking/occupancy kapasite +
    # oran NULL doner (ana ekran "—" gosterir, uydurma sayi yok).
    otopark_kapasite: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # ANPR (0011): esik ALTINDAKI okumalar gecis ACMAZ, onay kuyruguna duser.
    # Varsayilan 0.850 — P15 olcumu Frigate'in kendi tanima esigini 0.9,
    # OCR toleransini 1 karakter gosterdi; yani yanlis okuma BEKLENIR.
    anpr_guven_esigi: Mapped[float] = mapped_column(
        Numeric(4, 3), nullable=False, server_default=text("0.850")
    )
    # Cikis olayinda acik gecis otomatik kapansin mi? Tek yonlu kapida
    # (yalniz giris kamerasi) kapatan olmaz — site bunu kapatabilmeli.
    anpr_otomatik_cikis: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    #: (P115) DEMO MODU — YALNIZ App Store denetim tesisi icin true.
    #: Acikken "simule okutma" ucu calisir; kapaliyken o uc YOK gibi
    #: davranir (404). Bayrak SUNUCUDA durur: istemci bayragi olsaydi
    #: herhangi bir kullanici gercek bir tesiste sahte tur kaydi
    #: uretebilirdi ve tur kaydinin KANIT degeri sifirlanirdi.
    demo_mod: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    # --- MUHASEBE AYARLARI (P27) — tenant basina TEK satir oldugu icin ayri
    # tablo DEGIL. `para_birimi` YALNIZ GOSTERIMDIR: depo ve hesaplama ₺
    # kalir; cok para birimi (kur, ceviri tarihi) AYRI bir karardir ve bu
    # alani "destekleniyor" saymak sessiz yanlis toplamlar uretirdi.
    evrak_seri: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'A'")
    )
    evrak_sira: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default=text("1")
    )
    para_birimi: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'TRY'")
    )
    #: (P28) Aylik gecikme tazminati orani (%). Tazminat TUTARI SAKLANMAZ,
    #: raporlama/tahsilat aninda hesaplanir — saklansaydi oran degistiginde
    #: gecmis kayitlar tutarsiz kalirdi.
    gecikme_aylik_yuzde = mapped_column(
        Numeric(5, 2), nullable=False, server_default=text("0")
    )
    #: (P37) Gurultu caydiricisi: daire basina ACIK gurultu sikayeti bu
    #: sayiya ULASINCA (sinir DAHIL) uyari tetiklenir ve sayac SIFIRLANIR.
    gurultu_esigi: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("5")
    )
    #: (P37) NULL = varsayilan metin. Bos metin de varsayilana duser
    #: (iceriksiz anons kullanicinin niyeti olamaz).
    gurultu_uyari_metni: Mapped[str | None] = mapped_column(Text, nullable=True)
    #: (P37) NULL = MANUEL MOD (hata degil, birinci sinif mod): yoneticiye
    #: bildirim gider, anonsu o yapar.
    gurultu_integration_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    #: (P35) Guvenligi KIM yonetir? `yonetim_ici` (varsayilan, bugunku
    #: davranis: yonetici planlar) | `dis_sirket` (amir planlar, yonetici
    #: SALT-OKUR izler). Mevcut tesisler etkilenmez.
    guvenlik_modu: Mapped[str] = mapped_column(
        GUVENLIK_MODU, nullable=False, server_default=text("'yonetim_ici'")
    )
    #: (P34) Tur gecikme alarmi: pencere acildiktan sonra bu kadar dakika
    #: icinde okutma gelmezse alarm baslar. 10 dk bir sitede makul, kampus
    #: buyuklugunde erken alarm demektir — bu yuzden AYAR.
    tur_gecikme_toleransi_dk: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("10")
    )
    #: (P34) Alarm KAC KEZ tekrarlanir (0 = kapali). Sonsuz tekrar bildirim
    #: yorgunlugu uretir ve alarm ANLAMINI kaybeder.
    tur_alarm_tekrar_sayisi: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("3")
    )
    #: (P34) Turun ILK okutmasindan once kamera fotografi zorunlu mu?
    #: Gece vardiyasinda kamera kullanimi her sitede kabul gormez
    #: (personel mahremiyeti) — bu yuzden urun kurali degil TENANT ANAHTARI.
    tur_baslangic_foto_zorunlu: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    # Hava durumu konumu (0005) — baslikta gorunen ad + Open-Meteo koordinati.
    konum_ad: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'İstanbul'")
    )
    konum_lat = mapped_column(
        Numeric(9, 6), nullable=False, server_default=text("41.0082")
    )
    konum_lon = mapped_column(
        Numeric(9, 6), nullable=False, server_default=text("28.9784")
    )
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class AppUser(Base):
    __tablename__ = "app_user"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_app_user_id_tenant"),
        UniqueConstraint("tenant_id", "email", name="uq_app_user_tenant_email"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    # personel icin zorunlu (login anahtari); resident icin opsiyonel.
    email: Mapped[str | None] = mapped_column(Text, nullable=True)
    telefon: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Rol-bazli arama rizasi (C1a): numara YALNIZ riza=true iken ve yetkili
    # arayan role /call-target ile aciklanir (KVKK — amaç-sınırlı).
    #: (P36) Pazarlama izinleri — UC AYRI KANAL, tek bayrak DEGIL: kisi
    #: e-posta isteyip SMS istemeyebilir. UCU DE VARSAYILAN KAPALI
    #: (KVKK: riza ACIK olmali, varsayilan olamaz).
    pazarlama_eposta: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    pazarlama_sms: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    pazarlama_arama: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    #: (P36) Rizanin NE ZAMAN degistigi — KVKK'da ispat yukumlulugu veri
    #: sorumlusundadir.
    pazarlama_guncelleme_at = mapped_column(
        TIMESTAMP(timezone=True), nullable=True
    )
    aranabilir: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    # Tenant'in BIRINCIL yoneticisi mi? Tesisi ilk giriste adlandirma kapisi
    # (POST /tenant/setup) YALNIZ buna acilir. Kismi unique index
    # (uq_app_user_birincil) tenant basina en fazla bir true garantiler.
    birincil: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    # resident ilk giriste parola belirleyene kadar NULL.
    password_hash: Mapped[str | None] = mapped_column(Text, nullable=True)
    # sakinin tek seferlik gecici giris kodu (bcrypt hash; duz metin yok).
    temp_code_hash: Mapped[str | None] = mapped_column(Text, nullable=True)
    # sakin kalici parolasini belirledi mi (ilk giris akisi tamamlandi mi)?
    password_set: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    role: Mapped[str] = mapped_column(USER_ROLE, nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    #: (P128, goc 0032) GOREV PENCERESI — bugun YALNIZ `denetci` icin
    #: anlamli. Ikisi de NULL olabilir: suresiz gorev (kucuk tesislerde
    #: gercek durum). Pencere HER istekte olculur (deps.get_current_user);
    #: yalniz giriste olcmek, gorevi biten denetcinin acik oturumunu
    #: bitmemis sayardi.
    # (Dosyanin diger `Date` kolonlari gibi ANNOTASYONSUZ: `Mapped[date]`
    # yazmak `datetime.date`i modul ad alanina sokmayi gerektirir — SQLAlchemy
    # 2.0 annotasyon metnini calisma aninda cozer ve import olmadan mapper
    # kurulumu duser.)
    gorev_baslangic = mapped_column(Date, nullable=True)
    gorev_bitis = mapped_column(Date, nullable=True)
    # Personel profil fotografi (0005) — MinIO obje anahtari; yalniz personel
    # rolleri yazar (PATCH /me/avatar), resident'a 403.
    avatar_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    # (P30) Havale aciklama kodu — BIR KEZ uretilir ve SABIT KALIR.
    # Turetilseydi (orn. daire no + kisa id) daire numarasi degisince kod da
    # degisir ve sakinin bankadaki duzenli talimati SESSIZCE eslesmez olurdu.
    odeme_kodu: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class Shift(Base):
    __tablename__ = "shift"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_shift_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    # Gun-ici saat (UTC degil; tenant.timezone ile yorumlanir).
    baslangic_saat = mapped_column(Time, nullable=False)
    bitis_saat = mapped_column(Time, nullable=False)
    gun_tipi: Mapped[str] = mapped_column(
        GUN_TIPI, nullable=False, server_default=text("'her_gun'")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class ShiftAssignment(Base):
    """Vardiya personel atamasi (0005) — yonetici atar; kartta avatar."""

    __tablename__ = "shift_assignment"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "shift_id", "user_id", name="uq_shift_assignment"
        ),
        ForeignKeyConstraint(
            ["shift_id", "tenant_id"],
            ["shift.id", "shift.tenant_id"],
            ondelete="CASCADE",
            name="fk_shift_assignment_shift",
        ),
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_shift_assignment_user",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    shift_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    created_at = _created_at()


class Camera(Base):
    """Site kamerasi (0005) — yonetim yonetir, gorunurluk role gore suzulur.

    `sakin_gorebilir` TEK anahtardir: resident + tesis_gorevlisi YALNIZ
    `aktif=true AND sakin_gorebilir=true` kameralari gorur (suzgec SUNUCUDA,
    bkz. routers/cameras.py). Varsayilan KAPALI — kamera mahremiyet tasir.

    Backend yayini HIC cekmez (istemci oynatir) => SSRF yuzeyi yok. `tur`
    oynatilabilirligi belirler: hls/mp4 oynar, rtsp saklanir ama istemci
    natively oynatamaz (cikista `oynatilabilir=false`).
    """

    __tablename__ = "camera"
    __table_args__ = (
        UniqueConstraint("tenant_id", "ad", name="uq_camera_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    konum: Mapped[str | None] = mapped_column(Text, nullable=True)
    stream_url: Mapped[str] = mapped_column(Text, nullable=False)
    # RESTREAM (0012): RTSP kamerayi OYNATILABILIR yapan gecit adresi
    # (Frigate/go2rtc HLS). Dolu ise istemci BUNU oynatir ve `oynatilabilir`
    # true olur. `stream_url` kameranin KENDI adresidir ve korunur — restream
    # bozulunca gercek adres kaybolmasin.
    restream_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    # SNAPSHOT (0031 / P121): TEK KARE dondüren adres (image/jpeg). Izgara
    # karosu 5-10 sn'de bir BUNU ceker; oynatici acilmaz. Frigate'in
    # `/api/<kamera>/latest.jpg` ucu tam olarak budur ve P17'de doldurulur.
    # Uc adres UC AYRI SEYDIR: stream (kameranin kendisi), restream (gecidin
    # oynatilabilir yayini), snapshot (tek kare).
    snapshot_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    tur: Mapped[str] = mapped_column(
        CAMERA_TUR, nullable=False, server_default=text("'hls'")
    )
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    sakin_gorebilir: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class Checkpoint(Base):
    __tablename__ = "checkpoint"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_checkpoint_id_tenant"),
        UniqueConstraint("tenant_id", "nfc_tag_uid", name="uq_checkpoint_tenant_nfc"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    nfc_tag_uid: Mapped[str] = mapped_column(Text, nullable=False)
    gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    # NTAG424 SDM: AES-128 etiket anahtari (SDM_KEK ile AES-GCM sifreli, base64).
    # NULL = SDM provision edilmemis. sdm_son_sayac = replay korumasi.
    sdm_key_sifreli: Mapped[str | None] = mapped_column(Text, nullable=True)
    sdm_son_sayac: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default=text("0")
    )
    created_at = _created_at()
    updated_at = _created_at()

    @property
    def sdm_aktif(self) -> bool:
        return self.sdm_key_sifreli is not None


# --------------------------------------------------------------------------- #
class PatrolPlan(Base):
    __tablename__ = "patrol_plan"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_patrol_plan_id_tenant"),
        CheckConstraint("periyot_dakika > 0", name="ck_patrol_plan_periyot"),
        # DDL'de kolon-ozel: ON DELETE SET NULL (shift_id) — sadece shift_id
        # NULL'lanir, paylasilan NOT NULL tenant_id korunur. SQLAlchemy bu
        # kolon-ozel sozdizimini uretmedigimiz icin (DDL kaynagi /contracts)
        # burada ondelete="SET NULL" yalnizca sorgu/metadata aynasidir.
        ForeignKeyConstraint(
            ["shift_id", "tenant_id"],
            ["shift.id", "shift.tenant_id"],
            ondelete="SET NULL",
            name="fk_patrol_plan_shift",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    shift_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    baslangic_saat = mapped_column(Time, nullable=False)
    bitis_saat = mapped_column(Time, nullable=False)
    periyot_dakika: Mapped[int] = mapped_column(Integer, nullable=False)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class PatrolPlanCheckpoint(Base):
    __tablename__ = "patrol_plan_checkpoint"
    __table_args__ = (
        ForeignKeyConstraint(
            ["patrol_plan_id", "tenant_id"],
            ["patrol_plan.id", "patrol_plan.tenant_id"],
            ondelete="CASCADE",
            name="fk_ppc_plan",
        ),
        ForeignKeyConstraint(
            ["checkpoint_id", "tenant_id"],
            ["checkpoint.id", "checkpoint.tenant_id"],
            ondelete="CASCADE",
            name="fk_ppc_checkpoint",
        ),
        UniqueConstraint("patrol_plan_id", "sira", name="uq_ppc_plan_sira"),
        CheckConstraint("sira >= 0", name="ck_ppc_sira"),
    )

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    patrol_plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True
    )
    checkpoint_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True
    )
    sira: Mapped[int] = mapped_column(Integer, nullable=False)


# --------------------------------------------------------------------------- #
class PatrolWindow(Base):
    __tablename__ = "patrol_window"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_patrol_window_id_tenant"),
        ForeignKeyConstraint(
            ["patrol_plan_id", "tenant_id"],
            ["patrol_plan.id", "patrol_plan.tenant_id"],
            ondelete="CASCADE",
            name="fk_patrol_window_plan",
        ),
        CheckConstraint(
            "pencere_bitis > pencere_baslangic", name="ck_patrol_window_aralik"
        ),
        UniqueConstraint(
            "patrol_plan_id", "pencere_baslangic",
            name="uq_patrol_window_plan_baslangic",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    patrol_plan_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    pencere_baslangic = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    pencere_bitis = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    durum: Mapped[str] = mapped_column(
        PATROL_WINDOW_DURUM, nullable=False, server_default=text("'bekliyor'")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class ScanEvent(Base):
    __tablename__ = "scan_event"
    __table_args__ = (
        ForeignKeyConstraint(
            ["guard_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_scan_guard",
        ),
        ForeignKeyConstraint(
            ["checkpoint_id", "tenant_id"],
            ["checkpoint.id", "checkpoint.tenant_id"],
            ondelete="RESTRICT",
            name="fk_scan_checkpoint",
        ),
        # DDL'de kolon-ozel: ON DELETE SET NULL (patrol_window_id) — sadece
        # patrol_window_id NULL'lanir, paylasilan NOT NULL tenant_id korunur.
        # ondelete="SET NULL" burada yalnizca metadata aynasi (DDL /contracts).
        ForeignKeyConstraint(
            ["patrol_window_id", "tenant_id"],
            ["patrol_window.id", "patrol_window.tenant_id"],
            ondelete="SET NULL",
            name="fk_scan_window",
        ),
        UniqueConstraint(
            "tenant_id", "idempotency_key", name="uq_scan_tenant_idempotency"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    guard_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    checkpoint_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    patrol_window_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    nfc_tag_uid: Mapped[str] = mapped_column(Text, nullable=False)
    okutma_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    # (P34) NULL'un ANLAMI: "izin verilmedi" mi, "sinyal yok" mu, "eski
    # istemci" mi? Uc durum ayni gorunurken amir konumsuz okutmanin
    # OLDUGUNU bile fark edemezdi.
    konum_durumu: Mapped[str] = mapped_column(
        KONUM_DURUMU, nullable=False, server_default=text("'bilinmiyor'")
    )
    #: (P34) 5 m ile 2 km dogruluk ekranda AYNI gorunurdu; ikincisi kanit
    #: degeri tasimaz.
    gps_dogruluk_m = mapped_column(Numeric(7, 1), nullable=True)
    foto_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    imza_dogrulandi: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    idempotency_key: Mapped[str] = mapped_column(Text, nullable=False)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class KayitDogrulama(Base):
    """(P148) Bekleyen sakin kaydi + telefon dogrulama kodu.

    Kullanici satiri BU ASAMADA ACILMAZ: dogrulanmamis bir telefon icin
    `app_user` yazmak, tesis kodunu bilen herkesin kullanici listesini
    sisirmesine izin verirdi. Kayit ancak kod dogrulaninca kullaniciya
    donusur.
    """

    __tablename__ = "kayit_dogrulama"

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    #: YALNIZ `amac='kayit'`te dolu: giris/silme kodunun dairesi yoktur.
    unit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    telefon: Mapped[str] = mapped_column(Text, nullable=False)
    #: Kod DUZ METIN tutulmaz (giris kodlariyla ayni kural).
    kod_hash: Mapped[str] = mapped_column(Text, nullable=False)
    son_gecerlilik = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    #: Kaba kuvvet sayaci — 6 haneli kod sayilmadan dakikalar icinde bulunur.
    deneme: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    #: (P149) Kodun NE ICIN uretildigi. Giris kodu hesap silmeyi ONAYLAYAMAZ
    #: — "tek kod her kapiyi acar" hatasi yapisal olarak engellenir.
    amac: Mapped[str] = mapped_column(
        KOD_AMACI, nullable=False, server_default=text("'kayit'")
    )
    #: (P148.2) Basvuru sahibinin verdigi ad — onay ekraninda gorunur.
    ad: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        KAYIT_DURUM, nullable=False, server_default=text("'telefon_bekliyor'")
    )
    karar_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    #: Onay hangi kullaniciyi actı — ikinci onay ayni kullaniciyi TEKRAR
    #: acmasin (idempotens) ve iz kalsin.
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    created_at = _created_at()


class Notification(Base):
    __tablename__ = "notification"
    __table_args__ = (
        # DDL'de kolon-ozel ON DELETE SET NULL (<kolon>) — sadece ilgili FK kolonu
        # NULL'lanir, paylasilan NOT NULL tenant_id korunur (DDL kaynagi /contracts).
        ForeignKeyConstraint(
            ["patrol_window_id", "tenant_id"],
            ["patrol_window.id", "patrol_window.tenant_id"],
            ondelete="SET NULL",
            name="fk_notification_window",
        ),
        ForeignKeyConstraint(
            ["patrol_plan_id", "tenant_id"],
            ["patrol_plan.id", "patrol_plan.tenant_id"],
            ondelete="SET NULL",
            name="fk_notification_plan",
        ),
        ForeignKeyConstraint(
            ["checkpoint_id", "tenant_id"],
            ["checkpoint.id", "checkpoint.tenant_id"],
            ondelete="SET NULL",
            name="fk_notification_checkpoint",
        ),
        UniqueConstraint(
            "tenant_id", "tip", "patrol_window_id",
            name="uq_notification_tenant_tip_window",
        ),
        UniqueConstraint("tenant_id", "dedup_key", name="uq_notification_dedup"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    tip: Mapped[str] = mapped_column(NOTIFICATION_TIP, nullable=False)
    #: (P147) Bildirimin ALICISI. NULL = tesise ait YONETIM alarmi (bugunku
    #: butun satirlar boyle); dolu = su kisiye ait olay. Iki anlam ayri
    #: okunur: sakin yalnizca kendi satirlarini, yonetim yalnizca NULL
    #: olanlari gorur.
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    patrol_window_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    patrol_plan_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    checkpoint_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    task_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    dedup_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    # DEPRECATED (tur 16): donmus Turkce cumle. Yeni satirlarda yapisal
    # veriden uretilir; eski satirlarda tek kaynak odur.
    mesaj: Mapped[str] = mapped_column(Text, nullable=False)
    # Metnin KIMLIGI + parametreleri (0008). Okuma yolu metni istegin
    # dilinde bunlardan uretir — cumle kayda DONDURULMAZ.
    mesaj_kimlik: Mapped[str | None] = mapped_column(Text, nullable=True)
    mesaj_veri: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    okundu: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class TaskCategory(Base):
    """Yonetici-tanimli gorev kategorisi (A6) — tenant'a ozel, soft-delete."""

    __tablename__ = "task_category"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_task_category_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_task_category_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)


# --------------------------------------------------------------------------- #
class Task(Base):
    __tablename__ = "task"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_task_id_tenant"),
        CheckConstraint(
            "periyot_dakika IS NULL OR periyot_dakika > 0", name="ck_task_periyot"
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (<kolon>) — tenant_id korunur.
        ForeignKeyConstraint(
            ["atanan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_task_atanan",
        ),
        ForeignKeyConstraint(
            ["checkpoint_id", "tenant_id"],
            ["checkpoint.id", "checkpoint.tenant_id"],
            ondelete="SET NULL",
            name="fk_task_checkpoint",
        ),
        ForeignKeyConstraint(
            ["kategori_id", "tenant_id"],
            ["task_category.id", "task_category.tenant_id"],
            ondelete="SET NULL",
            name="fk_task_kategori",
        ),
        ForeignKeyConstraint(
            ["ticket_id", "tenant_id"],
            ["complaint.id", "complaint.tenant_id"],
            ondelete="SET NULL",
            name="fk_task_ticket",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    atanan_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    checkpoint_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    kategori_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    periyot_dakika: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sonraki_planlanan = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    foto_zorunlu: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    oncelik: Mapped[str | None] = mapped_column(TASK_ONCELIK, nullable=True)
    ticket_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class TaskCompletion(Base):
    __tablename__ = "task_completion"
    __table_args__ = (
        ForeignKeyConstraint(
            ["task_id", "tenant_id"],
            ["task.id", "task.tenant_id"],
            ondelete="CASCADE",
            name="fk_completion_task",
        ),
        ForeignKeyConstraint(
            ["tamamlayan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_completion_user",
        ),
        UniqueConstraint(
            "tenant_id", "idempotency_key", name="uq_completion_tenant_idempotency"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    task_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    tamamlayan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    tamamlanma_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    nfc_tag_uid: Mapped[str | None] = mapped_column(Text, nullable=True)
    gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    foto_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    idempotency_key: Mapped[str] = mapped_column(Text, nullable=False)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class Asset(Base):
    __tablename__ = "asset"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_asset_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    kategori: Mapped[str | None] = mapped_column(ASSET_KATEGORI, nullable=True)
    nfc_tag_uid: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        ASSET_DURUM, nullable=False, server_default=text("'musait'")
    )
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class AssetCheckout(Base):
    __tablename__ = "asset_checkout"
    __table_args__ = (
        ForeignKeyConstraint(
            ["asset_id", "tenant_id"],
            ["asset.id", "asset.tenant_id"],
            ondelete="CASCADE",
            name="fk_checkout_asset",
        ),
        ForeignKeyConstraint(
            ["alan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_checkout_user",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (birakan_user_id) — tenant_id korunur.
        ForeignKeyConstraint(
            ["birakan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_checkout_birakan",
        ),
        UniqueConstraint(
            "tenant_id", "idempotency_key", name="uq_checkout_tenant_idempotency"
        ),
        # Tek aktif zimmet (acik checkout) + birakma idempotency partial-unique index'leri
        # DDL'de (/contracts) tanimli; burada sadece sorgu aynasi.
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    asset_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    alan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    birakan_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    alma_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=False, server_default=text("now()"))
    birakma_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    alma_nfc_tag_uid: Mapped[str | None] = mapped_column(Text, nullable=True)
    birakma_nfc_tag_uid: Mapped[str | None] = mapped_column(Text, nullable=True)
    alma_gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    alma_gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    birakma_gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    birakma_gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    idempotency_key: Mapped[str] = mapped_column(Text, nullable=False)
    birakma_idempotency_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()




# --------------------------------------------------------------------------- #
class Unit(Base):
    __tablename__ = "unit"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_unit_id_tenant"),
        UniqueConstraint("tenant_id", "no", name="uq_unit_tenant_no"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    no: Mapped[str] = mapped_column(Text, nullable=False)
    blok: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Fiziksel yerlesim (bina semasi / yogunluk haritasi icin) — hepsi
    # nullable; yerlesimi girilmemis daire haritada "yerlesimsiz" kovadadir.
    kat: Mapped[int | None] = mapped_column(Integer, nullable=True)  # kat (0=zemin)
    sira: Mapped[int | None] = mapped_column(Integer, nullable=True)  # kattaki sira/konum
    metrekare = mapped_column(Numeric(8, 2), nullable=True)
    # SINIFLANDIRMA (P26) — ikisi de NULLABLE: tip/grup TANIM'dir, dairenin
    # varligi onlara bagli degildir. Tanim silinirse daire silinmez, yalniz
    # siniflandirmasiz kalir (ON DELETE SET NULL).
    unit_tip_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    unit_grup_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


class UnitGrup(Base):
    """Bagimsiz Bolum GRUBU (P26) — bolumun NE OLDUGU: Daire / Villa / Dukkan.

    Kucuk, yavas degisen liste; raporlamada kirilim eksenidir. Tipten (1+1,
    2+1) AYRIDIR: tek tabloda birlestirmek her grup x tip kombinasyonunu ayri
    satira zorlardi.
    """

    __tablename__ = "unit_grup"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_unit_grup_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_unit_grup_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


class UnitTip(Base):
    """Bagimsiz Bolum TIPI (P26) — buyukluk/duzen + VARSAYILAN AIDAT.

    Ad tamamen SERBEST metindir (1+0, 2+1, dubleks, stüdyo…): sabit bir enum,
    "1+1,5" diyen siteyi disarida birakirdi.

    `varsayilan_aidat_kurus` NULL ise "tanimsiz"dir, 0 DEGIL — 0 gecerli bir
    tutardir (muaf daire) ve ikisini karistirmak P28'de sessiz sifir aidat
    uretirdi.
    """

    __tablename__ = "unit_tip"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_unit_tip_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_unit_tip_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    varsayilan_aidat_kurus: Mapped[int | None] = mapped_column(
        BigInteger, nullable=True
    )
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class BuildingBlock(Base):
    """Bina blok kaydi (D-viz Rev-1) — yonetici/admin blok tanimlar; Rev-2
    gorsel editoru bu bloklara kat/daire yerlestirir. Blok-suz siteler bu
    tabloyu kullanmaz (unit.blok NULL). Etiket unit.blok ile eslesir (zayif
    baglanti; hard FK yok — blok-suz + blok-tabanli siteler birlikte)."""

    __tablename__ = "building_block"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_building_block_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_building_block_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)  # blok etiketi
    kat_sayisi: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class UnitResident(Base):
    __tablename__ = "unit_resident"
    __table_args__ = (
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_unitresident_unit",
        ),
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_unitresident_user",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    rol_tipi: Mapped[str | None] = mapped_column(RESIDENT_ROL, nullable=True)
    baslangic = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    bitis = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class DuesAssessment(Base):
    __tablename__ = "dues_assessment"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_assessment_id_tenant"),
        CheckConstraint("tutar_kurus > 0", name="ck_assessment_tutar"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_assessment_unit",
        ),
        UniqueConstraint(
            "tenant_id", "unit_id", "donem", name="uq_assessment_tenant_unit_donem"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    donem: Mapped[str] = mapped_column(Text, nullable=False)
    tutar_kurus: Mapped[int] = mapped_column(Integer, nullable=False)
    son_odeme_tarihi = mapped_column(Date, nullable=True)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    # --- P28 BORCLANDIRMA ALANLARI (paralel tablo DEGIL, ayni kayit) ------- #
    #: Borclandirma TURU (P27 tanimi). NULL = eski kayitlar / tursuz aidat.
    gelir_gider_tanim_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    #: Borcun KIME yazildigi. NULL = "daireye" (eski davranis).
    hedef_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    #: Islem gunu. `donem` (YYYY-MM) MUHASEBE DONEMIDIR ve ikisi ayni sey
    #: DEGILDIR: Ocak doneminin borcu Subat'ta acilabilir.
    tarih = mapped_column(Date, nullable=False, server_default=text("CURRENT_DATE"))
    gecikme_uygula: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    kaynak: Mapped[str] = mapped_column(
        BORCLANDIRMA_KAYNAK, nullable=False, server_default=text("'tekil'")
    )
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class DuesPayment(Base):
    __tablename__ = "dues_payment"
    __table_args__ = (
        CheckConstraint("tutar_kurus > 0", name="ck_payment_tutar"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_payment_unit",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (assessment_id); tenant_id korunur.
        ForeignKeyConstraint(
            ["assessment_id", "tenant_id"],
            ["dues_assessment.id", "dues_assessment.tenant_id"],
            ondelete="SET NULL",
            name="fk_payment_assessment",
        ),
        ForeignKeyConstraint(
            ["kaydeden_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_payment_kaydeden",
        ),
        UniqueConstraint(
            "tenant_id", "idempotency_key", name="uq_payment_tenant_idempotency"
        ),
        # composite FK hedefi (budget_entry.ilgili_payment_id).
        UniqueConstraint("id", "tenant_id", name="uq_payment_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    assessment_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    tutar_kurus: Mapped[int] = mapped_column(Integer, nullable=False)
    odeme_zamani = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=text("now()")
    )
    donem: Mapped[str | None] = mapped_column(Text, nullable=True)
    yontem: Mapped[str] = mapped_column(DUES_YONTEM, nullable=False)
    durum: Mapped[str] = mapped_column(
        DUES_DURUM, nullable=False, server_default=text("'basarili'")
    )
    makbuz_no: Mapped[str | None] = mapped_column(Text, nullable=True)
    provider: Mapped[str | None] = mapped_column(Text, nullable=True)
    provider_ref: Mapped[str | None] = mapped_column(Text, nullable=True)
    kaydeden_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(Text, nullable=False)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class BudgetCategory(Base):
    """Dinamik gelir/gider kategorisi (butce — Wave 2A).

    Silme = SOFT-DELETE (aktif=false): hareketi olan kategori hard-delete
    edilemez (budget_entry FK RESTRICT) — gecmis kayitlar kategorisini korur.
    """

    __tablename__ = "budget_category"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_budgetcat_id_tenant"),
        UniqueConstraint("tenant_id", "tip", "ad", name="uq_budgetcat_tenant_tip_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    tip: Mapped[str] = mapped_column(BUDGET_TIP, nullable=False)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class BudgetEntry(Base):
    """Butce defteri kaydi. Para INTEGER KURUS (dues ile ayni desen).

    kaynak='aidat_odeme' kayitlari basarili aidat odemesinden OTOMATIK uretilir
    ve ilgili_payment_id tasir; UNIQUE (tenant_id, ilgili_payment_id) ayni
    odemeden ikinci kaydi engeller (idempotency).
    """

    __tablename__ = "budget_entry"
    __table_args__ = (
        CheckConstraint("tutar_kurus > 0", name="ck_budget_entry_tutar"),
        UniqueConstraint("id", "tenant_id", name="uq_budget_entry_id_tenant"),
        UniqueConstraint(
            "tenant_id", "ilgili_payment_id", name="uq_budget_entry_payment"
        ),
        ForeignKeyConstraint(
            ["kategori_id", "tenant_id"],
            ["budget_category.id", "budget_category.tenant_id"],
            ondelete="RESTRICT",
            name="fk_budget_entry_kategori",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (ilgili_payment_id).
        ForeignKeyConstraint(
            ["ilgili_payment_id", "tenant_id"],
            ["dues_payment.id", "dues_payment.tenant_id"],
            ondelete="SET NULL",
            name="fk_budget_entry_payment",
        ),
        ForeignKeyConstraint(
            ["created_by", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_budget_entry_created_by",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    kategori_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    # Kategoriden kopyalanir (denormalize) — bkz. migration notu.
    tip: Mapped[str] = mapped_column(BUDGET_TIP, nullable=False)
    tutar_kurus: Mapped[int] = mapped_column(Integer, nullable=False)
    tarih = mapped_column(Date, nullable=False)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    kaynak: Mapped[str] = mapped_column(
        BUDGET_KAYNAK, nullable=False, server_default=text("'manuel'")
    )
    ilgili_payment_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    created_by: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class PaymentWebhookEvent(Base):
    __tablename__ = "payment_webhook_event"
    __table_args__ = (
        UniqueConstraint("tenant_id", "provider", "event_id", name="uq_webhook_event"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    provider: Mapped[str] = mapped_column(Text, nullable=False)
    event_id: Mapped[str] = mapped_column(Text, nullable=False)
    provider_ref: Mapped[str] = mapped_column(Text, nullable=False)
    created_at = _created_at()


class Announcement(Base):
    __tablename__ = "announcement"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_announcement_id_tenant"),
        ForeignKeyConstraint(
            ["olusturan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_announcement_olusturan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    govde: Mapped[str] = mapped_column(Text, nullable=False)
    # Opsiyonel gorsel — /uploads/presign ile yuklenen MinIO obje anahtari.
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Icerigin YAZILDIGI dil (orijinal). Ceviriler bundan uretilir; bkz.
    # app/ceviri.py. Simdilik tr sabit (admin secimi sonraki tur).
    kaynak_dil: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'tr'")
    )
    olusturan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class Complaint(Base):
    """Sikayet/oneri — sakin -> yonetim talep kanali (auth.md §4)."""

    __tablename__ = "complaint"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_complaint_id_tenant"),
        ForeignKeyConstraint(
            ["acan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_complaint_acan",
        ),
        ForeignKeyConstraint(
            ["kategori_id", "tenant_id"],
            ["task_category.id", "task_category.tenant_id"],
            ondelete="SET NULL",
            name="fk_complaint_kategori",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    acan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    mesaj: Mapped[str] = mapped_column(Text, nullable=False)
    kategori_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    durum: Mapped[str] = mapped_column(
        COMPLAINT_DURUM, nullable=False, server_default=text("'acik'")
    )
    # --- P33 IS TAKIBI GENISLETMESI (birlestirme DEGIL) ------------------ #
    #: Talebin ait oldugu bagimsiz bolum (yoktu).
    unit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    oncelik: Mapped[str] = mapped_column(
        TALEP_ONCELIK, nullable=False, server_default=text("'normal'")
    )
    #: Atanan personel — P27 kaydi, `app_user` DEGIL: temizlik/bahcivan gibi
    #: uygulama hesabi OLMAYAN personele de is atanabilmeli.
    atanan_personel_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    created_at = _created_at()
    updated_at = _created_at()


class ComplaintPhoto(Base):
    """Talep gorseli (<=3/talep) — MinIO obje anahtari, tenant-onekli."""

    __tablename__ = "complaint_photo"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_complaint_photo_id_tenant"),
        ForeignKeyConstraint(
            ["complaint_id", "tenant_id"],
            ["complaint.id", "complaint.tenant_id"],
            ondelete="CASCADE",
            name="fk_complaint_photo_complaint",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    complaint_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    foto_key: Mapped[str] = mapped_column(Text, nullable=False)
    sira: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default=text("0"))
    created_at = _created_at()


class ComplaintStatusHistory(Base):
    """Talep durum gecmisi (timeline). actor_role YALNIZ — user_id ASLA."""

    __tablename__ = "complaint_status_history"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_complaint_history_id_tenant"),
        ForeignKeyConstraint(
            ["complaint_id", "tenant_id"],
            ["complaint.id", "complaint.tenant_id"],
            ondelete="CASCADE",
            name="fk_complaint_history_complaint",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    complaint_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    durum: Mapped[str] = mapped_column(COMPLAINT_DURUM, nullable=False)
    actor_role: Mapped[str] = mapped_column(USER_ROLE, nullable=False)
    sebep: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()


class Visitor(Base):
    """Ziyaretci LOG kaydi — guvenlik kaydeder, dairenin TEK hedef sakinine
    BILGILENDIRME push'u gider. Onay/red YOKTUR; kayit bir gunluk girisidir.

    GSM'e hazir: hedef sakinin telefonu app_user.telefon'da; ileride gercek
    arama adimi ayri kolon/tablo ile eklenebilir (bkz. migration notu).
    """

    __tablename__ = "visitor"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_visitor_id_tenant"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_visitor_unit",
        ),
        ForeignKeyConstraint(
            ["kaydeden_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_visitor_kaydeden",
        ),
        ForeignKeyConstraint(
            ["target_resident_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_visitor_target",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    ziyaretci_ad: Mapped[str] = mapped_column(Text, nullable=False)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    kaydeden_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    # Guvenligin sectigi TEK hedef sakin: bilgilendirme push'u + gorunurluk YALNIZ onda.
    target_resident_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    # Cikis damgasi (G3). NULL = ziyaretci HALA ICERIDE.
    cikis_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


class Kargo(Base):
    """Kargo/paket takibi — guvenlik kaydeder, dairenin sakini teslim alir.

    visitor ile ayni desen (unit-bazli, push, tam gecmis); akis onay/red degil
    TESLIM: bekliyor -> teslim_alindi. Opsiyonel paket fotografi mevcut
    presign akisiyla yuklenir (foto_key; task/complaint/announcement deseni).
    """

    __tablename__ = "kargo"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_kargo_id_tenant"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_kargo_unit",
        ),
        ForeignKeyConstraint(
            ["kaydeden_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_kargo_kaydeden",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (teslim_alan_user_id); tenant_id korunur.
        ForeignKeyConstraint(
            ["teslim_alan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_kargo_teslim_alan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    firma: Mapped[str] = mapped_column(Text, nullable=False)
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        KARGO_DURUM, nullable=False, server_default=text("'bekliyor'")
    )
    kaydeden_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    teslim_alan_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    teslim_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


class UnitAccessPermission(Base):
    """Yonetici TEK-SEFERLIK ziyaretci/paket goruntuleme izni.

    Gizlilik: ziyaretci/kargo VARSAYILAN olarak yonetici'ye kapali. Yonetici
    bir daireye izin TALEBI acar -> dairenin sakini onaylar/reddeder. Onay =
    tek-kullanimlik izin (used=false); yonetici o dairenin kayitlarini ILK
    okudugunda tuketilir (used=true). Sureye bagli DEGIL (one-shot).
    Tek satir talep+izin yasam dongusunu tutar (durum).
    """

    __tablename__ = "unit_access_permission"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_uap_id_tenant"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_uap_unit",
        ),
        ForeignKeyConstraint(
            ["granted_to_yonetici_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_uap_yonetici",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (granted_by_resident_user_id).
        ForeignKeyConstraint(
            ["granted_by_resident_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_uap_resident",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    granted_to_yonetici_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    granted_by_resident_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    durum: Mapped[str] = mapped_column(
        ACCESS_REQUEST_DURUM, nullable=False, server_default=text("'bekliyor'")
    )
    used: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    requested_at = _created_at()
    decided_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    used_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


class OrtakAlan(Base):
    """Rezerve edilebilir ortak alan (havuz/teras/toplanti odasi).

    Silme = SOFT-DELETE (aktif=false): rezervasyon gecmisi alanini korur
    (rezervasyon.alan_id FK RESTRICT hard-delete'i engeller).
    """

    __tablename__ = "ortak_alan"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_ortak_alan_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_ortak_alan_tenant_ad"),
        CheckConstraint("kapanis > acilis", name="ck_ortak_alan_saat"),
        CheckConstraint(
            "slot_dakika > 0 AND slot_dakika <= 1440", name="ck_ortak_alan_slot"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    # MUSAITLIK: her gun [acilis, kapanis) araligi, slot_dakika slot uzunlugu.
    # Varsayilan tum-gun (saat girilmemis alan da rezerve edilebilir).
    acilis = mapped_column(Time, nullable=False, server_default=text("'00:00'"))
    kapanis = mapped_column(Time, nullable=False, server_default=text("'23:59:59'"))
    slot_dakika: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("60")
    )
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class Rezervasyon(Base):
    """Ortak alan rezervasyonu — sakin bos slotu ANINDA rezerve eder (onay yok).

    Cakisma engeli DB'de: partial EXCLUDE (gist) — ayni alanin ONAYLI iki
    rezervasyonu zaman araliginda kesisemez (bkz. migration 9z5). Kisit yalniz
    durum='onaylandi' satirlara uygulanir; INSERT aninda devreye girer, es
    zamanli iki cakisan talepten yalniz biri basarir (digeri 23P01 -> API 409).
    Iptal (durum='iptal') slotu bosaltir (kisit disi kalir).
    """

    __tablename__ = "rezervasyon"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_rezervasyon_id_tenant"),
        CheckConstraint("bitis > baslangic", name="ck_rezervasyon_aralik"),
        CheckConstraint("kisi_sayisi > 0", name="ck_rezervasyon_kisi"),
        ForeignKeyConstraint(
            ["alan_id", "tenant_id"],
            ["ortak_alan.id", "ortak_alan.tenant_id"],
            ondelete="RESTRICT",
            name="fk_rezervasyon_alan",
        ),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_rezervasyon_unit",
        ),
        ForeignKeyConstraint(
            ["talep_eden_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_rezervasyon_talep_eden",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (iptal_eden_user_id); tenant_id korunur.
        ForeignKeyConstraint(
            ["iptal_eden_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_rezervasyon_iptal_eden",
        ),
        # EXCLUDE USING gist kisiti DDL'de (/contracts); SQLAlchemy'de yalniz
        # dokumantasyon — sorgu katmani kisiti uretmez.
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    alan_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    talep_eden_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    tarih = mapped_column(Date, nullable=False)
    baslangic = mapped_column(Time, nullable=False)
    bitis = mapped_column(Time, nullable=False)
    kisi_sayisi: Mapped[int] = mapped_column(Integer, nullable=False)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        REZERVASYON_DURUM, nullable=False, server_default=text("'onaylandi'")
    )
    iptal_eden_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    iptal_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


class Etkinlik(Base):
    """Etkinlik (cenaze/mac izleme vb.) — yonetici olusturur, sakinler RSVP.

    Katilim SAYISI seffaftir (herkes gorur); kim-katiliyor listesi URUN
    GEREGI paylasilmaz — yalniz sayi (bkz. routers/events.py).
    """

    __tablename__ = "etkinlik"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_etkinlik_id_tenant"),
        ForeignKeyConstraint(
            ["olusturan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_etkinlik_olusturan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    aciklama: Mapped[str] = mapped_column(Text, nullable=False)
    # Baslangic; bitis_zamani NULL ise etkinlik anliktir (bitis = baslangic).
    tarih = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    bitis_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    konum: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Opsiyonel gorsel — duyuru/site kurali ile AYNI presign mekanizmasi.
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Orijinal dil — bkz. Announcement.kaynak_dil. (konum CEVRILMEZ: yer adi.)
    kaynak_dil: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'tr'")
    )
    olusturan_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class EtkinlikKatilim(Base):
    """Etkinlik RSVP'si — kullanici basina TEK kayit (UNIQUE), degistirilebilir
    (upsert). Etkinlik silinince RSVP'ler CASCADE ile gider."""

    __tablename__ = "etkinlik_katilim"
    __table_args__ = (
        ForeignKeyConstraint(
            ["etkinlik_id", "tenant_id"],
            ["etkinlik.id", "etkinlik.tenant_id"],
            ondelete="CASCADE",
            name="fk_katilim_etkinlik",
        ),
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_katilim_user",
        ),
        UniqueConstraint(
            "tenant_id", "etkinlik_id", "user_id",
            name="uq_katilim_tenant_etkinlik_user",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    etkinlik_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    durum: Mapped[str] = mapped_column(KATILIM_DURUM, nullable=False)
    created_at = _created_at()
    updated_at = _created_at()


class SiteKurali(Base):
    """Site kurali — blog-tarzi icerik (yonetici CRUD, herkes okur).

    sira ile siralanir; baslikta ILIKE arama (router). Silme HARD DELETE:
    salt icerik — operasyonel gecmis/FK tasimaz (karar, bkz. migration 9z7).
    """

    __tablename__ = "site_kurali"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_site_kurali_id_tenant"),
        CheckConstraint("sira >= 0", name="ck_site_kurali_sira"),
        ForeignKeyConstraint(
            ["olusturan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_site_kurali_olusturan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    icerik: Mapped[str] = mapped_column(Text, nullable=False)
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Orijinal dil — bkz. Announcement.kaynak_dil.
    kaynak_dil: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'tr'")
    )
    sira: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )
    olusturan_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    created_at = _created_at()
    updated_at = _created_at()


class DisHizmet(Base):
    """Dis Hizmetler — site yoneticisinin girdigi guvenilir esnaf/hizmet kisisi
    (cilingir/elektrik/tesisat...). Yonetici CRUD; tum roller okur. app_user FK
    YOK — tenant CASCADE ile temiz silinir. Bolum notu tenant.dis_hizmet_notu."""

    __tablename__ = "dis_hizmet"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_dis_hizmet_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    tur: Mapped[str] = mapped_column(Text, nullable=False)
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    soyad: Mapped[str] = mapped_column(Text, nullable=False)
    telefon: Mapped[str] = mapped_column(Text, nullable=False)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()
    updated_at = _created_at()


class UserDevice(Base):
    __tablename__ = "user_device"
    __table_args__ = (
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_user_device_user",
        ),
        UniqueConstraint("tenant_id", "fcm_token", name="uq_user_device_tenant_token"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    fcm_token: Mapped[str] = mapped_column(Text, nullable=False)
    platform: Mapped[str] = mapped_column(DEVICE_PLATFORM, nullable=False)
    # CIHAZIN dili — push metni GONDERIM aninda buradan cozulur (tur 16).
    # Kullanici degil cihaz bazli: ayni kisinin iki cihazi farkli dilde olabilir.
    dil: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'tr'"))
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


class Integration(Base):
    """Dis sistem entegrasyon konfigurasyonu (C1b).

    admin/yonetici bir dis ucu (megafon/akilli-ev/generic webhook) tanimlar;
    tetiklenince SSRF-korumali HTTP istegi gonderilir. `auth_secret_enc` KEK ile
    sifreli saklanir ve GET'te ASLA donmez (write-only). channel_type C1a kanal
    soyutlamasini genisletir (phone + webhook/megaphone/smarthome).
    """

    __tablename__ = "integration"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_integration_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    channel_type: Mapped[str] = mapped_column(
        INTEGRATION_CHANNEL, nullable=False, server_default=text("'webhook'")
    )
    endpoint_url: Mapped[str] = mapped_column(Text, nullable=False)
    http_method: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'POST'")
    )
    headers_json: Mapped[dict] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    auth_type: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'none'")
    )
    # KEK ile sifreli auth sirri (write-only); GET yanitinda donmez.
    auth_secret_enc: Mapped[str | None] = mapped_column(Text, nullable=True)
    payload_template: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("''")
    )
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


class UnitComplaint(Base):
    """Sakin -> HEDEF DAIRE sikayeti (D1). TAM ANONIM.

    `complainant_user_id` YALNIZ ic spam korumasi + RLS icindir; HICBIR
    serializer/uc bu alani DONDURMEZ (yonetici/admin dahil kimse sikayet edeni
    goremez). Yonetimin ayri `Complaint` modulunden BAGIMSIZDIR.
    """

    __tablename__ = "unit_complaint"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_unit_complaint_id_tenant"),
        ForeignKeyConstraint(
            ["target_unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_unit_complaint_target",
        ),
        ForeignKeyConstraint(
            ["complainant_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_unit_complaint_complainant",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    target_unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    # IC ALAN — asla serialize edilmez (bkz. schemas.UnitComplaintOut).
    complainant_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    kategori: Mapped[str] = mapped_column(
        UNIT_COMPLAINT_KATEGORI, nullable=False, server_default=text("'diger'")
    )
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        UNIT_COMPLAINT_DURUM, nullable=False, server_default=text("'acik'")
    )
    created_at = _created_at()
    updated_at = _created_at()


class UnitComplaintOkuma(Base):
    """Sikayet okuma durumu — KISI BASINA (P24).

    Satir VARSA o kullanici o sikayeti okumustur; YOKSA okunmamistir. Boylece
    yeni sikayet dogal olarak okunmamis baslar (ek yazma yok) ve bir
    yoneticinin okumasi digerinin triyaj kuyrugunu bosaltmaz.
    """

    __tablename__ = "unit_complaint_okuma"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "unit_complaint_id", "user_id", name="uq_unit_complaint_okuma"
        ),
        ForeignKeyConstraint(
            ["unit_complaint_id", "tenant_id"],
            ["unit_complaint.id", "unit_complaint.tenant_id"],
            ondelete="CASCADE",
            name="fk_unit_complaint_okuma_complaint",
        ),
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_unit_complaint_okuma_user",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_complaint_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    okundu_at = _created_at()


# --------------------------------------------------------------------------- #
class VehiclePass(Base):
    """Arac giris/cikis gecisi (G1) — TEK satir gecisin tamamini tutar.

    `cikis_zamani IS NULL` => arac ICERIDE (acik gecis). Otopark DOLULUGU (G4)
    bu acik satirlarin sayimidir; ayri sayac yoktur. `plaka` NORMALIZE saklanir
    (bosluksuz + BUYUK harf; crud_helpers.norm_plaka) ve ayni plakadan ayni
    anda en fazla bir acik gecis olabilir (kismi unique indeks -> 409).
    """

    __tablename__ = "vehicle_pass"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_vehicle_pass_id_tenant"),
        CheckConstraint("plaka ~ '^[A-Z0-9]{2,20}$'", name="ck_vehicle_pass_plaka"),
        CheckConstraint(
            "cikis_zamani IS NULL OR cikis_zamani >= giris_zamani",
            name="ck_vehicle_pass_cikis",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (unit_id); tenant_id korunur.
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="SET NULL",
            name="fk_vehicle_pass_unit",
        ),
        ForeignKeyConstraint(
            ["kaydeden_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_vehicle_pass_kaydeden",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    plaka: Mapped[str] = mapped_column(Text, nullable=False)
    arac_tanim: Mapped[str | None] = mapped_column(Text, nullable=True)
    giris_zamani = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=text("now()")
    )
    cikis_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    unit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    ziyaretci_mi: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    # ANPR gecisini BIR INSAN KAYDETMEZ (0011) — bu yuzden nullable.
    # `ck_vehicle_pass_kaydeden` kisiti elle kayitta ZORUNLU tutmayi surdurur:
    # kolonu nullable yapmak izlenebilirligi kaybetmek DEMEK DEGILDIR.
    kaydeden_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    # Gecisin kokeni: elle kayit mi, plaka okuma mi (0011).
    kaynak: Mapped[str] = mapped_column(
        GECIS_KAYNAK, nullable=False, server_default=text("'manuel'")
    )
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class Violation(Base):
    """Ihlal kaydi (G2) — site_kurali METNINDEN bagimsiz, somut ihlal izi.

    durum akisi: yeni -> inceleniyor -> kapatildi. 'kapatildi' TERMINAL ve
    YALNIZ admin kapatir (rol DB'de degil token'da => API katmani zorlar).
    """

    __tablename__ = "violation"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_violation_id_tenant"),
        ForeignKeyConstraint(
            ["olusturan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_violation_olusturan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    kaynak: Mapped[str] = mapped_column(
        VIOLATION_KAYNAK, nullable=False, server_default=text("'manuel'")
    )
    konum: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        VIOLATION_DURUM, nullable=False, server_default=text("'yeni'")
    )
    olusturan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class AuditLog(Base):
    """KVKK degistirilemez (append-only) denetim kaydi (migration 0002).

    Uygulama YALNIZ INSERT eder (app_rw UPDATE/DELETE alamaz — setup_app_role
    REVOKE eder). `tenant_id` platform olaylari icin NULL olabilir. `actor_user_id`
    FK'SIZDIR (bilincli): kullanici anonimlestirilse/silinse de iz kalir. `meta`
    yalniz id/alan-adi tutar — ASLA kisisel veri DEGERI (KVKK)."""

    __tablename__ = "audit_log"

    id: Mapped[uuid.UUID] = _pk()
    ts = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=text("now()")
    )
    # FK yok modelde de: tenant silinince DB CASCADE temizler (DDL'de tanimli).
    tenant_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    actor_rol: Mapped[str | None] = mapped_column(Text, nullable=True)
    action: Mapped[str] = mapped_column(Text, nullable=False)
    resource_type: Mapped[str | None] = mapped_column(Text, nullable=True)
    resource_id: Mapped[str | None] = mapped_column(Text, nullable=True)
    meta: Mapped[dict] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )


# --------------------------------------------------------------------------- #
class TransparencyPublication(Base):
    """Seffaflik Panosu aylik yayin durumu (migration 0003). YALNIZ yayin bayragi;
    finansal ozet server-side hesaplanir (kisisel veri TUTMAZ)."""

    __tablename__ = "transparency_publication"
    __table_args__ = (
        UniqueConstraint("tenant_id", "ay", name="uq_transparency_tenant_ay"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ay: Mapped[str] = mapped_column(Text, nullable=False)  # 'YYYY-MM'
    yayin: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    updated_at = _created_at()


__all__ = [
    "Base",
    "Tenant",
    "AuditLog",
    "TransparencyPublication",
    "AppUser",
    "Shift",
    "Checkpoint",
    "PatrolPlan",
    "PatrolPlanCheckpoint",
    "PatrolWindow",
    "ScanEvent",
    "Notification",
    "Task",
    "TaskCompletion",
    "Asset",
    "AssetCheckout",
    "Unit",
    "BuildingBlock",
    "UnitResident",
    "DuesAssessment",
    "DuesPayment",
    "PaymentWebhookEvent",
    "Announcement",
    "Visitor",
    "Kargo",
    "OrtakAlan",
    "Rezervasyon",
    "Etkinlik",
    "EtkinlikKatilim",
    "SiteKurali",
    "UserDevice",
    "USER_ROLE",
    "GUN_TIPI",
    "PATROL_WINDOW_DURUM",
    "NOTIFICATION_TIP",
    "ASSET_KATEGORI",
    "ASSET_DURUM",
    "RESIDENT_ROL",
    "DUES_YONTEM",
    "DUES_DURUM",
    "DEVICE_PLATFORM",
    "KARGO_DURUM",
    "REZERVASYON_DURUM",
    "KATILIM_DURUM",
    "Integration",
    "INTEGRATION_CHANNEL",
    "UnitComplaint",
    "UNIT_COMPLAINT_KATEGORI",
    "UNIT_COMPLAINT_DURUM",
    "PlatformSupportTicket",
]


# --------------------------------------------------------------------------- #
class PlatformSupportTicket(Base):
    """Yonetici -> Yonetio platform ekibi destek bileti (migration 0004).
    Yanit/durum guncellemesi YALNIZ admin'in SECURITY DEFINER fonksiyonundan
    gecer (app_rw'de UPDATE grant yok)."""

    __tablename__ = "platform_support_ticket"

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    # FK yok (audit ile ayni gerekce): acan silinse de bilet kaydi kalir.
    acan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    konu: Mapped[str] = mapped_column(Text, nullable=False)
    aciklama: Mapped[str] = mapped_column(Text, nullable=False)
    durum: Mapped[str] = mapped_column(Text, nullable=False, default="acik")
    admin_cevap: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Destek gorselleri (0006/WP-G) — MinIO obje anahtarlari (tenant-onekli).
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    admin_cevap_foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
# Icerik cevirisi (migration 0007) — yayin iceriginin 7 dildeki karsiligi.
#
# Sema uc tabloda AYNIDIR; entity basina ayri tablo olmasinin gerekcesi
# (composite FK + CASCADE) migration 0007'nin modul notundadir. Uygulama kodu
# bu tablolara `app/ceviri.py` TIPLER kaydindan uretilen SQL ile erisir
# (tek yol, uc entity); asagidaki modeller SEMAYI BELGELER ve ORM
# sorgularina aciktir.
# --------------------------------------------------------------------------- #
class _CeviriTaban:
    """Ortak ceviri kolonlari (bkz. 0007). Karma sinif — tablo DEGIL."""

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    # Hedef dil (ISO 639-1); kume CHECK ile kisitli (7 dil).
    dil: Mapped[str] = mapped_column(Text, nullable=False)
    # Cevrilmis alanlar: {"baslik": "...", "govde"/"icerik"/"aciklama": "..."}
    alanlar: Mapped[dict] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    durum: Mapped[str] = mapped_column(
        CEVIRI_DURUM, nullable=False, server_default=text("'bekliyor'")
    )
    # Metin MAKINE ciktisi mi (elle duzeltmede false olur).
    cevirildi_mi: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    # Yonetici elle duzeltti: kaynak metin degismedikce KORUNUR.
    elle_duzeltildi: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    # Cevirinin uretildigi kaynak metnin ozeti (elle duzeltme kuralinin anahtari).
    kaynak_hash: Mapped[str] = mapped_column(Text, nullable=False)
    hata_mesaji: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()
    updated_at = _created_at()


class AnnouncementCeviri(_CeviriTaban, Base):
    __tablename__ = "announcement_ceviri"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "announcement_id", "dil", name="uq_announcement_ceviri"
        ),
        ForeignKeyConstraint(
            ["announcement_id", "tenant_id"],
            ["announcement.id", "announcement.tenant_id"],
            ondelete="CASCADE",
            name="announcement_ceviri_announcement_id_tenant_id_fkey",
        ),
    )

    announcement_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )


class SiteKuraliCeviri(_CeviriTaban, Base):
    __tablename__ = "site_kurali_ceviri"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "site_kurali_id", "dil", name="uq_site_kurali_ceviri"
        ),
        ForeignKeyConstraint(
            ["site_kurali_id", "tenant_id"],
            ["site_kurali.id", "site_kurali.tenant_id"],
            ondelete="CASCADE",
            name="site_kurali_ceviri_site_kurali_id_tenant_id_fkey",
        ),
    )

    site_kurali_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )


class EtkinlikCeviri(_CeviriTaban, Base):
    __tablename__ = "etkinlik_ceviri"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "etkinlik_id", "dil", name="uq_etkinlik_ceviri"
        ),
        ForeignKeyConstraint(
            ["etkinlik_id", "tenant_id"],
            ["etkinlik.id", "etkinlik.tenant_id"],
            ondelete="CASCADE",
            name="etkinlik_ceviri_etkinlik_id_tenant_id_fkey",
        ),
    )

    etkinlik_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)


# --------------------------------------------------------------------------- #
class AnprApiKey(Base):
    """Tenant basina ANPR giris anahtari (0011).

    Kamera kutusu JWT tasiyamaz (kullanici oturumu yok, token yenilenemez);
    uzun omurlu bir anahtar gerekir. Anahtar `<kimlik>.<sir>` bicimindedir:
    `kimlik` ACIK saklanir (tenant bilinmeden aranabilmesi icin, global
    TEKIL), `sir` yalniz sha256 OZETIYLE. Anahtarin kendisi HICBIR YERDE
    saklanmaz — olusturma yanitinda BIR KEZ gosterilir.
    """

    __tablename__ = "anpr_api_key"
    __table_args__ = (
        UniqueConstraint("kimlik", name="uq_anpr_api_key_kimlik"),
        UniqueConstraint("id", "tenant_id", name="uq_anpr_api_key_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    kimlik: Mapped[str] = mapped_column(Text, nullable=False)
    sir_hash: Mapped[str] = mapped_column(Text, nullable=False)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    son_kullanim = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class AnprEvent(Base):
    """Gelen HAM plaka okuma olayi + islenme sonucu (0011).

    `(tenant_id, kaynak, kaynak_olay_id)` TEKILDIR ve bu bir susleme degil,
    P15'te OLCULMUS bir gerekliliktir: Frigate ayni olayi `update` ve `end`
    olarak birden cok kez yayinlar. Tekillik olmasa tek bir aracin girisi iki
    gecis kaydi acardi.

    Olay bir DEFTER kaydidir: islense de islenmese de saklanir. Iliskili
    gecis silinirse `vehicle_pass_id` NULL'a duser, olay KALIR.
    """

    __tablename__ = "anpr_event"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "kaynak", "kaynak_olay_id", name="uq_anpr_event_kaynak"
        ),
        ForeignKeyConstraint(
            ["vehicle_pass_id", "tenant_id"],
            ["vehicle_pass.id", "vehicle_pass.tenant_id"],
            ondelete="SET NULL",
            name="anpr_event_vehicle_pass_id_tenant_id_fkey",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    kaynak: Mapped[str] = mapped_column(Text, nullable=False)
    kaynak_olay_id: Mapped[str] = mapped_column(Text, nullable=False)
    plaka: Mapped[str] = mapped_column(Text, nullable=False)
    plaka_ham: Mapped[str | None] = mapped_column(Text, nullable=True)
    zaman = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    kamera: Mapped[str | None] = mapped_column(Text, nullable=True)
    yon: Mapped[str] = mapped_column(
        ANPR_YON, nullable=False, server_default=text("'bilinmiyor'")
    )
    guven: Mapped[float | None] = mapped_column(Numeric(4, 3), nullable=True)
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        ANPR_OLAY_DURUM, nullable=False, server_default=text("'islendi'")
    )
    durum_nedeni: Mapped[str | None] = mapped_column(Text, nullable=True)
    vehicle_pass_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    ham: Mapped[dict] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    created_at = _created_at()


# ======================= P27 "Tanimlar" katmani ============================= #
# Yedi kayit defteri. PARA HER YERDE `bigint` KURUS; acilis bakiyeleri
# ISARETSIZ tutar + AYRI yon (`borc|alacak`) tasir — "-500" bir firmada
# "biz mi borcluyuz, o mu" sorusunu yanitlamaz.
class Kasa(Base):
    """Kasa/banka hesabi tanimi (P27)."""

    __tablename__ = "kasa"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_kasa_id_tenant"),
        UniqueConstraint("tenant_id", "kod", name="uq_kasa_tenant_kod"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    kod: Mapped[str] = mapped_column(Text, nullable=False)
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    acilis_tarihi = mapped_column(Date, nullable=True)
    acilis_bakiye_kurus: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default=text("0")
    )
    #: IBAN/banka alanlari YALNIZ banka kasasinda dolabilir (CHECK zorlar):
    #: banka olmayan bir kasada dolu IBAN, odemeyi yanlis hesaba yonlendirirdi.
    banka_mi: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    iban: Mapped[str | None] = mapped_column(Text, nullable=True)
    banka_adi: Mapped[str | None] = mapped_column(Text, nullable=True)
    sube: Mapped[str | None] = mapped_column(Text, nullable=True)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


class GelirGiderGrup(Base):
    """Gelir/gider tanimlarinin ust kirilimi (P27)."""

    __tablename__ = "gelir_gider_grup"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_gg_grup_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_gg_grup_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


class GelirGiderTanim(Base):
    """Gelir/gider kalemi tanimi (P27) — P28 borclandirmasinin TURUDUR.

    `dagitim_sekli` YALNIZ gider/her_ikisi icin anlamlidir (CHECK zorlar): bir
    GELIR kalemi bagimsiz bolumlere "dagitilmaz", tahsil edilir.
    """

    __tablename__ = "gelir_gider_tanim"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_gg_tanim_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_gg_tanim_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    tip: Mapped[str] = mapped_column(GELIR_GIDER_TIP, nullable=False)
    grup_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    dagitim_sekli: Mapped[str | None] = mapped_column(
        GELIR_GIDER_DAGITIM, nullable=True
    )
    #: (P28) Borc KIME yazilir: aidat/faturalar kiraci oncelikli, yatirim/
    #: demirbas malik. Kural TANIMDA durur — borclandirma aninda secilseydi
    #: ayni kalem farkli aylarda farkli kisiye yazilabilirdi.
    hedef_kurali: Mapped[str] = mapped_column(
        BORC_HEDEF_KURALI, nullable=False, server_default=text("'kiraci_oncelikli'")
    )
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


class Firma(Base):
    """Tedarikci/hizmet firmasi kaydi (P27)."""

    __tablename__ = "firma"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_firma_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_firma_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    #: 10 hane (tuzel) ya da 11 hane (sahis/TC) — ikisi de kabul (CHECK).
    vergi_no: Mapped[str | None] = mapped_column(Text, nullable=True)
    vergi_dairesi: Mapped[str | None] = mapped_column(Text, nullable=True)
    telefon: Mapped[str | None] = mapped_column(Text, nullable=True)
    email: Mapped[str | None] = mapped_column(Text, nullable=True)
    adres: Mapped[str | None] = mapped_column(Text, nullable=True)
    yetkili_ad: Mapped[str | None] = mapped_column(Text, nullable=True)
    yetkili_telefon: Mapped[str | None] = mapped_column(Text, nullable=True)
    acilis_bakiye_kurus: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default=text("0")
    )
    acilis_bakiye_yon: Mapped[str] = mapped_column(
        BAKIYE_YON, nullable=False, server_default=text("'borc'")
    )
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


class PersonelKayit(Base):
    """Personel kaydi (P27) — `app_user`DAN AYRI.

    Her personelin uygulama hesabi yoktur (temizlik, bahcivan) ve her
    kullanici personel degildir (sakin). Ortusenler `app_user_id` ile
    BAGLANIR; hesap silinirse kayit DURUR (bordro gecmisi kimlik kaydina
    bagli olmamali).
    """

    __tablename__ = "personel_kayit"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_personel_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    tc: Mapped[str | None] = mapped_column(Text, nullable=True)
    gorev: Mapped[str | None] = mapped_column(Text, nullable=True)
    telefon: Mapped[str | None] = mapped_column(Text, nullable=True)
    email: Mapped[str | None] = mapped_column(Text, nullable=True)
    giris_tarihi = mapped_column(Date, nullable=True)
    cikis_tarihi = mapped_column(Date, nullable=True)
    maas_kurus: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    app_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


class AracKayit(Base):
    """KAYITLI arac (P27) — P17 rozetlerinin "kayitli mi" kaynagi.

    Plaka `vehicle_pass` ile AYNI kuralla normalize saklanir (bosluksuz +
    BUYUK); iki farkli normalizasyon iki farkli cevap verirdi.
    """

    __tablename__ = "arac_kayit"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_arac_id_tenant"),
        UniqueConstraint("tenant_id", "plaka", name="uq_arac_tenant_plaka"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    plaka: Mapped[str] = mapped_column(Text, nullable=False)
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    unit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    marka: Mapped[str | None] = mapped_column(Text, nullable=True)
    model: Mapped[str | None] = mapped_column(Text, nullable=True)
    renk: Mapped[str | None] = mapped_column(Text, nullable=True)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


class SayacAna(Base):
    """ANA sayac (P27) — site geneli; ortak alan tuketimi buradan dagitilir."""

    __tablename__ = "sayac_ana"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_sayac_ana_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_sayac_ana_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    tip: Mapped[str] = mapped_column(
        SAYAC_TIP, nullable=False, server_default=text("'diger'")
    )
    tesisat_no: Mapped[str | None] = mapped_column(Text, nullable=True)
    ortak_alan_dagitim: Mapped[str | None] = mapped_column(
        GELIR_GIDER_DAGITIM, nullable=True
    )
    ortak_alan_yuzde = mapped_column(Numeric(5, 2), nullable=True)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


class SayacBolum(Base):
    """BAGIMSIZ BOLUM sayaci (P27) — bir daireye ait, bir ana sayaca bagli.

    Ana sayacla TEK TABLODA birlestirilmedi: ana sayaca ozgu alanlar (ortak
    alan yuzdesi) daire satirlarinda anlamsizca null kalirdi.
    """

    __tablename__ = "sayac_bolum"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_sayac_bolum_id_tenant"),
        UniqueConstraint(
            "tenant_id", "unit_id", "ana_sayac_id", name="uq_sayac_bolum_unit_ana"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    ana_sayac_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    tesisat_no: Mapped[str | None] = mapped_column(Text, nullable=True)
    ilk_okuma = mapped_column(Numeric(12, 3), nullable=True)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


# ===================== P29 FINANSAL HAREKET DEFTERI ========================= #
class FinansalHareket(Base):
    """TEK DEFTER (P29): tahsilat, gider, gelir, virman, iade, acilis.

    Alti ayri tablo YERINE tek defter, cunku "kasa bakiyesi = hareket
    toplami" tutarliligi ancak TEK kaynak varken KANITLANABILIR; alti
    tabloda bakiye, alti toplami dogru birlestirmeye bagli olurdu ve bir
    tabloyu unutmak SESSIZ bir fark uretirdi.

    TUTAR HER ZAMAN POZITIF; isaret `yon` sutunundadir. Negatif tutar
    saklamak "iade" ile "eksi gider"i ayirt edilemez kilardi.

    VIRMAN IKI SATIRDIR (cikis + giris), `virman_grup_id` ile eslesir.
    IADE, iade ettigi hareketi `iade_edilen_id` ile GOSTERIR — "hangi
    tahsilat iade edildi" sorusu aciklama metnine birakilamaz.

    IDEMPOTENCY (P64): `idempotency_key` NULLABLE'dir ve tekillik KISMI
    bir indeksle zorlanir (`uq_hareket_tenant_idem`, 0028). Zorunlu
    kilmak, tabloda duran GECMIS kayitlara uydurma kimlik yazmak
    demekti; kimlik gonderilmediginde eski davranis aynen surer.
    `idem_satir` islemin KACINCI satiri oldugudur: virman iki, toplu
    tahsilat N satir yazar ve kimligi tek satira yazmak, tekrar gelen
    istekte islemin oteki satirlarini bulunamaz kilardi.

    """

    __tablename__ = "finansal_hareket"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_hareket_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    tip: Mapped[str] = mapped_column(HAREKET_TIP, nullable=False)
    yon: Mapped[str] = mapped_column(HAREKET_YON, nullable=False)
    tutar_kurus: Mapped[int] = mapped_column(BigInteger, nullable=False)
    tarih = mapped_column(Date, nullable=False, server_default=text("CURRENT_DATE"))
    kasa_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    unit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    firma_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    gelir_gider_tanim_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    assessment_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    belge_no: Mapped[str | None] = mapped_column(Text, nullable=True)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    virman_grup_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    iade_edilen_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    #: (P154 / Asama 10) IPTAL SATIRI, IPTAL ETTIGI SATIRI gosterir —
    #: `iade_edilen_id` ile AYNI YON. Iki benzer bagi iki farkli yonde
    #: tutmak, her okuyanin durup bakmasi demekti.
    #:
    #: IPTAL ILE IADE AYRI SEYLER: iade musteriye para donusudur (gercek
    #: bir hareket), iptal ise bir KAYIT DUZELTMESIDIR.
    ters_kayit_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    kaydeden_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    #: Vezne yazmalarinda CIFT KAYIT korumasi (P64). Bkz. sinif belgesi.
    idempotency_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    idem_satir: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    created_at = _created_at()


class IcraDosyasi(Base):
    """Icra dosyasi (P29) — PARA HAREKETI DEGIL, hukuki surec kaydi.

    Borclar zaten `dues_assessment`ta durur ve buraya KOPYALANMAZ: iki yerde
    tutulan borc, biri guncellenip digeri unutuldugunda hangi rakamin dogru
    oldugunu belirsiz birakirdi.
    """

    __tablename__ = "icra_dosyasi"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_icra_id_tenant"),
        UniqueConstraint("tenant_id", "dosya_no", name="uq_icra_tenant_dosya_no"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    dosya_no: Mapped[str] = mapped_column(Text, nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    veris_tarihi = mapped_column(Date, nullable=True)
    avukat: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        ICRA_DURUM, nullable=False, server_default=text("'acik'")
    )
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()
    updated_at = _created_at()


# ======================= P32 MESAJ SABLONU / GECMIS ========================= #
class MesajSablonu(Base):
    """SMS/e-posta sablonu (P32) — etiket interpolasyonlu govde.

    `amac` SABLONDA durur, gonderim aninda secilmez: ayni sablonun bir gun
    pazarlama bir gun operasyonel gonderilmesi, riza denetimini anlamsiz
    kilardi.
    """

    __tablename__ = "mesaj_sablonu"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_sablon_id_tenant"),
        UniqueConstraint(
            "tenant_id", "kanal", "ad", name="uq_sablon_tenant_kanal_ad"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    kanal: Mapped[str] = mapped_column(MESAJ_KANAL, nullable=False)
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    konu: Mapped[str | None] = mapped_column(Text, nullable=True)
    govde: Mapped[str] = mapped_column(Text, nullable=False)
    amac: Mapped[str] = mapped_column(
        MESAJ_AMAC, nullable=False, server_default=text("'operasyonel'")
    )
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


class MesajGonderim(Base):
    """Gonderim GECMISI (P32).

    GONDERILEN METIN KOPYALANIR (`govde`), sablona referans YETMEZ: sablon
    sonradan degistirilirse gecmis kayit "ne gonderdik" sorusuna YANLIS
    cevap verirdi — bu bir KVKK ve hukuk sorusudur (bildirim kaniti).
    """

    __tablename__ = "mesaj_gonderim"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_gonderim_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    sablon_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    kanal: Mapped[str] = mapped_column(MESAJ_KANAL, nullable=False)
    amac: Mapped[str] = mapped_column(MESAJ_AMAC, nullable=False)
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    hedef: Mapped[str] = mapped_column(Text, nullable=False)
    konu: Mapped[str | None] = mapped_column(Text, nullable=True)
    govde: Mapped[str] = mapped_column(Text, nullable=False)
    durum: Mapped[str] = mapped_column(
        MESAJ_DURUM, nullable=False, server_default=text("'kuyrukta'")
    )
    hata: Mapped[str | None] = mapped_column(Text, nullable=True)
    saglayici: Mapped[str | None] = mapped_column(Text, nullable=True)
    gonderen_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    #: (P154 / Asama 9) KUYRUK DEFTERI. Ayri bir kuyruk tablosu acmak, ayni
    #: satiri iki yerde tutmak ve "gecmis" ile "kuyruk" arasinda hangisinin
    #: dogru oldugu sorusunu uretmek olurdu — `durum='kuyrukta'` zaten
    #: enum'da vardi, eksik olan yalnizca ZAMANLAMAYDI.
    deneme: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )
    son_deneme_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


# ========================== P33 YONETISIM MODULLERI ========================= #
class KararDefteri(Base):
    """Yonetim kurulu karar defteri (P33)."""

    __tablename__ = "karar_defteri"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_karar_id_tenant"),
        UniqueConstraint("tenant_id", "karar_no", name="uq_karar_tenant_no"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    karar_no: Mapped[str] = mapped_column(Text, nullable=False)
    konu: Mapped[str] = mapped_column(Text, nullable=False)
    tarih = mapped_column(Date, nullable=False, server_default=text("CURRENT_DATE"))
    metin: Mapped[str] = mapped_column(Text, nullable=False)
    baskan_ad: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()
    updated_at = _created_at()


class KararUyesi(Base):
    """Karara katilan uye (P33).

    UYE ADI SAKLANIR, kullaniciya referans DEGIL: uye site disindan biri
    olabilir (denetci, avukat) ve kullanici kaydi silinse bile gecmis karar
    KIMLERIN katildigini gostermeli. Ayri tablo olmasi da bilincli — tek
    metin sutununa virgulle yazmak, "bu karara kim katildi" sorgusunu metin
    aramasina cevirirdi.
    """

    __tablename__ = "karar_uyesi"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_karar_uyesi_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    karar_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    gorev: Mapped[str | None] = mapped_column(Text, nullable=True)


class TenantDokuman(Base):
    """Site dokuman arsivi (P33) — YALNIZ META; dosya MinIO'da."""

    __tablename__ = "tenant_dokuman"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_dokuman_id_tenant"),
        UniqueConstraint(
            "tenant_id", "obje_anahtari", name="uq_dokuman_tenant_anahtar"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    obje_anahtari: Mapped[str] = mapped_column(Text, nullable=False)
    icerik_tipi: Mapped[str | None] = mapped_column(Text, nullable=True)
    boyut_bayt: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    yukleyen_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class VarlikEki(Base):
    """(P154 / Asama 6.4) NOT ve EK — her varliga takilabilen TEK sistem.

    POLIMORFIK BAG: `(varlik_tipi, varlik_id)`. Veritabani bu bagi
    ZORLAYAMAZ (FK yok) — bu bilincli bir takas ve bedeli goc 0043'un
    modul basliginda yazili. Butunluk uc katmanda karsilaniyor:
    `varlik_tipi` CHECK ile kapali kume, uc ust kaydin varligini VE
    gorunurlugunu dogruluyor, yetim temizligi ust silme yolunun isi.

    NOT ve DOSYA ayni tabloda (`tur`): ikisi de "bu kayda iliskin ek
    bilgi" ve ayni yetki kuralina tabi. Ayirmak, kullanicinin TEK bir
    zaman cizgisinde gormek istedigi seyi iki uca bolerdi.
    """

    __tablename__ = "varlik_eki"

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    varlik_tipi: Mapped[str] = mapped_column(Text, nullable=False)
    varlik_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    # `Text` DEGIL, ENUM: sutun goc 0043'te `ek_turu` tipinde. `Text`
    # yazildiginda INSERT'te asyncpg parametreyi `varchar` olarak bagliyor
    # ve Postgres "column tur is of type ek_turu but expression is of type
    # character varying" ile 500 veriyor — YAZMA YOLU HIC CALISMIYOR.
    # Yalniz mutlu-yol testi yakalar; yetki testleri POST'a ulasmadan
    # 403/404 doner.
    tur: Mapped[str] = mapped_column(EK_TURU, nullable=False)
    metin: Mapped[str | None] = mapped_column(Text, nullable=True)
    dosya_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    dosya_adi: Mapped[str | None] = mapped_column(Text, nullable=True)
    olusturan_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    created_at = _created_at()


class KvkkMetin(Base):
    """(P36) Aydinlatma metni — TENANT ICERIGI, urun sabiti DEGIL.

    Her tesisin veri sorumlusu kendisidir; platforma gomulu tek bir metin
    200 tesise BASKASININ metnini imzalatmak olurdu.

    YAYINLANMIS METIN DEGISTIRILEMEZ, yeni SURUM acilir: yerinde duzenlemeye
    izin verilseydi dun onay vermis bir kullanicinin onayi BUGUN BASKA BIR
    METNE ait gorunurdu.
    """

    __tablename__ = "kvkk_metin"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_kvkk_metin_id_tenant"),
        UniqueConstraint("tenant_id", "surum", name="uq_kvkk_metin_surum"),
        ForeignKeyConstraint(
            ["yayinlayan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_kvkk_metin_yayinlayan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    surum: Mapped[int] = mapped_column(Integer, nullable=False)
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    govde: Mapped[str] = mapped_column(Text, nullable=False)
    yayinlayan_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class KvkkOnay(Base):
    """(P36) Kullanicinin BELIRLI BIR SURUME verdigi onay.

    Satir SILINMEZ ve GUNCELLENMEZ. Onayi "geri almak" onay kaydini silmek
    DEGILDIR: aydinlatma bir BILDIRIMDIR ve geri alinmaz — geri alinabilen
    sey PAZARLAMA RIZASIDIR (app_user kolonlari).
    """

    __tablename__ = "kvkk_onay"
    __table_args__ = (
        UniqueConstraint("tenant_id", "user_id", "surum", name="uq_kvkk_onay"),
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_kvkk_onay_user",
        ),
        ForeignKeyConstraint(
            ["kvkk_metin_id", "tenant_id"],
            ["kvkk_metin.id", "kvkk_metin.tenant_id"],
            ondelete="RESTRICT",
            name="fk_kvkk_onay_metin",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    kvkk_metin_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    #: Surum AYRICA kopyalanir: metin satiri bir gun silinse bile "hangi
    #: surumu onayladi" sorusu yanitlanabilir kalmali.
    surum: Mapped[int] = mapped_column(Integer, nullable=False)
    onay_at = _created_at()


# --------------------------------------------------------------------------- #
class HesapSilmeKaydi(Base):
    """(P112) Hesap silindiginin KALICI kaniti — App Store 5.1.1(v) + KVKK.

    Kisisel verinin kendisi gittigi icin kanit ondan BAGIMSIZ olmak zorunda.
    `audit_log` yetmez: o, saklama politikasi geregi PURGE edilir
    (`retention_audit_months`); silme talebini eden kisi ya da denetleyen
    kurum bundan SONRA sorabilir. Bu tablo retention motoruna DAHIL DEGILDIR.

    ICINDE KISISEL VERI YOKTUR ve olamaz: tam olarak kisisel veriyi
    sildigimizi kanitlamak icin var.

    `user_id`de FK YOKTUR (bilincli): `hard_delete` modunda `app_user`
    satiri artik mevcut degildir.
    """

    __tablename__ = "hesap_silme_kaydi"
    __table_args__ = (
        UniqueConstraint("tenant_id", "user_id", name="uq_hesap_silme_user"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    rol: Mapped[str] = mapped_column(USER_ROLE, nullable=False)
    #: `hard_delete` (gecmis yok, satir gitti) | `anonymize` (defter kaldi).
    mod: Mapped[str] = mapped_column(Text, nullable=False)
    #: true = kullanicinin KENDISI sildi (5.1.1(v) akisi); false = yonetim.
    kendi_istegi: Mapped[bool] = mapped_column(Boolean, nullable=False)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class UnitUyari(Base):
    """(P37) Esige varinca verilen caydirici uyari kaydi.

    AYRI TABLO: "bu daireye ne zaman, hangi sayacla, hangi metinle uyari
    verildi" sorusu denetlenebilir olmali. Sikayet satirlarina gomulu bir
    bayrak, uyariyi bir sikayetin alt-ozelligi yapardi.

    `esik`, `sayac` ve `metin` O ANKI degerleriyle KOPYALANIR: ayar/sablon
    sonradan degisse de gecmis uyari ne oldugunu soylemeye devam eder.
    """

    __tablename__ = "unit_uyari"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_unit_uyari_id_tenant"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_unit_uyari_unit",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    esik: Mapped[int] = mapped_column(Integer, nullable=False)
    sayac: Mapped[int] = mapped_column(Integer, nullable=False)
    metin: Mapped[str] = mapped_column(Text, nullable=False)
    kanal: Mapped[str] = mapped_column(UYARI_KANAL, nullable=False)
    durum: Mapped[str] = mapped_column(UYARI_DURUM, nullable=False)
    deneme: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )
    hata: Mapped[str | None] = mapped_column(Text, nullable=True)
    son_deneme_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class TenantPortal(Base):
    """(P38) Tesisin PUBLIC web sayfasi icerigi.

    (P154 / Asama 7.2) UCLARI KALDIRILDI, MODEL DURUYOR — ve bu bilincli.

    Brief "olu kod kalmasin" diyor ve `/portal` + `/public/{slug}` uclari
    ile panel sayfasi SILINDI. Ama TABLO duruyor: icini dolduran tesisler
    olabilir ve `DROP TABLE` GERI ALINAMAZ bir veri kaybidir. Modeli
    silmek de mumkun degil — `goc-uyum` kapisi semayi modelle
    karsilastirir; tablo dururken modeli kaldirmak kapiyi kirardi.

    YANI BU BIR "OLU KOD" DEGIL, TABLONUN TANIMI. Tablolarin dusurulmesi
    ayri ve ACIK ONAY gerektiren bir adimdir (bkz. docs/P154-tur-raporu).

    VARSAYILAN KAPALI (`yayinda=false`): bir tesisin adi, adresi ve
    fotograflari yonetim ACIKCA yayinlamadan internete cikmamalidir.
    """

    __tablename__ = "tenant_portal"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"),
        primary_key=True,
    )
    yayinda: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    hero_baslik: Mapped[str | None] = mapped_column(Text, nullable=True)
    hero_alt: Mapped[str | None] = mapped_column(Text, nullable=True)
    hakkimizda: Mapped[str | None] = mapped_column(Text, nullable=True)
    iletisim_adres: Mapped[str | None] = mapped_column(Text, nullable=True)
    iletisim_telefon: Mapped[str | None] = mapped_column(Text, nullable=True)
    iletisim_email: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()
    updated_at = _created_at()


class PortalGaleri(Base):
    """(P38) Portal galerisi — sunucu dosyayi TASIMAZ, anahtari tutar."""

    # (P154 / Asama 7.2) Ucu kaldirildi, tablo + model duruyor —
    # gerekce `TenantPortal`da.
    __tablename__ = "portal_galeri"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_portal_galeri_id_tenant"),
        UniqueConstraint("tenant_id", "obje_anahtari", name="uq_portal_galeri_obje"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    obje_anahtari: Mapped[str] = mapped_column(Text, nullable=False)
    baslik: Mapped[str | None] = mapped_column(Text, nullable=True)
    sira: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    created_at = _created_at()


class Anket(Base):
    """(P38) Sakin oylamasi. Anket bir yoklama degil KARAR aracidir."""

    __tablename__ = "anket"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_anket_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    kapanis_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


class AnketSecenek(Base):
    __tablename__ = "anket_secenek"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_anket_secenek_id_tenant"),
        ForeignKeyConstraint(
            ["anket_id", "tenant_id"],
            ["anket.id", "anket.tenant_id"],
            ondelete="CASCADE",
            name="fk_anket_secenek_anket",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    anket_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    metin: Mapped[str] = mapped_column(Text, nullable=False)
    sira: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))


class AnketOy(Base):
    """(P38) TEK OY, DEGISTIRILEMEZ.

    `user_id` tek-oy kuralini zorlamak icin sarttir; hicbir uc oy verenin
    kimligini DONDURMEZ (`UnitComplaint.complainant_user_id` deseni).
    """

    __tablename__ = "anket_oy"
    __table_args__ = (
        UniqueConstraint("tenant_id", "anket_id", "user_id", name="uq_anket_oy"),
        ForeignKeyConstraint(
            ["anket_id", "tenant_id"],
            ["anket.id", "anket.tenant_id"],
            ondelete="CASCADE",
            name="fk_anket_oy_anket",
        ),
        ForeignKeyConstraint(
            ["secenek_id", "tenant_id"],
            ["anket_secenek.id", "anket_secenek.tenant_id"],
            ondelete="CASCADE",
            name="fk_anket_oy_secenek",
        ),
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_anket_oy_user",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    anket_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    secenek_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    created_at = _created_at()


class TanitimIletisim(Base):
    """(P127.2) Tanitim sitesi iletisim formu — PLATFORM duzeyi.

    `IletisimMesaji`den AYRI: o tablo bir TESISIN portalina gelen mesajdir
    (tenant'a aittir). Burada yazan kisinin henuz bir tesisi YOKTUR; gelen
    sey platforma gelen bir MUSTERI ADAYIDIR. Ikisini `tenant_id` nullable
    yapip birlestirmek, her sorguda "bu satir hangi anlamda?" sorusunu
    uretirdi.

    ERISIM: tabloda RLS ACIK ve POLITIKA YOK — app_rw dogrudan
    okuyamaz/yazamaz. Yazma `tanitim_iletisim_ekle`, okuma
    `tanitim_iletisim_listele` SECURITY DEFINER fonksiyonlarindan gecer
    (goc 0033). Bu model SEMAYI BELGELER; ORM ile sorgulanmaz.
    """

    __tablename__ = "tanitim_iletisim"

    id: Mapped[uuid.UUID] = _pk()
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    email: Mapped[str | None] = mapped_column(Text, nullable=True)
    telefon: Mapped[str | None] = mapped_column(Text, nullable=True)
    mesaj: Mapped[str] = mapped_column(Text, nullable=False)
    #: Formun gonderildigi dil — donuste ayni dilde cevap yazilabilsin.
    dil: Mapped[str | None] = mapped_column(Text, nullable=True)
    okundu: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    created_at = _created_at()


class IletisimMesaji(Base):
    """(P38) Portal iletisim formu.

    TENANT'A YAZILIR, e-postaya DEGIL: e-posta gonderimi yapilandirmaya
    baglidir ve yapilandirilmamis bir sitede mesaj SESSIZCE KAYBOLURDU.
    """

    # (P154 / Asama 7.2) Portal iletisim formu kaldirildi; tablo + model
    # duruyor (gelmis mesajlar veri) — gerekce `TenantPortal`da.
    __tablename__ = "iletisim_mesaji"

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    telefon: Mapped[str | None] = mapped_column(Text, nullable=True)
    email: Mapped[str | None] = mapped_column(Text, nullable=True)
    mesaj: Mapped[str] = mapped_column(Text, nullable=False)
    okundu: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    created_at = _created_at()


class IceAktarim(Base):
    """(P154 / Asama 8) Ice aktarim KOSUMU.

    Geri alinan kosum SILINMEZ, `durum='geri_alindi'` olur: silmek "bu
    dosya bir kez yuklendi ve geri alindi" gercegini yok etmek olurdu ve
    denetim izinin anlatmasi gereken sey tam da budur.

    DOSYANIN KENDISI SAKLANMAZ — yalniz adi. Icinde kisisel veri olabilir
    ve saklamanin bir amaci yok (KVKK: veri en az).
    """

    __tablename__ = "ice_aktarim"

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    tur: Mapped[str] = mapped_column(Text, nullable=False)
    dosya_adi: Mapped[str | None] = mapped_column(Text, nullable=True)
    satir_sayisi: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )
    olusan: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )
    atlanan: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )
    hatali: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )
    durum: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'uygulandi'")
    )
    olusturan_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    created_at = _created_at()
    geri_alma_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)


class IceAktarimKayit(Base):
    """(P154 / Asama 8) Bir kosumda yaratilan TEK satirin izi.

    `tablo` METINDIR ve FK YOKTUR: hedef onlarca tablodan biri olabilir.
    Kume uygulama tarafinda kapali (`routers/ice_aktarim.py`) — yeni bir
    ice aktarim turu eklemek GOC gerektirmemeli.

    `sira` yaratilma sirasidir; geri alma TERS SIRADA siler (once cocuk,
    sonra ebeveyn). Sirasiz silmek FK yuzunden rastgele basarisiz olurdu.
    """

    __tablename__ = "ice_aktarim_kayit"

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    aktarim_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("ice_aktarim.id", ondelete="CASCADE"),
        nullable=False,
    )
    tablo: Mapped[str] = mapped_column(Text, nullable=False)
    kayit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    sira: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at = _created_at()
