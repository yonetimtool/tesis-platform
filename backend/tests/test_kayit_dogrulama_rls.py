"""(P154) `kayit_dogrulama` RLS altinda — KIMLIK ONCESI akislar KIRILMADI.

Goc 0042 bu tabloya tenant izolasyon politikasi koydu. Tehlike sunda:
tablo kullanicinin HENUZ OTURUMU YOKKEN okunuyor, yani politikanin
bakacagi `app.current_tenant_id` set edilemez. Naif bir politika sakin
kaydini ve parolasiz girisi SESSIZCE sifir satira dusururdu — hicbir yerde
hata cikmadan, kullanici yalnizca "kod gecersiz" gorurdu.

Bu dosya, cozucunun (`kayit_dogrulama_tenant_coz`) ve tenant-uzeri
ezmenin (`kayit_dogrulama_acik_temizle`) o sinifi kapattigini olcer.

NEDEN AYRI DOSYA: rol kaydi testleri (`test_rol_secimli_kayit.py`) KAYIT
KURALLARINI olcer (sizdirmama, rol eslesmesi, kaba kuvvet). Burasi
ALTYAPIYI olcer — ayni akis kirilirsa iki dosya farkli seyler soyler ve
kok neden daha cabuk bulunur.

(P155r2) TESTLER P148 UCLARINDAN COZULDU. Eskiden `/auth/kayit/basla`
surulyordu; o akis kaldirildi. OLCULEN RISK DEGISMEDI — `kayit_dogrulama`
hâlâ kimlik oncesi okunuyor (`giris`/`oauth`/`kayit` kodlari) ve ayni
cozucuye bagli. Testler bu yuzden silinmedi, YASAYAN bir uca
(`/auth/giris/kod-iste` + `/kod-dogrula`) tasindi.
"""
from __future__ import annotations

import uuid


# ===================== 1) RLS GERCEKTEN ACIK MI ============================ #

def test_tablo_RLS_ve_FORCE_tasiyor(owner_conn):
    """FORCE olmadan tablo SAHIBI politikalari atlar; kilit yarim kalirdi."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT relrowsecurity, relforcerowsecurity "
            "FROM pg_class WHERE relname = 'kayit_dogrulama'"
        )
        rls, force = cur.fetchone()
        cur.execute(
            "SELECT count(*) FROM pg_policy "
            "WHERE polrelid = 'public.kayit_dogrulama'::regclass"
        )
        politika = cur.fetchone()[0]
    assert rls is True and force is True
    assert politika == 1, "tenant izolasyon politikasi yok"


def test_cozucu_YALNIZ_tenant_kimligi_doner(owner_conn):
    """Fonksiyon SATIR DONDURMEZ: donus tipi `uuid`.

    Kod/ad/daire donduren bir cozucu, kimlik oncesi bir uctan
    dogrulanmamis veriyi disari acardi.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT pg_get_function_result(p.oid) FROM pg_proc p "
            "JOIN pg_namespace n ON n.oid = p.pronamespace "
            "WHERE n.nspname='public' AND p.proname='kayit_dogrulama_tenant_coz'"
        )
        assert cur.fetchone()[0] == "uuid"


# ============ 2) KIMLIK ONCESI AKISLAR CALISMAYA DEVAM EDIYOR ============== #

def test_kod_iste_ve_DOGRULA_ucdan_uca(client, world, owner_conn):
    """RLS'in kirabilecegi ASIL yol: kod TELEFONDAN bulunuyor.

    Baglami cozucu kurmasaydi `kod-dogrula` satiri goremez ve dogru kod
    bile 422 alirdi.
    """
    tel = world["resident_a"]["phone"]
    with owner_conn.cursor() as cur:
        cur.execute(
            "DELETE FROM kayit_dogrulama WHERE telefon = %s AND amac = 'giris'",
            (tel,),
        )

    r = client.post("/auth/giris/kod-iste", json={"telefon": tel})
    assert r.status_code == 200, r.text

    # Kod SMS ile gider ve yanitta DONMEZ; testte veritabanindan okunamaz
    # (hash). Bu yuzden dogrulamayi YANLIS kodla deneyip AYIRT EDICI etkiyi
    # olcuyoruz: satir GORULUYORSA deneme sayaci ARTAR. Satir
    # GORULMESEYDI sayac hic artmazdi.
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT deneme FROM kayit_dogrulama "
            "WHERE telefon = %s AND amac = 'giris'", (tel,)
        )
        onceki = cur.fetchone()[0]

    r = client.post("/auth/giris/kod-dogrula",
                    json={"telefon": tel, "kod": "000000"})
    assert r.status_code == 422

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT deneme FROM kayit_dogrulama "
            "WHERE telefon = %s AND amac = 'giris'", (tel,)
        )
        sonraki = cur.fetchone()[0]
    assert sonraki == onceki + 1, (
        "deneme sayaci ARTMADI — satir RLS yuzunden GORULMUYOR olabilir; "
        "kimlik oncesi cozucu calismiyor"
    )


