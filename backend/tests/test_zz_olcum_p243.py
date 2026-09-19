from datetime import date, timedelta
def _h(client, slug, cred):
    r = client.post("/auth/login", json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}

def test_OLCUM_webin_gonderdigi_govde(client, world):
    """Web modali `/toplu`ya `baslangic`/`bitis` gonderiyor; sema
    `baslangic_tarih`/`bitis_tarih` istiyor."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    u = client.get("/users", headers=admin, params={"limit": 200}).json()["items"]
    guard = next(x for x in u if x["email"] == world["guard_a"]["email"])
    gun = date.today() + timedelta(days=200)
    r = client.post("/vardiya-plani/toplu", headers=admin, json={
        "user_id": guard["id"],
        "baslangic": str(gun), "bitis": str(gun),        # WEB'IN GONDERDIGI
        "baslangic_saat": "08:00", "bitis_saat": "16:00",
        "gunler": [str(gun)],
    })
    print("WEB GOVDESI ->", r.status_code, r.text[:160])
    assert False, "olcum"
