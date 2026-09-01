# P193 — Kurulum akışı boşlukları · kararlar ve gerekçeler

Bu tur, `docs/yonetici-kurulum-rehberi.md` sonundaki
**"C) Kurulum sırasında olması gereken ama olmayan şeyler"** listesindeki
14 maddeyi kapatıyor. Her bölümün sonunda **NE ÖLÇTÜM** başlığı var:
yalnız "test yeşil" değil, geliştirme ortamında akışı çalıştırıp ne
gördüğüm yazılı. Ölçemediklerim ayrı listeleniyor.

---

## Bölüm 1 — Excel/toplu aktarımda e-posta (14 eksik · madde 4)

### Sorun
Tek tek kullanıcı eklemede e-posta **zorunlu**, Excel aktarımında
**opsiyoneldi**. Aynı ürünün iki kapısı iki farklı kural uyguluyordu.
Sonuç: 120 kişilik bir dosyayı e-postasız aktaran yönetici, 120 kişilik
bir "hayalet" kadro yaratıyordu — hesaplar açık ama kimse giremiyor,
çünkü SMS varsayılan olarak kapalı, yani davet gidecek tek kanal e-posta.
Hiçbir ekran bunu söylemiyordu.

### Kararlar

**K1.1 — `kisi` türünde e-posta zorunlu alan oldu.**
`ice_aktarim.py` içindeki alan tanımı `zorunlu=True` yapıldı; boş satır
`zorunlu_alan_eksik` ile raporlanıyor. Zorunluluk tek yerde tanımlı
olduğu için hem sunucu doğrulaması hem panelin "Zorunlu sütunlar"
bilgisi hem de şablon aynı listeden besleniyor — ikisi ayrışamaz.

**K1.2 — Varsayılan davranış: "sorunlu satır varsa hiçbir şey yazma".**
İstek gövdesine `sorunlulari_atla` eklendi, **varsayılanı `false`**.
Aktarım artık iki geçişli: önce kuru geçiş, hata varsa `uygulanmadi=true`
ile rapor dönülür ve **tek satır yazılmaz**; kullanıcı kutucuğu bilerek
işaretlerse ikinci geçiş uygulanır.

*Neden SAVEPOINT/rollback değil:* satır uygulanırken davet e-postası
gönderiliyor. Veritabanını geri alabilirim, gönderilmiş e-postayı
alamam. "Yarısı davet aldı, kayıt yok" hali, hiç yazmamaktan daha kötü.
Bu yüzden kuru geçiş ayrı bir tam tur olarak koşuyor.

**K1.3 — Davet gerçekten gitti mi, sayılıyor.**
`davet_gonderildi` / `davet_basarisiz` / `davet_hatalari[]` sonuca
eklendi ve denetim kaydına (audit meta) yazılıyor. "Kaç kişi eklendi"
ile "kaç kişiye ulaşıldı" ayrı sorulardır; eskiden ikincisi hiç
sorulmuyordu. Panelde başarısız davetler satır numarasıyla ve
"bu kişiler giriş yapamaz" uyarısıyla gösteriliyor.

**K1.4 — Panelde önizleme bloklayıcı.**
Sorunlu satır varken **Aktar düğmesi kapalı**; yanında nedeni ve
"Sorunlu satırları atla" kutucuğu var. Çalışmayacak bir düğmeyi basılır
bırakmak kullanıcıya "sistem bozuk" hissi verir.

**K1.5 — Sayılar etiketlendi.** Okunan / Geçerli / Zaten kayıtlı /
Sorunlu ayrı ayrı yazılıyor (7 dilde). "4 satır işlendi" cümlesi
yöneticiye hiçbir şey söylemiyordu.

### NE ÖLÇTÜM

Geliştirme ortamında, `acme-plaza` tesisinde `yonetici@acme.com` ile
giriş yapıp **gerçek uca** (`POST /import/kisi`) 4 satırlık bir dosya
gönderdim: 2 satır sağlam, 1 satır e-postasız, 1 satır bozuk e-postalı.
Gördüğüm:

