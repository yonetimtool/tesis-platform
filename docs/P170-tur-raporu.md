# P170 — Beni hatırla · KVKK taşıma · mobil logo · mobil Özet (rapor)

---

## 1. "Beni hatırla" — parola nerede duruyor

**Kırmızı çizgi:** parola hiçbir uygulama deposuna düz metin yazılmadı.
`localStorage` / `SharedPreferences` / çerez **aynı sınıftır** — aynı kökende
çalışan her betik okur, tek bir XSS o an ekranda olan kullanıcının değil
**tüm kayıtlı parolaların** sızması demektir.

### Web — iki katman, alternatif değil

Ölçüm önce yapıldı: form **zaten** gerçek bir `<form>`du ve `autocomplete`
değerleri (`username` / `current-password`) yerindeydi. Eksik olan ikisi:

1. **`name` ve `id` yoktu.** `autocomplete` tek başına yetmiyor;
   tarayıcıların parola yöneticisi bir alanı kaydedebilmek için kararlı bir
   ad arar ve adsız alanlar çoğu tarayıcıda teklifin dışında kalır. Dört
   alana da eklendi.

2. **Credential Management API yoktu.** Tek sayfalı uygulamada form
   işaretlemesi tek başına yetmez: Chromium ailesi kaydetme teklifini
   çoğunlukla **gerçek bir gezinmeye** bağlıyor, bizde ise `preventDefault`
   + istemci tarafı yönlendirme var. `navigator.credentials.store` teklifi
   açıkça tetikliyor. Firefox/Safari desteklemiyor; orada (1) devrede.
   Bu yüzden ikisi **katmanlı**.

Hepsi `lib/kimlik-deposu.ts`de toplandı. Sakladığı tek şey **gizli olmayan
tanımlayıcılar** (tesis kodu, e-posta, telefon). Çıkışta tanımlayıcılar
siliniyor ve `preventSilentAccess()` ile tarayıcının **sessiz oturum açması**
kapatılıyor — ortak bir bilgisayarda "çıkış yaptım", bir sonraki kişinin tek
tıkla girememesi demektir.

### Mobil — zaten doğru yerdeydi, bir davranış değişti

Ölçüldü: telefon + parola **zaten** `flutter_secure_storage`da (iOS Keychain
/ Android Keystore, AES-GCM + RSA-OAEP anahtar sarma) tutuluyordu ve ön
doldurma çalışıyordu. İki değişiklik yapıldı:

* **Çıkış artık kimlik bilgisini de siliyor.** Önceden bilerek
  bırakılıyordu ("çıkış sonrası ekran ön dolu gelsin"). Karar değişti:
  çıkış, ortak ya da ödünç bir cihazda "benden sonrası bana ait değil"
  demenin tek yoludur. **Bedeli kabul edildi** — bilerek çıkan kullanıcı
  parolasını yeniden yazar; ön doldurma uygulamanın yeniden açılışında ve
  oturum süresi dolduğunda çalışmaya devam ediyor.
* **Saklanan kimlik bu cihazı terk etmiyor.** Anahtarlık erişilebilirliği
  `unlocked_this_device` yapıldı: varsayılan (`unlocked`) iCloud Anahtar
  Zinciri ile **yeni bir cihaza taşınır**. Bir jeton için bedeli sınırlıdır
  (kısa ömürlü, iptal edilebilir); bir parola için değildir.

### Biyometrik — bu tura alınmadı, gerekçesi

Eklenti biyometrik kapılı depolamayı **destekliyor**
(`AndroidOptions.biometric()`, Apple tarafında `accessControl`). Buna rağmen
sonraki tura bırakıldı:

* Biyometrik kapı **okuma anında** çalışır. Cihazda kayıtlı biyometri
  **yoksa ya da silinmişse** okuma başarısız olur ve ön doldurma sessizce
  bozulur — yani "beni hatırla" hiç çalışmıyormuş gibi görünür.
* Android tarafı `BiometricPrompt` istiyor ve bu host Activity'nin
  `FragmentActivity` olmasına bağlı; iOS tarafı `NSFaceIDUsageDescription`
  istiyor. İkisi de **gerçek cihazda** doğrulanmalı.
