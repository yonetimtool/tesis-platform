# P192 — Dağıtım notları

Kararlar ve gerekçeler: `docs/P192-kararlar.md`.
Uçtan uca test yol haritası: `docs/P192-test-yolharitasi.md`.

---

## 1. Göçler (sırayla, 0083 → 0087)

| Göç | Ne yapar | Geri alınabilir mi |
|---|---|---|
| `0083_tek_defter` | `finansal_hareket`e ödeme alanları; `hareket_durum`a `iptal`; mevcut `dues_payment` + manuel `budget_entry` satırlarını deftere taşır; kasasız tesislere **Merkez Kasa** açar; `payment_tenant_by_ref` artık deftere bakar | **Evet** — taşınan satırlar `goc_kaynak`/`kaynak_id` taşır, `downgrade()` tam olarak onları siler |
| `0084_banka_hesabi_ve_onay` | `bank_transaction.kasa_id` | Evet |
| `0085_tahakkuk_kalemleri` | `dues_assessment`: `kalem_tipi`, `ters_kayit_id`, `kaynak_assessment_id`, `iptal_edildi`; tekillik indeksi **kalem-farkındalı** oldu; `unit.arsa_payi`; `tenant.gecikme_uygula` | Evet (faiz ve ters kayıt satırları silinir — gerekçe göç başlığında) |
| `0086_otomasyon` | `aidat_plani`, `hatirlatma_ayari`, `duzenli_gider`, `otomasyon_gunlugu` + 4 bildirim tipi | Evet (enum değerleri kalır — Postgres düşürmez) |
| `0087_butce_hedefi` | `butce_hedefi` | Evet |

Beşi de dev'de **downgrade → upgrade** ile sürüldü.

### Dikkat: 0083 veri taşır

Prod'da gerçek finansal veri olmadığı bilgisiyle yazıldı. Yine de göçten
**önce yedek alın** (`infra/backup.sh`). Taşınan satır sayısını göçten
sonra doğrulayın:

```sql
SELECT goc_kaynak, count(*) FROM finansal_hareket
WHERE goc_kaynak IS NOT NULL GROUP BY 1;
```

`dues_payment` ve `budget_entry` **silinmez**, yalnız yazılmaz olur.

---

## 2. Dağıtım komutu

`beat` **zorunlu**: yeni `scheduler.finans_otomasyonu` görevi yalnız beat
imajında yaşıyor. Kısmi bir build (`migrate api admin-web worker`) onu
atlar ve otomasyon **hiç koşmaz** — `api` ve `worker` güncel görünürken.

```bash
cd infra
docker compose build migrate api admin-web worker beat
docker compose run --rm migrate
docker compose up -d
```

Ya da argümansız: `docker compose up -d --build` (hepsini kapsar).

---

## 3. Dağıtım sonrası doğrulama

```bash
# 1) Göç başı
docker compose run --rm --entrypoint sh migrate -c "cd /contracts/db && alembic current"
#    -> 0087_butce_hedefi

# 2) Beat programı yeni görevi tanıyor mu
docker compose exec beat python -c \
  "from app.celery_app import celery_app; print('finans-otomasyonu' in celery_app.conf.beat_schedule)"
#    -> True

# 3) Worker yeni modülleri yükleyebiliyor mu
docker compose exec worker python -c "import app.otomasyon, app.gecikme; print('ok')"
```

Otomasyon her gün **06:00 (Europe/Istanbul)** koşar. Elle tetiklemek için:

```bash
docker compose exec worker python -c \
  "from app.tasks import finans_otomasyonu; print(finans_otomasyonu())"
```

Görev **idempotenttir**: elle tetiklemek bir şeyi tekrarlamaz.

---

## 4. Yöneticinin dağıtımdan sonra yapması gerekenler

Otomasyonların hiçbiri kendiliğinden **açılmaz** — bu bilinçli: sistem
kimseye sormadan borç yazmaya ya da bildirim göndermeye başlamamalı.

1. **Kasa/banka hesabı**: Finans → Kasalar. Banka hesabı için `banka_mi`
   ve IBAN girin (banka tahsilatı o hesaba yazılır).
2. **Aidat planı**: Finans → Otomasyon → *Yeni plan*. Tutar, tahakkuk
   günü, vade, önizleme günü.
3. **Borç hatırlatma**: aynı sayfada *Etkin* kutusu (varsayılan **kapalı**).
4. **Gecikme faizi**: Finans → Borçlandırmalar → *Gecikme faizi* kartı.
   Oran ve *Gecikme faizi uygula* anahtarı (varsayılan açık, oran 0).
5. **Düzenli giderler**: kapıcı maaşı, asansör bakımı, sigorta.
6. **Bütçe hedefleri**: Finans → Bütçe (sapma tablosu için gerekli).
7. **Arsa payları**: Daireler ekranında, yalnız arsa payına göre dağıtım
   kullanılacaksa.

---

## 5. Davranış değişimleri (istemci tarafını etkileyenler)

* `GET /dues/payments` artık **vezne tahsilatlarını da** döndürüyor (tek
  defter). Aidat listesi eskisinden daha dolu görünecek — kayıp veri
  değil, daha önce görünmeyen tahsilatlar.
* `DuesPayment.unit_id`, `kaydeden_user_id`, `idempotency_key`
  **opsiyonelleşti**. Mobil model bunları zorunlu okuyorsa güncellenmeli
  (mobil tarafta değişiklik gerekmedi; alanlar zaten nullable okunuyordu).
* `DELETE /budget/entries/{id}` hâlâ 204 döner ama satırı **silmez**,
  ters kayıt yazar.
* Kasa bakiyesi artık **onay bekleyen** hareketleri saymıyor. Dağıtımdan
  sonra bazı kasa bakiyeleri **yükselmiş** görünebilir — düzeltilen budur.
* `POST /banka/eslestir` artık `cikis` yönlü satırları da işliyor
  (onay bekleyen gider). Daha önce `manuel_inceleme`de bekliyorlardı.

---

## 6. Geri alma

```bash
docker compose run --rm --entrypoint sh migrate -c \
  "cd /contracts/db && alembic downgrade 0082_cihaz_kimligi"
```

Ardından kodu bir önceki sürüme döndürün. 0083'ün `downgrade()`i taşınan
satırları siler; `dues_payment` ve `budget_entry` yerinde durduğu için
eski kod eski verisini bulur. **Göçten sonra yazılmış** yeni tahsilatlar
eski tablolarda olmayacaktır — bu yüzden geri alma yalnızca dağıtımdan
kısa süre sonra anlamlıdır.
