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
BEYAZ LISTE BURADA DONMUS DURUR — UYGULAMA MODULU ITHAL EDILMEZ
===========================================================================
Ilk yazimda bu goc `app.temizleme`yi ithal ediyordu; gerekce "tek dogruluk
kaynagi" idi. GEREKCE YANLISTI ve test ortamini dusurdu.

NE OLDU: `infra/docker-compose.yml` `contracts/` dizinini CANLI MOUNT eder,
`backend/app/` ise IMAJA GOMULUDUR. Yani goc dosyasi ile uygulama kodu
FARKLI KANALLARDAN gelir ve FARKLI SURUMLERDE olabilir. Depo guncellenip
imaj yeniden kurulmadiginda konteyner YENI gocu gorur ama ESKI kodu tasir:
`ModuleNotFoundError: app.temizleme`. Goc dustu, sema 0064'te kaldi, sema
uyumsuzlugu yuzunden api/worker/admin-web ayaga kalkamadi ve ortam
tamamen erisilemez oldu.

ASIL ILKE: GOCLER TARIHSEL KAYITTIR. Bir goc, YAZILDIGI ANDAKI dunyayi
tarif eder ve yillar sonra da ayni sonucu uretmelidir. Bugunun uygulama
koduna baglanan bir goc, o kod degistiginde (yeniden adlandirma, imza
degisikligi, silinme) GECMISI degistirir ya da kirar. Bu yuzden beyaz
liste asagida DONDURULMUSTUR ve `app/temizleme.py` ile ayrisabilir —
ayrismasi bir kusur DEGIL, dogru davranistir: bu goc 2026'daki kurali
uygular, bugunku uygulama bugunku kurali.

`nh3` yine de ithal ediliyor ve bu FARKLI bir sey: bir kutuphane
bagimliligidir, uygulama kodu degil; `requirements.txt` uzerinden IMAJA
girer, yani goc dosyasiyla AYNI kanaldan degil ama alembic'in kendisiyle
AYNI kanaldan. Yoksa goc ACIKCA ve OKUNUR bicimde durur (asagi bak) —
sessizce atlamak, guvenlik onarimini yapilmamis birakip yapilmis
saymak olurdu.

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


#: (P171) BU REVIZYONDA DONDURULMUS beyaz liste. `app/temizleme.py`nin
#: kopyasi DEGIL, o tarihteki halinin KAYDI. Uygulama listesi degisirse
#: burasi DEGISMEZ — bkz. modul basligi.
_ETIKETLER = {
    "p", "br", "strong", "em", "u", "s",
    "h1", "h2", "h3", "h4",
    "ul", "ol", "li",
    "a",
    "blockquote", "hr",
}
_OZNITELIKLER = {"a": {"href", "title"}}
_SEMALAR = {"http", "https", "mailto"}


def _temizle(govde: str) -> str:
    """Donmus beyaz listeyle temizler.

    Ithal FONKSIYON ICINDE: modul yuklenirken bir kutuphaneye bagimli
    olmak, `alembic history` gibi kod calistirmayan komutlari da onun
    varligina baglardi.
    """
    try:
        import nh3
    except ModuleNotFoundError as e:  # pragma: no cover - ortam arizasi
        raise RuntimeError(
            "0066: `nh3` bulunamadi. Bu goc bir GUVENLIK ONARIMIDIR ve "
            "sessizce atlanamaz. Migrate imaji `backend/requirements.txt` "
            "ile YENIDEN KURULMALI: `docker compose build migrate api`."
        ) from e

    return nh3.clean(
        govde,
        tags=_ETIKETLER,
        attributes={k: set(v) for k, v in _OZNITELIKLER.items()},
        url_schemes=_SEMALAR,
        link_rel="noopener noreferrer",
        strip_comments=True,
    )


def upgrade() -> None:
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
            temiz = _temizle(satir[1])
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
