# P174 — Kurulum sihirbazı "veriler yüklenmedi" (rapor)

> Backend'de sorun yoktu: `GET /kurulum` her çağrıda 200. Kusur **BFF'in
> jeton yenileme yarışındaydı** ve sihirbaza özgü değildi.

---

## 1. 401 → refresh → yeniden deneme akışı

Akış doğru kurulmuştu: `proxyJson` 401 alınca `refreshSingleFlight` ile
yeniler ve isteği **bir kez tekrarlar**; eş zamanlı istekler aynı
yenilemeyi bekler. `proxyBinary` de aynı yolu kullanıyor ve `callBackend`
dışarı açılmıyor — yani oturumlu **her** yol buradan geçiyor.

**Ama tek-uçuş penceresi çok dardı.** Girdi `finally` içinde, yani
yenileme **biter bitmez** siliniyordu:

```ts
} finally {
  inflight.delete(rt);      // <-- yenileme çözülür çözülmez
}
```

Bu yalnızca **aynı anda bekleyen** istekleri birleştirir. Gerçek sayfa
açılışında istekler aynı anda değil **ardışık** olarak 401 alır — senin
log'undaki desen tam olarak bu. Yenileme çözüldükten **sonra** 401 alan
istek haritada bir şey bulamıyor ve **eski, artık döndürülmüş** jetonla
**ikinci bir yenileme** başlatıyordu.

Backend rotation + reuse-revoke uyguluyor: o ikinci çağrı **reddedilir**,
`pair` null olur ve vekil **401 döndürüp oturum çerezlerini siler** — az
önce yenilenmiş, geçerli bir oturumu yok eder.

Belirtinin tamamı buradan çıkıyor: bazı istekler 200, biri 401; 401 alan
`jsonFetcher` üzerinden `/login`e yönlendirme tetikliyor, ve silinen
çerezlerle kardeş isteklerin yazdığı çerezler yarışıyor. "Bazı bileşenler"
ifadesindeki **bazı** kelimesi bu yarışın kendisi.

### Düzeltme: sonuç penceresi

Yenilenen çift, **eski jetonun anahtarıyla 30 saniye** saklanıyor. Geç
kalan istek elinde eski çerezle geliyor ve aradığı şey tam olarak bu.
Yeni jeton da aynı sonuca bağlanıyor — çerezi almış bir istek ikinci kez
yenilemeye kalkmasın.

**Neden çerezi beklemek işe yaramaz:** yenilenen çift `Set-Cookie` ile
tarayıcıya gider, ama aynı açılıştaki öteki istekler **zaten yoldadır** ve
eski çerezi taşır. Sunucu tarafında kısa süreli bir hafıza olmadan bu
yarış kapanmaz.

**Neden yalnız başarı saklanıyor:** başarısız bir yenileme geçici de
olabilir (ağ). `null`ı saklamak, tek bir geçici hatayı 30 saniyelik oturum
kaybına çevirirdi.

**Güvenlik:** pencere, eski jetonu **zaten elinde tutan** birine yeni çifti
verir — ama o kişi çerezi taşıyor demektir, yani zaten oturumun sahibi.
Yeni bir yüzey açılmıyor.

**Yazılı sınır:** hafıza **süreç içindedir**. Birden fazla `admin-web`
örneği çalıştırılırsa yarış örnekler arasında yeniden mümkün olur. Bugünkü
dağıtımda tek konteyner var; çok örneğe geçilirse bu pencerenin paylaşılan
bir depoya (Redis) taşınması gerekir.

---

## 2. Sihirbaz özelinde: hata temizleniyor mu

**Evet, ve bu varsayımla değil ölçümle söyleniyor.**
`tests/jeton-yenileme-ekran.dom.test.ts`: geçici bir hatadan sonra veri
gelince hata **kullanıcı hiçbir şey yapmadan** kayboluyor (SWR'nin kendi
yeniden denemesi; testte elle tetikleyici yok).

Sihirbazın kendi `hata` durumu yalnız **mutasyon** yolunda (adım atlama)
set ediliyor ve her denemede sıfırlanıyor — yükleme hatasını yerel duruma
kopyalamıyor.

---

## 3. Tüm ekranlarda tarama

199 `useSWR` çağrı yeri var; 39'u SWR `error`ünü doğrudan sayfa hatası
olarak çiziyor (`error ? t("...") : null`). **Hiçbiri** hatayı yerel
duruma kopyalamıyor — tarandı. Yani bu 39 ekranın hepsi SWR'nin başarılı
yeniden doğrulamasıyla kendini toparlıyor.

`setHata`/`setError` kullanan yerlerin tamamı **kullanıcı tetikli**
akışlar (giriş, OAuth, sosyal giriş, rapor modalı) ve her denemede
sıfırlanıyor.

**Sonuç: sihirbaza özgü bir kusur yoktu ve ekran başına düzeltme
yazılmadı.** Tek merkezî düzeltme (`refreshSingleFlight`) `proxyJson` ve
`proxyBinary` üzerinden bütün ekranları birden kapsıyor.

---

## 4. Kilitler

`tests/backend.test.ts` (24, üçü yeni):

* **Ardışık 401'de eski jetonla ikinci yenileme denenmez** — düzeltmeden
  önce bu test kırmızıydı, yarış deterministik olarak üretildi.
* **Sayfa açılışı deseni:** dört paralel + bir gecikmiş istek; hepsi 200,
  tek yenileme, hepsi yeni çifti taşıyor.
* **Sonuç penceresi dolunca** yeniden yenileme yapılır (sahte zamanlayıcı).

`tests/jeton-yenileme-ekran.dom.test.ts` (2): vekil doğru çalışınca ekran
hiç hata göstermiyor; geçici hatadan sonra kendini toparlıyor.

### Düzeltmenin gerekli olduğu kanıtlandı

Sonuç penceresi devre dışı bırakıldı → **üç test kırıldı**, beşinci istek
401 döndü. Geri alınınca 24'ü de yeşil.

### Yönü değiştirilen bir kilit

`"ucus BITTIKTEN sonra yeni bir 401 YENI refresh cagirir"` testi **eski
davranışı — yani kusuru — kilitliyordu** (`toBe(2)`). Kaldırılmadı,
**zamana bağlandı**: pencere içinde ikinci yenileme yok, pencere dolunca
var. Korunması gereken şey aynıydı — pencere sonsuz olmamalı, yoksa harita
büyür ve çok eski bir jetona sonsuza dek geçerli bir çift dağıtılırdı.

Ayrıca eş zamanlı testin jetonu benzersizleştirildi: pencere süreç içi ve
token anahtarlı olduğu için iki testin aynı dizgeyi kullanması, ikincisinin
önbellekten dönüp `fetch`e hiç gitmemesi demekti (ölçüldü). Gerçek
jetonlar zaten benzersiz.

---

## Test sunucusunda ne kontrol edeceksin

1. Panelde 15+ dakika bekle (erişim jetonu dolsun), sonra sayfayı yenile —
   **hiçbir hata görmemelisin**, `Kurulum` dahil.
2. Backend log'unda desen aynı kalacak (birkaç 401 + **tek** refresh + 200'ler);
   fark, tarayıcının artık hiç 401 görmemesi.
3. Log'da **ikinci bir `POST /auth/refresh`** görürsen bildir — pencere
   çalışmıyor demektir.

> Not: `cloudflareinsights/beacon.min.js` engellemesi uygulamayla ilgili
> değil, doğru.
