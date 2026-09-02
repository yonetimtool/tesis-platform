# P206 — Yönetici finans yetkisi + mobil parite

## §1 — YÖNETİCİ FİNANS YETKİSİ

### Ölçüm: hangi uçlar yöneticiye kapalıydı

Rol matrisi (`backend/tests/yetki/rol-matrisi.txt`, uçların tamamı ×
yedi rol) tarandı. Finans altında yöneticiye **kapalı (403)** olan
uçlar — **on altı**:

| Uç | Ne yapar | Kısıt bilinçli miydi? |
|---|---|---|
| `POST /finans/tahsilat` | Tekil tahsilat | Bilinçli (P167) — **gerekçe geçersiz** |
| `POST /finans/tahsilat/toplu` | Gün sonu toplu tahsilat | Aynı |
| `POST /finans/hareketler` | Gider/gelir kaydı | Aynı |
| `POST /finans/hareketler/{id}/onayla` | Gider onayı | Aynı |
| `POST /finans/hareketler/{id}/reddet` | Gider reddi | Aynı |
| `POST /finans/hareketler/{id}/iptal` | Hareket iptali | Aynı |
| `POST /finans/virman` | Kasa/banka arası aktarım | Aynı |
| `POST /finans/iade` | İade (ters kayıt) | Aynı |
| `POST /finans/acilis` | Açılış fişi | Aynı |
| `POST /finans/banka-eslestir` | Ekstre eşleştirme onayı | Aynı |
| `POST /dues/payments` | Aidat tahsilatı | Bilinçli (P167) — **gerekçe geçersiz** |
| `POST /borclandirma/toplu/onizleme` | Toplu tahakkuk önizleme | Gerekçesizdi |
| `POST /borclandirma/toplu` | Toplu tahakkuk | Gerekçesizdi |
| `POST /borclandirma/sayac` | Sayaç borçlandırma | Gerekçesizdi |
| `POST /borclandirma/ice-aktarim` | Borç içe aktarma | Gerekçesizdi |
| `PATCH /borclandirma/gecikme-ayari` | Gecikme faizi ayarı | Gerekçesizdi |

Kullanıcının verdiği somut örnek (`POST /borclandirma/toplu/onizleme`
yöneticiye 403) ölçümle doğrulandı — ve yalnız o değil, on altı uç.

Yöneticiye **zaten açık** olanlar (değişmedi): kasa yönetimi
(`/kasalar`), banka ekstresi içe aktarma ve eşleştirme (`/banka/*`),
bütçe (`/budget/*`), otomasyon (`/otomasyon-gunlugu`, düzenli giderler),
gecikme faizi işleme/önizleme, muhasebe tanımları ve ayarları,
raporlar (`/raporlar/*`, `/reports/*`), borçlulara hatırlatma/ödeme
planı/faiz affı, icra dosyaları, içe aktarım (`/ice-aktarim/*`).

### K1.1 — On altı ucun hepsi yöneticiye açıldı

Eski gerekçe (P167, `dues.py` içinde yazılıydı):

> "Tahakkuk bir BORÇ YAZMAKTIR ve yanlışsa düzeltilebilir; tahsilat ise
> PARA ALINDI beyanıdır ve muhasebe kaydını kapatır."

Ayrım mantıklı ama **yanlış yere çizilmişti**: parayı kapıda elden alan
kişi **yöneticidir**, platform admini değil. Platform admininin o
tahsilatı girebilmesi için önce yöneticiden duyması gerekiyordu — yani
kaydın doğruluğu zaten yöneticiye dayanıyordu. Yetkiyi ondan almak,
kaydı **geciktirmekten** başka bir şey yapmıyordu; modül, onu kullanacak
kişi için fiilen yoktu.

**Gider onayında kendi kaydını onaylama** sorusu: engellenmedi. Tek
yöneticili sitelerde (çoğunluk) engellemek, gider onayını **imkânsız**
kılardı. Bedeli açıkça yazıyorum: küçük sitede dört göz ilkesi
işlemiyor. Karşılığı denetim kaydıdır — kaydı kimin oluşturduğu ve
kimin onayladığı `audit_log`'ta ayrı ayrı duruyor ve denetçi ikisini de
okuyor. İki yöneticili sitede ayrım doğal olarak oluşuyor.

### K1.2 — Platform admini ile yönetici farkı

**Platformda kalan** (yöneticiye kapalı, bilinçli):

