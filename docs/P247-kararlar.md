# P247 — Kararlar

Sıra: §6 → §3 → §7 → §2 → §4+§5 → §1. Her bölüm ayrı commit.
Yöntem E2E turuyla aynı: gerçek akış canlı API üzerinde uçtan uca sürüldü,
sonra kilit testine çevrildi. Ölçülemeyenler en sonda ayrı listede.

---

## §6 API güvenliği — tüm modüller

**Envanter.** 611 uç tarandı. 108 kamu uç var ve hepsinin gerekçesi yazılı.
Tarama sırasında şu açıklar ortaya çıktı:

- 92 kimlikli yazma ucu (mutasyon) denetim kaydı yazmıyordu.
- 159 metin alanının üst sınırı yoktu.
- Arama ve dışa aktarma uçlarında hız sınırı yoktu.
- İki yanıt, istenenden fazla veri döndürüyordu.

**Kararlar**

1. **Gövde sınırı (5 MB, `app/govde_siniri.py`).** Saf ASGI katmanıdır;
   hem `Content-Length`e hem parçalı (chunked) akışa bakar. Aşılırsa 413
   döner ve mesaj kullanıcının dilindedir. Dosyalar presign ile doğrudan
   depoya gider, bu yüzden API gövdesinin 5 MB'ı geçmesi için meşru bir
   sebep yok.
2. **Metin tavanı (200 000 karakter).** `schemas.BaseModel` genel olarak
   `str_max_length` uygular. Daha dar sınır isteyen alan kendi sınırını
   yazar. 159 alana tek tek sınır koymak yerine taban sınır seçildi:
   yeni alan sınırsız doğamaz.
3. **Genel denetim (`app/genel_denetim.py`).** Kimlikli ve 2xx dönen
   her yazma isteği `api_yazma` eylemiyle denetim kaydına geçer. Kayıt
   rota şablonunu, ilk kimlik parametresini ve kişiyi tutar. Ayrı oturumda
   yazılır; ana işlemin geri alınması (rollback) kaydı silmez.
   - Hariç tutulanlar gerekçelidir: kendi tercihleri, cihaz kaydı, bildirim
     okundu, oturum açma. Oturum açmanın kendi denetimi zaten vardır.
   - Uçların kendi ayrıntılı denetimi olduğu gibi kalır; bu katman
     yalnızca "hiç iz yok" durumunu kapatır.
4. **Hız sınırı (`hiz_siniri.kullanici_siniri`).** Sınır kişi başınadır:
   arama 120/dk, dışa aktarma/indirme/PDF/makbuz 60/dk (yıl sonu "tüm raporlar" ~32 istek/dk meşru). Giriş ve kod isteme
   uçlarının mevcut IP/kimlik sınırları korundu.
5. **Yanıt fazlalığı.**
   - Panik yanıtındaki `olusturan_telefon` yalnızca güvenlik, amir ve
     yönetime, bir de alarmın sahibine döner. Önceden bina çapındaki panikte
     sakinlere de gidiyordu.
   - Kamera kaydedici adresi/kullanıcısı ve yayın kullanıcısı yalnızca
     yönetime döner.
6. **IDOR (dinamik tarama, ~100 deneme).**
   - `/ekler` üst kaydın kapsamını, o kaydın kendi router'ındaki
     yardımcıdan okur. Önceden rol kapısı kayıt kapsamının yerine
     geçiyordu; sakin, başka sakinin talebine yazılan notu okuyabiliyordu.
   - Amirin ekip kapsamı (`gorunur_roller`) artık görev okuma ve yazmada
     da geçerli. Atanmamış (havuz) görevler amire açık kalır.
