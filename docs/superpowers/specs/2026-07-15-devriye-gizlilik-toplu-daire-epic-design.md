# Epik: Devriye takibi + gizlilik + toplu daire + mobil edit/sil

**Tarih:** 2026-07-15
**Kapsam:** Kullanıcının tek mesajda istediği 5 özellik, 4 bağımsız parçaya bölündü.
Her parça kendi spec-detayı + testleri + commit'iyle sırayla uygulanır (küçükten
büyüğe). Bu doküman epiğin tamamını ve her parçanın tasarımını tanımlar.

## Onaylanan kararlar (kullanıcı)
- **Checkpoint tanımı:** yönetici UYGULAMADA tanımlar (yazma yetkisi yöneticiye
  açılır; şu an admin-only). Yalnız **NFC** (QR yok — tarama zaten çalışıyor).
- **Görev görünürlüğü:** KATI — görevi yalnız atanan görür; havuz/"Herkes"
  kavramı saha görünürlüğünden kalkar. Yönetim yine tümünü görür.
- **Edit/sil:** backend hazır; eksik olan **mobil UI**.

---

## Parça A — Şikayet gizliliği (F3) + Görev görünürlüğü (F4)

### A1. Daire şikayeti: yönetim complainant'ı görmesin
**Şu an:** `unit_complaints` yönetim uçları (`GET /unit-complaints` listesi,
`GET /unit-complaints/building-map` daire detayı, density) şikayet edenin
KİMLİĞİNİ döner ("denetim amacıyla"). `contracts/auth.md` + router docstring bunu
"kimlik yalnız yönetime" diye belgeliyor.

**Değişiklik:** Yönetim uçlarından **complainant kimliği kaldırılır**
(`complainant_user_id` + varsa `complainant_ad`). Yönetim yalnız şunları görür:
hedef `unit_no`, `kategori`, `tarih`, `durum`, `not` (serbest metin korunur) ve
daire başına **şikayet SAYISI/rengi**. Kim şikayet etti bilgisi hiçbir yönetim
ucunda dönmez.
- Sakinin kendi kaydı (`GET /unit-complaints/mine`) DEĞİŞMEZ (zaten kendi kaydı).
- Mobil `building_schematic_screen` daire detayında (yönetici görünümü) şikayet
  eden ad'ı gösteren alan kaldırılır.
- `contracts/auth.md` + openapi + router docstring güncellenir (artık "kimlik
  yönetime açık" DEĞİL).

### A2. Görev: yalnız atanan görür (katı)
**Şu an:** `tasks.py::_assignee_visibility(user)` saha rolüne şunu görünür kılar:
`atanan_user_id IS NULL` (havuz) VEYA `atanan_user_id IN (saha rolü kullanıcıları)`
(grup görünürlüğü). Yani bir saha çalışanı BAŞKA saha çalışanına atanmış + atanmamış
görevleri de görür.

**Değişiklik:** Saha görünürlüğü **bireysele** çekilir:
`_assignee_visibility` → yalnız `Task.atanan_user_id == user.id`. `_visible_task_or_404`
da aynı kurala göre güncellenir. Sonuç:
- Saha çalışanı YALNIZ kendine atanan görevleri görür/tamamlar.
- Atanmamış (havuz) görevler saha çalışanına GÖRÜNMEZ (yalnız yönetim görür — atar).
- Yönetim (admin/yönetici) görünürlüğü DEĞİŞMEZ (tümünü görür).
- Görev oluşturmada `atanan_user_id` yine opsiyonel kalır (yönetim atamasız
  oluşturup sonra atayabilir; atanana dek yalnız yönetim görür).

**Mobil:** `tasks_screen` saha rolünde artık "Görevlerim/Tümü (Herkes)" ayrımı
anlamsız (hep yalnız kendi) → saha rolünde sekme/çip kaldırılır, doğrudan "bana
atanan" listesi. Yönetim "Görev yönetimi" görünümü değişmez.

**Testler:** backend — saha A'ya atanan görevi saha B GÖRMEZ (404); atanmamış
görevi saha GÖRMEZ; yönetim hepsini görür. Mobil — saha rolünde toggle yok.

---

## Parça B — Toplu daire ekleme (F2)
**Şu an:** yalnız `POST /units` (tek daire). Edit/sil (`PATCH`/`DELETE /units/{id}`)
zaten var.

**Değişiklik:** Yeni `POST /units/bulk` — bir blok için çok daireyi tek seferde
üretir. Girdi: `blok` (str|null), `kat_sayisi` (int), `kat_basi_daire` (int).
- Numaralandırma B'ye başlarken netleştirilir; mevcut düzenle (`bina_duzenleme` +
  seed "A-12") tutarlı olacak — muhtemel biçim `{blok}-{kat}{sira}` (kat*10+sıra)
  veya `{blok}-{artan}`; en fazla makul üst sınır (ör. 500 daire/istek) korunur.
