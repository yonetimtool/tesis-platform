# NTAG424 DNA (SDM/SUN) kripto doğrulaması — tasarım

**Tarih:** 2026-07-03 · **Sahip:** DEV-A (backend) · **Durum:** Onaylandı (kullanıcı: yaklaşım A,
migration ve `imza_dogrulandi` girişinin kaldırılması — üçüne de evet)

## Amaç

`POST /scans`'teki `imza_dogrulandi` bugün istemci beyanı (`scans.py`: "gercek kripto
dogrulama bu promptta YOK"). Bu tasarımla değer yalnız **sunucu tarafında**, NTAG424 DNA
etiketinin SDM/SUN (Secure Dynamic Messaging) çıktısının kriptografik doğrulamasıyla
belirlenir. Sahte okutma (UID kopyalama) ve tekrar oynatma (replay) engellenir.

## Kapsam / kapsam dışı

- **Kapsam:** doğrulama çekirdeği, anahtar saklama + kayıt ucu, `POST /scans` entegrasyonu,
  sözleşme değişiklikleri, testler.
- **Kapsam dışı:** etiketin fiziksel provisioning'i (anahtarın taga yazılması — saha/mobil işi),
  mobil uygulama değişiklikleri, EV2 mutual authentication.

## Seçilen yaklaşım (A)

SDM/SUN sunucu doğrulaması, checkpoint-başına anahtar. Etiket her okumada şifreli PICC
verisi (UID + 3 baytlık okuma sayacı) + CMAC üretir; mobil bu ham veriyi `/scans` gövdesine
ekler; sunucu çözer ve doğrular. Alternatifler (B: AN10922 UID diversifikasyonu — provisioning'e
katı bağ, tenant izolasyonu zayıf; C: mock iskelet — işi ertelemek) reddedildi.

## Bileşenler

### 1) Kripto çekirdeği — `backend/app/nfc_sdm.py`

Saf, IO'suz fonksiyonlar (NXP AN12196'ya göre):

```
verify_sdm(key: bytes, expected_uid: str, picc_data_hex: str, cmac_hex: str,
           son_sayac: int) -> SdmResult
# SdmResult: ok: bool, sayac: int | None, neden: Literal["ok","cmac","uid","format","replay"]
```

- **PICCData çözümü:** AES-128-CBC (IV=0) ile 16 baytlık `ENCPICCData` çözülür;
  ilk bayt tag `0xC7` (UID + sayaç aynalı), ardından UID(7B) + SDMReadCtr(3B, LE).
- **CMAC doğrulaması:** oturum anahtarı `SV2 = 3CC3 0001 0080 || UID || SDMReadCtr`
  üzerinden `KSes = AES-CMAC(K, SV2)`; `SDMMAC = AES-CMAC(KSes, "")`'in tek indisli
  baytları (8B). Sabit-zaman karşılaştırma (`hmac.compare_digest`).
- **UID eşleşmesi:** çözülen UID, checkpoint'in `nfc_tag_uid` değeriyle eşleşmeli
  (hex, büyük/küçük harf duyarsız).
