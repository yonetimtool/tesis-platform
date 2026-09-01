# P197 — E-posta zorunlu: e-postasız hesap bir daha oluşmayacak

## Neden

E-posta bu üründe bir iletişim alanı değil, **kimliğin taşıyıcısı**:
davet, doğrulama kodu ve parola sıfırlama yalnız oradan gider (SMS ürün
genelinde kapalı). E-postasız açılan bir hesap daveti alamaz, Tesis ID'yi
öğrenemez, hiç giremez; parolasını sıfırlayamaz; hesabını silemez —
P196'da ölçüldü. Yani "e-postasız kullanıcı" bir kullanım biçimi değil,
**sessiz bir çıkmaz**.

Kural uygulama katmanında parça parça uygulanmıştı (P186 tekil ekleme,
P193 Excel aktarımı). Veritabanı hâlâ izin veriyordu — ve o izin fiilen
kullanılıyordu.

## 1. Göç 0089 — `app_user.email` NOT NULL

### Mevcut satırlar: silinmedi, sentetik adresle dolduruldu

Üç seçenek vardı:

| Seçenek | Karar | Gerekçe |
|---|---|---|
| **Sil** | Elendi | `app_user` bir sürü FK'nin hedefi (denetim, finans, okutma, talep) ve çoğu RESTRICT — göç yarıda patlardı. Patlamasa bile **geri alınamaz**: `downgrade` silinen kullanıcıyı geri getiremez. |
| **Anonimleştir** | Elendi | Anonimleştirme KVKK'nın bir aracıdır; kişinin talebi ya da saklama süresi dolması üzerine yapılır. Bir şema değişikliğini gerekçe sayıp kimlik verisi silmek, o aracı amacı dışında kullanmak olurdu. |
| **Sentetik adres** | **Seçildi** | Aşağıda. |

Değer: `gecersiz+<user_id>@yonetiyor.invalid`

* **`.invalid`** RFC 2606 ile ayrılmış bir TLD'dir — DNS'te **asla
  çözülmez**. Gerçek bir alan adı yazsaydık, bir gün o alanın sahibi
  bizim doğrulama kodlarımızı alırdı.
* `user_id` içerir → `uq_app_user_tenant_email` çakışması imkânsız.
* **Geri alınabilir**: `downgrade` tam olarak bu desendeki adresleri
  NULL'a çevirir, başka hiçbir satıra dokunmaz.
* `eposta_dogrulandi` bu satırlarda `false`'a çekilir — sentetik adres
  doğrulanmış sayılamaz.

Bu hesapların sahipleri hesaplarını kullanamaz; ama **zaten
kullanamıyorlardı**. Değişen tek şey, çıkmazın artık görünür olması:
adres `@yonetiyor.invalid` ile bitiyorsa hesap sahiplenilmemiş demektir.

`NOT NULL` yanına **`CHECK (btrim(email) <> '')`** kondu: NOT NULL tek
başına `''`e izin verir ve o, "adres var" görünen bir adressizliktir.

## 2. Kapatılan yollar

Asıl sızıntı beklediğim yerde değildi:

| Yol | Durum | Not |
|---|---|---|
| **`create_tenant_with_yoneticis`** (SECURITY DEFINER) | **Kapatıldı** | `app_user`a e-postasız yazıyordu. Dev'de biriken **952** e-postasız satırın kaynağı buydu. |
| **`add_tenant_yonetici`** (SECURITY DEFINER) | **Kapatıldı** | Aynısı. **Eski imza `DROP` edildi** — bırakılsaydı eski çağrı çözülmeye devam eder ve delik açık kalırdı. |
| `POST /tenants` | Kapatıldı | `YoneticiCreate.email` zorunlu |
| `POST /tenants/{id}/yoneticiler` | Kapatıldı | `TenantYoneticiAdd.email` zorunlu |
| `POST /users` | Zaten kapalıydı (P186) | Router'daki `if body.email else None` kalıntısı temizlendi |
| `POST /residents` | **Kapatıldı** | `ResidentAssign.email` opsiyoneldi |
| `PATCH /residents/{id}` | **Kapatıldı** | `email: null` adresi **boşaltıyordu**; artık "dokunma" demek |
| `POST /ice-aktarim/kisi` | Zaten kapalıydı (P193) | — |
| `POST /auth/kayit/tesis-olustur` | **Kapatıldı** | E-posta SSO kimliğinden alınır; sağlayıcı paylaşmadıysa 422 `eposta_gerekli` ve kullanıcı e-posta doğrulamalı yola yönlendirilir |
| `POST /auth/kayit/yonetici-tesis` | Zaten geçiyordu | `satir.eposta` fonksiyona iletiliyordu (kullanılmıyordu, artık kullanılıyor) |
| Seed betikleri | Zaten e-posta yazıyor | Ölçüldü |
| Mobil kayıt | Zaten e-posta istiyor | Yönetici mobilden kaydolamaz (P194) |

