# Yönetiyor — Yönetici Kurulum Rehberi

Bu rehber, Yönetiyor'u ilk kez kullanacak bir site yöneticisi içindir.
Hiçbir ön bilgi gerektirmez: kayıt olmaktan sistemin tam çalışır hâle
gelmesine kadar her adım sırayla yazılmıştır.

**Nasıl okunur:** adımlar birbirine bağlıdır. Daire yoksa sakin
eklenemez, kasa yoksa tahsilat girilemez. Sıra atlanmamalıdır.

---

## Önce şunu bilin: iki ayrı adres, iki ayrı cihaz

| Kim | Nereden çalışır |
|---|---|
| **Siz (yönetici)** ve **denetçi** | Bilgisayardan: **app.yonetiyor.com** |
| **Sakinler**, **güvenlik**, **tesis görevlileri** | Telefondan: **Yönetiyor** mobil uygulaması |

Sakin ve saha personeli web paneline **giremez** — bu bir eksiklik değil,
tasarım kararıdır: kapıda duran görevlinin ya da dairesinden aidatına
bakan sakinin masabaşı bilgisayarı yoktur. Onlara uygulama linki gider.

Uygulama bağlantıları:
* Android: `play.google.com/store/apps/details?id=com.app.yonetiyor`
* iPhone: `apps.apple.com/tr/app/id6797316863`

---

## MİNİMUM ÇALIŞIR KURULUM — 6 adım

Aşağıdaki altı adım tamamlandığında sistem gerçekten çalışır durumdadır:
sakinler uygulamaya girer, borçlarını görür, siz tahsilat işlersiniz.
**Toplam süre: yaklaşık 2 saat** (daire sayısına göre değişir).

| # | Adım | Bölüm | Süre |
|---|---|---|---|
| 1 | Yönetici kaydı + tesis oluşturma | **1** | 10 dk |
| 2 | Blok ve daireleri oluşturma | **3.1–3.2** | 20–40 dk |
| 3 | Sakinleri ekleme ve davet gönderme | **4** | 30–60 dk |
| 4 | En az bir kasa açma | **5.1** | 5 dk |
| 5 | İlk aidat tahakkuku | **5.3** | 10 dk |
| 6 | Site kurallarını ve ilk duyuruyu yazma | **7.1–7.2** | 10 dk |

Geri kalan her şey (otomasyon, devriye, kamera, bütçe, banka) **sonra**
yapılabilir ve sistemi bekletmez.

> **Daire tipleri** bu altı adımda yok çünkü tahakkuku sabit tutarla da
> yazabilirsiniz. Ama her daireye farklı aidat yazacaksanız (dükkân,
> 1+1, 3+1) tipleri **önce** tanımlamanız gerekir — bkz. 3.3.

---

## Yardımcınız: Kurulum sihirbazı

İlk girişte ekranın ortasında **"Kurulumu tamamlayın"** kutusu açılır:
*"Tesisinizi kullanıma hazır hâle getirmek için birkaç adım kaldı.
Sihirbaz sizi tek tek ilgili ekranlara götürür."* İki düğmesi vardır:
**Sihirbazı aç** ve **Daha sonra**.

Sihirbaza her zaman **sol menünün en altındaki "Kurulum sihirbazı"**
satırından da ulaşabilirsiniz. Sayfa sekiz adımı sırayla gösterir; her
adımın yanında **Git** düğmesi ilgili ekrana götürür.

> Hatırlatma kutusu **kurulum bitince kendiliğinden kaybolur** ve
> **Daha sonra** dediğinizde bir daha çıkmaz (tercih tarayıcınızda
> saklanır — başka bir bilgisayardan girerseniz yeniden görürsünüz).
> İlerlemeniz kaybolmaz: sunucu adımları sayar, bayrak tutmaz.

Sihirbazın adımları: Bloklar · Kat ve daireler · Daire tipleri ·
Sakinler · Personel · Görev alanları · NFC noktaları · Aidat tanımı.

* Adımlar **kilitli değildir**: istediğinize atlayabilir, yarım bırakıp
  devam edebilirsiniz.
* Bir adımı yapmayacaksanız **Atla** diyin; ilerleme çubuğu onu geçilmiş
  sayar. Sonradan **Atlamayı geri al** ile döndürebilirsiniz.

Sihirbaz **"yapıldı mı"yı kendisi ölçer** — bir adımı işaretlemenize gerek
yoktur, ilgili kayıt oluştuğunda kendiliğinden yeşile döner.

---

# BÖLÜM 1 — Kayıt ve tesis oluşturma

**Süre: 10 dakika · ZORUNLU · Her şeyin önkoşulu**

## 1.1 Kayıt formunu açın

Tarayıcıdan **app.yonetiyor.com** adresine gidin, **Kayıt ol** deyin.
Form altı adımdan oluşur ve üstte **"Adım 1/6"** gibi ilerleme yazar.

## 1.2 Adım adım

| Adım | Ekranda ne var | Ne yapacaksınız |
|---|---|---|
| 1 | **Kayıt ol — Size uygun olanı seçiniz** | **Yönetici** (*Siteyi yöneten kişi*) seçin. Diğer seçenek Denetçi'dir; o hesapları denetleyen kişidir, siz değilsiniz. |
| 2 | **Nasıl giriş yapacaksınız?** | Google/Apple ile devam edin ya da **E-posta ile kaydol** deyin. |
| 3 | **Bilgileriniz** | **Ad**, **Soyad**, **E-posta** ve (e-posta yolunu seçtiyseniz) **Yeni parola** + **Parola tekrar**. **Telefon** alanı da vardır. |
| 4 | **Nasıl devam etmek istersiniz?** | **Yeni tesis oluştur** seçin. (*Mevcut tesise katıl* seçeneği, size verilmiş bir Tesis ID ile başkasının sitesine katılmak içindir.) |
| 5 | **Tesisinizi oluşturun** | **Tesis adını giriniz** — örn. `Oltu Sitesi`. |
| 6 | **Doğrulama kodu** | E-postanıza gelen **6 haneli kodu** girin. |

**Zorunlu alanlar:** Ad, Soyad, E-posta, (e-posta yolunda) parola, Tesis
adı, doğrulama kodu, **Kullanıcı Sözleşmesi** ve **KVKK Aydınlatma
Metni** onayları.
**İsteğe bağlı:** Telefon, ticari ileti izni.

> Telefon alanının altında **"Yalnızca iletişim için; giriş anahtarı
> değildir"** yazar — girişi e-postanızla yaparsınız.