- **Sayaç monotonluğu:** `sayac > son_sayac` değilse `replay`.
- Bağımlılık: `cryptography` paketi (`requirements.txt`'e eklenir — AES + CMAC).
- Anahtar şifreleme yardımcıları aynı modülde: `encrypt_key/decrypt_key` — AES-GCM,
  env `SDM_KEK` (32+ karakter; `config.py`'ye `sdm_kek` alanı, jwt_secret deseniyle).

### 2) Veri modeli — migration (onaylı tablo değişikliği)

`checkpoint` tablosuna iki kolon (yeni tablo YOK):

| Kolon | Tip | Açıklama |
|---|---|---|
| `sdm_key_sifreli` | `TEXT NULL` | AES-128 etiket anahtarı, `SDM_KEK` ile AES-GCM şifreli (base64). NULL = SDM provision edilmemiş. |
| `sdm_son_sayac` | `BIGINT NOT NULL DEFAULT 0` | Kabul edilen en büyük okuma sayacı (replay koruması). |

Migration `/contracts/db/migrations` altına eklenir; RLS politikaları tablo bazlı olduğundan
değişiklik gerektirmez. Anahtar düz metin saklanmaz: DB dökümü tek başına anahtar sızdırmaz.

### 3) Anahtar kaydı — `PUT /checkpoints/{id}/sdm-key`

- **RBAC:** yalnız admin. Body: `{ "key": "<32 hex>" }` (AES-128).
- Sunucu şifreleyip `sdm_key_sifreli`'ye yazar, `sdm_son_sayac`'ı 0'a çeker
  (yeni anahtar = yeni/yeniden provision edilmiş etiket varsayımı).
- Anahtar HİÇBİR response'ta geri dönmez. `CheckpointOut`'a `sdm_aktif: bool`
  (kolon NULL mu değil mi) eklenir; liste/detay uçları bunu döner.
- Silme: `{ "key": null }` ile SDM kapatılır (kolon NULL'lanır).

### 4) `POST /scans` entegrasyonu

`ScanCreate`'e opsiyonel iki alan: `sdm_picc_data` (32 hex) + `sdm_cmac` (16 hex).
`imza_dogrulandi` gövde alanı **DEPRECATED ve YOK SAYILIR** (sözleşmede işaretlenir;
eski mobil sürümler kırılmaz, alan etkisizleşir). Karar tablosu:

| Checkpoint anahtarı | SDM alanları | Sonuç |
|---|---|---|
| yok | yok/var | kayıt `imza_dogrulandi=false` (geçiş dönemi; bugünkü davranış) |
| var | yok | kayıt `imza_dogrulandi=false` (zorlama YOK — v1'de tenant ayarıyla zorlanabilir, şimdilik YAGNI) |
| var | var, geçersiz (CMAC/UID/format) | **422 `invalid_signature`** — kayıt oluşmaz |
| var | var, sayaç ≤ `sdm_son_sayac` | **422 `replay_detected`** — kayıt oluşmaz |
| var | var, geçerli | kayıt `imza_dogrulandi=true`; sayaç güncellenir |

- **Sayaç güncelleme (yarış güvenli):** `UPDATE checkpoint SET sdm_son_sayac = :ctr
  WHERE id = :id AND sdm_son_sayac < :ctr`; etkilenen satır 0 ise eşzamanlı yarışta
  kaybedilmiştir → `replay_detected`. Scan insert ile aynı transaction'da.
- **Idempotency etkileşimi (kritik sıra değişikliği):** aynı `Idempotency-Key` ile tekrar
  gönderimde sayaç zaten ilerlediği için doğrulama tekrarı yanlış `replay_detected` üretir.
  Yeni sıra: (1) `idempotency_key` ile mevcut kayıt SELECT — varsa gövde karşılaştır
  (200/409), SDM doğrulaması ATLANIR; (2) yoksa SDM doğrula + insert; insert'te unique
  ihlali olursa (eşzamanlı yarış) mevcut idempotent yol çalışır. Not: bugünkü kod önce
  insert deneyip ihlalde karşılaştırıyor; SELECT-önce sırası buna eşdeğer davranışı korur,
  SAVEPOINT'li insert yarış için yine kalır.
- `_same_request` karşılaştırmasından `imza_dogrulandi` çıkar (artık türetilmiş değer);
  yerine `sdm_picc_data`/`sdm_cmac` karşılaştırmaya girer.

### 5) Sözleşme değişiklikleri (/contracts)

- `openapi.yaml`: `ScanCreate`'e `sdm_picc_data`/`sdm_cmac`; `imza_dogrulandi`'ya
  `deprecated: true` + açıklama ("sunucu hesaplar, girdi yok sayılır"); `/scans` 422
  açıklamasına `invalid_signature`/`replay_detected`; `PUT /checkpoints/{id}/sdm-key`
  path'i; `Checkpoint` şemasına `sdm_aktif`.
- `auth.md`: `PUT /checkpoints/{id}/sdm-key` matris satırı (yalnız admin ✅).
- `contracts/README.md` + `backend/README.md`: SDM bölümü (davranış tablosu + KEK notu).
- DB migration (bkz. §2) — kullanıcı onaylı.

## Hata yönetimi

- Hata zarfı mevcut desen: `{ "error": { "code": "...", "message": "..." } }` —
  yeni kodlar `invalid_signature`, `replay_detected` (ikisi de 422, `APIError` ile).
- `SDM_KEK` yapılandırılmamışken anahtar kaydı denenirse: **500 `config_error`**
  (açık mesajla) — anahtar YAZMA reddedilir; scan doğrulaması anahtarsız davranışa
  (false) düşmez, çünkü anahtar zaten yazılamamıştır.
- Hex parse hataları `format` → `invalid_signature` (ayrıntı sızdırılmaz).

## Test stratejisi (TDD)

1. **Birim (`tests/test_nfc_sdm.py`):** NXP AN12196 yayınlı test vektörleriyle
   `verify_sdm` (geçerli; bozuk CMAC; yanlış UID; sayaç replay; bozuk hex/format).
   AES-GCM anahtar şifrele/çöz gidiş-dönüşü.
2. **API (`tests/test_scans_sdm.py`):** anahtar kaydı (admin 200; security/cleaning/
   resident 403; tenant izolasyonu; response'ta anahtar yok; `sdm_aktif` görünür);
   scans karar tablosunun her satırı; idempotent tekrar 200 (replay sanılmaz);
   sayaç güncellenmesi; yeni anahtar yazınca sayaç sıfırlanması.
3. **Mevcut 144 test PASS kalır.** Bilinen tek temas: `test_scans.py:58`
   `imza_dogrulandi is False` — yeni davranışta da false (sdm verisi yok), değişiklik
   gerekmez. `_same_request` değişikliği idempotency testleriyle doğrulanır.

## Riskler / notlar

- SDM'in `SDMMAC` girdisi provisioning konfigürasyonuna göre değişebilir (örn.
  `SDMMACInputOffset`). v0 varsayımı: MAC yalnız SV2-türevli oturum anahtarıyla boş
  mesaj üzerinden (AN12196 örnek konfigürasyonu — UID+CTR aynalı, ENCPICCData'lı).
  Provisioning talimatı README'ye yazılır; farklı konfigürasyon gerekirse çekirdek
  fonksiyon parametrik genişletilir.
- Mobil ekip `sdm_picc_data`/`sdm_cmac` alanlarını gönderecek şekilde NDEF okumayı
  eklemeli — sözleşme + README notu ile duyurulur (mobile/README.md desenine uygun).
- `SDM_KEK` rotasyonu v0 kapsam dışı (tek KEK; rotasyon gerekirse yeniden şifreleme
  script'i sonraki iş).