- Zaten var olan `unit_no`'lar atlanır (idempotent) veya çakışma raporlanır.
- RBAC: admin + yönetici (create ile aynı). Dönüş: üretilen daireler + atlananlar.

**Mobil:** `bina_duzenleme` blok detayında "Toplu daire ekle" formu (kat sayısı +
kat başına daire) → `POST /units/bulk` → izgara tazelenir.

**Testler:** N kat × M daire = N*M kayıt; çakışan no atlanır; RBAC.

---

## Parça C — Mobil edit/sil UI (F5)
**Şu an:** backend hazır (`PATCH`/`DELETE` görev, daire, sakin atama). Boşluk mobil
UI'da.

**Değişiklik (mobil, önce audit):**
- **Görev:** yönetici uygulamadan görevi DÜZENLE (PATCH: ad/tip/atanan/checkpoint/
  foto-zorunlu/aktif) + SİL (DELETE) + YENİDEN ATA. Eksikse `task_detail`/form'a
  eklenir.
- **Daire:** `bina_duzenleme`'de daire DÜZENLE (no/kat/sıra) + SİL — eksikse eklenir.
- **Sakin atama:** sakin çıkar/pasifleştir zaten var (residents ekranı); teyit.

C'ye başlarken mobil taranıp yalnız gerçek boşluklar doldurulur (var olanı bozmadan).

**Testler:** mobil widget testleri — düzenle/sil aksiyonları görünür ve API'yi çağırır.

---

## Parça D — Devriye: checkpoint tanımı + gün-gün tarama raporu (F1)
**Şu an:**
- Checkpoint CRUD var ama **admin-only** ve **yalnız admin-web'de**. NFC-only
  (`nfc_tag_uid`), QR yok.
- Tarama çalışıyor: `POST /scans` → `scan_event` (guard_id + okutma_zamani +
  checkpoint + gps). Mobil NFC + offline outbox.
- AMA tarama-düzeyi rapor YOK. Tüm takip pencere-bazlı ÖZET sayı; "kim, hangi
  noktayı, ne zaman taradı" listesi hiçbir katmanda yok. `scan_event`'in okuma ucu yok.

**Değişiklik:**
### D1. Backend
- **Checkpoint yazma yetkisi yöneticiye açılır:** `checkpoints.py::_ADMIN`
  (POST/PATCH/DELETE/sdm-key) → `require_role("admin", "yonetici")`. Okuma zaten
  tüm rollerde. (contracts + testler güncellenir.)
- **Yeni `GET /scans` (tarama raporu):** RBAC admin + yönetici. Parametre:
  `tarih=YYYY-MM-DD` (tenant timezone; o günün taramaları) — opsiyonel
  `baslangic`/`bitis` aralığı. Her satır: `id, checkpoint_id, checkpoint_ad,
  guard_id, guard_ad, okutma_zamani, gps_lat, gps_lng, imza_dogrulandi`. Sıra:
  `okutma_zamani` (o gün içinde). Yeni `ScanReportItem`/`ScanReportResponse` şeması.

### D2. Mobil ("Devriye takibi" ekranı, yönetici)
- **Checkpoint yönetimi:** ekle/düzenle/sil (ad + nfc_tag_uid + gps + aktif). Yeni
  `checkpoint_api` (list/create/update/delete). Bir sekme veya alt-ekran.
- **Gün-gün rapor:** gün seç (tarih) → `GET /scans?tarih=…` → "kim, hangi nokta,
  ne zaman" listesi (checkpoint adı + kişi adı + saat). Mevcut pencere-özet
  görünümü kalabilir; buna EK yeni sekme.

**Testler:** backend — yönetici checkpoint açar/siler (artık 200/204, admin değil);
`GET /scans` o günün taramalarını kişi+saat+nokta ile döner; RBAC (saha/resident 403).
Mobil — checkpoint yönetim UI + gün-gün liste.

---

## Sıra ve gerekçe
A (küçük, bağımsız, yüksek değer) → B (orta) → C (orta, audit) → D (en büyük).
Her parça yeşil testlerle commit + push edilir; kullanıcı arada test edebilir.

## Riskler / açık noktalar
- **B numaralandırma:** daire no biçimi B başında netleşecek (mevcut düzene uyum).
- **F4 havuz:** atanmamış görev oluşturma korunur ama saha görmez; kullanıcı "her
  görev atanmalı" derse create'te `atanan_user_id` zorunlu yapılabilir (ayrı karar).
- **D `GET /scans` isim çakışması:** `POST /scans` var; aynı path'e GET eklenir
  (REST tutarlı) — router zaten `/scans` prefix'li.
