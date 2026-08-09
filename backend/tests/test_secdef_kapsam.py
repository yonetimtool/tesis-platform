"""SECURITY DEFINER YUZEYI — RLS'i BYPASS eden 13 fonksiyon (tur 75).

NEDEN: tur 73'un RLS kapsami olcumu 48 tablonun politikalarini dogruladi, ama
`SECURITY DEFINER` fonksiyonlar o politikalarin TAMAMINI atlar — owner
yetkisiyle kosarlar ve owner'in `rolbypassrls=true` ozelligi var. Yani bu 13
fonksiyon, cok-kiracili izolasyonun TEK gercek deligi ve tur 73'un olcumu
onlara HIC bakmiyordu.

Uc bagimsiz hata sinifi olculur:

  1. search_path SABITLENMIS MI. Klasik SECURITY DEFINER acigi: `search_path`
     pinlenmezse, arama yolunda daha onde bir semaya nesne yaratabilen bir
     cagirici fonksiyonun icindeki `tenant` referansini KENDI tablosuna
     yonlendirebilir ve owner yetkisiyle kostururabilir.

  2. EXECUTE PUBLIC'E ACIK MI. Varsayilan olarak yeni fonksiyonlarda EXECUTE
     PUBLIC'tedir. Bu fonksiyonlar acik acik yalniz owner + app_rw'ye
     verilmeli.

  3. GOZDEN GECIRILMIS MI. Asagidaki ENVANTER her fonksiyonu, HTTP rol
     kapisiyla birlikte kaydeder. Katalogda envanterde OLMAYAN bir fonksiyon
     cikarsa test kirilir — yani yeni bir SECURITY DEFINER fonksiyonu
     gozden gecirilmeden semaya giremez. Ters yon de kirilir (envanterde olup
     semada olmayan = olu kayit).

Ayrica ENVANTER'deki `admin` kapisi DAVRANISSAL olarak dogrulanir: yonetici
rolu o uclarda 403 almali. Boylece envanter suslemeden ibaret kalmaz.

NOT — bu olcumun kapsamadigi sey: `admin` rolu bu uclarda BILINCLI olarak
tenant sinirini gecer (panelin isi tam olarak bu). Olculen sey admin'in
kisitlanmasi degil, admin OLMAYAN hicbir rolun bu yuzeye erisememesi.
"""
from __future__ import annotations

import os

import pytest

#: Katalogda bundan az SECURITY DEFINER fonksiyon gorulurse sorgu bozulmustur
#: ve asagidaki kontroller BOSA GECER.
TABAN_FONKSIYON = int(os.getenv("SECDEF_TABAN", "10"))

