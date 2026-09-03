"""Pydantic request/response semalari — openapi.yaml ile uyumlu."""
from __future__ import annotations

import re
import uuid
from datetime import date, datetime, time, timezone
from typing import Annotated, Any, Literal

from pydantic import (
    AfterValidator,
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    field_validator,
    model_validator,
)

from .security import normalize_phone
from .temizleme import zengin_temizle

#: (P171) ZENGIN METIN GOVDESI — YAZMA ANINDA TEMIZLENIR.
#
# TIP OLARAK yazildi, uc icinde bir cagri OLARAK degil. Gerekce: bir
# temizleme cagrisi yeni bir ucta UNUTULABILIR ve unutuldugunda hicbir sey
# hata vermez — yalnizca o uc korumasiz kalir. Tip, korumayi SEMANIN
# KENDISINE tasir: `ZenginHtml` yazan her alan temizlenmis olur.
#
# `AfterValidator`: uzunluk/bosluk dogrulamalarindan SONRA calisir, yani
# `max_length` KULLANICININ yazdigi metne uygulanir — temizlenmis (kisalmis)
# haline degil.
ZenginHtml = Annotated[str, AfterValidator(zengin_temizle)]

# ======================= (P203 §1) KOORDINAT TIPLERI ======================== #
#
# OLCULEN KUSUR: `PATCH /checkpoints/{id}` koordinat girilince **500**
# donuyordu. Zincir:
#   1. Panel `sayiCoz` ile ayristiriyordu — o bir PARA ayristiricisidir ve
#      noktadan sonra 2'den fazla basamak varsa noktayi BINLIK AYRACI
#      sayip SILER: "41.008238" -> 41008238 (olculdu).
#   2. Sunucu bu sayiyi DOGRULAMADAN kabul ediyordu (`float`, sinir yok).
#   3. Sutun `Numeric(9, 6)`: uc tam basamak sigar. 41008238 TASTI ve
#      psycopg `NumericValueOutOfRange` atti -> yakalanmamis istisna -> 500.
#
# Panel tarafi ayrica duzeltildi (koordinat para degildir), AMA SUNUCU
# KENDI BASINA DA DAYANIKLI OLMALI: istemciye guvenmek, ayni 500'u bir
# sonraki istemcide (mobil, entegrasyon, curl) yeniden uretmek olurdu.
#
# ARALIK DOGRULAMASI SUTUN GENISLIGINDEN DAHA DAR ve bu bilincli:
# `Numeric(9,6)` 999.999999'a kadar izin verir ama 200 enlemi diye bir
# sey YOKTUR. Fiziksel olarak imkansiz bir koordinati sessizce saklamak,
# haritada bir noktayi okyanusa koymak demektir.
#
# `konum_lat` (TenantSettingsUpdate) bu dogrulamayi ZATEN tasiyordu —
# yani kural depoda vardi, GPS alanlarinda UYGULANMAMISTI.
Enlem = Annotated[float, Field(ge=-90, le=90)]
Boylam = Annotated[float, Field(ge=-180, le=180)]

GunTipi = Literal["her_gun", "hafta_ici", "hafta_sonu", "resmi_tatil"]


# Parola politikasi (kayit/tesis-olustur/parola-belirle/degistir/personel-sakin
# ekle): en az 8 karakter + buyuk harf + rakam + sembol (Turkce harfler dahil).
_PW_UPPER = re.compile(r"[A-ZÇĞİÖŞÜ]")
_PW_DIGIT = re.compile(r"[0-9]")
_PW_SYMBOL = re.compile(r"[^0-9A-Za-zÇĞİÖŞÜçğıöşü\s]")


def validate_password_strength(v: str) -> str:
    if len(v) < 8:
        raise ValueError("Parola en az 8 karakter olmalı.")
    if not _PW_UPPER.search(v):
        raise ValueError("Parola en az bir büyük harf içermeli.")
    if not _PW_DIGIT.search(v):
        raise ValueError("Parola en az bir rakam içermeli.")
    if not _PW_SYMBOL.search(v):
        raise ValueError("Parola en az bir sembol içermeli (örn. ! ? @ # . -).")
    return v


def _hhmm(v: object) -> object:
    """time/str -> "HH:MM" (openapi gun-ici saat formati)."""
    if isinstance(v, time):
        return v.strftime("%H:%M")
    if isinstance(v, str):
        return v[:5]  # "HH:MM[:SS]" -> "HH:MM"
    return v


# ------------------------------- auth -------------------------------------- #
# --------------------------------------------------------------------------- #
# (P211 §3) PARA ALANLARININ UST SINIRI — 500'UN KOK NEDENLERINDEN BIRI.
#
# OLCULDU: `POST /dues/payments` govdesinde `tutar_kurus=10**19` gonderildi
# ve uc 500 dondu. Sebep is kurali degil, VERI TIPI: `bigint` (int64) tasti
# ve asyncpg `DataError: value out of int64 range` atti — yani gecersiz
# girdi, dogrulama katmanini gecip surucude patliyordu.
#
# Sinir int64'un cok altinda BILINCLI olarak: 10^15 kurus = 10 trilyon TL.
# Gercek bir aidat/gider bunun yanina yaklasmaz; yaklasan bir sayi kullanici
# hatasidir ve "anlasilir 422" ile geri donmelidir.
KURUS_UST_SINIR = 10**15

class LoginRequest(BaseModel):
    """(P205 §1) TEK KIMLIK ALANI — e-posta VEYA telefon.

    `tenant_slug` ARTIK OPSIYONEL. Uc, kimlik + parolayla eslesen
    uyelikleri bulur:
      * TEK uyelik -> dogrudan giris (slug'a gerek yok),
      * BIRDEN COK -> `tesis_secimi_gerekli` (istemci secim gosterir),
      * slug VERILMISSE -> yalniz o tesis denenir (eski davranis).

    Slug'i zorunlu birakmak, kullaniciya ezberlemesi gerekmeyen bir kodu
    ezberletmekti — P203 §2'de web'de duzeltilen sikayetin ta kendisi.
    """

    tenant_slug: str | None = Field(None, examples=["acme-plaza"])
    #: E-posta ya da telefon. Eski istemciler `email` gonderiyordu;
    #: dogrulayici ikisini de kabul eder (bkz. `_kimlik_birlestir`).
    kimlik: str | None = Field(None, min_length=1, max_length=254)
    email: EmailStr | None = None
    password: str = Field(..., min_length=1)

    @model_validator(mode="after")
    def _kimlik_birlestir(self) -> "LoginRequest":
        """`kimlik` yoksa `email`den doldur — ESKI ISTEMCILER KIRILMASIN.

        Mobil uygulama magazadadir ve eski surumler bir sure daha
        `email` gonderecek. Alani zorunlu kilmak, guncellemeyen
        kullanicilarin girisini KIRMAK olurdu (P202'de eklenen zorunlu
        guncelleme bile aninda yayilmaz).
        """
        if not self.kimlik and self.email:
            object.__setattr__(self, "kimlik", str(self.email))
        if not self.kimlik:
            raise ValueError("kimlik zorunlu")
        return self


# ===================== (P203 §2) COKLU TESIS ================================ #
class TesislerimIstek(BaseModel):
    """Giris ekraninda "hangi tesislerdeyim" sorusu.

    (P205 §1) TEK ALAN: `kimlik` E-POSTA DA OLABILIR TELEFON DA.
    Kullaniciya "hangisini yaziyorsun" diye sormak, bilgisayarin
    kolayca yapabilecegi bir ayrimi insana yaptirmakti.

    PAROLA ZORUNLU. Uyelik listesi bir SIZINTI YUZEYIDIR: parolasiz
    sorulabilseydi uc, "bu kimlik hangi sitelerde oturuyor" sorgusuna
    donusurdu. Parolayla birlikte sorulunca, cagirinin ZATEN sahip
    oldugu bir bilgiden fazlasi verilmez.

    `min_length` PAROLADA 8 DEGIL 1: bu uc bir DOGRULAMA ucu degil,
    ARAMA ucudur ve kisa bir parola girildiginde "parolan cok kisa"
    demek, hesabin var olup olmadigindan BAGIMSIZ bir sinyal vermek
    olurdu. Kisa parola da sessizce bos liste doner.
    """

    kimlik: str | None = Field(None, min_length=1, max_length=254)
    #: (P203 §2) ILK SURUMDE alan `email` idi. Tarayicida ONBELLEKTEKI
    #: eski JS bir sure daha `email` gonderir; alani reddetmek, giris
    #: ekranindaki tesis SECIMINI onlarda kirardi. `LoginRequest` ile
    #: AYNI uzlasma.
    email: EmailStr | None = None
    password: str = Field(..., min_length=1)

    @model_validator(mode="after")
    def _kimlik_birlestir(self) -> "TesislerimIstek":
        if not self.kimlik and self.email:
            object.__setattr__(self, "kimlik", str(self.email))
        if not self.kimlik:
            raise ValueError("kimlik zorunlu")
        return self


class TesisUyeligi(BaseModel):
    tenant_id: uuid.UUID
    slug: str
    ad: str
    #: Bu TESISTEKI rol. Ayni kisi bir tesiste yonetici, otekinde sakin
    #: olabilir — rol UYELIGE aittir, kisiye degil.
    rol: str


class TesislerimYanit(BaseModel):
    tesisler: list[TesisUyeligi]


class TesisDegistirIstek(BaseModel):
    tenant_id: uuid.UUID


class PhoneLoginRequest(BaseModel):
    """Telefonla giris: cep telefonu (global benzersiz) + (gecici kod VEYA
    kalici parola). Tenant, telefondan otomatik cozulur (tenant_slug YOK)."""

    phone: str = Field(..., min_length=1, examples=["+905321112203"])
    password: str = Field(..., min_length=1)


class PhoneLoginResponse(BaseModel):
    """Telefon giris yaniti — iki durum:

    * Kalici parola ile giris: `password_setup_required=false` + tam token cifti.
    * Gecici kod ile ILK giris: `password_setup_required=true` + `setup_token`
      (yalniz /auth/set-password'de gecer; oturum token'i VERILMEZ).
    """

    password_setup_required: bool
    setup_token: str | None = None
    access_token: str | None = None
    refresh_token: str | None = None
    token_type: str | None = None
    expires_in: int | None = None


class SetPasswordRequest(BaseModel):
    setup_token: str
    new_password: str = Field(..., min_length=8)

    @field_validator("new_password")
    @classmethod
    def _strong(cls, v: str) -> str:
        return validate_password_strength(v)


# Self-servis parola degisimi (PATCH /me/password) — kullanici KENDI parolasini
# gunceller; mevcut parola zorunlu (auth.md self-servis profil).
class PasswordChangeRequest(BaseModel):
    """Parolasi OLAN: `current_password` · PAROLASIZ: `kod` (HesapSilmeIstek deseni).

    (P184) Parolasiz kullanici mevcut parola YERINE bir sahiplik kaniti kodu
    gonderir; kod `amac='hesap_silme'` ile uretilir ve doğrulanmış e-posta
    varsa E-POSTAYA gider (`/me/hesap-sil/eposta-kod-iste`). Hangisinin
    isteneceğini SUNUCU secer (`password_hash is None`). `current_password`
    ZORUNLU DEGIL: zorunlu birakmak, kendi kaydolan (parolasiz) kullanicinin
    parola KURAMAMASI demekti.
    """

    current_password: str | None = Field(None, min_length=1, max_length=200)
    #: (P184) Parolasiz kullanici icin sahiplik kaniti kodu. Parolasi olanda bos.
    kod: str | None = None
    new_password: str = Field(..., min_length=8)

    @field_validator("new_password")
    @classmethod
    def _strong(cls, v: str) -> str:
        return validate_password_strength(v)


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int


# ------------------------------- users ------------------------------------- #
class UserOut(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    ad: str
    email: str | None = None  # resident'ta opsiyonel
    # (P181 Bölüm 1) E-posta doğrulandı mı? Arayüz "beklemede" durumunu ve
    # reset/OTP uygunluğunu buna göre gösterir.
    eposta_dogrulandi: bool = False
    role: str
    is_active: bool
    # Profil fotografi (0005/WP-D) — kisa omurlu presigned GET URL (varsa).
    avatar_url: str | None = None
    # (P190 §5) Tema tercihi — hesapta saklanır; web açılışta senkronlar.
    ui_tema: str = "system"


class MeTemaRequest(BaseModel):
    """(P190 §5) Tema tercihini güncelle — hesapta saklanır."""

    tema: Literal["system", "light", "dark"]
    model_config = ConfigDict(extra="forbid")


class MeEpostaEkleRequest(BaseModel):
    """(P181 Bölüm 1) Mevcut kullanıcının e-posta ekleme/doğrulama isteği."""
    eposta: str = Field(min_length=3, max_length=254, examples=["ayse@ornek.com"])
    model_config = ConfigDict(extra="forbid")


class MeEpostaDogrulaRequest(BaseModel):
    eposta: str = Field(min_length=3, max_length=254)
    kod: str = Field(min_length=4, max_length=8)
    model_config = ConfigDict(extra="forbid")


class AvatarUpdate(BaseModel):
    """PATCH /me/avatar — null gonderimi fotografi KALDIRIR (alan zorunlu)."""

    avatar_key: str | None


UserRoleLiteral = Literal[
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
    # (P35) Dis guvenlik sirketinin amiri.
    "guvenlik_amiri",
    # (P128) Tesisin SALT-OKUMA mali denetcisi.
    "denetci",
]
GuvenlikModu = Literal["yonetim_ici", "dis_sirket"]


# Admin kullanici yonetimi ciktisi (TEK kayit) — password_hash ASLA yok.
# telefon burada doner (tek-kayit yonetim gorunumu); LISTEDE donmez (KVKK —
# numaralar TOPLU listelenmez, bkz. UserAdminListItem).
class UserAdminOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    email: str | None = None  # resident'ta opsiyonel
    telefon: str | None = None
    aranabilir: bool = False
    role: str
    is_active: bool
    # Tenant'in birincil yoneticisi mi? Mobil ilk-giris adlandirma kapisi
    # yalniz buna acilir (yonetici disi rollerde daima false).
    birincil: bool = False
    # Saha personeli profil fotografi (presign GET URL; router doldurur).
    avatar_url: str | None = None
    # (P128) Gorev penceresi — denetci disi rollerde NULL.
    gorev_baslangic: date | None = None
    gorev_bitis: date | None = None
    # (P186 §2) Kayit tamamlandi mi (password_set): tamamlanmis hesabin
    # e-postasi giris kimligidir -> panelde salt-okunur. Aktif daire atamasi
    # duzenleme formunu on-doldurur (yalniz DETAY GET doldurur; listede NULL).
    kayit_tamamlandi: bool = False
    daire_id: uuid.UUID | None = None
    # --- (P193 §7) BILDIRIM TESHISI — YALNIZ DETAY GET doldurur --------- #
    #
    # Rehberde eksik 5: "sakine bildirim gitmiyor" sikayetinde yoneticinin
    # bakabilecegi HICBIR ekran yoktu; kisinin kendi ayarina bakmasi
    # gerekiyordu. Bu alanlar SALT OKUNUR: kanal tercihi kisinin kendi
    # tercihidir, yonetici GOREBILMELI ama DEGISTIREMEMELI (KVKK: tercihi
    # baskasi adina degistirmek rizayi anlamsizlastirir).
    #: E-postasi DOGRULANMAMIS kullaniciya bildirim gonderilse de
    #: kullanici giris yapamaz; teshisin ilk sorusu budur.
    eposta_dogrulandi: bool = False
    bildirim_eposta: bool | None = None
    bildirim_sms: bool | None = None
    bildirim_mobil: bool | None = None
    #: Kayitli mobil cihaz sayisi. "Push acik" ile "push GIDEBILIR" ayri
    #: seylerdir: cihaz kaydi yoksa tercih acik olsa da bildirim gitmez ve
    #: teshisin cevabi tam olarak budur.
    mobil_cihaz_sayisi: int | None = None
    #: (P193 §7 / eksik 10) Havale aciklamasina yazilacak kod. Banka
    #: eslestirmesinin kesin calismasi buna bagli; sakinin uygulamasinda
    #: gorunuyordu ama yonetici goremiyordu — yani "kodunu yaz" diye
    #: soyleyemiyordu.
    odeme_kodu: str | None = None
    created_at: datetime


class OdemeKoduSatiri(BaseModel):
    user_id: uuid.UUID
    ad: str
    #: Aktif daire baglantisi. Duyuru "A-12 -> ABC123" seklinde yazilir;
    #: yalniz ad ile ayni isimli iki sakin ayirt edilemezdi.
    daire_no: str | None = None
    odeme_kodu: str


class OdemeKoduListe(BaseModel):
    """(P193 §7) Sakinlerin havale kodlari.

    `uretilen` AYRI DONER: yonetici ekrani ilk actiginda cogu kod HENUZ
    YOKTUR (tembel uretim) ve "bu cagri veriyi degistirdi mi" sorusunun
    gorunur bir yaniti olmali.
    """

    uretilen: int = 0
    items: list[OdemeKoduSatiri] = Field(default_factory=list)


# Liste ogesi — telefon YOK (data-minimization: numaralar toplu listelenmez).
# aranabilir (riza bayragi; PII degil) yonetim gorunurlugu icin doner.
class UserAdminListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    email: str | None = None
    aranabilir: bool = False
    role: str
    is_active: bool
    # Tenant'in birincil yoneticisi mi? Mobil ilk-giris adlandirma kapisi
    # yalniz buna acilir (yonetici disi rollerde daima false).
    birincil: bool = False
    # Saha personeli profil fotografi (presign GET URL; router doldurur).
    avatar_url: str | None = None
    # (P128) Gorev penceresi — denetci disi rollerde NULL.
    gorev_baslangic: date | None = None
    gorev_bitis: date | None = None
    created_at: datetime


class AcilabilirRollerOut(BaseModel):
    """(P130) `GET /users/acilabilir-roller` — cagiranin acabilecegi roller.

    Liste BOS olabilir (hicbir rolu acamayan bir cagiran); istemci bunu
    "form kapali" diye cizmeli, "kural yok" diye degil.
    """

    roller: list[UserRoleLiteral]


class UserCreate(BaseModel):
    # Telefon global benzersiz iletisim anahtaridir (E.164 normalize). email
    # (P185) artik ZORUNLUDUR: dogrulama/bildirim kanalidir (yine de giris
    # anahtari DEGIL — giris telefonla).
    #
    # (P186) PAROLA ALANI KALDIRILDI. Yonetici parola atamaz: hesap parolasiz
    # acilir ve kisi davet (Tesis ID) ile mobilden KENDI kimligini kurar
    # (SSO ya da e-posta + kendi parolasi). Yoneticinin parola bilmesi
    # guvenlik acigiydi.
    ad: str = Field(..., min_length=1)
    telefon: str = Field(..., min_length=1, examples=["+905321112203"])
    email: EmailStr
    aranabilir: bool = False
    role: UserRoleLiteral
    # (P128) GOREV PENCERESI — bugun yalniz `denetci` icin anlamli, ikisi de
    # opsiyonel (suresiz gorev gecerli bir durumdur). Rolle KISITLAMIYORUZ
    # ki yarin baska bir gecici rol icin ayni alan yeniden turetilmesin;
    # anlamsiz doldurulan bir pencere kimseye zarar vermez, eksik olan
    # verirdi.
    gorev_baslangic: date | None = None
    gorev_bitis: date | None = None

    @model_validator(mode="after")
    def _pencere_tutarli(self) -> "UserCreate":
        if (
            self.gorev_baslangic is not None
            and self.gorev_bitis is not None
            and self.gorev_bitis < self.gorev_baslangic
        ):
            # Semada da CHECK var (goc 0032); burada kesmek kullaniciya
            # veritabani hatasi yerine alan adiyla mesaj verir.
            raise ValueError("gorev_bitis, gorev_baslangic'tan once olamaz")
        return self

    @field_validator("telefon")
    @classmethod
    def _normalize_telefon(cls, v: str) -> str:
        try:
            return normalize_phone(v)
        except ValueError as exc:
            raise ValueError(str(exc)) from exc


class UserCreatedOut(BaseModel):
    """Kullanici olusturma yaniti. (P186) `temp_code` KALDIRILDI — hesap
    parolasiz acilir ve sahiplenme yalniz DAVET yoluyladir; gosterilecek bir
    tek-seferlik kod yoktur."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    email: str | None = None
    telefon: str | None = None
    aranabilir: bool = False
    role: str
    is_active: bool
    # Tenant'in birincil yoneticisi mi? Mobil ilk-giris adlandirma kapisi
    # yalniz buna acilir (yonetici disi rollerde daima false).
    birincil: bool = False
    # (P128) Gorev penceresi — olusturulan kayit ne dondugu gibi geri doner.
    gorev_baslangic: date | None = None
    gorev_bitis: date | None = None
    created_at: datetime
    # (P155 §7 · P186) Davet gonderim ozeti — hesap DAIMA parolasiz acilir,
    # davet her zaman gonderilir (eski `temp_code` kaldirildi).
    davet: "DavetGonderimSonucu | None" = None


class UserUpdate(BaseModel):
    # (P97) telefon E.164 NORMALIZE EDILIR — asagidaki dogrulayiciya bak.
    ad: str | None = Field(None, min_length=1)
    email: EmailStr | None = None
    telefon: str | None = None
    aranabilir: bool | None = None
    role: UserRoleLiteral | None = None
    is_active: bool | None = None
    # (P186-ek2) `password` KALDIRILDI: yonetici bir kullanicinin parolasini
    # DEGISTIREMEZ (o parolayla hesaba girebilirdi). Kullanici kendi parolasini
    # `PATCH /me/password` (mevcut parola/kod) ile degistirir; unutursa
    # "sifremi unuttum" (e-posta OTP).
    # (P128) Gorev penceresi GUNCELLENEBILIR: yonetici gorevi uzatir ya da
    # bitis tarihini bugune cekerek FIILEN IPTAL eder. `is_active=false` ile
    # kapatmak da mumkundur; ikisi farkli seylerdir — biri "gorevi bitti",
    # digeri "hesabi kapatildi" der ve denetim izinde de oyle gorunur.
    gorev_baslangic: date | None = None
    gorev_bitis: date | None = None

    # (P97) TELEFON NORMALIZE EDILMIYORDU. Olculdu:
    # `PATCH /users/{id} {"telefon": "//evil.example/x"}` -> **200** ve deger
    # HAM saklaniyordu. Iki sonucu vardi:
    #   * telefon GLOBAL BENZERSIZ bir GIRIS KIMLIGIDIR (telefonla giris);
    #     normalize edilmemis deger benzersizlik varsayimini bozar
    #     (`0532…` ile `+90532…` ayni kisi, farkli satir),
    #   * `resolve_phone_target` `tel:{numara}` kurar; ham deger
    #     `tel://evil.example/x` gibi bir URI uretir ve istemcinin sema
    #     kontrolu (P96) bunu GECIRIR cunku sema hala `tel`.
    # Ayni alanin YARATMA yolunda (UserCreate) dogrulayici zaten vardi;
    # GUNCELLEME yolunda yoktu — ayni gercek iki yerde, biri korumasiz.
    @field_validator("telefon")
    @classmethod
    def _normalize_telefon_upd(cls, v: str | None) -> str | None:
        if v is None:
            return None
        # (P98) BOS DIZGE "NUMARAYI KALDIR" DEMEKTIR, gecersiz numara degil.
        # Mevcut sozlesme bu: `PATCH /users/{id}/contact {"telefon": ""}`
        # numarayi siler ve `resolve_phone_target` da `(telefon or "").strip()`
        # ile bos degeri "numara yok" sayar. Ilk surumde bunu 422 yaptim ve
        # `test_riza_yoksa_numara_aciklanmaz_404` dustu — dogrulayici,
        # dogrulamasi gerekmeyen bir DEGERI reddediyordu.
        if not v.strip():
            return v
        try:
            return normalize_phone(v)
        except ValueError as exc:
            raise ValueError(str(exc)) from exc

    @model_validator(mode="after")
    def _at_least_one(self) -> "UserUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


# Rol-bazli arama iletisim ayari (C1a) — YALNIZ telefon + riza; admin+yonetici
# yonetir (rol/parola gibi hassas alanlara dokunmadan — yetki yukseltme yok).
class HesapSilmeIstek(BaseModel):
    """(P112) Self-servis hesap silme — YENIDEN KIMLIK DOGRULAMA zorunlu.

    Access token'i olan biri (odunc alinmis telefon) tek dokunusla
    baskasinin hesabini silememeli; `PATCH /me/password` ile ayni desen.
    """

    #: (P149) Parolasiz kullanicida BOS kalir — sunucu o durumda `kod`
    #: ister. Zorunlu birakmak, kendi kaydolan sakinin hesabini SILEMEMESI
    #: demekti (Play sartinin ihlali).
    current_password: str | None = Field(None, min_length=1, max_length=200)
    #: (P149) Parolasiz kullanici icin telefon kodu. Parolasi olan
    #: kullanicida bos birakilir — hangisinin isteneceğini SUNUCU secer.
    kod: str | None = None


class HesapSilmeSonuc(BaseModel):
    """`deleted=true` -> satir tamamen silindi (hicbir gecmisi yoktu).
    `deleted=false` -> yasal saklama geregi satir KALDI, kimlik alanlari
    temizlendi (anonimlestirme). Istemci ikisinde de OTURUMU KAPATIR."""

    deleted: bool


class UserContactUpdate(BaseModel):
    telefon: str | None = Field(None, max_length=40)
    aranabilir: bool | None = None

    # (P97) UserUpdate ile AYNI gerekce; sakinin KENDI numarasini
    # guncelledigi yol da normalize edilmeli.
    @field_validator("telefon")
    @classmethod
    def _normalize_telefon_contact(cls, v: str | None) -> str | None:
        if v is None:
            return None
        # (P98) BOS DIZGE "NUMARAYI KALDIR" DEMEKTIR, gecersiz numara degil.
        # Mevcut sozlesme bu: `PATCH /users/{id}/contact {"telefon": ""}`
        # numarayi siler ve `resolve_phone_target` da `(telefon or "").strip()`
        # ile bos degeri "numara yok" sayar. Ilk surumde bunu 422 yaptim ve
        # `test_riza_yoksa_numara_aciklanmaz_404` dustu — dogrulayici,
        # dogrulamasi gerekmeyen bir DEGERI reddediyordu.
        if not v.strip():
            return v
        try:
            return normalize_phone(v)
        except ValueError as exc:
            raise ValueError(str(exc)) from exc

    @model_validator(mode="after")
    def _at_least_one(self) -> "UserContactUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class MeContactUpdate(UserContactUpdate):
    """(P167 §1.7) Self-servis iletisim + GORUNEN AD.

    NEDEN `UserContactUpdate`E EKLENMEDI DE TUREDI: o sema yonetim ucunu
    (`PATCH /users/{id}/contact`) da besliyor. Oraya `ad` eklemek, "iletisim
    guncelle" adli bir ucun sessizce KIMLIK alani da degistirebilmesi
    demekti — yetki matrisi degismeden davranis genisler ve kimse fark
    etmezdi. Turetmek, yeni alani YALNIZ self-servis yola acar.

    E-POSTA BILEREK YOK. E-posta bu sistemde LOGIN ANAHTARIDIR
    (`uq_app_user_tenant_email`) ve dogrulama akisi yoktur. Dogrulamasiz
    degistirilebilseydi: (a) odunc alinmis bir oturum adresi degistirip
    hesabin sahibini kalici olarak disarida birakabilirdi, (b) yanlis
    yazilan bir adres parola sifirlamayi SESSIZCE calismaz hale getirirdi.
    Degisim yolu, dogrulama kodu akisiyla birlikte acilmalidir.
    """

    ad: str | None = Field(None, min_length=1, max_length=120)

    @field_validator("ad")
    @classmethod
    def _ad_bosluk(cls, v: str | None) -> str | None:
        if v is None:
            return None
        temiz = v.strip()
        if not temiz:
            # BOS AD "adi kaldir" DEMEK DEGILDIR (telefondan farki bu):
            # `app_user.ad` NOT NULL ve her ekranda kisinin tek tanimi.
            # Bos birakmak, listelerde adsiz satirlar uretirdi.
            raise ValueError("ad_bos_olamaz")
        return temiz


# Self-servis profil ciktisi (GET /me/profile, PATCH /me/contact) — kullanici
# KENDI kimlik + iletisim alanlarini gorur. password_hash ASLA yok.
class MeProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    email: str | None = None  # resident'ta opsiyonel
    eposta_dogrulandi: bool = False  # (P181 Bölüm 1)
    telefon: str | None = None
    aranabilir: bool = False
    role: str
    is_active: bool
    # Tenant'in birincil yoneticisi mi? Mobil ilk-giris adlandirma kapisi
    # yalniz buna acilir (yonetici disi rollerde daima false).
    birincil: bool = False
    # (P167 §1.7) Kisa omurlu presigned GET URL'i; obje anahtari ISTEMCIYE
    # VERILMEZ (UserOut ile ayni kural). `None` = fotograf yok → arayuz bas
    # harfleri cizer.
    #
    # NEDEN BURAYA EKLENDI: sag ust kullanici menusu (avatar + ad) ile
    # profil sayfasi AYNI kaydin iki gorunumu. Avatari `/me`den, geri
    # kalanini `/me/profile`dan cekmek her ekranda IKI istek ve iki ayri
    # onbellek demekti; ikisi ayrisinca avatar bir yerde eski kalirdi.
    avatar_url: str | None = None


class BildirimTercihleri(BaseModel):
    """(P167 §1.7) Isleyis bildirimlerinin kanal tercihleri.

    Pazarlama izinlerinin (`PazarlamaTercihleri`) IKIZI DEGILDIR — goc
    0055'in basligindaki ayrim: pazarlama bir riza, bildirim bir tercih.
    """

    model_config = ConfigDict(from_attributes=True)

    bildirim_eposta: bool
    bildirim_sms: bool
    bildirim_mobil: bool
    #: (P207 §2) SESLI UYARI. `bildirim_mobil` ile karistirilmamali:
    #: bu, bildirimin GELIP GELMEYECEGINI degil SESLI olup olmayacagini
    #: soyler.
    bildirim_sesi: bool = True


class BildirimTercihUpdate(BaseModel):
    """KISMI guncelleme — gonderilmeyen kanal DEGISMEZ.

    Uc alanin ucunu birden zorunlu kilmak, tek bir anahtari ceviren
    arayuzu otekilerin o anki degerini de gondermeye zorlardi; iki sekme
    acik olan kullanicida bu, digerinin degisikligini SESSIZCE geri alirdi.
    """

    #: E-postasi DOGRULANMAMIS kullaniciya bildirim gonderilse de
    #: kullanici giris yapamaz; teshisin ilk sorusu budur.
    eposta_dogrulandi: bool = False
    bildirim_eposta: bool | None = None
    bildirim_sms: bool | None = None
    bildirim_mobil: bool | None = None
    bildirim_sesi: bool | None = None


class CihazOut(BaseModel):
    """(P167 §1.7) "Guvenilen cihazlar" satiri — kullanicinin KENDI cihazi.

    `fcm_token` BILINCLI OLARAK YOK: push adresidir ve disari verilmesi,
    o kullaniciya bildirim gondermenin anahtarini vermek olurdu. Silme
    `id` ile yapilir (`DELETE /devices/{fcm_token}` mobil istemcinin kendi
    token'ini biliyorken kullandigi AYRI bir yol).
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    platform: str
    dil: str
    aktif: bool
    created_at: datetime
    #: Son etkinlik — token her uygulama acilisinda upsert edildigi icin
    #: bu alan pratikte "cihaz en son ne zaman gorundu"yu tasir.
    updated_at: datetime


class HesapEtkinligiOut(BaseModel):
    """(P167 §1.7) "Son hesap etkinligi" satiri — kendi denetim kaydi.

    `/audit` ucunun kisitlanmis bir kopyasi DEGIL, AYRI bir yetki karari:
    `/audit` tesisin TAMAMINI gosterir ve yalniz admin/denetci gorur;
    burasi kisinin YALNIZ KENDI satirlarini doner ve her role aciktir.
    Kendi hesabinda ne olup bittigini gormek bir yonetim yetkisi degil,
    hesap guvenliginin temel kosuludur.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    action: str
    resource_type: str | None = None
    #: `audit_log.resource_id` METIN'dir (uuid degil): kayit her zaman bir
    #: uuid'ye isaret etmez (orn. bir dosya anahtari). Sema onu oldugu gibi
    #: tasir — daraltmak, bazi satirlarin dogrulamada patlamasi demekti.
    resource_id: str | None = None
    ts: datetime
    #: Serbest ayrinti (JSON) — "Detaylari gor" acilirinda gosterilir.
    #: KVKK: `meta` yalniz id/alan-adi tutar, kisisel veri DEGERI ASLA.
    meta: dict = {}


class UserAdminListResponse(BaseModel):
    meta: PageMetaOut
    items: list[UserAdminListItem]


# Rol-bazli arama hedefi (C1a) — numara YALNIZ burada, yetki+riza kapisindan
# gecince aciklanir. channel alani C1b (megafon/akilli-ev) icin genisletilebilir.
class CallTargetOut(BaseModel):
    user_id: uuid.UUID
    ad: str
    role: str
    # Kanal turu — C1a yalniz 'phone'; C1b baska kanallar ekleyecek.
    channel: str = "phone"
    telefon: str
    # Cihaz cevirici icin hazir tel: URI (istemci dogrudan baslatir).
    tel_uri: str


# ----------------------- Faz-0 dogrulama (diagnostic) ---------------------- #
# NOT: /me/checkpoints diagnostigi icin (Faz-0). Checkpoint CRUD asagida.
class CheckpointBrief(BaseModel):
    id: uuid.UUID
    ad: str
    nfc_tag_uid: str


# --------------------------- ortak: sayfalama ------------------------------ #
class PageMetaOut(BaseModel):
    limit: int
    offset: int
    total: int


# -------------------------------- shift ------------------------------------ #
class ShiftPersonelOut(BaseModel):
    """Vardiyaya atanan personel (WP-E) — kart avatari + adi."""

    user_id: uuid.UUID
    ad: str
    avatar_url: str | None = None


class ShiftOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    baslangic_saat: str
    bitis_saat: str
    gun_tipi: str
    created_at: datetime
    updated_at: datetime | None = None
    # Atanan personel (WP-E) — router zenginlestirir; ORM'de kolon degil.
    personel: list[ShiftPersonelOut] = []

    @field_validator("baslangic_saat", "bitis_saat", mode="before")
    @classmethod
    def _fmt_saat(cls, v: object) -> object:
        return _hhmm(v)


class ShiftCreate(BaseModel):
    ad: str = Field(..., min_length=1)
    # "HH:MM" / "HH:MM:SS" kabul edilir. baslangic > bitis (gece sarkmasi) gecerli.
    baslangic_saat: time
    bitis_saat: time
    gun_tipi: GunTipi | None = None


class ShiftUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1)
    baslangic_saat: time | None = None
    bitis_saat: time | None = None
    gun_tipi: GunTipi | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "ShiftUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class ShiftAssignmentsUpdate(BaseModel):
    """Tam-liste degistirme (declarative replace) — tekil ekle/cikar ucu YOK."""

    user_ids: list[uuid.UUID]


class ShiftListResponse(BaseModel):
    meta: PageMetaOut
    items: list[ShiftOut]


# -------------------------------- cameras ---------------------------------- #
# Kamera yayin turu — istemci oynatilabilirligini belirler.
CameraTur = Literal["hls", "mp4", "rtsp"]

# tur -> izinli URL semasi. hls/mp4 istemcide oynar => http(s) ZORUNLU.
# rtsp yayin istemcide oynatilamaz ama kayit TUTULUR (envanter/ileride medya
# gecidi) ve rtsp:// semasi ancak tur=rtsp iken kabul edilir; boylece
# "oynatilabilir" alanlarda calismayan sema saklanmaz.
_TUR_SEMALARI: dict[str, tuple[str, ...]] = {
    "hls": ("http://", "https://"),
    "mp4": ("http://", "https://"),
    "rtsp": ("rtsp://",),
}


#: Yayin adresi UST SINIRI (P25). 2048, HTTP yiginlarinin fiili URL
#: siniridir (IE mirasi; Nginx/Apache varsayilan istek satiri da bu
#: mertebede). Daha uzunu zaten AGIN oteki ucunda kirilirdi — ama sinirsiz
#: `text` sutunu, yapistirilan bir DVR yapilandirmasinin tamamini (kilobaytlar)
#: kabul edip listeyi ve mobil kart cizimini sisiriyordu.
URL_UST_SINIR = 2048


def dogrula_restream(restream_url: str | None) -> None:
    """Restream YALNIZ http(s) olabilir.

    Gecit HLS yayinlar ve istemci onu oynatir; buraya bir `rtsp://` adresi
    yazmak "oynatilabilir" isaretli ama OYNAMAYAN bir kamera uretirdi — yani
    tam da bu ozelligin cozdugu sorunu geri getirirdi.
    """
    if restream_url is None:
        return
    if len(restream_url) > URL_UST_SINIR:
        raise UrlCokUzun("restream_url", len(restream_url))
    if not restream_url.startswith(("http://", "https://")):
        raise UrlTurUyusmazligi("restream", ("http://", "https://"))


def dogrula_snapshot(snapshot_url: str | None) -> None:
    """Anlik kare adresi YALNIZ http(s) olabilir (0031 / P121).

    `dogrula_restream` ile ayni gerekce, bir adim daha keskin: istemci bu
    adresi bir GORSEL gibi ceker. `rtsp://` yazilirsa karo sessizce bos
    kalir — hata da vermez, cunku istek hic kurulmaz. Sema burada
    reddedilmezse belirti "kamera calismiyor" diye gorunur ve teshis
    kamerada aranir, kayitta degil.
    """
    if snapshot_url is None:
        return
    if len(snapshot_url) > URL_UST_SINIR:
        raise UrlCokUzun("snapshot_url", len(snapshot_url))
    if not snapshot_url.startswith(("http://", "https://")):
        raise UrlTurUyusmazligi("snapshot", ("http://", "https://"))


def oynatilabilir_mi(tur: str, restream_url: str | None = None) -> bool:
    """Istemci bu kamerayi oynatabilir mi?

    `hls`/`mp4` NATIVE oynar. `rtsp` kendi basina OYNAMAZ — ama bir RESTREAM
    adresi (Frigate/go2rtc HLS gecidi) tanimliysa istemci ONU oynatir ve
    kamera oynatilabilir hale gelir (0012 / P17). P15'te olculdu: go2rtc'nin
    yeniden yayini gercekten oynatilabilir.
    """
    if restream_url:
        return True
    return tur in ("hls", "mp4")


class UrlCokUzun(ValueError):
    """Yayin adresi [URL_UST_SINIR] karakteri asiyor.

    METIN DEGIL VERI tasir ([UrlTurUyusmazligi] ile ayni gerekce): cumle
    router'da istegin dilinde uretilir.
    """

    def __init__(self, alan: str, uzunluk: int) -> None:
        self.alan = alan
        self.uzunluk = uzunluk
        super().__init__(f"{alan} too long: {uzunluk} > {URL_UST_SINIR}")


class UrlTurUyusmazligi(ValueError):
    """`stream_url` semasi `tur` ile uyusmuyor.

    METIN DEGIL VERI tasir (tur 14): kullaniciya gosterilecek cumle router'da
    `hata_metinleri` katalogundan istegin dilinde uretilir. `str(exc)` yalniz
    pydantic ayrintisi/log icin teknik bir ozet verir.
    """

    def __init__(self, tur: str, semalar: tuple[str, ...]) -> None:
        self.tur = tur
        self.semalar = semalar
        super().__init__(f"tur={tur} requires stream_url starting with "
                         f"{' or '.join(semalar)}")


def dogrula_url_tur(stream_url: str, tur: str) -> None:
    """URL semasi ile `tur` tutarli mi (aksi halde [UrlTurUyusmazligi] -> 422).

    hls/mp4 -> http(s):// ; rtsp -> rtsp://. Backend yayini HIC cekmez, bu
    yuzden sema kontrolu SSRF icin degil, "kayit ile gerceklik tutarli
    kalsin" diyedir (yanlis semali kayit istemcide sessizce bozulur).
    """
    if len(stream_url) > URL_UST_SINIR:
        raise UrlCokUzun("stream_url", len(stream_url))
    izinli = _TUR_SEMALARI[tur]
    if not stream_url.startswith(izinli):
        raise UrlTurUyusmazligi(tur, tuple(izinli))


# --------------------------- (P191 §4) BANKA -------------------------------- #
class BankaEkstreSatiri(BaseModel):
    """Panelin ayrıştırdığı bir ekstre satırı.

    XLSX SUNUCUDA AYRIŞTIRILMAZ (P28/P29 kararı, saldırı yüzeyi): panel
    dosyayı zaten önizleme için okuyor ve sunucuya YAPILANDIRILMIŞ satır
    gönderiyor. Sunucu her satırı yine doğrular.
    """

    #: `YYYY-MM-DD`, `DD.MM.YYYY`, `DD/MM/YYYY` kabul edilir.
    tarih: str
    #: Kuruş (tam sayı) ya da metin (`1.234,56` / `1,234.56`).
    tutar: str | int
    aciklama: str = ""
    #: Verilmezse tutarın İŞARETİNDEN türetilir.
    yon: str | None = None
    #: Bankanın referans numarası. YOKSA kararlı bir kimlik türetilir.
    referans: str | None = None
    karsi_ad: str | None = None
    karsi_iban: str | None = None
    para_birimi: str | None = None
    model_config = ConfigDict(extra="forbid")


class BankaIceAktarIstek(BaseModel):
    """Ekstre içe aktarma. `satirlar` VEYA `mt940` — ikisi birden değil."""

    kaynak: str = Field(default="ekstre", examples=["ekstre"])
    satirlar: list[BankaEkstreSatiri] | None = None
    #: MT940 düz metni (sunucuda ayrıştırılır — zip/XML değil, güvenli).
    mt940: str | None = None
    #: (P192 §2.1) Ekstrenin ait olduğu BANKA HESABI. Verilmezse varsayılan
    #: banka hesabı kullanılır. Bir tesisin iki hesabı varsa ikisinin
    #: ekstresini aynı kasaya yazmak, bakiyeleri karıştırmak olurdu.
    kasa_id: uuid.UUID | None = None
    model_config = ConfigDict(extra="forbid")


class BankaIceAktarSonuc(BaseModel):
    eklenen: int
    #: Aynı ekstre ikinci kez yüklendiğinde atlanan satır sayısı.
    yinelenen: int
    toplam: int


class BankaEslesmeOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID | None = None
    unit_id: uuid.UUID | None = None
    #: NULL = daire alacağına yazılan FAZLA ödeme.
    assessment_id: uuid.UUID | None = None
    tutar_kurus: int
    confidence_score: int
    match_type: str
    durum: str
    receipt_id: uuid.UUID | None = None


class BankaHareketOut(BaseModel):
    """Banka hareketi — IBAN MASKELİ (tam değer hiçbir yanıtta dönmez)."""

    id: uuid.UUID
    kaynak: str
    external_transaction_id: str
    islem_tarihi: date
    tutar_kurus: int
    yon: str
    para_birimi: str
    aciklama: str | None = None
    karsi_ad: str | None = None
    karsi_iban_maskeli: str | None = None
    durum: str
    not_metni: str | None = None
    created_at: datetime
    eslesmeler: list[BankaEslesmeOut] = []


class BankaHareketListesi(BaseModel):
    meta: PageMetaOut
    items: list[BankaHareketOut]


class BankaKosumSonuc(BaseModel):
    """(P191 §4) Eşleştirme KOŞUMUNUN özeti.

    Ad `BankaEslestirSonuc` DEĞİL: o ad P29'un öneri üreticisinde ZATEN
    kullanılıyor ve iki şemayı aynı adla tutmak, hangisinin döndüğünü
    sessizce değiştiren bir tuzaktı (ölçüldü: uç 500 verdi).
    """

    incelenen: int
    #: Güven eşiğini geçip UYGULANAN (borç kapandı + defter + makbuz).
    otomatik: int
    #: Yöneticinin önüne düşen.
    manuel: int


class BankaManuelEslestirIstek(BaseModel):
    user_id: uuid.UUID
    #: Kişi çok daireye bağlıysa hangi daire (verilmezse ilk bağ).
    unit_id: uuid.UUID | None = None
    model_config = ConfigDict(extra="forbid")


class BankaIsaretIstek(BaseModel):
    durum: str | None = Field(default=None, examples=["ilgisiz_gelir"])
    not_metni: str | None = Field(default=None, max_length=500)
    model_config = ConfigDict(extra="forbid")


class BankaMakbuzOut(BaseModel):
    id: uuid.UUID
    belge_no: str
    tutar_kurus: int
    user_id: uuid.UUID | None = None
    unit_id: uuid.UUID | None = None
    created_at: datetime
    #: Kısa ömürlü presigned indirme adresi (depo erişilemezse None).
    pdf_url: str | None = None


class KameraTestIstek(BaseModel):
    """(P191 §3) "Bağlantıyı test et" — KAYDETMEDEN önce dene.

    Ölçülen kusur: yönetici kamerayı kaydediyor, ızgarada "Görüntü yok"
    görüyor ve adresin mi ağın mı yanlış olduğunu bilmiyordu. Adres
    doğruluğu KAYIT ANINDA ölçülebilir olmalı.
    """

    stream_url: str
    #: Yalnız `rtsp` desteklenir (sunucu-taraflı çekimin SSRF sınırı).
    tur: CameraTur = "rtsp"
    model_config = ConfigDict(extra="forbid")


class KameraTestSonuc(BaseModel):
    """Başarı yanıtı. BAŞARISIZLIK bir APIError'dır (tanılı mesajla)."""

    basarili: bool
    #: Alınan karenin bayt boyu — "gerçekten görüntü geldi" kanıtı.
    kare_bayt: int


class CameraCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=100)
    # Serbest konum metni (orn. "Ana Kapı - Giriş").
    konum: str | None = Field(None, min_length=1, max_length=200)
    # Istemcinin oynattigi yayin; backend HIC cekmez.
    stream_url: str
    tur: CameraTur = "hls"
    aktif: bool = True
    # KVKK: sakin/tesis gorevlisi gorunurlugu YALNIZ bu bayrakla acilir.
    sakin_gorebilir: bool = False
    # RESTREAM (0012 / P17): RTSP kamerayi oynatilabilir yapan HLS gecidi
    # (Frigate/go2rtc). Dolu ise istemci BUNU oynatir. Yalniz http(s) —
    # istemci HLS oynatir, rtsp gecit adresi anlamsizdir.
    # NOT: `max_length` BILEREK KOYULMADI — pydantic'in kendi 422'si ham
    # Ingilizce bir cumle dondururdu; sinir `dogrula_url_tur`/`dogrula_restream`
    # icinde olculur ve router katalogdan istegin dilinde metin uretir.
    restream_url: str | None = None
    # SNAPSHOT (0031 / P121): izgara karosunun cektigi TEK KARE adresi.
    # Yalniz http(s); sinir/sema `dogrula_snapshot` icinde olculur.
    snapshot_url: str | None = None

    # NOT: URL/tur ve uzunluk dogrulamasi BURADA YAPILMAZ — ROUTER'da yapilir.
    # (P25 bulgusu) Buradaki bir `model_validator`, ValueError'i pydantic'in
    # KENDI `validation_error` zarfina cevirir ve kullaniciya ham INGILIZCE
    # bir cumle doner; yani "acik Turkce hata" hedefi olusturma yolunda HIC
    # calismiyordu (yalniz PATCH yolu katalog metnini uretiyordu, cunku orada
    # dogrulama zaten router'daydi). Kural: URL kurallari tek yerde, router'da.


class CameraUpdate(BaseModel):
    """Kismi guncelleme; en az bir alan. URL/tur tutarliligi router'da
    MEVCUT kayitla birlestirilerek dogrulanir (yalniz biri gonderilebilir)."""

    ad: str | None = Field(None, min_length=1, max_length=100)
    konum: str | None = Field(None, max_length=200)
    stream_url: str | None = None
    tur: CameraTur | None = None
    aktif: bool | None = None
    sakin_gorebilir: bool | None = None
    # RESTREAM (0012 / P17): RTSP kamerayi oynatilabilir yapan HLS gecidi
    # (Frigate/go2rtc). Dolu ise istemci BUNU oynatir. Yalniz http(s) —
    # istemci HLS oynatir, rtsp gecit adresi anlamsizdir.
    # Sinir dogrulayicida olculur (bkz. CameraCreate notu).
    restream_url: str | None = None
    # SNAPSHOT (0031 / P121) — bkz. CameraCreate.
    snapshot_url: str | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "CameraUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        # URL kurallari router'da (bkz. CameraCreate notu).
        return self


class CameraOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    konum: str | None = None
    stream_url: str
    # Restream gecidi (0012). Dolu ise istemci BUNU oynatmalidir.
    restream_url: str | None = None
    # Anlik kare adresi (0031). Dolu ise izgara karosu periyodik olarak
    # BUNU ceker; bos ise karo yer tutucu gosterir (davranis degismez).
    snapshot_url: str | None = None
    tur: CameraTur
    aktif: bool
    sakin_gorebilir: bool
    # TURETILMIS (saklanmaz): istemci bu kamerayi oynatabilir mi. `rtsp` bile
    # `restream_url` doluysa TRUE olur.
    oynatilabilir: bool = True
    # (P190 §6) TURETILMIS: RTSP kamera icin YONETILEN canli izleme yolu
    # (backend HLS vekili, `/cameras/{id}/canli/index.m3u8`). MediaMTX
    # yapilandirilmamissa None. Istemci doluysa BUNU oynatir (kimlik-kapili;
    # RTSP adresi/kimlik bilgisi istemciye gitmez).
    canli_yol: str | None = None
    created_at: datetime
    updated_at: datetime


class CameraListResponse(BaseModel):
    meta: PageMetaOut
    items: list[CameraOut]


# ------------------------------ checkpoint --------------------------------- #
class CheckpointOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    nfc_tag_uid: str
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None
    aktif: bool
    # NTAG424 SDM provision edildi mi (anahtar HICBIR response'ta donmez).
    sdm_aktif: bool = False
    created_at: datetime
    updated_at: datetime | None = None


class SdmKeyUpdate(BaseModel):
    """PUT /checkpoints/{id}/sdm-key govdesi — key: 32 hex (AES-128) | null (kapat)."""

    key: str | None

    @field_validator("key")
    @classmethod
    def _hex_128bit(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        if len(v) != 32:
            raise ValueError("key 32 hex karakter (AES-128) olmali.")
        try:
            bytes.fromhex(v)
        except ValueError:
            raise ValueError("key gecerli hex olmali.")
        return v


class CheckpointCreate(BaseModel):
    ad: str = Field(..., min_length=1)
    nfc_tag_uid: str = Field(..., min_length=1)
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None
    aktif: bool = True


class CheckpointUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1)
    nfc_tag_uid: str | None = Field(None, min_length=1)
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "CheckpointUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class CheckpointListResponse(BaseModel):
    meta: PageMetaOut
    items: list[CheckpointOut]


# ------------------------------ patrol plan -------------------------------- #
class PatrolPlanOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    shift_id: uuid.UUID | None = None
    baslangic_saat: str
    bitis_saat: str
    periyot_dakika: int
    aktif: bool
    created_at: datetime
    updated_at: datetime | None = None

    @field_validator("baslangic_saat", "bitis_saat", mode="before")
    @classmethod
    def _fmt_saat(cls, v: object) -> object:
        return _hhmm(v)


class PatrolPlanCheckpointOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    checkpoint_id: uuid.UUID
    sira: int


class PatrolPlanDetailOut(PatrolPlanOut):
    checkpoints: list[PatrolPlanCheckpointOut] = []


class PatrolPlanCreate(BaseModel):
    ad: str = Field(..., min_length=1)
    shift_id: uuid.UUID | None = None
    baslangic_saat: time
    bitis_saat: time
    periyot_dakika: int = Field(..., ge=1)
    aktif: bool = True


class PatrolPlanUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1)
    shift_id: uuid.UUID | None = None
    baslangic_saat: time | None = None
    bitis_saat: time | None = None
    periyot_dakika: int | None = Field(None, ge=1)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "PatrolPlanUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class PatrolPlanListResponse(BaseModel):
    meta: PageMetaOut
    items: list[PatrolPlanOut]