| Alan | Uçlar | Gerekçe |
|---|---|---|
| Tesis yaşam döngüsü | `/tenants*` (oluştur, sil, yönetici ata, kota) | Abonelik ve müşteri ilişkisi platformun; tesisin kendini silmesi/çoğaltması ürün sınırı |
| Sürüm politikası | `/surum-politikasi*` | Zorunlu güncelleme tüm tesisleri etkiler (P202) |
| Platform gözlemi | `/admin/overview`, `/audit` (platform kapsamı), `/devices` | Çapraz tesis görünümü |
| Destek kuyruğu | `/support/all`, `PATCH /support/{id}` | Platform ekibinin işi |
| Tanıtım sitesi | `/tanitim-iletisim*` | Tesise ait değil |

Kural cümlesi: **tesisin parası, kadrosu ve kayıtları yöneticinindir;
tesisin var olup olmaması, ne kadar kota aldığı ve hangi sürümü
çalıştırdığı platformundur.**

### K1.3 — Denetçi ve sakin değişmedi

Denetçi **salt okuma**: on altı ucun hepsinde 403 alır
(`test_DENETCI_finans_YAZMA_uclarinda_403_ALIR`). Mali gözetim okumakla
yapılır; yazma yetkisi gözetimin bağımsızlığını bozardı. Sakin finans
uçlarının hiçbirine giremez (ayrı test).

### K1.4 — Yetki genişledi, KAPSAM genişlemedi

Yönetici yalnız **kendi** tesisinde yazar. Üç yerden birden kapalı:
`get_tenant_db` oturumu token'daki tenant'a RLS ile bağlar; başka
tesisin kasa/daire kimliği 422 `invalid_reference` alır; kayıt
`tenant_id=user.tenant_id` ile yazılır (istekten gelmez). Test:
`test_YONETICI_BASKA_TESISIN_kasasina_YAZAMAZ`.

### Ölçüm — kilit kanıtı

`test_p206_yonetici_finans.py` 4 test. `_YAZMA`yı `require_role("admin")`
yapınca iki test düştü (`403 == 422`), geri alındı. Rol matrisi
yeniden üretildi: **16 satır** `RED` → `IZIN` (yalnız yönetici sütunu).
Ayrıca eski beklentiyi kilitleyen üç test güncellendi
(`test_finans.py::test_rbac`, `test_dues.py::test_yonetici_tahakkuk_
tenant_izolasyonu`, `test_borclandirma_uc.py::test_rbac_yazma_ADMIN` →
`..._YONETIM`) — hepsi **kusuru** kilitliyordu.

---

## §2 — TAHSİLATTA BORÇLU LİSTESİ

### Kök neden — ÖLÇÜLDÜ, yetkiyle İLGİSİ YOK

```
GET /users?limit=500  -> 422 {"field":"query.limit","message":"Input should be less than or equal to 200"}
GET /users?limit=200  -> 200 (7 kayıt)
```

İstemci (`useKisiler`) `limit=500` istiyor, uç 200 tavanında **422**
dönüyor, SWR hatası `data?.items ?? []` ile **sessizce** boş listeye
dönüşüyordu. Kullanıcı "kimseyi seçemiyorum" diyordu; ekran hiçbir şey
söylemiyordu. §1 ile ilgisi yok — yönetici zaten `/users` okuyabiliyor.

### K2.1 — Üç ayrı düzeltme

1. **Tavan uyumu:** `/users` limiti 200 → **1000** (`/units` P187'de aynı
   sebeple aynı şeyi yapmıştı: istemci ve tavan uyuşmuyordu).
2. **Sessizlik bitti:** `useKisiler` artık `{kisiler, hata}` dönüyor ve
   ekran hatayı yazıyor. Bir listenin boş görünmesiyle alınamamış olması
   kullanıcı için aynı şey değil.
3. **Liste artık BORÇLULAR:** tahsilat penceresinde sorulan soru "kime
   borcu var"dır. Kaynak `/finans/yaslandirma` — borçlular ekranının
   kaynağıyla **aynı** (P192 tek kaynak kuralı; ikinci bir uç yazmak
   aynı sayının iki yerde ayrışması demekti). Satırda **ad · daire ·
   kalan tutar** yazar.

### K2.2 — Peşin ödeme AÇIK bir seçim

