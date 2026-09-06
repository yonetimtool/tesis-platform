# DUKKAN — 00 · MİMARİ

> **AŞAMA 1 / TASARIM.** Bu belgede kod yok. Onay bekliyor.
> **Belgedeki kural:** doğrulayabildiğim her şeyi mevcut koddan ölçtüm; ölçemediğim
> her yere **"EMİN DEĞİLİM"** yazdım. Varsayımı varsayım diye işaretledim.

---

## 0. Önce: okuyamadığım kaynak

`/home/yonetiyoradmin/Yonetiyor_Master_Cloud_Prompt` **okunamadı** — `Permission denied`,
bu makinede `sudo` yok. Ham (uyarlanmamış) prompt'taki maddeleri göremedim.
Bu belgeler **yalnızca senin uyarlanmış prompt'una** ve koddan yaptığım ölçümlere
dayanıyor. Ham dosyada burada olmayan bir kısıt varsa **kaçırmışımdır**.

---

## 1. Ölçtüklerim (tahmin değil)

Tasarımın dayandığı olgular. Her biri komutla doğrulandı.

| # | Ölçüm | Sonuç | Tasarıma etkisi |
|---|---|---|---|
| M1 | `app_user` benzersizlik kısıtları (`\d app_user`) | `uq_app_user_telefon` **UNIQUE, btree (telefon) WHERE telefon IS NOT NULL** → telefon **GLOBAL** benzersiz. `uq_app_user_tenant_email` → e-posta **yalnız tesis içinde** benzersiz | **Dukkan kimliği TELEFONA çapalanır.** E-posta kişiyi tekilleştiremez |
| M2 | `create_access_token` (`app/security.py:110`) | JWT: `sub`, `tenant_id`, `role`, `exp` — `tenant_id` **zorunlu** | Yönetiyor JWT'si Dukkan'da doğrudan kullanılamaz; bağımsız kullanıcının tesisi yok → Dukkan **kendi jetonunu** üretir |
| M3 | `DisHizmet` (`app/models.py:2247`) | `tenant_id` CASCADE, `app_user` FK **yok**, alanlar `tur/ad/soyad/telefon/aciklama` | `dis_hizmet` **pazar yeri değil**, yöneticinin özel defteri. Dukkan onun yerine geçmez → §4 |
| M4 | Tesis adres alanları (P193) | `adres, ilce, il, posta_kodu` — **hepsi nullable** | Bölge ön-doldurma için tek kaynak bu |
| M5 | **`SELECT count(*) FILTER (WHERE il IS NOT NULL) FROM tenant`** | **1 / 2239** | **En sarsıcı bulgu.** "Yönetiyor kullanıcısına bölgeyi ön-doldur" bugünkü veriyle **%99,96 çalışmaz** → §5 |
| M6 | `apps/tanitim-web` | Ayrı Next uygulaması; `lib/backend.ts` → `API_BASE_URL ?? "http://api:8000"`, tarayıcı backend'e **hiç** gitmiyor | Dukkan kamu yüzeyi için **hazır kalıp**; "yalnız API üzerinden" zaten evin deseni |
| M7 | `apps/tanitim-web/app/sitemap.ts` | 7 yolluk **elle yazılmış** dizi | Dukkan'ın sitemap'i **üretilmek** zorunda → `05-seo.md` |
| M8 | `admin-web/tests/uc-sozlesme-kapisi.test.ts` | BFF uç sözleşme kapısı **zaten var** | Dukkan gün 1'de aynı kapıyı kurar → `04-api-sozlesmesi.md` |

---

## 2. Kısıtlar (senin verdiklerin, aynen)

1. **Aynı yığın.** Yeni dil / framework / Kubernetes / Kafka / mikroservis **yok**.
   Tek geliştirici, tek sunucu, mevcut operasyon bilgisi.
2. **Yönetiyor veritabanına doğrudan yazma yok. Okuma da API üzerinden.**
3. Ayrı veritabanı **sunucusu** kurma — aynı PostgreSQL örneği.
4. Üç yüzey: `dukkan.yonetiyor.com` (kamu + SEO), mobil "Dış Hizmetler" sekmesi,
   `app.yonetiyor.com` "Yerel İşletmeler".
