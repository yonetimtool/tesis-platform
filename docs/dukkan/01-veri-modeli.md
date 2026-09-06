# DUKKAN — 01 · VERİ MODELİ

> Şema: **`dukkan`** (aynı PostgreSQL örneği, ayrı rol — bkz. `00-mimari.md` §K2).
> **Yönetiyor tablolarına FK YOK.** Ne mantıken ne fiziksel olarak: `dukkan_app`
> rolünün `public` şemasında yetkisi yok, dolayısıyla böyle bir FK zaten kurulamaz.
> Bu, kısıtın kod incelemesine değil **veritabanına** gömülmesi demek.

Tüm tablolarda ev kuralları: `id uuid` PK, `created_at`/`updated_at timestamptz`,
para **kuruş `bigint`** (asla `float`), metinler `text`.

---

## 1. Kimlik — `dukkan_kullanici`

**Ölçüme dayanan tek karar (M1).** `app_user`'da telefon **global** benzersiz
(`uq_app_user_telefon`), e-posta **yalnız tesis içinde** benzersiz
(`uq_app_user_tenant_email`).

Bunun doğrudan sonucu: **e-posta bir kişiyi tekilleştiremez.** Aynı e-posta
Yönetiyor'da iki farklı tesiste iki farklı `app_user` satırı olabilir.
Dukkan kimliğini e-postaya çapalasaydım, iki tesiste birden kayıtlı bir kişi
Dukkan'da iki hesap olurdu — ya da daha kötüsü, iki farklı insan bir hesapta
birleşirdi.

> **Dukkan'ın kimlik çapası: DOĞRULANMIŞ TELEFON.**

```
dukkan_kullanici
  id                    uuid PK
  telefon               text NOT NULL UNIQUE      -- E.164, tek gerçek kimlik
  telefon_dogrulandi_at timestamptz               -- NULL = doğrulanmamış
  ad_soyad              text
  eposta                text                      -- opsiyonel, UNIQUE DEĞİL
  eposta_dogrulandi_at  timestamptz
  tip                   text  -- 'bireysel' | 'isletme_sahibi'
  durum                 text  -- 'aktif' | 'askida' | 'silindi'
  varsayilan_mahalle_id uuid FK -> mahalle NULL
  kvkk_onay_at          timestamptz
  son_giris_at          timestamptz
```

`tip` bir **rol değil, başlangıç niyeti**. Bir kişi hem hizmet alan hem işletme
sahibi olabilir; yetki `isletme.sahip_kullanici_id` üzerinden okunur (`02`).

### Yönetiyor bağı — ayrı tablo, çünkü çoğa-bir

```
dukkan_yonetiyor_bag
  id                  uuid PK
  dukkan_kullanici_id uuid FK -> dukkan_kullanici NOT NULL
  yonetiyor_user_id   uuid NOT NULL      -- FK DEĞİL (başka şema, kasıtlı)
  yonetiyor_tenant_id uuid NOT NULL      -- FK DEĞİL
  UNIQUE (yonetiyor_user_id, yonetiyor_tenant_id)
```

Neden ayrı tablo: **bir kişi birden çok tesiste olabilir** (senin belirttiğin
kısıt, M1 ile doğrulandı). Üç sitede yöneticilik yapan biri Yönetiyor'da 3
`app_user` satırıdır ama **tek telefondur** → Dukkan'da **tek kullanıcı, üç bağ**.
Bağı `dukkan_kullanici` üzerinde iki sütun olarak tutsaydım bu kişi ya
üç hesaba bölünürdü ya da üç tesisten ikisi kaybolurdu.

`yonetiyor_user_id` bilerek **FK değil**: şemalar arası FK, K2'deki rol yasağını
delerdi. Bütünlük uygulama katmanında; sarkan kayıt riski kabul edilmiş ve
`02-kimlik-ve-yetki.md` §6'da nasıl yönetileceği yazılı.

---

## 2. Lokasyon — `ulke > il > ilce > mahalle`

