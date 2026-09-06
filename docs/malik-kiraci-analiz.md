# Malik / kiracı ayrımı — ölçüm ve tasarım önerisi

> **Bu belge analizdir. Kod yazılmadı.** Öneri sunulup onay bekleniyor.
>
> Ölçümler dev ortamında **gerçek uçlar sürülerek** yapıldı (kod okuma +
> canlı istek). Emin olmadığım yerler açıkça işaretli.

---

## 1. Mevcut durum — ölçüldü

### 1.1 Kısa cevap: mekanizma VAR ve ÇALIŞIYOR, arayüzü EKSİK

Beklediğimin aksine `rol_tipi` ölü bir alan değil. Borç hedefleme mantığı
`app/borclandirma.py::hedef_sec` içinde yaşıyor, iki kural destekliyor ve
**gelir/gider tanımına bağlı** (`gelir_gider_tanim.hedef_kurali`,
`borc_hedef_kurali` enum'u: `kiraci_oncelikli | malik`).

**Uçtan uca sürdüm** — bir daireye malik + kiracı bağladım, iki tanım
açtım ve tahakkuk kestim:

| tanımın `hedef_kurali` | tahakkukun `hedef_user_id` |
|---|---|
| `kiraci_oncelikli` (varsayılan) | **kiracı** |
| `malik` | **malik** |

Yani KMK md. 20 ayrımının **motoru zaten kurulu**.

### 1.2 Arayüzde malik/kiracı seçilebiliyor mu?

| yüzey | durum |
|---|---|
| **Mobil** — Sakinler ekranı | **var**, hem oluştururken hem **sonradan değiştirilebiliyor** (`residents_screen.dart`) |
| **Web** — Daire paneli (`UnitDetail`) | **var** (malik / kiracı seçimi) |
| **Web** — Kullanıcı ekleme (`/users`) | **YOK.** Daire atanıyor ama `rol_tipi` **hiç gönderilmiyor** → bağ `NULL` rolle açılıyor |
| **Web** — Tanımlar ekranı (`hedef_kurali`) | **YOK.** Alan `ad / tip / dagitim_sekli / aktif` ile sınırlı; `hedef_kurali` hiçbir yerde düzenlenemiyor |

**En önemli iki boşluk bunlar.** Motor çalışıyor ama:
- yönetici bir gider türünün "kim öder"ini **değiştiremiyor** (her tanım
  varsayılan `kiraci_oncelikli` ile doğuyor),
- kullanıcı ekleme ekranından atanan daire bağı **rolsüz** kalıyor.

### 1.3 Borç kime yazılıyor — daireye mi kişiye mi?

**İkisi de.** `dues_assessment` hem `unit_id` hem `hedef_user_id` taşıyor:

- `hedef_user_id` **dolu** → borç o kişinin,
- `hedef_user_id` **NULL** → borç **daireye** yazılmış sayılıyor.

Kural uygulanamadığında (örn. `hedef_kurali = malik` ama dairede malik
kayıtlı değil) **hedef NULL kalıyor ve borç daireye yazılıyor** — ölçtüm.
`hedef_sec` bunu bilerek yapıyor: uydurma bir kişi seçmek yanlış kişiyi
borçlandırırdı.

### 1.4 Sakin kendi borcunu görürken ne görüyor?

`app/routers/sakin_odeme.py` koşulu:

```
hedef_user_id == ben
   OR (unit_id ∈ benim aktif dairelerim  AND  hedef_user_id IS NULL)
```

Yani sakin: **kendine yazılan borçlar** + **kendi dairesine yazılmış
hedefsiz borçlar**.

Bunun doğrudan sonucu — sizin sorduğunuz soru: *kiracı, maliğe ait bir
tadilat borcunu görür mü?* **Görmez**, çünkü o borç `hedef_user_id =
malik` ile yazılır ve kiracının koşuluna girmez. **Ama** dairede malik
kayıtlı değilse aynı borç hedefsiz kalır ve **kiracı onu görür**. Bu bir
boşluk (§3.6).

### 1.5 Bir dairede hem malik hem kiracı varsa

Destekleniyor: kural **daire başına en fazla 1 malik + 1 kiracı**
(`daire_rolu_dolu_mu`, göç 0049). İkinci malik denemesi 409 veriyor —
ölçtüm.

### 1.6 "Hem malik hem oturan" — **temsil EDİLEMİYOR**

Ölçtüm: **aynı kişi aynı daireye ikinci bir rolle bağlanamıyor.**

```
POST /units/{id}/residents  {user_id: A, rol_tipi: "malik"}   -> 201
POST /units/{id}/residents  {user_id: A, rol_tipi: "kiraci"}  -> 409
   "Bu kullanıcı daireye zaten aktif olarak bağlı."
```

Bugün yönetici ya `malik` yazıyor (oturduğu bilgisi kayboluyor) ya
`kiraci` (yanlış). **Model bu durumu taşımıyor** ve bu, isteğin 4.
bölümünün doğrudan konusu.

Pratikte bugün ne oluyor: `hedef_kurali = kiraci_oncelikli` olan bir
tanımda kiracı yoksa **malige** düşüyor (`hedef_sec` sırası: kiracı →
malik → belirsiz). Yani **oturan malik senaryosu tesadüfen doğru
çalışıyor** — ama "belirsiz" bağlar da aynı torbada olduğu için bu
güvenilir bir davranış değil.

### 1.7 Finans ekranlarında ayrım görünüyor mu?

Borçlandırmalar listesinde **`hedef_ad` sütunu var** — borcun kime
yazıldığı görünüyor. **Rol görünmüyor** (malik mi kiracı mı). Tahsilat
ekranında kişi seçicisi `rol_tipi`'yi okuyor (`components/finans/ortak.ts`)
ama ekranda göstermiyor.

### 1.8 Kiracı taşınırsa eski borç ne oluyor?

Ölçtüm/okudum: çıkarma işlemi bağa `bitis` yazıyor, **tahakkuku
değiştirmiyor**. `hedef_user_id` kişide kaldığı için:

- taşınan kiracı borcu **görmeye devam ediyor** (birinci koşul),
- daire artık listesinde olmadığı için **yeni** hedefsiz borçları
  görmüyor.

Bu doğru davranış: ayrılmak borcu silmez.

---

## 2. Boşlukların özeti

| # | Boşluk | Etki |
|---|---|---|
| B1 | `hedef_kurali` **arayüzde yok** | Yönetici KMK ayrımını kullanamıyor; her tanım `kiraci_oncelikli` |
| B2 | Kullanıcı ekleme ekranında **rol sorulmuyor** | Bağlar rolsüz doğuyor; hedefleme "belirsiz" torbasına düşüyor |
| B3 | **"Malik ve oturan" temsil edilemiyor** | Üçüncü durum modelde yok |
| B4 | Malik kayıtlı değilse malik-borcu **daireye** düşüyor | Kiracı, maliğe ait borcu görebiliyor |
| B5 | Finans ekranlarında **rol görünmüyor** | "Bu borç neden ona yazıldı" sorusu ekrandan yanıtlanamıyor |

---

## 3. Tasarım soruları — cevaplar ve öneri

### 3.1 Gider türlerine "kim öder" eklenmeli mi?

**Zaten var, açığa çıkarılmalı.** Yeni bir kavram icat etmeye gerek yok:
`gelir_gider_tanim.hedef_kurali` alanı mevcut, enum kurulu, motor
çalışıyor. Yapılacak iş **arayüz**: tanımlar ekranına bir seçim alanı.

Etiketler kullanıcının dilinde olmalı — `kiraci_oncelikli` teknik bir ad:

| değer | önerilen etiket | KMK karşılığı |
|---|---|---|
| `kiraci_oncelikli` | **"Kullanan öder (kiracı, yoksa malik)"** | md. 20/a — işletme giderleri |
| `malik` | **"Malik öder"** | md. 20/b — bakım, onarım, güçlendirme |

**Göç gerekmiyor.**

### 3.2 Yoksa her tahakkukta yönetici elle mi seçsin?

**Hayır — varsayılan tanımdan gelmeli.** Gerekçe: aynı gider türü her ay
aynı kişiye yazılır; her tahakkukta sormak, her ay tekrarlanan bir karar
ve **her ay yeni bir hata fırsatı** demektir. Tanım düzeyinde bir kez
kararlaştırılır.

**Ama tekil tahakkukta ezme (override) sunulmalı:** istisnalar var (bir
kere maliğe yazılan bir işletme gideri). Öneri: tekil tahakkuk formunda
"Kime yazılsın" alanı **tanımdan gelen değerle dolu** gelir, yönetici
değiştirebilir. Toplu borçlandırmada da aynı alan bulunur ve **o partiye**
uygulanır.

> **Göç gerekir mi:** Tahakkukta hangi kuralın uygulandığını *saklamak*
> isterse `dues_assessment`'a bir sütun gerekir. **Önermiyorum**: sonuç
> zaten `hedef_user_id`de duruyor, kural yalnızca ona nasıl varıldığını
> anlatıyor. Denetim için `audit_log` meta'sına yazmak yeterli.

### 3.3 Site bazında varsayılan kural olmalı mı?

**Evet, ama dar biçimde.** Bazı siteler her şeyi malige yazıyor (sizin
gözleminiz). Öneri: `tenant`'a **tek** bir ayar —
*"Yeni gider türleri varsayılan olarak: kullanan öder / malik öder"*.

**Neden yalnızca varsayılan, neden zorlayıcı değil:** tenant düzeyinde
"her şeyi malige yaz" diye bir *kilit* koyarsak, o siteye bir gün su
faturasını kiracıya yazmak gerektiğinde ayar tüm türleri birden
etkiler. Varsayılan yeni tanım doğarken uygulanır, sonra tür bazında
değiştirilebilir.

**Göç gerekir:** `tenant`'a bir enum sütunu (mevcut `borc_hedef_kurali`
tipi yeniden kullanılır). Küçük ve geri alınabilir.

