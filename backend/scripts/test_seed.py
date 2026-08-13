"""(P154) TEST SUNUCUSU tohumlama — TAMAMEN UYDURMA veri.

===========================================================================
KULLANIM (tek komut)
===========================================================================
    docker compose -f docker-compose.prod.yml --env-file .env.test \\
      -p yonetio-test run --rm worker python -m scripts.test_seed

`worker`, `api` DEGIL: `OWNER_DSN` (superuser) yalniz worker/beat
konteynerlerinde tanimlidir; api'ye bilincli olarak verilmez.

Parola: `TEST_SEED_PAROLA` verilmezse GUCLU bir parola URETILIR ve
sonunda EKRANA BASILIR. Sabit bir varsayilan YOKTUR — internete acik bir
sunucuda "Test123!" gibi bir parola, herkesin bildigi bir hesap demekti
(`demo_tenant.py` ile ayni ilke).

===========================================================================
KVKK — bu dosyada gercek kisi verisi YOKTUR
===========================================================================
Adlar uydurma, telefonlar `+9055500000xx` (Turkiye'de tahsis edilmemis
55x araligi), e-postalar `@test.yonetio.site`. Prod veritabanindan HICBIR
satir kopyalanmaz; her sey burada, kodun icinde uretilir.

===========================================================================
IDEMPOTENT — tekrar kosulabilir
===========================================================================
Her ekleme ya `ON CONFLICT DO NOTHING/UPDATE` ile ya da "varsa bul, yoksa
ac" ile yapilir. Ikinci kosum yeni satir URETMEZ; parolalari gunceller
(yani parolayi unutunca betigi tekrar kosmak yeterli).

TESIS KODU ELLE YAZILMAZ: `kayit_kodu` sutunu NOT NULL ama tetikleyici
(`tenant_kayit_kodu_ata`, goc 0037/0040/0041) onu adin ilk 4 harfi +
'-' + YYAAGG kuralindan URETIR. Betik yalniz `INSERT` eder ve kodu GERI
OKUR — kurali burada tekrar yazmak, iki kaynak yaratmak olurdu.
"""
from __future__ import annotations

import base64
import os
import secrets
import sys
from datetime import date, timedelta

import psycopg

sys.path.insert(0, "/app")

from app.security import hash_password  # noqa: E402

TENANT_AD = "Deneme Konakları"
TENANT_SLUG = "deneme-konaklari-test"

#: `+90555...` araligi Turkiye'de operatore TAHSIS EDILMEMISTIR: uydurma
#: numaranin gercek birine ait olma ihtimalini sifira yaklastirir.
def _tel(n: int) -> str:
    return f"+90555000{n:04d}"


#: (rol, ad, e-posta yerel kismi, telefon no) — her rolden en az bir hesap.
HESAPLAR: tuple[tuple[str, str, str, str], ...] = (
    ("yonetici",         "Ayşe Yönetici",     "yonetici",  _tel(101)),
    ("denetci",          "Cem Denetçi",       "denetci",   _tel(102)),
    ("security",         "Deniz Güvenlik",    "guvenlik",  _tel(103)),
    ("guvenlik_amiri",   "Emre Güvenlik Amiri", "amir",    _tel(104)),
    ("tesis_gorevlisi",  "Fatma Tesis Görevlisi", "gorevli", _tel(105)),
    ("resident",         "Gökhan Sakin",      "sakin1",    _tel(201)),
    ("resident",         "Hale Sakin",        "sakin2",    _tel(202)),
    ("resident",         "İlker Sakin",       "sakin3",    _tel(203)),
)