```
KISI ALANLARI:  ad -> ZORUNLU / telefon -> ZORUNLU / eposta -> ZORUNLU
                daire_no -> opsiyonel / rol_tipi -> opsiyonel

=== 1) ÖNİZLEME (yalniz_dogrula=true) ===
  HTTP 201 · okunan=4  gecerli=2  atlanan=0  sorunlu=2
   SATIR 3 · eposta -> Zorunlu alan boş.
   SATIR 4 · eposta -> Geçerli bir e-posta adresi girin.

=== 2) AKTAR (sorunlulari_atla YOK) ===
  HTTP 201 · uygulanmadi = True · aktarim_id = None
  → HİÇBİR SATIR YAZILMADI (veritabanında kontrol edildi)

=== 3) AKTAR (sorunlulari_atla=true) ===
  HTTP 201 · uygulanmadi = False
  olusan=2  sorunlu=2  davet_gonderildi=0  davet_basarisiz=2
   DAVET SATIR 2 -> Davet e-postası gönderilemedi...
   DAVET SATIR 5 -> Davet e-postası gönderilemedi...
```

Son satır beklenmedik ama **doğru** bir bulgu: geliştirme ortamında
SMTP yok, dolayısıyla davetlerin hiçbiri gitmiyor. Eskiden bu tamamen
görünmezdi — aktarım "2 kişi eklendi" der, kimse giremezdi. Artık
yönetici bunu ekranda görüyor. Prod'da SMTP çalıştığı için orada
`davet_gonderildi=2` beklenir; **bu sayının prod'da doğrulanması
gerekir** (aşağıdaki "ölçemediklerim").

Ekran tarafı: `admin-web/tests/ice-aktarim.dom.test.ts` sayfayı gerçekten
render edip ölçüyor (8 test, hepsi geçiyor) — hem düşen hem geçen durum:
sorunlu satırda Aktar **kapalı** ve "Aktarım YAPILMADI" + satır numarası
görünüyor; kutucuk işaretlenince düğme **açılıyor** ve istek gövdesinde
`sorunlulari_atla: true` gidiyor; davet özeti ve uyarısı basılıyor.

Backend: `backend/tests/test_ice_aktarim.py` **18 test geçti**.

### Ölçemediklerim (prod'da/cihazda doğrulanmalı)
- Gerçek SMTP ile `davet_gonderildi` sayısının dolması ve e-postanın
  gelen kutusuna düşmesi.
- Gerçek bir `.xlsx` dosyasıyla tarayıcıdan yükleme (dosyayı panel
  ayrıştırıyor; testler yapıştırılan metinle ölçüyor — ayrıştırma yolu
  aynı, dosya okuma katmanı değil).

---

## Bölüm 2 — Kurulum sihirbazı (14 eksik · maddeler 11, 12, 13, 14)

### Sorun
Sihirbaz sekiz adımdı ve kurulumun **en kritik iki bağımlılığını** hiç
sormuyordu: e-posta gönderimi (davetlerin gittiği tek kanal) ve kasa
(tahsilatın yazıldığı yer). Ayrıca hiçbir adım "yapmazsan ne olmaz"
demiyordu; yönetici kasayı atlıyor, sonucu ilk tahsilatı girmeye
çalışırken öğreniyordu.

### Kararlar

**K2.1 — Dört yeni adım. Sekiz → on iki.**

| Adım | Neden | Zorunlu mu |
|---|---|---|
| **E-posta gönderimi** (sakinden hemen sonra) | Davetler e-postayla gidiyor; çalışmıyorsa açılan hesapların hiçbirine girilemez ve bu ancak şikâyet gelince anlaşılır. | Evet |
| **Kasa** (aidattan önce) | Tahsilat bir kasaya yazılır. Kasasız tesiste borç yazılabilir, para giremez. | Evet |
| **Rezervasyon alanları** | Tanımsızken modül sessizce boş görünüyor; kullanıcı bozuk sanıyor. | Hayır |
| **Sayaçlar** | Aynı sebep. | Hayır |

