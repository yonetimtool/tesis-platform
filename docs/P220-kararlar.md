# P220 — Kararlar

> Beş bölüm, her biri ayrı commit. Bu belge her bölüm bittikçe büyüyor.

---

## §1 — Şikâyet sayısı: görünür sayı ile eşik sayacı ayrıldı

### Önce ölçtüm, tahmin etmedim

Kusurun nerede olduğunu bulmak için gerçek akışı sürdüm: şikâyet
oluşturdum, pencereyi 24 saate ayarladım, sonra kaydı 48 saat geriye
alıp (**silmeden**) dört ayrı yanıtı ölçtüm.

| Ölçüm | Taze | 48 saat eski | Değerlendirme |
|---|---|---|---|
| yönetim `complaint_count` | 1 | **0** | ✓ P219'da pencereye bağlanmış |
| yönetim `/density.acik_sayisi` | 1 | **0** | ✓ |
| **sakin `benim_acik_sayisi`** | 1 | **1** | ✗ **KUSUR** |
| **sakin `benim_sikayetim`** | true | **true** | ✗ **KUSUR** |
| `/mine` toplamı | 1 | 1 | ✓ (bilinçli — aşağıda) |
| liste toplamı | 1 | 1 | ✓ (görünürlük filtresi, veri silme değil) |

**Kusur tam olarak buydu:** P219 haritanın penceresini `complaint_count`
için kurmuş, sakinin **kendi** sayımını atlamıştı. Aynı ızgarada,
haritadan düşmüş bir şikâyet sakinin hücresinde görünmeye devam
ediyordu — kullanıcının bildirdiği şeyin birebir kaynağı.

İronik olan: P219'un `building-map` içindeki notu *"iki uç aynı haritayı
besliyor ve birinde filtreleyip ötekinde filtrelememek, aynı ekranda iki
farklı sayı göstermek olurdu"* diyor. Gerekçe doğru yazılmış, **bir sütun
atlanmış**.

### Web'de aynı sorun var mı — kontrol edildi

**Yok.** `admin-web` dashboard'ı hücre durumunu `complaint_count`'tan
türetiyor (`(u.complaint_count ?? 0) > 0`), o da pencereye bağlı.
`benim_acik_sayisi` yalnız `resident` rolüne dönüyor ve web yüzeyi
yöneticiye/admin'e/denetçiye açık — orada resident haritası **yok**.
Yani kusur mobil-özel.

### Karar: iki sayı kodda ve arayüzde **adlandırılarak** ayrıldı

Kullanıcının istediği ayrım artık üç yerde yazılı:

| Sayı | Nerede | Penceresi | Sorusu |
|---|---|---|---|
| **(a) görünür şikâyet sayısı** | `/density.acik_sayisi`, `/building-map.complaint_count`, `/building-map.benim_acik_sayisi` | `tenant.sikayet_harita_saat` (24 saat) | "**şu anda** nerede sorun var" |
| **(b) eşik sayacı** | `gurultu_akisi.acik_gurultu_sayisi()` → `esik_kontrol()` | `tenant.gurultu_pencere_gun` (30 gün) | "uyarı gönderilmeli mi" |

(b) istemciye **hiç gelmez** ve (a) değiştiğinde **değişmez**.

Ayrım `unit_complaints.py` modül başlığında ve mobil
`building_map_models.dart` alan yorumlarında yazılı. İki yönde de
kusur üretir:

- **(b)'yi (a)'ya bağlamak** → 24 saat sonra sayaç sıfırlanır, 5 şikâyete
  hiçbir zaman ulaşılamaz, **sesli uyarı hiç gitmez**. Ve uyarı
  gitmemesi sessizdir — aylar sonra fark edilir.
- **(a)'yı (b)'ye bağlamak** → harita 30 gün kırmızı kalır ve "hiç olmuş
  mu" sorusunu yanıtlamaya döner (P219'da düzeltilen kusur).