```
ulke   (id, kod 'TR', ad)
il     (id, ulke_id, ad, plaka smallint, slug)      -- 81
ilce   (id, il_id, ad, slug)                        -- ~970
mahalle(id, ilce_id, ad, slug, posta_kodu, tip)     -- ~50.000+
         tip: 'mahalle' | 'koy' | 'belde'
UNIQUE (il_id, slug), (ilce_id, slug) ...           -- SEO yolları için
```

`slug` **kalıcıdır ve elle yönetilir**: SEO URL'i ona bağlı (`05-seo.md`).
Bir mahallenin adı idari kararla değişse bile slug değişmez; değişmesi
gerekiyorsa 301 ile eski slug yaşatılır. Slug'ı addan her seferinde türetmek,
sessizce ölü bağlantı üretmenin en kısa yoludur.

### Veri kaynağı — araştırdım, kesin sonuç şu

| Kaynak | Ne | Değerlendirme |
|---|---|---|
| **NVI / AKS** (`adres.nvi.gov.tr`) | Resmî Adres Kayıt Sistemi | **Otoritatif kaynak budur.** Ama halka açık toplu indirme/serbest API'si **yok**; MAKS kurumlara (belediye) protokolle açılıyor. **Tek kişilik bir ürünün erişemeyeceğini varsayıyorum — EMİN DEĞİLİM, doğrulanmalı** |
| **NVI web sorgu** | İl→ilçe→mahalle kademeli sorgu | Resmî veriyi **bir kez** çıkarmanın pratik yolu; toplu/otomatik çekim izin durumu **EMİN DEĞİLİM** |
| **GitHub: `emreuenal/...-veri-tabani`** | NVI türevi, PostgreSQL dökümü | ~~V1 için önerim~~ → **REDDEDİLDİ.** Lisansı **GPL-3.0**, son güncelleme **Nisan 2021**. "Lisansı net + ticari kullanıma uygun" şartını karşılamıyor |
| **GitHub: `ferhat-mousavi/turkiye-il-ilce-mahalle-koy`** | JSON, hiyerarşik | **SEÇİLDİ. Lisans: MIT** (LICENSE dosyası var). Ancak verisi HAM HALİYLE KULLANILAMAZDI — aşağıya bak |
| **GitHub: `bertugfahriozer/il_ilce_mahalle`** | JSON, TÜİK/İçişleri kaynaklı | README "ticari kullanılabilir" diyor ama **LICENSE dosyası YOK**. Bir README cümlesi resmî lisans değil; kullanılmadı |
| **TurkiyeAPI / Tradres** | REST API | Çalışma anında dış servise bağımlılık — **hayır.** Lokasyon ağacı SEO URL'lerinin temeli; dış servis düşünce site çöker. Yalnız **ilk yükleme** için kullanılabilir |


### Seçilen kaynak ham haliyle kullanılamazdı — ölçüldü ve onarıldı

MIT lisansı temiz olsa da **verinin kendisi bozuktu**. İndirip ölçtüm:

| Ölçüm | Sonuç |
|---|---|
| 74.402 Türkçe adda **`ı` harfi** | **0 kez** — Türkçede `ı` çok yaygın ("Balıkesir", "Çınarlı"); sıfır olması istatistiksel olarak imkânsız |
| U+0307 birleşen nokta taşıyan mahalle adı | **%83,6** (`"Mahallesi̇"`) |
| İl adları | Onlar da bozuk: `Balikesi̇r`, `Di̇yarbakir`, `Afyonkarahi̇sar` |

**Teşhis:** kaynak metin BÜYÜK HARFTİ ve **Türkçe olmayan bir yerel ayarla**
küçültülmüş. Python'da bu dönüşüm birebir şudur:
`'İ'.lower()` → `'i' + U+0307`, `'I'.lower()` → `'i'` (doğrusu `'ı'` olmalıydı).

**Bozulma geri döndürülebilir**, çünkü iki durum birbirinden ayırt edilebiliyor:
biri birleşen nokta taşıyor, öteki taşımıyor. Onarım uygulandı ve
**tahminle değil ölçümle** doğrulandı:

