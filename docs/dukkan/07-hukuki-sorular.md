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
> teklif verir, kullanıcı birini seçer. **V1'de platform üzerinden ödeme,
> sipariş veya komisyon YOK** — para tamamen taraflar arasında, platform dışında
> el değiştirir. Platform işletmelerden ücret almaz. Kullanıcılar yorum yazar.
> İşletmeler kayıt olur ve **elle onaydan** geçer.

Bu tanımın **"ödeme yok"** kısmının altını çiz: aşağıdaki soruların çoğunun
cevabı buna bağlı.

---

## A. EN KRİTİK — yayından önce (1-5)

### 1. Dukkan, 6563 sayılı Kanun anlamında "elektronik ticaret aracı hizmet sağlayıcı" (ETAHS) mı?

**Neden önemli:** Bütün uyum yükü bu tek cevaba bağlı. ETAHS isek ETBİS kaydı,
hizmet sağlayıcı bilgilerinin doğrulanması ve ciro eşiklerine bağlı ek
yükümlülükler gündeme gelir; değilsek yük çok daha hafif.

**Sorunun özü:** Platform üzerinden **sipariş/sözleşme kurulmuyor ve ödeme
alınmıyorsa**, yapılan iş "aracı hizmet sağlayıcılık" mı yoksa bir **ilan/
rehber hizmeti** mi sayılır?

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

### 13. Platform bir gün komisyon/abonelik alırsa ne değişir?

**Neden önemli:** Cevap veri modelini **bugünden** etkileyebilir. Tasarımda para
alanı kuruş `bigint` olarak hazır ama akışın nereye çapalanacağı
(`is` mi `teklif` mi) belirsiz bırakıldı — çünkü bu bir iş kararı.

**Sorunun özü:**
- **Abonelik** (işletmeden sabit ücret) ile **komisyon** (iş başına yüzde)
  arasında hukuki fark var mı?
- Komisyon alırsak ETAHS statüsü **kesinleşir mi** (soru 1)?
- Platform **ödemeye aracılık ederse** BDDK lisansı gerekir mi? *(Bu yüzden V1'de
  ödeme kapsam dışı bırakıldı — doğru bir karar mı?)*

### 14. Fatura: işletmeden ücret aldığımızda faturayı kim, kime, ne zaman keser?

*(Bu soru mali müşavire.)*

### 15. Platformdaki işletmeler bizim "çalışanımız" ya da "bayimiz" sayılır mı?

**Neden önemli:** Türkiye'de gig-ekonomi platformlarında bu tartışma açık.
Sözleşme dilini bugünden doğru kurmak, sonradan düzeltmekten ucuz.

### 16. Yönetiyor ile Dukkan'ın aynı şirket altında olması bir risk doğurur mu?

**Sorunun özü:** Dukkan'da doğan bir hukuki sorun Yönetiyor'un müşteri
ilişkilerini etkiler mi? İki ürünü **ayrı tüzel kişilik** altında tutmak
mantıklı mı, yoksa gereksiz karmaşıklık mı?

---

## D. Görüşmeye giderken yanında götür

1. Bu belge.
2. `docs/dukkan/03-guven-ve-fraud.md` — özellikle §5 (şikâyet ve sorumluluk) ve
   §5.3 (askı ölçütleri tablosu).
3. `docs/dukkan/02-kimlik-ve-yetki.md` §6 — KVKK tasarımı: sakinin adresi,
   telefonu ve daire numarasının bir işletmeye **otomatik gitmediği**, iki
   aşamalı görünürlük.
4. Şu tek cümle: **"V1'de platform üzerinden ödeme ve sipariş YOK."**

## E. Görüşmeden sonra

Alınan cevapları bu belgeye **soruların altına** yaz ve hangi tasarım
kararının değiştiğini işaretle. Cevaplar `03-guven-ve-fraud.md` §5.1'deki
"EMİN DEĞİLİM" bloğunun yerini alacak.
