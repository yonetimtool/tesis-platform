# -*- coding: utf-8 -*-
"""(1.8.0) PAKET ICERIK OLCUMU — UC KODLAMAYLA, GERCEK PAKETE KARSI.

Kullanim:  python3 tools/paket-icerik-olc-1.8.0.py <app-release.apk>

Dart AOT'ta bir dizge `OneByteString` ise (tum kod birimleri < 256)
LATIN-1, degilse UTF-16LE saklanir; UTF-8 de denenir (varlik/kaynak).
Tek kodlamayla aramak Turkce karakterli her dizgi icin SAHTE "YOK"
uretir (P237/P240). Bkz. `paket-icerik-olc.py` (1.6.0 surumu).

YONLENDIRME HARITASI SABIT LISTEDEN DEGIL KAYNAKTAN TURETILIR
(P240 dersi): `push_yonlendirme.dart`taki her `case` tipi pakette mi,
hedef rotalar pakette mi, ve backend'in gonderdigi her push kimliginin
(`push_metinleri.METINLER`) mobilde bir yonlendirmesi var mi.
"""
import ast
import pathlib
import re
import subprocess
import sys
import tempfile
import zipfile

APK = pathlib.Path(sys.argv[1]).resolve()
KOK = pathlib.Path(__file__).resolve().parents[1]          # mobile/
BACKEND = KOK.parent / "backend" / "app"

with zipfile.ZipFile(APK) as z:
    SO = z.read("lib/arm64-v8a/libapp.so")
    DEX = b"".join(z.read(n) for n in z.namelist() if re.fullmatch(r"classes\d*\.dex", n))
    MANIFEST_VAR = "AndroidManifest.xml" in z.namelist()


def bul(veri: bytes, s: str):
    vurus = []
    for ad in ("latin-1", "utf-8", "utf-16le"):
        try:
            if s.encode(ad) in veri:
                vurus.append(ad)
        except UnicodeEncodeError:
            pass
    return vurus


def grup(baslik, ogeler, veri=SO):
    print(f"\n=== {baslik}")
    eksik = []
    for etiket, dizge in ogeler:
        v = bul(veri, dizge)
        print(f"  {'VAR ' if v else 'YOK '} {etiket:<38} [{','.join(v) or '-'}]  {dizge!r}")
        if not v:
            eksik.append(f"{baslik}: {etiket}")
    return eksik


eksikler: list[str] = []

# ------------------------------------------------ P249 §1 SOS ALICI DENEYIMI
eksikler += grup("P249 §1 — SOS: iki ekran, Guvendeyim, durum", [
    # Uc `'/panik/$id/$eylem'` kalibiyla kurulur: pakette EYLEM ADI durur
    # (ilk olcum "/guvendeyim" arayip sahte YOK verdi).
    ("uc eylemi: guvendeyim", "guvendeyim"),
    ("uc eylemi: yardim", "yardim"),
    ("uc: durum", "/durum"),
    ("toplu alan", "toplu"),
    ("talimat alani", "talimat"),
    ("benim yanitim", "benim_yanitim"),
    ("dugme: guvendeyim", "GÜVENDEYİM"),
    ("dugme: yardim", "YARDIMA İHTİYACIM VAR"),
    ("talimat basligi", "Ne yapmalısınız"),
    ("durum basligi", "Daire bazında durum"),
    ("alarm rotasi", "/panik-alarm"),
    ("alarm koprusu", "site.yonetio.app/alarm"),
    ("ayar karti", "SOS alarm ayarları"),
    ("ayar: tam ekran", "Kilit ekranında tam ekran aç"),
    ("ayar: kritik bekliyor", "Apple onayı bekleniyor. O zamana kadar alarm Odak modunu deler ama telefon sessizdeyken ÇALMAZ."),
    ("push tipi: yardim talebi", "panik_yardim_talebi"),
    ("cihaz alani: kritik uyari", "kritik_uyari"),
])
eksikler += grup("P249 §1c — ANDROID YEREL ALARM (classes.dex)", [
    ("alarm kanali", "yonetio_alarm_v1"),
    ("acilis eki", "sos_panik_id"),
    ("yerel alarm isareti", "yerel_alarm"),
    ("kopru kanali", "site.yonetio.app/alarm"),
], veri=DEX)