5. Ayrı mobil uygulama **yok**. İşletme paneli mobilde **yok**.
6. Yönetiyor kullanıcısı olmayan da kullanabilmeli.

---

## 3. Kararlar

### K1 — Backend: mevcut `api` konteynerine **MODÜL** (ayrı konteyner değil)

`backend/app/dukkan/` altında kendi router paketi, `/dukkan/*` ön ekiyle.

**Neden modül:**
- Ayrı konteyner, **ikinci bir dağıtım yüzeyi** demek: kendi imajı, kendi sağlık
  kontrolü, kendi env'i, kendi Caddy upstream'i, kendi log akışı. Tek geliştirici
  için bu, ürün değeri üretmeyen sabit bir maliyet.
- Kimlik doğrulama **süreç içinde** kalır. Ayrı konteynerde Dukkan'ın Yönetiyor
  JWT'sini doğrulaması için ya `JWT_SECRET`'ı paylaşman (iki servise yayılan sır)
  ya da her istekte bir ağ atlaması gerekir.
- Hazır olan ve **yeniden yazılmayacak** olanlar: hata zarfı `{kod, mesaj}`,
  7 dilli `hata_metinleri.py`, `openapi.yaml` sözleşme kapısı, rol matrisi kilidi,
  push altyapısı, MinIO istemcisi, Celery kuyruğu, denetim günlüğü.
- **P215 dersi doğrudan burada:** `mediamtx`'i ayrı bir servis yaptık ve
  `docker-compose.prod.yml`'de **ağa eklemeyi unuttuk**; hata prod'a kadar gitti.
  Her yeni konteyner bu sınıf hatanın yeni bir fırsatı.

**Maliyeti (dürüstçe):** Dukkan trafiği Yönetiyor `api` süreçleriyle **aynı
havuzu** paylaşır. SEO sayfaları bot trafiği çeker; bir tarama dalgası Yönetiyor
API'sini yavaşlatabilir.
**Azaltma:** aynı imajdan **ikinci bir `api` replikası** (`api-dukkan`) kaldırıp
Caddy'de yalnız `/dukkan/*`'ı oraya yönlendirmek — *aynı kod, ayrı süreç*.
Bu, ayrı konteynerin izolasyonunu ayrı kod tabanının maliyeti olmadan verir ve
**sonradan**, ölçülmüş bir yavaşlama üzerine yapılabilir. V1'de yapma.

### K2 — Veritabanı: aynı örnekte **AYRI ŞEMA** + **AYRI ROL** (ayrı veritabanı değil)

`dukkan` şeması, `public`'in yanında, aynı `tesis` veritabanında.

**Neden ayrı veritabanı değil:**
- Tek bir Alembic zinciri yürütülemez; ikinci bir göç altyapısı, ikinci bir
  `migrate` servisi, ikinci bir yedekleme yolu gerekir.