- **81/81** il adı bilinen doğru adla eşleşti,
- **39/39** İstanbul ilçesi eşleşti,
- brief'in örnek yolu `Çatalmeşe` doğru biçimde bulundu,
- yükleme sonrası: 14.113 adda `ı` geri geldi, **bozuk kayıt 0**.

**Yüklenmeyenler:** `Mevkii` (22.912) ve `Mezrası` (5.337). Bunlar kırsal
konum adları; bir usta hizmet alanı olarak "mevki" seçmez. Yüklemek, mahalle
seçicisini 45.000 yerine 74.000 seçeneğe çıkarır ve hiçbir işletme onları
seçmeyeceği için o sayfalar **kalıcı olarak SEO eşiğinin altında** kalırdı.

**Yüklenen: 81 il / 973 ilçe / 44.719 mahalle+köy.** Slug çakışması: 0.

### Kaynak izi veritabanında: `dukkan.veri_kaynagi`

Senin şartın "kaynağı ve indirme tarihini belgele" idi. Bunu bir markdown
cümlesi yerine **tabloya** koydum: `kaynak_url`, `lisans`, `surum`, `sha256`,
`indirme_tarihi`, `kayit_sayisi`, `onarim_notu`.

Gerekçe: iki yıl sonra "bu mahalle listesi nereden geldi, ne zaman, hangi
sürümden?" diye soran kişi kodu değil **veritabanını** sorgular. `sha256`
ayrıca aynı dosyanın yeniden yüklenip yüklenmediğini kesin söyler — dosya adı
ve tarih yanıltıcıdır, özet değildir.

**Güncelleme yolu:** yılda 1-2 kez yeni döküm → **fark raporu** (yeni/silinen/
adı değişen) → **elle onay**. Otomatik uygulanmıyor: silinen bir mahalle,
ona bağlı işletmeleri ve canlı SEO sayfalarını sessizce düşürür.

**Karar:** lokasyon verisi **Dukkan'ın kendi tablosunda yaşar**, çalışma anında
hiçbir dış servise sorulmaz. Bir kez yüklenir, elle güncellenir.

**Neden çalışma anında dış servis yok:** `/istanbul/cekmekoy/catalmese/elektrikci`
sayfası varlığını `mahalle` satırına borçlu. Bu satır bir API'den geliyorsa,
API'nin kesintisi **binlerce SEO sayfasının 500 vermesi** demek — Google'ın
gördüğü en kötü sinyal.

**Güncelleme yolu:** yılda bir-iki kez yeni döküm alınır, bir **fark raporu**
üretilir (yeni/silinen/adı değişen mahalleler) ve **elle onaylanır**. Otomatik
uygulama yok: silinen bir mahalle, o mahalleye bağlı işletmeleri ve canlı SEO
sayfalarını sessizce düşürebilir. Yılda iki kez 10 dakikalık göz kontrolü,
bu riskin karşılığında ucuz.

**Nüfus/il sayısı gibi rakamlar yaklaşıktır — EMİN DEĞİLİM**, yükleme sırasında
gerçek sayı ölçülüp buraya yazılacak.

### PostGIS — V1'de HAYIR, gerekçesiyle

Eşleşme **mahalle kimliği** üzerinden: işletme mahalle listesi seçer, talep bir
mahalleye düşer, eşleşme `isletme_hizmet_alani` üzerinden bir JOIN.

PostGIS'in maliyeti yalnız eklenti kurmak değil:
- Her mahalleye **koordinat/sınır poligonu** gerekir — bu veri ayrı bir iş ve
  ücretsiz sürümü genelde nokta merkezi, poligon değil.
- Yarıçap sorgusu ("5 km içindeki ustalar") **kullanıcının konumunu** ister →
  yeni bir KVKK yüzeyi (konum verisi), yeni izin metni.
