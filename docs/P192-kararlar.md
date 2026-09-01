# P192 — Finans tutarlılığı ve otomasyon: kararlar ve gerekçeleri

Kaynak: `docs/finans-analiz.md` (P191 sonrası okuma turu).
Bu belge **ne yapıldığını değil, neden öyle yapıldığını** yazar. Ne
yapıldığı `docs/P192-dagitim.md`de; nasıl test edileceği
`docs/P192-test-yolharitasi.md`de.

---

## Bölüm 1 — Tek defter

### Karar: tek doğru kaynak `finansal_hareket` (para) + `dues_assessment` (borç)

Üç aday vardı ve üçü de aynı parayı yazıyordu:

| İşlem | `dues_payment` | `finansal_hareket` | `budget_entry` |
|---|---|---|---|
| `POST /dues/payments` | yazar | YAZMAZ | yazar |
| `POST /finans/tahsilat` (vezne) | YAZMAZ | yazar | YAZMAZ |
| Banka eşleştirme | yazar | yazar | YAZMAZ |

`finansal_hareket` seçildi çünkü diğer ikisinin **yapamadığı** şeyleri
zaten yapıyor:

* **Kasa bağı var** (`kasa_id`) — kasa bakiyesi ondan türetiliyor.
  `dues_payment`in kasa kavramı yoktu; kabul ölçütü 2'nin ("aidat ödemesi
  kasayı artırsın") başka türlü karşılanması mümkün değildi.
* **Silinemez.** `app_rw`nin DELETE yetkisi göç 0047'de geri alındı.
  `budget_entry` DELETE edilebiliyordu — bir para defteri için yanlış.
* **Düzeltme yolu modellenmiş:** `ters_kayit_id` (iptal, kayıt düzeltmesi)
  ve `iade_edilen_id` (iade, gerçek para dönüşü) **ayrı** alanlar.
* **Merkezi belge no** (`belge_no`) ve **idempotency** (`idempotency_key`,
  `idem_satir`) taşıyor.
* **Onay durumu** (`durum`) taşıyor.

Diğer ikisi bunların hiçbirini birlikte taşımıyordu; ikisi de
`finansal_hareket`in eksik birer kopyasıydı.

**Borç ayrı kaldı ve bu bilinçli.** `dues_assessment` bir *borç*tur, para
hareketi değildir. Bakiye = tahakkuk − ödenen; iki tablodan gelmesi
doğrudur, çünkü bir borç ile onu kapatan para aynı satır değildir.

### "Ödenen" tek bir yerde tanımlı

`app/defter.py::tahsilat_etkisi()`. Kural:

```
odenen = Σ işaret(yon) × tutar
         tip = 'tahsilat'                                   -> +
         tip ∈ ('iade','iptal') VE ilgili satır tahsilat    -> −
         yalnız durum = 'odendi'
```

İki tuzak vardı:

1. **Yön üzerinden ayırmak yetmezdi.** Bir *gelir iptali* de `cikis`
   yönlüdür; tahsilattan düşülseydi tahsilat toplamı yanlış çıkardı. Bu
   yüzden iade/iptal satırı, iptal ettiği satıra JOIN edilip onun tipine
   bakılıyor.
2. **Eski iade/iptal satırları borç atfı taşımıyordu.** `coalesce` ile
   atıf orijinal satırdan tamamlanıyor; ayrıca `/finans/iade` ve
   `/finans/hareketler/{id}/iptal` artık `assessment_id` + `donem`
   kopyalıyor. Kopyalamasaydı para kasadan çıkar, borç kapalı kalırdı —
   sakin ödemediği bir borcu ödenmiş sanırdı.

### Yanıt biçimleri korundu

`DuesPaymentOut` ve `BudgetEntryOut` aynen duruyor; defter satırı bu
biçimlere **çevriliyor** (`dues.py::_odeme_out`, `budget.py::_entry_out`).
Defteri tek kaynak yapmak bir **iç** karardır; mobil ve paneli aynı turda
kırmak değişimi gereksizce riskli kılardı.

Üç alan opsiyonelleşti (`unit_id`, `kaydeden_user_id`, `idempotency_key`,
`kategori_id`) çünkü defterde de opsiyoneller: vezneden girilen bir
tahsilat daireye bağlı olmayabilir.

### Aidat tahsilatı hâlâ "gelir"dir

Eskiden başarılı aidat ödemesi `budget_entry`e `kaynak='aidat_odeme'` bir
gelir satırı üretirdi ve şeffaflık raporunun "toplam gelir"i onu
içeriyordu. Tek deftere geçerken bu davranış **korundu**:
`defter.GELIR_TIPLERI = ('gelir', 'tahsilat')`. Dışarıda bıraksaydık
sitenin geliri bir gecede aidat kadar düşük görünürdü.