7. **Kilit.** `tests/yetki/uc-guvenlik.tsv` + `test_p247_uc_guvenlik.py`.
   Her uç şu sütunları beyan eder:
   - kimlik, kapsam, sahiplik, hız, denetim, hassas, tavan, not.
   - Hesaplanan sütunlar koddan üretilir; beyan sütunları elle doldurulur.
   - Yeni uç eklenince kilit kırmızı olur ve beyan boş geçilemez.
   - Kamu uç ya da denetimsiz yazma ucu için gerekçe yazmak zorunludur.
   - Hassas uçta hız sınırı zorunludur.
   - `kendi`, `atama` veya `hedef` beyanlı her uç için
     `test_p247_idor.py` içinde dinamik bir vaka olmak zorundadır.
   - Kilidi yeniden üretmek için: `UC_GUVENLIK_GUNCELLE=1`.
8. **Mobil.**
   - Jetonlar `flutter_secure_storage`dadır: iOS Keychain
     (`unlocked_this_device`), Android'de Keystore.
   - TLS doğrulamasını atlayan bir yol yok.
   - Günlüğe yalnız hata metni yazılır.
   - "Beni hatırla" parolayı saklıyordu; §4'te kaldırıldı.

**Ürün kararı bekleyenler (düzeltilmedi, not edildi).**
- Saha personeli birbirinin izin notunu görüyor (P232). Not sağlık
  gerekçesi taşıyabilir.
- Güvenlik ve tesis görevlisi daire notlarını okuyor.

## §3 Kargo ve ziyaretçi "bekliyor"da kalıyor

**Ölçüm.** Backend akışları çalışıyordu. Kayıtlar kapanmıyordu, çünkü
kaydı kapatacak kişinin yetkisi ya da düğmesi yoktu:

- Güvenlik teslimi işaretlediğinde 403 alıyordu.
- Mobilde ziyaretçi çıkış düğmesi yoktu. Model `cikis_zamani` alanını
  okumuyordu, bu yüzden "içeride" sayacı yalnızca artıyordu.
- Kaydı süre dolunca kapatan bir mekanizma yoktu.

**Kararlar**

1. **Kargo teslimini güvenlik de işaretler**, çünkü paketi kapıda fiilen
   veren odur.
   - Güvenlik, paketi kime verdiğini dairenin aktif sakinlerinden seçebilir.
   - `teslim_eden_user_id` ayrı bir kolondur.
   - Güvenlik teslim ettiğinde dairenin tüm sakinlerine `kargo_teslim`
     bildirimi gider. Sakin kendisi işaretlerse bildirim gitmez.
   - Amir ve yönetim teslim işaretlemez.
2. **3 gün** teslim alınmayan kargo durum değiştirmeden **gecikmiş**
   olarak işaretlenir. Otomatik "teslim edildi" yazmak yalan olurdu, çünkü
   paket fiziksel olarak hâlâ kapıdadır.
3. **Ziyaretçi.** Çıkış düğmesi mobilde güvenliğe açıldı.
   - Çıkışı damgalanmamış kayıt **24 saat** sonra saatlik beat görevi
     `ziyaretci-otomatik-kapanis` ile `cikis_otomatik=true` olarak kapanır.
   - Ekranda "Çıkış kaydedilmedi" yazar.
   - Etkinlik akışında "çıktı" olarak görünmez.
   - Gün sonu yerine 24 saat seçildi, çünkü gece kalan misafir meşrudur.
4. **Göç 0153:** `kargo.teslim_eden_user_id`, `visitor.cikis_otomatik`,
   `kargo_teslim` bildirim tipi.

## §7 Mobil görünüm

**(a) Büyük modda ızgara 8'den 4'e inmiyordu.**

- **Ölçüm.** Cihaz içi yol çalışıyordu. Seçim cihazda saklanıyordu
  (P230, `ui.gorunum_modu`), ızgara bunu okuyordu ve Ayarlar'da Büyük
  seçilince 4 karo çıkıyordu.
- **Kök neden.** P243 §4 aynı ayarı **hesapta** da tutmaya başladı
  (`app_user.ui_gorunum`, `PATCH /me/gorunum`). Mobil bu alanı hiç
  okumuyor ve yazmıyordu. Sonuçları:
  - Web'de Büyük seçen kişi telefonda 8 karo görüyordu.
  - Telefonda yapılan seçim web'e gitmiyordu.
  - Uygulamayı silip yeniden kuran kişi seçimini kaybediyordu.
