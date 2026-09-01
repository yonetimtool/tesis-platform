# P194 — dağıtım notları

Mobilde yönetici SSO girişi. **Göç YOK**, şema değişmedi.

---

## 1. Ne dağıtılmalı

| Bileşen | Değişti mi | Not |
|---|---|---|
| **backend (`api`)** | Evet | `routers/oauth.py` — giriş niyetinde e-posta eşleşmesi + `mevcut_hesap` dalının bağlama düzeltmesi |
| **mobil (APK/IPA)** | **Evet — asıl düzeltme burada** | Yeni sürüm yayınlanmadan kullanıcı hâlâ eski ekranı görür |
| admin-web | Hayır | — |
| worker/beat | Hayır | `api` ile aynı imaj; birlikte kurulur |

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build api worker
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d api worker
```

> **Sunucu tek başına dağıtılırsa ne olur:** eski mobil sürüm rol
> göndermeye devam eder ve yönetici yine `onay_bekliyor` alır. Ama K4
> sayesinde (giriş niyetinde e-posta eşleşmesi) **doğrulanmış e-postalı**
> yönetici artık Tesis ID formuna hiç düşmeden girer — yani sunucu
> dağıtımı tek başına da çoğu durumu düzeltir. Tam düzelme için mobil
> sürüm gerekir.

## 2. Bayrak

`YENI_KAYIT_AKISI` **açık olmalı** (prod varsayılanı zaten `true`).
Kapalıyken `POST /auth/oauth/rol-tamamla` **503** döner ve SSO tamamlama
hiç çalışmaz. `.env.prod`da değer varsa `true` olduğunu doğrulayın.

## 3. Davranış değişiklikleri

1. **Mobil giriş ekranında rol seçimi YOK.** Kullanıcı SSO ile gelip
   kimliği bağlı değilse yalnız **Tesis ID** sorulur.
2. **Doğrulanmış e-postalı yönetici Tesis ID bile görmez** — kimlik
   bağlanır ve oturum açılır (web'deki davranışın aynısı).
3. **Doğrulanmamış e-postada değişiklik yok**: `baglama_gerekli` ve
   e-posta OTP yolu aynen duruyor.
4. **Kayıt akışı değişmedi**: yönetici mobilden hâlâ kaydolamaz.

## 4. Prod'da doğrulanması gerekenler

Dev'de sağlayıcı kimlik bilgileri yok; gerçek SSO akışı **denenmedi**.

- [ ] Google ile: web'de kaydolmuş bir yönetici hesabıyla mobilden giriş.
- [ ] Microsoft ile aynısı.
- [ ] Apple ile aynısı (private relay adresli hesap dahil — relay
      adresleri doğrulanmış sayılır, uyarı ekranda gösterilir).
- [ ] Giriş sonrası **yönetici arayüzünün** açıldığı (sakin arayüzü
      değil).
- [ ] Bir **sakinin** SSO ile girişinin bozulmadığı (rol artık
      gönderilmiyor; sunucu rolü hesaptan okuyor).
- [ ] Aynı sağlayıcıdan **ikinci bir hesapla** giren yöneticide 500
      alınmadığı (K5 düzeltmesi).

## 5. Geri alma

Kod tarafı: önceki commit + `api` yeniden kurulumu. Mobil tarafta
mağazadan eski sürüme dönmek gerekmez — sunucu değişikliği eski
istemciyle uyumludur (rol göndermek hâlâ geçerli bir istektir).
