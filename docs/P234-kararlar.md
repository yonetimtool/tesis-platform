# P234 — Resend geçişi, Excel sakin aktarımı, Cloudflare değerlendirmesi

---

## §1 — Resend'e geçiş

### Ölçülen durum (önce)

`app/gonderim.py::eposta_saglayicisi()` zaten TEK seçim noktasıydı ve
`SmtpEpostaSaglayici` / `KonsolEpostaSaglayici` / `LogEpostaSaglayici`
üçlüsünü ayırıyordu. Yani soyutlama **vardı** — istekteki "yeni katman
açma" şartı bu yüzden zaten karşılanabilir durumdaydı.

**Mailcow'a ait kod ya da yapılandırma deposunda YOK.** Tarandı: `mailcow`
geçen tek bir dosya bile çıkmadı. Tek iz `infra/.env.prod.example`
içindeki yorum satırıydı (`# SMTP_HOST=mail.yonetiyor.com`) — o da
Resend'e göre güncellendi. Yani "ölü kod bırakma" maddesinde temizlenecek
bir kod yığını çıkmadı; bu iyi haber, çünkü Mailcow hiçbir zaman koda
sızmamış, yalnızca bir SMTP sunucusu adı olarak kalmış.

### SMTP mi API mi — **API**, ve gerekçesi tek bir şeye dayanıyor

Resend ikisini de sunuyor. **HTTP API** seçildi:

**Asıl sebep — teslim geri bildirimi.** Bounce webhook'u "şu mesaj geri
döndü" der ve elindeki tek tanıtıcı **Resend'in kendi mesaj kimliğidir**.
API yanıtı o kimliği döner (`{"id": "..."}`); SMTP'de böyle bir kimlik
yok — 250 yanıtındaki kuyruk kimliği sunucuya göre değişir ve Resend
tarafındaki kimlikle aynı olacağının garantisi yoktur.

SMTP seçseydik webhook gelir ama **hiçbir satıra yazılamazdı**: "bounce
geri bildirimi" maddesi kâğıt üzerinde kalırdı. Bu tek başına belirleyici.

İkincil sebepler (tek başlarına yetmezdi): 587/465 giden portu birçok ağda
kısıtlı, 443 zaten açık (Open-Meteo, FCM, ödeme sağlayıcıları aynı yoldan
gidiyor); hatalar yapısal (JSON + kod), `hata` alanına anlamlı değer
yazılabiliyor.

### Seçim nasıl yapılıyor — `konsol` ile AYNI kalıp

`SMTP_HOST=resend` + `SMTP_PASSWORD=re_...`. Taşıyıcı **sunucu adı olarak**
seçiliyor; yeni bir bayrak/env anahtarı **açılmadı**.

Gerekçe P196'da ölçülmüş: global bir `EPOSTA_SAGLAYICI` değişkeni tesis ve
env ayarından **önce** geliyor, "hiçbir yapılandırma yok" durumunu ortadan
kaldırıyor ve ürünün çekirdek garantisini (yapılandırma yokken
"gönderildi" deme) ölçen **14 testi** düşürüyordu. O yol bir kez denenip
geri alınmış; aynı hatayı tekrarlamadım.

Sonuç: **kendi SMTP'sini girmiş tesis etkilenmiyor** (test ediliyor), ve
isterse bir tesis kendi Resend anahtarını kullanabiliyor.

API anahtarı `smtp_parola` alanından okunuyor: sır taşıyan kanal zaten o
ve maskeleme/denetim kuralları ona göre kurulu. İkinci bir sır alanı
açmak, aynı kuralı iki yerde tutmak olurdu.

### Bounce geri bildirimi — zincir

```
gönderim → Resend API → {"id": "..."} → mesaj_gonderim.saglayici_mesaj_id
                                              ↑
POST /webhooks/eposta/resend ← Resend ────────┘
   (Svix HMAC doğrula → olay defteri → tenant çöz → satırı güncelle)
```

