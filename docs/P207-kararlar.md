# P207 — Vardiya planlama genişletme + bildirim sesi

## §1 — AY BAZINDA TOPLU VARDİYA PLANLAMA

### Ölçüm: P205 nereye kadar gidiyordu

P205 §2'nin hızlı ekleme penceresi **tek kişi + tek saat aralığı + tarih
aralığı** alıyordu (`POST /vardiya-plani/toplu`). Ay ölçeğinde eksik olan
üç şey vardı: (a) düzensiz gün seçimi ("tüm pazartesiler"), (b) günü
birden çok vardiyaya bölme, (c) toplu işlemi geri alma.

### K1.1 — Gün seçimi SET, aralık değil

Seçim istemcide `Set<string>` olarak tutulur ve sunucuya **gün listesi**
gider. Aralık (başlangıç–bitiş) göndermek, "tüm pazartesiler" gibi
düzensiz bir seçimi **anlatamazdı** — ve seçimi aralıklara bölüp N istek
atmak, çakışma raporunu N parçaya bölerdi.

Üç seçim yolu: tıklama (aç/kapa), **sürükleme** (basılı tutup gezmek
aralık seçer) ve **hafta günü kalıbı** (Pazartesi… Pazar düğmeleri).
Otuz sütunluk bir şeritte pazartesileri tek tek tıklamak, dört-beş
tıklama ve her birinde yanlış sütuna basma ihtimaliydi.

Seçim **görsel olarak belirgin**: dolgu + sol kenarlık + `aria-pressed`.
Silik bir işaret, otuz sütunluk şeritte göz taramasıyla bulunamazdı.

Araç çubuğu **yalnız AY görünümünde** çizilir: gün/hafta görünümünde bir
avuç gün vardır ve toplu planlama orada anlamlı değil.

### K1.2 — Kalıp: JSONB dilimler, ayrı tablo değil (göç 0099)

`vardiya_kalibi(ad, dilimler JSONB, aktif)`. Dilimler ayrı tabloya
bölünmedi: hep **birlikte** okunup **birlikte** yazılıyorlar, bağımsız
bir yaşamları yok (kalıpsız dilim anlamsız) ve tek tek sorgulanmıyorlar;
sıra önemli ve JSONB dizisi sırayı zaten taşıyor. CHECK: 1–6 dilim (boş
kalıp uygulandığında hiçbir şey olmaz ve kullanıcı sebebini anlayamazdı;
üst sınır ise tek istekle yüzlerce vardiya üretilmesini engelliyor).

Kalıp **kaydetmek opsiyonel**: tek seferlik plan için `dilimler` doğrudan
gönderilebilir. Bir kerelik plan için kalıcı tanım üretmek, tanım
listesini şişirirdi. Aynı ad iki kez kullanılamaz (409) — ay başında
"hangisiydi" sorusu yanıtlanamaz olurdu.

Kalıp silinince **ondan oluşmuş planlar kalır**: kalıp bir şablondur,
plan satırlarının ona bağlı bir yaşamı yok (geri alma `parti_id` ile).

### K1.3 — Rotasyon: EVET, ama yalnız "haftalık" ve tek kaydırma

**Destekleniyor.** Güvenlik sektörünün standart kalıbı: A ekibi bu hafta
gündüz, gelecek hafta gece. Desteklemeseydik yönetici ya aynı ayı iki kez
planlar (önce A gündüz, sonra B gündüz) ya da her hafta elle değiştirirdi
— ve elle değiştirilen her hafta, bir haftanın atlanma ihtimalidir.

**Neden yalnız bu biçim:** üçlü/dörtlü rotasyon, ileri/geri yön, "iki gün
çalış bir gün izin" gibi desenler var ama her biri **başka** bir kural.
Hepsini tek parametreye sığdırmak, kullanıcının anlamadığı bir kutu
üretirdi. Buradaki söz net: her hafta atamalar **bir dilim ileri** kayar.
Ötekiler için kalıp iki kez uygulanır (ayrı partiler, ayrı geri alma).

### K1.4 — Önizleme ayrı uç DEĞİL

`kuru=true` hiçbir şey yazmaz ve **aynı** hesabı döner. Ayrı bir
"önizleme" ucu yazmak, iki kod yolunun ayrışma riskiydi: sonuç
önizlemede başka, kaydetmede başka çıkardı — ve kullanıcı buna ancak
yazdıktan sonra güvenmeyi bırakırdı. Ekranda "Önizle" ve "Uygula" ayrı
düğmeler; önizleme kaç vardiya oluşacağını söyler (kabul kriteri 4).

