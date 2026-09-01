# P201 — Google yönetici kaydı döngüsü: kök neden YAPILANDIRMADA

**Tarih:** 2026-09-01 · **Kapsam:** admin-web · backend (ölçülebilirlik) · örnek yapılandırma + doküman

P198'de kod düzeltildi ve düzeltme **doğruydu**. Prod'da tutmadı çünkü
kırık olan yer kod değildi.

---

## K1 — Kök neden: `OAUTH_KAYIT_DONUS` yanlış sayfayı gösteriyor

Callback şuraya 303 atar: `<OAUTH_KAYIT_DONUS>?oauth=<sonuc_id>`.

`?oauth=` parametresini çözen (yani `POST /auth/oauth/sonuc`'u çağıran)
**tek sayfa `/giris/oauth`**tur. Çözdükten sonra kullanıcıyı zaten
`/kayit`a bırakır. `/kayit` ise parametreyi **okumaz** — sonucu
`sessionStorage`dan bekler.

`OAUTH_KAYIT_DONUS` `.../kayit` ise sonuç kimliği **hiçbir yerde
tüketilmez**: sayfa bomboş açılır, kullanıcı kayda baştan başlar.

**Depodaki `.env.prod.example` operatöre tam olarak bu yanlış değeri
öneriyordu** (satır 151):

```
# OAUTH_KAYIT_DONUS=https://app.yonetiyor.com/kayit
```

### Prod izi bunu birebir doğruluyor

```
POST /auth/oauth/baslat/google        200
GET  /auth/oauth/callback/google...   303
GET  /auth/oauth/saglayicilar         200   ← sayfa BAŞTAN yüklendi
```

Arada **`POST /auth/oauth/sonuc` yok**. `/giris/oauth` bu ucu *her
zaman* çağırır — dolayısıyla 303 oraya gitmedi.

### Ölçüm (prod biçimli yapılandırmayla, api konteynerinde)

```
A) .env.prod.example'in önerdiği değerle
   OAUTH_KAYIT_DONUS = 'https://app.yonetiyor.com/kayit'
   niyet=kayit  -> Location: https://app.yonetiyor.com/kayit?oauth=SONUC123     ← ÇIKMAZ
   niyet=giris  -> Location: https://app.yonetiyor.com/giris/oauth?oauth=SONUC123

B) düzeltilmiş değerle
   niyet=kayit  -> Location: https://app.yonetiyor.com/giris/oauth?oauth=SONUC123
```

## K2 — niyet=kayit PROD'DA DOĞRU GİDİYOR (P198 fix'i çalışıyor)

Bunu logun kendisi kanıtlıyor, ek ölçüme gerek yok:

* niyet **giris** olsaydı backend `OAUTH_WEB_DONUS`u kullanırdı
  (= `.../giris/oauth`), o sayfa da **mutlaka** `POST /auth/oauth/sonuc`
  çağırırdı.
* Logda o çağrı **yok**.
* Demek ki backend `OAUTH_KAYIT_DONUS`u kullandı → **niyet=kayit
  sunucuya doğru ulaşmış.**

P198 düzeltmesi yerinde duruyor; kırık olan onun **indiği yer**di.

## K3 — Kod artık yanlış yapılandırmaya DAYANIKLI

Yanlış bir ortam değişkeninin cezası "kullanıcı kaydolamaz" olmamalı.
İki sertleştirme yapıldı:

1. **`/kayit`, `?oauth=` ile açılırsa `/giris/oauth`a devreder.** Sonucu
   ikinci kez çözmek yerine devretmek seçildi: dört durumu
   (`kayit` / `mevcut_hesap` / `baglama_gerekli` / `giris`) o sayfa
   zaten doğru ele alıyor ve mantığı kopyalamak, biri değişince
   ötekinin eskimesi demekti.

2. **Niyet artık sunucudan da okunuyor.** `/giris/oauth` niyeti yalnız
   `sessionStorage`dan okuyordu; `sessionStorage` **köken başınadır**.
   Dönüş başka konağa düşerse (ya da kullanıcı sekme değiştirirse)
   değer kaybolur, kayıt niyeti giriş sanılır ve kullanıcıya **Tesis ID
   sorulur** — bildirilen belirtinin ikinci üretim yolu tam olarak
   budur. Sunucu niyeti zaten biliyor ve `durum` alanında geri
   yolluyor; karar artık yanıttan veriliyor.

Böylece **iki değer de çalışır**, ama doğru olanı `/giris/oauth`tur ve
örnek dosyalar düzeltildi.

## K4 — Testler bunu neden yakalamadı

P198'in uçtan uca testi `/kayit` sayfasını sürüyor ama **tarayıcının
sağlayıcıdan nasıl döndüğünü varsayıyor**: sonucun `sessionStorage`da
hazır olduğunu kabul ediyor. Ölçmediği şey, akışın kod ile
**yapılandırma** arasındaki dikişi.

Daha sert bir gerçek: **dev bu akışı ölçemezdi.** Ölçüldü —

```
POST /auth/oauth/baslat/google {"niyet":"kayit"} -> 503
service_unavailable: "Bu sosyal giriş yöntemi şu anda kullanılamıyor."
```

Dev'de `OAUTH_KAYIT_DONUS` **boş**, yani SSO kaydı geliştirmede hiç
çalışmıyor. "Geliştirmede ölçtüm" iki turdur bu yüzden yetmedi.

## K5 — Eklenen kilitler

| Kilit | Ölçtüğü |
|---|---|
| `p201-oauth-donus-adresi.test.ts` | Örnek yapılandırmalardaki **her** `OAUTH_*_DONUS` değeri, `?oauth=`i gerçekten tüketen bir sayfaya bakmalı |
| aynı dosya | `OAUTH_KAYIT_DONUS` örneklerde **tanımlı** olmalı (eksikse SSO kaydı 503) |
| `p201-kayit-donus-akisi.dom.test.ts` | `/kayit?oauth=` devreder · niyet yerel kopyada yokken de kayıt dalı · kayıt niyetinde **Tesis ID sorulmaz** · giriş dalı bozulmadı |
| `test_p201_oauth_donus_adresi.py` | Location'ın kurulumu (ayraç dahil), niyet→adres eşlemesi, ve **dev'de akışın kapalı olduğunun kaydı** |

`_donus_url` bu tur ayrı bir fonksiyona çıkarıldı: prod'da kırılan şey
tam olarak bu adresti ve satır arasında olduğu için ölçülemiyordu.

## Kilit kanıtı — dört bozma, dördü de doğru testten düştü

| Bozma | Düşen test |
|---|---|
| Dönüş adresi tüketmeyen bir yola (`/giris`) ayarlandı | ÖRNEK YAPILANDIRMALARDAKİ... |
| Örnekten `OAUTH_KAYIT_DONUS` satırı silindi | KAYIT DÖNÜŞÜ ÖRNEKLERDE TANIMLI |
| `/kayit` devretmeyi bıraktı (prod'daki hâli) | `/kayit ?oauth=` DEVREDER |
| Niyet yalnız `sessionStorage`dan okundu (eski hâli) | NİYET YEREL KOPYADA YOKKEN + TESİS ID FORMU ÇIKMAZ |

Hepsi geri alındı.

---

## Dağıtımda yapılacak — ÖNEMLİ

`infra/.env.prod` dosyasında:

```env
OAUTH_KAYIT_DONUS=https://app.yonetiyor.com/giris/oauth
```

Sonra `api` yeniden kurulmalı. Kod düzeltmesi (`admin-web`) yanlış
değerle de çalışır, ama doğru değer bir yönlendirme atlatır.

## Ölçemediğim

* **Prod'a erişimim yok** (dev makineden yalnız 80/443). Yukarıdaki
  Location ölçümü, prod *biçimli* yapılandırmayla **dev api
  konteynerinde** yapıldı; prod sunucusunda değil.
* **`.env.prod`un gerçek içeriğini görmedim** — istekte yer tutucu
  (`[Location başlığını ve .env.prod çıktısını buraya ekle]`) boş
  kalmıştı. Kök neden log dizisinden çıkarıldı ve yeniden üretildi;
  yine de şu iki değeri görmek teşhisi **kanıta** çevirir:
  `OAUTH_KAYIT_DONUS` ve `OAUTH_WEB_DONUS`, bir de 303'ün `Location`
  başlığı.
* **Gerçek Google oturumuyla uçtan uca deneme** yapılmadı; sağlayıcı
  takası taklit edilemez.
