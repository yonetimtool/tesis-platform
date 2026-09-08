# F8 — Gelir modeli: reklam. Kararlar

> **Model değişti:** platform hizmet bedeline **hiç dokunmaz**. Sakin
> ustayla doğrudan iletişime geçer, parayı doğrudan öder. Sipariş, satın
> alma, komisyon **yok**. Tek gelir: işletmelerin görünürlük için ödediği
> **reklam bedeli** — doğrudan satış, ödeme aracılığı değil.

Faz üçe bölündü: **F8a** (para akışı yok — anlam, metin, kilit),
**F8b** (reklam modeli), **F8c** (ödeme altyapısı).

---

## Ölçüm önce: mevcut kodda ödeme varsayan ne vardı?

`odeme|siparis|komisyon|order|payment|invoice|fatura|iade|escrow|kapora`
taraması. Beklediğimden temizdi — V1 zaten "platform üzerinden ödeme yok"
varsayımıyla kurulmuştu. **Kaldırılacak kod çıkmadı**; değişen şey
**anlam ve metin** oldu, artı bir ölü durum değeri.

| Bulgu | Karar |
|---|---|
| `teklif.tutar_kurus` | **Kalır** — bu bir *beyan*, ödeme değil. Sütun yorumu eklendi |
| Göç 0118 başlığı: *"ödeme geldiğinde (V2) bu sütun hazır olacak"* | **Metin düzeltildi** — ödeme artık gelmiyor; yanlış vaat |
| `is_kaydi.durum` içinde `anlasmazlik` | **Kaldırıldı** (göç 0123) — aşağıda |
| `sikayet.tip='odeme'` + `ODEME_SIKAYET_ESIGI` + otomatik askı | **Kalır, daha önemli** — para platform dışında olduğu için kapora dolandırıcılığının tek sinyali bu |
| *"Dükkan ödemelere aracılık etmez"* uyarısı (web + mobil) | **Kalır ve güçlenir** — geçici durum değil, kalıcı politika |
| `00-mimari §8`, `01-veri-modeli §8`, `06-yol-haritasi` | **Yeniden yazıldı** |
| `01-veri-modeli`: *"EMİN DEĞİLİM: ödeme `is` mi `teklif` mi çapalanacak"* | **Düştü** — hizmet bedeli hiç çapalanmıyor |
| "İşi ver" / "Hire" / "Beauftragen" / "Нанять" | **Değişti** — aşağıda |

**Talep/teklif akışında para geçmiyor:** `tutar_kurus` yalnız yazılıyor
ve gösteriliyor. Hiçbir tahsilat, bakiye, mutabakat yolu yok;
`finansal_hareket` Dukkan'dan zaten erişilemez (`dukkan_app` `public`'e
yasaklı).

---

## F8a §1 — `anlasmazlik` kaldırıldı (göç 0123)

Hiçbir uç onu **yazmıyordu**; yalnız `is_tamamlandi` ucu "kapalı"
sayıyordu. Yani ölü bir değer — ama ölü olması zararsız olduğu anlamına
gelmiyor:

- Bir anlaşmazlık **durumu** tutmak, platformun taraflar arasında
  **hakemlik ettiğini** ima eder. Platform sözleşmenin tarafı değil.
- Kullanıcıda "platform çözer" beklentisi yaratır. Karşılanmayınca
  şikâyet, karşılanırsa üstlenilmemiş bir sorumluluk doğar.
- Hukuken aleyhe yorumlanabilir: bir uyuşmazlık süreci işleten platform,
  ilan/eşleştirmeden fazlasını yapıyor görünür.

Memnun olmayan kullanıcının yolu **zaten var ve ayrı**: yorum yazar ya da
şikâyet açar.

**Göç veri kaybı yapmıyor:** `upgrade` önce o durumda satır olup
olmadığına bakıyor; **varsa göç duruyor**. Sessizce `iptal`e çevirmek,
bir kullanıcının açık sorununu kayıt dışı bırakırdı. Bugün sıfır satır
bekleniyor — ama "beklenen" ile "ölçülen" aynı şey değil.

---

## F8a §2 — Metin: "İşi ver" → "Bu işletmeyle devam et"

7 dil + web. Diğer diller Türkçeden **daha kötüydü**: `Hire`,
`Beauftragen`, `Contratar`, `Нанять` — hepsi iş sözleşmesi/istihdam ima
ediyor.

Yalnız butonu değiştirmek yetmezdi; akışın **diğer metinleri de** aynı
yanlışı taşıyordu ("iş kabulünden sonra açılır", "işi verdiğin ustaya").
Yalnız butonu düzeltip diğerlerini bırakmak, arayüzü **kendi içinde
çelişkili** yapardı. Yedi anahtar × 7 dil değişti.