* Bu turda gerçek cihaz yok ve canlıya dağıtım yok. Doğrulanamayan bir kapı
  eklemek, çalışan bir özelliği sessizce bozma riski taşırdı.

Yerine, **doğrulanabilir** olan iki sertleştirme yapıldı (yukarıdaki
`unlocked_this_device` ve çıkışta temizlik).

### Testler

* Mobil `test/beni_hatirla_test.dart` (5): saklama/okuma, **parolanın yalnız
  güvenli depo kanalına gittiği** (SharedPreferences kanalına tek bir yazma
  bile olmadığı), işaretsizde silinme, çıkışta temizlenme, yarım kaydın
  geçersiz sayılması.
* Web `tests/beni-hatirla.dom.test.ts` (8): parolanın `localStorage`da
  **hiçbir anahtarda geçmediği**, kimlik deposu varsa parolanın oraya
  verildiği, deponun hata vermesinin girişi bozmadığı, çıkışta
  `preventSilentAccess` çağrıldığı ve form işaretlemesinin yerinde olduğu.

---

## 2. KVKK metinleri — ne taşındı, ne yerinde kaldı

### Önce bir tespit

`kvkk_metin` tablosunun kendi belgesinde şu yazılıydı: *"Her tesisin veri
sorumlusu kendisidir; platforma gömülü tek bir metin 200 tesise
**başkasının** metnini imzalatmak olurdu."* KVKK'da veri sorumlusu tipik
olarak site yönetimidir, platform değil.

Bu yüzden brief **veriyi değil yetkiyi** taşıyacak biçimde uygulandı:
**metinler tesise ait kalmaya devam ediyor, onları yayınlayan platform.**
Panel önce **tesis sorar**, sonra o tesise sürüm yayınlar. Aksi (tek global
metin) yukarıdaki cümlenin tarif ettiği hatayı üretirdi.

### Taşınan (yönetim)

| Eski | Yeni |
|---|---|
| `POST /kvkk/metin` (`admin` + `yonetici`) | `POST /tenants/{id}/kvkk` (**yalnız platform admin**) |
| `GET /kvkk/metinler` (`admin` + `yonetici`) | `GET /tenants/{id}/kvkk` (**yalnız platform admin**) |
| `/kvkk-metinler` app.\* · menü grubu "Yönetim" | `/kvkk-metinler` panel.\* · menü grubu "Platform" |

Çapraz-tenant erişim, panelin `tenants` uçlarında **zaten kullanılan**
desenle: dar, tek işli `SECURITY DEFINER` SQL işlevleri (göç **0065**) —
`kvkk_metin_listele`, `kvkk_metin_yayinla`, `kvkk_onay_ozeti`. Sürüm
sunucuda artıyor, aynı gövde yeniden yayınlanmıyor (409), bilinmeyen tesis
404.

**Ölü kod bırakılmadı:** BFF beyaz listesinden `kvkk-metinler` ve
`kvkk-metin` girişleri, `TESIS_ROTALARI`dan ve `ROTA_ROLLERI`den `/kvkk-metinler`
kaldırıldı. Uçlar backend'de de **gerçekten** yok — testi var: kapı yalnız
ekranda kapansaydı, tesis yöneticisi adresi yazıp yayın yapmaya devam
ederdi.

### Yerinde kalan (okuma ve onay)

* `GET /kvkk/metin` · `GET /kvkk/durum` · `POST /kvkk/onay` — **tüm roller**.
* **Yeni:** `GET /kvkk/onaylarim` — kullanıcının **kendi** onay geçmişi;
  sorgu `user_id` ile sınırlı, yönetici bile buradan başkasının onayını
  göremez. Eskiyen onay `guncel_mi=false` ile **açıkça** işaretlenir; sessiz
  bırakmak kullanıcıya okumadığı bir metni onaylamış gibi gösterirdi.
* **Web:** `/profil → Yasal Metinler` — beş metin sekmeli, gövde + kendi
  onay geçmişi.
* **Mobil:** `YasalMetinlerScreen` **zaten vardı** (P168 §5) ve kaldırılan
  uçların hiçbirini kullanmıyor; dokunulmadı.

Sürümleme, onay kaydı ve "yeniden onay gerektirir" davranışı **korundu**.

