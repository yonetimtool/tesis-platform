# Mobil (Flutter) — Notlar

> Bu dosya depoda yoktu; mobil ekibin §10 bulgusuna backend cevabini kayit altina
> almak icin olusturuldu. Mobil ekip kendi README'sini eklerken bu bolumu koruyup
> icine alabilir.

## 10. Bulgu: aktif turda okutulan noktalarin listesi sunucudan alinamiyor

Mobil ekip bulgusu (onemli): "aktif turumda HANGI noktalari okuttum" listesi
sunucudan alinamiyordu — `/dashboard/live` ve `/patrol-windows` yalniz SAYI
veriyor (okutulan/beklenen), `/scans` yalniz POST. Gecici cozum cihazda yerel
kayitti (zayif: cihaz verisi silinirse kaybolur, baska elemanin okutmasi
gorunmez). Onerilen uc: `GET /me/patrol-window`.

### CEVAP (DEV-A / backend) — cozuldu: `GET /me/patrol-window` yayinda (main, `7f9c448`)

Yerel kayit cozumunu sokebilirsiniz; onerdiginiz semaya sadik kalindi, birkac
ekleme var:

- **Sekil:** `{ generated_at, window, checkpoints, windows }`. `window` +
  `checkpoints` onerdiginiz sade yapi; ek olarak `windows[]` TUM aktif
  pencereleri doner (birden cok plan ayni anda aktif olabildigi icin, her biri
  kendi checkpoint listesiyle, `pencere_bitis` ASC). `window` = bitisi en yakin
  aktif pencere. Tek pencereli kullanim icin `window`/`checkpoints` yeterli.
- **Aktif pencere yoksa:** `window: null` + bos listeler, **200** (hata degil) —
  retry/hata akisi kurmayin.
- **`okutuldu` pencere-geneli:** baska elemanin okutmasi da gorunur
  (scheduler'in "tamamlandi" mantigiyla ayni eslesme). `okutma_zamani` /
  `okutan_user_id` penceredeki **ilk** scan'den; checkpoint alanlari:
  `checkpoint_id, ad, sira, okutuldu, okutma_zamani?, okutan_user_id?`
  (alan adlari onerdiginiz gibi).
- **RBAC:** admin + security (cleaning/resident 403). Detay:
  `contracts/openapi.yaml` → `/me/patrol-window` ve `contracts/README.md` →
  "Aktif devriye durumu (me/patrol-window)".