**Göç 0135**: `mesaj_gonderim.saglayici_mesaj_id` (kısmi benzersiz
indeks), `eposta_webhook_olay` (tekrar engeli),
`gonderim_tenant_by_saglayici_id` (SECURITY DEFINER — webhook'ta tenant
bağlamı yok, ödeme webhook'uyla aynı kalıp).

**Yeni enum değeri açılmadı.** `mesaj_durum` zaten `iletildi` ve `okundu`
taşıyor — Resend'in `delivered`/`opened` olayları tam olarak bunlar.
`bounced`/`complained` için üçüncü bir değer eklemedim: enum'a değer
eklemek kolay, **geri almak değil** (`goc-tersinirlik.sh` downgrade
sonrası şemayı karşılaştırıyor), ve ikisi de aynı eyleme çıkıyor — *bu
adrese bir daha yazma*. `basarisiz` + ayırt edici `hata` kodu
(`bounce`, `spam_sikayeti`) hem durumu hem sebebi taşıyor.

**Şikayet neden `basarisiz`:** mesaj teknik olarak teslim edildi, yani
"başarılı" da denebilirdi. Ama şikayet, bir sonraki gönderimin spam
klasörüne düşme olasılığını artıran **en önemli sinyaldir**; onu
"başarılı" kutusuna koymak, yöneticinin görmesi gereken tek satırı
gizlemek olurdu.

**Durum geri gitmez:** olaylar sırasız gelebiliyor (`opened` bazen
`delivered`'dan önce düşüyor). Sıralı bir sayaç olmadan tek güvenli kural
ilerlemedir; aksi hâlde panelde "okundu" yazan satır sonradan
"gönderildi"ye dönerdi.

**Bilinmeyen olay türü 200 döner:** 4xx dönmek sağlayıcıyı tekrar denemeye
ve sonunda webhook'u **devre dışı bırakmaya** iter — yani bilmediğimiz bir
olay yüzünden bildiğimiz olayları da kaybederiz.

### Kırarak doğrulandı

| Kırma | Sonuç |
|---|---|
| İmza doğrulamayı bypass et | 2 test düştü ✔ |
| Durum geri gitme korumasını kaldır | 1 test düştü ✔ |
| `davet.py`den `saglayici_mesaj_id`yi sil | **hiçbiri düşmedi ✘** |

Üçüncüsü gerçek bir boşluktu: davet e-postası bounce olsa panelde yine
"gönderildi" yazardı — turun düzelttiği kusurun aynısı, başka bir yolda.
Davranış testiyle yakalanamıyor (konsol/log sağlayıcıları kimlik
üretmiyor, gerçek Resend çağrısı yapılamaz), bu yüzden **kaynak taraması
kilidi** eklendi: `MesajGonderim(...)` kurup `kanal="eposta"` yazan her yer
`saglayici_mesaj_id` geçmek zorunda. Dört dedektör vakasıyla sınandı.

### Gönderen adresi — **alt alan adı öneriyorum**

```
Yönetiyor <bildirim@bildirim.yonetiyor.com>
```

**Neden alt alan adı:**

1. **İtibar yalıtımı.** Uygulama e-postaları hacimlidir ve bounce/şikayet
   riski taşır (yanlış yazılmış sakin adresleri). O riski kök alan adına
   yüklemek, `iletisim@yonetiyor.com`'dan yazılan bir sözleşme e-postasının
   da spam'e düşmesi demektir. Alt alan adı ayrı bir itibar havuzudur.
2. **Google Workspace ile çakışmaz.** Kurumsal posta kökte (`MX` →
   Google), Resend alt alan adında. İkisinin SPF kaydını tek `TXT`e
   sıkıştırma zorunluluğu ortadan kalkar — SPF'nin 10 DNS-sorgusu sınırı
   gerçek bir tuzaktır ve iki sağlayıcıyı kökte birleştirmek onu zorlar.
3. **Geri dönüşü kolay.** Alt alan adının itibarı bozulursa yenisine
   geçilir; kök alan adının itibarı bozulursa yapılacak bir şey yoktur.

**Bedeli dürüstçe:** yeni alt alan adı **sıfır itibarla** başlar; ilk
günlerde ısınma (warm-up) gerekir — düşük hacimle başlayıp artırmak.
Kökten göndermek olsaydı da aynı şey geçerliydi (kök de bugüne kadar
Mailcow'dan gönderiyordu ve o itibar zaten **RBL'de**), yani bu bedel
geçiş kararının değil, kaynağın bedeli.

### Eklemen gereken DNS kayıtları

Resend panelinde alan adını eklediğinde **sana özel değerler** üretir;
aşağıdaki tablo hangi kayıtların geleceğini ve nereye konacağını gösterir.

| Tip | Ad | Değer | Not |
|---|---|---|---|
| `MX` | `send.bildirim.yonetiyor.com` | `feedback-smtp.eu-west-1.amazonses.com` (öncelik 10) | Resend'in bounce toplaması. **Bölge Resend panelinde ne diyorsa o** |
| `TXT` | `send.bildirim.yonetiyor.com` | `v=spf1 include:amazonses.com ~all` | SPF |
| `TXT` | `resend._domainkey.bildirim.yonetiyor.com` | `p=MIGfMA0GCSq...` (Resend verir) | DKIM |
| `TXT` | `_dmarc.yonetiyor.com` | `v=DMARC1; p=none; rua=mailto:dmarc@yonetiyor.com` | **Kökte**, alt alanları da kapsar |

**DMARC neden `p=none` ile başlıyor:** `p=reject` ile başlamak, henüz
göremediğimiz bir yanlış yapılandırmanın **tüm postayı sessizce
öldürmesi** demektir. `none` + `rua` raporu, iki hafta rapor topladıktan
sonra `quarantine`, sonra `reject`. Sıra atlanmamalı.

**Google Workspace kökte ayrı:** `MX` kayıtları (`ASPMX.L.GOOGLE.COM` vb.)
**köke** gider ve Resend'in `send.` altındaki MX'iyle çakışmaz — farklı
adlar. Kökün SPF'i Google'ı içerir (`include:_spf.google.com`), Resend'in
SPF'i alt alanda durur. İkisi birbirine karışmaz.

### Kesintisiz geçiş sırası

Sıra **bu** olmalı; 3 ve 4 yer değişirse posta durur.

1. **DNS kayıtlarını ekle** (yukarıdaki tablo). Mailcow hâlâ çalışıyor,
   hiçbir şey değişmedi. Resend panelinde alan adı "verified" olana kadar
   bekle (dakikalar–saatler).
2. **Resend'de webhook oluştur**: `https://api.yonetiyor.com/webhooks/eposta/resend`,
   olaylar: `email.sent`, `email.delivered`, `email.opened`,
   `email.bounced`, `email.complained`, `email.delivery_delayed`.
   Verilen `whsec_...` sırrını `.env.prod`a `RESEND_WEBHOOK_SIRRI` olarak
   koy. **Henüz gönderim Resend'den gitmiyor** — webhook boşta bekler,
   zararsız.
3. **Uygulamayı Resend'e al**: `.env.prod`da
   `SMTP_HOST=resend`, `SMTP_PASSWORD=re_...`,
   `SMTP_FROM="Yönetiyor <bildirim@bildirim.yonetiyor.com>"`.
   `docker compose up -d --force-recreate api worker beat`.
   Bu andan itibaren yeni e-postalar Resend'den çıkar.
4. **Doğrula** (Mailcow hâlâ ayakta, geri dönüş bir env satırı):
   - kendine bir davet gönder → geldi mi,
   - `/mesajlar` sayfasında satır `gönderildi` → birkaç saniye sonra
     `İletildi` oluyor mu (webhook çalışıyor demektir),
   - var olmayan bir adrese gönder → satır `Başarısız · Geri döndü` mü.
5. **Kurumsal postayı Google Workspace'e taşı** (senin işin) — kök `MX`
   değişir. Bu adım 3'ten **sonra** olmalı: uygulama postası artık Mailcow'a
   bağlı değil, yani MX değişimi uygulamayı etkilemez.
6. **Mailcow'u kapat.** En az bir hafta bekle: gecikmeli bounce'lar ve
   eski MX'e gelen postalar için.

**Geri dönüş planı:** 3. adımdan sonra sorun çıkarsa `SMTP_HOST`u eski
değere döndürmek yeterli — kod iki yolu da taşıyor ve tesis bazlı SMTP
ayarı hiç bozulmadı.

### Yöneticiye görünen teslim durumu

`/mesajlar` sayfası zaten `durum` + `hata` gösteriyordu. Eklenen: eksik
olan `yapilandirilmadi` çevirisi ve teslim kodlarının çevirisi —
`bounce` → "Geri döndü (adres ulaşılamaz)", `spam_sikayeti` → "Spam olarak
işaretlendi". Ham kodu göstermek yöneticiye sözlük aratmak olurdu;
**çevirisi olmayan sağlayıcı kodları olduğu gibi kalır** (uydurmak yerine
ham kod göstermek doğru).

---

## §3 — Cloudflare değerlendirmesi (UYGULANMADI, onayını bekliyorum)

Bu bölümde **hiçbir şey uygulanmadı**. İstek açıktı: "Uygulamadan ÖNCE
onayımı al." Aşağıdakiler ölçüm ve öneridir.

### Önce ölçüm — sorduğun risklerin bugünkü gerçeği

| Soru | Ölçülen durum |
|---|---|
| WebSocket var mı? | **YOK.** Ne backend'de ne panelde WebSocket/SSE kullanımı bulunamadı. |
| Gerçek istemci IP'si nerede kullanılıyor? | **Hız sınırlama IP'ye BAKMIYOR** — `hiz_siniri.py` telefon/e-posta ekseninde ve gerekçesi dosyada yazılı ("`X-Forwarded-For`a güvenmek, başlığı uyduran birine sınırsız hak vermek olurdu"). **`audit_log`da IP sütunu YOK.** |
| MediaMTX HLS ayrı konaktan mı? | **Hayır.** Canlı akış `api` üzerinden geçiyor (`/cameras/{id}/canli/index.m3u8`); Caddy'de MediaMTX'e ait bir blok yok. |
| MinIO yükleme nereden? | `storage.yonetio.site` → Caddy → MinIO, **presigned URL** ile ve `Host` korunarak (s3v4 imzası buna bağlı). |
| Caddy TLS | Her konak bloğunda `{$CADDY_TLS}`; prod'da ACME (Let's Encrypt). |

Yani **iki endişen bu kurulumda bugün geçersiz**: WebSocket yok, ve IP'ye
bakan bir hız sınırlama/denetim yok. Bu, Cloudflare'i daha kolay
kılıyor — ama aşağıdaki üç gerçek engel duruyor.

### Alan adı alan adı öneri

| Alan adı | Proxy | Gerekçe |
|---|---|---|
| `yonetiyor.com`, `www` | **AÇIK** 🟠 | Tanıtım sitesi. Statik, kamuya açık, önbellekten en çok kazanan yüzey. Risk yok. |
| `panel.yonetiyor.com` | **AÇIK** 🟠 | Yönetim paneli. WebSocket yok, yükleme presigned URL ile `storage.`ye gidiyor — Cloudflare'in gövde sınırına takılmıyor. |
| `app.yonetiyor.com` | **AÇIK** 🟠 | Aynı gerekçe. |
| `api.yonetiyor.com` | **KAPALI** ⚪ | Aşağıda — canlı kamera akışı. |
| `api.yonetio.site` | **KAPALI** ⚪ | Yayındaki mobil sürümler buraya bağlı; değiştirmeye değmez. |
| `storage.yonetio.site` | **KAPALI** ⚪ | Aşağıda — imza + gövde sınırı. |
| `mail` / `MX` / `SPF` / `DKIM` / `DMARC` | **KAPALI** ⚪ | Aşağıda — kritik. |

### `api.` neden proxy'den GEÇMEMELİ

**Asıl sebep canlı kamera akışı.** HLS ayrı bir konaktan değil,
`api.yonetiyor.com/cameras/{id}/canli/index.m3u8`den servis ediliyor.
Cloudflare'in **Hizmet Şartları 2.8** maddesi, ücretsiz/Pro katmanlarda
HTML olmayan sürekli video içeriğinin proxy üzerinden servisini
kısıtlıyor. Bu bir performans meselesi değil, **hesap askıya alma**
meselesi — ve askıya alınan şey yalnız video değil, API'nin tamamı olur.

İkincil sebepler:
- **Yükleme boyutu:** ücretsiz katmanda istek gövdesi **100 MB** ile
  sınırlı. Bugün büyük yüklemeler `storage.`ye gidiyor, yani API bu
  sınıra yakın değil — ama rapor/belge uçları büyürse sessizce 413
  vermeye başlar.
- **Uzun istekler:** Cloudflare 100 saniyede (524) keser. Rapor üretimi
  ve toplu aktarım bu eşiğe yaklaşabilir.
- **Mobil için kazanç yok:** mobil istemci zaten tek bir bölgeden
  konuşuyor; CDN önbelleği API yanıtlarında kullanılmıyor.

### `storage.` neden proxy'den GEÇMEMELİ

1. **Presigned URL imzası `Host` başlığına bağlı.** Caddy `Host`u koruyor
   ve MinIO s3v4 imzasını onunla doğruluyor (`Caddyfile` yorumu bunu
   açıkça yazıyor). Cloudflare araya girdiğinde `Host` korunur ama
   **query string ve başlık normalizasyonu** imzayı bozabilir. Bu, "bazen
   çalışır bazen çalışmaz" sınıfı bir kırılganlıktır.
2. **100 MB gövde sınırı doğrudan buraya vurur** — fotoğraf/belge yükleme
   tam olarak bu yoldan geçiyor.

### Mail DNS — **proxy KAPALI olmalı** (en kritik madde)

`MX`, `SPF` (TXT), `DKIM` (TXT), `DMARC` (TXT) kayıtları **zaten
proxy'lenemez** — Cloudflare yalnız `A`/`AAAA`/`CNAME` kayıtlarını
proxy'ler ve `MX`/`TXT` için turuncu bulut seçeneği bile çıkmaz.

**Gerçek tehlike başka yerde ve senin uyarın haklı:** posta sunucusunun
`A` kaydı (örneğin `mail.yonetiyor.com`) proxy'lenirse `MX`in işaret
ettiği ad Cloudflare IP'sine çözülür ve **gelen posta tamamen durur**.
§1'deki geçişten sonra kendi posta sunucumuz kalmıyor (Resend + Google
Workspace), yani bu risk **geçiş tamamlandığında ortadan kalkıyor** — ama
geçiş bitmeden Cloudflare'e geçilirse tam olarak bu olur.

