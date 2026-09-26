"""(P130) KIM KIMI YONETEBILIR — hesap yetkisinin TEK kaynagi.

KAPSAM (duzeltme turu): tablo YALNIZ "kim kimi ACAR" degil, "kim kimin
kaydina DOKUNABILIR"i soyler — olusturma, duzenleme, pasiflestirme ve
parola sifirlama AYNI kumeden okur. Eskiden olusturma bu tablodan,
duzenleme ise router icindeki AYRI bir `if` zincirinden geliyordu ve ikisi
AYRISMISTI: yonetici bir SAKINI olusturabiliyor (POST /residents) ama
DUZENLEYEMIYORDU ("yalniz saha personelini duzenleyebilirsiniz"). Kural
tek yerde olmadikca bu tur ayrisma kacinilmazdir.

NEDEN AYRI MODUL: kural bugune kadar `routers/users.py` icinde iki ayri
frozenset olarak yasiyordu (`_YONETICI_CREATABLE_ROLES`,
`_AMIR_CREATABLE_ROLES`) ve UC yerde ayri ayri uygulaniyordu (POST, PATCH ve
panelin acilir listesi). Panelin listesi hicbir yerden turetilmiyordu: TUM
rolleri gosteriyordu, yani bir site yoneticisi "Platform Admin" secenegini
GORUYOR, seciyor ve 403 aliyordu. Sunucu dogru davraniyordu; arayuz yanlis
soz veriyordu.

Kural burada TEK yerde durur; hem uc noktalar hem de `GET /users/
acilabilir-roller` (panelin listesi) bunu okur. Ikinci bir kopya yoktur.

SINIR NEREDE DEGIL: bu tablo YALNIZ "hangi rolde hesap acilabilir"i
soyler. "Hangi YUZEYDE acilabilir" ayri bir karardir (platform admini
YALNIZ `panel.*`ta acilir — P129/P130 web katmani) ve bu tablo onu
bilmez: backend'e `Host` basligina gore karar verdirmek, API'yi kendisini
cagiran istemcinin adresine bagimli kilardi.
"""
from __future__ import annotations

#: Sistemdeki TUM roller (models.USER_ROLE ile AYNI sira).
TUM_ROLLER: tuple[str, ...] = (
    "admin",
    "yonetici",
    "security",
    "tesis_gorevlisi",
    "resident",
    "guvenlik_amiri",
    # (P128) Denetci — tesisin SALT-OKUMA mali gozetimi.
    "denetci",
)

#: yoneten rol -> uzerinde islem yapabildigi roller (olustur/duzenle/
#: pasiflestir/parola sifirla).
#:
#: `yonetici` icin `resident` VARDIR (duzeltme turu). Onceki tur onu
#: bilerek disarida birakmisti: "sakin `POST /residents` ile acilir, oradan
#: acmak DAIRESIZ sakin uretir". Gerekce olusturma icin makuldu ama tablo
#: DUZENLEMEYI de yonettigi icin yan etkisi sakinin profiline hic
#: dokunulamamasi oldu — yonetici kendi tesisindeki sakinin adini bile
#: duzeltemiyordu. Kural artik "yonetici kendi tesisinin sakinini yonetir".
#:
#: DAIRE BAGLANTISI ICIN HÂLÂ `/residents` DOGRU KAPIDIR: `POST /users` ile
#: acilan sakin DAIRESIZ olur (gecici kod + daire baglantisini o uc kurar).
#: Panel sakin olusturmayi oraya yonlendirir; buradaki izin, kaydin
#: SONRADAN duzenlenebilmesi icin gereklidir.
YONETILEBILIR_ROLLER: dict[str, frozenset[str]] = {
    # Platform operatoru: her rol. Tesisin ic isleyisine karisan degil,
    # tesisi KURAN roldur (ilk yoneticiyi de o acar).
    "admin": frozenset(TUM_ROLLER),
    # Site yoneticisi: kendi sahasi. `admin` ve `yonetici` YOK — ikisi de
    # yetki YUKSELTMEsidir (kendi rolunu cogaltmak dahil).
    # (P128/P130) `denetci` BURADA: denetciyi ATAYAN, denetlenen tesisin
    # kendi yonetimidir (site yonetim planinda denetim kurulunu genel kurul
    # secer; uygulamada onu tanimlayan kisi yonetici olur). Platform
    # operatorune baglamak, her denetci degisikligi icin bizi arayan bir
    # tesis demekti.
    # (P213 §6) `guvenlik_amiri` EKLENDI. Onceki tabloda yoktu: amiri
    # YALNIZ platform operatoru (admin) atayabiliyordu, cunku rol P35'te
    # "DIS guvenlik sirketinin amiri" olarak tasarlanmisti ve tesisin ic
    # isi sayilmamisti. Gecmis kayit izleme bu varsayimi bozdu: kayda
    # kimin bakacagina karar veren kisi TESISIN YONETICISIDIR ve her
    # amir degisikligi icin bizi aramasi anlamsizdi.
    #
    # YETKI YUKSELTMESI DEGIL: amirin acabildigi tek rol `security` ve
    # yonetici zaten `security` aciyor. Yani yonetici, amir atayarak
    # KENDINDE OLMAYAN bir yetkiyi kimseye veremez — yalnizca kendi
    # yetkisinin bir alt kumesini devreder.
    "yonetici": frozenset(
        {"resident", "security", "tesis_gorevlisi", "denetci", "yonetici", "guvenlik_amiri"}
    ),
    # (P35) Dis guvenlik sirketinin amiri YALNIZ kendi ekibini acar;
    # `tesis_gorevlisi` bile degil (o site isidir, dis sirketin degil) ve
    # kendi rolunu de acamaz.
    "guvenlik_amiri": frozenset({"security"}),
    # Saha ve sakin rolleri hic hesap acmaz (uc zaten `require_role` ile
    # kapali; tablo bunu ACIKCA yazar ki matris testi bos hucre birakmasin).
    "security": frozenset(),
    "tesis_gorevlisi": frozenset(),
    "resident": frozenset(),
    # Denetci HICBIR hesap acmaz — salt-okuma rolun hesap acmasi, rolun
    # tanimiyla celisirdi.
    "denetci": frozenset(),
}


