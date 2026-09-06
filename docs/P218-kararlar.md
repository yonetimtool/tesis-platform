# P218 — Malik / kiracı ayrımı (uygulama)

Analiz ve ölçümler: `docs/malik-kiraci-analiz.md`. Onaylanan kararlar
uygulanıyor; aşağıdakiler **uygulama** notlarıdır.

Onay özeti: hepsi tek turda · `oturuyor` bayrağı · tek alan üç seçenek ·
tanımdan varsayılan + formda ezme · tenant varsayılanı zorlayıcı değil ·
eşleme öneri niteliğinde · B4 düzeltilecek · malik oturuyorken kiracı da
olabilir.

---

## §A — Veri modeli ve hedefleme çekirdeği

### `unit_resident.oturuyor` (göç 0109)

Mülkiyet ile kullanım **ayrı iki alanda**. `rol_tipi`ye üçüncü değer
eklemek "malikler" sorgusunu iki değeri birden aramaya zorlardı ve
unutulduğu yerde sessizce yanlış çalışırdı.

**Mevcut veri:** `kiraci` olan bağlar `true`, malik ve rolsüz bağlar
`false`. Bu **bugünkü davranışı birebir korur** — `hedef_sec`in kullanan
kuralı bugün de kiracıyı seçiyordu. Ölçüldü: göç sonrası
`malik/f: 3, kiraci/t: 2, rolsüz/f: 1`. Çift yönlü doğrulandı
(downgrade → upgrade, veri korundu).

### `hedef_sec`: "kiracı öncelikli" → "oturan öncelikli"

Sıra artık **OTURAN → kiracı → malik → belirsiz**.

**`kiracilar` adımı bilerek korundu:** göç uygulanmamış ya da yarım
kalmış veride `oturuyor` hepsinde `false` olur; o durumda eski davranış
(kiracıya yaz) geçerli kalır ve borç sessizce yanlış kişiye gitmez. Bu
ayrıca testle kilitli.

**Enum değeri değişmedi:** `kiraci_oncelikli` dizesi veritabanında aynı
kaldı, yalnızca **anlamı** genişledi ("kiracı" değil "oturan"). Değeri
değiştirmek göç + tüm satırların yeniden yazılması demekti ve kazancı
yalnızca bir isimdi; arayüzde görünen etiket zaten çeviriden geliyor.

### `oturuyor_coz` — tek kural, iki yazma yolu

`/residents` ve `/units/{id}/residents` ayrı dosyalarda; aynı varsayımı
iki kez yazmak birinin değişip ötekinin kalması demekti:

- değer **açıkça verilmişse** o geçerli,
- verilmemişse **kiracı → `true`** (kiracı tanımı gereği oturur; ayrıca
  sormak yöneticiye bilgi değeri olmayan bir soru sormaktı),
- malik ve rolsüz → `false` ("bilinmiyor"u "oturuyor" saymak, işletme
  giderini oturmayan malige yazardı).

**Güncellemede özel kural:** rol `malik`e çevrilirken `oturuyor` **korunur**
— oturan bir malikin rolü düzeltildiğinde "oturmuyor" hâline düşmesi,
bakım giderini ona yazmayı sürdürürken işletme giderini başkasına
kaydırırdı.

### `tenant.varsayilan_hedef_kurali` (göç 0110)

Yeni gelir/gider tanımlarının başlangıç değeri. **Mevcut tanımlara
dokunulmuyor:** çalışan bir sitenin geçmiş kurulumunu değiştirmek,
kimsenin istemediği bir davranış değişimi olurdu. Mevcut
`borc_hedef_kurali` enum'u yeniden kullanıldı — aynı kavramın ikinci bir
tipi olsaydı ikisi zamanla ayrışırdı.

### Uçtan uca ölçüm

Üç durum da gerçek uçlarla sürüldü:

| durum | işletme gideri (`kullanan`) | bakım gideri (`malik`) |
|---|---|---|
| Malik oturmuyor + kiracı | **kiracı** | **malik** |
| **Malik oturuyor** | **malik-oturan** | **malik-oturan** |
| Yalnız oturmayan malik | malik (son çare) | malik |

Üçüncü durum eskiden **temsil edilemiyordu**; artık kasıtlı çalışıyor.

**Ürün kararı (onaylandı):** malik oturuyorken kiracı da eklenebilir —
engellenmiyor. Malik bir odayı kiraya vermiş olabilir; devir döneminde
ikisi bir arada görünebilir.

### Testler

`test_borclandirma_cekirdek.py` +3 (oturan önceliği, devir dönemi, göç
öncesi veri), `test_p218_malik_kiraci.py` 8 (üç durum + varsayılanlar +
sınırlar). İlgili takımlar: 70 geçti.

