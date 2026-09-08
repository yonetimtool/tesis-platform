# DUKKAN — 06 · YOL HARİTASI VE AÇIK SORULAR

---

## 1. Kod yazmadan önce ölçülecekler

Bu tasarım beş yerde **tahmine** dayanıyor. Uygulamanın **ilk işi** bunları
ölçmek, çünkü M5'te (tesislerin `il` doluluğu **1/2239**) tam da varsaymayıp
ölçtüğüm için özelliği yanlış kurmaktan dönmüştüm.

> **F1'de HEPSİ YAPILDI. Sonuçlar aşağıda — ikisi tasarımı değiştirdi.**

| # | Ölçüm | **SONUÇ** | Ne değişti |
|---|---|---|---|
| Ö1 | `app_user.telefon` boş oranı | **837 / 3104 = %27** | **Değişti.** SSO'da telefon sorma yolu "nadir kenar durum" değil, **her dört kullanıcıdan biri**. Hata ekranı gibi değil, akışın doğal dalı olarak tasarlanacak (`02` §3) |
| Ö2 | `tenant.posta_kodu` doluluğu | **1 / 2239** (`ilce` de 1/2239) | Bölge ön-doldurmanın **ikinci şansı yok**. "En iyi çaba" kararı doğrulandı (`00` §5) |
| Ö3 | İkinci Alembic zinciri gerekli mi | **GEREKMEDİ** | **Değişti.** Ölçüm: `migrate` zaten OWNER ile, `api`/`worker`/`beat` `app_rw` ile bağlanıyor — "göçü owner koşar, uygulama kısıtlı rolle bağlanır" deseni **evde zaten var**. Dukkan üçüncü rol olarak katıldı. İkinci zincir yalnızca ikinci bir `migrate` servisi ve ikinci bir yedekleme yolu getirirdi |
| Ö4 | Sınır kanıtı | **KANITLANDI** (aşağıda) | — |
| Ö5 | Lokasyon verisi | **81 il / 973 ilçe / 44.719 mahalle+köy** | Kaynak değişti: GPL-3.0+2021 yerine MIT. Veri bozuktu, onarıldı (`01` §2) |

### Ö4 — kanıt

```
dukkan_app ile SELECT public.app_user   ->  permission denied for table app_user
dukkan_app ile UPDATE public.app_user   ->  permission denied for table app_user
dukkan_app ile SELECT public.tenant     ->  permission denied for table tenant
dukkan_app ile INSERT dukkan.ulke       ->  çalışıyor
app_rw     ile SELECT dukkan.ulke       ->  permission denied   (simetrik)
```

`backend/tests/test_dukkan_sinir.py` bunu kilitliyor ve kilit **kırılarak
doğrulandı**: `GRANT SELECT ON public.app_user TO dukkan_app` verilince iki
test kırmızı yandı, `REVOKE` ile yeşile döndü. Katalog üzerinden yapılan
test, **gelecekte eklenecek** Yönetiyor tablolarını da kapsıyor — tablo tablo
bakan bir test yeni tabloyu görmezdi.

"Yönetiyor veritabanına yazma" kuralı artık bir niyet değil, kırıldığında
kırmızı yanan bir kilit.

---

## 2. Aşamalar

### F0 — Temel (kod yok, karar var)
Bu belgelerin onayı + §4'teki soruların cevapları.

### F1 — İskelet ✅ **TAMAMLANDI**
`dukkan` şeması + `dukkan_app` rolü + Ö4 testi; lokasyon (44.719 mahalle) ve
kategori (12 ana / 51 hizmet) yüklendi; 4 kamu ucu; `apps/dukkan-web` +
**BFF sözleşme kapısı** (kırarak doğrulandı).

`/istanbul/cekmekoy/catalmese/elektrikci` — brief'in örnek yolunun **her
parçası** API'den çözülüyor.

**Akış sürülürken bulunan kusur:** mahalle araması Türkçe harfsiz yazımda
(`"catal"`) hiçbir şey bulmuyordu, oysa "Çatalmeşe" oradaydı. Türkçe klavyesi
olmayan biri hiçbir mahalle bulamazdı — ve mahalle seçimi hem sakinin hem
**ustanın hizmet alanı seçtiği** yer. Çözüm bedavaydı: `slug` sütunu zaten
ASCII'ye katlanmış duruyordu (SEO için üretilmişti), `unaccent` eklentisi
gerekmedi.

