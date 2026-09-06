# P217 — Tahsilat ve tahakkuk arayüz hataları

> Not: bu numarayla ayrıca `docs/P217-push-yonlendirme.md` var (push
> yönlendirmesi turu). İçerikler ayrı.

---

## §1 — Toplu borçlandırma

### Ölçüm: iddia doğrulanmadı, iki gerçek kusur bulundu

Akışı **gerçekten sürdüm** — hem uçtan (`api` konteyneri içinden) hem
web BFF üzerinden, hem **admin** hem **yönetici** hesabıyla:

| Ölçüm | Sonuç |
|---|---|
| `POST /borclandirma/toplu/onizleme` | 200 · "15 daire işlenecek" |
| `POST /borclandirma/toplu` | 201 · `dues_assessment`'a **15 kayıt yazıldı** |
| Borçlandırmalar listesi | kayıtlar **görünüyor** ("P217 surus" açıklamasıyla) |
| Finans özeti | `acik_borc_kurus: 410175` — tahakkuku **sayıyor** |
| Tahsilat göstergesi | `tahakkuk_kurus: 225000` — **görüyor** |
| **Yönetici** rolü | önizleme 200, işleme 201 — **çalışıyor** |

Yani "toplu borçlandırma çalışmıyor" iddiası ölçümde çıkmadı. **P199'daki
403 gerçekten kapanmış**: P206'da `_ADMIN` kaldırılıp `_YONETIM`
(admin+yonetici) konmuş ve uçtan uca doğrulandı.

Buna rağmen kullanıcının gördüğü şey gerçek. İki kusur ölçüldü:

### Kusur 1 — sessiz başarısızlık (asıl açıklama)

Aynı dönem **ikinci kez** borçlandırılınca 15 satırın hepsi benzersizlik
çarpışmasıyla atlanıyor, **hiçbir tahakkuk yazılmıyor** — ama sunucu
`created: []` dönüyordu (bilerek, yanıtı şişirmemek için) ve **kaç tane
oluştuğunu söylemiyordu**. Web her durumda **"Kaydedildi"** yazıyordu.

Kullanıcının "işlem oldu ama ortada borç yok" deneyiminin en olası
açıklaması bu; ve bu turda **üçüncü kez** çıkan kalıbın (sessiz
başarısızlık) aynısı.

**Düzeltme:** `DuesAssessmentResult.olusan` eklendi — toplu, sayaç ve
tekil yolların **hepsinde** dolu. Web:
- `olusan > 0` → *"15 tahakkuk oluşturuldu"* + modal kapanır,
- `olusan == 0` → **hata tonunda** *"Hiçbir tahakkuk oluşturulmadı — bu
  dairelerin seçilen dönemde borcu zaten var. Başka bir dönem seçin ya da
  mevcut kayıtları düzeltin"* + **modal açık kalır** (dönem düzeltilebilsin).

### Kusur 2 — dairelerde borç görünmüyordu

`/units` yanıtı **borç alanı taşımıyordu**; "Daireler" ekranında borç
sütunu yoktu. Tahakkuklar yazılmıştı, finans özeti sayıyordu — görünmeyen
tek yer buydu ve kullanıcı "borçlandırma çalışmıyor" sonucuna buradan
varmış olabilir.

**Düzeltme:** `UnitOut.borc_kurus` (tahakkuk − tahsilat) + Daireler
ekranında "Açık borç" sütunu. **Tek toplu sorgu** — daire başına sorgu
elli daireli sitede elli sorgu demekti. **Negatif değer kırpılmıyor:**
fazla ödeme yapmış daire alacaklıdır ve bunu gizlemek yöneticiden bilgi
saklamaktır.

### Tek defter (P192): kabul kriteri 2 karşılanamaz — gerekçe

İstek "toplu borçlandırma `finansal_hareket`'e yazılsın" diyordu.
**Tasarım bunun tersi ve değiştirmedim:**

`hareket_tip` enum'u yalnızca **para hareketlerini** tanıyor:
`tahsilat, gider, gelir, virman, iade, acilis, iptal`. **`tahakkuk` diye
bir tür yok.** Tahakkuk bir *borç kaydıdır*, para hareketi değil; defterde
karşılığı ancak tahsil edildiğinde (`tip=tahsilat`) doğar. Tekil tahakkuk
yolu da aynı şekilde davranıyor — yani toplu yol bir istisna değil.

Deftere yazmak için önce enum'a yeni bir tür eklemek, yani P192'nin
"defter = para" tanımını değiştirmek gerekirdi. Bunun için bir gerekçe
görmedim: finans özeti tahakkuku `dues_assessment`'tan okuyor ve
`acik_borc_kurus`'u **doğru** veriyor (ölçüldü). Bu karar testle de
görünür kılındı (`test_TAHAKKUK_deftere_YAZILMAZ_ve_bu_KUSUR_DEGIL`).