Kategori de korundu: `/dues/payments` ve banka eşleştirme, tahsilat
satırına `budget_category_id = "Aidat"` yazıyor (get-or-create). Böylece
bütçe kırılımı eskisi gibi çalışıyor ama **ayrı bir satır** üretmiyor.

### Banka eşleştirme artık pay başına satır yazıyor

P191'de bir transfer üç ayı kapatsa bile deftere **tek** satır yazılıyor,
borç kapanışı `dues_payment`te üç satırla izleniyordu. Tek defterde bu
mümkün değil: her pay kendi tahsilat satırını alıyor
(`idem_satir = 1..N`, aynı `idempotency_key`). Toplamları transferin
tutarına eşit olduğu için **kasa bakiyesi şişmiyor**, buna karşılık her
ayın kapanışı ayrı ayrı izlenebiliyor.

### DELETE artık ters kayıt

`DELETE /budget/entries/{id}` satır **silmiyor**, tam tutarlı bir ters
kayıt yazıyor (yanıt yine 204). Defterde DELETE yetkisi yok ve olmamalı:
silme, "bu para nereye gitti" sorusunu cevapsız bırakırdı. Listeler iki
satırı da göstermiyor (`defter.iptal_edilmis()`), toplamlar zaten
işaretle götürüyor.

### Göç 0083 geri alınabilir

Taşınan her satır `goc_kaynak` (`dues_payment` | `budget_entry`) ve
`kaynak_id` taşıyor; `downgrade()` tam olarak onları siliyor. Kaynak
tablolar **silinmedi**, yalnız yazılmaz oldu — geri dönüşte veri yerinde.

İki bilinçli sınır:

* `durum='iptal'` ödemeler taşınmadı: hiçbir zaman para hareketi
  olmamışlardı (kart sağlayıcıdan başarısız döndü).
* `kaynak='aidat_odeme'` bütçe satırları taşınmadı: aynı parayı ikinci
  kez yazarlardı — ödemenin kendisi zaten `tahsilat` olarak taşınıyor.

Kasası olmayan tesislere `KASA / Merkez Kasa` açıldı. Alternatif
`kasa_id=NULL` bırakmaktı; o zaman para defterde görünür ama **hiçbir kasa
bakiyesinde** görünmezdi — §2.1'in düzelttiği kusurun aynısı.

### `hareket_durum`a `iptal` eklendi

Kart ödemesi sağlayıcıdan başarısız dönünce satır `bekliyor`da kalsaydı,
hiçbir zaman gelmeyecek para sonsuza kadar "bekleyen tahsilat" görünürdü.

---

## Bölüm 2 — Kasa tutarlılığı

### 2.1 Banka hesabı = `banka_mi` olan kasa, ayrı bir tablo değil

Yeni bir `bank_account` tablosu **açılmadı**. `kasa` zaten `banka_mi`,
`iban`, `banka_adi`, `sube` taşıyor ve bir CHECK bu alanların yalnızca
banka kasasında dolmasını zorluyor. İkinci bir tablo, "bakiye nereden
hesaplanıyor" sorusunu ikiye bölerdi — Bölüm 1'in düzelttiği hatanın
aynısı.

Eksik olan şey **ekstrenin hangi hesaba ait olduğuydu**. Göç 0084
`bank_transaction.kasa_id` ekliyor; `/banka/ice-aktar` artık `kasa_id`
alıyor ve eşleştirme parayı **o hesaba** yazıyor. Bir tesisin iki banka
hesabı olabilir (site hesabı + demirbaş hesabı); ikisinin ekstresini aynı
kasaya yazmak bakiyeleri tek sayıya karıştırmak olurdu.

FK `ON DELETE SET NULL`: bir kasa kapatılırsa geçmiş ekstre satırları
kaybolmamalı. `RESTRICT` olsaydı kullanılmış bir kasa hiç silinemezdi.

### 2.2 Bakiye yalnız gerçekleşmiş hareketi sayar

`kasa_bakiyeleri` `durum` süzgeci **uygulamıyordu**. Onay bekleyen bir
gider ve sağlayıcıdan dönmemiş bir kart ödemesi bakiyeye anında
yansıyordu; yönetici onaylamadığı bir ödemeyi kasadan düşülmüş görüyordu.

