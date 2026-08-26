# P181 — Dağıtım notları (prod)

Geliştirme ortamında çalışıldı (192.168.20.101). Prod'u kullanıcı uygular. Bu
belge her bölümün prod'a taşınması için GEREKENLERİ toplar: göçler, yeniden
derlenecek servisler, yeni env değişkenleri.

**Kanonik dağıtım komutu** (kısmi derleme YAPMA — bkz. RUNBOOK §6.1):
`docker compose build migrate api admin-web worker` (ya da argümansız
`up -d --build`). `migrate` göçleri uygular; `api`/`admin-web` kod gömülü olduğu
için mutlaka yeniden derlenir.

---

## Bölüm 1 — E-posta zorunlu + doğrulama beklemede

- **Göç:** `0070_eposta_dogrulandi` — `app_user.eposta_dogrulandi`
  (NOT NULL DEFAULT false) + `kod_amaci` enum `eposta_ekle`. Geriye dönük
  güvenli: mevcut kullanıcılar doğrulanmamış (false) başlar.
- **Yeniden derle:** `api` (yeni uçlar + model), `admin-web` (profil kartı + BFF).
- **Yeni env:** YOK.

## Bölüm 2 — Parola sıfırlama ("şifremi unuttum")

- **Göç:** `0071_kod_amaci_sifre_sifirla` — `kod_amaci` enum `sifre_sifirla`.
- **Model düzeltmesi (Böl.1 gizli hatası):** `models.py` `kod_amaci` ENUM'una
  `eposta_ekle` + `sifre_sifirla` eklendi; `api` yeniden derlenmeli (yoksa
  `/me/eposta/dogrula` ve `/auth/sifre/dogrula-ve-ayarla` 500 verir).
- **Yeniden derle:** `api` (2 yeni uç), `admin-web` (`/giris/sifremi-unuttum`
  sayfası + BFF).
- **Yeni env:** YOK. E-posta gönderimi mevcut `SMTP_*` ile (compose'da zaten
  tanımlı); SMS yok. Prod'da gerçek kod e-postası için `SMTP_HOST/USER/PASSWORD/
  FROM` dolu olmalı (boşsa gönderim LOG'a düşer, sessizce "gönderildi" demez).

---

## Göç sırası özet

```
0069_yonetici_by_email      (P180)
0070_eposta_dogrulandi      (P181 Böl.1)
0071_kod_amaci_sifre_sifirla (P181 Böl.2)
```

Göçler ileri-uyumlu ve geriye dönük güvenli (enum ADD VALUE + nullable-default
kolon). `create_type=False` enum'ları model tarafında da güncellendi.