- **1.6.0'da var mı?** Evet. P230 ve P243 §4 commit'lerinin ikisi de
  1.6.0+16'nın atası.
- **Karar: tek doğru hesaptır.**
  - Yerel depo yalnızca ilk karenin önbelleğidir. `runApp`'ten önce
    okunur, böylece açılışta 8 karo görünüp 4'e zıplamaz.
  - Oturum açılınca hesaptaki seçim kazanır.
  - Bu cihazda yapılıp sunucuya ulaşmamış seçim ezilmez, önce sunucuya
    gönderilir. Bu kapsama çevrimdışı yapılan seçim ve 1.6.0'dan kalan,
    eşitlik işareti olmayan seçim girer. Aksi hâlde 1.6.0'da Büyük seçmiş
    herkes ilk eşitlemede küçülürdü.
  - Bekleyen seçim kullanıcıya bağlıdır (`bekliyor:<uid>`); başka bir
    hesaba yazılmaz.
  - Yeni uç açılmadı.

**(b) iOS'ta "Rezervasyo|n" bölünüyordu.**

- **Kök neden.** Punto seçici metni `TextStyle(fontSize)` ile ölçüyordu.
  Kart ise w600 ağırlıkla ve temadan miras gelen 0.25 harf aralığıyla
  çiziliyordu. iOS'ta SF Pro Regular ile ölçülen kelime, Semibold olarak
  çizilince taşıyordu.
- **Karar: tek bileşen, `KartEtiketi`.**
  - Ölçüm, gerçekten çizilen stille yapılır (`DefaultTextStyle` ⊕ kart
    stili) ve 1 px pay bırakılır.
  - Sıra: önce küçült; yine sığmazsa tek satır ve sondan üç nokta.
  - İkinci emniyet olarak `wrapWords:false` kullanılır.
  - Bileşen hızlı erişim kartlarına (üç ana ekran) ve Hızlı Özet
    kutularına bağlandı. Almanca "Gesamteinnahme|n" de bölünüyordu.
- **Kilit.** Test, çizilen widget'ın her satır sonunun bir kelime
  sınırına düştüğünü doğrular. Kapsam: 7 dil × 320 ve 390 dp × iki mod,
  iOS tipografisiyle.
- **Test fontu: DejaVu Sans Bold.** Material'ın iOS aileleri
  (`CupertinoSystemText` / `CupertinoSystemDisplay`) adıyla yüklenir.
  Roboto SemiBold'dan %23–33 geniştir; en az %15 fark kilitlidir. SF Pro
  lisansı gereği repoda yok.

## §2 Profilden rol geçişi (yönetici ↔ sakin)

**Kural istisnası (tek).** Aynı tesiste bir kişinin birden fazla rolü
olamaz (P212). Tek istisna **YÖNETİCİ + SAKİN**:

- Yönetici, kendi e-postası ya da telefonuyla `POST /residents` üzerinden
  bir daireye bağlanır. Yeni hesap açılmaz, davet gönderilmez.
  `RESIDENT_ASSIGN` denetimine `yonetici_sakin` yazılır.
- Diğer bütün birleşimler 409 `kisi_bu_tesiste_baska_rolde` döner.
  Örnek: güvenlik görevlisini sakin olarak eklemek.
- Kilit: `test_p212…::test_YONETICI_SAKIN_OLABILIR_DIGER_BIRLESIMLER_YASAK`.

**Sunucu aktif rolü zorlar.**

- `GET /me.roller`, kişinin geçebileceği rolleri verir: yönetici ve aktif
  daire bağı varsa `[yonetici, resident]`, diğerlerinde tek eleman.
- `POST /me/rol-gecis`, geçişi **yeni bir yetki bağlamı** olarak açar:
  - mevcut erişim jetonu kara listeye alınır,
  - eski refresh ailesi kapatılır,
  - aktif rolü taşıyan yeni bir çift döner.
