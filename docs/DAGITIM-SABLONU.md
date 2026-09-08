# DAĞITIM NOTU ŞABLONU

> **Her yeni dağıtım belgesi bundan türer.** Kopyala, doldur, sil.
>
> Şablonun varlık sebebi tek bir tekrarlayan kusur: **kanonik komuttan
> `beat` düştü ve zamanlayıcı sessizce eski kodla çalıştı.** Üç kez
> oldu — P187 (vardiya özeti), P192 (finans otomasyonu), F8b (reklam
> bakımı). Üçünde de görev yazıldı, `api` ve `worker` yenilendi, `beat`
> atlandı, hiçbir hata görünmedi.

---

## KANONİK KOMUT — DEĞİŞTİRME, KISALTMA

```bash
git pull
docker compose -f docker-compose.prod.yml build migrate api admin-web worker beat
docker compose -f docker-compose.prod.yml up migrate
docker compose -f docker-compose.prod.yml up -d --force-recreate api admin-web worker beat
```

**Beşi de her zaman listede.** Değişmeyen bir servisi kurmak yalnızca
birkaç saniye sürer (katman önbelleği); listeden çıkarmanın bedeli ise
üç kez ölçüldü.

> **`restart` YETMEZ.** `backend/` imaja gömülüdür; kod ancak yeniden
> kurulup `--force-recreate` ile ayağa kalkan konteynerde yenilenir.
> `restart` env'i de yenilemez.

### `dukkan-web` yayındaysa

```bash
docker compose -f docker-compose.prod.yml build dukkan-web
docker compose -f docker-compose.prod.yml up -d --force-recreate dukkan-web
docker inspect -f '{{json .NetworkSettings.Networks}}' \
  $(docker compose -f docker-compose.prod.yml ps -q dukkan-web) \
  | tr ',' '\n' | grep -i tesisnet   # BOŞSA DUR (P215)
```

---

## DAĞITIM SONRASI DOĞRULAMA — ÜÇ SATIR

Sırayla; **biri kırmızıysa dur.**

### 1. Şema ile kod uyumlu mu

```bash
curl -s https://api.yonetiyor.com/health | python3 -m json.tool | head -20
```

`schema.uyumlu` **true** olmalı. `false` ise `migrate` koşmamış.

### 2. Zamanlayıcı güncel mi — **atlanmayacak adım**

```bash
curl -s https://api.yonetiyor.com/health \
  | python3 -c 'import json,sys; b=json.load(sys.stdin)["beat"]; \
print(b["durum"], b.get("kod_gorev"), "/", b.get("sozlesme_gorev"), \
b.get("yalniz_sozlesmede") or "")'
```

| Çıktı | Anlamı | Ne yapmalı |
|---|---|---|
| `uyumlu 12 / 12` | Beat güncel | Devam |
| `ayrisma 12 / 13 ['x']` | **Beat eski imajda** — `x` görevi çalışmıyor | `build beat` + `up -d --force-recreate beat` |
| `kayit_yok` | Beat hiç kalkmadı **ya da** bu kontrolün olmadığı eski imajda | Aynısı |
| `olculemedi` | `contracts` beat'e mount edilmemiş | compose'u kontrol et |

> **Neden `/health` üzerinden:** beat'in HTTP'si yok. Durumunu açılışta
> Redis'e yazıyor, `api` okuyup raporluyor. `docker compose logs beat |
> grep` de işe yarar ama **bakan biri gerekir** — üç olayın üçünde de
> kimse bakmadı.

### 3. Servisler ayakta mı

```bash
docker compose -f docker-compose.prod.yml ps
```

---

## YENİ ZAMANLANMIŞ GÖREV EKLEDİYSEN

`celery_app.conf.beat_schedule`'a görev eklemek **iki dosya** ister:

1. `backend/app/celery_app.py` — zamanlama.
2. `contracts/beat-gorevleri.txt` — manifest.

İkincisi unutulursa `test_beat_schedule.py` **kırmızı yanar** (kayıt
kilidi kalıbı; `rol-matrisi.txt` ve `openapi.yaml` ile aynı fikir).

Manifesti yeniden üretmek:

```bash
docker compose exec -T api sh -lc "cd /app && python -c \"
from app.celery_app import celery_app
from app.beat_kilidi import zamanlama_satirlari
print(chr(10).join(zamanlama_satirlari(celery_app.conf.beat_schedule)))\""
```

Manifest `contracts/` altında çünkü **orası canlı mount** — imaj eski
olsa bile depodaki hâli. Beat açılışta ikisini karşılaştırır; iki taraf
aynı imajdan gelseydi karşılaştırma anlamsız olurdu.

---

## GERİ ALMA

```bash
docker compose -f docker-compose.prod.yml run --rm --entrypoint sh migrate \
  -lc "alembic -c /contracts/db/alembic.ini downgrade <önceki-revizyon>"
git checkout <önceki-sha>
docker compose -f docker-compose.prod.yml build migrate api admin-web worker beat
docker compose -f docker-compose.prod.yml up -d --force-recreate api admin-web worker beat
```

**Geri almada da beşi birden.** Geri alırken `beat`i atlamak, ileri
giderken atlamakla aynı kusurdur — bu kez ters yönde: eski kod, yeni
zamanlama.

---

## BELGE İSKELETİ

```markdown
# DUKKAN F<n> — DAĞITIM NOTU

> Bir cümlede ne yapıldığı ve neyin bozulabileceği.

## 1. Yeni ortam değişkenleri
(yoksa "Yok." yaz — boş bırakma)

## 2. Göç
Numara, ne yaptığı, geri alınabilir mi, **veri kaybı var mı**.

## 3. Uygulama
Yukarıdaki KANONİK KOMUT. Beşi de listede.

## 4. Doğrulama
Yukarıdaki üç satır + faza özel ölçümler.
Her ölçümde **"şu çıkarsa dur"** yazılı olmalı.

## 5. Geri alma
Komut + **ne kaybolur**.

## 6. Bu fazın açık bıraktıkları
Ölçülemeyenler dâhil. Boş bırakma — "yok" da bir cevaptır.
```
