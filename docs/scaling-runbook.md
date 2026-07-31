# Ölçek runbook'u (P39)

> **Bu belge ölçülmüş sayılar içerir, hedef değil.** Sayılar tek bir
> geliştirme makinesinde (8 çekirdek; `api`, `db`, `redis` **ve** yük
> üreticisi aynı kutuda) alındı. Prod'da veritabanı ayrı bir makinede
> olacağı için mutlak değerler değişir — **oranlar ve darboğaz sırası**
> taşınabilir olandır.

## 1. Yük takımı

```bash
# Tam profil (giriş + ana ekran demeti + akış + aidat + okutma)
docker compose -f infra/docker-compose.yml -f infra/docker-compose.load.yml \
  run --rm -e VUS=10 -e SURE=30s -e NFC=<seed-nfc-uid> k6 run /load/senaryo.js

# Tek uç (darboğaz çerçevede mi sorguda mı?)
docker compose -f infra/docker-compose.yml -f infra/docker-compose.load.yml \
  run --rm -e VUS=20 -e SURE=15s -e YOL=/activity?limit=20 k6 run /load/tekil.js
```

k6 **konteynerden** koşar (host'a kurulum yok) ve `api` ile **aynı ağdadır**:
ölçüme internet gecikmesi girmez. `load` profili altındadır — normal
`docker compose up` ile **başlamaz**.

Senaryo, "en çok çağrılan uçlar"ı değil **kullanıcının gününü** temsil eder:
giriş günde bir kez (bu yüzden `setup()`ta bir kez), ana ekran demeti bir
kaç kez, akış kaydırma, aidat, okutma. `Idempotency-Key` her yinelemede
**farklıdır** — aynı anahtarı tekrarlamak yazma yolunu değil idempotent
dönüş yolunu ölçerdi.

## 2. Ölçülen taban (2026-07-31)

**Tek uç, 20 eşzamanlı kullanıcı, düşünme süresi yok:**

| Uç | RPS | p50 | p95 |
|---|---:|---:|---:|
| `GET /me` | **283** | 63 ms | 100 ms |
| `GET /dashboard/live` | **177** | 103 ms | 155 ms |
| `GET /activity?limit=20` | **168** | 110 ms | 167 ms |

**Karma profil, 10 eşzamanlı kullanıcı, 1 sn düşünme süresi:**

| Ölçüm | 1 işçi | 4 işçi |
|---|---:|---:|
| ana ekran demeti p95 (3 isteğin toplamı) | 2.08 s → **1.35 s** | **1.26 s** |
| `/activity` p95 | 397 ms | 236 ms |
| `/scans` p95 | 100 ms | 184 ms |
| toplam istek/sn | 27.6 | **29.3** |
| başarısız istek | %0 | %0 |

> İlk sütundaki 2.08 s → 1.35 s düşüşü havuzun **açıkça
> boyutlandırılmasıyla** ve ısınmayla geldi; 4 işçiye geçiş bu profilde
> yalnızca **%6** ek kazanç verdi. Yani **bu profilde darboğaz CPU değil**:
> 1 sn düşünme süresi eşzamanlılığı zaten sınırlıyor.

**Okunuş:** bir düğüm, 1 sn düşünme süreli bu profilde **~30 kullanıcı
etkileşimi/sn** taşıyor. Etkileşimler kullanıcı başına ~2 sn sürdüğünden bu,
**tek düğümde ~300 eşzamanlı aktif kullanıcı** demektir. Uygulamanın gerçek
kullanımı çok daha seyrektir (sakin günde birkaç kez açar), dolayısıyla tek
düğüm **binlerce kayıtlı kullanıcıya** rahatlıkla yeter.

## 3. Bulunanlar ve yapılanlar

### 3.1 Havuz ve işçi sayısı ARTIK AÇIK (düzeltildi)

Önceden `create_async_engine` varsayılanlarla çağrılıyordu (havuz 5 + taşma
10) ve `uvicorn` tek işçiyle sabitti. Tehlike varsayılanların kendisi değil,
**görünmez olmalarıydı**: çok işçiye geçen ilk kişi

```
toplam bağlantı = API_WORKERS × (DB_POOL_SIZE + DB_MAX_OVERFLOW)
```

formülünü hiç görmeden `--workers 8` yazsaydı **8 × 15 = 120 > 100**
(`max_connections`) olur ve sistem yük altında `too many clients` ile
düşerdi. Artık üçü de env'dir (`API_WORKERS`, `DB_POOL_SIZE`,
`DB_MAX_OVERFLOW`), varsayılanlar **1 / 5 / 5**'tir ve `pool_timeout=10 sn`
konuldu: **sonsuz bekleme, yük altında isteği sessizce asılı bırakırdı** —
istemci kendi zaman aşımına kadar bekler, yeniden dener ve yük **katlanır**.

**Boyutlandırma kuralı:** `API_WORKERS × 10 + 20` (worker/beat/migrate payı)
`max_connections`ın altında kalmalı. 100 ile: `API_WORKERS ≤ 8`. Bunun
üstüne çıkılacaksa **PgBouncer** (transaction pooling) gelmeli — ama RLS
`SET LOCAL app.current_tenant_id` kullandığı için pooler **transaction**
modunda olmalı, `session` modunda değil.

### 3.2 Önbellek EKLENMEDİ — ve nedeni ölçümdür