- Gerekçe: aynı jetonla iki mod, önbelleklerde ve açık sekmelerde karışık
  bir durum demekti. Eski bağlamın kapanması, yönetim ekranından sakin
  moduna "sızmış" bir isteğin olmamasını garanti eder.
- Jeton `role` = aktif rol ve `asil_rol` = yönetici taşır. Refresh
  jetonu `arol` taşır, böylece mod yenilemede korunur.
- `get_current_user` jetondaki rolü **yalnız** izinli ikincil rolse ve
  kişi hâlâ uygunsa uygular. Daire bağı koptuysa DB rolüne döner. Sahte
  bir `role` claim'i yok sayılır; testte ölçüldü.
- Sakin modunda yönetim uçları 403 döner. İstemci atlatılıp API doğrudan
  çağrılarak ölçüldü (`/users`, `/residents`, `/finans/ozet`, `/audit`).
- Her geçiş denetime `rol_gecisi` (önceki/yeni) olarak yazılır.

**Web.**

- Yöneticinin sakin modu ayrı bir web rolüdür: `sakin_modu`. Jetonda
  `role=resident` ve `asil_rol=yonetici` bulunur.
- Saf sakin P129 gereği hâlâ yalnız mobildedir.
- Sakin alanı yeni sayfa açmadı; P129'da park edilen sakin sayfaları
  kullanılıyor: Aidatım + ödeme bilgileri, Duyurular, Taleplerim,
  Rezervasyonlarım, Etkinlikler, Kurallar, Yönetim iletişim, Bildirimler.
- Sakin modunda menü tek ve başlıksız bir bölümdür. Her yönetim rotası,
  derin bağlantılar dahil, `/aidatim`'e yönlendirilir.
- Geçiş **tam sayfa yüklemesiyle** biter: SWR ve Next önbelleği tamamen
  atılır. Bu, P203 tesis değiştirme kararının aynısıdır.
- Geçiş sırasında tam ekran bir perde gösterilir; eski modun ekranı
  hiçbir an etkileşimli kalmaz.
- Mod, refresh çerezindeki `arol` ile hatırlanır.

**Mobil.**

- Geçiş, oturum kabının (`ProviderScope`) nesil anahtarıyla yeniden
  kurulmasıdır. Tek tek `invalidate` yapılmadı: role bakmayan, autoDispose
  olmayan çok sayıda denetleyici var ve liste eksik kalırdı.
- Perde, SnackBar ve hedef rota yeni kapta işlenir.
- Mobilde giriş jetonu asıl rolle verilir. Bu yüzden son mod kullanıcı
  başına güvenli depoda tutulur ve girişten sonra geri yüklenir. Daire
  bağı koptuysa yönetici modunda kalınır.

**Ortak.**

- Menü yalnız `roller` iki elemanlıyken çizilir ve aktif mod işaretlidir.
  Tek rollü kullanıcıda menü yoktur (Playwright ile ölçüldü).
- **Bildirime dokunma:**
  - Push'ta `data.hedef_rol` (§5) kullanılır.
  - Kalıcı listede tip + `SAKIN_KIMLIKLERI` kullanılır (web, mobil ve
    backend kümesi eşit; testle kilitli).
  - Hedef aktif modda yoksa ve diğer modda varsa önce o moda geçilir,
    "… moduna geçildi" bildirilir, sonra hedefe gidilir.
- **Panik tam ekran uyarısı iki modda da gösterilir.** Kişiye gelen bir
  acil durum mod saflığından önce gelir. Uyarı yalnız bildirimdir; yönetim
  eylemi açmaz.

**Finans: yönetici kendi aidatını tahsil ederse** denetim kaydına
`kendi_tahsilati: true` yazılır; toplu tahsilatta bu bir sayıdır.
Şeffaflık panosu anonim aylık toplam olduğu için olağan görünür; ayrı bir
iz eklenmedi. Kayıt denetimde durur, panoda kişi ifşa edilmez.

