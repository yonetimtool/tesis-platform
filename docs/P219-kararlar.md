# P219 — Tesis ayarları sadeleştirme + şikâyet haritası saklama süresi

---

## §1 — Ayarları anlaşılır hâle getirme

### Somut örneğin ölçümü: eskalasyon eşiği

Şikâyetiniz **birebir doğrulandı**. Kod `asama > esik` diye bakıyordu:

```
ayar=1 -> İLK eskalasyon 2. uyarıda
ayar=2 -> İLK eskalasyon 3. uyarıda
ayar=3 -> İLK eskalasyon 4. uyarıda
```

Yani ekranda **"1" yazan alan aslında "2. uyarıda"** demekti. İpucu bunu
bir dipnotla telafi etmeye çalışıyordu (*"1 = ikinci kez eşiğe
ulaşıldığında"*). **Bir ayarın anlamını dipnotla düzeltmek, ayarın
kendisinin yanlış olduğunu kabul etmektir.**

**Karar: değeri anlama eşitle** (göç 0111). Ayar artık doğrudan
*"kaçıncı uyarıda güvenliğe bildirilsin"* ve kod `asama >= esik`:

```
ayar=2 -> 2. uyarıda   (eski 1'in davranışı)
ayar=1 -> İLK uyarıda  (yeni: eski semantikte İFADE EDİLEMİYORDU)
```

**Alternatif reddedildi:** etiketi değiştirip değeri korumak. Alana "1"
yazıp ekranda "2. uyarı" görmek aynı karışıklığı sürdürürdü.

**Göç mevcut davranışı birebir korur:** her tesisin değeri +1 (10'da
durur — şema üst sınırı 10 ve 10. aşamaya ulaşan daire zaten çok önce
eskale olmuştur). Ölçüldü: **2217 tesisin hepsi 1 → 2**, ikisi de "2.
uyarıda" demek.

### Etiketler: teknikten sonuç odaklıya

| önce | sonra |
|---|---|
| Tur gecikme toleransı (dk) | Tur başlamazsa kaç dakika sonra uyarılsın |
| Alarm tekrar sayısı | Alarm kaç kez tekrarlansın |
| Okutma mesafe eşiği (m) | Okutma en fazla kaç metre uzaktan yapılabilsin |
| Güvenlik yönetimi | Vardiya ve turları kim planlasın |
| Gürültü uyarı eşiği | Kaç şikâyet birikince daireye uyarı gitsin |
| Gürültü sayım penceresi (gün) | Şikâyetler kaç gün geriye kadar sayılsın |
| Uyarı sonrası susma süresi (gün) | Uyarıdan sonra kaç gün yeniden uyarılmasın |
| **Güvenliğe eskalasyon eşiği** | **Kaçıncı uyarıda güvenliğe bildirilsin** |
| Vardiya hatırlatma (dakika) | Vardiyadan kaç dakika önce hatırlatılsın |
| Vardiyaya başlamama uyarısı (dakika) | Vardiyaya başlanmazsa kaç dakika sonra uyarılsın |
| Rezervasyon geçmişi (ay) | Geçmiş rezervasyonlar kaç ay geriye görünsün |

**İlke:** etiket bir **soru** oldu ve birimi kendi içinde taşıyor.
"(dk)" gibi parantezli birimler yerine "kaç dakika" — kullanıcı alanı
doldururken ne yazacağını etiketten okuyor.

**Açıklamalar** *ne olacağını* söylüyor, *nasıl çalıştığını* değil.
Örnek: "Aralıklar katlanır: tolerans, 2×, 4×" → "Her tekrar bir
öncekinin iki katı kadar bekler."

### Ayarlar gruplandı

15 ayar tek sütunda diziliydi ve aralarında bağlantı yoktu — devriye
toleransı, gürültü susma süresi ve borç hedefi arka arkaya. Beş grup:

**Devriye ve turlar** (4) · **Vardiya ve güvenlik** (3) · **Gürültü
şikâyetleri** (6) · **Aidat ve giderler** (1) · **Rezervasyon** (1)

Gruplama **işleve** göre: kullanıcının "neyi ayarlamak istiyorum"
sorusuna karşılık geliyor. Boş grup çizilmiyor (rolün göremediği ayarlar
elendiğinde başlık ortada kalmasın).

### Sayaç penceresi ↔ harita süresi karışıklığı

İkisi **farklı şeyler** ve ikisi de "Gürültü şikâyetleri" grubunda yan
yana duruyor. Sayım penceresi açıklamasına açık bir ayrım cümlesi
eklendi: *"(Haritada görünme süresiyle karıştırmayın — o ayrı bir
ayardır.)"* Bu, testle de kilitli.

### Çakışan/anlamsız ayar taraması

Tek tek inceledim; **kaldırılması gereken ayar çıkmadı**. Bulduklarım:

1. **Eskalasyon eşiği** — değer/anlam ayrışması. **Düzeltildi** (yukarıda).
2. **`guvenlik_modu`** etiketi ("Güvenlik yönetimi") neyin
   ayarlandığını söylemiyordu. **Yeniden yazıldı.**
3. **`tur_alarm_tekrar_sayisi`** açıklaması uygulama ayrıntısı
   veriyordu. **Sonuç diline çevrildi.**
4. **Yanlış alarm:** ilk taramamda `gurultu_uyari_metni` alanının metin
   olmasına rağmen `min: 0, max: 365` taşıdığını sanmıştım — düzeltmeye
   giderken kaynağa baktım, öyle değildi; regex'im bir sonraki bloğun
   sınırlarını o alana yapıştırmış. **Kodda böyle bir kusur yok.**

