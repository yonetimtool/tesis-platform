# P172 — E-posta sağlayıcısı (Resend) ve e-posta kanalı (rapor)

> Kurulum: Resend SMTP · `smtp.resend.com:587` (STARTTLS) · kullanıcı
> `resend` · şifre = API anahtarı · gönderen `noreply@yonetio.site`.
> Port 25 ISP'de kapalı; 587'den Resend'e veriliyor, dışarı iletmeyi Resend
> yapıyor. Gelen mail yok ve gerekmiyor.

**Önce ölçtüm.** Brief'in yedi maddesinden **üçü zaten kuruluydu** (§3
ayarlar ekranı, §4 test gönderimi, §7 hata sebebi — P168 §4). §6 davet
altyapısı da P155'te kurulmuştu. Yeni iş, kalan boşluklar ve ölçerken
çıkan **üç gerçek kusur** oldu.

---

## 1. Öncelik sırası — tanımlıydı, ama **yanlış çalışıyordu**

**Kural (netleştirildi):** tesis kendi ayarını girmişse o, girmemişse
`.env`deki genel ayar. `MesajYapilandirma` modelinde de böyle yazılıydı.

**Kusur:** karar **kayıt başına** veriliyordu, kanal başına değil:

```python
if ayar is not None and (ayar.sms_saglayici or ayar.smtp_host):
    return ayar          # <-- KAYDIN TAMAMI
```

Yani tesis **yalnız SMS'ini** girdiyse, aynı kayıt e-posta için de
"tesisin ayarı" sayılıyor ve `smtp_host` boş olduğu için e-posta **LOG'a
düşüyordu — `.env`de çalışan bir SMTP dururken.**

Bu, bu kurulumda somut bir arıza: Resend genel ayar olarak duruyor; kendi
SMS bayiliğini giren **ilk tesis**, e-posta gönderimini sessizce
kaybederdi. "Sessizce", çünkü LOG sağlayıcısı `yapilandirilmadi` döner ve
kimse `.env`de çalışan bir SMTP olduğunu bilmez.

**Düzeltildi:** her kanal kendi ayarına bakıyor. Tesis SMS'ini girdiyse
SMS tesisin, SMTP'sini girmediyse e-posta `.env`in. Her iki yön de testli.

### Aynı sınıfın iki örneği daha (ölçerken çıktı)

`tenant_ayari` **`routers/mesajlar.py` içindeydi**, yani gönderim yapan
öteki yollar onu çağıramıyordu (çekirdek bir modülün router ithal etmesi
ters bağımlılıktır). Sonucu:

* **Davetler** (`app/davet.py`) sağlayıcıyı **ayarsız** seçiyordu.
* **Mesaj kuyruğu** (`app/mesaj_kuyruk.py`) — başarısız gönderimlerin
  yeniden denenmesi — de **ayarsız**.

Yani kendi SMTP'sini giren bir tesiste ilk deneme doğru hesaptan,
**yeniden deneme başka hesaptan** çıkardı; davetler ise hep genel
hesaptan. Hiçbiri hiçbir yerde görünmezdi.

`tenant_ayari` `app/gonderim.py`e taşındı ve üç yol da ona bağlandı.

---

## 2. Compose — `.env`e yazmak gerçekten yetmiyordu

Ölçüm: `docker-compose.yml`de **hiç** SMS/SMTP değişkeni yok;
`docker-compose.prod.yml`de yalnız `api`de ve yalnız **SMS** var.

Daha kötüsü: **`worker` hiçbirini almıyordu.** Oysa `mesaj_kuyrugu` görevi
başarısız gönderimleri yeniden dener ve `kanal_saglayicisi(...)` çağırır —
yani toplu gönderimin yeniden deneme yolu sağlayıcısız kalıyor, sessizce
LOG'a düşüyordu: panelde "yeniden denendi" görünür, kimseye bir şey
gitmezdi.

**Eklendi:** `SMTP_HOST/PORT/USER/PASSWORD/FROM` + `SMS_*`, **hem `api`
hem `worker`**, **hem dev hem prod** compose'unda. Hepsi `:-` ile
opsiyonel — eksik değişken compose'u kırmaz (OAuth'ta `:?` kullanılıp
yığın açılmamıştı; tekrarlanmadı). `beat` yalnız zamanlar, göndermez;
bilerek dışarıda.

---

## 3–4. Ayarlar ekranı ve test gönderimi — **zaten vardı**