> Google/Apple ile kaydolduysanız 6. adım (kod) **atlanır**: sağlayıcı
> e-postanızı zaten doğrulamıştır.

## 1.3 Tesis ID'niz

Kayıt bittiğinde ekranda **Tesis kodunuz** başlığı altında Tesis ID'niz
görünür (örn. `OLTU-260715`) ve şu not eşlik eder:

> *Bu kodu sakinlerinize ve personelinize iletin; uygulamaya bu kodla
> katılırlar.*

**Tesis ID'yi siz üretmezsiniz — sistem üretir.** Kaydettikten sonra da
her zaman bulabilirsiniz:

> **İletişim → Davetler** sayfasının üstünde **Tesis kodu** kutusu ve
> kopyalama düğmesi vardır.

**Doğru yaptığınızı nasıl anlarsınız:** **Panoya git** deyince **Özet**
ekranı açılır; sol menüde Güvenlik, Tesis, Finansal İşlemler, İletişim,
Tanımlar, Yönetim başlıkları görünür.

**Atlanırsa:** hiçbir şey yapılamaz — bu ilk adımdır.

---

# BÖLÜM 2 — Tesis bilgileri

**Süre: 5 dakika · Kısmen mümkün**

## 2.1 Tesis adını değiştirme

Tesis adını kayıt sırasında girdiniz. Değiştirmek isterseniz:

> **Mobil uygulama → Ayarlar → Tesis adı** kartından değiştirilir.

**Web panelinde tesis adını değiştirebileceğiniz bir ekran yoktur.**
Paneldeki **Platform → Ayarlar** sayfası yalnızca Yönetiyor'un kendi
ekibine açıktır; sizin hesabınızda görünmez.

## 2.2 Yapılamayan şeyler (bugün)

Aşağıdakiler için **hiçbir ekran yoktur** — ne web ne mobil:

* Site **adresi** (mahalle, sokak, no) — sistemde böyle bir alan yok.
* **Saat dilimi** (varsayılan Türkiye saati olarak çalışır).
* **Hava durumu konumu** (varsayılan İstanbul).
* **Otopark kapasitesi**.
* Güvenlik modu, gürültü eşiği gibi operasyon ayarları.

Bunlar gerekiyorsa Yönetiyor destek ekibine yazmanız gerekir:
**İletişim → Destek**.

---

# BÖLÜM 3 — Yapı kurulumu (blok, daire, tip)

**Süre: 20–40 dakika · ZORUNLU · Sakin ve aidatın önkoşulu**

Sıra önemlidir: **blok → daire → daire tipi**. Blok olmadan daire,
daire olmadan sakin eklenemez.

## 3.1 Blokları oluşturun

> **Tanımlar → Bloklar** (sihirbazdaki adı: *Bloklar*)

Sayfanın açıklaması: *"Blok, kat ve daireleri görsel olarak oluşturun.
Şikayet Haritası bu yapıyı yansıtır."*

1. **Blok ekle** deyin.
2. **Blok etiketi** girin — *Kısa alfanumerik (örn. A, B1) — tire yok*.
3. Kaydedin. Her blok için tekrarlayın.

**Doğru yaptığınızı nasıl anlarsınız:** *"Blok oluşturuldu."* bildirimi
çıkar ve blok listede görünür.

**Atlanırsa:** daire eklemeye çalıştığınızda sistem sizi durdurur:
*"Önce en az bir blok tanımlamalısınız; daireler bloklara bağlıdır."*

## 3.2 Daireleri oluşturun

Aynı ekranda (**Tanımlar → Bloklar**) bir bloğun üzerine tıklayın.

**Tek tek eklemek için:** **+ Kat** ile kat açın, kata daire ekleyin.

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Daire no** | Zorunlu | *Alfanumerik + tire (örn. A-12, B3, 12)* |
| **Kat** | İsteğe bağlı | *0 = zemin*, bodrum için negatif: `-1`, `-2` |
| **Kattaki konum** | İsteğe bağlı | Şikayet haritasındaki sırası |

**Toplu oluşturmak için** aynı ekranda toplu form vardır: **Kat sayısı**,
**Kat başına daire**, **Başlangıç numarası**, **Başlangıç katı**
(*Bodrum için negatif yazın: -2, -1, 0 (zemin), 1…*).

**Excel'den aktarmak için:** bkz. **3.4**.

**Doğru yaptığınızı nasıl anlarsınız:** *"Daireler oluşturuldu."*
bildirimi; **Tesis → Daireler** listesinde daireler görünür.

**Atlanırsa:** **sakin hiç eklenemez** — sakin rolünde blok ve daire
seçimi zorunludur, form daire olmadan kaydedilmez. Aidat tahakkuku da
hiçbir daireye yazılamaz.

## 3.3 Daire tiplerini tanımlayın

> **Tanımlar → Daire tipleri → Yeni kayıt**

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Ad** | Zorunlu | örn. `1+1`, `2+1`, `Dükkân` |
| **Varsayılan aidat** | İsteğe bağlı | O tipteki dairelere yazılacak tutar |
| **Aktif** | İsteğe bağlı | Varsayılan açık |

**Varsayılan aidat neden önemli:** toplu tahakkukta tutar yazmazsanız
sistem her daireye **kendi tipinin** varsayılan tutarını yazar. Tipi
olmayan ya da tipinde tutar tanımsız olan daire **atlanır** ve size
söylenir.

**Ayrıca:** **Tanımlar → Daire grupları** ile bölümün *ne olduğunu*
(Daire / Villa / Dükkân) tanımlayabilirsiniz. Tip ile grup ayrı
kavramlardır: grup "ne", tip "ne büyüklükte".

**Daire tipini dairelere atamak için:** **Tanımlar → Bloklar** ekranında
daireleri seçip **Daire tipi toplu değiştir** kullanın.

## 3.4 Excel'den toplu aktarım (isteğe bağlı ama çok zaman kazandırır)

> **Tanımlar → İçe aktarım**

*"Excel'den toplu veri aktarımı — önizleme ve geri alma ile"*

**Aktarım türleri:** Daireler ve bloklar · Kişiler ve sakinler · Açılış
bakiyeleri · Araçlar.

Akış:
1. **Aktarım türü** seçin → **Şablonu indir (.csv)**.
2. Excel'de doldurun.
3. **Dosya seç (.xlsx veya .csv)** ya da satırları kopyalayıp yapıştırın.
4. **Kolon eşleme** ekranında hangi sütunun ne olduğunu işaretleyin.
5. **Önizle (hiçbir şey yazılmaz)** — sonucu görün.
6. **Aktar**.

