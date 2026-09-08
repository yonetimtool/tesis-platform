# DUKKAN — Açık maddelerin önceliği

> `DURUM.md`'deki sekiz teknik açığın triyajı. Ölçüt tek: **ürün bu madde
> olmadan çalışır mı?** "Çalışır" = talep açılır, teklif gelir, iş verilir,
> yorum yazılır, dolandırıcılık bildirilebilir.
>
> Madde 1 (mobil bildirim ekranı + FCM kaydı) **F6-ek'te kapatıldı**;
> aşağıdaki liste kalan yedisi.

---

## Ürünü ENGELLEYENLER — **F7'de kapatıldı**

> İkisi de yazıldı ve `main`'e push'landı (`F7-kararlar.md`,
> `F7-dagitim.md`). SMS başlığı onayı beklenmedi: ikisi de başlık gelene
> kadar *tam olarak* sürülemez ama başlık geldiği gün **tek satır
> `SMS_BASLIK=`** ile çalışır. Aşağıdaki iki bölüm kayıt olarak duruyor.

### 1. Mobilde telefon-OTP akışı yok — **%27'lik duvar**

> `F4 §14` · Ölçüldü: Yönetiyor'daki 3104 kullanıcının **837'sinde (%27)
> telefon yok.**

Bu insanlar mobilde Dukkan jetonu **alamıyor**. Köprü 409
`telefon_gerekli` dönüyor, uygulama "dukkan.yonetiyor.com'a gidin"
diyor. Yani her dört kullanıcıdan biri, akışın ortasında **tarayıcıya
gönderiliyor** — ve pratikte orada kayboluyor.

**Neden engelliyor:** talep açmak, teklif görmek, panel — hepsi jeton
istiyor. Bu kullanıcılar için mobil Dukkan **arama ekranından ibaret**.

**İş:** mobilde OTP ekranı (kod iste / doğrula) + köprünün 409 dalını o
ekrana bağlamak. Backend uçları **zaten var**
(`/dukkan/auth/telefon/kod`, `/dogrula`) ve web'de çalışıyor.

**Bağımlılık:** **SMS başlığı onayı.** Başlık gelmeden OTP ekranı
yazılabilir ama sürülemez — kod hiç gitmez.

---

### 2. Davet kotası: başarısız SMS kotayı yiyor

> `F5-dagitim §6`

Yorum daveti kotası `3 + 2×etkinlik`. SMS gönderimi **başarısız olsa
bile** kota tüketiliyor. Başlık onayı gelene kadar prod'da **her davet
başarısız** — yani ilk işletmeler kotalarını hiç SMS gitmeden bitirir.

**Neden engelliyor:** güven sisteminin arz tarafı (yorum toplama)
başlangıçta **tamamen** çalışmaz hâle gelir ve bunu ancak işletme
şikâyet edince fark ederiz.

**İş:** küçük. `telefon_dogrulama`daki kısmi indeksin aynısı: gönderim
başarısızsa kota satırı sayılmasın. Göç 0116'da aynı kalıp zaten var,
kopyalanacak.

---

## İYİLEŞTİRMELER

### 3. Bildirim toplulaştırma (batching) yok — *yakında engelleyici olur*

> `F6 §13`

Bir talep bölgedeki **tüm** eşleşen işletmelere ayrı push atıyor. Bugün
bölge başına birkaç işletme var; sorun değil. Bir mahallede 30
elektrikçi olduğunda, tek talep 30 bildirim demek ve ustalar
bildirimleri **kapatır** — kapattıkları an pazar yeri arz tarafını
kaybeder.

**Ne zaman:** ilk yoğun mahallede işletme sayısı ~10'u geçtiğinde. Ölçüm
sorgusu basit; `dukkan.isletme_hizmet_alani`'nda mahalle başına sayım.

Yönetiyor'da vardiya özetleri için **batching zaten yazıldı** (P181 §10);
kalıp hazır.

### 4. `bildirim` tablosunda retention yok

> `F6-dagitim §8`

