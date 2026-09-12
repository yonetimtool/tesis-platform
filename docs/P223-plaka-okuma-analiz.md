# P223 §3 — Plaka okuma (ANPR/LPR) analizi

**Bu belge bir ÖNERİDİR, kod değildir.** Onay beklenen kısım budur;
otopark sayacı onaydan bağımsız olarak bu turda yapıldı.

Tarih: 2026-09-11

---

## 0. Önce ölçülen: neyimiz zaten var

| Parça | Durum |
|---|---|
| `vehicle_pass` tablosu — plaka + giriş/çıkış zamanı, açık geçiş = içeride | **var** |
| `GET /parking/occupancy` — kapasite / dolu / oran | **var** |
| `tenant.otopark_kapasite` | **vardı, ama hiçbir ekranda girilemiyordu** (bu turda eklendi) |
| Elle giriş/çıkış işaretleme uçları | **vardı, ama yönetici yetkisiz**di (bu turda eklendi) |

Yani plaka okuma **sıfırdan bir modül değil**, mevcut `vehicle_pass`
akışına bir **otomatik kaynak** eklemektir. Bu, aşağıdaki üç yolun
hepsini aynı veri modeline bağlamayı mümkün kılıyor — seçim
değişirse uygulama katmanı değişmez.

---

## 1. Üç yol

### (a) Kamera okur — kamera içi ANPR

**Kapsam:** Hikvision'ın ANPR/"Vehicle Detection" özellikli modelleri
(DeepinView serisi, bazı ColorVu/AcuSense ITS modelleri), Dahua'nın ITS
/ "Traffic" ve bazı WizMind modelleri. **Standart bir dome/bullet
kamerada bu özellik yoktur** — model adına bakmak yetmez, ürün
sayfasındaki "License Plate Recognition / ANPR" satırı aranmalıdır.