**Daireler için zorunlu sütunlar:** `blok`, `daire_no`.
**Kişiler için zorunlu sütunlar:** `ad`, `telefon`.
İsteğe bağlı: `eposta`, `daire_no`, `rol_tipi` (`malik` / `kiraci`).

> **DİKKAT — kişileri Excel'den aktarırken e-posta sütununu mutlaka
> doldurun.** E-postası olmayan kişiye davet **gönderilemez** (SMS kanalı
> kapalıdır) ve o kişi Tesis ID'yi hiçbir zaman öğrenemez. Ayrıntı:
> *Sık karşılaşılan sorunlar → "Davet e-postası gitmedi"*.

## 3.5 Arsa payları (isteğe bağlı — Kat Mülkiyeti Kanunu'na göre paylaşım yapacaksanız)

> **Tesis → Daireler → (bir daire) → Düzenle → Arsa payı**

Gideri arsa payına göre paylaştırmak istiyorsanız her dairenin arsa
payını buraya girin. **Metrekare** alanı da aynı formdadır.

**Atlanırsa:** toplu borçlandırmada "Arsa payına göre" dağıtımı
seçtiğinizde arsa payı girilmemiş daireler **atlanır** ve size *"Arsa
payı girilmemiş"* diye tek tek listelenir. Sessizce sıfır borç
yazılmaz.

**Not:** arsa payı yalnızca daire **düzenleme** ekranındadır; blok
düzenleme ekranındaki toplu daire oluşturmada ve Excel aktarımında bu
alan **yoktur**.

---

# BÖLÜM 4 — Kullanıcılar ve davetler

**Süre: 30–60 dakika · ZORUNLU · Önkoşul: daireler (3.2)**

## 4.1 Kullanıcı eklemenin iki yolu

> **Yönetim → Kullanıcılar → Yeni kullanıcı**

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Ad** | Zorunlu | |
| **E-posta** | **Zorunlu** | *Doğrulama ve bildirim için; zorunlu.* |
| **Cep telefonu** | Zorunlu | *Yalnızca iletişim için.* |
| **Rol** | Zorunlu | Sakin / Güvenlik / Tesis görevlisi / Yönetici / Denetçi |
| **Blok** + **Daire** | **Sakin için ZORUNLU** | Yöneticide isteğe bağlı; güvenlik ve tesis görevlisinde alan hiç çıkmaz. Önce **Blok seçin**, daire listesi ona göre süzülür. |
| **Aranabilir (rıza)** | İsteğe bağlı | *Numara aramaya izin verildi mi?* |
| **Görev başlangıcı / bitişi** | İsteğe bağlı | Genelde denetçi için: *Boş bırakılırsa görev süresizdir.* |

**Parola alanı yoktur ve olmamalıdır.** Hesap parolasız açılır; kişi
kendi parolasını davet bağlantısından kendisi kurar. Yöneticinin
kullanıcı parolası bilmesi bir güvenlik açığı olurdu.

**Toplu eklemek için:** aynı sayfadaki **Excel ile toplu yükle** düğmesi
sizi içe aktarım ekranına götürür (bkz. 3.4).

## 4.2 Davet nasıl gider

Kullanıcıyı kaydettiğiniz anda sistem ona **e-posta** gönderir. E-posta
şunları içerir:

* **Yönetiyor'a hoş geldiniz** başlığı ve *"{tesis} sizi {rol} olarak
  davet etti"* satırı,
* **Daveti Aç** düğmesi (davet bağlantısı),
* **Tesis ID**'niz,
* App Store ve Google Play bağlantıları.

> **SMS gönderilmez.** Sistemde SMS kanalı varsayılan olarak **kapalıdır**
> ve açık olmadığı sürece hiç denenmez. Davetin tek kanalı e-postadır.

## 4.3 Kişi kaydını nasıl tamamlar

**Yol A — davet bağlantısıyla (en kolay):** Kişi e-postadaki **Daveti Aç**
düğmesine basar. Açılan sayfada **Parolanızı belirleyin** der; parolasını
kurar ya da Google/Apple ile bağlanır. Hesabı hazırdır.

**Yol B — uygulamadan, Tesis ID ile:** Kişi uygulamayı indirir,
**Kayıt ol** der, rolünü seçer, **Mevcut tesise katıl** yolunu seçer ve
**Tesis ID**'yi girer. E-postasına gelen 6 haneli kodu doğrular.

> Zaten sizin açtığınız bir hesap varsa kişi doğrudan giriş yapabilir;
> yoksa talebi **size onaya düşer** ve kişi *"Yönetici onayı bekleniyor"*
> ekranını görür.

## 4.4 Davetleri izleyin

> **İletişim → Davetler**

*"Gönderilen davetler ve durumları."* Gitmeyen bir daveti buradan
**yeniden gönderebilirsiniz**. Sayfanın üstünde Tesis kodu kutusu vardır:
*"Davet gitmediyse tesis kodunu elle iletebilirsiniz."*

**Doğru yaptığınızı nasıl anlarsınız:** Kullanıcılar listesinde kişi
görünür; Davetler sayfasında durumu takip edebilirsiniz.

**Atlanırsa:** sakinler uygulamaya giremez; borçlarını göremez,
bildirim alamaz.

## 4.5 Personel kayıtları — kullanıcı hesabından AYRIDIR

> **Tanımlar → Personel → Yeni kayıt**

Bu ekran **çalışanın özlük kaydıdır** (Görev, TC, Giriş tarihi, Çıkış
tarihi, Maaş). **Giriş hesabı değildir.**

Bir güvenlik görevlisinin hem uygulamaya girmesi hem bordroda görünmesi
gerekiyorsa **iki kayıt** açmalısınız: *Yönetim → Kullanıcılar*'da hesap,
*Tanımlar → Personel*'de özlük kaydı.

---

# BÖLÜM 5 — Finans kurulumu

**Süre: 30–45 dakika · Kasa + tahakkuk ZORUNLU, gerisi isteğe bağlı**

Sıra: **kasa → gelir/gider kalemi → tahakkuk**. Kasa olmadan tahsilat
girilemez; sistem sizi durdurur: *"Önce bir kasa tanımlamalısınız;
tahsilat bir kasaya işlenir."*

## 5.1 Kasa ve banka hesabı açın — ZORUNLU

