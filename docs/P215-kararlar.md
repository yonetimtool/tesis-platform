# P215 — Canlı yayın: iki prod yapılandırma hatası

## Ölçülen durum

**1. Ağ.** Prod'da `mediamtx` ile `api` farklı docker ağlarında:

```
mediamtx → yonetio-prod_default
api      → yonetio-prod_tesisnet
```

İki ağ arasında DNS yok; `api` konteynerinde `mediamtx` adı çözülmedi
(`socket.gaierror`) ve **her** canlı yayın isteği 502 döndü.

**Kök neden — okundu, tahmin edilmedi:** `docker-compose.prod.yml`de 14
servisin **13'ü** `networks: [tesisnet]` taşıyor; `mediamtx`'te bu satır
**yazılmamış**. Docker, ağı belirtilmeyen servisi varsayılan ağa koyar.

**2. Port.** Bildirilen belirti "logda `:999`, api 9997 arıyor". Ölçtüm:
`infra/mediamtx.yml`'de `apiAddress: :9997` **doğru** ve dev'de log da
`:9997` diyor — yani **dosyada yazım hatası yok**. Ama gerçek bir kusur
vardı: **aynı ayar iki yerde tanımlıydı** — mount edilen dosyada ve
compose `environment` bloğunda (`MTX_APIADDRESS`) — ve env dosyayı
**eziyordu**. "Hangi değer geçerli" sorusu okunarak yanıtlanamıyordu; bir
ayrışma sessizce yaşayabilirdi. Belirsizliğin kendisi kusurdur.

## Kararlar

**Ağ:** `mediamtx` → `networks: [tesisnet]`. Diğer 13 servis zaten
doğruydu (tam liste çıkarıldı, tek eksik buydu).

**Port tek kaynaktan:** compose'daki `MTX_*` yinelemeleri **kaldırıldı**,
tek kaynak `infra/mediamtx.yml`. Dev'de de aynısı yapıldı — dev ile
prod'un aynı kaynağı kullanması, bir prod kusurunun dev'de görünmeme
olasılığını düşürür.

## Bu neden yakalanmadı — dürüst yanıt

P213 §2'de bulduğum kusur (MediaMTX API 401) **gerçekti** ve çözüldü. Ama
ölçtüğüm şey **zincirin kendisiydi, zincirin prod topolojisi değil**. Üç
ayrı boşluk:

1. **Dev'de bu kusurun ortaya çıkması mümkün değildi.**
   `docker-compose.yml` hiçbir servise ağ yazmaz — hepsi aynı varsayılan
   ağa düşer ve isim çözümü **her zaman** çalışır. Yani dev, prod
   topolojisinin bu yönünü hiç temsil etmiyordu.
2. **Hiçbir test `docker-compose.prod.yml`i okumuyordu.** Prod
   topolojisi dağıtımdan önce hiçbir yerde doğrulanmıyordu; ilk
   doğrulama canlı sistemdi.
3. **Testler `api` konteynerinin içinden koşuyor** ve orada mediamtx
   erişilebilir. "Geçit çalışıyor" sonucu dev topolojisi için doğruydu,
   prod için hiçbir şey söylemiyordu.

Bunu "test eksikliği" diye geçiştirmemek gerekiyor: P213 §2'de
**"çözüldü"** derken ölçtüğüm ortam, kusurun yaşadığı ortam değildi. Doğru
ifade "dev'de ölçüldü ve çözüldü; prod topolojisi ölçülmedi" olmalıydı.

## Kalıcı kilit

`backend/tests/test_p215_gecit_ag.py` — iki seviye:

**A. Yapısal** (makineden bağımsız, dağıtımdan önce):
- prod compose'daki **her** servis `tesisnet`'te mi — yeni bir servis
  eklenip ağı unutulursa düşer,
- `mediamtx` ile `api` özellikle aynı ağda mı,
- `mediamtx.yml`'deki port ile `MEDIAMTX_API_URL`/`MEDIAMTX_URL`
  içindeki port aynı mı (iki dosyada yazılı, ayrışmaları sessiz),
- compose'da dosyayı ezen `MTX_*` yinelemesi kalmamış mı.

**B. Çalışma zamanı:** api konteynerinden geçit API'sine gerçek istek —
ve başarısızsa **hangisinin** kırıldığını söyler: DNS çözülmüyorsa *ağ*,
bağlantı reddediliyorsa *port*, 401/403 ise *yetki*. Üçü de aynı belirtiyi
(502) üretiyordu; ayrımı test yapıyor.

Kilit, `networks: [tesisnet]` satırı silinerek doğrulandı:
`Prod'da AGI YAZILMAMIS servis(ler): mediamtx`.

Ayrıca `api` konteynerine `mediamtx.yml` salt-okunur mount edildi (sır
içermez); testin okuyacağı dosya bulunamazsa **sessizce atlanırdı** ve hep
atlayan bir test hiçbir şey korumaz.

## Hata ayrımı: kamera mı, sunucu mu

**Kusur:** kullanıcının gördüğü tek şey *"Yayın açılamadı. Adresi ve ağ
erişimini kontrol edin."* idi. Yönetici, **hiçbir sorunu olmayan**
kamerayı düzeltmeye çalıştı. Oysa backend tanılı bir mesaj **döndürüyordu**
— oynatıcı onu **hiç okumuyordu**: `hls.js`'in ölümcül hatasını sabit bir
metne çeviriyordu.

**Karar:** ayrım `code` ile, **metinle değil** (metne bakan kural dil
değişince sessizce kırılır):

| `code` | anlamı | kullanıcıya |
|---|---|---|
| `server_config` | sunucuda ağ/port/yapılandırma | "Kameranızda sorun yok, sistem yöneticisine bildirin" + **"kamera ayarlarını değiştirmeyin"** |
| `bad_gateway` | kameraya ulaşılamıyor | adres/kimlik/ağ izni kontrolü |

Oynatıcı ölümcül hatada playlist'i bir kez çekip sunucunun gövdesindeki
tanılı mesajı gösteriyor; teşhis denemesi başarısız olursa **sessizce**
genel metne düşüyor (teşhis, oynatmayı bozmamalı).

`kamera_gecit_yok` ve `kamera_gecit_yetkisiz` metinleri 7 dilde yeniden
yazıldı: artık *ne olduğunu* değil, **yöneticinin ne yapmayacağını** da
söylüyorlar.

**Ayrışma kilidi:** backend sabiti (`SUNUCU_YAPILANDIRMA = "server_config"`)
ile istemcideki küme aynı olmak zorunda; web testi backend kaynağını okuyup
karşılaştırıyor — ayrışırlarsa hiçbir şey patlamaz, yalnızca ayrım çalışmaz
olurdu.

## Ölçemediğim

Prod'a erişimim yok (bu makine yalnız dev). Ağ düzeltmesinin prod'da
çalıştığını **siz** doğrulayacaksınız; `docs/P215-dagitim.md` her adımı
beklenen çıktısıyla veriyor. Buradaki kilit, aynı hatanın bir daha
**dağıtıma kadar gizli kalmasını** engelliyor — prod'un şu anki durumunu
ölçmüyor.