### 3.4 Borç daireye mi kişiye mi yazılsın?

**Mevcut çift yapı doğru, korunmalı** — değiştirmeyi önermiyorum:

- **Kişiye** (`hedef_user_id`) yazmak, kiracı taşındığında borcun onunla
  gitmesini sağlar. Aidat kişisel bir yükümlülüktür.
- **Daireye** (`unit_id`) yazmak, hedef çözülemediğinde borcun
  kaybolmamasını sağlar; tahsilat daire üzerinden yapılabilir ve daire el
  değiştirdiğinde borç dairede kalır (KMK md. 22: yeni malik önceki
  borçtan müteselsilen sorumlu).

**Öneri (B4'ün çözümü):** hedef çözülemediğinde borç yine daireye
yazılsın **ama bu bir uyarı üretsin** — bugün sessiz. Toplu borçlandırma
önizlemesi zaten "atlanacak" satırlarını gösteriyor; oraya
*"malik kayıtlı değil → daireye yazılacak"* satırı eklenebilir.

### 3.5 "Hem malik hem oturan" nasıl temsil edilmeli?

**Üç seçenekli tek alan değil, iki bilgi öneriyorum** — ama isteğinizdeki
üç seçenek *arayüzde* korunur:

| arayüzde gösterilen | veride |
|---|---|
| Malik (oturmuyor) | `rol_tipi = malik`, `oturuyor = false` |
| Kiracı | `rol_tipi = kiraci`, `oturuyor = true` |
| Malik ve oturan | `rol_tipi = malik`, `oturuyor = true` |

**Neden bayrak, neden `rol_tipi`ye üçüncü değer değil:**

1. **Mülkiyet ile kullanım ayrı iki gerçektir.** KMK ayrımı tam olarak
   buna dayanıyor: gider ya *mülkiyete* ya *kullanıma* bağlanıyor.
   `malik_oturan` diye üçüncü bir enum değeri eklersek, "malikler"
   sorgusu artık iki değeri birden aramak zorunda kalır — ve bunu bir
   yerde unutmak sessiz bir hata olur.
2. **`hedef_sec` neredeyse hiç değişmez:** `kiraci_oncelikli` kuralı
   "kiracı varsa ona" yerine **"oturan varsa ona"** olur; malik-oturan
   doğal olarak kazanır. Bugün bu senaryo tesadüfen (kiracı yokluğundan)
   çalışıyor; bayrakla **kasıtlı** çalışır.
3. Kiracı zaten tanımı gereği oturandır — `oturuyor` onda `true` sabit
   kalır ve arayüzde sorulmaz.

**Göç gerekir:** `unit_resident`'a `oturuyor boolean not null default
false`. Mevcut satırlar için önerim: **`kiraci` olanlara `true`, malik ve
rolsüz olanlara `false`** — bugünkü davranışı birebir korur (kiracı
öncelikli kural bugün de kiracıyı seçiyor). Geri alınabilir: sütun
düşürülür, davranış eski hâline döner.

> **Emin değilim:** "malik ve oturan" durumunda `daire_rolu_dolu_mu`
> kuralının nasıl davranması gerektiğinden. Bugün bir dairede 1 malik +
> 1 kiracı olabiliyor. Malik oturuyorsa kiracı olmaması *beklenir* ama
> zorlamayı önermiyorum — devir dönemlerinde ikisi bir arada
> görünebilir. Bunu ürün kararı olarak size bırakıyorum.

### 3.6 Sakin kendi borcunda hangi kalemleri görmeli?

**Kural bugünkü hâliyle doğru, bir düzeltme öneriyorum:**

- Kiracı **maliğe yazılmış** kalemleri görmemeli — bugün böyle. ✔
- Kiracı **kendi hedefli** kalemlerini görmeli — böyle. ✔
- **Sorun:** hedefsiz (daireye yazılmış) kalemler herkese görünüyor.
  Malik kayıtlı olmadığı için daireye düşen bir *tadilat* borcunu kiracı
  görüyor — hem yanlış bilgi hem gereksiz endişe.

**Öneri:** hedefsiz kalemlerde görünürlük, tanımın `hedef_kurali`'na
bakılarak belirlensin: `malik` kuralıyla yazılmış hedefsiz bir kalem
**kiracıya gösterilmesin** (dairenin maliği bulununca ona görünür).

> **Emin değilim:** bu değişikliğin mevcut sakin ekranlarında ne kadar
> kalem gizleyeceğinden — dev verisinde hedefsiz kalem sayısı gerçek bir
> siteyi temsil etmiyor. Kararlaştırılırsa **önce ölçüp** sayıyı size
> bildiririm.

### 3.7 Kiracı taşındığında ne olur?

**Bugünkü davranış doğru, değiştirmeyi önermiyorum:** bağa `bitis`
yazılır, tahakkuklar olduğu yerde kalır, borç kişide kalır ve taşınan
kişi onu görmeye devam eder.

**Bir ekleme öneriyorum:** çıkarma anında **açık borcu varsa yönetici
uyarılsın** ("Bu sakinin 1.250,00 ₺ açık borcu var"). Sessizce çıkarmak,
borcun tahsil edilebilirliğini azaltıyor. Uyarı **engel değil** — çıkarma
yine yapılabilir.

---

## 4. Kullanıcı ekleme ekranı

**Öneri: tek alan, üç seçenek** (arayüzde), **iki alana yazılır**
(veride) — §3.5'teki eşleme.

Neden arayüzde tek alan: yöneticinin kafasındaki soru tektir ("bu kişi
buranın nesi?"). İki ayrı kutu ("malik mi?" + "oturuyor mu?") dört
kombinasyon üretir ve biri anlamsızdır (*malik değil + oturmuyor*).
Anlamsız durumu çizmemek için nasılsa koşul yazmak gerekecek — o zaman
üç seçenekli tek alan hem daha kısa hem daha dürüst.

Alan **daire seçilince** görünür (daire yoksa rol de yok) ve
**zorunludur**: bugün rolsüz doğan bağlar B2'nin kaynağı. Varsayılan
seçili değer **koymuyorum** — yanlış varsayılan sessizce yanlış veri
üretir; yönetici bilerek seçsin.

Aynı alan **daire panelinde** (`UnitDetail`) ve **mobil sakinler
ekranında** da aynı üç seçenekle görünmeli — üç yüzeyin farklı soru
sorması bugünkü tutarsızlığın kaynağı.

---

## 5. Özet: ne var, ne yapılacak

| | durum |
|---|---|
| Hedefleme motoru (`hedef_sec`) | **var, çalışıyor** — ölçüldü |
| Tanım başına `hedef_kurali` | **var** (veri + API), **arayüz yok** |
| Malik/kiracı seçimi | mobil + daire panelinde var, **kullanıcı ekleme ekranında yok** |
| "Malik ve oturan" | **temsil edilemiyor** — göç gerekir |
| Tenant varsayılanı | yok — göç gerekir |
| Rolün finans ekranlarında görünmesi | yok |

**Göç gereken iki şey:** `unit_resident.oturuyor` (§3.5) ve
`tenant.varsayilan_hedef_kurali` (§3.3). İkisi de küçük ve geri
alınabilir.

**Göç gerekmeyen ve en yüksek değerli iş:** tanımlar ekranına
`hedef_kurali` seçimi (B1) + kullanıcı ekleme ekranına rol alanı (B2).
Bu ikisi, hâlihazırda çalışan motoru yöneticinin eline verir.

---

## 6. Ölçemediklerim / emin olmadıklarım

- **Gerçek sitede** hangi giderlerin kiracıya, hangilerinin malige
  yazıldığını bilmiyorum; KMK md. 20 metnine ve sizin tarifinize
  dayandım. Varsayılan eşlemeyi (§3.1 tablosu) siz onaylamalısınız.
- §3.6'daki görünürlük değişikliğinin **kaç kalemi** etkileyeceğini
  ölçmedim (dev verisi temsil etmiyor).
- Mobil sakinler ekranındaki rol seçimini **kodda gördüm**, cihazda
  sürmedim.
- `daire_rolu_dolu_mu` kuralının "malik oturuyorsa kiracı olabilir mi"
  sorusuna nasıl davranması gerektiği bir **ürün kararı** — önermedim.

---

## 7. Onayınızı beklediğim noktalar

1. §3.1 etiket/eşleme tablosu doğru mu?
2. §3.3 tenant varsayılanı — sadece "yeni tanımlar için varsayılan"
   olması yeterli mi, yoksa zorlayıcı mı olmalı?
3. §3.5 `oturuyor` bayrağı + üç seçenekli arayüz kabul mü?
4. §3.6 hedefsiz malik-borcunu kiracıdan gizleme — uygulayalım mı?
5. §3.7 çıkarmada borç uyarısı — eklensin mi?
6. Sıra: önce göçsüz işler (B1+B2) mi, yoksa hepsi tek turda mı?
