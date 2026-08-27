# P182 — Dağıtım notları (prod)

Geliştirme ortamında çalışıldı (192.168.20.101). Prod'u kullanıcı uygular.
P182'nin dört bölümü de **yalnız admin-web** (web arayüzü). **Backend
değişmedi, göç YOK, yeni env YOK.**

**Kanonik dağıtım komutu** (kısmi derleme YAPMA — bkz. RUNBOOK §6.1): argümansız
`docker compose up -d --build` (tüm kod-taşıyan servisleri kapsar). P182 için
pratikte yalnız `admin-web` yeniden derlenmesi yeterlidir; ama alışkanlığı
bozmamak için argümansız form önerilir.

---

## Bölüm 1 — 3D maket işaret etiketleri kaldırıldı

- **Yeniden derle:** yalnız `admin-web` (`components/3d/bina-sahnesi.tsx`).
- **Göç/env:** YOK. Katkısal, geriye dönük güvenli — veri modeli değişmedi,
  yalnız çizim. Tıklama/seçim davranışı korundu.

## Bölüm 2 — Izgara sınırı 6 (istemci) + sessiz-kayıt düzeltmesi

- **Yeniden derle:** yalnız `admin-web` (`lib/pano-tercihi.ts` `WIDGET_SINIRI=6`,
  `dashboard/page.tsx` `duzeniKaydet`/`varsayilanaDon`, `widget-seridi.tsx`).
- **Sunucu:** DEĞİŞMEDİ — `PanoTercihi.widgetlar max_length=6` ZATEN 6'ydı;
  tutarsızlık istemcideydi. Yeni derleme sonrası 7. widget istemcide eklenemez,
  metin "6" der.
- **Geriye dönük:** Kayıtlı 7-widget'lı eski tercih (varsa) `tercihGovdesi`
  6'ya dilimlenir; kullanıcı fazlalığı bir dahaki düzenlemede kaybeder (zaten
  sunucu 6'dan fazlasını hiç kabul etmemişti).
- **Göç/env:** YOK.

## Bölüm 3 — Izgara hizası (masaüstü tam genişlik)

- **Yeniden derle:** yalnız `admin-web` (`widget-seridi.tsx` `lg:grid-cols-6`).
- **Göç/env:** YOK. Salt görsel (CSS ızgara sütun sayısı).

## Bölüm 4 — Düzenleme arayüzü sadeleştirme (sürükle-bırak + klavye)

- **Yeniden derle:** yalnız `admin-web` (`dashboard/page.tsx` sürükle-bırak +
  klavye + bırakma bölgeleri; `lib/pano-tercihi.ts` `bolumSurukleBirak`/
  `bolumOkTasi`; 7 dil sözlüğüne `panoTasiTut` + `panoBosSatir`).
- **Göç/env:** YOK. Tercih yine `PUT /me/pano-tercihi` ile aynı JSONB gövdesine
  yazılır (şema değişmedi) — **otomatik kayıt** (bkz. `P182-kararlar.md §4`).
- **Geriye dönük:** Yerleşim modeli (`satirlar`/`bolumler`) değişmedi; eski
  kayıtlar aynen çizilir.

---

## Özet

| Bölüm | Servis | Göç | Env |
|------|--------|-----|-----|
| 1 3D etiket | admin-web | — | — |
| 2 sınır 6 | admin-web | — | — |
| 3 hiza | admin-web | — | — |
| 4 sürükle-bırak | admin-web | — | — |

Hiçbir bölüm backend/DB dokunmuyor. Tek başına `admin-web` derlemesi P182'yi
prod'a taşır; risk düşük (salt web UI), geri alma = eski `admin-web` imajı.
