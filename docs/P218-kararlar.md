# P218 — Malik / kiracı ayrımı (uygulama)

Analiz ve ölçümler: `docs/malik-kiraci-analiz.md`. Onaylanan kararlar
uygulanıyor; aşağıdakiler **uygulama** notlarıdır.

Onay özeti: hepsi tek turda · `oturuyor` bayrağı · tek alan üç seçenek ·
tanımdan varsayılan + formda ezme · tenant varsayılanı zorlayıcı değil ·
eşleme öneri niteliğinde · B4 düzeltilecek · malik oturuyorken kiracı da
olabilir.

---

## §A — Veri modeli ve hedefleme çekirdeği

### `unit_resident.oturuyor` (göç 0109)

Mülkiyet ile kullanım **ayrı iki alanda**. `rol_tipi`ye üçüncü değer
eklemek "malikler" sorgusunu iki değeri birden aramaya zorlardı ve
unutulduğu yerde sessizce yanlış çalışırdı.

**Mevcut veri:** `kiraci` olan bağlar `true`, malik ve rolsüz bağlar
`false`. Bu **bugünkü davranışı birebir korur** — `hedef_sec`in kullanan
kuralı bugün de kiracıyı seçiyordu. Ölçüldü: göç sonrası
`malik/f: 3, kiraci/t: 2, rolsüz/f: 1`. Çift yönlü doğrulandı
(downgrade → upgrade, veri korundu).

### `hedef_sec`: "kiracı öncelikli" → "oturan öncelikli"

Sıra artık **OTURAN → kiracı → malik → belirsiz**.

**`kiracilar` adımı bilerek korundu:** göç uygulanmamış ya da yarım
kalmış veride `oturuyor` hepsinde `false` olur; o durumda eski davranış
(kiracıya yaz) geçerli kalır ve borç sessizce yanlış kişiye gitmez. Bu
ayrıca testle kilitli.

**Enum değeri değişmedi:** `kiraci_oncelikli` dizesi veritabanında aynı
kaldı, yalnızca **anlamı** genişledi ("kiracı" değil "oturan"). Değeri
değiştirmek göç + tüm satırların yeniden yazılması demekti ve kazancı
yalnızca bir isimdi; arayüzde görünen etiket zaten çeviriden geliyor.

### `oturuyor_coz` — tek kural, iki yazma yolu

`/residents` ve `/units/{id}/residents` ayrı dosyalarda; aynı varsayımı
iki kez yazmak birinin değişip ötekinin kalması demekti:

- değer **açıkça verilmişse** o geçerli,
- verilmemişse **kiracı → `true`** (kiracı tanımı gereği oturur; ayrıca
  sormak yöneticiye bilgi değeri olmayan bir soru sormaktı),
- malik ve rolsüz → `false` ("bilinmiyor"u "oturuyor" saymak, işletme
  giderini oturmayan malige yazardı).

**Güncellemede özel kural:** rol `malik`e çevrilirken `oturuyor` **korunur**
— oturan bir malikin rolü düzeltildiğinde "oturmuyor" hâline düşmesi,
bakım giderini ona yazmayı sürdürürken işletme giderini başkasına
kaydırırdı.

### `tenant.varsayilan_hedef_kurali` (göç 0110)

Yeni gelir/gider tanımlarının başlangıç değeri. **Mevcut tanımlara
dokunulmuyor:** çalışan bir sitenin geçmiş kurulumunu değiştirmek,
kimsenin istemediği bir davranış değişimi olurdu. Mevcut
`borc_hedef_kurali` enum'u yeniden kullanıldı — aynı kavramın ikinci bir
tipi olsaydı ikisi zamanla ayrışırdı.

### Uçtan uca ölçüm

Üç durum da gerçek uçlarla sürüldü:

| durum | işletme gideri (`kullanan`) | bakım gideri (`malik`) |
|---|---|---|
| Malik oturmuyor + kiracı | **kiracı** | **malik** |
| **Malik oturuyor** | **malik-oturan** | **malik-oturan** |
| Yalnız oturmayan malik | malik (son çare) | malik |

Üçüncü durum eskiden **temsil edilemiyordu**; artık kasıtlı çalışıyor.

**Ürün kararı (onaylandı):** malik oturuyorken kiracı da eklenebilir —
engellenmiyor. Malik bir odayı kiraya vermiş olabilir; devir döneminde
ikisi bir arada görünebilir.

### Testler

`test_borclandirma_cekirdek.py` +3 (oturan önceliği, devir dönemi, göç
öncesi veri), `test_p218_malik_kiraci.py` 8 (üç durum + varsayılanlar +
sınırlar). İlgili takımlar: 70 geçti.

---

## §B — Arayüz: tek alan, üç seçenek

Üç yüzeyde de **aynı soru**: kullanıcı ekleme (`/users`), daire paneli
(`UnitDetail`), mobil sakinler ekranı. Üç yüzeyin farklı soru sorması
bugünkü tutarsızlığın kaynağıydı — daire panelinde iki seçenek vardı,
kullanıcı ekleme ekranında **hiç sorulmuyordu**.

| arayüzde | veride |
|---|---|
| Malik (oturmuyor) | `rol_tipi=malik`, `oturuyor=false` |
| Kiracı | `rol_tipi=kiraci`, `oturuyor=true` |
| **Malik ve oturan** | `rol_tipi=malik`, `oturuyor=true` |

Eşleme **tek yerde** (`SIFAT_VERISI`): formun üç yerinde aynı eşleme
yazılsaydı biri değişip ötekiler kalırdı.

### Kullanıcı ekleme ekranı

- Alan **daire seçilince** görünür (daire yoksa sıfat da yok).
- **Zorunlu ve varsayılansız.** Yanlış bir varsayılan sessizce yanlış
  veri üretir: herkesi "malik" saymak işletme giderini oturmayan malige
  yazdırırdı. Yönetici bilerek seçsin.
- Kritik düzeltme: bu ekran daire atarken **rol hiç göndermiyordu** ve
  bağlar rolsüz doğuyordu (analizin B2 boşluğu).

### Daire paneli

Sakin listesinde sıfat **tam adıyla** yazıyor. Önceden yalnız `rol_tipi`
gösteriliyordu ve "malik" yazan bir satırın oturup oturmadığı ekrandan
okunamıyordu.

### Mobil

Aynı üç seçenek, aynı eşleme. `residents_api` `oturuyor` alanını taşıyor.

### Testler

`p218-daire-sifati.dom.test.ts` (6): alan daire seçilmeden görünmez, üç
seçenek sunar, varsayılan seçili değildir, ve **üç sıfat da doğru iki
alana çevriliyor** — gönderilen gövde okunarak. Kilit kırılarak
doğrulandı (malik-oturan'ı `false` yapınca ilgili test düştü).