- Tek bağlantı havuzu bölünür — tek sunucuda bağlantı zaten kıt kaynak
  (bunu P187'de idle-in-transaction 90/100 ile **acıyla** ölçtük).
- Sonradan "şu iki veriyi bir arada oku" gerektiğinde `dblink`/FDW'ye mahkûm olursun.

**Ayrı şema tek başına YETMEZ** — ve tasarımın can alıcı noktası bu.
Aynı veritabanında ayrı şema, "yanlışlıkla `public.app_user`'a yazmayı"
**engellemez**; sadece isimleri ayırır. Senin kısıtın bir isimlendirme
tercihi değil, bir **güvenlik sınırı**. O yüzden:

> **Sınırı şema değil, ROL zorlar.**
> `dukkan_app` adında ayrı bir PostgreSQL rolü: `dukkan` şemasında tam yetki,
> **`public` şemasında hiçbir yetki yok** (`REVOKE ALL ON SCHEMA public`).
> Dukkan modülü **yalnız bu rolle** bağlanan ayrı bir SQLAlchemy engine kullanır.

Bunun kıymeti: kısıt **test edilebilir** hale gelir. "Dukkan bağlantısıyla
`SELECT * FROM public.app_user` çalıştır, `permission denied` bekle" diye bir
test yazılabilir — ve bu test, kısıtı bir gün gözden kaçan bir `import`
ihlal ettiğinde kırmızı yanar. Yorumla yazılmış bir kural bunu yapamaz.

Göç zinciri: aynı Alembic dizini, `dukkan` şemasındaki **ayrı sürüm tablosu**
(`version_table_schema="dukkan"`). Yönetiyor'un 0112'ye varmış zinciriyle
Dukkan'ın zinciri birbirini beklemez.

**EMİN DEĞİLİM:** iki Alembic zincirini tek `migrate` servisinde sırayla
koşturmanın mevcut `test_goc_bagimsizligi.py` kilidiyle nasıl etkileşeceğini
ölçmedim. Uygulama aşamasının **ilk** işi bu olmalı.

### K3 — Yönetiyor verisine erişim: **dar bir köprü**, tabloya asla dokunmadan

Rol kısıtı Dukkan'ın Yönetiyor tablolarını okumasını **fiziksel olarak**
engelliyor (K2). Geriye şu soru kalıyor: Dukkan'ın Yönetiyor'dan gerçekten
neye ihtiyacı var? Ölçtüm — **üç şey, hepsi bu:**

1. Kullanıcının **doğrulanmış telefonu** (kimlik eşleme, M1).
2. Kullanıcının **adı** (profil gösterimi).
3. Kullanıcının bağlı olduğu tesisin **il/ilçe**'si (bölge ön-doldurma — ki M5'e
   göre bu bugün neredeyse hiç yok).

Üçü de **giriş anında bir kez** gerekiyor, sonra Dukkan kendi kaydında tutuyor.

**Önerim:** `backend/app/dukkan/kopru.py` — **en fazla 3 fonksiyonluk**, salt
okunur, adı konmuş bir arayüz. Dukkan'ın Yönetiyor tarafına bakan **tek** kapısı.

**Burada sana dürüst olmam gereken bir yer var.** Modül içi çağrı, kelimenin tam
anlamıyla "API üzerinden" değil — aynı süreçte bir fonksiyon çağrısı.
Alternatif, `api`'nin kendi kendine HTTP çağrısı yapması olurdu: gerçek bir ağ
atlaması, ek gecikme, ek hata yolu ve **sıfır ek güvenlik** (aynı süreç, aynı
kod). Kısıtının *ruhu* — "Dukkan Yönetiyor'un iç yapısına bulaşmasın" —
K2'deki rol yasağı + bu 3 fonksiyonluk kapı ile korunuyor; *lafzı* değil.
**Bunu sana soruyorum, kendi başıma karar vermiyorum** → `06-yol-haritasi.md` §S3.

### K4 — Kiracılık (tenant) ve RLS: Dukkan **çok-kiracılı değil**

Yönetiyor'un RLS'i `app.current_tenant_id`'ye dayanıyor. Dukkan'da tesis kavramı
yok: bir işletme İstanbul'daki 40 siteye birden hizmet verir. `tenant_id`
taşımak, anlamı olmayan bir sütunu her tabloya yaymak olurdu.

İzolasyon sınırı **sahiplik**: `isletme.sahip_kullanici_id`.

**V1'de RLS yok, açık kontrol var** — gerekçesi:
Yönetiyor'da RLS'in değeri, bir hatanın **başka bir sitenin** verisini sızdırması
gibi felaket bir sonucu son savunma hattıyla kesmesi. Dukkan'da verinin
**çoğunluğu tasarım gereği herkese açık** (işletme profilleri, yorumlar, kategori
sayfaları). Özel yüzey dar: talepler, teklifler, iletişim bilgileri.

