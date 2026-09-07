# DUKKAN F5 — KARARLAR

Güven katmanı: iki katmanlı yorum, davet kotası, cevap hakkı, şikâyet,
askı ölçütleri, moderasyon paneli. Web + mobil.

---

## 1. İki katman — filtrelemek değil AYIRMAK

İdeal kural *"yalnız platform üzerinden tamamlanmış işe yorum"* olurdu ve
sahte yorumu neredeyse tümüyle keserdi.

Gerçek hayat başka: kullanıcı numarayı görür, **telefonla arar**, iş biter.
Platform bunu hiç görmez — ve bu bir kaçak değil, **beklenen davranış**.

İdeal kuralı uygularsam yorumların ~%90'ı doğmaz, işletmelerin çoğu "0 yorum"
görünür ve pazar yeri **yorumsuz** kalır. **Katı olan kural, burada güvenli
olan kural değil.**

| Katman | Şart | Rozet | Ağırlık |
|---|---|---|---|
| **A — platform** | `is_kaydi` kaydı + `tamamlandi` | ✔ görünür | 1.0 |
| **B — davet** | işletmenin daveti + OTP | yok, **etiketli** | 0.3 |

`kaynak` **her yanıtta** dönüyor; özet iki katmanı **ayrı** sayıyor. Kullanıcı
*"8 doğrulanmış"* ile *"0 doğrulanmış, 40 davetli"* arasındaki farkı **kendi
okuyor** — kararı gizlemek yerine görünür kılıyoruz.

Arayüzde iki katman **ayrı başlıklar** altında ve davetlilerin üstünde ne
oldukları yazılı. Aynı listeye karıştırıp sonuna küçük bir etiket iliştirmek,
farkı *teknik olarak* göstermek ama *fiilen* gizlemek olurdu.

---

## 2. Doğrulanmış olumsuz yorum **doğrudan yayınlanır**

Gerçek bir iş var; susturmak yorum sistemini **yalancı** yapardı. Bir test
bunu ters yönden kanıtlıyor: kural *"iyi yorumu yayınla"* değil.

**Davetli + olumsuz** ise moderasyona düşüyor (doğrulanmış iş yok). Rakip
saldırısını (T2) **susturmadan yavaşlatmanın** yolu: yayın **gecikir,
kaybolmaz**.

---

## 3. Kendine yorum — iki kaçak yolu da kapalı

1. Sahip **doğrudan** yazamaz (`sahip_kullanici_id` eşleşmesi).
2. Sahip, **işletme numarasıyla ayrı bir Dukkan hesabı** açıp yazamaz
   (telefon eşleşmesi).

İkincisi önemli: sahiplik kontrolü tek başına onu **yakalamaz** — hesap
farklı bir kullanıcı. **Kırarak doğrulandı:** iki kontrolü de kaldırınca iki
test kırmızı yandı.

**Kendi numarasına davet** de 403 — en kaba sahte yorum yolu.

---

## 4. Davet kotası — maliyeti gerçek işe bağlamak

```
hak = min(30, 3 + (son 30 gündeki teklif + iş sayısı) × 2)
```

Kotasız davet, *"bana 50 yorum yaz"* demenin platform onaylı yolu olurdu.
Kota, sahte yorum üretmenin maliyetini **gerçek iş yapmaya** bağlıyor.

**Taban 3, sıfır değil:** yeni bir işletme platform dışında yaptığı ilk işler
için hiç yorum toplayamaz ve "0 yorum" olarak doğar — bu, arz tarafını başta
cezalandırırdı.

**Tavan 30:** etkinliği çok olan işletme bile sınırsız davet gönderemesin.

**Aynı numaraya 90 günde bir.**

İşletme kotasını **görüyor** (`/yorum-daveti/kota`) — görmezse *"neden
gönderemiyorum"* sorusu cevapsız kalır ve destek yükü doğar.

---

## 5. Kota aşımı denetime yazılıyor — ve bir kusur düzeltildi

