# P205 — Çok yönlü giriş + vardiya zaman çizelgesi

**Tarih:** 2026-09-02

---

# 0. Uygulamadan ÖNCE yapılan iki ölçüm

Sen P204'te "ölçemediklerini uygulamadan önce doğrula" dedin. İkisini de
yaptım ve **ikisi de analizimi düzeltti.**

## 0.1 P204 tablosunda YANLIŞ olan üç satır

| İşlev | P204'te yazdığım | ÖLÇÜLEN gerçek |
|---|---|---|
| **Davet gönderme** | "mobilde yok, küçük iş" | **Kısmen VAR.** `residents_api.dart` / `staff_screen.dart`: mobilde sakin veya personel eklerken sunucu **otomatik davet gönderiyor**. Eksik olan şey davet **listesi + yeniden gönderme** (`/davetler`). |
| **Gider/gelir kaydı** | "mobilde yok, küçük iş" | **VAR.** `budget_api.dart` `POST /budget/entries` çağırıyor ve o uç **`FinansalHareket` yazıyor** (tek defter). Yani mobilde gelir/gider kaydı zaten yapılabiliyor. Eksik olan: fiş fotoğrafı ve onay akışı. |
| **Bütçe** | "salt okunur" | **Yazma var:** `POST /budget/categories` + `POST /budget/entries`. |

**Sonuç:** P204'ün öncelik listesindeki **3 (davet)** ve **4 (gider
kaydı)** maddeleri baştan yazılacak işler değil, **tamamlanacak** işler.
Bunu ölçmeden başlasaydım var olan bir şeyi yeniden yazıyor olacaktım —
uyarın yerindeydi.

## 0.2 SSO ile giren çok tesisli yönetici — ÖLÇÜLDÜ, hata YOK

Ölçüm (`pg_indexes` + `pg_proc`):

```
uq_oauth_kimlik_subject       UNIQUE (saglayici, subject)   ← PLATFORM GENELİNDE
uq_oauth_kimlik_user_saglayici UNIQUE (user_id, saglayici)

tenant_id_by_oauth: SELECT tenant_id FROM oauth_kimlik
                    WHERE saglayici = ? AND subject = ?
```

`(saglayici, subject)` **platform genelinde tekil**. Yani bir Google
hesabı tüm platformda **tek bir `app_user` satırına** bağlanabilir ve
`tenant_id_by_oauth` **belirsiz olamaz**.

**Cevap:** SSO ile giren çok tesisli yönetici, **kimliğini bağladığı
tesise** düşüyor. Rastgele değil, deterministik. **Ayrı bir hata yok.**

Gerçek sınır şu: aynı Google hesabını **ikinci** bir tesise
bağlayamıyor. Ama P203 §2'den beri uygulama içinden geçiş var, yani
bağlı olduğu tesise girip ötekine geçiyor.

**Karar:** SSO girişinden sonra da — parola girişinde olduğu gibi —
üyelik listesi >1 ise **tesis seçimi gösterilecek**. Böylece üç giriş
yolu (parola / kod / SSO) aynı davranışı gösterir.

---

# 1. Çok yönlü giriş — BACKEND BİTTİ

## K1.1 — Ayrım `@` işaretine bakar, sezgiye değil

`app/kimlik.py`: **`@` varsa e-postadır.** Tahmin değil — hiçbir telefon
numarası `@` içermez, hiçbir e-posta `@`sız olamaz (RFC 5321). Rakam
sayısına ya da uzunluğa bakan bir sezgi `1234@ornek.com` gibi adreslerde
yanılırdı; test onu da kapsıyor.

Telefon **E.164'e normalize edilir**: `"0532 111 22 03"`,
`"+90 532 111 22 03"`, `"(0532) 111-22-03"` aynı kişidir. Normalize
etmeden aramak, kullanıcının boşluk koyup koymamasına göre giriş
yaptırmak olurdu.

## K1.2 — Ölçüm bir kusur gösterdi: ülke kodu iki kez ekleniyor

```
normalize_phone("905321112203") -> +90905321112203     ← ölçüldü
```

`+` yoksa ve rakamla başlıyorsa başına `+90` ekliyor; girdinin **zaten
ülke kodu taşıdığını** görmüyor. `905...` numarayı yazmanın çok yaygın
bir biçimi — yeni tek alanda bu, **girişin sessizce başarısız olması**
demekti.