> **Tanımlar → Kasalar → Yeni kayıt**

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Kod** | Zorunlu | Kısa kod, örn. `KASA`, `BANKA` |
| **Ad** | Zorunlu | örn. `Merkez Kasa` |
| **Açılış tarihi** | İsteğe bağlı | |
| **Açılış bakiyesi (₺)** | İsteğe bağlı | Devreden nakit |
| **Banka hesabı** | İsteğe bağlı | İşaretlerseniz banka hesabı olur |
| **IBAN (yalnız banka)** | İsteğe bağlı | Yalnız banka hesabında doldurulabilir |
| **Banka adı**, **Şube** | İsteğe bağlı | |

**En az iki kayıt açmanız önerilir:** nakit için bir **kasa**, havaleler
için bir **banka hesabı** (IBAN'lı).

**IBAN'ı neden banka hesabına yazmalısınız:** sakinlerin *"Öde"*
ekranında görünen IBAN, sitenin IBAN'lı banka kasasından okunur. Yoksa
sakin nereye para yatıracağını göremez.

**Doğru yaptığınızı nasıl anlarsınız:** **Finansal İşlemler → Finans**
sayfasındaki **Kasalar** tablosunda kayıtlarınız ve **Genel toplam**
görünür.

**Atlanırsa:** tahsilat, gider, virman, açılış fişi — hiçbiri
girilemez.

## 5.2 Gelir/gider kalemlerini tanımlayın

> **Tanımlar → Gelir/Gider Grupları → Yeni kayıt** (üst kırılım, örn.
> `Aidat Gelirleri`, `Bakım Giderleri`) — sonra
> **Tanımlar → Gelir/Gider Kalemleri → Yeni kayıt**

Kalem alanları:

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Ad** | Zorunlu | örn. `Aidat`, `Asansör bakımı` |
| **Tip** | Zorunlu | Gelir / Gider / Her ikisi |
| **Dağıtım şekli** | İsteğe bağlı | *yalnız gider* — Bağımsız bölümlere eşit / Tipe göre |

**En az bir GİDER kalemi (`Aidat`) tanımlayın** — toplu borçlandırma bir
kalem seçmenizi ister.

> Bir **gelir** kalemi borçlandırılamaz; tahsil edilir. Sistem gelir
> kalemiyle borç yazmanızı reddeder.

## 5.3 İlk aidat tahakkukunu oluşturun — ZORUNLU

İki yol vardır.

**Basit yol** — tüm aktif dairelere aynı tutar:

> **Finansal İşlemler → Aidat**

Üstteki **Toplu tahakkuk (tüm aktif daireler)** kutusunu doldurun:

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Dönem** | Zorunlu | *Örnek: 2026-07* |
| **Tutar (TL)** | Zorunlu | Her aktif daireye aynı tutar |
| **Son ödeme (opsiyonel)** | İsteğe bağlı | **Gecikme faizi kullanacaksanız doldurun** |
| **Açıklama (opsiyonel)** | İsteğe bağlı | |

**Toplu tahakkuk oluştur** deyin.

Sonuç satırı şunu der: *"{olusan} tahakkuk oluşturuldu · {atlanan}
atlandı (zaten vardı)."*

**Gelişmiş yol** — kaleme, dağıtıma ve süzgece göre:

> **Finansal İşlemler → Borçlandırmalar → Toplu**

| Alan | Zorunlu mu |
|---|---|
| **Tür** (gelir/gider kalemi) | Zorunlu |
| **Tarih** | Zorunlu (dönem tarihten türetilir) |
| **Son ödeme** | İsteğe bağlı ama **gecikme faizi için gerekli** |
| **Dağıtım** | Daire başına tutar / Toplamı eşit böl / Arsa payına göre / Metrekareye göre |
| **Kalem türü** | Aidat / Demirbaş / Olağanüstü / Sayaç / Diğer |
| **Tutar** ya da **Dağıtılacak toplam** | Dağıtıma göre biri zorunlu |

**Her zaman önce Önizle deyin.** Önizleme kaç daireye ne kadar
yazılacağını ve **atlanacak daireleri nedenleriyle** gösterir (örn.
*"Arsa payı girilmemiş"*, *"Daire tipinin varsayılan tutarı yok"*).

**Doğru yaptığınızı nasıl anlarsınız:** **Tesis → Daireler → (bir
daire)** açıldığında **Bakiye** görünür; sakin uygulamada **Aidatım**
ekranında borcunu görür.

**Atlanırsa:** hiç kimseye borç yazılmamış olur; tahsilat, borçlu
listesi, tahsilat oranı — hepsi boş kalır. Kurulum sihirbazının son adımı
da tamamlanmaz.

## 5.4 Aidat otomasyonu (isteğe bağlı ama çok değerli)

> **Finansal İşlemler → Otomasyon**

*"Bir kez tanımlayın; sistem her ay otomatik tahakkuk etsin."*

**Yeni plan** düğmesi:

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Plan adı** | Zorunlu | örn. `Aylık aidat` |
| **Tür** | Zorunlu | Gelir/gider kalemi |
| **Tutar** | Zorunlu | |
| **Tahakkuk günü** | İsteğe bağlı (varsayılan 1) | 1–28 arası |
| **Vade (gün sonra)** | İsteğe bağlı (varsayılan 15) | |
| **Önizleme (gün önce)** | İsteğe bağlı (varsayılan 3) | Size önceden bildirim gider |

Sistem her ay o gün geldiğinde tahakkuku kendisi yazar. Tahakkuktan
birkaç gün önce size *"3 gün sonra 26 daireye toplam X TL tahakkuk
edilecek"* bildirimi gelir.

* Bir ayı atlamak isterseniz plan satırında **Bu ayı atla** deyin —
  plan kapanmaz, yalnız o ay yazılmaz.
* Sistem bir gün çalışamazsa **atlanan ay telafi edilir**.
* Planı iki kez çalıştırmak borcu iki katına çıkarmaz.

**Atlanırsa:** her ay tahakkuku elle çalıştırmanız gerekir; unutursanız o
ay borç oluşmaz.

## 5.5 Borç hatırlatmaları (isteğe bağlı)

Aynı sayfadaki **Borç hatırlatma** kartı:

* **Etkin** kutusu — **varsayılan kapalıdır**, siz açmadan hiçbir
  hatırlatma gitmez.
* **Vadeden kaç gün önce** — 0 yazarsanız vade öncesi hatırlatma gitmez.
* **Vade sonrası kademeler (gün)** — örn. `3, 10, 30`.
* **Hatırlatma metni (boş = varsayılan)** — kendi cümlenizi yazarsanız
  o gider ve **çevrilmez**. `{tutar}` ve `{vade}` yazarsanız sistem
  doldurur.

*"Ödeyene hatırlatma gitmez; her sakine günde en fazla bir bildirim."*

Aynı sayfadaki **Gönderilen hatırlatmalar** kartı kaç hatırlatma
gittiğini ve kaçının açıldığını gösterir.

## 5.6 Gecikme faizi (isteğe bağlı)

> **Finansal İşlemler → Borçlandırmalar** → sayfanın üstündeki
> **Gecikme faizi** kartı

* **Gecikme faizi uygula** kutusu — bazı siteler faiz almaz; bu bir
  karardır, açık bırakmak zorunda değilsiniz.
* **Aylık oran (%)**.
* Kart altında *"{n} borç için toplam {tutar} faiz işlenecek"* yazar;
  **Faizi işle** deyince faiz **ayrı bir borç kalemi olarak** yazılır ve
  tahsil edilebilir hâle gelir.

**Önkoşul:** tahakkuklarda **son ödeme tarihi** dolu olmalıdır. Vadesi
olmayan borç gecikmiş sayılmaz.

Faiz otomasyona da bağlıdır: açık bırakırsanız sistem ayda bir kendisi
işler.

## 5.7 Düzenli giderler (isteğe bağlı)

> **Finansal İşlemler → Otomasyon → Yeni düzenli gider**

Kapıcı maaşı, asansör bakımı, sigorta gibi tekrar eden giderler.

| Alan | Zorunlu mu |
|---|---|
| **Ad** | Zorunlu |
| **Tutar** | Zorunlu |
| **Tekrar** | Aylık / 3 aylık / 6 aylık / Yıllık |
| **Sonraki tarih** | Zorunlu |
| **Kasa** | İsteğe bağlı |
| **Onay istemeden ödendi yaz** | İsteğe bağlı — **varsayılan kapalı** |

*"Vadesi gelince gider onayınıza düşer; otomatik ödenmiş yazılmaz."*

## 5.8 Bütçe hedefleri (isteğe bağlı)

> **Finansal İşlemler → Bütçe**

**Yıl**, **Tür** (bütçe kategorisi) ve **Hedef** girip **Hedef belirle**
deyin. Tablo hedefi, gerçekleşeni ve **sapmayı** yan yana gösterir.

*"Aylık hedef yoksa yıllık hedefin aya düşen payı kullanılır."*

**Atlanırsa:** sapma tablosu boş kalır; diğer hiçbir şey etkilenmez.

## 5.9 Banka entegrasyonu (isteğe bağlı)

> **Finansal İşlemler → Banka Entegrasyonu**

*"Banka ekstresini yükleyin; sistem ödemeleri açık borçlarla eşleştirsin.
Eşleşmeyenler aşağıda listelenir ve elle atanabilir."*

1. **Ekstre yükle (CSV, Excel veya MT940)** → **Dosya seç**.
2. **Sütun eşlemesi**: Tarih, Tutar, Açıklama, Gönderen adı, Gönderen
   IBAN, Banka referansı.
3. **Önizleme (ilk 5 satır)** → **İçe aktar**.
4. **Eşleştirmeyi çalıştır**.

Aynı ekstreyi iki kez yüklerseniz ikinci yükleme yeni satır açmaz.

**Eşleşmenin kesin olması için:** sakinlerin ödeme açıklamasına kendi
**ödeme kodlarını** yazması gerekir. Sakin bu kodu uygulamada **Öde**
ekranında görür.

## 5.10 Açılış bakiyeleri (isteğe bağlı — devir varsa)

Eski sistemden devreden borçları girmek için:

> **Tanımlar → İçe aktarım → Açılış bakiyeleri**

Zorunlu sütunlar: `daire_no`, `tutar`. İsteğe bağlı: `aciklama`.

---

# BÖLÜM 6 — Güvenlik kurulumu

**Süre: 30–45 dakika · İsteğe bağlı (güvenlik hizmeti varsa)**

Sıra: **NFC noktaları → vardiyalar → devriye planları**. Plan, nokta ve
(isterseniz) vardiya seçmenizi ister.

## 6.1 NFC noktalarını tanımlayın

> **Güvenlik → NFC Noktaları → Yeni nokta**

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Ad** | Zorunlu | örn. `A Blok Giriş` |
| **NFC etiket UID** | Zorunlu | *Büyük harf hex, ayraçsız. Örnek: 04A1B2C3D4* |
| **GPS enlem / boylam** | İsteğe bağlı | Girerseniz harita ve mesafe kontrolü çalışır |

> Etiket UID'sini elle yazmak yerine, görevli mobil uygulamayla etiketi
> okuttuğunda uygulama bu biçimde gönderir.

**Aynı etiket iki noktada kullanılamaz:** *"Bu NFC etiketi başka bir
noktada kullanılıyor."*

## 6.2 Vardiyaları tanımlayın

> **Güvenlik → Vardiyalar → Yeni vardiya**

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Ad** | Zorunlu | örn. `Gündüz`, `Gece` |
| **Başlangıç** / **Bitiş** | Zorunlu | 24 saat biçimi |
| **Gün tipi** | İsteğe bağlı | Her gün / Hafta içi / Hafta sonu / Resmi tatil |

## 6.3 Devriye planı kurun

> **Güvenlik → Devriye Planları**

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Ad** | Zorunlu | |
| **Başlangıç** / **Bitiş** | Zorunlu | Saat biçimi `HH:MM` |
| **Periyot (dk)** | Zorunlu | Turun kaç dakikada bir tekrarlanacağı |
| **Vardiya** | İsteğe bağlı | Ekranda *Vardiya (opsiyonel)* yazar |
| **Nokta ekle** | En az bir nokta | Turda okutulacak noktalar |
| **Aktif** | | Plan çalışsın mı |

**Doğru yaptığınızı nasıl anlarsınız:** plan kaydedildikten sonra sistem
tur pencerelerini kendisi üretir; **Özet** ekranında "Bugünün turları"
görünür.

**Atlanırsa:** devriye takibi çalışmaz; kaçırılan tur uyarısı gelmez.

## 6.4 Kameraları ekleyin

> **Güvenlik → Kameralar → Yeni kamera**

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Ad** | Zorunlu | |
| **Kamera adresi** | Zorunlu | *RTSP kamera için rtsp://…, hazır bir yayın için http(s) adresi. Türü sistem adresten anlar.* |
| **Konum** | İsteğe bağlı | |

Adres örneği ekranda yazar:
`rtsp://kullanici:parola@192.168.1.50:554/Streaming/Channels/101`
— kullanıcı adı ve parola **adresin içine** yazılır.

Kaydetmeden önce **Bağlantıyı test et** deyin. Başarılıysa *"Bağlantı
çalışıyor: kamera görüntü verdi"* der. (Test yalnız `rtsp://` adresleri
içindir.)