Kapsam "sıcak sayaçlar için kısa TTL'li önbellek" diyordu. Ölçüm bunu
**gerektirmedi**: 20 eşzamanlı kullanıcıda en ağır uç bile p95 **167 ms** ve
168 RPS veriyor. Bu sayılarda önbellek, kazandırdığı milisaniyeden çok
**bayat veri sınıfı bir hata türü** getirirdi (pano sayacı 5 sn geriden
gelir, kullanıcı "kaydettim ama görünmüyor" der). Önbellek, ölçüm bir ucu
**tek başına** darboğaz gösterdiğinde eklenmeli — o gün geldiğinde ilk aday
`/dashboard/live` sayaçlarıdır.

Not: `/activity` ve `/dashboard/live` zaten tur 77–78'de optimize edildi
(LIMIT dallara itildi, hacim kapsamı tüm şemaya çıkarıldı). Bu turda o
sınıfta yeni bir bulgu **çıkmadı**.

### 3.3 Giriş ~400 ms — ve bu KASITLIDIR

`POST /auth/login` p50 ~390 ms. Neredeyse tamamı **bcrypt**tir ve
düşürülmesi güvenlik açısından yanlış olurdu. Yük takımı bu yüzden giriş
yapmayı `setup()`a taşır: her yinelemede giriş yapmak, ölçümü parola
hash'leme maliyetiyle doldurup **gerçek kullanımı yanlış temsil ederdi**
(kullanıcı günde bir kez giriş yapar).

## 4. Yatay ölçek hazırlığı — denetim

| Konu | Durum | Not |
|---|---|---|
| `api` durumsuz mu? | **Evet** | Süreç içi durum yok; oturum Redis'te, dosyalar MinIO'da. Çoğaltılabilir. |
| Oturum/token | **Paylaşımlı** | Erişim jetonu imzalı (durumsuz); **refresh** Redis'te (`refresh:valid:*`, `refresh:fam:*`) — tüm düğümler aynı Redis'i görmeli. |
| Dosyalar | **Paylaşımlı** | MinIO; API dosyayı taşımaz, presign eder. Yerel disk bağımlılığı yok. |
| `worker` (celery) | **Çoğaltılabilir** | Görevler idempotent yazılmıştır (`ON CONFLICT DO NOTHING`, `dedup_key`, deneme sayacı). |
| `beat` | **TEK ÖRNEK OLMALI** | İki beat = her işin iki kez kuyruklanması. Bugün compose'da tek örnek; çok düğümde **yalnız bir düğümde** çalıştırılmalı (ya da bir kilit eklenmeli). Bu, ölçeklemeden önce kararlaştırılacak **tek gerçek engeldir**. |
| Zamanlanmış işlerin yarışı | **Güvenli** | Pencere üretimi `ON CONFLICT DO NOTHING`; kaçırılan tur bildirimi kısmî tekillikle; gecikme alarmı `dedup_key = tip:pencere:adım`. İki koşum çift bildirim üretmez. |
| RLS | **Uyumlu** | Bağlam bağlantı değil **transaction** kapsamlıdır (`SET LOCAL`), bu yüzden havuz paylaşımı güvenlidir; pooler kullanılacaksa **transaction** modu şart. |
| DB bağlantı tavanı | **Formülle** | §3.1. |

## 5. Büyüme yolu

1. **Bugün (tek düğüm, compose).** `API_WORKERS=4`, `DB_POOL_SIZE=5`,
   `DB_MAX_OVERFLOW=5`. Ölçülen: ~30 etkileşim/sn, ~300 eşzamanlı aktif
   kullanıcı, %0 hata.
2. **Dikey (aynı makine, daha çok çekirdek).** `API_WORKERS`ı çekirdek
   sayısına kadar çıkar; §3.1 tavanını aşma. Beklenen kazanç bu profilde
   sınırlı (ölçüldü: %6) çünkü darboğaz düşünme süresidir; CPU'ya bağlı bir
   profilde (rapor üretimi, PDF) kazanç daha büyük olur.
3. **Veritabanını ayır.** İlk gerçek sıçrama budur: `db` kendi makinesine
   taşınır, `max_connections` ve `shared_buffers` oraya göre ayarlanır.
   Uygulama tarafında **hiçbir kod değişikliği gerekmez** (DSN env).
4. **API'yi çoğalt.** `api` servisini N kopya + önünde Caddy/LB. Şartlar:
   ortak Redis, ortak MinIO, `beat` **yalnız bir düğümde**. Bağlantı tavanı
   artık `N × API_WORKERS × 10`.
5. **PgBouncer (transaction modu).** Bağlantı sayısı tavanı zorladığında.
   RLS `SET LOCAL` kullandığı için transaction modu güvenlidir; session
   modu bağlamı düğümler arasında sızdırırdı.
6. **Okuma çoğaltması.** Rapor/pano okumaları replikaya alınabilir —
   ama **önce** ölçülmeli: bu turda okuma darboğazı çıkmadı.

**Mikroservis yok.** Ölçüm, tek uygulamanın bu profilde rahat çalıştığını
gösteriyor; hizmet bölmek bugün yalnızca dağıtık işlem ve ağ gecikmesi
sınıfında yeni hata türleri eklerdi.

## 6. Regresyon kontrolü

Yük takımı eşikleri **hedef değil taban**dır: `http_req_failed < %1`,
`sure_home p95 < 1.5 sn`, `sure_activity p95 < 1.5 sn`. Bunların altına
düşülürse bir regresyon vardır. Takım CI'da koşacaksa `VUS=10 SURE=30s`
yeterlidir (~1 dk).

İlgili: `infra/load/senaryo.js`, `infra/load/tekil.js`,
`infra/docker-compose.load.yml`, `docs/MASTER-PLAN.md` → P39.