Artık `bakiye = açılış + Σ(durum='odendi')`. Bekleyen tutar **kaybolmuyor**,
ayrı dönüyor: `bekleyen_cikis_kurus` / `bekleyen_giris_kurus` +
`bekleyen_cikis_toplam_kurus`. "Bakiye X, bekleyen Y" tek rakamdan daha
doğru bir tablo. Panelde de ayrı sütun.

`iptal` durumundakiler **bekleyende de yok**: gerçekleşmeyeceği belli olmuş
bir hareketi beklentide tutmak, hiç gelmeyecek parayı yöneticiye vaat
etmek olurdu.

Aynı süzgeç `rapor_motoru`nun kasa mutabakat raporuna da eklendi; yoksa
mutabakat tablosu ile kasa ekranı ayrışırdı. (Orada `docs/finans-analiz.md`nin
raporladığı bir **ölü satır** da temizlendi: sorgu çalıştırılıp sonucu
`and []` ile atılıyordu.)

### 2.3 Onay = gerçekleşti, red = hiç olmadı

`durum='onay_bekliyor'` P167'de eklendi, panel sayıyordu, **onaylayan uç
yoktu**. İki uç eklendi:

* `POST /finans/hareketler/{id}/onayla` → `odendi`. Hareket o an kasa
  bakiyesine girer.
* `POST /finans/hareketler/{id}/reddet` → `iptal`.

Red neden **ters kayıt değil**: ters kayıt *gerçekleşmiş* bir hareketi
düzeltir. Reddedilen gider hiç gerçekleşmedi, kasadan hiç çıkmadı. Ters
kayıt yazsaydık defterde birbirini götüren iki sahte satır olurdu.

Satır **silinmiyor**: "bu harcama talebi reddedildi" bilgisi denetimin
konusudur; silinirse bir daha sorulamaz. İki uç da ayrı denetim eylemi
yazıyor (`finans_hareket_onay` / `finans_hareket_red`) — "kim girdi" ile
"kim onayladı" aynı kayıtta toplanırsa onayı verenin kim olduğu denetimde
cevapsız kalırdı.

Ayrıca özet kartındaki "Borçlarım" sorgusu `durum != 'odendi'` diyordu;
`iptal` eklenince reddedilmiş bir harcama "borcum var" diye sayılacaktı.
`in ('bekliyor','onay_bekliyor')` olarak düzeltildi.

---

## Bölüm 3 — Kayıp para ve eksik tahakkuk

### 3.1 Gecikme faizi artık yazılan bir borç

**Ölçülen kusur:** faiz iki yerde hesaplanıyordu (`dues.py` liste
zenginleştirmesi, `rapor_motoru`) ama **hiçbir yere yazılmıyordu**. Sakin
ana borcunu ödeyince faiz buharlaşıyordu; tahsil edilebilir bir kalem
değil, ekranda görünen bir sayıydı.

**Karar:** faiz `dues_assessment`e `kalem_tipi='faiz'` bir satır olarak
yazılır ve hangi borçtan doğduğunu `kaynak_assessment_id` ile taşır.
Alternatif "ana borcun tutarını artırmak"tı; o zaman ana para ile faiz
ayırt edilemez, kısmi ödeme hangisine sayıldı belirsiz kalır ve faiz affı
imkânsızlaşırdı.

Üç kural:

* **Her koşum farkı yazar** — o ana kadar birikmiş toplam eksi daha önce
  yazılmış faiz. Aylık koşum faizi artırarak ilerler; tekrarlı koşum 0
  fark bulur ve hiçbir şey yazmaz. Veritabanı da aynı borca aynı dönemde
  ikinci kalemi engelliyor.
* **Faize faiz işlemez** — yazılan kalem `gecikme_uygula=false` taşır;
  aksi halde basit faiz kuralı sessizce bileşiğe dönerdi.
* **Kapanmış borca faiz işlemez**, ama geçmişte birikmiş faiz **ayakta
  kalır**: borcun kapanması faizi silmez.

Ekranda gösterilen `gecikme_kurus` artık **henüz yazılmamış** faizdir
(yazılmış kalemler düşülür); yoksa aynı faiz hem orada hem ayrı bir borç
kalemi olarak iki kez görünürdü.

**Faiz affı** = faiz kaleminin ters kayıtlanması (§6.3 ile aynı yol),
denetim kaydıyla. Affedilmiş faiz "yazılmış" sayılmaz — af geri
alınabilir olsun diye.

**Ayar:** `tenant.gecikme_uygula` eklendi. Oranı 0 yapmak "hiç uygulama"
demenin dolaylı yoluydu ama "oran henüz girilmedi" ile aynı görünürdü;
bazı siteler faiz **almaz** ve bu bir karardır, eksik veri değil.