Kullanıcının şartı: *"kota aşımı ve şüpheli örüntü admin'e bildirilsin"*.
Sessizce reddetmek kötüye kullanımı **görünmez** yapar — engellenen deneme de
bir sinyaldir.

**İlk yazımda bu çalışmıyordu ve test yakaladı.** Denetim kaydı aynı oturuma
yazılıp hemen ardından `HTTPException` fırlatılıyordu; istek başarısız olduğu
için transaction **geri sarılıyor** ve kayıt **kayboluyordu**.

> İroni tam burada: kaydın varlık sebebi *"engellenen deneme de bir
> sinyaldir"* idi ve sinyal, **tam da engellendiği için** siliniyordu.

Düzeltme: denetim satırı **ayrı ve kendi commit'i olan** bir oturuma yazılıyor.

---

## 6. İşletme silemez, **cevap verebilir**

Silme yetkisi verilseydi olumsuz her yorum kaybolur ve sistemin tamamı
anlamsızlaşırdı. İşletme:

- **cevap** verebilir (herkese açık, okuyucu iki tarafı görür — çoğu durumda
  en iyi savunma),
- **bildirebilir** (moderasyona düşer).

Silme ucu **yok** ve bir test `DELETE`'in 404/405 döndüğünü ölçüyor.

---

## 7. Şikâyet **kimliksiz** — bilinçli

Dolandırılan bir kullanıcının Dukkan hesabı **olmayabilir**: numarayı
profilden alıp telefonla aramış olabilir. Kimlik zorunlu olsaydı **en çok
duyulması gereken ses kesilirdi**.

`iletisim` opsiyonel ve **neden** istendiği yazılı — zorunlu yapmak, anonim
kalmak isteyen kişiyi şikâyet etmekten caydırırdı.

**Yanlış yazılmış `isletme_slug` şikâyeti reddetmiyor**, yalnızca işletme
bağlantısı boş kalıyor: bir dolandırıcılık şikâyetini slug hatası yüzünden
reddetmek en kötü sonucu üretirdi.

---

## 8. Otomatik askı yerine **aday listesi** — tasarımdan bilinçli sapma

`03-guven-ve-fraud.md` §5.3 **otomatik askı** diyordu ve gerekçesi sağlamdı:
*bekleyen her gün yeni mağdur demek.*

Uygularken şu görüldü: **şikâyet kimliksiz yapılabiliyor** (§7 — bilinçli bir
karar), dolayısıyla **üç şikâyet üretmek ucuz**. Otomatik askı, bir işletmeyi
**rakibinin** kapatmasının yolu olurdu.

İki kaygıyı birleştiren çözüm: eşik aşıldığında kayıt **anında** aday
listesine düşüyor, moderatöre **kırmızı sayaçla** görünüyor ve **aynı gün**
bakılıyor (§5.4 "acil"). Hız korunuyor, karar bir insanın.

Bu sapma panelde de yazılı — moderatör **neden otomatik olmadığını** görüyor.

---

## 9. Şüpheli örüntü: işaret, **ret değil**

Aynı IP'den aynı işletmeye ikinci yorum → moderasyon kuyruğu. **Otomatik ret
değil:** ortak ev/işyeri IP'si meşru olabilir ve otomatik ret **doğru
yorumları da keserdi**.

Moderasyon kuyruğunda `supheli_sebep` **her satırda** görünüyor: moderatör
**neden** kuyrukta olduğunu bilmeden karar veremez. *"Doğrulanmamış olumsuz"*
ile *"aynı IP'den ikinci yorum"* **farklı** kararlar gerektirir.

---

## 10. Moderasyon paneli — tek ekran (F2 açık maddesi kapandı)

Dört sekme: **Başvurular · Yorumlar · Şikâyetler · Askı adayları**. Her
sekmenin sayacı görünüyor; moderatör neye bakacağını **açmadan önce** biliyor.