Sıra tesadüf değil ve testle kilitli: e-posta **sakinden hemen sonra**
(ilk toplu davet oradan çıkar; önce yüzlerce hesap açıp sonra
"e-postam çalışmıyormuş" demek, davetleri tek tek yeniden göndermek
demektir), kasa **aidattan önce** (önce para kutusu, sonra borç).

*Görev kategorisi* rehberde eksik sayılmıştı (madde 12) ama sihirbazda
**zaten var**: `gorev_alani` adımının sunucudaki ölçüsü `task_category`
sayısıdır. Rehberdeki bu satır yanlıştı; §8'de düzeltiliyor.

**K2.2 — E-posta adımı sayılamaz, ölçülür.**
Öteki adımlar bir tablo satırını sayar; e-posta gönderimi sayılamaz —
tesis kendi SMTP'sini girmemiş olabilir ama **genel (ENV) ayardan**
çalışıyor olabilir. Adımın cevabı ancak sağlayıcı seçimi çalıştırılarak
bulunur, ve ölçüt **Mesajlar ekranındaki rozetle birebir aynı**
(`kanal_saglayicisi("eposta", ayar)` LOG sağlayıcısı mı döndürüyor).
Ayrı bir ölçüt yazmak ("smtp_host dolu mu"), ENV'de çalışan bir SMTP
varken sihirbazı yanlış uyarmak olurdu — P172 §1'de kapatılan kusurun
aynısı.

**K2.3 — "Zorunlu" kararı sunucuda, tek yerde.**
Her adım artık `zorunlu` bayrağıyla dönüyor ve sunucu ayrıca
`eksik_zorunlular[]` + `calisir` özetini veriyor. İstemci bunu kendi
listesinden türetseydi, yeni bir adım eklendiğinde iki liste ayrışırdı.

**K2.4 — İlerleme yüzdesi ile "çalışır mı" AYRI iki sayaç.**
Atlanan adım ilerlemeyi rahatlatır (bilinçli atlayan tesis %100'e
ulaşabilmeli) ama **özeti değiştirmez**: kasası olmayan tesis, adım
atlandı diye tahsilat yapamaz. Bu ayrım hem backend hem panel testinde
kilitli.

**K2.5 — Her adım "ne engelliyor"u yazıyor.**
12 adım için 7 dilde engel metni. Biten adımda çizilmez — olmayan bir
sorunu anlatmak gürültüdür.