## §4 Oturum süresi ve arka plan bildirimi

**Ölçüm (önce).**
- Erişim jetonu 15 dk, yenileme jetonu 30 gün. Her yenilemede yeni bir
  30 günlük jeton verilir, yani oturum zaten **kayan** 30 gündü.
- Web çerezleri: erişim 15 dk, yenileme 30 gün. Çerez her yenilemede
  yeniden yazılır.
- Bulunan kusurlar:
  1. Parola değişince hiçbir cihaz düşmüyordu.
  2. Mobilde "beni hatırla" bayrağını yalnızca parolalı giriş yazıyordu.
     SSO, davet, kodla giriş ve tesis oluşturma yolları bayrağı hiç
     yazmıyordu, bu yüzden bu kullanıcılar uygulamayı her yeniden açışta
     oturumsuz kalıyordu.
  3. "Beni hatırla" **parolayı** cihazda saklıyordu.

**Kararlar**

1. **Oturum: kayan 30 gün.** Kullanan kişi düşmez; 30 gün
   kullanılmayan cihazın oturumu kendiliğinden biter. Sabit 30 günde
   her gün kullanan kişi de ayda bir yeniden giriş yapardı; bunun
   güvenlik kazancı yok, çünkü çalınan cihaz zaten iptal ile kapatılır.
   Erişim jetonu 15 dk olarak kalır, böylece çalınan erişim jetonunun
   ömrü kısa olur.
2. **Parola değişince tüm cihazlar düşer.**
   - `PATCH /me/password` iptal damgası basar (`tum_oturumlari_kapat`) ve
     yalnızca isteği yapan cihaza taze bir jeton çifti döner (204 → 200
     TokenPair).
   - Web BFF bu çifti httpOnly çereze yazar; mobil secure storage'a yazar.
   - Başarısız deneme kimseyi düşürmez; aksi halde bu bir DoS yolu olurdu.
   - Eski mobil sürüm (204 bekleyen) gövdeyi yok sayar ve bir sonraki
     yenilemede düşer. Bu, güvenli yöne doğru bir kırılmadır.
3. **Mobil "beni hatırla" varsayılan olarak AÇIK.** Kayıt yoksa oturum
   hatırlanır. Kullanıcı kutuyu kaldırırsa açıkça `false` yazılır.
   Telefon kişisel bir cihazdır; ortak cihazda kutu kaldırılır.
4. **Parola artık cihazda saklanmıyor.** Yalnızca kimlik (telefon/e-posta)
   ön-doldurulur. Eski sürümlerin sakladığı parola ilk okumada silinir.
   Parola sunucudan iptal edilemez, jeton edilebilir; 30 günlük jetonun
   olduğu yerde parolayı saklamanın bir getirisi yok.
5. **E2E çıkış ve sıfırlama iptaliyle uyumlu.** Aynı damga ve aynı jti
   kara listesi kullanılır. `ims` ms damgası, taze çiftin damganın
   ARKASINDA kalmasını garanti eder (`jeton_ms < damga` katı).

**Uygulama kapalıyken push.** Ölçülen/kanıtlanan:
- Gövde `notification` taşır; bildirimi işletim sistemi ya da FCM
  SDK'sı çizer, Flutter motoru gerekmez.
- Acil ve sesli bildirimlerde `android.priority=high` gönderilir, böylece
  Doze modunda geciktirilmez.
- iOS'ta `apns-priority: 10` ve `apns-push-type: alert` başlıkları
  gönderilir.
- `aps-environment` yetkisi var. App Store dışa aktarımında Xcode bunu
  `production` yapar.
- Arka plan işleyicisi `@pragma('vm:entry-point')` ile kayıtlı.

Olgu: Android'de **zorla durdurulmuş** (force-stop) uygulamaya hiçbir FCM
mesajı teslim edilmez. Bu işletim sisteminin kuralıdır, uygulama bunu
aşamaz. Kaydırılıp kapatılmış uygulama ise bildirimi alır.

