# DUKKAN — 07 · AVUKAT VE MALİ MÜŞAVİRE SORULACAKLAR

> Sen istedin: **"hangi soruların sorulması gerektiğini listele, ben o listeyle
> gideyim. Cevap üretme, soru üret."** Bu belgede cevap yok, yalnız soru var.
>
> Her sorunun altında **"bu neden önemli"** ve **"cevaba göre ne değişir"**
> yazıyor — çünkü avukatın verdiği cevap bir yazılım kararına dönüşecek ve
> hangi kararı etkilediğini bilmeden sorulan soru, yanlış ayrıntıda cevap alır.
>
> Soruları **öncelik sırasına** koydum: 1-5 yayına çıkmadan **kesin**
> cevaplanmalı; 6-12 ilk üç ay içinde; 13-16 büyüme sonrası.

---

## Ürünü bir cümleyle anlat (avukata verilecek arka plan)

> `dukkan.yonetiyor.com`, kullanıcıların yerel esnaf/hizmet sağlayıcı
> (elektrikçi, tesisatçı, temizlikçi, nakliyeci) aradığı bir **ilan ve
> eşleştirme** platformu. Kullanıcı ihtiyacını yazar, bölgesindeki işletmeler
> teklif verir, kullanıcı birini seçer ve **doğrudan** o işletmeyle iletişime
> geçer.
>
> **Platform hizmet bedeline hiç dokunmaz:** sipariş, satın alma, tahsilat,
> komisyon, escrow YOK. Para tamamen taraflar arasında, platform dışında el
> değiştirir. Platform sözleşmenin tarafı değildir ve taraflar arasında
> **hakemlik yapmaz**.
>
> **Platformun tek geliri:** işletmelerin görünürlük (reklam) için ödediği
> bedel. Bu **doğrudan satış** — işletme platforma öder, platform kendi
> hizmetini satar. Ödeme *aracılığı* değildir.
>
> Kullanıcılar yorum yazar. İşletmeler kayıt olur ve **elle onaydan** geçer.

> **DEĞİŞİKLİK NOTU:** Bu belgenin ilk hâlinde ürün "platform işletmelerden
> ücret almaz" diye tanımlanmıştı ve ödeme "V1 dışı, ileride gelebilir"
> sayılıyordu. **İkisi de değişti:** hizmet bedeli akışı artık *kalıcı
> olarak* kapsam dışı, buna karşılık işletmelerden **reklam geliri**
> alınıyor. Aşağıdaki soruların bir kısmı bu yüzden düştü, bir kısmı
> değişti, üç tanesi yeni eklendi (S17-S19).

Altını çiz: **hizmet bedeline aracılık yok, reklam geliri var.** Aşağıdaki
soruların çoğunun cevabı bu ikisinin birleşimine bağlı.

---

## A. EN KRİTİK — yayından önce (1-5)

### 1. Dukkan, 6563 sayılı Kanun anlamında "elektronik ticaret aracı hizmet sağlayıcı" (ETAHS) mı?

**Neden önemli:** Bütün uyum yükü bu tek cevaba bağlı. ETAHS isek ETBİS kaydı,
hizmet sağlayıcı bilgilerinin doğrulanması ve ciro eşiklerine bağlı ek
yükümlülükler gündeme gelir; değilsek yük çok daha hafif.

**Sorunun özü:** Platform üzerinden **sipariş/sözleşme kurulmuyor ve ödeme
alınmıyorsa**, yapılan iş "aracı hizmet sağlayıcılık" mı yoksa bir **ilan/
rehber hizmeti** mi sayılır?

**F8 EKİ — mutlaka birlikte sor:** Platform, listelediği işletmelerden
**reklam/görünürlük bedeli** alıyor. Bu gelir, ürünü "ilan hizmeti"
olmaktan çıkarıp aracı hizmet sağlayıcı konumuna taşır mı? Yoksa
gazete/rehber ilanı gibi mi değerlendirilir? Yani belirleyici olan
**ticari fayda elde etmek** mi, yoksa **işlemin platformda kurulması**
mı?

**Cevaba göre ne değişir:** ETAHS isek ETBİS kaydı ve doğrulama akışları V1
kapsamına girer — F2'nin (işletme kaydı) tasarımı değişir.

### 2. ETBİS kaydı bu ürün için zorunlu mu? Zorunluysa ne zaman ve hangi bilgilerle?

**Neden önemli:** Kayıt zorunluysa **yayına çıkmadan önce** yapılmalı; sonradan
yapmak geriye dönük ihlal doğurabilir.