### 3.2 Kısıt kaldırılmadı — kalem-farkındalı yapıldı

**Analiz raporumu ölçüm düzeltti.** `finans-analiz.md` "UNIQUE (tenant,
unit, donem) aynı aya ikinci kalemi engelliyor" diyordu; kaynağı
`models.py`deki eski `__table_args__`tı. Veritabanında 0018'den beri
**tür-farkındalı** bir kısmi indeks var:
`(tenant, unit, donem, COALESCE(tanim_id, nöbetçi))`. Yani "Mart aidatı +
Mart elektriği" zaten mümkündü. Gerçek boşluk **tanımsız** kalemlerdeydi.

Kısıtı tamamen kaldırmak yanlış olurdu ve bu ölçüldü: dört mevcut test tam
da bu korumayı kilitliyor. Kaldırmak, aylık toplu tahakkuku yanlışlıkla
iki kez çalıştıran yöneticinin bütün siteyi **iki kat** borçlandırması
demekti.

İndeks bu yüzden **genişletildi**: `kalem_tipi` ve `kaynak_assessment_id`
eklendi; düzeltilmiş çift (`iptal_edildi` / `ters_kayit_id`) indeksin
dışında bırakıldı. Böylece:

* tanımsız akışta "Mart aidatı + Mart çatı onarımı" mümkün,
* bir dairenin aynı ayda birden çok gecikmiş borcu için ayrı faiz
  kalemleri açılabiliyor,
* "yanlış tutarı düzelt, doğrusunu yaz" akışı ikinci adımda 409 almıyor,
* mükerrer koruması **duruyor**.

**Asıl şikâyet — sessiz atlama — kaldırıldı:** atlananlar artık dökümlü
dönüyor (`atlananlar[]`, `unit_no` + neden) ve panel hem önizlemede hem
işlemeden sonra gösteriyor.

### 3.3 Arsa payı ve metrekare dağıtımı

`unit.arsa_payi` eklendi (KMK md. 20). Toplu borçlandırmaya `dagitim`
alanı geldi: `daire_basina` (eski davranış, varsayılan) · `esit` ·
`arsa_payi` · `metrekare`. Son üçü **toplamı** dairelere böler.

Dağıtım çekirdeği `borclandirma.oransal_dagit`: **en büyük kalan**
yöntemi, hesap `Decimal`. Her payı tek tek yuvarlamak toplamda kuruş
kaybettirirdi; dağıtılan toplam her zaman girdiye eşit (testle kilitli:
100.001 kuruş / 3 daire → 33.333 + 33.334 + 33.334).

Ağırlığı olmayan daire `None` alır ve **atlanır** — sessizce sıfır
borçlandırmak, yönetimin fark etmediği eksik tahakkuk üretirdi.

---

## Bölüm 4 — Otomasyon

### Üç ortak kural

Dört tablo (`aidat_plani`, `hatirlatma_ayari`, `duzenli_gider`,
`otomasyon_gunlugu`) ve beş görev aynı üç kuralı paylaşıyor:

1. **Açılıp kapatılabilir** (`aktif`). Bir hatayı durdurmanın tek yolu
   kaydı silmek olmamalı.
2. **İz bırakır** (`otomasyon_gunlugu`, append-only). Bir görevin
   çalıştığı ancak ürettiği kayda bakılarak anlaşılabilseydi, **hiçbir şey
   üretmediği** durum — ki asıl merak edilen odur — görünmez kalırdı.
3. **İdempotent.** Beat sıklığı bir **dağıtım detayıdır**, iş kuralı
   değil; ikinci koşum aynı işi tekrar yapmamalı.

İdempotency her yerde aynı desenle: yapılan iş bir **damga** bırakır
(`aidat_plani.son_donem`, `duzenli_gider.sonraki_tarih`,
`hatirlatma_ayari.son_calisma`, `otomasyon_gunlugu` satırı) ve görev
damgaya bakar. Tarihe bakıp "bugün ayın 5'i mi" demek yetmezdi: görev gün
içinde birden çok kez koşar ve saatlik bir pencere uydurmak, kaçırılan bir
koşumu telafi edilemez kılardı.

**Tenant bağlamı:** görevler tek tesis için çalışır, RLS bağlamı çağıran
tarafından kurulur. Owner bağlantısıyla tüm tesisleri tek sorguda işlemek
daha hızlı olurdu ama RLS'i bypass ederdi — otomasyonun bir tesisin
verisini diğerine yazma ihtimali, kazandığı hızdan pahalı.

**Bir tesisin hatası diğerlerini düşürmez:** her tesis kendi işlemi ve
kendi `try/except`i içinde. Aksi halde tek bir bozuk plan bütün
müşterilerin tahakkukunu durdururdu.

