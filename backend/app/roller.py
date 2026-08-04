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
    "yonetici": frozenset({"resident", "security", "tesis_gorevlisi", "denetci"}),
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