### Bilinen boşluk (yazılı bırakılıyor)

Platform tarafında yapılan yayın, tesisin `audit_log`una **düşmüyor** —
`tenants.py`daki öteki çapraz-tenant uçları da düşürmüyor (yönetici
ekleme/silme dahil). `yayinlayan_user_id` NULL yazılıyor ve bu zorunlu:
kolon `(user_id, tenant_id)` bileşke anahtarıyla **o tenant'ın** kullanıcısına
bağlı, platform yöneticisi orada yok. Uydurma bir kimlik yazmaktansa boşluk
görünür bırakıldı; platform işlemleri için ayrı denetim kanalı sonraki turun
işi.

---

## 3. Marka/logo oranı

### Üst bar — dar ekranda yalnız simge

Hesap **kaynaktaki ölçülerden** yapıldı (cihazda ölçülmedi): 360 px'lik üst
barda satır **menü düğmesi (~40) + logo bloğu (~135: `size={30}` işaret +
`gap-2` + `text-xl` kelime ~95) + bildirim/dil/hesap üçlüsü (~130) +
`px-4` yan boşluklar (32)** = ~337 px, kullanılabilir 328 px'in üstünde.
Kelime işaretinin sarma ya da kırpılma yeri yok.

İki seçenek vardı:

* **(a) kelimeyi küçültmek** — 328 px'e sığması için ~12 px gerekirdi. O
  boyutta kelime işareti okunmuyor ve marka ölçeği başka her yerden
  (çekmece, giriş, davet) farklı çıkıyor. **Küçük ve çirkin bir marka,
  markasızlıktan kötüdür.**
* **(b) kelimeyi gizlemek** — kimlik işaretle zaten taşınıyor; üst bardaki
  öteki üç öğe **işlevdir** ve atılamaz.

**(b) seçildi.** Kayıp da yok: çekmece açıldığında logo kelime işaretiyle
**tam** çiziliyor, yani marka adı bir dokunuş uzakta. `whitespace-nowrap`
ile kelime hiçbir genişlikte ikinci satıra düşmüyor; `width`/`height` eşit
verildiği için işaret hiçbir bantta ezilmiyor. `sm` (≥640) ve üstünde kelime
geri geliyor — orada yer var.

Açık/koyu tema: işaretin iki varyantı `dark:` sınıfıyla zaten ayrı çiziliyor
(P166), kelime `text-[#0E3C91] dark:text-white`. Değişiklik yalnız
görünürlük; her iki temada da aynı.

### Giriş ekranı banner'ı — ölçüldü, değişiklik gerekmedi

`h-9 w-auto` (36 px yüksek, 1271×339 oranıyla ~135 px geniş), `px-6` içinde.
360 px'te kullanılabilir alan 312 px. **Taşma yok, oran korunuyor, kırpılma
yok.** Değiştirilmedi.

Aynı dosyada **başka** bir kusur bulundu ve düzeltildi: sahne yoğunluğu
kararı (`mobil`) `useEffect` içinde **bir kez** ölçülüyordu ve eşiği 768'di —
projede başka hiçbir yerde geçmeyen bir sayı. Artık canlı ve `lg` (1024)
eşiğinden, yani giriş düzeninin kendi kırılma noktasından.

---

## 4. Özet sayfası

### 4.1 Widget şeridi — sorun sütun sayısı değil hizaydı

Ölçüldü: sütunlar **zaten** doğruydu (2 → 3 → 4 → 7, brief'in istediğiyle
birebir). Bozuk olan iki şey vardı:

1. **Yedi kutu iki sütuna sığmaz** ve sonuncusu satırın sol yarısında tek
   kalıyordu; sağdaki boşluk "eksik kart" gibi okunuyor, kullanıcı bir şeyin
   yüklenmediğini sanıyordu.
2. Kart içeriği **üstten** hizalıydı; etiketler bir ya da iki satır olduğu
   için ikonlar aynı yatayda durmuyordu.

