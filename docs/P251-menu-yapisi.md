# P251 §8 — Web/mobil menü yapısı: ölçüm ve öneri (ONAY BEKLİYOR)

Bu belge **kod değiştirmeden** yapılan ölçümün tablosu ve yeni bilgi
mimarisi önerisidir. Uygulama onaydan sonra yapılacak.

Kaynaklar: `admin-web/lib/menu.ts`, `admin-web/lib/yuzey.ts`, web sayfaları;
`mobile/lib/src/features/home/domain/home_menu.dart`, `home_drawer.dart`,
`app_router.dart`; sunucu rol kapıları (`require_role`, `roller.py`).
Satır numaraları ölçüm anındaki HEAD'e göredir (4b8c29aa).

---

## ADIM 1 — Ölçüm tablosu

Kısaltmalar: **T** = tek tek ekleme, **X** = toplu (Excel), **D** = düzenleme,
**S** = silme. "w / m" = web / mobil.

| İşlem | Web'de yeri | Mobilde yeri | T (w/m) | X (w/m) | D (w/m) | S (w/m) | Rol (sunucu) |
|---|---|---|---|---|---|---|---|
| **Sakin** | Yönetim › Kullanıcılar (ekle/düzenle) + Yönetim › Sakinler (liste + sil) + Tanımlar › İçe aktarım | Tanımlar › Site Sakinleri | ✓ / ✓ | ✓ / — | ✓ / ✓ | ✓ / ✓ | admin, yönetici |
| **Saha personeli hesabı** (güvenlik, tesis görevlisi) | Yönetim › Kullanıcılar | Tanımlar › Saha Personeli | ✓ / ✓ | — / — | ✓ / ✓ | ✓ / yalnız pasifleştir | admin, yönetici, güvenlik amiri (yalnız güvenlik) |
| **Güvenlik amiri** | Yönetim › Kullanıcılar | Tanımlar › Saha Personeli (koşullu) | ✓ / koşullu | — | ✓ / ✓ | ✓ / pasifleştir | admin, yönetici |
| **Yönetici** | Yönetim › Kullanıcılar; Platform › Tesisler | **yok** | ✓ / — | — | ✓ / — | ✓ / — | admin, yönetici |
| **Denetçi** | Yönetim › Kullanıcılar (özel form) | **yok** | ✓ / — | — | ✓ / — | ✓ / — | admin, yönetici |
| **Personel kaydı (maaş defteri, hesapsız)** | Tanımlar › "Personel" | **yok** | ✓ / — | — | ✓ / — | ✓ / — | admin, yönetici |
| **Davetler** | **İletişim** › Davetler | **Tanımlar** › Davetler | otomatik | — | yeniden gönder (her ikisi) | — | admin, yönetici |
| **Bloklar** | Tanımlar › **Bloklar** | Tanımlar › **Bina Yapısı** | ✓ / ✓ | — | ✓ / ✓ | ✓ / ✓ | admin, yönetici |
| **Daireler** | Tesis › Daireler (liste/düzenle/sil) + Tanımlar › Bloklar (oluşturma) + İçe aktarım | Tanımlar › Bina Yapısı | ✓ / ✓ | ✓ / — | ✓ / ✓ | ✓ / ✓ | admin, yönetici |
| **Daire tipleri / grupları** | Tanımlar › iki ayrı öğe | Tanımlar › tek "Daire Tipleri" | ✓ / ✓ | — | ✓ / ✓ | ✓ / ✓ | admin, yönetici |
| **Kasalar, gelir/gider grupları ve kalemleri, firmalar, sayaçlar, muhasebe ayarları** | Tanımlar › 8 ayrı öğe (`?defter=`) | **yok** | ✓ / — | açılış bakiyesi / — | ✓ / — | ✓ / — | admin, yönetici |
| **Araç kaydı (plaka sicili)** | Tanımlar › Araçlar + İçe aktarım | **yok** | ✓ / — | ✓ / — | ✓ / — | ✓ / — | admin, yönetici |
| **Görev kategorileri** | Tanımlar | Tanımlar | ✓ / ✓ | — | ✓ / **—** | ✓ / ✓ | admin, yönetici |
| **NFC noktaları** | Güvenlik › NFC Noktaları | menüde **yok** (Devriye Takibi ekranının içinde) | ✓ / ✓ | — | ✓ / ✓ | ✓ / ✓ | admin, yönetici/amir (moda göre) |
| **Devriye planları** | Güvenlik › Devriye Planları | menüde **yok** (Devriye Takibi içinde) | ✓ / ✓ | — | ✓ / ✓ | ✓ / ✓ | aynı |
| **Rezervasyon alanları** | Tesis › Rezervasyon yönetimi | Tesis › Rezervasyon | ✓ / ✓ | — | ✓ / ✓ | pasifleştir (her ikisi) | admin, yönetici |
| **Site kuralları** | **İletişim** › Kural yönetimi | **Tesis** › Site Kuralları | ✓ / ✓ | — | ✓ / ✓ | ✓ / ✓ | admin, yönetici |
| **Etkinlik yönetimi** | **İletişim** › Etkinlik yönetimi | **Tesis** › Etkinlikler | ✓ / ✓ | — | ✓ / ✓ | ✓ / ✓ | admin, yönetici |
| **Duyurular** | İletişim › Duyurular | İletişim › Duyurular | ✓ / ✓ | — | ✓ / ✓ | ✓ / ✓ | admin, yönetici |
| **Otomasyon (aidat planı, düzenli ödeme, hatırlatma)** | Finans › Otomasyon | menüde **yok** (Borçlular ekranının içinde) | ✓ / ✓ | — | aç/kapat, atla | ✓ / ✓ | admin, yönetici |
| **Aidat tahakkuku** | Finans › Aidat | **yok** | ✓ / — | — | — | — | admin, yönetici |
| **Entegrasyonlar** | **Yönetim** › Entegrasyonlar | **Tanımlar** › Entegrasyonlar | ✓ / ✓ | — | ✓ / ✓ | ✓ / ✓ | admin, yönetici |
| **Diyafon** | Entegrasyonlar sayfasının içinde | Tanımlar › Diyafon (ayrı öğe) | ✓ / ✓ | — | ✓ / **—** | **ikisinde de yok** (sunucuda var) | admin, yönetici |
| **Tesis ayarları** | Yönetim › Tesis ayarları (tüm alanlar) | Ayarlar › Tesis (yalnız ad) | — | — | tümü / yalnız ad | — | admin, yönetici |
| **Kurulum sihirbazı** | grup dışı, kenar çubuğunun altı | Tanımlar › Kurulum + Ayarlar › Yönetim (iki giriş) | — | — | adım atla (her ikisi) | — | admin, yönetici |