# plana checkpoint atama (PUT /patrol-plans/{id}/checkpoints)
class PatrolPlanCheckpointItemIn(BaseModel):
    checkpoint_id: uuid.UUID
    sira: int | None = Field(None, ge=0)


class PatrolPlanCheckpointAssign(BaseModel):
    items: list[PatrolPlanCheckpointItemIn]


# -------------------------------- scans ------------------------------------ #
#: (P34) Konum NEDEN yok? Uc farkli durum (izin reddi / servis kapali /
#: zaman asimi) tek bir NULL'a inseydi, amir "konumsuz okutma" diye bir sey
#: OLDUGUNU bile fark edemezdi. `bilinmiyor` = alan hic gonderilmedi
#: (eski istemci) — bunu `izin_yok` saymak OLMAYAN bir izin reddi
#: raporlamak olurdu.
KonumDurumu = Literal["var", "izin_yok", "servis_kapali", "zaman_asimi", "bilinmiyor"]


class SimuleScanCreate(BaseModel):
    """(P115) SIMULE OKUTMA govdesi — YALNIZ demo modundaki tesiste.

    `nfc_tag_uid` YOKTUR ve olamaz: etiketin UID'sini istemciden almak,
    demo tesisinde bile "hangi etiket okutuldu" sorusunu istemcinin
    uydurmasina birakmak olurdu. Sunucu UID'yi `checkpoint_id`den kendisi
    cozer.

    `okutma_zamani` opsiyoneldir; verilmezse SUNUCU SAATI kullanilir —
    denetci elle zaman girmek zorunda kalmasin.
    """

    checkpoint_id: uuid.UUID
    patrol_window_id: uuid.UUID | None = None
    okutma_zamani: datetime | None = None
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None


class ScanCreate(BaseModel):
    nfc_tag_uid: str = Field(..., min_length=1)
    # istemci biliyorsa verir; yoksa nfc_tag_uid ile cozulur (nfc kaynak-dogru).
    checkpoint_id: uuid.UUID | None = None
    patrol_window_id: uuid.UUID | None = None
    okutma_zamani: datetime
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None
    # (P34) Verilmezse SUNUCU TURETIR: koordinat varsa 'var', yoksa
    # 'bilinmiyor'. Eski istemciler bu alani hic gondermez ve kirilmaz.
    konum_durumu: KonumDurumu | None = None
    #: (P34) Metre. 5 m ile 2 km dogruluk ekranda AYNI gorunurdu; ikincisi
    #: "gorevli noktadaydi" kanit degeri tasimaz.
    gps_dogruluk_m: float | None = Field(None, ge=0, le=1_000_000)
    #: (P34) Tur baslangic fotografinin DEPO ANAHTARI (/uploads/presign ile
    #: alinir, tenant namespace'i dogrulanir). `foto_url` alani sozlesmenin
    #: ilk surumunden kalmadir ve dogrulanmaz — yeni istemciler `foto_key`
    #: gonderir; ikisi de ayni kolona yazilir.
    foto_key: str | None = Field(None, max_length=500)
    foto_url: str | None = None
    # DEPRECATED + YOK SAYILIR: deger artik SUNUCUDA SDM dogrulamasiyla belirlenir.
    # Eski mobil surumler kirilmasin diye govdede kabul edilir ama etkisizdir.
    imza_dogrulandi: bool = False
    # NTAG424 SDM/SUN ham verisi (etiketin NDEF ciktisindan): 16B ENCPICCData +
    # 8B SDMMAC, hex. Ikisi birlikte gonderilir; checkpoint'te anahtar varsa
    # sunucu dogrular (gecersiz -> 422 invalid_signature, tekrar -> replay_detected).
    sdm_picc_data: str | None = Field(None, min_length=32, max_length=32)
    sdm_cmac: str | None = Field(None, min_length=16, max_length=16)


class ScanEventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    guard_id: uuid.UUID
    checkpoint_id: uuid.UUID
    patrol_window_id: uuid.UUID | None = None
    nfc_tag_uid: str
    okutma_zamani: datetime
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None
    konum_durumu: KonumDurumu = "bilinmiyor"
    gps_dogruluk_m: float | None = None
    foto_url: str | None = None
    imza_dogrulandi: bool
    idempotency_key: str
    created_at: datetime


class ScanReportItem(BaseModel):
    """Gun-gun tarama raporu satiri (Parca D): kim, hangi nokta, ne zaman.
    checkpoint_ad + guard_ad join ile doldurulur (yonetici takibi)."""

    id: uuid.UUID
    checkpoint_id: uuid.UUID
    checkpoint_ad: str
    guard_id: uuid.UUID
    guard_ad: str
    okutma_zamani: datetime
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None
    # (P34) Konum raporda GORUNUR: amir "kac okutma konumsuz" sorusunu
    # satirlari tek tek acmadan yanitlayabilmeli.
    konum_durumu: KonumDurumu = "bilinmiyor"
    gps_dogruluk_m: float | None = None
    imza_dogrulandi: bool


class ScanReportResponse(BaseModel):
    """Bir gunun (tenant timezone) taramalari — okutma zamanina gore sirali."""

    tarih: date
    items: list[ScanReportItem]
    #: (P34) O gunun konumsuz okutma sayisi. SESSIZ BOSLUK OLMAZ: sayi
    #: filtreden BAGIMSIZ hesaplanir, yoksa `konumsuz=true` suzgecini acan
    #: amir "kac tanesi" sorusunu ancak satirlari sayarak yanitlardi.
    konumsuz_sayisi: int = 0


# ------------------------------ dashboard ---------------------------------- #
AlarmTip = Literal[
    "kacirilan_tur", "eksik_checkpoint", "gecikmis_okutma", "uzak_okutma"
]


class AktifTurOut(BaseModel):
    patrol_window_id: uuid.UUID
    patrol_plan_id: uuid.UUID
    patrol_plan_ad: str | None = None
    pencere_baslangic: datetime
    pencere_bitis: datetime
    durum: str
    beklenen_checkpoint_sayisi: int | None = None
    okutulan_checkpoint_sayisi: int | None = None
    # (P181 7.3) Görsel devriye bileşeni için son okutma zamanı (hiç yoksa null).
    son_okutma: datetime | None = None


class AlarmOut(BaseModel):
    tip: AlarmTip
    olusma_zamani: datetime
    mesaj: str
    patrol_window_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None


#: (P133.3) Alarm ONEMI — TIPTEN TURETILIR, kolonda TUTULMAZ.
#:
#: DURUSTCE: sozlesme grup basina "en kotu onem" istiyor; ama gruplama
#: zaten (tip, devriye) ikilisiyle yapildigi icin bir grubun icindeki tum
#: olaylar AYNI tiptedir ve dolayisiyla ayni onemdedir. Yani "en kotu"
#: hesabi bugun her zaman tipin kendi onemini verir. Alan yine de
#: donuluyor: istemcinin siralama/renk karari icin tipten onem tablosunu
#: KENDISININ tasimasi, ayni bilgiyi iki yerde tutmak olurdu.
#:
#: Gercek bir OLAY-BASINA onem (orn. "12 dakika gecikme" ile "3 saat
#: gecikme") bugun veride YOK; eklenirse burasi max() olur ve sozlesme
#: degismez.
ALARM_ONEMI: dict[str, str] = {
    # Tur tamamen kacirildi: sahada kimse yok demektir.
    "kacirilan_tur": "yuksek",
    # Turun bir noktasi atlandi: tur yurudu, kapsama eksik.
    "eksik_checkpoint": "orta",
    # Okutma gecikti: sahada olabilir, gec kalmis.
    "gecikmis_okutma": "dusuk",
    # (P160) ORTA: tur yapilmis, kayit var — ama nerede yapildigi
    # soruluyor. `kacirilan_tur` kadar agir degil, `gecikmis_okutma`dan
    # daha somut (olculmus bir sapma var).
    "uzak_okutma": "orta",
}
AlarmOnemLiteral = Literal["dusuk", "orta", "yuksek"]


class AlarmOlayiOut(BaseModel):
    """Grup icindeki TEK bir olay — istemci grubu actiginda gosterir.

    NE YOK ve NEDEN — bu, gruplamanin govdeyi gercekten kucultmesini
    saglayan karardir:

      * `tip` ve `patrol_plan_id`: grubun ustunde bir kez duruyor.
      * `mesaj`: EN BUYUK alan (~100 bayt) ve grup icinde neredeyse AYNI
        cumlenin tekrariydi ("E-Devriye turunda okutma yok" x 6). Temsili
        metin grupta bir kez duruyor; olay satirinin tasidigi bilgi zaten
        KENDI zamani ve noktasidir.

    ILK OLCUM YANLISTI ve olcum onu dusurdu: yalniz `tip`i yukari almak
    govdeyi 1533 -> 1594 bayta BUYUTMUSTU (grup basligi tasarruftan
    pahali). Tekrar eden asil sey metindi.
    """

    olusma_zamani: datetime
    patrol_window_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None


class AlarmGrubuOut(BaseModel):
    """(tip, devriye) ikilisiyle toplanmis alarmlar."""

    tip: AlarmTip
    patrol_plan_id: uuid.UUID | None = None
    patrol_plan_ad: str | None = None
    #: Grubun TEMSILI metni — en yeni olayin cumlesi, istegin dilinde.
    #: Olay basina degil grup basina tutulur (bkz. AlarmOlayiOut).
    mesaj: str
    sayi: int
    en_son: datetime
    onem: AlarmOnemLiteral
    olaylar: list[AlarmOlayiOut]


class DashboardLiveOut(BaseModel):
    generated_at: datetime
    aktif_turlar: list[AktifTurOut]
    #: (P133.2) Aidat tahsilat orani — YALNIZ mali yetkisi olan role.
    #:
    #: Bu uc `security` ve `guvenlik_amiri`ne de acik; tahsilat orani MALI
    #: veridir ve guvenlik gorevlisinin isi degildir. Rol yetmiyorsa alan
    #: `null` doner ve pano o blogu HIC cizmez — "0%" gostermek, veriyi
    #: sizdirmadan yanlis bilgi vermek olurdu.
    #:
    #: Deger AYRI BIR UCTAN GELMEZ: panonun ek gidis-donusu olmasin diye
    #: ayni yanita bindirildi ve hesap `reports._tahsilat_ozet`ten AYNEN
    #: kullanilir — tahsilat oraninin ikinci bir tanimi olmasin diye.
    aidat_tahsilat_orani: int | None = None
    #: (P133.2) Tesis blogundaki NFC nokta sayisi. Ayri bir `/checkpoints`
    #: istegi acmamak icin bu yanita bindirildi (pano ek gidis-donus
    #: getirmemeli); yalniz AKTIF noktalar sayilir — pasif nokta sahada
    #: okutulmaz ve sayiya girmesi yaniltici olurdu.
    nfc_nokta_sayisi: int = 0
    # (P133.3) `son_alarmlar` KALDIRILDI, yerine gruplu liste geldi.
    # Sozlesme degisikligi bilinclidir ve tuketici olculdu: mobil yalniz
    # `aktif_turlar` okuyor, `son_alarmlar`in TEK tuketicisi web panosuydu.
    alarm_gruplari: list[AlarmGrubuOut]


# ---------------------------- patrol-windows ------------------------------- #
PatrolWindowDurumLiteral = Literal["bekliyor", "tamamlandi", "kacirildi"]


class PatrolWindowOut(BaseModel):
    id: uuid.UUID
    patrol_plan_id: uuid.UUID
    plan_adi: str | None = None
    pencere_baslangic: datetime
    pencere_bitis: datetime
    durum: str
    beklenen_checkpoint_sayisi: int
    okutulan_checkpoint_sayisi: int


class PatrolWindowOzet(BaseModel):
    toplam: int
    tamamlandi: int
    kacirildi: int
    bekliyor: int


class PatrolWindowListResponse(BaseModel):
    meta: PageMetaOut
    ozet: PatrolWindowOzet
    items: list[PatrolWindowOut]


# --------------------------- me/patrol-window ------------------------------ #
class MePatrolCheckpointOut(BaseModel):
    checkpoint_id: uuid.UUID
    ad: str
    sira: int
    okutuldu: bool
    okutma_zamani: datetime | None = None
    okutan_user_id: uuid.UUID | None = None


class MePatrolWindowInfo(BaseModel):
    id: uuid.UUID
    patrol_plan_id: uuid.UUID
    plan_adi: str | None = None
    pencere_baslangic: datetime
    pencere_bitis: datetime
    durum: str


class MePatrolWindowItem(MePatrolWindowInfo):
    checkpoints: list[MePatrolCheckpointOut]


class MePatrolWindowResponse(BaseModel):
    generated_at: datetime
    window: MePatrolWindowInfo | None = None
    checkpoints: list[MePatrolCheckpointOut]
    windows: list[MePatrolWindowItem]


# ------------------------------ icerik cevirisi ---------------------------- #
CeviriDurum = Literal["hazir", "bekliyor", "hata"]


class CevrilebilirOut(BaseModel):
    """Cevrilebilir YAYIN icerigi (duyuru / site kurali / etkinlik) ortak alanlari.

    Govdedeki metin alanlari (baslik + govde/icerik/aciklama) Accept-Language
    ile SECILEN dilde doner; asagidaki alanlar o metnin NE oldugunu soyler:

    * `orijinal_dil`   : icerigin yazildigi dil (kaynak).
    * `gosterilen_dil` : govdedeki metnin GERCEK dili. Ceviri hazir degilse
                         geri-dusme yuzunden `orijinal_dil`e esit olur.
    * `ceviri_durumu`  : istenen dil icin hazir | bekliyor | hata. `bekliyor`
                         iken istemci "çeviri hazırlanıyor" gosterebilir —
                         metin alanlari BOS DEGIL, orijinali tasir.
    * `cevirildi_mi`   : govdedeki metin MAKINE cevirisi mi? Orijinalde ve elle
                         duzeltilmis ceviride false.
    * `orijinal`       : orijinal metinler ({"baslik": ..., ...}) — HER ZAMAN
                         doner (ayri istek/parametre gerekmez), boylece istemci
                         "orijinali goster" secenegini tek yanitla sunabilir.
    """

    orijinal_dil: str = "tr"
    gosterilen_dil: str = "tr"
    ceviri_durumu: CeviriDurum = "hazir"
    cevirildi_mi: bool = False
    orijinal: dict[str, str] = Field(default_factory=dict)


# ---------------------------- announcements -------------------------------- #
class AnnouncementCreate(BaseModel):
    baslik: str = Field(..., min_length=1, max_length=200)
    govde: str = Field(..., min_length=1, max_length=5000)
    # Opsiyonel gorsel: /uploads/presign ile yuklenen obje anahtari.
    foto_key: str | None = None


class AnnouncementUpdate(BaseModel):
    baslik: str | None = Field(None, min_length=1, max_length=200)
    govde: str | None = Field(None, min_length=1, max_length=5000)
    # Acikca null gonderilirse gorsel kaldirilir; alan hic yoksa dokunulmaz.
    foto_key: str | None = None


class AnnouncementOut(CevrilebilirOut):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    # baslik/govde: Accept-Language ile secilen dilde (bkz. CevrilebilirOut).
    baslik: str
    govde: str
    foto_key: str | None = None
    # Goruntuleme icin kisa omurlu presigned GET URL (foto_key varsa).
    foto_url: str | None = None
    olusturan_user_id: uuid.UUID
    # Liste ekranlarinda "kim gonderdi" icin ad (join ile doldurulur).
    olusturan_ad: str | None = None
    created_at: datetime
    updated_at: datetime


class AnnouncementListResponse(BaseModel):
    meta: PageMetaOut
    items: list[AnnouncementOut]


# ----------------------------- complaints ---------------------------------- #
class TelefonIstek(BaseModel):
    telefon: str = Field(min_length=5, max_length=32)


class TelefonKodIstek(BaseModel):
    telefon: str = Field(min_length=5, max_length=32)
    kod: str = Field(min_length=4, max_length=12)


class EpostaKodIstek(BaseModel):
    """(P172 §5) E-posta ile giris kodu istegi.

    (P205 §1) TESIS KODU ARTIK OPSIYONEL.

    Eski gerekce: "telefon platform genelinde benzersiz, e-posta tenant
    icinde — tesis kodu olmadan iki tesis birbirine karisirdi." Dogru
    ama COZUMU YANLISTI: kullaniciya ezberlemesi gerekmeyen bir kod
    yazdirmak.

    YENI DAVRANIS: slug verilmezse kod, ADRESIN UYE OLDUGU TUM
    TESISLERE AYNI DEGERLE yazilir. Dogrulamada eslesen tesis TEK ise
    dogrudan giris; BIRDEN COK ise 409 `tesis_secimi_gerekli` ve
    istemci secim gosterir — parola yolundaki davranisin AYNISI.

    Kod ADRESE gider ve adresin sahibi TEK KISIDIR; ayni kodu iki
    tenant satirina yazmak yeni bir yetki vermez.
    """

    tenant_slug: str | None = Field(None, min_length=1, max_length=100)
    eposta: EmailStr


class EpostaKodDogrulaIstek(BaseModel):
    tenant_slug: str | None = Field(None, min_length=1, max_length=100)
    eposta: EmailStr
    kod: str = Field(min_length=4, max_length=12)


# (P181 Bölüm 2) PAROLA SIFIRLAMA — "şifremi unuttum". E-POSTA TABANLI, SMS YOK.
# `EpostaKodIstek` ile AYNI kimlik (tenant + e-posta); ayrı amaç/hız-sınırı.
class SifreKodIstek(BaseModel):
    tenant_slug: str = Field(min_length=1, max_length=100)
    eposta: EmailStr


class SifreSifirlaIstek(BaseModel):
    tenant_slug: str = Field(min_length=1, max_length=100)
    eposta: EmailStr
    kod: str = Field(min_length=4, max_length=12)
    yeni_parola: str = Field(..., min_length=8)

    @field_validator("yeni_parola")
    @classmethod
    def _strong(cls, v: str) -> str:
        return validate_password_strength(v)


class KayitDurumResponse(BaseModel):
    """`POST /auth/giris/kod-iste`in KASTEN BILGISIZ yaniti.

    (P155r2) Bu sema P148 onay akisindan ARTA KALDI ve tek tasidigi deger
    (`onay_bekliyor`) artik bir onay kuyrugunu ANLATMIYOR — o kuyruk
    kaldirildi. Yine de DEGISTIRILMEDI ve sebebi guvenlik: `kod-iste`
    numaranin kayitli olup olmadigini SIZDIRMAMALI, yani yanit her
    durumda BYTE BYTE AYNI olmali. Sabit tek degerli bir alan bunu
    yapisal olarak garantiler; "gonderildi/gonderilmedi" gibi anlamli bir
    ad koymak, ilk degistiren kisiyi sizintiya davet ederdi.
    """

    durum: Literal["onay_bekliyor"]


#: (P154) ROL SECIMLI KAYIT — kaydolabilen roller.
#:
#: `admin` YOK: platform sahibidir, tesis kaydiyla acilmaz.
#: `guvenlik_amiri` YOK: brief'in mobil (yonetici/sakin/guvenlik/tesis
#: gorevlisi) ve web (yonetici/denetci) listelerinde GECMIYOR. Enum'da
#: duruyor ve demo hesabi var; kaydolabilir yapmak bir URUN karari
#: oldugu icin tek tarafli alinmadi.
KayitRolu = Literal["yonetici", "resident", "security", "tesis_gorevlisi", "denetci"]


# ==================== (P155r2 / §3) YONETICI SELF-SIGNUP =================== #


class TesisOlusturRequest(BaseModel):
    """Yonetici tesisini UYGULAMADAN acar — admin paneli adimi YOK.

    IKI YONTEMDEN BIRI ZORUNLU (`parola` ya da `baglama_jetonu`), IKISI
    BIRDEN DEGIL. Kural `model_validator`da (uc govdesinde degil) ki
    sozlesmeyi okuyan istemci de bilsin.

    `tesis_kodu` ISTENMEZ ve GONDERILEMEZ: kodu SUNUCU uretir (`ad` +
    kayit tarihi, goc 0037/0041). Istemciye birakmak, ayni kurali iki
    yerde tutmak ve cakisma cozumunu istemciye yikmak olurdu.
    """

    tesis_ad: str = Field(min_length=2, max_length=120, examples=["Oltu Sitesi"])
    ad: str = Field(min_length=2, max_length=120, examples=["Ayse Yilmaz"])
    #: (P187) TELEFON OPSIYONEL. Bu uc pratikte SOSYAL (SSO) "yeni tesis" yolu
    #: icindir; SSO kimligi telefon vermez ve yonetici zaten SSO ile girer —
    #: telefon giris anahtari DEGILDIR. P185'te akis yeniden kurulurken telefon
    #: formdan cikti (sema zorunlu kalmisti -> 422, kayit kilitlenmisti).
    #: Verilirse iletisim olarak saklanir ve benzersizligi kontrol edilir.
    telefon: str | None = Field(default=None, min_length=5, max_length=32, examples=["+905321112203"])
    #: Elle kayit yolu. Sosyal yolda BOS birakilir.
    parola: str | None = Field(default=None, min_length=8, max_length=128)
    #: Sosyal yol: `POST /auth/oauth/sonuc`tan gelen kisa omurlu jeton.
    baglama_jetonu: str | None = None

    @model_validator(mode="after")
    def _yontem_kurali(self) -> "TesisOlusturRequest":
        if bool(self.parola) == bool(self.baglama_jetonu):
            raise ValueError(
                "Parola VEYA sosyal baglama jetonu verilmeli (ikisi birden degil)."
            )
        return self


class TesisOlusturResponse(BaseModel):
    """Tesis ACILDI ve oturum ACILDI — ayri bir giris adimi YOK.

    `tesis_kodu` DONUYOR cunku yoneticinin sakinlerine/personeline
    iletecegi sey odur ve SMS saglayicisi baglanana kadar tek dagitim
    yolu ELLE iletmektir (sartname §4). Kodu ilk ekranda gostermek,
    yoneticiyi onu aramaya gondermekten iyidir.
    """

    tesis_ad: str
    tesis_kodu: str = Field(examples=["OLTU-260715"])
    jetonlar: TokenPair


class RolKayitBaslaRequest(BaseModel):
    """(P154) Rol secimli kaydin 1. adimi.

    `daire_no` YALNIZ `resident` icin anlamlidir ve orada ZORUNLUDUR;
    yoneticiden daire istenmez (brief). Dogrulamasi `model_validator`da,
    uc govdesinde degil: kural sozlesmenin parcasi olmali ki openapi'yi
    okuyan istemci de bilsin.
    """

    rol: KayitRolu
    tesis_kodu: str = Field(min_length=4, max_length=32, examples=["OLTU-260715"])
    telefon: str = Field(min_length=5, max_length=32, examples=["+905321112203"])
    daire_no: str | None = Field(default=None, max_length=32)
    blok: str | None = Field(default=None, max_length=32)

    @model_validator(mode="after")
    def _daire_kurali(self) -> "RolKayitBaslaRequest":
        if self.rol == "resident" and not (self.daire_no or "").strip():
            raise ValueError("Site sakini icin daire no zorunludur.")
        return self


class RolKayitBaslaResponse(BaseModel):
    """Tesis DOGRULANDI; eslesme sonucu SOYLENMEZ.

    `tesis_ad` donuyor cunku tesis kodu zaten kamuya aciktir (P148.1
    guvenlik notu) ve en sik yazim hatasi orada olur — kullaniciya
    "yanlis tesis" geri bildirimi vermek bir sey sizdirmaz.

    Telefonun O TESISTE KAYITLI OLUP OLMADIGI ise SOYLENMEZ: yanit
    eslesme olsa da olmasa da AYNIDIR ve SMS yalnizca eslesmede gider.
    Aksi hâlde uc, "hangi numara bu tesiste hangi rolde" sorusunu
    yanitlayan bir SORGULAMA ARACI olurdu.

    `telefon_maskeli`, KULLANICININ YAZDIGI numaradan uretilir — kayitli
    bir numaradan degil; dolayisiyla maskenin kendisi de bilgi tasimaz.
    """

    tesis_ad: str
    telefon_maskeli: str


class RolKayitDogrulaRequest(BaseModel):
    telefon: str = Field(min_length=5, max_length=32)
    kod: str = Field(min_length=4, max_length=12)


class RolKayitDogrulaResponse(BaseModel):
    """Kod dogru: parola belirleme jetonu.

    OTURUM DEGIL — `setup_token` yalnizca `/auth/set-password`te gecer.
    Kayit, parola belirlenene kadar TAMAMLANMAMIS sayilir.
    """

    setup_token: str


ComplaintDurum = Literal["acik", "is_emri", "cozuldu", "reddedildi", "geri_alindi"]
TaskOncelik = Literal["dusuk", "orta", "yuksek"]


class ComplaintPhotoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    foto_key: str
    sira: int
    foto_url: str | None = None


class ComplaintStatusHistoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    durum: str
    actor_role: str
    sebep: str | None = None
    created_at: datetime


# ========================= P33 YONETISIM MODULLERI ========================== #
TalepOncelik = Literal["dusuk", "normal", "yuksek", "acil"]


class ComplaintCreate(BaseModel):
    baslik: str = Field(..., min_length=1, max_length=200)
    mesaj: str = Field(..., min_length=1, max_length=5000)
    kategori_id: uuid.UUID | None = None
    # (P33) Talebin ILGILI OLDUGU daire. Acanin kendi dairesi OTOMATIK
    # varsayilmaz: sakin ortak alan icin de talep acar ("asansor bozuk") ve
    # talebi kendi dairesine yapistirmak, is emrini yanlis yere yonlendirirdi.
    unit_id: uuid.UUID | None = None
    # En fazla 3 gorsel; her biri /uploads/presign obje anahtari.
    foto_keys: list[str] = Field(default_factory=list, max_length=3)


class ComplaintOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    acan_user_id: uuid.UUID
    acan_ad: str | None = None
    baslik: str
    mesaj: str
    kategori_id: uuid.UUID | None = None
    kategori_ad: str | None = None
    durum: str
    # (P33) Is takibi alanlari.
    unit_id: uuid.UUID | None = None
    unit_no: str | None = None
    oncelik: TalepOncelik = "normal"
    atanan_personel_id: uuid.UUID | None = None
    atanan_personel_ad: str | None = None
    fotograflar: list[ComplaintPhotoOut] = Field(default_factory=list)
    gecmis: list[ComplaintStatusHistoryOut] = Field(default_factory=list)
    # Bagli is emri (varsa): task ozeti.
    is_emri_id: uuid.UUID | None = None
    is_emri_durum: str | None = None  # 'acik' (atandi) | 'tamamlandi'
    created_at: datetime
    updated_at: datetime


