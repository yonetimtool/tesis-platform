# P168 — tur raporu

Brief'in uyarısı haklıydı: bazı maddeler P167'de "bitti" diye raporlanmış
ama **test sunucusunda çalışmıyordu**. Her maddede önce ölçüm yapıldı,
sonra düzeltildi.

| Madde | Ölçülen durum | Sonuç |
|---|---|---|
| 1.1 Widget tıklama | `Kart` `href`'i **yaymıyordu** → href'siz `<a>` | düzeltildi |
| 1.2 Widget 6→7 | sınır 6, ızgara 6 sütun | düzeltildi |
| 1.3 "Paneli düzenle" konumu | sayfa başlığındaydı | üst bara taşındı |
| 2 İcra oluşturma | uç `admin`e kapalı + durum sözlüğü farklı | düzeltildi |
| 3 Rapor motoru | 13/13 kart var, **3 alan eksik** | tamamlandı |
| 4 SMS/E-posta | sayaç/etiket/segment var; sağlayıcı **"gönderildi" yalanı** | düzeltildi |
| 5 KVKK metinleri | tek tür vardı, beş tür isteniyor | kuruldu |
| 6 Mobil uyarlama | kısmi | karar tablosu + taşınanlar aşağıda |

---

# §1 — Özet sayfası

## 1.1 Widget tıklama hatasının kök nedeni

**Kusur:** `Kart` bileşeni `href` prop'unu **kabul etmiyor ve fazladan
prop'ları yaymıyordu**. Çağıranlar şunu yazıyordu:

```tsx
<Kart as="a" {...{ href: w.rota }}>
```

`href` bileşene **hiç ulaşmıyordu** ve `<a>` etiketi **href'siz**
çiziliyordu. Href'siz bir `<a>`:

- tıklanmaz,
- klavyeyle **odaklanamaz** (tab sırasında yok),
- ekran okuyucuya "bağlantı" diye duyurulmaz.

Yani kusur yalnızca fare kullanıcısını değil, klavye ve ekran okuyucu
kullanıcısını da vuruyordu.

**Derleyici de susmuştu:** JSX spread'i TypeScript'in fazla-özellik
denetiminden kaçar. Tip sistemi, test ve göz denetimi — üçü de
kaçırabilecek bir sınıf.

**Aynı kusur iki yerdeydi:** widget şeridi **ve finansal özet kartları**.
Brief yalnızca widget'ları sayıyordu; öteki de ölü bağlantıydı.

**Düzeltme:** `href` artık `Kart`ın **tipli** bir prop'u ve verilince Next
`Link` çizilir (istemci tarafı gezinme; ham `<a>` tam sayfa yenilemesi
yapardı). Yanlış kullanım artık **derleme hatası**.
`tests/pano-widget-tiklama.dom.test.ts` `getByRole("link")` ile ölçüyor —
href'siz bir `<a>` o sorguda **bulunmaz**, yani eski kod bu satırda düşerdi.

