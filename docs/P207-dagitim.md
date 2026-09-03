# P207 — dağıtım notları

Sıra önemlidir: **göç → imajlar → doğrulama**. Komutlar `infra/` içinde
`--env-file .env.prod` ile çalıştırılır (RUNBOOK-PROD.md §6).

```bash
cd /opt/yonetio/infra   # sunucudaki yol
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

> **Kısmi build YAPMAYIN.** `migrate api admin-web worker beat` beşi birden
> gerekiyor; argümansız `up -d --build` hepsini kapsar (P171 olayı).

> **BEAT VE WORKER BU TURDA ZORUNLU.** §3 yeni bir zamanlanmış görev
> ekliyor (`scheduler.vardiya_hatirlatma`, dakikada bir). Görev tanımı
> **worker** imajında, zamanlama **beat** imajındadır: yalnız `api`
> güncellenirse hatırlatmalar hiç çalışmaz ve bu **sessiz** bir arızadır
> (hata yok, sadece bildirim gelmez). Bu not iki turda atlandığı için
> burada ayrıca yazılıyor.

Bu turda **dört yeni göç** var:
`0099_vardiya_kalibi`, `0100_bildirim_sesi`, `0101_vardiya_hatirlatma`,
`0102_bildirim_tipi_vardiya`.

---

## §1 — Ay bazında toplu vardiya planlama

Yeni değişken yok. Göç `0099` iki şey ekliyor: `vardiya_kalibi` tablosu
(RLS açık) ve `vardiya_plani.parti_id` (kısmi indeks).

**Doğrulama:** yönetici olarak `app.*` → Vardiya planı → **Ay** görünümü →
takvim şeridinden birkaç gün seç → "Kalıp uygula" → "Önizle" kaç vardiya
oluşacağını söylemeli; "Uygula" sonrası "Son toplu işlemi geri al"
düğmesi çıkmalı.

---

## §2 — Bildirim sesi

Göç `0100` (`app_user.bildirim_sesi`, varsayılan **true**).

**Mobil sürüm gerekiyor:** bildirim kanalları uygulamada oluşturuluyor
(`MainActivity.kt`). Sunucu yeni gövdeyi göndermeye başlasa bile
**eski mobil sürümde kanal yoktur** ve bildirim manifest varsayılanına
düşer. Sıralama önemli değil (eski sürüm kırılmaz) ama sesin duyulması
için yeni APK/AAB şart.

### Ses dosyası (henüz YOK — sistem sesiyle çalışıyor)

Dosya geldiğinde:

1. `mobile/android/app/src/main/res/raw/yonetio_bildirim.ogg`
   (OGG/Vorbis, 1–3 sn, < 100 KB, ad küçük harf)
2. `mobile/ios/Runner/yonetio_bildirim.caf`
   (CAF/LinearPCM, **30 sn'den kısa olmak zorunda** — uzunsa iOS sesi
   sessizce varsayılana düşürür; Xcode'da Runner target'ına eklenmeli)
3. `backend/app/push_kanal.py`: `SES_HAZIR = True`
4. **Kanal kimlikleri `_v2` yapılmalı** (üç sabit + `MainActivity.kt`):
   Android'de var olan kanalın sesi değiştirilemez; kimlik değişmezse
   güncelleyen kullanıcıda **eski sessiz kanal kalır**.
5. Yeni mobil sürüm + `api` yeniden dağıtımı.

---

## §3 — Vardiya hatırlatma

Göç `0101` (tenant ayarları) + `0102` (bildirim tipi enum'u).

Yeni beat girdisi: `vardiya-hatirlatma`, **60 sn**. Görev hem hatırlatmayı
hem "vardiyaya başlamadı" uyarısını çalıştırır.

### Tenant ayarları (varsayılanlar göçte)

| Alan | Varsayılan | Anlamı |
|---|---|---|
| `vardiya_hatirlatma_dk` | `15` | Virgülle kademe listesi ("30,5"); boş = kapalı, en fazla 3 kademe |
| `vardiya_baslamadi_dk` | `15` | Vardiya başladıktan sonra okutma yoksa yöneticiye uyarı; 0 = kapalı |

**Doğrulama (prod):**

```bash
# 1) Beat görevi tanımlı mı?
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec beat celery -A app.celery_app inspect scheduled 2>/dev/null | head

# 2) Görev koşuyor mu (worker logu, dakikada bir):
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  logs --since 5m worker | grep -i vardiya_hatirlatma | tail
```

Hatırlatma **ileri bakar, geri bakmaz**: beat bir süre koşmadıysa geçmiş
vardiyalar için telafi bildirimi gönderilmez (kaçırılan vardiya ayrıca
`vardiya_baslamadi` ile yakalanır).