Tablo sınırsız büyür. Bugün birkaç yüz satır. KVKK açısından da
savunulacak bir saklama süresi yazılı değil — ama bildirim satırı
`tip` + `veri` tutuyor, içinde kişisel veri **yok** (ad/telefon
paylaşımı `talep` tarafında ve orada kural yazılı).

**Ne zaman:** ilk gerçek trafikten sonra, gecelik Celery görevine bir
satır. Yönetiyor'un `retention` görevi kalıp olarak duruyor.

### 5. `talep.son_gecerlilik` var ama kullanılmıyor

> `F4 §14`

Süresi dolan talepler `acik` kalıyor; işletmeler aylar önceki bir talebe
teklif verebilir ve müşteri şaşırır. Kolon **var**, dolduruluyor, hiçbir
sorgu bakmıyor.

**İş:** küçük ve iki yerde: eşleşme sorgusuna filtre + gecelik görevde
`durum='suresi_doldu'`. Şu an talep hacmi sıfır olduğu için etkisi yok.

### 6. İtiraz ucu yok

> `F5 §14`

İşletme, reddedilen/askıya alınan kararına uygulama içinden itiraz
edemiyor; süreç e-posta. **Denetim izi hazır** (`denetim` tablosu
append-only, karar ve gerekçe yazılı), yani itiraz geldiğinde
incelenebiliyor.

**Neden engelleyici değil:** V1'de moderatör sayısı bir kişi ve karar
hacmi düşük. Bir uç yazmak, gelmeyen itirazlar için ekran yapmak olurdu.

**Ne zaman:** aylık ret sayısı iki haneye çıktığında.

### 7. Jeton `localStorage`'da — **ARTIK ENGELLEYİCİ (F8)**

> **Sınıfı değişti.** Bu madde "ödeme fazından önce yapılmalı" diye
> yazılmıştı ve ödeme fazı **geldi**. Reklam satın alma akışı devreye
> girdiğinde, çalınan bir jeton başkasının adına reklam satın
> alabilir — ve o an gerçek para söz konusu.
>
> **Sağlayıcı bağlanmadan önce yapılmalı.** Bugün ödeme kapalı olduğu
> için hâlâ zaman var; sağlayıcı onayı geldiği gün bu madde ilk sıraya
> çıkar.

> `F2 §11`

XSS'e açık. httpOnly çerez daha güvenli olurdu. Panelin sunduğu yüzey
dar ve **para/ödeme yok**; risk şu hâliyle kabul edilebilir görünüyor.

**Ne zaman: ödeme fazından ÖNCE, o fazın ilk maddesi olarak.** Para
girdiği anda bu maddenin sınıfı değişir — iyileştirmeden **engelleyiciye**
döner. Kararlar belgesinde açık madde olarak yazılı.

---

## Önerilen sıra

| # | Madde | Neden bu sırada |
|---|---|---|
| ~~1~~ | ~~**Davet kotası düzeltmesi**~~ | **F7 §1 — YAPILDI** (göç 0122) |
| ~~2~~ | ~~**Mobil OTP akışı**~~ | **F7 §2 — YAPILDI** (jeton cihazda, sızıntı kilidi kırılarak doğrulandı) |
| 1 | **SMS başlığı** (dış bağımlılık) | Yukarıdaki ikisini de *çalışır* hâle getirir; sende, kod işi değil |
| 4 | `talep.son_gecerlilik` | Küçük; ilk gerçek talepler gelmeden yapılırsa hiç veri düzeltmesi gerekmez |
| 5 | Bildirim batching | İlk yoğun mahalle görülünce; erken yapmak tahminle ayar demek |
| 6 | `bildirim` retention | Gerçek hacim görülünce |
| 7 | İtiraz ucu | Ret hacmi iki haneye çıkınca |
| 8 | Jeton taşıma | **Ödeme fazının ilk maddesi** — o zamana kadar bekler |

> 1–3 arasındaki üçü birlikte "pazar yeri mobilde de tam çalışır"
> demek. 4–8 ürün yaşadıkça ölçülerek yapılacak işler.