Dar ve sayılabilir bir yüzeyde, tek bir `sahiplik_dogrula()` yardımcısı +
**her özel uç için zorunlu IDOR testi**, RLS'ten daha okunur ve daha kolay
denetlenir. Kural: özel uç eklendiğinde IDOR testi de eklenir; sözleşme kapısı
bunu zorlar (`04-api-sozlesmesi.md` §5).

**EMİN DEĞİLİM — ve bu bilinçli bir risk.** RLS son savunma hattıdır; açık
kontrol ilk hattır. Yorum sayısı büyüdükçe ve V2'de mesajlaşma geldiğinde
`talep`/`teklif`/`mesaj` üçlüsüne RLS eklemek doğru olabilir. V1'de eklememenin
sebebi maliyet değil, **erken karmaşıklık**: RLS'siz IDOR testi yazmak, RLS'li
yanlış politika yazmaktan daha güvenli.

---

## 4. `dis_hizmet` ile ilişki — Dukkan onun yerine GEÇMEZ

M3'ü ölçtükten sonra bu netleşti. İkisi **farklı iki şey**:

| | `dis_hizmet` (mevcut) | Dukkan (yeni) |
|---|---|---|
| Kim girer | Site yöneticisi | İşletmenin kendisi |
| Kim görür | Yalnız o tesis | Herkes (SEO dahil) |
| Kapsam | Tesise özel (`tenant` CASCADE) | Platform geneli |
| Güven | Yöneticinin şahsi kefaleti | Doğrulama + yorum |
| Anlamı | "Bizim tesisatçımız" | "Bu bölgedeki tesisatçılar" |

Yöneticinin kendi güvendiği çilingirin numarası, bir pazar yeri listesi değil;
**kurumsal hafıza**. Onu Dukkan'a taşımak, yöneticiden bir şey almak olurdu.

**V1: dokunma.** İkisi yan yana yaşar.
**V2 köprüsü (tek yön):** Dukkan'da beğenilen bir işletme için "Dış Hizmetler
listeme ekle" düğmesi → Yönetiyor'un **kendi** `POST /external-services` ucunu
kullanıcının **kendi** jetonuyla çağırır. Dukkan `dis_hizmet` tablosuna
yazmaz — zaten K2'deki rol bunu engeller.

---

## 5. Bölge ön-doldurma — M5 bulgusunu ciddiye almak

Prompt'unda "Yönetiyor kullanıcısı giriş yapınca bölgesi ön-dolu gelir" yazıyor.
**Ölçtüm: 2239 tesisin 1'inde `il` dolu.** Bu özellik bugün yazılırsa
kullanıcıların ~%100'ü boş bir alan görür ve *sanki bozukmuş gibi* hisseder.

Bu bir kusur değil, **veri boşluğu**. Üç seçenek, birlikte:

1. **Ön-doldurma "en iyi çaba" olarak tasarlanır**, garanti olarak değil.
   Boşsa kullanıcı bölgeyi kendi seçer — akışın **normal** hâli bu olmalı,
   istisna değil. (Ters tasarlanırsa boş hâl "hata" gibi görünür.)
2. **Posta kodundan çıkarım.** `posta_kodu` doluluğunu **ölçmedim** — `il`
   sonucuna bakılırsa umut düşük. Ölçülecek.
3. **Veriyi toplamak ayrı bir iştir.** Tesis kurulum sihirbazına (P193) il/ilçe
   adımı eklemek, Dukkan'dan **bağımsız** bir Yönetiyor işi. Dukkan bunu
   bekleyemez; kendi lokasyon seçimini kendi taşır.

**Karar:** Dukkan'ın bölge seçimi **kendi kendine yeter**. Ön-doldurma bir
kolaylıktır; olmadığında hiçbir şey bozulmaz.

---

## 6. Yüzeyler

### 6.1 `dukkan.yonetiyor.com` — yeni Next uygulaması `apps/dukkan-web`

`apps/tanitim-web` kalıbının birebir kardeşi (M6): tarayıcı backend'e hiç
gitmez, her çağrı BFF üzerinden `http://api:8000`'e. SEO burada yaşar.

