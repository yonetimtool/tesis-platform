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