## §5 Bildirim görünümü — "WhatsApp gibi"

**Temel karar: `notification` gövdesi kalır, data-only'ye geçilmedi.**
MessagingStyle, eylem düğmeleri ve avatar gibi özellikler, bildirimi
uygulamanın kendisinin çizmesini gerektirir. Bu da data-only mesaj ve
arka planda uyanan bir Flutter motoru demektir. Bunun iki sonucu var:

- iOS'ta kapalı uygulamaya data-only mesaj **hiç** teslim edilmez.
- Bazı Android üreticilerinde (Xiaomi, Huawei gibi) arka plan motoru
  öldürülür ve bildirim sessizce kaybolur.

Panik alarmının hiç görünmemesi, "WhatsApp gibi" görünmemesinden çok daha
ağır bir sonuçtur. Gövdenin taşıyabildiği her şey eklendi
(`app/push_gorunum.py`):

| Özellik | Android | iOS |
|---|---|---|
| Gruplama | `tag` = kayıt (aynı kaydın yeni bildirimi eskisinin yerini alır); 4+ bildirimi sistem kendisi demetler | `thread-id` = tesis + konu ("Acil", "Kargo", "Finans"…) |
| Kaynak | Başlığa ek: "Kargo · Güneş Sitesi" | `subtitle` = tesis adı |
| Tam önizleme | Gövde kesilmez; genişletince tam metin görünür | Gövde kesilmez |
| Acil (panik, yangın, gürültü eskalasyonu) | Ses kapalı olsa bile `priority=high`, `PRIORITY_MAX`, kritik kanal (heads-up) | `interruption-level=time-sensitive`, `apns-priority 10` |
| Rozet | `notification_count` | `badge` = kişinin okunmamış sayısı + 1; uygulama açılınca gerçek sayıya çekilir (`site.yonetio.app/rozet`) |
| Kilit ekranı | Acil tipler `PUBLIC`, diğerleri `PRIVATE` ("hassas içeriği gizle" ayarına uyar) | Kullanıcının "Önizleme göster" ayarı geçerli |
| Aynı kaydın güncellemesi | `tag` | `apns-collapse-id` |

- **Rozet sayısı** uygulamadaki okunmamış sayısıyla aynı kuralla
  hesaplanır. `test_p247_bildirim_gorunumu` bunu sakin, güvenlik ve
  yönetici için karşılaştırır.
- **Üç ses kanalı korundu** (kritik, gürültü, vardiya); kanal kimlikleri
  değişmedi.
- **Kilit ekranında kişisel veri.** Bildirim gövdelerinde telefon ve
  e-posta taşınmaz. Panik bildirimi kilitliyken okunabilir kalır, çünkü
  bilgi saniyeler içinde gerekir.
- **§2 ile uyum.** Her push'ta `data.hedef_rol` bulunur. İki rollü kişiye
  kişi olarak giden sakin bildirimi (kargo, aidat, talep sonucu…)
  `resident`, rol yayını ise asıl rol taşır. Dokunulunca uygulama o moda
  geçer.
- **Eylem düğmeleri ("Gördüm", "Gidiyorum", "Onayla") eklenmedi.**
  Karar ve gerekçe:
  1. Güvenlik: kilit ekranından, kimlik doğrulamadan yapılan bir
     "Gidiyorum", telefonu eline alan herkesin panik alarmını
     yanıtlayabilmesi demektir. Diğer görevliler "biri gidiyor" diye
     durur. Bu yüzden durum değiştiren her eylem **kilidi açmayı ve
     uygulamayı açmayı** gerektirmeli.
  2. Uygulama zaten açılacaksa düğme, bildirime dokunmaktan fazlasını
     vermez. Dokunma doğrudan kayda gider ve düğmeler ekranın üstündedir.
  3. Android'de `notification` gövdesi eylem taşıyamaz. Düğme için
     data-only mesaj ve yerel çizim gerekir, bu da yukarıdaki teslim
     riskine geri döner.