### K1.5 — Çakışma sessizce atlanmaz (P205 kuralı korundu)

Çakışma varsa ve `cakisanlari_atla=false` ise **hiçbir şey yazılmaz**;
yanıt hangi **gün/dilim/kişi** çakıştığını satır satır söyler. Ekran ilk
on satırı listeler ve "çakışanlar hariç uygula" düğmesi sunar.

`zaten_var` ayrı bir durum: kalıbı ikinci kez uygulamak (bir gün ekleyip
yeniden çalıştırmak) mevcut satırları **hata gibi göstermemeli**.

### K1.6 — Geri alma: `parti_id` (istekteki KRİTİK şart)

Aynı istekte yazılan satırlar aynı `parti_id`yi taşır (göç 0099, kısmi
indeks: `parti_id IS NOT NULL`). Geri alma o kimliğe bakar.

**Neden `created_at` aralığı değil:** iki yönetici aynı dakika içinde iki
ayrı toplu işlem yapabilir ve zaman aralığıyla geri almak, ötekinin
satırlarını da iptal ederdi.

**Silmez, `iptal` işaretler** (P203 kuralı) ve **yalnız hâlâ `planli`
olan** satırlara dokunur: parti sonrası elle çıkarılmış satırları geri
getirmek, yöneticinin aradaki kararını sessizce ezmek olurdu. İkinci kez
geri alma 404.

Ekranda "Son toplu işlemi geri al" düğmesi yalnız son parti varken
görünür ve geri alındıktan sonra kaybolur.

### Ölçüm

Backend `test_p207_kalip.py` **15 test**: kalıp tanımı/tekrar kullanım,
kalıpsız uygulama, önizlemenin yazmaması, gün×dilim sayısı, gün aşırı
dilimin ertesi güne taşması (P205 korundu), düzensiz gün seçimi, çakışma
+ "hariç uygula", `zaten_var`, haftalık rotasyonun kaydırması, rotasyonsuz
sabitlik, geri alma, partiler arası bağımsızlık, saha rolünün 403 alması,
başka tesisin personelinin atanamaması.

Web `p207-kalip.dom.test.ts` **10 test**: araç çubuğunun yalnız ay
görünümünde çıkması, tıklama/hafta günü kalıbı/temizleme, seçim yokken
düğmenin pasifliği, `kuru=true` önizleme, uygulama gövdesi (günler +
atamalar + rotasyon), çakışma listesi + hariç uygula, geri alma.

**Kilit kanıtı:** (a) çakışma dalı kaldırıldı → `CAKISMA_SESSIZCE_ATLANMAZ`
düştü; (b) rotasyon kaydırması sıfırlandı → `HAFTALIK_ROTASYON` düştü;
(c) web'de "Önizle" doğrudan yazacak şekilde bozuldu → önizleme testi
düştü. Üçü de geri alındı.

Göç 0099 downgrade→upgrade doğrulandı. Rol matrisine 5 satır eklendi
(kalıp okuma sahaya da açık — "bir sonraki vardiyada kim var" sorusu
sahanın sorusu; yazma yalnız admin+yönetici).

**Ölçemediğim:** gerçek tarayıcıda fare sürükleme hissi (jsdom'da
`mousedown`/`mouseenter` olayları tetikleniyor ama gerçek sürükleme
eşiği/ivmesi ölçülmedi).

---

## §2 — BİLDİRİM SESİ

### Ölçüm: neden sessizdi

FCM gövdesi (`app/push.py`) yalnızca `notification{title, body}` + `data`
taşıyordu. **Android 8'den beri bildirimin sesi kanalın özelliğidir**;
kanal belirtilmeyen bildirim manifest'teki varsayılan kanala düşer ve o
kanal **tanımlı değildi** (`AndroidManifest.xml`'de
`default_notification_channel_id` yoktu, `MainActivity.kt` boş bir sınıftı).
iOS tarafında `aps.sound` **hiç** gönderilmiyordu. Yani sessizlik bir ayar
değil, **eksikti**.

### Teknik gerçekler — doğrulandı ve karara bağlandı

