# P232 — Vardiya: şablon birleştirme + gün başına farklı saat

## §A — `/shifts` sayfası: ölçüm ve birleştirme kararı

### Ölçüm

`/shifts` **gerçekten şablon tutuyor ve kullanılıyor.** `Shift` üç şey
taşıyor: saat aralığı, **gün tipi** (hafta içi / hafta sonu / resmi
tatil) ve **varsayılan kadro** (`ShiftAssignment` — bu vardiyada normalde
kim çalışır).

`/vardiya-plani`'daki **"Haftayı doldur"** düğmesi tam olarak bunu
tüketiyor: kadroyu okuyup haftayı otomatik dolduruyor. **Kaldırmak o
özelliği de öldürürdü.**

### Asıl kusur: web'de özelliğin yarısı yok

| | şablon tanımı | varsayılan kadro |
|---|---|---|
| Web `/shifts` | var | **yok** (`assignments` çağrısı sıfır) |
| Mobil `/vardiyalar` | var | var (`updateAssignments`) |

Web'de şablon tanımlanabiliyor ama kimse atanamıyor; onu tüketen "Haftayı
doldur" ise kadroya ihtiyaç duyuyor. Sayfanın **boş görünmesinin sebebi
bu**: kimse şablon tanımlamamış, çünkü tanımlasa da işe yaramıyor.

### Karar: kaldırma değil, birleştirme

1. Şablon yönetimi `/vardiya-plani` içine **bölüm** olarak taşınır —
   kullanıldığı yerde yönetilsin, menüde tek giriş kalsın.
2. Web'e eksik **varsayılan kadro** düzenlemesi eklenir (parite eksiği).
3. Adlandırma: menü girişi **"Vardiya planı"**, içindeki bölüm **"Vardiya
   şablonları"**. "Vardiyalar" adı kalkar — ikisi de vardiyaydı ve ayrım
   addan anlaşılmıyordu.
4. `/shifts` → `/vardiya-plani` yönlendirmesi (yer imleri kırılmasın).

---

## §B — Gün başına farklı saat

### Ölçüm: istenenin çoğu zaten vardı

`POST /vardiya-plani/kalip-uygula` (P207) şu an bile şunları yapıyor:

| istenen | durum |
|---|---|
| Takvimden keyfi gün(ler) seçimi | **var** — `gunler: list[date]` |
| Gece/gündüz kalıbı | **var** — `dilimler` |
| Saatler kalıptan gelsin, değiştirilebilsin | **var** — `kalip_id` *veya* serbest `dilimler` |
| Önizleme | **var** — `kuru=true`, **ayrı uç değil**, aynı kod yolu |
| Çakışma sessizce atlanmasın | **var** — P205 kuralı |
| Geri alınabilir | **var** — `parti_id` |
| Tekrarlama (rotasyon) | **var** — `rotasyon: haftalik` |

**Eksik olan tek şey:** bir istekte **aynı dilimler tüm günlere**
uygulanıyordu. "Pazartesi gündüz, salı-çarşamba gece" için modalı üç kez
açmak ve **üç ayrı parti** üretmek gerekiyordu — üç önizleme, üç çakışma
kontrolü ve geri alırken **üç ayrı istek**. Kullanıcı açısından tek
karar, sistemde üç iz.

### Eklenen: `gruplar`

```
gruplar: [ {gunler, dilimler|kalip_id, atamalar}, ... ]   (en çok 10)
```

* **Tek parti.** Gruplar ayrı ayrı yazılsaydı geri alma birden çok istek
  olurdu.
* **Tek önizleme, tek çakışma kontrolü.** `kuru=true` bütünü sayar.
* **Tekil biçim kaldırılmadı** — yayındaki istemciler onu gönderiyor.
  `gruplar` verilirse tekil alanlar yok sayılır.
* **Tek kod yolu:** `_gruplari_coz` her iki girişi aynı şekle indirger.
  İki ayrı döngü yazmak, çakışma kuralının ya da rotasyonun birinde
  güncellenip ötekinde eskimesi demekti.

### Tekrarlama sunucuda **yok** — bilinçli

"1 hafta / 1 ay tekrarla" istemcide **günleri çoğaltarak** ifade edilir.
Sunucuya ayrı bir `tekrar` alanı koymak, aynı gerçeği iki biçimde
anlatmak olurdu (hem `gunler` hem `tekrar`) ve ikisi ayrışabilirdi.
Önizleme sayısı zaten genişletilmiş gün listesinden çıkıyor.

### İki kalıp kavramı var — ve birleştirilmesi gereken bu

Ölçüldü, **iki ayrı kavram bulundu**:

| | `Shift` (göç 0005) | `VardiyaKalibi` (göç 0099, P207) |
|---|---|---|
| içerik | **tek** saat aralığı + gün tipi + varsayılan kadro | **dilimler listesi** (günü bölme) |
| tüketen | `haftayi-doldur`, tekil `POST /vardiya-plani` | `kalip-uygula` |