**Yeni kalıcı satır** (`dukkanAraciDegiliz`), teklif listesinin
**üstünde**, dipnot değil:

> *"Dükkan bir ilan ve eşleştirme hizmetidir. Anlaşma ve ödeme doğrudan
> işletmeyle senin arandadır; Dükkan taraf değildir."*

Butonun adı tek başına yetmez: kullanıcı bir düğmeye basıp "platform
üzerinden anlaştım" sanabilir.

---

## F8a §3 — Kısıt **kilitle** korunuyor

`test_dukkan_para_akisi_yok.py`: `talep`, `teklif`, `is_kaydi`
tablolarında ödeme ima eden bir sütun belirirse kırmızı yanar.

**Neden yorum değil test:** "bu akışa ödeme eklemeyin" cümlesini bir dosya
başlığına yazmak, o dosyayı okuyanı bağlar. Altı ay sonra `is_kaydi`ya
`odendi_at` eklemek isteyen kişi muhtemelen **göç dosyasını** yazacak ve
o başlığı hiç görmeyecek. Aynı ders daha önce alındı: "Dukkan Yönetiyor'a
yazmaz" kuralı yorumla değil **rol yetkisiyle** zorlandı (göç 0113).

**Kilit dar tutuldu — reklam tarafı serbest.** Yasak yalnız o üç tabloya
bakıyor. Reklamda ödeme **gerçek ve meşru**; orayı da yasaklamak gelir
modelini imkânsız kılardı. Geniş bir yasak, ilk meşru ihtiyaçta devre
dışı bırakılır ve o andan sonra hiçbir şey korumaz.

Kısıt ayrıca **veritabanında** da yazılı: `COMMENT ON TABLE is_kaydi` ve
`COMMENT ON COLUMN teklif.tutar_kurus` — tabloya bakan geliştirici, kodu
okumadan da neyin yasak olduğunu görür.

---

## F8b §1 — Slot sınırı: sayılar **veride**

Mahalle **1** / ilçe **2** / il **3**, artı **%20 oran tavanı**.

**Sayılar `reklam_slot_kurali` tablosunda, kodda değil.** Bir mahallede
kaç işletme olduğunu, bir ilçede kaç arama yapıldığını bugün bilmiyoruz;
bunlar **tahmin**. Kodda sabit olsalardı her ayar bir dağıtım demek
olurdu. Tablo `etkin_at` ile versiyonlu ve eski satırlar **silinmez** —
"o tarihte kural neydi" sorusu bir itirazda sorulur.

**Oran tavanı neden var:** mahallede 3 işletme varsa 1 slot bile listenin
üçte biri olur. Sayfa reklam panosuna dönerse organik sonucun değeri
düşer — ve satılan şey tam olarak *"değerli bir listenin üstünde
olmak"*. Etkin slot = `min(kural slotu, işletme_sayısı × oran / 100)` ve
**aşağı yuvarlanır**: 3 işletme + %20 → **0 slot**. Yukarı yuvarlamak,
tam da önlemek istediğimiz durumu üretirdi.

**Kural yoksa satış kapalı** (0 slot). "Kural bulunamadı" durumunda
sınırsız satmak, bir yapılandırma hatasını gelire çevirip sayfayı reklam
panosuna döndürürdü.

---

## F8b §2 — Slot dolunca **satış kapanır**, rotasyon yok

Fazla satıp sırayla göstermek daha çok gelir getirirdi. Yapılmadı:
işletme **ne satın aldığını bilemez**, "ne kadar göründüm" sorusu doğar
ve platform onu **kanıtlamak** zorunda kalır. Kapalı satış dürüst: *"bu
bölge dolu, sıraya girin."* Kıtlık ayrıca fiyatı korur.

**Bekleme listesi** (`reklam_bekleme`): yanıt **kaçıncı sırada olduğunu**
döner — "sıradasınız" demek yetmez, kaçıncı olduğunu bilmeyen işletme
bekleyip beklememeye karar veremez.

**Yer varken sıraya alınmaz** (409 `yer_var`): işletme beklediğini sanıp
beklerken, satın alabileceği bir yer boş dururdu.

**Vazgeçen silinmiyor**, `vazgecti` işaretleniyor: "kaç işletme sıraya
girip vazgeçti" bölge fiyatlaması için bir sinyal.

---

## F8b §3 — Sponsorlu görünüm: **ayrı anahtar, ayrı sorgu, ayrı blok**

Arama yanıtı artık `items` (organik) **ve** `sponsorlu` (reklamlı) olarak
iki anahtar döner.

`items` içine karıştırmak daha az kod olurdu — ve tam olarak yasaklanan
şey o:

