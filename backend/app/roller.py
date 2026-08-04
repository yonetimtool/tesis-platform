"""(P130) KIM KIMI ACABILIR — hesap olusturma yetkisinin TEK kaynagi.

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

#: acan rol -> `POST /users` ile acabildigi roller.
#:
#: `yonetici` icin `resident` bilerek YOKTUR: sakin hesabi `POST /residents`
#: ile acilir, cunku daire baglantisini (ve gecici kodu) o uc kurar. Buradan
#: acmak DAIRESIZ bir sakin uretirdi. Yoneticinin sakin acma yetkisi
#: kisitlanmis degildir — sadece dogru kapidan gecer.
#:
#: `admin` icin `resident` VARDIR: platform operatorunun destek amaciyla
#: (veri kurtarma, hatali kayit onarimi) daireye baglamadan hesap acmasi
#: gerekebilir; tesis yoneticisi icin ayni gerekce yoktur.
ACILABILIR_ROLLER: dict[str, frozenset[str]] = {
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
    "yonetici": frozenset({"security", "tesis_gorevlisi", "denetci"}),
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


def acilabilir(acan_rol: str) -> frozenset[str]:
    """`acan_rol`un acabildigi roller; taninmayan rol icin BOS kume.

    Bilinmeyen bir rolde bos kume donmek bilinclidir: yeni bir rol eklenip
    tabloya yazilmazsa hicbir sey acamaz (fail-closed). Tersi — varsayilani
    "her sey" yapmak — yeni rolu sessizce en yetkili rol yapardi.
    """
    return ACILABILIR_ROLLER.get(acan_rol, frozenset())