`components/mesaj/ayarlar-sekmesi.tsx` (P168 §4.4): SMTP host/port/kullanıcı
/parola/gönderen alanları, kota, ve test gönderimi düğmesi.

**Sırlar maskeli:** uç parolayı geri döndürmüyor, yalnız `smtp_parola_var`
boole bayrağı gidiyor. Model belgesinde gerekçesi yazılı — sırlar
sağlayıcıya aynen gönderilmek zorunda, yani geri dönüşü olmayan bir özet
işe yaramaz; koruma katmanı veritabanı erişimi (RLS + `app_rw`) ve arayüz
değerleri **hiç görmüyor**.

**Test gönderimi gerçekten gönderiyor:** "ayarlar dolu mu" diye bakmak
yanlış parolayı ya da yanlış başlığı yakalamaz. Sonuç ekranda (durum +
sağlayıcı + hata sebebi) ve **geçmişe yazılmıyor** — test bir bildirim
değil; "kime ne gönderdik" defterini kirletirdi. İkisi de testle kilitli.

---

## 5. E-posta OTP — mevcut altyapı, yeni kimlik

Ayrı bir sistem kurulmadı. `kayit_dogrulama` zaten kodun dört korumasını
taşıyor: kod düz metin tutulmaz (bcrypt), süreli, deneme sayacı **ayrı
oturumda** kalıcılaştırılır ve `amac` ayrımı "giriş kodu hesap silmeyi
onaylayamaz" kuralını yapısal olarak uygular. İkinci bir tablo, bu dördünü
ikinci kez — ve bir gün eksik — yazmak olurdu.

**Göç 0067:** `telefon` NULL'a açıldı, `eposta` kolonu eklendi ve yerine
bir CHECK geldi (ikisinden biri dolu olmalı). Süre, deneme sınırı ve hız
sınırı **SMS'tekiyle aynı** — aynı sabitlerden geliyor.

**Tesis kodu zorunlu** ve bu telefon yolundan farklı: telefon platform
genelinde benzersizdir (tesis ondan çözülür), e-posta ise **tenant içinde**
benzersiz. Tesis kodu olmadan aynı adresi kullanan iki tesis birbirine
karışırdı — testle kilitli.

