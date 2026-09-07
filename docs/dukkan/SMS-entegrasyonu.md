# DUKKAN — SMS (VERİMOR) ENTEGRASYONU

> Dört maddelik istek üzerine yazıldı. Her maddenin cevabı ve **neden öyle**
> yapıldığı burada.

---

## 0. Önce: paralel bir katman yazmadım

İlk yaklaşımım Dukkan'a ayrı bir `dukkan/sms.py` yazmaktı. **Yanlıştı** ve
yazdıktan sonra sildim.

`backend/app/mesajlasma.py`'de zaten çalışan bir soyutlama vardı: ana şalter,
tek seçim noktası, ve *"gönderildi demeyen"* bir kapalı sağlayıcı
(`KapaliSmsSaglayici`). O dosyanın başlığında şu söz yazılıydı:

> *"başkasına geçmek bu dosyaya **BİR SINIF** eklemek demek."*

Verimor tam olarak o sözü kullanıyor. Paralel bir katman iki yerde kimlik,
iki yerde ana şalter ve iki yerde hata eşlemesi demekti; biri gün gelip
ötekinden ayrışırdı. Üstelik Verimor hesabı **aynı hesap**.

---

## 1. Sağlayıcı soyutlaması

**Eklenen sınıflar** (`mesajlasma.py`):
- `VerimorSmsSaglayici` — `POST /v2/send.json`
- `KonsolSmsSaglayici` — geliştirme taşıyıcısı (§5)

**Seçim noktası:** `dukkan_sms_saglayicisi()` — `DUKKAN_SMS_SAGLAYICI` okur.

### Neden Yönetiyor'un `sms_aktif` şalterinden ayrı

Yönetiyor'da SMS **ürün genelinde kapalı** ve bu bir karar: telefon orada
yalnız iletişim bilgisi, doğrulama e-posta koduyla yapılıyor.

Dukkan'da durum **tersi**: telefon **kimliğin çapası** — e-posta bir kişiyi
tekilleştiremez (`uq_app_user_tenant_email` yalnız tesis içinde benzersiz).
SMS olmadan Dukkan kimliği çalışmaz.

İki ürünün bu konudaki kararı gerçekten farklı, dolayısıyla şalter de ayrı.
**Sağlayıcı sınıfları paylaşılıyor** — ayrışan şey karar, kod değil.

### Sağlayıcı değiştirmek

`mesajlasma.py`'ye bir sınıf, `dukkan_sms_saglayicisi()`'ne bir `if`.
Çağıran kod (`kimlik.py`, uçlar) **değişmez** — hangi sağlayıcı olduğunu
bilmiyor.

### Ölçülen ayrıntılar

| Ayrıntı | Neden önemli |
|---|---|
| Numara `905XXXXXXXXX` (`+` yok) | `+90…` göndermek numarayı geçersiz kılar; sağlayıcı 200 dönebileceği için bu **sessiz** bir başarısızlık olurdu |
| Başarılı yanıt **düz metin** (kampanya no) | `yanit.json()` çağırmak patlardı: gönderilmiş SMS "başarısız" sayılırdı |
| Ağ hatasında yalnız **sınıf adı** loglanır | Hata mesajı URL ve kimlik içerebilir (P134) |

Taklit **HTTP katmanına** konuyor (`httpx.post` monkeypatch), sağlayıcı
sınıfına değil — sınıfı taklit etmek gövde kurulumunu, alan adlarını ve
numara biçimini **atlardı** (P198/P200 dersi).

---

## 2. Çelişki giderildi — bildirdiğin kusur

**Eski:** `{"gonderildi": true, "gonderim": "saglayici_bagli_degil"}`
İki alan birbiriyle çelişiyordu. Haklıydın: tam da "sessiz başarısızlık"
sınıfı, üstelik onu engellemek için yazılmış bir alanın içinde.

**Yeni:** `gonderildi` **yalnızca** sağlayıcı mesajı kabul ettiyse `true`.
Bir test bunu kalıcı kılıyor:

```python
assert d["gonderildi"] is (d["gonderim"] == "gonderildi")
```

**Ve dahası: gönderilemezse uç 200 dönmüyor, 503 dönüyor.**
200 + `gonderildi: false` istemciyi "başarılı yanıt geldi" dalına sokar ve
kullanıcıya **gelmeyecek** bir kodun bekleme ekranını gösterirdi. Durum kodu,
istemcinin okumak zorunda **olduğu** tek sinyal.

Giriş ekranında bunun somut karşılığı: 503'te `api()` hata fırlatıyor, yani
`setAdim("kod")` **hiç çalışmıyor**. Kullanıcı kod ekranını görmüyor.

---

## 3. Gönderim başarısız olursa kullanıcı ne görüyor

Üç durum **ayrı**, çünkü kullanıcının yapacağı şey farklı:

| Kod | Kullanıcı ne görüyor | Neden ayrı |
|---|---|---|
| `sms_baslik_yok` | *"SMS gönderimi henüz açılmadı. Onay sürecimiz sürüyor; bu arada bize ulaşarak hesabınızı açtırabilirsiniz."* | Beklemekten başka yapacağı yok → **alternatif kanal** sunuluyor |
| `sms_basarisiz` | *"Kod gönderilemedi. Birkaç dakika sonra tekrar deneyin."* | Geçici → tekrar denemek **mantıklı** |
| `sms_saglayici_yok` | *"SMS servisi şu anda kullanılamıyor. Lütfen bizimle iletişime geçin."* | Yapılandırma eksik → tekrar denemek **işe yaramaz** |