"Gece/gündüz kalıbı" doğal olarak `VardiyaKalibi.dilimler`'dir — P207'nin
kavramı **zaten** gece/gündüz kalıbıdır. **İkinci bir kavram
üretilmedi**; `gruplar` mevcut `dilimler`i kullanıyor.

`Shift`'in ayrı yaşamaya devam etmesinin tek sebebi, `VardiyaKalibi`'nde
olmayan iki şeyi taşıması: **gün tipi** ve **varsayılan kadro**. §A'daki
birleştirme bu ikisini tek ekranda toplar.

### (P231) Amir kapsamı yeni biçimde de geçerli

`_hedef_gorunur` çok gruplu istekte de uygulanıyor: **yeni bir giriş
biçimi, eski bir kapıyı atlamanın yolu olmamalı.** Test ediliyor.

### Modaldaki fazlalık — ölçüldü

Modalda hem `vardiya-ekle-ara` ("Kişi ara") hem `vardiya-ekle-kisi`
("Personel") var. Arama alanının **tek işi** açılır listenin
seçeneklerini süzmek (`personel.filter(...)`); başka bir şey yapmıyor.
Native `<select>` zaten yazarak atlamayı destekliyor. **Kaldırılıyor.**

### §A uygulandı — ve eksik yarının teknik sebebi bulundu

Web'de kadro atanamamasının sebebi ölçüldü: **`assignments` BFF rotası
hiç yoktu.** Arka uçta `PUT /shifts/{id}/assignments` vardı ve mobil onu
kullanıyordu (`shifts_api.dart`); web'de karşılığı yoktu. P226/P229'daki
sınıfın aynısı — iki uç ayrı ayrı doğru, **orta halka** eksik.

Kadro ayrı bir modalda: "bu vardiya ne zaman" (şablon) ile "normalde kim
çalışır" (kadro) **ayrı kararlar**; tek forma sıkıştırmak, şablon adını
değiştirmek isteyene kadro listesini de göstermek olurdu.

Üç test dosyası eski sayfayı çiziyordu. Sildiğim için değil **taşıdığım**
için, testler yeni bileşene yönlendirildi — ölçtükleri davranış (gece
vardiyası uyarısı, uç düştüğünde hata) korundu.

### Kilitlerin yakaladığı bir P231 hatası

`yuzey-ayrimi` kilidi `/kameralar`'ın amire açılmış olduğunu yakaladı ve
**haklıydı**. P231 §3'te "kameralar: canlı + geçmiş kayıt" derken bu
sayfayı da açmıştım; ama `/kameralar` **kamera yönetimidir** (kamera
ekleme, adres/kimlik düzenleme) — tesis yönetiminin işi, güvenlik
gözetiminin değil. Backend zaten `POST/PATCH /cameras`'ı admin+yöneticiye
kapatıyor, yani amir sayfayı açsa düğmelerde 403 alırdı: "menüde ama
yetkisiz". Geri kapatıldı; P213'ün dar kapsamı doğruymuş.

`/users` ise haklı olarak açık kaldı, kilit gerekçesiyle güncellendi:
**ekran açıldı, küme açılmadı** — sunucu listeyi `gorunur_roller` ile
daraltıyor.

---

## §C — Yapısal engel: koşan takımın altından konteyner çekilmesin

### Sorun

Tek bir seansta **beş kez** aynı şey oldu: tam test takımı koşarken
`docker compose build api && up -d --force-recreate api` çalıştırıldı ve
koşum `EXIT=137` ile öldü. Her seferinde 40–70 dakikalık bir koşum baştan
başladı. Bir keresinde daha kötüsü oldu: koşum ölmedi ama **eski imajla**
devam etti ve düzeltilmiş kodu "kırmızı" raporladı (P230 §4 — üç sahte
kırmızı, sebebini bulmak ayrıca zaman aldı).

"Dikkat edeceğim" bir mekanizma değil. Beş tekrar bunu kanıtladı.

### Seçilen çözüm: canlı duruma bakan sarmalayıcı

`infra/guvenli-derle.sh` — derlemeden önce **api konteynerinde pytest
süreci var mı** diye bakar, varsa durur ve ne koştuğunu adıyla yazar.

### Neden kilit dosyası değil

İlk akla gelen "koşum başında bir kilit dosyası bırak" idi. **Reddedildi:**
bu depoda kilidin **bayatlaması bilinen bir sorun** — öldürülen
`docker compose exec pytest` konteynerde yetim kalıyor ve ileriki
koşumları bloke ediyor. Bayat bir kilit dosyası da meşru derlemeleri
engellerdi ve kullanan kişi bunu `--zorla` ile atlamayı **öğrenirdi**; o
noktada engel yok demektir.

Canlı durum bayatlayamaz.

### Fail-closed

Durum okunamıyorsa derleme **yapılmaz**. Fail-open, tam olarak önlemeye
çalıştığımız kusuru geri getirirdi: kontrol başarısız → "bir şey yoktur"
→ derle → koşum öl.

### Engelin kendisinde iki kusur çıktı — ikisi de kanıt denemesinde

Betiği yazıp bitirmedim, **denedim** ve iki kez düştü:

1. **`ps` slim imajda yok.** Komut hata verdi, sondaki `|| true` hatayı
   **yuttu** ve kontrol "koşan yok" dedi. Yani engelin kendisi
   **fail-open**'dı — önlemeye çalıştığı kusurun aynısı. Koşan takım
   gerçekten öldürüldü. `/proc` okumasına geçildi (her Linux
   konteynerinde var, ek paket istemez) ve `|| true` kaldırıldı.
2. **Prob kendini gördü.** `case $satir in *pytest*)` yazan probun kendi
   komut satırı "pytest" kelimesini içeriyor ve `/proc`ta kendini
   buluyordu — hiçbir takım koşmazken bile engelliyordu. Yanlış pozitif
   de zararlı: engel güvenilmez olunca insan `--zorla` alışkanlığı edinir.
   Aranan kelime parçalanarak kuruluyor (`aranan="py""test"`).

### Kanıt

İki yönde de sürüldü:

* Koşum **yokken** → `>> hazır`, çıkış 0.
* Koşum **varken** → çıkış 1, koşan süreç adıyla yazıldı, derleme
  yapılmadı ve koşum sağ kaldı.

### §C-2 — İkinci yapısal engel: bayat imajla test koşulmasın

`guvenli-derle.sh` bir kusuru kapattı (koşan takımın altından konteyner
çekmek). Ama **ikinci** bir kusur aynı seansta **iki kez** tekrarladı ve o
betik onu görmez:

> kaynağı değiştir (ya da kırma deneyinden geri al) → **derlemeyi unut** →
> testi koş → konteyner **eski kodla** cevap verir.

Sonuç her iki yönde de yanıltıcı: P230 §4'te **düzeltilmiş** kodu
"kırmızı" raporladı (üç sahte kırmızı, sebebini bulmak ayrıca zaman
aldı); P232'de ise geri alınmış bir **kırma deneyi** hâlâ kırıkmış gibi
göründü. Testin kendisi bunu fark edemez: konteyner sağlıklı, uçlar cevap
veriyor, yalnızca kod eski.

`infra/guvenli-test.sh` kaynak ile imajın **içerik özetini** karşılaştırır.

**Neden zaman damgası değil:** ilk yazım mtime karşılaştırıyordu ve hemen
yanlış pozitif verdi — kırma deneyinden `cp` ile geri alınan dosyanın
içeriği eski haliyle **aynı** olduğu için Docker katman önbelleği tuttu ve
imajdaki mtime eski kaldı; kaynak "167 sn daha yeni" göründü, oysa kod
aynıydı. Sorulan asıl soru zaten "kod aynı mı"; içerik özeti onu doğrudan
yanıtlar.

**Bu engelde de üç kusur çıktı, üçü de ölçümle yakalandı:**

1. mtime yanlış pozitifi (yukarıda).
2. `sort` **farklı yol önekleri** üzerinde çalışıyordu (`backend/app/…` ve
   `app/…`), aynı dosyalar farklı sırada özetleniyor ve toplam hep
   ayrışıyordu — tek tek dosyalar birebir aynı olduğu hâlde.
3. Konteyner kökü `/` sanılmıştı; doğrusu `/app` (`COPY app ./app`,
   `COPY tests ./tests`). `tests` bulunamıyor ve **sessizce eksik** bir
   küme özetleniyordu.

Ayrıca `guvenli-derle.sh`'in "hazır" ölçütü de düzeltildi: `python -c
pass` konteynerin ayakta olduğunu söylüyordu ama uvicorn henüz
dinlemiyorken ardından koşan **14 test "API erişilemiyor" diye atlandı**.
Atlanan test geçmiş test gibi görünür — sessiz bir yanlış güven. Artık
`/health` yanıtı bekleniyor.

---

## §D — Düzenleme: "yalnız bu günü" / "tüm seriyi"

`PATCH /vardiya-plani/{id}` yalnız tek blok değiştiriyordu; seri kavramı
yoktu. `kapsam: tek|seri` eklendi — seri, aynı `parti_id`yi taşıyan
satırlar (P207 toplu işleminin ürettiği küme).

**Varsayılan `tek` ve bu bilinçli:** tek satırı düzeltmek en sık yapılan
iş; varsayılanı `seri` yapmak kullanıcının **beklemediği** bir toplu
değişiklik üretirdi.

**Seride tarih değiştirilemez (422).** Serideki her satırın kendi tarihi
var; hepsini tek tarihe çekmek otuz günlük planı **tek güne yığmak**
olurdu — kullanıcının "saati düzeltiyorum" derken kaybedeceği bir şey.

**Partisi olmayan satırda `seri` de reddedilir (422).** Sessizce "tek"
gibi davranmak, kullanıcıya yaptığını sandığı şeyi **yapmamış** olmaktı.

**Seri düzenlemede çakışma satır satır sorulmaz.** Otuz satır için otuz
ayrı 409, kullanıcıyı aynı kararı otuz kez vermeye zorlardı; çakışanlar
uyarı olarak döner.

Kapsam **denetim kaydına** yazılıyor: "otuz vardiyam neden değişti"
sorusunun yanıtı orada aranır.
