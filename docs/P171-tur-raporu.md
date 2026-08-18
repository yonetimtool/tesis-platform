# P171 — Sunucu tarafı HTML temizleme (rapor)

> P170'te XSS **istemcide**, gövdeyi düz metne çevirerek kapatılmıştı.
> Bedeli: başlık/madde/kalın biçimlendirmesi kayboldu. Bu tur kalıcı
> çözümü kuruyor: **yazma anında, sunucuda, beyaz listeyle** temizleme —
> ve biçimlendirme geri geliyor.

---

## 1. Temizleyici

`backend/app/temizleme.py` · **nh3 0.2.18** (Rust `ammonia` bağlaması).
`bleach` seçilmedi: 2023'te bakımdan çıktı ve kendi belgesinde nh3'e
yönlendiriyor. Elle temizleyici **kesinlikle yazılmadı** — HTML ayrıştırmanın
köşeleri (mutasyon XSS, iç içe yorumlar, eksik kapanış, `<svg><style>`
geçişleri) tam olarak bu tür kütüphanelerin varlık sebebi.

| | |
|---|---|
| **İzinli etiketler** | `p br strong em u s h1 h2 h3 h4 ul ol li a blockquote hr` |
| **İzinli öznitelikler** | yalnız `a[href]`, `a[title]` |
| **İzinli şemalar** | `http`, `https`, `mailto` |
| **Atılanlar** | `on*` (tümü), `style`, `script`, `iframe`, `svg`, `img`, `object`, yorumlar, `javascript:`, `data:` |
| **Eklenen** | `rel="noopener noreferrer"` |

**Beyaz liste, kara liste değil.** Kara liste ("şunları at") kaybetmeye
mahkûmdur: yarın çıkacak bir öznitelik listede olmaz. `on*` özniteliklerinin
tek tek sayılmadığı, adını bilmediğimiz bir olayın da gittiği test edildi.

`img` bilinçli olarak listede yok: `onerror` en yaygın vektör ve bir yasal
metnin görsele ihtiyacı yok. Gerekirse ayrı bir karar olarak, `src` şema
kısıtıyla açılır.

`rel="noopener noreferrer"`: `target` özniteliği listede yok, ama bağlantı
yine de yeni sekmede açılabilir ve açılan sayfa `window.opener` üzerinden
bizi yönlendirebilirdi (tabnabbing). Bedava bir sıkılaştırma.

---

## 2. Nerede uygulandı — ve **neden her yerde değil**

Temizlik bir **tip** olarak yazıldı, uç içinde bir çağrı olarak değil:

```python
ZenginHtml = Annotated[str, AfterValidator(zengin_temizle)]
```

Gerekçe: bir temizleme çağrısı yeni bir uçta **unutulabilir** ve
unutulduğunda hiçbir şey hata vermez — yalnızca o uç korumasız kalır. Tip,
korumayı şemanın kendisine taşır.

`AfterValidator` (Before değil): uzunluk doğrulamasından **sonra** çalışır,
yani `max_length` kullanıcının yazdığı metne uygulanır. Tersi olsaydı sınırı
aşan bir gövde, temizlik onu kısalttığı için **sessizce** kabul edilirdi.

### Zengin metin alanları (temizleniyor)

| Şema | Alan | Neden HTML |
|---|---|---|
| `KvkkMetinCreate` | `govde` | `ZenginMetin` editörü; tesisteki herkese gösteriliyor |
| `MesajSablonuCreate` | `govde` | e-posta kanalında zengin metin; **başkasına gönderiliyor** |
| `MesajSablonuUpdate` | `govde` | aynısı |
| `MesajOnizlemeIstek` | `govde` | saklanmaz **ama ekranda çizilir** |

Önizleme de temizleniyor: bırakılsaydı *"kaydetmeden önce dene"* yoluyla
açılmış bir enjeksiyon kapısı olurdu. Ayrıca önizleme, kaydedilenle **aynı**
şeyi göstermeli.

