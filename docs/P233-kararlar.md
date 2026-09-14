# P233 — konum, kısayol, telefon/e-posta sınırları, ikon

## §1 — Tesis konum bilgisi

### Ölçüm: alan vardı, **değer yoktu**

P193'te adres alanları (açık adres, ilçe, il, posta kodu) eklenmişti.
Enlem/boylam sorusunun yanıtı: **zaten var** — `tenant.konum_lat`,
`konum_lon`, `konum_ad` göç 0005'ten beri duruyor ve `/weather` onları
kullanıyor.

Ama dev veritabanındaki **tüm tesisler aynı değeri taşıyor**:

```
ad                      konum_ad   konum_lat   konum_lon
Bambaska Bir Ad         İstanbul   41.008200   28.978400
Oltu Sitesi Sinama      İstanbul   41.008200   28.978400
Coklu Yonetici Sitesi   İstanbul   41.008200   28.978400
...
```

Bu **sunucu varsayılanı** (`server_default`) — kimse hiç ayarlamamış.
Sonucu görünür ve yanlış: Erzurum'daki tesis **İstanbul havasını**
gösteriyor. Fark edilmesi en zor kusur sınıfından, çünkü ekran
**çalışıyor görünür**.

Alanlar `PATCH /tenant/settings` ile **yazılabilir durumdaydı**; eksik
olan şey, yöneticinin **enlem/boylam yazmadan** konumunu verebileceği bir
yoldu. Kimse tesisinin enlemini bilmez; alan bu yüzden boş kaldı.

### Karar: haritadan seçim değil, **adresten çözümleme**

Üç seçenek ölçüldü:

| seçenek | ölçüm | karar |
|---|---|---|
| Haritadan seçim | Web'de Leaflet **var** (`konum-haritasi.tsx`), **mobilde hiç harita paketi yok** (`pubspec.yaml`'da flutter_map/google_maps yok) | **reddedildi** — yeni bağımlılık + karo sağlayıcı + çevrimdışı davranış; yalnız web'e yapmak kalıcı parite kuralını bozardı |
| Dukkan hiyerarşisinden türetme | `dukkan.il/ilce/mahalle` 44.719 mahalle taşıyor ama **koordinat taşımıyor** (sütunlar: id/ad/slug/posta_kodu/tip) | **mümkün değil** |
| **Adresten çözümleme** | Open-Meteo coğrafi kodlama: anahtar istemiyor, **zaten kullandığımız sağlayıcı** (hava durumu aynı yerden) | **seçildi** |

Doğruluk **ilçe düzeyinde** — istenen iki kullanım (hava durumu, bölgesel
analiz) için tam yeterli; hava sokak hassasiyeti istemez.

Elle enlem/boylam yazma yolu **kapatılmadı** (`PATCH /tenant/settings`
duruyor): ücra bir konum için kaçış yolu kalsın.

### Aday listesi, tek sonuç değil

"Oltu" sorgusu üç farklı yer döndürüyor (ölçüldü):

```
Oltu     Erzurum         40.53945  41.98722
Oltush   Brest Oblast    51.68848  23.96978
Oltuca   Artvin          41.21180  42.25735
```

Sunucunun ilkini seçip "buldum" demesi, yöneticinin **hiç görmediği** bir
konumu tesise yazmak olurdu.

### Servis düşerse 503, sessiz boş liste değil

Boş liste "böyle bir yer yok" demektir; servis erişilemiyorsa bu **yanlış
bir cümledir** ve kullanıcıyı adresini yanlış yazdığını sanmaya iter.

### Dukkan hiyerarşisiyle eşleşme

**Şema sınırı korundu:** `app_rw`'nin `dukkan` şemasında sıfır yetkisi var
(P221'de kurulan kural) ve **yeni yazma yolu açılmadı**. Tesisin il/ilçe
bilgisi zaten `tenant` tablosunda **metin** olarak duruyor (P193);
Dukkan eşleşmesi gerektiğinde slug üzerinden yapılır — çapraz şema FK
yok.

### Zorunlu mu?

**Hayır.** Alan göç 0005'ten beri NOT NULL ve varsayılanı var; zorunlu
işaretlemek **bugün çalışan her tesisi bir gecede "eksik" ilan etmek**
olurdu — hiçbiri bozulmuş değil, yalnızca hava durumları yanlış. Kurulum
sihirbazı bunu **gösterir** ve düzeltmeyi kolaylaştırır; tesisi durdurmaz.

Sihirbaz ölçütü "alan dolu mu" **değil**, "varsayılandan farklı mı".
Gerçekten İstanbul'da olan bir tesis için bu yanlış negatif üretir (adım
"yapılmadı" görünür) — kabul edilebilir, çünkü adım zorunlu değil ve
yönetici konumu bir kez onaylayınca kapanır. Tersi — yanlış pozitif —
her tesise sessizce yanlış hava göstermekti.

### KVKK / yetki

| | kim |
|---|---|
| Konumu **görmek** (hava durumu) | herkes — tesisin genel bilgisi, sakinden saklamanın anlamı yok |
| Konumu **aramak** (`/konum/ara`) | admin + yönetici |
| Konumu **yazmak** (`PATCH /tenant/settings`) | admin + yönetici (saha rolü 403 — test edildi) |

### Ölçemediğim

Coğrafi kodlama servisinin **prod ağından** erişilebilirliği. Dev
makineden çalıştığı ölçüldü (HTTP 200); prod çıkış kuralları farklıysa uç
503 döner ve arayüz bunu **söyler** — sessizce boş liste göstermez.

---

## §2 — Mobil üst bar kısayolu: dil yerine arama

Üst barda dört kısayol vardı: ızgara düzenleme, bildirim zili, **dil**,
avatar. Dil simgesi kaldırıldı, yerine **arama** geldi.

Gerekçe isteğin kendisi: dil **zaten Ayarlar'dan** değiştirilebiliyor
(`settings_screen` içinde kendi kartı var) ve bir kez seçilip bir daha
dokunulmayan bir tercih; üst barda kalıcı yer kaplaması orantısızdı.

### Ölçüm sırasında çıkan bir yan sorun

P230 §3'te arama simgesini **karşılama satırına** koymuştum. Üst bara
taşıyınca **iki arama girişi** oluştu. İkisini de bırakmak, aynı işi iki
yerden yapan ve hangisinin "gerçek" olduğu belirsiz bir arayüz üretirdi;
karşılama satırındaki kaldırıldı.

**Üst bar seçildi** çünkü orada **her rolde aynı yerde** duruyor;
karşılama satırı rol ekranına göre değişiyordu.

`DilButonu` bileşeni silindi ama **`dilModaliniAc` duruyor**: modalin
kendisi hâlâ çağrılabilir, yalnızca üst bardaki girişi kalktı. Modali de
silmek, ileride başka bir yerden (örneğin ilk açılış) açmak isteyeni
sıfırdan yazmaya zorlardı.

Dokunma hedefi `IconButton` varsayılanıyla 48 dp (P220 kilidi) — test
ediliyor.