**Bu yüzden sıra önemli: §1 geçişi bitsin, sonra Cloudflare.**

### Caddy ile çakışır mı — SSL modu

Çakışmaz, **ama yanlış mod felakettir.**

- **Kullanılacak mod: `Full (strict)`.** Cloudflare ↔ sunucu arası TLS
  kurulur ve sertifika doğrulanır. Caddy zaten geçerli Let's Encrypt
  sertifikası sunuyor; hiçbir şey değişmez.
- **`Flexible` ASLA KULLANILMAMALI:** Cloudflare sunucuya **HTTP**
  konuşur. Caddy 80'i 443'e yönlendirdiği için sonsuz yönlendirme
  döngüsü oluşur, ve oluşmasa bile trafik son bacakta şifresiz gider.
- **`Full` (strict değil)** ortada bir şey: şifreli ama sertifika
  doğrulanmıyor — ortadaki adam saldırısına açık. Gerekçesi yok.

ACME ile çakışma: Caddy `HTTP-01` doğrulaması yapıyor. Proxy açıkken
Cloudflare `/.well-known/acme-challenge/` yolunu geçiriyor, yani
yenileme çalışmaya devam eder. Yine de **ilk geçişte sertifika
yenilemesini izlemek gerekir**; sorun çıkarsa çözüm `DNS-01`e geçmek
(Caddy Cloudflare DNS eklentisi) ya da o konağı gri buluta almaktır.