**Neden `admin-web`'e sayfa değil, ayrı uygulama:**
`admin-web` **giriş arkasında** bir panel — SSR'ı oturuma, çerezine, rol
kapısına bağlı. Kamuya açık, bot tarafından taranan, ISR ile önbelleklenen
sayfaları oraya koymak iki zıt ihtiyacı tek uygulamada çarpıştırırdı.
Ayrıca `tanitim-web` bu ayrımı zaten yapmış ve çalışıyor.

### 6.2 Mobil — mevcut uygulamada sekme

Ayrı uygulama yok (senin kararın; katılıyorum: ikinci bir mağaza kimliği,
ikinci imza zinciri, ikinci sürüm döngüsü, ve **P211'de iOS `aps-environment`
eksikliğini** bulmamız aylar aldı — o sınıf sessiz kırılma iki katına çıkardı).

Kapsam: arama, işletme profili, ara/WhatsApp, talep oluştur, teklifleri gör.

**İşletme paneli mobilde neden yok — gerekçe:**
- İşletme sahibinin işi **veri girişi ağırlıklı**: profil metni, fiyat, çalışma
  saatleri, hizmet alanı olarak onlarca mahalle seçimi, belge yükleme. Bunlar
  masaüstü işleri; mahalle çoklu seçimi telefonda düpedüz eziyet.
- Mobil uygulama **site sakinlerinin** uygulaması. İçine bir işletme paneli
  koymak, her sakinin gördüğü menüye ait olmayan bir dünya sokar.
- **Ölçülen sebep:** her yeni mobil ekran `test/yerlesim/*.txt` yerleşim kilidini,
  menü kilidini ve sözlük çıtçıtını genişletir; mobil takım **tam** koşulmadan
  kırılmaz (hafızadaki kayıt). İşletme paneli gibi büyük bir yüzey için bu bedel,
  masaüstünde bedava olan bir şeyin karşılığında ödenir.
- İşletme sahibi **acil** ne yapar? Yeni teklif bildirimi alır ve teklif verir.
  O ikisi V2'de dar bir şekilde mobile gelebilir — panelin tamamı değil.

### 6.3 `app.yonetiyor.com` → "Yerel İşletmeler"

Yöneticinin yüzeyi: bölgesindeki işletmeleri görür, tesis adına talep açar,
beğendiğini Dış Hizmetler'e ekler (V2, §4).

---

## 7. Dağıtım

Yeni: `dukkan-web` konteyneri (Next), Caddy'de `dukkan.yonetiyor.com` bloğu.
Değişen: `api` (yeni router), `db` (yeni şema + rol).

**P215 dersi zorunlu kontrol listesi olarak:** yeni servis `tesisnet` ağına
eklenecek — `docker-compose.prod.yml`'de. O hatayı bir kez ödedik; ikinci kez
ödememek için dağıtım belgesine ağ doğrulama komutu **girmeden** bitmiş sayılmaz.

---

## 8. V1 dışı — ve veri modelinin bunları engellememesi

| Dışarıda | Gerekçe (seninki, katılıyorum) | Model bugünden ne yapmalı |
|---|---|---|
| Ödeme / abonelik | Şirket yok, fatura kesilemez; ödeme aracılığı BDDK lisansı gerektirebilir | `teklif.tutar` **kuruş `bigint`** tutulur, `float` asla. Para akışı gelirse **P192 dersi: TEK DEFTER** — `finansal_hareket` kalıbı |
| Reklam / sponsorluk | Gelir modeli belirsiz | Sıralama `siralama_puani` üzerinden; sponsorluk sonradan **ayrı** bir alan olur, puana gömülmez |
| AI arama | Klasik arama önce ölçülmeli | Metin arama `pg_trgm`/FTS ile; vektör sonradan **ek** sütun |
| Harita / mesafe | Maliyet ve karmaşıklık | Eşleşme **mahalle** üzerinden (`01-veri-modeli.md` §6). PostGIS eklenirse mahalleye koordinat eklenir, model değişmez |