#: Fonksiyon -> (HTTP rol kapisi, davranissal sonda). Sonda `None` ise uc
#: KIMLIK GEREKTIRMEZ (giris/webhook) ve bu BILINCLIDIR.
ENVANTER: dict[str, tuple[str, tuple[str, str] | None]] = {
    # --- platform admin paneli: tenant yonetimi (tenant sinirini GECER) ---
    "list_all_tenants": ("admin", ("get", "/tenants")),
    "tenant_detail": ("admin", ("get", "/tenants/{tid}")),
    "create_tenant_with_yoneticis": ("admin", ("post", "/tenants")),
    "update_tenant_ad": ("admin", ("patch", "/tenants/{tid}")),
    "update_tenant_yonetici": ("admin", ("patch", "/tenants/{tid}/yonetici")),
    "reset_tenant_yonetici_credential": (
        "admin",
        ("post", "/tenants/{tid}/yonetici/reset-credential"),
    ),
    "delete_tenant": ("admin", ("delete", "/tenants/{tid}")),
    # (P154) Tesis basina COKLU yonetici. Ucu de tenant sinirini GECER
    # (admin baska bir tesisin kadrosunu yonetir) ve ucu de YALNIZ admin.
    "tenant_yoneticiler": ("admin", ("get", "/tenants/{tid}/yoneticiler")),
    "add_tenant_yonetici": ("admin", ("post", "/tenants/{tid}/yoneticiler")),
    "remove_tenant_yonetici": (
        "admin",
        ("delete", "/tenants/{tid}/yoneticiler/{uid}"),
    ),
    # --- platform destek kanali: TUM tenant'larin biletleri ---
    "support_ticket_list": ("admin", ("get", "/support/all")),
    "support_ticket_answer": ("admin", ("patch", "/support/{tid}")),
    # --- KVKK denetim kaydi: tenant filtresi opsiyonel ---
    "audit_log_list": ("admin", ("get", "/audit")),
    # --- KIMLIK ONCESI (bilincli): giris ve odeme webhook'u ---
    # Giriste kullanici henuz kimliklenmemistir; tenant'i cozmek icin RLS
    # bypass SART. Ikisi de yalniz bir uuid doner, satir vermez.
    "tenant_id_by_slug": ("public", None),
    "tenant_id_by_phone": ("public", None),
    # (P148) Sakin kaydolurken oturumu YOKTUR; tesis, kayit kodundan cozulur.
    # (P154'te REVOKE/GRANT ve `search_path=''` eklendi — 0036'da unutulmustu.)
    "tenant_id_by_kayit_kodu": ("public", None),
    # Saglayici webhook'u imzayla dogrulanir; tenant provider_ref'ten cozulur.
    "payment_tenant_by_ref": ("public", None),
    # ANPR girisi (P16): kamera kutusu JWT tasimaz, kimlik `X-ANPR-Key`
    # basligiyla kurulur. Istek geldiginde tenant HENUZ BILINMEDIGI icin RLS
    # baglami kurulamaz — cozumleme burada olur. Fonksiyon YALNIZ
    # (tenant_id, key_id) doner: satirin geri kalanini (ad, hash) sizdirmaz
    # ve `aktif=false` anahtari HIC dondurmez.
    "anpr_key_coz": ("public", None),
    # --- (P127.2) TANITIM SITESI ILETISIM FORMU ---
    # Tablo TENANT'SIZ: satirin sahibi bir tesis degil, PLATFORMDUR. Bu
    # yuzden `app.current_tenant_id` uzerine politika yazilamaz ve tabloda
    # POLITIKA YOKTUR — app_rw dogrudan okuyamaz/yazamaz. Erisimin TAMAMI
    # bu uc fonksiyondan gecer.
    #
    # `ekle` PUBLIC (kimlik yok): formu dolduran ziyaretcinin hesabi
    # yoktur. Fonksiyon YALNIZ yeni satirin id'sini doner — hicbir satir
    # OKUTMAZ, yani public uc tabloyu goremez.
    "tanitim_iletisim_ekle": ("public", None),
    # Okuma ve isaretleme YALNIZ platform admini (kayitlar kisisel veri).
    "tanitim_iletisim_listele": ("admin", ("get", "/tanitim-iletisim")),
    "tanitim_iletisim_okundu": ("admin", ("patch", "/tanitim-iletisim/{tid}")),
}


@pytest.fixture
def secdef(owner_conn):
    """(ad, proconfig, proacl) — eklenti fonksiyonlari HARIC."""
    return owner_conn.execute(
        """
        SELECT p.proname,
               p.proconfig,
               p.proacl::text[]
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef
          AND NOT EXISTS (SELECT 1 FROM pg_depend d
                          WHERE d.objid = p.oid AND d.deptype = 'e')
        ORDER BY p.proname
        """
    ).fetchall()


# --------------------------------------------------------------------------- #
# 0. BOSA-GECME MUHAFIZI
# --------------------------------------------------------------------------- #
def test_secdef_sayisi_makul(secdef):
    assert len(secdef) >= TABAN_FONKSIYON, (
        f"yalniz {len(secdef)} SECURITY DEFINER fonksiyon goruldu; beklenen en az "
        f"{TABAN_FONKSIYON}. Sorgu yanlis veritabanina baktiysa asagidaki "
        f"kontroller BOSA GECER."
    )