def yonetilebilir(yoneten_rol: str) -> frozenset[str]:
    """`yoneten_rol`un dokunabildigi roller; taninmayan rol icin BOS kume.

    Bilinmeyen bir rolde bos kume donmek bilinclidir: yeni bir rol eklenip
    tabloya yazilmazsa hicbir sey acamaz (fail-closed). Tersi — varsayilani
    "her sey" yapmak — yeni rolu sessizce en yetkili rol yapardi.
    """
    return YONETILEBILIR_ROLLER.get(yoneten_rol, frozenset())


#: (P248 §1) KAYITTA BEYAN EDILEN ROL AILELERI.
#:
#: OLCULEN KUSUR: yoneticinin DOGRUDAN guvenlik amiri olarak ekledigi kisi
#: mobilde "Kayit ol" dediginde listede kendi rolu yoktu, "Guvenlik"i
#: secti; `_liste_kontrolu` `"guvenlik_amiri" != "security"` gorup
#: `rol_uyusmuyor` ile kisiyi ONAY KUYRUGUNA atti (SSO yolunda ekranda
#: "yonetici onayi bekliyor", e-posta yolunda HIC gelmeyen bir kod).
#: Davet edilmis bir kisi onay beklememeliydi.
#:
#: KURAL: beyan, listedeki rolle AYNI AILEDEYSE eslesmis sayilir. Guvenlik
#: ailesi = gorevli + amir; insanlar ikisini gunluk dilde ayirmaz ("ben
#: guvenlikciyim"). Diger roller tek basina bir ailedir.
#:
#: YETKI YUKSELTMESI YOK: beyan HICBIR ZAMAN yetki vermez. Kaydin sonunda
#: acilan oturumun rolu HER ZAMAN listedeki hesaptan gelir
#: (`rol_eposta_dogrula` beklenen rolu kullanicidan okur, `set-password`
#: jetonu kullanicinin kendi satirindan uretir). "Amir" beyan eden bir
#: guvenlik gorevlisi guvenlik gorevlisi olarak girer; "Guvenlik" beyan
#: eden amir amir olarak girer. Aile disi beyan (sakin <-> guvenlik,
#: gorevli <-> guvenlik) eskisi gibi `rol_uyusmuyor` -> kuyruk.
KAYIT_ROL_AILELERI: tuple[frozenset[str], ...] = (
    frozenset({"security", "guvenlik_amiri"}),
)


def kayit_beyani_eslesir(beyan: str, liste_rolu: str) -> bool:
    """Kayitta BEYAN edilen rol, listedeki hesabin roluyle eslesiyor mu?

    Ayni rol ya da ayni aile (bkz. `KAYIT_ROL_AILELERI`). Eslesme yalniz
    "kisi onaysiz sahiplenebilir mi" sorusunu yanitlar; rolun kendisini
    DEGISTIRMEZ.
    """
    if beyan == liste_rolu:
        return True
    return any(beyan in a and liste_rolu in a for a in KAYIT_ROL_AILELERI)


