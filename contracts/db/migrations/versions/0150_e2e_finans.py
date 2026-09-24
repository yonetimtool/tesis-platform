"""(E2E 2026-09) FINANS duzeltmeleri — tek gocte toplandi.

Goc `app.*` ithal ETMEZ (dondurulmus kopya kurali). Her bolum kendi
basligiyla ayrilmistir.

===========================================================================
ARAYUZ-4 — `dues_assessment.tutar_kurus` BIGINT
===========================================================================
Kolon `integer`di (ust sinir ~21,4 milyon TL); sema ise `KURUS_UST_SINIR`e
kadar izin veriyordu. 2^31 kurusluk tahakkuk asyncpg'de "value out of int32
range" ile 500 donuyordu. Ayni tutar `/finans/tahsilat`ta (bigint) 201.

===========================================================================
TESIS-08 — BORCUN SAHIBI SILMEDE BOSALMAZ
===========================================================================
`dues_assessment.hedef_user_id` ve `finansal_hareket.user_id` FK'leri
`ON DELETE SET NULL` idi: gecmisi "yalniz borcu" olan sakin
`DELETE /residents` ile SERT silindi ve borc kime ait belli olmadan
kaldi. `hesap_silme` "once sil, FK itiraz ederse anonimlestir" kuralina
dayanir; FK itiraz etmedigi icin yanlis mod secildi.

NO ACTION (RESTRICT DEGIL): kontrol ifade sonunda yapilir. Tesis silindiginde
app_user ve borc satirlari AYNI ifadede cascade ile gider ve kontrol
gecer; RESTRICT ise cascade'den once itiraz ederdi.

===========================================================================
FINANS-03 — HAYALI IPTAL SATIRLARININ ETKISIZLESTIRILMESI
===========================================================================
Onay bekleyen ya da reddedilmis gider "iptal" edilebiliyordu; ters satir
`durum='odendi'` ile yazildigi icin kasaya hic cikmamis para GIRDI
(+900 / +3.500). Uygulama artik reddediyor; mevcut hayali satirlar
`durum='iptal'`e cekilir — tum toplamlar yalniz `odendi` saydigi icin
etkileri kalkar, satirlar (denetim izi) SILINMEZ.

Orijinal SONRADAN onaylanmissa (eski surumde mumkundu) iptal satiri
artik gercek bir duzeltmedir ve DOKUNULMAZ (orijinal `odendi`).

===========================================================================
FINANS-01 — DAIRESIZ TAHSILATIN DAIRESI
===========================================================================
Daire secilmeden alinan tahsilat `unit_id=NULL` yazildi; para kasada,
borc acik. Kisinin TEK aktif dairesi varsa tahsilat o daireye baglanir
(uygulamanin yeni kurali). Cok daireli / dairesiz kisinin satiri
TAHMIN EDILMEZ, oldugu gibi kalir (NOTICE ile sayilir).

===========================================================================
FINANS-07 — DONEMSIZ TAHSILAT
===========================================================================
Kalemsiz tahsilatlar `donem=NULL` yazildi. Oran artik donem alanina
bakmiyor (kalem duzeyinde FIFO), ama `/dues/payments?donem=` suzgeci ve
listeler bakiyor: bos donem islem tarihinin ayiyla doldurulur.

===========================================================================
FINANS-08 — KASASIZ MESAI GIDERI
===========================================================================
Fazla mesai gideri kasasiz yazildi; onaylansa da hicbir kasa bakiyesi
dusmedi. Tesisin varsayilan (banka olmayan, aktif) kasasina baglanir;
kasa yoksa satir oldugu gibi kalir.
"""
from alembic import op

