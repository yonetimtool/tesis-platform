"""(P240 §2) DIYAFON ENTEGRASYONU — uc yontem, tek tablo, tek soyutlama.

===========================================================================
NEDEN AYRI TABLO (mevcut `integration` DEGIL)
===========================================================================
`integration` genel bir WEBHOOK tanimidir: URL + sablon + auth. Diyafon
ise yonteme gore FARKLI alanlar ister:

  * `sip`          — SIP sunucusu/cihaz adresi, hesap, hedef dahili no
  * `sip_kopru`    — sitedeki PBX (Asterisk/FreeSWITCH) adresi + hesap
  * `kuru_kontak`  — role modulunun HTTP ucu (zil/kapi icin ayri yollar)

Bunlari `headers_json` icine sikistirmak, sozlesmesi olmayan serbest bir
JSON'a is kurali gommek olurdu; panelin hangi alani hangi yontemde
soracagini da bilemezdi.

===========================================================================
UC YONTEM AYNI SOYUTLAMANIN ARKASINDA
===========================================================================
Cagiran kod (panik anonsu, ziyaretci bildirimi) YONTEMI BILMEZ:
`diyafon/taban.py` bir saglayici doner ve `yetenekler()` neyin mumkun
oldugunu soyler. SMS ve odeme soyutlamalarindaki desen.

===========================================================================
YETENEK FARKI SEMADA DEGIL KODDA
===========================================================================
Kuru kontak SESLI MESAJ VEREMEZ (yalniz role kapatir). Bu bir VERI degil
DAVRANIS gercegi; tabloya "anons_yapabilir" diye yazmak, yanlis
isaretlendiginde sunucunun olmayan bir yetenegi denemesi demekti.
Yetenek `taban.py`de yonteme gore SABITTIR ve arayuz onu oradan okur.

===========================================================================
SAGLIK ALANLARI `integration` ILE AYNI (P240 §4 deseni)
===========================================================================
Ayni sutunlar, ayni anlamlar: `bilinmiyor` ≠ `hata`, hata KIMLIGI
(cumle degil), kopusta tek bildirim damgasi. Iki ayri saglik modeli,
"Entegrasyonlar" ekraninda iki ayri okuma bicimi demekti.
"""
from alembic import op

APP_ROLE = "app_rw"

revision = "0142_diyafon"
down_revision = "0141_entegrasyon_sagligi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TYPE diyafon_yontem AS ENUM ('sip', 'sip_kopru', 'kuru_kontak');"
    )
    op.execute(
        """
        CREATE TABLE diyafon (
            id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id      uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad             text NOT NULL,
            yontem         diyafon_yontem NOT NULL,
            -- ADRES: SIP sunucusu / PBX / role modulu. Yontem ne olursa
            -- olsun bir konak vardir; port yontemin varsayilanina duser.
            host           text NOT NULL,
            port           integer,
            -- SIP hesabi (sip + sip_kopru) ya da HTTP temel kimlik
            -- (kuru_kontak). Sifre KEK ile sifreli; GET'te ASLA donmez.
            kullanici      text,
            sifre_enc      text,
            -- SIP hedefi: anonsun/aramanin gidecegi dahili numara.
            hedef          text,
            -- KURU KONTAK: zil ve kapi icin AYRI HTTP yollari. Ayni yol
            -- olsaydi "zil cal" ile "kapi ac" ayirt edilemezdi ve bir
            -- role modulu her ikisini de ayni kanaldan yapamaz.
            zil_yolu       text,
            kapi_yolu      text,
            aktif          boolean NOT NULL DEFAULT true,
            -- SAGLIK (P240 §4 ile AYNI anlamlar)
            saglik              entegrasyon_saglik NOT NULL DEFAULT 'bilinmiyor',
            son_kontrol_at      timestamptz,
            son_basarili_at     timestamptz,
            son_hata_kod        text,
            son_hata_ayrinti    text,
            kopus_bildirildi_at timestamptz,
            created_at     timestamptz NOT NULL DEFAULT now(),
            updated_at     timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT ck_diyafon_port CHECK (
                port IS NULL OR (port BETWEEN 1 AND 65535)
            )
        );
        """
    )
    op.execute("CREATE INDEX ix_diyafon_tenant ON diyafon (tenant_id);")
    op.execute("ALTER TABLE diyafon ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE diyafon FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY diyafon_isolation ON diyafon
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON diyafon TO {APP_ROLE};")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS diyafon;")
    op.execute("DROP TYPE IF EXISTS diyafon_yontem;")
