# P218 — Malik / kiracı ayrımı (DAĞITIM)

Kararlar ve gerekçeler: `docs/P218-kararlar.md`.
Ölçüm ve tasarım analizi: `docs/malik-kiraci-analiz.md`.

---

## Ne değişiyor

Kat Mülkiyeti Kanunu md. 20 gider sorumluluğunu **iki ayrı gerçeğe**
bağlıyor: işletme gideri **kullananın**, bakım/onarım gideri **malikin**.
Sistem bugüne kadar yalnızca `rol_tipi` (malik|kiracı) tutuyordu ve
**"malik ve oturan"** durumunu temsil edemiyordu.

| | önce | sonra |
|---|---|---|
| Malik oturmuyor + kiracı | çalışıyordu | çalışıyor |
| **Malik oturuyor** | **temsil edilemiyordu** (409) | işletme + bakım ikisi de ona |
| "Kim öder" ayarı | veri ve motor vardı, **arayüz yoktu** | Tanımlar ekranında |
| Tesis varsayılanı | yoktu | Tesis ayarlarında |
| Kullanıcı eklerken rol | **hiç sorulmuyordu** | üç seçenek, zorunlu |
| Hedef çözülemezse | sessizce daireye, kiracı görüyordu | önizlemede uyarı + kiracıya gösterilmiyor |

---

## İki göç

| göç | ne yapar | geri alınabilir mi |
|---|---|---|
| **0109** | `unit_resident.oturuyor` ekler; **mevcut kiracıları `true` işaretler** | evet — sütun düşer, hedefleme eski davranışına döner |
| **0110** | `tenant.varsayilan_hedef_kurali` ekler (mevcut enum yeniden kullanılır) | evet |

**Mevcut davranış birebir korunuyor:** göç sonrası malik ve rolsüz bağlar
`false` kalıyor; `hedef_sec`in "kullanan" kuralı bugün de kiracıyı
seçiyordu. Dev'de ölçüldü: `malik/f: 3, kiraci/t: 2, rolsüz/f: 1`.

---

## Dağıtım

```bash
cd infra
git pull

# Göç ZİNCİRİ: migrate imajı da yenilenmeli (backend/ imaja gömülü).
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  build migrate api admin-web worker

docker compose -f docker-compose.prod.yml --env-file .env.prod \
  up -d --force-recreate migrate api admin-web worker
```

---

## Doğrulama

### 1) Göçler uygulandı mı?

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "\d unit_resident" | grep oturuyor
#   beklenen: oturuyor | boolean | not null | false

docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "\d tenant" | grep varsayilan_hedef_kurali
```

### 2) Mevcut veri doğru taşındı mı?

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "SELECT rol_tipi, oturuyor, count(*) FROM unit_resident
    WHERE bitis IS NULL GROUP BY 1,2 ORDER BY 1,2;"
```

Beklenen: **`kiraci` satırlarının tamamı `oturuyor = t`**; `malik` ve
rolsüz satırlar `f`. `kiraci` + `f` kombinasyonu **çıkmamalı** — çıkarsa
göç yarım kalmıştır (`0109`'u yeniden koşun).

> Not: `malik/f` satırları normaldir. "Oturuyor mu" bilgisi onlar için
> **bilinmiyor** ve varsaymak bakım giderini yanlış kişiye yazdırabilirdi.
> Yönetici bu daireleri düzelttikçe `malik ve oturan` işaretlenecek.

### 3) Hedefleme çalışıyor mu? (uçtan uca)

Bir daire seçip (malik + kiracı kayıtlı olan) iki tahakkuk kesin:

```bash
# İşletme gideri türü (Kullanan öder) ile bir tahakkuk -> KİRACIYA
# Bakım gideri türü (Malik öder) ile bir tahakkuk       -> MALİĞE
```

Borçlandırmalar listesinde **kişi sütunu** artık `Ad (Sıfat)` biçiminde;
kimin hangi sıfatla borçlandığı ekrandan okunuyor.

### 4) Ekranlar

| ekran | ne görünmeli |
|---|---|
| **Tanımlar > Gelir/Gider türleri** | Yeni alan: **"Borç kime yazılır"** + altında KMK md. 20 ipucu |
| **Tesis ayarları** | **"Yeni gider türlerinde borç kime yazılsın"** |
| **Kullanıcılar > Yeni** (daire seçince) | **"Dairedeki sıfatı"**: Malik (oturmuyor) / Kiracı / Malik ve oturan — **zorunlu** |
| **Daire paneli > Sakin ekle** | Aynı üç seçenek; listede sıfat tam adıyla |
| **Mobil > Sakinler** | Aynı üç seçenek |
| **Toplu borçlandırma önizleme** | Hedefi çözülemeyen daire varsa **uyarı + daire numaraları** |

---

## Dağıtımdan sonra yapılacak (ürün işi, acil değil)

1. **Tesis varsayılanını ayarlayın.** Site her şeyi malige yazıyorsa
   *Tesis ayarları > Yeni gider türlerinde borç kime yazılsın* → **Malik
   öder**. Bu yalnızca **yeni** türleri etkiler; mevcut türlere
   dokunmaz (bilerek — çalışan bir kurulumu değiştirmek istenmez).

2. **Mevcut gider türlerini gözden geçirin.** Hepsi bugüne kadar
   `kiraci_oncelikli` (kullanan öder) ile doğdu. Bakım/onarım türlerini
   *Malik öder* yapmak isteyebilirsiniz. Referans tablo:
   `docs/P218-kararlar.md` → "KMK md. 20 gider eşlemesi".

3. **"Malik ve oturan" daireleri işaretleyin.** Göç, malik bağlarını
   `oturuyor = false` bıraktı (bilinmiyor). Malikin oturduğu dairelerde
   sıfatı **Malik ve oturan** yapın — yoksa o dairelerde işletme gideri
   "son çare" olarak yine malige yazılır (sonuç aynı), ama
   **kiracı geldiğinde** ayrım doğru çalışsın diye kayıt doğru olmalı.

4. **Hedefi çözülemeyen daireler.** Toplu borçlandırma önizlemesi bunları
   listeliyor. Genellikle **malik kayıtlı değildir**; daire kayıtlarını
   tamamlayınca borç doğru kişiye gider.

---

## Geri alma

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  run --rm --entrypoint sh migrate -c \
  "alembic -c /contracts/db/alembic.ini downgrade 0108_kamera_gecmis_kayit"
```

Sonra bir önceki imaja dönün. Hedefleme eski (kiracı öncelikli)
davranışına döner; **veri kaybı yok** — `oturuyor` bilgisi silinir,
`rol_tipi` olduğu gibi kalır.

---

## Ölçemediğim

- **Prod'a erişimim yok**; buradaki her ölçüm dev ortamında yapıldı.
  Göç çift yönlü doğrulandı ama **sizin verinizde** `kiraci` + `oturuyor
  = f` satırı kalıp kalmadığını 2. adımda siz göreceksiniz.
- **Gerçek sitede** hangi giderin kime yazıldığını bilmiyorum; eşleme
  tablosu KMK metnine dayanıyor ve **zorlayıcı değil**.
- Mobil sakinler ekranındaki yeni seçeneği **cihazda sürmedim** (widget
  testi ve `flutter analyze` yeşil).