#: (P155r2) SAHIPLENILMEMIS HESAPLAR — yeni kayit akisini denemek icin.
#:
#: NEDEN GEREKLI: yukaridaki `HESAPLAR`in hepsinin parolasi KURULUDUR ve
#: yeni kayit yolu (`/auth/kayit/rol-basla`) parolasi olan hesabi BILEREK
#: reddeder — kayit, PAROLASIZ bir hesabi sahiplenmektir. Yani o hesaplarla
#: kayit akisi test sunucusunda HIC denenemezdi; ekipteki biri "kayit
#: bozuk" diye rapor ederdi, oysa kural boyle.
#:
#: Bunlar yoneticinin ONCEDEN EKLEDIGI kisilerdir: parola YOK, gecici kod
#: YOK. Tesis kodu + telefonla kaydolup parolalarini KENDILERI belirlerler.
SAHIPSIZ: tuple[tuple[str, str, str, str], ...] = (
    ("resident",        "Kayıtsız Sakin",     "yeni-sakin",    _tel(301)),
    ("security",        "Kayıtsız Güvenlik",  "yeni-guvenlik", _tel(302)),
    ("tesis_gorevlisi", "Kayıtsız Görevli",   "yeni-gorevli",  _tel(303)),
    # Ikinci yonetici: sartname §3 "Zaten bir sitem var" akisini dener.
    ("yonetici",        "Kayıtsız Yönetici",  "yeni-yonetici", _tel(304)),
)

BLOKLAR = (("A", 4), ("B", 3))   # (ad, kat sayisi)
DAIRE_PER_KAT = 3

DUYURULAR = (
    ("Su kesintisi", "Yarın 09:00–13:00 arası şebeke bakımı nedeniyle su kesintisi olacaktır."),
    ("Aidat hatırlatması", "Ağustos ayı aidatlarının son ödeme tarihi ayın 15'idir."),
    ("Otopark düzenlemesi", "B blok otoparkı çizgi boyası nedeniyle Cumartesi kapalı olacaktır."),
)

GOREV_KATEGORILERI = ("Temizlik", "Teknik Bakım", "Güvenlik Turu")

GOREVLER = (
    ("Ortak alan temizliği", "Temizlik", "A blok merdiven ve asansör önü."),
    ("Jeneratör kontrolü", "Teknik Bakım", "Yağ seviyesi ve akü gerilimi ölçülecek."),
    ("Gece turu", "Güvenlik Turu", "Tüm NFC noktaları okutulacak."),
)

NOKTALAR = (
    ("A Blok Giriş", "04A1B2C3D4E580"),
    ("B Blok Giriş", "04A1B2C3D4E581"),
    ("Otopark", "04A1B2C3D4E582"),
    ("Çatı Katı", "04A1B2C3D4E583"),
)

TALEPLER = (
    ("Asansör arızası", "A blok asansörü 3. katta takılı kalıyor."),
    ("Bahçe sulama", "Ön bahçedeki sulama başlığı kırılmış."),
)


def _parola() -> str:
    ham = os.getenv("TEST_SEED_PAROLA", "").strip()
    if ham:
        return ham
    # 18 bayt -> 24 karakter base64; buyuk/kucuk harf + rakam iceriyor.
    # Sonundaki `!A1` parola politikasini (buyuk harf + rakam + sembol)
    # HER ZAMAN saglar; rastgele dizeye guvenmek, betigin ayda bir
    # "parola zayif" diye patlamasi demekti.
    return base64.urlsafe_b64encode(secrets.token_bytes(18)).decode().rstrip("=") + "!A1"