**Gelişmiş ayarlar** bölümünü **boş bırakın** — sistem ızgara karesini ve
canlı yayını kendisi üretir; o alanlar yalnız kendi yayın geçidini
kullanan kurulumlar içindir.

---

# BÖLÜM 7 — İletişim

**Süre: 15 dakika · Kısmen zorunlu**

## 7.1 Site kurallarını yazın — ÖNERİLİR

> **İletişim → Kural yönetimi**

*"Sakinlerin gördüğü kuralları buradan ekleyip düzenlersiniz."*

**Yeni kural** → **Kural metni** yazın. Sıralama alanı vardır: *"Küçük
sıra önce gösterilir."*

Sakinler bunu uygulamada **Site kuralları** ekranında görür.

## 7.2 İlk duyurunuzu yayınlayın — ÖNERİLİR

> **İletişim → Duyurular → Yeni duyuru**

| Alan | Zorunlu mu | Not |
|---|---|---|
| **Başlık** | Zorunlu | en fazla 200 karakter |
| **Duyuru metni** | Zorunlu | en fazla 5000 karakter |
| **Görsel (opsiyonel)** | İsteğe bağlı | *Okuyan herkes duyuruda görür* |

İlk duyuru olarak sakinlere sistemi tanıtmanız işinizi kolaylaştırır:
uygulamayı nereden indireceklerini, Tesis ID'yi ve aidatlarını nereden
göreceklerini yazın.

