# PLATFORM / TESİS AYRIMI — panel.* ve app.* ne sunar (P125)

Kerem'in ürün kararı:

| Konak | Kim girer | Ne görür |
|---|---|---|
| `panel.yönetiyor.com` | **yalnız biz** (platform sahibi) | tesis yönetimi, platform ayarları, tesisler-arası görünümler, işlem geçmişi |
| `app.yönetiyor.com` | **tüm tesis rolleri** | yönetici / sakin / güvenlik / tesis görevlisi — herkes yalnız kendi alanını |
| `www.yönetiyor.com` (+ kök) | herkes | tanıtım sitesi (SEO) |

Bu belge, o kararı **ölçülmüş veriye** oturtur: sınıflandırma tahminle değil,
`backend/tests/yetki/rol-matrisi.txt`ten (317 uç, koddan üretilen kilit)
okunarak yapıldı.

---

## 0) ÖLÇÜLEN BAŞLANGIÇ DURUMU — istenen izolasyon BUGÜN VAR

Görev "platform_admin rolü oluştur/onayla; tesis yöneticisi platform
API'sine ulaşamasın" diyor. **Ulaşamıyor.** Rol matrisi bunu zaten
kilitliyor:

```
POST   /tenants        admin=IZIN  yonetici=RED  security=RED
                       tesis_gorevlisi=RED  resident=RED  guvenlik_amiri=RED
```

`admin` cross-tenant çalışır (owner-sahipli oturum; `tenant` tablosunda RLS
FORCE olduğu için tesis-kapsamlı bir oturumla bu uçlar zaten çalışamazdı).
Yani **yeni bir rol eklemek şart değil** — eklenecek olsaydı, 317 satırlık
matrisin yeniden üretilmesi ve bir enum göçü gerekirdi; aynı sonucu daha
pahalıya verirdi.

## 1) ASIL SORUN: `admin` AŞIRI YÜKLÜ

"Yalnız admin" olan **35 uç** iki **farklı** şeye ayrılıyor:

### 1a) Gerçek PLATFORM uçları (14) — `panel.*`ta kalır

```
GET    /admin/overview
GET    /audit
GET    /devices
GET    /support/all
PATCH  /support/{ticket_id}
GET    /integrations/anpr/keys
POST   /integrations/anpr/keys
DELETE /integrations/anpr/keys/{key_id}
GET    /tenants
POST   /tenants
GET    /tenants/{tenant_id}
PATCH  /tenants/{tenant_id}
DELETE /tenants/{tenant_id}
PATCH  /tenants/{tenant_id}/yonetici
POST   /tenants/{tenant_id}/yonetici/reset-credential
```

### 1b) TESİS SEVİYESİ ama admin-only olanlar (~21) — `app.*`a taşınır

`/finans/*` (9), `/borclandirma/*` (5), `/dues/assessments`,
`/dues/payments`, `/assets` (3), `PUT /checkpoints/{id}/sdm-key`,
`POST /unit-uyarilari/kuyruk-isle`.

**Bunlar tam olarak Kerem'in "panel'de tek bir sitenin aidat işlemleri
olmasın" dediği şey.** Bir tesisin tahsilatını platform panelinden yapmak,
platform sahibini o tesisin muhasebecisi hâline getirir; ayrıca hangi
tesiste olduğunuzu ekranda taşımayan bir arayüzde **yanlış tesise
kaydetmek** an meselesidir.

### KARAR (düzeltildi)

`admin` **platform** rolü olarak kalır. Yeni bir `platform_admin` enum
değeri **eklenmez** (göç + 317 satırlık matrisin yeniden üretimi = aynı
sonuç, daha pahalı).

**1b kümesinden `admin` ÇEKİLMEZ.** İlk yazımda "çekilir" demiştim; bu
**istenenin ötesindeydi ve risklidir**, düzeltiyorum. Görevin şartı şu:
*"tests prove a tenant role gets 403 on platform endpoints and platform nav
never renders for them, and vice-versa"* — yani **tesis rolü → platform ucu
403** (bugün sağlanıyor) ve **menü karşı tarafta hiç çizilmez**. Platform
rolünün tesis uçlarındaki yetkisini geri almak bunların hiçbiri için
gerekli değil; buna karşılık bir tesiste hem platform sahibi hem yönetici
olan bir kurulumda **çalışan bir akışı kırardı**.