#: (P231 §2) BIR ROLUN PERSONEL LISTESINDE GOREBILECEGI ROLLER.
#:
#: OLCULEN SIZINTI (P231 §0, canli surulerek): `GET /users` cagiranin
#: ROLUNE GORE SUZMUYORDU. `guvenlik_amiri` ile giris yapip listeyi
#: cektigimde YEDI ROLUN HEPSI geldi — sakin, yonetici, admin, denetci,
#: tesis gorevlisi dahil. Rol P129'dan beri `GET /users`ta IZINLI ve
#: hicbir yerde daraltilmamisti.
#:
#: NEDEN BURADA: ayni soru UC ucta birden soruluyor (`/users`, `/shifts`,
#: `/vardiya-plani/*`). Uc kopya, birinin guncellenip otekinin eskimesi
#: demekti — `MALI_GORUNURLUK`un var olma gerekcesiyle ayni (P133.6).
#:
#: `None` = SINIRSIZ (yonetim rolleri tum personeli gorur).
#:
#: AMIR NEDEN KENDI ROLUNU DE GORUR: `guvenlik_amiri` de guvenlik
#: personelidir. Kumeden cikarmak, amirin KENDISINI ve birlikte calistigi
#: ikinci amiri listede gorememesi demekti — "tesis gorevlisini, sakini,
#: diger calisanlari gormez" kuralini bozmadan.
#:
#: GORMEK != YONETMEK: amir ikinci bir amiri GORUR ama DUZENLEYEMEZ
#: (`YONETILEBILIR_ROLLER["guvenlik_amiri"] == {"security"}`).
GORUNUR_ROLLER: dict[str, frozenset[str] | None] = {
    "admin": None,
    "yonetici": None,
    "denetci": None,
    "guvenlik_amiri": frozenset({"security", "guvenlik_amiri"}),
    # (P232) SAHA ROLLERI ACIKCA YAZILDI — ilk yazimda UNUTULMUSTU ve
    # fail-closed varsayilani onlari da kapsadi: `GET /shifts` cagiran
    # bir guvenlik gorevlisi vardiyadaki PERSONELI BOS goruyordu
    # (`test_shift_assignments` yakaladi, 0 == 2).
    #
    # Kusur sessizdi cunku uc 200 doner ve liste doludur; yalnizca her
    # vardiyanin `personel` alani bosalir. "Bu vardiyada benimle kim
    # var" sorusu VARDIYA DEVRININ kendisidir.
    #
    # NEDEN `None` (sinirsiz): bu kume YALNIZ saha rollerinin ZATEN
    # erisebildigi uclarda (vardiya/cizelge) isler. `/users` onlara
    # `require_role` ile kapali (403) — yani "sinirsiz" demek, personel
    # listesini acmak DEGIL.
    "security": None,
    "tesis_gorevlisi": None,
}


def gorunur_roller(rol: str) -> frozenset[str] | None:
    """`rol`un personel listelerinde gorebilecegi roller; `None` = hepsi.

    TANINMAYAN ROL ICIN BOS KUME (fail-closed): yeni bir rol eklenip
    tabloya yazilmazsa HICBIR personeli gormez. Tersi — varsayilani
    `None` (hepsi) yapmak — yeni rolu sessizce tam gorunurlukle acardi.
    """
    return GORUNUR_ROLLER.get(rol, frozenset())


#: (P133.6) MALI VERIYI GOREBILEN ROLLER — tek kaynak.
#:
#: NEDEN BURADA: "kim parayi gorur" sorusu P133'e kadar IKI yerde
#: yasiyordu — `routers/reports.py` icinde `_YONETIM` ve (P133.2'de
#: eklenen) `routers/dashboard.py` icinde `_MALI_ROLLER`. Ikincisini
#: yazarken yorumuna "kume reports.py'den alinir" diye not dusmustum ama
#: KOD ayri bir literal yaziyordu: yorum tek kaynak vaat ediyor, kod
#: kopyaliyordu. Tam olarak bu modulun (P130) var olma sebebi budur.
#:
#: AYRISMANIN BEDELI SESSIZDIR: biri bir gun `denetci`yi eklerse denetci
#: raporlarda tahsilati gorur ama panoda goremez — ya da tersi. Hicbir
#: test dusmez, kimse fark etmez.
#:
#: SINIR: bu kume "mali OZET gorunur mu"yu soyler. Mali YAZMA (tahakkuk,
#: tahsilat kaydi) ayri bir karardir ve `denetci` oradan BILEREK disaridir
#: (P128: salt-okuma gozetim).
MALI_GORUNURLUK: frozenset[str] = frozenset({"admin", "yonetici"})
