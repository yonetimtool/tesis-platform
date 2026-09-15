# P235 — vardiya modalı birleştirme + mobil paket + Cloudflare adımları

---

## §1 — Vardiya ekleme: web'de iki ekran vardı

### Ölçüm

**Web'de iki ayrı giriş, iki ayrı bileşen:**

| Düğme | `data-test` | Açtığı | Ne yapıyor |
|---|---|---|---|
| Üstte "Vardiya ekle" | `vardiya-yeni` | `page.tsx` içindeki `<Modal>` (1025–1183) | kişi → **başlangıç/bitiş tarihi** → saatler → not. Takvim YOK, çok grup YOK |
| Altta "Kalıp uygula" | `vardiya-kalip-ac` | `components/vardiya/kalip-modali.tsx` (586 satır) | takvimden gün seçilmiş olmalı; kalıp (dilimler) + dilim başına personel + rotasyon |

**Mobilde tek akış** (`_HizliEkleDialogu`, `vardiya_plani_screen.dart`):

1. personel (açılır liste)
2. **`GunTakvimi`** — günler takvimden seçilir
3. seçili gün sayısı + "seçimi temizle"
4. başlangıç/bitiş **tarihi** — takvim boşken çalışan aralık kipi
5. başlangıç/bitiş **saati**
6. not
7. **"Gruba ekle"** (P232 çok gruplu yapı: "pazartesi gündüz, salı-çarşamba gece")
8. önizleme (kaç vardiya oluşacak) → gönder

Yani mobilde **takvim + çok grup** var, web'in üst modalında **ikisi de
yok**. Kullanıcının gördüğü fark tam olarak buydu.

### Yapılan: web mobile eşitlendi, TEK modal

`components/vardiya/vardiya-ekle-modali.tsx` yazıldı; **iki düğme de onu
açıyor**. Akış mobildekiyle aynı sırada:

1. **takvim** (modalın içinde, ay ızgarası) → günler
2. seçili gün sayısı + "seçimi temizle"
3. **kalıp**: "Serbest saat" (varsayılan) ya da kayıtlı kalıp
4. serbest saatte kişi + başlangıç/bitiş **saati**; kalıpta **dilim başına** kişi
5. tarih aralığı (takvim boşken — mobildeki fallback'in aynısı)
6. **"Bu grubu ekle"** → biriken gruplar (P232)
7. rotasyon · not
8. önizleme → gönder (çakışma akışı)

**İki gönderim yolu, mobildekinin aynısı:** grup yoksa ve kalıp
seçilmemişse `/toplu` (tekil kip), aksi hâlde `/kalip-uygula` (çok
gruplu). İkisi de yaşıyor — birini kapatmak **yayındaki mobil sürümleri
kırardı**.

### Silinen ölü kod

| Ne | Satır |
|---|---|
| `components/vardiya/kalip-modali.tsx` | **586 → silindi** |
| `page.tsx` içindeki `HizliEkle` fonksiyonu | **~240 → silindi** |
| `page.tsx` toplam | 1185 → **946** |

### Kalıp ve rotasyon KAYBOLMADI

`kalip-modali.tsx`in iki yeteneği yeni modala **taşındı**: kayıtlı kalıp
(gün içinde birden çok dilim) ve rotasyon (haftalık kaydırma). Bunları
atmak "birleştirme" değil **özellik silme** olurdu; istek ekranların
birleşmesiydi.

### Ölçüm sırasında çıkan iki gerçek kusur

1. **Şerit seçimi modala hiç aktarılmıyordu.** Başlangıç değerini
   `useState(() => new Set(prop))` ile vermiştim; modal sayfada **hep
   monteli** duruyor (`acik` bir prop), yani o başlatıcı yalnız bir kez —
   modal kapalıyken ve prop boşken — çalışıyordu. Kullanıcı çizelgede
   günleri işaretleyip "Kalıp uygula"ya basınca modal **boş** açılırdı.
   `acik` kenarında çalışan bir efekte taşındı.
2. **"Geri al" düğmesi hiç çıkmıyordu.** Birleştirmede `onUygulandi →
   setSonParti` geri çağrısını düşürmüşüm. Otuz günlük yanlış planı tek
   tek silmemek isteğin kritik şartıydı; `onParti` olarak geri kondu.

İkisini de testler yakaladı.

### Parite durumu — açıkça

| Yetenek | Web | Mobil |
|---|---|---|
| Takvimden gün seçimi | ✅ | ✅ |
| Aralık kipi (bas/son tarih) | ✅ | ✅ |
| Çok gruplu plan (P232) | ✅ | ✅ |
| Önizleme + çakışma akışı | ✅ | ✅ |
| Kayıtlı kalıp (çok dilim) | ✅ | ❌ |
| Rotasyon (haftalık) | ✅ | ❌ |

**Son iki satır ÖNCEDEN VAR OLAN bir boşluk** — bu tur üretmedi, çünkü o
iki yetenek zaten yalnız web'deki `kalip-modali.tsx`teydi. Bu turda
istenen şey web'deki **iki ekranın birleşmesiydi** ve o yapıldı; mobile
kalıp/rotasyon eklemek ayrı bir iştir ve **yapılmadı** olarak
bildiriyorum.