- **Avatar eklenmedi.** Kişi fotoğrafının adresi FCM üzerinden (Google)
  geçerdi. Adres presign edilmiş olduğu için süresi dolar, ve bildirim
  yükünde kişisel veri taşınmış olurdu. Kaynak olarak tesis adı
  kullanılıyor.
- **Xcode adımları (iOS iletişim bildirimi/avatar ve Odak modunu delme
  için, isteğe bağlı):**
  1. Signing & Capabilities → **Time Sensitive Notifications**
     yeteneğini ekle. Developer portalda App ID'de de açılmalı; açılmadan
     yetki dosyasına eklenirse imza kırılır. Bu adım yapılmadan
     `time-sensitive` iOS'ta `active` gibi davranır.
  2. File → New → Target → **Notification Service Extension**
     (`YonetioNSE`), paket kimliği `site.yonetio.app.nse`. Aynı App
     Group'u ekle.
  3. NSE'de `mutable-content` ile gelen bildirimden (sunucu zaten
     gönderiyor) `INSendMessageIntent` kur; bildirim avatarlı "iletişim
     bildirimi" olur. Bunun için **Communication Notifications** yeteneği
     gerekir.
  4. Podfile'da NSE hedefi Firebase'e bağlanmaz; uzantı yalnızca
     UserNotifications + Intents kullanır.
  5. Yeni hedef için bir provisioning profile oluştur ve arşivle.

## §1 Vardiya rotasyonu — döngü kalıpları

**Ölçüm (önce).** P207 haftalık ve P243 aylık rotasyonlar dilim
atamalarını dönem başına yalnızca kaydırıyordu. Bu yüzden:

- 2 gece / 2 gündüz / 2 tatil (bir gün dizisi) anlatılamıyordu.
- 12/36 (gün aşırı) anlatılamıyordu.
- Her uygulama tek seferlik bir partiydi; kaydırma her ay elle
  tutturuluyordu.
- Mobilde kalıp da rotasyon da yoktu.

**Kararlar.** Yeni bir vardiya kavramı açılmadı; KALIP ve PARTİ
genişletildi.

1. **Tek model: adım dizisi.** `vardiya_kalibi.adimlar` gün uzunluğunda
   bir dizidir.
   - Her adım o gün çalışılan dilimlerin sıra numaralarıdır; boş dizi
     tatildir.
   - 12/36 = `[[gece],[]]`. İki hafta gece + iki hafta gündüz 12/36 =
     7×`[[gece],[]]` + 7×`[[gündüz],[]]`.
   - Saat tabanlı ikinci bir model yazılmadı. Plan satırı güne bağlı, ve
     24 saatin katı olmayan her oran birkaç günlük bir diziye açılıyor.
     İkinci model, aynı satırı iki kod yolundan üretmek olurdu.
2. **Adım takvimden hesaplanır:** (gün − referans) mod uzunluk. Sayaç
   yok, bu yüzden **izin, resmî tatil ve elle değişiklik döngüyü
   kaydırmaz.**
3. **Ufuk: süresiz atama, kayan 62 gün.**
   - Beat görevi `scheduler.vardiya_dongu_uret` ufku her gece 00:30
     İstanbul'da ilerletir.
   - 62 gün, bir sonraki tam takvim ayının her an üretilmiş olmasını
     sağlar.
   - Satırlar taslaktır; P241 taslak/yayınla akışı korunur.
4. **Filigran (`uretildi_kadar`).**
   - Üretici geriye dönmez: elle değiştirilen, silinen ya da izinli gün
     ezilmez ve geri gelmez.
   - İzinli gün `atlanan` listesinde raporlanır.
   - Çakışma sessizce atlanmaz; `cakisanlari_atla` bayrağı gerekir.
5. **Ekip kaydırması.** Kişiler sıralıdır; i. kişiye i×k gün ofset
   verilir.
   - Önizleme, gün başına **kimsesiz saat aralıklarını** kırmızı ve saat
     aralığıyla gösterir.
   - Kapsama, seçilen kişilerin rollerindeki tüm personele göre hesaplanır.