def test_giris_kodu_iste_KIRILMADI(client, world):
    """Parolasiz giris de ayni tabloyu kimlik oncesi kullanir.

    Uc, numara kayitli OLMASA DA ayni yaniti verir; olctugumuz sey
    yanit degil, istegin 5xx'e DUSMEMESIDIR — RLS bir yazmayi
    engelleseydi burada hata cikardi.
    """
    r = client.post("/auth/giris/kod-iste",
                    json={"telefon": world["resident_a"]["phone"]})
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "onay_bekliyor"


# ================ 3) ASIL RISK: TENANT-UZERI "EZME" ======================== #

def test_BASKA_TESISTE_asili_kalan_satir_akisi_KIRMAZ(client, world, owner_conn):
    """`uq_kayit_acik_basvuru` KISMI ve GLOBAL: bir telefon TUM PLATFORMDA
    (telefon, amac) basina tek acik satir tasiyabilir.

    SENARYO: numaraya ait acik bir `giris` satiri BASKA bir tesiste asili
    kalmis (kullanici tasindi, hesabi tasindi, ya da eski bir akistan
    arta kaldi). Simdi numaranin GERCEK tesisinde kod isteniyor. Ezme
    tenant sinirini GECMEZSE yeni INSERT o satirla catisir ve kullanici
    500 alir. Bu testin varlik sebebi tam olarak o 500'dur.

    (P155r2) Senaryo ESKIDEN `/auth/kayit/basla`yi iki tesiste cagirarak
    kuruluyordu; o uc kaldirildi. Asili satir artik DOGRUDAN yaziliyor —
    olculen sey (tenant-uzeri ezme) ayni, kurulumu daha dogrudan.
    """
    tel = world["resident_a"]["phone"]
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM kayit_dogrulama WHERE telefon = %s", (tel,))
        # Numaranin sahibi A'da; acik satiri B'ye koyuyoruz.
        cur.execute(
            "INSERT INTO kayit_dogrulama "
            "(tenant_id, telefon, kod_hash, son_gecerlilik, amac, durum) "
            "SELECT id, %s, 'x', now() + interval '10 min', "
            "       'giris'::kod_amaci, 'telefon_bekliyor'::kayit_durum "
            "FROM tenant WHERE slug = %s",
            (tel, world["slug_b"]),
        )

    r = client.post("/auth/giris/kod-iste", json={"telefon": tel})
    assert r.status_code == 200, (
        f"kod istegi DUSTU ({r.status_code}) — tenant-uzeri ezme "
        f"calismiyor: {r.text}"
    )

    # Ve geriye TEK acik satir kalir; sahibi numaranin GERCEK tesisidir (A).
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT t.slug FROM kayit_dogrulama k JOIN tenant t "
            "ON t.id = k.tenant_id "
            "WHERE k.telefon = %s AND k.amac = 'giris' "
            "AND k.durum = 'telefon_bekliyor'", (tel,)
        )
        satirlar = cur.fetchall()
    assert len(satirlar) == 1, f"tek acik satir bekleniyordu: {satirlar}"
    assert satirlar[0][0] == world["slug_a"]


def test_ezme_BASKA_amaci_silmez(client, world, owner_conn):
    """Ezme (telefon, amac) ciftine baglidir.

    Bir kullanicinin bekleyen HESAP SILME kodu, yeni bir GIRIS kodu
    istendiginde silinmemelidir; yoksa iki akis birbirini iptal ederdi.
    """
    tel = world["resident_a"]["phone"]
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM kayit_dogrulama WHERE telefon = %s", (tel,))
        cur.execute(
            "INSERT INTO kayit_dogrulama "
            "(tenant_id, telefon, kod_hash, son_gecerlilik, amac, durum) "
            "SELECT id, %s, 'x', now() + interval '10 min', "
            "       'hesap_silme'::kod_amaci, 'telefon_bekliyor'::kayit_durum "
            "FROM tenant WHERE slug = %s",
            (tel, world["slug_a"]),
        )

    assert client.post("/auth/giris/kod-iste",
                       json={"telefon": tel}).status_code == 200

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT amac::text FROM kayit_dogrulama WHERE telefon = %s "
            "AND durum = 'telefon_bekliyor' ORDER BY 1", (tel,)
        )
        amaclar = [r[0] for r in cur.fetchall()]
    assert amaclar == ["giris", "hesap_silme"], (
        f"amac ayrimi bozuldu: {amaclar}"
    )