### Gerçek istemci IP'si

Cloudflare arkasında sunucu **Cloudflare IP'sini** görür; gerçek adres
`CF-Connecting-IP` başlığında gelir.

**Bugün bunu kullanan bir yer YOK** (ölçüldü: hız sınırlama telefon
ekseninde, `audit_log`da IP sütunu yok). Yani geçiş bugün hiçbir şeyi
bozmuyor. **Ama bu, ileride IP'ye bakan bir şey yazılırsa sessizce yanlış
çalışacağı anlamına gelir** — bu yüzden geçişle birlikte Caddy'ye
`trusted_proxies` + `CF-Connecting-IP` eşlemesi konmalı ki doğru adres
`X-Forwarded-For`a yazılsın. Cloudflare IP aralıkları düzenli değişir,
yani bu liste **güncel tutulmalı**; Caddy'nin `cloudflare` IP kaynağı
modülü bunu otomatik yapar.

### Kazanımlar (dürüstçe: sınırlı)

- **DDoS ve bot filtresi** — tanıtım sitesi ve panel için gerçek kazanç.
- **Kaynak IP gizlenir** — sunucunun genel IP'si doğrudan hedeflenemez.
  (Not: `api.` ve `storage.` gri kalacağı için **IP yine görünür olur**;
  bu kazanım kısmi.)