---

## §B — Arayüz: tek alan, üç seçenek

Üç yüzeyde de **aynı soru**: kullanıcı ekleme (`/users`), daire paneli
(`UnitDetail`), mobil sakinler ekranı. Üç yüzeyin farklı soru sorması
bugünkü tutarsızlığın kaynağıydı — daire panelinde iki seçenek vardı,
kullanıcı ekleme ekranında **hiç sorulmuyordu**.

| arayüzde | veride |
|---|---|
| Malik (oturmuyor) | `rol_tipi=malik`, `oturuyor=false` |
| Kiracı | `rol_tipi=kiraci`, `oturuyor=true` |
| **Malik ve oturan** | `rol_tipi=malik`, `oturuyor=true` |

Eşleme **tek yerde** (`SIFAT_VERISI`): formun üç yerinde aynı eşleme
yazılsaydı biri değişip ötekiler kalırdı.

### Kullanıcı ekleme ekranı

- Alan **daire seçilince** görünür (daire yoksa sıfat da yok).
- **Zorunlu ve varsayılansız.** Yanlış bir varsayılan sessizce yanlış
  veri üretir: herkesi "malik" saymak işletme giderini oturmayan malige
  yazdırırdı. Yönetici bilerek seçsin.
- Kritik düzeltme: bu ekran daire atarken **rol hiç göndermiyordu** ve
  bağlar rolsüz doğuyordu (analizin B2 boşluğu).

### Daire paneli

Sakin listesinde sıfat **tam adıyla** yazıyor. Önceden yalnız `rol_tipi`
gösteriliyordu ve "malik" yazan bir satırın oturup oturmadığı ekrandan
okunamıyordu.

### Mobil

Aynı üç seçenek, aynı eşleme. `residents_api` `oturuyor` alanını taşıyor.

### Testler

`p218-daire-sifati.dom.test.ts` (6): alan daire seçilmeden görünmez, üç
seçenek sunar, varsayılan seçili değildir, ve **üç sıfat da doğru iki
alana çevriliyor** — gönderilen gövde okunarak. Kilit kırılarak
doğrulandı (malik-oturan'ı `false` yapınca ilgili test düştü).

---

## §C — "Kim öder" arayüzü ve tesis varsayılanı

### Tanımlar ekranına `hedef_kurali`

Alan ve motor P28'den beri vardı ama **hiçbir ekranda düzenlenemiyordu**
(analizin B1 boşluğu): her tanım varsayılanla doğuyor, yönetici "bu bakım
gideri malige yazılsın" diyemiyordu.

Etiketler kullanıcının dilinde — `kiraci_oncelikli` bir enum değeri,
cümle değil:

| değer | etiket | KMK md. 20 |
|---|---|---|
| `kiraci_oncelikli` | **Kullanan öder (kiracı, yoksa malik)** | a) işletme giderleri |
| `malik` | **Malik öder** | b) bakım, onarım, güçlendirme |

Bunun için tanım tablosuna `secenekEtiketleri` desteği eklendi:
seçenekler bugüne kadar **ham değerle** çiziliyordu (`tipe_gore`) ve bu,
teknik adı kullanıcıya göstermekti. **Mevcut alanların görünümü
değiştirilmedi** — eşleme verilmezse eski davranış sürüyor.

### Tesis varsayılanı

`tenant.varsayilan_hedef_kurali` yalnızca **yeni açılan** türlerin
başlangıç değeri. Ölçüldü:

```
ayar = malik
  hedef_kurali VERMEDEN açılan tanım  -> malik           (varsayılan uygulandı)
  açıkça kiraci_oncelikli verilen     -> kiraci_oncelikli (varsayılan EZİLDİ)
  mevcut tanımlar                      -> DEĞİŞMEDİ
```

**Neden zorlayıcı değil:** tenant düzeyinde kilit olsaydı, o siteye bir
gün su faturasını kiracıya yazmak gerektiğinde ayar tüm türleri birden
etkilerdi.

**Neden yöneticide:** "işletme gideri kime yazılır" kararı site
yönetiminin işi — kira sözleşmelerini ve site teamülünü bilen kişi odur.
Platform operatörüne bırakmak, her site için bizi arayan bir ayar demekti.

### Yan düzeltme: yavaş test

