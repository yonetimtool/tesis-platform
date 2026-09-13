# P224 — Tesis silme koruması ve kurtarma

Tarih: 2026-09-12

---

## 0. Neyin kilidi bu

Prod'da "Yönetio Platform" tesisi silindi. Platform admin hesabı o tesise
bağlıydı ve `ON DELETE CASCADE` ile gitti:

```
SELECT ... FROM app_user WHERE role='admin'  ->  0 satır
```

Panele girilemez hale gelindi. **Sistem hiçbir noktada direnmedi**: son
admin koruması yok, kendi tesisini silme engeli yok, önizleme yok, onay
kelimesi her tesiste aynı ("SİL") — yani yanlış tesisi silmeye karşı
hiçbir şey yapmıyor, yalnızca kas hafızası üretiyordu.

Kurtarma ayrı belgede: `/home/kerem/kurtarma.txt` (hedefli, tam geri
yükleme değil).

---

## 1. Platform admini koruması — iki yönlü, veritabanında

**Neden trigger, neden uç katmanı yetmiyor:** uçtaki bir kontrol
atlanabilir — `psql`, bir göç, bir bakım betiği, ileride yazılacak başka
bir uç. Bu kaza **tek bir hesabın kaybıyla tüm platformu yönetilemez
bıraktı**; korumanın veritabanında olması gerekiyor.

**İki ayrı trigger, çünkü kaza dolaylıydı:**

| Trigger | Tablo | Ne der |
|---|---|---|
| `trg_son_platform_admini_koru` | `app_user BEFORE DELETE` | son `role='admin'` satırı silinemez |
| `trg_admin_tesisini_koru` | `tenant BEFORE DELETE` | platform admini barındıran tesis silinemez |

İkincisi olmadan birincisi **aynı kazayı tekrar yaşatırdı**: kimse admini
silmedi, tesisi sildi. Cascade sırasında birinci trigger yine ateşlenirdi
ama mesaj "son admin silinemez" olurdu ve yönetici **neyi** yanlış
yaptığını anlamazdı. İkinci trigger ayrı ve net konuşuyor.

**Ölçülen tuzak:** ikisi de `SET search_path` taşıyor. Eksikken silme
`type "user_role" does not exist` ile 500 veriyordu — yani koruma da
çalışmıyor, **işlem de** çalışmıyordu. Trigger fonksiyonu çağıranın
`search_path`'ini devralır ve uygulama bağlantısı `public` taşımayabilir.

