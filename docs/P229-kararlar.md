# P229 — mobil metin taşması, vardiya takvimi, görev tamamlama

## §1 — Mobilde metin taşması

### Ölçüm: bildirilen belirti istisna üretmiyor

Kusur "sığmayan kelimeler **alt satıra kayıyor**" diye bildirildi. Flutter'da
bu **istisna üretmez** — metin sessizce sarar. Mevcut
`small_screen_overflow_test` `takeException()` kullanıyor, yani bu kusuru
**hiçbir zaman göremezdi**; nitekim ana ekranları 7 dilde, 320dp'de,
1.0 ve 1.3 yazı ölçeğinde sürdüm: **istisna yok**. Bu yüzden ölçüm
**sarma sayısına** çevrildi.

### Kök neden: Almanca bileşik isimler

En uzun tek (bölünemez) kelimeler taranınca tablo netleşti:

| uzunluk | dil | kelime |
|---|---|---|
| 30 | de | `Benachrichtigungseinstellungen` |
| 29 | de | `Marktplatz-Benachrichtigungen` |
| 28 | de | `Beschwerdebenachrichtigungen` |
| 24 | de | `Nachbarschaftsbeschwerde` |

Türkçe karşılıkları kısa olduğu için kusur TR'de görünmüyordu. Rusça
uzun ama **boşluklu** — sarabildiği için Almanca kadar zarar vermiyor.

### Ölçüm tuzağı: test fontu genişlikleri şişiriyor

İlk ölçüm 53 düğmeyi "taşıyor" gösterdi; `Bewohner hinzufügen` bile
listedeydi. Sebep: `flutter_test` varsayılan fontu **her glifi kare em**
çizer, yani genişlik = karakter sayısı × fontSize. Gerçek fontlarda
Latin/Kiril ortalaması ~0.52 em. Sistemdeki gerçek `DejaVuSans` ile
`FontLoader` üzerinden yeniden ölçtüm: **53 değil 15** anahtar sarıyor,
bunların 7'si 1.0 ölçekte.

### Düzeltme: çeviri kısaltma

Kullanıcının belirttiği öncelik sırası izlendi — **metin değişikliği en
ucuzu** ve dokunma hedefine dokunmaz. Kısaltılanlar (anlam korunarak):

| anahtar | önce (de) | sonra (de) |
|---|---|---|
| `karKaydetVeBildir` | Speichern und Bewohner benachrichtigen | Speichern + benachrichtigen |
| `hesapSilKodlaOnayla` | Kein Passwort – mit Code bestätigen | Mit Code bestätigen |
| `izgaraSifirla` (es) | Restablecer valores predeterminados | Restablecer |
| `vardiyaCakisanHaric` (es) | Añadir excluyendo los conflictos | Sin conflictos |
| `gorevYeniTamamlamaBaslat` (fr) | Démarrer un nouvel achèvement | Nouvel achèvement |
| `otoparkAracListesi` (de) | Fahrzeugdurchfahrten öffnen | Durchfahrten |
| `ozetTahsilatOrani` (en) | Dues collection rate | Collection rate |

**Üç nokta ile kesme kullanılmadı** — kısaltma yeterli oldu ve kesme,
erişilebilirlik etiketi gerektiren ikinci bir mekanizma getirirdi.

### Sarması serbest bırakılanlar — gerekçeli

`kayitGirisLinki` ("Zaten hesabınız var mı? Giriş yapın") ve
`girisKayitBaglantisi` düğme değil, **içinde bağlantı olan cümlelerdir**.
İki satıra sarmaları doğru davranıştır; kısaltmak cümleyi bozardı.
Kilitte gerekçeli izin listesinde (`kSarmasiSerbest`).

### Izgara kartları: zaten korunuyordu — bir gerçek kesilme vardı

Izgara kartı `AutoSizeText(maxLines: 2, minFontSize: 8)` kullanıyor:
sığmayan başlık **taşmaz, küçülür**. İlk eşiği 12sp koydum ve **Türkçe
bile düştü** ("Aidat Tahsilat Oranı") — o eşik tasarımın kendisini hatalı
ilan ediyordu, çünkü küçülme beklenen davranış. Doğru eşik **taban olan
8sp**: orada da sığmıyorsa `AutoSizeText`in yapabileceği kalmaz ve başlık
kesilir. O eşikte **tek** gerçek kusur çıktı: `ozetTahsilatOrani` (en).

### Kilit

`mobile/test/dugme_metni_tasmasi_test.dart` — 7 dil, 85 düğme etiketi +
33 ızgara başlığı. Taşınabilirlik için sistem fontuna bağlanmadı;
test fontu **kalibre edilmiş genişlikle** (232/0.52 ≈ 446) kullanılıyor,
kalibrasyon DejaVu ölçümüyle doğrulandı (7'ye 6 örtüşme, fark yalnız
eşik üzerindeki sınır vakaları).