## 1.2 Yedi widget
Sınır tek yerde (`WIDGET_SINIRI`) ve ızgara geniş ekranda yedi eşit alan;
dar ekranda 2→3→4 diye kırılır (yedi kutu 60 px'e düşüp okunmaz olurdu).

## 1.3 "Paneli düzenle" üst barda
Bildirim ikonunun **solunda**. Kabuk sayfaya özel düğmeyi **tanımaz**:
`SayfaEylemleri` portalı ile sayfa kendi düğmesini kabuğun açtığı **boş
yuvaya** koyar. Düğmeyi `AppShell`e taşımak, kabuğun yavaş yavaş bütün
sayfaların mantığını toplaması olurdu.

**Yuva yoksa eylemler yerinde çizilir.** İlk yazımda `null` dönüyordu ve bu
sessiz bir kayıptı — kabuk yuvayı kaldırsa düğmeler ekrandan tamamen
silinirdi.

---

# §2 — İcra dosyaları

## "Yalnız görüntüleme" — iki kök neden

1. **Yazma ucu `require_role("admin")` idi.** Yönetici sayfayı açıyor,
   "+ Yeni" düğmesi **çizilmiyor** (basılacak ama 403 alacak bir düğme
   çizmemek doğru karardı) — yani sayfa yönetici için gerçekten salt
   görüntülemeydi.
2. **Durum sözlüğü brief'inkiyle aynı değildi** (`acik/takipte/
   tahsil_edildi/kapandi`), yani istenen seçenekler açılır listede
   **hiç yoktu**.

## Göç 0062 — enum yeniden kuruldu

Yeni değerleri ekleyip eskileri bırakmak, tabloda **iki sözlük** yaşatmak
olurdu: açılır liste beş değer gösterirken veritabanı dokuz değer kabul
eder ve eski satırlar listede karşılığı olmayan bir durumla görünürdü.

**Bir ayrım kayboluyor ve gizlenmiyor:** `tahsil_edildi` → `kapandi`.
Dosyanın *neden* kapandığı durum alanından artık okunamıyor; tahsilatın
kendisi `dues_payment` defterinde durur. Dev veritabanında etkilenen satır
**sıfır** ölçüldü.

## Yeni: silme ucu

"Finansal kayıt silinmez" ilkesi **defter** içindir. İcra dosyası defter
satırı **değil, süreç kaydıdır** — borç `dues_assessment`ta durur ve
dosyaya kopyalanmaz; silmek hiçbir tutarı yok etmez. Testi var
(`test_SILME_BORCU_yok_etmez`).

Sayfa: veriliş tarihi kolonu (brief'te vardı, tabloda yoktu), Düzenle/Sil
eylemleri, aynı modal iki kipte, veriliş tarihi varsayılan **bugün**.

---

# §3 — Rapor motoru durum tablosu

Ölçüm `backend/app/routers/rapor_motoru.py` kaynağından yapıldı:

| Rapor | Kart | Üretim dalı | Eksik alan |
|---|---|---|---|
| Borç-Alacak Listesi | var | var | — |
| Detaylı Borç Listesi | var | var | — |
| Site Sakinleri Listesi | var | var | **iletişim bilgileri** |
| Dönemsel Bakiye | var | var | — |
| Notlar | var | var | — |
| Kasa Ekstresi | var | var | — |
| Firma Ekstresi | var | var | — |
| Hesap Ekstresi | var | var | — |
| İşletme Defteri | var | var | — |
| Finansal Hareketler | var | var | — |
| Makbuz Dökümü | var | var | **tür** |
| Gelir-Gider Özet | var | var | — |
| İhtar Yazısı | var | var | **tarih** |

**13/13 kartın kartı ve üretim dalı vardı** — brief'in "kısmen yapılmış"
tespiti alan düzeyindeydi, rapor düzeyinde değil. Üç eksik kapatıldı.

**İletişim kutusu SÜTUN AÇAR, değeri boşaltmaz:** boş bir "Telefon"
sütunu "bu kişinin telefonu yok" demek olurdu — oysa göstermemeyi biz
seçtik. **Varsayılan kapalı:** telefon/e-posta kişisel veridir ve kapıya
asılacak bir listede varsayılan olarak bulunmamalı.

**Tarih varsayılanları:** İlk Tarih = yılbaşı, Son Tarih = bugün.
`tazminat_tarihi` **bilerek boş** kalır — o "hangi tarihe göre gecikme
hesaplansın" sorusudur; yılbaşı yapsaydık tazminatı **yılın başına** göre
hesaplatırdık (sessizce yanlış rakam).

---

# §4 — SMS / E-posta

## En ciddi bulgu: sağlayıcı yokken "gönderildi" yalanı

`LogSmsSaglayici` hiçbir şey **göndermeden** `"gonderildi"` dönüyordu.
Yönetici "Gönderim" listesinde yeşil bir satır görüyor, sakin hiçbir şey
almıyordu. Bir SMS'in gidip gitmediği **hukuki** bir sorudur (bildirim
kanıtı); yanlış bir kayıt, olmayan bir bildirimi **ispat gibi** gösterirdi.

Artık `yapilandirilmadi` dönüyor. **`basarisiz` değil ve bu bilinçli:**
başarısızlık "denedik, olmadı" der ve kullanıcıyı "tekrar dene"ye iter;
oysa **hiç denenmedi** ve yapılması gereken **ayarları doldurmaktır**.
Ayrı bir durum, arayüzün doğru eylemi önerebilmesini sağlar.

## Göç 0063 — tesis başına yapılandırma

Sağlayıcı bilgisi bugüne kadar **ENV**'deydi, yani **bütün tesisler için
tekti**. Çoklu tesisli bir platformda bu yanlış: her tesis kendi SMS
bayiliğini kullanır ve faturası kendine çıkar.

**ENV yedek kalır:** kayıt yoksa mevcut ENV yapılandırması kullanılır;
böylece bugün çalışan kurulumlar bozulmaz.

## Sırlar arayüze hiç dönmez — "maskeli" bile değil

`****` gibi bir metin döndürmek kolay ama **yanlış** olurdu: maskeli değer
de bir **değerdir**, forma girer ve "kaydet"te gerçek parolanın üzerine
yazılırdı. Yalnızca `*_var` bayrakları döner; boş bırakılan parola
**mevcudu korur**, açıkça boş dizge **temizler**.

## Diğerleri

- **Test gönderimi gerçekten gönderir** ("ayarlar dolu mu" diye bakmak
  yanlış parolayı yakalamaz) ama **geçmişe yazılmaz** (test bir bildirim
  değildir; "kime ne gönderdik" defterini kirletirdi).
- **Kota tesis başına** ve `yapilandirilmadi` kayıtları kotadan **düşmez**
  — yoksa ayarlarını doldurmamış bir tesis, hiç mesaj göndermeden
  kotasını tüketirdi.
- **Hazır şablonlar** brief'in listesiyle birebir tamamlandı: SMS'te
  "Davetiye" ve "Yeni Duyuru", e-postada "Borç Girişi", "Tahsilat Girişi",
  "Toplantı Çağrısı" **eksikti**.
- **Sekmeli yapı**: Gönderim · SMS Şablonları · E-posta Şablonları ·
  Ayarlar. Sekme **adreste** tutulur (paylaşılan bağlantıda aynı sekme).
- **Etiket çipleri**: önceki hâl tek satırlık bir ipucuydu ve kullanıcının
  etiketi **doğru yazmasını** bekliyordu; tek harf hatası (`{bakiyee}`)
  mesajda olduğu gibi görünüyordu. Çip, imlecin olduğu yere ekler.
- **Canlı SMS sayacı** (`lib/sms-olcu.ts`): `ı ğ ş` GSM-7'de **yok**,
  `ö ü` **var**, büyük `Ç` **var** ama küçük `ç` **yok**. Kabaca "Türkçe
  harf varsa 70" yazan bir sayaç `ç` içeren 150 karakterlik bir mesajı üç
  SMS gösterip kullanıcıyı gereksiz yere metni kısaltmaya iterdi.
- **Zengin metin editörü** (e-posta gövdesi): dış kütüphane **yok**;
  `document.execCommand` kullanıldı ve bu **bilinçli bir taviz** — API
  "deprecated" ama yerine konan bir şey yok ve bütün güncel tarayıcılarda
  çalışıyor. Alternatif, `Range` üzerinde kendi biçimlendirme motorumuzu
  yazmaktı.

## §4'te yapılmayan — dürüstçe

- **E-posta şablonuna dosya eki.** Zengin editörde "dosya ekle" **yok**:
  ek göndermek SMTP gönderim hattının MIME çok-parçalı gövde üretmesini
  gerektirir ve bu, gönderim yolunda ayrı bir iştir. Görsel **URL ile**
  eklenebiliyor (e-posta istemcilerinin çoğu gömülü görseli zaten engeller).
- **Kuyruk + yeniden deneme.** `mesaj_durum` enum'unda `kuyrukta` değeri
  var ama hiçbir yol onu yazmıyor; gönderim istek içinde senkron. Bu sınır
  P154'ten beri `app/gonderim.py` sonunda yazılı ve bu turda da kapanmadı.

---

# §5 — KVKK ve yasal metinler

Brief: *"Mevcut `kvkk_metin` tablosunu incele; varsa üzerine kur, yeniden
yazma."* Doğru karar: tablo P36'da zaten doğru kurulmuş — sürümleme var,
yayınlanmış metin **değiştirilemiyor**, onay **sürüme** bağlı. Eksik olan
tek şey metnin **türüydü**.

## Göç 0064 — beş tür

Sürüm artık **tür başına** ilerler: `(tenant, surum)` → `(tenant, tur,
surum)`. Aksi hâlde gizlilik politikası yayınlamak aydınlatma metninin
sürüm numarasını atlatırdı ve *"v3'ü onayladım"* cümlesi hangi metne ait
olduğu belirsiz kalırdı.

**Onay da tür başına:** `(tenant, user, surum)` → `(tenant, user, tur,
surum)`. Bu kısıt genişlemeseydi, kullanıcı gizlilik politikasının 1.
sürümünü onayladığında aydınlatma metninin 1. sürümü de **onaylanmış
sayılırdı** — hukuken yanlış, ve sessiz.

## "Yeniden onay gerektirir" bayrağı

Gerçek bir ihtiyaç: bir yazım hatasını düzeltmek için çıkılan sürüm 200
sakini yeniden onay ekranına sokmamalı; esasa ilişkin bir değişiklik
**sokmalı**.

**Varsayılan `true` ve bu bilinçli:** güvenli yön **sormaktır**. `false`
varsayılan olsaydı, esaslı bir değişikliği yayınlayan yönetici kutuyu
işaretlemeyi unuttuğunda kimseye sorulmaz ve bu **sessizce** hukuki bir
eksiklik olurdu.

**Hiç onaylamamış kullanıcıya her zaman sorulur** — bayrak `false` olsa
bile. Metni hiç görmemiş birine sormamak, aydınlatmanın kendisini atlamak
olurdu.

## Yürürlük durumu neden kolon değil

Ayrı bir `yururlukte` kolonu **açılmadı**: iki satırın aynı anda
yürürlükte olması ya da hiçbirinin olmaması mümkün hâle gelirdi ve bu,
"hangi metni onaylıyorum" sorusunu cevapsız bırakırdı. Yürürlükte olan,
**tür başına en yüksek sürümdür** — türetilir, saklanmaz.

## Bir davranış değişikliği

`onayladigi_surum` artık kullanıcının **son onayını** döner; eskiden
güncel sürüme onay yoksa `None` dönüyordu. Eski davranış **daha az
dürüsttü**: alanın adı "onayladığı sürüm" ve kullanıcı gerçekten 1.
sürümü onaylamıştı. Yeni değer ayrıca **gerekli**: yeniden onay bayrağı
tam olarak "onayladığı sürüm < güncel sürüm" farkını kullanıyor.

---

# §6 — Mobil uyarlama: neyin taşındığı ve neden

## Taşınanlar

| Ekran | Karar | Gerekçe |
|---|---|---|
| **KVKK / Yasal Metinler** | **taşındı** | Brief §5 açıkça istiyor: kullanıcı metinlere ulaşabilmeli ve **onay geçmişini** görebilmeli. Bu, kullanıcının **kendi hakkı** — masaüstü/mobil ayrımı yapılamaz. |
| **Doküman okuma** | (P167 ek'te taşındı) | Sakinin yönetim planına telefondan bakması makul; görünürlük bayrağıyla sınırlı. |
| **Üst bar: kısayol ızgarası** | **eklendi** | Ana ekran karolarını düzenleme ekranı **zaten vardı** ama ona yalnızca menüden ulaşılıyordu; en çok kullanılan kısayolları düzenlemek için önce menüyü açmak gerekiyordu. |

## Taşınmayanlar — ve nedenleri

| Ekran | Karar | Gerekçe |
|---|---|---|
| **Özet paneli (widget + finans kartları + takvim)** | **hayır** | Mobilin **kendi ana ekranı var** ve o ekran mobil için tasarlandı (P145 dizisi): hızlı erişim ızgarası, akış, hava durumu. Web panelini mobile taşımak, iki farklı ana ekranı yan yana koymak ve kullanıcıya "hangisi benim ekranım" dedirtmek olurdu. |
| **SMS/E-posta şablonları ve gönderim** | **hayır** | Şablon yazmak uzun metin girişi + etiket yerleştirme + karakter bütçesi yönetimidir; toplu gönderim ise **geri alınamaz** bir işlemdir. İkisi de masa başı işi. Yanlış segmente gönderilen 300 SMS'in geri dönüşü yok. |
| **Karar defteri** | **hayır** | Karar metni yazmak uzun metin girişidir. (P167'de de aynı karar verilmişti.) |
| **Doküman *yükleme*** | **hayır** | Sürükle-bırak, 25 MB dosya, çoklu seçim — masa başı işi. Okuma tarafı taşındı. |
| **İcra dosyaları** | **hayır** | Hukuki dosya takibi masa başı işi; brief de "görüntüleme yeterli olabilir" diyor. Uçlar rol kapısıyla hazır — mobil bir gün isterse ekran işi kalır. |
| **Rapor motoru** | **hayır** | On beş raporluk bir yapılandırma ızgarası ve on alanlı bir modal telefonda aracı yanlış işe koşmaktır. Sakinin mali ihtiyacı (aidatım, borcum, makbuzum) **kendi ekranlarında** zaten karşılanıyor; yöneticinin rapor ihtiyacı masa başındadır. |
| **Üst barda global arama** | **hayır (bugün)** | Mobilde ekran-içi aramalar var (site kuralları, dokümanlar). **Global** arama, web'in `/arama` ucuna karşılık gelen bir mobil akış gerektirir; düğmeyi şimdi koymak, hiçbir yere gitmeyen bir düğme çizmek olurdu — bu turda düzelttiğim kusurun ta kendisi. |

## Mobil tasarım dili hakkında dürüst not

Brief "web'deki yeni tasarım dili mobile taşınacak" diyor. Mobil kabuk
**kendi tasarım sistemine** sahip (`core/theme/home_tokens.dart`,
`HomeSurface`) ve P145 dizisinde referans görsellere göre kuruldu. Web'in
`--yz-*` metalik token'larını mobile taşımak, çalışan ve tutarlı bir
sistemi ikinci bir sistemle değiştirmek olurdu — bu, bu turun işi değil ve
tek bir commit'te yapılırsa **her mobil ekranı** riske atardı.

Bu turda mobile taşınan şey **yapı**dır (üst bar kısayolu, yeni ekranlar),
**boya** değil.

---

# Yeni uçlar ve göçler

| Uç | Rol | Not |
|---|---|---|
| `DELETE /finans/icra-dosyalari/{id}` | admin, yönetici | **yeni** |
| `POST/PATCH /finans/icra-dosyalari` | admin, **+yönetici** | yetki genişledi |
| `GET/PUT /mesaj-ayarlari` | admin, yönetici | **yeni** |
| `POST /mesaj-ayarlari/test` | admin, yönetici | **yeni** |
| `GET /kvkk/metin?tur=` · `/kvkk/metinler?tur=` | mevcut roller | tür süzgeci |
| `GET /kvkk/durum?tur=` · `POST /kvkk/onay` | tüm roller | tür alanı |

**Göçler:** `0062_icra_durum_yeniden`, `0063_mesaj_yapilandirma`,
`0064_kvkk_metin_turleri`.

---

# Test çıktısı

- **Backend: `1814 geçti, 0 düştü`** (30 dk 15 sn; 1 atlandı — önceden var
  olan fixture atlaması).
- **Web: 135 dosya / 1297 test yeşil**; `tsc --noEmit` ve `next build` temiz.
- **Mobil: 1912 geçti, 0 düştü**; `flutter analyze` temiz.

## Yol boyunca düşen testler

**Backend (3).** İkisi `yapilandirilmadi` değişikliğinin doğal sonucuydu —
`test_gonderim_katmani`'nin kendi açıklaması zaten *"ölçülen şey
`gonderildi` DEMİYOR olması"* diyordu; yeni durum o amacı daha keskin
karşılıyor. Üçüncüsü sayfalama kararlılık kilidiydi: KVKK durum sorgusuna
`id` kırıcısı eklendi. Kısıt (`uq_kvkk_onay`) onu zaten kararlı kılıyordu,
ama kararlılığın bir **kısıta bağlı** olması, o kısıt bir gün
değiştiğinde **sessizce** bozulması demekti.

**Mobil (4, P167'den kalma).** `mobile/` tam takımı P167'de
koşulmamıştı — yalnızca yeni dosyanın testi ve `analyze`. Bu turda
koşulunca dört kırmızı çıktı: menü kilidine işlenmemiş `dokumanlar`
girişi, iki yerleşim kilidi (üst bara eklenen ikon; kasıtlı, kilit
yenilendi ve diff satır satır doğrulandı) ve sözlük çıtçıtına eklenmesi
gereken "KB" birim kısaltması. Bu ders kalıcı nota yazıldı.

**Bir ölçüm hatası — dürüstçe.** Mobil takımı backend takımıyla **aynı
anda** koşturunca 16 test düştü; hepsi kare zamanlamasına duyarlı widget
testleriydi ve izole koşumda geçiyordu. Yüksüz tam koşumda **1912/1912**
geçti. Kodda değişiklik yapılmadı.

---

# Test sunucusunda ne göreceksiniz

1. **Özet.** Widget'lara tıklayın — **artık gidiyorlar** (ve Tab tuşuyla
   da odaklanılıyor). Şerit **yedi** kutu. Sağ üstte, bildirim ikonunun
   solunda **"Paneli düzenle"**; açınca yanında "Varsayılana dön" belirir.
   Finansal özet kartları da artık tıklanıyor.
2. **İcra Dosyaları.** **Yönetici hesabıyla** girin: "+ Yeni" düğmesi
   **var**. Modal: Dosya No, Kişi (arama), Veriliş Tarihi (bugün dolu),
   Açıklama, Avukat, Dosya Durumu — açılır listede **Bağınız · Beklemede ·
   Avukatta · Mahkeme Sürecinde · Kapandı**. Sağda kişinin açık evrakları.
   Tabloda **Veriliş Tarihi** kolonu ve satırda **Düzenle / Sil**.
3. **Raporlar.** Üç kategori, 13 kart. "Site Sakinleri"nde artık
   **"İletişim Bilgilerini Göster"** kutusu var (kapalı başlar; açınca
   Telefon ve E-posta **sütunları** gelir). "Makbuz Dökümü"nde **Tür**,
   "İhtar Yazısı"nda **Tarih** alanı var. Her modalda İlk Tarih
   **yılbaşı**, Son Tarih **bugün** dolu gelir.
4. **SMS/E-Posta Yönetimi.** Dört sekme. **SMS Şablonları**'nda "+ Yeni":
   gövdenin altında **canlı sayaç** ("Kalan Karakter Sayısı" + "2 SMS") ve
   Türkçe harf uyarısı; üstte **etiket çipleri** — tıklayınca imlecin
   olduğu yere `{bakiye}` girer. **E-posta Şablonları**'nda gövde
   **zengin metin editörü**.
5. **Ayarlar sekmesi.** En üstte **SMS: yapılandırılmadı** rozeti.
   Sağlayıcı/kullanıcı/parola/başlık ve SMTP alanları; parola alanı **boş**
   ve altında "kayıtlı bir parola var" yazar. **Test Gönder**'e basın:
   sonuç **"yapilandirilmadi"** döner — sessizce "gönderildi" **demez**.
6. **KVKK ve Yasal Metinler.** Beş sekme. Sürüm tablosunda **Yürürlükte /
   Geçmiş sürüm** rozeti ve **Yeniden Onay** sütunu. Yeni sürüm formunda
   zengin editör ve **"Kullanıcılardan yeniden onay istensin"** kutusu
   (varsayılan **açık**). Kutuyu kapatıp yeni sürüm yayınlayın: önceki
   sürümü onaylamış kullanıcıya **yeniden sorulmaz**.
7. **Mobil.** Ayarlar → **Yasal Metinler**: beş sekme, her birinde metin +
   sürüm + "Onayladığınız sürüm: N" ya da "Bu metni henüz onaylamadınız".
   Yayınlanmamış metin **hata gibi değil**, "henüz yayınlanmamış" diye
   görünür. Üst barda yeni **ızgara/kısayol** düğmesi.