### 4.1 Otomatik aylık tahakkuk

`tahakkuk_gunu` 1–28 ile sınırlı: 29/30/31 her ayda yoktur ve "ayın 31'i"
kuralı Şubat'ta **sessizce hiç çalışmazdı**.

**Önizleme ile tahakkuk tek görevde**: ikisi aynı planı okur. Ayrı
görevler olsaydı biri planın değişen tutarını görüp diğeri görmeyebilirdi.

**Erteleme planı kapatmaz** (`ertelenen_donem`): pasife almak gelecek
ayları da kapatırdı; yönetici genelde "bu ay olmasın" der. İşlenmiş bir
dönem ertelenemez (409) — borç yazıldı, geri almak ters kayıtla olur.

**Elle ve otomatik tahakkuk aynı çekirdeği kullanır.** `borclandirma_uc.py`
içindeki plan üretimi ve satır yazımı `app/toplu_tahakkuk.py`ye taşındı.
İkinci bir kopya, "elle" ile "otomatik" tahakkukun günün birinde farklı
davranması demekti — ve fark ancak rakamlar tutmayınca fark edilirdi.

`tahakkuk_yaz`'ın `user` parametresi opsiyonelleşti: otomatik tahakkukun
bir kullanıcısı yoktur ve uydurma bir kullanıcı atamak, denetim kaydında o
kişiye yapmadığı bir işin altına imza attırmak olurdu.

### 4.2 Otomatik borç hatırlatma

**Ödeyene gitmez:** aday kümesi tahakkuk listesi değil, **kalan > 0** olan
borçlar. Kalan defterdeki tahsilat etkisinden hesaplanır (§1'in tek
tanımı).

**Kişi başına tek bildirim:** üç ayrı borcu olan sakine üç push gitmez;
tutarlar toplanır, en erken vade gösterilir.

**Günde bir kez:** `son_calisma` damgası. Görev günde on kez koşsa da
sakinin telefonu on kez ötmez.

Kademeler bir **INT dizisi** (3, 10, 30): kademe sayısını sütunlara
sabitlemek (gun1/gun2/gun3), dördüncü kademeyi şema değişikliğine
bağlardı. Vade öncesi ve sonrası kurallar tek bir **küme**de birleşir —
aynı güne iki kural denk gelirse sakine iki bildirim gitmemeli.

Yöneticinin yazdığı metin **çevrilmez**: onun cümlesini makineyle
değiştirmek, söylemediği bir şeyi ona söyletmek olurdu.

### 4.3 Banka hareketlerinin kasaya yansıması

Bankadan **çıkan** para artık gider olarak deftere giriyor. Önceden
`cikis` yönlü satırlar sonsuza kadar `manuel_inceleme`de bekliyordu:
eşleştirme motoru yalnızca borç kapatmayı bilir ve bir çıkış hiçbir borcu
kapatmaz. Karşılığının defterde olmaması, banka bakiyesi ile kasa
bakiyesinin ayrışması demekti.

**Otomatik "ödendi" yazılmaz** — kullanıcının açık kuralı: banka masrafı
da, bilinmeyen bir havale de yöneticinin onayına düşer
(`durum='onay_bekliyor'`, onay/red uçları §2.3).

Gelen para tarafı §2.1'de çözülmüştü: ekstre hangi hesabınsa tahsilat o
hesaba yazılır.

### 4.4 Otomatik makbuz ve bildirim

Makbuz zaten üretiliyordu ama **sakin ona ulaşamıyordu**: makbuz ucu yalnız
yönetime açıktı. `GET /me/makbuzlar` eklendi — kapsam **kendi**
makbuzları; daire üzerinden süzmek, aynı dairede oturmuş eski sakinin
makbuzlarını yeni sakine göstermek olurdu.

**E-posta push'un kalıcı ikizi**: sakin bildirimi kaçırsa, telefonunu
değiştirse ya da uygulamayı silse bile makbuzun kopyası posta kutusunda
durur. **PDF eklenmez, bağlantı verilir**: ek olarak gönderilen bir PDF
boyut sınırlarına ve spam süzgeçlerine takılır; ayrıca bağlantı kısa
ömürlüdür (presign) ve posta kutusu ele geçse bile süresiz erişim vermez.
E-posta bir **yan iştir**: gönderilemezse tahsilat düşmez.

### 4.5 Düzenli giderler

Tekrar **saklanır, genişletilmez**: "her ay" bir kuraldır ve her örneğini
satır olarak yazmak, kuralı değiştirmeyi yüzlerce satır güncellemeye
çevirirdi.

