# P212 — web giriş hatası, profil fotoğrafı, gürültü eskalasyonu

## §1 — Web girişi kırıktı: BFF vekili eski sözleşmede kalmış

### ÖLÇÜM — kırılma noktası arayüz değil, **vekil**
`app.yonetiyor.com/login`de telefon + parola ile giriş
**"Tesis kodu, e-posta ve parola zorunlu."** hatası veriyordu.

Kaynağa bakıldığında zincir netleşti:

| Katman | Ne gönderiyor / ne bekliyor | Durum |
|---|---|---|
| Form (`GirisFormu`) | `{kimlik, password}` (P205 tek alan) | **doğru** |
| BFF `app/api/auth/login/route.ts` | `{tenant_slug, email, password}` **zorunlu** | **KIRIK** |
| Backend `POST /auth/login` | `LoginRequest.kimlik`, slug opsiyonel, çok tesiste 409 | **doğru** |

Vekil `tenant_slug` boş olduğu için isteği **backend'e hiç göndermeden**
400 dönüyordu. Yani P205 arayüzü ve backend'i güncellemiş, **aradaki
vekili güncellememişti**; mobil aynı akışı doğrudan backend'e konuştuğu
için çalışıyordu.

**Neden testler görmedi:** mevcut giriş testleri taklidi
`/api/auth/login` **sınırında** kuruyordu — yani tam da bozuk olan
katmanın *yerine*. P200 dersi birebir tekrarladı: taklit, ölçülecek
katmanın **altına** konur.

### KARAR K1.1 — Vekil sözleşmesi `kimlik` + `password`
`tenant_slug` **opsiyonel**: girişte sorulmaz, yalnız kullanıcı tesis
seçtiğinde ikinci çağrıda dolar. Eski `email` alanı da kabul edilir
(eski istemci/testler kırılmasın), `kimlik`e düşürülür.

### KARAR K1.2 — Kod yolu telefonda **dürüstçe** reddedilir
Kod **e-posta ile** teslim ediliyor (SMS kapalı) ve backend
`EpostaKodIstek.eposta` bir `EmailStr`. Telefon yazıp "Kod ile giriş"e
basınca istek gidiyor ve biçimsel bir **422** dönüyordu. Artık istek
**atılmadan** sebep söyleniyor: *"Kod ile giriş e-posta adresiyle
çalışır."* (7 dil).

Telefonla kod istemek için sunucunun numarayı hesaba çözüp kodu o
hesabın **e-postasına** göndermesi gerekir — ayrı bir iş; bu turda
yapılmadı, uydurma bir yol da açılmadı.

### Ölçüm — neyi sürdüm
* Form gerçekten sürüldü (jsdom): telefon ve e-posta ile giriş, giden
  gövde ölçüldü → `{kimlik, password}`, **`tenant_slug` yok**.
* **Gerçek route handler** çalıştırıldı, taklit **backend çağrısında**:
  backend'e giden gövde `{kimlik, password}`; seçimden sonra
  `tenant_slug` de iletiliyor; boş kimlik/parola backend'e **hiç
  gitmiyor** (400).
* Kırma denemesi: vekile eski `tenant_slug` şartı geri konduğunda tam
  olarak 2 test düştü ("backend'e istek GITMEDI"), geri alınca 8'i geçti.
* Çok tesisli akış (409 → `tesislerim` → seçim) ve hata mesajlarının
  hesap varlığını sızdırmaması **zaten** P203/P205 testleriyle kilitli;
  ikisi de yeşil.

### Ölçemediğim
Gerçek `app.yonetiyor.com` üzerinden giriş — prod'a erişimim yok. Ölçülen
şey, istemcinin ve vekilin gerçek kodla ürettiği isteklerdir.

---

## §2 — Profil fotoğrafı: ne bozuktu, ne bozuk değildi

### ÖLÇÜM 1 — Sunucu ve istemci API katmanı **çalışıyor**
Dev API'ye **gerçek istekler** gönderdim (taklit yok):