### F2 — Arz tarafı (önce bu)
İşletme kaydı, telefon doğrulama, kategori/hizmet alanı seçimi, belge yükleme,
moderasyon kuyruğu, işletme profil sayfası.

> **Neden arz önce:** boş bir pazar yerine talep getirmek, kullanıcıya
> "aradığın bölgede kimse yok" göstermektir — ve o kullanıcı bir daha gelmez.
> İşletmeleri toplamak yavaş bir iştir, erken başlamalı.

### F3 — SEO yüzeyi
Bölge/kategori sayfaları, **eşik mantığı** (`05` §3), sitemap üretimi,
Schema.org, kırıntı, ana sayfa. F2'nin doldurduğu bölgeler kendiliğinden açılır.

### F4 — Talep tarafı
Talep oluşturma + **KVKK paylaşım tercihleri** (`02` §6.2), işletmeye talep
akışı, teklif, teklif kabul → `is` → **adres açılması**, `04` §4'teki 5 kilit testi.

### F5 — Yorum ve güven
Katman A, Katman B + davet kotası, cevap hakkı, şikâyet, askı ölçütleri (`03`).

### F6 — Yönetiyor entegrasyonu
SSO köprüsü, mobil "Dış Hizmetler" sekmesi, `app.yonetiyor.com` "Yerel İşletmeler".

> **Neden en sonda:** Dukkan'ın **kendi başına ayakta durması** gerekiyor
> (bağımsız kullanıcılar senin kısıtın). Entegrasyonu önce yapmak, Dukkan'ı
> Yönetiyor'a yaslanır hâlde tasarlamaya iter ve bağımsız kullanıcı sonradan
> "eklenti" olur. Ters sıra, ürünün omurgasını yanlış kurar.

**Süre tahmini vermiyorum** — tek geliştiricinin başka işleri de var ve
uydurma bir takvim, sonra ona göre karar verilen bir sayı hâline gelir.

---

## 3. Kalıcı kurallar (gün 1'den, sonradan eklenmez)

| Kural | Nereden öğrenildi |
|---|---|
| **Sessiz başarısızlık yok** — her yazma ucu sayı döndürür; sıfırsa arayüz "Kaydedildi" demez | P217: toplu borçlandırma 0 kayıt üretip "Kaydedildi" diyordu |
| **BFF vekil bütünlüğü** — metot metot sözleşme kapısı | P173/P189: eksik `export` → 405, testler görmüyor |
| **Testler akışı ölçer** — taklit **HTTP** katmanında | P198/P200: repo düzeyinde taklit, kıran katmanı ölçmüyor |
| **Sahiplik sunucuda, testle kilitli** — her özel uç için IDOR testi | `02` §5 |
| **Reklam tahsilatı TEK DEFTER** | P192 — hizmet bedeli akışı yok (F8) |
| **Yeni servis → `tesisnet` ağı + dağıtım belgesinde doğrulama komutu** | P215: `mediamtx` yanlış ağda, prod'a kadar gitti |
| **Göç `app.*` import etmez** — gereken mantık göçe donmuş kopya olarak girer | P213: 0107 zinciri komple düşürdü |

---

## 4. SANA SORULARIM — cevaplamadan uygulamaya geçmiyorum

### S1 — Ayrı veritabanı mı, aynı örnekte ayrı şema mı?

**Önerim: aynı örnekte AYRI ŞEMA + AYRI ROL.** (`00-mimari.md` K2)

Gerekçe özeti: ayrı veritabanı tek Alembic zincirini, tek bağlantı havuzunu
ve tek yedekleme yolunu bölerdi — tek sunucuda bağlantı kıt bir kaynak ve
bunu P187'de idle-in-transaction 90/100 ile acıyla ölçtük.

**Ama asıl noktam şu:** ayrı şema **tek başına yetmez**. Aynı veritabanında
şema ayrımı, yanlışlıkla `public.app_user`'a yazmayı engellemez; sadece
isimleri ayırır. Senin kısıtın bir isimlendirme tercihi değil, **güvenlik
sınırı**. Bu yüzden sınırı şema değil **rol** zorluyor: `dukkan_app` rolünün
`public` şemasında hiçbir yetkisi yok. Böylece kısıt **test edilebilir**
oluyor (Ö4) — yorumla yazılmış bir kural bunu yapamaz.

