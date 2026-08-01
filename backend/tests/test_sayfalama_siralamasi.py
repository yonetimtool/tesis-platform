"""(P106) SAYFALI SORGULARDA KARARLI SIRALAMA — çırçır kilidi.

`ORDER BY created_at DESC LIMIT n OFFSET m` sıralaması **kararsızdır**:
eşit değerli satırların birbirine göre sırası Postgres tarafından garanti
edilmez. Sonuç, sayfalar arasında **tekrarlayan ve kaybolan satırlardır** —
yönetici ikinci sayfada aynı talebi yeniden görür, bir başkasını hiç
görmez ve hiçbir yerde hata çıkmaz.

Eşitlik nadir sanılır ama **toplu üretilen satırlar aynı `created_at`i
paylaşır**: toplu borçlandırma, Excel ile site aktarımı, seed. Yani kusur
tam olarak en çok satırın olduğu yerde ortaya çıkar.

`ad`/`no`/`kod` gibi kolonlarda eşitlik **normaldir** (aynı isimli iki
kategori, aynı numaralı iki daire farklı bloklarda).

DURUM: 12 sorgu düzeltildi (ad/no/kod/plaka ile sıralananlar). Kalanlar
`created_at`/zaman damgası ile sıralanıyor ve tek turda hepsine dokunmak
40'tan fazla uç davranışını aynı anda değiştirmek olurdu. Bu yüzden bir
**çırçır**: sayı ARTAMAZ; yeni uç eklerken kararlı sıralama zorunludur.
"""
import pathlib
import re

KOK = pathlib.Path(__file__).resolve().parents[1] / "app" / "routers"

#: Ölçülen kalan sayı. AZALTILABILIR, ARTIRILAMAZ.
ESIK = 42


def _kararsiz_sorgular() -> list[str]:
    bulgu: list[str] = []
    for yol in sorted(KOK.glob("*.py")):
        satirlar = yol.read_text(encoding="utf-8").split("\n")
        for i, satir in enumerate(satirlar):
            if "order_by(" not in satir:
                continue
            pencere = "\n".join(satirlar[i : i + 4])
            if ".limit(" not in pencere and ".offset(" not in pencere:
                continue
            if re.search(r"order_by\([^)]*\.id\b", pencere):
                continue
            bulgu.append(f"{yol.name}:{i + 1}")
    return bulgu


def test_kararsiz_sayfalama_ARTMIYOR():
    kalan = _kararsiz_sorgular()
    assert len(kalan) <= ESIK, (
        f"Kararli siralamasi olmayan sayfali sorgu sayisi ARTTI "
        f"({len(kalan)} > {ESIK}). Yeni uclarda `order_by(..., Model.id)` "
        f"kullanin.\n" + "\n".join(kalan[:15])
    )


def test_esik_GERCEKCI(pytestconfig=None):
    """Esik, gercek sayidan cok buyuk olmamali.

    Cok yuksek bir esik circiri islevsiz kilar: 42 yerine 200 yazsaydim
    kilit hicbir sey tutmazdi. Esigin gercege YAKIN olmasi, kilidin
    yasadigini gosterir.
    """
    kalan = _kararsiz_sorgular()
    assert ESIK - len(kalan) <= 3, (
        f"Esik ({ESIK}) gercek sayidan ({len(kalan)}) fazla uzak — "
        "duzeltmeler yapildiysa esigi de indirin."
    )
