"""vezne idempotency (0028) — MASTER-PLAN P64: cift kayit riski kapatildi.

OLCULEN RISK (P64 Notes). Iki odeme yolundan yalniz BIRI korunuyordu:
`POST /dues/payments` `Idempotency-Key` ZORUNLU kilar; vezne yolu
(`finansal_hareket` yazan alti uc) kimliksizdi. Panelin dugmesi ucus
sirasinda kilitli oldugu icin HIZLI CIFT TIKLAMA zaten korunuyordu;
korunmayan sey ZAMAN ASIMI SONRASI TEKRARDI — istek sunucuya ulasip
yanit donmezse kullanici "kaydedilmedi" sanip tekrar basar ve kasada
IKI hareket olusur. Yonetici bunu ancak mutabakatta fark eder.

NEDEN AYRI SUTUN, `dues_payment`e BIRLESTIRME DEGIL: `finans.py` bu
ayrimi bilincli belgeliyor — `dues_payment` SAGLAYICI odaklidir
(provider referansi, webhook durumu), `finansal_hareket` ise VEZNE
kaydidir ve kasayi etkiler. Ikisini birlestirmek, saglayici alanlarini
her nakit tahsilatta bos birakmak demekti. Bu revizyon o ayrimi KORUR
ve yalnizca eksik olan kimligi ekler.

NEDEN NULLABLE + KISMI BENZERSIZ INDEKS (dues_payment'taki NOT NULL
degil): tabloda GECMIS kayitlar var ve prod calisiyor. NOT NULL bir
sutun, mevcut satirlara uydurma bir kimlik yazmak demekti. Kimlik
GONDERILDIGINDE tekillik zorlanir, gonderilmediginde eski davranis
aynen surer — yani bu revizyon GERIYE UYUMLUDUR. Ayni desen depoda
zaten var: `uq_checkout_birakma_idem` (0001).

TEKILLIK KAPSAMI `(tenant_id, idempotency_key, idem_satir)`: kimlik
istemcide uretilir, iki tesisin ayni kimligi uretmesi cakisma
sayilmamalidir — bu yuzden `tenant_id` icerde.

NEDEN UCUNCU SUTUN (`idem_satir`): bir vezne islemi BIRDEN COK SATIR
uretebilir — virman IKI satirdir (cikis + giris), toplu tahsilat ve
"Yeni Satir" akisi N satir yazar. Yalniz `(tenant_id, key)` uzerinde
tekillik, kimligi satirlarin YALNIZ BIRINE yazdirirdi ve tekrar geldiginde
sunucu islemin OTEKI satirlarini bulamazdi (eksik yanit). Satir sirasi
islem icinde deterministik oldugu icin tekrar gelen istek AYNI
(key, satir) ciftlerine carpar ve veritabani onu reddeder.

Revision ID: 0028_vezne_idempotency
Revises: 0027_portal_anket
"""
from __future__ import annotations

from alembic import op

revision = "0028_vezne_idempotency"
down_revision = "0027_portal_anket"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE finansal_hareket ADD COLUMN idempotency_key text;")
    op.execute("ALTER TABLE finansal_hareket ADD COLUMN idem_satir smallint;")
    op.execute(
        "CREATE UNIQUE INDEX uq_hareket_tenant_idem "
        "ON finansal_hareket (tenant_id, idempotency_key, idem_satir) "
        "WHERE idempotency_key IS NOT NULL;"
    )


def downgrade() -> None:
    # Indeks sutunlarla birlikte DUSER, ama acikca dusurulur: `DROP COLUMN`in
    # yan etkisine guvenmek, indeksin bagimsiz oldugu bir gelecekte sessiz
    # bir kalinti birakirdi (goc-tersinirlik.sh "ARTIK" olcumu bunu yakalar).
    op.execute("DROP INDEX IF EXISTS uq_hareket_tenant_idem;")
    op.execute("ALTER TABLE finansal_hareket DROP COLUMN IF EXISTS idem_satir;")
    op.execute("ALTER TABLE finansal_hareket DROP COLUMN IF EXISTS idempotency_key;")
