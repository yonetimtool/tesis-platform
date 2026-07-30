# Ölçülmeyen durumlar — dördüncü envanter (tur 68)

**Tarih:** 2026-07-30 · **Kapsam:** sözleşme + backend + panel + ölçüm araçlarının kendisi

Üçüncü envanterin (tur 62) A–F maddeleri tur 63–67'de **kapatıldı** (tek kalan:
gerçek cihazda kare bütçesi). Bu belge, o kapanıştan sonra kalanları listeler.

Bu turda bilinçli olarak **hiç bakılmamış yerlere** baktım: sözleşme dosyası,
backend'in kendi kapsamı, panelin birim kapsamı, ve ölçüm araçlarının kendi
durumu. Üç maddenin hepsi ölçümle bulundu.

---

## A. SÖZLEŞME SAPMASI — hiçbir şey kontrol etmiyordu ✔ **KAPANDI (tur 68)**

`contracts/openapi.yaml` bu projede **sözleşmedir**: mobil domain testleri ona
atıf yapıyor ("bkz. `contracts/openapi.yaml`"), panel tipleri ona göre yazıldı.
Ama **uygulamanın sözleşmeye uyduğunu kontrol eden hiçbir test yoktu.**

Ölçüm: FastAPI **133** yol sunuyor, sözleşme **119** yol tanımlıyordu.

İlk karşılaştırma **63 sapma** gösterdi — ama çoğu parametre **adı** farkıydı
(`/assets/{asset_id}` vs `/assets/{id}`), sözleşme farkı değil. Normalizasyondan
sonra gerçek sayı: **14 yol belgelenmemiş**, ters yönde (ölü belge) **0**.

Belgelenmemiş olanlar tek tek uçlar değil, **tüm modüllerdi**:

| Modül | Yollar |
|---|---|
| Destek (platform) | `/support`, `/support/all`, `/support/{id}` |
| Şeffaflık panosu | `/transparency`, `/transparency/{ay}`, `/transparency/{ay}/publish` |
| Oturum sahibi | `/me`, `/me/avatar`, `/me/checkpoints` |
| Diğer | `/audit`, `/admin/overview`, `/users/{id}/avatar`, `/shifts/{id}/assignments`, `/health` |

**Kapatma:** 14 yol sözleşmeye eklendi ve
`backend/tests/test_sozlesme_sapmasi.py` iki yönü de kilitledi (belgelenmemiş uç
**ve** ölü belge). Ayrıştırıcının gerçekten yol bulduğunu doğrulayan üçüncü bir
test de var — boş küme dönseydi diğer ikisi sessizce geçerdi.

## B. BACKEND ve PANEL KAPSAMI hiç ölçülmemişti ✔ **ÖLÇÜLDÜ (tur 68)**

Bu program 30+ turdur mobil kapsamı takip ediyor (%67,7 → %75,0). Ama:

* **backend**: 763 test var, kapsam **hiç ölçülmedi** — `pytest-cov` kurulu
  bile değildi.
* **panel**: 105 birim test var, kapsam **hiç ölçülmedi** —
  `@vitest/coverage-v8` kurulu değildi.

İkisi de kuruldu. **Backend'de ikinci bir ölçüm tuzağı çıktı:** bu projenin
backend testleri **canlı sunucuya HTTP ile** gidiyor (bkz.
`conftest.py`'daki `client` fixture'ı). Yani `pytest --cov=app` yalnızca **test
sürecini** ölçer — istek işleme ayrı bir uvicorn sürecinde olduğu için
router'lar hiç sayılmaz. İlk koşumu 30+ dakika bekledikten sonra bunu fark edip
**kestim**: yanlış şeyi ölçen bir sayı yayınlamak, ölçmemekten kötüdür. Doğru
yol sunucu sürecini örneklemek:

```
coverage run --source=app -m uvicorn app.main:app --port 8001 &
API_URL=http://127.0.0.1:8001 pytest -q
coverage report
```