Bu ayrımın güzel bir sonucu var: telefon satırlarının ezilmesi
`SECURITY DEFINER` bir fonksiyon gerektiriyordu (RLS altında başka
tenant'ın satırı görülemez); e-posta satırları tenant içinde kaldığı için
düz `DELETE` yetiyor. **Daha az yetki, daha az yüzey.**

Uçlar: `POST /auth/giris/eposta-kod-iste` ve `.../eposta-kod-dogrula`.
Adres varlığını sızdırmıyor (kayıtsız adres ve bilinmeyen tesis kodu için
de **aynı** yanıt), kod tüketiliyor, görev süresi dışındaki denetçi token
almıyor (parolalı ve telefonlu yollarla aynı kural).

**Panel arayüzü de eklendi.** Backend'de duran ama hiçbir istemcinin
çağıramadığı bir yetenek "gönderilebilsin" sayılmaz. Yol **yalnız e-posta
yüzeyinde** (`panel.*`): `app.*` telefonla girer ve orada kod yolu mobil
uygulamada zaten var. Kod alanı `autocomplete="one-time-code"` taşıyor —
bu olmadan iOS/Android gelen koddan okuyup önermez.

---

## 6. Davet linki — vardı, **iki kusuru düzeltildi**

`Davet` modeli (P155): tek kullanımlık (`used_at`), süreli
(`son_gecerlilik`), jeton **düz metin değil** (sha256 özeti saklanır, düz
jeton yalnız bağda ve bir kez üretilir). Gövde SMS ve e-posta için
**ortak** ve **tesis kodunu taşıyor** — SMS kanalı açıldığında aynı şablon
oradan gidecek. Dördü de testle kilitli.

**Kusur 1 — sağlayıcı ayarsız seçiliyordu** (yukarıda, §1).

**Kusur 2 — panel özeti SMS'e sabitlenmişti:**

```python
davet.son_kanal = "sms"      # her zaman
return sms.durum != "basarisiz"
```

Bu, "SMS asıl kanaldır" varsayımına dayanıyordu. **Bugün o varsayım
yanlış:** SMS geçidi yapılandırılmadı, e-posta çalışıyor. Eski kodla panel
**her daveti "gitmedi" gösterirdi — davet e-postayla ulaşmışken.**

Artık başarılı olan kanal yazılıyor; ikisi de başarısızsa denenen kanalın
sebebi yazılıyor ki teşhis kaybolmasın. Dönüş değeri de "herhangi bir
kanaldan ulaştı mı" oldu.

---

## 7. Hata sebebi — vardı, bir yanlış varsayım düzeltildi

Gönderim geçmişi `hata` alanını taşıyor ve panel gösteriyor.
`yapilandirilmadi` ayrı bir durum ve **"başarısız" değil**: başarısızlık
"denedik, olmadı" der ve kullanıcıyı "tekrar dene"ye iter; burada hiç
denenmedi, yapılması gereken ayarları doldurmaktır.

Ama bir yer bu ayrımı **yutuyordu**: davet dönüşü `durum != "basarisiz"`
diyordu, yani `yapilandirilmadi`yi **başarı** sayıyordu. Bir test de bu
yanlış gerçeği sabitliyordu (`gonderildi is True`). İkisi de düzeltildi —
brief'in açıkça yasakladığı şey buydu: *"sessizce gönderildi demesin"*.

SMTP hata sebebi sağlayıcıdan geldiği gibi kaydediliyor (bağlantı hatası,
kimlik doğrulama reddi, geçersiz adres, kota). Resend'in reddettiği bir
adres ya da aşılan kota bu alanda görünür.

---

## Testler

| Yer | Kapsam |
|---|---|
| `backend/tests/test_eposta_kanali.py` (15) | öncelik sırası **dört yön** (yok/tam/yalnız-SMS/yalnız-SMTP), yapılandırma yokken `yapilandirilmadi` + sebep, testin geçmişe yazılmadığı, OTP'nin adres sızdırmadığı · aynı tablo/hash/süre · yanlış kod · doğru kodda oturum · kodun tükenmesi · **tesis sınırını geçmediği**, davet jetonunun tek kullanımlık ve süreli olduğu, tesis kodunu taşıdığı, şablonun ortak olduğu, yapılandırma yokken `gonderildi=False` |
| `admin-web/tests/eposta-kod-girisi.dom.test.ts` (5) | yolun yalnız `panel.*`ta görünmesi, kod adımına geçiş, sızdırmayan mesaj, `one-time-code`, sunucunun hata metni, parolaya dönüş |

Güncellenen **üç** kilit, üçü de bilinçli: `test_davet.py` yapılandırma
yokken `True` bekliyordu (P168 sonrası yanlış kalmış bir gerçek);
`test_mesaj_kuyrugu.py` sahte sağlayıcısı tek argüman alıyordu (kuyruk
artık tesis ayarını geçiriyor); `test_denetci_salt_okuma.py` **rol kapısı
olmayan mutasyon uçlarının beklenen kümesini** tutuyor — iki yeni
kimlik-öncesi uç oraya gerekçesiyle eklendi (kişi henüz oturum açmamıştır,
rol kapısı olamaz; kötüye kullanım yüzeyi hız sınırıyla kapatılır ve uç
adres varlığını sızdırmaz).

Ayrıca `backend/tests/yetki/rol-matrisi.txt` **üretildi** (elle
yazılmadı) — üretim aynı zamanda doğrulamadır: iki yeni uç gerçekten
yedi rolün hepsine açık, yani kimlik öncesi.

---

## Test sunucusunda ne kontrol edeceksin

1. `.env.prod`a Resend değerlerini yaz, sonra **kanonik komutla** dağıt:
   `docker compose build migrate api admin-web worker` (kısmi build
   yapma — P171).
2. `SMS/E-Posta Yönetimi → Ayarlar` → **Test gönderimi**: kanal `eposta`,
   kendi adresin. Sonuç ekranda `gonderildi` olmalı; olmuyorsa hata sebebi
   yazacak.
3. Bir sakin ekle: davet e-postası gelmeli, içinde **tesis kodu** ve
   bağlantı olmalı. Panelde davet satırı `eposta` kanalıyla `gonderildi`
   görünmeli (eskiden `sms` / gitmedi görünürdü).
4. `panel.*` giriş ekranı → **"Parola yerine e-postaya kod gönder"** →
   gelen kodla gir. Kod 10 dk geçerli, ikinci kullanımda reddedilmeli.
5. Ayarlar ekranını yeniden aç: **parola alanı boş** gelmeli (kaydedilmiş
   sır arayüze dönmez), "kayıtlı" bilgisi ayrı bir bayrakla görünür.