**Ek olarak sor:** Kayıt şirket üzerinden mi, alan adı üzerinden mi? Birden çok
alan adımız var (`yonetiyor.com`, `dukkan.yonetiyor.com`) — her biri ayrı mı?

### 3. İşletmelerin kimlik/vergi bilgilerini doğrulama yükümlülüğümüz var mı? Varsa hangi ölçüde?

**Neden önemli:** Tasarımda V1 için **insan incelemesi** (vergi levhası fotoğrafı
+ elle onay) öngörüldü, otomatik doğrulama yok.

**Sorunun özü:** Beyan + belge fotoğrafı + elle inceleme **yeterli mi**, yoksa
resmî bir kaynaktan (GİB/MERSİS) teyit **zorunlu mu**?

**Ek olarak sor:** Gerçek kişi esnaf (şahıs işletmesi) ile şirket için
yükümlülük farklı mı? Vergi mükellefi olmayan biri (ör. ev temizliği yapan
bir kişi) platformda yer alabilir mi?

**Cevaba göre ne değişir:** "Zorunlu" cevabı, F2'ye resmî sorgulama
entegrasyonu ekler ve kayıt akışını yavaşlatır.

### 4. Bir kullanıcı platformda bulduğu işletme tarafından dolandırılırsa platformun hukuki sorumluluğu nedir?

**Neden önemli:** Ürünün en büyük itibar ve hukuk riski bu.

**Sorunun özü:** Para platform dışında el değiştirdiği hâlde, kullanıcı
işletmeyi *burada* bulduğu için platform sorumlu tutulabilir mi?

**Ek olarak sor:**
- Kullanım koşullarında sorumluluk sınırlaması **ne kadar** geçerli olur?
- "Ödemeyi iş bitmeden yapmayın" uyarısını **göstermiş olmak** hukuken bir
  koruma sağlar mı? Sağlıyorsa nerede ve nasıl gösterilmeli?
- Şikâyeti alıp işletmeyi askıya almamız sorumluluğu azaltır mı — yoksa
  "biliyordunuz" argümanıyla **artırır mı**?

### 5. KVKK: Dukkan ile Yönetiyor ayrı veri sorumluları mı?

**Neden önemli:** Teknik tasarım bu ayrımı **varsayarak** kuruldu: Dukkan'ın
kendi aydınlatma metni var ve Yönetiyor'un tesis bazlı KVKK metnini
devralmıyor. Ayrıca Dukkan'ın veritabanı rolü Yönetiyor tablolarına
**erişemiyor**.

**Sorunun özü:** Aynı şirketin iki ürünü ayrı veri sorumlusu olabilir mi;
olmalı mı? Yönetiyor kullanıcısının SSO ile Dukkan'a geçmesi bir **veri
aktarımı** mıdır ve ayrı **açık rıza** gerektirir mi?

**Cevaba göre ne değişir:** "Ayrı rıza gerekir" cevabı, SSO akışına bir onay
adımı ekler (`docs/dukkan/02-kimlik-ve-yetki.md` §3).

---

## B. İLK ÜÇ AY (6-12)

### 6. Kullanıcı yorumları: yayınlanan bir yorumdan platform sorumlu mu?

**Ek olarak sor:**
- Bir işletme "bu yorum iftira" derse **kaldırmak zorunda mıyız**? Hangi süre
  içinde?
- Kaldırmazsak sorumluluk doğar mı? Kaldırırsak yorumu yazan kullanıcıya karşı
  sorumluluk doğar mı?
- **Doğrulanmamış** yorumu (platform dışı iş) yayınlamanın riski, doğrulanmışa
  göre farklı mı? *(Tasarımda ikisi ayrı etiketle gösteriliyor —
  `03-guven-ve-fraud.md` §2.)*

### 7. "Doğrulanmış işletme" rozeti bir taahhüt sayılır mı?

**Neden önemli:** Rozet üç kademeli (telefon doğrulandı / belge doğrulandı /
kurumsal) ve kullanıcıya bir güven sinyali veriyor.

**Sorunun özü:** Rozet verdiğimiz bir işletme kullanıcıyı mağdur ederse, rozet
platformun **garantisi** gibi yorumlanır mı? Rozet metnini nasıl yazarsak bu
riski azaltırız?

### 8. Şikâyet mekanizması için yasal bir asgari standart var mı?

**Ek olarak sor:** Yanıt süresi zorunluluğu? Kaydı ne kadar saklamalıyız?
Şikâyetçiye sonucu bildirme zorunluluğu var mı?

