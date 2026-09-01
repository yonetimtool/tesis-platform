# P193 — dağıtım notları

Bu tur `docs/yonetici-kurulum-rehberi.md` sonundaki **14 eksik**
listesini kapatıyor. Sekiz bölüm, on iki commit, hepsi `main`de.

> **Panel de dağıtılmalı.** Bu turda `admin-web` içinde `middleware.ts`
> değişti (yeni korumalı sayfa) ve üç yeni BFF rotası eklendi. Yalnız
> `api` kurmak, panelin yeni ekranlarını 404'e düşürür.

---

## 1. Göç

**Tek göç: `0088_tesis_adresi`** (tenant adres alanları).

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml run --rm migrate
```

- `tenant` tablosuna dört sütun ekler: `adres`, `ilce`, `il`,
  `posta_kodu` (hepsi NULL edilebilir) + `posta_kodu` için beş haneli
  CHECK.
- **Geri alınabilir**: `downgrade -1` → `upgrade head` dev'de koşuldu.
- Veri kaybı riski yok: yalnız ekleme yapar, var olan satırlara
  dokunmaz.

Şema sürümü kontrolü: API açılışta `Sema surumu uyumlu: 0088_tesis_adresi`
yazar.

---

## 2. Dağıtım sırası

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build \
  migrate api admin-web worker
docker compose -f docker-compose.yml -f docker-compose.prod.yml run --rm migrate
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d \
  api admin-web worker
```

`worker`/`beat` bu turda değişmedi ama `api` ile aynı imajı paylaştığı
için birlikte kurulmalı (kısmi build göç zinciri hatasına yol açar).

---

## 3. Yeni uçlar

| Uç | Rol | Ne yapar |
|---|---|---|
| `PATCH /units/arsa-payi` | admin + yönetici | Daire başına farklı arsa payını tek istekte yazar |
| `GET /units/arsa-payi-ozeti` | admin + yönetici | Toplam + eksik giriş sayısı |
| `POST /users/odeme-kodlari` | admin + yönetici | Sakinlerin havale kodları; **eksik olanları üretir** |

Rol matrisi kilidi (`backend/tests/yetki/rol-matrisi.txt`) güncellendi.

## 4. Değişen yanıtlar (uyumlu, kırıcı değil)

- `GET /kurulum`: **8 adım → 13 adım**; adımlara `zorunlu`, yanıta
  `zorunlu_toplam` / `eksik_zorunlular` / `calisir` eklendi. Eski panel
  yeni yanıtla çalışmaya devam eder (ek alanları görmezden gelir).
- `GET/PATCH /tenant/settings`: `adres`, `ilce`, `il`, `posta_kodu`.
- `GET /users/{id}`: `bildirim_eposta/sms/mobil`, `eposta_dogrulandi`,
  `mobil_cihaz_sayisi`, `odeme_kodu` (hepsi salt okunur).
- `GET /dues/assessments`: `iptal_edildi`.
- `POST /ice-aktarim/*`: istekte `sorunlulari_atla`, yanıtta
  `uygulanmadi`, `guncellenen`, `davet_gonderildi`, `davet_basarisiz`,
  `davet_hatalari`.
- `POST /units/bulk`: `arsa_payi`, `metrekare`.
- `PATCH /units/toplu`: `arsa_payi`, `metrekare`.

## 5. Davranış değişiklikleri — DİKKAT

Bunlar bilinçli ve rehberde yazılı, ama prod'da fark edilir:

1. **Excel'de kişi aktarımında e-posta artık ZORUNLU.** E-postasız satır
   hata verir. Eskiden geçen bir dosya artık geçmeyebilir.
2. **Sorunlu satır varsa hiçbir şey yazılmaz.** Eski davranış "geçerli
   olanları yaz, sorunluları raporla"ydı. Yeni varsayılan "hiç yazma";
   kullanıcı **"Sorunlu satırları atla"**yı işaretlerse eski davranışa
   döner.
3. **Daire aktarımı var olan daireyi artık günceller** (yalnız
   `arsa_payi` / `metrekare` verilmişse). Eskiden koşulsuz atlanıyordu.
4. **Kurulum sihirbazı 13 adım gösterir** ve daha önce %100 görünen bir
   tesis artık eksik adım gösterebilir (kasa, e-posta, adres…). Veri
   kaybı değil, ölçüm genişledi.
5. **E-posta adımı ENV'deki genel SMTP'yi de sayar.** Tesisin kendi SMTP
   ayarı yoksa ama ENV'de çalışan bir sağlayıcı varsa adım **tamam**
   görünür — ölçüt Mesajlar ekranındaki rozetle aynı.

## 6. Prod'da doğrulanması gerekenler

Dev ortamında **SMTP yok**; e-postaya bağlı her şey orada ölçülemedi:

- [ ] Excel'den kişi aktarımı sonrası **davet gerçekten gidiyor mu**
      (`davet_gonderildi` > 0). Dev'de 0/2 çıktı, sebebi SMTP'nin
      olmaması.
- [ ] Kurulum sihirbazında **E-posta gönderimi** adımı `tamam` görünüyor
      mu (prod'da SMTP çalıştığı için görünmeli).
- [ ] Mesajlar → **test gönderimi** başarılı dönüyor mu.
- [ ] Tesis adresi girildikten sonra **makbuz PDF**'inde adres satırı
      (dev'de PDF'e çizildiği ölçüldü; prod'da gerçek bir tahsilat
      makbuzuyla bakın).
- [ ] **Rapor PDF** başlığındaki adres satırı (kod yolu makbuzla aynı,
      ama rapor çıktısı render edilip görülmedi).
- [ ] Gerçek `.xlsx` dosyasıyla yükleme (dosya ayrıştırma panelde;
      testler yapıştırılan/yapılandırılmış satırlarla ölçüldü).
- [ ] Tarayıcıda menüde **Yönetim → Tesis ayarları** satırının yönetici
      hesabında göründüğü.

## 7. Geri alma

Kod tarafı: bir önceki commit'e dönüp `api` + `admin-web` yeniden
kurmak yeterli. Göç geri alınmak istenirse:

```bash
docker compose ... run --rm migrate \
  alembic -c /contracts/db/alembic.ini downgrade 0087_butce_hedefi
```

Adres alanları silinir; başka hiçbir veri etkilenmez. Yeni uçlar
kaybolur, panel eski hâline döndüğü için onları çağırmaz.
