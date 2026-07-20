# Ticketing v1 — Talep/Arıza → İş Emri (uçtan uca)

**Tarih:** 2026-07-20
**Durum:** Onaylandı (brainstorming)
**Kapsam:** `/backend` `/contracts` `/mobile` `/admin-web` `/infra(seed)`

## 1. Amaç ve strateji

Mevcut `complaint` (Şikayet/Öneri) modülünü **yerinde** bir uçtan-uca bakım/talep
(ticketing) sistemine dönüştürüyoruz. Paralel bir sistem kurulmuyor: aynı tablo, aynı
`/complaints` uçları, aynı `Complaint` şeması ve TS/Dart aynaları **repurpose** ediliyor —
sadece iç isim `complaint` olarak kalıyor (tüm yığında riskli bir yeniden adlandırmadan
kaçınmak için); **kullanıcıya görünen etiketler "Talep / Arıza" ve "İş Emri" oluyor.**

`/unit-complaints` (tam anonim daire şikayeti + yoğunluk haritası) **hiç dokunulmuyor** —
anonim kanal olarak o kalıyor.

### Anonimlik: KAPSAM DIŞI (bilinçli karar)
Talepler **her zaman kimlikli**. `acan_user_id` yönetici/atanan rollere normal serialize
edilir. `anonim` bayrağı YOK, per-talep toggle YOK, anonim sızıntı testi YOK. Gerekçe: bir
bakım/onarım talebi aksiyon alınabilir olması için bilinen bir birim/bildiren gerektirir;
hassas anonim bildirim ihtiyacı zaten `/unit-complaints`'te var (dokunulmadı).

Not: Durum geçmişi (history) satırları yine de yalnızca **actor_role** tutar, `user_id`
tutmaz — timeline için rol yeterli, kimlik geçmişe de yazılmaz.

## 2. Veri modeli (0001 yerinde düzenlenir, `down -v`)

House pattern korunur: her yeni tablo `tenant_id uuid NOT NULL REFERENCES tenant(id) ON
DELETE CASCADE`, `UNIQUE(id, tenant_id)`, `ix_<t>_tenant`, kompozit FK'ler, ve **her iki RLS
döngüsüne** (`upgrade` 1832-1869 ve `downgrade`) eklenir.

### 2.1 `complaint` tablosu değişiklikleri
- `durum` enum `complaint_durum` → **`acik | is_emri | cozuldu | reddedildi`** (varsayılan
  `acik`). Eski `inceleniyor` kaldırılır.
- `foto_key` (tekil) **kaldırılır** → `complaint_photo` alt tablosu (§2.2).
- `yonetici_yaniti`, `yanitlayan_user_id`, `yanit_zamani` **kaldırılır** → bilgi
  `complaint_status_history` içine taşınır (§2.3).
- `kategori` enum (`complaint_kategori`) **kaldırılır** → **`kategori_id`** nullable kompozit
  FK `→ task_category(id, tenant_id)` `ON DELETE SET NULL`. Talep kategorisi = dinamik görev
  kategorisi taksonomisi (elektrik/tesisat/asansör…). Tek taksonomi; dönüştürmede iş emri bu
  kategoriyi devralır. `complaint_kategori` enum'u tamamen silinir.
- `baslik` (kısa başlık) + `mesaj` (açıklama) korunur.

### 2.2 `complaint_photo` (yeni) — talep başına ≤ 3 foto
`(id, tenant_id, complaint_id, foto_key, sira, created_at)`. Kompozit FK `→ complaint(id,
tenant_id) ON DELETE CASCADE`. `foto_key` tenant-önekli. Sunucu tarafı `≤ 3` doğrulaması
create sırasında (fazlası → 422). Serializer `foto_url` (kısa ömürlü presigned GET) lazily
imzalar, storage hatasını yutar.

### 2.3 `complaint_status_history` (yeni) — timeline kaynağı
`(id, tenant_id, complaint_id, durum, actor_role, sebep NULL, created_at)`.
- **actor_role yalnızca** (`admin|yonetici|security|tesis_gorevlisi|resident`) — asla
  `user_id`.
- `sebep`: reddetme gerekçesi (zorunlu), dönüştürme notu (opsiyonel), veya doğrudan çözüm
  notu (opsiyonel).
- Her durum geçişinde bir satır yazılır. Talep oluşturulunca ilk satır (`acik`) yazılır.

### 2.4 `task` tablosu değişikliği
`ticket_id` nullable eklenir, kompozit FK `→ complaint(id, tenant_id) ON DELETE SET NULL`.
Açık bir talep → bir görev (iş emri). Görev silinse bile talep kalır (link kopar).

### 2.5 `notification_tip` enum
Ticketing geçişleri için yeni değerler eklenir (0001'de `CREATE TYPE`'a):
`talep_is_emri`, `talep_cozuldu`, `talep_reddedildi`, `is_emri_atandi`.