### 9. İşletme askıya alma/kapatma kararlarında hukuki risk nedir?

**Sorunun özü:** Bir işletmeyi askıya aldığımızda "ticari itibar zedelendi"
davası açılabilir mi? Kullanım koşullarında askı ölçütlerini **yazılı** ve
**önceden** ilan etmek koruma sağlar mı? *(Tasarımda ölçüt tablosu var —
`03-guven-ve-fraud.md` §5.3.)*

**Ek olarak sor:** İtiraz hakkı tanımak zorunlu mu?

### 10. Kullanım koşulları ve gizlilik metinlerini kim hazırlamalı?

**Ek olarak sor:** Yönetiyor'un mevcut metinleri uyarlanabilir mi, yoksa
Dukkan'ınki sıfırdan mı yazılmalı? Mesafeli satış sözleşmesi **gerekli mi**
(ödeme yokken)?

### 11. Reklam ve tanıtım: SEO sayfalarında "Çekmeköy'ün en iyi elektrikçileri" gibi ifadeler kullanabilir miyiz?

**Neden önemli:** SEO başlıkları büyüme kanalı; "en iyi", "en ucuz", "garantili"
gibi ifadeler reklam mevzuatına takılabilir.

**Sorunun özü:** Hangi ifadeler **ispatlanabilir** olmadıkça kullanılamaz?
Sıralamayı biz belirlediğimize göre, sıralamanın nasıl oluştuğunu **açıklamak
zorunda mıyız**?

### 12. İşletmelerden gelen görsel ve metinlerin telif sorumluluğu kimde?

---

## C. GELECEK (13-16) — ama bugün sorulması ucuz

> S13 **F8 ile değişti** (aşağıda), S14 **genişledi**.

### 13. ~~Platform bir gün komisyon/abonelik alırsa ne değişir?~~ → **DEĞİŞTİ**

**Eski hâli varsayımsaldı** ("bir gün alırsak"). Artık varsayım değil:
komisyon **hiç alınmayacak**, reklam **alınıyor**. Soru ikiye bölündü:

**13a. Komisyona geçmenin bedeli nedir?** Bugün hizmet bedeline hiç
dokunmuyoruz ve bu kararı kodda **testle** kilitledik. İleride biri
"komisyon ekleyelim" derse, hangi yükümlülükler devreye girer? (ETAHS
statüsü kesinleşir mi, ödeme aracılığı BDDK lisansı gerektirir mi,
mesafeli satış mevzuatı bağlar mı?) **Cevabı bugün istiyoruz ki, o gün
gelirse bilerek karar verilsin.**

**13b. Reklam geliri hangi mevzuata tabi?** Ticari Reklam ve Haksız
Ticari Uygulamalar Yönetmeliği kapsamında mıyız? Sponsorlu sonucun
**ayırt edilebilir** olması yasal bir zorunluluk mu, yoksa iyi
uygulama mı? (Ürün tarafında "Sponsorlu" etiketini zaten zorunlu
yaptık — ama yeterli mi, konumu/büyüklüğü için bir ölçüt var mı?)

### 14. Fatura: işletmeden **reklam bedeli** aldığımızda faturayı kim, kime, ne zaman keser?

*(Bu soru mali müşavire.)*

**F8 eki — somut sorular:**
- Reklam satışında **e-Arşiv fatura zorunlu mu**, yoksa ciro eşiğine mi
  bağlı? Eşik nedir?
- Fatura **satın alma anında mı** yoksa **dönem sonunda mı** kesilir?
  (Reklam 30/90 günlük bir dönem için peşin satılıyor.)
- **KDV oranı** reklam hizmetinde kaç? Ara dönemde iptal olursa (bkz.
  S19) düzeltme nasıl yapılır?
- Ödeme sağlayıcısının (sanal POS) kestiği komisyon **gider olarak** mı
  yazılır, yoksa hasılattan mı düşülür?

### 15. Platformdaki işletmeler bizim "çalışanımız" ya da "bayimiz" sayılır mı?

**Neden önemli:** Türkiye'de gig-ekonomi platformlarında bu tartışma açık.
Sözleşme dilini bugünden doğru kurmak, sonradan düzeltmekten ucuz.

### 16. Yönetiyor ile Dukkan'ın aynı şirket altında olması bir risk doğurur mu?

**Sorunun özü:** Dukkan'da doğan bir hukuki sorun Yönetiyor'un müşteri
ilişkilerini etkiler mi? İki ürünü **ayrı tüzel kişilik** altında tutmak
mantıklı mı, yoksa gereksiz karmaşıklık mı?