**Tek kalan kart tam genişlik alıyor, ortalanmıyor:** ortalamak iki çeyrek
boşluk bırakır ve kartın sol kenarı sayfanın öteki bölümleriyle hizasını
kaybederdi — brief'in "kenar boşlukları aynı hizada başlasın" maddesi tam
bunu istiyor. Yatay kaydırmalı şerit **seçilmedi**: yedi kısayolun kaçının
olduğu tek bakışta görünmez olurdu ve kaydırma göstergesi olmayan bir şerit,
P169'da tablolarda düzelttiğimiz "veri eksik sanma" kusurunu geri getirirdi.

İçerik `justify-center` + `min-h-24` ile dikey ortalandı; düzenleme okları
kaba işaretçide 44 px oldu.

### 4.2 Takvim — ajanda artık gerçek bir görünüm

P169'da ajanda, `sm`de ay ızgarasının **yerine geçen** bir kipti. Bunun
somut kusuru: araç çubuğundaki **"Ay" düğmesi basılıyor ve hiçbir şey
olmuyordu** — yani bir anahtar vardı ve yalan söylüyordu.

Değişenler:

* **Ajanda dördüncü bir görünüm** oldu (`Ajanda · Gün · Hafta · Ay`), dar
  ekranda **varsayılan**. Kullanıcı bir kez seçim yaparsa otomatik karar
  susuyor — bayrak olmasaydı pencereyi daraltan kullanıcının seçimi her
  seferinde ezilirdi.
* **Ay ızgarası dar ekranda okunur:** olay adı yerine **nokta**, hücre
  yüksekliği 80 → 56 px. 45 px'lik bir hücrede olay adı iki harfe düşüyordu;
  okunmayan bir metin bilgi taşımaz, yalnız yer kaplar. Nokta "bu günde bir
  şey var" bilgisini tam taşır, sayısı da görünür.
* **Sabit yükseklik + içeride kaydırma:** ay değiştirmek olay sayısını
  değiştirir; kap serbest büyüseydi sayfanın altındaki her şey yukarı
  çekilirdi.
* **Açılışta bugüne kaydırma** — ama sayfa değil **kap**. `scrollIntoView`
  ataları da kaydırır ve pano sayfası takvimin bulunduğu yere zıplardı;
  bunun yerine kabın `scrollTop`u doğrudan yazılıyor.
* **"Bugün" vurgusu renkten ibaret değil:** accent renge ek olarak **rozet**.
  Renk tek başına yeterli bir işaret değil — renk körlüğünde ve düşük
  kontrastlı ortamda kaybolur.
* **Satırlar zaman çizgisi gibi:** ajandada saat başa alındı, sabit genişlikli
  bir sütunda hizalı; ikinci satırda tekrarlanmıyor.
* **Boş günler çizilmiyor.** Otuz satırlık bir "hiçbir şey yok" listesi,
  gerçek olayları görünmez kılardı.
* **Kaydırma jesti eklenmedi.** Dikey kaydıran bir listede yatay sürtme,
  iOS'un kenar geri jestiyle ve listenin kendi kaydırmasıyla çakışır;
  ileri/geri düğmeleri kaba işaretçide zaten 44 px.

### 4.3 Sayfanın geri kalanı