class ComplaintUpdate(BaseModel):
    """(P33) Yonetimin is takibi alanlari — durum makinesine DOKUNMAZ.

    Oncelik/atama, talebin YASAM DONGUSUNDEN bagimsizdir: acik bir talebin
    onceligi is emrine donusmeden de yukselebilir. Bu yuzden ayri bir uc,
    convert govdesine sikistirilmis alanlar degil.
    """

    unit_id: uuid.UUID | None = None
    oncelik: TalepOncelik | None = None
    #: `personel_kayit` kaydi (app_user DEGIL): her personelin uygulama
    #: hesabi yoktur (bkz. P27). Uygulamali atama `convert` ile yapilir.
    atanan_personel_id: uuid.UUID | None = None
    model_config = ConfigDict(extra="forbid")


class ComplaintListResponse(BaseModel):
    meta: PageMetaOut
    items: list[ComplaintOut]


class ComplaintConvertRequest(BaseModel):
    """Talebi is emrine donustur (yonetici)."""
    kategori_id: uuid.UUID | None = None       # onaylanan/degistirilen kategori
    oncelik: TaskOncelik = "orta"
    atanan_user_id: uuid.UUID = Field(...)
    not_: str | None = Field(None, alias="not", max_length=2000)
    model_config = ConfigDict(populate_by_name=True)


class ComplaintResolveRequest(BaseModel):
    """Dogrudan coz (yonetici) — opsiyonel cozum notu timeline'a yazilir."""
    cozum_notu: str | None = Field(None, max_length=2000)


class ComplaintDeclineRequest(BaseModel):
    """Reddet (yonetici) — sebep ZORUNLU."""
    sebep: str = Field(..., min_length=1, max_length=2000)


# ------------------------------- visitors ---------------------------------- #
# Ziyaretci artik LOG-ONLY kayittir (onay/red akisi kaldirildi): durum yok,
# sakin yaniti yok. Guvenlik kaydeder + hedef sakine BILGILENDIRME push'u gider.


# ======================= (P203 §5) FAZLA MESAI ============================== #
class MesaiKisiOut(BaseModel):
    user_id: uuid.UUID
    ad: str
    toplam_saat: float
    #: HAFTA HAFTA hesaplanir (4857 md. 41 haftalik esige bakar); ay
    #: toplamiyla hesaplamak, bir hafta 60 otekinde 30 saat calisan
    #: biri icin "fazla mesai yok" derdi.
    fazla_saat: float
    saatlik_ucret_kurus: int | None = None
    #: Ucret tanimsizsa `None` — SIFIR DEGIL. Sifir yazmak, yoneticiye
    #: "mesai yok" demenin sessiz ve yanlis yoluydu.
    fazla_mesai_kurus: int | None = None
    ucret_tanimsiz: bool = False
    gidere_yazildi: bool = False


class MesaiOzetOut(BaseModel):
    yil: int
    ay: int
    katsayi: float
    #: Hesabin KAYNAGI. Su an daima `"plan"`: sistemde gercek bir mesai
    #: kaydi (turnike/QR) YOK ve uydurmak, gelmis bir gorevliyi eksik
    #: gostermeye acikti — ustelik o sayi PARAYA donusuyor.
    kaynak: str = "plan"
    kisiler: list[MesaiKisiOut] = []


class MesaiGidereYazSatiri(BaseModel):
    user_id: uuid.UUID
    #: Yonetici saati DUZELTEBILIR: hesap plan uzerinden yapiliyor ve
    #: gercegi bilen kisi odur. Bos ise plandaki fazla saat kullanilir.
    gerceklesen_fazla_saat: float | None = Field(None, ge=0, le=400)


class MesaiGidereYazIstek(BaseModel):
    yil: int = Field(..., ge=2000, le=2100)
    ay: int = Field(..., ge=1, le=12)
    satirlar: list[MesaiGidereYazSatiri]


# ===================== (P203 §4) VARDIYA PLANI ============================== #
class VardiyaKisiOut(BaseModel):
    plan_id: uuid.UUID
    user_id: uuid.UUID
    ad: str
    rol: str


class VardiyaSlotOut(BaseModel):
    """Bir gunun bir vardiyasi."""

    shift_id: uuid.UUID
    shift_ad: str
    baslangic_saat: time
    bitis_saat: time
    kisiler: list[VardiyaKisiOut] = []
    #: BOS bayragi `kisiler`den TURETILEBILIR ama yine de doner: istemci
    #: "uzunluk 0" kontrolunu her cizim yerinde tekrarlasaydi birinde
    #: unuturdu ve bos vardiya BELIRGIN olmazdi (istegin acik sarti).
    bos: bool = False


class VardiyaGunuOut(BaseModel):
    tarih: date
    slotlar: list[VardiyaSlotOut] = []


class VardiyaHaftaOut(BaseModel):
    baslangic: date
    bitis: date
    gunler: list[VardiyaGunuOut] = []


class VardiyaAtamaIstek(BaseModel):
    shift_id: uuid.UUID
    tarih: date
    user_id: uuid.UUID
    not_metni: str | None = Field(None, max_length=500)


class VardiyaPlanOut(BaseModel):
    id: uuid.UUID
    #: (P205 §2) SERBEST vardiyada YOK — satir kendi saatlerini tasir.
    shift_id: uuid.UUID | None = None
    tarih: date
    user_id: uuid.UUID
    durum: str
    not_metni: str | None = None
    #: (4857/63) Haftalik 45 saat asildiysa UYARI doner — RED DEGIL.
    #: Ustu FAZLA MESAIDIR: yasal (md. 41) ama maliyetli. Engellemek,
    #: sistemin desteklemesi gereken mesru bir durumu imkansiz kilardi.
    uyarilar: list[str] = []


# ================= (P205 §2) ZAMAN CIZELGESI ================================ #
class VardiyaBlokOut(BaseModel):
    """Cizelgede TEK bir vardiya blogu — bir kisinin bir vardiyasi.

    SAATLER COZULMUS GELIR (`baslar`/`biter` tam damga). Istemciye
    "sablon mu satir mi" secimini yaptirmak, ayni kurali web'de ve
    mobilde IKI KEZ yazmak olurdu; biri sapinca cizelge yalan soylerdi.
    """

    plan_id: uuid.UUID
    tarih: date
    baslar: datetime
    biter: datetime
    #: Sablondan geliyorsa adi; serbest vardiyada YOK.
    shift_ad: str | None = None
    not_metni: str | None = None
    #: (§2.2) 22:00-05:00 gibi ERTESI GUNE tasan vardiya. Istemci bunu
    #: `baslar`/`biter`den de cikarabilir ama cizelge bunu IKI GUNDE
    #: cizmek zorunda ve bayragi tek yerde uretmek, iki yuzeyde ayri
    #: hesaplamaktan daha guvenli.
    gece_asiyor: bool = False


class VardiyaCizelgeKisiOut(BaseModel):
    user_id: uuid.UUID
    ad: str
    rol: str
    bloklar: list[VardiyaBlokOut] = []


class VardiyaCizelgeOut(BaseModel):
    baslangic: date
    bitis: date
    #: Vardiyasi OLMAYAN personel de listede DURUR: cizelgenin isi
    #: "kim calisiyor" kadar "kim BOSTA" sorusunu da yanitlamaktir.
    personel: list[VardiyaCizelgeKisiOut] = []


class VardiyaTopluIstek(BaseModel):
    """(§2.2) Hizli vardiya ekle — TARIH ARALIGI.

    `cakisanlari_atla` VARSAYILAN OLARAK FALSE ve bu bilincli: istek
    acikca "cakisan gunler ATLANMASIN, kullaniciya sorulsun" diyor.
    Sunucu once REDDEDER ve cakisan gunleri sayar; istemci kullaniciya
    sorup ISTERSE bayragi acik gonderir.
    """

    user_id: uuid.UUID
    baslangic_tarih: date
    bitis_tarih: date
    baslangic_saat: time
    bitis_saat: time
    not_metni: str | None = Field(None, max_length=500)
    cakisanlari_atla: bool = False


class VardiyaTopluGunOut(BaseModel):
    tarih: date
    #: `eklendi` | `cakisma` | `eklenebilir` (yalniz onizlemede)
    durum: str
    plan_id: uuid.UUID | None = None


class VardiyaTopluOut(BaseModel):
    #: FALSE = HICBIR SEY YAZILMADI: cakisma var ve kullanici henuz
    #: karar vermedi. Istemci gunleri gosterip istegi
    #: `cakisanlari_atla=true` ile TEKRARLAR (ya da vazgecer).
    uygulandi: bool = True
    eklenen: int
    cakisan: int
    gunler: list[VardiyaTopluGunOut] = []
    uyarilar: list[str] = []


# ================= (P207 §1) VARDIYA KALIBI + AY BAZINDA TOPLU ============== #
class VardiyaDilim(BaseModel):
    """Bir gunun TEK bir vardiya dilimi."""

    ad: str = Field(..., min_length=1, max_length=40)
    baslangic: time
    bitis: time


class VardiyaKalibiCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=60)
    #: EN AZ BIR, EN FAZLA ALTI dilim. Alti, saatlik nobet gibi bir
    #: kaliba bile yeter; sinirsiz birakmak tek istekle yuzlerce
    #: vardiya uretilmesine kapi acardi.
    dilimler: list[VardiyaDilim] = Field(..., min_length=1, max_length=6)
    aktif: bool = True


class VardiyaKalibiOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    dilimler: list[VardiyaDilim]
    aktif: bool


class VardiyaKalibiListResponse(BaseModel):
    items: list[VardiyaKalibiOut] = []


class VardiyaKalipUygulaIstek(BaseModel):
    """(§1.3) Secili GUNLERE kalip uygula.

    GUNLER ISTEMCIDEN GELIR, aralik degil: takvimde tiklayarak,
    surukleyerek ya da "tum pazartesiler" kalibiyla secilen gunler
    duzensiz olabilir. Sunucuya "baslangic-bitis" gondermek, o secimi
    ANLATAMAZDI.
    """

    kalip_id: uuid.UUID | None = None
    #: Kalip KAYDEDILMEDEN de uygulanabilir (tek seferlik plan).
    dilimler: list[VardiyaDilim] | None = None
    gunler: list[date] = Field(..., min_length=1, max_length=62)
    #: dilim sirasi -> o dilime atanacak personel kimlikleri.
    #: Bos birakilan dilim ATLANIR (o gun o vardiya BOS kalir).
    atamalar: dict[int, list[uuid.UUID]] = Field(default_factory=dict)
    #: `yok` | `haftalik`. Rotasyon, dilim atamalarini HAFTA BASINA
    #: bir kaydirir (A ekibi gunduz -> gece, B ekibi gece -> gunduz).
    rotasyon: Literal["yok", "haftalik"] = "yok"
    not_metni: str | None = Field(None, max_length=500)
    #: TRUE ise HICBIR SEY YAZILMAZ — yalnizca onizleme doner.
    kuru: bool = False
    cakisanlari_atla: bool = False

    @model_validator(mode="after")
    def _kaynak_tek(self) -> "VardiyaKalipUygulaIstek":
        if (self.kalip_id is None) == (self.dilimler is None):
            # Ikisi birden ya da hicbiri: hangi dilimlerin uygulanacagi
            # BELIRSIZ olurdu.
            raise ValueError("kalip_id VEYA dilimler verilmeli (ikisi degil)")
        return self


class VardiyaKalipGunDilim(BaseModel):
    """Onizleme/sonuc satiri: gun x dilim x kisi."""

    tarih: date
    dilim: str
    baslangic: time
    bitis: time
    user_id: uuid.UUID
    ad: str | None = None
    #: `eklenecek` | `eklendi` | `cakisma` | `zaten_var`
    durum: str


class VardiyaKalipSonuc(BaseModel):
    """(§1.3) Onizleme ya da uygulama sonucu.

    ONIZLEME KAYDETMEDEN ONCE KAC VARDIYA OLUSACAGINI SOYLER (istegin
    acik sarti): `eklenecek` sayisi. Uygulamada `parti_id` doner ve
    GERI ALMA onu kullanir.
    """

    uygulandi: bool
    parti_id: uuid.UUID | None = None
    eklenecek: int = 0
    eklenen: int = 0
    cakisan: int = 0
    zaten_var: int = 0
    satirlar: list[VardiyaKalipGunDilim] = []
    uyarilar: list[str] = []


class VardiyaPartiGeriAlSonuc(BaseModel):
    parti_id: uuid.UUID
    iptal_edilen: int


class VardiyaGuncelleIstek(BaseModel):
    """(§2.3) Blogun saatini/gununu degistir.

    Verilmeyen alan DEGISMEZ. `None` ile "sablona geri don" DEMEK
    MUMKUN DEGIL — bilincli: bos birakmak "degistirme" demek ve iki
    anlami tek alana yuklemek, yanlislikla saat silmeye acik olurdu.
    """

    tarih: date | None = None
    baslangic_saat: time | None = None
    bitis_saat: time | None = None
    not_metni: str | None = Field(None, max_length=500)


class VardiyaSimdiOut(BaseModel):
    """(§4.2) Anlik durum."""

    #: Tenant'in YEREL saati (sunucunun UTC'si degil).
    zaman: datetime
    gorevdeki_vardiya: VardiyaSlotOut | None = None
    gorevdekiler: list[VardiyaKisiOut] = []
    sonraki_vardiya: VardiyaSlotOut | None = None
    sonrakiler: list[VardiyaKisiOut] = []
    sonraki_baslangic: datetime | None = None


class DaireAramaOut(BaseModel):
    """(P203 §3) Arama sonucu: daire + AKTIF sakinleri.

    Sakinler AYNI YANITTA doner. Ayri bir cagri, arama sonucundan
    birini secen gorevliye ikinci bir bekleme daha yasatirdi — ustelik
    hedef sakin secimi ZORUNLU oldugu icin o cagri HER ZAMAN yapilirdi.
    """

    id: uuid.UUID
    no: str
    blok: str | None = None
    sakinler: list["UnitResidentBriefOut"] = []


class VisitorCreate(BaseModel):
    """Guvenlik kaydi: daire unit_id VEYA unit_no ile verilir (tam biri).

    Kapidaki guvenlik daire numarasini bilir (unit listesine RBAC'i yoktur);
    unit_no sunucuda tenant icinde cozulur — bulunamazsa 422.
    """

    unit_id: uuid.UUID | None = None
    unit_no: str | None = Field(None, min_length=1, max_length=50)
    ziyaretci_ad: str = Field(..., min_length=1, max_length=200)
    # Guvenligin sectigi TEK hedef sakin: bildirim + gorunurluk + karar YALNIZ
    # onda. O dairenin AKTIF sakini olmali (sunucu dogrular; degilse 422).
    target_resident_user_id: uuid.UUID
    # "not" SQL/Python anahtar sozcugu — kolon/alan adi codebase deseniyle
    # 'notlar' (asset_checkout ile ayni).
    notlar: str | None = Field(None, min_length=1, max_length=1000)

    @model_validator(mode="after")
    def _tek_daire_referansi(self) -> "VisitorCreate":
        if (self.unit_id is None) == (self.unit_no is None):
            raise ValueError("unit_id veya unit_no alanlarindan tam biri verilmeli")
        return self


class VisitorUpdate(BaseModel):
    """Guvenlik ziyaretci kaydini duzenler (kismi — yalniz verilen alan degisir).
    Daire referansi verilecekse unit_id VEYA unit_no (ikisi birlikte olmaz);
    daire/hedef degisirse hedef, dairenin AKTIF sakini olarak yeniden dogrulanir.
    notlar ACIKCA null gonderilirse temizlenir; alan hic yoksa dokunulmaz."""

    unit_id: uuid.UUID | None = None
    unit_no: str | None = Field(None, min_length=1, max_length=50)
    ziyaretci_ad: str | None = Field(None, min_length=1, max_length=200)
    target_resident_user_id: uuid.UUID | None = None
    notlar: str | None = Field(None, min_length=1, max_length=1000)

    @model_validator(mode="after")
    def _tek_daire_referansi(self) -> "VisitorUpdate":
        if self.unit_id is not None and self.unit_no is not None:
            raise ValueError("unit_id ve unit_no birlikte verilemez")
        return self


class VisitorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    unit_id: uuid.UUID
    # Daire numarasi (join ile doldurulur — guvenlik/sakin ekrani icin).
    unit_no: str | None = None
    ziyaretci_ad: str
    notlar: str | None = None
    kaydeden_user_id: uuid.UUID
    # Kaydi acan guvenligin adi (join ile).
    kaydeden_ad: str | None = None
    # Hedef sakin (bilgilendirme/gorunurluk sahibi) + adi (join ile).
    target_resident_user_id: uuid.UUID
    target_resident_ad: str | None = None
    # Cikis damgasi (G3) — null ise ziyaretci HALA ICERIDE.
    cikis_zamani: datetime | None = None
    created_at: datetime


class UnitResidentBriefOut(BaseModel):
    """Bir dairenin AKTIF sakini — hedef sakin secicisi icin (user_id + ad).

    Guvenlik ziyaretci kaydinda hangi sakine bildirilecegini secer; bu uc o
    listeyi verir (auth.md §4). Sakin komsularini listeleyemez (403)."""

    user_id: uuid.UUID
    ad: str


class VisitorListResponse(BaseModel):
    meta: PageMetaOut
    items: list[VisitorOut]


# -------------------------------- kargo ------------------------------------- #
KargoDurum = Literal["bekliyor", "teslim_alindi"]


class KargoCreate(BaseModel):
    """Guvenlik kaydi: daire unit_id VEYA unit_no ile verilir (tam biri —
    visitor ile ayni desen). foto_key /uploads/presign akisindan gelir."""

    unit_id: uuid.UUID | None = None
    unit_no: str | None = Field(None, min_length=1, max_length=50)
    firma: str = Field(..., min_length=1, max_length=200)
    # Opsiyonel paket fotografi: /uploads/presign ile yuklenen obje anahtari.
    foto_key: str | None = None
    # "not" SQL/Python anahtar sozcugu — alan adi codebase deseniyle 'notlar'.
    notlar: str | None = Field(None, min_length=1, max_length=1000)

    @model_validator(mode="after")
    def _tek_daire_referansi(self) -> "KargoCreate":
        if (self.unit_id is None) == (self.unit_no is None):
            raise ValueError("unit_id veya unit_no alanlarindan tam biri verilmeli")
        return self


class KargoUpdate(BaseModel):
    """Sakin teslim isareti — tek gecerli hedef durum (geri donus yok);
    teslim alan + zaman sunucuda damgalanir."""

    durum: Literal["teslim_alindi"]


class KargoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    unit_id: uuid.UUID
    # Daire numarasi (join ile doldurulur).
    unit_no: str | None = None
    firma: str
    foto_key: str | None = None
    # Goruntuleme icin kisa omurlu presigned GET URL (foto_key varsa).
    foto_url: str | None = None
    notlar: str | None = None
    durum: str
    kaydeden_user_id: uuid.UUID
    # Kaydi acan guvenligin adi (join ile).
    kaydeden_ad: str | None = None
    teslim_alan_user_id: uuid.UUID | None = None
    # Teslim alan sakinin adi (join ile; teslim alinmadiysa null).
    teslim_alan_ad: str | None = None
    teslim_zamani: datetime | None = None
    created_at: datetime


class KargoListResponse(BaseModel):
    meta: PageMetaOut
    items: list[KargoOut]


# --------------------- unit access permission (yonetici) -------------------- #
AccessRequestDurum = Literal["bekliyor", "onaylandi", "reddedildi"]
# Sakinin verebilecegi karar — 'bekliyor'a geri donus yok.
AccessRequestKarar = Literal["onaylandi", "reddedildi"]


class UnitAccessRequestCreate(BaseModel):
    """Yonetici izin talebi: bir dairenin ziyaretci/paket kayitlarini TEK
    SEFERLIK gormek icin. Daire unit_id VEYA unit_no ile verilir (tam biri)."""

    unit_id: uuid.UUID | None = None
    unit_no: str | None = Field(None, min_length=1, max_length=50)

    @model_validator(mode="after")
    def _tek_daire_referansi(self) -> "UnitAccessRequestCreate":
        if (self.unit_id is None) == (self.unit_no is None):
            raise ValueError("unit_id veya unit_no alanlarindan tam biri verilmeli")
        return self


class UnitAccessRequestDecision(BaseModel):
    """Sakin karari — onay/red (karar veren + zaman sunucuda damgalanir)."""

    durum: AccessRequestKarar


class UnitAccessRequestOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    unit_id: uuid.UUID
    unit_no: str | None = None
    granted_to_yonetici_user_id: uuid.UUID
    # Talebi acan yoneticinin adi (join ile).
    yonetici_ad: str | None = None
    granted_by_resident_user_id: uuid.UUID | None = None
    # Karari veren sakinin adi (join ile; karar verilmemisse null).
    resident_ad: str | None = None
    durum: str
    used: bool
    requested_at: datetime
    decided_at: datetime | None = None
    used_at: datetime | None = None


class UnitAccessRequestListResponse(BaseModel):
    meta: PageMetaOut
    items: list[UnitAccessRequestOut]


class BulkAccessRequestResult(BaseModel):
    """Toplu izin talebi sonucu: her sakinli daire icin bekleyen talep olusur.
    Zaten acik (bekleyen) veya kullanilmamis onayli izni olan daireler atlanir
    (mukerrer bildirim spam'ini onler). Per-daire sakin RIZASI korunur — toplu
    talep hicbir onayi baypas etmez."""

    created: int  # yeni acilan bekleyen talep sayisi
    skipped: int  # zaten acik/onayli oldugu icin atlanan daire sayisi
    items: list[UnitAccessRequestOut]  # yeni acilan talepler (daire adiyla)


class GrantedUnitOut(BaseModel):
    """Talebi acanin SU AN goruntuleyebilecegi daire (onaylandi + kullanilmamis)."""

    request_id: uuid.UUID  # izin (talep) kaydinin id'si
    unit_id: uuid.UUID
    unit_no: str | None = None
    decided_at: datetime | None = None


class GrantedUnitsResponse(BaseModel):
    items: list[GrantedUnitOut]


# ---------------------------- ortak alan / rezervasyon ---------------------- #
# Onay akisi KALDIRILDI: bos slot talebi ANINDA onaylanir (durum='onaylandi').
# Tek gecis 'onaylandi' -> 'iptal' (sakin/yonetim iptali; slotu bosaltir).
RezervasyonDurum = Literal["onaylandi", "iptal"]


# Musaitlik: alan her gun [acilis, kapanis) araliginda, slot_dakika slot
# uzunluguyla rezerve edilebilir. Varsayilan tum-gun (00:00-23:59:59, 60 dk).
_ACILIS_VARSAYILAN = time(0, 0)
_KAPANIS_VARSAYILAN = time(23, 59, 59)
_SLOT_VARSAYILAN = 60


class OrtakAlanCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=200)
    aciklama: str | None = Field(None, min_length=1, max_length=1000)
    # "HH:MM"/"HH:MM:SS"; kapanis > acilis. Girilmezse tum-gun rezerve edilebilir.
    acilis: time = _ACILIS_VARSAYILAN
    kapanis: time = _KAPANIS_VARSAYILAN
    slot_dakika: int = Field(_SLOT_VARSAYILAN, gt=0, le=1440)

    @model_validator(mode="after")
    def _saat(self) -> "OrtakAlanCreate":
        if self.kapanis <= self.acilis:
            raise ValueError("kapanis acilistan sonra olmali")
        return self


class OrtakAlanUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=200)
    aciklama: str | None = Field(None, min_length=1, max_length=1000)
    # Alan kaldirma = aktif=false (soft-delete; rezervasyon gecmisi korunur).
    aktif: bool | None = None
    acilis: time | None = None
    kapanis: time | None = None
    slot_dakika: int | None = Field(None, gt=0, le=1440)

    @model_validator(mode="after")
    def _at_least_one(self) -> "OrtakAlanUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        # Ikisi de verildiyse tutarli olmali (biri verildiyse router mevcut
        # deger ile birlikte dogrular; DB CHECK son guvence).
        if (
            self.acilis is not None
            and self.kapanis is not None
            and self.kapanis <= self.acilis
        ):
            raise ValueError("kapanis acilistan sonra olmali")
        return self


class OrtakAlanOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    aciklama: str | None = None
    aktif: bool
    acilis: str
    kapanis: str
    slot_dakika: int
    created_at: datetime

    @field_validator("acilis", "kapanis", mode="before")
    @classmethod
    def _fmt_saat(cls, v: object) -> object:
        return _hhmm(v)


class OrtakAlanListResponse(BaseModel):
    meta: PageMetaOut
    items: list[OrtakAlanOut]


class SlotOut(BaseModel):
    """Bir gunun tek slotu — ROL-FARKINDA gorunurluk.

    resident/saha: yalniz dolu/bos (kimlik/kisi sayisi YOK — gizlilik).
    admin/yonetici: dolu slotta ayrica hangi DAIRE rezerve etti + kisi sayisi
    (yonetim denetimi). unit_no/kisi_sayisi yalniz yonetime + dolu slotta dolar.
    """

    baslangic: str
    bitis: str
    # dolu = bu slotla kesisen ONAYLI bir rezervasyon var.
    dolu: bool
    # rezerve_edilebilir: istekteki sakin bu slotu SIMDI rezerve edebilir mi
    # (24s penceresi + gunluk kota + son-dakika istisnasi; yonetimde her zaman
    # False — yonetim rezerve etmez). sebep None ise edilebilir.
    rezerve_edilebilir: bool = False
    # Neden edilemedigi: 'dolu' | 'gecti' | 'cok_erken' | 'gunluk' | None.
    sebep: str | None = None
    # YALNIZ admin/yonetici + dolu slot: rezerve eden daire no + kisi sayisi
    # (denetim). resident/saha icin DAIMA None (gizlilik).
    unit_no: str | None = None
    kisi_sayisi: int | None = None
    # YALNIZ resident: bu dolu slot KENDI rezervasyonu mu (yesil/kirmizi renk
    # kararini istemci baslangic/bitis + simdi ile verir). Baskalarinin dolu
    # slotu benim=False + kimlik/kisi None kalir (gizlilik).
    benim: bool = False


class AlanSlotResponse(BaseModel):
    alan_id: uuid.UUID
    tarih: date
    slot_dakika: int
    items: list[SlotOut]


class RezervasyonCreate(BaseModel):
    """Sakin talebi: alan + tarih + saat araligi + kisi sayisi.

    Daire token'daki sakinin AKTIF dairesinden turetilir; birden fazla
    dairesi olan sakin unit_id ile secebilir (kendi dairesi olmali).
    """

    alan_id: uuid.UUID
    tarih: date
    # "HH:MM" / "HH:MM:SS" kabul edilir; bitis > baslangic (ayni gun icinde).
    baslangic: time
    bitis: time
    kisi_sayisi: int = Field(..., gt=0, le=1000)
    # Opsiyonel; sakinin BIRDEN FAZLA aktif dairesi varsa secim icin.
    unit_id: uuid.UUID | None = None
    # "not" SQL/Python anahtar sozcugu — alan adi codebase deseniyle 'notlar'.
    notlar: str | None = Field(None, min_length=1, max_length=1000)

    @model_validator(mode="after")
    def _aralik(self) -> "RezervasyonCreate":
        if self.bitis <= self.baslangic:
            raise ValueError("bitis baslangictan sonra olmali")
        return self


class RezervasyonOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    alan_id: uuid.UUID
    # Alan/daire adlari join ile doldurulur (liste/karti icin).
    alan_ad: str | None = None
    unit_id: uuid.UUID
    unit_no: str | None = None
    tarih: date
    baslangic: str
    bitis: str
    kisi_sayisi: int
    notlar: str | None = None
    durum: str
    talep_eden_user_id: uuid.UUID
    talep_eden_ad: str | None = None
    #: (P165) BITIS SAATI GECTI MI — SUNUCU hesaplar, tesisin saat
    #: diliminde. Istemci kendi saatiyle hesaplasaydi, saati yanlis kurulu
    #: bir cihaz gecmis bir kaydin yaninda "Iptal et" gosterirdi.
    #:
    #: OLCU BITIS, BASLANGIC DEGIL: su an SUREN bir rezervasyon aktiftir
    #: ve iptal edilebilmelidir.
    gecmis: bool = False
    # Iptal eden (sakin/yonetim) + zamani — yalniz durum='iptal'de dolu.
    iptal_eden_user_id: uuid.UUID | None = None
    iptal_eden_ad: str | None = None
    iptal_zamani: datetime | None = None
    created_at: datetime

    @field_validator("baslangic", "bitis", mode="before")
    @classmethod
    def _fmt_saat(cls, v: object) -> object:
        return _hhmm(v)


class RezervasyonListResponse(BaseModel):
    meta: PageMetaOut
    items: list[RezervasyonOut]


# ------------------------------- etkinlik ----------------------------------- #
KatilimDurum = Literal["katiliyorum", "katilmiyorum"]


def _utc(v: datetime | None) -> datetime | None:
    """Naive zamani UTC kabul et (sozlesme konvansiyonu: tum zamanlar UTC).

    Neden gerekli: naive ve aware datetime KARSILASTIRILAMAZ (TypeError). Bu
    normalizasyon olmadan "naive tarih + aware bitis" ya da "naive bitis +
    DB'den gelen aware tarih" karsilastirmasi 500 uretirdi
    (bkz. routers/scans.py, routers/vehicle_passes.py — ayni konvansiyon).
    """
    if v is not None and v.tzinfo is None:
        return v.replace(tzinfo=timezone.utc)
    return v


class EtkinlikCreate(BaseModel):
    baslik: str = Field(..., min_length=1, max_length=200)
    aciklama: str = Field(..., min_length=1, max_length=5000)
    # Etkinlik BASLANGICI (timestamptz — ISO8601 UTC).
    tarih: datetime
    # Opsiyonel BITIS: verilirse baslangictan sonra olmali. ?aktif=true
    # suzgeci COALESCE(bitis_zamani, tarih) >= now() uygular.
    bitis_zamani: datetime | None = None
    konum: str | None = Field(None, min_length=1, max_length=500)
    # Opsiyonel gorsel: /uploads/presign ile yuklenen obje anahtari
    # (duyuru/site kurali ile AYNI akis).
    foto_key: str | None = None

    @field_validator("tarih", "bitis_zamani")
    @classmethod
    def _v_utc(cls, v: datetime | None) -> datetime | None:
        return _utc(v)

    @model_validator(mode="after")
    def _v_aralik(self) -> "EtkinlikCreate":
        if self.bitis_zamani is not None and self.bitis_zamani <= self.tarih:
            raise ValueError("bitis_zamani baslangictan sonra olmali")
        return self


class EtkinlikUpdate(BaseModel):
    baslik: str | None = Field(None, min_length=1, max_length=200)
    aciklama: str | None = Field(None, min_length=1, max_length=5000)
    tarih: datetime | None = None
    # Acikca null gonderilirse bitis kaldirilir (anlik etkinlige doner).
    bitis_zamani: datetime | None = None
    konum: str | None = Field(None, max_length=500)
    # Acikca null gonderilirse gorsel kaldirilir; alan yoksa dokunulmaz.
    foto_key: str | None = None

    @field_validator("tarih", "bitis_zamani")
    @classmethod
    def _v_utc(cls, v: datetime | None) -> datetime | None:
        return _utc(v)

    @model_validator(mode="after")
    def _at_least_one(self) -> "EtkinlikUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        # Ikisi birlikte geldiyse burada; yalniz biri geldiyse router MEVCUT
        # kayitla birlestirip dogrular (ck_etkinlik_bitis ayni kurali DB'de
        # de zorlar).
        if (
            self.tarih is not None
            and self.bitis_zamani is not None
            and self.bitis_zamani <= self.tarih
        ):
            raise ValueError("bitis_zamani baslangictan sonra olmali")
        return self


class EtkinlikRsvp(BaseModel):
    """Sakin RSVP'si — kullanici basina TEK kayit; tekrar PUT ile degisir."""

    durum: KatilimDurum


class EtkinlikOut(CevrilebilirOut):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    # baslik/aciklama: Accept-Language ile secilen dilde. konum CEVRILMEZ
    # (yer adi) — bkz. CevrilebilirOut.
    baslik: str
    aciklama: str
    tarih: datetime
    bitis_zamani: datetime | None = None
    konum: str | None = None
    foto_key: str | None = None
    # Goruntuleme icin kisa omurlu presigned GET URL (foto_key varsa).
    foto_url: str | None = None
    olusturan_user_id: uuid.UUID
    # Olusturan yoneticinin adi (join ile).
    olusturan_ad: str | None = None
    # SEFFAF SAYILAR: herkes gorur; kim-katiliyor listesi URUN GEREGI YOK.
    katiliyorum_sayisi: int = 0
    katilmiyorum_sayisi: int = 0
    # Istekteki kullanicinin kendi RSVP'si (yoksa null) — UI secim gosterimi.
    benim_durumum: str | None = None
    created_at: datetime
    updated_at: datetime


class EtkinlikListResponse(BaseModel):
    meta: PageMetaOut
    items: list[EtkinlikOut]


# ------------------------------ site kurallari ------------------------------ #
class SiteKuraliCreate(BaseModel):
    baslik: str = Field(..., min_length=1, max_length=200)
    icerik: str = Field(..., min_length=1, max_length=10000)
    # Opsiyonel gorsel: /uploads/presign ile yuklenen obje anahtari.
    foto_key: str | None = None
    # Liste sirasi (kucuk once); verilmezse sona (0 varsayilanla en basa
    # dusmemesi icin istemci genelde mevcut-en-buyuk+1 gonderir).
    sira: int = Field(0, ge=0)


class SiteKuraliUpdate(BaseModel):
    baslik: str | None = Field(None, min_length=1, max_length=200)
    icerik: str | None = Field(None, min_length=1, max_length=10000)
    # Acikca null gonderilirse gorsel kaldirilir; alan yoksa dokunulmaz.
    foto_key: str | None = None
    sira: int | None = Field(None, ge=0)

    @model_validator(mode="after")
    def _at_least_one(self) -> "SiteKuraliUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class SiteKuraliOut(CevrilebilirOut):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    # baslik/icerik: Accept-Language ile secilen dilde (bkz. CevrilebilirOut).
    baslik: str
    icerik: str
    foto_key: str | None = None
    # Goruntuleme icin kisa omurlu presigned GET URL (foto_key varsa).
    foto_url: str | None = None
    sira: int
    olusturan_user_id: uuid.UUID
    # Olusturan yoneticinin adi (join ile).
    olusturan_ad: str | None = None
    created_at: datetime
    updated_at: datetime


class SiteKuraliListResponse(BaseModel):
    meta: PageMetaOut
    items: list[SiteKuraliOut]


# ---------------------------- dis hizmetler -------------------------------- #
class DisHizmetCreate(BaseModel):
    """Guvenilir esnaf/hizmet kisisi — yonetici ekler. tur: Cilingir/Elektrik/..."""

    tur: str = Field(..., min_length=1, max_length=80, examples=["Çilingir"])
    ad: str = Field(..., min_length=1, max_length=120)
    soyad: str = Field(..., min_length=1, max_length=120)
    telefon: str = Field(..., min_length=1, max_length=40)
    aciklama: str | None = Field(None, max_length=1000)


class DisHizmetUpdate(BaseModel):
    """Kismi guncelleme — verilmeyen alan degismez; en az bir alan gerekir."""

    tur: str | None = Field(None, min_length=1, max_length=80)
    ad: str | None = Field(None, min_length=1, max_length=120)
    soyad: str | None = Field(None, min_length=1, max_length=120)
    telefon: str | None = Field(None, min_length=1, max_length=40)
    aciklama: str | None = Field(None, max_length=1000)

    @model_validator(mode="after")
    def _at_least_one(self) -> "DisHizmetUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class DisHizmetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tur: str
    ad: str
    soyad: str
    telefon: str
    aciklama: str | None = None
    created_at: datetime


class DisHizmetListResponse(BaseModel):
    """Dis Hizmetler: bolum notu (yonetici) + kisiler (ture/ada gore sirali)."""

    note: str | None = None
    items: list[DisHizmetOut]


class DisHizmetNoteUpdate(BaseModel):
    note: str | None = Field(None, max_length=2000)