`tesis-ayarlari.dom.test.ts`'teki eşik testi tam takımda **5006 ms** ile
sınırı aşıyordu. Kök neden: `userEvent.type` tuşa tuş yazıyor ve her
karakterde yeniden çizim tetikliyor; bu sayfa her çizimde tüm ayar
alanlarını kuruyor. Zaman aşımını büyütmek belirtiyi ertelerdi —
`fireEvent.change` ile giriş **tek seferde** yapıldı ve sebep ortadan
kalktı (3,7 sn → tüm dosya).

### Testler

`test_p218_malik_kiraci.py` +4: yeni tanım varsayılanı alır, tanım
bazında ezilir, **mevcut tanımlara dokunulmaz**, yönetici ayarı
değiştirebilir. Toplam 12.

---

## §D — Hedef çözülemezse (analizin B4 boşluğu)

**Ölçülen durum:** `hedef_kurali = malik` olan bir tanımda dairede malik
kayıtlı değilse hedef çözülemiyor ve borç **daireye** yazılıyordu
(`hedef_user_id = NULL`). İki sonucu vardı ve ikisi de sessizdi:

1. borç kimseye "ait" olmuyor,
2. daireye yazılan her kalem o dairenin **tüm** sakinlerine görünüyor —
   yani malik için kesilmiş bir bakım borcunu **kiracı görüyordu**.

Bu, bir **veri eksikliğinin** sonucu (dairede malik kayıtlı değil), ama
kullanıcıya bir davranış olarak yansıyordu.

### İki yönlü düzeltme

**1. Yönetici bilgilendiriliyor.** Toplu borçlandırma önizlemesi artık
`hedefsiz` sayısını ve **hangi daireler** olduğunu gösteriyor. Bu bir
**atlama değil** — satır işlenir — bu yüzden "atlanacak" kutusundan
**ayrı** duruyor: ikisini birleştirmek "hiç yazılmayacak" ile "sahipsiz
yazılacak" durumlarını karıştırırdı. Mesaj ne yapılacağını da söylüyor
("genellikle malik kayıtlı değildir").

**2. Kiracıya gösterilmiyor.** Hedefsiz bir kalem, tanımı `malik` diyorsa
artık kiracının borç toplamına **girmiyor**. Pratikte kimseye görünmüyor
— ve bu doğru: eksik olan **veri**, gösterilecek kişi değil. Yönetici
uyarıyı zaten önizlemede görüyor.

**Kural bilerek dar:** yalnızca **kiracı** bağı olan sakinler için
uygulanıyor. Malik ve rolsüz sakinler daireye yazılmış kalemleri görmeye
**devam ediyor** — P28 öncesi (türsüz) tahakkuklar öyle yazılıydı ve
onları gizlemek, ödenmesi gereken borcu saklamak olurdu. Bu sınır ayrıca
testle ölçülüyor.

### Testler

Backend +4 (önizleme sayar, çözülen satır işaretlenmez, **kiracı malik
kalemini görmez**, **malik hedefsiz kalemi görür**), web +2 (uyarı ve
daire numarası görünür, hedefsiz yokken uyarı çıkmaz).