- İşletmenin "ben şu mahallelere giderim" beyanı, çoğu zaman yarıçaptan **daha
  doğru**: bir usta 3 km ötedeki mahalleye köprü yüzünden gitmiyor olabilir.

**Sonradan eklemek ucuz:** `mahalle`'ye `konum geography(Point)` sütunu eklenir,
mevcut sorgular değişmez. Model bugünden buna kapalı değil.

---

## 3. Kategori — `kategori`

```
kategori
  id            uuid PK
  ust_id        uuid FK -> kategori NULL    -- 2 seviye: ana > hizmet
  ad            text
  slug          text NOT NULL               -- SEO; UNIQUE (ust_id, slug)
  aciklama      text
  sira          int
  aktif         bool
  ikon          text
```

İki seviye yeter: `Tadilat > Boya Badana`. Üçüncü seviye hem kullanıcıyı hem
URL'i uzatır, hem de armut.com'un yaptığı gibi *soru setiyle* daraltmak
(V2) daha iyi bir daraltma yoludur.

`talep_sorusu` (V2, şimdi **yazma**): kategoriye bağlı soru şablonu. Bugün
yalnız yerini ayırıyorum ki `talep` modeli sonradan kırılmasın.

---

## 4. İşletme — `isletme`

```
isletme
  id                  uuid PK
  sahip_kullanici_id  uuid FK -> dukkan_kullanici NOT NULL
  ad                  text NOT NULL
  slug                text NOT NULL UNIQUE       -- /isletme/{slug}
  aciklama            text
  telefon             text NOT NULL
  telefon_dogrulandi_at timestamptz
  whatsapp            text
  eposta              text
  vergi_no            text                       -- 10 hane TCKN/VKN
  vergi_dairesi       text
  adres_mahalle_id    uuid FK -> mahalle          -- MERKEZ; hizmet alanı ayrı
  adres_detay         text
  durum               text NOT NULL
      -- 'taslak' | 'onay_bekliyor' | 'onayli' | 'askida' | 'reddedildi'
  dogrulama_seviyesi  smallint NOT NULL DEFAULT 0   -- 03-guven §3
  red_sebebi          text
  siralama_puani      numeric                    -- türetilmiş, 05-seo §6
  ortalama_puan       numeric                    -- türetilmiş (yorumdan)
  yorum_sayisi        int                        -- türetilmiş
  askiya_alma_sebebi  text
  onaylandi_at        timestamptz
```

`ortalama_puan` / `yorum_sayisi` **bilerek türetilmiş sütun**: kategori
sayfasında 20 işletme listelenirken her biri için yorum toplamı hesaplamak
N+1 üretir. Yorum yazıldığında/moderasyondan geçtiğinde tek yerde güncellenir.
**Kural:** bu iki sütunu güncelleyen **tek bir fonksiyon** olur; ikinci bir
yazma yolu açılırsa sayı sessizce kayar (P192'nin "tek defter" dersinin
buradaki karşılığı).

```
isletme_kategori        (isletme_id, kategori_id) PK       -- M2M
isletme_hizmet_alani    (isletme_id, mahalle_id) PK        -- M2M, service_areas
isletme_belge           (id, isletme_id, tip, dosya_yolu, durum, inceleyen, not)
      -- tip: 'vergi_levhasi' | 'ustalik_belgesi' | 'sicil' ...
      -- dosya MinIO'da; 03-guven §3
isletme_calisma_saati   (isletme_id, gun smallint, acilis time, kapanis time)
```

`isletme_hizmet_alani` mahalle bazında, çünkü eşleşme motorunun tamamı bu.
40 mahalle seçen bir işletme 40 satır — küçük ve indekslenebilir.

---

## 5. Talep, teklif, iş — **KVKK'nın göbeği**

### 5.1 `talep`