**Kaldırmadım hiçbir ayarı:** on beşinin de bir karşılığı var ve
kullanılmayan bir ayar bulamadım. Kaldırma, çalışan bir davranışı
sessizce değiştirmek olurdu.

### Ölçüm

`p219-ayar-anlasilirlik.test.ts` (10): her ayarın bir grubu var,
tanımsız/boş grup yok, **7 dilde** etiket ve açıklama var, açıklamasız
ayar yok, sayı alanlarının etiketinde birim/soru var, açıklamalar
yeterince somut, eskalasyon etiketi "kaçıncı uyarı" diye soruyor,
açıklaması güvenlik+polis+örnek içeriyor, sayım penceresi açıklaması
harita süresine değiniyor.

Backend `test_p212` +2: `esigi=2` → **ikinci** uyarıda eskale (eskiden
üçüncüde), `esigi=1` → **ilk** uyarıda (eski semantikte ifade
edilemiyordu). Mevcut P212/P213 testleri yeni anlama göre güncellendi.

**Bir metnin "anlaşılır" olduğunu test edemem** — ölçtüğüm şey yapısal
eksikler (birimsiz sayı, grupsuz ayar, açıklamasız alan) ve kusur tam
olarak orada başlamıştı.

---

## §2 — Şikâyet haritasında saklama süresi

### Neden

Şikâyetler haritada **süresiz** kalıyordu: altı ay önce çözülmüş bir
gürültü şikâyeti, dün gece gelenle aynı kırmızı noktayı üretiyordu.
Harita *"şu anda nerede sorun var"* sorusunu yanıtlaması gerekirken
*"hiç olmuş mu"* sorusunu yanıtlıyor ve zamanla her daire kırmızıya
dönüyordu.

### Bu bir görünürlük filtresi, veri silme değil

`tenant.sikayet_harita_saat` (göç 0112, varsayılan **24 saat**).
Etkilenmeyenler — hepsi testle ölçülüyor:

| | etkileniyor mu |
|---|---|
| Harita (`/density` ve `/building-map`) | **evet** — filtrelenir |
| Şikâyet kaydının kendisi | hayır — **silinmez** |
| Eşik sayaçları (P208/P209/P212) | hayır — **kendi penceresi var** |
| Şikâyet listeleri, raporlar, denetim kaydı | hayır |
| Sakinin kendi şikâyetleri | hayır |

**İki uç birden filtrelendi.** `/density` (yoğunluk) ve
`/building-map` (bina şeması) **aynı haritayı** besliyor; birinde
filtreleyip ötekinde filtrelememek aynı ekranda iki farklı sayı
göstermek olurdu.

**"Sil" kelimesi hiçbir yerde geçmiyor** — ne kodda ne arayüzde.
Açıklama "SİLİNMEZ" diyor ve neyin etkilenmediğini tek tek sayıyor. Bu
da testle kilitli.

### `0` = süresiz göster — evet, kapatılabilir olmalı

**Gerekçe:** haftada bir şikâyet gelen küçük bir sitede 24 saatlik
pencere haritayı sürekli boş gösterir ve harita işlevini yitirir.
Yönetici süresiz görmeyi tercih edebilmeli.

`0` değeri üründe zaten "sınırsız" anlamında kullanılıyor
(`gurultu_pencere_gun`, `rezervasyon_gecmis_ay`) — aynı kavrama aynı
değeri vermek, yöneticinin öğrenmesi gereken kural sayısını artırmıyor.

**Üst sınır 8760 saat (bir yıl):** daha uzunu "süresiz"in kendisidir ve
`0` onu zaten ifade ediyor.

### İki süre karıştırılmasın

| ayar | birim | ne yapar |
|---|---|---|
| Şikâyetler kaç gün geriye kadar sayılsın | **gün** (30) | **eşik mantığı** — uyarı ne zaman tetiklenir |
| Şikâyetler haritada kaç saat görünsün | **saat** (24) | **görünürlük** — haritada ne kadar durur |

İkisi de "Gürültü şikâyetleri" grubunda **yan yana** duruyor (bilinçli:
yönetici farkı bir arada görsün) ve **açıklamaları birbirine gönderme
yapıyor**.

### Ölçüm — istediğiniz akış uçtan uca sürüldü

`test_p219_harita_penceresi.py` (7):

1. Şikâyet açıldı → **haritada göründü** (hem `/density` hem
   `/building-map`: 1).
2. Şikâyet 30 saat öncesine alındı → **haritadan kayboldu** (ikisi de 0).
3. **Kayıt duruyor:** şikâyet listesinde hâlâ var, `durum = acik`.
4. **Süre uzatılınca yeniden göründü** — silinseydi bu mümkün olmazdı.
5. `0` ile üç ay önceki şikâyet bile görünüyor.
6. **Eşik sayacı etkilenmiyor:** 30 günlük pencerede sayı hâlâ 1;
   `acik_gurultu_sayisi` imzasında `pencere_gun` var ve kaynağında
   "harita" geçmiyor.
7. Sakinin kendi şikâyeti görünmeye devam ediyor.

Kilit kırılarak doğrulandı: filtreyi devre dışı bırakınca 4 test düştü.

**Ölçüm kurulurken üç gerçek kural öğrendim** (ve testler bunlara
uyarlandı): sakin yalnız **kendi bloğundaki** daireleri şikâyet
edebiliyor; `world` fixture'ı sakini hiçbir daireye bağlamıyor (test
kendi ön koşulunu kuruyor); bina şeması ucu `/unit-complaints/building-map`
ve yerleşimsiz daireler `unplaced` kovasında duruyor.
