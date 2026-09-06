# DUKKAN — 05 · SEO

> Prompt'unda yazdığın gibi: **programatik yerel sayfalar büyüme kanalı.**
> Ama aynı prompt'ta doğru olan asıl uyarı da senin: **işletmesi olmayan
> bölge/kategori kombinasyonu için sayfa üretme.** Bu bölümün yarısı o eşiğe
> dair, çünkü yanlış yapılırsa **bütün alan adını** aşağı çeker.

---

## 1. Nerede yaşar

`apps/dukkan-web` — `apps/tanitim-web` kalıbının kardeşi (ölçtüm, M6):
tarayıcı backend'e hiç gitmez, her çağrı BFF üzerinden `http://api:8000`.

`admin-web`'e koymamanın sebebi (`00-mimari.md` §6.1): orası giriş arkasında
bir panel; SSR'ı oturuma ve rol kapısına bağlı. Bota açık, ISR ile
önbelleklenen sayfalar oraya ait değil.

---

## 2. URL şeması

```
/                                              ana sayfa
/{il}/{ilce}/{mahalle}/{kategori}              ANA SEO SAYFASI
/{il}/{ilce}/{kategori}                        ilçe seviyesi
/{il}/{kategori}                               il seviyesi
/kategori/{kategori}                           ülke geneli
/isletme/{slug}                                işletme profili
/talep-olustur                                 dönüşüm
/isletme-kaydi                                 arz tarafı
```

Örnek: `/istanbul/cekmekoy/catalmese/elektrikci`

**Neden bu sıra (`il/ilçe/mahalle/kategori`), `kategori/il/...` değil:**
Kırıntı yolu (breadcrumb) coğrafi hiyerarşiyi izler ve kullanıcı URL'i
kırparak yukarı çıkabilir — `/istanbul/cekmekoy/elektrikci` anlamlı bir sayfa.
Kategori öne alınsaydı ara seviyeler ("İstanbul'daki elektrikçiler" olmadan
"Çekmeköy elektrikçi") kırık olurdu.

`slug`'lar `01-veri-modeli.md` §2'de **kalıcı** ve elle yönetilir. Addan her
seferinde türetmek, idari bir ad değişikliğinde sessizce ölü bağlantı üretir.

---

## 3. İnce içerik eşiği — **en önemli karar**

Türkiye'de ~50.000 mahalle × ~100 kategori = **5 milyon** olası URL.
Bunların ezici çoğunluğunda **tek bir işletme bile yok**. Hepsini üretmek,
Google'a "bu alan adı boş sayfa fabrikası" demenin en hızlı yolu — ve ceza
sayfa başına değil, **alan adı geneline** işler. Yani 10 iyi sayfan da düşer.

### Kural

| İşletme sayısı | Ne olur |
|---|---|
| **0** | Sayfa **YOK**. API `404`, sitemap'te yok, iç bağlantı yok |
| **1–2** | Sayfa var ama `noindex`, **sitemap'te yok**. Bağlantıyla gelen kullanıcı bir üst seviyeye yönlendirilir |
| **≥3** | **Tam indekslenir**, sitemap'e girer, iç bağlantı alır |

**Neden 3?** Bir listeleme sayfasının kullanıcıya değeri **karşılaştırmadır**.
Tek işletmeli bir "liste", listenin vaadini tutmaz — kullanıcı geri döner,
ve dönüş oranı Google'ın gördüğü en net kalite sinyali.
**EMİN DEĞİLİM:** 3 bir başlangıç değeri, ölçülmüş bir eşik değil. İlk üç ayda
Search Console'da 1-2 işletmeli sayfaların gösterim/tıklama davranışı
ölçülüp ayarlanmalı. Sabit bir doğru gibi kodlanmamalı — **yapılandırma
değeri** olsun.

### Eşik altı sayfa boş bırakılmaz

`0` durumunda **404 doğru cevap** — "yakında" sayfası ince içeriktir.
Ama kullanıcı oraya bir yerden geldiyse boşluğa düşmesin: 404 sayfası
**bir üst seviyeyi** (ilçe/il) ve "bu bölgede işletme misin? kaydol"
çağrısını gösterir. Bu, arz tarafı için gerçek bir kanal.

### Eşik dinamiktir

Bir mahalleye 3. işletme katıldığında sayfa **doğar**; bir işletme askıya
alınınca 2'ye düşerse **`noindex`'e geri döner**. Bu yüzden sitemap
**üretilmek zorunda** — `tanitim-web`'in 7 yolluk elle yazılmış dizisi (M7)
burada işe yaramaz.

---

## 4. Oluşturma stratejisi

| Sayfa | Yöntem | Gerekçe |
|---|---|---|
| SEO bölge sayfaları | **ISR**, `revalidate` ~24 sa | İçerik günde bir değişir; her istekte SSR, bot trafiğinde veritabanını yorar |
| İşletme profili | **ISR**, ~1 sa | Yorumlar daha sık değişir |
| Arama sonuçları | **CSR** + `noindex` | Filtre kombinasyonları sonsuz; indekslenmemeli |
| Talep oluştur / kayıt | CSR | SEO değeri yok |

**`generateStaticParams` ile önceden üretme: yalnız eşiği geçen sayfalar.**
Hepsini üretmeye kalkmak derlemeyi saatlere çıkarır ve zaten üretilmemesi
gereken sayfaları üretir. Eşik altı yollar **istek anında** karşılanır ve
`404`/`noindex` döner.