Üçünü tek "bir hata oluştu"ya indirmek, başlık onayı beklerken gelen her
kullanıcıyı sonsuz tekrar denemeye iterdi.

**Başarısız gönderim hız sınırını yemiyor.** Saatlik sınır (numara başına 5)
artık yalnız `gonderim_durumu='gonderildi'` satırlarını sayıyor. Sağlayıcı
kesintisinde kullanıcı beş kez deneyip **hiçbirini alamadan** bir saatliğine
kilitlenmemeli — kendi hatası olmayan bir şey yüzünden. Başarısız deneme
kayıtta **duruyor** (teşhis için), kotayı tüketmiyor.

---

## 4. `DUKKAN_OTP_YANITTA` sızmasını imkânsız kılan kilit

Sorduğun buydu ve cevabı: **evet, artık var — ve yapısal.**

Kod yanıtta **ancak iki koşul birden** doğruysa dönüyor:

```python
if settings.dukkan_otp_yanitta and not gercek_saglayici:
    yanit["dev_kod"] = kod
```

Prod'da Verimor yapılandırılı olduğu için **ikinci koşul yapısal olarak
tutmaz**. Ayar yanlışlıkla açılsa bile kod sızmaz.

> Bir yapılandırma hatasının **tek başına yeterli olmaması**, savunmanın
> kendisidir. "Ayar prod'da kapalı olmalı" diye *beklemek* değil.

**Davranışsal olarak ölçüldü** — kaynak taraması değil, gerçek koşum:
konteyner `DUKKAN_SMS_SAGLAYICI=verimor` **ve** `DUKKAN_OTP_YANITTA=true`
ile kaldırıldı (ayar kasıtlı açık):

```
DURUM: 503
GOVDE: {"error":{"code":"error","message":"sms_baslik_yok"}}
dev_kod SIZDI MI: HAYIR
```

**Üç katmanlı savunma:**

1. **Yapısal** (yukarıdaki koşul) — asıl kilit.
2. **Yapılandırma driftine karşı test:** `docker-compose.prod.yml` bu
   değişkeni **hiç tanımlamamalı** — en olası sızma yolu dev compose'undan
   kopyalanan bir satır.
3. **Konsol taşıyıcısı prod'da yasak:** o taşıyıcı kodu **günlüğe** yazıyor;
   prod'da seçilirse doğrulama kodları konteyner günlüklerine dökülürdü.
   Ayrı bir test bunu da kilitliyor.

---

## 5. Geliştirme taşıyıcısı — ve neden gerekliydi

"Gönderilemezse 503" kuralı doğru, ama bir yan etkisi vardı: dev'de hiçbir
SMS geçidi yok, dolayısıyla telefonla giriş ve işletme telefonu doğrulama
akışları dev'de **hiç çalıştırılamaz** hale gelirdi.

`KapaliSmsSaglayici` bu işi göremez — o `yapilandirilmadi` döner ve
"gönderildi" **demez** (doğrusu da budur). Gereken şey mesajı **gerçekten
teslim eden** bir taşıyıcı.

`KonsolSmsSaglayici` mesajı konsola teslim ediyor. `gonderildi: true`
**dürüst**: mesaj gerçekten teslim edildi. Bu, ev deseninin kopyası —
`KonsolEpostaSaglayici` P196'da birebir aynı gerekçeyle yazılmış.

---

## 6. Prod yapılandırması

### Şimdi (başlık onayı beklerken)

```
DUKKAN_SMS_SAGLAYICI=verimor
SMS_KULLANICI=<verimor kullanıcı adı — 12 haneli telefon>
SMS_PAROLA=<verimor API parolası>
SMS_BASLIK=                     # BOŞ BIRAK
```

Bu hâlde uç **503 `sms_baslik_yok`** dönüyor ve Verimor'a **hiç istek
atılmıyor** — onaysız başlıkla denemek yalnız günlüğü kirletir ve
kullanıcıya *"başarısız"* der; oysa gerçek durum farklı.

### Onay geldiğinde

**Tek satır**, kod değişikliği yok:

```
SMS_BASLIK=<onaylı başlık>
```

Sonra `up -d --force-recreate api worker beat` (`restart` env tazelemez —
P215'te ölçüldü).

### Doğrulama

```bash
# Başlık ONAYSIZ iken -> 503 sms_baslik_yok
curl -s -X POST https://api.yonetiyor.com/dukkan/auth/telefon/kod \
  -H 'content-type: application/json' -d '{"telefon":"+905551112233"}'

# Her koşulda: dev_kod OLMAMALI
```

`dev_kod` görürsen **dur ve bildir**.

---

## 7. Açık madde

**Verimor kimlik bilgileri Yönetiyor ile paylaşılıyor** (`SMS_KULLANICI` /
`SMS_PAROLA`). Aynı hesap olduğu için doğru; ama Yönetiyor bir gün SMS'i
açarsa iki ürün **aynı krediyi** harcar ve kontör tükenmesi ikisini birden
durdurur.

Bugün Yönetiyor'da `SMS_AKTIF=false` olduğu için sorun yok. Yönetiyor SMS'i
açıldığında kredi izleme veya ayrı alt hesap düşünülmeli — **bu bir uyarı,
bugün için bir eksik değil.**