class NotificationOut(BaseModel):
    """In-app bildirim satiri.

    `mesaj` ISTEGIN DILINDE uretilir (tur 16): kayit cumle degil
    `mesaj_kimlik` + `mesaj_veri` tasir, metin okuma aninda kurulur. Boylece
    ayni kayit her kullaniciya kendi dilinde gorunur. Kimlik/veri alanlari da
    doner: istemci kendi metnini kurmak ya da derin baglanti yapmak isterse
    kullanir. Tur 16 ONCESI satirlarda kimlik NULL'dur ve `mesaj` kayitta ne
    yaziyorsa odur (Turkce).
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tip: str
    patrol_window_id: uuid.UUID | None = None
    patrol_plan_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None
    task_id: uuid.UUID | None = None
    mesaj: str
    mesaj_kimlik: str | None = None
    mesaj_veri: dict[str, Any] | None = None
    okundu: bool
    created_at: datetime


class NotificationListResponse(BaseModel):
    meta: PageMetaOut
    items: list[NotificationOut]


class NotificationUpdate(BaseModel):
    okundu: bool


# (P181 Bölüm 6.5) TOPLU İŞLEM. `ids` en az 1, en çok 500 (tek istekte makul üst
# sınır — UI sayfa başına ~20-50 gösterir). Kapsam sunucuda `_kapsam` ile zorlanır.
class NotificationTopluOkundu(BaseModel):
    ids: list[uuid.UUID] = Field(min_length=1, max_length=500)
    okundu: bool = True


class NotificationTopluSil(BaseModel):
    ids: list[uuid.UUID] = Field(min_length=1, max_length=500)


class NotificationTopluSonuc(BaseModel):
    """Kaç satır etkilendi — istemci sayacı/tazelemesi için."""
    etkilenen: int


# -------------------------------- tasks ------------------------------------ #
class TaskCategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    aktif: bool
    created_at: datetime
    updated_at: datetime | None = None


class TaskCategoryCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=100)


class TaskCategoryUpdate(BaseModel):
    """(P166 §8.3) Kategori DUZENLEME — yeni.

    NEDEN GEREKLI: kategori CRUD'unda POST/GET/DELETE vardi, PATCH YOKTU.
    Yazim hatasi duzeltmenin tek yolu sil-yeniden-olustur olurdu ve o,
    kategoriyi kullanan gorevleri PASIF bir kategoriye baglar; gecmis
    "silinmis kategori" gorunurdu. Ad degistirmek kimligi degistirmemeli.

    `aktif` de buradan: soft-delete edilmis bir kategoriyi GERI ALMANIN
    baska yolu yoktu (DELETE `aktif=false` yapiyor, tersi yok).
    """

    ad: str | None = Field(None, min_length=1, max_length=100)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "TaskCategoryUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class TaskCategoryListResponse(BaseModel):
    meta: PageMetaOut
    items: list[TaskCategoryOut]


class TicketSummaryOut(BaseModel):
    """Gorev bir TALEPTEN (complaint→is emri) geldiyse baglantili talebin kompakt
    ozeti — atanan saha personeli baglam gorur. kisisel-veri gorunurluk kurallari:
    ticketing anonim DEGIL; unit_label talebi acanin dairesidir (varsa)."""

    id: uuid.UUID
    kategori_ad: str | None = None    # talebin kategorisi (NULL = "Diğer")
    baslik: str                       # kisa aciklama
    durum: str                        # acik | is_emri | cozuldu | reddedildi
    unit_label: str | None = None     # talebi acanin daire no'su (varsa)


class TaskOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    aciklama: str | None = None
    atanan_user_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None
    # Gorev tipi = yonetici-tanimli kategori; NULL = "Diger" (sabit tip enum'u
    # kaldirildi). Istemci kategori_id'yi kategori listesinden ad'a cozer.
    kategori_id: uuid.UUID | None = None
    periyot_dakika: int | None = None
    sonraki_planlanan: datetime | None = None
    foto_zorunlu: bool
    aktif: bool
    # Ticketing: gorev bir talepten geldiyse ticket_id + oncelik dolu, ticket ozet.
    ticket_id: uuid.UUID | None = None
    oncelik: TaskOncelik | None = None
    ticket: TicketSummaryOut | None = None
    created_at: datetime
    updated_at: datetime | None = None


class TaskCreate(BaseModel):
    ad: str = Field(..., min_length=1)
    aciklama: str | None = None
    atanan_user_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None
    kategori_id: uuid.UUID | None = None  # NULL = "Diger"
    periyot_dakika: int | None = Field(None, ge=1)
    sonraki_planlanan: datetime | None = None
    foto_zorunlu: bool = False
    aktif: bool = True


class TaskUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1)
    aciklama: str | None = None
    atanan_user_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None
    kategori_id: uuid.UUID | None = None
    periyot_dakika: int | None = Field(None, ge=1)
    sonraki_planlanan: datetime | None = None
    foto_zorunlu: bool | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "TaskUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class TaskListResponse(BaseModel):
    meta: PageMetaOut
    items: list[TaskOut]


class TaskCompletionCreate(BaseModel):
    tamamlanma_zamani: datetime
    nfc_tag_uid: str | None = None
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None
    foto_key: str | None = None
    notlar: str | None = None


class TaskCompletionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    task_id: uuid.UUID
    tamamlayan_user_id: uuid.UUID
    tamamlanma_zamani: datetime
    nfc_tag_uid: str | None = None
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None
    foto_key: str | None = None
    foto_url: str | None = None
    notlar: str | None = None
    idempotency_key: str
    created_at: datetime


class TaskCompletionListResponse(BaseModel):
    meta: PageMetaOut
    items: list[TaskCompletionOut]


# Capraz-gorev tamamlama gecmisi (GET /task-completions). foto_url/gps yok;
# kanit varligi foto_var/nfc_dogrulandi bool olarak yeter.
class TaskCompletionHistoryOut(BaseModel):
    id: uuid.UUID
    task_id: uuid.UUID
    task_adi: str | None = None
    # Gorevin kategorisi (yonetici-tanimli); NULL kategori -> "Diğer".
    kategori_ad: str = "Diğer"
    tamamlayan_user_id: uuid.UUID
    tamamlanma_zamani: datetime
    foto_var: bool
    nfc_dogrulandi: bool
    notlar: str | None = None


class TaskCompletionKategoriSayi(BaseModel):
    kategori_ad: str
    sayi: int


class TaskCompletionOzet(BaseModel):
    toplam: int
    # Kategori bazli tamamlanma sayimlari (sabit tip kirilimi kaldirildi);
    # NULL kategori "Diğer" altinda toplanir. sayi'ya gore azalan.
    kalemler: list[TaskCompletionKategoriSayi]


class TaskCompletionHistoryListResponse(BaseModel):
    meta: PageMetaOut
    ozet: TaskCompletionOzet
    items: list[TaskCompletionHistoryOut]


# ------------------------------- devices ----------------------------------- #
DevicePlatform = Literal["android", "ios", "web"]

# Desteklenen UI dilleri — `ceviri.DESTEKLENEN_DILLER` ile AYNI kume; burada
# Literal olarak yazilir ki sema/openapi degeri kisitlasin (gecersiz dil 422).
Dil = Literal["tr", "en", "ar", "ru", "de", "fr", "es"]


class DeviceRegister(BaseModel):
    fcm_token: str = Field(..., min_length=1)
    platform: DevicePlatform
    # Cihazin UI dili — push metni bu dilde uretilir (tur 16). Gonderilmezse
    # `tr` (eski istemciler bugunku davranisi korur). Dil uygulama icinden
    # degistiginde istemci cihazi YENIDEN kaydeder (upsert).
    dil: Dil | None = None
    #: (P191-ek §1) Uygulamanın ilk açılışta üretip sakladığı KARARLI kurulum
    #: kimliği (donanım kimliği DEĞİL — o kalıcı bir izleyicidir ve KVKK
    #: açısından gereksizdir; kurulum kimliği uygulama silinince yok olur).
    #: Verilirse aynı cihazın ESKİ jetonu pasifleştirilir ve kayıt ÇOĞALMAZ.
    cihaz_kimligi: str | None = Field(default=None, max_length=128)


class DeviceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    fcm_token: str
    platform: str
    dil: str
    cihaz_kimligi: str | None = None
    aktif: bool
    created_at: datetime
    updated_at: datetime


class DeviceListResponse(BaseModel):
    meta: PageMetaOut
    items: list[DeviceOut]


# ------------------------- (P191 §2) push teşhisi --------------------------- #
class PushDenemeOut(BaseModel):
    """Tek bir push denemesi — "kime, ne zaman, sonuç ne"."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    #: Olay tipi (push_metinleri kimliği): gorev_atandi, duyuru, test, ...
    kimlik: str
    user_id: uuid.UUID | None = None
    ad: str | None = None
    rol: str | None = None
    #: FCM jetonunun SON 6 karakteri — tam jeton HİÇBİR yanıtta dönmez.
    token_son6: str | None = None
    platform: str | None = None
    saglayici: str
    #: gonderildi | gecersiz_token | basarisiz | noop | yapilandirilmadi | hedef_yok
    durum: str
    hata_kodu: str | None = None
    created_at: datetime


class PushTeshisResponse(BaseModel):
    """Push zincirinin durum tablosu (bkz. routers/push_teshis.py)."""

    #: Aktif sağlayıcı: `noop` ise HİÇBİR bildirim gönderilmez.
    saglayici: str
    #: `fcm` için servis hesabı + proje kimliği var mı.
    yapilandirildi: bool
    cihaz_aktif: int
    cihaz_kullanici: int
    #: `bildirim_mobil = false` diyen aktif kullanıcı sayısı (bunlara gitmez).
    bildirim_kapali: int
    #: Son 24 saatin sonuç dağılımı: {durum: adet}.
    ozet_24s: dict[str, int]
    denemeler: list[PushDenemeOut]


class PushTestResponse(BaseModel):
    """`POST /push/test` sonucu — zincirin NEREDE koptuğunu söyler."""

    saglayici: str
    #: Kendi aktif cihaz sayınız (0 ise gönderilecek yer yok).
    cihaz: int
    gonderildi: int
    durum: str
    hata_kodu: str | None = None
    #: (P191-ek §1) FCM "kayıtlı değil" dediği için PASİFLEŞTİRİLEN jeton
    #: sayısı. Ölü jeton bir daha denenmez.
    budanan: int = 0


class PushTemizlikResponse(BaseModel):
    """`POST /push/cihaz-temizle` — geçersiz jetonları toplu temizleme.

    `desteklenmiyor=true` "hepsi sağlam" DEMEK DEĞİLDİR: sağlayıcı (noop ya
    da kimliksiz fcm) doğrulama yapamamıştır. İkisini tek yanıtla anlatmak,
    ölü jetonları sağlam ilan etmek olurdu.
    """

    saglayici: str
    denenen: int
    budanan: int
    desteklenmiyor: bool
    #: Geçici hata (ağ/kota) yüzünden KARAR VERİLEMEYEN jeton sayısı —
    #: bunlar korunur, bir sonraki temizlikte yeniden bakılır.
    belirsiz: int = 0


# ------------------------------- uploads ----------------------------------- #
# İzin verilen gorsel MIME'lari — content_type imzali URL'e baglanir (airtight).
_ALLOWED_UPLOAD_CT = {"image/jpeg", "image/png", "image/webp", "image/heic"}
_MAX_UPLOAD_BYTES = 8 * 1024 * 1024  # ~8 MB, client-declared (best-effort)


class PresignRequest(BaseModel):
    content_type: str = Field(..., min_length=1, examples=["image/jpeg"])
    dosya_adi: str | None = None
    boyut: int | None = Field(None, ge=1, description="Client-declared byte size")

    @field_validator("content_type")
    @classmethod
    def _ct_allow(cls, v: str) -> str:
        if v.lower() not in _ALLOWED_UPLOAD_CT:
            raise ValueError("content_type gorsel olmali (jpeg/png/webp/heic)")
        return v.lower()

    @field_validator("boyut")
    @classmethod
    def _size_cap(cls, v: int | None) -> int | None:
        if v is not None and v > _MAX_UPLOAD_BYTES:
            raise ValueError("dosya cok buyuk (max 8MB)")
        return v


class PresignResponse(BaseModel):
    foto_key: str
    upload_url: str
    method: str = "PUT"
    expires_in: int


# -------------------------------- assets ----------------------------------- #
AssetKategori = Literal["ekipman", "arac", "alet", "diger"]
AssetDurum = Literal["musait", "zimmetli", "bakimda"]


class AcikZimmetOut(BaseModel):
    """Asset uzerindeki ACIK zimmetin ozeti (mobil §13 #2/#5) — history taramadan."""

    alan_user_id: uuid.UUID
    alan_user_ad: str
    alinma_zamani: datetime


class AssetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    kategori: str | None = None
    nfc_tag_uid: str | None = None
    durum: str
    aciklama: str | None = None
    aktif: bool
    acik_zimmet: AcikZimmetOut | None = None
    created_at: datetime
    updated_at: datetime | None = None


class AssetCreate(BaseModel):
    ad: str = Field(..., min_length=1)
    kategori: AssetKategori | None = None
    nfc_tag_uid: str | None = None
    aciklama: str | None = None
    aktif: bool = True


class AssetUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1)
    kategori: AssetKategori | None = None
    nfc_tag_uid: str | None = None
    durum: AssetDurum | None = None
    aciklama: str | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "AssetUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class AssetListResponse(BaseModel):
    meta: PageMetaOut
    items: list[AssetOut]


class AssetCheckoutOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    asset_id: uuid.UUID
    alan_user_id: uuid.UUID
    alan_user_ad: str | None = None
    birakan_user_id: uuid.UUID | None = None
    birakan_user_ad: str | None = None
    alma_zamani: datetime
    birakma_zamani: datetime | None = None
    alma_nfc_tag_uid: str | None = None
    birakma_nfc_tag_uid: str | None = None
    alma_gps_lat: Enlem | None = None
    alma_gps_lng: Boylam | None = None
    birakma_gps_lat: Enlem | None = None
    birakma_gps_lng: Boylam | None = None
    notlar: str | None = None
    idempotency_key: str
    created_at: datetime


class AssetCheckoutListResponse(BaseModel):
    meta: PageMetaOut
    items: list[AssetCheckoutOut]


class CheckoutRequest(BaseModel):
    nfc_tag_uid: str | None = None
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None
    notlar: str | None = None


class CheckinRequest(BaseModel):
    nfc_tag_uid: str | None = None
    gps_lat: Enlem | None = None
    gps_lng: Boylam | None = None
    notlar: str | None = None


# --------------------------- tenant settings ------------------------------- #
class TenantSettings(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    tenant_id: uuid.UUID
    ad: str
    slug: str
    timezone: str
    # false ise BIRINCIL yonetici ILK GIRISTE tesisi adlandirmalidir.
    kurulum_tamamlandi: bool = True
    # Tesisin yonetim maili — yonetici iletisim kartinda gosterilir.
    yonetim_email: str | None = None
    #: (P193 §4) Tesis posta adresi — makbuzda ve resmi ciktida yazilir.
    adres: str | None = None
    ilce: str | None = None
    il: str | None = None
    posta_kodu: str | None = None
    # Hava durumu konumu (0005) — baslik + /weather sorgusu.
    konum_ad: str = "İstanbul"
    # (P203 §1) OKUMA semasi ama ARALIK YINE DE TASIR: sema sozlesmenin
    # kendisidir ve istemciye "buraya 1000 gelebilir" demek, istemciyi
    # gelmeyecek bir degere hazirlanmaya zorlar. Yazma esi
    # (`TenantSettingsUpdate`) ayni araligi zaten tasiyordu.
    konum_lat: Enlem = 41.0082
    konum_lon: Boylam = 28.9784
    # Otopark kapasitesi (G4). null = tanimsiz -> /parking/occupancy kapasite
    # ve oran alanlarini null doner (ana ekran "—" gosterir).
    otopark_kapasite: int | None = None
    # ANPR (P16): esik ALTINDAKI plaka okumalari gecis ACMAZ, onay kuyruguna
    # duser. Varsayilan 0.850.
    anpr_guven_esigi: float = 0.850
    # Cikis olayinda acik gecis otomatik kapansin mi? Tek yonlu kapida
    # (yalniz giris kamerasi) kapatan olmaz — site bunu kapatabilmeli.
    anpr_otomatik_cikis: bool = True
    #: (P115) Demo modu — istemci "simule okutma" dugmesini YALNIZ bu
    #: bayrak acikken cizer. Yazma yolu YOK (TenantSettingsUpdate'te
    #: bulunmuyor): bayragi uygulamadan acabilmek, korumayi anlamsiz
    #: kilardi.
    demo_mod: bool = False
    # (P35) Guvenligi kim yonetir (bkz. deps.GUVENLIK_YAZAN).
    guvenlik_modu: GuvenlikModu = "yonetim_ici"
    # (P37) Gurultu caydiricisi. `gurultu_integration_id` NULL = MANUEL MOD.
    gurultu_esigi: int = 5
    #: (P160) Okutmanin NFC noktasina azami uzakligi (metre). Panel
    #: haritasi bunun uzerindeki okutmayi "esik disi" isaretler. Sabit
    #: DEGIL: bir sitede noktalar 10 m araliklarla, digerinde bloklar
    #: arasi 200 m — ayni sayi ikisinde de anlamli olamaz.
    okutma_mesafe_esigi_m: int = 50
    #: (P165) Rezervasyon gecmisi kac ay gorunur (`0 = sinirsiz`).
    rezervasyon_gecmis_ay: int = 12
    gurultu_uyari_metni: str | None = None
    gurultu_integration_id: uuid.UUID | None = None
    # (P208 §1) Sayim penceresi / susma suresi / sakine bildirim.
    gurultu_pencere_gun: int = 30
    gurultu_susma_gun: int = 7
    gurultu_sakin_uyarisi: bool = True
    # (P34) Tur gecikme alarmi. Tolerans TENANT AYARIDIR: 10 dk bir sitede
    # makul, kampus buyuklugunde erken alarm demektir. Tekrar 0 = KAPALI.
    tur_gecikme_toleransi_dk: int = 10
    tur_alarm_tekrar_sayisi: int = 3
    # (P34) Kamera fotografi urun kurali DEGIL tenant tercihi: gece
    # vardiyasinda kamera kullanimi her sitede kabul gormez.
    tur_baslangic_foto_zorunlu: bool = False
    # (P207 §3) VARDIYA HATIRLATMA. "Kac dakika once" sorusunun TEK
    # dogru yaniti yok: sitede 15 dakika makul, kampuste personel yola
    # cikmis olmali. Virgullu kademe listesi ("30,5"); bos = KAPALI.
    vardiya_hatirlatma_dk: str = "15"
    #: Vardiya basladiktan sonra okutma gelmezse yoneticiye uyari.
    #: 0 = kapali. GECIKMIS DEVRIYE ALARMINDAN FARKLI: o, acilmis bir
    #: turun gec kalmasi; bu, vardiyaya HIC BASLAMAMA.
    vardiya_baslamadi_dk: int = 15


class TenantSettingsUpdate(BaseModel):
    """admin: hepsi. yonetici: `ad` + konum + otopark kapasitesi (digerleri 403
    — bkz. router)."""

    timezone: str | None = None
    ad: str | None = None
    yonetim_email: str | None = None
    #: (P193 §4) Adres alanlari. Bos dizge `None`a cevrilir (asagidaki
    #: dogrulayici): `" "` TRUTHY oldugu icin "adres var" sayilir ve
    #: makbuzda bos bir satir birakirdi.
    adres: str | None = Field(None, max_length=500)
    ilce: str | None = Field(None, max_length=100)
    il: str | None = Field(None, max_length=100)
    #: DB CHECK ile AYNI kural: bes hane. Iki yerde iki farkli sinir,
    #: API'den gecen degerin veritabaninda reddedilmesi demekti.
    posta_kodu: str | None = Field(None, pattern=r"^[0-9]{5}$")
    konum_ad: str | None = Field(None, min_length=1)
    konum_lat: float | None = Field(None, ge=-90, le=90)
    konum_lon: float | None = Field(None, ge=-180, le=180)
    # Acikca null gonderilirse kapasite TANIMSIZ'a doner (oran yeniden null).
    otopark_kapasite: int | None = Field(None, ge=0, le=100000)
    # ANPR esigi 0..1. 1.0 = "hicbir okumaya guvenme" (hepsi onaya duser);
    # 0.0 = "hepsini isle". Ikisi de GECERLI ayarlardir.
    anpr_guven_esigi: float | None = Field(None, ge=0, le=1)
    anpr_otomatik_cikis: bool | None = None
    # (P34) 0 tekrar = alarm kapali (gecerli tercih); ust sinir bildirim
    # yorgunlugunu onler. Sinirlar DB CHECK'i ile aynidir.
    tur_gecikme_toleransi_dk: int | None = Field(None, ge=1, le=240)
    tur_alarm_tekrar_sayisi: int | None = Field(None, ge=0, le=10)
    tur_baslangic_foto_zorunlu: bool | None = None
    #: (P208 §1) Sinirlar DB CHECK'i ile AYNI (goc 0103). 0 = kapali
    #: (pencere sinirsiz / susma yok).
    gurultu_pencere_gun: int | None = Field(None, ge=0, le=365)
    gurultu_susma_gun: int | None = Field(None, ge=0, le=365)
    gurultu_sakin_uyarisi: bool | None = None
    #: (P207 §3) Kademe listesi — bicim dogrulamasi UYGULAMADA
    #: (`hatirlatma_kademeleri`): gecersiz metin KAPALI demektir ve
    #: kullaniciyi 422 ile durdurmak, "kapat" niyetini hataya
    #: cevirirdi. Uzunluk siniri yeter.
    vardiya_hatirlatma_dk: str | None = Field(None, max_length=40)
    #: DB CHECK ile AYNI sinir (goc 0101).
    vardiya_baslamadi_dk: int | None = Field(None, ge=0, le=180)
    #: (P35) Mod degisimi SAHIPLIGI devreder — bu yuzden YALNIZ admin
    #: (bkz. router). Yoneticinin kendi yetkisini kendine geri verebilmesi,
    #: dis sirkete devri anlamsizlastirirdi.
    guvenlik_modu: GuvenlikModu | None = None
    #: (P37) Sinir DB CHECK'iyle ayni. `gurultu_uyari_metni: null` gonderimi
    #: metni VARSAYILANA dondurur (silmek degil, varsayilana donmek).
    gurultu_esigi: int | None = Field(None, ge=1, le=50)
    #: (P160) Semadaki CHECK ile AYNI aralik — iki yerde iki
    #: farkli sinir, API'den gecen degerin veritabaninda
    #: reddedilmesi demekti.
    okutma_mesafe_esigi_m: int | None = Field(None, ge=1, le=5000)
    #: `0 = sinirsiz`; ust sinir 120 ay (10 yil) — daha uzugu bir politika
    #: degil, yanlis girilmis bir deger olurdu. Sema kisiti DDL'de de var.
    rezervasyon_gecmis_ay: int | None = Field(None, ge=0, le=120)
    gurultu_uyari_metni: str | None = Field(None, max_length=1000)
    gurultu_integration_id: uuid.UUID | None = None


    # (P99) `TenantAdminCreate` ile AYNI normalizasyon. Orada vardi, burada
    # yoktu: yaratma yolu bos/bosluk degeri `None`a ceviriyor, GUNCELLEME
    # yolu ise `" "` gibi bir degeri OLDUGU GIBI sakliyordu. `" "` TRUTHY
    # oldugu icin "yonetim e-postasi var" sayilir ve bildirim yolu bos bir
    # adrese gitmeye calisirdi. (P97'nin telefonda bulunan asimetrisinin
    # aynisi: ayni alan, iki yazma yolu, tek dogrulayici.)
    @field_validator("yonetim_email", "adres", "ilce", "il")
    @classmethod
    def _bos_ise_none_upd(cls, v: str | None) -> str | None:
        return (v.strip() or None) if v is not None else None

    @model_validator(mode="after")
    def _at_least_one(self) -> "TenantSettingsUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


# --------------------------- yonetici iletisim ----------------------------- #
class YoneticiKart(BaseModel):
    """Yonetici iletisim karti.

    GIZLILIK ISTISNASI (contracts/auth.md): `telefon` burada tenant'in TUM
    uyelerine acilir — C1a'nin yon/riza kapilari BU UC icin gecerli DEGILDIR
    (yonetici = HIZMET rolu; numarayi admin bilerek girer). Istisna YALNIZ
    role='yonetici' icindir; C1a modeli baska her seyde korunur.
    """

    model_config = ConfigDict(from_attributes=True)

    user_id: uuid.UUID
    ad_soyad: str
    telefon: str | None = None
    # Profil fotografi (WP-D) — presigned GET URL (yonetici yuklediyse).
    avatar_url: str | None = None


class YoneticiIletisimOut(BaseModel):
    yoneticiler: list[YoneticiKart]
    yonetim_email: str | None = None


# Admin (platform) tesis olusturma/listeleme (cross-tenant) + yonetici ilk-giris
# adlandirma (onboarding, Model A).
class YoneticiCreate(BaseModel):
    """Tenant olusturmada TEK bir yonetici satiri.

    (P197) E-POSTA ARTIK ZORUNLU. Eski not "e-posta alinmaz, mobil giris
    telefonladir" diyordu; o kural degisti ve degismesi gerekiyordu:
    davet, dogrulama kodu ve parola sifirlama YALNIZ e-postadan gidiyor
    (SMS urun genelinde kapali). E-postasiz acilan bir yonetici hesabi
    daveti alamaz, parolasini sifirlayamaz, hesabini silemez — yani
    ACILDIGI ANDA SAHIPLENILEMEZ. `app_user.email` goc 0089'da NOT NULL
    oldu; bu alan onun uc yuzundeki karsiligidir.

    Tenant seviyesindeki `yonetim_email` AYRIDIR (iletisim kartinda
    gosterilir, giris/davet ile ilgisi yok).
    """

    ad: str = Field(..., min_length=2, max_length=120, examples=["Ayse Yilmaz"])
    phone: str = Field(..., min_length=1, examples=["+905321112203"])
    email: EmailStr = Field(..., examples=["ayse@ornek.com"])
    password: str | None = Field(None, min_length=8)

    @field_validator("password")
    @classmethod
    def _strong(cls, v: str | None) -> str | None:
        return v if v is None else validate_password_strength(v)


class TenantAdminCreate(BaseModel):
    """Admin bir tenant + N yonetici acar. ILK yonetici BIRINCIL'dir (tesisi
    ilk giriste adlandirir). `ad` verilmezse yer tutucu + rastgele slug; her
    durumda kurulum_tamamlandi=false — birincil adi ONAYLAR."""

    ad: str | None = Field(None, min_length=2, max_length=160, examples=["Acme Plaza"])
    yonetim_email: str | None = Field(None, examples=["yonetim@acme.com"])
    yoneticiler: list[YoneticiCreate] = Field(..., min_length=1)

    @field_validator("yonetim_email")
    @classmethod
    def _bos_ise_none(cls, v: str | None) -> str | None:
        return (v.strip() or None) if v is not None else None

    @model_validator(mode="after")
    def _telefon_tekrari_yok(self) -> "TenantAdminCreate":
        phones = [y.phone for y in self.yoneticiler]
        if len(phones) != len(set(phones)):
            raise ValueError("Ayni telefon birden fazla yoneticide kullanilamaz.")
        return self


class YoneticiCreatedOut(BaseModel):
    user_id: uuid.UUID
    ad: str
    birincil: bool
    temp_code: str | None = None


class TenantAdminCreatedOut(BaseModel):
    """temp_code YALNIZ parola verilmeyen yonetici icin ve BIR KEZ doner (admin
    ilgili yoneticiye iletir). tenant_id GIZLI kimliktir (yalniz admin gorur)."""

    tenant_id: uuid.UUID
    yoneticiler: list[YoneticiCreatedOut]


class TenantAdminListItem(BaseModel):
    id: uuid.UUID
    ad: str
    # (P155 §6) Yoneticinin ILETECEGI tanimlayici — panelde birincil gosterilir.
    # Tetikleyici her tenant'a atar (goc 0037); teoride NULL olmamali ama
    # eski/yaris bir satira karsi opsiyonel birakilir (panel bos gosterir).
    kayit_kodu: str | None = None
    kurulum_tamamlandi: bool
    created_at: datetime


class TenantAdminListResponse(BaseModel):
    items: list[TenantAdminListItem]


class TenantSetupRequest(BaseModel):
    """Yonetici ilk giriste tesisini adlandirir (kurulum_tamamlandi=true olur)."""

    ad: str = Field(..., min_length=2, max_length=120)


class TenantYoneticiOut(BaseModel):
    """Bir tesisin yonetici hesabi (admin detay gorunumu)."""

    id: uuid.UUID
    ad: str
    telefon: str | None = None
    is_active: bool
    password_set: bool


class TenantAdminDetail(BaseModel):
    """Admin tesis detayi: tenant + (varsa) yoneticisi. yonetici None ise tesiste
    henuz yonetici yok (beklenmez — Model A tenant+yonetici birlikte acar)."""

    tenant_id: uuid.UUID
    ad: str
    kayit_kodu: str | None = None  # (P155 §6) panelde birincil + kopyalanabilir
    kurulum_tamamlandi: bool
    created_at: datetime
    yonetici: TenantYoneticiOut | None = None


class TenantAdminUpdate(BaseModel):
    """Admin tesis adini degistirir (rename/duzeltme)."""

    ad: str = Field(..., min_length=2, max_length=120)


class TenantYoneticiUpdate(BaseModel):
    """Yonetici ad/telefon/aktiflik guncelleme (kismi; verilmeyen alan degismez)."""

    ad: str | None = Field(None, min_length=2, max_length=120)
    phone: str | None = Field(None, min_length=1)
    is_active: bool | None = None


class TenantYoneticiResetOut(BaseModel):
    """Credential sifirlama sonucu: yeni tek-seferlik gecici kod (bir kez doner)."""

    temp_code: str


# ------------------- (P154) tesis basina COKLU yonetici -------------------- #
class TenantYoneticiListItem(TenantYoneticiOut):
    """Listedeki bir yonetici. `birincil` EKLENDI: tekil `TenantAdminDetail`
    yalniz birincili donduruyordu, dolayisiyla o alan orada gereksizdi; listede
    ise hangi satirin silinemeyecegini kullaniciya soyleyen tek isarettir."""

    birincil: bool
    created_at: datetime


class TenantYoneticiListResponse(BaseModel):
    items: list[TenantYoneticiListItem]


class TenantYoneticiAdd(BaseModel):
    """Var olan bir tesise SONRADAN yonetici ekleme.

    `password` YOK — `YoneticiCreate`ten kasitli fark: tesis kurulumunda admin
    bazen yoneticiyle ayni odadadir ve parolayi birlikte belirler. Sonradan
    ekleme uzaktan yapilir; admin'in baskasi adina parola secmesi, o parolayi
    bir kanaldan iletmesi demektir. Tek yol TEK SEFERLIK gecici koddur.
    """

    ad: str = Field(..., min_length=2, max_length=120, examples=["Ayse Yilmaz"])
    phone: str = Field(..., min_length=1, examples=["+905321112203"])
    #: (P197) ZORUNLU — gecici kod bu adrese gider ve `app_user.email`
    #: NOT NULL (goc 0089). E-postasiz eklenen yonetici, kodunu hicbir
    #: kanaldan alamazdi (SMS urun genelinde kapali).
    email: EmailStr = Field(..., examples=["ayse@ornek.com"])


class TenantYoneticiAddedOut(BaseModel):
    """Eklenen yonetici + BIR KEZ donen gecici kod (admin ilgiliye iletir)."""

    user_id: uuid.UUID
    ad: str
    temp_code: str


# -------------------------------- aidat ------------------------------------ #
ResidentRol = Literal["malik", "kiraci"]
DuesYontem = Literal["elden", "havale", "kart", "diger"]
DuesDurum = Literal["basarili", "bekliyor", "iptal"]


# ---------------------- Bagimsiz Bolum tip/grup (P26) ---------------------- #
#: Tanim adi: SERBEST metin (1+0, dubleks, "Dükkan"), yalniz uzunluk sinirli.
#: Desen KOYULMADI — kullanicinin yazacagi etiketi tahmin etmek, "1+1,5" ya da
#: "stüdyo" diyen siteyi disarida birakirdi.
_TANIM_AD = Field(..., min_length=1, max_length=60)


class UnitGrupCreate(BaseModel):
    ad: str = _TANIM_AD
    aktif: bool = True


class UnitGrupUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=60)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "UnitGrupUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class UnitGrupOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    aktif: bool
    #: Bu gruba bagli daire sayisi (silmeden once "kac daireyi etkiler").
    daire_sayisi: int = 0
    created_at: datetime
    updated_at: datetime | None = None


class UnitGrupListResponse(BaseModel):
    meta: PageMetaOut
    items: list[UnitGrupOut]


class UnitTipCreate(BaseModel):
    ad: str = _TANIM_AD
    #: NULL "tanimsiz"dir, 0 DEGIL — 0 gecerli bir tutardir (muaf daire).
    varsayilan_aidat_kurus: int | None = Field(None, ge=0)
    aktif: bool = True


class UnitTipUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=60)
    varsayilan_aidat_kurus: int | None = Field(None, ge=0)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "UnitTipUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class UnitTipOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    varsayilan_aidat_kurus: int | None = None
    aktif: bool
    daire_sayisi: int = 0
    created_at: datetime
    updated_at: datetime | None = None


class UnitTipListResponse(BaseModel):
    meta: PageMetaOut
    items: list[UnitTipOut]


class UnitOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    no: str
    blok: str | None = None
    # Fiziksel yerlesim (bina semasi) — nullable; girilmemis daire haritada
    # "yerlesimsiz" kovaya duser.
    kat: int | None = None
    sira: int | None = None
    metrekare: float | None = None
    #: (P192 §3.3) Kat Mulkiyeti Kanunu md. 20 gider paylasimini ARSA
    #: PAYINA gore tanimlar. Girilmemis daire arsa payi dagitiminin
    #: DISINDA kalir ve bu kullaniciya soylenir.
    arsa_payi: float | None = None
    aktif: bool
    # SINIFLANDIRMA (P26). Ad da doner: istemci ayri bir istek yapmadan
    # listeyi cizebilsin (daire listesi tip/grup adini gosterir).
    unit_tip_id: uuid.UUID | None = None
    unit_tip_ad: str | None = None
    unit_grup_id: uuid.UUID | None = None
    unit_grup_ad: str | None = None
    created_at: datetime
    updated_at: datetime | None = None


# Daire no: harf + sayi + tire serbest kombinasyon ("A-12", "B3", "12");
# bosluk/ozel karakter kabul edilmez (A5).
_UNIT_NO_PATTERN = r"^[A-Za-z0-9-]+$"
# Blok etiketi: kisa alfanumerik ("A", "B1"); tire/bosluk yok.
_BLOK_PATTERN = r"^[A-Za-z0-9]+$"
# Yerlesim sinirlari (makul araliklar): kat -5 (bodrum) .. 200; sira 0 .. 999.
_KAT_MIN, _KAT_MAX = -5, 200
_SIRA_MIN, _SIRA_MAX = 0, 999


class UnitCreate(BaseModel):
    no: str = Field(..., min_length=1, max_length=50, pattern=_UNIT_NO_PATTERN)
    # Blok ZORUNLU (canli site kurali): her yeni daire bir bloga baglanir. MEVCUT
    # blok-suz daireler (varsa) korunur — yalniz OLUSTURMA bloklu olmali.
    blok: str = Field(..., min_length=1, max_length=8, pattern=_BLOK_PATTERN)
    kat: int | None = Field(None, ge=_KAT_MIN, le=_KAT_MAX)
    sira: int | None = Field(None, ge=_SIRA_MIN, le=_SIRA_MAX)
    metrekare: float | None = None
    arsa_payi: float | None = Field(None, ge=0)
    aktif: bool = True
    unit_tip_id: uuid.UUID | None = None
    unit_grup_id: uuid.UUID | None = None


_BULK_MAX = 500  # tek istekte en fazla daire


class UnitBulkCreate(BaseModel):
    """Toplu daire olusturma: bir blok icin kat_sayisi × kat_basi_daire adet
    daire, baslangic_no'dan itibaren ARDISIK numaralandirilir (kat kat dolar:
    kat 1 baslangic..+M-1, kat 2 devam eder). Daire no = blok varsa '{blok}-{n}',
    '{blok}-{n}'. Zaten var olan no'lar atlanir. Katlar 1..kat_sayisi; sira
    1..kat_basi_daire. En fazla 500 daire/istek."""

    # Blok ZORUNLU (toplu olusturma da bloga baglanir). no = '{blok}-{n}'.
    blok: str = Field(..., min_length=1, max_length=8, pattern=_BLOK_PATTERN)
    kat_sayisi: int = Field(..., ge=1, le=_KAT_MAX)
    kat_basi_daire: int = Field(..., ge=1, le=_SIRA_MAX)
    baslangic_no: int = Field(..., ge=0, le=999999)
    #: (P154 / Asama 5) BASLANGIC KATI. Brief: "-2, -1, 0, zemin, 1...".
    #:
    #: NEGATIF DEGER SERBEST: bodrum ve zemin gercek katlardir. Eskiden
    #: katlar HER ZAMAN 1'den basliyordu ve bodrumlu bir binada kat
    #: numaralari bir kaydirmayla yaziliyordu — yani veri, binanin
    #: kendisini anlatmiyordu.
    #:
    #: "ZEMIN" AYRI BIR DEGER DEGIL, 0'DIR: metin bir kat numarasi
    #: siralanamaz ve "zemin" ile "0" iki ayri deger olarak durursa
    #: siralama iki kurala baglanirdi. Etiket ARAYUZDE cozulur.
    #:
    #: VARSAYILAN 1, 0 DEGIL — ve bu bilincli. Brief "baslangic kati
    #: SECILEBILSIN" diyor, "varsayilan degissin" demiyor. 0 yapmak,
    #: alani hic gondermeyen HER cagirani (mobil toplu olusturma dahil)
    #: sessizce etkilerdi: bugune kadar 1'den baslayan binalar bir anda
    #: zeminden baslardi. `test_units_bulk` bu kaymayi yakaladi.
    baslangic_kat: int = Field(1, ge=-_KAT_MAX, le=_KAT_MAX)
    # PARTI BASINA siniflandirma (P26): toplu olusturmada her daireye tek tek
    # tip secmek anlamsizdir — bir blok genelde tek tiptir. Daire basi
    # istisnalar sonradan PATCH ile duzeltilir.
    unit_tip_id: uuid.UUID | None = None
    unit_grup_id: uuid.UUID | None = None
    #: (P193 §6) PARTI BASINA arsa payi / metrekare. Tip dairelerde
    #: (ayni kat plani) hepsi aynidir; 100 daireyi tek tek dolasmak
    #: gereksiz bir istir. Istisnalar `PATCH /units/arsa-payi` ile.
    arsa_payi: float | None = Field(None, ge=0)
    metrekare: float | None = Field(None, ge=0)

    @model_validator(mode="after")
    def _cap(self) -> "UnitBulkCreate":
        if self.kat_sayisi * self.kat_basi_daire > _BULK_MAX:
            raise ValueError(f"Tek seferde en fazla {_BULK_MAX} daire olusturulabilir.")
        return self

    @property
    def toplam(self) -> int:
        return self.kat_sayisi * self.kat_basi_daire

    @property
    def bitis_no(self) -> int:
        return self.baslangic_no + self.toplam - 1


class UnitBulkResult(BaseModel):
    """Toplu olusturma sonucu: olusturulan daireler + atlanan (zaten var olan)
    no'lar + hesaplanan bitis_no."""

    olusturulan: list[UnitOut]
    atlanan: list[str]
    bitis_no: int


class UnitUpdate(BaseModel):
    no: str | None = Field(None, min_length=1, max_length=50, pattern=_UNIT_NO_PATTERN)
    blok: str | None = Field(None, min_length=1, max_length=8, pattern=_BLOK_PATTERN)
    kat: int | None = Field(None, ge=_KAT_MIN, le=_KAT_MAX)
    sira: int | None = Field(None, ge=_SIRA_MIN, le=_SIRA_MAX)
    metrekare: float | None = None
    arsa_payi: float | None = Field(None, ge=0)
    aktif: bool | None = None
    # `None` GONDERILEBILIR: siniflandirmayi KALDIRMAK icin (bkz. router —
    # `exclude_unset` ile "gonderilmedi" ile "null gonderildi" ayrilir).
    unit_tip_id: uuid.UUID | None = None
    unit_grup_id: uuid.UUID | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "UnitUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class UnitLayoutUpdate(BaseModel):
    """Daire fiziksel yerlesimi (blok/kat/sira) — yonetim (admin+yonetici)
    tarafindan girilir; PATCH /units/{id}/layout. Alanlar bagimsiz gonderilebilir
    (null = 'yerlesimden cikar'); en az bir alan gerekir. Anonimlik: yerlesim
    hicbir sikayetci verisi tasimaz."""

    blok: str | None = Field(None, min_length=1, max_length=8, pattern=_BLOK_PATTERN)
    kat: int | None = Field(None, ge=_KAT_MIN, le=_KAT_MAX)
    sira: int | None = Field(None, ge=_SIRA_MIN, le=_SIRA_MAX)

    @model_validator(mode="after")
    def _at_least_one(self) -> "UnitLayoutUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class UnitListResponse(BaseModel):
    meta: PageMetaOut
    items: list[UnitOut]


# --------------------------- building block (Rev-1) ------------------------- #
class BlockCreate(BaseModel):
    """Bina blogu — yonetici/admin tanimlar (Rev-2 editoru iskeleti). `ad`
    kisa alfanumerik (blok etiketi); kat_sayisi opsiyonel."""

    ad: str = Field(..., min_length=1, max_length=8, pattern=_BLOK_PATTERN)
    kat_sayisi: int | None = Field(None, ge=0, le=_KAT_MAX)


class BlockUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=8, pattern=_BLOK_PATTERN)
    kat_sayisi: int | None = Field(None, ge=0, le=_KAT_MAX)

    @model_validator(mode="after")
    def _at_least_one(self) -> "BlockUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class BlockOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    kat_sayisi: int | None = None
    # Bu blogu kullanan daire sayisi (silme guvenligi + editor icin).
    unit_sayisi: int = 0
    created_at: datetime
    updated_at: datetime | None = None


class BlockListResponse(BaseModel):
    items: list[BlockOut]


class UnitResidentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    unit_id: uuid.UUID
    user_id: uuid.UUID
    # (P181 Bölüm 6.1) Sakinin ad-soyadı — arayüz UUID yerine ADI göstersin.
    # Endpoint AppUser join'iyle doldurur; kayıt silinmişse null.
    user_ad: str | None = None
    rol_tipi: str | None = None
    baslangic: datetime | None = None
    bitis: datetime | None = None
    created_at: datetime


class ResidentAssign(BaseModel):
    user_id: uuid.UUID
    rol_tipi: ResidentRol | None = None
    baslangic: datetime | None = None


