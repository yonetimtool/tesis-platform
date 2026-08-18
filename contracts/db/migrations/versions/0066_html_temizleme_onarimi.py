"""(P171) MEVCUT KAYITLARIN HTML ONARIMI — yazma anindaki temizlik geriye islenir.

===========================================================================
NEDEN GEREKLI
===========================================================================
Temizlik bugunden itibaren YAZMA aninda yapiliyor. Ama istemci artik
govdeyi ZENGIN METIN olarak cizecek; dunden kalan bir satirda betik
tasiyicisi varsa, o satir bugun CALISIR hale gelirdi. Yani onarim
gocu, zengin cizimin ON KOSULUDUR — sonradan yapilacak bir temizlik degil.

===========================================================================
IKI TABLO, IKI FARKLI HASSASIYET
===========================================================================
`mesaj_sablonu.govde` — sablonlar TASARIM GEREGI degistirilebilir; yerinde
temizlemek olagan bir guncelleme.

`kvkk_metin.govde` — YAYINLANMIS METIN DEGISTIRILEMEZ (P36 karari):
"yerinde duzenlemeye izin verilseydi dun onay vermis bir kullanicinin
onayi BUGUN BASKA BIR METNE ait gorunurdu." Bu goc o kurala DOKUNUYOR ve
karar bilincli:

  * Temizlik yalniz BETIK TASIYICILARINI kaldirir — `on*` oznitelikleri,
    `<script>`, `<iframe>`, `javascript:` semasi. Bunlarin hicbiri bir
    yasal metnin ICERIGI degildir; kullanicinin okuyup onayladigi CUMLELER
    aynen kalir.
  * Tersi cok daha kotuydu: "metin degismesin" diye bir enjeksiyon
    vektorunu yayinda birakmak, o metni okuyan HER kullanicinin oturumunu
    riske atardi.
  * Yeni SURUM acilmiyor — acmak, hicbir sey degismemis olan tesislerde de
    200 sakini yeniden onaya sokardi ve "surum artti, metin degisti"
    cumlesi YALAN olurdu.

DEGISMEYEN SATIRA DOKUNULMAZ: `WHERE govde <> :temiz`. Cogu satir icin bu
goc hicbir yazma yapmaz ve `updated_at` benzeri alanlar kirlenmez.

===========================================================================
TEMIZLEYICI TEK KAYNAKTAN
===========================================================================
Beyaz liste `app/temizleme.py`de. Buraya KOPYALANMADI: iki liste bir gun
ayrisirdi ve o gun, gocun ureti degerle uygulamanin uretecegi deger
BIRBIRINI TUTMAZDI.

Revision ID: 0066_html_temizleme_onarimi
Revises: 0065_kvkk_platform_yonetimi
"""
from alembic import op
import sqlalchemy as sa

revision = "0066_html_temizleme_onarimi"
down_revision = "0065_kvkk_platform_yonetimi"
branch_labels = None
depends_on = None

#: (tablo, kolon) — zengin metin tasiyan alanlar.
HEDEFLER = (
    ("kvkk_metin", "govde"),
    ("mesaj_sablonu", "govde"),
)


def upgrade() -> None:
    # Ithal FONKSIYON ICINDE: modul yuklenirken uygulama paketine bagimli
    # olmak, `alembic history` gibi kod calistirmayan komutlari da
    # `app`in ithal edilebilirligine baglardi.
    from app.temizleme import zengin_temizle

    baglanti = op.get_bind()
    for tablo, kolon in HEDEFLER:
        # Tablo yoksa (kismi sema, eski ortam) sessizce gec: bir onarim
        # gocu, olmayan bir tablo yuzunden gocun tamamini dusurmemeli.
        var = baglanti.execute(
            sa.text("SELECT to_regclass(:t)"), {"t": f"public.{tablo}"}
        ).scalar()
        if var is None:
            continue

        satirlar = baglanti.execute(
            sa.text(f"SELECT id, {kolon} FROM public.{tablo}")
        ).all()
        for satir in satirlar:
            if satir[1] is None:
                continue
            temiz = zengin_temizle(satir[1])
            if temiz == satir[1]:
                continue
            baglanti.execute(
                sa.text(
                    f"UPDATE public.{tablo} SET {kolon} = :g WHERE id = :i"
                ),
                {"g": temiz, "i": satir[0]},
            )


def downgrade() -> None:
    # GERI ALINAMAZ VE ALINMAMALI: atilan sey betik tasiyicisiydi, veri
    # degil. "Geri yukleme" diye bir sey, kaldirilan enjeksiyon vektorunu
    # geri koymak olurdu. Goc bu yonde BILEREK bostur.
    pass