| Platform | Gerçek | Bizdeki karşılığı |
|---|---|---|
| Android | Kanalın sesi **oluşturulduktan sonra program tarafından değiştirilemez** (yalnız kullanıcı sistem ayarlarından değiştirir) | Kanal kimlikleri **sürümlü**: `yonetio_kritik_v1`. Ses dosyası değişirse `_v2` açılır, eskisi silinir |
| Android | Kanal **uygulamada** oluşturulur; FCM'deki `channel_id` var olan kanalı **seçer**, oluşturmaz | `MainActivity.kt` üç kanalı `onCreate`te oluşturuyor |
| iOS | Özel ses **uygulama paketine gömülüdür**; sunucu yalnız adını gönderir | Yeni ses = **yeni sürüm yayını**. `SES_HAZIR=False` iken `aps.sound="default"` |

**Bağımlılık eklenmedi:** `flutter_local_notifications` yalnızca kanal
açmak için eklenecekti; uygulamanın hiçbir yerinde yerel bildirim
göstermiyoruz. Kanallar native tarafta (Kotlin) açılıyor.

### SES DOSYASI — İSTENEN BİÇİM (siz sağlayacaksınız)

Tek bir ses, iki formatta gerekiyor:

**Android** — `mobile/android/app/src/main/res/raw/yonetio_bildirim.ogg`
- Biçim: **OGG/Vorbis** (tercih) veya MP3/WAV
- Süre: **1–3 saniye** (sistem 30 sn'ye kadar çalar ama bildirim sesi
  uzun olursa kullanıcı kapatır)
- Örnekleme: 44.1 kHz, mono yeter; hedef boyut **< 100 KB**
- Dosya adı **küçük harf + rakam + alt çizgi** olmalı (Android kaynak adı
  kuralı) ve **uzantısız** olarak koda girer — bu yüzden ad sabit:
  `yonetio_bildirim`

**iOS** — `mobile/ios/Runner/yonetio_bildirim.caf`
- Biçim: **CAF** (Linear PCM / IMA4), alternatif `.aiff` / `.wav`
- Süre: **30 saniyeden kısa olmak ZORUNDA** — uzunsa iOS sesi çalmaz,
  sessizce varsayılana düşer (en sinsi hata biçimi); pratikte 1–3 sn
- Xcode'da **Runner target'ına** eklenmeli (Copy Bundle Resources)
- Dönüştürme: `afconvert -f caff -d LEI16 giris.wav yonetio_bildirim.caf`

Dosyalar geldiğinde kodda değişecek **tek yer**: `push_kanal.py` içinde
`SES_HAZIR = True` ve kanal kimliklerinin `_v2`ye çıkarılması (Android'de
sesi değişen kanal yeni kimlik ister). Şu an sistem sesiyle çalışıyor.

### K2.1 — Üç kanal, bildirim tipine göre seçim

`yonetio_kritik_v1` (IMPORTANCE_HIGH, özel/sistem sesi + titreşim),
`yonetio_genel_v1` (IMPORTANCE_DEFAULT, sistem sesi),
`yonetio_sessiz_v1` (IMPORTANCE_LOW, ses yok).

Kritik listesi (`KRITIK_TIPLER`): şikayet/talep hattının tamamı, vardiya
hatırlatma + başlamama + özet, kaçırılan tur, gecikmiş okutma, uzak
okutma, gürültü uyarısı. Ortak yanları: **bekleyen bir iş değil, olmayan
bir işi** ya da kullanıcının hemen görmesi gerekeni bildiriyorlar.

Kritik bildirimde FCM önceliği `high`: Android düşük öncelikli mesajları
Doze modunda toplayıp geciktirir; "vardiyanıza 5 dakika" bildiriminin
gecikmesi onu **anlamsız** yapardı.

### K2.2 — Ses tercihi SUNUCUDA (göç 0100)

`app_user.bildirim_sesi` (varsayılan **true**). Neden istemcide değil:
Android'de sesi kapatmak kanalı değiştirmek demektir ve uygulama var olan
bir kanalın sesini değiştiremez — "sesi kapat" ancak sunucunun **başka
bir kanala** göndermesiyle olur.

`bildirim_mobil`den ayrı bir bayrak: biri "push gelsin mi", öteki "sesli
mi gelsin". Tek bayrağa bağlamak, "gece çalıyor" diyen kullanıcıya
bildirimin **tamamını** kapattırırdı — ve o kullanıcı ertesi gün
vardiyasını da kaçırırdı.

Gönderimde ses kırılımı **kişi bazında**: aynı gönderimde bir kullanıcı
sesli, öteki sessiz olabilir; tek bir "sesli mi" değeri kullanmak, sesi
kapatan kullanıcının telefonunu çaldırırdı.