# ------------------- sakin olusturma (yonetici, gecici kod) ---------------- #
class ResidentCreate(BaseModel):
    """Yonetici daire + sakin hesabini tek adimda acar; gecici kod uretilir.

    telefon global benzersiz LOGIN anahtaridir (E.164 normalize); sakin
    telefonla girer (daire no login KALDIRILDI). email opsiyonel.

    (P154 / Asama 5) `ad` ARTIK OPSIYONEL. Brief mobil tekli eklemeyi
    "yalniz telefon" diye tarif ediyor (Kerem netlestirdi: telefon +
    daire no); yonetici sakini eklerken adini BILMEK ZORUNDA DEGIL.

    NEDEN SEMA `ad`I NULL YAPMIYOR: `app_user.ad` NOT NULL ve 87 yerde
    okunuyor, 20+ yanit semasinda `ad: str` olarak ZORUNLU. Sutunu
    global nullable yapmak, brief'in dokunmadigi her ekrani (personel,
    yonetici, denetci listeleri) ilgilendiren bir degisiklik olurdu.
    Bunun yerine uc, ad verilmediginde DAIREDEN TURETILEN gecici bir ad
    yazar ("A-12 sakini") — listede anlamli gorunur, gecici oldugu
    okunur ve kisi kaydolunca profilinden duzeltir."""

    unit_no: str = Field(..., min_length=1, examples=["A-12"])
    blok: str | None = None  # yalniz YENI acilan unit'e islenir
    ad: str | None = Field(None, min_length=1)
    telefon: str = Field(..., min_length=1, examples=["+905321112203"])
    #: (P197) ZORUNLU OLDU. Eski not "sakinde opsiyonel" diyordu; o kural
    #: sahiplenilemez hesap uretiyordu: davet YALNIZ e-postadan gider
    #: (SMS urun genelinde kapali), yani e-postasiz acilan sakin Tesis
    #: ID'yi hicbir zaman ogrenemez ve hesabina hic giremez.
    #: `app_user.email` goc 0089'da NOT NULL oldu.
    email: EmailStr
    rol_tipi: ResidentRol | None = None
    # (P186-ek2) `password` KALDIRILDI: yonetici parola atamaz; hesap parolasiz
    # acilir ve DAVET (Tesis ID) ile kisi kendi kimligini kurar.

    @field_validator("telefon")
    @classmethod
    def _normalize_telefon(cls, v: str) -> str:
        try:
            return normalize_phone(v)
        except ValueError as exc:
            raise ValueError(str(exc)) from exc


class ResidentCreatedOut(BaseModel):
    """(P186-ek2) `temp_code` KALDIRILDI — hesap parolasiz acilir ve sahiplenme
    yalniz DAVET yoluyladir; gosterilecek tek-seferlik kod yoktur."""

    user_id: uuid.UUID
    unit_id: uuid.UUID
    unit_no: str
    ad: str
    email: str | None = None
    # (P155 §7) Davet gonderim ozeti — parolasiz acilan hesaba jetonlu bag
    # gonderildi mi. Saglayici yapilandirilmamissa gonderildi=false gelir ve
    # panel yoneticiye "gitmeyeni" gosterir.
    davet: "DavetGonderimSonucu | None" = None


# Site sakini yonetimi (yonetici) — liste ogesi. Telefon KVKK geregi DONMEZ.
class ResidentListItem(BaseModel):
    user_id: uuid.UUID
    ad: str
    unit_no: str | None = None  # aktif daire(ler); coklu ise virgulle birlesir
    is_active: bool


class ResidentListResponse(BaseModel):
    items: list[ResidentListItem]


# Sakin duzenleme (PATCH /residents/{id}) — en az bir alan. telefon normalize +
# global benzersiz. Numara bos birakmak = degismez (exclude_unset).
class ResidentUpdate(BaseModel):
    """Sakin duzenleme (P23b).

    KURAL: olusturmada girilebilen HER ALAN sonradan da duzenlenebilir.
    Eskiden yalniz `ad` + `telefon` vardi; `email` ve `rol_tipi`
    (malik/kiraci) olusturmada giriliyor ama BIR DAHA degistirilemiyordu —
    kiraci cikip malik oturmaya baslayinca kayit yanlis kaliyordu ve bu,
    muhasebe hedeflemesini (P28) dogrudan bozacak bir hataydi.

    `rol_tipi` kullanicinin AKTIF daire baglarina (bitis IS NULL) uygulanir;
    aktif bagi yoksa 422 (once daire atanmali).
    (P197) `email` ARTIK TEMIZLENEMEZ. Eskiden acikca `null` gonderilerek
    bosaltilabiliyordu ("sakinde opsiyonel" kuralinin kalintisi); bu, NOT
    NULL sutunu (goc 0089) ihlal etmesinin yani sira SAHIPLENILEMEZ bir
    hesap uretirdi — davet ve dogrulama kodu yalniz e-postadan gider.
    Alan gonderilmezse DEGISMEZ; gonderilirse GECERLI bir adres olmali.
    """

    ad: str | None = Field(None, min_length=1)
    telefon: str | None = Field(None, min_length=1)
    #: `None` = "gonderilmedi" (degistirme). ACIKCA `null` gondermek de
    #: ayni anlama gelir — TEMIZLEME ARTIK YOK (bkz. docstring).
    email: EmailStr | None = None
    rol_tipi: ResidentRol | None = None

    @field_validator("telefon")
    @classmethod
    def _normalize_telefon(cls, v: str | None) -> str | None:
        if v is None:
            return v
        try:
            return normalize_phone(v)
        except ValueError as exc:
            raise ValueError(str(exc)) from exc

    @model_validator(mode="after")
    def _at_least_one(self) -> "ResidentUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class ResidentDeleteOut(BaseModel):
    """Akilli sil sonucu: deleted=true tamamen silindi (gecmissiz);
    deleted=false gecmis nedeniyle pasiflestirildi (telefon yine serbest)."""

    deleted: bool


class DuesAssessmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    unit_id: uuid.UUID
    donem: str
    tutar_kurus: int
    son_odeme_tarihi: date | None = None
    aciklama: str | None = None
    # --- P28 (ADDITIVE — eski alanlar aynen durur) ------------------------- #
    gelir_gider_tanim_id: uuid.UUID | None = None
    gelir_gider_tanim_ad: str | None = None
    hedef_user_id: uuid.UUID | None = None
    hedef_ad: str | None = None
    tarih: date | None = None
    gecikme_uygula: bool = True
    kaynak: str = "tekil"
    #: HENUZ YAZILMAMIS gecikme faizi (P192 §3.1). Yazilmis faiz kalemleri
    #: DUSULUR: yoksa ayni faiz hem burada hem ayri bir borc kalemi olarak
    #: iki kez gorunurdu.
    gecikme_kurus: int = 0
    # --- (P192 §3) --------------------------------------------------------- #
    #: Borc NEYIN borcu: aidat | demirbas | olaganustu | faiz | sayac | diger.
    kalem_tipi: str = "aidat"
    #: Doluysa bu satir bir DUZELTMEDIR ve gosterdigi tahakkuku goturur.
    ters_kayit_id: uuid.UUID | None = None
    #: (P193 §3) Bu tahakkuk ters kayitla DUZELTILDI mi.
    #:
    #: EKRAN ICIN SART: panel "Düzelt" dugmesini yalnizca duzeltilebilir
    #: satirda cizebilmeli. Alan olmadan dugme her satirda cizilir ve
    #: kullanici tiklayinca 409 alirdi — yapamayacagi bir eylemi
    #: gostermek, P167'de kapatilan kusur sinifi.
    iptal_edildi: bool = False
    #: Faiz kaleminin dogdugu borc.
    kaynak_assessment_id: uuid.UUID | None = None
    created_at: datetime


class DuesAssessmentCreate(BaseModel):
    donem: str = Field(..., min_length=1)
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)  # KURUS; negatif/sifir reddedilir
    unit_id: uuid.UUID | None = None     # verilirse tek daire
    unit_ids: list[uuid.UUID] | None = None  # toplu hedef; yoksa tum aktif daireler
    son_odeme_tarihi: date | None = None
    aciklama: str | None = None
    # --- P28 (hepsi OPSIYONEL: mevcut cagiranlar aynen calisir) ------------ #
    gelir_gider_tanim_id: uuid.UUID | None = None
    tarih: date | None = None
    gecikme_uygula: bool = True
    # --- (P192 §3.2) ------------------------------------------------------- #
    #: Kalem tipi. `faiz` DISARIDA: faiz elle yazilmaz, `gecikme-faizi/isle`
    #: ucundan dogar — elle yazilabilseydi kaynak borcla bagi kurulmaz ve
    #: idempotency kirilirdi.
    kalem_tipi: Literal["aidat", "demirbas", "olaganustu", "sayac", "diger"] = "aidat"


class TahakkukAtlanan(BaseModel):
    """(P192 §3.2) Yazilamayan daire ve NEDENI.

    Onceden yalnizca bir SAYI donuyordu ve toplu tahakkukta atlanan satir
    sessizce kayboluyordu; yonetici eksik tahakkuk yaptigini fark
    etmiyordu.
    """

    unit_id: uuid.UUID
    unit_no: str | None = None
    neden: str


class DuesAssessmentResult(BaseModel):
    created: list[DuesAssessmentOut]
    atlanan: int
    #: Atlananlarin DOKUMU. Bos liste, atlanan olmadigi anlamina gelir.
    atlananlar: list[TahakkukAtlanan] = []


class DuesAssessmentListResponse(BaseModel):
    meta: PageMetaOut
    items: list[DuesAssessmentOut]


class DuesPaymentOut(BaseModel):
    """Bir tahsilatin sakin/panel gorunumu.

    (P192 §1) Kaynak artik `dues_payment` DEGIL `finansal_hareket`tir;
    bicim korundu (bkz. `routers/dues.py::_odeme_out`). Uc alan
    OPSIYONELLESTI cunku defterde de opsiyoneller: vezneden girilen bir
    tahsilat daireye bagli olmayabilir, idempotency basligi gonderilmemis
    olabilir ve kaydeden kullanici silinmis olabilir.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    unit_id: uuid.UUID | None = None
    assessment_id: uuid.UUID | None = None
    tutar_kurus: int
    odeme_zamani: datetime
    donem: str | None = None
    yontem: str
    durum: str
    makbuz_no: str | None = None
    provider: str | None = None
    provider_ref: str | None = None
    kaydeden_user_id: uuid.UUID | None = None
    idempotency_key: str | None = None
    created_at: datetime


class DuesPaymentCreate(BaseModel):
    unit_id: uuid.UUID
    assessment_id: uuid.UUID | None = None
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)  # KURUS
    yontem: DuesYontem
    makbuz_no: str | None = None
    odeme_zamani: datetime | None = None
    # 'YYYY-MM'; verilmezse assessment'tan turer, o da yoksa NULL kalir.
    donem: str | None = Field(None, min_length=1)
    #: (P192 §1) Paranin girdigi kasa/banka hesabi. Verilmezse yontemden
    #: turetilir (havale/kart -> banka hesabi, elden -> merkez kasa) ve
    #: hicbiri yoksa acilir — NULL BIRAKILMAZ, cunku kasasiz bir tahsilat
    #: hicbir kasa bakiyesinde gorunmezdi.
    kasa_id: uuid.UUID | None = None


class DuesPaymentListResponse(BaseModel):
    meta: PageMetaOut
    items: list[DuesPaymentOut]


class UnitDuesStatus(BaseModel):
    unit_id: uuid.UUID
    no: str
    toplam_tahakkuk_kurus: int
    toplam_odenen_kurus: int
    bakiye_kurus: int
    assessments: list[DuesAssessmentOut] = []
    payments: list[DuesPaymentOut] = []


class MeDuesResponse(BaseModel):
    items: list[UnitDuesStatus]


# ------------------------------- budget ------------------------------------ #
# Butce (Wave 2A): para HER YERDE integer KURUS (dues deseni; float ASLA).
BudgetTip = Literal["gelir", "gider"]
BudgetKaynak = Literal["manuel", "aidat_odeme"]


class BudgetCategoryCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=100)
    tip: BudgetTip


class BudgetCategoryUpdate(BaseModel):
    """aktif=false = soft-delete (kayitli hareketler kategorisini korur)."""

    ad: str | None = Field(None, min_length=1, max_length=100)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "BudgetCategoryUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class BudgetCategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    tip: str
    aktif: bool
    created_at: datetime


class BudgetCategoryListResponse(BaseModel):
    meta: PageMetaOut
    items: list[BudgetCategoryOut]


class BudgetEntryCreate(BaseModel):
    """Manuel defter kaydi. `tip` ISTEMCIDEN ALINMAZ — kategoriden turetilir
    (kategori-tip uyusmazligi imkansiz olsun)."""

    kategori_id: uuid.UUID
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)  # KURUS; sifir/negatif reddedilir
    tarih: date
    aciklama: str | None = Field(None, max_length=1000)

    @field_validator("tutar_kurus", mode="before")
    @classmethod
    def _tam_kurus(cls, v: object) -> object:
        # 10.5 gibi float'lar sessizce yuvarlanmasin — para integer kurus.
        if isinstance(v, float):
            raise ValueError("tutar_kurus tam sayi (kurus) olmali")
        return v


class BudgetEntryUpdate(BaseModel):
    """Yalniz MANUEL kayitlar duzenlenebilir (aidat_odeme kayitlari aidat
    modulunun yetkisindedir)."""

    kategori_id: uuid.UUID | None = None
    tutar_kurus: int | None = Field(None, ge=1)
    tarih: date | None = None
    aciklama: str | None = Field(None, max_length=1000)

    @field_validator("tutar_kurus", mode="before")
    @classmethod
    def _tam_kurus(cls, v: object) -> object:
        if isinstance(v, float):
            raise ValueError("tutar_kurus tam sayi (kurus) olmali")
        return v

    @model_validator(mode="after")
    def _at_least_one(self) -> "BudgetEntryUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class BudgetEntryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    # (P192 §1) Defter satirinin butce kategorisi. OPSIYONEL: vezneden ya da
    # aidattan gelen bir satirin butce kategorisi olmayabilir; uydurma bir
    # kategori atamak, butce kirilimini gercek olmayan bir kalemle
    # doldururdu.
    kategori_id: uuid.UUID | None = None
    # Liste/rapor icin kategori adi (join ile doldurulur).
    kategori_ad: str | None = None
    tip: str
    tutar_kurus: int
    tarih: date
    aciklama: str | None = None
    kaynak: str
    ilgili_payment_id: uuid.UUID | None = None
    created_by: uuid.UUID | None = None
    created_at: datetime


class BudgetEntryListResponse(BaseModel):
    meta: PageMetaOut
    items: list[BudgetEntryOut]


class BudgetCategorySummary(BaseModel):
    kategori_id: uuid.UUID
    ad: str
    tip: str
    toplam_kurus: int


class BudgetSummary(BaseModel):
    """Kasa ozeti: bakiye = gelir - gider (negatif olabilir). KURUS."""

    toplam_gelir_kurus: int
    toplam_gider_kurus: int
    bakiye_kurus: int
    kategoriler: list[BudgetCategorySummary]


# --------------------- finansal ozet raporu (Wave 2B) ---------------------- #
class GiderKalemi(BaseModel):
    """En yuksek gider kategorileri (agregat — kisi/daire verisi yok)."""

    ad: str
    toplam_kurus: int


class TahsilatOzet(BaseModel):
    """Aidat tahsilat blogu — YALNIZ yonetim (admin+yonetici) gorur."""

    tahakkuk_kurus: int
    tahsilat_kurus: int  # yalniz durum='basarili' odemeler
    # tahakkuk 0 ise null (oran tanimsiz).
    tahsilat_orani_yuzde: int | None = None
    # donem tahakkuku tam odenmemis daire sayisi.
    geciken_daire_sayisi: int


class FinancialSummary(BaseModel):
    """Cepten hizli finansal ozet. Agregat alanlar TUM rollere; [tahsilat]
    yalniz yonetimde dolar (sakin/saha icin null — kisi/daire verisi sizmaz)."""

    donem: str | None = None
    toplam_gelir_kurus: int
    toplam_gider_kurus: int
    bakiye_kurus: int
    en_yuksek_giderler: list[GiderKalemi]
    tahsilat: TahsilatOzet | None = None


# --------------------- integrations (C1b — entegrasyon) --------------------- #
IntegrationChannel = Literal["webhook", "megaphone", "smarthome"]
HttpMethod = Literal["GET", "POST", "PUT", "PATCH"]
AuthType = Literal["none", "bearer", "api_key"]


def _validate_public_scheme(url: str) -> str:
    # Sema kapisi (tam SSRF kapisi TETIK aninda — DNS cozumu + IP denetimi).
    if not (url.startswith("http://") or url.startswith("https://")):
        raise ValueError("endpoint_url http(s) olmali")
    return url


class IntegrationCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=200)
    channel_type: IntegrationChannel = "webhook"
    endpoint_url: str = Field(..., min_length=1, max_length=2000)
    http_method: HttpMethod = "POST"
    headers_json: dict[str, str] = Field(default_factory=dict)
    auth_type: AuthType = "none"
    # Write-only: yalniz yazilir, GET'te ASLA donmez. KEK ile sifreli saklanir.
    auth_secret: str | None = Field(None, max_length=4000)
    payload_template: str = Field("", max_length=8000)
    aktif: bool = True

    @field_validator("endpoint_url")
    @classmethod
    def _scheme(cls, v: str) -> str:
        return _validate_public_scheme(v)


class IntegrationUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=200)
    channel_type: IntegrationChannel | None = None
    endpoint_url: str | None = Field(None, min_length=1, max_length=2000)
    http_method: HttpMethod | None = None
    headers_json: dict[str, str] | None = None
    auth_type: AuthType | None = None
    auth_secret: str | None = Field(None, max_length=4000)
    payload_template: str | None = Field(None, max_length=8000)
    aktif: bool | None = None

    @field_validator("endpoint_url")
    @classmethod
    def _scheme(cls, v: str | None) -> str | None:
        return None if v is None else _validate_public_scheme(v)

    @model_validator(mode="after")
    def _at_least_one(self) -> "IntegrationUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class IntegrationOut(BaseModel):
    """GET ciktisi — SIR ASLA donmez; yerine auth_secret_set (bool)."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    channel_type: str
    endpoint_url: str
    http_method: str
    headers_json: dict[str, str] = Field(default_factory=dict)
    auth_type: str
    # Sirrin VARLIGI bildirilir; sirrin KENDISI donmez (write-only).
    auth_secret_set: bool = False
    payload_template: str
    aktif: bool
    created_at: datetime

    @classmethod
    def from_model(cls, obj) -> "IntegrationOut":
        return cls(
            id=obj.id,
            ad=obj.ad,
            channel_type=obj.channel_type,
            endpoint_url=obj.endpoint_url,
            http_method=obj.http_method,
            headers_json=obj.headers_json or {},
            auth_type=obj.auth_type,
            auth_secret_set=bool(obj.auth_secret_enc),
            payload_template=obj.payload_template,
            aktif=obj.aktif,
            created_at=obj.created_at,
        )


class IntegrationListResponse(BaseModel):
    meta: PageMetaOut
    items: list[IntegrationOut]


class IntegrationTriggerIn(BaseModel):
    # Opsiyonel: payload_template yer tutucularini doldurur.
    message: str = Field("", max_length=2000)
    title: str = Field("", max_length=500)


class IntegrationTriggerOut(BaseModel):
    ok: bool
    status: int | None = None
    error: str | None = None


class IntegrationPresetOut(BaseModel):
    key: str
    channel_type: str
    http_method: str
    headers_json: dict[str, str]
    payload_template: str


# ------------------- unit complaints (D1 — daire sikayeti) ------------------ #
# TAM ANONIM: hicbir semada complainant_user_id YOKTUR (kasitli). Yonetimin
# ayri 'complaint' modulunden bagimsizdir.
UnitComplaintKategori = Literal[
    "gurultu", "kapi_onu_ayakkabi", "zarar_verme", "goruntu_kirliligi", "diger"
]
UnitComplaintDurum = Literal["acik", "kapali", "geri_alindi"]
# P24 — DORT KADEME: 0 yesil · 1-2 sari · 3-4 kirmizi · 5+ mor.
# Esikler `routers/unit_complaints._ESIKLER` tablosundadir (tek kaynak).
DensityRenk = Literal["yesil", "sari", "kirmizi", "mor"]


class UnitComplaintCreate(BaseModel):
    target_unit_id: uuid.UUID
    kategori: UnitComplaintKategori = "diger"
    notlar: str | None = Field(None, min_length=1, max_length=1000)


class UnitComplaintDecision(BaseModel):
    """Yonetim kapatma karari — YALNIZ durum (sikayet edeni GORMEDEN).

    (P146) `geri_alindi` BILEREK DISARIDA: geri alma SIKAYET EDENIN
    hakkidir ve kendi ucundan (`/withdraw`) yapilir. Ayni Literal'i burada
    da kullansaydik yonetim, sikayeti "sahibi geri aldi" gibi
    isaretleyebilirdi — kaydin anlamini bozan sessiz bir yetki genislemesi.
    """

    durum: Literal["acik", "kapali"]


class UnitComplaintOut(BaseModel):
    """Daire sikayeti ciktisi.

    Rev-2 GIZLILIK: `complainant_user_id` + `complainant_ad` ARTIK HICBIR uctan
    DOLDURULMAZ (her zaman None) — yonetim dahil kimse sikayet edenin kimligini
    gormez. Alanlar geriye-uyum icin sema'da kalir (hep null). `notlar` yalniz
    kendi kaydini goren sakine + yonetime doludur."""

    id: uuid.UUID
    target_unit_id: uuid.UUID
    unit_no: str | None = None
    kategori: str
    notlar: str | None = None
    durum: str
    created_at: datetime
    # YALNIZ yonetim icin doldurulur (denetim); digerinde None. resident kendi
    # actigi kaydin yanitinda da None gorur (kendi kimligini tekrar donmeye gerek yok).
    complainant_user_id: uuid.UUID | None = None
    complainant_ad: str | None = None
    #: ISTEYEN yoneticiye gore okunmus mu (P24 triyaj). Yonetim uclarinda dolu,
    #: sakin uclarinda None — okuma durumu bir YONETIM kuyrugu kavramidir.
    okundu: bool | None = None

    @classmethod
    def from_model(
        cls,
        obj,
        *,
        unit_no: str | None,
        include_note: bool,
        include_complainant: bool = False,
        complainant_ad: str | None = None,
        okundu: bool | None = None,
    ) -> "UnitComplaintOut":
        return cls(
            okundu=okundu,
            id=obj.id,
            target_unit_id=obj.target_unit_id,
            unit_no=unit_no,
            kategori=obj.kategori,
            notlar=obj.notlar if include_note else None,
            durum=obj.durum,
            created_at=obj.created_at,
            complainant_user_id=obj.complainant_user_id if include_complainant else None,
            complainant_ad=complainant_ad if include_complainant else None,
        )


class UnitComplaintListResponse(BaseModel):
    meta: PageMetaOut
    items: list[UnitComplaintOut]


class UnitDensityItem(BaseModel):
    """Daire-basi ANONIM yogunluk — sayilar + renk (sikayet eden YOK)."""

    target_unit_id: uuid.UUID
    unit_no: str
    blok: str | None = None
    acik_sayisi: int  # ACIK sikayet sayisi (kapatilanlar renge etki etmez)
    renk: DensityRenk


class UnitDensityResponse(BaseModel):
    items: list[UnitDensityItem]


# ------------------- building map (D-viz — bina semasi) --------------------- #
# ROL-FARKINDA (Rev-1): yonetici/admin sayim+renk gorur; resident/security/
# tesis_gorevlisi YALNIZ yapi (sayim+renk NULL). Renk esikleri: 0-2/3-4/5+.
class BuildingMapUnit(BaseModel):
    """Haritada tek daire — yerlesim + (yonetim icin) sayim/renk + (resident icin)
    KENDI sikayet isareti.

    complaint_count/color YALNIZ yonetim (admin+yonetici) icin doludur; diger
    roller icin None (residentlar hangi dairenin kac sikayeti oldugunu bilemez).

    benim_sikayetim/benim_acik_sayisi YALNIZ resident icin anlamlidir ve
    TAMAMEN kendi kayitlarindan (complainant == kendisi) turetilir: bu daireye
    KENDI sikayeti var mi (isaretleme) + KENDI acik sikayet sayisi. Genel
    yogunluk/baskalarinin verisi ASLA sizmaz (digerinin sayisi hep None/False).
    """

    unit_id: uuid.UUID
    unit_no: str
    blok: str | None = None
    kat: int | None = None
    sira: int | None = None
    complaint_count: int | None = None  # yalniz yonetim; digerinde None
    color: DensityRenk | None = None    # yalniz yonetim; digerinde None
    # resident'in KENDI sikayet isareti (kendi kayitlarindan; baskasi icin False/None).
    benim_sikayetim: bool = False       # bu daireye KENDI sikayetim var mi
    benim_acik_sayisi: int | None = None  # KENDI acik sikayet sayim (yalniz resident)


class BuildingMapKat(BaseModel):
    """Bir bloktaki tek kat — sira'ya gore sirali daireler."""

    kat: int
    units: list[BuildingMapUnit]


class BuildingMapBlok(BaseModel):
    """Tek blok — kat'a gore sirali (0=zemin altta)."""

    blok: str
    katlar: list[BuildingMapKat]


class BuildingMapResponse(BaseModel):
    """Cizilebilir yapi: blok -> kat -> daire; yerlesimi eksik daireler
    'unplaced' kovada. ROL-FARKINDA: `shows_density` yonetimde True (sayim+renk
    dolu); resident/security/gorevli icin False (yalniz yapi). resident YALNIZ
    KENDI blogunu gorur (sikayet secici)."""

    shows_density: bool  # True: complaint_count/color dolu (yonetim); False: yapi
    bloklar: list[BuildingMapBlok]
    unplaced: list[BuildingMapUnit]


# ------------------------------ denetim (audit) ---------------------------- #
class AuditLogOut(BaseModel):
    """KVKK denetim satiri (admin goruntuleyici). meta yalniz id/alan-adi tutar."""

    id: uuid.UUID
    ts: datetime
    tenant_id: uuid.UUID | None = None
    actor_user_id: uuid.UUID | None = None
    actor_rol: str | None = None
    action: str
    resource_type: str | None = None
    resource_id: str | None = None
    meta: dict = {}


class AuditLogListResponse(BaseModel):
    meta: PageMetaOut
    items: list[AuditLogOut]


# ----------------------- seffaflik panosu (transparency) ------------------- #
class TransparencyKategoriKalemi(BaseModel):
    """Gider dagilimi kalemi — kategori ADI (kisisel veri DEGIL) + tutar + %."""

    ad: str
    toplam_kurus: int
    yuzde: int  # toplam gider icindeki pay (0-100)


class TransparencyAidat(BaseModel):
    """Aidat toplama — TUTAR-bazli + ADET(daire)-bazli. Bireysel veri YOK; yalniz
    toplamlar/sayilar/yuzdeler. `geciken_daire_sayisi` yalniz SAYI (hangi daire ASLA)."""

    tahakkuk_kurus: int
    tahsilat_kurus: int
    tutar_orani_yuzde: int | None = None   # amount-based (tahakkuk 0 -> null)
    toplam_daire: int
    odeyen_daire: int                      # tam odeyen daire sayisi
    daire_orani_yuzde: int | None = None   # count-based (toplam_daire 0 -> null)
    geciken_daire_sayisi: int              # SAYI ONLY — kimlik/daire etiketi YOK


class TransparencyBoardOut(BaseModel):
    """Aylik anonim seffaflik ozeti. Ad/daire-etiketi/bireysel-tutar ICERMEZ."""

    ay: str
    yayinlandi: bool
    toplam_gelir_kurus: int
    toplam_gider_kurus: int
    net_kurus: int
    gider_dagilimi: list[TransparencyKategoriKalemi]
    aidat: TransparencyAidat
    onceki_ay_net_kurus: int | None = None


class TransparencyAyOzet(BaseModel):
    """Ay listesi ogesi. Sakin: yayinlanmis aylar. Yonetim: aday aylar + durum."""

    ay: str
    yayinlandi: bool
    net_kurus: int | None = None  # yonetim/onizleme dolu; sakin listesinde de dolu


class TransparencyListResponse(BaseModel):
    items: list[TransparencyAyOzet]


class TransparencyPublishRequest(BaseModel):
    yayin: bool


# ------------------------- platform destek kanali -------------------------- #
SupportDurum = Literal["acik", "cozuldu"]


class SupportTicketCreate(BaseModel):
    konu: str = Field(..., min_length=1, max_length=200)
    aciklama: str = Field(..., min_length=1, max_length=4000)
    # Talep gorseli (WP-G) — opsiyonel; tenant-onekli MinIO anahtari.
    foto_key: str | None = None


class SupportTicketOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tenant_id: uuid.UUID
    acan_user_id: uuid.UUID
    konu: str
    aciklama: str
    durum: str
    admin_cevap: str | None = None
    # Gorseller (WP-G) — key ORM/SQL'den; url router'da presign ile doldurulur.
    foto_key: str | None = None
    admin_cevap_foto_key: str | None = None
    foto_url: str | None = None
    admin_cevap_foto_url: str | None = None
    created_at: datetime
    updated_at: datetime | None = None


class SupportTicketAdminOut(SupportTicketOut):
    """Admin capraz-tenant listesi: tenant adi da doner."""

    tenant_ad: str | None = None


class SupportTicketListResponse(BaseModel):
    meta: PageMetaOut
    items: list[SupportTicketOut]


class SupportTicketAdminListResponse(BaseModel):
    meta: PageMetaOut
    items: list[SupportTicketAdminOut]


class SupportTicketUpdate(BaseModel):
    """Admin yaniti: en az bir alan verilmeli (router zorlar)."""

    durum: SupportDurum | None = None
    admin_cevap: str | None = Field(None, max_length=4000)
    # Admin cevap gorseli (WP-G) — opsiyonel; admin kendi tenant onegi.
    admin_cevap_foto_key: str | None = None


# -------------------------------- weather ---------------------------------- #
class WeatherOut(BaseModel):
    sicaklik_c: float
    durum: str  # acik|parcali|kapali|sis|yagmur|kar|firtina
    konum_ad: str


# ----------------------------- vehicle pass (G1) ---------------------------- #
class VehiclePassCreate(BaseModel):
    """Arac GIRISI. plaka sunucuda normalize edilir (bosluksuz + BUYUK).

    Daire referansi opsiyoneldir: unit_id VEYA unit_no (ikisi birlikte olmaz).
    Hicbiri verilmezse arac daireye bagli degildir (ziyaretci/kurye/bilinmeyen).
    """

    plaka: str = Field(..., min_length=1, max_length=32, examples=["34 ABC 123"])
    arac_tanim: str | None = Field(None, min_length=1, max_length=120,
                                   examples=["BMW Siyah"])
    unit_id: uuid.UUID | None = None
    unit_no: str | None = Field(None, min_length=1, max_length=50)
    ziyaretci_mi: bool = False
    # Girilmezse sunucu saati (now()) damgalanir; geriye donuk kayit icin acik
    # deger verilebilir (gelecege damga 422 — router dogrular).
    giris_zamani: datetime | None = None

    @model_validator(mode="after")
    def _tek_daire_referansi(self) -> "VehiclePassCreate":
        if self.unit_id is not None and self.unit_no is not None:
            raise ValueError("unit_id ve unit_no birlikte verilemez")
        return self


class VehiclePassOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    # NORMALIZE plaka (bosluksuz + BUYUK) — saklanan halin aynisi.
    plaka: str
    arac_tanim: str | None = None
    giris_zamani: datetime
    # null => arac HALA ICERIDE (acik gecis).
    cikis_zamani: datetime | None = None
    unit_id: uuid.UUID | None = None
    # Daire numarasi (join ile; daire bagi yoksa null).
    unit_no: str | None = None
    ziyaretci_mi: bool
    kaydeden_user_id: uuid.UUID
    # Kaydi acan personelin adi (join ile).
    kaydeden_ad: str | None = None
    created_at: datetime


class VehiclePassListResponse(BaseModel):
    meta: PageMetaOut
    items: list[VehiclePassOut]


# ---------------------------- parking occupancy (G4) ------------------------ #
class ParkingOccupancyOut(BaseModel):
    """Otopark dolulugu. `dolu` = ACIK arac gecisi (cikis_zamani IS NULL) sayisi.

    Kapasite tenant ayarindan gelir; TANIMSIZ (null) veya 0 iken `oran` da null
    doner — istemci "—" gosterir (uydurma yuzde uretilmez).
    """

    kapasite: int | None = None
    dolu: int
    # Yuzde (0-100, tam sayiya yuvarli); kapasite null/0 iken null.
    oran: int | None = None


# ------------------------------ violation (G2) ------------------------------ #
ViolationKaynak = Literal["kamera", "manuel", "devriye"]
ViolationDurum = Literal["yeni", "inceleniyor", "kapatildi"]


class ViolationCreate(BaseModel):
    baslik: str = Field(..., min_length=1, max_length=200)
    aciklama: str | None = Field(None, min_length=1, max_length=2000)
    kaynak: ViolationKaynak = "manuel"
    konum: str | None = Field(None, min_length=1, max_length=200,
                              examples=["Otopark Girişi - Kamera 3"])


class ViolationUpdate(BaseModel):
    """Durum gecisi. 'kapatildi' TERMINAL ve YALNIZ admin (router zorlar)."""

    durum: ViolationDurum


class ViolationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    baslik: str
    aciklama: str | None = None
    kaynak: str
    konum: str | None = None
    durum: str
    olusturan_user_id: uuid.UUID
    # Kaydi acan kullanicinin adi (join ile).
    olusturan_ad: str | None = None
    created_at: datetime
    updated_at: datetime


class ViolationListResponse(BaseModel):
    meta: PageMetaOut
    items: list[ViolationOut]


# --------------------------- unified activity (G5) -------------------------- #
# Renk ipucu — UI noktasi/rozet rengi (mobil sozlugu).
ActivityRenk = Literal["olumlu", "uyari", "alarm", "notr"]


class ActivityItemOut(BaseModel):
    """Birlesik akis olayi. `id` kaynaklar arasi benzersizdir ("<tur>:<uuid>");
    `kaynak_id` ise kaynak kaydin kendi uuid'sidir (derin baglanti icin).

    METIN DEGIL KIMLIK (tur 15): satirin gorunen cumlesini ISTEMCI kurar.
      * `baslik_kimlik` — yerellestirilebilir baslik kimligi. `tur`den AYRIDIR
        cunku bir tur birden cok baslik verebilir (`talep` -> `talep_acik` |
        `talep_is_emri` | `talep_cozuldu` | `talep_reddedildi`).
      * `veri` — satirin DEGISKEN kismi (daire no, firma, plaka, kurus,
        kategori kimligi, pencere sinirlari). Opsiyonel alanlar YOKTUR
        (gonderilmez), boylece istemci bicimi alanin varligina gore secer.
        Para `tutar_kurus` tam sayidir: bicimleme dile duyarlidir, sunucunun
        isi degildir.

    `baslik`/`alt_metin` **DEPRECATED**: yalniz guncellenmemis istemciler icin
    ve YALNIZ Turkce uretilir (`app/akis_metinleri.py`). Yeni istemci bunlara
    bakmaz; tum istemciler gecince alanlar sozlesmeden kalkacak.
    """

    id: str
    tur: str
    baslik_kimlik: str
    veri: dict[str, Any] = Field(default_factory=dict)
    baslik: str
    alt_metin: str | None = None
    zaman: datetime
    renk_ipucu: ActivityRenk | None = None
    kaynak_id: uuid.UUID


class ActivityMetaOut(BaseModel):
    """Cursor sayfalama meta'si — `total` YOKTUR (birlesik akista sayim pahali
    ve anlamsizdir). `next_cursor` null ise akisin sonundasiniz."""

    limit: int
    next_cursor: str | None = None


class ActivityResponse(BaseModel):
    meta: ActivityMetaOut
    items: list[ActivityItemOut]


# --------------------------------------------------------------------------- #
# ANPR — kaynaktan bagimsiz plaka okuma girisi (0011 / P16)
# --------------------------------------------------------------------------- #
class AnprEventIn(BaseModel):
    """Kaynaktan bagimsiz ANPR olay govdesi.

    `kaynak` hangi ADAPTORUN calisacagini secer. `frigate|hikvision|dahua`
    icin govdenin geri kalani O MARKANIN kendi bicimi olabilir (`ham` icinde
    ya da dogrudan); `manuel`/`standart` icin asagidaki alanlar dogrudan
    okunur. Adaptor esleme tablosu: `docs/frigate-poc.md` §6.
    """

    kaynak: str = Field(..., examples=["frigate"])
    # Kaynagin KENDI olay kimligi — IDEMPOTENCY anahtari. Frigate ayni olayi
    # `update` ve `end` olarak iki kez yayinlar; bu alan olmadan tek arac iki
    # gecis acardi (P15'te olculdu).
    kaynak_olay_id: str | None = Field(None, max_length=200)
    plaka: str | None = Field(None, max_length=64)
    zaman: datetime | None = None
    kamera: str | None = Field(None, max_length=120)
    yon: str | None = Field(None, examples=["giris"])
    guven: float | None = Field(None, ge=0, le=100)
    foto_key: str | None = Field(None, max_length=500)
    ham: dict[str, Any] = Field(default_factory=dict)

    model_config = {"extra": "allow"}


class AnprEventOut(BaseModel):
    """Islenmis olay — kamera kutusuna DA bu doner (tani icin)."""

    id: uuid.UUID
    kaynak: str
    kaynak_olay_id: str
    plaka: str
    zaman: datetime
    kamera: str | None = None
    yon: str
    guven: float | None = None
    durum: str
    durum_nedeni: str | None = None
    vehicle_pass_id: uuid.UUID | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class AnprEventListResponse(BaseModel):
    meta: PageMetaOut
    items: list[AnprEventOut]


class AnprOnayIn(BaseModel):
    """Onay kuyrugundaki bir okumanin insan karari.

    `plaka` verilirse OCR duzeltilir (bir-iki karakter yanlis okunmasi en
    yaygin hatadir); verilmezse okunan plaka kabul edilir.
    """

    onay: bool
    plaka: str | None = Field(None, min_length=1, max_length=64)


class AnprApiKeyCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=120, examples=["Ana kapi kutusu"])


class AnprApiKeyOut(BaseModel):
    id: uuid.UUID
    ad: str
    kimlik: str
    aktif: bool
    son_kullanim: datetime | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class AnprApiKeyCreated(AnprApiKeyOut):
    """Olusturma yaniti — `anahtar` YALNIZ BURADA, BIR KEZ doner.

    Sunucuda anahtarin kendisi saklanmaz (yalniz sha256 ozeti); kaybedilirse
    yenisi uretilir. Bu, sizan bir yedekten anahtarin geri uretilememesi
    icindir.
    """

    anahtar: str


# ====================== P27 "Tanimlar" katmani semalari ===================== #
# PARA HER YERDE KURUS (`*_kurus`, int). Acilis bakiyeleri ISARETSIZ tutar +
# AYRI yon tasir: "-500" bir firmada "biz mi borcluyuz, o mu" sorusunu
# yanitlamaz.
GelirGiderTip = Literal["gelir", "gider", "her_ikisi"]
#: TANIMIN varsayilan dagitim SEKLI (bir ipucudur). Gercek dagitim
#: yontemi P192 §3.3'ten beri `TopluBorcIstek.dagitim` alanindadir
#: (`esit` / `arsa_payi` / `metrekare` / `daire_basina`); burasi enum
#: oldugu icin genisletmek ALTER TYPE gerektirir ve iki yerde iki ayri
#: dogruluk uretirdi.
GelirGiderDagitim = Literal["bagimsiz_bolumlere_esit", "tipe_gore"]
#: (P28) Borcun KIME yazilacagi — kural TANIMDA durur (bkz. models).
BorcHedefKurali = Literal["kiraci_oncelikli", "malik"]
BakiyeYon = Literal["borc", "alacak"]
SayacTip = Literal["su", "elektrik", "dogalgaz", "isi", "diger"]