## 3. Durum makinesi

```
acik ──convert (yönetici)──▶ is_emri ──bağlı görev tamamlandı──▶ cozuldu
  │                                                               ▲
  ├──decline + sebep (yönetici)──▶ reddedildi                     │
  └──direct resolve (yönetici, ops. çözüm notu)──────────────────┘
```

Geçerli geçişler:
- `acik → is_emri` (dönüştür; görev oluşturur)
- `acik → reddedildi` (zorunlu `sebep`)
- `acik → cozuldu` (doğrudan çözüm; **opsiyonel çözüm notu** history satırına yazılır —
  timeline boş bir sıçrama göstermesin)
- `is_emri → cozuldu` (bağlı görev tamamlanınca otomatik)

Geçersiz her geçiş → **422 invalid_transition**. `cozuldu` ve `reddedildi` terminal; reopen
yok, `is_emri → reddedildi` yok. Her geçiş bir history satırı yazar ve açanı FCM ile bildirir.

## 4. RBAC matrisi (onaylandı)

| Aksiyon | admin | yönetici | security | tesis_görevlisi | resident |
|---|:-:|:-:|:-:|:-:|:-:|
| `POST /complaints` (talep aç) | ❌ | ❌ | ✅ | ✅ | ✅ |
| `GET` liste/detay | ✅ | ✅ | ✅° | ✅° | ✅° |
| `POST /{id}/convert` → görev | ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /{id}/resolve` (doğrudan çözüm) | ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /{id}/decline` (+sebep) | ✅ | ✅ | ❌ | ❌ | ❌ |
| bağlı görevi tamamla (oto-çözüm) | ✅ | ❌ | ✅‡ | ✅‡ | ❌ |

° yalnız kendi kayıtları · ‡ yalnız kendine atanmış görev.
Atanan (görevli/güvenlik) talep bağlamını (kategori/açıklama/fotolar/birim) **bağlı görev
üzerinden** görür, talep listesinden değil.

## 5. Fotoğraflar

- `POST /uploads/presign` + `storage.presign_get` + `_validate_foto_key` önek koruması
  yeniden kullanılır. Create'te ≤ 3 foto (`complaint_photo`) + tamamlamada 1 opsiyonel kanıt
  fotoğrafı (mevcut `task_completion.foto_key` — şema değişikliği yok, mobil UI zaten var).