**Not:** ISR'ın disk üzerinde önbellek tuttuğunu ve konteyner yeniden
kalktığında sıfırlandığını hesaba katmak gerekiyor — ilk isteklerde
yavaşlama olur. **EMİN DEĞİLİM:** tek sunucuda kalıcı ISR önbelleği için
ek yapılandırma gerekip gerekmediğini ölçmedim.

---

## 5. Sayfa içi

**Başlık:** `Çatalmeşe Elektrikçi — 7 Usta ve Firma | Dukkan`
Sayısı başlığa koymak tıklama oranını artırır **ve** doğrudur; ISR yenilemesi
sayıyı güncel tutar.

**H1:** `Çatalmeşe Mahallesi'nde Elektrikçiler`
**Kırıntı:** Ana sayfa › İstanbul › Çekmeköy › Çatalmeşe › Elektrikçi
**Canonical:** her sayfa kendine. Sıralama/sayfalama parametreleri
canonical'a **girmez** (aynı içeriğin 10 kopyası olur).

**İç bağlantı** — organik ve sınırlı:
- Komşu mahalleler (aynı ilçede, **eşiği geçenler**)
- Aynı mahallede diğer kategoriler (eşiği geçenler)
- Bir üst seviye (ilçe sayfası)

Eşiği geçmeyene **bağlantı verilmez** — verilirse Google'a var olmayan
sayfaların haritasını çizmiş oluruz.

**Schema.org** (JSON-LD):
- Listeleme sayfası: `ItemList` + her öğe için `LocalBusiness`
- Profil: `LocalBusiness` (+ `address`, `telephone`, `areaServed`,
  `aggregateRating` **yalnız gerçek yorum varsa**)
- Kırıntı: `BreadcrumbList`

> **`aggregateRating`'i yorumu olmayan işletmeye koymak yapılandırılmış veri
> ihlalidir** ve manuel işlem sebebidir. Koşullu üretilecek — "her zaman
> koy, boşsa 0 yaz" **yapılmayacak**.

**EMİN DEĞİLİM:** `Review`/`aggregateRating` işaretlemesinin
"davetli değerlendirme" (Katman B, `03` §2.2) için de kullanılıp
kullanılamayacağından emin değilim. İhtiyatlı yol: `aggregateRating`'e
**yalnız Katman A** (doğrulanmış iş) yorumlarını dahil etmek. Bu hem
mevzuata hem de kullanıcının gördüğü ayrıma sadık.

---

## 6. Sıralama

`isletme.siralama_puani` — türetilmiş, periyodik hesaplanan tek sütun:
- Doğrulama seviyesi (Sv2 > Sv1)
- **Katman A** yorum sayısı ve ortalaması (ağır)
- **Katman B** yorum ortalaması (hafif)
- Teklif yanıt hızı ve oranı
- Profil eksiksizliği
- **Rastgele küçük bir bileşen** — yeni işletmeler hiç görünmeden ölmesin
  ("zengin daha zengin olur" döngüsünü kırmak için; yoksa arz tarafı büyümez)

Tek sütun olması bilinçli (`00-mimari.md` §8): sponsorluk bir gün gelirse
puana **karışmaz**, ayrı bir alan olur ve "bu sonuç neden üstte?" sorusu
cevaplanabilir kalır.

---

## 7. Teknik

- `sitemap.xml` **üretilir**, indeks + parçalara bölünür (50.000 URL sınırı).
  Yalnız eşiği geçen sayfalar.
- `robots.txt`: `/api/`, arama sonuçları, `/ben/*` kapalı.
- Tüm sayfalarda `hreflang` — **V1'de tek dil (tr)**. Yönetiyor 7 dilli ama
  yerel esnaf araması Türkçe; çok dilli SEO ayrı bir iş ve yarım yapılırsa
  zararlı.
- Görseller `next/image`, MinIO'dan; `storage.yonetio.site` presign kalıbı.
- Core Web Vitals: listeleme sayfası **sunucuda** çizilir, istemci JavaScript'i
  minimum. Harita yok (`01` §2) — bu LCP için bedava bir kazanç.

---

## 8. armut.com benzerliği hakkında

İstediğin şeyi anladım ve büyük kısmına katılıyorum: **ürün kalıbı**
(ihtiyacı anlat → teklifler gelsin → karşılaştır ve seç), üç adımlı
"nasıl çalışır" anlatımı, kategori ızgarası, bölge sayfaları, güven
göstergeleri. Bunlar bu iş kolunun **yerleşik ve kanıtlanmış** dili;
farklı bir şey icat etmek kullanıcıyı zorlamak olurdu. Ölçtüğüm ana sayfa
yapısı (hero + arama, trend hizmetler, 4 değer önerisi, 3 adım, popüler
hizmetler, bölge listesi, güven bölümü, uygulama indir) `dukkan-web` ana
sayfasının iskeleti olacak.

Kopyalamayacağım iki şey var ve sebebi pratik:
- **Marka varlıkları** (logo, ad, slogan, özgün illüstrasyonlar) — bunlar
  hukuken korunuyor ve kullanılması gerçek bir risk.
- **Birebir CSS/işaretleme kopyası** — Yönetiyor'un `--yz-*` tasarım
  jetonları, karanlık kip ve erişilebilirlik kilitleri zaten var; onları
  atıp yabancı bir stil sayfası getirmek, mevcut test kilitlerini
  (`tasarim-token.test.ts`) kırar ve bakımı ikiye böler.

Yani: **aynı ürün, aynı akış, aynı sayfa mimarisi; Yönetio'nun görsel dili.**