def main() -> int:
    dsn = os.getenv("OWNER_DSN")
    if not dsn:
        print(
            "HATA: OWNER_DSN yok. Bu betik `worker` konteynerinde kosmali:\n"
            "  ... -p yonetio-test run --rm worker python -m scripts.test_seed",
            file=sys.stderr,
        )
        return 2

    parola = _parola()
    pw_hash = hash_password(parola)

    with psycopg.connect(dsn, autocommit=False) as con, con.cursor() as cur:
        # ---------------------------------------------------------- tesis
        cur.execute(
            "INSERT INTO tenant (ad, slug, timezone, kurulum_tamamlandi) "
            "VALUES (%s, %s, 'Europe/Istanbul', true) "
            "ON CONFLICT (slug) DO UPDATE SET ad = EXCLUDED.ad "
            "RETURNING id, kayit_kodu",
            (TENANT_AD, TENANT_SLUG),
        )
        tid, kayit_kodu = cur.fetchone()

        # ---------------------------------------------------------- bloklar
        for ad, kat in BLOKLAR:
            cur.execute(
                "INSERT INTO building_block (tenant_id, ad, kat_sayisi) "
                "VALUES (%s, %s, %s) "
                "ON CONFLICT (tenant_id, ad) DO UPDATE SET kat_sayisi = EXCLUDED.kat_sayisi",
                (tid, ad, kat),
            )

        # ---------------------------------------------------------- daireler
        daireler: list[tuple[str, str]] = []   # (no, blok)
        for blok, kat_sayisi in BLOKLAR:
            for kat in range(1, kat_sayisi + 1):
                for sira in range(1, DAIRE_PER_KAT + 1):
                    no = f"{blok}-{kat}{sira:02d}"
                    cur.execute(
                        "INSERT INTO unit (tenant_id, no, blok, kat, sira, aktif) "
                        "VALUES (%s, %s, %s, %s, %s, true) "
                        "ON CONFLICT (tenant_id, no) DO UPDATE "
                        "  SET blok = EXCLUDED.blok, kat = EXCLUDED.kat, sira = EXCLUDED.sira",
                        (tid, no, blok, kat, sira),
                    )
                    daireler.append((no, blok))

        # ---------------------------------------------------------- hesaplar
        #
        # BIRINCIL yonetici: `uq_app_user_birincil` tenant basina TEK
        # birincil kaydi zorluyor. Listedeki ILK `yonetici` birincil olur;
        # tekrar kosumda deger DEGISMEZ (ayni kisi).
        #
        # `denetci`nin gorev penceresi BILEREK genis: `gorev_penceresi_
        # disinda` kapisi (P128) dar bir pencerede girisi 403'le reddeder
        # ve test sunucusunda bu, "denetci giremiyor" diye rapor edilen
        # sahte bir kusur uretirdi.
        bugun = date.today()
        uid: dict[str, str] = {}
        birincil_verildi = False
        for rol, ad, yerel, telefon in HESAPLAR:
            birincil = rol == "yonetici" and not birincil_verildi
            if birincil:
                birincil_verildi = True
            gorev = (bugun - timedelta(days=1), bugun + timedelta(days=365)) \
                if rol == "denetci" else (None, None)
            cur.execute(
                "INSERT INTO app_user (tenant_id, ad, email, telefon, password_hash, "
                "                      password_set, role, is_active, aranabilir, birincil, "
                "                      gorev_baslangic, gorev_bitis) "
                "VALUES (%s,%s,%s,%s,%s, true, %s::user_role, true, %s, %s, %s, %s) "
                "ON CONFLICT (tenant_id, email) DO UPDATE "
                "  SET password_hash = EXCLUDED.password_hash, password_set = true, "
                "      ad = EXCLUDED.ad, telefon = EXCLUDED.telefon, is_active = true, "
                "      temp_code_hash = NULL, "
                "      gorev_baslangic = EXCLUDED.gorev_baslangic, "
                "      gorev_bitis = EXCLUDED.gorev_bitis "
                "RETURNING id",
                (tid, ad, f"{yerel}@test.yonetio.site", telefon, pw_hash, rol,
                 rol in ("yonetici", "security", "guvenlik_amiri"), birincil,
                 gorev[0], gorev[1]),
            )
            uid[yerel] = cur.fetchone()[0]

        # ------------------------------------- (P155r2) SAHIPSIZ HESAPLAR
        #
        # PAROLA YOK, GECICI KOD YOK: `password_hash=NULL`,
        # `password_set=false`, `temp_code_hash=NULL`. Yeni kayit akisinin
        # aradigi durum tam olarak budur.
        #
        # TEKRAR KOSUMDA SIFIRLANIR (`password_set = false` ile UPDATE) ve
        # bu BILINCLI: biri akisi deneyip hesabi sahiplendikten sonra
        # betigi tekrar kosan kisi, akisi BIR KEZ DAHA deneyebilmeli.
        # Ustteki `HESAPLAR` icin bunun tersi gecerli (orada parola
        # kuruluyor) — iki liste iki farkli isi yapiyor.
        for rol, ad, yerel, telefon in SAHIPSIZ:
            cur.execute(
                "INSERT INTO app_user (tenant_id, ad, email, telefon, password_hash, "
                "                      password_set, temp_code_hash, role, is_active, "
                "                      aranabilir, birincil) "
                "VALUES (%s,%s,%s,%s, NULL, false, NULL, %s::user_role, true, %s, false) "
                "ON CONFLICT (tenant_id, email) DO UPDATE "
                "  SET password_hash = NULL, password_set = false, "
                "      temp_code_hash = NULL, ad = EXCLUDED.ad, "
                "      telefon = EXCLUDED.telefon, is_active = true "
                "RETURNING id",
                (tid, ad, f"{yerel}@test.yonetio.site", telefon, rol,
                 rol in ("yonetici", "security")),
            )
            uid[yerel] = cur.fetchone()[0]

        # SAHIPSIZ SAKIN BIR DAIREYE BAGLANIR: `rol-basla` sakin icin
        # daire eslesmesi de arar (`_daire_eslesiyor`); bagli olmayan bir
        # sakin dogru tesis kodunu girse bile kaydolamazdi.
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi) "
            "SELECT %s, u.id, %s, 'kiraci' FROM unit u "
            " WHERE u.tenant_id = %s AND u.no = %s "
            "ON CONFLICT DO NOTHING",
            (tid, uid["yeni-sakin"], tid, daireler[3][0]),
        )

        # ------------------------------------------------- sakin <-> daire
        # Uc sakin, A blokun ilk uc dairesine. `uq_unitresident_aktif`
        # (unit_id, user_id) WHERE bitis IS NULL — tekrar kosumda catismasin
        # diye ON CONFLICT DO NOTHING.
        for i, yerel in enumerate(("sakin1", "sakin2", "sakin3")):
            no = daireler[i][0]
            cur.execute(
                "INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi) "
                "SELECT %s, u.id, %s, 'malik' FROM unit u "
                " WHERE u.tenant_id = %s AND u.no = %s "
                "ON CONFLICT DO NOTHING",
                (tid, uid[yerel], tid, no),
            )

        # ---------------------------------------------------------- duyurular
        for baslik, govde in DUYURULAR:
            cur.execute(
                "SELECT 1 FROM announcement WHERE tenant_id = %s AND baslik = %s",
                (tid, baslik),
            )
            if cur.fetchone() is None:
                cur.execute(
                    "INSERT INTO announcement (tenant_id, baslik, govde, olusturan_user_id) "
                    "VALUES (%s,%s,%s,%s)",
                    (tid, baslik, govde, uid["yonetici"]),
                )

        # ------------------------------------------------- gorev kategorileri
        kat_id: dict[str, str] = {}
        for ad in GOREV_KATEGORILERI:
            cur.execute(
                "INSERT INTO task_category (tenant_id, ad, aktif) VALUES (%s,%s,true) "
                "ON CONFLICT (tenant_id, ad) DO UPDATE SET aktif = true RETURNING id",
                (tid, ad),
            )
            kat_id[ad] = cur.fetchone()[0]

        # ---------------------------------------------------------- noktalar
        nokta_id: dict[str, str] = {}
        for ad, uid_tag in NOKTALAR:
            cur.execute(
                "INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid, aktif) "
                "VALUES (%s,%s,%s,true) "
                "ON CONFLICT (tenant_id, nfc_tag_uid) DO UPDATE "
                "  SET ad = EXCLUDED.ad, aktif = true RETURNING id",
                (tid, ad, uid_tag),
            )
            nokta_id[ad] = cur.fetchone()[0]

        # ---------------------------------------------------------- gorevler
        for ad, kategori, aciklama in GOREVLER:
            cur.execute(
                "SELECT 1 FROM task WHERE tenant_id = %s AND ad = %s", (tid, ad)
            )
            if cur.fetchone() is None:
                cur.execute(
                    "INSERT INTO task (tenant_id, ad, aciklama, kategori_id, "
                    "                  atanan_user_id, aktif, oncelik) "
                    "VALUES (%s,%s,%s,%s,%s,true,'orta')",
                    (tid, ad, aciklama, kat_id[kategori], uid["gorevli"]),
                )

        # ------------------------------------------------------------ aidat
        # Her daireye bu ay ve gecen ay icin birer tahakkuk.
        # `uq_assessment_unit_donem_tur` (tenant, unit, donem, tanim)
        # tekrar kosumda catismayi engelliyor.
        for kayma in (0, 1):
            ay = (bugun.replace(day=1) - timedelta(days=31 * kayma)).replace(day=1)
            donem = ay.strftime("%Y-%m")
            for no, _blok in daireler:
                cur.execute(
                    "INSERT INTO dues_assessment (tenant_id, unit_id, donem, tutar_kurus, "
                    "                             son_odeme_tarihi, aciklama) "
                    "SELECT %s, u.id, %s, %s, %s, %s FROM unit u "
                    " WHERE u.tenant_id = %s AND u.no = %s "
                    "ON CONFLICT DO NOTHING",
                    (tid, donem, 85000, ay + timedelta(days=14),
                     f"{donem} aidatı", tid, no),
                )

        # ---------------------------------------------------------- talepler
        for i, (baslik, mesaj) in enumerate(TALEPLER):
            cur.execute(
                "SELECT 1 FROM complaint WHERE tenant_id = %s AND baslik = %s",
                (tid, baslik),
            )
            if cur.fetchone() is None:
                cur.execute(
                    "INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj, durum) "
                    "VALUES (%s,%s,%s,%s,'acik')",
                    (tid, uid[f"sakin{i + 1}"], baslik, mesaj),
                )

        con.commit()

    # ------------------------------------------------------------- rapor
    print()
    print("=" * 68)
    print("TEST SUNUCUSU TOHUMLAMASI TAMAM — veriler TAMAMEN UYDURMA")
    print("=" * 68)
    print(f"Tesis      : {TENANT_AD}")
    print(f"Tesis ID   : {kayit_kodu}   (tetikleyici uretti, elle yazilmadi)")
    print(f"Slug       : {TENANT_SLUG}")
    print(f"Bloklar    : " + ", ".join(f"{a} ({k} kat)" for a, k in BLOKLAR))
    print(f"Daire      : {len(BLOKLAR) * 0 + sum(k for _, k in BLOKLAR) * DAIRE_PER_KAT}")
    print()
    print(f"PAROLA (tum hesaplar icin AYNI): {parola}")
    print("  Bu parola BIR KEZ basilir. Unutulursa betigi tekrar kosun —")
    print("  idempotenttir ve parolalari gunceller.")
    print()
    print(f"{'ROL':<18}{'AD':<24}{'E-POSTA':<34}{'TELEFON'}")
    print("-" * 96)
    for rol, ad, yerel, telefon in HESAPLAR:
        print(f"{rol:<18}{ad:<24}{yerel + '@test.yonetio.site':<34}{telefon}")
    print()
    print("SAHIPSIZ HESAPLAR — YENI KAYIT AKISINI BUNLARLA DENEYIN")
    print("-" * 96)
    print("  Parolalari YOK. Uygulamada: rol sec -> yontem -> ad/telefon/parola")
    print(f"  -> tesis kodu ({kayit_kodu}). Kendi parolalarini belirlerler.")
    print("  Betigi tekrar kosarsaniz yeniden SAHIPSIZ olurlar (akis tekrar denenir).")
    print()
    print(f"{'ROL':<18}{'AD':<24}{'DENENECEK AKIS':<34}{'TELEFON'}")
    print("-" * 96)
    _AKIS = {
        "resident": "tesis kodu + daire eslesmesi",
        "security": "tesis kodu eslesmesi",
        "tesis_gorevlisi": "tesis kodu eslesmesi",
        "yonetici": "'Zaten bir sitem var'",
    }
    for rol, ad, _yerel, telefon in SAHIPSIZ:
        print(f"{rol:<18}{ad:<24}{_AKIS[rol]:<34}{telefon}")
    print()
    print("  Yonetici SELF-SIGNUP'i (yeni tesis acma) denemek icin bu listeye")
    print("  gerek YOK: kaydolma ekraninda 'Yonetici' + 'Tesis adini giriniz'")
    print("  ile HIC KAYITLI OLMAYAN bir numara kullanin.")
    print()
    print("GIRIS YOLLARI:")
    print("  panel-test.yonetio.site : e-posta + parola (yalniz `admin` rolu)")
    print("  app-test.yonetio.site   : telefon + parola (yonetici, denetci)")
    print("  mobil                   : telefon + parola (tum tesis rolleri)")
    print()
    print("NOT: `admin` (platform) hesabi BU BETIKTE ACILMAZ — o tesise")
    print("     degil platforma aittir: scripts/create_admin.py kullanin.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
