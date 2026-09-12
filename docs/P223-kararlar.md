# P223 — Kamera görüntüleme, otopark/plaka, rapor görselleştirme

Tarih: 2026-09-11

---

## §1 — Ana sayfada kamera karesi

### Ölçüm (tahmin değil, akış sürüldü)

Dev backend'de `yonetici@acme.com` ile gerçek akış sürüldü:

```
PATCH /cameras/{id} {"ana_ekranda": true}   -> 200, ana_ekranda: true
GET   /cameras?ana_ekranda=true&limit=10    -> meta.total: 1, items: ["Ana Kapı"]
GET   /cameras/{id}/kare                    -> 200 image/jpeg, 12 461 bayt
```

**Backend uçtan uca çalışıyor.** İşaret kaydediliyor, süzgeç süzüyor,
kare geliyor. Panonun attığı isteğin birebir aynısı denendi.

Veritabanı sayımı:

```
toplam kamera: 6 · aktif: 5 · ana_ekranda: 0
```

**Kök neden: işaretli kamera yok ve bu SESSİZ.**

| Yüzey | Kod | Davranış |
|---|---|---|
| Web | `components/KameraSeridi.tsx:81` → `if (gorunen.length === 0) return null;` | bölüm **hiç çizilmez** |
| Mobil | `yonetici_home_screen.dart:227` → `if (kameralar.isNotEmpty)` | bölüm **hiç çizilmez** |

Kullanıcının gördüğü: Kameralar sekmesinde kareler var (o sayfa **tüm**
kameraları çeker), ana sayfada hiçbir şey yok ve **neden olduğunu
söyleyen tek bir satır bile yok**. P217'nin dersi burada tekrarlanmış:
sıfır sonuç sessizce yutulmuş.

### İkinci bulgu — mobilde işaret KONULAMIYOR

`kamera_form_sheet.dart` `aktif` ve `sakinGorebilir` anahtarlarını
taşıyor ama **`anaEkranda` anahtarı yok**; `CameraDraft.toUpdateJson()`
da `ana_ekranda` göndermiyor. Yani mobilden yöneten bir kullanıcı bu
özelliği **hiç açamıyor** — ana ekranında neden kare olmadığını
anlamasının yolu da yok.

P213 §4'te bayrak backend + okuma tarafında yapılmış, **yazma tarafı
yalnız web'e konmuş**. Parite kuralı gereği açıkça yazıyorum: bu
turda kapatılıyor.

### Karar

1. **Boş hal artık sessiz değil.** İşaretli kamera yokken bölüm
   gizlenmiyor; "ana ekranda gösterilecek kamera seçilmedi" deniyor ve
   Kameralar sayfasına bağlantı veriliyor.
2. **Yalnız yönetim rolüne.** Sakine bu mesajı göstermek anlamsız
   olurdu: işareti koyamaz, yapabileceği bir şey yok. Sakinde eski
   davranış (bölüm gizli) sürüyor.
3. **Tesiste hiç kamera yoksa** mesaj farklı: "seçilmedi" demek yanlış
   yönlendirme olurdu.
4. **Mobile `anaEkranda` anahtarı eklendi** — web'deki kutunun karşılığı.
