"""(E2E 2026-09) TESIS operasyonu duzeltmeleri — tek gocte toplandi.

Bu dosya birden fazla bulgunun VERI tarafini tasir; her bolum kendi
basligiyla ayrilmistir. Goc `app.*` ithal ETMEZ (dondurulmus kopya kurali).

===========================================================================
TESIS-07 / GUVENLIK-05 — NFC UID NORMALIZASYONU
===========================================================================
OLCULEN: `04A1B2C3D4E500`, `04a1b2c3d4e500` ve `04:A1:B2:C3:D4:E5:00` UC
AYRI kontrol noktasi olarak kaydediliyordu (tekillik ham degerde). Okutma
normalize karsilastirdigi icin `scalar_one_or_none` MultipleResultsFound
ile 500 veriyordu; etiket fiilen devre disi kaliyor, turlar "kacirildi"
yaziliyordu. Mobil UID'yi ayracsiz BUYUK harf uretir (`nfc_service.dart`).

KANONIK BICIM: bosluk, ':' ve '-' atilir, kalan BUYUK harf. Uygulama
(`crud_helpers.norm_nfc`) yazarken ayni bicimi uretir.

CAKISMA POLITIKASI — GOC PATLAMAZ: normalize sonrasi ayni degere dusen
kayitlar (ayni tenant) OLDUKLARI GIBI birakilir ve her grup WARNING ile
raporlanir (`docker compose logs migrate` icinde "e2e_tesis NFC cakismasi").
Hangisinin dogru etiket oldugunu goc bilemez — tur gecmisi (scan_event)
ikisine de bagli olabilir; birini silmek ya da birlestirmek veri kaybidir.
Yonetici birini silip digerini duzeltir. Okutma ucu bu arada 500 vermez:
birden cok eslesmede kanonik bicimde saklanan / en eski kayit secilir.
Cakismayan kayitlar kanonik bicime cekilir.

Bilincli olarak CHECK KISITI KONMADI: NOT VALID bir CHECK bile birakilan
cakisma satirlarinin HER guncellemesini (ad degistirme dahil) reddederdi.
"""
from alembic import op

revision = "0151_e2e_tesis"
down_revision = "0150_e2e_finans"
branch_labels = None
depends_on = None


# Uygulamadaki `norm_nfc` ile AYNI ifade: bosluk / ':' / '-' at, BUYUK harf.
_NFC_NORM = "upper(regexp_replace({col}, '[[:space:]:-]', '', 'g'))"


def upgrade() -> None:
    # --- TESIS-07 / GUVENLIK-05: NFC UID normalizasyonu ---
    c_norm = _NFC_NORM.format(col="c.nfc_tag_uid")
    d_norm = _NFC_NORM.format(col="d.nfc_tag_uid")
    op.execute(
        f"""
        DO $$
        DECLARE r record;
        BEGIN
          FOR r IN
            SELECT c.tenant_id, {c_norm} AS norm, count(*) AS adet,
                   string_agg(c.id::text || '=' || c.nfc_tag_uid, ', ') AS kayitlar
              FROM checkpoint c
             GROUP BY c.tenant_id, {c_norm}
            HAVING count(*) > 1
          LOOP
            RAISE WARNING 'e2e_tesis NFC cakismasi: tenant=% uid=% (% kayit): %',
              r.tenant_id, r.norm, r.adet, r.kayitlar;
          END LOOP;

          UPDATE checkpoint c
             SET nfc_tag_uid = {c_norm}
           WHERE c.nfc_tag_uid <> {c_norm}
             AND {c_norm} <> ''
             AND NOT EXISTS (
                   SELECT 1 FROM checkpoint d
                    WHERE d.tenant_id = c.tenant_id
                      AND d.id <> c.id
                      AND {d_norm} = {c_norm}
                 );
        END $$;
        """
    )


def downgrade() -> None:
    # --- TESIS-07 / GUVENLIK-05 ---
    # Veri normalizasyonu GERI ALINAMAZ (ham bicim saklanmadi); kanonik
    # bicim eski kodla da calisir (eski okutma zaten upper(btrim) ile
    # karsilastiriyordu).
    pass