### Yöneticinin ayarlarına dokunulmadı

`sikayet_harita_saat`, `gurultu_esigi`, `gurultu_pencere_gun`,
`gurultu_susma_gun` — hiçbiri değişmedi. Testler bu değerleri
**okuyor**, sabit varsaymıyor.

### `/mine` bilerek filtrelenmedi

Sakinin kendi açtığı şikâyet, haritadan düştükten sonra da **onun
kaydıdır**. Gizlemek "şikâyetim kayboldu" demek olurdu ve sakin aynı
şikâyeti tekrar açmaya çalışıp spam korumasına takılırdı. P219 notu da
bunu açıkça kapsam dışı bırakmış.

Ana ekrandaki "Gürültü Şikâyeti" sayacı bu uçtan besleniyor ve o **(a)
değil**: "benim açık şikâyetlerim", haritanın "şu anda nerede sorun var"
sorusundan farklı bir soru.

### Ölçtüklerim

1. **Kusur** — 48 saat eskitilmiş şikâyette sakinin işareti düşmüyordu.
2. **Düzeltme** — aynı akış: işaret `true → false`, sayı `1 → 0`.
3. **Eşik sayacı bozulmadı** — harita penceresi 1 saatken, 3 saat eski
   5 şikâyetle **gerçek uçtan** son şikâyet açıldı ve `unit_uyari`
   satırı doğdu. Yani sesli uyarı hâlâ gidiyor.
4. **Veri silinmedi** — pencere dışı şikâyet tabloda ve `/mine`'da
   duruyor.
5. **Pencere `0` = süresiz** — küçük sitelerde iki sayım da eski
   şikâyeti görüyor.

### Kilitleri kırarak doğruladım

- Düzeltmeyi geri aldım → 3 test kırmızı.
- Eşik sayacını harita penceresine bağladım → `test_ESIK_UYARISI_HALA_URETILIYOR`
  kırmızı. (İlk kırma denemem `pencere_gun=0` idi ve **geçti** — çünkü
  0 "sınırsız" demek; yanlış kırmaydı, düzelttim.)

### Yan bulgu: ölçülen bir test flake'i — ve kaynağı

Hedefli koşumlar sırasında `test_SUSMA_SURESINDE_ikinci_uyari_GITMEZ`
**bir kez** düştü. Tek başına, kendi dosyasında, iki dosyalık ve üç
dosyalık kombinasyonlarda **geçti**; dördüncü denemede yakalandı.

Kaynağı buldum: üç test `tenant.gurultu_susma_gun`'ü `0` yapıp **geri
almıyordu** (`test_gurultu_caydirici.py` bir, `test_p212_gurultu_eskalasyon.py`
sekiz yerde). Veritabanı pytest koşumları arasında **kalıcı** olduğu
için, susmayı kapatan bir koşumdan sonraki koşum onu kapalı buluyor ve
susma testi düşüyor.

Belirtisi sinsi: **kod doğru, test doğru, sıra yanlış.**

**Ayarı yok saymak yerine geri almayı seçtim.** Testin meşru işi
özelliği kapatıp ölçmek; kapalı bırakması başka testlerin işi değil.
`susma_ayari_geri_al` fixture'ı değeri anlık görüntüleyip geri yazıyor.

Doğrulama: `caydirici → p212 → caydirici` sırasıyla koştum (daha önce bu
sıra flake üretiyordu) — **56 passed**.

Bu P220'nin kapsamında değildi ama düzeltmemek, kendi değişikliğimin
yeşilliğini ölçemez hâle getirirdi.

### Ölçemediklerim

- **Sesli anonsun cihazda çalması.** Ölçülen şey `unit_uyari` satırının
  doğması ve push sağlayıcısına gitmesi; dev'de `PUSH_PROVIDER=noop`.
- **Mobil ızgaranın cihazdaki görünümü** — emülatör yok. Ölçülen şey
  sunucunun döndürdüğü sayı.