# --------------------------------------------------------------------------- #
# 1. search_path SABITLENMIS
# --------------------------------------------------------------------------- #
def test_her_secdef_fonksiyonunun_search_path_i_sabit(secdef):
    kusurlu = [
        ad
        for ad, proconfig, _acl in secdef
        if not any(str(k).startswith("search_path=") for k in (proconfig or []))
    ]
    assert not kusurlu, (
        "search_path SABITLENMEMIS SECURITY DEFINER fonksiyon(lar): "
        + ", ".join(kusurlu)
        + ". Sabitlenmezse cagirici, fonksiyonun icindeki tablo referanslarini "
        + "kendi nesnelerine yonlendirip OWNER yetkisiyle kosturabilir."
    )


# --------------------------------------------------------------------------- #
# 2. EXECUTE PUBLIC'E ACIK DEGIL
# --------------------------------------------------------------------------- #
def test_hicbir_secdef_fonksiyonu_public_execute_degil(secdef):
    kusurlu = []
    for ad, _cfg, acl in secdef:
        if acl is None:
            # NULL proacl = VARSAYILAN yetkiler = PUBLIC EXECUTE.
            kusurlu.append(f"{ad} (proacl NULL -> varsayilan PUBLIC EXECUTE)")
            continue
        # "=X/owner" (grantee bos) girdisi PUBLIC demektir.
        if any(girdi.startswith("=") for girdi in acl):
            kusurlu.append(f"{ad} (PUBLIC'e EXECUTE: {acl})")
    assert not kusurlu, (
        "PUBLIC EXECUTE'a acik SECURITY DEFINER fonksiyon(lar): "
        + "; ".join(kusurlu)
    )


# --------------------------------------------------------------------------- #
# 3. ENVANTER ile katalog ORTUSUYOR (iki yonlu)
# --------------------------------------------------------------------------- #
def test_envanter_katalogla_ortusuyor(secdef):
    katalogda = {ad for ad, _c, _a in secdef}
    envanterde = set(ENVANTER)
    gozden_gecirilmemis = sorted(katalogda - envanterde)
    olu_kayit = sorted(envanterde - katalogda)
    assert not gozden_gecirilmemis, (
        "GOZDEN GECIRILMEMIS SECURITY DEFINER fonksiyon(lar): "
        + ", ".join(gozden_gecirilmemis)
        + ". Bunlar RLS'i BYPASS eder; ENVANTER'e rol kapisiyla eklenmeden "
        + "semaya girmemeliler."
    )
    assert not olu_kayit, (
        "ENVANTER'de olup semada OLMAYAN kayit(lar): " + ", ".join(olu_kayit)
    )


# --------------------------------------------------------------------------- #
# 4. ENVANTER'deki `admin` kapisi DAVRANISSAL olarak dogru
# --------------------------------------------------------------------------- #
def test_admin_kapili_uclar_yoneticiye_kapali(client, world):
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": world["slug_a"],
            "email": world["yonetici_a"]["email"],
            "password": world["yonetici_a"]["password"],
        },
    )
    assert r.status_code == 200, f"yonetici girisi basarisiz: {r.text}"
    basliklar = {"Authorization": f"Bearer {r.json()['access_token']}"}

    sondalar = [
        (ad, sonda) for ad, (kapi, sonda) in ENVANTER.items()
        if kapi == "admin" and sonda
    ]
    assert sondalar, "admin kapili sonda yok — ENVANTER bozuk mu?"

    sizanlar = []
    for ad, (metot, yol) in sondalar:
        url = yol.replace("{tid}", str(world["b"]))  # BASKA tenant'in id'si
        kw = {"headers": basliklar}
        if metot in ("post", "patch", "put"):
            kw["json"] = {}
        cevap = getattr(client, metot)(url, **kw)
        if cevap.status_code != 403:
            sizanlar.append(f"{ad}: {metot.upper()} {url} -> {cevap.status_code}")
    assert not sizanlar, (
        "ENVANTER bu fonksiyonlari `admin` kapili sayiyor ama yonetici rolu 403 "
        "ALMIYOR (RLS bypass eden yuzeye erisim):\n  " + "\n  ".join(sizanlar)
    )
