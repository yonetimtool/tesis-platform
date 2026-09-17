# P240 — PANİK BUTONU + DİYAFON + AKILLI EV + üç düzeltme

Sıra: §5 → §1 → §4 → §2 → §3 (kullanıcının verdiği sıra).

---

## §5 — Üç küçük düzeltme

### (a) "Yeni vardiya" düğmesi görünmüyordu

**Ölçüm:** düğme görünüm seçici + filtreler + tazele ile **aynı
sarılabilir satırdaydı** ve hepsi `ikincil` (gri) olduğu için aralarında
kayboluyordu; dar ekranda alt satıra sarıyor ve hiç görünmüyordu.

**Karar — iki şey birden değişti, ikisi de gerekli:**
- **Yer:** gezinme/görüntüleme araçlarıyla aynı kümede değil. Bu bir
  *görünüm seçimi* değil, *kayıt oluşturma*. Artık başlık satırının
  sağında, tarih gezinme kümesinin sonunda.
- **Renk:** `birincil` (mavi dolgu, `--yz-metal-accent`). Bir ekranda tek
  birincil düğme olur; o da budur. Yanındaki araçlar gri **kaldı** —
  "hepsini mavi yap" değil, birini öne çıkar.

Şablon bölümünün "Yeni şablon" düğmesi de birincil, ama sayfanın
**altında**, kendi bölüm başlığının yanında; ikisi aynı ekran alanında
yan yana görünmüyor. P239 §2'de etiketleri ayırmıştık, artık görsel
ağırlık da ayrı.

### (b) Mobil devriye planında vardiya alanı — **ZATEN VAR**

P239 §3'te (`2775f2e5`) eklenmişti: `devriye-vardiya` seçici,
`patrol_plan_api`de `shiftId` alanı, taklit HTTP adapter üzerinden beş
kilit. Bu turda **tekrar yapılmadı**; doğrulandı.

### (c) Görev tarihi takvimden — ve iki ekran AYNI takvime eşitlendi

**Ölçüm: web'de gün seçimi iki farklı şekilde yapılıyordu.**

| Yer | Nasıl |
|---|---|
| Vardiya ekleme modalı | elde çizilmiş gün şeridi — sarılabilir düğme yığını, **haftaya hizalı değil**, hücre 36px |
| Görev formu | `<input type="datetime-local">` — **tarayıcının kendi takvimi**, her tarayıcıda başka görüntü |

Mobildeki `GunTakvimi` ise bir **ay ızgarası** (7 sütun, haftaya hizalı).
Yani "mobildeki gibi" olan hiçbiri değildi.

**Karar:** ortak `admin-web/components/ui/ay-takvimi.tsx` (`AyTakvimi`).
Her iki yer de onu kullanıyor.
- **Hafta pazartesi başlar (ISO-8601)** — P239 §4'te devriye günleri için
  seçilen numaralandırmayla aynı; "pazartesi" iki ekranda aynı sütuna
  denk gelsin.
- **Gün adları sözlükten değil yerelden** (`Intl.DateTimeFormat`):
  7×7 = 49 yeni anahtar eklemek yerine (mobildeki `gun_takvimi.dart` ile
  aynı karar).
- **Hücre 44px** (2.75rem) — tasarım sisteminin dokunma hedefi. Eski
  şerit 36px'ti; o bir dokunma hedefi değil, yoğun-bağlam ölçüsü.
- **Ay gezinme** görev formunda var (ileri/geri). Düzenlemede takvim
  **görevin ayına atlar**; atlamazsa başka aydaki son tarih için takvim
  boş görünür ve kullanıcı "tarih silinmiş" sanır.
- **Gün + saat ayrı.** Gün tek başına yetmez. **Saat verilmezse gün sonu
  (23:59)** — "tarih verdim ama saat vermedim" = "o günün sonuna kadar";
  00:00 almak işi daha başlamadan gecikmiş yapardı.
- **Aynı güne ikinci tıklama seçimi kaldırır** — son tarihi silmenin
  başka yolu yok.
- **Geçmiş gün seçilebilir** kalır: kapatmak, dün bitmesi gereken bir işi
  sisteme girmeyi imkânsız kılardı (gecikme raporu tam bunun için var).

### KİLİTLER

`admin-web/tests/p240-kucuk-duzeltmeler.dom.test.ts` (5) — düğme birincil
ve komşuları hâlâ ikincil, gezinme kümesinin dışında; görev formunda ay
ızgarası var ve eski `datetime-local` **kalmadı**; vardiya modalı ile
görev formu aynı bileşeni kullanıyor (7 sütunlu ızgara imzası); geçmiş
gün kapalı değil.
`p239-gorev-son-tarih.dom.test.ts` yeni etkileşime göre yeniden
yazıldı (+2 test: gün sonu kuralı, ikinci tıklamayla silme).

**KIRMA:** düğme `ikincil`e çevrildi → 1 kırmızı. Geri alındı.

**Testin kendi hatası düzeltildi:** ilk yazımda ISO dizesinde
`"2026-09-20"` aranıyordu; test ortamının saat dilimi UTC-4 olduğu için
yerel 23:59 **ertesi günün** UTC damgası oluyor ve test kırmızı döndü —
doğru olarak. Ölçüm, değerin **yerel** olarak 20 Eylül 23:59'a denk
gelmesine çevrildi. (P239'daki 17:30 bu tuzağı gizlemişti.)
