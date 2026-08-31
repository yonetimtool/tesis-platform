# P192 — Tesis izolasyonu incelemesi (güvenlik)

> **Bildirim:** "Bir tesisin yöneticisi BAŞKA tesislerin kullanıcılarını
> görebiliyor; Kullanıcılar ekranında tüm tesislerin kayıtları listeleniyor."

## Prod verisi ne diyor (2026-08-31, kullanıcı raporu)

Kullanıcılar **5 tesise dağılmış**; şikâyete konu yönetici hesabı yalnız
**Oltu Sitesi**'nde (26 kullanıcı) ve gördüğü liste kendi tesisinin
kullanıcıları. Yani gözlem **2. nedene** (veri düzeni / algı) uyuyor,
sızıntıya değil. Aşağıdaki ölçümler de bunu destekliyor. Kalan tek adım,
prod'da RLS ve bağlantı kimliğinin teyididir (teşhis betiği 1-3).

## Sonuç (özet)

**Backend'de çapraz-tesis sızıntısı bulunamadı.** Sızıntı iddiası dört ayrı
katmanda ölçüldü ve dördü de kapalı çıktı. Ölçümler kalıcı test hâline
getirildi (`backend/tests/test_tesis_izolasyonu_tarama.py`, 79 test).

Bu, "sorun yok" demek **değildir**: gördüğünüz tabloyu üretebilecek üç
neden var ve ikisi koda değil **veriye/role** bakar. Hangisi olduğunu
`infra/tesis-izolasyon-teshis.sh` 30 saniyede söyler.

---

## 1) Ne ölçüldü, ne bulundu

### a. Veritabanı katmanı — kapalı

| Kontrol | Sonuç |
|---|---|
| `tenant_id` taşıyan her tabloda RLS | **ENABLE + FORCE** (istisnasız) |
| `app_rw` superuser mı | hayır |
| `app_rw` BYPASSRLS mı | hayır |
| API hangi kullanıcıyla bağlanıyor | `app_rw` (owner DEĞİL) |

`FORCE` şart: onsuz tablo **sahibi** politikayı atlar. Superuser ise RLS'i
tümden atlar — API owner ile bağlansaydı her uç her şeyi döndürürdü ve bu,
bildirilen tabloyu birebir üretirdi. Bağlantı kullanıcısı bu yüzden
teşhisin **ilk** maddesi.

### b. `/users` — kapalı (doğrudan ölçüldü)

Veritabanında **1655** kullanıcı varken A tesisinin yöneticisi `/users`
çağırdığında **tam olarak A'nın 7 kaydı** döndü; B'den sızan kayıt: 0.

### c. 65 listeleme ucu — kapalı

B tesisine her ana tabloda birer satır yazıldı (daire, görev, talep,
kamera, duyuru, bildirim, finansal hareket, banka hareketi, kullanıcılar);
sonra A'nın **yöneticisi ve admini** 65 ucu çağırdı. Yanıt **metninde**
B'ye ait hiçbir kimlik geçmedi.

Metin araması alan adından bağımsızdır ve bu bilinçli: bir uç sızıntıyı
`items[].id` yerine `meta` ya da iç içe bir alanda yapabilir; alan alan
bakmak, bakmayı unuttuğumuz alanı savunmasız bırakırdı.

Kapsanan uçlar arasında: `/users`, `/units`, `/residents`, `/tasks`,
`/complaints`, `/finans/*`, `/dues/*`, `/banka/hareketler`, `/cameras`,
`/announcements`, `/notifications`, `/devices`, `/push/teshis`,
`/dashboard/live`, `/activity` ve **`/arama`** (çok kaynaklı global arama —
tek uçta sekiz tablo tarar; bir kaynağı süzgeçsiz bırakmak bütün tesisleri
aramaya açardı).

### d. IDOR — kapalı

Liste sızdırmasa bile **kimliği bilinen** tekil kayda erişim ayrı bir
sınıftır. B'nin daire/görev/talep/duyuru/finansal hareket **ve kullanıcı**
kimlikleriyle doğrudan çağrı yapıldı: hepsi 404.

404 beklenir, 403 değil: kaydın **varlığı** da sızmamalı — "yetkiniz yok"
demek, o kimlikte bir kayıt olduğunu doğrulamaktır.

### e. Platform yüzeyi — ayrı ve kapalı (madde 5)

