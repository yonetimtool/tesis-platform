# P173 — E-posta ayarları ekranı çalışmıyordu (rapor)

> Belirti: `GET mesaj-ayarlari` → **404** (×3), `test` → **405** (×2).
> Sunucu log'unda traceback yok. Ekran çizili, alanlar boş, Kaydet
> kaydetmiyor, rozet "yapılandırılmadı" diyor.

---

## 1. Frontend ne çağırıyor, backend'de karşılığı ne

| Arayüz | BFF'te | Backend | Sonuç |
|---|---|---|---|
| `GET /api/panel/mesaj-ayarlari` | beyaz listede **YOK** | `GET /mesaj-ayarlari` **VAR** | vekilin kendi **404**'ü |
| `PUT /api/panel/mesaj-ayarlari` | `PUT` işleyicisi **YOK** | `PUT /mesaj-ayarlari` **VAR** | Next **405** |
| `POST /api/panel/mesaj-ayarlari/test` | rota **YOK** | `POST /mesaj-ayarlari/test` **VAR** | Next **405** |

**Backend'de üçü de vardı** (P168'den beri). Eksik olan **BFF vekiliydi**.

Bu, log'da iz olmamasını da açıklıyor: beyaz listede olmayan bir ad için
vekil kendi 404'ünü döner ve istek **sunucuya hiç gitmez**; tanımsız bir
metot için de Next 405 üretir ve uç gövdesi hiç çalışmaz. Senin teşhisin
("yönlendirme katmanında reddediliyor") birebir doğruydu.

**Düzeltildi:**
* `lib/panel-vekil.ts` → `mesaj-ayarlari` hem OKUMA hem YAZMA listesinde.
* `app/api/panel/[kaynak]/route.ts` → **`PUT` işleyicisi** eklendi. Vekil
  metodu **değiştirmiyor**: backend'de uç gerçekten `PUT`; değiştirseydik
  sözleşme ile gerçeklik ayrışırdı.
* `app/api/panel/mesaj-ayarlari/test/route.ts` → kendi rotası. `[kaynak]/[id]`
  kullanmak yanlış olurdu: "test" bir **kimlik değil, eylem**; oraya POST
  eklemek her kaynağın her kimliğine POST atılabilen genel bir kapı açardı.

---

## 2–3. Sözleşme

`contracts/openapi.yaml`da üçü de tanımlıydı — yani sözleşme **doğruydu**,
uygulayan katman eksikti. Yeni uç yazmak gerekmedi; yazılan tek şey vekil
rotalarıydı.

---

## 4. Rozet mantığı