# (P206 §3.1) IBAN DENETIMI REGEX'TEN CIKTI.
#
# Eski hâl `^TR[0-9]{24}$` iki ucta birden yanlisti: yurt disindaki bir
# tesis kendi IBAN'ini GIREMIYOR, buna karsilik tek hanesi yanlis
# yazilmis bir TR IBAN'i KABUL EDILIYORDU (para yanlis hesaba gider ve
# ancak kaybolunca fark edilir). Yerine `app/iban.py`: ulke uzunlugu +
# ISO 13616 mod 97 saglama toplami. Gerekce `docs/P206-kararlar.md` K3.1.
def _iban_dogrula(v: str | None) -> str | None:
    """Bos gecerli; dolu ise DOGRULANIR ve KANONIK bicimde saklanir.

    Normalizasyon SUNUCUDA yapilir, yalniz istemcide degil: ayni IBAN'in
    "TR33 0006..." ve "TR330006..." diye iki kayit uretmesi, IBAN'i
    esleme anahtari olarak kullanan banka ekstresi eslestirmesini
    (P191) bozardi — ve istemci her zaman bizim istemcimiz degil.
    """
    from .iban import iban_gecerli_mi, iban_temizle

    if v is None or not v.strip():
        return None
    if not iban_gecerli_mi(v):
        # Pydantic hatasi -> 422 `validation_error`. Metin kataloga
        # bagli degil cunku alan duzeyinde doner (`details[].field`).
        raise ValueError("iban_gecersiz")
    return iban_temizle(v)


#: Vergi no 10 hane (tuzel) ya da TC 11 hane (sahis) — ikisi de kabul.
_VERGI_NO_PATTERN = r"^[0-9]{10,11}$"


class _TanimBase(BaseModel):
    """Tum tanim ciktilarinin ortak kuyrugu."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    aktif: bool
    created_at: datetime
    updated_at: datetime | None = None


# --------------------------------- kasa ------------------------------------ #
class KasaCreate(BaseModel):
    kod: str = Field(..., min_length=1, max_length=20)
    ad: str = Field(..., min_length=1, max_length=100)
    acilis_tarihi: date | None = None
    acilis_bakiye_kurus: int = 0
    banka_mi: bool = False
    iban: str | None = Field(None, max_length=42)
    banka_adi: str | None = Field(None, max_length=100)
    sube: str | None = Field(None, max_length=100)
    aktif: bool = True

    @field_validator("iban")
    @classmethod
    def _iban(cls, v: str | None) -> str | None:
        return _iban_dogrula(v)

    @model_validator(mode="after")
    def _banka_alanlari(self) -> "KasaCreate":
        # IBAN yalniz BANKA kasasinda anlamlidir: banka olmayan bir kasada
        # dolu IBAN, odemeyi yanlis hesaba yonlendirme riskidir.
        if not self.banka_mi and (self.iban or self.banka_adi or self.sube):
            raise ValueError("banka bilgileri yalniz banka kasasinda girilebilir")
        return self


class KasaUpdate(BaseModel):
    kod: str | None = Field(None, min_length=1, max_length=20)
    ad: str | None = Field(None, min_length=1, max_length=100)
    acilis_tarihi: date | None = None
    acilis_bakiye_kurus: int | None = None
    banka_mi: bool | None = None
    iban: str | None = Field(None, max_length=42)
    banka_adi: str | None = Field(None, max_length=100)
    sube: str | None = Field(None, max_length=100)
    aktif: bool | None = None

    @field_validator("iban")
    @classmethod
    def _iban(cls, v: str | None) -> str | None:
        return _iban_dogrula(v)

    @model_validator(mode="after")
    def _at_least_one(self) -> "KasaUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class KasaOut(_TanimBase):
    kod: str
    ad: str
    acilis_tarihi: date | None = None
    acilis_bakiye_kurus: int
    banka_mi: bool
    iban: str | None = None
    banka_adi: str | None = None
    sube: str | None = None


class KasaListResponse(BaseModel):
    meta: PageMetaOut
    items: list[KasaOut]


# --------------------------- gelir/gider grubu ------------------------------ #
class GelirGiderGrupCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=100)
    aktif: bool = True


class GelirGiderGrupUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=100)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "GelirGiderGrupUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class GelirGiderGrupOut(_TanimBase):
    ad: str


class GelirGiderGrupListResponse(BaseModel):
    meta: PageMetaOut
    items: list[GelirGiderGrupOut]


# --------------------------- gelir/gider tanimi ----------------------------- #
class GelirGiderTanimCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=100)
    tip: GelirGiderTip
    grup_id: uuid.UUID | None = None
    dagitim_sekli: GelirGiderDagitim | None = None
    #: (P28) Borc KIME yazilir. Varsayilan `kiraci_oncelikli` (aidat,
    #: faturalar: kullanan oder); yatirim/demirbas icin `malik` secilir.
    hedef_kurali: BorcHedefKurali = "kiraci_oncelikli"
    aktif: bool = True

    @model_validator(mode="after")
    def _dagitim_gelirde_olmaz(self) -> "GelirGiderTanimCreate":
        # Bir GELIR kalemi bagimsiz bolumlere "dagitilmaz", tahsil edilir.
        if self.tip == "gelir" and self.dagitim_sekli is not None:
            raise ValueError("gelir kaleminde dagitim sekli olmaz")
        return self


class GelirGiderTanimUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=100)
    tip: GelirGiderTip | None = None
    grup_id: uuid.UUID | None = None
    dagitim_sekli: GelirGiderDagitim | None = None
    hedef_kurali: BorcHedefKurali | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "GelirGiderTanimUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class GelirGiderTanimOut(_TanimBase):
    ad: str
    tip: str
    grup_id: uuid.UUID | None = None
    #: Grup ADI da doner — istemci ayri istek yapmadan listeyi cizsin.
    grup_ad: str | None = None
    dagitim_sekli: str | None = None
    hedef_kurali: str = "kiraci_oncelikli"


class GelirGiderTanimListResponse(BaseModel):
    meta: PageMetaOut
    items: list[GelirGiderTanimOut]


# -------------------------------- firma ------------------------------------- #
class FirmaCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=150)
    vergi_no: str | None = Field(None, pattern=_VERGI_NO_PATTERN)
    vergi_dairesi: str | None = Field(None, max_length=100)
    telefon: str | None = Field(None, max_length=30)
    email: EmailStr | None = None
    adres: str | None = Field(None, max_length=500)
    yetkili_ad: str | None = Field(None, max_length=150)
    yetkili_telefon: str | None = Field(None, max_length=30)
    acilis_bakiye_kurus: int = Field(0, ge=0, le=KURUS_UST_SINIR)
    acilis_bakiye_yon: BakiyeYon = "borc"
    aktif: bool = True


class FirmaUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=150)
    vergi_no: str | None = Field(None, pattern=_VERGI_NO_PATTERN)
    vergi_dairesi: str | None = Field(None, max_length=100)
    telefon: str | None = Field(None, max_length=30)
    email: EmailStr | None = None
    adres: str | None = Field(None, max_length=500)
    yetkili_ad: str | None = Field(None, max_length=150)
    yetkili_telefon: str | None = Field(None, max_length=30)
    acilis_bakiye_kurus: int | None = Field(None, ge=0)
    acilis_bakiye_yon: BakiyeYon | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "FirmaUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class FirmaOut(_TanimBase):
    ad: str
    vergi_no: str | None = None
    vergi_dairesi: str | None = None
    telefon: str | None = None
    email: str | None = None
    adres: str | None = None
    yetkili_ad: str | None = None
    yetkili_telefon: str | None = None
    acilis_bakiye_kurus: int
    acilis_bakiye_yon: str


class FirmaListResponse(BaseModel):
    meta: PageMetaOut
    items: list[FirmaOut]


# ------------------------------- personel ----------------------------------- #
class PersonelKayitCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=150)
    tc: str | None = Field(None, pattern=r"^[0-9]{11}$")
    gorev: str | None = Field(None, max_length=100)
    telefon: str | None = Field(None, max_length=30)
    email: EmailStr | None = None
    giris_tarihi: date | None = None
    cikis_tarihi: date | None = None
    maas_kurus: int | None = Field(None, ge=0)
    #: (P203 §5) SAATLIK ucret. BOS ISE aylikten turetilir
    #: (`maas_kurus / 225`; 30 gun x 7,5 saat — Turkiye'de standart
    #: bolen). Zorunlu kilmak, ayligi girmis yoneticiye ayni bilgiyi
    #: ikinci kez sordurmakti; hic sormamak ise saatlik calisan
    #: sozlesmelerini imkansiz kilardi.
    saatlik_ucret_kurus: int | None = Field(None, ge=0)
    #: Uygulama hesabiyla BAG (opsiyonel) — her personelin hesabi yoktur.
    app_user_id: uuid.UUID | None = None
    aktif: bool = True

    @model_validator(mode="after")
    def _tarih_sirasi(self) -> "PersonelKayitCreate":
        if (
            self.cikis_tarihi is not None
            and self.giris_tarihi is not None
            and self.cikis_tarihi < self.giris_tarihi
        ):
            raise ValueError("cikis tarihi giris tarihinden once olamaz")
        return self


class PersonelKayitUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=150)
    tc: str | None = Field(None, pattern=r"^[0-9]{11}$")
    gorev: str | None = Field(None, max_length=100)
    telefon: str | None = Field(None, max_length=30)
    email: EmailStr | None = None
    giris_tarihi: date | None = None
    cikis_tarihi: date | None = None
    maas_kurus: int | None = Field(None, ge=0)
    #: (P203 §5) SAATLIK ucret. BOS ISE aylikten turetilir
    #: (`maas_kurus / 225`; 30 gun x 7,5 saat — Turkiye'de standart
    #: bolen). Zorunlu kilmak, ayligi girmis yoneticiye ayni bilgiyi
    #: ikinci kez sordurmakti; hic sormamak ise saatlik calisan
    #: sozlesmelerini imkansiz kilardi.
    saatlik_ucret_kurus: int | None = Field(None, ge=0)
    app_user_id: uuid.UUID | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "PersonelKayitUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class PersonelKayitOut(_TanimBase):
    ad: str
    tc: str | None = None
    gorev: str | None = None
    telefon: str | None = None
    email: str | None = None
    giris_tarihi: date | None = None
    cikis_tarihi: date | None = None
    maas_kurus: int | None = None
    app_user_id: uuid.UUID | None = None
    #: Bagli kullanicinin adi (varsa) — "bu personel kim olarak giris yapiyor".
    app_user_ad: str | None = None


class PersonelKayitListResponse(BaseModel):
    meta: PageMetaOut
    items: list[PersonelKayitOut]


# --------------------------------- arac -------------------------------------- #
class AracKayitCreate(BaseModel):
    #: Sunucu NORMALIZE eder (bosluksuz + BUYUK) — `vehicle_pass` ile ayni kural.
    plaka: str = Field(..., min_length=2, max_length=30)
    user_id: uuid.UUID | None = None
    unit_id: uuid.UUID | None = None
    marka: str | None = Field(None, max_length=50)
    model: str | None = Field(None, max_length=50)
    renk: str | None = Field(None, max_length=30)
    aktif: bool = True


class AracKayitUpdate(BaseModel):
    plaka: str | None = Field(None, min_length=2, max_length=30)
    user_id: uuid.UUID | None = None
    unit_id: uuid.UUID | None = None
    marka: str | None = Field(None, max_length=50)
    model: str | None = Field(None, max_length=50)
    renk: str | None = Field(None, max_length=30)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "AracKayitUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class AracKayitOut(_TanimBase):
    plaka: str
    user_id: uuid.UUID | None = None
    user_ad: str | None = None
    unit_id: uuid.UUID | None = None
    unit_no: str | None = None
    marka: str | None = None
    model: str | None = None
    renk: str | None = None


class AracKayitListResponse(BaseModel):
    meta: PageMetaOut
    items: list[AracKayitOut]


# ------------------------------- sayaclar ------------------------------------ #
class SayacAnaCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=100)
    tip: SayacTip = "diger"
    tesisat_no: str | None = Field(None, max_length=50)
    ortak_alan_dagitim: GelirGiderDagitim | None = None
    ortak_alan_yuzde: float | None = Field(None, ge=0, le=100)
    aktif: bool = True


class SayacAnaUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=100)
    tip: SayacTip | None = None
    tesisat_no: str | None = Field(None, max_length=50)
    ortak_alan_dagitim: GelirGiderDagitim | None = None
    ortak_alan_yuzde: float | None = Field(None, ge=0, le=100)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "SayacAnaUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class SayacAnaOut(_TanimBase):
    ad: str
    tip: str
    tesisat_no: str | None = None
    ortak_alan_dagitim: str | None = None
    ortak_alan_yuzde: float | None = None
    #: Bu ana sayaca bagli bagimsiz bolum sayaci sayisi.
    bolum_sayaci_sayisi: int = 0


class SayacAnaListResponse(BaseModel):
    meta: PageMetaOut
    items: list[SayacAnaOut]


class SayacBolumCreate(BaseModel):
    unit_id: uuid.UUID
    ana_sayac_id: uuid.UUID | None = None
    tesisat_no: str | None = Field(None, max_length=50)
    ilk_okuma: float | None = Field(None, ge=0)
    aktif: bool = True


class SayacBolumUpdate(BaseModel):
    ana_sayac_id: uuid.UUID | None = None
    tesisat_no: str | None = Field(None, max_length=50)
    ilk_okuma: float | None = Field(None, ge=0)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "SayacBolumUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class SayacBolumOut(_TanimBase):
    unit_id: uuid.UUID
    unit_no: str | None = None
    ana_sayac_id: uuid.UUID | None = None
    ana_sayac_ad: str | None = None
    tesisat_no: str | None = None
    ilk_okuma: float | None = None


class SayacBolumListResponse(BaseModel):
    meta: PageMetaOut
    items: list[SayacBolumOut]


class SayacBolumOtomatikOlustur(BaseModel):
    """Bir ana sayac icin TUM aktif dairelere sayac uret (P27).

    Elle 200 daire icin sayac acmak gercekci degildir; zaten sayaci olan
    daireler ATLANIR (yeniden calistirilabilir).
    """

    ana_sayac_id: uuid.UUID


class SayacOtomatikSonuc(BaseModel):
    olusturulan: int
    atlanan: int


# --------------------------- tenant muhasebe ayarlari ------------------------ #
class MuhasebeAyarOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    evrak_seri: str
    evrak_sira: int
    #: YALNIZ GOSTERIM — depo ve hesaplama ₺ kalir (cok para birimi ayri karar).
    para_birimi: str


class MuhasebeAyarUpdate(BaseModel):
    evrak_seri: str | None = Field(None, pattern=r"^[A-Z]{1,5}$")
    evrak_sira: int | None = Field(None, ge=1)
    para_birimi: str | None = Field(None, pattern=r"^[A-Z]{3}$")

    @model_validator(mode="after")
    def _at_least_one(self) -> "MuhasebeAyarUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


# ========================= P28 BORCLANDIRMA MOTORU ========================== #
# Uc yol da AYNI kayda (`dues_assessment`) yazar — paralel bir sistem YOK.
BorclandirmaKaynak = Literal["tekil", "toplu", "sayac", "ice_aktarim"]


class TopluBorcSuzgec(BaseModel):
    """Toplu borclandirmanin HEDEF SUZGECI (P26 tip/grup + blok)."""

    blok: str | None = None
    unit_tip_id: uuid.UUID | None = None
    unit_grup_id: uuid.UUID | None = None
    #: Verilirse suzgec YERINE bu daireler (elle secim).
    unit_ids: list[uuid.UUID] | None = None


class TopluBorcIstek(BaseModel):
    """Toplu borclandirma — ONIZLEME ve ISLEME AYNI govdeyi kullanir.

    Ayni govde olmasi bilincli: onizlemede gorulen ile islenen arasinda
    fark kalmasin. `tutar_kurus` verilirse HER daireye o tutar; verilmezse
    P26'nin TIP VARSAYILANI kullanilir (`tipe_gore`).
    """

    donem: str = Field(..., min_length=1, max_length=7)
    gelir_gider_tanim_id: uuid.UUID
    suzgec: TopluBorcSuzgec = Field(default_factory=TopluBorcSuzgec)
    tutar_kurus: int | None = Field(None, ge=1)
    #: `tutar_kurus` yoksa tipi/tutari olmayan daireler icin yedek tutar.
    yedek_tutar_kurus: int | None = Field(None, ge=1)
    son_odeme_tarihi: date | None = None
    tarih: date | None = None
    aciklama: str | None = Field(None, max_length=500)
    gecikme_uygula: bool = True
    kalem_tipi: Literal[
        "aidat", "demirbas", "olaganustu", "sayac", "diger"
    ] = "aidat"
    # --- (P192 §3.3) DAGITIM YONTEMI --------------------------------------- #
    #: `daire_basina` (varsayilan, ESKI DAVRANIS) — `tutar_kurus` her
    #: daireye ayni ayni yazilir, yoksa tip varsayilani kullanilir.
    #: `esit` / `arsa_payi` / `metrekare` — `toplam_tutar_kurus` DAIRELERE
    #: BOLUNUR. Kat Mulkiyeti Kanunu md. 20 arsa payini sart kosar;
    #: uründe yalniz esit ve daire tipi vardi.
    dagitim: Literal[
        "daire_basina", "esit", "arsa_payi", "metrekare"
    ] = "daire_basina"
    #: `dagitim` `daire_basina` DISINDA ise ZORUNLU: dagitilacak TOPLAM.
    toplam_tutar_kurus: int | None = Field(None, ge=1)

    @model_validator(mode="after")
    def _dagitim_tutari(self) -> "TopluBorcIstek":
        if self.dagitim != "daire_basina" and self.toplam_tutar_kurus is None:
            raise ValueError("dagitim icin toplam_tutar_kurus gerekli")
        return self


class TopluBorcSatir(BaseModel):
    unit_id: uuid.UUID
    unit_no: str
    tutar_kurus: int | None = None
    hedef_user_id: uuid.UUID | None = None
    hedef_ad: str | None = None
    #: Bu satir neden ATLANACAK (None ise islenecek).
    atlama_nedeni: str | None = None


class TopluBorcOnizleme(BaseModel):
    """Onizleme: NE OLACAGINI gosterir, HICBIR SEY YAZMAZ.

    `atlanacak` ayri sayilir cunku "500 daireden 3'u tipsiz" bilgisi
    islemeden ONCE gorulmelidir — sonra fark edilirse eksik tahakkuk
    sessizce yayilir.
    """

    satirlar: list[TopluBorcSatir]
    islenecek: int
    atlanacak: int
    toplam_kurus: int


class SayacBorcIstek(BaseModel):
    """Sayac ile borclandirma sihirbazinin SON adimi (4/4).

    Adimlar: dagitim sekli -> ana sayac -> tuketim degerleri -> borclandirma.
    Ilk uc adim istemcide toplanir; sunucuya TEK istek gelir — ara adimlarda
    sunucu durumu tutmak, yarim kalmis sihirbazlari temizlemek zorunda
    birakirdi.
    """

    donem: str = Field(..., min_length=1, max_length=7)
    gelir_gider_tanim_id: uuid.UUID
    ana_sayac_id: uuid.UUID
    #: Ana sayacin DONEM TUKETIMI (birim).
    ana_tuketim: float = Field(..., ge=0)
    #: Birim fiyat, KURUS (orn. 1 m3 su = 3550 kurus).
    birim_fiyat_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)
    #: daire sayac id -> donem tuketimi.
    bolum_tuketimleri: dict[uuid.UUID, float]
    son_odeme_tarihi: date | None = None
    tarih: date | None = None
    aciklama: str | None = Field(None, max_length=500)


class BorcIceAktarimSatir(BaseModel):
    """Excel/CSV ice aktarim SATIRI — hatali satirlar tek tek raporlanir."""

    satir_no: int
    unit_no: str
    tutar_kurus: int | None = None
    aciklama: str | None = None


class BorcIceAktarimIstek(BaseModel):
    donem: str = Field(..., min_length=1, max_length=7)
    gelir_gider_tanim_id: uuid.UUID
    satirlar: list[BorcIceAktarimSatir]
    son_odeme_tarihi: date | None = None
    tarih: date | None = None


class BorcIceAktarimHata(BaseModel):
    satir_no: int
    unit_no: str | None = None
    #: Katalog KIMLIGI degil, cozulmus METIN (satir basina, istegin dilinde).
    hata: str


class BorcIceAktarimSonuc(BaseModel):
    """Satir-bazli hata raporu.

    BOZUK SATIR TUM ICE AKTARIMI DUSURMEZ: 400 satirlik bir dosyada 3 hatali
    satir yuzunden 397 dogru satiri reddetmek, kullaniciyi dosyayi elle
    ayiklamaya zorlardi.
    """

    olusturulan: int
    atlanan: int
    hatalar: list[BorcIceAktarimHata]


class GecikmeAyarOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    gecikme_aylik_yuzde: float
    #: (P192 §3.1) Site gecikme faizi UYGULUYOR MU. Orani 0 yapmak "hic
    #: uygulama" demenin dolayli yoluydu ama "oran henuz girilmedi" ile
    #: ayni gorunurdu.
    gecikme_uygula: bool = True


class GecikmeAyarUpdate(BaseModel):
    gecikme_aylik_yuzde: float | None = Field(None, ge=0, le=100)
    gecikme_uygula: bool | None = None

    @model_validator(mode="after")
    def _en_az_bir(self) -> "GecikmeAyarUpdate":
        if self.gecikme_aylik_yuzde is None and self.gecikme_uygula is None:
            raise ValueError("en az bir alan gerekli")
        return self


class GecikmeFaizSatiri(BaseModel):
    """(P192 §3.1) Bir borc icin faiz durumu."""

    assessment_id: uuid.UUID
    unit_id: uuid.UUID
    unit_no: str
    donem: str
    son_odeme_tarihi: date | None = None
    kalan_kurus: int
    #: O ana kadar BIRIKMIS toplam faiz.
    toplam_faiz_kurus: int
    #: Daha once yazilmis faiz kalemleri.
    yazilmis_kurus: int
    #: Bu kosumda YAZILACAK tutar (toplam - yazilmis).
    fark_kurus: int


class GecikmeFaizOnizleme(BaseModel):
    donem: str
    uygulaniyor: bool
    aylik_yuzde: float
    toplam_fark_kurus: int
    items: list[GecikmeFaizSatiri]


class GecikmeFaizSonuc(BaseModel):
    donem: str
    yazilan: int
    toplam_kurus: int
    #: Faiz uygulanmiyorsa ya da fark yoksa BOS doner ve `yazilan=0` olur —
    #: sessiz basari degil, ACIK bir "hicbir sey yapilmadi".
    items: list[GecikmeFaizSatiri]


class TahakkukTersKayitIstek(BaseModel):
    """(P192 §6.3) Yanlis tahakkukun DUZELTILMESI."""

    aciklama: str | None = Field(None, max_length=500)



class MakbuzOut(BaseModel):
    """(P192 §4.4) Sakinin makbuz arsivi satiri.

    `pdf_url` KISA OMURLUDUR (presign) ve saklanmaz: kalici bir baglanti,
    kimlik dogrulamasi olmadan erisilebilen bir mali belge demekti.
    """

    id: uuid.UUID
    belge_no: str
    tutar_kurus: int
    unit_id: uuid.UUID | None = None
    created_at: datetime
    pdf_url: str | None = None


class MakbuzListResponse(BaseModel):
    meta: PageMetaOut
    items: list[MakbuzOut]



# ============== (P192 §5) YONETICININ GORMESI GEREKENLER ==================== #
class YaslandirmaDaire(BaseModel):
    unit_id: uuid.UUID
    unit_no: str
    #: Dairenin EN ESKI acik borcunun gecikme gunu — kovasi budur.
    en_eski_gun: int
    kova: str
    kalan_kurus: int
    borclu_ad: str | None = None
    borclu_user_id: uuid.UUID | None = None


class YaslandirmaKovasi(BaseModel):
    kova: str
    daire: int
    kalan_kurus: int
    #: Tiklaninca listelenecek daireler. `ozet=true` ile BOS doner —
    #: kart yalnizca sayilari cizerken yuzlerce satir tasimasin.
    daireler: list[YaslandirmaDaire] = []


class YaslandirmaResponse(BaseModel):
    kovalar: list[YaslandirmaKovasi]
    toplam_kalan_kurus: int
    toplam_daire: int


class TahsilatGostergesi(BaseModel):
    """(P192 §5.2) Bu ay ne kadari tahsil edildi, gecen aya gore nasil.

    TEK KAYNAK: `defter.tahsilat_toplami` (P192 §1). Ayni metrik iki
    ekranda iki farkli rakam veriyordu; artik veremez.
    """

    donem: str
    tahakkuk_kurus: int
    tahsilat_kurus: int
    oran_yuzde: int | None = None
    onceki_donem: str
    onceki_oran_yuzde: int | None = None
    #: Puan farki (yuzde puani). `None` = onceki ayda tahakkuk yok.
    degisim_puan: int | None = None


class HatirlatmaGecmisiSatiri(BaseModel):
    """(P192 §4.2) "Kac hatirlatma gitti, kim acti" — gorunur iz.

    OKUNDU BILGISI ALICIYA AITTIR: her alici icin ayri `notification`
    satiri yazilir (bkz. `sakin_bildirimi_yaz`), yoksa bir kullanicinin
    okumasi otekininkini de "okundu" yapardi.
    """

    id: uuid.UUID
    user_id: uuid.UUID | None = None
    ad: str | None = None
    gonderim_zamani: datetime
    okundu: bool
    tutar: str | None = None


class HatirlatmaGecmisi(BaseModel):
    meta: PageMetaOut
    gonderilen: int
    okunan: int
    items: list[HatirlatmaGecmisiSatiri]


class BorcluTopluIstek(BaseModel):
    """Secilen borclulara toplu islem.

    `unit_ids` BOS BIRAKILAMAZ: "hepsi" anlamina gelen bos bir liste,
    yanlislikla butun siteye islem yapmayi bir tikla mumkun kilardi.
    """

    unit_ids: list[uuid.UUID] = Field(..., min_length=1, max_length=500)


class TopluHatirlatmaSonuc(BaseModel):
    gonderilen: int
    #: Borcu KAPANMIS olduğu icin atlanan daireler.
    atlanan: int


class TopluFaizAffiSonuc(BaseModel):
    affedilen_kalem: int
    toplam_kurus: int


class OdemePlaniIstek(BorcluTopluIstek):
    """Vade YAPILANDIRMASI — yeni borc URETMEZ.

    Acik borclarin `son_odeme_tarihi` degerleri `taksit_sayisi` aya
    yayilir. Yeni tahakkuk yazmak, ayni borcu iki kez gostermek
    olurdu (eskisi ters kayitlanmadikca) ve ters kayitlamak da odenmis
    kismi karsiliksiz birakirdi.
    """

    taksit_sayisi: int = Field(..., ge=2, le=36)
    ilk_vade: date


class OdemePlaniSonuc(BaseModel):
    daire: int
    guncellenen_borc: int


class ButceHedefiCreate(BaseModel):
    yil: int = Field(..., ge=2000, le=2100)
    #: NULL = YILLIK hedef; dolu ('YYYY-MM') = o ayin hedefi.
    donem: str | None = Field(None, min_length=7, max_length=7)
    kategori_id: uuid.UUID
    tutar_kurus: int = Field(..., ge=0, le=KURUS_UST_SINIR)
    aciklama: str | None = Field(None, max_length=500)


class ButceHedefiOut(ButceHedefiCreate):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    created_at: datetime


class ButceHedefiListResponse(BaseModel):
    items: list[ButceHedefiOut]


class ButceKarsilastirmaSatiri(BaseModel):
    kategori_id: uuid.UUID | None = None
    ad: str
    tip: str
    hedef_kurus: int
    gerceklesen_kurus: int
    #: gerceklesen - hedef. GIDERDE POZITIF = butce asildi; GELIRDE
    #: POZITIF = hedefin uzerinde gelir. Isaretin anlami TIPE baglidir ve
    #: bunu istemciye birakmak, iki ekranda iki yorum demekti.
    sapma_kurus: int
    sapma_yuzde: int | None = None


class ButceKarsilastirma(BaseModel):
    donem: str | None = None
    yil: int
    items: list[ButceKarsilastirmaSatiri]
    hedef_gelir_kurus: int
    hedef_gider_kurus: int
    gerceklesen_gelir_kurus: int
    gerceklesen_gider_kurus: int


# ==================== (P192 §4) FINANS OTOMASYONU =========================== #
# Dort kayit: aidat plani, hatirlatma ayari, duzenli gider, otomasyon
# gunlugu. Ortak ilke: her otomasyon ACILIP KAPATILABILIR ve IZ BIRAKIR.
GiderPeriyot = Literal["aylik", "uc_aylik", "alti_aylik", "yillik"]
OtomasyonTuru = Literal[
    "aidat_tahakkuk", "aidat_onizleme", "borc_hatirlatma",
    "duzenli_gider", "gecikme_faizi", "aylik_ozet",
]


class AidatPlaniBase(BaseModel):
    ad: str = Field(..., min_length=1, max_length=100)
    #: ZORUNLU: dagitim hedefi ve borcun KIME yazilacagi (kiraci/malik)
    #: tanimdan gelir. Tanimsiz bir plan hedefi cozemezdi.
    gelir_gider_tanim_id: uuid.UUID
    kalem_tipi: Literal[
        "aidat", "demirbas", "olaganustu", "sayac", "diger"
    ] = "aidat"
    dagitim: Literal["daire_basina", "esit", "arsa_payi", "metrekare"] = "daire_basina"
    tutar_kurus: int | None = Field(None, ge=1)
    toplam_tutar_kurus: int | None = Field(None, ge=1)
    #: 1..28 — 29/30/31 her ayda YOKTUR ve "ayin 31'i" kurali Subat'ta
    #: sessizce hic calismazdi.
    tahakkuk_gunu: int = Field(1, ge=1, le=28)
    vade_gun: int = Field(15, ge=0, le=90)
    onizleme_gun: int = Field(3, ge=0, le=28)
    aktif: bool = True
    aciklama: str | None = Field(None, max_length=500)

    @model_validator(mode="after")
    def _tutar_dagitima_uysun(self) -> "AidatPlaniBase":
        if self.dagitim == "daire_basina" and self.tutar_kurus is None:
            raise ValueError("daire_basina dagitim icin tutar_kurus gerekli")
        if self.dagitim != "daire_basina" and self.toplam_tutar_kurus is None:
            raise ValueError("bu dagitim icin toplam_tutar_kurus gerekli")
        return self


class AidatPlaniCreate(AidatPlaniBase):
    pass


class AidatPlaniUpdate(BaseModel):
    """Kismi guncelleme. Tutar/dagitim tutarliligi SUNUCUDA yeniden
    dogrulanir (CHECK kisiti da ayni kurali zorluyor)."""

    ad: str | None = Field(None, min_length=1, max_length=100)
    kalem_tipi: Literal[
        "aidat", "demirbas", "olaganustu", "sayac", "diger"
    ] | None = None
    dagitim: Literal[
        "daire_basina", "esit", "arsa_payi", "metrekare"
    ] | None = None
    tutar_kurus: int | None = Field(None, ge=1)
    toplam_tutar_kurus: int | None = Field(None, ge=1)
    tahakkuk_gunu: int | None = Field(None, ge=1, le=28)
    vade_gun: int | None = Field(None, ge=0, le=90)
    onizleme_gun: int | None = Field(None, ge=0, le=28)
    aktif: bool | None = None
    aciklama: str | None = Field(None, max_length=500)


class AidatPlaniErtele(BaseModel):
    """Bir donemi ATLA. Plani pasife almak gelecek aylari da kapatirdi."""

    donem: str = Field(..., min_length=7, max_length=7)


class AidatPlaniOut(AidatPlaniBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    #: Islenen SON donem — idempotency damgasi. Gorev gunde on kez kossa
    #: da ayni donemi ikinci kez islemez.
    son_donem: str | None = None
    onizleme_donem: str | None = None
    ertelenen_donem: str | None = None
    created_at: datetime


class AidatPlaniListResponse(BaseModel):
    items: list[AidatPlaniOut]


class HatirlatmaAyariOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    aktif: bool = False
    vade_oncesi_gun: int = 3
    #: Vade GECTIKTEN sonra kac gun sonra hatirlatilacagi (kademeler).
    kademeler: list[int] = []
    metin: str | None = None
    son_calisma: date | None = None


class HatirlatmaAyariUpdate(BaseModel):
    aktif: bool | None = None
    vade_oncesi_gun: int | None = Field(None, ge=0, le=30)
    kademeler: list[int] | None = Field(None, max_length=6)
    metin: str | None = Field(None, max_length=1000)

    @field_validator("kademeler")
    @classmethod
    def _kademe_araligi(cls, v: list[int] | None) -> list[int] | None:
        if v is None:
            return v
        for gun in v:
            if gun < 0 or gun > 365:
                raise ValueError("kademe gunu 0-365 araliginda olmali")
        # Siralanmis ve TEKIL: ayni gune iki kademe koymak, sakine ayni
        # gun iki hatirlatma gonderme riski demekti.
        return sorted(set(v))


class DuzenliGiderBase(BaseModel):
    ad: str = Field(..., min_length=1, max_length=100)
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)
    periyot: GiderPeriyot = "aylik"
    sonraki_tarih: date
    kasa_id: uuid.UUID | None = None
    firma_id: uuid.UUID | None = None
    gelir_gider_tanim_id: uuid.UUID | None = None
    #: VARSAYILAN false: vadesi gelen gider ONAY BEKLEYEN yazilir.
    otomatik_onay: bool = False
    aktif: bool = True
    aciklama: str | None = Field(None, max_length=500)


class DuzenliGiderCreate(DuzenliGiderBase):
    pass


class DuzenliGiderUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=100)
    tutar_kurus: int | None = Field(None, ge=1)
    periyot: GiderPeriyot | None = None
    sonraki_tarih: date | None = None
    kasa_id: uuid.UUID | None = None
    firma_id: uuid.UUID | None = None
    gelir_gider_tanim_id: uuid.UUID | None = None
    otomatik_onay: bool | None = None
    aktif: bool | None = None
    aciklama: str | None = Field(None, max_length=500)


class DuzenliGiderOut(DuzenliGiderBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    created_at: datetime


class DuzenliGiderListResponse(BaseModel):
    items: list[DuzenliGiderOut]


class OtomasyonGunlukOut(BaseModel):
    """Otomasyonun NE ZAMAN NE YAPTIGI — kullaniciya gorunur iz."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tur: str
    calisma_zamani: datetime
    donem: str | None = None
    adet: int
    tutar_kurus: int
    sonuc: dict = {}


class OtomasyonGunlukListResponse(BaseModel):
    meta: PageMetaOut
    items: list[OtomasyonGunlukOut]


# ==================== P29 FINANSAL HAREKET / TAHSILAT ======================= #
# TEK DEFTER: tahsilat, gider, gelir, virman, iade, acilis ayni kayitta `tip`
# ile ayrilir. TUTAR HER ZAMAN POZITIF; isaret `yon`dadir.
HareketTip = Literal["tahsilat", "gider", "gelir", "virman", "iade", "acilis"]
HareketYon = Literal["giris", "cikis"]
#: (P168 §2) Brief: Baginiz · Beklemede · Avukatta · Mahkeme Surecinde · Kapandi
IcraDurum = Literal["baginiz", "beklemede", "avukatta", "mahkemede", "kapandi"]


class HareketOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tip: str
    yon: str
    tutar_kurus: int
    tarih: date
    kasa_id: uuid.UUID | None = None
    kasa_ad: str | None = None
    user_id: uuid.UUID | None = None
    user_ad: str | None = None
    unit_id: uuid.UUID | None = None
    firma_id: uuid.UUID | None = None
    gelir_gider_tanim_id: uuid.UUID | None = None
    assessment_id: uuid.UUID | None = None
    belge_no: str | None = None
    aciklama: str | None = None
    virman_grup_id: uuid.UUID | None = None
    iade_edilen_id: uuid.UUID | None = None
    #: (P167 Asama 2) `odendi` / `bekliyor` / `onay_bekliyor`.
    durum: str = "odendi"
    created_at: datetime


class HareketListResponse(BaseModel):
    meta: PageMetaOut
    items: list[HareketOut]


class TahsilatCreate(BaseModel):
    """Tekil tahsilat. `assessment_id` verilirse o borca sayilir."""

    user_id: uuid.UUID | None = None
    unit_id: uuid.UUID | None = None
    assessment_id: uuid.UUID | None = None
    kasa_id: uuid.UUID
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)
    tarih: date | None = None
    belge_no: str | None = Field(None, max_length=50)
    aciklama: str | None = Field(None, max_length=500)
    #: (P192 §1) MUHASEBE DONEMI. Verilmezse `assessment_id`den turer.
    #: Vezneden girilen tahsilatin donemi bilinmezse "bu ayin tahsilat
    #: orani" hesabina giremezdi.
    donem: str | None = Field(None, min_length=1, max_length=7)
    #: Paranin nasil alindigi. Vezne varsayilani elden.
    yontem: DuesYontem | None = None


class TopluTahsilatSatir(BaseModel):
    user_id: uuid.UUID | None = None
    unit_id: uuid.UUID | None = None
    assessment_id: uuid.UUID | None = None
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)
    aciklama: str | None = None
    donem: str | None = Field(None, min_length=1, max_length=7)


class TopluTahsilatIstek(BaseModel):
    """Cok satirli tahsilat — "Yeni Satır" akisinin sunucu karsiligi."""

    kasa_id: uuid.UUID
    tarih: date | None = None
    satirlar: list[TopluTahsilatSatir] = Field(..., min_length=1, max_length=500)


class HareketSatir(BaseModel):
    """Gider/gelir hareketi satiri (cok satirli giris)."""

    tip: Literal["gider", "gelir"]
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)
    kasa_id: uuid.UUID
    firma_id: uuid.UUID | None = None
    gelir_gider_tanim_id: uuid.UUID | None = None
    tarih: date | None = None
    belge_no: str | None = Field(None, max_length=50)
    aciklama: str | None = Field(None, max_length=500)
    #: (P167 Asama 2, goc 0056) GERCEKLESME DURUMU. Varsayilan `odendi`
    #: cunku bugune kadar yazilan her satir gerceklesmis bir hareketti;
    #: baska bir varsayilan, mevcut istemcilerin ANLAMINI degistirirdi.
    durum: Literal["odendi", "bekliyor", "onay_bekliyor"] = "odendi"


class HareketToplu(BaseModel):
    satirlar: list[HareketSatir] = Field(..., min_length=1, max_length=200)


class VirmanIstek(BaseModel):
    """Hesaplar arasi virman — IKI SATIR uretir (cikis + giris)."""

    kaynak_kasa_id: uuid.UUID
    hedef_kasa_id: uuid.UUID
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)
    tarih: date | None = None
    aciklama: str | None = Field(None, max_length=500)

    @model_validator(mode="after")
    def _ayni_kasa_olmaz(self) -> "VirmanIstek":
        # Ayni kasaya virman, bakiyeyi degistirmeyen ama defteri sisiren
        # anlamsiz iki satir uretirdi.
        if self.kaynak_kasa_id == self.hedef_kasa_id:
            raise ValueError("kaynak ve hedef kasa ayni olamaz")
        return self


class IptalIstek(BaseModel):
    """(P154 / Asama 10) Bir hareketi TERS KAYITLA iptal eder.

    TUTAR ALINMAZ: kismi iptal diye bir sey yoktur. Kismen geri odenen
    para IADEDIR (`/finans/iade`) ve o uc kismi tutari zaten destekler.
    Iptal, "bu kayit yanlis girildi" demektir ve yarim yanlis olmaz.
    """

    aciklama: str | None = Field(None, max_length=500)
    tarih: date | None = None
    model_config = ConfigDict(extra="forbid")