**SECURITY DEFINER fonksiyonlar neden kritikti:** uygulama katmanındaki
her doğrulamayı atlarlar. Sütunu NOT NULL yapıp fonksiyonları bırakmak,
göçün ertesi günü `POST /tenants`i 500'e düşürürdü.

## 3. Hesap silme: telefon yolu kaldırıldı

`POST /me/hesap-sil/kod-iste` **silindi**. Bu, P196'da bilinçli olarak
bıraktığım istisnanın kapanmasıdır:

> P196'da o uçta 502 dönmemeyi seçmiştim, çünkü SMS kapalı olmasına
> rağmen uç kaldırılırsa **telefon-only bir kullanıcının hesabını
> silmesinin hiçbir yolu kalmıyordu** (mağaza şartı). Yani uç,
> çalışmadığı hâlde "tek yol" olduğu için duruyordu.

**Artık telefon-only kullanıcı yok.** Herkesin e-postası var, dolayısıyla
herkes `/me/hesap-sil/eposta-kod-iste` kullanabilir. Çalışmayan bir ucu
"tek yol" diye tutmanın gerekçesi kalmadı — ve çalışmayan bir uç,
kullanıcıya "kod gönderildi" diyen bir yalandan ibaretti.

**P196'nın açık maddesi bu turda kapandı.**

## 4. Yan bulgu: anonimleştirme 500 veriyordu

KVKK anonimleştirmesi `hedef.email = None` yazıyordu — NOT NULL'a takılıp
hesap silmeyi **500'e düşürdü** (ölçüldü). Çözüm, adresin silinmesi değil
**kişisel veri taşımaması**: göçle aynı desen
(`gecersiz+<id>@yonetiyor.invalid`). Adres yalnız satırın zaten taşıdığı
birincil anahtarı içerir ve DNS'te çözülmez.

## 5. Kalıcı kilit — `test_p197_eposta_zorunlu.py` (10 test)

| Ne kilitleniyor |
|---|
| Sütun NOT NULL **ve** boş dizge CHECK'i var |
| Veritabanında e-postasız satır kalmadı |
| İki SECURITY DEFINER fonksiyonu da `email` yazıyor |
| **Eski (e-postasız) `add_tenant_yonetici` imzası artık çözülemiyor** |
| `POST /users`, `POST /residents`, `POST /tenants`, `POST /tenants/{id}/yoneticiler` e-postasız gövdeyi 422 ile reddediyor |
| `PATCH /residents` e-postayı temizleyemiyor |
| Excel aktarımı e-postasız satırı hata sayıyor |
| Anonimleştirme e-postayı NULL yapmıyor |

## NE ÖLÇTÜM

```
GÖÇ ÖNCESİ (dev):  toplam 2363 kullanıcı, 952 e-postasız (hepsi 'yonetici')
GÖÇ SONRASI:       sentetik adres verilen 953, e-postasız kalan 0
                   email NOT NULL: True
                   kısıtlar: ck_app_user_email_bos_degil, uq_app_user_tenant_email
DOWNGRADE:         nullable: YES, NULL'a geri dönen 953, sentetik kalan 0
TEKRAR UPGRADE:    temiz
```

Göç tam simetrik. Testler: yeni kilit **10 test**; e-posta zorunluluğu
55 test gövdesini ve 4 testin varsayımını değiştirdi (hepsi güncellendi,
gerekçeleri testlerin içinde yazılı).

## Ölçemediklerim / dikkat

- **Prod'daki 12 kayıt** dev'dekilerle aynı desende değil (dev'inkiler
  fixture artığı). Göç ikisini de aynı şekilde ele alır: adres yazar,
  silmez.
- Prod'da göçten sonra şu sorgu, dokunulan satırları gösterir:
  ```sql
  SELECT id, ad, role, is_active, created_at
    FROM app_user WHERE email LIKE 'gecersiz+%@yonetiyor.invalid';
  ```
  Beklenen: **12 satır**. Farklıysa göçten önce beklenmedik bir şey var
  demektir — bakmadan devam etmeyin.