# ------------------------------------------------------------ P249 §2 TATBIKAT
eksikler += grup("P249 §2 — TATBIKAT", [
    ("uc", "/tatbikat"),
    ("baslik", "Tatbikatlar"),
    ("planla", "Tatbikat planla"),
    ("serit", "TATBİKAT — Bu gerçek bir alarm değildir"),
    ("tatbikat alani", "tatbikat"),
    ("push tipi: duyuru", "panik_tatbikat_duyuru"),
])

# -------------------------------------------------- P249 §3 DAIREYE ULASMA
eksikler += grup("P249 §3a — ZIYARETCI ONAYI", [
    ("uc soneki", "/onay"),
    ("istek alani", "onay_iste"),
    ("durum alani", "onay_durum"),
    ("secenek", "Sakinlerden onay iste (3 dk)"),
    ("onayla", "Onayla"),
    ("reddet", "Reddet"),
    ("push tipi: istek", "ziyaretci_onay_istegi"),
    ("push tipi: yanit", "ziyaretci_onay_yaniti"),
])
eksikler += grup("P249 §3b — SESLI MESAJ", [
    ("uc", "/sesli-mesaj"),
    ("yukleme soneki", "/sesli-mesaj/yukleme"),
    ("icerik turu", "audio/mp4"),
    ("ekran", "Sesli mesajlar"),
    ("kayit dugmesi", "Basılı tut, konuş, bırak (en fazla 60 sn)"),
    ("push tipi", "sesli_mesaj"),
    ("kayit eklentisi kanali", "com.llfbandit.record/messages"),
])
eksikler += grup("P249 §3e — TELEFON YEDEGI", [
    ("uc soneki", "/ulas/telefon"),
    ("ozet ucu soneki", "/ulas"),
    ("izin alani", "yonetim_arayabilir"),
    ("ayar", "Yönetim beni bu numaradan arayabilir"),
    ("ekran", "Daireye ulaş"),
])

# -------------------------------------------------- §8 JETON GUVENLI DEPODA
eksikler += grup("JETON SAKLAMA (token_storage) — Dart tarafi", [
    ("erisim anahtari", "auth.access_token"),
    ("yenileme anahtari", "auth.refresh_token"),
    ("hatirla bayragi", "auth.remember_me"),
    ("kimlik on-doldurma", "auth.saved_phone"),
    # Eski surumun parolasi YALNIZ SILMEK icin adlandiriliyor.
    ("eski parola (silinmek icin)", "auth.saved_password"),
    ("guvenli depo kanali", "plugins.it_nomads.com/flutter_secure_storage"),
])
# SINIF ADIYLA ARANMAZ: yayin yapiminda R8 eklenti sinifinin tanimlayicisini
# yeniden adlandiriyor (ilk olcum "YOK" dedi, eklenti oradaydi). Kucultmeden
# SAG CIKAN dizgiler: eklentinin paket-onekli is adi, yapilandirma sinifinin
# toString'i ve Keystore saglayici adi.
eksikler += grup("JETON SAKLAMA — Android yerel eklenti (classes.dex)", [
    ("eklenti paketi", "com.it_nomads.fluttersecurestorage"),
    ("eklenti yapilandirmasi", "FlutterSecureStorageConfig{"),
    ("Keystore saglayici", "AndroidKeyStore"),
], veri=DEX)
# Jeton anahtarlari SharedPreferences eklentisi uzerinden YAZILMAMALI:
# SharedPreferences dizgi onekinin jeton anahtariyla YAN YANA gecmesi
# aranir (ayni sabit havuzunda "flutter.auth.access_token").
kacak = [s for s in ("flutter.auth.access_token", "flutter.auth.refresh_token")
         if bul(SO, s) or bul(DEX, s)]
print(f"\n=== JETON SharedPreferences'ta DEGIL: {'EVET' if not kacak else 'HAYIR ' + str(kacak)}")
if kacak:
    eksikler += [f"jeton SharedPreferences: {k}" for k in kacak]