### Ölçüm notları

Backend testleri **canlı sunucuya** gidiyor (mevcut desen); web testinde
taklit **`fetch` düzeyinde** — `apiSend` ve yanıt işleme gerçekten koşuyor
(P200 dersi). Kilitler kırılarak doğrulandı: `olusan`'ı sabit 0 yapınca 3
backend testi düştü.

Test yazarken üç ön koşul eksiği çıktı ve düzeltildi: `world` fixture'ında
gider tanımı ve daire yok (test kendi verisini kuruyor), tahsilat ucu
`yontem: elden` ve `Idempotency-Key` istiyor. İlk yazımda tahsilat testini
**atlıyordum** — atlanan test hiçbir şey korumaz, doğru değeri kullanmak
gerekiyordu.

---

## §2 — Modal kapanmıyor

### Kök neden

Daire panelinde (`components/UnitDetail.tsx`) **üç modal** var ve üçü
**ayrı davranıyordu**:

| modal | başarıda kapanıyor mu | başarı bildirimi |
|---|---|---|
| Tahsilat | **evet** (`setPOpen(false)`) | — |
| **Tahakkuk** | **hayır** | `setAOk("Tahakkuk eklendi.")` — modal içi, **sabit Türkçe** |
| **Sakin atama** | **hayır** | yok |

Kullanıcının tarifi birebir tahakkuk modalı: kayıt başarılı, mesaj
çıkıyor, liste tazeleniyor — ama modal açık kalıyor. En olası tepki aynı
tahakkuku bir kez daha yazmaya çalışmak ve "zaten var" hatası almak.

### Karar

Üç modal da aynı kuralı izler:

- **Başarıda kapanır**, bildirim **toast**'a taşınır (modal kapanınca
  modal içi mesaj zaten görünmez olurdu).
- **Hatada açık kalır** — başarısız kayıtta form kaybolursa kullanıcı ne
  yazdığını da kaybeder.

`"Tahakkuk eklendi."` sabit Türkçe metni sözlüğe alındı (7 dil); artık
kullanılmayan `aOk` durumu kaldırıldı.

Aynı kural §1'deki toplu borçlandırma modalına da uygulandı: **hiçbir
tahakkuk oluşmadıysa kapanmaz** (kullanıcı dönemi düzeltip yeniden
denesin).

### Diğer modallar — tarama

Sayfa dosyalarında `toast.success` sonrası kapanma araması yaptım; sonuç
çok gürültülü çıktı (çoğu `toast.success` satır içi işlemlerden: silme,
durum değiştirme). Bu yüzden isteğin saydığı modalları **tek tek**
inceledim:

| modal | durum |
|---|---|
| Tahsilat (`finans/tahsilatlar`) | kapanıyor · `onKapat()` |
| Tahakkuk (`finans/borclandirmalar`, tekil) | kapanıyor · `onKapat()` |
| Toplu borçlandırma | **§1'de düzeltildi** (yalnız başarıda kapanır) |
| Gider (`finans/giderler`) | kapanıyor |
| Kamera (`kameralar`) | kapanıyor · `setAcik(false)` |
| Kullanıcı ekleme (`users`) | kapanıyor |
| **Daire paneli: tahakkuk / sakin atama** | **kapanmıyordu → düzeltildi** |

Yani kusur genel değil, `UnitDetail`'e özgüydü.

### Ölçüm

`p217-modal-kapanma.dom.test.ts` (4): başarıda kapanır, **hatada açık
kalır** (kapanma kuralı kör olmasın), bildirim çevrilmiş metinle gelir, ve
üç modalın da kapatma çağrısını taşıdığı (kaynak kilidi — biri unutulursa
haber verir). Kilit kırılarak doğrulandı.

Test yazarken kendi hatamı ölçüm ortaya çıkardı: **dönem alanı `required`**
ve boş bırakınca form hiç gönderilmiyor — modal "kapanmadı" görünüyordu.
Kodun kusuru değil, testin eksiğiydi.

---

## §3 — Tahsilattaki arama alanı

### Kaldırmadan önce ölçtüm — alan bir iş yapıyor

Şikâyet: *"daire ve kişi zaten ayrı ayrı seçilebiliyor, arama gereksiz
kalabalık."* Ölçüm, alanın **seçicilerin yapamadığı** bir iş yaptığını
gösterdi: kişi seçicisini besleyen **üç listeyi de** süzüyor —
borçlular, tüm kişiler ve daire sakinleri. 500 kişilik bir sitede daire
seçmeden kişi bulmak, aramasız bir açılır listede pratikte imkânsız.