- **Statik önbellek** — tanıtım sitesinde anlamlı, panelde az.
- **Ücretsiz TLS + DNS yönetimi** — DNS'i tek yerden yönetmek §1'in
  kayıtlarını eklemeyi de kolaylaştırır.

### Kayıplar / riskler

- **Gri kalan konaklar korunmaz:** `api.` ve `storage.` Cloudflare
  arkasında olmayacağı için DDoS koruması onları kapsamaz ve sunucunun
  gerçek IP'si o kayıtlardan görünür. Yani "kaynak IP gizlenir" kazanımı
  **pratikte gerçekleşmez**. Bunu peşinen söylüyorum, çünkü Cloudflare'in
  en çok anlatılan faydası bu ve burada büyük ölçüde geçersiz.
- **Teşhis zorlaşır:** araya bir katman girer; 5xx'in kimden geldiği
  (Cloudflare mi Caddy mi) ayrı bir soru olur.
- **Yanlış yapılandırma tek hamlede her şeyi durdurur** — özellikle
  `Flexible` SSL ve posta `A` kaydı.

### Önerim

**Sınırlı bir geçiş:** yalnız `yonetiyor.com`, `www`, `panel.`, `app.`
turuncu; `api.`, `api.yonetio.site`, `storage.` ve tüm posta kayıtları
gri. SSL modu `Full (strict)`. Ve **§1 tamamlandıktan sonra.**