`otomatik_onay=false` **varsayılan**: vadesi gelen gider onay bekleyen
yazılır ve yöneticinin önüne düşer. Otomatik "ödendi" yazmak, sistemin
kimseye sormadan kasadan para çıkarması olurdu.

`ay_ekle` ayın son gününü aşmaz (31 Ocak + 1 ay = 28/29 Şubat).
`timedelta(days=30)` her tekrarda tarihi kaydırır ve bir yıl sonra gider
"ayın 20'si" olmaktan çıkardı.

### 4.6 Aylık özet raporu

Ayın 1'inde **değil**, "1'inde ya da sonra ve bu dönem gönderilmediyse":
görev bir gün hiç koşmazsa (bakım, kesinti) özet tamamen kaybolurdu. Damga
`otomasyon_gunlugu`nda — ayrı bir sütun açmaya gerek yok.

### Beat: günde bir, 06:00 (Europe/Istanbul)

Tek görev, beş iş: hepsi aynı günlük pencerede ve aynı tesis bağlamında.
Beş ayrı görev, beş ayrı tenant döngüsü ve beş ayrı bağlantı demekti;
ayrıca sıralama garantisi kalmazdı (faiz, tahakkuk yazıldıktan **sonra**
hesaplanmalı).

Saat seçimi: tahakkuk ve hatırlatma bildirimleri **sabah** gitmeli — gece
yarısı gönderilen bir "borcunuz var" bildirimi kimseyi harekete geçirmez,
yalnızca uyandırır. Retention 01:00'de koşuyor; ondan **sonra** olması da
bilinçli: silinmiş/anonimleştirilmiş kayıtlara bildirim gitmesin.

---

## Bölüm 5 — Yöneticinin görmesi gerekenler

### 5.1 Borç yaşlandırma

**Daire başına tek kova.** Bir dairenin üç gecikmiş borcu varsa üç kovaya
birden dağıtmak, "kaç daire 90+ gündür borçlu" sorusunu toplamı daire
sayısını aşan bir sayıyla yanıtlardı. Daire **en eski** borcunun kovasına
girer ve **tüm** kalan borcu orada sayılır — yönetici için anlamlı olan
"bu daire ne kadar süredir borçlu"dur.

**Kalan, tahakkuk değil:** kısmi ödenmiş bir borcu tam tutarıyla
yaşlandırmak, tahsil edilmiş parayı "90 gündür ödenmiyor" diye göstermek
olurdu.

Vadesi **gelmemiş** ve **vadesiz** borçlar yaşlandırmaya girmez: ilki bir
gecikme değil, ikincisinde gecikme tanımsız.

Hesap `app/yaslandirma.py`de, üç yerden çağrılıyor (panel kartı, toplu
işlem aday listesi, rapor). Üçünde ayrı yazmak, üç farklı "90+ gün"
tanımı demekti.

### 5.2 Tahsilat oranı — tek kaynaktan

Gösterge `defter.tahakkuk_toplami` + `defter.tahsilat_toplami` çağırıyor;
rapor ve şeffaflık da aynı fonksiyonları. Test bunu doğrudan kilitliyor:
gösterge ile `/reports/financial-summary` **aynı** rakamı vermek zorunda.

### 5.3 Borçlulara toplu işlem

* **Toplu hatırlatma** otomatik hatırlatmadan ayrıdır ve onun günlük
  damgasına dokunmaz: yönetici bilinçli olarak "şimdi gönder" diyor.
  Borcu kapanmış daireler atlanır ve sayısı döner.
* **Toplu faiz affı** = faiz kalemlerinin ters kayıtlanması. Silme yok: af
  bir karardır, izi kalmalı. Ödenmiş faiz affedilemez (§6.3 ile aynı
  kural).
* **Ödeme planı yeni borç üretmez.** "Borcu N taksite bölmek" akla gelen
  ilk yol ama üründe bu, eski borçları ters kayıtlayıp N yeni kalem yazmak
  demekti — ve **kısmi ödenmiş** bir borcu ters kayıtlamak alınmış parayı
  karşılıksız bırakırdı (daire alacaklı görünürdü). Plan borcun kendisine
  değil **vadesine** dokunur: açık borçlar en eskiden yeniye sıralanır ve
  vadeleri `ilk_vade`den başlayarak aylık dağıtılır. Bilinçli yan etki:
  vade ileri atıldığı için gecikme faizi de azalır — bir ödeme planının
  zaten beklenen davranışı.

Boş `unit_ids` reddedilir (422): "hepsi" anlamına gelen boş bir liste,
yanlışlıkla bütün siteye işlem yapmayı bir tıkla mümkün kılardı.