- **Yeni sunucu tarafı doğrulama** (`PresignRequest` / presign ucu):
  - content-type allow-list: `{image/jpeg, image/png, image/webp, image/heic}` → dışı **422**.
    Content-type imzalı URL'e bağlanır (MinIO da uyumsuz yüklemeyi reddeder) — **airtight katman**.
  - client-declared `boyut` (byte) ~8 MB üstü presign'de reddedilir — **best-effort**
    (client doğrudan MinIO'ya PUT eder; gerçek byte doğrulaması MinIO politikası gerektirir).
    Belgede bu sınır açıkça best-effort olarak işaretlenir.
  - Tüm presign çağıranlarına uygulanır (tasks, kargo, complaints) — bugün hepsi görsel
    yüklediği için güvenli sıkılaştırma.

## 6. Dönüştür / tamamla / reddet / bildirim

FCM `scheduler/notify.py:dispatch_external(...)` yeniden kullanılır — best-effort additive,
hata orijinal yazımı bozmaz.

- **Dönüştür** (yönetici bottom-sheet: kategori onayla, öncelik `dusuk|orta|yuksek`, atanan
  `security|tesis_gorevlisi`, opsiyonel not) → bağlı `task` oluşturur (kategori devralır,
  `ticket_id` set), talep → `is_emri`, history satırı. Bildirim: **atanan** (`is_emri_atandi`)
  + **açan** (`talep_is_emri`).
- **Doğrudan çözüm** (yönetici, opsiyonel çözüm notu) → `cozuldu`, history satırı (not
  `sebep`'e). Bildirim: **açan** (`talep_cozuldu`).
- **Tamamla** (atanan; mevcut idempotent completion + opsiyonel kanıt fotoğrafı) → talep oto
  → `cozuldu`, history satırı. Bildirim: **açan** (`talep_cozuldu`).
- **Reddet** (yönetici, zorunlu `sebep`) → `reddedildi`, history satırı. Bildirim: **açan**
  (`talep_reddedildi`).

**İş emri önceliği:** Mevcut `task` modelinde öncelik alanı yok; dönüştürme öncelik topladığı
için `task`'a nullable `oncelik` enum `task_oncelik` (`dusuk|orta|yuksek`) eklenir (0001'de).
`ticket_id` NULL olan normal görevlerde `oncelik` de NULL kalabilir.

## 7. Contracts

- `contracts/openapi.yaml`: `Complaint` şeması güncellenir (durum enum, `kategori_id`,
  `fotograflar[]`, kaldırılan alanlar); yeni şemalar `ComplaintPhoto`,
  `ComplaintStatusHistory`, `ComplaintConvertRequest`, `ComplaintResolveRequest`,
  `ComplaintDeclineRequest`; yeni uçlar `POST /complaints/{id}/convert`,
  `POST /complaints/{id}/resolve`, `POST /complaints/{id}/decline`; `Task` şemasına `ticket_id`
  + `oncelik`; `PresignRequest` content-type/boyut alanları.
- `contracts/auth.md §4`: ticketing satırları (aç/oku/dönüştür/çöz/reddet/tamamla), durum
  makinesi, foto kuralları (presign footnote stilinde). Anonimlik bölümü açıkça N/A —
  `/unit-complaints`'e işaret eder.

## 8. Mobil (Flutter — `mobile/lib/src/features/complaints/`)

- **Create form** (`_ComplaintForm`): çoklu foto picker (maks 3, ilerleme; paylaşılan
  `imagePickerProvider` + presign akışı) + kategori dinamik `task_category` listesinden.
- **"Taleplerim" listesi**: durum chip renkleri **acik=amber, is_emri=blue, cozuldu=green,
  reddedildi=red**.
- **Detay**: foto galerisi (InteractiveViewer) + **dikey timeline stepper** (history:
  timestamp + rol etiketi + durum + sebep/not).
- **Yönetici**: liste durum filtresi + "İş Emrine Dönüştür" (kategori/öncelik/atanan/not) &
  "Reddet" (sebep) & "Çöz" (ops. not) bottom-sheet'leri; dönüştürülen talepte bağlı iş emri
  durumu canlı.
- **Atanan (görevli/güvenlik)**: mevcut `task_detail_screen.dart` — iş emri görevleri bağlı
  talep bilgisini (kategori/açıklama/fotolar/birim) + kanıt foto adımını gösterir (zaten var,
  ticket bağlamı eklenir).

## 9. Admin-web (Next.js — `admin-web/app/(protected)/complaints/`)

- `page.tsx`: durum kolonu + filtre (Tümü/Açık/İş Emri/Çözüldü/Reddedildi), foto küçük
  resimleri, salt-okunur bağlı iş emri referansı + durumu.
- Mutasyonlar (dönüştür/çöz/reddet) yönetici uçlarına `apiSend` + `toast` + `mutate()`; BFF
  proxy'leri `api/complaints/[id]/convert|resolve|decline/route.ts`.
- Faz-2 tasarım sistemi: `tableCardCls`, `EmptyState`, `Toast`. Dark mode yalnız
  `globals.css` üzerinden — yeni accent eklenirse oraya map.
- Durum badge renkleri mobil ile aynı kod.

## 10. Seed (`infra` / seed image)

3–4 demo talep, karışık durum:
1. `acik` — fotosuz basit talep.
2. `acik` — 2-3 fotolu talep.
3. `is_emri` — dönüştürülmüş, görev atanmış, devam eden.
4. `is_emri → cozuldu` — dönüştürülüp kanıt fotoğrafıyla tamamlanmış.

(Anonim talep yok — kaldırıldı.) api/seed image pytest/seed öncesi yeniden build edilir.

## 11. Testler (`backend/tests/`, canlı-sunucu httpx pattern)

- Durum geçişleri + **geçersiz geçiş 422** (ör. `cozuldu → *`, `is_emri → reddedildi`).
- `convert` bağlı görev oluşturur + durum `is_emri` + kategori devri + `ticket_id` set.
- Bağlı görev tamamlama talebi **oto `cozuldu`** yapar + history satırı.
- `decline` **sebep zorunlu** (boş → 422).
- `resolve` opsiyonel not history'ye yazılır.
- Foto: content-type allow-list (dışı 422) + tenant izolasyon (`_validate_foto_key`).
- Bildirim dispatch geçişlerde çağrılır (mockable seam).
- RBAC: resident convert edemez (403), atanan decline edemez (403), açan olmayan detay 404.
- Cross-tenant 404 (B tenant A'nın talep id'sini isteyince).
- **Anonimlik-sızıntı testi YOK** (kaldırıldı).

## 12. Kabul (verify path)

`backend down -v && up --build && seed && pytest` ✓ + `flutter build apk --debug` ✓ +
`flutter test` ✓ + admin-web build ✓. Uçtan uca: sakin fotolu talep açar → yönetici iş
emrine dönüştürür → atanan kanıtla tamamlar → sakin tam timeline + bildirimleri görür.

## 13. Kapsam dışı (bilinçli)

- Anonimlik / per-talep anonim toggle / anonim sızıntı testleri — kaldırıldı.
- `/unit-complaints` modülü — dokunulmadı.
- Gerçek (byte-kesin) upload boyut zorlaması — best-effort declared-size; MinIO politikası
  ayrı iş.