6. **Geri alma.** Mevcut parti mekanizması kullanılır. Döngü partisinde
   atamalar da kapanır; kapanmasa beat ertesi gece yeniden doldururdu.
   Kişi bazında `sonlandir` ayrı bir uçtur.
7. **Sınırlar.**
   - Döngü satırında "tüm seri" düzenlemesi 422 döner.
   - Aynı kişiye ikinci etkin döngü 409 döner.
   - Etkin döngünün kalıbı silinmek istenirse 409 döner.
   - Döngü kalıbı `kalip-uygula` ile uygulanmak istenirse 422 döner.
8. **Korunanlar.** Hepsi testle ölçüldü:
   - gün aşırı (gece geçen) vardiya
   - çakışma denetimi
   - izin denetimi
   - planlanan/gerçekleşen, mesai
   - yasal mola
   - taslak/yayınla
   - amir kapsamı (amir tesis görevlisine döngü atayamaz: 403)
9. **Mobil parite.**
   - Mobilde olanlar: kayıtlı döngüyü atama, önizleme (boşluklar dahil),
     kaydetme, geri alma, iki hazır döngü (2-2-2 ve 12/36 iki hafta).
   - **Yalnız web (gerekçeli istisna):** serbest döngü editörü (6 dilim ×
     84 gün telefonda hataya açık; tanım bir kez yapılır) ve kişi bazında
     sonlandırma.
10. **Göç 0154:** `vardiya_kalibi.adimlar`, `vardiya_dongu_atama`
    (RLS), `vardiya_plani.dongu_atama_id`.

---

## Ölçülemeyenler

- **Gerçek iOS cihazda bildirim görünümü:** thread gruplaması, subtitle,
  rozet ve time-sensitive davranışı. Test yalnızca FCM'e giden gövdeyi
  ölçer. Bu makinede iOS cihaz ve Xcode yok. `AppDelegate.swift` içindeki
  rozet kanalı derlenmedi.
- **Uygulama kapalıyken push:** Android'de kaydırılıp kapatılmış
  uygulama, iOS'ta sonlandırılmış uygulama. Geliştirme ortamında cihaz ve
  emülatör yok, `PUSH_PROVIDER` gerçek FCM'e bağlı değil. Ölçülen şeyler
  gövde, öncelik ve yetkiler (yukarıda).
- **Android'de genişletilmiş tam metin:** FCM SDK'sının BigTextStyle
  kullanması cihazda görülmedi.
- **Beat zamanlaması:** iş fonksiyonları (ziyaretçi otomatik kapanış,
  döngü ufku) doğrudan çağrılarak ölçüldü. Zamanlama kayıtları manifest
  testiyle kilitli. Dağıtımda beat ve worker imajları yenilenmeli.
- **20 kişilik ekipte döngü önizleme süresi:** 3 kişide 0,44 sn ölçüldü.
- **Gerçek iOS cihazda font ölçüsü:** SF Pro metrikleri burada yok.
  "DejaVu Bold en az SF Pro Semibold kadar geniş" varsayımı ölçülmedi.
  Gerçek cihazda "Rezervasyon" ve Almanca kartlara göz ile bakılmalı.
- **Android'de silip yeniden kurma** ve **mobilde yapılan görünüm
  seçiminin web'e yansıması** tarayıcıda sürülmedi; yalnızca kod okuma ve
  HTTP adaptörü testiyle ölçüldü.
- **§2 mobilde gerçek cihaz:** FCM soğuk açılışı ve oturum kabının
  yeniden kurulması (push jeton kaydının tekrar tetiklenmemesi dahil)
  yalnızca widget testiyle ölçüldü.
- **§2 web'de bildirim üzerinden otomatik mod geçişi:** gerçek bir
  yönetim bildirimiyle canlı sürülmedi; karar birim testiyle ölçüldü.