Ayrım bu yüzden **yüzey** ayrımıdır:

| Katman | Ne yapar |
|---|---|
| `panel.*` **menüsü ve rotaları** | yalnız platform bölümleri — tesis sayfaları oraya **hiç konmaz** |
| Sunucu (rol matrisi) | tesis rolü platform ucunda **403** (bugün var, kilitli) |
| Test | platform menüsü tesis rolüne **çizilmez**; tesis menüsü platform yüzeyinde **çizilmez** |

Yani "tek bir sitenin aidat işlemleri panelde olmasın" şartı, o sayfaları
`panel.*`tan **kaldırarak** karşılanır — API yetkisini geri alarak değil.
Bir gün gerçekten geri alınacaksa bu ayrı ve **duyurulması gereken** bir
karardır; bu turda yapılmadı.

---

## 2) PANEL SAYFALARININ SINIFLANDIRMASI

`admin-web/app/(protected)` altındaki **32** sayfa:

### PLATFORM → `panel.*`ta kalır (7)

| Sayfa | Neden |
|---|---|
| `tenants`, `tenants/[id]` | tesis yaşam döngüsü — platformun çekirdek işi |
| `audit` | işlem geçmişi (tesisler arası) |
| `support` | tüm tesislerin destek talepleri (`/support/all`) |
| `integrations` | ANPR anahtarları, cihaz kayıtları — platform envanteri |
| `yetki` | koddan üretilen yetki matrisi görünümü (P41) |
| `settings` | **BÖLÜNÜR**: platform ayarları panelde, tesis ayarları app'te |

### TESİS → `app.*`a taşınır (25)

`announcements`, `assets`, `building-editor`, `checkpoints`, `complaints`,
`dashboard`, `dues`, `finans`, `mesajlar`, `notifications`, `patrol-plans`,
`portal`, `raporlar`, `reports/dues`, `reports/patrols`, `reports/tasks`,
`sayac-okuma`, `schematic`, `shifts`, `tanimlar`, `tasks`, `transparency`,
`units`, `users`, `yonetisim`.

> `users` **tesis** tarafındadır: bir tesisin personel/sakin listesidir.
> Platform tarafındaki kullanıcı işi `tenants/[id]` içindeki *yönetici
> ata/sıfırla* akışıdır ve o zaten orada.

---

## 3) ZORLAMA SUNUCUDADIR, MENÜ DEĞİL

Menüyü gizlemek bir yetkilendirme değildir: adres çubuğuna yazan biri
sayfayı açar ve BFF çağrısı yaparsa veri alır. Bu yüzden ayrımın kilidi
**rol matrisi**dir (`backend/tests/yetki/rol-matrisi.txt`, koddan üretilir)
ve iki yönde de ölçülür:

* tesis rolü → platform ucunda **403**,
* platform rolü → tesis-özel uçta **403**.

İkinci yön **menü** düzeyindedir, yetki düzeyinde değil (bkz. yukarıdaki
düzeltilmiş karar): platform yüzeyinde tesis menüsü çizilmez, tesis
yüzeyinde platform menüsü çizilmez.

---

## 4) SIRA (uygulama planı)

1. **Panel rotalarından tesis sayfalarını çıkar** — `panel.*` yalnız
   platform bölümlerini sunar. Rol matrisine **dokunulmaz** (yetki geri
   alınmıyor); eklenen şey menü/rota testleridir.
2. **Panel navigasyonunu platform-only'ye indir**; tesis sayfaları `app.*`
   yapısına taşınır (P126).
3. **Caddy**: `app.` bugün yer tutucu sunuyor; P126 landing ettiğinde
   `admin-web`e proxy'lenir ve konak listesi/`alan-adi-denetimi` güncellenir.
4. `yonetio.site` **her zaman** çalışır durumda kalır (App Store bağlantıları
   ve mobilin gömülü `api.yonetio.site` adresi).
