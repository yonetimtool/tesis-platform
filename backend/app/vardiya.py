"""(P203 §4) VARDIYA PLANLAMA KURALLARI — cakisma ve calisma suresi.

===========================================================================
GECEYI ASAN VARDIYA
===========================================================================
`shift.bitis_saat <= baslangic_saat` ise vardiya ERTESI GUNE tasar
(20:00-08:00). Bunu gormezden gelmek, gece vardiyasini "eksi saat"
sayardi ve hem cakisma hem sure hesabini sessizce bozardi.

===========================================================================
IKI KURAL, IKI FARKLI SERTLIK — GEREKCESI IS HUKUKUNDA
===========================================================================
1. CAKISMA -> KESIN RED (422).
   Ayni kisi ayni anda iki yerde olamaz; bu bir tercih degil, fiziksel
   bir imkansizlik. Uyari verip gecmek, planin kendisini yalan yapardi.

2. GUNLUK 11 SAAT -> UYARI, RED DEGIL. (DUZELTILDI — asagiya bak.)

   ILK YAZIMDA KESIN RED yapilmisti. Akis CALISTIRILINCA goruldu ki bu
   karar ozelligi HEDEF KULLANICISI ICIN KULLANILAMAZ yapiyor:

       20:00-08:00 gece vardiyasi = 12 saat -> TEK BASINA reddediliyordu

   Guvenlik sektorunde 12 saatlik vardiya STANDART kaliptir ve
   fiilen 1 saat ara dinlenmeyle 11 saat calismadir. Model ARA
   DINLENMEYI BILMIYOR: 12 saatlik bir kaydin 11 saat calisma mi yoksa
   12 saat calisma mi oldugunu AYIRT EDEMEZ.

   Dogrulayamadigimiz bir seyi "kanuna aykiri" diye reddetmek, mesru ve
   yaygin bir plani imkansiz kilmak olurdu. Bu yuzden UYARI: yonetici
   gorur, kararini kendi verir.

   Kesin red yalniz DOGRULAYABILDIGIMIZ sey icin: CAKISMA.

3. HAFTALIK 45 SAAT -> UYARI, RED DEGIL.
   Md. 63 haftalik normal calisma suresini 45 saat sayar; USTU FAZLA
   MESAIDIR ve iscinin onayiyla YASALDIR (md. 41, yilda 270 saat
   tavaniyla). Yani 45 saati asmak bir HATA DEGIL, BIR MALIYETTIR —
   ve §5 tam olarak onu hesaplayip gidere yaziyor. Engellemek,
   sistemin desteklemesi gereken mesru bir durumu imkansiz kilardi.

Ayrimin ozeti: YALNIZ DOGRULAYABILDIGIMIZ IMKANSIZLIK (cakisma)
engellenir. Sure sinirlari UYARILIR — cunku modelde ara dinlenme yok ve
"11 saati asti" dedigimiz sey aslinda 11 saat calisma olabilir.

GECE CALISMASI (md. 69, 7.5 saat) BILINCLI OLARAK UYGULANMADI: "gece
donemi" tanimi (20:00-06:00) ve istisnalari (turizm, saglik, guvenlik
hizmetleri) burada saglikli modellenemez ve yanlis bir kesin red,
guvenlik sektorunde mesru bir plani engellerdi. Uyari listesine de
konmadi cunku dogrulanamayan bir uyari, gurultu uretip otekileri de
okunmaz yapardi. Kayit altina aliniyor: gerekirse ayri bir tur.
"""
from __future__ import annotations

import datetime as dt

#: (4857/63) Gunluk calisma tavani. UYARI esigi — RED DEGIL: model ara
#: dinlenmeyi bilmedigi icin 12 saatlik bir vardiyanin 11 saat calisma
#: olup olmadigini AYIRT EDEMEZ (gerekce modul basliginda).
GUNLUK_AZAMI_SAAT = 11.0

#: (4857/63) Haftalik NORMAL sure. Ustu fazla mesaidir — YASAL ama
#: MALIYETLI; engellenmez, UYARILIR.
HAFTALIK_NORMAL_SAAT = 45.0


def vardiya_araligi(
    tarih: dt.date, baslangic: dt.time, bitis: dt.time
) -> tuple[dt.datetime, dt.datetime]:
    """Vardiyanin GERCEK baslangic/bitis damgasi.

    GECEYI ASAN VARDIYA: bitis <= baslangic ise ERTESI GUNE tasar.
    Bunu atlamak 20:00-08:00'i "-12 saat" yapardi.
    """
    bas = dt.datetime.combine(tarih, baslangic)
    son = dt.datetime.combine(tarih, bitis)
    if son <= bas:
        son += dt.timedelta(days=1)
    return bas, son


def saat_farki(bas: dt.datetime, son: dt.datetime) -> float:
    return (son - bas).total_seconds() / 3600.0


def cakisiyor_mu(
    a: tuple[dt.datetime, dt.datetime], b: tuple[dt.datetime, dt.datetime]
) -> bool:
    """Iki aralik KESISIYOR mu.

    UC UCA EKLENEN vardiyalar (08:00-16:00 ve 16:00-24:00) CAKISMAZ:
    sinir ANI paylasmak, ayni anda iki yerde olmak DEGILDIR. `<` ve `>`
    yerine `<=` kullanmak, mesru bir devir teslimi engellerdi.
    """
    return a[0] < b[1] and b[0] < a[1]


def plan_araligi(plan, shift) -> tuple[dt.datetime, dt.datetime]:
    """(P205 §2) BIR PLAN SATIRININ gercek zaman araligi — TEK KURAL.

    Saat iki yerden gelebilir ve oncelik NETTIR:
      1. SATIRIN KENDI saatleri (serbest vardiya ya da o gunluk sapma),
      2. yoksa SABLONUN saatleri.

    Bu secim uc yerde lazim (cizelge, cakisma denetimi, mesai hesabi) ve
    orada ayri ayri yazilsaydi, birinde unutulan bir dal saatleri
    sessizce sablondan okur — yani kullanicinin yazdigi saat KAYBOLURDU.
    """
    bas = plan.baslangic_saat or (shift.baslangic_saat if shift else None)
    son = plan.bitis_saat or (shift.bitis_saat if shift else None)
    if bas is None or son is None:
        # Goc 0096'daki CHECK bunu engelliyor; yine de sessiz bir 0 saat
        # yerine ACIK hata: saati olmayan bir vardiya, cakisma ve mesai
        # hesabinda gorunmez bir bosluk olurdu.
        raise ValueError("vardiya plani satirinin saati yok")
    return vardiya_araligi(plan.tarih, bas, son)


def gece_asiyor_mu(bas: dt.time, son: dt.time) -> bool:
    """22:00-05:00 gibi ERTESI GUNE tasan vardiya mi?"""
    return son <= bas