Bunu onaylarsan uygulanacak adımları (Caddy `trusted_proxies` dahil)
yazar ve senin çalıştıracağın komut listesini çıkarırım.

---

## Kilit registreleri — tam paket ne buldu

İlk tam koşum **3246 geçti, 7 düştü**. Yedisi de kilit registresi; ikisi
**P233'ten kalmaydı** ve bu, benim atladığım bir adımın sonucu:

> **P233 §1'i backend tam paketini koşmadan push etmişim.** O turda yalnız
> yeni test dosyasını koştum. `kurulum`a eklenen `konum` adımı
> `test_ADIM_KODLARI_SABIT`i (18 → 19) ve `rol-matrisi.txt`i kırmıştı;
> ikisi de bu turda kapandı.

| Kilit | Sebep | Çözüm |
|---|---|---|
| `test_ADIM_KODLARI_SABIT` | P233 §1 `konum` adımı | 19 + sıra + gerekçe yazıldı |
| `rol_matrisi_kilidi` | `/konum/ara` + webhook | yeniden üretildi (2 satır) |
| `test_rls_kapsam` ×2 | yeni tablo **RLS'sizdi** | aşağıda |
| `denetci_salt_okuma` | yeni kapısız uç | webhook kaydedildi |
| `tesis_izolasyonu_tarama` | yeni uç paydayı artırdı | aşağıda |
| `public_beyan_edilenler` | webhook 401 dönüyor | aşağıda |

### Yeni tablo RLS'siz bırakılmıştı — desen ihlali

`eposta_webhook_olay`u "tenant'sız, o hâlde RLS'siz" diye bıraktım.
`test_rls_kapsam` düştü ve haklıydı: **depoda "RLS'siz tablo" diye bir
sınıf yok.** Tenant'sız üç tablo (`tanitim_iletisim`, `yonetici_basvuru`,
`surum_politikasi`) hepsi aynı deseni taşıyor — RLS **AÇIK + FORCE**,
politika **YOK**, erişim **yalnız SECURITY DEFINER** fonksiyonundan.