### 5.4 Bütçe ile gerçekleşen

Üründe "bütçe" vardı ama o **gerçekleşen** defterdi. Planlanan tutarı
tutan hiçbir yer yoktu; karşılaştırılacak ikinci sayı olmadığı için
"sapma" sorusu cevaplanamıyordu.

`butce_hedefi` **ayrı tablo** (göç 0087). Deftere "plan" satırı yazmak
düşünüldü ve elendi: bir plan para değildir ve kasa bakiyesine karışma
riski taşırdı (yalnız `durum` süzgeciyle ayrılırdı, ve o süzgeci bir gün
unutan bir sorgu harcanmamış parayı harcanmış gösterirdi).

Yıllık hedef + isteğe bağlı aylık hedef. Aylık sorulduysa aylık hedef,
yoksa **yıllık hedefin aya düşen payı** (yıllık/12): aylık hedefi olmayan
bir kategoriyi "hedefsiz" saymak, yıllık bütçesi genel kurulda onaylanmış
bir kalemi sıfır hedefle göstermek olurdu.

Hedefi olup hiç hareketi olmayan kategori de tabloda: "bütçelendim ama hiç
harcamadım" bir sapmadır.

Aynı hedef ikinci kez yazılırsa **güncellenir** (upsert): bütçe revize
edilen bir şeydir ve "önce sil, sonra ekle" akışı arada hedefsiz kalan bir
an bırakırdı.

Sapmanın işaretinin anlamı **tipe bağlıdır** (giderde pozitif = bütçe
aşıldı, gelirde pozitif = hedefin üzerinde) ve bu yorum sunucuda
belgelenip panelde tek yerde renklendiriliyor.

### 5.5 Muhasebeciye dışa aktarım

Ayrı bir uç açılmadı: rapor motoru zaten Excel/PDF üretiyor, site başlığı
ve para/tarih biçimleri orada tek yerde. İkinci bir yazıcı, aynı
biçimlendirmenin iki yerde yaşaması demekti. Yeni katalog kaydı:
**Muhasebeye Aktarım**.

**Borç ve alacak ayrı sütun**: tek sütunda işaretli tutar vermek, muhasebe
programlarına aktarmayı zorlaştırır (çoğu iki sütun bekler) ve işaretin
yönünü okuyanın yorumuna bırakırdı. Borç = kasadan çıkan, alacak = kasaya
giren (terminoloji **kasa** açısından).

Onay bekleyen ve iptal satırları dışarıda: muhasebeciye giden döküm
**gerçekleşmiş** hareketlerin dökümüdür.

---

## Bölüm 6 — Sorunlu yerler

### 6.1 `budget.py` denetim izi — Bölüm 1'de kapandı

Modülde tek bir `audit_user` çağrısı yoktu; şeffaflık yayınını besleyen
defter denetim izi olmadan yazılıyordu. Defter `finansal_hareket`e
taşınırken üç yazma yolunun üçü de denetime işleniyor (oluşturma,
düzenleme — eski/yeni değerle — ve iptal).

### 6.2 Çift tıklama koruması ekranlarda kullanılmıyordu

Uç `Idempotency-Key` başlığını **anlıyor** ama ekranlar
**göndermiyordu**. Analiz raporu bunu Tahsilatlar sayfasında ölçmüştü;
tarama beş ekranda daha aynı boşluğu gösterdi: tahsilat (tekil + toplu),
açılış fişi, iade, virman ve gelir/gider modalı.

Anahtar **form örneği başına** üretiliyor ve başarılı kayıttan sonra
yenileniyor: aynı gönderimin tekrarı aynı anahtarı taşır (koruma), ama
aynı formdan bilinçli ikinci bir kayıt yeni anahtar alır — aksi halde
ikinci kayıt hiç oluşmazdı.

Korunan risk hızlı çift tıklama değil (buton zaten uçuş sırasında kilitli);
**zaman aşımı sonrası tekrar**: istek sunucuya ulaşıp yanıt dönmezse
kullanıcı "kaydedilmedi" sanıp yeniden basar ve kasada iki hareket
oluşurdu. Yönetici bunu ancak mutabakatta fark ederdi.

### 6.3 Tahakkuk düzeltme — Bölüm 3'te kapandı

`POST /dues/assessments/{id}/ters-kayit`. Gerekçe §3.2'de.

### 6.4 Sayaç dağıtımındaki float