Ama şikâyet de haklı: **daire seçilince** liste o dairenin sakinlerine
(2-3 kişi) iniyor ve orada arama fazladan bir alan.

### Karar: kaldırma değil, koşullu gösterim

Arama alanı **liste uzunken** görünür, kısayken gizlenir
(`ARAMA_ESIGI = 10`). Böylece tipik akışta (daire seç → kişi seç)
kalabalık kalkar, büyük listede işlev korunur. P211'in "daire seçilince
kişi otomatik gelir" davranışı **aynen duruyor** (mevcut testleri de
geçiyor).

**Eşik süzülmemiş liste üzerinden ölçülüyor.** Süzülmüş liste üzerinden
ölçseydim kullanıcı arama yazıp listeyi kısaltınca alan **kendi altından
kaybolur** ve yazdığı metin ekrandan silinirdi — bu ayrıca testle
kilitli.

`10` sayısı: iki-üç sakinli bir daire, on kişilik küçük bir site ve peşin
ödeme listesi bu eşiğin altında; 500 kişilik bir sitenin borçlu listesi
üstünde.

### Ölçüm

`p217-tahsilat-arama.dom.test.ts` (4): kısa listede görünmez (şikâyetin
çözümü) ama kişi/daire seçicileri durur, uzun listede görünür,
**gerçekten süzer** (seçenek sayısı azalıyor), ve yazarken kendi altından
kaybolmaz.

Test yazarken bir eksiğimi ölçüm gösterdi: borçlular `/api/panel/yaslandirma`
uçundan **kova yapısıyla** geliyor; ilk yazımda düz `items` döndürdüm ve
"uzun liste" senaryosu hiç kurulmamıştı (test yeşil olurdu ama hiçbir şey
ölçmezdi).

---

## §4 — Daire atamasında dolu daireler

### Karar: gizleme, işaretle

İstek "atanmış daireler görünmesin" diyordu ama aynı zamanda doğru
soruyu da soruyordu: *"bir dairede birden çok sakin olabilir; tamamen
gizlemek mi doğru, yoksa 'dolu' işaretiyle göstermek mi?"*

**Ölçüm — veri modeli:** `unit_resident` tablosunda daire başına
**tekillik kısıtı yok** ve `rol_tipi` alanı `malik | kiraci` değerlerini
tutuyor. Yani model, bir dairede birden çok sakini **bilerek** destekliyor:

- eşler / aile bireyleri,
- **malik + kiracı bir arada** (malik oturmuyor, kiracı oturuyor — ikisi
  de kayıtlı olmalı; aidat borcu birine, tebligat ötekine gidebilir).

Dolu daireleri gizleseydik **ikinci sakini eklemek imkânsız** olurdu.
Bu, var olan bir ihtiyacı arayüzden silmek demekti.

**Ama şikâyetin işaret ettiği sorun gerçek:** 200 daire arasında boş
olanı bulmak zor. Çözüm iki parçalı:

1. **Boş daireler önce sıralanır** — aranan daire ilk bakışta bulunur.
2. **Dolu olanın yanında kaç sakin olduğu yazar** (`A-1 · 2 sakin`).

Böylece varsayılan akış hızlanır, ikinci sakin eklemek mümkün kalır ve
yönetici bunu **bilerek** yapar.

**Sayı, "dolu" bayrağı değil:** ikili bayrak "1 sakin" ile "4 sakin"i
aynı gösterirdi. Sayı, yöneticiye ne yaptığını söyler.

**Sıralama kararlı:** boş/dolu ayrımından sonra mevcut sıra (blok, no)
korunur; aksi hâlde aynı liste her çizimde farklı görünürdü.

### Kiracı/malik durumu

Seçeneğe rol dökümü (`1 malik, 1 kiracı`) **koymadım**: açılır liste
satırı zaten blok/daire + sayı taşıyor ve rol ayrımı bu ekranda bir karar
değiştirmiyor — atama sırasında rol **ayrıca soruluyor**. Daire panelinde
(`UnitDetail`) sakinler rolleriyle birlikte zaten listeleniyor.

### Ölçüm

Backend (`test_p217_toplu_borclandirma.py`, 2 test): `/units`
`sakin_sayisi` döndürüyor ve sakin atanınca artıyor; **ayrılan sakin
sayılmıyor** (`bitis` dolu kayıt aktif değil — taşınmış biri yüzünden
daire sonsuza dek "dolu" görünemez).

Web (`p217-daire-atama.dom.test.ts`, 4): dolu daireler **listede kalır**,
kaç sakin olduğu yazar, boş dairede işaret **yok** (kalabalık yapmasın),
boşlar önce sıralanır ve sıralama kararlı. Kilit kırılarak doğrulandı.