Ayarlar ekranında anahtar var ve **kapalıyken uyarı çıkıyor**: "sesli
uyarıları kapattınız: vardiya hatırlatmalarını ve şikayet bildirimlerini
duymayabilirsiniz". Uyarı yalnız kapalıyken görünür — sürekli görünen
bir uyarı okunmaz olurdu.

### K2.3 — Sessiz saatler: HAYIR (gerekçeli)

**Yapılmadı.** Gece vardiyası olan bir sistemde "gece sessiz olsun" kuralı
tam olarak **yanlış kişiyi** susturur: 23:00'te vardiyaya girecek
güvenlik görevlisinin hatırlatması, sessiz saatlerin göbeğine düşer.
Doğru kurgu "kullanıcının **kendi vardiyası dışındaki** saatler" olurdu;
bu, vardiya planına bağlı kişiselleştirilmiş bir sessizlik penceresi
demek ve planı olmayan roller (sakin) için tanımsız kalır.

Kullanıcının bugün elinde olan iki kaldıraç yeterli: (a) uygulama içi
"sesli uyarılar" anahtarı, (b) Android'in kendi kanal ayarları ve
"Rahatsız Etmeyin" programı — ki bu, işletim sisteminin zaten çözdüğü ve
kullanıcının kendi ritmine göre kurduğu bir şey. Kayıt altında: vardiya
planına bağlı sessizlik penceresi istenirse ayrı bir tur.

### Ölçüm

Backend `test_p207_push_kanal.py` **8 test + 2 atlanan**: kanal seçimi
(kritik/genel/sessiz), ses kapalıyken kritik bildirimin de sessiz kanala
düşmesi, dosya yokken sistem sesi, FCM gövdesinde `channel_id` +
`priority` + `aps.sound`, sessiz gönderimde `apns`ın **hiç** olmaması,
kanalsız eski çağıranın kırılmaması, tercih ucunun okunup değiştirilmesi.

Kanal kimliği **eşitlik kilidi** mobil tarafta:
`p207_kanal_kimlik_test.dart` **4 test** — backend'deki `push_kanal.py`
ile `MainActivity.kt`i okuyup karşılaştırır (backend konteynerinde mobil
kaynak olmadığı için oradaki aynı kilit kendini atlıyor ve bunu açıkça
söylüyor). Kilit kanıtı: Kotlin'deki kimlik `_v2` yapıldı → test düştü,
geri alındı.

**Ölçemediğim:** gerçek cihazda sesin çalması. Kanalın oluşması, sesin
kanala bağlanması ve FCM'in doğru kanalı seçmesi ancak fiziksel cihazda
(veya emülatörde) doğrulanabilir; burada emülatör yok. Ölçtüğüm şey
**gövdenin doğru alanları taşıdığı** ve **kimliklerin ayrışmadığı**.

---

## §3 — VARDİYA HATIRLATMA BİLDİRİMİ

### K3.1 — Kademe sayısı: en fazla ÜÇ, tenant ayarı

`tenant.vardiya_hatirlatma_dk` virgüllü liste ("30,5"); boş = kapalı.
Neden metin: kademe **sayısı** değişken (bir ya da üç) ve ayrı bir tablo
açmak, iki satırlık bir ayarı yönetmek için CRUD ekranı gerektirirdi.

**Birden çok kademe destekleniyor** ama en fazla üç: üçten fazlası
bildirim yorgunluğu üretir ve hatırlatma **anlamını kaybeder**
(`tur_alarm_tekrar_sayisi` ile aynı gerekçe, P34). Liste büyükten küçüğe
sıralanır — kullanıcı "5,30" yazsa bile önce 30 dakika kalınca
hatırlatılır; sırasız bırakmak aynı vardiyada önce 5 sonra 30 bildirimi
demekti.

Geçersiz/boş metin **kapalı** demektir; 422 ile durdurmak kullanıcının
"kapat" niyetini hataya çevirirdi.

### K3.2 — Hatırlatma YALNIZ atanan personele

Yöneticiye **gönderilmiyor.** Yirmi kişilik bir ekipte yönetici günde
yirmi "vardiyanıza 15 dakika" bildirimi alırdı — kendisiyle ilgisi
olmayan yirmi bildirim, okunmaz hale gelir ve gerçekten yöneticiye ait
olan uyarıyı (aşağıdaki "başlamadı") da götürürdü.