`sayac_tuketim_dagitimi` ara hesabı float'tı: `ana - sum(bölümler)` ve
ardından `* yüzde / 100.0`. İkili gösterimde `12.3 - 12.0 =
0.2999999999999989` çıkar ve birim fiyatla çarpılınca kuruş kayar. Ara
hesap `Decimal`e çevrildi; **yuvarlama kuralı değişmedi** (aşağı kesme,
diğer kalemlerle aynı) — değişen tek şey ara değerin gösterimi.

Yeni `oransal_dagit` de `Decimal` + en büyük kalan; float ile 1/3 payı
`0.3333333333333333` olur ve büyük tutarlarda kuruş kayardı.

Kalan taramada para hesabında başka float bulunmadı.

---

## Kapanış: kabul ölçütleri

| # | Ölçüt | Durum | Kilit |
|---|---|---|---|
| 1 | Para tek defterde; vezneden tahsilat borcu kapatıyor | ✅ | `test_p192_tek_defter.py::test_vezneden_tahsilat_sakinin_borcunu_kapatir` |
| 2 | `/dues/payments` kasa bakiyesini artırıyor | ✅ | `..::test_dues_payments_kasa_bakiyesini_artirir` |
| 3 | Tahsilat oranı her ekranda aynı | ✅ | `..::test_tahsilat_orani_her_ekranda_ayni`, `test_p192_gosterge.py::test_gosterge_rapordaki_rakamla_AYNI` |
| 4 | Banka tahsilatı bir hesaba yazılıyor, toplamlar tutuyor | ✅ | `test_p192_kasa.py::test_banka_tahsilati_secilen_hesaba_yazilir` |
| 5 | Onay bekleyen gider bakiyeyi düşürmüyor; onaylanabiliyor/reddedilebiliyor | ✅ | `test_p192_kasa.py` (4 test) |
| 6 | Gecikme faizi borç olarak yazılıyor ve tahsil edilebiliyor | ✅ | `test_p192_tahakkuk.py::test_faiz_BORC_olarak_yazilir_ve_tahsil_edilebilir` |
| 7 | Aynı döneme birden çok kalem; atlanan sessizce kaybolmuyor | ✅ | `..::test_ayni_doneme_ikinci_kalem_yazilabilir`, `..::test_atlanan_daire_SESSIZCE_kaybolmaz` |
| 8 | Arsa payına ve metrekareye göre dağıtım | ✅ | `..::test_oransal_dagitim_kurus_kaybetmez` |
| 9 | Aylık tahakkuk otomatik, idempotent, önizleme bildirimi | ✅ | `test_p192_otomasyon.py` (4 test) |
| 10 | Borç hatırlatmaları otomatik, ödeyene gitmiyor | ✅ | `..::test_hatirlatma_odeyene_GITMEZ` |
| 11 | Borç yaşlandırma ekranı | ✅ | `test_p192_gosterge.py` (5 test) |
| 12 | Muhasebeciye dışa aktarım | ✅ | `..::test_muhasebe_aktarimi_*` (3 test) |
| 13 | `budget.py` denetim izi | ✅ | `test_p192_kalanlar.py::test_butce_defterine_yazma_DENETIME_islenir` |
| 14 | Çift tıklama iki tahsilat yazmıyor | ✅ | `..::test_ayni_idempotency_anahtari_IKINCI_tahsilat_yazmaz` + beş ekranda başlık |
| 15 | Tahakkuk düzeltilebiliyor (ters kayıt) | ✅ | `test_p192_tahakkuk.py` (3 test) |
| 16 | Para hesaplarında float kalmadı | ✅ | `test_p192_kalanlar.py` (3 test) |
| 17 | Tam test paketi yeşil | ✅ | backend + admin-web + flutter |

## Bu turda açılan yeni tablolar

Yedi: `aidat_plani`, `hatirlatma_ayari`, `duzenli_gider`,
`otomasyon_gunlugu`, `butce_hedefi` — ve **hiç** yeni site/daire/sakin
tablosu. Para ve borç için de yeni tablo açılmadı: bu turun asıl işi zaten
var olan üç deftere **birini** seçmekti.

## Bu turda kapatılmayan şey

`dues_payment` ve `budget_entry` tabloları **silinmedi**. Yazılmıyorlar ve
hiçbir okuma yolu onlara bakmıyor (tarama `app/` altında sıfır sonuç
veriyor: yalnız yorumlarda ve göç dosyalarında geçiyorlar). Silme bilinçli
olarak ertelendi — geri dönüş penceresi kapanana kadar veri yerinde
dursun. İleride `DROP TABLE` yazılacaksa önce
`SELECT count(*) FROM dues_payment WHERE created_at > '<göç tarihi>'`
sıfır olmalı.
