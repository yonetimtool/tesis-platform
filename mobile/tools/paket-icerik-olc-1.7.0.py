# -*- coding: utf-8 -*-
"""(1.7.0) PAKET ICERIK OLCUMU — UC KODLAMAYLA, GERCEK PAKETE KARSI.

Kullanim:  python3 tools/paket-icerik-olc-1.7.0.py <app-release.apk>

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

eksikler += grup("P247 §2 — ROL GECISI (yonetici <-> sakin)", [
    ("uc", "/me/rol-gecis"),
    ("roller alani", "roller"),
    ("push hedef rolu", "hedef_rol"),
    ("menu basligi", "Görünüm"),
    ("perde (sakin)", "Sakin moduna geçiliyor…"),
    ("perde (yonetici)", "Yönetici moduna geçiliyor…"),
    ("bildirim", "Sakin moduna geçildi"),
    ("hata", "Mod değiştirilemedi. Lütfen tekrar deneyin."),
])

eksikler += grup("P247 §1 — DONGU ATA DIYALOGU", [
    ("uc: uygula", "/vardiya-plani/dongu-uygula"),
    ("uc: atamalar", "/vardiya-plani/dongu-atamalari"),
    ("dugme", "Döngü / rotasyon"),
    ("baslik", "Vardiya döngüsü (rotasyon)"),
    ("hazir 2-2-2", "2 gece · 2 gündüz · 2 tatil"),
])

eksikler += grup("SIFREMI UNUTTUM (E2E)", [
    ("uc: kod iste", "/auth/sifre/kod-iste"),
    ("uc: dogrula", "/auth/sifre/dogrula-ve-ayarla"),
    ("baslik", "Şifremi Unuttum"),
    ("kur dugmesi", "Parolayı güncelle"),
])

eksikler += grup("DAVETLER (E2E)", [
    ("uc", "/davetler"),
    ("aciklama", "Gönderilen davetler ve durumları."),
    ("tesis kodu kopyala", "Tesis kodunu kopyala"),
])

eksikler += grup("GURULTU UYARILARI (E2E)", [
    ("uc", "/unit-uyarilari"),
    ("aciklama", "Eşiği aşan gürültü şikâyetleri ve anons durumları."),
    ("bos durum", "Henüz eşik aşılmadı."),
])

eksikler += grup("P247 §3 — KARGO / ZIYARETCI KAPANISI", [
    ("kargo teslim dugmesi", "Teslim et"),
    ("kargo gecikmis rozeti", "Gecikmiş"),
    ("teslim alan alani", "teslim_alan_user_id"),
    ("gecikmis alani", "gecikmis"),
    ("push tipi", "kargo_teslim"),
    ("ziyaretci cikis dugmesi", "Çıkış yaptı"),
    ("otomatik kapanis etiketi", "Çıkış kaydedilmedi"),
    ("otomatik alan", "cikis_otomatik"),
    ("cikis ucu soneki", "/checkout"),
])

eksikler += grup("P247-bekleyen 1.2 — DAIRE NOTU SAHA ISARETI", [
    ("bolum basligi", "Daire notları"),
    ("isaret etiketi", "Güvenlik ve tesis görevlileri bu notu görebilir"),
    ("isaret aciklamasi", "İşaretlemezseniz not yalnızca yönetim tarafından görülür. Borç, anlaşmazlık veya kişisel bilgi içeren notları işaretlemeyin."),
    ("alan", "saha_gorebilir"),
])

eksikler += grup("P247 §7 — GORUNUM ESITLEME / §4 OTURUM", [
    ("gorunum ucu", "/me/gorunum"),
    ("hesap alani", "ui_gorunum"),
    ("parola ucu", "/me/password"),
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