**Sonuç (ilk kez ölçüldü): backend `app/` kapsamı %72** — 8 119 satırın
2 301'i kapsanmamış; 766 test 13:46'da geçti (araçlı sunucu suite'i ~2× yavaşlattı).

**Hiç koşmayan dört dosya** (bunlar HTTP ile değil, zamanlayıcı/Celery ile
çalışıyor; test süreci onları ayrı ayrı import ediyor ama sunucu süreci hiç
çalıştırmıyor — yani bu %0'lar "test yok" demek değil, "sunucu sürecinde
çalışmıyor" demek):

| Dosya | Kapsam |
|---|---|
| `app/retention.py` | %0 |
| `app/scheduler/service.py` | %0 |
| `app/scheduler/windows.py` | %0 |
| `app/tasks.py` (Celery) | %0 |

**En düşük gerçek router'lar:** `residents` %31, `dues` %37,
`common_areas` %42, `units` %44, `blocks` %44, `assets` %45, `tasks` %45,
`patrol_plans` %47. Bunlar D2 maddesinin hedef listesi.

Panel sonucu ise bir **payda tuzağı** ortaya çıkardı:

| Ölçüm | Sonuç |
|---|---|
| v8 varsayılanı (yalnız import edilen dosyalar) | **%95,73** (202/211 satır) |
| `all: true` (tüm kaynak dosyalar paydada) | **%26,79** (194/724 satır) |

%95,7 rakamı **yanıltıcıydı**: paydası yalnız `lib/`ydi, çünkü birim testler
`app/` ve `components/` altındaki gerçek UI'yi hiç import etmiyor. Panelin UI'si
Playwright sürüşleriyle kapsanıyor ve o sürüşler kapsam üretmiyor. Yapılandırma
`all: true` ile düzeltildi; artık rapor gerçeği söylüyor.

> Bu tam olarak bu programın var olma sebebi olan hata sınıfı: **ölçüm yapıyor
> görünen ama paydası yanlış olan bir sayı.**

## C. Ölçüm araçlarının durumu — temiz

* Panel sürüşlerinin **11'inin 11'i** `DENEY=1` ile kendini sınıyor
  (`tesis-id.mjs` bir yardımcı modül, sürüş değil).
* Mobil tarafta dedektör öz-testleri: eksen kombinasyonu (5), okuma sırası (4),
  yerleşim kilidi (3), görsel çözme (3), görsel belleği (5).
* `worker/` dizini **boş** (`.gitkeep`) — kullanılmıyor, kör nokta değil.

## D. Hâlâ ölçülmeyenler

1. **Kare bütçesi / jank.** Gerçek cihaz ya da `flutter drive` + emülatör
   gerektiriyor; süreç içinde eşdeğeri yok. (Tur 67 belleği süreç içinde
   ölçmeyi başardı; kare süresi için aynı yol yok.)
2. **Backend kapsamının DÜŞÜK bölgeleri.** Sayı alındı (%72) ve hedef liste
   çıktı: `residents` %31, `dues` %37, `common_areas` %42, `units`/`blocks` %44,
   `assets`/`tasks` %45, `patrol_plans` %47. Ayrıca zamanlayıcı/Celery dosyaları
   sunucu sürecinde hiç koşmuyor — onların ölçümü ayrı bir yol gerektiriyor.
3. **Panel UI birim kapsamı %26,8.** UI'yi Playwright sürüşleri kapsıyor ama
   *satır* düzeyinde ölçüm yok; React bileşenlerini jsdom ile test etmek ayrı
   bir altyapı kararı (bilinçli olarak yapılmamıştı — `vitest.config.ts`
   başındaki nota bakın).
4. **Prod dağıtım yolu.** `infra/*.prod`, Caddy TLS, yedekleme betiği ve
   `RUNBOOK-PROD.md` hiçbir otomatik ölçümde yok; tur 41'de prod erişimi
   kullanıcıya bırakılmıştı ve teyit edilmedi.
5. **Migrasyon geri alma (rollback).** `0002`–`0008` migrasyonları ileri yönde
   test ediliyor; geri alma yolu ölçülmedi.

## Kör nokta OLMAYANLAR (bilerek dışarıda)

* Para biçimi (TL + Türkçe gruplama) dile duyarsız — politika.
* `data/*_api.dart` düşük kapsam — sürüşler API'yi bilerek sahteliyor.
* CSV kolon başlıkları ASCII/Türkçe — makine okunur kolon kimliği.
* Piksel golden regresyonu — yerine yerleşim kilidi (tur 60).

## Öneri sırası

1. **Backend kapsamının düşük bölgeleri** (D2) — sayı artık var, hedefleme
   yapılabilir.
2. **Migrasyon geri alma** (D5) — üretimde geri dönüş yolu ölçülmemiş.
3. **Prod dağıtım yolu** (D4) — en riskli ama en zor ölçülen.
4. Kare bütçesi (D1) — ortam kurulumu gerektiriyor.