`/tenants`, `/audit`, `/admin/overview`, `/support/all` **tesisler arası
olmak zorundadır**; platform konsolu budur. Ölçüm tersine çevrildi: bir
**tesis rolü (yonetici) bu uçlara giremiyor** (403). "Platform admini her
şeyi görür" kuralı ancak bu kanıtlandığında güvenlidir.

Platform admini ayrı bir **bootstrap tesiste** yaşar
(`backend/scripts/create_admin.py`, `role='admin'`). Yeni tesis kaydı ilk
kullanıcıyı **`yonetici`** olarak açar (`create_tenant_with_yoneticis`) —
yani kayıt yolu kimseye platform yetkisi vermiyor.

---

## 2) Gördüğünüz tabloyu üretebilecek ÜÇ neden

| # | Neden | Belirti | Çözüm |
|---|---|---|---|
| 1 | **Gerçek sızıntı** | RLS kapalı ya da API superuser ile bağlanıyor | Teşhis 1-3; kod tarafı bu turda kapatıldı ve kilitlendi |
| 2 | **Veri düzeni** | O kişiler gerçekten **aynı tenant'ta** (aynı tesise kaydolmuşlar / davet edilmişler) | Sızıntı yok; kayıtlar doğru tesise taşınmalı |
| 3 | **Rol** | O yönetici `admin` (platform) rolünde | Rolü `yonetici`ye çevirin |

**2. neden sanıldığından yaygındır:** kayıt akışında "yeni tesis" yerine
"mevcut tesise katıl" seçilirse ya da davet başka bir tesisin koduyla
gönderilirse kişi o tesise düşer. Ekran doğru çalışıyor, veri yanlış yerde.

`infra/tesis-izolasyon-teshis.sh` üçünü ayırt eder ve **hiçbir şeyi
değiştirmez**.

---

## 3) Bu turda yapılan değişiklikler

* **`backend/tests/test_tesis_izolasyonu_tarama.py` (YENİ, 79 test)** —
  kalıcı kapı: 65 liste ucu + IDOR + platform yüzeyi + şema kapıları
  (RLS açık/zorlanmış, `app_rw` atlayamaz) + kimliksiz istek 401.
  `test_tarama_kapsami_daralmadi` yeni bir liste ucu eklenip taramaya
  yazılmadığında **kapsamın sessizce daralmasını** engeller.
* **`infra/docker-compose.prod.yml`** — `APP_DB_USER` artık `:?` ile
  zorunlu. Boş kalırsa bağlantı kimliği belirsizleşiyordu; yapılandırma
  hatası **sessiz** kalmamalı, yığın açılmamalı.
* **`infra/tesis-izolasyon-teshis.sh` (YENİ)** — prod teşhisi. Altı adım:
  bağlantı kimliği, `app_rw` bayrakları, RLS kapsamı (açık sayıyla),
  platform rolündeki hesaplar, kullanıcıların tesislere dağılımı ve
  **canlı çapraz-tesis ölçümü**.

  Son adım talimat değil ÖLÇÜMDÜR: kimlik verilirse betik gerçekten giriş
  yapar, `/users` çağırır ve dönen kullanıcıların **kaç farklı tesise**
  ait olduğunu veritabanından sayar. 1'den büyükse sızıntı kanıtlanmış
  olur.

  ```bash
  # prod sunucusunda, infra/ içinde:
  ./tesis-izolasyon-teshis.sh                       # 1-5. adımlar
  SLUG=<slug> EPOSTA=<eposta> PAROLA=<parola> \
    ./tesis-izolasyon-teshis.sh                     # + canlı ölçüm
  ```

  **Betik geliştirme yığınında çalıştırılarak doğrulandı** (altı adımın
  hepsi, canlı ölçüm dâhil): koşulmamış bir teşhis betiği, en çok
  ihtiyaç duyulan anda elde araç bırakmamak demektir. Dosya adları
  değişkenleştirildi ki dev'de de aynen denenebilsin:
  `COMPOSE_DOSYA=docker-compose.yml ENV_DOSYA= ./tesis-izolasyon-teshis.sh`

## 4) Ölçüm aracının kendi hatası (kayda değer)

Taramanın ilk sürümü `/arama`yı "sızdırıyor" diye işaretledi. Sebep:
uç, isteğin `q`sunu yanıtta **geri veriyor** (`{"q":"...","items":[]}`) ve
test bu yankıyı sızıntı sandı. Yanlış pozitif üreten bir güvenlik ölçümü,
gerçek açığı ararken sahte açık kovalatır — yankı alanları artık ölçümden
çıkarılıyor ve gerekçe testin içinde yazılı.