Yöneticinin ihtiyacı olan bilgi "kim gelmedi"dir, "kim gelecek" değil —
ve o bilgi zaten ikinci bildirimde var.

### K3.3 — İleri bakar, GERİ BAKMAZ (telafi yok)

Hatırlatma penceresi `(kademe-1, kademe]` dakikadır. Beat bir süre
koşmadıysa **telafi yapılmaz**: geçmiş bir vardiya için "5 dakika kaldı"
demek kullanıcıya **yanlış** bir şey söylemektir ve kaçırılmış vardiyayı
geri getirmez.

Kuralı ayrıca `kalan_dk <= 0` diye yazmadım: aynı kuralı iki yerde tutmak,
biri değişince ötekinin sessizce eskimesi demekti — ve o kod dalını
hiçbir test kıramıyordu (denendi; break testinde pencere koşulu zaten
yakalıyor, guard ölü koddu).

### K3.4 — "Vardiyaya başlamadı" uyarısı — geciken devriyeden FARKLI

`tenant.vardiya_baslamadi_dk` (varsayılan 15, 0 = kapalı). Vardiya
başladıktan sonra bu süre içinde **personelden hiç okutma gelmediyse**
yöneticiye uyarı.

P34'teki geciken devriye alarmı **açılmış bir tur penceresinin** gecikmesi;
bu ise vardiyaya **hiç başlamama**. İkisini tek alarma indirmek, "geç
kaldı" ile "yok" arasındaki farkı silerdi — biri beklenir, öteki **yerine
birini göndermeyi** gerektirir.

Uyarı **yöneticiye** gider: personele "gelmedin" demek faydasız biçim;
sorunu çözecek kişi yöneticidir.

Tarama penceresi üstten sınırlı (`tolerans` ile `tolerans+60` dk arası):
`dedup` zaten tekrarı engelliyor ama her dakika bütün günü sorgulamak
gereksiz yük olurdu.

### K3.5 — İdempotency

`dedup_key = tip:plan_id:kademe` (hatırlatma) ve `tip:plan_id`
(başlamadı), `notification` tablosunda `ON CONFLICT DO NOTHING`.
**Kademe anahtara girer**: 30 ve 5 dakika kademeleri ayrı bildirimlerdir
ve ikisi de gitmelidir; anahtara girmeseydi ikinci kademe "zaten
gönderildi" diye yutulurdu.

### K3.6 — Sesli (§2'ye bağlı)

`vardiya_hatirlatma` ve `vardiya_baslamadi` `KRITIK_TIPLER` içinde: kritik
kanaldan, `priority=high` ile gider. Android düşük öncelikli mesajları
Doze modunda toplayıp geciktirir; "vardiyanıza 5 dakika" bildiriminin
gecikmesi onu **anlamsız** yapardı.

### Beat ve dağıtım

`scheduler.vardiya_hatirlatma`, **60 saniye**. Beş dakikada bir koşsaydı
"5 dakika kaldı" kademesi çoğu vardiyada hiç yakalanmazdı.

Görev tanımı **worker**, zamanlama **beat** imajında —
`docs/P207-dagitim.md` bunu ayrıca yazıyor (iki turda atlandığı için).

### Ölçüm

`test_p207_vardiya_hatirlatma.py` **15 test**: kademe çözümleme (sıra,
sınır, geçersiz/boş), pencerede gönderim + kişiye hedefleme,
idempotency, başlamış vardiyada sessizlik, pencere dışında sessizlik,
iki kademenin ayrı bildirim olması, kapalı ayar, iptal edilmiş plan,
başlamama uyarısı (yöneticiye), okutma varsa gönderilmemesi,
idempotency, tolerans dolmadan/çok eski vardiyada sessizlik, tesis
izolasyonu.

**Kilit kanıtı:** dedup anahtarından kademe çıkarıldı →
`IKI_KADEME_IKI_AYRI_BILDIRIM` düştü; geri alındı.

**İlk yazımda bulunan kusur:** `scan_event` tablosunda `user_id` **yok**
(sütun `guard_id`); test bunu ilk koşumda gösterdi ve düzeltildi —
kaynak okuyarak varsaydığım bir sütun adıydı.

**Ölçemediğim:** gerçek beat döngüsünde (Celery zamanlayıcısı) tetiklenme;
testler zamanlayıcı fonksiyonunu `now` enjekte ederek doğrudan çağırıyor.
Prod'da doğrulama komutları dağıtım belgesinde.