**`normalize_phone`'u değiştirmedim** ve bu bilinçli: o fonksiyon
**kullanıcı yaratma** anında da çalışıyor ve **saklama biçimini**
belirliyor. Davranışını değiştirmek, eskiden o yolla yazılmış satırları
erişilemez kılabilirdi — bu turda onları ölçmedim.

Telafi **yalnız giriş yolunda** (`kimlik.py::_ulke_kodunu_duzelt`), dar
bir kuralla: girdi tamamen rakamsa, `90` ile başlıyorsa ve 12 hane ise
başına `+` konur. Kusurun kendisi bir testle **kayıt altında** — biri
`normalize_phone`u düzeltirse test uyarıyor.

## K1.3 — `tenant_slug` artık opsiyonel

| Durum | Davranış |
|---|---|
| Tek üyelik | Doğrudan giriş — **seçim gösterilmez** |
| Birden çok | **409 `tesis_secimi_gerekli`**, jeton **üretilmez** |
| Slug verilmiş | Yalnız o tesis denenir (eski davranış) |

Rastgele birini seçmek, kullanıcıyı **bilmediği bir tesise sokmak**
olurdu. Slug'ı zorunlu bırakmak ise P203 §2'de web'de düzeltilen
şikâyetin ta kendisiydi.

## K1.4 — Sızdırmama: hepsi aynı 401

Çözülemeyen kimlik · bilinmeyen kimlik · yanlış parola · pasif hesap ·
üye olunmayan slug → **hepsi aynı durum + aynı kod + aynı metin**. Bir
test bu beş imzanın **tekil** olduğunu kilitliyor.

Metin de tür söylemiyor: eski `giris_bilgileri_hatali_email` yerine
**`giris_bilgileri_hatali`** ("Giriş bilgileri hatalı."). *"E-posta
hatalı"* demek, saldırgana girdisinin hangi dala girdiğini söylerdi.
Eski metinler duruyor — telefona özel `login-phone` ucu onları
kullanmaya devam ediyor.

`/auth/tesislerim`de çözülemeyen girdi **hata değil, boş liste**; ve
parolada `minLength` **yok**: bu bir doğrulama ucu değil **arama**
ucudur, "parolan çok kısa" demek hesabın varlığından bağımsız bir sinyal
vermek olurdu.

## K1.5 — Eski istemciler kırılmıyor

`LoginRequest.email` alanı **duruyor** ve `kimlik` boşsa ondan
dolduruluyor. Mobil uygulama mağazadadır; eski sürümler bir süre daha
`email` gönderecek ve alanı zorunlu kılmak **güncellemeyen kullanıcıların
girişini kırmak** olurdu (P202'de eklenen zorunlu güncelleme bile anında
yayılmaz).

## K1.6 — Telefon benzersizliği KALDIRILMADI

P204 kararı korundu. Göç 0095 kısıtı **görmezden gelmiyor, ondan
faydalanıyor**: telefonla eşleşme en fazla **bir** satır döndürür,
dolayısıyla telefonla girişte tesis seçimi zaten çıkmaz. Ölçüldü:
`tesislerim` e-postayla **2**, telefonla **1** tesis döndü.

## Ölçüm — akış gerçekten sürüldü

```
E-POSTA (tek tesis)      -> 200 jeton
TELEFON                  -> 200 jeton
TELEFON (5 farklı yazım) -> 200 jeton
ESKİ istemci (email)     -> 200 jeton
YANLIŞ parola            -> 401  ┐
BİLİNMEYEN e-posta       -> 401  │ hepsi AYNI kod + AYNI metin
BİLİNMEYEN telefon       -> 401  │
ÇÖZÜLEMEYEN girdi        -> 401  ┘
ÇOK TESİS (slug yok)     -> 409 tesis_secimi_gerekli, jeton YOK
ÇOK TESİS + slug         -> 200 jeton
tesislerim e-posta / tel -> 2 tesis / 1 tesis
```

| Kilit kanıtı — bozma | Düşen test |
|---|---|
| Çok tesiste ilkini seç | ÇOK TESİS SEÇİM İSTER |
| Çözülemeyen girdiye özel 422 | TÜM BAŞARISIZ DURUMLAR AYNI YANIT |

Testler: kimlik ayrımı 19, uç davranışı 18 (izolasyon kilidi dahil).
Kilit registreleri (sözleşme, hata metinleri, denetçi) 78 test yeşil.