class IadeIstek(BaseModel):
    """Odeme iadesi — IADE ETTIGI hareketi gosterir."""

    hareket_id: uuid.UUID
    tutar_kurus: int | None = Field(None, ge=1)
    tarih: date | None = None
    aciklama: str | None = Field(None, max_length=500)


class AcilisFisi(BaseModel):
    """Acilis fisi: kisi ya da kasa baslangic bakiyesi."""

    kasa_id: uuid.UUID
    user_id: uuid.UUID | None = None
    yon: HareketYon
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)
    tarih: date | None = None
    aciklama: str | None = Field(None, max_length=500)


class HareketOnayIstek(BaseModel):
    """(P192 §2.3) Harcama onayi/reddi.

    `aciklama` REDDE anlamlidir ("neden reddedildi") ama onayda da
    serbesttir; ayri iki sema yazmak, ayni akisi iki yerde tanimlamak
    olurdu.
    """

    aciklama: str | None = Field(None, max_length=500)


class KasaBakiye(BaseModel):
    kasa_id: uuid.UUID
    kod: str
    ad: str
    acilis_bakiye_kurus: int
    hareket_kurus: int
    bakiye_kurus: int
    #: (P192 §2.1) Kasa mi banka hesabi mi. Ayrim GORUNUR olmali: "kasada
    #: 50.000 var" ile "bankada 50.000 var" ayni sey degildir.
    banka_mi: bool = False
    iban: str | None = None
    #: (P192 §2.2) HENUZ GERCEKLESMEMIS hareketler. Bakiyeye DAHIL DEGIL:
    #: onay bekleyen bir gider bakiyeyi simdiden dusuruyordu ve yonetici
    #: elinde olmayan bir parayi yokmus gibi goruyordu.
    bekleyen_cikis_kurus: int = 0
    bekleyen_giris_kurus: int = 0


class KasaBakiyeResponse(BaseModel):
    items: list[KasaBakiye]
    genel_toplam_kurus: int
    #: Tum kasalarin bekleyen cikisi — "bakiye X, bekleyen Y" gosterimi.
    bekleyen_cikis_toplam_kurus: int = 0


class BankaSatirIn(BaseModel):
    satir_no: int
    aciklama: str = Field(..., max_length=500)
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)


class BankaEslestirIstek(BaseModel):
    satirlar: list[BankaSatirIn] = Field(..., min_length=1, max_length=500)


class BankaEslestirOneri(BaseModel):
    satir_no: int
    user_id: uuid.UUID | None = None
    user_ad: str | None = None
    assessment_id: uuid.UUID | None = None
    guven: int
    neden: str


class BankaEslestirSonuc(BaseModel):
    oneriler: list[BankaEslestirOneri]


class IcraDosyasiCreate(BaseModel):
    dosya_no: str = Field(..., min_length=1, max_length=50)
    user_id: uuid.UUID
    veris_tarihi: date | None = None
    avukat: str | None = Field(None, max_length=150)
    durum: IcraDurum = "beklemede"
    aciklama: str | None = Field(None, max_length=1000)


class IcraDosyasiUpdate(BaseModel):
    dosya_no: str | None = Field(None, min_length=1, max_length=50)
    veris_tarihi: date | None = None
    avukat: str | None = Field(None, max_length=150)
    durum: IcraDurum | None = None
    aciklama: str | None = Field(None, max_length=1000)

    @model_validator(mode="after")
    def _at_least_one(self) -> "IcraDosyasiUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class IcraDosyasiOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    dosya_no: str
    user_id: uuid.UUID
    user_ad: str | None = None
    veris_tarihi: date | None = None
    avukat: str | None = None
    durum: str
    aciklama: str | None = None
    #: Kisinin ACIK borc toplami — dosya kaydina KOPYALANMAZ, anlik okunur.
    acik_borc_kurus: int = 0
    created_at: datetime
    updated_at: datetime | None = None


class IcraDosyasiListResponse(BaseModel):
    meta: PageMetaOut
    items: list[IcraDosyasiOut]


class FinansOzet(BaseModel):
    """Panel ozet kartlari (P29 · P167 Asama 2).

    (P167 §2.2) UC ALAN EKLENDI. Brief'in alti kartindan dordu zaten
    hesaplanabiliyordu; "Borclarim", "Onay Bekleyen Hareketler" ve
    "Odenmis Faturalar" icin uc yeni toplam gerekti.

    HEPSI DEFTERDEN OKUNUR, hicbiri saklanmaz — kartlarin bir gun defterle
    celismesi ancak SAKLANAN bir ozetle mumkun olurdu.
    """

    borclandirilan_ay_kurus: int
    tahsil_edilen_ay_kurus: int
    #: Sakinlerin siteye BORCU (alacaklarimiz).
    acik_borc_kurus: int
    kasa_toplam_kurus: int
    icra_acik_dosya: int
    #: (P167 §2.2) "BORCLARIM" — sitenin firmalara odenmemis gideri.
    #: `acik_borc_kurus`un AYNASI degil TERSI: o sakinin bize borcu, bu
    #: bizim disariya borcumuz. Ikisini tek kartta toplamak, kimin kime
    #: borclu oldugunu okunamaz kilardi.
    borc_kurus: int = 0
    #: (P167 §2.2) Onay bekleyen hareket ADEDI — tutar degil. Yonetici
    #: burada "ne kadar" degil "kac tane is bekliyor" sorusunu soruyor;
    #: tutar, tiklayinca acilan listede.
    onay_bekleyen_adet: int = 0
    #: (P167 §2.2) Bu ay ODENMIS gider toplami ("Odenmis Faturalar").
    odenmis_fatura_ay_kurus: int = 0


# ================== (P167 Asama 2) OZET SAYFASI ============================= #
#
# Uc kavram, uc ayri sebep:
#   * PANO TERCIHI — kullanicinin kendi ekran duzeni
#   * HATIRLATMA   — kullanicinin kendi takvim notu
#   * TAKVIM       — alti kaynagin BIRLESIK okumasi


class PanoWidget(BaseModel):
    """Widget seridindeki tek kisayol.

    ROTA SAKLANIR, "widget tipi" DEGIL: kisayol zaten menudeki bir sayfaya
    gidiyor. Ayri bir tip listesi acmak, menuye eklenen her sayfayi
    ikinci bir yerde daha tanimlamak ve ikisi ayrisinca "widget yapilamayan
    sayfa" uretmek olurdu.
    """

    #: Menu ogesinin baglantisi (`/dues`, `/finans?tip=gelir`...).
    rota: str = Field(..., min_length=1, max_length=200)


class PanoBolum(BaseModel):
    """Ozet sayfasindaki bir bolumun sira/gorunurluk kaydi."""

    #: Bolum kimligi (`widgetlar`, `finans`, `takvim`, `maket`, `alarmlar`).
    id: str = Field(..., min_length=1, max_length=40)
    gizli: bool = False


class PanoSatir(BaseModel):
    """(P181 7.1/7.2) Duzenlenebilir yerlesimde BIR SATIR.

    `sutun` (1-4) o satirin kac esit hucreye bolunecegini; `idler` satirdaki
    bolumleri; `baslik` (7.2) opsiyonel banner metnini tutar. `satirlar`
    verildiginde yerlesim ondan kurulur; yoksa eski tam/yarim eslesme calisir
    (geriye donuk uyumlu).
    """

    sutun: int = Field(1, ge=1, le=4)
    idler: list[str] = Field(default_factory=list, max_length=8)
    baslik: str | None = Field(None, max_length=60)


class PanoTercihi(BaseModel):
    """(P167 §2.1/§2.5) Kullanicinin Ozet sayfasi duzeni.

    JSONB'de duruyor ama SEMASIZ DEGIL: uc bu modelle dogrular ve
    tanimadigi anahtari ATAR. Serbest JSON, arayuz degistiginde
    veritabaninda hangi seklin durdugunu bilinemez kilardi.

    BOS NESNE = "varsayilani kullan". Istemci varsayilani kendi kurar
    (rolde gorunen ilk alti sayfa); sunucuya yazmak, kullanici HIC
    dokunmadan bir tercih kaydi uretmek olurdu ve varsayilan degistiginde
    o kullanicilar eski varsayilanda kilitli kalirdi.
    """

    model_config = ConfigDict(extra="ignore")

    #: En fazla ALTI widget — brief'in sayisi. Sinir sunucuda cunku
    #: istemci sinirini asan bir istek, seridi tasan bir pano uretirdi.
    widgetlar: list[PanoWidget] | None = Field(None, max_length=6)
    bolumler: list[PanoBolum] | None = Field(None, max_length=20)
    #: (P181 7.1/7.2) Satır bazlı yerleşim: her satır 1-4 sütun + opsiyonel
    #: banner. Verilmezse eski tam/yarım eşleşme kullanılır.
    satirlar: list[PanoSatir] | None = Field(None, max_length=20)


HATIRLATMA_TEKRARLARI = ("yok", "gunluk", "haftalik", "aylik")


class HatirlatmaBase(BaseModel):
    baslik: str = Field(..., min_length=1, max_length=200)
    aciklama: str | None = Field(None, max_length=2000)
    baslangic: datetime
    bitis: datetime | None = None
    renk: str = Field("mavi", min_length=1, max_length=20)
    tekrar: Literal["yok", "gunluk", "haftalik", "aylik"] = "yok"

    @field_validator("baslik")
    @classmethod
    def _baslik_bosluk(cls, v: str) -> str:
        temiz = v.strip()
        if not temiz:
            raise ValueError("hatirlatma_baslik_bos")
        return temiz

    @model_validator(mode="after")
    def _aralik(self) -> "HatirlatmaBase":
        # Ters aralik VERITABANINDA da kisitli (goc 0056). Burada da
        # denetleniyor cunku 422 + alan adi, 500 + kisit adindan cok daha
        # anlasilir bir cevaptir.
        if self.bitis is not None and self.bitis < self.baslangic:
            raise ValueError("hatirlatma_ters_aralik")
        return self


class HatirlatmaCreate(HatirlatmaBase):
    pass


class HatirlatmaUpdate(BaseModel):
    """KISMI guncelleme — gonderilmeyen alan DEGISMEZ."""

    baslik: str | None = Field(None, min_length=1, max_length=200)
    aciklama: str | None = Field(None, max_length=2000)
    baslangic: datetime | None = None
    bitis: datetime | None = None
    renk: str | None = Field(None, min_length=1, max_length=20)
    tekrar: Literal["yok", "gunluk", "haftalik", "aylik"] | None = None

    @model_validator(mode="after")
    def _en_az_bir(self) -> "HatirlatmaUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class HatirlatmaOut(HatirlatmaBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    created_at: datetime


class TakvimOgesi(BaseModel):
    """(P167 §2.3) Takvimde cizilen TEK bir olay.

    ALTI KAYNAK TEK SEKILDE: etkinlik, devriye penceresi, aidat son odeme,
    gorev teslim, rezervasyon, hatirlatma. Her biri kendi tablosunda baska
    alan adlari tasiyor; takvim onlari BURADA tek dile cevirir — aksi
    hâlde cizim kodu alti farkli sekli bilmek zorunda kalirdi.
    """

    #: Kaynak tipi — renk ve ikon bundan secilir.
    tip: Literal[
        "etkinlik", "devriye", "aidat", "gorev", "rezervasyon", "hatirlatma"
    ]
    #: Kaynak kaydin kimligi. TEKRAR EDEN hatirlatmada AYNI id birden fazla
    #: satirda gorunur (kural genisletiliyor, kayit cogaltilmiyor).
    id: uuid.UUID
    baslik: str
    baslangic: datetime
    bitis: datetime | None = None
    #: Tiklaninca gidilecek panel rotasi. Sunucu veriyor cunku hangi
    #: kaydin hangi ekranda acildigini uc zaten biliyor; istemcide bir
    #: `tip -> rota` tablosu tutmak ikinci bir dogruluk kaynagi olurdu.
    hedef: str | None = None
    #: Yalniz `hatirlatma` icin dolu — kullanicinin sectigi renk.
    renk: str | None = None


class TakvimResponse(BaseModel):
    items: list[TakvimOgesi]


# ======================= P30 SAKIN ODEME AKISI ============================== #
class OdemeBilgileri(BaseModel):
    """Sakinin "Öde" ekrani icin gereken HER SEY tek yanitta.

    Iki cagri yapmak (IBAN ayri, kod ayri) ekrani iki yukleme durumuna
    bolerdi; bu ekranin tek isi "nereye, ne kadar, hangi kodla" demektir.
    """

    #: Site'nin anlasmali banka kasasinin IBAN'i. Tanimli banka kasasi yoksa
    #: `null` — istemci havale secenegini GIZLER (yanlis IBAN gostermektense
    #: hic gostermemek dogru).
    iban: str | None = None
    banka_adi: str | None = None
    #: Havale aciklamasina yazilacak BENZERSIZ kod.
    odeme_kodu: str
    #: Odenmemis toplam (kurus) — ekranda onerilen tutar.
    borc_kurus: int
    #: Kart odemesi acik mi (saglayici yapilandirilmis mi).
    kart_aktif: bool


class KartOdemeBaslat(BaseModel):
    tutar_kurus: int = Field(..., ge=1, le=KURUS_UST_SINIR)


class KartOdemeSonuc(BaseModel):
    """Saglayici soyutlamasinin dondurdugu sonuc.

    `odeme_url` doluysa istemci 3D akisina yonlendirir; `durum` `basarili`
    ise (sahte saglayici) tahsilat ANINDA yazilmistir.
    """

    durum: str
    odeme_url: str | None = None
    hareket_id: uuid.UUID | None = None


# ============================ P31 RAPOR MOTORU ============================== #
class RaporParametre(BaseModel):
    """Parametre modali — TEK MODEL, her rapor alt kumesini kullanir.

    Rapor basina ayri model, modal bileseninin her rapor icin yeniden
    yazilmasi olurdu.
    """

    baslangic: date | None = None
    bitis: date | None = None
    #: Gecikme tazminatinin HANGI TARIHE gore hesaplanacagi (ayri alan:
    #: donem raporunu BUGUNUN tazminatiyla almak isteyen yonetim var).
    tazminat_tarihi: date | None = None
    blok: str | None = None
    gelir_gider_tanim_id: uuid.UUID | None = None
    listeleme_tipi: str | None = Field(None, max_length=30)
    min_tutar_kurus: int | None = None
    max_tutar_kurus: int | None = None
    siralama: str | None = Field(None, max_length=30)
    #: KVKK: kapiya asilacak listede ad OLMAMALI.
    ismi_goster: bool = True
    icradakileri_goster: bool = True

    # ---- (P167 Asama 5) brief §5'in alan listesinden gelen EKLER --------
    # Hepsi OPSIYONEL; varsayilanlar bugunku davranisi korur.
    kasa_id: uuid.UUID | None = None
    firma_id: uuid.UUID | None = None
    user_id: uuid.UUID | None = None
    unit_id: uuid.UUID | None = None
    olusturan_user_id: uuid.UUID | None = None
    bolum: str | None = Field(None, max_length=40)
    ekstre_turu: str | None = Field(None, max_length=20)
    evrak_tipi: str | None = Field(None, max_length=20)
    calisma_sekli: str | None = Field(None, max_length=20)
    #: BRIEF "bes ayri alan" diyor — o MODAL YERLESIMI. Veri bir LISTE:
    #: bes ayri alan adi, altincisi istendiginde sozlesme degistirirdi.
    gelir_gider_tanim_idler: list[uuid.UUID] = Field(default_factory=list, max_length=5)
    baslangic_ay: int | None = Field(None, ge=1, le=12)
    baslangic_yil: int | None = Field(None, ge=2000, le=2200)
    bitis_ay: int | None = Field(None, ge=1, le=12)
    bitis_yil: int | None = Field(None, ge=2000, le=2200)
    imza: bool = False
    aciklamalari_goster: bool = True
    evrak_bilgisi_goster: bool = True
    grup_goster: bool = False
    #: (P168 §3) Site Sakinleri Listesi'nde "Iletisim Bilgileri goster".
    #: VARSAYILAN KAPALI: telefon ve e-posta kisisel veridir; kapiya
    #: asilacak ya da toplantida dagitilacak bir listede varsayilan
    #: olarak BULUNMAMALI (amac sinirliligi). Isteyen acar.
    iletisim_goster: bool = False

    @model_validator(mode="after")
    def _aralik_tutarli(self) -> "RaporParametre":
        if self.baslangic and self.bitis and self.bitis < self.baslangic:
            raise ValueError("bitis tarihi baslangictan once olamaz")
        if (
            self.min_tutar_kurus is not None
            and self.max_tutar_kurus is not None
            and self.max_tutar_kurus < self.min_tutar_kurus
        ):
            raise ValueError("maks tutar minden kucuk olamaz")
        return self

    def model_dump(self, **kw):  # type: ignore[override]
        veri = super().model_dump(**kw)
        # Cekirdek saf Python calisir: UUID'yi metne cevir.
        if veri.get("gelir_gider_tanim_id") is not None:
            veri["gelir_gider_tanim_id"] = str(veri["gelir_gider_tanim_id"])
        return veri


class RaporSutun(BaseModel):
    anahtar: str
    baslik: str
    tip: str = "metin"


class RaporTablo(BaseModel):
    """"Göster" ciktisi — Excel/PDF ile AYNI satirlardan uretilir."""

    kod: str
    baslik: str
    sutunlar: list[RaporSutun]
    satirlar: list[dict[str, Any]]
    toplamlar: dict[str, Any] = Field(default_factory=dict)
    #: Serbest metin bolumu (yaslandirma, ihtar govdesi, denetim notu).
    metin: str | None = None


class RaporIsOut(BaseModel):
    """(P167 §5) Arka plan rapor isi.

    `dosya_key` DONMEZ: obje anahtari istemciye verilmez (avatar ve duyuru
    gorseliyle ayni kural). Indirme, ayri bir uctan alinan kisa omurlu
    presigned URL ile yapilir.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    kod: str
    bicim: str
    durum: str
    dosya_adi: str | None = None
    #: KULLANICIYA gosterilecek kisa hata kimligi — yigin izi DEGIL.
    hata: str | None = None
    created_at: datetime
    biten_at: datetime | None = None


class RaporGrafikTanimi(BaseModel):
    """(P181 Bölüm 8) Raporun grafik yapılandırması — web/PDF/Excel tek kaynak."""

    tip: str  # "cizgi" | "sutun" | "pasta"
    x: str
    seriler: list[str]


class RaporKatalogOgesi(BaseModel):
    kod: str
    baslik: str
    aciklama: str
    #: (P167 §5) "listeler" | "ekstreler" | "dokumler" — kart izgarasinin
    #: bolumu. Istemcide ikinci bir eslestirme tablosu tutulmaz.
    kategori: str = "dokumler"
    #: Bu raporun ANLAMLANDIRDIGI parametre alanlari. Modal yalniz bunlari
    #: cizer; sunucu yalniz bunlari okur. Istemcide ayri bir liste
    #: tutulsaydi, bir rapora yeni suzgec eklendiginde iki yer ayrisir ve
    #: kusur SESSIZ olurdu (alan cizilir, sunucu yok sayar).
    alanlar: list[str] = []
    #: Tum defteri tarayan rapor mu? Istemci bunlari senkron uc yerine
    #: KUYRUGA yollar. Olcuyu sunucu bilir; istemci bilemez.
    agir: bool = False
    #: (P181 Bölüm 8) Grafik yapılandırması (yoksa yalnız tablo).
    grafik: RaporGrafikTanimi | None = None


class RaporKatalogResponse(BaseModel):
    items: list[RaporKatalogOgesi]
    #: Kategori SIRASI — brief §5'in sirasi. Alfabetik siralamak
    #: "Listeler"i "Dokumler"in altina duşürürdü.
    kategoriler: list[str] = []


# ========================= P32 MESAJ SABLONLARI ============================= #
MesajKanal = Literal["sms", "eposta"]
#: Amac SABLONDA durur, gonderim aninda secilmez: ayni sablonun bir gun
#: pazarlama bir gun operasyonel gonderilmesi riza denetimini anlamsiz
#: kilardi.
MesajAmac = Literal["pazarlama", "operasyonel"]
MesajDurum = Literal["kuyrukta", "gonderildi", "iletildi", "okundu", "basarisiz"]


class MesajSablonuCreate(BaseModel):
    kanal: MesajKanal
    ad: str = Field(..., min_length=1, max_length=100)
    konu: str | None = Field(None, max_length=200)
    #: (P171) E-POSTA kanalinda govde zengin metindir (`ZenginMetin`
    #: editoru) ve saklanan deger baskasina GONDERILIR. SMS'te
    #: bicimlendirme zaten anlamsiz; temizlik ona da zarar vermez cunku
    #: duz metin beyaz listeden DEGISMEDEN gecer.
    govde: ZenginHtml = Field(..., min_length=1, max_length=4000)
    amac: MesajAmac = "operasyonel"
    aktif: bool = True

    @model_validator(mode="after")
    def _konu_yalniz_epostada(self) -> "MesajSablonuCreate":
        # SMS'te dolu konu, gonderilen metne GIRMEYEN bir alan olurdu:
        # kullanici yazar ve kaybeder.
        if self.kanal == "sms" and self.konu:
            raise ValueError("SMS sablonunda konu olmaz")
        return self


class MesajSablonuUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=100)
    konu: str | None = Field(None, max_length=200)
    govde: ZenginHtml | None = Field(None, min_length=1, max_length=4000)
    amac: MesajAmac | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "MesajSablonuUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class MesajSablonuOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    kanal: str
    ad: str
    konu: str | None = None
    govde: str
    amac: str
    aktif: bool
    #: Sablonda gecen etiketler (onizleme/dogrulama).
    etiketler: list[str] = Field(default_factory=list)
    #: Desteklenmeyen etiketler — UYARIDIR, hata degil: sablon kaydedilir
    #: ama kullanici yazim hatasini gorur.
    bilinmeyen_etiketler: list[str] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime | None = None


class MesajSablonuListResponse(BaseModel):
    meta: PageMetaOut
    items: list[MesajSablonuOut]


class SmsOlcumOut(BaseModel):
    karakter: int
    unicode_mi: bool
    parca: int
    kalan: int
    #: UCS-2'ye ZORLAYAN karakterler (Turkce `ı/ğ/ş` sinirlari 160'tan 70'e
    #: dusurur) — kullanici gorup bilincli secsin.
    zorlayan: list[str]


class MesajOnizlemeIstek(BaseModel):
    #: (P171) ONIZLEME DE TEMIZLENIR. Saklanmayan bir govde ama ONIZLEME
    #: EKRANDA CIZILIR: temizlenmemis birakmak, "kaydetmeden once dene"
    #: yoluyla acilmis bir enjeksiyon kapisi olurdu. Ayrica onizleme
    #: KAYDEDILENLE AYNI SEYI gostermeli — temizlenmemis bir onizleme,
    #: kullaniciya kaydedilmeyecek bir sonuc gosterirdi.
    govde: ZenginHtml = Field(..., min_length=1, max_length=4000)
    konu: str | None = Field(None, max_length=200)
    #: Onizleme icin ornek kisi (verilmezse ornek degerler kullanilir).
    user_id: uuid.UUID | None = None


class MesajOnizlemeOut(BaseModel):
    konu: str | None = None
    govde: str
    etiketler: list[str]
    bilinmeyen_etiketler: list[str]
    sms: SmsOlcumOut | None = None


# ------------------------ (P154 / Asama 6.4) NOT VE EK --------------------- #
EkTuru = Literal["not", "dosya"]


class EkCreate(BaseModel):
    """Not ya da dosya eki.

    DOSYA YUKLEME BURADA DEGIL: istemci once `/uploads/presign` ile
    imzali URL alir, dosyayi DOGRUDAN depoya koyar, sonra donen anahtari
    (`dosya_key`) buraya yazar. Ikinci bir yukleme yolu, boyut/tur
    dogrulamasini iki yerde tutmak olurdu.
    """

    varlik_tipi: str = Field(max_length=32)
    varlik_id: uuid.UUID
    tur: EkTuru
    metin: str | None = Field(None, max_length=4000)
    dosya_key: str | None = Field(None, max_length=500)
    dosya_adi: str | None = Field(None, max_length=255)

    @model_validator(mode="after")
    def _icerik_zorunlu(self) -> "EkCreate":
        # Goc 0043'teki `ck_varlik_eki_icerik` CHECK'iyle AYNI kural.
        # Burada da olculuyor cunku veritabani hatasi kullaniciya
        # "IntegrityError" olarak doner; sozlesme duzeyinde reddetmek
        # ona NE eksik oldugunu soyler.
        if self.tur == "not" and not (self.metin or "").strip():
            raise ValueError("Not icin metin zorunludur.")
        if self.tur == "dosya" and not (self.dosya_key or "").strip():
            raise ValueError("Dosya eki icin dosya_key zorunludur.")
        return self


class EkOut(BaseModel):
    id: uuid.UUID
    tur: EkTuru
    metin: str | None = None
    dosya_key: str | None = None
    dosya_adi: str | None = None
    #: Kim ekledi. "kim yazdi" bilinmeyen bir not, kayit defterinde ise
    #: yaramaz.
    olusturan_ad: str | None = None
    created_at: datetime


class EkListResponse(BaseModel):
    items: list[EkOut]


# ------------------------- (P154 / Asama 6.3) ARAMA ------------------------ #
class AramaVurusu(BaseModel):
    """Tek bir arama vurusu.

    GOVDE DONMEZ, yalniz baslik + kisa ayrinti: arama sonucu bir ONIZLEME
    yuzeyidir. Tam kaydi vermek, listeleme uclarinin suzgeclerini (ornegin
    talebin `_own_scope`u degil ama alan bazli gizlemeleri) atlayan
    ikinci bir okuma yolu acardi. Kullanici satira tiklayip ASIL uca
    gider.
    """

    kaynak: Literal[
        "kisi", "daire", "blok", "firma", "gorev", "duyuru", "talep", "finans"
    ]
    id: uuid.UUID
    baslik: str
    ayrinti: str | None = None


class AramaSonucu(BaseModel):
    q: str
    items: list[AramaVurusu]


class MesajGonderIstek(BaseModel):
    """Bireysel + toplu gonderim TEK govdede.

    `user_ids` verilirse o kisilere; verilmezse suzgec uygulanir. Iki ayri
    uc, ayni riza/gecmis mantigini iki kez yazmak olurdu.
    """

    sablon_id: uuid.UUID
    user_ids: list[uuid.UUID] | None = None
    blok: str | None = None
    #: "borclu" | "tumu" — borc durumuna gore suzgec.
    borc_durumu: str | None = Field(None, max_length=20)
    #: (P154 / Asama 9) ROL BAZLI segment — brief'in dorduncu alici kumesi.
    #:
    #: DIGER SUZGECLERDEN AYRI CALISIR: blok/borc suzgecleri SAKIN
    #: listesinden turuyor (`unit_resident` uzerinden); rol segmenti ise
    #: PERSONELI de kapsamali (guvenlik, tesis gorevlisi — onlarin dairesi
    #: yoktur ve sakin listesinde HIC gorunmezler). Ikisini tek sorguya
    #: sikistirmak, "guvenlige duyuru gonder" dendiginde SESSIZCE bos liste
    #: uretirdi.
    rol: str | None = Field(None, max_length=32)


class MesajGonderimOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    kanal: str
    amac: str
    user_id: uuid.UUID | None = None
    user_ad: str | None = None
    hedef: str
    konu: str | None = None
    govde: str
    durum: str
    hata: str | None = None
    saglayici: str | None = None
    created_at: datetime


class MesajGonderimListResponse(BaseModel):
    meta: PageMetaOut
    items: list[MesajGonderimOut]


class MesajYapilandirmaOut(BaseModel):
    """(P168 §4.4) Ayarlar ekranina donen yapilandirma.

    ===========================================================================
    SIRLAR HIC DONMEZ — "maskeli" bile degil
    ===========================================================================
    Brief "sirlar arayuzde maskeli gosterilsin" diyor. Bunu `****` gibi
    bir metin dondurerek yapmak KOLAY ama YANLIS olurdu: maskeli deger de
    bir DEGERDIR, forma girer ve kullanici "kaydet"e bastiginda gercek
    parolanin uzerine `****` yazilirdi.

    Bunun yerine deger HIC DONMEZ; yalnizca "dolu mu" bayragi doner.
    Arayuz bos bir parola alani cizer ve altinda "kayitli bir parola var,
    degistirmek icin yenisini yazin" der. Bos birakilirsa sunucu mevcut
    degeri KORUR.
    """

    model_config = ConfigDict(from_attributes=True)

    sms_saglayici: str | None = None
    sms_kullanici: str | None = None
    sms_baslik: str | None = None
    #: Parolanin KENDISI degil, VARLIGI.
    sms_parola_var: bool = False
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_kullanici: str | None = None
    smtp_parola_var: bool = False
    smtp_gonderen: str | None = None
    gunluk_kota: int | None = None
    #: Bugun kac gonderim yapildi — kotanin ne kadarinin kullanildigini
    #: gostermek, kullaniciyi "neden gonderilmiyor" sorusuyla bas basa
    #: birakmamak icin.
    bugun_gonderilen: int = 0
    #: Kanal basina "gercekten gonderebilir miyim". Arayuz bunu okur ve
    #: gonderim ekraninda ONCEDEN uyarir — gonderdikten SONRA degil.
    sms_hazir: bool = False
    eposta_hazir: bool = False
    #: (P173 §4) KANAL HANGI AYARDAN CALISIYOR.
    #:
    #: `hazir` bayragi tek basina YANILTICIYDI: alanlar BOS gorunurken
    #: rozet "hazir" diyordu ve kullanici "ben bir sey girmedim, nasil
    #: hazir?" diye sorup ayarlari yeniden girmeye kalkisiyordu. Sebep
    #: dogru ama gorunmezdi — kanal ENV'deki GENEL ayardan calisiyor.
    #:
    #: `tesis`: bu tesisin kendi ayari · `genel`: ENV'deki ortak ayar ·
    #: `yok`: hicbiri.
    sms_kaynak: Literal["tesis", "genel", "yok"] = "yok"
    eposta_kaynak: Literal["tesis", "genel", "yok"] = "yok"


class MesajYapilandirmaUpdate(BaseModel):
    """Kismi guncelleme. BOS BIRAKILAN PAROLA MEVCUDU KORUR.

    `None` "degistirme" demek, bos dizge ise "TEMIZLE" demektir — ikisini
    ayirmasaydik kayitli bir parolayi silmenin hicbir yolu olmazdi.
    """

    sms_saglayici: str | None = Field(None, max_length=40)
    sms_kullanici: str | None = Field(None, max_length=150)
    sms_parola: str | None = Field(None, max_length=200)
    sms_baslik: str | None = Field(None, max_length=40)
    smtp_host: str | None = Field(None, max_length=200)
    smtp_port: int | None = Field(None, ge=1, le=65535)
    smtp_kullanici: str | None = Field(None, max_length=200)
    smtp_parola: str | None = Field(None, max_length=200)
    smtp_gonderen: str | None = Field(None, max_length=200)
    #: NULL = sinir yok; 0 KABUL EDILMEZ ("kapali" demek olurdu).
    gunluk_kota: int | None = Field(None, ge=1, le=100000)

    @model_validator(mode="after")
    def _en_az_bir(self) -> "MesajYapilandirmaUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class MesajTestGonderim(BaseModel):
    """(P168 §4.4) Test gonderimi — ayarlarin GERCEKTEN calistigini olcer."""

    kanal: MesajKanal
    #: Telefon ya da e-posta; hangisi oldugunu `kanal` soyler.
    hedef: str = Field(..., min_length=3, max_length=200)


class MesajTestSonuc(BaseModel):
    durum: str
    saglayici: str
    hata: str | None = None


class MesajGonderSonuc(BaseModel):
    gonderildi: int
    basarisiz: int
    #: Riza YOKLUGU nedeniyle atlananlar — sessizce dusurulmez, SAYILIR.
    riza_yok: int
    #: Adresi/numarasi olmayanlar.
    adres_yok: int




class KararUyesiIn(BaseModel):
    ad: str = Field(..., min_length=1, max_length=150)
    gorev: str | None = Field(None, max_length=100)


class KararDefteriCreate(BaseModel):
    #: (P167 §6.2) ZORUNLU DEGIL. Brief'in alan listesinde yildiz yalniz
    #: "Konu"da; numara bos birakilirsa MERKEZI seriden (`KRR-yil-000001`)
    #: uretilir. Zorunlu tutmak, her karar icin kullaniciyi bir numara
    #: uydurmaya zorlar ve seri tutarliligini insan hafizasina birakirdi.
    karar_no: str | None = Field(None, min_length=1, max_length=30)
    konu: str = Field(..., min_length=1, max_length=200)
    tarih: date | None = None
    metin: str = Field(..., min_length=1, max_length=20000)
    baskan_ad: str | None = Field(None, max_length=150)
    uyeler: list[KararUyesiIn] = Field(default_factory=list, max_length=50)


class KararDefteriUpdate(BaseModel):
    karar_no: str | None = Field(None, min_length=1, max_length=30)
    konu: str | None = Field(None, min_length=1, max_length=200)
    tarih: date | None = None
    metin: str | None = Field(None, min_length=1, max_length=20000)
    baskan_ad: str | None = Field(None, max_length=150)
    #: Verilirse uye listesi TAMAMEN DEGISTIRILIR (kismi ekleme/cikarma
    #: yerine): kismi islem, "uyeyi cikardim mi ekledim mi" belirsizligini
    #: istemciye birakirdi.
    uyeler: list[KararUyesiIn] | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "KararDefteriUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class KararDefteriOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    karar_no: str
    konu: str
    tarih: date
    metin: str
    baskan_ad: str | None = None
    uyeler: list[KararUyesiIn] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime | None = None


class KararDefteriListResponse(BaseModel):
    meta: PageMetaOut
    items: list[KararDefteriOut]


class DokumanCreate(BaseModel):
    """Dokuman KAYDI — dosya MinIO'ya presign ile ayrica yuklenir."""

    ad: str = Field(..., min_length=1, max_length=200)
    obje_anahtari: str = Field(..., min_length=1, max_length=500)
    icerik_tipi: str | None = Field(None, max_length=150)
    #: 25 MB ust sinir (CHECK de zorlar) — daha buyugu presign akisinda
    #: zaman asimina ve mobilde bellek baskisina yol acar.
    boyut_bayt: int | None = Field(None, ge=1, le=26_214_400)
    aciklama: str | None = Field(None, max_length=1000)
    #: (P167 ek) VARSAYILAN KAPALI — gerekce goc 0061'de.
    sakine_acik: bool = False


class DokumanUpdate(BaseModel):
    """(P167 ek) Yalnizca GORUNURLUK degistirilebilir.

    Ad/aciklama/dosya duzenleme BILEREK YOK: dosyanin kendisi degismez
    (yeni surum yeni kayittir) ve adi degistirmek, sakinin indirdigi
    dosyayla listede gordugu adin ayrismasina yol acardi.
    """

    sakine_acik: bool


class DokumanOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    obje_anahtari: str
    icerik_tipi: str | None = None
    boyut_bayt: int | None = None
    aciklama: str | None = None
    yukleyen_user_id: uuid.UUID | None = None
    yukleyen_ad: str | None = None
    created_at: datetime
    sakine_acik: bool = False


class DokumanListResponse(BaseModel):
    meta: PageMetaOut
    items: list[DokumanOut]


#: (P168 §5) Brief'in bes yasal metni.
KvkkTur = Literal[
    "aydinlatma", "acik_riza", "gizlilik", "kullanim_kosullari", "cerez"
]


class KvkkMetinCreate(BaseModel):
    """Yeni SURUM yayinla. `surum` ISTEMCIDEN ALINMAZ — sunucu artirir:
    istemcinin surum secmesi, iki yoneticinin ayni numarayi vermesi ya da
    numara atlamasi demekti."""

    #: (P168 §5) Hangi yasal metin. Varsayilan `aydinlatma` — bugune
    #: kadar yayinlanan tek metin oydu ve mevcut istemciler `tur`
    #: gondermiyor.
    tur: KvkkTur = "aydinlatma"
    baslik: str = Field(..., min_length=1, max_length=200)
    #: (P171) YAZMA ANINDA TEMIZLENIR — zengin metin editorunden geliyor ve
    #: tesisteki HERKESE gosteriliyor.
    govde: ZenginHtml = Field(..., min_length=1, max_length=100_000)
    #: (P168 §5) VARSAYILAN `True` ve bu bilincli: guvenli yon SORMAKTIR.
    #: `False` varsayilan olsaydi, esasli bir degisikligi yayinlayan
    #: yonetici kutuyu isaretlemeyi unuttugunda kimseye sorulmaz ve bu
    #: SESSIZCE hukuki bir eksiklik olurdu. Yazim hatasi duzeltmeleri
    #: icin `False` gonderilir.
    yeniden_onay_gerekir: bool = True


class KvkkMetinOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    tur: KvkkTur = "aydinlatma"
    surum: int
    baslik: str
    govde: str
    yeniden_onay_gerekir: bool = True
    #: (P168 §5) TURETILIR, saklanmaz: yururlukte olan tur basina EN
    #: YUKSEK surumdur. Kolon olsaydi iki metin ayni anda yururlukte
    #: olabilir ya da hicbiri olmayabilirdi.
    yururlukte: bool = False
    created_at: datetime


class KvkkDurumOut(BaseModel):
    """Kullanicinin onay DURUMU — istemci kapiyi buna gore kurar."""

    #: Tenant henuz metin yayinlamadiysa False (kapi kurulamaz; metin yok).
    metin_var: bool
    guncel_surum: int | None = None
    onayladigi_surum: int | None = None
    onay_at: datetime | None = None
    #: True ise istemci ONAY KAPISINI acar. Surum artinca yeniden True olur.
    onay_gerekli: bool


class KvkkOnayGecmisiOgesi(BaseModel):
    """(P170 §2) Kullanicinin KENDI onay gecmisinden bir satir.

    OKUMA YUZEYI YERINDE KALIR: yonetim panele tasindi, ama "hangi metni
    hangi surumde ne zaman onayladim" sorusu kullanicinin KENDI verisidir
    ve profilinden gorulebilmeli. KVKK'nin kendisi bunu gerektiriyor.
    """

    model_config = ConfigDict(from_attributes=True)
    tur: KvkkTur
    surum: int
    onay_at: datetime
    #: Onaylanan surum HALA YURURLUKTE MI. Turetilir: tur basina en yuksek
    #: surumle karsilastirilir. Istemcinin bunu kendi hesaplamasi, ayni
    #: kurali ikinci kez (ve bir gun farkli) yazmasi olurdu.
    guncel_mi: bool = False


class KvkkPlatformMetin(BaseModel):
    """(P170 §2) Platform panelinde bir tesisin metin surumu."""

    id: uuid.UUID
    tur: KvkkTur
    surum: int
    baslik: str
    govde: str
    yeniden_onay_gerekir: bool
    yururlukte: bool
    created_at: datetime


class KvkkPlatformOnayOzeti(BaseModel):
    """Tur basina YURURLUKTEKI surumu kac kisi onaylamis.

    KISI LISTESI DONMEZ: capraz-tenant bir uctan kisi dokumu almak,
    yonetim isi icin gereksiz bir kisisel veri akisi olurdu.
    """

    tur: KvkkTur
    surum: int
    onaylayan: int


class KvkkPlatformDurum(BaseModel):
    """Bir tesisin KVKK durumu — metinler + onay ozeti tek cagrida."""

    metinler: list[KvkkPlatformMetin]
    onaylar: list[KvkkPlatformOnayOzeti]


