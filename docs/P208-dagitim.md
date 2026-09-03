# P208 — dağıtım notları

Sıra önemlidir: **göç → imajlar → doğrulama**.

```bash
cd /opt/yonetio/infra
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

> **Kısmi build YAPMAYIN.** `migrate api admin-web worker beat` beşi birden
> gerekiyor; argümansız `up -d --build` hepsini kapsar (P171 olayı).

Bu turda **bir yeni göç** var: `0103_gurultu_uyari_sakin` (üç tenant
ayarı + `unit_uyari.sakin_bildirildi` + iki bildirim tipi).

---

## §1 — Gürültü uyarısı

Yeni değişken yok. Varsayılanlar göçte geliyor:

| Ayar | Varsayılan | Anlamı |
|---|---|---|
| `gurultu_pencere_gun` | 30 | Şikayetlerin sayıldığı pencere; 0 = sınırsız (P37 davranışı) |
| `gurultu_susma_gun` | 7 | Uyarılan daire bu süre yeniden uyarılmaz; 0 = her eşikte uyar |
| `gurultu_sakin_uyarisi` | true | Eşik aşılınca daire sakinine bildirim |

> **DAVRANIŞ DEĞİŞİKLİĞİ:** eşik aşılınca artık **daire sakinine** de
> bildirim gidiyor ve **7 gün** boyunca tekrar uyarı gönderilmiyor.
> Eskiden ikinci beş şikayette ikinci uyarı üretiliyordu. Bir tesis eski
> davranışı isterse `gurultu_susma_gun=0` yapar.

**Doğrulama:** yönetici → Tesis ayarları → "Gürültü sayım penceresi",
"Uyarı sonrası susma süresi" ve "Daire sakinine uyarı bildirimi gönder"
alanları görünmeli. Bir daireye eşik kadar gürültü şikayeti girildiğinde
`unit_uyari` satırında `sakin_bildirildi=true` olmalı ve `audit_log`'da
`resource_type='unit_uyari'` satırı bulunmalı.

---

## §2 — Bildirim sesleri

**Yeni kanal:** `yonetio_gurultu_v1` (gürültü uyarısı, kendi sesiyle).
Kanal **uygulamada** oluşuyor → **yeni mobil sürüm gerekiyor**. Eski
sürümde bu kanal yoktur; sunucu `channel_id` gönderse de bildirim
manifest varsayılanına düşer (görünür ama sessiz).

### Ses dosyaları geldiğinde — ADIM ADIM

Şu an **iki ses de sistem sesi** (`SES_HAZIR=False`). Dosyalar geldiğinde:

1. Dosyaları koy:
   - `mobile/android/app/src/main/res/raw/yonetio_bildirim.ogg`
   - `mobile/android/app/src/main/res/raw/yonetio_gurultu.ogg`
   - `mobile/ios/Runner/yonetio_bildirim.caf`
   - `mobile/ios/Runner/yonetio_gurultu.caf` (Xcode → Runner target →
     Copy Bundle Resources)
2. `backend/app/push_kanal.py`: `SES_HAZIR = True`
3. **KANAL KİMLİKLERİNİ `_v2` YAP** — dört sabit `push_kanal.py`'de ve
   dördü `MainActivity.kt`'de:
   `yonetio_kritik_v2`, `yonetio_genel_v2`, `yonetio_sessiz_v2`,
   `yonetio_gurultu_v2`. Manifest'teki `default_notification_channel_id`
   de `yonetio_genel_v2` olmalı.

   > **NEDEN ZORUNLU:** Android'de var olan bir kanalın sesi program
   > tarafından **değiştirilemez**. Kullanıcının telefonunda kanal zaten
   > oluşmuştur; kimlik aynı kalırsa **eski (sessiz) kanal kalır** ve
   > "sesi ekledik ama çalmıyor" olur. Kimlik eşitliğini
   > `mobile/test/p207_kanal_kimlik_test.dart` kilitliyor — iki taraftan
   > birini güncellemeyi unutursanız test kırmızı olur.
4. İsteğe bağlı ama önerilir: `MainActivity`'de eski `_v1` kanallarını
   `deleteNotificationChannel` ile temizleyin — yoksa kullanıcı sistem
   ayarlarında iki kuşak kanal görür.
5. `api` yeniden dağıtımı + yeni APK/AAB.