Rozet `sms_hazir` / `eposta_hazir` alanlarını okuyor ve bunlar **gerçek
sağlayıcı seçim fonksiyonundan** türetiliyor — yani P172'deki kanal başına
`.env` yedeğini **zaten görüyor**. `.env`de SMTP tanımlıyken rozet "hazır"
diyecek. (Bugün "yapılandırılmadı" demesinin sebebi rozet mantığı değil,
GET'in 404 alması ve `data`nın hiç gelmemesiydi.)

Ama ortada gerçek bir okunabilirlik kusuru vardı: **alanlar boş görünürken
rozet "hazır" diyor.** Kullanıcı haklı olarak "ben bir şey girmedim, nasıl
hazır?" diye sorup ayarları yeniden girmeye kalkışıyor. Sebep doğru ama
görünmüyordu.

**Eklendi:** `sms_kaynak` / `eposta_kaynak` = `tesis` | `genel` | `yok`.
Rozet artık **"hazır (genel ayar)"** diyor; boş alanlar böylece tutarlı
görünüyor. Ölçüt `_ayardan_veya_env` ile **aynı** — farklı bir ölçüt
yazmak, rozetle gerçek seçimin bir gün ayrışması demekti.

Kural `ayar_kaynagi()` olarak **modül düzeyinde ve saf** yazıldı: bir
kapanışın içinde saklıyken yalnızca HTTP üzerinden ölçülebiliyordu ve
testler **canlı sunucuya** gittiği için `.env` dalı test sürecinden
`monkeypatch` ile sürülemiyordu.

---

## 5. Gövdesiz yanıtta anlamlı mesaj

Yazma yolu (`apiSend`) bunu P163'te çözmüştü (durum kodu + referans).
**Okuma yolu (`jsonFetcher`) çözmemişti**: gövde yoksa "Bir hata oluştu"
diyordu — ekranın "sessizce boş kalması" buydu.

Artık 404 ve 405 gövdesiz geldiğinde ne olduğunu söylüyor: *panel ile
sunucu sürümleri ayrışmış olabilir, sistem yöneticisine bildirin*. "Tekrar
dene" **demiyor**, çünkü tekrar denemek işe yaramaz.

---

## 6. Kapı — sınıfı kapatmak

`admin-web/tests/uc-sozlesme-kapisi.test.ts`. Dört ölçüm:

1. **Beyaz liste ↔ sözleşme:** her OKUMA yolu sözleşmede `GET`, her YAZMA
   yolu bir yazma metoduyla tanımlı mı.
2. **Vekil çağrıları:** `app/api/**/route.ts` içindeki her sabit
   `proxyJson`/`proxyBinary` yolu + metodu sözleşmede var mı.
3. **Arayüz → beyaz liste:** `/api/panel/<ad>` çağrılarının hepsi listede
   mi. **Bu turun kusurunun tam kendisi.**
4. **Arayüz metodu → sözleşme metodu:** `apiSend(url, "METOT")` ve
   `useSWR(url)` çağrıları, eşlenen backend yolunda o metotla tanımlı mı.
   **P168'in kusurunun tam kendisi.**

**Neden (4) ayrıca gerekli:** genel vekilde yol bir **değişkendir**, sabit
değil; (2) yalnız sabitleri görür. Deney yapıldı — vekilin `PUT` çağrısı
`POST`a çevrildi ve **(2) sessiz kaldı**. (4) zinciri uçtan uca kapatıyor:
*arayüzün metodu → beyaz listedeki yol → sözleşmedeki metot*.

Sözleşme üzerinden ölçülüyor çünkü `contracts/openapi.yaml` backend
testleriyle **gerçek uygulamaya karşı** doğrulanıyor
(`test_yetki_kapsam`, `test_secdef_kapsam`) — yani sözleşmede olan
backend'de de vardır.

### Kapı kırılabildiğini kanıtladı

* `mesaj-ayarlari` beyaz listeden silindi → **(3) kırıldı**.
* Arayüzün `PUT`u `POST` yapıldı → **(4) kırıldı**.
* Sözleşme ayrıştırıcısı boş dönerse test kendini kırıyor (`SOZLESME.size
  > 150`) — yokluk iddiaları boş küme üzerinde her zaman doğrudur.

### Ve hemen **üçüncü örneği** buldu

`POST /api/panel/ice-aktarim/{id}/geri-al` — **BFF'te rota yoktu.** Genel
vekil `[kaynak]/[id]` yalnız **iki** segment eşleştirir; üçüncü segment
(`geri-al`) için hiçbir rota yok, istek **404** alıyordu. Uç backend'de ve
sözleşmede vardı. Yani "İçe aktarımı geri al" düğmesi ekranda duruyor,
basılıyor ve hiçbir şey olmuyordu — aranarak değil **taranarak** bulundu.

Rotası yazıldı. Genel vekile üçüncü segment eklemek yerine kendi rotası:
keyfi alt-eylem gönderilebilen bir kapı, beyaz listenin anlamını
zayıflatırdı.

---

## Test sunucusunda ne kontrol edeceksin

1. **Kanonik komutla** dağıt: `docker compose build migrate api admin-web worker`.
2. `SMS/E-Posta Yönetimi → Ayarlar`: alanlar gelmeli (boş olabilir),
   rozet **"E-posta: hazır (genel ayar)"** demeli.
3. **Kaydet**: bir değer gir, kaydet, sayfayı yenile — kalmalı. Parola
   alanı boş gelmeli (kayıtlı sır arayüze dönmez).
4. **Test gönderimi**: kanal `eposta`, kendi adresin → `gonderildi`.
5. `İçe Aktarım` → bir koşumu **Geri al**: artık çalışmalı (404 almıyordu).
