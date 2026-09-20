# -*- coding: utf-8 -*-
"""(P221/P237/P240) PAKET ICERIK OLCUMU — UC KODLAMAYLA.

Dart AOT'ta bir dizge `OneByteString` ise (tum kod birimleri < 256)
LATIN-1, degilse UTF-16LE saklanir. Tek kodlamayla aramak, Turkce
karakter tasiyan her dizge icin SAHTE "YOK" uretir — P237 ve P240'ta
tam olarak bu oldu. UTF-8 de denenir (varlik/kaynak metinleri).
"""
import sys

VERI = open(sys.argv[1], 'rb').read()

def bul(s: str):
    vurus = []
    for ad, kod in (("latin-1", "latin-1"), ("utf-8", "utf-8"), ("utf-16le", "utf-16le")):
        try:
            if s.encode(kod) in VERI:
                vurus.append(ad)
        except UnicodeEncodeError:
            pass
    return vurus

def grup(baslik, ogeler):
    print(f"\n=== {baslik}")
    eksik = []
    for etiket, dizge in ogeler:
        v = bul(dizge)
        durum = "VAR " if v else "YOK "
        print(f"  {durum} {etiket:<34} [{','.join(v) or '-'}]  {dizge!r}")
        if not v:
            eksik.append(etiket)
    return eksik

eksikler = []

eksikler += grup("P241 §1 — PERIYODIK BAKIM", [
    ("ekran basligi", "Periyodik bakım"),
    ("bos durum", "Bakımı izlenecek ekipman yok."),
    ("bos durum rehberi (§6c)", "Asansör, jeneratör gibi demirbaşları ekleyip periyot tanımlayın."),
    ("rota", "/bakim"),
])

eksikler += grup("P241 §2 — VARDIYA YENIDEN TASARIM / IZIN SEKMESI", [
    ("izin sekmesi", "İzinli"),
    ("izin ekle", "İzin ekle"),
    ("izin turu", "İzin türü"),
    ("yillik izin", "Yıllık izin"),
    ("taslak/yayinla", "Yayınla"),
    ("mola", "Mola"),
])

eksikler += grup("P243 §5 — KATEGORILI SOS", [
    ("kategori sorusu", "Ne oluyor?"),
    ("kategori aciklamasi", "Kategori seçin; alarmı alan kişi ne yapacağını görsün."),
    ("deprem", "Deprem"),
    ("yangin", "Yangın"),
    ("gaz kacagi", "Gaz kaçağı"),
    ("saglik", "Sağlık"),
    ("guvenlik tehdidi", "Güvenlik tehdidi"),
    ("tahliye", "Tahliye"),
    ("diger", "Diğer"),
    ("site geneli rozeti", "Tüm siteye gider"),
    ("ekip rozeti", "Yönetim ve güvenliğe gider"),
    # Sunucunun kategori KIMLIKLERI (goc 0146) — arayuz etiketi degil,
    # tele giden deger. Ikisi ayri: etiket cevrilir, kimlik cevrilmez.
    ("kimlik: deprem", "deprem"),
    ("kimlik: yangin", "yangin"),
    ("kimlik: gaz", "gaz"),
    ("kimlik: tahliye", "tahliye"),
    ("kimlik: saglik", "saglik"),
    ("kimlik: guvenlik_tehdidi", "guvenlik_tehdidi"),
    ("kimlik: diger", "diger"),
])

eksikler += grup("P243 §6d — ONBOARDING TURU", [
    ("tur basligi", "Yönetio'ya hoş geldiniz"),
    ("1. ekran", "Önce bloklar ve daireler"),
    ("2. ekran", "Kişiler davetle girer"),
    ("3. ekran", "Aidat ve tahsilat, hazır olunca"),
    ("4. ekran", "Kurulum sihirbazı yanınızda"),
    ("atla", "Turu atla"),
    ("tekrar ac", "Tanıtım turunu tekrar göster"),
])

eksikler += grup("P243 §6a — ASGARI KURULUM", [
    ("asgari baslik", "Başlamak için gerekenler"),
    ("sonra yapilabilecekler", "Şunları da yapabilirsiniz"),
])

eksikler += grup("P243 §3 — ICE AKTARIM (mobil yuzeyi)", [
    ("bilgisayardan uyarisi", "Toplu aktarım bilgisayardan yapılır. 200 satırlık bir önizlemeyi telefonda doğrulamak mümkün değil."),
])

# ---------------------------------------------------------------- yonlendirme
YONLENDIRME = [
    "kacirilan_tur", "eksik_checkpoint", "gecikmis_okutma",
    "talep_is_emri", "talep_cozuldu", "talep_reddedildi",
    "is_emri_atandi", "gorev_atandi", "gorev_tamamlandi",
    "gorev_adim_ilerleme", "uzak_okutma",
    "kargo", "ziyaretci", "rezervasyon", "sikayet_cozuldu",
    "panik_alarm", "panik_yanlis_alarm", "panik_kapandi",
    "akilli_ev_kacak", "akilli_ev_yangin",
    "entegrasyon_koptu",
    "bakim_yaklasti", "bakim_bugun", "bakim_gecikti",
    "vardiya_yayinlandi",
]
eksikler += grup("BILDIRIM YONLENDIRME HARITASI (25 tip)",
                 [(t, t) for t in YONLENDIRME])

HEDEF = ["/patrol-tracking", "/complaints", "/tasks", "/kargo", "/visitors",
         "/panik-takip", "/akilli-ev", "/integrations", "/bakim",
         "/vardiya-plani"]
eksikler += grup("YONLENDIRME HEDEF ROTALARI", [(r, r) for r in HEDEF])

print("\n" + "=" * 60)
print("EKSIK:", eksikler if eksikler else "YOK — hepsi pakette")
sys.exit(1 if eksikler else 0)
