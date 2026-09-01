# Mobilde yönetici: ne yapabilir, ne yapamaz

Kaynak: `mobile/lib/src/features/home/domain/home_menu.dart`
(`case UserRole.yonetici`) + ekran kodları. Web menüsü:
`admin-web/lib/menu.ts`.

---

## A) Mobilde YAPABİLDİKLERİ

Yönetici menüsünde **27 modül** var. İşlevine göre:

### İletişim
| Ekran | Ne yapabilir |
|---|---|
| Duyurular | Okur **ve oluşturur** |
| Etkinlikler | Görür, yönetir |
| Anketler | Görür, açar |
| Site kuralları | Görür, yazar |
| Talepler (şikâyet/arıza) | Listeler, durum değiştirir |
| Şikâyet haritası | Bina üzerinde yoğunluk görür |
| Dış hizmetler | Görür **ve yazar** (`canWrite` yönetici/admin) |

### Saha ve güvenlik
| Ekran | Ne yapabilir |
|---|---|
| Devriye takibi | **Salt izleme** — bugünün pencereleri + geçmiş |
| Devriye planları | Tanımlar |
| Kontrol noktaları (NFC) | Tanımlar |
| Görev takibi | `?gorunum=yonetim` — takip eder |
| Vardiyalar | Görür **ve yazar** |
| İhlaller | Görür |
| Otopark | Doluluk görür |
| Kameralar | Ana ekran şeridinden + Ayarlar'dan yönetir |
| Bildirimler | Görür |

> Yönetici **tur okutmaz, zimmet vermez, kuyruk işlemez** — bunlar saha
> rollerinin kanıt üreten işleri ve menüde bilinçli olarak gizli.

### Yapı ve tanımlar
| Ekran | Ne yapabilir |
|---|---|
| Bina düzenleme | Blok/daire düzenler (saha rollerinde salt-okuma) |
| Daire tanımları | Tip/grup tanımlar |
| Görev kategorileri | Tanımlar |
| Daire erişimi (sakin-daire bağı) | Görür, atar |
| Rezervasyon | Görür, yönetir |

### Kişiler
| Ekran | Ne yapabilir |
|---|---|
| Sakinler | Listeler, ekler |
| Personel | Listeler, ekler |

### Finans (yalnız **okuma**)
| Ekran | Ne yapabilir |
|---|---|
| Bütçe | Özet **görür** |
| Finansal özet | **Görür** |
| Şeffaflık | **Görür** |
| Raporlar | **Görür** |

### Kurulum ve ayarlar
| Ekran | Ne yapabilir |
|---|---|
| Kurulum sihirbazı | Adımları görür, ekranlara gider |
| Entegrasyonlar | Görür/yönetir |
| Ayarlar → **Tesis adı** | Değiştirir (`PATCH /tenant/settings {ad}`) |
| Ayarlar → Kameralar | Yönetir |
| Ayarlar → dil, tema, bildirim kanalları, KVKK, hesap silme | Kendi hesabı |
| Profil | Kendi bilgileri |

---

## B) Web'de OLUP mobilde OLMAYAN yönetici işlevleri

Karar sizin; liste bilgi içindir.

### Finans yazma — **en büyük boşluk**
Mobilde finans **tamamen salt okunur**. Web'de yöneticinin şu 18 ekranı
var, mobilde **hiçbiri** yok:

- Aidat / borçlandırmalar (tekil + toplu tahakkuk)
- **Tahsilat girişi** — mobilde tahsilat işlenemiyor
- Gider, gelir, virman, iade, açılış fişi
- Kasalar (tanım)
- Banka entegrasyonu (ekstre yükleme, eşleştirme)
- Aidat otomasyonu, borçlular, bütçe hedefleri
- İcra dosyaları
- Sayaç okuma
- Gecikme faizi

### Kullanıcı yönetimi
- **Kullanıcılar** ekranı (rol değiştirme, e-posta düzenleme, silme,
  davet yeniden gönderme, **ödeme kodları**, bildirim tanılama) — mobilde
  yalnız "Sakinler" ve "Personel" listeleri var, tam CRUD yok.
- **Davetler** ekranı yok.
- **Excel içe aktarım** yok.

### Tesis ayarları
- Mobilde yalnız **tesis adı** değiştirilebiliyor. Web'deki
  **Tesis ayarları** ekranının geri kalanı (adres, konum, otopark
  kapasitesi, gürültü eşiği, tur alarmı, okutma mesafesi, rezervasyon
  geçmişi) mobilde **yok**.

### Yönetişim / belge
- Karar defteri, Doküman arşivi, KVKK metinleri, Gürültü uyarıları,
  Denetim kaydı (audit), Yetki matrisi — mobilde yok.

### İletişim
- **SMS/E-posta yönetimi** (şablonlar, gönderim, sağlayıcı ayarları) yok.
- Toplu mesaj gönderme yok.

### Diğer
- Ziyaretçi/kargo/araç geçişi kayıtları yönetici menüsünde yok
  (sakin ve güvenlik menülerinde var).
- Demirbaş (assets) yönetici menüsünde yok (saha menüsünde var).
- Rapor motoru (özel rapor kurma) yok — yalnız hazır raporlar.

---

## C) Değerlendirme (karar sizin)

Mobilin bugünkü şekli tutarlı bir üründür: **sahada bakılan** işler
mobilde, **masabaşı** işler web'de. Ama iki nokta bu ayrımı zorluyor:

1. **Tahsilat girişi.** Kapıda elden aidat alan bir yönetici için en
   doğal mobil iş bu ve yok. (Bugün web'de bile gider oluşturma
   platform yöneticisinde — bkz. P193 §3 açık maddesi.)
2. **Kullanıcı ekleme/davet.** Yeni sakin taşındığında yönetici
   telefonundan ekleyip davet gönderemiyor.

Geri kalanların mobilde olmaması savunulabilir: banka ekstresi yükleme,
Excel aktarımı, denetim kaydı incelemesi ve rapor motoru gerçekten
masabaşı işleridir.