### Düz metin alanları (bilinçli olarak temizlenmiyor)

Brief bunları da saymıştı; taradım ve **her birini HTML temizleyicisinden
geçirmemek gerektiği sonucuna vardım**:

`AnnouncementCreate/Update.govde` · `SiteKuraliCreate/Update.icerik` ·
`KararDefteriCreate/Update.metin` · `EtkinlikCreate/Update.aciklama` ·
`ComplaintCreate.mesaj` · `SupportTicketCreate.aciklama` ·
`SupportTicketUpdate.admin_cevap` · `EkCreate.metin` ·
`AnketCreate/Update.aciklama` · `HatirlatmaBase.aciklama` ·
`ViolationCreate.aciklama` · `DokumanCreate.aciklama` ·
`IcraDosyasiCreate/Update.aciklama`

**Neden:** hiçbiri zengin metin editörüyle yazılmıyor ve hiçbir istemci
onları HTML olarak çizmiyor. Bir HTML temizleyicisinden geçirmek onları
**korumaz, bozar**: `5 < 10` yazan bir duyuru veritabanında `5 &lt; 10`
olarak durur ve kullanıcıya öyle görünür. Koruma zaten başka yerde ve
şimdi **kilitli**: hiçbir istemci bu alanları HTML olarak çizmiyor.

Bu ayrım iki yönlü kilitli (`backend/tests/test_temizleme.py`):
zengin alanların hepsi temizleniyor **ve** düz metin alanları
temizleyiciden geçmiyor. Ayrıca envanter kapısı var — şemada `ZenginHtml`
kullanıp envantere girmeyen bir alan testi kırar, yani yeni bir zengin
metin alanı **kimse bakmadan** eklenemez.

**Kontrol edilip temiz çıkanlar:** e-posta gövdesi `set_content()` ile
**text/plain** gidiyor (HTML enjeksiyonu yok); PDF `canvas.drawString`
kullanıyor, ReportLab'in mini-markup'ını yorumlayan `Paragraph` **değil**.

---

## 3. Onarım göçü — gerekli, ve KVKK'da bir gerilim var

**Göç 0066** `kvkk_metin.govde` ve `mesaj_sablonu.govde` satırlarını yerinde
temizliyor. **Zengin çizimin ön koşuludur**, sonradan yapılacak bir temizlik
değil: istemci artık gövdeyi HTML olarak çiziyor, dünden kalan bir satırda
betik taşıyıcısı varsa bugün **çalışır** hale gelirdi.

`mesaj_sablonu` için sorun yok — şablonlar tasarım gereği değiştirilebilir.

`kvkk_metin` için **yayınlanmış metin değiştirilemez** kuralı var (P36):
*"yerinde düzenlemeye izin verilseydi dün onay vermiş bir kullanıcının onayı
bugün başka bir metne ait görünürdü."* Göç bu kurala dokunuyor ve karar
bilinçli:

* Temizlik **yalnız betik taşıyıcılarını** kaldırır. Bunların hiçbiri yasal
  metnin *içeriği* değildir; kullanıcının okuyup onayladığı cümleler aynen
  kalır.
* Tersi çok daha kötüydü: "metin değişmesin" diye bir enjeksiyon vektörünü
  yayında bırakmak, o metni okuyan **her** kullanıcının oturumunu riske
  atardı.
* **Yeni sürüm açılmıyor.** Açmak, hiçbir şey değişmemiş tesislerde de 200
  sakini yeniden onaya sokardı ve "sürüm arttı, metin değişti" cümlesi
  **yalan** olurdu.

Değişmeyen satıra dokunulmuyor (`temiz == mevcut` ise atlanır), yani çoğu
kurulumda göç hiçbir yazma yapmıyor. Geri alma **bilerek boş**: atılan şey
betik taşıyıcısıydı, veri değil — "geri yükleme", kaldırılan vektörü geri
koymak olurdu.

