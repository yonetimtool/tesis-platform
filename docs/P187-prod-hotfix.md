# P187 — Prod hotfix: bağlantı sızıntısı + kayıt/daire kilitleri

Prod'da üç canlı sorun; ikisi akışı tamamen kilitliyordu. Hepsi backend
düzeltmesiyle çözüldü (web değişikliği gerekmedi).

## 1) BAĞLANTI SIZINTISI — "idle in transaction" 90/100 (ACİL)

### Kök neden
`backend/app/tasks.py`'deki üç **async** Celery görevi (`gurultu_kuyrugu`,
`mesaj_kuyrugu` her 60 sn beat ile; `rapor_uret` istek üzerine) her çağrıda
`asyncio.run(...)` ile **YENİ bir event loop** açıp kapatıyordu. asyncpg
bağlantıları oluşturuldukları event loop'a **bağlıdır**; loop kapanınca havuzda
kalan bağlantılar **ölü loop'a** bağlı olur, temiz kapatılamaz ve PostgreSQL
tarafında **"idle in transaction"** olarak birikir. Beat her dakika 2 async
görev tetiklediği için slotlar saatler içinde `max_connections=100`'e dolup
tabloları da kilitliyordu. (Geliştirmede yaşanan "PG slot tükenmesi" ile aynı
sınıf: bağlantı temiz kapatılmıyor.)

Not: scheduler/retention/notify görevleri **sync psycopg** (`with
psycopg.connect(...)`) kullanır — bağlam yöneticisiyle kapanır, sızdırmaz.
Sızıntı yalnız async engine (app_rw) + asyncio.run-per-görev deseninden.

### Düzeltme (üç katman)
1. **`tasks.py` — `_async_calistir` yardımcısı:** her async görevi kendi
   loop'unda koşar ve **loop kapanmadan `engine.dispose()`** çağırır →
   bağlantılar temiz kapanır, sonraki görev taze açar. Üç görev buna geçirildi.
2. **`db.py` — engine seviyesi savunma:** `connect_args.server_settings`'e
   `idle_in_transaction_session_timeout=60000` (60 sn) + `pool_recycle=1800`
   eklendi (yeni config: `db_idle_tx_timeout_ms`, `db_pool_recycle`).
   `pool_pre_ping` zaten açıktı.
3. **Göç 0074 — rol seviyesi savunma:** `ALTER ROLE app_rw/app_ro SET
   idle_in_transaction_session_timeout = '60s'` (koşullu DO bloğu; `app_ro`
   her ortamda yok). Böylece **sync psycopg bağlantıları da** kapsanır ve
   sızıntı olsa bile PG slotu 60 sn'de geri verir → havuz **kendini iyileştirir**.

### Neden 60 sn güvenli
Normal istek ms sürer. En uzun meşru "idle in transaction" boşluk davetin
senkron SMTP/SMS çağrısıdır (~18 sn) — 60 sn'nin rahatça altında (Excel
içe-aktarımda bile satır-başı boşluk < 60 sn). Yalnız SMTP/SMS **askıda
kalırsa** (>60 sn) işlem öldürülür; bu da doğru davranış (sızıntıdansa iyidir).

### Havuz matematiği
`db_pool_size=5 + db_max_overflow=5 = 10/işlem`. API `uvicorn --workers
${API_WORKERS:-1}` (varsayılan 1 → 10). Worker (celery prefork): dispose ile
görev sonrası ~0 kalıcı bağlantı. Beat: yalnız zamanlama, ihmal edilebilir.
Toplam `max_connections=100` altında. `API_WORKERS` artırılırsa formül:
`API_WORKERS×10 + worker_peak + ~2 ≤ 100`.

### İzleme
```sql
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
```
Düzeltmeden sonra "idle in transaction" birikmemeli; birikse bile 60 sn'de düşer.

## 2) tesis-olustur → 422 telefon required (kayıt kilidi)

`POST /auth/kayit/tesis-olustur` bu üç SSO "yeni tesis" yolu içindir; SSO kimliği
telefon vermez ve web SSO akışı telefon toplamaz (yalnız `{tesis_ad, ad,
baglama_jetonu}` gönderir). P185'te akış yeniden kurulurken telefon **formdan
çıktı ama şemada zorunlu kaldı** → 422, yönetici kaydı tamamlanamıyordu.

**Karar:** telefon **şemadan zorunluluğu kaldırıldı** (opsiyonel). Gerekçe: SSO
yöneticisi telefonla değil SSO ile girer; telefon giriş anahtarı değildir;
`app_user.telefon` zaten nullable. `TesisOlusturRequest.telefon` opsiyonel;
endpoint verilirse normalize + benzersizlik yapar, verilmezse atlar; hız sınırı
telefon yoksa **sosyal kimlik subject'ine** dayanır. Parola yolu (`yonetici-
basvuru`) telefonu zaten topluyor, dokunulmadı. openapi `required`'dan çıkarıldı.

## 3) GET /units?limit=1000 → 422 (site sakini eklenemiyor)

Yeni kullanıcı formundaki BLOK→DAİRE seçici tüm daireleri tek çağrıda ister
(`limit=1000`) ama uç `le=200` ile sınırlıydı → 422 → daire listesi boş → sakin
eklenemiyordu. `list_units` limit tavanı **200 → 1000** çıkarıldı (istemciyle
uyumlu; 1000 pratikte her konut sitesini kapsar). openapi `/units` için iç
parametre (max 1000) ile güncellendi (ortak `Limit` bileşeni 200'de kaldı).

## Test
Backend hedefli: tesis-olustur (telefon opsiyonel dahil) + units + yapı
yönetimi + sakin ödeme **53 geçti**; tam takım koşuldu (commit mesajı). Sızıntı
düzeltmesi çalışma-zamanı davranışıdır (birim testiyle doğrulanamaz); kod
doğruluğu + mevcut testlerin bozulmaması + göç uygulanması doğrulandı.

## Dağıtım
`docker compose build migrate api worker` → migrate (göç 0074) → api/worker/beat
yeniden başlat. Göç `idle_in_transaction_session_timeout`'u rol seviyesinde
kalıcı yazar; engine `connect_args` bunu async engine'e ayrıca uygular.