## 7.3 E-posta gönderimi ayarları — DAVETLER İÇİN KRİTİK

> **İletişim → SMS/E-Posta Yönetimi → Ayarlar** sekmesi

Burada **E-posta (SMTP)** ve **SMS Sağlayıcı** ayarları vardır.

**Kendi e-posta sunucunuzu tanımlamazsanız** sistem Yönetiyor'un
varsayılan gönderimini kullanır. Davetleriniz gitmiyorsa ilk bakılacak
yer burasıdır.

Ayarları girdikten sonra aynı sayfadaki **Test Gönderimi** kutusuna
**Hedef (telefon/e-posta)** yazıp **Test Gönder** deyin. Not:
*"Gerçekten gönderir; gönderim geçmişine yazılmaz."*

## 7.4 Bildirim tercihleri

Her kullanıcı kendi bildirim tercihini kendisi yönetir:

> **Profil → Bildirim ayarları** (web) veya mobilde **Ayarlar →
> Bildirimler**

Üç kanal ayrı ayrı açılıp kapanır: **E-posta bildirimleri**, **SMS
bildirimleri**, **Mobil bildirimler**.

> **Yöneticinin bir sakinin bildirimlerini onun adına açıp kapatacağı bir
> ekran yoktur.** Sakin push almıyorsa kendi ayarlarına bakması gerekir.

## 7.5 Diğer iletişim ekranları (kurulum gerektirmez)

| Ekran | Ne işe yarar |
|---|---|
| **İletişim → Talepler** | Sakinlerin açtığı talepleri görür, iş emrine çevirirsiniz |
| **İletişim → Anketler** | Sakinlere anket açarsınız |
| **İletişim → Etkinlik yönetimi** | Site etkinlikleri |
| **İletişim → Yönetim iletişim** | Sakinlerin gördüğü yönetici iletişim kartı |
| **İletişim → Destek** | Yönetiyor ekibine soru sorarsınız |

---

# BÖLÜM 8 — Diğer modüller

**Süre: 15 dakika · Hepsi isteğe bağlı**