### Bulunan tutarsızlıklar

1. **"Personel" iki ayrı şeyin adı.** Web Tanımlar › Personel = maaş
   defteri (hesap açmaz); mobil "Saha Personeli" = giriş hesabı. Kurulum
   sihirbazının "personel" adımı sunucuda maaş defterini sayıyor; mobil
   bu adımı hesap ekranına yönlendiriyor → mobilde personel eklemek
   adımı **hiç tamamlamıyor**. (Kullanıcının "web'de yalnız Excel ile
   toplu ekleme var" gözlemi doğru değil: o sayfa tek tek kayıt ekliyor
   ama hesap değil maaş kaydı; Excel türü de yok. Karışıklığın kendisi
   ölçümün ana bulgusu.)
2. **Kişiler üç yerde:** web'de Kullanıcılar (herkesi ekler), Sakinler
   (liste + sil, ekleme yok), Personel (maaş defteri). Mobilde iki ekran
   (Saha Personeli, Site Sakinleri); yönetici/denetçi mobilde hiç açılamıyor.
3. **Aynı iş farklı grupta:** Davetler (İletişim ↔ Tanımlar), Site
   kuralları ve Etkinlikler (İletişim ↔ Tesis), Entegrasyonlar
   (Yönetim ↔ Tanımlar).
4. **Aynı iş farklı adla:** "Bloklar" ↔ "Bina Yapısı"; "Kural yönetimi" ↔
   "Site Kuralları"; daire tip/grupları web'de iki öğe, mobilde bir.
5. **Mobilde gizli yönetim girişleri:** NFC noktaları ve devriye planları
   (Devriye Takibi içinde), otomasyon (Borçlular içinde).
6. **Yalnız web:** muhasebe tanımları, Excel içe aktarım, aidat tahakkuku,
   tesis ayarlarının konum/otopark/eşik alanları, yönetici/denetçi hesabı.
