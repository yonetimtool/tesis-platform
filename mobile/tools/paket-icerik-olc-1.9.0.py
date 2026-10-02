# -*- coding: utf-8 -*-
"""(1.9.0) PAKET ICERIK OLCUMU — UC KODLAMAYLA, GERCEK PAKETE KARSI.

Kullanim:  python3 tools/paket-icerik-olc-1.9.0.py <app-release.apk>

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

# ------------------------------------------------------- P251 §8 MENU PARITESI
eksikler += grup("P251 §8 — MENU: Kisiler tek ekran, Tanimlar, Yonetim", [
    ("Kisiler", "Kişiler"),
    ("sekme: yoneticiler", "Yöneticiler ve denetçiler"),
    ("yonetici ekle", "Yönetici / denetçi ekle"),
    ("rota: kisiler", "/kisiler"),
    ("rota: tanimlar", "/tanimlar"),
    ("rota: tesis ayarlari", "/tesis-ayarlari"),
    ("rota: otomasyon", "/otomasyon"),
    ("rota: bilgisayardan", "/bilgisayardan"),
    ("Bilgisayardan yapilanlar", "Bilgisayardan yapılanlar"),
    ("Tesis ayarlari", "Tesis ayarları"),
    ("ad: otopark", "Otopark ve araç geçişleri"),
    ("ad: olaylar", "Olaylar ve ihlaller"),
    ("devriye (tek ekran)", "Devriye"),
])
# ------------------------------------------------ P251 §11 IZGARA SURUKLE-BIRAK
eksikler += grup("P251 §11 — IZGARA: basili tut, surukle, hesapta", [
    ("uc", "/me/ana-ekran-izgarasi"),
    ("kart oneki", "kart:"),
    ("erisilebilirlik: yukari", "Yukarı taşı"),
    ("erisilebilirlik: asagi", "Aşağı taşı"),
])
# ----------------------------------------------------------- P251 §9 TEK SOS
eksikler += grup("P251 §9 — TEK SOS", [
    ("cekmece etiketi", "SOS"),
])
# --------------------------------------------------------- P251 §5 GORSELLER
eksikler += grup("P251 §5 — GORSELLER (etkinlik, duyuru, rezervasyon alani)", [
    ("alan: foto_key", "foto_key"),
    ("alan: foto_url", "foto_url"),
    ("bekle uyarisi", "Görsel henüz yükleniyor — bitmesini bekleyin veya kaldırın."),
])
# ----------------------------------------------------------------- P250
eksikler += grup("P250 — kurulum videolari, otomasyon, odeme kodu e-postasi, ad/soyad", [
    ("video ucu", "/egitim-videolari"),
    ("video ekrani", "Kurulum videoları"),
    ("otomasyon kurallari", "Otomasyon kuralları"),
    ("otomasyon ucu", "/otomasyon/son-calismalar"),
    ("odeme kodu e-posta ucu", "/users/odeme-kodlari/eposta"),
    ("odeme kodu e-posta dugmesi", "E-posta gönder"),
    ("soyad alani", "soyad"),
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