revision = "0150_e2e_finans"
down_revision = "0149_bildirim_kisi_durumu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- ARAYUZ-4 ---------------------------------------------------------
    op.execute(
        "ALTER TABLE dues_assessment ALTER COLUMN tutar_kurus TYPE bigint;"
    )

    # --- TESIS-08 ---------------------------------------------------------
    op.execute(
        "ALTER TABLE dues_assessment DROP CONSTRAINT IF EXISTS fk_assessment_hedef;"
    )
    op.execute(
        "ALTER TABLE dues_assessment ADD CONSTRAINT fk_assessment_hedef "
        "FOREIGN KEY (hedef_user_id, tenant_id) "
        "REFERENCES app_user (id, tenant_id) ON DELETE NO ACTION;"
    )
    op.execute(
        "ALTER TABLE finansal_hareket DROP CONSTRAINT IF EXISTS "
        "finansal_hareket_user_id_tenant_id_fkey;"
    )
    op.execute(
        "ALTER TABLE finansal_hareket ADD CONSTRAINT "
        "finansal_hareket_user_id_tenant_id_fkey "
        "FOREIGN KEY (user_id, tenant_id) "
        "REFERENCES app_user (id, tenant_id) ON DELETE NO ACTION;"
    )

    # --- FINANS-03 --------------------------------------------------------
    op.execute(
        """
        UPDATE finansal_hareket t
           SET durum = 'iptal'
          FROM finansal_hareket o
         WHERE t.ters_kayit_id = o.id
           AND t.tenant_id = o.tenant_id
           AND t.tip = 'iptal'
           AND t.durum = 'odendi'
           AND o.durum <> 'odendi';
        """
    )

    # --- FINANS-01 --------------------------------------------------------
    op.execute(
        """
        DO $$
        DECLARE kalan integer;
        BEGIN
          UPDATE finansal_hareket f
             SET unit_id = tek.unit_id
            FROM (
                  SELECT ur.tenant_id, ur.user_id, min(ur.unit_id::text)::uuid AS unit_id
                    FROM unit_resident ur
                   WHERE ur.bitis IS NULL
                   GROUP BY ur.tenant_id, ur.user_id
                  HAVING count(DISTINCT ur.unit_id) = 1
                 ) tek
           WHERE f.tip = 'tahsilat'
             AND f.unit_id IS NULL
             AND f.user_id IS NOT NULL
             AND tek.tenant_id = f.tenant_id
             AND tek.user_id = f.user_id;

          SELECT count(*) INTO kalan
            FROM finansal_hareket
           WHERE tip = 'tahsilat' AND unit_id IS NULL AND user_id IS NOT NULL;
          IF kalan > 0 THEN
            RAISE NOTICE 'e2e_finans: dairesi cozulemeyen % tahsilat satiri (cok daireli ya da dairesiz kisi) oldugu gibi birakildi', kalan;
          END IF;
        END $$;
        """
    )

    # --- FINANS-07 --------------------------------------------------------
    op.execute(
        """
        UPDATE finansal_hareket
           SET donem = to_char(tarih, 'YYYY-MM')
         WHERE tip = 'tahsilat' AND donem IS NULL;
        """
    )

    # --- FINANS-08 --------------------------------------------------------
    op.execute(
        """
        UPDATE finansal_hareket f
           SET kasa_id = (
                 SELECT k.id FROM kasa k
                  WHERE k.tenant_id = f.tenant_id
                    AND k.aktif AND NOT k.banka_mi
                  ORDER BY (k.kod = 'KASA') DESC, k.created_at, k.id
                  LIMIT 1
               )
         WHERE f.tip = 'gider'
           AND f.kasa_id IS NULL
           AND f.aciklama LIKE 'Fazla mesai%';
        """
    )


def downgrade() -> None:
    # Veri onarimlari (FINANS-01/03/07/08) GERI ALINMAZ: onceki hal hataliydi
    # ve eski kod yeni degerlerle de dogru calisir.
    op.execute(
        "ALTER TABLE finansal_hareket DROP CONSTRAINT IF EXISTS "
        "finansal_hareket_user_id_tenant_id_fkey;"
    )
    op.execute(
        "ALTER TABLE finansal_hareket ADD CONSTRAINT "
        "finansal_hareket_user_id_tenant_id_fkey "
        "FOREIGN KEY (user_id, tenant_id) "
        "REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (user_id);"
    )
    op.execute(
        "ALTER TABLE dues_assessment DROP CONSTRAINT IF EXISTS fk_assessment_hedef;"
    )
    op.execute(
        "ALTER TABLE dues_assessment ADD CONSTRAINT fk_assessment_hedef "
        "FOREIGN KEY (hedef_user_id, tenant_id) "
        "REFERENCES app_user (id, tenant_id) "
        "ON DELETE SET NULL (hedef_user_id);"
    )
    # BIGINT -> integer geri donusu, sigmayan tutar varsa BASARISIZ olur;
    # bu bilincli (sessiz kesme para kaybidir).
    op.execute(
        "ALTER TABLE dues_assessment ALTER COLUMN tutar_kurus TYPE integer;"
    )