```
talep
  id                uuid PK
  kullanici_id      uuid FK -> dukkan_kullanici NOT NULL
  kategori_id       uuid FK -> kategori NOT NULL
  mahalle_id        uuid FK -> mahalle NOT NULL   -- teklif aşamasında GÖRÜNEN tek konum
  baslik            text
  aciklama          text NOT NULL
  butce_min_kurus   bigint
  butce_max_kurus   bigint
  durum             text  -- 'acik'|'teklif_var'|'is_verildi'|'iptal'|'suresi_doldu'
  son_gecerlilik    timestamptz
  -- KVKK: PAYLAŞIM TERCİHLERİ
  paylas_telefon    bool NOT NULL DEFAULT false
  paylas_adres      bool NOT NULL DEFAULT false
  paylas_ad         bool NOT NULL DEFAULT false
  -- Açık adres, teklif aşamasında KİMSEYE gösterilmez
  acik_adres        text
  adres_mahalle_id  uuid FK -> mahalle
  tesis_id_beyan    uuid     -- Yönetiyor tesisi ise; FK DEĞİL, yalnız iz
```

> **Bu tablonun en önemli özelliği, üç `paylas_*` sütununun `DEFAULT false`
> olması.** Sakinin adresi, daire numarası ve telefonu bir işletmeye
> **hiçbir koşulda kendiliğinden** gitmez. Varsayılan `true` olsaydı, formda
> onay kutusunu kaldırmayı unutan bir kullanıcı verisini paylaşmış olurdu;
> `false` ile unutmanın cezası "veri paylaşılmadı"dır — güvenli yön.

**Daire numarası özellikle:** `acik_adres` serbest metin ve **iş kabul
edilene kadar hiçbir sorgu onu döndürmez**. Bunu bir sunucu kuralı olarak
`04-api-sozlesmesi.md` §4'te ve bir testle kilitliyorum, arayüz kuralı olarak
değil — arayüz kuralı, ikinci bir istemci (mobil) geldiğinde delinir.

### 5.2 `teklif`

```
teklif
  id            uuid PK
  talep_id      uuid FK -> talep NOT NULL
  isletme_id    uuid FK -> isletme NOT NULL
  tutar_kurus   bigint            -- NULL = "yerinde görmem gerek"
  mesaj         text
  durum         text  -- 'gonderildi' | 'kabul' | 'red' | 'geri_cekildi'
  gecerlilik    timestamptz
  UNIQUE (talep_id, isletme_id)   -- bir işletme bir talebe BİR teklif
```

`tutar_kurus` nullable, çünkü gerçek hayatta usta çoğu işe bakmadan fiyat
vermez. Zorunlu yapmak, ustayı uydurma rakam yazmaya iter — sonra da
müşteri "fiyat tutmadı" diye şikâyet eder. Boş bırakabilmek daha dürüst.

### 5.3 `is` — adresin açıldığı yer

```
is
  id            uuid PK
  talep_id      uuid FK -> talep NOT NULL UNIQUE
  teklif_id     uuid FK -> teklif NOT NULL
  isletme_id    uuid FK -> isletme NOT NULL
  kullanici_id  uuid FK -> dukkan_kullanici NOT NULL
  durum         text  -- 'kabul'|'devam'|'tamamlandi'|'iptal'|'anlasmazlik'
  kabul_at      timestamptz NOT NULL
  tamamlandi_at timestamptz
```

`is` satırının varlığı iki şeyin **tek** anahtarı:
1. açık adres + telefon o işletmeye açılır,
2. **doğrulanmış yorum** hakkı doğar (`03-guven-ve-fraud.md` §2).

`UNIQUE(talep_id)`: bir talepten bir iş. Aynı talebi iki ustaya vermek
isteyen kullanıcı ikinci bir talep açar — yoksa "hangi işin yorumu bu?"
sorusu cevapsız kalır.

---

## 6. Yorum ve güven