| Modül | Menü yolu | Kurulum gerekir mi |
|---|---|---|
| **Görevler** | Tesis → Görevler | **Evet** — önce **Tanımlar → Görev kategorileri**'nde en az bir kategori (temizlik, bakım…) tanımlayın. Kategori yoksa görev türü seçilemez. |
| **Rezervasyon** | Tesis → Rezervasyon yönetimi | **Evet** — **Alanlar** sekmesinde **Yeni alan** ile alan tanımlayın: **Alan adı** (zorunlu), Açıklama, **Açılış**/**Kapanış** saati, **Slot (dakika)**. Alan yoksa sakin rezervasyon yapamaz. |
| **Demirbaş** | Tesis → Demirbaş | Hayır — doğrudan kayıt ekleyebilirsiniz |
| **Kargo** | Güvenlik → Kargolar | Hayır |
| **Ziyaretçi** | Güvenlik → Ziyaretçiler | Hayır |
| **Şikayet (daire)** | Tesis → Şikayet Haritası | Hayır — kategoriler sabittir (Gürültü, Kapı önü, Zarar verme, Görüntü kirliliği, Diğer). Harita için dairelerin **kat** ve **kattaki konum** bilgisinin girilmiş olması gerekir. |
| **Sayaç okuma** | Finansal İşlemler → Sayaç Okuma | **Evet** — önce **Tanımlar → Sayaçlar** (ana) ve **Tanımlar → Bölüm Sayaçları** tanımlayın |
| **Araçlar** | Tanımlar → Araçlar | Hayır — Excel'den de aktarılabilir |
| **Firmalar** | Tanımlar → Firmalar | Hayır — gider girişinde firma seçmek isterseniz |
| **Karar Defteri** | Yönetim → Karar Defteri | Hayır |
| **Doküman Yönetimi** | Yönetim → Doküman Yönetimi | Hayır |
| **Şeffaflık** | Yönetim → Şeffaflık | Hayır — ama sakinlerin görmesi için her ayı **yayınlamanız** gerekir |
| **Raporlar** | Finansal İşlemler → **Rapor motoru** | Hayır — 17 hazır rapor; ekran/Excel/PDF çıktısı alınır |
| **Dış hizmetler** | Tesis → Dış hizmetler | Hayır |

**Yalnızca Yönetiyor ekibinin görebildiği ekranlar** (sizde
görünmez): Olaylar, Araç geçişleri, Platform → Tesisler / Entegrasyonlar
/ Ayarlar / KVKK Metinleri, Yönetim → Denetim Kaydı, Yetki matrisi.

---

# A) SIK KARŞILAŞILAN SORUNLAR

## "Davet e-postası gitmedi"

**En sık nedeni: kişinin e-postası yok.** Kullanıcıyı Excel'den
aktardıysanız `eposta` sütunu boş kalmış olabilir — tek tek eklemede
e-posta zorunludur ama **Excel aktarımında değildir**.

**SMS beklemeyin:** SMS kanalı varsayılan olarak kapalıdır ve kapalıyken
hiç denenmez.

Sırayla kontrol edin:
1. **Yönetim → Kullanıcılar** → kişinin e-postası dolu mu?
2. **İletişim → Davetler** → davetin durumu ne? **Yeniden gönder**.
3. **İletişim → SMS/E-Posta Yönetimi → Ayarlar** → **E-posta (SMTP)**
   ayarları doğru mu? Aynı sayfadaki **Test Gönderimi** kutusuna kendi
   adresinizi yazıp **Test Gönder** deyin. (*Gerçekten gönderir;
   gönderim geçmişine yazılmaz.*)
4. Kişinin spam/gereksiz klasörüne bakmasını isteyin.
5. Hâlâ gitmiyorsa: **İletişim → Davetler** sayfasındaki **Tesis kodu**nu
   kopyalayıp kişiye elle iletin. Kişi uygulamadan *Mevcut tesise katıl*
   ile kaydolabilir.

## "Sakin kaydını tamamlayamıyor"

* **"Bu davet bağlantısının süresi dolmuş"** → Davetler sayfasından
  yeniden gönderin.
* **"Yönetici onayı bekleniyor"** → Kişi sizin açmadığınız bir hesapla
  katılmaya çalışıyor. Önce **Yönetim → Kullanıcılar**'dan hesabını açın.
* **Kişi Tesis ID'yi bilmiyor** → Davetler sayfasından kopyalayıp
  gönderin.
* **Kişi web panelinden girmeye çalışıyor** → Sakin ve saha personeli web
  paneline **giremez**. Uygulamayı indirmesi gerekir.
* **Kişi telefonuyla giriş yapmayı deniyor** → Giriş **e-posta** iledir;
  telefon yalnızca iletişim bilgisidir.

## "Daire listesi boş geliyor"

* Blokları oluşturdunuz ama daireleri oluşturmadınız. **Tanımlar →
  Bloklar** ekranında bir bloğa girip kat ve daire ekleyin.
* Daireler **pasif** olabilir. **Tesis → Daireler**'de durumu kontrol
  edin — toplu tahakkuk yalnız **aktif** daireleri kapsar.

## "Tahakkuk çalışmadı / bazı daireler atlandı"

Toplu borçlandırma her zaman **neden atlandığını söyler**. Sık nedenler:

| Mesaj | Anlamı | Çözüm |
|---|---|---|
| *Bu dönemde aynı kalem zaten var* | O daireye o dönem aynı türde tahakkuk yazılmış | Mükerrer koruma çalışıyor, bir şey yapmayın |
| *Daire tipinin varsayılan tutarı yok* | Tutar yazmadınız, tip de tutar taşımıyor | Tutar yazın ya da **Tanımlar → Daire tipleri**'nde varsayılan aidat girin |
| *Arsa payı girilmemiş* | Arsa payına göre dağıtım seçtiniz | İlgili dairelere arsa payı girin (3.5) |
| *Metrekare girilmemiş* | Metrekareye göre dağıtım seçtiniz | Daire düzenleme ekranından metrekare girin |

## "Otomatik tahakkuk çalışmadı"

1. **Finansal İşlemler → Otomasyon** → plan **Etkin** mi?
2. **Tahakkuk günü** geldi mi? Gün gelmeden yazılmaz.
3. **İşlenen son dönem** sütununa bakın — bu ay yazıyorsa zaten işlenmiş
   demektir.
4. O ay için **Bu ayı atla** demiş olabilirsiniz.
5. **Otomasyon günlüğü** kartında ne zaman ne yapıldığı satır satır
   yazar.

## "Tahsilat girdim ama sakinin borcu kapanmadı"

Tahsilatı bir **tahakkuka bağlamanız** gerekir. **Finansal İşlemler →
Tahsilatlar → Yeni**'de daireyi ve ilgili borcu seçin. Daire/borç
seçmeden girilen tahsilat kasaya girer ama kimsenin borcunu kapatmaz.

## "Kasa bakiyesi beklediğimden düşük/yüksek"

**Finans → Kasalar** tablosunda **Bekleyen** sütununa bakın. Onay
bekleyen giderler bakiyeye **dahil değildir** — bilerek böyledir.
Onaylandıklarında bakiyeden düşerler.

## "Kamera görüntüsü gelmiyor"

1. Adres doğru mu? RTSP adresi `rtsp://` ile başlamalı.
2. Kullanıcı adı ve parola **adresin içinde** mi?
3. **Bağlantıyı test et** deyin — hata mesajı nedeni söyler.
4. Kameranın panelin çalıştığı sunucudan erişilebilir olması gerekir; ev
   ağındaki bir kamera dışarıdan görünmez.

## "Gecikme faizi hesaplanmıyor"

1. **Gecikme faizi uygula** açık mı?
2. **Aylık oran** sıfırdan büyük mü?
3. Tahakkuklarda **son ödeme tarihi** dolu mu? Vadesiz borç gecikmiş
   sayılmaz.
4. Vade üzerinden **tam bir ay** geçti mi? Faiz tam ay üzerinden
   hesaplanır.

## "Sakine bildirim gitmiyor"

1. Sakin uygulamayı açıp **giriş yaptı** mı? Giriş yapmamış cihaza
   bildirim gitmez.
2. Sakin kendi **Ayarlar → Bildirimler** ekranında **Mobil bildirimler**i
   kapatmış olabilir.
3. Telefonun sistem ayarlarında uygulama bildirimleri kapalı olabilir.

---

# B) KURULUM SONRASI KONTROL LİSTESİ

## Temel (bunlar olmadan sistem çalışmaz)

- [ ] **app.yonetiyor.com**'a kendi hesabımla girebiliyorum
- [ ] **İletişim → Davetler** sayfasında **Tesis kodu** görünüyor ve
      kopyalayabiliyorum
- [ ] **Tanımlar → Bloklar**'da bütün bloklar var
- [ ] **Tesis → Daireler** listesinde bütün daireler var ve sayı doğru
- [ ] **Tanımlar → Daire tipleri**'nde en az bir tip tanımlı
- [ ] **Yönetim → Kullanıcılar**'da bütün sakinler var ve **hepsinin
      e-postası dolu**
- [ ] En az bir sakin uygulamaya girip **Aidatım** ekranını görebildi
- [ ] **Tanımlar → Kasalar**'da en az bir kasa var
- [ ] **Tanımlar → Gelir/Gider Kalemleri**'nde en az bir **gider** kalemi
      var
- [ ] Bir dönem için tahakkuk oluşturuldu ve **Tesis → Daireler → (daire)**
      ekranında **Bakiye** görünüyor
- [ ] Test amaçlı bir tahsilat girdim, **Finans → Kasalar**'da bakiye
      arttı **ve** dairenin borcu azaldı

## Finans (tam çalışır kurulum)

- [ ] IBAN'lı bir **banka hesabı** tanımlı (sakinler "Öde" ekranında
      IBAN'ı görüyor)
- [ ] **Otomasyon** sayfasında bir **aidat planı** var ve **Etkin**
- [ ] **Borç hatırlatma** ayarlandı (kademeler + metin)
- [ ] **Gecikme faizi** kararı verildi (uygulanacaksa oran girildi)
- [ ] **Düzenli giderler** tanımlandı (kapıcı maaşı, bakım, sigorta)
- [ ] **Bütçe** hedefleri girildi
- [ ] **Finansal İşlemler → Borçlular** sayfasında yaşlandırma tablosu
      anlamlı görünüyor
- [ ] **Finansal İşlemler → Rapor motoru → Muhasebeye Aktarım** Excel
      çıktısı alınabiliyor

## Güvenlik (güvenlik hizmeti varsa)

- [ ] Bütün **NFC noktaları** tanımlı ve etiketler yapıştırıldı
- [ ] **Vardiyalar** tanımlı
- [ ] En az bir **devriye planı** aktif
- [ ] Bir görevli telefonuyla bir noktayı okutabildi
- [ ] **Kameralar** ekleniyor ve canlı görüntü açılıyor

## İletişim

- [ ] **Site kuralları** yazıldı
- [ ] En az bir **duyuru** yayınlandı ve sakinler gördü
- [ ] **SMS/E-Posta Yönetimi → Ayarlar**'da e-posta gönderimi test edildi
- [ ] **İletişim → Davetler**'de gitmemiş davet kalmadı

## Modüller (kullanacaksanız)

- [ ] **Görev kategorileri** tanımlı
- [ ] **Rezervasyon alanları** tanımlı (saatler + slot süresi)
- [ ] **Sayaçlar** tanımlı (ana + bölüm)
- [ ] **Şeffaflık** sayfasında ilk ay yayınlandı

---

# C) Kurulum sırasında olması gereken ama olmayan şeyler

Bu rehberi yazarken bulunan eksikler. Hiçbiri kurulumu **durdurmaz** ama
her biri yöneticiyi bir noktada zorlar.

## Tesis bilgileri

1. **Site adresi diye bir alan yok.** Ne web ne mobil — sistemde tesisin
   posta adresi hiçbir yerde tutulmuyor. Makbuz ve resmi çıktılarda
   adres gerekiyorsa bugün yazılamıyor.
2. **Yönetici tesis ayarlarına ulaşamıyor.** Saat dilimi, hava durumu
   konumu, otopark kapasitesi, güvenlik modu, gürültü eşiği — hepsi
   yalnız Yönetiyor ekibinin gördüğü **Platform → Ayarlar** ekranında.
   Sunucu bunların bir kısmını yöneticiye açıyor ama **ekran yok**.
3. **Tesis adı yalnız mobilden değiştirilebiliyor.** Web'de yönetici için
   böyle bir alan yok.

## Kullanıcılar

4. **Tek tek eklemede e-posta zorunlu, Excel aktarımında değil.** Aynı
   veri iki farklı kuralla giriliyor ve Excel yolu, davet alamayacak
   kullanıcılar üretebiliyor. Aktarım da e-postayı zorunlu tutmalı —
   ya da en azından e-postasız satırlar için açık bir uyarı vermeli.
5. **Yönetici, sakinin bildirim kanallarını göremiyor.** "Sakine bildirim
   gitmiyor" sorununda yöneticinin bakabileceği bir ekran yok; kişinin
   kendi ayarına bakması gerekiyor.

## Yapı

6. **Arsa payı yalnız tek tek girilebiliyor.** Ne toplu daire
   oluşturmada ne Excel aktarımında arsa payı sütunu var. 100 daireli bir
   sitede tek tek girmek gerekiyor. Metrekare için de aynı durum
   (Excel'de yok).

## Finans

7. **Onay bekleyen gideri panelden onaylayamıyorsunuz.** Gider
   oluştururken "Onay bekliyor" seçilebiliyor, **Finans → Kasalar**'da
   "Bekleyen" olarak görünüyor, ama panelde **onaylama/reddetme düğmesi
   yok**. Sunucu tarafı hazır, ekran eksik.
8. **Yanlış tahakkuku panelden düzeltemiyorsunuz.** Ters kayıt yolu
   sunucuda var ama **Borçlandırmalar** ekranında düğmesi yok.
9. **Banka ekstresi yüklerken hangi hesaba ait olduğunu
   seçemiyorsunuz.** Birden çok banka hesabı olan bir sitede ekstre
   varsayılan hesaba yazılıyor. Sunucu hesap seçimini destekliyor, ekran
   desteklemiyor.
10. **Sakinin ödeme kodunu yönetici göremiyor.** Banka eşleştirmesinin
    kesin çalışması için sakinin açıklamaya kendi kodunu yazması
    gerekiyor; kod sakinin uygulamasında görünüyor ama yönetici onu
    listeleyip topluca duyuramıyor.

## Kurulum akışı

11. **Sihirbazda kasa adımı yok.** Sekiz adım blok → daire → tip →
    sakin → personel → görev alanı → NFC → aidat diye gidiyor; ama aidat
    tahsil edebilmek için **kasa** şart ve sihirbaz bunu hiç
    söylemiyor. Yönetici ilk tahsilatı girmeye çalışınca öğreniyor.
12. **Rezervasyon alanı, görev kategorisi ve sayaç tanımları sihirbazda
    yok.** İlgili modüller kurulum yapılmadan sessizce boş görünüyor.
13. **E-posta gönderim ayarı sihirbazda yok.** Kurulumun en kritik
    bağımlılığı (davetler e-postayla gidiyor) sihirbazın hiçbir adımında
    geçmiyor.
14. **Kurulum hatırlatıcısını geri getirmenin yolu yönetici için yok.**
    Kutuyu "Daha sonra" ile kapattıysanız onu yeniden açan düğme
    (*Kurulum sihirbazını tekrar göster*) yalnızca Yönetiyor ekibinin
    gördüğü **Platform → Ayarlar** sayfasında. Sihirbazın kendisine sol
    menüden ulaşılabildiği için işiniz durmaz, ama hatırlatma bir daha
    çıkmaz.