P192'de "borç öncesi peşin ödeme alacakta bekler" senaryosu var, yani
borcu olmayandan tahsilat mümkün olmalı. İki listeyi birleştirmek yerine
**açık bir kutu** kondu ("Borcu olmayan birinden tahsilat"). Birleştirmek,
borçlu ararken yüzlerce borçsuz adı da listelemek olurdu; gizlemek ise
meşru bir işlemi imkânsız kılardı.

Borçlu yoksa ekran bunu **yazar** ve peşin ödeme kutusuna yönlendirir —
boş bir seçim kutusu bırakılmaz (kabul kriteri 6).

### K2.3 — Borçlu seçilince daire otomatik dolar

Borç daireye bağlıdır. Daireyi ayrıca elle seçtirmek, yanlış daireye
makbuz kesme riskini bedavaya ekliyordu. Arama hem adda hem daire
numarasında çalışır.

### Ölçüm

`p206-tahsilat-borclu.dom.test.ts` 6 test (borçlu listesi + tutar,
kişisiz daire atlanır, borçlu yok mesajı, uç hatası görünür, arama,
peşin ödeme, seçimde dairenin gövdeye gitmesi). Kilit kanıtı: borçlu
listesi boş dönecek şekilde bozuldu → 3 test düştü, geri alındı.

---

## §3 — IBAN VE BANKA ALANI

### Ölçüm: ne vardı

```
schemas.py:  _IBAN_PATTERN = r"^TR[0-9]{24}$"     (Pydantic)
DB CHECK:    ck_kasa_iban  iban ~ '^TR[0-9]{24}$'
web:         { ad: "iban", tip: "metin" }          (serbest metin, gruplama yok)
             { ad: "banka_adi", tip: "metin" }     (elle yazılıyor)
```

Bu denetim **iki uçta birden yanlıştı**:

* **Çok dar:** yurt dışındaki bir tesis kendi IBAN'ını giremiyordu; DB
  hatası "değer kısıt ihlali" diyordu, yani kullanıcı nedenini bile
  anlayamıyordu.
* **Çok gevşek:** "TR" + 24 rakamın **herhangi biri** geçerli sayılıyordu.
  Tek hanesi yanlış yazılmış bir IBAN kaydediliyor, para yanlış hesaba
  gidiyor ve bu ancak ödeme kaybolunca fark ediliyordu. (Ölçüldü:
  `TR330006100519786457841327` eski regex'ten **geçiyor**, mod 97'den
  geçmiyor.)

### K3.1 — Ülke sınırı YOK; doğruluk MOD 97 ile

Uzunluk **ülkeye göre** denetlenir (tablo: TR=26, DE=22, GB=22, …).
Tabloda olmayan ülke için yalnız genel ISO sınırı (15–34) uygulanır —
listede olmayan bir ülkeyi reddetmek, doğru IBAN'ı olan kullanıcıyı
kilitlemek olurdu. Doğruluk **ISO 13616 mod 97** sağlama toplamıyla
denetlenir; regex'in yapamadığı tam olarak buydu.

Katmanlar:

| Katman | Ne denetler | Neden orada |
|---|---|---|
| DB CHECK (göç 0097) | Yapı: `^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$` | "Bu alan bir IBAN'dır"ın veritabanında söylenebilecek en doğru hâli. Mod 97'yi CHECK içinde yazmak mümkün ama okunmaz bir ifade olur ve kural iki dilde iki kez bakım isterdi |
| Pydantic (`app/iban.py`) | Ülke uzunluğu + mod 97, **kanonik** hâle çevirir | Son söz sunucunundur; istemci her zaman bizim istemcimiz değil |
| Web (`lib/iban.ts`) | Aynısı + yazarken gruplama | Kullanıcıyı 422 beklemeden uyarır |

Kural iki dilde yazılı; ayrışmaya karşı **aynı örnek kümesi** iki tarafta
da koşuyor (`test_p206_iban.py` / `p206-iban.test.ts`).

### K3.2 — Depoda boşluksuz, ekranda dörderli

Aynı IBAN'ın `TR33 0006…` ve `TR330006…` diye iki kayıt üretmesi, IBAN'ı
eşleme anahtarı olarak kullanan **banka ekstresi eşleştirmesini** (P191)
bozardı. Kanonik biçim depoda; okunabilirlik çizim katmanının işi.
Yazarken alan dörderli gruplar ve azami uzunluğu **sert** sınırlar
(sınırsız yazdırıp sonra reddetmek kullanıcıyı boşuna uğraştırırdı).