7. **Eksik işlemler:** diyafon silme (iki yüzeyde de yok), diyafon ve görev
   kategorisi düzenleme mobilde yok, personel kalıcı silme mobilde yok.
8. **Menü ile yüzey çelişkisi:** web Yönetim grubundaki Denetim kaydı ve
   Yetki matrisi platform rotası; tesis yüzeyinde yöneticiye görünmüyor.

---

## ADIM 2 — Öneri

### İlkeler

1. **Aynı iş, aynı grup, aynı ad** — web ve mobilde birebir. Grup listesi
   iki yüzeyde aynı ve aynı sırada: **Güvenlik · Tesis · Finans · İletişim
   · Kişiler · Tanımlar · Yönetim**.
2. **Her işlem iki yüzeyde.** Yalnız bir yüzeyde kalanların gerekçesi
   yazılır ve öbür yüzeyde öğe **görünür kalır**: dokununca "Bu işlem
   bilgisayardan yapılır — app.yonetiyor.com" bilgisi ve bağlantı.
3. **Bir işin tek girişi olur;** başka ekranlardan oraya kısayol olabilir
   ama ikinci bir kopya olmaz.

### Karar: "Kişiler" TEK GİRİŞ, sekmeli

**Kişiler** = Sakinler · Personel · Yöneticiler ve denetçiler · Davetler.

Gerekçe:
* Hepsi aynı kayıt (`app_user`, rolü farklı); bugün kullanıcıyı "neyi
  nerede" sorusuna iten şey aynı kaydın üç sayfaya bölünmesi.
* Sekme, rolün kendi sütunlarını ve formunu korur (sakinde daire/malik-
  kiracı, personelde vardiya rolü, denetçide kapsam) — tek tablo her şeyi
  karıştırırdı, ayrı sayfalar ise bugünkü sorunu sürdürürdü.
* "Ekle" düğmesi bulunulan sekmenin rolüyle açılır (sakin sekmesinde
  sakin formu); rol seçimi yine mümkün ama varsayılan doğru.
* Davetler kişinin hesabının durumudur; Kişiler'in sekmesi olunca "davet
  gitti mi" sorusu kişinin yanında cevaplanır.
* Excel ile toplu ekleme Sakinler sekmesinin içinde ("Excel'den ekle");
  mobilde aynı düğme "bilgisayardan yapılır" der.

**Maaş defteri** ("Personel" adlı tanım) hesap değildir: adı **"Maaş
kartları"** olur ve **Finans** grubuna taşınır (giderin tanımıdır). Kurulum
sihirbazının "personel" adımı **hesabı** (saha personeli) sayacak şekilde
düzeltilir; maaş kartı isteğe bağlı finans adımı olur.

### Yeni web menüsü (tesis yüzeyi, yönetici)

* **Özet**
* **Güvenlik:** Acil durum çağrıları · Kameralar · Kamera kayıtları ·
  Devriye (takip · NFC noktaları · planlar — tek sayfa, sekmeli) · Vardiya
  planı · Araç geçişleri · Akıllı ev · Bildirimler
* **Tesis:** Daireler · Görevler · Bakım takibi · Demirbaş · Şikayet
  haritası · Rezervasyon yönetimi · Dış hizmetler · Yerel işletmeler
* **Finans:** Finans özeti · Aidat · Tahsilatlar · Giderler · Gelirler ·
  Borçlular · Otomasyon · Banka · Virman · İade · Açılış · Bütçe · Mesai ·
  Maaş kartları · İcra · Sayaç okuma · Raporlar
* **İletişim:** Duyurular · Site kuralları · Etkinlikler · Anketler ·
  Talepler · SMS/E-posta · Gürültü uyarıları
* **Kişiler:** Sakinler · Personel · Yöneticiler ve denetçiler · Davetler
  (tek sayfa, sekmeli)
* **Tanımlar:** Bina yapısı (bloklar ve daireler · daire tipleri · daire
  grupları) · Kasalar · Gelir/gider grupları · Gelir/gider kalemleri ·
  Firmalar · Sayaçlar · Görev kategorileri · Araçlar · Muhasebe ayarları ·
  İçe aktarım
* **Yönetim:** Tesis ayarları · Entegrasyonlar (diyafon sekmesi dahil) ·
  Kurulum sihirbazı · Şeffaflık · Karar defteri · Dokümanlar · KVKK