Tablo dördüncü üye olarak aynı desene uyduruldu: doğrudan `INSERT`
kaldırıldı, yerine `eposta_webhook_olay_ekle(text) → boolean` kondu (TRUE =
ilk kez görüldü). Platform tavanı 3 → 4, gerekçesi yazılı.

### İzolasyon taraması — kural vardı ama yanlış sebeple çalışıyordu

Tarama "oturumun tenant'ı dışındaki satırlar dönüyor mu" diye sorar.
Webhook'ta **oturum yok**: çağıran bir kullanıcı değil sağlayıcı, kimlik
jetonla değil imzayla kuruluyor. Böyle bir uca o soruyu sormak, sorunun
ön koşulunu taşımıyor.

Ödeme webhook'u bu taramadan **tesadüfen** muaftı — yolunda `{provider}`
olduğu için `"{" not in y` süzgecine takılıyordu. Resend webhook'unda
parametre yok, paydaya girdi ve oranı eşiğin altına düşürdü. `/webhooks`
artık **adıyla** dışarıda.

### `security: []` ne demek — tanımın düzeltilmesi

`public_beyan_edilenler` testi "public beyan edilen uç 401 dönmemeli" der.
Webhook 401 dönüyor çünkü imza yok.

`security: []` **"bearer jeton istemiyorum"** demektir; "kimlik doğrulamam
yok" demek değil. İmzasız isteğe 401 dönmek **doğru cevaptır**. Bu ayrımı
yapmasaydık iki seçenek kalırdı: sözleşmede webhook'u jetonlu göstermek
(yalan — sağlayıcı jeton göndermiyor) ya da 401 yerine 400 dönmek (testi
memnun etmek için yanlış durum kodu). İkisi de kilidi kandırmak olurdu.
`/webhooks` testten muaf tutuldu ve gerekçe testin içine yazıldı.

---

## §2 — Excel ile sakin aktarımı

### Ölçüm önce: çerçevenin çoğu P193'te YAPILMIŞTI

İstenen yedi maddeden dördü zaten çalışıyordu:

| İstenen | Durum |
|---|---|
| Örnek dosya indirilebilsin | **vardı** (CSV), ama tek örnek satır, açıklama yok |
| Yükleme öncesi önizleme | **vardı** (`yalniz_dogrula` — hiçbir şey yazmaz) |
| Sorunlu satır → DUR veya açıkça "atla" | **vardı** (kuru koşum + `sorunlulari_atla`) |
| Aktarım sonrası özet | **vardı** (eklenen/atlanan/hatalı + davet sayıları) |
| Blok sütunu | **yoktu** |
| Malik/kiracı/malik-oturan | kısmen — `malik`/`kiraci` vardı |
| E-posta zorunlu | **vardı** (P193 §1) |

Yani bu turda yapılan iş, var olanı yeniden yazmak değil **eksik dördü
kapatmak** oldu.

### Ölçüm sırasında çıkan çelişki — telefon

`kisi` türünde **telefon ZORUNLUYDU**. Ama P212-ek §2'de tekil ekleme
ucunda (`UserCreate.telefon`) zorunluluk **kaldırılmıştı** ve gerekçesi
şuydu: `uq_app_user_telefon` telefonu **platform genelinde** benzersiz
kılıyor, yani aynı kişi ikinci bir tesise ancak **uydurma bir numarayla**
eklenebiliyordu. Kimlik P197'den beri e-postadır.

Excel yolu o değişiklikten habersiz kalmış: **aynı veri iki farklı kuralla
giriliyordu** — P193 §1'in düzelttiği kusurun ters yönde aynısı. Telefonu
olmayan bir sakin listesi yükleyen yönetici her satırda
"zorunlu_alan_eksik" görüyordu.

Kaldırıldı. **Biçim denetimi duruyor**: doldurulduysa geçerli olmalı —
sessizce bozuk numara yazmak, sonradan hiçbir kanaldan ulaşılamayan bir
kayıt bırakırdı.