### K3.3 — Banka adı: liste + otomatik doldurma + serbest giriş

TR IBAN'ı: `TR` + 2 kontrol + **5 hane banka kodu** + 1 rezerv + 16 hane
hesap. EFT kodları 4 hanedir ve alana soldan sıfırla doldurulur
(`0062` → `00062`) — bu yüzden **son dört hane** alınır. (İlk yazımda ilk
dördü alıyordum; Garanti "0006" diye okunup listede bulunamıyordu, örnek
IBAN'la görüldü ve düzeltildi.)

IBAN girilince banka adı **otomatik dolar** (boşsa; üzerine yazmak
serbest). TR dışında banka **uydurulmaz** — kodun yeri ülkeye göre
değişir ve tahmin, yanlış banka adı yazdırırdı.

**Liste kapalı değil.** `datalist` ile hem seçim hem serbest giriş var.
Kapalı bir açılır liste, katılım bankalarını, yeni lisans alanları ve
yabancı şubeleri dışarıda bırakır; gerçek bir hesabı **kaydedilemez**
yapardı. Banka adları çeviri taramasından muaf tutuldu (gerekçe
`tests/i18n.test.ts` içinde): banka adı bir cümle değil, **kurumun tescilli
adıdır** ve mutabakatta ekrandaki adla bankanın adı aynı olmalı.

### Ölçüm

Backend `test_p206_iban.py` 16 test, web `p206-iban.test.ts` 8 +
`p206-iban-alani.dom.test.ts` 5 test. Kilit kanıtı: mod 97 denetimi
kaldırıldı → 3 test düştü (biri açıkça "eski regex bunu geçiriyordu"
diyen test), geri alındı. Göç 0097 downgrade→upgrade ile doğrulandı.

**Ölçemediğim:** banka kodu listesinin güncelliği — kodlar TCMB/BKM
yayınından elle alındı; yeni lisans alan bir bankanın kodu listede
olmaz (serbest giriş bu yüzden korundu).

---

## §4 — MOBİL PARİTE (P204 öncelik listesi 2–6)

### ÖNCE ÖLÇÜM: beşinin gerçek durumu

P204'te "mobil ekranların yazma kapsamını ekran ekran açmadım" demiştim.
Açtım — ve **tablo yanlıştı**:

| Madde | P204'te | GERÇEK (ölçüldü) |
|---|---|---|
| 4.1 Tahsilat girişi | "yok" | **Doğru: yok.** Mobilde `/finans/tahsilat`'a giden hiçbir çağrı yok (`odeme_api.dart` sakinin KENDİ online ödemesi) |
| 4.2 Davet / kullanıcı ekleme | "tam" | **YANLIŞ — KIRIK.** `addStaff` gövdesi `ad`+`telefon`+`role`; uç **422** veriyor: `{"field":"email","message":"Field required"}`. P197'den (e-posta zorunlu, göç 0089) beri mobilde personel eklenemiyordu |
| 4.3 Gider kaydı | "yok" | **Doğru: yok** |
| 4.4 Borçlular | "yok" | **Doğru: yok** (`/finans/yaslandirma` mobilde hiç çağrılmıyor) |
| 4.5 Sayaç okuma | "yok" | **Doğru: yok** |

Yani beş maddeden biri "var" sanılıyordu ve aslında **bozuktu**.

### K4.1 — Tahsilat: dört karar, sekiz alan değil

Bu ekranın kullanıldığı an, yöneticinin kapıda biriyle **konuştuğu**
andır. Web formunu (kişi, daire, yöntem, kasa, tutar, tarih, açıklama,
belge no) telefona kopyalamak o konuşmayı form doldurmaya çevirirdi.
Ekran dörde indi: **kim** (borçlu listesinden, tutarıyla) → **ne kadar**
(varsayılan: kalan borcun tamamı) → **hangi kasa** (tek kasa varsa
sorulmaz) → kaydet. Tarih bugün, yöntem elden — mobil tahsilatın tanımı
bu.

**Çift tıklama koruması mobilde de var**: `Idempotency-Key` form örneği
başına üretilir, başarılı kayıttan sonra yenilenir. Sahada bağlantı
kopar, kullanıcı "gitmedi" sanıp yeniden basar; anahtar olmasa kasada iki
hareket olurdu ve bu ancak ay sonu mutabakatında görülürdü.

**Makbuz ve bildirim sunucuda**: web ile aynı uç (`/finans/tahsilat`),
yani makbuz numarası ve sakine giden bildirim aynı kodda üretiliyor.
Mobil için ikinci bir yol açmak, ikisinin ayrışma riskini bedavaya
eklerdi. Ekran bunu kullanıcıya da yazıyor.

### K4.2 — Davet: e-posta eklendi (kırık akış onarıldı)

E-posta alanı **zorunlu** ve düzenlemede **kapalı**: e-posta değişikliği
ayrı bir akıştır (doğrulama + eski adrese bildirim, P184) ve buradan
sessizce yapmak, hesabı başkasına devretmenin kolay yolu olurdu.

Biçim denetimi kaba; son sözü sunucu söyler (`EmailStr`). İstemcideki
amaç, açık bir yazım hatasını **istek atmadan** yakalamak.

Excel toplu aktarım **yok** (P204 kararı korundu). Blok/daire seçimi:
mobil personel ekranı yalnız **saha personeli** açıyor ve saha personeli
daireye bağlanmaz — sakin ekleme mobilde zaten yok, dolayısıyla dar
ekranda blok/daire seçicisi gerekmedi. **Sakin ekleme mobile
taşınmadı** ve bu bilinçli: sakin kaydı daire bağı, malik/kiracı ayrımı
ve KVKK onayı ister; telefonda yarım bir sakin kaydı, web'de düzeltilmesi
gereken bir kayıt üretirdi.

### K4.3 — Gider: onay durumu görünür, fiş fotoğrafı VAR

`durum` sessiz bir varsayılan değil, ekranda **anahtar**: "Onaya gönder"
açıkken kayıt `onay_bekliyor` gider ve ekran "onay bekleyen gider kasa
bakiyesini DÜŞÜRMEZ" diye yazar (P192). Sessiz bir varsayılan,
yöneticinin bakiyeyi yanlış okumasına yol açardı.

**Fiş fotoğrafı: evet.** Nakit gider en çok tartışılan kalemdir ve fiş
sahada, telefondadır. Mevcut ek mekanizması kullanıldı — göç 0098 ile
`finansal_hareket` ek varlık tiplerine eklendi (yeni tablo yok, yetki
kümesi finans router'ından okunuyor). Fotoğraf **zorunlu değil**:
zorunlu kılmak, fişi olmayan meşru gideri (kapıcı avansı, banka masrafı)
kaydedilemez yapardı. Yükleme başarısız olursa **kayıt geri alınmaz** —
para hareketi gerçek, fotoğraf onun kanıtı.

### K4.4 — Borçlular: kova ŞERİDİ (dar ekran kararı)

Web'de dört kova yan yana kart. Telefonda dördünü yan yana koymak her
birini ~80 px'e sıkıştırır (başlık kırılır, tutar okunmaz); alt alta
koymak ise ekranın tamamını özete verip **asıl listeyi** katlar.

**Seçilen**: kovalar yatay kaydırılan bir şerit (her biri 140 px, tek
bakışta ikisi görünür), altında seçili kovanın listesi. Sahada sorulan
soru "en eski borçlular kim" — tek dokunuşla yanıtlanıyor.

Toplu hatırlatma var; buton **yalnız seçim varken** görünür (boş seçimle
basılabilen bir buton, hiçbir şey yapmayıp kullanıcıyı "gitti mi?" diye
bırakırdı). Tahsilat oranı **tek kaynaktan**: `/finans/tahsilat-gostergesi`
(P192 §5.2) — aynı sayıyı mobilde yeniden hesaplamak, iki ekranda iki
farklı oran demekti.

### K4.5 — Sayaç okuma: tek liste + fotoğraf

Web dört adımlı sihirbaz (masabaşı için doğru). Sahada kişi bodrumda,
tek elle çalışıyor: ekran **tek liste** — üstte kalem/ana sayaç/dönem,
altında daire daire değer alanları. Adımlara bölmek, her sayaçta
ileri-geri gitmek demekti.

**Önceki okuma her satırda yazar** ve **geri sayan okuma istek atmadan
reddedilir**: sahada en sık yapılan hata değeri öncekinin altına
yazmaktır; sunucuya gönderip 422 beklemek, sayacın başında duran kişiyi
bir gidiş-dönüş daha bekletirdi.

**Fotoğraf: evet — ama DAİREYE bağlı.** "Benim sayacım 145
göstermiyordu" itirazı her dönem çıkar ve bugün yanıtlanamıyor. Fotoğraf
`varlik_tipi=unit` ekine yazılır (metninde dönem + okunan değer), çünkü
itiraz daire üzerinden gelir ve okuma kalıcı bir varlık değil, bir
borçlandırma girdisidir. Borçlandırmadan **sonra** yüklenir: önce
fotoğraf yükleyip sonra borçlandırsaydık, yarım kalan akış daireye
"sahipsiz" ek bırakırdı.

Borçlandırma **web ile aynı uca** gider (`POST /borclandirma/sayac`) —
dağıtım kuralının iki yerde ayrışma riski yok.

### Yetkiler ve izolasyon

Mobil istemci **hiçbir rol kontrolü yapmaz**; kural sunucuda (§1: admin +
yönetici) ve ekran yalnız "reddedilecek düğmeyi çizmeme" kararını verir.
Menü girişleri yalnız yöneticide (`home_menu.dart`), yazma uçlarının
kapısı `test_p206_yonetici_finans.py` ile kilitli. Tesis izolasyonu
sunucuda (RLS + `tenant_id=user.tenant_id`), mobil için ek bir yol yok.

### Ölçüm

Mobil: `p206_mobil_finans_test.dart` **10 test**,
`p206_mobil_sayac_personel_test.dart` **5 test** — hepsi taklidi HTTP
adapter'ında kuruyor (P200 dersi), yani gövdeyi kuran katman da testin
içinden geçiyor. Ölçülenler: giden uç + gövde + `Idempotency-Key`
başlığı, tek kasada seçici çizilmemesi, borçlu yoksa mesaj, onay
durumunun gövdeye gitmesi, geri sayan okumanın istek atmadan
reddedilmesi.

**Kilit kanıtı:** `addStaff` gövdesinden `email` çıkarıldı → ilgili test
düştü; geri alındı. Mobil tam takım **2029 yeşil**.

**Ölçemediğim:** gerçek cihazda kamera akışı (fotoğraf çekme ve yükleme
uçtan uca sürülmedi — `image_picker` testte taklit); MinIO'ya gerçek
presigned PUT; sahada tek elle kullanım hissi.

---

## Tam takım sonrası düzeltmeler (§1 ve §3'ün yakalanan artçıları)

İlk tam backend koşumu **5 kırmızı** gösterdi — hepsi bu turda bilinçli
değiştirilen davranışı kilitleyen eski testler ya da onların yan etkisi:

1. `test_ters_kayit::test_YALNIZ_ADMIN_iptal_edebilir` — iptal artık
   yöneticide. Test yeniden adlandırıldı
   (`test_YONETICI_DE_iptal_edebilir_SAHA_EDEMEZ`) ve **saha rolünün hâlâ
   giremediği** ölçülüyor. İptal silmez, ters kayıt yazar — yetkinin
   genişlemesi denetim izini zayıflatmıyor.
2. `test_yonetici::..._TAHSILAT_YAZAMAZ` — tahsilat artık yöneticide.
   Ayrıca ölçüm sırasında görüldü: `/dues/payments` `Idempotency-Key`
   **zorunlu** (P192 §6.2), anahtarsız istek 400 alıyor — bu yetkiyle
   ilgili değil, test anahtarı göndermiyordu.
3. `test_p192_kasa` + `test_p192_otomasyon` — testler
   `f"TR{rastgele:024d}"` ile **sahte IBAN** üretiyordu; eski regex'ten
   geçiyordu, mod 97'den geçmiyor. `conftest.rastgele_iban()` eklendi
   (sağlama toplamı doğru). İlk yazımında 24 haneli gövde üretip
   `iban_uzunluk` aldı — TR IBAN'ında gövde 22 hanedir; ölçümle
   düzeltildi.
4. `test_health::..._SEMA_SURUMUNU_bildirir` — API imajı göç 0098'den
   önce derlenmişti (imaj beklenen şema başını gömüyor). Yeniden
   derleme çözdü; kod kusuru değil.

Bu dördü de "test yeşil sanıyordum" durumunun karşıtı: **tam takım
olmasaydı** üçüncü madde (sahte IBAN'lar) prodüksiyonda değil ama
gelecekteki her banka kasası testinde sessizce yanlış veri üretmeye
devam ederdi.