**Kırılarak kanıtlandı:** `karKaydetVeBildir` eski Almanca metnine geri
alındı → test düştü ve satırı adıyla yazdı; geri konunca yeşillendi.

### Yan etki: 6 mobil test kırmızıya döndü — ve bu iyi haber

Kısaltmalar 4 test dosyasındaki eski metin iddialarını düşürdü. Bu,
metinlerin gerçekten ekranda çizildiğinin kanıtı; iddialar güncellendi.

---

## §2 — Vardiyada gün seçimi

### Ölçüm: web tam, mobil eksik

| | ay görünümü | keyfi çoklu gün | aralık | "tüm pazartesiler" |
|---|---|---|---|---|
| **Web** (P207/P214) | var | var (`gunler: string[]`) | sürükle-seç | var |
| **Mobil** (önce) | yok | **yok** | bas/son `showDatePicker` | yok |

Yani "gün seçilemiyor" tam doğru değildi: mobilde **bitişik aralık**
seçilebiliyordu, **bitişik olmayan** seçim yoktu. Asıl boşluk
web↔mobil paritesiydi.

### Karar: aynı uç, yeni alan — yeni uç değil

`POST /vardiya-plani/toplu` opsiyonel `gunler: list[date]` aldı.
Verilirse aralık alanları yok sayılır; verilmezse davranış **birebir**
eskisi gibi.

**Neden yeni uç değil:** çakışma denetimi, "hepsi ya da hiçbiri" iki
geçişi, azami gün sınırı ve denetim kaydı orada. İkinci bir uç, P205'te
çözülen "sessizce atlama" kusurunu yeni uçta yeniden doğururdu.

**Neden aralık alanları zorunlu kaldı:** yayındaki mobil sürümler onları
gönderiyor; opsiyonel yapmak sözleşmeyi onlar için değiştirirdi.

**Tekrar eden günler sunucuda eleniyor:** aynı günü iki kez yazmak,
kullanıcının **görmediği** bir çakışma üretirdi (çizelgede üst üste iki
blok).

### Dokunmatik seçim kararı: dokun = tekil, uzun bas = aralığa tamamla

Masaüstünde (P214) aralık `Shift`, tekil ekleme `Ctrl`. Dokunmatikte
değiştirici tuş yok; üç seçenek değerlendirildi:

1. **Sürükle-seç** (web'de var) — **reddedildi**: takvim kaydırılabilir
   bir gövdede duruyor; sürüklemeyi kaydırmadan ayırmak jest çatışması
   üretir, kullanıcı ayı kaydırmaya çalışırken gün seçer.
2. **"Başlangıç seç / bitiş seç" kipi** — **reddedildi**: görünmez bir
   kip yaratır, kullanıcı hangi aşamada olduğunu unutur.
3. **Dokun = tekil aç/kapa, uzun bas = son seçilenden buraya** —
   **seçilen**. Tekil seçim en sık yapılan iştir ve tek dokunuşta olur;
   aralık, alışılmış bir jestle gelir. **Kip yoktur**: her dokunuş kendi
   başına anlamlıdır. Hiçbir gün seçili değilken uzun bas tekil gibi
   davranır — yoksa jest sessizce hiçbir şey yapmazdı.

### Hafta günü kalıbı: evet, uygulandı

P207'de web'de vardı. Mobilde **hafta günü başlıkları aynı zamanda kalıp
düğmesidir** — başlığa dokunmak ayın tüm o günlerini seçer. Ayrı bir düğme
sırası eklemek, dar ekranda §1'de ölçülen taşmanın ikinci bir kaynağı
olurdu.

### Gün adları sözlükten değil yerelden

`DateFormat.E(dil)` yedi dilin gün adlarını zaten biliyor. Sözlüğe 7×7 =
49 anahtar eklemek, her biri çevrilmesi gereken ve yanlışlıkla Türkçe
kalabilecek 49 satır demekti.

### Korunan kurallar

* **Gün aşırı vardiya (22:00–06:00, P205)** — keyfi seçimde de doğru;
  ardışık iki gece vardiyası çakışma **sayılmıyor** (birinin bitişi
  ötekinin başlangıcı, üst üste binmiyor). İkisi de test edildi.
* **Çakışma sessizce atlanmıyor (P205)** — keyfi seçimde de iki aşamalı:
  çakışma varsa hiçbir şey yazılmaz, günler adlarıyla döner, kullanıcı
  karar verir.
* **Dokunma hedefi 48×48 (P220)** — hücre yüksekliği
  `kMinInteractiveDimension`da sabit; 320dp'de genişlik daralır, yükseklik
  daralmaz. Test ediliyor.

### İki kip, tek diyalog

Takvimden gün seçilmişse aralık alanları **gizlenir**. İkisini birden
göstermek hangisinin geçerli olduğunu belirsiz bırakırdı: kullanıcı aralığı
1–7 bırakıp takvimden 3 gün seçer ve kaç vardiya oluşacağını bilemezdi.