Kilit kırılarak doğrulandı: rol koşulunu kapatınca kiracı 57.000 kuruş
görüyor (50.000'i maliğe ait bakım borcu).

---

## §E — Tahakkukta hedef ezme + finans ekranlarında sıfat

### Ezme (analiz §3.2)

Varsayılan **tanımdan gelir** — aynı gider türü her ay aynı kişiye
yazılır; her tahakkukta sormak her ay yeni bir hata fırsatıdır. Ama
istisnalar var: sözleşmeye göre devredilen bir kalem, bir kereye mahsus
malige yazılan bir işletme gideri.

`hedef_kurali` artık **tekil ve toplu** tahakkuk gövdesinde kabul
ediliyor; **o partiye** uygulanıyor ve **tanımı değiştirmiyor** (ölçüldü:
ezmeden sonra tanım hâlâ `kiraci_oncelikli`).

İki yolun da aynı alanı kabul etmesi şart: aynı ekrandan yapılan iki
işlemin farklı davranması, kullanıcının güvenini bozan türden bir
tutarsızlık olurdu.

**Tahakkukta saklanmıyor** (analizdeki karar korundu): sonuç zaten
`hedef_user_id`de duruyor, kural yalnızca ona nasıl varıldığını anlatıyor.
Bir sütun daha eklemek, aynı gerçeği iki yerde tutmaktı.

### Sıfat görünürlüğü (analizin B5 boşluğu)

`DuesAssessmentOut.hedef_sifat` eklendi: `malik | kiraci | malik_oturan`.
Ad tek başına *"bu borç neden ona yazıldı"* sorusunu yanıtlamıyordu —
aynı isim bir dairede malik, ötekinde kiracı olabilir.

**"Malik ve oturan" ayrı gösteriliyor:** yalnızca "malik" demek, ekranda
okunamayan bir ayrım bırakırdı.

**Tek sorgu:** kayıt başına sorgu, 400 satırlık listede 400 sorgu demekti.

Borçlandırmalar listesinde kişi sütunu artık `Ad (Sıfat)` biçiminde.

### Testler

+5: tekil ezme, **ezme tanımı değiştirmez**, toplu yolda da ezme, sıfat
döner (`malik_oturan`), hedefsiz tahakkukta sıfat `None`. Toplam 21.

---

## Ek — KMK md. 20 gider eşlemesi (REFERANS, zorlayıcı değil)

> Bu tablo **koda gömülü değildir** ve hiçbir yerde otomatik
> uygulanmaz. Yöneticinin bir gider türü açarken başvurabileceği bir
> referanstır. Karar her zaman türün kendi `hedef_kurali` alanındadır.

**Kanun ne diyor (Kat Mülkiyeti Kanunu md. 20):** kat malikleri anagayrimenkulün
ortak giderlerine katılmakla yükümlüdür; ancak *kullanmadan doğan* giderler
ile *anayapının korunması ve onarımına* ilişkin giderler farklı
değerlendirilir. Uygulamada yerleşmiş ayrım:

### Kullanan öder (işletme giderleri)

Dairenin **kullanılmasından doğan**, kiracı varsa ona yansıyan giderler:

| gider türü | not |
|---|---|
| Kapıcı / görevli ücreti ve SGK | md. 20/a'da açıkça sayılır |
| Elektrik (ortak alan), su, doğalgaz | tüketim kullanımla doğar |
| Asansör **işletme** gideri (elektrik, periyodik kontrol) | bakımdan ayrı |
| Temizlik malzemesi ve hizmeti | |
| Bahçe bakımı, çöp toplama | |
| Güvenlik hizmeti | |
| Yakıt (kalorifer) | |

### Malik öder (anayapı giderleri)

**Mülkiyete** bağlı, kiracı değişse de malikte kalan yükümlülükler:

| gider türü | not |
|---|---|
| Çatı, cephe, dış boya onarımı | anayapının korunması |
| Asansör **yenileme / büyük onarım** | işletmeden ayrı |
| Isıtma sistemi değişimi, kazan yenileme | |
| Deprem güçlendirme | |
| Ortak yerlerin büyük tadilatı | |
| Demirbaş alımı | mülke kalıcı katkı |
| Olağanüstü aidat (yenileme fonu) | |
| Yönetim planı değişikliği, dava/avukat giderleri | |

### Sınır durumlar — dikkat

- **Asansör** iki satırda birden geçiyor ve bu bilinçli: *işletme*
  (elektrik, aylık kontrol) kullananın, *yenileme/büyük onarım* malikin.
  Tür adını "Asansör" diye tek kalem açmak bu ayrımı kaybettirir; iki
  ayrı tür açmak daha doğru.
- **Sözleşme farklı diyebilir.** Kira sözleşmesi giderleri başka türlü
  paylaştırmışsa geçerli olan odur; bu yüzden eşleme zorlayıcı değil ve
  tekil tahakkukta **ezme** var (§E).
- **Bazı siteler her şeyi malige yazar.** Tesis varsayılanı (§C) tam bu
  yüzden var; o siteler ayarı bir kez `Malik öder` yapar ve tür tür
  uğraşmaz.

### Arayüzde ipucu — ne yaptım, ne yapmadım

**Yaptım:** tanım formunda "Borç kime yazılır" alanının altında **statik
bir ipucu** — KMK ayrımının bir cümlelik özeti ve örnekleri. Zorlayıcı
değil, seçimi değiştirmiyor.

**Yapmadım — tür adından tahmin:** "adında 'bakım' geçiyorsa malik öner"
gibi bir kural cazip ama **reddettim**:

1. Tür adı **serbest metin ve 7 dil**. "Asansör Bakımı", "Asansör
   bakım-onarım", "Lift maintenance", yazım hataları... Kelime eşleme bu
   çeşitlilikte güvenilir olamaz.
2. **Yanlış öneri, önerisizlikten kötüdür.** "Asansör" hem işletme hem
   yenileme olabilir (yukarıdaki sınır durum); ada bakan bir kural bunu
   ayırt edemez ve yöneticiyi yanlış seçime **iter**.
3. Öneri bir kez yanlış çıkarsa yönetici sonrakilere de güvenmez —
   ipucunun tüm değeri kaybolur.

Statik ipucu bu üç riski de taşımıyor: kanunun ne dediğini söylüyor,
kararı yöneticiye bırakıyor.