```
POST /uploads/presign            -> 200  (upload_url: 192.168.20.101:9000)
PUT  <presigned>                 -> 200
PATCH /me/avatar {key}           -> 200
GET  /me                         -> avatar_url DOLU
PATCH /me/avatar {avatar_key:null} -> 200
GET  /me                         -> avatar_url null
```

Aynı zinciri **mobil `AvatarApi` sınıfıyla** da sürdüm (gerçek Dio, dev
MinIO): `PRESIGN OK → UPLOAD OK → SET AVATAR → KALDIR (null)`. Yani
"kaldırılamıyor/güncellenemiyor" şikâyetinin sebebi **bu katman değil**.

Yan ölçüm — presigned PUT'un iki tuzağı (ikisi de gerçek yanıt):
* gövde **chunked** gönderilirse MinIO **411 MissingContentLength**;
* **farklı `Content-Type`** ile PUT edilirse **403 SignatureDoesNotMatch**.
Mobil kod ikisini de doğru yapıyor (`Content-Length` set ediliyor, presign
ile PUT aynı tipi kullanıyor).

### ÖLÇÜM 2 — Ekran **hatayı yutuyordu** (gerçek kusur)
`myAvatarUrlProvider` şöyleydi: `catch (_) { return null; }`. Sonuç:
`GET /me` başarısız olduğunda ekran **fotoğrafı olmayan** bir kullanıcı
gibi davranıyor, **"Kaldır" düğmesini gizliyor** ve kullanıcıya **hiçbir
şey söylemiyordu**. "Kaldıramıyorum" şikâyetinin ekranda hiçbir izinin
olmamasının sebebi bu.

**KARAR K2.1 — "fotoğraf yok" ile "okuyamadım" ayrı durumlar.** Hata artık
yukarı çıkar; profil kartı mesaj + **"Tekrar dene"** gösterir, app-bar
sessizce baş harflere düşer (orası bir durum ekranı değil).

### ÖLÇÜM 3 — Mobilde baş harf yoktu (kabul kriteri 7)
Web'de karar **zaten verilmişti** (`components/Avatar.tsx`: baş harfler +
addan türeyen kararlı renk). Mobil ise herkese aynı gri silueti çiziyordu.

**KARAR K2.2 — `BasHarfAvatar` (mobil), web ile aynı kurallar:** en fazla
iki harf, tek kelimede ilk iki harf, addan türeyen **kararlı** renk.
Türkçe büyütme **elle**: Dart'ın `toUpperCase()`i locale tanımaz ve
"ismail" → "IS" verirdi; doğrusu "**İ**S".

### Web tarafı — kontrol edildi, kusur bulunmadı
Yükleme presign + **doğrudan** PUT + `PATCH {avatar_key}`; kaldırma
`PATCH {avatar_key: null}`; fotoğraf yokken **baş harfler**; "Kaldır"
düğmesi yalnız fotoğraf varken. Dördü de artık testli.

### Kilit
Mobil 7 test (baş harf kuralları, renk kararlılığı, fotoğraflı/fotoğrafsız
çizim, presign→PATCH gövdesi, kaldırmada `avatar_key: null`'ın gerçekten
gitmesi, hatanın yutulmaması) + web 4 test. Kırma denemesi: web'de
kaldırma gövdesi `{}` yapıldığında ilgili test düştü, geri alınca geçti.

### Ölçemediğim — ve senden istediğim
**Cihazdaki hatayı yeniden üretemedim**: telefon bende yok ve prod'a
istemci olarak bağlanamıyorum. Ölçebildiğim her katman (backend, depo,
istemci API sınıfı) dev'de çalışıyor. Şimdi ekran hatayı **gösterecek**;
cihazda tekrar denediğinde **ekranda çıkan mesajı** bana ilet — sessiz
başarısızlık kalmadığı için artık teşhis edilebilir olacak.