Beyaz liste göçe **kopyalanmadı**, `app/temizleme.py`den ithal ediliyor: iki
liste bir gün ayrışırdı ve o gün göçün ürettiği değerle uygulamanın
üreteceği değer birbirini tutmazdı.

---

## 4. İstemciler — biçimlendirme geri geldi

### Web

P170'in `DOMParser` düz-metin çevirisi (`lib/zengin-metin-oku.ts`) ve testi
**silindi**; gövde yine `dangerouslySetInnerHTML` ile çiziliyor.

**İstemcide ikinci bir temizleyici konmadı** (DOMPurify dahil). Gerekçe:
temizlik istemci kararı olsaydı her istemci (web, mobil, e-posta, rapor) onu
ayrı ayrı doğru yapmak zorunda kalırdı ve birinin atlaması sessiz bir açık
olurdu. Tek doğru yer, verinin **girdiği** yer. İstemcideki bir temizleyici
burada yalnız aynı işi ikinci kez yapar ve *"asıl koruma nerede"* sorusunu
bulanıklaştırırdı.

`dangerouslySetInnerHTML` kullanımı artık **beyaz listeli**
(`tests/duz-metin-alanlari.test.ts`): yalnız iki dosya kullanabilir ve her
girişin yazılı bir gerekçesi var. Yeni bir kullanım, sunucu tarafında bir
karşılığı olduğunu göstermek zorunda.

Tailwind `preflight` başlıkları ve liste işaretlerini sıfırlıyordu — dar
kapsamlı bir `.yz-yasal-govde` stili eklendi. Genel bir `prose` sınıfı
açmak, sıfırlamayı uygulamanın her yerinde geri almak olurdu.

### Mobil — `flutter_html` değil, 200 satırlık kendi çizicimiz

Mobil `SelectableText(govde)` çiziyordu: sunucu artık `<h2>`/`<li>` içeren
gövdeler sakladığı için kullanıcı yasal metnin **ortasında ham etiketler**
görüyordu. Bu, bu turun yarattığı bir gerileme olurdu.

`lib/src/core/widgets/zengin_govde.dart` yazıldı. **`flutter_html` neden
değil:** o genel bir HTML+CSS motorudur (onlarca etiket, CSS ayrıştırma,
tablo/medya); bizim dilbilgimiz sunucunun garanti ettiği **13 etiket ve iki
öznitelik**. Genel motoru getirmenin bedeli paket boyutu ve — daha önemlisi —
bakım yüzeyi: kütüphane bir bakım aralığına girdiğinde yasal metin ekranı ona
bağlı kalırdı.

**Elle ayrıştırma burada neden kabul edilebilir, sunucuda değildi:**
sunucuda ayrıştırıcı **güvenlik sınırıdır** ve bir köşe durumu XSS demektir.
Burada gövde bu noktaya gelmeden önce temizlenmiş oluyor; bu dosya yalnız
görüntüleme yapıyor. En kötü hata biçimi *"bir etiketi yanlış çizmek"*,
*"kod çalıştırmak"* değil. Yine de ikinci katman var: bağlantı açılırken şema
tekrar denetleniyor.

Üç ekran bağlandı: `YasalMetinlerScreen`, `KvkkMetinScreen` ve
`KvkkOnayScreen`. Onay kapısında bu özellikle önemli — kullanıcının
**onayladığı** metni ham etiketlerle göstermek, neyi onayladığını
bulanıklaştırırdı.

---

## 5. Testler

