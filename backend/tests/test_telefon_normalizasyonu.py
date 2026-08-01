"""(P97) Telefon E.164 normalizasyonu GUNCELLEME yolunda da uygulanir.

Olculdu: `PATCH /users/{id} {"telefon": "//evil.example/x"}` **200** donuyor
ve deger HAM sakalaniyordu. Yaratma yolunda (`UserCreate`) dogrulayici
vardi, guncelleme yolunda yoktu — ayni gercek iki yerde, biri korumasiz.

Iki sonucu vardi:
  * telefon GLOBAL BENZERSIZ bir GIRIS KIMLIGIDIR (telefonla giris);
    normalize edilmemis deger benzersizligi bozar (`0532…` ile `+90532…`
    ayni kisi, farkli satir),
  * `resolve_phone_target` `tel:{numara}` kurar; ham deger
    `tel://evil.example/x` gibi bir URI uretir ve istemcinin sema kontrolu
    (P96) bunu GECIRIR cunku sema hala `tel`.
"""
import uuid


def _admin(client, world):
    a = world["admin_a"]
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"], "email": a["email"],
        "password": a["password"],
    })
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _yeni_kullanici(client, h) -> str:
    son = uuid.uuid4().hex[:6]
    r = client.post("/users", headers=h, json={
        "ad": f"Tel {son}", "email": f"tel-{son}@acme.com",
        "role": "yonetici", "telefon": f"+9053{uuid.uuid4().int % 10**8:08d}",
    })
    assert r.status_code == 201, r.text
    return r.json()["id"]


def test_gecersiz_telefon_guncellemede_REDDEDILIR(client, world):
    h = _admin(client, world)
    uid = _yeni_kullanici(client, h)
    for kotu in ["//evil.example/x", "abc", "+1", "tel:+905321112233"]:
        r = client.patch(f"/users/{uid}", headers=h, json={"telefon": kotu})
        assert r.status_code == 422, f"{kotu} -> {r.status_code} {r.text[:120]}"


def test_gecerli_telefon_E164e_NORMALIZE_edilir(client, world):
    h = _admin(client, world)
    uid = _yeni_kullanici(client, h)
    son = uuid.uuid4().int % 10**7
    r = client.patch(f"/users/{uid}", headers=h,
                     json={"telefon": f"0532 {son:07d}"[:14]})
    assert r.status_code == 200, r.text
    tel = r.json()["telefon"]
    assert tel.startswith("+90"), tel
    assert " " not in tel and "-" not in tel, tel


def test_telefon_None_gonderilebilir(client, world):
    # `None` "numara yok" demektir ve dogrulayici onu ELEMEMELI.
    h = _admin(client, world)
    uid = _yeni_kullanici(client, h)
    r = client.patch(f"/users/{uid}", headers=h, json={"telefon": None})
    assert r.status_code == 200, r.text
    assert r.json()["telefon"] is None


def test_BOS_DIZGE_numarayi_kaldirir_gecersiz_SAYILMAZ(client, world):
    """(P98) `""` "numarayi kaldir" demektir; dogrulayici onu ELEMEMELI.

    Ilk surumde bos dizge 422 oluyordu ve `test_call_target` dustu:
    dogrulayici, dogrulamasi gerekmeyen bir DEGERI reddediyordu. Uc
    sozlesmesi bu: `resolve_phone_target` `(telefon or "").strip()` ile
    bos degeri "numara yok" sayar.
    """
    h = _admin(client, world)
    uid = _yeni_kullanici(client, h)
    r = client.patch(f"/users/{uid}/contact", headers=h, json={"telefon": ""})
    assert r.status_code == 200, r.text
    # Numara artik yok -> arama hedefi 404 (numara ASLA donmez).
    assert not (r.json().get("telefon") or "").strip()


def test_yonetim_email_BOSLUK_None_olur(client, world):
    """(P99) Aynı asimetri `yonetim_email`de de vardı.

    `TenantAdminCreate` boş/boşluk değeri `None`a çeviriyordu; ama
    `TenantSettingsUpdate` çevirmiyordu ve `" "` OLDUGU GIBI saklaniyordu.
    `" "` TRUTHY oldugu icin "yonetim e-postasi var" sayilir ve bildirim
    yolu BOS bir adrese gitmeye calisirdi.
    """
    h = _admin(client, world)
    r = client.patch("/tenant/settings", headers=h, json={"yonetim_email": "   "})
    assert r.status_code == 200, r.text
    assert r.json().get("yonetim_email") is None

    r2 = client.patch("/tenant/settings", headers=h,
                      json={"yonetim_email": " yonetim@acme.com "})
    assert r2.status_code == 200, r2.text
    assert r2.json().get("yonetim_email") == "yonetim@acme.com"