```
yorum
  id             uuid PK
  isletme_id     uuid FK -> isletme NOT NULL
  yazan_id       uuid FK -> dukkan_kullanici NOT NULL
  is_id          uuid FK -> is NULL          -- DOLU = doğrulanmış
  kaynak         text NOT NULL  -- 'platform' | 'davet'
  puan           smallint NOT NULL CHECK (puan BETWEEN 1 AND 5)
  metin          text
  durum          text NOT NULL  -- 'beklemede'|'yayinda'|'reddedildi'|'gizlendi'
  moderasyon_not text
  yayinlandi_at  timestamptz
  UNIQUE (is_id)                          -- bir işe bir yorum
  UNIQUE (isletme_id, yazan_id, kaynak)   -- 'davet' için 03-guven §2.3
yorum_cevap  (id, yorum_id UNIQUE, isletme_id, metin, durum)
yorum_davet  (id, isletme_id, telefon, kod, durum, gonderildi_at, kullanildi_at)
sikayet      (id, sikayetci_id, isletme_id, is_id NULL, tip, metin, durum,
              atanan, sonuc, kapandi_at)      -- 6563, 03-guven §5
denetim      (id, aktor_id, aktor_tip, eylem, hedef_tip, hedef_id, meta jsonb, ip)
```

`is_id` nullable — ve **bu, ürünün en zor kararı** (`03-guven-ve-fraud.md` §2'de
uzun uzun tartışılıyor). Kısaca: işlerin çoğu telefonda halloluyor; yalnız
platform üstünden biten işe yorum hakkı vermek, yorum sayısını sıfıra yakın
tutar ve pazar yeri **yorumsuz** kalır. Yorumsuz pazar yeri işe yaramaz.
Çözüm, ikisini **ayırmak**: `kaynak` sütunu hangi yorumun neye dayandığını
saklamıyor, **gösteriyor**.

`denetim` ayrı tabloda çünkü Dukkan Yönetiyor'un `audit_log`'una yazamaz (K2).

---

## 7. İndeksler (ilk gün konacaklar)

```
isletme_hizmet_alani (mahalle_id, isletme_id)     -- eşleşme motoru
isletme_kategori     (kategori_id, isletme_id)    -- kategori sayfası
isletme (durum, siralama_puani DESC)              -- listeleme; kısmi: onayli
talep   (mahalle_id, kategori_id, durum)          -- işletmeye talep akışı
teklif  (talep_id), (isletme_id, created_at DESC)
yorum   (isletme_id, durum, yayinlandi_at DESC)
isletme (ad gin_trgm_ops)                         -- pg_trgm ad araması
```

SEO sayfasının sorgusu ilk üçünün kesişimi ve **en sıcak yol** budur:
"şu mahalleye hizmet veren, şu kategoride, onaylı işletmeler".
`pg_trgm` dışında eklenti yok; PostGIS yok (§2).

---

## 8. Bilerek yazmadıklarım

`odeme`, `abonelik`, `fatura`, `reklam`, `sponsorluk`, `mesaj` — V1 dışı
(`00-mimari.md` §8). Yerlerini **ayırmıyorum bile**: boş tablo, yarın onu
dolduracak kişiyi bugünkü yarım fikrime mahkûm eder.

Modelin bunları engellemediğini iddia ediyorum, şu somut sebeplerle:
para zaten **kuruş `bigint`** (`teklif.tutar_kurus`); `is` satırı bir ödemenin
doğal çapası; sıralama tek bir `siralama_puani` sütununda, dolayısıyla
sponsorluk ona **karışmadan** ayrı bir çarpan olarak eklenebilir.

**EMİN DEĞİLİM:** ödeme geldiğinde `is` üzerinden mi yoksa `teklif` üzerinden mi
çapalanacağını bugünden bilmiyorum — hizmet bedeli mi yoksa platform komisyonu
mu tahsil edileceğine bağlı ve bu bir **iş kararı**, teknik karar değil.

Sources:
- [NVI Adres Kayıt Sistemi](https://adres.nvi.gov.tr/Home)
- [NVI — AKS](https://www.nvi.gov.tr/adres-kayit-sistemi)
- [emreuenal/turkiye-il-ilce-sokak-mahalle-veri-tabani](https://github.com/emreuenal/turkiye-il-ilce-sokak-mahalle-veri-tabani)
- [Tradres — Türkiye Adres API](https://tradres.com.tr/)