- Karıştırmak, kullanıcının "en iyi sonuç" sandığı şeyi satmak olurdu.
- Ayrı anahtar, istemcinin **rozeti unutmasını** zorlaştırıyor.
- `siralama_puani` bu sorgudan **habersiz** kalır.

**`sponsorlu: true` bayrağı sunucudan geliyor.** İstemcinin "bu listeden
gelenler sponsorludur" varsayımına bırakılsaydı, ikinci istemci (mobil) o
varsayımı taşımayabilir ve **rozet düşerdi**. Rozet zorunlu.

**Sponsorlu işletme organik listede de çıkar** (hak ettiği sırada).
Organikten çıkarmak, paranın sıraya karışmasının tersten hâliydi.

**Kategorisiz aramada sponsorlu gösterilmiyor:** "Çekmeköy'de her şey"
arayan kullanıcıya elektrikçi reklamı göstermek alâkasız reklamdır ve
tıklanmayan reklam iki tarafı da memnuniyetsiz bırakır.

**Yalnız ilk sayfada:** ikinci sayfaya inen kullanıcı zaten aramasını
sürdürüyor; oraya da reklam koymak listeyi reklamla kesmek olurdu.

**Sponsorlu bloğun kendi içinde sıra:** dar kapsam önce (mahalle > ilçe >
il), sonra eski alan önce. `siralama_puani` **kullanılmıyor** —
kullanılsaydı para ile organik puan aynı sorguda buluşur ve ayrım
bulanırdı.

**Kilit:** `test_REKLAM_SIRALAMA_PUANINI_DEGISTIRMEZ` — reklam satın
alındığında `siralama_puani` aynı kalmalı. İddia değil, ölçüm.

---

## F8b §4 — Süre bitimi: düşer, hatırlatır, sırayı haberdar eder

Gecelik `dukkan.reklam_bakimi` (02:20 — sıralama işinden sonra; ikisi
aynı veritabanına yazıyor).

- **Süresi biten** `durum='bitti'` olur. **Silinmez**: "geçen ay hangi
  reklam yayındaydı" sorusu bir faturada ya da itirazda sorulur.
- **Hatırlatma** bitişe 7 gün ve 1 gün kala. Aynı gün ikinci bildirim
  yazılmaz (görev günde birden fazla koşarsa kullanıcı aynı uyarıyı
  birkaç kez almasın).
- **Yer açıldı** bildirimi bekleme listesinin **ilk sırasındakine**.
  Hepsine göndermek, birinin alacağı tek yer için herkesi koşturmak
  olurdu.

**Otomatik yenileme yok** — karar, eksiklik değil. Sessizce kart çekmek
en çok şikâyet üreten şeydir; üstelik iptal ve kısmi iade akışı
gerektirir. İşletme yenilemeyi kendi yapar; biz yalnız hatırlatırız.

Bildirim tipleri `dukkan_` **önekli** (F6-ek kanal kuralı): öneksiz bir
tip Yönetiyor kanalından gider ve kullanıcı pazar yeri bildirimlerini
kapattığını sanıp almaya devam ederdi.

---

## F8b §5 — Reklam **kategoriye bağlı**

"Çekmeköy'de öne çık" değil, **"Çekmeköy'de elektrikçi ararken öne
çık"**. Kategorisiz reklam alâkasız aramalarda çıkar; işletmenin o
kategoride kayıtlı olması da şart (400 `isletme_bu_kategoride_degil`).

**Onaysız işletme reklam alamaz** (403): aramada hiç görünmeyen bir
işletmeye para ödetmek olurdu.

**Çakışma veritabanında engelleniyor:** aynı işletme + kategori + bölge
için çakışan tarihli iki reklam `EXCLUDE USING gist` ile imkânsız.
Uygulama düzeyinde saymak, eş zamanlı iki satın almada **ikisini de**
geçirirdi (TOCTOU) — ve işletme aynı şeyi iki kez ödediğini ancak
faturada görürdü.

---

## Ölçemediklerim

1. **Slot sayılarının doğruluğu.** 1/2/3 ve %20 birer **tahmin**. Gerçek
   arama hacmi ve bölge yoğunluğu görülmeden doğrulanamaz — bu yüzden
   veride tutuluyorlar.
2. **Reklamın işe yarayıp yaramadığı.** Tıklama/görüntülenme ölçümü
   **yok** (F8'de bilerek): ölçüm eklemek, "gösterim garantisi" beklentisi
   yaratır ve sözleşmede taahhüt hâline gelir (avukat sorusu S19).
3. **Fiyatın doğruluğu.** `reklam_paketi` boş geliyor; fiyatlar veriden
   yükleniyor ve bugün **hiç fiyat yok**.
4. **Gerçek ödeme.** F8c'de; bu fazda reklam **doğrudan** açılıyor.
