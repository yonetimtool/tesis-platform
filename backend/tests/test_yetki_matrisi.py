"""Yetki matrisi ucu (P41) — KODUN KENDISIYLE ayni seyi soyluyor mu?

Bu testin degeri tek bir soruda: panelde gosterilen matris, isteklerin
GERCEKTEN gectigi kapiyla ortusuyor mu? Ucu elle bir listeden beslemek
"ayni gercegi ikinci bir yerden uretmek" olurdu; burada uc ile
`tests/yetki/rol-matrisi.txt` KILIDI karsilastirilir — ikisi ayni
`require_role` cagrilarindan turedigi icin ayrismalari, birinin bozuldugu
anlamina gelir.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

KILIT = Path(__file__).resolve().parent / "yetki" / "rol-matrisi.txt"
#: Kilit dosyasindaki sutun sirasi (basliktan okunur).
SATIR = re.compile(r"^(\w+)\s+(\S+)\s+(.*)$")


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def matris(client, world):
    r = client.get("/yetki-matrisi",
                   headers=_h(client, world["slug_a"], world["admin_a"]))
    assert r.status_code == 200, r.text
    return r.json()


def test_sutun_sirasi_KILITLE_AYNI(matris):
    """Panel ile test kilidi YAN YANA okunabilmeli."""
    baslik = KILIT.read_text(encoding="utf-8").splitlines()[0]
    assert baslik.startswith("#")
    kilit_roller = baslik.lstrip("#").split()
    assert matris["roller"] == kilit_roller


def test_uc_KILITLE_ORTUSUYOR(matris):
    """UCUN OLCTUGU SEY: matris kodun kendisinden uretiliyor mu?

    Kilit, uclari GERCEK isteklerle surerek olculdu (401/403/digeri);
    bu uc ise bagimlilik agacini gezerek uretiyor. Ikisi ayni
    `require_role` cagrilarindan turedigi icin ROL KUMELERI ortusmeli.
    """
    kilit: dict[tuple[str, str], set[str]] = {}
    satirlar = KILIT.read_text(encoding="utf-8").splitlines()
    roller = satirlar[0].lstrip("#").split()
    for ham in satirlar[1:]:
        if not ham.strip():
            continue
        m = SATIR.match(ham)
        assert m, ham
        metot, yol, kalan = m.groups()
        hucreler = kalan.split()
        assert len(hucreler) == len(roller), ham
        kilit[(metot, yol)] = {
            rol for rol, h in zip(roller, hucreler) if h == "IZIN"
        }

    uc = {
        (x["metot"], x["yol"]): (set(x["roller"]) if x["roller"] else None)
        for x in matris["items"]
    }

    sapma: list[str] = []
    for anahtar, kilit_roller in kilit.items():
        if anahtar not in uc:
            # Kilit surulen yollari parametre ADIYLA tasir; uc yolu FastAPI
            # sablonuyla verir. Ortusmeyen anahtar bir SAPMA DEGIL,
            # adlandirma farki olabilir — bu yuzden yalniz ORTAK anahtarlar
            # karsilastirilir ve kapsam ayrica `test_sozlesme_sapmasi` ile
            # olculur.
            continue
        uc_roller = uc[anahtar]
        if uc_roller is None:
            continue  # rol kapisi yok (kimlik kapisi olabilir)
        # Kilit "IZIN" = istek EL HANDLER'A ULASTI. `moda_bagli` uclarda
        # kilit YALNIZ varsayilan modu (yonetim_ici) olcer, uc ise IKI
        # MODUN BIRLESIMINI verir — bu yuzden kilit, ucun ALT KUMESI olmali.
        if not kilit_roller <= uc_roller:
            sapma.append(f"{anahtar}: kilit={sorted(kilit_roller)} uc={sorted(uc_roller)}")
    assert not sapma, "matris ile kilit AYRISTI:\n  " + "\n  ".join(sapma[:10])


def test_MODA_BAGLI_uclar_isaretli(matris):
    """P35: guvenlik yazma uclarinda tek bir rol kumesi YOKTUR; sabit bir
    kume gostermek `dis_sirket` modundaki davranisi YANLIS anlatirdi."""
    modabagli = {(x["metot"], x["yol"]) for x in matris["items"] if x["moda_bagli"]}
    assert ("POST", "/patrol-plans") in modabagli
    assert ("POST", "/shifts") in modabagli
    assert ("POST", "/checkpoints") in modabagli
    # Moda bagli olmayan bir uc yanlislikla isaretlenmemeli.
    assert ("GET", "/patrol-plans") not in modabagli


def test_rol_kapisi_OLMAYANLAR_ayirt_edilir(matris):
    """`roller: null` "herkese acik" DEMEK DEGILDIR — ikisini karistirmak,
    kimliksiz erisilebilir bir uc varmis gibi gostermek olurdu."""
    kapisiz = [x for x in matris["items"] if x["roller"] is None]
    yollar = {x["yol"] for x in kapisiz}
    # /health gercekten kimliksizdir; /me ise KIMLIK ister ama ROL kapisi
    # yoktur — ikisi ayni kovada gorunur ve bu BILINCLIDIR (uc yalniz ROL
    # kapisini olcer).
    assert "/health" in yollar
    assert len(kapisiz) < len(matris["items"]) / 2, "cogunluk kapisiz olamaz"


def test_RBAC_yalniz_yonetim(client, world):
    """Matris tum sistemin yetki haritasidir; saha personeline hangi
    uclarin var oldugunu gostermek gereksiz bir kesif yuzeyi acardi."""
    for rol, izin in [("admin", True), ("yonetici", True),
                      ("guard_a", False), ("resident_a", False),
                      ("amir_a", False)]:
        anahtar = rol if rol.endswith("_a") else f"{rol}_a"
        h = _h(client, world["slug_a"], world[anahtar])
        r = client.get("/yetki-matrisi", headers=h)
        assert (r.status_code == 200) is izin, (rol, r.status_code)


def test_YENI_UC_matriste_KENDILIGINDEN_belirir(matris):
    """Matris koddan uretildigi icin, bu turda eklenen ucun kendisi de
    listede olmali — elle liste tutulsaydi burasi bos kalirdi."""
    yollar = {x["yol"] for x in matris["items"]}
    assert "/yetki-matrisi" in yollar
    # (P154 / Asama 7.2) `/portal` KALDIRILDI; olcum `/anketler` ile
    # surduruluyor (matrisin gercekten dolu geldigini kanitlar).
    assert "/anketler" in yollar and "/ekler" in yollar