# ------------------------------------------ §7 BILDIRIM YONLENDIRME HARITASI
kaynak = (KOK / "lib/src/routing/push_yonlendirme.dart").read_text()
tipler = sorted(set(re.findall(r"case '([a-z0-9_]+)':", kaynak)))
eksikler += grup(f"BILDIRIM YONLENDIRME HARITASI ({len(tipler)} tip, kaynaktan)",
                 [(t, t) for t in tipler])

router = (KOK / "lib/src/routing/app_router.dart").read_text()
rotalar = dict(re.findall(r"static const (\w+) = '([^']+)';", router))
kullanilan = sorted(set(re.findall(r"AppRoutes\.(\w+)", kaynak)))
eksikler += grup(f"YONLENDIRME HEDEF ROTALARI ({len(kullanilan)})",
                 [(r, rotalar[r]) for r in kullanilan if r in rotalar])

# Backend'in gonderdigi her push kimliginin mobilde yonlendirmesi var mi.
metin = (BACKEND / "push_metinleri.py").read_text()
kimlikler: set[str] = set()
for n in ast.walk(ast.parse(metin)):
    hedef = getattr(n, "target", None) or (getattr(n, "targets", None) or [None])[0]
    if getattr(hedef, "id", "") == "METINLER" and isinstance(n.value, ast.Dict):
        kimlikler = {k.value for k in n.value.keys if isinstance(k, ast.Constant)}
# Yonlendirme `data.tip` ile yapilir ve tip kimlikle HER ZAMAN ayni
# degildir: `yeni_talep` -> tip "talep", `erisim_onaylandi/reddedildi` ->
# "erisim_sonuc", kategorili panik -> "panik_alarm". Kaynaktaki her
# `dispatch_external("<kimlik>", ..., data={"tip": "<tip>"...})` cagrisi
# okunur; literal tipi olmayan (degisken) kimlikte tip = kimlik varsayilir.
eslem: dict[str, set[str]] = {}
for f in BACKEND.rglob("*.py"):
    # Kimlik bir KOSULLU ifade olabilir: `"a" if onay else "b"`.
    for m in re.finditer(
        r'dispatch_external\(\s*("[a-z0-9_]+"(?:\s+if\s+[\w.]+\s+else\s+"[a-z0-9_]+")?)'
        r'(.{0,600}?)data=\{"tip":\s*"([a-z0-9_]+)"',
        f.read_text(), re.S,
    ):
        if "dispatch_external(" not in m.group(2):   # baska cagriya tasmasin
            for kimlik in re.findall(r'"([a-z0-9_]+)"', m.group(1)):
                eslem.setdefault(kimlik, set()).add(m.group(3))
gonderilen = {t for ts in eslem.values() for t in ts}
# (1.8.0) KIMLIGI DEGISKEN OLAN cagrilar (`dispatch_external(kimlik, ...)`)
# ve `METINLER.update(...)` ile uretilen metinler yukaridaki desene girmez;
# backend'de LITERAL yazilmis HER `data={"tip": ...}` degeri de sayilir.
for f in BACKEND.rglob("*.py"):
    gonderilen |= set(re.findall(r'data=\{"tip":\s*"([a-z0-9_]+)"', f.read_text()))
gonderilen |= {k for k in kimlikler
               if k not in eslem and not k.startswith("panik_kategori_")}
# Yonlendirmesi BILEREK olmayanlar: teshis/test ve web-yalniz iletisim formu.
BILEREK = {"test", "portal_iletisim"}
yonsuz = sorted(gonderilen - set(tipler) - BILEREK)
print(f"\n=== BACKEND PUSH TIPLERI -> MOBIL YONLENDIRME ({len(gonderilen)} tip)")
print(f"  yonlendirmesi olmayan: {yonsuz or 'YOK'}")
eksikler += [f"yonlendirmesi yok: {k}" for k in yonsuz]

print("\n" + "=" * 60)
print("EKSIK:", eksikler if eksikler else "YOK — hepsi pakette")
sys.exit(1 if eksikler else 0)