**K2.6 — Hatırlatıcıyı geri açma düğmesi sihirbaza taşındı (madde 14).**
Düğme yalnız `/settings`teydi, yani **yalnız admin** görüyordu; "Daha
sonra" diyen bir yöneticiye hatırlatma bir daha çıkmıyordu. Artık
sihirbaz sayfasının özet kartında — kullanıcı hatırlatmayı arıyorsa
sihirbaza bakar, platform ayarlarına değil. `/settings`teki düğme
duruyor (admin'in alışkanlığını bozmanın bir faydası yok).

**K2.7 — Özet alanları istemcide OPSİYONEL.**
Panel ve sunucu ayrı dağıtılıyor; yeni panel bir an eski sunucudan yanıt
alabilir. Alanları zorunlu saymak sayfayı tamamen boş bırakırdı — bu
ölçüldü (`undefined.length` ile çizim çöktü, test yazılırken görüldü).
Özet yoksa yalnız özet çizilmez; adım listesi çalışır.

**Yarım bırakıp devam etme** için kod yazılmadı ve bu bilinçli: durum
zaten saklanmıyor, **sayılıyor** (`routers/kurulum.py`). Yeni oturumda
aynı yerden devam edilir; ölçüldü (aşağıda). Sihirbaza yalnız bunu
söyleyen bir satır eklendi.

### NE ÖLÇTÜM

`acme-plaza` tesisinde, gerçek uca (`GET/PATCH /kurulum`) çağrı yaparak:

```
BASLANGIC: calisir=False eksik=['daire_tipi','eposta'] zorunlu=7 gecilen=10/12
  POST /unit-tipleri  -> 201
TIP EKLENDIKTEN SONRA: calisir=False eksik=['eposta'] gecilen=11/12
  eposta ATLANDI  -> eksik=['eposta'] calisir=False  gecilen=12/12   ← ayrım
  atlama GERI ALINDI -> gecilen=11/12
  YENI OTURUM ayni durumu goruyor: True (11/12)
```

Üç şey bu çıktıda görünüyor: (a) gerçek bir kayıt yaratınca adım kendi
kendine tamamlanıyor, (b) **atlamak ilerlemeyi 12/12 yapıyor ama
`calisir` yine `False`** — istenen ayrım tam olarak bu, (c) yeni bir
oturum aynı ilerlemeyi görüyor, yani "yarım bırakıp devam etme"
çalışıyor.

E-posta adımının ölçütünün Mesajlar ekranıyla aynı olduğunu da ayrıca
doğruladım:

```
GET  /mesaj-ayarlari       -> eposta_hazir=False  kaynak="yok"
POST /mesaj-ayarlari/test  -> {"durum":"yapilandirilmadi","hata":"smtp_yapilandirilmadi"}
```

Sihirbazın `eposta` adımı da `tamam=False` diyor — iki ekran aynı şeyi
söylüyor. (Dev ortamında SMTP yok; §1'deki davet bulgusuyla aynı kök.)

Ekran tarafı: yeni `admin-web/tests/kurulum-ozet.dom.test.ts` sayfayı
render ederek ölçüyor — Kasa ve E-posta adımlarının listede olması,
"Zorunlu adımlar: 5/7" ve engel cümleleri, hepsi tamamken "Tesis çalışır
durumda", **yöneticinin** hatırlatıcıyı geri açması (`localStorage`
kaydının gerçekten silindiği), ve eski sunucu yanıtının sayfayı
kırmaması. 5 test. `test_kurulum.py` 10 test geçti.

### Ölçemediklerim
- Tarayıcıda gerçek tıklama akışı (adım → hedef ekran → geri dön →
  adımın tamamlandığını gör). Ölçüm uç ve render seviyesinde.
- Gerçek SMTP'li bir tesiste `eposta` adımının `tamam=True` olması.

---

## Bölüm 3 — P192'nin üç ekran boşluğu (14 eksik · maddeler 7, 8, 9)

P192 üç yeteneği **sunucuya** ekledi ama panelde düğmeleri yoktu. Bu
bölümde önce uçların gerçekten çalıştığını ölçtüm, sonra ekranı yazdım.

### Kararlar

**K3.1 — Onay bekleyen giderde İPTAL değil, ONAYLA/REDDET çizilir.**
Henüz gerçekleşmemiş bir kaydı "ters kayıtla iptal etmek" anlamsızdır;
orada verilecek karar onaylanıp onaylanmayacağıdır. Satır
`onay_bekliyor` ise iki düğme, değilse eskisi gibi "İptal et".

**K3.2 — Yapılamayacak eylem çizilmez.**
Ters kaydın kendisi ters kayıtlanamaz (422), zaten düzeltilmiş tahakkuk
ikinci kez düzeltilemez (409). İkisinde de düğme yerine durum yazısı
çıkıyor ("Düzeltme satırı" / "Düzeltildi"). Düğmeyi çizip sunucuya
reddettirmek, kullanıcıya "sistem bozuk" dedirtir — P167'de kapatılan
kusur sınıfının aynısı.

**K3.3 — `iptal_edildi` yanıt şemasına eklendi.**
Panel "düzeltilebilir mi" sorusunu ancak böyle yanıtlayabilir. Alan
modelde vardı, dışarı verilmiyordu.

**K3.4 — Onay metinleri ne olacağını söyler.**
"Sil" demiyor ve silmiyor: *"Kayıt silinmez: listede ters bir satır daha
görünür."* Aksi hâlde kullanıcı listede iki satır görünce yanlışlık
sanardı.

**K3.5 — Ekstre hedef hesabı seçilebiliyor, ama zorunlu değil.**
Uç `kasa_id`yi P192'den beri kabul ediyordu; panel hiç göndermiyordu,
yani iki hesaplı bir tesiste ikinci hesabın ekstresi **sessizce**
varsayılan hesaba yazılıyor ve iki bakiye birden yanlış çıkıyordu.
Seçim dosya seçiminin **üstünde** duruyor (yanlış hesaba yazılan bir
ekstreyi geri almak satır satır iptal demek). Yalnız banka kasaları
listeleniyor; "Varsayılan banka hesabı" seçeneği duruyor çünkü tek
hesaplı bir tesisin her yüklemede seçim yapması gereksiz.

**K3.6 — Rol değiştirilmedi.** Bu üç uç `admin` rolünde. Yönetici zaten
gider **oluşturamıyor** (`POST /finans/hareketler` de admin); onay
yetkisini tek başına açmak, "giremediği bir kaydı onaylayan yönetici"
gibi tutarsız bir durum yaratırdı. Finans yazma rolünü genişletmek
P193'ün kapsamı değil, ayrı bir karar — **açık madde olarak bırakıldı**.

**K3.7 — Bir çökme düzeltildi (yan bulgu).** Borçlandırmalar sayfasının
üstündeki gecikme faizi kartı, önizleme yanıtında `items` alanı yoksa
`undefined.length` ile **tüm sayfayı** düşürüyordu. Test yazarken
ölçüldü, `items?` ile korundu.

### NE ÖLÇTÜM

**Uçlar (dev API'ye gerçek çağrı, `admin@acme.com`):**

```
=== A) GIDER ONAY/RET ===
  POST /finans/hareketler (durum=onay_bekliyor) -> 201  durum=onay_bekliyor
  POST .../onayla   -> 200  durum=odendi
  POST .../onayla (ikinci kez) -> 409 "Bu hareket onay beklemiyor."
  POST .../reddet   -> 200  durum=iptal
=== B) TAHAKKUK TERS KAYIT ===
  POST /dues/assessments/{id}/ters-kayit -> 201  tutar=75000
  POST (ikinci kez) -> 409 "Bu tahakkuk zaten düzeltilmiş."
=== C) EKSTRE HESAP SECIMI ===
  kasa_id VERILDI          -> 201 {"eklenen":1,"yinelenen":0}
  AYNI SATIR TEKRAR        -> 201 {"eklenen":0,"yinelenen":1}
  GECERSIZ kasa_id         -> 422 "Kasa bulunamadı."
  kasa_id YOK (varsayılana)-> 201 {"eklenen":1,"yinelenen":0}
```

Üçü de çalışıyor; hem geçen hem düşen durum denendi.

**Ekranlar** (`admin-web/tests/p193-finans-eylemleri.dom.test.ts`, 7 test,
sayfalar gerçekten render edilerek):
- Bekleyen satırda Onayla/Reddet **var**, ödenmiş satırda **yok** (orada
  İptal et var).
- Onayla → onay diyaloğu ("kasadan düşülecek") → `POST
  /api/panel/finans-hareketler/{id}/onayla`; Reddet → `.../reddet`.
- Düzelt → diyalogda "ters bir satır" uyarısı → `POST
  /api/panel/dues-assessments/{id}/ters-kayit`.
- Düzeltilmiş ve düzeltme satırında düğme **çizilmiyor**.
- Ekstre hesap seçiminde **yalnız banka** kasaları; nakit kasa listede
  yok; seçilen hesap gövdede `kasa_id` olarak gidiyor (MT940 yüklemesi
  ile uçtan uca).

Backend: `test_dues.py` + `test_finans.py` + `test_p191_banka_uc.py` +
`test_p192_tahakkuk.py` — **71 test geçti**.

### Ölçemediklerim
- Tarayıcıda gerçek bir `.xlsx` ekstre dosyasıyla yükleme (DOM testi
  MT940 metin yolundan geçiyor; XLSX ayrıştırma katmanı ayrı).
- Yöneticinin (admin değil) bu ekranlardaki davranışı — uçlar admin'e
  kapalı olduğu için değişmedi; K3.6'daki açık madde.

---

## Bölüm 4 — Tesis adresi (14 eksik · madde 1)

### Kararlar

**K4.1 — Dört ayrı alan, tek serbest metin değil.**
`adres` / `ilce` / `il` / `posta_kodu` (göç **0088**, geri alınabilir —
downgrade→upgrade koşuldu). Tek metin daha az iş olurdu ama il/ilçe
sonradan **süzülebilir** alanlardır (bölgeye göre tesis listesi, resmî
entegrasyon); serbest metinden il çıkarmak bir ayrıştırıcının işi olur ve
"İstanbul" ile "ISTANBUL" aynı sayılmazdı.

**K4.2 — Hepsi boş bırakılabilir.** Zorunlu yapmak bugün çalışan her
tesisi bir anda "eksik" hâle getirir, göç de `NOT NULL`da patlardı.

**K4.3 — Posta kodu beş hane, kural İKİ YERDE DE AYNI.** DB `CHECK` +
Pydantic `pattern`. İki farklı sınır yazmak, API'den geçen bir değerin
veritabanında reddedilmesi demekti.

**K4.4 — Makbuzda ve rapor PDF başlığında görünür; adres yoksa satır hiç
açılmaz.** Boş bir satır bırakmak, "adres girilmemiş" mesajını yöneticiye
değil sakine göstermek olurdu. Birleştirme `adres_satiri()` tek yerde:
`"Örnek Mah. No:5, Kadıköy, 34710 İstanbul"`, boş alan sarkan virgül
bırakmaz.

**K4.5 — Adresi YÖNETİCİ yazar.** `_YONETICI_YAZABILIR` kümesine eklendi:
adresi bilen kişi yöneticidir; platform operatörüne bırakmak her tabela
değişikliğini destek talebine çevirirdi.

**K4.6 — Sihirbazda sorulur ama zorunlu değil.** Adressiz tesis çalışır,
yalnız çıktıları eksik görünür. Ama sorulmazsa yönetici böyle bir alan
olduğunu hiç öğrenmiyordu.

### NE ÖLÇTÜM

```
PATCH /tenant/settings (YONETICI ile) -> 200
  {'adres': 'Örnek Mah. 1. Sk. No:5', 'ilce': 'Kadıköy',
   'il': 'İstanbul', 'posta_kodu': '34710'}
posta_kodu "34 71"      -> 422 İstek gövdesi geçersiz.
guvenlik_modu (platform)-> 403 Yönetici yalnız tesis adını ... değiştirebilir.
timezone      (platform)-> 403 (aynı)
GET /kurulum · adres adımı -> {'sayi':1,'tamam':True,'zorunlu':False}, toplam 13
```

Makbuzun adresi gerçekten yazdığını, PDF'e çizilen metinleri kaydederek
ölçtüm (`Canvas.drawString` izlendi):

```
ADRESLI makbuzda çizilen ilk 3 metin:
  ['Acme Plaza', 'Örnek Mah. No:5, Kadıköy, 34710 İstanbul', 'TAHSİLAT MAKBUZU']
ADRESSIZ makbuzda çizilen ilk 3 metin:
  ['Acme Plaza', 'TAHSİLAT MAKBUZU', 'Ödeyen:']
```

Göç geri alınabilir: `downgrade -1` → `upgrade head` temiz koştu.
Testler: yeni `test_p193_tesis_adresi.py` **6 test**;
`test_kurulum.py` + `test_tenants.py` + `test_tenant_ad.py` **42 test**.

### Ölçemediklerim
- Rapor PDF'inin başlığındaki adres satırı (kod yolu makbuzla aynı
  `adres_satiri()`, ama rapor çıktısını render edip görmedim).
- Mobil tarafta adresin gösterimi — mobilde adres ekranı **yok**, bu
  turda eklenmedi (§7'de açık madde).

---

## Bölüm 5 — Yöneticinin tesis ayarları ekranı (14 eksik · maddeler 2, 3)

### Sorun
Sunucu `PATCH /tenant/settings`in bir kısmını yöneticiye zaten açıyordu
(`_YONETICI_YAZABILIR`: tesis adı, konum, otopark kapasitesi, tur alarmı,
gürültü eşiği, okutma mesafesi, rezervasyon geçmişi). Panelde bu alanları
gösteren tek ekran `/settings`ti ve o **platform yüzeyinde** — yani yalnız
Yönetiyor ekibi görüyordu. Yönetici tesis adını bile web'den
değiştiremiyordu (yalnız mobilden).

### Kararlar

**K5.1 — Yeni ekran: `/tesis-ayarlari` (tesis yüzeyi, admin + yönetici).**
`/settings` platformda **kaldı**: orada saat dilimi, tesis kodu ve
güvenlik modu gibi kimlik/sahiplik değerleri var.

**K5.2 — Alan tablosu kopyalanmadı, `lib/tesis-ayar-alanlari.ts`e taşındı.**
İki liste tutmak, yeni bir ayar eklendiğinde ekranlardan birinin
**sessizce** eksik kalması demekti (ekranda alan yok, sunucu alanı kabul
ediyor). `/settings` de artık aynı tablodan besleniyor.

**K5.3 — Platformda kalanlar ve gerekçeleri** (ekranda da yazılı):
| Ayar | Neden yönetici değil |
|---|---|
| Güvenlik modu | Sahipliği devreder (P35). Yöneticinin kendi yetkisini kendine geri verebilmesi, dış şirkete devri anlamsızlaştırırdı. |
| Saat dilimi | Oturumların ve geçmiş kayıtların **yorumunu** değiştirir; yanlış bir değer tüm zaman damgalarını kaydırır. |
| Tesis kodu (slug) | Giriş anahtarı. Değişmesi, kayıtlı her kullanıcının giriş bilgisini geçersiz kılardı. |
| Yönetim e-postası | Bugün admin'de. **Açık madde**: site iletişim adresidir ve yöneticiye açılması savunulabilir; rol kümesini bu turda değiştirmedim çünkü bildirim yollarının hangi adresi kullandığını ayrıca ölçmek gerekir. |

Sunucu bunları zaten reddediyor (403); ekrandaki gizleme yalnızca
kullanıcıya 403 aldırmamak için — karar tek yerde, sunucuda.

**K5.4 — Yalnız değişen alan gönderilir; boş ile boş aynıdır.**
Sunucu boş metni `null` döner, form `""` tutar. İkisini farklı saymak,
kullanıcı hiçbir şeye dokunmadan "Kaydet"e bastığında boş alanları
yeniden yazan bir istek üretiyordu — ölçüldü (`gurultu_uyari_metni: null`
sızıyordu), düzeltildi.

### NE ÖLÇTÜM
- Uç tarafı yukarıdaki §4 çıktısında: yönetici **yazabildiklerini**
  yazdı, **yazamadıklarında 403** aldı.
- Ekran: `admin-web/tests/tesis-ayarlari.dom.test.ts` (5 test) sayfayı
  render ediyor — tesis adı + dört adres alanı çiziliyor; güvenlik modu
  ve saat dilimi **çizilmiyor** ve nedeni ekranda yazılı; işletme ayarları
  (gürültü, okutma) çiziliyor; tek alan değişince gövdede **yalnız o**
  gidiyor; hiçbir şey değişmediyse istek **atılmıyor**.
- Menü/rol kilidi: `rol-menusu.test.ts` 19 test (yeni rota birincil
  ucuyla `PATCH /tenant/settings` olarak kaydedildi).

### Ölçemediklerim
- Ekranın gerçek tarayıcıda yöneticinin menüsünde göründüğü (kilit testi
  kuralı doğruluyor, gözle görmedim).
