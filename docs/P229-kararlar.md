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

---

## §3 — Görev tamamlama bilgisi

### Ölçüm: "kaydediliyor da mı gösterilmiyor?" → **kaydediliyor, gösterilmiyor**

Bu ayrım kullanıcının kendi sorusuydu ve yanıtı belirleyici oldu.

`POST /tasks/{id}/completions` **zaten** kaydediyordu: kim
(`tamamlayan_user_id`), ne zaman (`tamamlanma_zamani`), fotoğraf
(`foto_key` + presigned `foto_url`), not, NFC, GPS, idempotency, görev
bazlı foto zorunluluğu, periyodik ilerletme, talep otomatik çözme.

Eksik olan **beş** şey:

1. **`TaskOut` tamamlama hakkında hiçbir şey taşımıyordu.** Liste ve
   ayrıntı "tamamlandı mı" sorusunu yanıtlayamıyordu.
2. **`GET /tasks/{id}/completions` hiçbir istemciden çağrılmıyordu.**
   Mobil detay ekranı yalnız **kendi POST yanıtını** çiziyordu — ekranı
   kapatınca kayboluyor, başka kimse görmüyordu.
3. **`tamamlayan_ad` yoktu.** Saha rolü kullanıcı listesini göremiyor
   (403), yani id'den adı çözemezdi: "kim tamamladı" mobilde **teknik
   olarak çizilemiyordu**.
4. **Denetim kaydı yoktu** — `tasks.py`'de tek bir `audit_user` çağrısı
   bile yoktu.
5. **Geri açma yolu yoktu.**

### Ek bulgu: web'de tamamlama tablosu hiç çalışmıyormuş

`app/(protected)/tasks/page.tsx` detay panelinde
`/api/tasks/{id}/completions` okuyor ve tabloyu çiziyordu. Arka uç doğru,
sayfa doğru — ama BFF rotası **yalnız POST export ediyordu**, yani istek
**405** alıyordu ve tablo hiç dolmuyordu. P189 ve P226'da ölçülen sınıfın
aynısı: "iki uç ayrı ayrı doğru, **orta halka** ölçülmemiş". `GET`
eklendi ve kilitlendi.

### Kararlar

| Soru | Karar | Gerekçe |
|---|---|---|
| **Kim tamamlayabilir?** | admin + **yönetici** + saha (saha yalnız kendine atananı) | `_COMPLETER`'da yönetici **yoktu**: personel izinli/ayrılmışsa görev sonsuza kadar açık kalıyordu. Saha kısıtı korundu. |
| **Geri açılabilir mi, kim?** | Evet — **yalnız admin + yönetici** | Geri açma bir **kanıtı** siler. Sahadaki kişi kendi tamamlamasını silebilseydi "yaptım" deyip izini temizleyebilirdi. |
| **Nasıl geri açılır?** | Kayıt **silinir**, "iptal" bayrağı konmaz | Bayrak, "son tamamlama" hesabını ve rapor toplamlarını her yerde o bayrağı kontrol etmeye zorlardı; bir yerde unutulması, geri alınmış bir işin raporda **yapılmış** görünmesi demekti. İz denetim kaydında: `task_complete` / `task_reopen`. |
| **Yöneticiye bildirim?** | Evet — **oluşturana değil yönetime** | Oluşturan kişi izinli/ayrılmış olabilir; o zaman "iş bitti" haberini kimse almazdı. Kendi kapattığı görevi yöneticinin kendisine bildirmiyoruz (gürültü). Yeni tip `gorev_tamamlandi`, göç **0131**. |
| **Neden `gorev_atandi` tipi değil?** | Ayrı tip | Yönleri ters: atama yönetimden sahaya, tamamlanma sahadan yönetime. Tek tipe indirmek, bildirim tercihinde birini kapatmayı ötekini de kapatmak yapardı. |
| **Fotoğraf zorunlu mu, türe göre mi?** | Zaten **görev bazında** (`foto_zorunlu`), türe göre değil | Aynı kategorideki iki işten biri kanıt isteyebilir (yangın tüpü kontrolü), diğeri istemeyebilir (çöp toplama). Kategoriye bağlamak esnekliği kaybettirirdi. |

### Performans kararı: özet listede, ayrıntı ayrı uçta

`son_tamamlama` **özet**tir (id, kim, ne zaman, foto **var mı**, not) —
tam kayıt değil. Liste yüzlerce görev dönebilir ve her satır için
presigned foto URL'i üretmek **her satırda imza hesabı** demektir.
Ayrıntı (GPS, NFC, foto URL) `GET /tasks/{id}/completions`te.

N+1 yok: tüm görevlerin tamamlamaları **tek sorguda** çekilip en yenisi
seçiliyor.

### Yetki kuralları sunucuda

`_COMPLETER` ve `_REOPENER` arka uçta; BFF yalnız yolu açıyor, rol
kontrolü **tekrarlanmıyor** — iki yerde ayrışabilecek ikinci bir kural
olurdu. `backend/tests/yetki/rol-matrisi.txt` yeniden üretildi:

```
POST   /tasks/{id}/completions                 IZIN IZIN IZIN IZIN RED RED RED
DELETE /tasks/{id}/completions/{completion_id} IZIN IZIN RED  RED  RED RED RED
```

### Kilitler — kırılarak kanıtlandı

* Backend `test_p229_gorev_tamamlama.py` — 16 test. `_tamamlama_ozeti_doldur`
  devre dışı bırakıldı → 4 test düştü. ✔
* Web `p229-gorev-tamamlama.dom.test.ts` — BFF metot taraması + 7 dil
  paritesi. `GET` export'u kaldırıldı → test düştü. ✔
* Mobil `p229_gorev_tamamlama_test.dart` — 6 test, taklit **HTTP
  adapter'ında** (P200 dersi).

### Ölçemediğim

Gerçek cihazda push **bildiriminin gelişini** ölçemedim: dev'de
`PUSH_PROVIDER=noop` ve emülatör yok. Ölçtüğüm şey, `notification`
satırının yazıldığı ve `dispatch_external`'ın doğru tip ve hedeflerle
çağrıldığı.