**Nasıl bildirir:** kamera, olayı kendi HTTP "event notification"
mekanizmasıyla gönderir (Hikvision ISAPI `/ISAPI/Event/notification/
httpHosts` → bizim uca POST; Dahua'da benzeri). Gövde plakayı, zamanı ve
genelde bir kırpılmış görüntü taşır.

**Artı:** sunucuda **sıfır** CPU. Okuma kamera üzerinde, üretici
tarafından optimize edilmiş donanımla yapılır.
**Eksi:** kamera değişimi gerekir (ANPR'li modeller belirgin şekilde
pahalı); her marka ayrı entegrasyon; kamera konumu/açısı plaka okumaya
uygun olmalı (aşağıda).

### (b) NVR okur

**Kapsam:** Hikvision/Dahua'nın bazı NVR modellerinde "AI by NVR" veya
"Plate Recognition" modülü var; kameradan gelen ham görüntüyü NVR
işliyor. Genelde **kanal başına lisans** ve NVR'ın toplam AI kanal
sayısı sınırı var.

**Artı:** mevcut kameralar değişmeyebilir.
**Eksi:** NVR modeline sıkı bağımlılık; lisans maliyeti; olayı dışarı
verme biçimi markaya özel ve genelde kameradan daha kısıtlı.

### (c) Sunucuda yazılım okur

**Seçenekler:** OpenALPR (açık çekirdek + ticari bulut), PaddleOCR
tabanlı hatlar, YOLO-plaka + OCR kombinasyonları, Frigate + ALPR
eklentisi.

**Gerçekçi CPU maliyeti.** Burada **ölçtüğüm bir sayı yok** ve uydurmam
doğru olmaz; bu yüzden mertebeyi ve neyin ölçülmesi gerektiğini
yazıyorum:

- Sürekli izleme (her kareyi işlemek) **gereksizdir**. Plaka yalnızca
  araç geçerken vardır; doğru tasarım **hareket/araç tetiklemeli**
  çalışmaktır: kare farkıyla ya da hafif bir araç dedektörüyle aday
  kareleri seçip yalnızca onları OCR'a vermek.
- Böyle bir hatta yük, **geçiş sayısıyla** ölçeklenir, kamera sayısıyla
  değil. Günde 200 araç girişi olan bir sitede iş, kapı başına günde
  birkaç yüz kısa OCR çağrısıdır.
- Her kareyi işleyen naif bir kurulum ise tek kamerada bile bir CPU
  çekirdeğini doyurur; 4 kamerada mevcut sunucu (192.168.1.105) API +
  Postgres + Celery + MinIO ile birlikte **zorlanır**.

**Ölçülmesi gereken, tahmin edilmemesi gereken:** seçilen hattın tek bir
geçişte harcadığı CPU-saniye ve gecikme. Bunu ancak gerçek kamera
görüntüsüyle, gerçek sunucuda ölçebiliriz. Prod sunucunun çekirdek
sayısı ve mevcut yükü de ölçülmeden "kaç kamera kaldırır" sorusuna
dürüst bir sayı veremem.

---

## 2. KVKK — plaka kişisel veridir

Plaka, bir araç üzerinden **belirlenebilir gerçek kişiye** bağlanabildiği
için kişisel veridir. Site otoparkında okunması, KVKK m.5/2-f (meşru
menfaat) ile yürütülebilir ama **şartlara tabidir**:

1. **Aydınlatma zorunlu.** Otopark girişine, kamerayla plaka okunduğunu,
   kim tarafından ve hangi amaçla işlendiğini yazan bir levha; ayrıca
   uygulamadaki aydınlatma metnine eklenmesi. Levhasız okuma, hukuka
   aykırı işlemedir.
2. **Amaçla sınırlılık.** Amaç "otopark doluluğu ve site güvenliği"dir.
   Aynı veriyle "kim saat kaçta geldi gitti" raporu üretmek **amaç
   aşımıdır** — teknik olarak mümkün olması, meşru olduğu anlamına
   gelmez.
3. **Saklama süresi.** Öneri: **plaka metni 30 gün**, sonra silinir;
   **istatistik (saatlik giriş/çıkış sayısı) süresiz** ama plakasız.
   Doluluk için plakaya kalıcı olarak ihtiyaç yoktur — sayaç, plakayı
   yalnız "bu araç hâlâ içeride mi" eşlemesi için kullanır. Görüntü
   kırpıntısı saklanacaksa süresi daha da kısa (7 gün) olmalı ve
   gerekçesi yazılmalı.
4. **Rıza gerekir mi?** Meşru menfaat dayanağıyla rıza gerekmez, ama
   **veri sahibinin itiraz hakkı** vardır ve itirazı karşılayacak bir
   yol bulunmalı (bir sakin "aracımın plakası kaydedilmesin" derse ne
   olacak — o araç elle işaretlenir).
5. **VERBİS / envanter.** İşleme faaliyeti kişisel veri envanterine
   eklenmeli; yönetimin aydınlatma metni güncellenmeli.
6. **Aktarım yok.** Bulut tabanlı bir ANPR servisi (ör. OpenALPR Cloud)
   kullanılırsa plaka **yurt dışına aktarılmış** olur ve bu ayrı bir
   hukuki rejimdir. **Öneri: yalnız yerel işleme.**

---

## 3. Yanlış okuma sayacı nasıl bozar, nasıl telafi edilir

Gerçek ANPR'da hatalar kaçınılmazdır: gece, yağmur, kirli plaka, açı,
iki aracın arka arkaya girmesi. İki hata tipi ve etkileri:

| Hata | Sayaca etkisi |
|---|---|
| Giriş okunmaz, çıkış okunur | Kapatılacak açık geçiş yok → çıkış **düşer**, sayaç doğru kalır ama geçiş kaydı eksik |
| Giriş okunur, çıkış okunmaz | Açık geçiş **sonsuza kadar** kalır → sayaç **şişer** |
| Plaka yanlış okunur (34ABC12 → 34A8C12) | Girişte yanlış kayıt, çıkışta eşleşmez → sayaç şişer |

**Telafi — üçü birlikte:**

1. **Bayat geçiş süpürme.** `N saatten` uzun süredir açık kalan geçişler
   otomatik kapatılır (öneri: 24 saat, tesis ayarı). Kapanış "otomatik"
   olarak işaretlenir ki elle kapatılanla karışmasın. Bu, "şişme"
   hatasının **ana** telafisidir.
2. **Yöneticinin elle düzeltmesi.** Açık geçişler listesi girişten
   eskiye sıralı gösterilir, yönetici gerçekte çıkmış olanı kapatır.
   **Ofset sayacı KULLANILMAMALI**: "dolu = açık geçiş + elle düzeltme"
   biçiminde bir düzeltme, kimsenin açıklayamadığı bir sayı üretir ve
   plaka entegrasyonu geldiğinde onunla çatışır. Düzeltme daima
   **veriyi düzeltmek**tir, sayıyı değil.
3. **Benzer plaka eşleştirme.** Çıkışta birebir eşleşme yoksa, 1
   karakter farkla eşleşen açık geçiş aranır ve eşleşirse o kapatılır
   (kayıt "düzeltildi" işaretiyle). Bu, OCR'ın en sık hatasını
   (karakter karışması) sessizce toparlar.

---

## 4. Sayaç tasarımı — sorulan kararlar

**Gece yarısı / vardiya başında sıfırlama olmalı mı? → HAYIR, ve bu
önemli bir karar.**

Doluluk bir **durum**dur, bir **sayaç** değil: "şu anda içeride kaç araç
var". Gece yarısı sıfırlamak, içeride duran araçları yok saymak olur ve
sabah 08:00'de otopark doluyken "0 araç" gösterir. Vardiya başında
sıfırlamak daha da kötüsü: bir vardiyanın işaretlediği girişler diğer
vardiyada kaybolur.

Doğru araç sıfırlama değil **bayat geçiş süpürme**dir (yukarıda): 24
saattir açık kalan bir geçiş, büyük olasılıkla kaçırılmış bir çıkıştır
ve kapatılmalıdır. Bu, sıfırlamanın çözmeye çalıştığı sorunu, doğru
kayıtları silmeden çözer.

**Kritik seviyede bildirim gitsin mi? → EVET ama YÖNETİME, sakine
DEĞİL.**

- Yönetime "otopark %95 dolu" bildirimi işe yarar: misafir yönlendirmesi,
  ikinci kapının açılması gibi bir karar doğurur.
- Sakine göndermek **istenmeyen bildirim** olur: sakin otoparka
  gelmiyorsa bilgi gürültüdür, geliyorsa zaten uygulamada boş yer
  sayısını görüyor. Push bildirimi "kullanıcının o an bir şey yapması
  gereken" durumlar içindir.
- Eşik **tesis ayarı** olmalı (öneri varsayılan %90) ve bildirim
  **tekrarlanmamalı**: bir kez gönderilip doluluk eşiğin altına inene
  kadar susmalı. Aksi halde yoğun saatte dakika başı bildirim gider.

---

## 5. Önerim — hangi yol

**Aşama 1 (şimdi, yapıldı):** elle işaretlenen sayaç. Kapasite girilir,
yönetici/güvenlik giriş-çıkış işaretler, sakin boş yer görür.

**Aşama 2 (öneri):** **(a) kamera içi ANPR**, tek kapıda, tek kamerayla
pilot. Gerekçe:
- sunucuya **sıfır** CPU yükü getirir — mevcut sunucunun kaç kamera
  kaldıracağı sorusu tamamen ortadan kalkar,
- okuma kalitesi, genel amaçlı bir kameradan alınan görüntüyü sonradan
  işlemekten belirgin şekilde iyidir (kamera ANPR için pozlama/shutter
  ayarlarını kendisi yapar),
- bizim tarafta yazılacak tek şey bir **webhook ucu**dur; bu uç (c)
  yoluna geçilirse de aynen kullanılır.

**(c) sunucuda yazılım** ikinci tercihtir ve ancak ANPR'li kamera
bütçesi yoksa anlamlıdır; o durumda da **yalnız yerel işleme** ve
**tetiklemeli** çalışma şarttır.

**(b) NVR** en zayıf seçenek: lisans maliyeti (a)'ya yaklaşır ama
esnekliği düşüktür ve NVR modeline kilitler.

**Pilot ölçütü:** tek kapıda bir hafta. Ölçülecek: okunan/okunmayan geçiş
oranı, yanlış okuma oranı, bayat geçiş sayısı. Bu sayılar görülmeden
ikinci kapıya geçilmemeli.

---

## 6. Onay bekleyen sorular

1. Aşama 2 için **(a) kamera içi ANPR** yolunu onaylıyor musunuz?
2. Plaka saklama **30 gün** + istatistik süresiz (plakasız) kabul mü?
3. Bayat geçiş süpürme eşiği **24 saat** (tesis ayarı) uygun mu?
4. Kritik doluluk bildirimi **yalnız yönetime**, varsayılan eşik **%90** —
   onaylıyor musunuz?