class KvkkOnayIstek(BaseModel):
    """Onaylanan SURUM govdede TASINIR: istemci ekranda gordugu surumu
    bildirir. Sunucu guncel surumle karsilastirir — arada metin
    degistiyse onay ESKI METNE ait olurdu ve 409 doner."""

    #: (P168 §5) Hangi metnin onayi. Varsayilan, mevcut istemcileri
    #: bozmamak icin `aydinlatma`.
    tur: KvkkTur = "aydinlatma"
    surum: int = Field(..., ge=1)


class PazarlamaTercihleri(BaseModel):
    """Uc BAGIMSIZ kanal. Tek bir "pazarlama" bayragi, kisiyi istemedigi
    kanaldan mesaj almak ile hic almamak arasinda secmeye zorlardi."""

    model_config = ConfigDict(from_attributes=True)
    eposta: bool = False
    sms: bool = False
    arama: bool = False
    guncelleme_at: datetime | None = None


class PazarlamaTercihUpdate(BaseModel):
    eposta: bool | None = None
    sms: bool | None = None
    arama: bool | None = None
    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="after")
    def _en_az_bir(self) -> "PazarlamaTercihUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


# ============================ P37 GURULTU UYARISI =========================== #
class UnitUyariOut(BaseModel):
    """Verilen caydirici uyari kaydi — DENETIM gorunumu."""

    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    unit_id: uuid.UUID
    unit_no: str | None = None
    esik: int
    sayac: int
    metin: str
    kanal: Literal["webhook", "manuel"]
    durum: Literal["gonderildi", "basarisiz", "manuel_bekliyor", "manuel_yapildi"]
    deneme: int
    hata: str | None = None
    created_at: datetime


class UnitUyariListResponse(BaseModel):
    meta: PageMetaOut
    items: list[UnitUyariOut]


# ============================== P38 ANKET =================================== #
# (P154 / Asama 7.2) PORTAL SEMALARI SILINDI. `/portal` ve `/public/{slug}`
# uclari kaldirildi (brief: "ozel domain hizmeti sunmuyoruz"); sema
# sinif-larini birakmak, hicbir ucun uretmedigi bir sozlesmeyi surdurmek
# olurdu. Anket semalari KALDI — anket calisiyor ve mobil karsiligi var.
class PortalAnketSecenek(BaseModel):
    id: uuid.UUID
    metin: str
    sira: int
    #: Oy sayisi — YALNIZ sonuc gorunur oldugunda dolar (bkz. AnketOut).
    oy: int | None = None


class AnketOut(BaseModel):
    """Anket + secenekler (+ kosullu sonuc).

    SONUC KAPANANA KADAR GIZLI: acik bir ankette guncel dagilimi gostermek,
    sonraki oy verenleri etkiler (surusel etki) ve oylamanin kendisini
    bozardi. Yonetim sonucu HER ZAMAN gorur (kararin sahibi odur).
    """

    id: uuid.UUID
    baslik: str
    aciklama: str | None = None
    kapanis_at: datetime | None = None
    aktif: bool
    #: Anket oy almaya acik mi (aktif + kapanis gecmemis).
    acik: bool
    #: Istegi yapan kisi oy verdi mi (anonim public uc icin None).
    oy_verdim: bool | None = None
    #: Toplam oy — sonuc gorunur degilse None.
    toplam_oy: int | None = None
    secenekler: list[PortalAnketSecenek]
    created_at: datetime


class AnketListResponse(BaseModel):
    meta: PageMetaOut
    items: list[AnketOut]


class AnketSecenekIn(BaseModel):
    metin: str = Field(..., min_length=1, max_length=200)
    sira: int = Field(0, ge=0, le=999)


class AnketCreate(BaseModel):
    baslik: str = Field(..., min_length=1, max_length=200)
    aciklama: str | None = Field(None, max_length=2000)
    kapanis_at: datetime | None = None
    #: EN AZ IKI secenek: tek secenekli bir anket oy toplamaz, onay toplar.
    secenekler: list[AnketSecenekIn] = Field(..., min_length=2, max_length=20)


class AnketUpdate(BaseModel):
    """Secenekler DEGISTIRILEMEZ: oy verilmis bir anketin seceneklerini
    degistirmek, verilmis oylari baska bir soruya tasimak olurdu."""

    baslik: str | None = Field(None, min_length=1, max_length=200)
    aciklama: str | None = Field(None, max_length=2000)
    kapanis_at: datetime | None = None
    aktif: bool | None = None
    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="after")
    def _en_az_bir(self) -> "AnketUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class AnketOyIstek(BaseModel):
    secenek_id: uuid.UUID


class TanitimIletisimIstek(BaseModel):
    """(P127.2) Tanitim sitesi iletisim formu — PUBLIC, kimliksiz.

    Portal formuyla AYNI "donus yolu" kurali: telefon VEYA e-posta zorunlu;
    ikisi de yoksa gelen mesaja cevap verilemezdi.

    `dil` istemciden gelir (sayfanin o anki dili) — cevabi ayni dilde
    yazabilmek icin. Dogrulanir: bilinmeyen bir deger saklanmaz.
    """

    ad: str = Field(..., min_length=2, max_length=150)
    email: str | None = Field(None, max_length=200)
    telefon: str | None = Field(None, max_length=40)
    mesaj: str = Field(..., min_length=5, max_length=5000)
    dil: str | None = Field(None, max_length=5)

    @model_validator(mode="after")
    def _donus_yolu(self) -> "TanitimIletisimIstek":
        if not (self.telefon or self.email):
            raise ValueError("telefon veya email zorunlu")
        return self


class TanitimIletisimOut(BaseModel):
    """Admin listesi ogesi — kisisel veri TASIR, yalniz platform admini gorur."""

    id: uuid.UUID
    ad: str
    email: str | None = None
    telefon: str | None = None
    mesaj: str
    dil: str | None = None
    okundu: bool
    created_at: datetime


class TanitimIletisimListResponse(BaseModel):
    meta: PageMetaOut
    items: list[TanitimIletisimOut]


class TanitimIletisimOkunduIstek(BaseModel):
    okundu: bool = True


class YetkiSatiri(BaseModel):
    """Tek bir (METOT, yol) icin rol kapisi."""

    metot: str
    yol: str
    #: `None` = ucta ROL KAPISI YOK. Bu "herkese acik" DEMEK DEGILDIR;
    #: kimlik dogrulamasi yine gerekebilir. Ikisini karistirmak, kimliksiz
    #: erisilebilir bir uc varmis gibi gostermek olurdu.
    roller: list[str] | None = None
    #: (P35) Yazma sahibi TENANT MODUNA bagli. Sabit bir kume gostermek,
    #: `dis_sirket` modundaki gercek davranisi yanlis anlatirdi.
    moda_bagli: bool = False


class YetkiMatrisiResponse(BaseModel):
    #: Sutun sirasi — panel ile test kilidi yan yana okunabilsin.
    roller: list[str]
    items: list[YetkiSatiri]


# ==================== (P154 / Asama 7.3) KURULUM SIHIRBAZI ================== #
class KurulumAdimOut(BaseModel):
    """Tek bir kurulum adimi.

    `sayi` DA DONER, yalniz `tamam` degil: "3 blok var" ile "blok var"
    kullaniciya ayni seyi soylemez ve sihirbaz ilerlemeyi anlatabilmeli.
    Metin DEGIL KOD doner — etiket istemcide aktif dilde cozulur.
    """

    kod: str
    sayi: int
    tamam: bool
    atlandi: bool
    #: (P193 §2) Adim MINIMUM CALISIR KURULUMUN parcasi mi. Karar sunucuda
    #: (bkz. `routers/kurulum.py::ADIMLAR`); istemci yalnizca cizer.
    zorunlu: bool = False


class KurulumDurumOut(BaseModel):
    adimlar: list[KurulumAdimOut]
    toplam: int
    #: Tamamlanan + BILINCLI ATLANAN. Atlanani saymasaydik, "bu sitede NFC
    #: yok" diyen bir tesis %100'e asla ulasamaz ve gosterge kalici bir
    #: sitem olurdu.
    gecilen: int
    #: (P193 §2) Kac adim MINIMUM calisir kurulumun parcasi.
    zorunlu_toplam: int = 0
    #: (P193 §2) Tamamlanmamis zorunlu adimlarin KODLARI. ATLAMA burada
    #: sayilmaz: atlamak gostergeyi rahatlatir, gercegi degistirmez.
    eksik_zorunlular: list[str] = Field(default_factory=list)
    #: (P193 §2) Tesis calisir hâlde mi (eksik zorunlu yok).
    calisir: bool = True


class KurulumAtlaIstek(BaseModel):
    kod: str = Field(max_length=32)
    #: `false` ATLAMAYI GERI ALIR — tek yonlu bir atlama, sonradan NFC
    #: kuran bir tesise sihirbazi bir daha tam gosteremezdi.
    atla: bool = True
    model_config = ConfigDict(extra="forbid")


# ==================== (P154 / Asama 8) ICE AKTARIM CATISI =================== #
class IceAktarimAlanOut(BaseModel):
    """Bir turun tek alani — istemcinin KOLON ESLEMESI bunun uzerine kurulur."""

    kod: str
    zorunlu: bool
    ornek: str


class IceAktarimTurOut(BaseModel):
    kod: str
    #: Aciklama METIN DEGIL ANAHTAR: etiket istemcide aktif dilde cozulur.
    aciklama_kodu: str
    alanlar: list[IceAktarimAlanOut]


class IceAktarimSatir(BaseModel):
    """Excel'den gelen TEK satir — istemci ayristirir ve BIZIM alan
    kodlarimizla gonderir (xlsx ayristirma bir saldiri yuzeyidir, P28/P29).
    """

    satir_no: int
    degerler: dict[str, str | int | float | None] = Field(default_factory=dict)


class IceAktarimIstek(BaseModel):
    satirlar: list[IceAktarimSatir] = Field(..., min_length=1, max_length=2000)
    #: True ise HICBIR SEY YAZILMAZ, yalnizca dogrulama raporu doner.
    yalniz_dogrula: bool = False
    #: (P193 §1) SORUNLU SATIR VARSA NE OLACAK.
    #:
    #: VARSAYILAN `false` = AKTARIM YAPILMAZ. P154'te kismi basari
    #: varsayilandi ("300 satirda 4 hata yuzunden 296'yi reddetmek
    #: kullaniciyi elle ayiklamaya zorlar") ve o gerekce hâlâ gecerli —
    #: ama SESSIZ oldugu icin kusurluydu: yonetici 50 kisi yukluyor,
    #: 10'u atlaniyor, kimse fark etmiyor. Artik atlama bir KARARDIR:
    #: kullanici onizlemede sorunlari gorur ve acikca "atla" der.
    sorunlulari_atla: bool = False
    #: Yalniz gecmis listesinde gosterilir. DOSYANIN KENDISI SAKLANMAZ —
    #: icinde kisisel veri olabilir (KVKK: veri en az).
    dosya_adi: str | None = Field(None, max_length=255)
    model_config = ConfigDict(extra="forbid")


class IceAktarimHata(BaseModel):
    satir_no: int
    alan: str | None = None
    hata: str


class IceAktarimSonuc(BaseModel):
    satir_sayisi: int = 0
    olusan: int = 0
    atlanan: int = 0
    #: (P193 §6) VAR OLAN kayda yeni bilgi yazildi (bugun yalniz daire
    #: arsa payi/metrekare). "Atlandi" ile ayni sey DEGIL: atlanan satir
    #: hicbir sey degistirmez, bu satir degistirir.
    guncellenen: int = 0
    hatali: int = 0
    hatalar: list[IceAktarimHata] = Field(default_factory=list)
    #: Yalniz UYGULANDIGINDA doner; onizlemede `null`. Geri alma bunu
    #: kullanir.
    aktarim_id: uuid.UUID | None = None
    # --- (P193 §1) ------------------------------------------------------- #
    #: HICBIR SEY YAZILMADI: sorunlu satir var ve kullanici "sorunlulari
    #: atla" DEMEDI. Onizlemede daima `false` doner (onizleme zaten
    #: yazmaz); yalnizca gercek aktarim isteginde anlamlidir.
    uygulanmadi: bool = False
    #: Davet ULASAN kisi sayisi. "Kac kisi eklendi" ile "kac kisiye
    #: ulasildi" AYRI sorulardir: hesap acilmis ama daveti gitmemis bir
    #: kisi sisteme HIC giremez ve yoneticinin bunu bilmesi gerekir.
    davet_gonderildi: int = 0
    davet_basarisiz: int = 0
    #: Daveti gitmeyen satirlar — satir numarasiyla.
    davet_hatalari: list[IceAktarimHata] = Field(default_factory=list)


class IceAktarimOut(BaseModel):
    id: uuid.UUID
    tur: str
    dosya_adi: str | None = None
    satir_sayisi: int
    olusan: int
    atlanan: int
    hatali: int
    durum: str
    created_at: datetime
    geri_alma_at: datetime | None = None


class IceAktarimListResponse(BaseModel):
    meta: PageMetaOut
    items: list[IceAktarimOut]


# ================== (P154 / Asama 5) YAPI DUZENLEME TOPLU ISLEMLERI ========= #
class TopluIslemSonuc(BaseModel):
    """Toplu GUNCELLEME/SIRALAMA sonucu.

    `UnitBulkResult` YENIDEN KULLANILMADI: onun `olusturulan` ve
    `bitis_no` alanlari bir guncellemede ANLAMSIZDIR ve doldurmak icin
    uydurma deger yazmak gerekirdi (olculdu: bos birakinca 500).
    """

    etkilenen: int
    #: Bulunamayan kimlikler — RLS baska tenant'in satirini zaten
    #: gostermez; kimlik SESSIZCE dusmez, burada gorunur.
    atlanan: list[str] = Field(default_factory=list)


class UnitTopluGuncelle(BaseModel):
    """Secili dairelerin niteligini TOPLU degistirir.

    KIMLIK LISTESI ALINIR, "3,5,7-12" GIBI BIR ARALIK DEGIL: aralik ifadesi
    kullanicinin EKRANDA GORDUGU listeye gore anlam kazanir (suzgec acikken
    "7-12" baska daireleri gosterir). Sunucuda cozmek, istemcinin gordugu
    kume ile sunucunun anladigi kumenin AYRISMASI demekti — ve yanlis
    daireye toplu islem uygulamak geri alinmasi zor bir hatadir.
    Aralik ayristirmasi arayuzdedir; sunucuya kesinlesmis kimlikler gelir.
    """

    unit_ids: list[uuid.UUID] = Field(..., min_length=1, max_length=500)
    unit_tip_id: uuid.UUID | None = None
    unit_grup_id: uuid.UUID | None = None
    aktif: bool | None = None
    #: (P193 §6) AYNI degeri hepsine yazar — tip daireler icin dogru arac
    #: (ayni katta ayni metrekare). Daire basina FARKLI deger icin
    #: `PATCH /units/arsa-payi` vardir.
    arsa_payi: float | None = Field(None, ge=0)
    metrekare: float | None = Field(None, ge=0)
    model_config = ConfigDict(extra="forbid")


class ArsaPayiSatiri(BaseModel):
    id: uuid.UUID
    #: `None` = arsa payini KALDIR. Bir daire arsa payi dagitiminin
    #: disinda birakilabilmeli (ticari birim, ortak alan).
    arsa_payi: float | None = Field(None, ge=0)


class ArsaPayiToplu(BaseModel):
    """(P193 §6) DAIRE BASINA FARKLI arsa payi — TEK ISTEKTE.

    `UnitTopluGuncelle` ile ayni sey DEGIL: o, secili dairelerin hepsine
    AYNI degeri yazar. Arsa payi ise dogasi geregi daire basina farklidir
    (100 daireli bir sitede 100 farkli sayi). Tek tek PATCH atmak 100
    istek, 100 denetim kaydi ve yarim kalabilen bir yazma demekti.
    """

    satirlar: list[ArsaPayiSatiri] = Field(..., min_length=1, max_length=500)
    model_config = ConfigDict(extra="forbid")


class ArsaPayiOzet(BaseModel):
    """Arsa payi TOPLAMI ve eksik girisler.

    TOPLAM GOSTERILIR cunku arsa payi bir PAYDIR: toplami 1 (ya da
    binde/yuzde olarak 1000/100) etmeyen bir dagilim, gider paylasimini
    sessizce yanlis hesaplar. Kullanici toplami gormeden bunu fark
    edemez.
    """

    daire_sayisi: int
    girilmis: int
    girilmemis: int
    toplam: float


class UnitSiralamaSatiri(BaseModel):
    id: uuid.UUID
    kat: int
    sira: int


class UnitSiralama(BaseModel):
    """Surukle-birak sonrasi yeni yerlesim — TEK ISTEKTE.

    Her daire icin ayri PATCH atmak, yirmi dairelik bir katta yirmi istek
    ve ARADA KESILME riski demekti: yarim uygulanmis bir siralama,
    kullanicinin gordugu duzenle veritabanindakini ayirirdi.
    """

    satirlar: list[UnitSiralamaSatiri] = Field(..., min_length=1, max_length=500)
    model_config = ConfigDict(extra="forbid")


class KatSilIstek(BaseModel):
    """Bir katin TUM dairelerini siler."""

    blok: str = Field(..., min_length=1, max_length=8)
    kat: int
    #: Dairelerin bagli kayitlari varsa (sakin, tahakkuk...) islem 409
    #: doner; `cascade=true` ile onaylanir. Blok silmedeki kaza korumasinin
    #: aynisi.
    cascade: bool = False
    model_config = ConfigDict(extra="forbid")


class KatSilOnizleme(BaseModel):
    """(P165) KAT SILME ETKI OZETI — silmeden ONCE ne kaybedilecegi.

    Brief: "kullanici ne kaybedecegini SILMEDEN ONCE gorsun". Uc, silme
    YAPMAZ; yalnizca sayar.

    NEDEN AYRI UC, NEDEN 409 GOVDESINE GOMULMEDI: 409 ancak kullanici
    SILMEYE BASTIKTAN sonra gorunur. Ozet ise karar ANINDAN once
    gerekiyor — onay ekraninda. Hata yolunu bilgi yolu olarak kullanmak,
    kullaniciyi once denemeye zorlamakti.

    KATEGORILER AYRI SAYILIR: "12 bagli kayit" bir sey soylemez; "3
    sakin, 9 tahakkuk" karar verdirir.
    """

    blok: str
    kat: int
    daire: int
    sakin: int
    tahakkuk: int
    odeme: int
    talep: int
    rezervasyon: int
    #: MALI KAYIT VAR MI — tahakkuk/odeme/finansal hareket. Arayuz bunu
    #: ayri bir uyari olarak gosterir: aidat kaydi silmek bir muhasebe
    #: izini yok etmektir ve denetimde aciklanamaz.
    mali_kayit: bool


class TopluSilIstek(BaseModel):
    ids: list[uuid.UUID] = Field(..., min_length=1, max_length=200)
    cascade: bool = False
    model_config = ConfigDict(extra="forbid")


class TopluSilSonuc(BaseModel):
    silinen: int
    #: Silinemeyenler ve SEBEBI — sessizce atlamak, kullanicinin sildigini
    #: sanmasi demekti.
    atlanan: list[dict] = Field(default_factory=list)


# ===================== (P154 / Asama 4) SOSYAL GIRIS ======================= #


class OauthSaglayiciListesi(BaseModel):
    """Yapilandirilmis saglayicilar. Arayuz dugmeleri buradan kurar —
    kapali bir saglayiciyi gostermek, kullaniciyi kesin basarisiz bir
    yola sokmak olurdu."""

    saglayicilar: list[str]


class OauthBaslaRequest(BaseModel):
    #: `web` | `mobil`. Callback SONRASI nereye donulecegini belirler;
    #: adresin KENDISI ayarlardan gelir (acik yonlendirme).
    yuzey: str = "web"
    #: (P180) `giris` (varsayilan — MEVCUT DAVRANIS) | `kayit` (yonetici kaydi).
    #: Niyet state'e yazilir ve callback ISTEKTEN DEGIL state'ten okur.
    niyet: str = "giris"
    #: (P180) niyet=kayit icin iki onay ZORUNLU (backend de dogrular — istemci
    #: kilidine guvenilmez); `onay_ticari` istege bagli.
    onay_sozlesme: bool = False
    onay_kvkk: bool = False
    onay_ticari: bool = False
    model_config = ConfigDict(extra="forbid")


class OauthBaslaResponse(BaseModel):
    adres: str
    #: Cagiran, donen `state`i kendi tarafinda da eslestirebilsin diye
    #: doner. Sunucu dogrulamasi buna BAGLI DEGIL — state Redis'te tutulur.
    state: str


class OauthSonucIstek(BaseModel):
    sonuc_id: str = Field(..., min_length=8, max_length=200)
    model_config = ConfigDict(extra="forbid")


class OauthSonucResponse(BaseModel):
    """`giris` ya da `baglama_gerekli`.

    IKI DURUM TEK SEMADA: cagiran tek bir yanit sekli bekler ve `durum`a
    bakar. Iki ayri uc, arayuzde iki ayri hata yolu demekti.
    """

    durum: str
    jetonlar: TokenPair | None = None
    saglayici: str | None = None
    #: YALNIZ GORUNTULEME — "hangi hesabi bagliyorum" sorusu icin.
    eposta: str | None = None
    #: Apple "e-postami gizle" dediyse `true`; arayuz bunu kullaniciya
    #: soyler, cunku o adrese posta gonderilemeyecegini bilmeli.
    relay: bool = False
    #: (P155r2 / §2) Saglayicinin bildirdigi ad soyad — kayit formunu
    #: ON-DOLDURMAK icin; kullanici duzeltebilir. Apple bunu `id_token`da
    #: VERMEZ, bos gelir ve akis kirilmaz.
    ad: str | None = None
    baglama_jetonu: str | None = None
    #: (P211 §1) `durum="tesis_secimi"` icin: TEK KULLANIMLIK secim
    #: jetonu ve secilebilecek tesisler. Jeton hicbir tesise yetki
    #: VERMEZ; yalnizca "bu dogrulanmis adres su tesislerde yonetici"
    #: bilgisini tasir.
    secim_jetonu: str | None = None
    tesisler: list[OauthTesisSecenek] = []


class OauthTesisSecenek(BaseModel):
    tenant_id: uuid.UUID
    ad: str
    slug: str


class OauthTesisSecIstek(BaseModel):
    secim_jetonu: str = Field(..., min_length=8, max_length=200)
    tenant_id: uuid.UUID


class OauthKayitBaslaResponse(BaseModel):
    """`RolKayitBaslaResponse` ile AYNI ILKE: eslesme sonucu SOYLENMEZ."""

    tesis_ad: str
    telefon_maskeli: str


class OauthBaglaBaslaRequest(BaseModel):
    baglama_jetonu: str
    tesis_kodu: str = Field(..., min_length=1, max_length=64)
    telefon: str = Field(..., min_length=5, max_length=32)
    model_config = ConfigDict(extra="forbid")


class OauthBaglaDogrulaRequest(BaseModel):
    baglama_jetonu: str
    telefon: str = Field(..., min_length=5, max_length=32)
    kod: str = Field(..., min_length=4, max_length=10)
    model_config = ConfigDict(extra="forbid")


# ---- (P184) SSO ROL TAMAMLAMA — e-posta ile (SMS'siz) ---- #
#
# `OauthBagla*`nin E-POSTA karsiligi: SSO kimligini bir ROL hesabina baglar,
# ama telefon+SMS yerine ya saglayici `email_verified=true` (OTP atlanir) ya da
# e-posta OTP ile. P177 uc sarti aynen (Tesis ID + liste + kanit). Terminoloji
# "kayit" degil "girişte Tesis ID ile tamamlama".


class OauthRolTamamlaRequest(BaseModel):
    """Doğrulanmış SSO kimliği + Tesis ID + beyan edilen rol.

    `baglama_jetonu` içinde saglayici + subject + eposta + email_verified imzalı
    gelir (`/auth/oauth/sonuc`un dönüşü). `rol` beyandır; listedeki rolle
    uyuşmazsa onay kuyruğuna düşer (`rol-eposta-basla` ile aynı ilke).

    (P191 §1) `rol` ARTIK OPSİYONEL — iki ayrı niyet vardır:

    * `rol` VERİLİR (kayıt akışı, mobil): "ben şu rolde kaydoluyorum" beyanı.
      Beyan listedeki rolle uyuşmazsa onay kuyruğuna düşer.
    * `rol` YOK (**girişte tamamlama**, web SSO): kullanıcı zaten yöneticinin
      davet ettiği kişidir; rol HESAPTAN okunur. Kullanıcıya rolünü sormak,
      bilmediği bir soruyu sormak ve yanlış cevapta onu çıkmaza atmaktı —
      ölçülen kusur tam buydu ("davet edildim ama SSO 'tesise bağlı değil'
      diyor"). Bu modda `password_set=true` hesap da bağlanabilir: sağlayıcı
      e-postayı DOĞRULADIYSA kanıt, üründe zaten oturum açan e-posta kodu
      (`/auth/giris/eposta-kod-iste`) ile aynı sınıftadır.
    """

    baglama_jetonu: str
    tesis_kodu: str = Field(..., min_length=3, max_length=40, examples=["OLTU-260715"])
    rol: str | None = Field(default=None, examples=["resident"])
    model_config = ConfigDict(extra="forbid")


class OauthRolTamamlaDogrulaRequest(BaseModel):
    """`email_verified=false` yolunda ikinci adım: e-posta OTP + bağlama."""

    baglama_jetonu: str
    tesis_kodu: str = Field(..., min_length=3, max_length=40)
    #: (P191 §1) `rol-tamamla` ile AYNI kural: yoksa rol hesaptan okunur.
    rol: str | None = Field(default=None, examples=["resident"])
    kod: str = Field(..., min_length=4, max_length=8)
    model_config = ConfigDict(extra="forbid")


class OauthRolTamamlaResponse(BaseModel):
    """TEK ŞEMA, ÜÇ SONUÇ — `durum` yönlendirir; hangi şartın tutmadığı SIZMAZ.

    * `giris`        — kimlik bağlandı, oturum açıldı (`jetonlar` dolu).
    * `otp_gerekli`  — sağlayıcı e-postayı doğrulamamış; e-posta OTP gönderildi
                       (`tesis_ad` teyit için dolu). İstemci `-dogrula` çağırır.
    * `onay_bekliyor`— liste dışı / rol uyuşmuyor / hesap kullanımda VEYA geçersiz
                       Tesis ID. Kullanıcıya AYNI nötr mesaj (K4 sızdırmama).
    """

    #: giris | otp_gerekli | onay_bekliyor
    durum: str = Field(examples=["giris"])
    #: Yalnız `otp_gerekli` iken dolu — kullanıcı doğru siteyi seçtiğini görsün.
    tesis_ad: str | None = None
    #: Yalnız `durum='giris'` iken dolu.
    jetonlar: TokenPair | None = None


class OauthBaglantiOut(BaseModel):
    saglayici: str
    eposta: str | None = None
    son_giris_at: datetime | None = None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class OauthBaglantiListesi(BaseModel):
    items: list[OauthBaglantiOut]


# ==================== (P155 / §7) DAVET JETONU ============================= #


class DavetCozRequest(BaseModel):
    """Jetonu cozer — GET yerine POST: jeton, tarayici gecmisine ve sunucu
    erisim gunluguune URL parametresi olarak dusmesin (jeton bir sirdir)."""

    jeton: str = Field(..., min_length=8, max_length=128)


class DavetCozResponse(BaseModel):
    """Cozulen davet baglami. TELEFON MASKELI doner (kullanici dogruladigini
    gorsun ama tam numara sizmasin). `ad` on-doldurma icindir."""

    tesis_ad: str
    rol: str
    ad: str
    telefon_maskeli: str
    daire_no: str | None = None  # yalniz sakinde dolu


class DavetParolaRequest(BaseModel):
    """Davetle gelen kullanici PAROLA yontemi secti.

    `ad` opsiyonel: sosyal olmayan yolda kullanici adini duzeltebilir
    (yonetici yalniz telefon girmis, ad daireden turetilmis olabilir)."""

    jeton: str = Field(..., min_length=8, max_length=128)
    ad: str | None = Field(None, min_length=1, max_length=120)
    new_password: str = Field(..., min_length=8)

    @field_validator("new_password")
    @classmethod
    def _strong(cls, v: str) -> str:
        return validate_password_strength(v)


class DavetSosyalRequest(BaseModel):
    """Davetle gelen kullanici SOSYAL yontem secti; saglayici akisi bitti.

    SMS YOK (sartname §7): davet jetonu, yoneticinin bu kisiyi ekledigi
    kanittir; sosyal saglayici kimligi kanitlar. Ikisi birlikte SMS'in
    yerini tutar."""

    jeton: str = Field(..., min_length=8, max_length=128)
    baglama_jetonu: str
    ad: str | None = Field(None, min_length=1, max_length=120)


class DavetDurumOut(BaseModel):
    """Panel 'davetler' satiri — yoneticinin gitmeyeni gormesi icin."""

    user_id: uuid.UUID
    ad: str
    rol: str
    telefon: str
    daire_no: str | None = None
    son_kanal: str | None = None
    son_durum: str | None = None
    son_hata: str | None = None
    son_gonderim_at: datetime | None = None
    used_at: datetime | None = None
    son_gecerlilik: datetime


class DavetDurumListResponse(BaseModel):
    # (P155 §7) Yoneticinin kendi tesis kodu — saglayici yokken "gitmeyen"
    # daveti ELLE iletmenin yedegi (davet bagi hash'li oldugu icin panelde
    # gosterilemez; elle iletilen sey TESIS KODUDUR ve kisi §4 yedek yoluyla
    # kaydolur).
    tesis_kodu: str | None = None
    items: list[DavetDurumOut]


class DavetGonderimSonucu(BaseModel):
    """Sakin/personel eklemede davet gonderim ozeti — yoneticiye gorunur."""

    gonderildi: bool
    kanal: str | None = None


# (P155 §7) Forward-ref cozumu: `DavetGonderimSonucu` dosya sonunda tanimli;
# ona atifta bulunan yanit semalari modul yuklendikten sonra yeniden kurulur.
ResidentCreatedOut.model_rebuild()
UserCreatedOut.model_rebuild()


# ========================================================================== #
# (P177 §4-§6) YENI KAYIT AKISI
# ========================================================================== #
# HEPSI `YENI_KAYIT_AKISI` BAYRAGI ARKASINDA. Bayrak kapaliyken bu
# semalari kullanan uclar `503 kayit_akisi_kapali` doner ve mevcut kayit
# yollari (`/auth/kayit/tesis-olustur`, `/auth/kayit/rol-basla`) HIC
# ETKILENMEZ — o uclar bu bayragi OKUMAZ bile.


class YoneticiBasvuruRequest(BaseModel):
    """Tanitim sitesindeki yonetici kayit formunun 1. adimi.

    TESIS ADI BURADA ISTENMEZ ve bu bilincli: tesis ancak e-posta
    DOGRULANDIKTAN sonra acilir (§5). Adi bu adimda alsaydik, hicbir
    zaman dogrulanmayan basvurular icin de bir tesis adi tasimak ve
    kullaniciyi henuz karar vermedigi bir sey icin dusundurmek olurdu.

    UC ONAY UC AYRI ALAN: "hepsini kabul ediyorum" seklinde tek bir
    bayrak, hangi metnin onaylandigini ispat edemezdi. Ucuncusu ISTEGE
    BAGLIDIR ve zorunlu ikisiyle ayni anlami TASIMAZ.

    IP ve tarayici bilgisi GOVDEDE ISTENMEZ: tarayici kendi IP'sini
    bilemez ve istemcinin beyan ettigi bir IP ispat degeri tasimaz.
    Sunucu onlari BASLIKTAN okur (`X-Istemci-Ip`, BFF ekler).
    """

    ad: str = Field(min_length=2, max_length=80, examples=["Ayşe"])
    soyad: str = Field(min_length=2, max_length=80, examples=["Yılmaz"])
    eposta: EmailStr = Field(examples=["ayse@ornek.com"])
    telefon: str = Field(min_length=5, max_length=32, examples=["+905321112203"])
    #: AYNI POLITIKA — `validate_password_strength`. Kendi `min_length`i
    #: ile yetinmek, YENI kayit yolundan girilen parolanin `set-password`
    #: ucundan girilenden ZAYIF olabilmesi demekti (olculdu: "GucluParola123"
    #: burada gecerdi, orada sembol eksikliginden 422 alirdi). Iki kapi,
    #: iki farkli guc siniri.
    parola: Annotated[str, AfterValidator(validate_password_strength)] = Field(
        min_length=8, max_length=128
    )
    onay_sozlesme: bool
    onay_kvkk: bool
    onay_ticari: bool = False

    @model_validator(mode="after")
    def _zorunlu_onaylar(self) -> "YoneticiBasvuruRequest":
        # KAPI SUNUCUDA. Arayuz de kontrol ediyor ama istemci
        # dogrulamasi atlanabilir; onay bir HUKUKI kayittir.
        if not (self.onay_sozlesme and self.onay_kvkk):
            raise ValueError(
                "Kullanıcı Sözleşmesi ve KVKK Aydınlatma Metni onayları zorunludur."
            )
        return self


class YoneticiBasvuruResponse(BaseModel):
    """E-postaya kod GONDERILDI — ama bunu YANITTAN OKUYAMAZSINIZ.

    `durum` her zaman `kod_gonderildi`dir. Adresin kayitli olup olmadigi,
    basvurunun tazelendigi ya da yeni acildigi SIZDIRILMAZ: aksi hâlde uc
    bir "bu e-posta sistemde var mi" sorgusuna donusurdu.
    """

    durum: str = Field(default="kod_gonderildi", examples=["kod_gonderildi"])


class YoneticiDogrulaRequest(BaseModel):
    eposta: EmailStr
    kod: str = Field(min_length=4, max_length=8, examples=["482913"])


class YoneticiDogrulaResponse(BaseModel):
    """OTURUM DEGIL, KURULUM JETONU.

    Kod dogru olsa bile ortada bir TESIS ve bir KULLANICI henuz yok; ne
    verilecek bir oturum var ne de girilecek bir yer. Jeton yalniz bir
    sonraki adimi (`/auth/kayit/yonetici-tesis`) acar ve kisa omurludur.
    """

    kurulum_jetonu: str


class YoneticiTesisRequest(BaseModel):
    kurulum_jetonu: str
    tesis_ad: str = Field(min_length=2, max_length=120, examples=["Oltu Sitesi"])


class RolEpostaBaslaRequest(BaseModel):
    """(§6) Sakin/guvenlik/gorevli kaydinin 1. adimi — E-POSTA ile.

    TELEFONLU KARDESI (`RolKayitBaslaRequest`) DURUYOR ve degistirilmedi.
    Bu ayri bir yol cunku kimlik farkli: orada telefon + SMS, burada
    e-posta + e-posta kodu. SMS gonderilmiyor (bkz. `settings.sms_aktif`).
    """

    tesis_kodu: str = Field(min_length=3, max_length=40, examples=["OLTU-260715"])
    eposta: EmailStr
    rol: str = Field(examples=["resident"])
    #: Yalniz bilgi amacli: kuyruga dusen bir denemede yonetici kimin
    #: denedigini gorsun diye. Dogrulamada KULLANILMAZ.
    ad: str | None = Field(default=None, max_length=120)
    telefon: str | None = Field(default=None, max_length=32)


class RolEpostaBaslaResponse(BaseModel):
    """SONUC YANITTAN OKUNAMAZ — telefon yolundaki kuralin aynisi.

    `tesis_ad` DONER cunku kullanicinin dogru siteye kaydoldugunu
    gormesi gerekir ve tesis kodu ZATEN kamuya aciktir. Ama e-postanin
    listede olup olmadigi HICBIR alandan anlasilmaz: uc, "bu sitede kim
    var" sorgusuna donusmemeli.
    """

    tesis_ad: str
    durum: str = Field(default="kod_gonderildi", examples=["kod_gonderildi"])


class RolEpostaDogrulaRequest(BaseModel):
    tesis_kodu: str = Field(min_length=3, max_length=40)
    eposta: EmailStr
    kod: str = Field(min_length=4, max_length=8)


class RolEpostaDogrulaResponse(BaseModel):
    """Uc sart da tuttuysa `setup_token`, tutmadiysa `onay_bekliyor`.

    TEK YANIT TIPI, IKI SONUC: ayri hata kodlari dondurmek "e-postan
    listede yok" ile "kod yanlis" arasindaki farki disariya sizdirirdi.
    `durum` alani kullaniciya NE YAPACAGINI soyler, hangi sartin
    tutmadigini DEGIL.
    """

    #: hazir | onay_bekliyor
    durum: str = Field(examples=["hazir"])
    #: Yalniz `durum='hazir'` iken dolu — parola belirleme jetonu.
    setup_token: str | None = None


# ======================= (P202) SURUM POLITIKASI ============================ #
class SurumKontrolIstek(BaseModel):
    """Uygulamanin acilista bildirdigi iki sey: KIM ve HANGI SURUM."""

    #: 'ios' | 'android'. Bilinmeyen deger HATA DEGIL — uc "guncel" doner
    #: (gerekce `routers/surum.py`).
    platform: str = Field(max_length=32)
    #: Pakette yazan surum ("1.1.1"). `+yapim` eki kabul edilir, karsilastirmaya
    #: girmez.
    surum: str = Field(max_length=64)


class SurumKontrolYanit(BaseModel):
    """`guncel` | `onerilen` | `zorunlu` + gosterilecekler.

    `mesaj` ve `magaza_url` YALNIZ guncelleme gerektiginde doludur:
    guncel istemciye gonderilen her alan, onun yanlislikla ekran
    cizmesine zemin hazirlar.
    """

    durum: str
    mesaj: str | None = None
    magaza_url: str | None = None
    asgari_surum: str | None = None
    onerilen_surum: str | None = None


def _surum_dogrula(v: str | None) -> str | None:
    """Panelden gelen esik BURADA dogrulanir.

    Gecersiz metni sessizce kabul edip `surum.py`nin "gecersiz esik =
    yok say" davranisina birakmak, operatore "kaydedildi" deyip
    politikayi HIC calistirmamak olurdu — en kotu tur sessiz kusur.
    BOSALTMA serbesttir (bos = o seviye kapali).
    """
    from .surum import ayristir

    if v is None:
        return None
    metin = v.strip()
    if not metin:
        return None
    if ayristir(metin) is None:
        raise ValueError("Surum bicimi gecersiz (ornek: 1.2.0).")
    return metin


class SurumPolitikasiUpdate(BaseModel):
    asgari_surum: str | None = None
    onerilen_surum: str | None = None
    #: dil kodu -> metin. Bos birakilabilir; uygulama kendi metnini kullanir.
    mesaj: dict[str, str] | None = None

    @field_validator("asgari_surum", "onerilen_surum")
    @classmethod
    def _bicim(cls, v: str | None) -> str | None:
        return _surum_dogrula(v)

    @field_validator("mesaj")
    @classmethod
    def _diller(cls, v: dict[str, str] | None) -> dict[str, str] | None:
        if v is None:
            return None
        from .ceviri import DESTEKLENEN_DILLER

        bilinmeyen = sorted(set(v) - set(DESTEKLENEN_DILLER))
        if bilinmeyen:
            raise ValueError(f"Desteklenmeyen dil: {', '.join(bilinmeyen)}")
        # Bos metinler SAKLANMAZ: "girilmedi" ile "bos girildi" ayni sey.
        return {k: m.strip() for k, m in v.items() if m and m.strip()}


class SurumPolitikasiOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    platform: str
    asgari_surum: str | None = None
    onerilen_surum: str | None = None
    mesaj: dict[str, str] = {}


class SurumPolitikasiListesi(BaseModel):
    ogeler: list[SurumPolitikasiOut]