| Kontrol | Sonuç |
|---|---|
| Finansal kartlar tek sütuna iniyor mu | **Evet** (`sm:grid-cols-2 xl:grid-cols-3` → <640'ta tek sütun). Değişiklik gerekmedi. |
| Excel/PDF ikonları dokunulabilir mi | **Hayır idi.** 32×32'lik düğmeler P169'un kuralıyla 32×**44** oluyordu — yükseklik düzeliyor, genişlik kalıyordu. `yz-dokunma-44` sınıfı eklendi (6 simge düğmesi). Genel bir `min-width: 44px` **ölçülüp elendi**: 360 px'te takvim ay ızgarasında bir hücre ~40 px'e düşüyor ve ızgara taşardı. |
| 3D sahne sayfayı yavaşlatıyor mu | **Hayır.** P169'da <1024'te sadeleştirildi, tembel yükleniyor ve dokunma kapısı var. |
| "Paneli düzenle" mobilde çalışıyor mu | **Çalışmıyordu.** Sayfa eylem yuvası kabuğun `hidden … lg:flex` çubuğunun **içindeydi**; o çubuk dar ekranda `display:none` ama DOM'da duruyor, portal hedefi buluyor ve düğme **görünmez bir kutuda** kalıyordu. Yani "Paneli düzenle" telefonda ve tablette hiç basılamıyordu. Yuva artık `lg` altında **hiç monte edilmiyor** ve bileşen kendi geri düşüşüyle eylemleri sayfa içinde, başlığın altında çiziyor. |

---

## 4.4 Takım sonuçları

| Takım | Sonuç |
|---|---|
| Web (`vitest` + `next build`) | **142 dosya / 1346 test yeşil**, derleme temiz |
| Mobil (`flutter test`) | **1917 test yeşil**, `flutter analyze` temiz |
| Backend (`pytest`) | **1820 test yeşil**, 1 atlanan (fixture kaynaklı, turdan önce de vardı) |

Bu turda **güncellenen dört kilit** var ve dördü de bilinçli:

* `yonetim-bolunmesi.test.ts` (P167 §6.1) KVKK metninin tesis menüsünde
  `yonetim` grubunda olmasını kilitliyordu. Kilit gevşetilmedi, **yön
  değiştirdi**: satırın gerçekten silinmediğini, `platform` grubunda
  durduğunu ve tesis rol haritasından çıktığını ölçen yeni bir iddia
  eklendi. Yoksa "tesis menüsünde yok" cümlesi, gerçekten silinmiş olmayı
  da geçirirdi — ki o dosyanın varlık sebebi tam olarak budur.
* `profil.dom.test.ts` beş bölüm bekliyordu; artık altı (Yasal Metinler).
* `backend/tests/yetki/rol-matrisi.txt` — **elle yazılmadı, üretildi**
  (`YETKI_KILIT_GUNCELLE=1`). Üretim aynı zamanda bir doğrulamadır: yeni
  iki uç gerçekten yalnız `admin`e açık, `GET /kvkk/onaylarim` gerçekten
  yedi rolün hepsine.
* `test_secdef_kapsam.py` envanteri — yeni üç `SECURITY DEFINER` işlev
  kaydedildi. Bu test bir **gözden geçirme kapısıdır**: envantere
  girmemiş bir işlev şemaya giremez, ve envanterdeki `admin` kapısı
  davranışsal olarak da sınanır (yönetici o uçlarda 403 almalı).

---

## 5. Test sunucusunda telefondan ne kontrol edeceksin

1. **Üst bar** — 360 px genişlikte "yönetiyor" yazısı görünmemeli, yalnız
   simge; menüyü açınca çekmecede tam logo görünmeli. Tabletlerde (≥640)
   yazı geri gelmeli. Açık ve koyu temada ayrı bak.
2. **Özet → widget şeridi** — 7 kısayol 2 sütun; **sonuncusu tam genişlik**;
   ikonlar aynı yatayda; "Paneli düzenle" **başlığın altında görünmeli** ve
   basılabilmeli. Düzenleme kipinde ‹ × › okları parmakla vurulabilmeli.
3. **Özet → takvim** — açılışta **Ajanda** seçili gelmeli ve liste **bugüne
   kaydırılmış** olmalı, bugünün başlığında rozet olmalı. "Ay"a bas: ızgara
   **gerçekten** açılmalı ve hücrelerde gün numarası + noktalar okunmalı.
   Ay/hafta değiştirirken takvimin altındaki bölümler **zıplamamalı**.
4. **Özet → finans** — Excel/PDF ikonlarına parmakla vur; ıskalamamalı.
5. **Giriş** — telefon + parola gir, "Beni hatırla" işaretli gönder.
   Tarayıcı parolayı kaydetmeyi teklif etmeli. Çıkış yap → giriş ekranı
   **boş** gelmeli (tarayıcı kendi kayıtlı parolasını önerebilir, bu
   beklenen). Mobil uygulamada: çıkış sonrası alanlar **boş**, uygulamayı
   kapatıp açınca **dolu**.
6. **KVKK** — `panel.*` ile admin gir: menüde **Platform** grubunda
   "KVKK Metinleri" olmalı, önce tesis seçtirmeli. `app.*` ile yönetici gir:
   bu satır menüde **olmamalı** ve adresi elle yazınca girememeli.
   Her rolde `Profil → Yasal Metinler` açılmalı; beş sekme ve onay geçmişi
   görünmeli.