**Onaylıyor musun?**

### S2 — Ayrı konteyner mi, mevcut `api`'ye modül mü?

**Önerim: mevcut `api`'ye MODÜL** (`/dukkan/*`). (`00-mimari.md` K1)

Ayrı konteyner ikinci bir dağıtım yüzeyi demek: kendi imajı, sağlık kontrolü,
env'i, Caddy upstream'i, ağ tanımı. P215'te `mediamtx`'i ağa eklemeyi unuttuk
ve hata prod'a kadar gitti — her yeni konteyner o sınıf hatanın yeni bir
fırsatı. Ayrıca modül olunca Yönetiyor JWT'si **süreç içinde** doğrulanıyor;
ayrı konteynerde `JWT_SECRET`'ı iki servise yaymak gerekirdi.

**Dürüst maliyeti:** Dukkan SEO trafiği (bot dahil) Yönetiyor `api`
süreçleriyle aynı havuzu paylaşır. Bir tarama dalgası Yönetiyor'u
yavaşlatabilir. Azaltma yolu hazır ve ucuz: aynı imajdan ikinci bir replika
(`api-dukkan`), Caddy'de yalnız `/dukkan/*` oraya. **Ama bunu şimdi değil,
ölçülmüş bir yavaşlama üzerine yapmayı öneriyorum.**

**Onaylıyor musun?**

### S3 — Dukkan Yönetiyor verisine tam olarak nasıl erişsin?

Bu, **sana sormadan karar vermeyeceğim** yer.

Ölçtüm: Dukkan'ın Yönetiyor'dan ihtiyacı **3 şey**, hepsi **giriş anında bir
kez** — doğrulanmış telefon, ad, tesisin il/ilçesi (`00-mimari.md` K3).

Rol kısıtı (S1) tabloya erişimi **fiziksel olarak** kapatıyor. Geriye bu 3
şeyin nasıl alınacağı kalıyor:

- **(a) Süreç içi köprü** — `kopru.py`, en fazla 3 salt-okunur fonksiyon.
  *Önerim bu.*
- **(b) HTTP döngüsü** — `api` kendi kendine HTTP isteği yapar. Kısıtının
  **lafzına** tam uyar; gerçek bir ağ atlaması, ek gecikme, ek hata yolu
  ve — aynı süreç, aynı kod olduğu için — **sıfır ek güvenlik** getirir.