(§7 ile birlikte: Tanımlar'ın alt öğeleri kenar çubuğunda tek "Tanımlar"
girişine indirilir, sekmeler sayfanın içinde kalır — bkz. §7.)

### Yeni mobil menü (yönetici çekmecesi)

* **Güvenlik:** Acil durum çağrıları · Kamera kayıtları · Devriye (takip ·
  NFC noktaları · planlar) · Vardiya planı · Otopark · İhlaller ·
  Görüntüleme izni
* **Tesis:** Daireler · Görevler · Bakım takibi · Şikayet haritası ·
  Rezervasyon · Dış hizmetler · Yerel işletmeler · Akıllı ev
* **Finans:** Tahsilat · Gider kaydı · Borçlular · **Otomasyon** · Sayaç
  okuma · Bütçe · Finansal özet · Şeffaflık · Aylık raporlar ·
  *Maaş kartları, kasalar vb. → "bilgisayardan yapılır"*
* **İletişim:** Duyurular · **Site kuralları** · **Etkinlikler** ·
  Anketler · Talep / Arıza · Gürültü uyarıları
* **Kişiler:** Sakinler · Personel · Yöneticiler ve denetçiler ·
  Davetler (tek ekran, sekmeli)
* **Tanımlar:** Bina yapısı · Görev kategorileri · *Muhasebe tanımları,
  araçlar, içe aktarım → "bilgisayardan yapılır"*
* **Yönetim:** Tesis ayarları · Entegrasyonlar (diyafon dahil) · Kurulum
  sihirbazı

### Yalnız bir yüzeyde kalacaklar (gerekçe)

| İşlem | Yüzey | Gerekçe | Öbür yüzeyde |
|---|---|---|---|
| Excel içe aktarım | web | 200 satırlık önizlemeyi telefonda doğrulamak mümkün değil (P204) | öğe görünür, "bilgisayardan yapılır" |
| Muhasebe tanımları (kasa, gelir/gider, firma, sayaç, muhasebe ayarları), araçlar | web | çok sütunlu defterler; telefonda okunmaz ve yanlış girişin maliyeti yüksek | aynı |
| Aidat tahakkuku (toplu borçlandırma) | web | önizleme + dağıtım seçimi geniş tablo ister; otomasyon kuralı mobilde de var | aynı |
| Tesis konumu (harita üzerinde) | web | harita sürükle-bırak + adres arama; mobilde ad/iletişim alanları açılır | konum alanı "bilgisayardan" |

Mobile **eklenecek** (bugün yok): yönetici ve denetçi ekleme (Kişiler
sekmesi), diyafon düzenleme/silme, görev kategorisi düzenleme, tesis
ayarlarının metin alanları. İki yüzeye **eklenecek**: diyafon silme.

### Eski adres yönlendirmeleri (web)

| Eski | Yeni |
|---|---|
| `/users` | `/kisiler?sekme=hepsi` (rol süzgeci korunur) |
| `/residents` | `/kisiler?sekme=sakinler` |
| `/davetler` | `/kisiler?sekme=davetler` |
| `/tanimlar?defter=personel-kayitlari` | `/finans/maas-kartlari` |
| `/building-editor` | `/tanimlar?defter=bina` (Bina yapısı) |
| `/tanimlar?defter=unit-tipleri`, `unit-gruplari` | `/tanimlar?defter=bina&sekme=tipler` / `…=gruplar` |
| `/checkpoints`, `/patrol-plans` | `/devriye?sekme=noktalar` / `…=planlar` |
| `/site-kurallari`, `/etkinlik-yonetimi` | adres aynı, grup İletişim (değişmez) |

Mobilde rotalar `go_router` yönlendirmesiyle aynı şekilde eşlenir
(`/sakinler` → Kişiler/Sakinler, `/personel` → Kişiler/Personel,
`/davetler` → Kişiler/Davetler); bildirimlerden gelen derin bağlantılar
bozulmaz.

### Onay için sorular

1. "Kişiler" tek giriş + sekmeler — onay?
2. "Personel" maaş defterinin adı "Maaş kartları" ve Finans'a taşınması —
   onay?
3. Devriye (takip · NFC · planlar) tek sayfa — onay?
4. Yalnız-web listesi (yukarıdaki tablo) — eksik/fazla var mı?