---

## D. F8 İLE GELEN YENİ SORULAR (17-19) — reklam modeli

### 17. Reklam geliri, platformun 6563 karşısındaki konumunu değiştirir mi?

**Neden önemli:** S1'in cevabı "hayır, ilan hizmetiyiz" ise, reklam
geliri bu cevabı bozar mı? Ürün hâlâ sipariş/ödeme taşımıyor ama artık
**listelediği işletmelerden para alıyor**.

**Sorunun özü:** 6563'ün "aracı hizmet sağlayıcı" tanımında belirleyici
olan, elektronik ticaret ortamında **başkalarına ait iktisadi ve ticari
faaliyetlerin yapılmasına imkân sağlamak** mı? Reklam geliri bu tanımı
tetikler mi, yoksa tanım için **işlemin platformda kurulması** mı
gerekir?

**Ek olarak sor:** Cevap "evet, ETAHS'sınız" ise, aracı hizmet
sağlayıcının **kendi hizmetini** (reklam) satması ayrıca bir sınıflama
doğurur mu?

### 18. Sponsorlu sonuçları nasıl göstermeliyiz? "Örtülü reklam" riski var mı?

**Neden önemli:** Reklam Kurulu'nun örtülü reklam yaptırımları var ve
platform tarafında da uygulanıyor.

**Sorunun özü:**
- Reklamlı işletme, arama sonuçlarında **organik listeden ayrı bir
  blokta** ve **"Sponsorlu" rozetiyle** gösteriliyor. Bu yeterli mi?
- Rozetin **boyutu, konumu, kontrastı** için bir asgari ölçüt var mı?
- Sponsorlu sonuç aynı zamanda organik listede de çıkıyor (hak ettiği
  sırada). Bu bir sorun mu?
- SEO sayfalarında sponsorlu içerik göstermek ek yükümlülük doğurur mu?

**Ürün tarafındaki karar:** Reklam, organik sıralama puanına **hiç
karışmıyor** — ayrı tablo, ayrı sorgu, ayrı blok; bunu bir testle
kilitledik. Bu ayrımın hukuken de doğru ayrım olup olmadığını sor.

### 19. Reklam sözleşmesi: iade, iptal ve "gösterim garantisi" yükümlülüğü

**Neden önemli:** Reklam bedeli **peşin** ve **tek seferlik** alınıyor
(abonelik yok). İşletme "yeterince gösterilmedim" derse ne olur?

**Sorunun özü:**
- İşletme bir **tacir** olduğu için mesafeli satış mevzuatındaki
  **cayma hakkı** uygulanmaz sanıyoruz — doğru mu?
- Reklam süresi içinde işletme **askıya alınırsa** (bizim moderasyon
  kararımızla), kalan süre iade edilmeli mi? Sözleşmeye ne yazmalıyız?
- **Gösterim sayısı garantisi vermiyoruz** (bölgede kaç arama yapılacağı
  bilinmiyor). Bunu sözleşmede nasıl ifade etmeliyiz ki eksik ifa
  sayılmasın?
- Aynı bölgede slot sayısı **sınırlı** (mahalle 1 / ilçe 2 / il 3) ve
  dolunca satış kapanıyor. Bu sınırın **rekabet** açısından bir sakıncası
  var mı?

---

## D. Görüşmeye giderken yanında götür

1. Bu belge.
2. `docs/dukkan/03-guven-ve-fraud.md` — özellikle §5 (şikâyet ve sorumluluk) ve
   §5.3 (askı ölçütleri tablosu).
3. `docs/dukkan/02-kimlik-ve-yetki.md` §6 — KVKK tasarımı: sakinin adresi,
   telefonu ve daire numarasının bir işletmeye **otomatik gitmediği**, iki
   aşamalı görünürlük.
4. Şu iki cümle: **"Platform hizmet bedeline hiç dokunmuyor — sipariş,
   ödeme, komisyon yok."** ve **"Tek gelir, işletmelerden alınan reklam
   bedeli — doğrudan satış."**
5. `docs/dukkan/F8-kararlar.md` — reklam modelinin ürün tarafındaki
   kuralları (slot sınırı, "Sponsorlu" etiketi, sıralamaya karışmama).

## E. Görüşmeden sonra

Alınan cevapları bu belgeye **soruların altına** yaz ve hangi tasarım
kararının değiştiğini işaretle. Cevaplar `03-guven-ve-fraud.md` §5.1'deki
"EMİN DEĞİLİM" bloğunun yerini alacak.