(a)'nın kelimenin tam anlamıyla "API üzerinden" olmadığını kabul ediyorum.
Kısıtının *ruhunu* (Dukkan Yönetiyor'un iç yapısına bulaşmasın) rol yasağı +
3 fonksiyonluk kapı koruyor; *lafzını* değil.

**Hangisini istersin?** (b) dersen yapılabilir, sadece bedelini bilerek ödemiş
oluruz.

### S4 — Lokasyon verisi nereden gelsin?

**Önerim:** NVI verisinden türetilmiş hazır PostgreSQL dökümü
(`emreuenal/turkiye-il-ilce-sokak-mahalle-veri-tabani`) ile **bir kez**
yüklemek; veri **Dukkan'ın kendi tablosunda** yaşasın, çalışma anında hiçbir
dış servise sorulmasın.

Çalışma anında dış API'ye bağlanmamamın sebebi somut: `/istanbul/cekmekoy/
catalmese/elektrikci` sayfası varlığını `mahalle` satırına borçlu. O satır bir
API'den gelirse, API'nin kesintisi **binlerce SEO sayfasının 500 vermesi**
demek — Google'a verilebilecek en kötü sinyal.

Güncelleme: yılda 1-2 kez yeni döküm → **fark raporu** → **elle onay**.
Otomatik uygulamıyorum çünkü silinen bir mahalle, işletmeleri ve canlı SEO
sayfalarını sessizce düşürür.

**EMİN DEĞİLİM:** NVI/MAKS'ın tek geliştiriciye resmî toplu erişim verip
vermediğini doğrulayamadım. Veriyi resmî yoldan alabiliyorsan **o daha iyi** —
biliyor musun?

### S5 — Yorum güveni için hangi model?

**Önerim: iki katman, açıkça etiketli.** (`03-guven-ve-fraud.md` §2)

- **Katman A** "Platform üzerinden alınan hizmet" — `is` kaydına bağlı,
  rozetli, sıralamada tam ağırlık.
- **Katman B** "Davetli değerlendirme" — işletme, işini yaptığı müşteriye
  davet gönderir, müşteri OTP ile doğrulanır; rozetsiz, düşük ağırlık,
  **platform etkinliğine bağlı aylık kota**.

Gerekçe: yalnız Katman A'yı kabul etmek "doğru" görünüyor ama işlerin çoğu
telefonda hallolduğu için yorumların ~%90'ı hiç doğmaz — pazar yeri
**yorumsuz** kalır ve yorumsuz pazar yeri işe yaramaz. Katı olan kural, burada
güvenli olan kural değil. Katman B'nin riskini **kota** ile fiyatlıyorum:
hiç teklif vermemiş işletme davet gönderemez, yani sahte yorumun maliyeti
**gerçek iş yapmaya** bağlanıyor.

Kullanıcıya ikisi ayrı gösteriliyor — kararı ondan saklamak yerine görünür
kılıyorum.

**Kabul etmem gereken:** bu, sahte yorumu **bitirmiyor**; maliyetini
yükseltiyor ve örüntüsünü görünür kılıyor. Bitirdiğini iddia eden bir tasarım
yanlış olurdu.

**Onaylıyor musun, yoksa daha katı (yalnız Katman A) mı istersin?**

---

## 5. Ölçemediklerim / karar veremediklerim

Prompt'un son sorusu buydu. Tam liste:

1. **Ham prompt'u okuyamadım.** `/home/yonetiyoradmin/Yonetiyor_Master_Cloud_Prompt`
   → `Permission denied`, `sudo` yok. Orada bu belgelerde olmayan bir kısıt
   varsa **kaçırmışımdır**.
2. **Hukuki durum belirsiz.** Dukkan V1'in 6563 anlamında "elektronik ticaret
   aracı hizmet sağlayıcı" sayılıp sayılmayacağından **emin değilim** —
   platform üzerinden sipariş/ödeme yok, yapılan şey ilan/eşleştirme.
   **F8:** reklam geliri eklendi — 6563 değerlendirmesine etkisi avukata
   soruldu (07 S17). ETBİS
   kayıt yükümlülüğünün doğup doğmadığından da emin değilim. Saklama sürelerini
   ve ceza tutarlarını **bilerek yazmadım**; yanlış hatırlanmış bir süre hiç
   yazmamaktan kötüdür. **Yayına çıkmadan bir avukatla bir saatlik görüşme
   öneriyorum.** Bu, yazılımla kapatılamayacak bir belirsizlik.
3. **Vergi no doğrulaması** için tek geliştiricinin kullanabileceği ücretsiz
   resmî bir API bulduğuma emin değilim → V1'de **insan incelemesi** (`03` §3).
4. **İnce içerik eşiği "3"** ölçülmüş değil, başlangıç değeri. Search
   Console verisiyle ayarlanmalı; yapılandırma değeri olsun, sabit olmasın.
5. **Kotalar** (davet sayısı, otomatik askı eşiği N) tahmin. İlk üç ayda ölçülüp
   ayarlanacak.
6. **Ö1-Ö5** (§1) ölçülmedi.
7. **Hesap silme etkileşimi**: Yönetiyor hesabını silen kullanıcının Dukkan
   hesabına ne olacağı bir **ürün kararı** — teknik olarak bağımsız yaşayabilir,
   ama kullanıcı ikisini birden kastediyor olabilir. Senin kararın (`02` §6.5).
8. ~~**Ödeme geldiğinde çapa** `is` mi `teklif` mi~~ — **DÜŞTÜ (F8).**
   Hizmet bedeli akışı hiç gelmiyor; platform ona dokunmuyor. Gelir
   reklamdan ve kendi tablolarında yaşıyor.
9. **İşletme sahipliği devri / kimlik gaspı itirazının** hukuki tarafını
   tasarlayacak yetkinlikte değilim (`03` §3).
10. **Hiçbiri gerçek trafikle sınanmadı.** Bu belgeler bir tasarım; ölçüm
    değil. Ölçtüğüm 8 şey `00-mimari.md` §1'de, geri kalanı tasarım kararı.