Üç ayrı sayfa yapmak, günde 20–30 dakikalık bir işi bir saate çıkarırdı
(§5.4'ün hacim varsayımı).

**Askı adayları dördüncü sekme ve dolu olduğunda sayaç kırmızı** — boşken
dikkat çekmemeli, doluyken kaçırılmamalı.

Ret/askı/kapatma kararlarında **gerekçe önce** isteniyor (`prompt`), sonra
istek atılıyor: gerekçesiz gönderip 422 almak kullanıcıyı iki adıma sokardı.

---

## 11. Belge yükleme ekranı (F2 açık maddesi kapandı)

Presign akışı: sunucu **megabaytlarca ikili veriye aracı olmuyor**, tarayıcı
doğrudan depoya yüklüyor.

- **Zorunlu olmadığı yazılı** — zorunlu sanılırsa kayıt akışı gereksiz
  tıkanır. Ne işe yaradığı söyleniyor: *"Doğrulanmış işletme"* rozeti.
- **İnceleme durumu görünüyor** (inceleniyor / onaylandı / reddedildi + not).
  Görmezse *"yükledim ama bir şey olmuyor"* durumunda kalır.
- **Moderatörün adı dönmüyor** — kimliği işletme sahibine karşı korunmalı.
- **PUT düşerse söyleniyor:** presign başarılı olup yükleme düşerse kayıt
  "bekliyor" kalır ve kullanıcı yüklediğini **sanardı**.

---

## 12. Mobil

| Web | Mobil | Neden |
|---|---|---|
| Yorumlar profilde iki bölüm | **Aynı ayrım**, kart tabanlı | Rozet farkı telefonda da görünür olmalı |
| Şikâyet ayrı sayfa | **Ayrı ekran, kimliksiz** | Jeton istemiyor — hesabı olmayan da bildirebilmeli |
| Moderasyon paneli | **YOK** | Bilinçli: masaüstü işi (§14) |

---

## 13. Kırarak doğrulananlar

| Kırma denemesi | Sonuç |
|---|---|
| Kendine yorum kontrolünü kaldır | **2 test kırmızı** |
| Davet kotasını kaldır | kırmızı |
| Olumsuz davetli yorumu doğrudan yayınla | kırmızı |
| Sahiplik kontrolünü kaldır | **11 uç kırmızı** |

---

## 14. Açık maddeler

| Madde | Durum |
|---|---|
| **Moderasyon paneli mobilde yok** | **Bilinçli.** Moderatör işi masaüstü işi: uzun metin okuma, gerekçe yazma, belge inceleme. Telefonda yapılabilir ama iyi yapılamaz — ve yarım bir moderasyon ekranı, acele karar demek |
| **Bildirim yok** | Yorum daveti SMS ile gidiyor; ama "teklif geldi", "yorumun yayınlandı", "işletmen askıya alındı" için push yok. F6 |
| **Yorum düzenleme yok** | Kullanıcı yazdığı yorumu değiştiremiyor. Bilinçli: düzenlenebilir yorum, işletmenin baskısıyla değiştirilebilir yorum demektir |
| **İtiraz süreci** | `03` §5.3 "her olumsuz karar için bir kez itiraz hakkı" diyor. Denetim kaydı ve gerekçeler **hazır**, ama itiraz **ucu yok** — operasyonel olarak e-posta ile yürüyecek |

---

## 15. Ölçemediklerim

1. **Sahte yorumun gerçek maliyeti.** Kota formülü bir **tahmin**: `3 + 2×etkinlik`,
   tavan 30. Gerçek trafikte kaç davetin cevaplandığını, kaç işletmenin kotayı
   doldurduğunu bilmiyorum. İlk üç ayda ölçülüp ayarlanmalı.
2. **Eşik "3 ödeme şikâyeti"** aynı şekilde tahmin.
3. **Ağırlık `0.3`** — davetli yorumun doğrulanmışa oranı. Ölçülmüş değil;
   `03` §2.2b'de gerekçesi yazılı ama gerçek dağılımla sınanmadı.
4. **Şüpheli örüntü tespiti IP tabanlı ve zayıf.** Aynı evden iki meşru yorum
   kuyruğa düşer (moderatör yükü), farklı ağlardan gelen organize sahte yorum
   **düşmez**. Cihaz parmak izi yok.
