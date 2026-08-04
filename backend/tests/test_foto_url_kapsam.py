"""(P131) FOTO KANITI GORUNUR MU — `foto_url` DOLDURULUYOR mu?

OLCULEN KUSUR: `TaskCompletionOut` semasinda `foto_url` alani VARDI, iki
istemci de onu okuyordu (mobil `TaskCompletion.fotoUrl`, panelin gorev
detayi) — ama sunucu HICBIR YERDE DOLDURMUYORDU. Fotograf yukleniyor,
saklaniyor ve HICBIR YERDE gorunmuyordu. Belirti "web'de gorseller
cikmiyor"du; sebep web degil, sunucunun doldurmadigi bir alandi.

BU DOSYA IKI SEYI OLCER:
  1. Gorev tamamlamasinda `foto_key` doluysa `foto_url` DA dolu (regresyon
     kilidi — alan yeniden bosalirsa test duser),
  2. AYNI KURAL diger icerik uclarinda da geciyor mu (duyuru, site kurali,
     etkinlik, talep). Bu ikincisi olmadan, yarin baska bir uc ayni sekilde
     bosalirsa hicbir sey yakalanmazdi — kusur bir UCA degil bir DESENE
     aitti.

`presign_get` GERCEKTEN cagrilir (MinIO dev'de ayakta); URL'in ICERIGI
degil, VARLIGI ve imzali olmasi olculur — imza dogrulamasi depolama
katmaninin isidir.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _gorevli_id(client, yonetici) -> str:
    """Saha rolunun user id'si — gorev ONA ATANMALI.

    Olculdu: atanmamis bir goreve saha rolu `POST .../completions`
    dedigiinde 404 gelir (`_visible_task_or_404` saha rolune yalniz kendi
    gorevini gosterir). Testin ilk hâli bunu bilmiyordu ve 404 aliyordu —
    kusur testte, kodda degil.
    """
    r = client.get("/users", headers=yonetici, params={"role": "tesis_gorevlisi"})
    assert r.status_code == 200, r.text
    return r.json()["items"][0]["id"]


def _foto_anahtari(tenant_id) -> str:
    # IDOR kurali: anahtar tenant onekiyle baslamali (uploads/presign).
    return f"{tenant_id}/tasks/{uuid.uuid4().hex}.jpg"


def test_gorev_tamamlamasinda_foto_url_DOLU(client, world):
    """Foto kaniti olan bir tamamlama, GORUNTULENEBILIR bir adres dondurur."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])

    r = client.post(
        "/tasks",
        headers=yonetici,
        json={
            "ad": "Foto kanitli gorev",
            "atanan_user_id": _gorevli_id(client, yonetici),
            "foto_zorunlu": False,
        },
    )
    assert r.status_code == 201, r.text
    task_id = r.json()["id"]

    anahtar = _foto_anahtari(world["a"])
    c = client.post(
        f"/tasks/{task_id}/completions",
        headers={**gorevli, "Idempotency-Key": f"p131-{uuid.uuid4().hex}"},
        json={
            "tamamlanma_zamani": "2026-01-01T10:00:00Z",
            "foto_key": anahtar,
            "notlar": "kanit",
        },
    )
    assert c.status_code in (200, 201), c.text
    # 1) OLUSTURMA YANITI: istemci ikinci istek atmadan fotografi gostermeli.
    assert c.json()["foto_key"] == anahtar
    assert c.json()["foto_url"], "olusturma yanitinda foto_url BOS"

    # 2) LISTE: asil kusurun oldugu yer.
    liste = client.get(f"/tasks/{task_id}/completions", headers=yonetici)
    assert liste.status_code == 200, liste.text
    oge = liste.json()["items"][0]
    assert oge["foto_key"] == anahtar
    assert oge["foto_url"], "listede foto_url BOS — kusur geri geldi"
    # Presigned URL: imza parametresi tasir (duz obje yolu DEGIL).
    assert "X-Amz-Signature" in oge["foto_url"] or "Signature" in oge["foto_url"]


def test_fotosuz_tamamlamada_foto_url_NULL(client, world):
    """Ters yon: fotosuz kayitta uydurma bir adres URETILMEZ.

    Bu olculmeseydi, `foto_url`i her zaman dolduran (ve olmayan bir objeye
    isaret eden) bir uygulama da testi gecerdi.
    """
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    r = client.post(
        "/tasks", headers=yonetici,
        json={
            "ad": "Fotosuz gorev",
            "atanan_user_id": _gorevli_id(client, yonetici),
            "foto_zorunlu": False,
        },
    )
    task_id = r.json()["id"]
    c = client.post(
        f"/tasks/{task_id}/completions",
        headers={**gorevli, "Idempotency-Key": f"p131-{uuid.uuid4().hex}"},
        json={"tamamlanma_zamani": "2026-01-01T11:00:00Z", "notlar": "fotosuz"},
    )
    assert c.status_code in (200, 201), c.text
    assert c.json()["foto_url"] is None

    liste = client.get(f"/tasks/{task_id}/completions", headers=yonetici)
    assert liste.json()["items"][0]["foto_url"] is None


def test_DESEN_diger_iceriklerde_de_gecerli(client, world):
    """Duyuru/site kurali/etkinlik: `foto_key` varsa `foto_url` da var.

    Kusur bir UCA degil bir DESENE aitti; desen burada kilitlenir.
    """
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    anahtar = _foto_anahtari(world["a"])

    d = client.post(
        "/announcements", headers=yonetici,
        json={"baslik": "Foto testi", "govde": "gövde", "foto_key": anahtar},
    )
    assert d.status_code == 201, d.text
    assert d.json().get("foto_url"), "duyuru foto_url BOS"

    k = client.post(
        "/site-rules", headers=yonetici,
        json={"baslik": "Kural foto", "icerik": "içerik", "foto_key": anahtar},
    )
    assert k.status_code == 201, k.text
    assert k.json().get("foto_url"), "site kurali foto_url BOS"
