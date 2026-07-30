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

**Sonuç (ilk kez ölçüldü): backend `app/` kapsamı %72** — ama **bu sayı da
yanlıştı.** Üçüncü tuzak:

### ÜÇÜNCÜ TUZAK: ölçüm aracının kendisi async gövdeleri kaçırıyordu

Sayıyı yayınladıktan sonra doğruladım (bu programın kuralı: ölçüm de ölçülür) ve
tutarsızlık buldum: `residents.py` **%31** görünüyordu, oysa o router'ın beş ucu
7 testle sürülüyor. Kanıt zinciri:

1. Yalnız `test_residents.py` koşuldu → aynı %31, eksik satırlar `57-115`
   (yani `create_resident`'ın tüm gövdesi).
2. `uvloop` şüphesi → `--loop asyncio` ile de aynı.
3. Rota gerçekten o fonksiyon mu? `app.routes` incelendi: `POST /residents` →
   `app.routers.residents`, satır 46. Evet.
4. Dosya konteynerde farklı mı? `md5sum` host = konteyner. Hayır.
5. **Uvicorn erişim günlüğü:** `"POST /residents HTTP/1.1" 201 Created`. Yani
   gövde KESİNLİKLE çalıştı ama kapsanmamış görünüyordu.
6. Aynı dosyanın **GET** gövdesi (125-155) kapsanmış görünüyordu — yani hata
   dosya bazlı değil, **çağrı bazlı** ve tutarsız.

Sebep: coverage'ın **varsayılan C izleyicisi** bu kurulumda async uç
gövdelerini güvenilmez şekilde izliyor. Python 3.12'nin `sys.monitoring`
çekirdeği (`COVERAGE_CORE=sysmon`) ile aynı 7 test `residents.py`'yi
**%31 → %92** yapıyor.

> Yani "%72" ve ondan çıkardığım "en düşük router'lar" listesi **geçersizdi**.
> Bu, aynı belgede belgelediğim hata sınıfının üçüncü örneği: ölçüm yapıyor
> görünen ama yanlış olan bir sayı — ve bu kez tuzak **ölçüm aracının
> kendisindeydi**.

Doğru komut:

```
COVERAGE_CORE=sysmon coverage run --source=app -m uvicorn app.main:app --port 8001 &
API_URL=http://127.0.0.1:8001 pytest -q
coverage report
```

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
2. **Backend kapsamının DÜŞÜK bölgeleri.** İlk sayı (%72) ve ondan çıkan hedef
   liste **geçersizdi** (yukarıdaki üçüncü tuzak). Doğru çekirdekle yeniden
   ölçüldü; hedef liste o sayılara göre çıkarılacak. Zamanlayıcı/Celery
   dosyaları sunucu sürecinde hiç koşmuyor — onların ölçümü yine ayrı bir yol
   gerektiriyor.
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