| Yer | Ne ölçüyor |
|---|---|
| `backend/tests/test_temizleme.py` (18) | `<script>`, `<img onerror>`, `<svg onload>`, `<iframe>`, `javascript:`, `data:`, `style`, `on*` atılıyor; **meşru biçimlendirme korunuyor**; uçtan dönen **ve veritabanında duran** değer temiz; uzunluk sınırı kullanıcının metnine uygulanıyor; alan sınıflandırması iki yönlü kilitli |
| `admin-web/tests/duz-metin-alanlari.test.ts` (3) | `dangerouslySetInnerHTML` beyaz listesi; istemcide ikinci temizleyici yok |
| `mobile/test/zengin_govde_test.dart` (8) | ham etiket sızmıyor, metin kaybolmuyor, varlıklar çözülüyor, madde/numara işaretleri var, **tehlikeli şema tanıcı almıyor**, bozuk girdi ekranı çökertmiyor |

"Meşru biçimlendirme korunuyor" testi en az diğerleri kadar önemli: her şeyi
atan bir "temizleyici" güvenlidir ama ürünü bozar — P170'te tam olarak o
bedel ödenmişti ve bu turun sebebi de bu.

Test yazarken **iki gerçek belirsizlik** yakalandı ve ikisi de kodu
düzeltti: `ZenginHtml | None` alanlarında `AfterValidator` alanın
üstverisinde değil birleşim üyesinin içinde duruyor (üstveriye bakan bir
denetim, temizlik gerçekten çalışırken "çalışmıyor" diyordu) — denetim
**davranışsal** hale getirildi, tipi çalıştırıyor.

---

## 6. Test sunucusunda ne kontrol edeceksin

1. `panel.*` → **KVKK Metinleri** → tesis seç → editörde başlık, kalın,
   madde işaretli liste ve bir bağlantı içeren metin yayınla.
2. Herhangi bir rolle `app.*` → **Profil → Yasal Metinler**: başlıklar
   büyük, maddeler işaretli, bağlantı altı çizili görünmeli. Açık ve koyu
   temada bak.
3. Mobil uygulamada aynı metni aç: **ham `<h2>` etiketi görünmemeli**,
   biçimlendirme görünmeli, bağlantı dokununca tarayıcıda açılmalı.
4. Editöre dışarıdan HTML **yapıştır** (ör. `<img src=x onerror=alert(1)>`
   içeren bir parça) ve yayınla — kaydedilen metinde o parça **olmamalı**,
   yazdığın normal metin yerinde durmalı.

---

# P171 düzeltmesi — dağıtım ortamı düştü

> `34e4c0c4` dağıtıldı, göç 0066 `ModuleNotFoundError: app.temizleme` verdi,
> şema 0064'te kaldı, `api`/`admin-web`/`worker` hiç başlamadı.
> Ortam tamamen erişilemez oldu. **Bu benim hatamdı.**

## 1. Kök neden

Göç 0066 `from app.temizleme import zengin_temizle` yazıyordu; gerekçem
"tek doğruluk kaynağı" idi. **Gerekçe yanlıştı.**

`infra/docker-compose.yml` `contracts/` dizinini **canlı mount** eder,
`backend/app/` ise **imaja gömülüdür**. Göç dosyası ile uygulama kodu
**farklı kanallardan** gelir ve **farklı sürümlerde olabilir**. Depo
güncellenip imaj yeniden kurulmadığında konteyner yeni göçü görür ama eski
kodu taşır.

Bunu daha önce not etmişim (`backend-contracts-canli-mount`) ve yine de
aynı ayrımın içine düştüm.

**Asıl ilke:** göçler tarihsel kayıttır. Bir göç yazıldığı andaki dünyayı
tarif eder ve yıllar sonra aynı sonucu üretmelidir. Bugünün uygulama koduna
bağlanan bir göç, o kod değiştiğinde geçmişi kırar. Beyaz liste artık göç
dosyasının içinde **dondurulmuş**; `app/temizleme.py` ile ayrışabilir ve
ayrışması bir kusur **değil**, doğru davranıştır.

`nh3` ithali kaldı — o bir kütüphane bağımlılığıdır, `requirements.txt`
üzerinden alembic'le **aynı kanaldan** imaja girer. Eksikse göç sessizce
atlamak yerine **eyleme dönük** bir mesajla durur: bir güvenlik onarımını
yapılmamış bırakıp yapılmış saymak, yapmamaktan kötüdür.