**Koruma dar, geniş değil** — ve bu ayrıca ölçüldü:
- son admini sil → **engellendi** (psql'den bile)
- adminin tesisini sil → **engellendi** (psql'den bile)
- iki admin varken birini sil → **izin verildi**
- admin olmayan tesisi sil → **izin verildi** (204)

Kendi hesabını silme zaten engelliydi (`kendi_hesabini_silemez`) —
ölçtüm, yeniden yazmadım.

### Tasarım sorusu: model değişmeli mi?

**Bugün:** `app_user.tenant_id` NOT NULL, giriş `(tenant_slug, email,
parola)`. Rol tesis üstü ama kayıt tesise bağlı. Platform admini bir
"bootstrap tenant"ta oturuyor.

**Görüşüm: bu turda değiştirme — ama kalıcı çözüm değil.**

Modelin doğrusu, platform adminini `tenant_id` NULL olabilen ayrı bir
kimlik olarak tutmak ya da `tesis_uyelik` üzerinden tesisten bağımsız
kılmaktır. Bugün yapmamanın gerekçesi maliyet değil **risk**: giriş
akışının tamamı (`tenant_uyelikleri`, RLS bağlamı, token'daki
`tenant_id`, 100 tablonun politikası) bu varsayımın üzerinde duruyor.
Kurtarmanın hemen ardından, çalışan giriş sistemine dokunmak yanlış
sıralama olurdu.

İki trigger, modeli değiştirmeden kazayı **imkânsız** kılıyor. Model
değişikliği ayrı bir tur olarak planlanmalı; o zaman `tesis_uyelik`
zaten hazır duruyor (bugün kimse okumuyor, P177 §6'da bilinçli açılmış).

**Yan bulgu — `tesis_uyelik.birincil`:** kurtarma sırasında aynı kişinin
iki satırında da `birincil = t` görüldü. Göç 0068'in kendi yorumu alanın
**kişi başına** olduğunu söylüyor ("kişinin ASIL tesisi"). Bugün hiçbir
giriş yolu okumadığı için görünür zararı yok — ve tam bu yüzden
tehlikeli: çoklu tesis girişi açıldığı gün, kimsenin dokunmadığı eski
satırlar yüzünden rastgele bir tesise girilir ve sebebi aylar sonra
aranır. Göç 0127 kısmi benzersiz indeks koydu; mevcut ihlaller **en eski
üyelik birincil kalacak** şekilde deterministik düzeltildi.

---

## 2. Tesis silme — zorlaştırıldı

**Önizleme** (`GET /tenants/{id}/silme-ozeti`): kullanıcı, daire,
finansal hareket, şikayet, belge, denetim kaydı sayıları. Sayılar
**temsili**: 100 cascade tablosunun hepsini saymak hem yavaş hem okunmaz
olurdu; kullanıcının "bunu gerçekten silecek miyim" sorusunu
yanıtlayacaklar seçildi.

**Onay = tesisin adı.** `onay_metni` sunucudan gelir, istemci
uydurmasın. **Sunucu da doğrular**: panelin tek başına zorlaması, ucu
doğrudan çağıran her şeyi (betik, `curl`, ileride başka bir istemci)
korumasız bırakırdı. Büyük/küçük harf tolere edilmiyor; yalnız baştaki
ve sondaki boşluk kırpılıyor — kopyala-yapıştırda eklenen bir boşluk
yüzünden "adını doğru yazdım ama kabul etmiyor" demek korumayı
güçlendirmez, sadece sinir bozar.

**Akıllı silme kademesi** — P189'un (kullanıcı silme) tesis karşılığı.
Ölçüt **para ve şikayet**: ikisi de geriye dönük sorulabilen,
silindiğinde yerine konamayan kayıtlar. Daire/kullanıcı sayısı ölçüt
**değil** — boş bir deneme tesisinde de daire açılmış olabilir ve onu
silmek meşrudur.

**Denetim kaydı** (`tenant_archive` / `tenant_restore` /
`tenant_delete`): prod'da bir tesis silindi ve geriye "kim, ne zaman,
neyi sildi" sorusunu yanıtlayan **tek bir satır bile** kalmadı. Silme
kaydı **silmeden önce** yazılıyor ve **adminin kendi tesisine**
düşüyor — silinen tesise yazsaydık `audit_log.tenant_id` cascade ile onu
da götürürdü.

---

## 3. Kurtarma — yaklaşım seçimi

**Yumuşak silme (`tenant.arsivlendi_at`), çöp kutusu değil.**

| Yaklaşım | Maliyet / risk |
|---|---|
| Çöp kutusu (satırları ayrı tabloya taşı) | 100 cascade tablosunun tamamını kopyalamak ve geri yazmak; **her yeni tablo mekanizmayı sessizce eksik bırakır** |
| **Yumuşak silme (seçilen)** | Tek kolon. Veri yerinde kalır, hiçbir FK kırılmaz, geri getirmek tek `UPDATE` |

Yumuşak silmenin bilinen maliyeti: her sorgunun "arşivli mi" süzgecini
taşıması. Bunu **tek yerde** çözdük (aşağıda).

### RLS kararı — görünürlük kimlik sınırında kesiliyor

İlk aklıma gelen `tenant` RLS politikasına `arsivlendi_at IS NULL`
eklemekti. **Yanlış olurdu ve sebebi ölçülebilir:** o politika yalnız
tesis satırını gizler; veri 100 ayrı tabloda ve her birinin kendi
politikası `tenant_id` üzerinden çalışıyor — `unit`, `complaint`,
`finansal_hareket` görünmeye devam ederdi. "100 politikaya da ekleyelim"
çözüm değil: **her yeni tablo bu şartı sessizce unutur**, bu depoda
birden çok kez yaşanmış bir kusur sınıfı.

Doğru yer kimlik sınırı: **arşivli tesise ait token üretilemez**, veri
katmanına hiç gelinmez.

1. `tenant_uyelikleri` (SECURITY DEFINER) — parola girişi, telefon
   girişi ve "tesislerim" **hepsi** buradan geçiyor. Arşivli tesis
   buradan düşüyor.
2. Yenileme (refresh) ucunda ayrı denetim: arşivlemeden **önce** alınmış
   oturum yenilemede reddediliyor ve aile iptal ediliyor.
3. Erişim jetonu kısa ömürlü: arşivleme ile tam kopuş arasında en fazla
   o kadar süre geçer. Bunu "anlık" yapmak her isteğe bir sorgu eklemek
   demekti; arşivleme yıkıcı olmayan ve geri alınabilir bir işlem olduğu
   için o bedel haklı değil.

Ayrıca `list_all_tenants(p_arsivli)` — arşivliler **açıkça istenmedikçe**
gelmiyor. Silindi sanılan bir tesisi listede görmek, yöneticiye
"silinmemiş" dedirtirdi.

### Otomatik silme olmalı mı? → HAYIR

Arşivlenen tesis **kendiliğinden silinmez**. Gerekçe: otomatik silmenin
tek kazancı disk, tek maliyeti **geri dönüşü olmayan veri kaybının
takvime bağlanması**. "90 gün sonra silinir" diyen bir beat görevi,
tatildeki bir yöneticinin haberi olmadan kazayı kalıcı hale getirir —
yani bu turda önlemeye çalıştığımız şeyin zamanlayıcıya bağlanmış hali.

Gerçek silme **açık ikinci adım**: arşivdeki tesiste silme düğmesi
duruyor, tesis adı yine yazdırılıyor. Arşiv bir çıkmaz sokak değil.

---

## 4. Aynı sınıf tehlike — tarama

45 `DELETE` ucu tarandı. Onay/önizleme/akıllı silme taşıyanlar: yalnız
`tenants` (bu tur) ve `blocks` (onay var).

Veritabanı tarafında **cascade yoğunluğu** (tenant hariç):

| Tablo | Cascade çocuk | Not |
|---|---|---|
| `app_user` | 15 | akıllı silme VAR (P189) |
| `isletme` | 11 | Dükkan — **önizleme yok** |
| `unit` | 10 | daire silme — **önizleme yok** |

**Öncelik önerim:**

1. **`DELETE /units/{id}`** — bir daire; sakin bağları, şikayetler,
   aidat tahakkukları, sayaç okumaları cascade. Önizleme ve onay yok.
   *En yüksek öncelik*: günlük işte kullanılan bir uç ve yanlış daire
   silmek kolay.
2. **`DELETE /dukkan/isletme/{id}`** — 11 cascade çocuk, işletmenin
   tüm teklif/yorum/reklam geçmişi. Dükkan henüz yayında değil, o yüzden
   ikinci.
3. **`DELETE /users/{id}`** — akıllı silme zaten var, eksik olan
   **önizleme**: "bu kullanıcının 14 şikayeti, 3 dairesi var".
4. Kalan 40 uç tekil kayıt siliyor (bir duyuru, bir görev, bir kamera);
   onay kutusu eklemek gürültü olur.

Bu turda **yalnız tarama yapıldı**, düzeltme yapılmadı.

---

## Ölçemediklerim

- Prod'da hiçbir şey çalıştırmadım; kurtarma komutlarını kullanıcı
  koştu ve sonuçları bana bildirdi.
- Arşivli tesise ait **mevcut bir erişim jetonunun** ne kadar sürede
  geçersizleştiği prod'da ölçülmedi; tasarım gereği erişim jetonu ömrü
  kadar.

---

# P225 — Tesisler ekranı: koruma + numaralandırma + arama

Tarih: 2026-09-12

## 1. Silme koruması — eksik olan ÜÇÜNCÜ katmandı

P224'te sunucu ve trigger kapatılmıştı; kullanıcının ekran görüntüsü
**arayüz katmanının açık kaldığını** gösterdi: Tesisler listesinde
platform tesisinin satırında Sil düğmesi ötekilerle **aynıydı** — kırmızı,
tıklanabilir, hiçbir uyarı yok.

Üç katman artık tam:

| Katman | Nasıl |
|---|---|
| Arayüz | `platform_admini_var` satırda Sil yerine "Korumalı" işareti çizer |
| Sunucu | `DELETE /tenants/{id}` 409 `tesiste_platform_admini_var` |
| Veritabanı | `trg_admin_tesisini_koru` — psql'den bile |

**Bayrak listede dönüyor**, satır başına sorgu yok: alternatifi her satır
için `silme-ozeti` çağırmaktı (8 tesiste 8 istek, 200 tesiste 200).

**Onay artık tesisin adı** listede de. Eski kodun yorumu "yeni tesisin adı
yer tutucu olduğu için ad-yazdırma pratik değil" diyordu; doğru çözüm
ad-yazdırmaktan vazgeçmek değil, **ne yazılacağını sunucunun söylemesi**
(liste zaten gerçek adı taşıyor). Onay sunucuya da gidiyor.

## 2. Numaralandırma — bileşene eklendi, sayfaya değil

`VeriTablosu`'na `numarali` prop'u. Kural iki maddede:

- Numara **listenin tamamına** göre: `(sayfa-1)*boy + i + 1` — ikinci
  sayfada 26'dan devam eder, 1'e dönmez.
- **Sıralama değişince yeniden hesaplanır**: sayım sıralanmış dizi
  üzerinden yapıldığı için bu kendiliğinden olur. Numara satırın kimliği
  değil konumudur.

Sayfaya değil bileşene eklendi: başka tablolar da aynı davranışı tek
satırla alsın, iki yerde iki farklı numaralandırma olmasın.

## 3. Arama — SUNUCUDA

Bugün 8 tesis var; istemcide süzmek de çalışırdı. Sunucu seçildi:

- **Süzgeç verinin yanında durursa, sayfalama eklendiği gün arama
  taşınmak zorunda kalmaz.** İstemcide süzen liste ilk sayfalamada
  "yalnız bu sayfada ara" haline düşer ve bu sessiz bir gerilemedir.
- **Türkçe harf katlaması tek kural olmalı.** Dükkan araması aynı sorunu
  `slug` üzerinden çözmüştü ve `tenant.slug` da ASCII katlanmış olarak
  zaten duruyor. İstemcide ikinci bir katlama yazmak, iki yerde iki
  farklı "cekmekoy" tanımı demekti.

**İlk yazımım eksikti ve test yakaladı:** yalnız harfleri katlıyordum,
boşlukları bırakıyordum. Gerçek slug `arikoy-sitesi-239a9` iken katlanmış
sorgu `arikoy sitesi 239a9` oluyor ve hiçbir şey eşleşmiyordu. Artık
`slugify_tenant` ile **aynı iki adım** uygulanıyor (harf katlama +
alfanumerik olmayanların tireye dönmesi); rastgele ek ve uzunluk kırpması
yok — onlar slug'ı benzersiz kılmak için, arama için değil.

Gecikme 300 ms (`useGecikmeli`, P220'de yazılan ortak kanca).

**Boş sonuç mesajı aramaya göre değişiyor:** "hiç tesis yok" ile "aramana
eşleşen yok" ayrı durumlar; aynı cümle, süzgeci açık bıraktığını fark
etmeyen kullanıcıya "tesisler silinmiş" dedirtirdi.

## 4. Kurulum süzgeci — eklendi

Değerlendirme sonucu **evet**: listede "bekliyor" ve "tamamlandı" zaten
görünüyor ama yarım kalmış kurulumları *bulmak* için süzgeç gerekiyordu.
Sunucu tarafında, aramayla aynı yerde — ikisi farklı katmanda olsaydı
sayfalama geldiğinde biri doğru biri yanlış çalışırdı.

## Ölçüm

```
q='arikoy'            -> 1 sonuç  ['Arıköy Sitesi b8693']
q='Arıköy'            -> 1 sonuç  ['Arıköy Sitesi b8693']
q='ARIKOY'            -> 1 sonuç  ['Arıköy Sitesi b8693']
q='yok-boyle-bir-sey' -> 0 sonuç  []
platform_admini_var olanlar: ['Acme Plaza']
kurulum=False: 609 · kurulum=True: 2225
```

Testler: backend 10, web 6. Beş kırma testi yapıldı (ASCII katlama,
platform bayrağı, korumalı satır, numaralandırma, gecikme).

---

# P226 — Prod'da kırılan iki şey: BFF sorgusu ve gradyan `<select>`

Tarih: 2026-09-12

P225 prod'a çıktı; koruma ve numaralandırma çalıştı, **arama süzmedi** ve
**kurulum listesi boş göründü**. İkisi de testlerden geçmişti.

## Kusur 1 — BFF sorgu dizesini düşürüyordu

`app/api/tenants/route.ts`:

```ts
export async function GET(): Promise<NextResponse> {   // istegi HIC ALMIYOR
  return proxyJson("/tenants", "GET");
}
```

Tarayıcı `?q=oltu` gönderiyor, BFF **sessizce düşürüyor**, backend
süzgeçsiz listeyi dönüyordu. `?kurulum=` ve `?arsivli=` de hiç
ulaşmıyordu — yani **arşiv görünümü de bozuktu** ve bunu kimse fark
etmemişti.

### Testler neden görmedi — iki ölçüm de doğruydu

| Ölçüm | Ne yaptı | Sonuç |
|---|---|---|
| Backend testi | ucu **doğrudan** çağırdı (`/tenants?q=...`) | süzüyor ✓ |
| Web testi | `fetch`i **tarayıcı sınırında** taklit etti, `q=` taşındığını doğruladı | gönderiyor ✓ |

Hiçbiri **tarayıcı → BFF → backend** zincirinin **orta halkasını**
ölçmedi. Benim "arikoy/Arıköy/ARIKOY üçü de buluyor" ölçümüm de backend
ucuna doğrudan yapılmıştı — dev/prod farkı değil, **ölçüm katmanı**
farkıydı.

Bu, P200 dersinin (*taklidi ölçülecek katmanın altına koy*) ve P213 §6'nın
**üçüncü tekrarı**.

### Kapatılan şey: örnek değil SINIF

`tests/bff-yol-eslesmesi.test.ts`'e yeni tarama: bir sayfa `/api/x?...`
diye **sorgu dizesiyle** çağırıyorsa, o yolun vekili isteği **almak
zorunda**. `GET()` ya da `GET(_req)` imzası, sorgunun okunamayacağının
kanıtıdır. 54 sorgulu çağrı tarandı; düzelttiğim yer dışında ihlal yok.

Beyaz liste kullanıldı (`q`, `kurulum`, `arsivli`), ham yeniden yayın
değil: gelen her parametreyi iletmek, ileride eklenen bir uç
parametresini de farkında olmadan açmak olurdu (P213 §3).

## Kusur 2 — `<select>` arka planında gradyan

`background: var(--yz-metal-1)` yazmıştım; o token bir
**`linear-gradient`** (`app/tasarim-sistemi.css:141`). `<option>` satırları
select'in arka planını devralır ama native açılır listede gradyan
**uygulanamaz**: tarayıcı geri düşer, `color` ise `--yz-text` olarak
kalır. Koyu temada açık metin açık zeminde kalıyor ve **seçenekler
görünmez** oluyor. Kullanıcının gördüğü "listede yalnız ilk satır var"
tam olarak bu.

### Testler neden görmedi — ve bu sefer görmesi mümkün değildi

jsdom **renk çizmez**. DOM ölçümü üç `<option>`u da doğru metinle
buluyordu (bunu ölçtüm: `value=''/'bekliyor'/'tamam'`, metinler yerinde)
ve test geçiyordu. Görünürlüğü ancak gerçek bir tarayıcı ölçebilir.

Onun yerine **sebebi yasakladım**: yeni tarama, gradyan token listesini
**CSS'ten üretiyor** ve hiçbir `<select>`/`<option>`ın onu `background`
olarak kullanmamasını zorluyor. Liste elle yazılmadığı için yeni bir
gradyan token eklenirse kural onu kendiliğinden kapsıyor.

**Tarama aynı kusuru ikinci bir yerde buldu:** `rapor-modali.tsx`'teki
çok seçimli liste de `--yz-metal-1` kullanıyordu — orada seçenekler
`multiple` olduğu için **her zaman ekranda**, yani etkisi tesisler
ekranındakinden daha belirgin. `ZenginMetin`'deki iki başlık seçici de
(`--yz-metal-2`) düzeltildi. Üçü de `--yz-surface-1` (düz renk) kullanıyor
ve `<option>`lar artık açıkça boyanıyor.

## Ölçemediğim

Gradyan düzeltmesinin görsel sonucunu **ölçemedim**: jsdom renk
çizmiyor, bu makinede tarayıcı testi yok. Yapısal kilit sebebi
engelliyor ama açılır listenin gerçekten okunur olduğunu **prod'da gözle**
doğrulaman gerekiyor.