**Yan etkisi vardı ve kapatıldı:** mükerrer kontrolü yalnız telefona
bakıyordu. Telefon opsiyonel olunca telefonsuz satırlarda o kontrol **hiç
çalışmazdı** — aynı dosya iki kez yüklenince aynı kişi iki kez açılır ve
"idempotent: var olan kayıt ATLANIR" sözü sessizce bozulurdu. Kontrol iki
anahtara bakıyor ve **kapsamları farklı** (P228'de ölçülmüştü): telefon
platform genelinde, e-posta tesis içinde benzersiz.

### Blok sütunu — ilk gerekçem yanlıştı, test yakaladı

"İki blokta aynı numaralı daire olabilir, blok onu ayırır" diye yazmıştım.
`uq_unit_tenant_no` buna **zaten izin vermiyor** — daire numarası tesis
içinde benzersiz. Şema varsayımımı çürüttü.

Sütun duruyor ama işi başka: **tutarlılık denetimi**. Kullanıcı dosyaya
`blok=B, daire=A-3` yazdıysa dosyanın kendisi yanlıştır; blok verildiğinde
arama ona göre daraltılır ve eşleşme bulunamazsa satır **hata olarak
raporlanır**. Sessizce numaraya bakıp "buldum" demek, yanlış yazılmış bir
dosyayı doğru sanıp uygulamak olurdu.

Boş bırakılabilir — verilmezse eski davranış korunur, mevcut dosyalar
bozulmaz.

### `malik_oturan` — üçüncü bir rol DEĞİL

P218'de ölçülmüştü: "malik ve oturan" üçüncü bir rol değil, malikin
oturuyor olmasıdır (`rol_tipi='malik'` + `oturuyor=true`). Modele üçüncü
bir enum değeri eklemek, "malikler" sorgusunu iki değeri birden aramaya
zorlardı ve unutulduğu yerde sessizce yanlış çalışırdı.

Ama **kullanıcı Excel'e "malik-oturan" yazar**. Sütun üçünü de kabul edip
modele doğru çeviriyor; tire/alt tire/boşluk normalleştiriliyor. Tire
yüzünden hata vermek, sütunun kendisini kullanılmaz kılardı.

### Örnek dosya — neden CSV, ne değişti

**CSV kaldı, XLSX üretilmiyor** ve bu P28/P29 kararının devamı: sunucu
xlsx **ayrıştırmıyor** (saldırı yüzeyi) ve üretmiyor da. CSV'yi Excel
doğrudan açar, BOM sayesinde Türkçe harfler bozulmaz, ve indirilen şablon
ile kabul edilen biçim **tek kaynaktan** (alan listesi) geliyor — yani
ayrışamazlar.

Eklenen: **açıklama satırı** (`# ad (zorunlu) | telefon (istege bagli) |
...`) ve `kisi` türünde **üç örnek satır** (malik, kiracı, malik_oturan).
Açıklama `#` ile başlıyor ve **yükleyici onu atlıyor** — aksi hâlde kendi
ürettiğimiz şablon kendi yükleyicimizi kırardı; bu da teste bağlandı.

Ayrı bir "açıklama sayfası" değil, çünkü kullanıcı şablonu Excel'de açıp
doğrudan dolduruyor; açıklamayı başka yere koymak, okunmayacağı yere
koymak olurdu.

### Mobil

**Mobilde Excel aktarımı YOK ve olmayacak** — P204 kararı geçerli: 200
satırlık bir önizlemeyi telefonda doğrulamak mümkün değil. Bu, kalıcı
web+mobil parite kuralının **önceden gerekçelendirilmiş istisnasıdır**.

### Web tam paketi iki gerçek kusur buldu

Şablonu genişletirken iki çevrilmemiş sabit bıraktım ve **kilitler
yakaladı** — ikisi de gerçek:

1. **`(zorunlu)` / `(isteğe bağlı)`** açıklama satırına Türkçe sabit
   olarak yazılmıştı. O satır **indirilen dosyaya giriyor ve kullanıcı
   onu okuyor**: Almanca arayüz kullanan bir yöneticiye Türkçe açıklama
   vermek olurdu. 7 dile çevrildi.
2. **`Ayşe Yılmaz` / `Mehmet Demir`** örnek satırlarında Türkçe karakterli
   sabitler vardı. Örnek adlar ASCII'ye çevrildi — satırın bilgi taşıyan
   yanı zaten `rol_tipi` sütunu; ad alanı yalnızca satırı dolduruyor.
