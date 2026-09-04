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