**0065 kontrol edildi:** yalnız `from alembic import op` içeriyor, aynı
sorun yok.

## 2. API şema uyumsuzluğunda ne yapmalı

Önce bir düzeltme: **API zaten uyarıyla açılıyor ve sağlık kontrolünde
bildiriyor** (P124'te tam bu senaryo için tasarlanmış). Çökme sebebi API
değildi.

Gerçek mekanizma **compose bağımlılık kapısı**: `api` migrate'e
`service_completed_successfully` ile bağlı, `admin-web` de `api`'nin
sağlığına. Göç düşünce üçü de hiç başlamıyor ve `docker ps` boş görünüyor.

**Bu kapıyı gevşetmeyi önermiyorum.** Yarı göç edilmiş bir şemaya karşı
servis vermek, kapalı olmaktan kötüdür: kod beklemediği bir şemaya **yazar**.
Asıl boşluk teşhisti, ve iki yerde kapatıldı:

* **Migrate düşerse eyleme dönük banner** (dev + prod compose): ne olduğunu,
  neden her şeyin kapalı göründüğünü ve ne yapılacağını yazıyor. Hata yolu
  gerçekten sürüldü. (`trap ... ERR` denendi ve **çalışmadı** — konteynerin
  kabuğu `sh`, ERR tuzağı bash'e özel; açık `|| hata` kullanıldı.)
* **Açılışta şema günlüğü**: önceden yalnız `/health` raporluyordu, yani
  *bakan biri* gerekiyordu. Ayrışma artık ilk istekten önce logda.

**Öneri (uygulanmadı, kararı senin):** `admin-web`i `api: service_healthy`
kapısından çıkarmak. Bugün API düşünce alan adı Caddy 502 veriyor; bağımsız
başlarsa en azından bir sayfa gelir. Dağıtım topolojisi değişikliği olduğu
için bir düzeltme turunda tek başıma yapmadım.

## 3. Kapılar — ikisi tamamlayıcı

**`backend/tests/test_goc_bagimsizligi.py` (statik).** Hiçbir göç `app.*`
ithal edemez; fonksiyon içindeki ithaller de sayılır (ilk kusur tam orada,
`upgrade()` içindeydi). Zincirin tek uçlu, kopuksuz ve tekrarsız olduğunu da
ölçüyor. **Kilidin kusuru yakaladığı kanıtlandı**: eski ithal geri kondu,
test kırıldı, geri alındı.

**`infra/goc-sifirdan.sh` (uçtan uca).** Depodaki hâliyle **yeniden kurulan**
migrate imajı, **boş** bir veritabanında zinciri baştan sona koşuyor ve
varılan revizyon dosyalardan hesaplanan HEAD ile karşılaştırılıyor —
"hata vermedi" yetmez, zincir ortada durmuş olabilir. `--deney` bayrağı
geçici bir bozuk göç yazıp kapının **gerçekten kırıldığını** gösteriyor;
kapı, kırılabildiğini kanıtlayana kadar kapı değildir. `infra/kapilar.sh`
`goc` grubuna bağlandı.

**Neden ikisi birden:** statik olan sınıfı ortamdan bağımsız kapatır ama
"imajda gerçekten koşuyor mu" sorusunu yanıtlamaz (örneğin `nh3` eksikse
orada görünmez). Uçtan uca olan çalışırlığı ölçer ama geliştiricinin imajı
tazeyse — **bu turda tam olarak öyle oldu** — kusuru göremez.

Mevcut `goc-tersinirlik.sh` bu kusuru neden kaçırdı: o da gerçek konteynerde
koşuyor, ama **o an kurulu** imajla. İmajın depoyla uyumlu olup olmadığını
hiç ölçmüyordu.
