# Oturum Sonuç Raporu — 2026-08-01

Bu oturumda **P51 → P87 arası 37 madde** kapandı. Aşağıda ne yapıldığı, ne
bulunduğu ve **ne yapılmadığı** var.

---

## 1. Kapılar (son ölçülen durum)

| Alan | Sonuç | Ne zaman ölçüldü |
|---|---|---|
| backend `pytest` | **1138 passed, 1 skipped, EXIT=0** (20 dk 49 sn) | P75 — tek koşum, borusuz |
| göç uyumu (`goc-uyum-dogrula.sh`) | **bulgu 0**, EXIT=0 | P76 |
| göç tersinirliği (`goc-tersinirlik.sh`) | **bulgu 0**, EXIT=0 — 28 sınır | P76 |
| admin-web `vitest` | **280 passed** (45 dosya) | P85 |
| admin-web `tsc` + `npm run build` | temiz / yeşil | P85 |
| mobile `flutter analyze` | temiz | P85 |
| mobile `flutter test` | **1559 passed** | P86 |
| mobile `flutter build apk --debug` | başarılı | P82 |

> **Kovalandı (P87).** O anomali **5 ardışık tam koşumda tekrarlamadı**.
> Bu "flake yoktu" demek **değildir** — 1/5'ten seyrek bir olay bu ölçümle
> ayırt edilemez; kaydedilen şey bir **sayı**, bir sonuç değil. Kök neden
> bulunamadı çünkü **kanıt ilk seferde yok edilmişti**: komut `| tail -1`
> ile koşmuştu ve başarısızlık listesi kaybolmuştu. Kural 6 artık
> `flutter test` için de "çıktıyı boruya sokma" diyor.

---

## 2. Bulunan gerçek kusurlar (hepsi düzeltildi)

### Sessiz başarısızlık / sessiz veri kaybı
1. **P51** — Bildirimlerde ham `fetch`: sunucu **500 dönse bile** "okundu
   olarak işaretlendi" deniyordu.
2. **P52** — **Çıkış**: istek düşerse çerezler kalıyor ama kullanıcı giriş
   ekranını görüp çıktığını sanıyordu. Ortak bilgisayarda bedeli oturum devri.
3. **P55/P56** — `Number()` → `NaN` → `null` → **alan silinir**. Altı yerde.
   En ağırı: **tanımlar sayfası `1.250` yazan yöneticiye 1,25 TL kaydediyordu**
   (bin katlık, sessiz, her daireye yazılan aidat tutarında).
4. **P57** — Mobilde Türkçe klavyeyle girilen **koordinat sessizce siliniyordu**
   (ondalık tuşu virgül, `double.tryParse` null döner).
5. **P60/P61** — Hata varken "kayıt yok" iddiası: destek, şikayet haritası
   ("3 açık şikayet" ile "açık şikayet yok" **yan yana**), bina düzenleme,
   tanımlar.
6. **P58/P59** — İkincil arama düşünce açılır liste boş kalıyor ve "kayıt yok"
   gibi okunuyordu; ad sütununda kimlik parçası (`3f2a91c8`) **ad sanılıyordu**.
7. **P65** — Aidat raporu tarayıcıdan **1.000 ardışık istek** atabiliyordu;
   sınır kondu **ve** kırpma kullanıcıya söyleniyor.

### Görünen ama yanlış bilgi
8. **P53** — Ham tel değeri **sekiz yerde** ekrandaydı; en ağırı **pano**.
9. **P66** — Denetim kaydında rol `yonetici` diye ham çiziliyordu.
10. **P47/P48/P49/P50** (önceki turlardan devam) + **P62** — koyu temada
    devrilmemiş renkler; ilki **benim eklediğim** uyarıydı.
11. **P54** — **Sekiz silme onayı** İngilizce arayüzde de Türkçe çıkıyordu.
12. **P68** — Yönetici satırlarında `key={i}` (parola yöneticisi yanlış satıra
    bağlanabilir) + gizli sabit Türkçe başlık.
13. **P63** — **Dört form denetiminin adı yoktu**; biri **tesis silme onayı**.

---

## 3. Kalıcı hale getirilenler (kilitler)

Her biri **kusuru geri koyarak** doğrulandı — yakaladığı görülmeden kilit
sayılmadı.

| Kilit | Ne tutuyor |
|---|---|
| `sessiz-fetch.test.ts` | Ham `fetch` yanıt denetimi |
| `ham-enum.test.ts` | Tel değeri ekranda (önek toleranslı — P67) |
| `hata-mesaji.test.ts` | Korumasız `String(hata)` + boş-durum çelişkisi |
| `koyu-tema.test.ts` | Devrilmemiş renk sınıfları (gerekçeli liste) |
| `erisilebilir-etiket.test.ts` | Adsız form denetimi |
| `i18n.test.ts` (+3 tarama) | `toast()`, tarayıcı diyalogları, şablon dizgeleri |
| `conftest.py` koşum kilidi | İki eşzamanlı pytest koşumu |
| `enterpolasyon_sabit_metin_test.dart` | Enterpolasyonlu dizgede sabit metin (P86) |

### Çapraz bağ zinciri (P77–P85)
İki yerde tutulan aynı gerçeğin **sessizce ayrışmasını** engeller:

1. **P77** — mobil para ↔ mobil sayı (ayırıcı kuralı)
2. **P78** — panel para ↔ panel sayı **+ iki istemcinin listeleri**
3. **P79** — panel ↔ mobil **biçimlendirme çıktısı** (yol farkı bilinçli)
4. **P80** — panel rol listesi ↔ backend `user_role`
5. **P81** — altı enum haritası ↔ backend enum'ları (istisnalar **denetimli**)
6. **P82** — mobil `UserRole` ↔ backend (bedeli en ağır: rol **ekran seçer**)
7. **P83** — panel ayar anahtarları ↔ `schemas.py` (alt küme kararı yazılı)
8. **P84** — BFF beyaz listesi ↔ `openapi.yaml` (var olan sözleşme zincirine ek)
9. **P85** — dil listeleri: panel ↔ mobil enum ↔ ARB dosyaları (**sıra dahil**)

---

## 4. Panel bileşen kapsamı

**12 → 280 test.** Kapsamı olmayan sayfa kalmadı (`integrations` sonuncusuydu,
P73). İlke baştan sona aynıydı: **hedef yüzde değil hata sınıfı.**

---

## 5. Kendi hatalarım (ölçümle yakalandı)

Bunları saklamak yerine yazıyorum, çünkü ikisi de yeşil bir suite'i yanlış
güvene çevirebilirdi:

1. **P62** — Kilit **sessizce geçiyordu**: kaçış katmanları fazlaydı, üretilen
   düzenli ifade hiçbir şeyle eşleşmiyordu. Enjekte edilen renk yakalanmayınca
   ortaya çıktı.
2. **P65** — Üst sınırı sarmalayıcının **arkasına** koymuştum: dört çağıran da
   sessizce kırpılırdı. "Sessiz kırpma yapma" kuralını tam da onu koyarken
   bozuyordum.
3. **P70** — Kilit doğrulanamadı, bu yüzden **eklenmedi**. P86'da nedeni
   bulundu ve kilit doğrulanabilir biçimde yazıldı.
4. **P74/P75** — "Suite'te 1 ERROR var" dedim; **yanlıştı**. Sebep benim
   eşzamanlı ikinci koşumumdu. Bu sırada üç kez "ölçtüm" sandığım şey ölçüm
   değildi: `ps` konteynerde **yok** (sıfır bir komut hatasıydı),
   `pytest | tail` **çıkış kodunu maskeliyor**, konteynerde **eski kod** vardı.
5. **P77** — Sanity kontrolü ilk denemede **anlamsızdı** (boş gövdeli `if`).
6. **P68** — Yazdığım testin `key={i}` ile de geçtiğini ölçtüm ve **"kararlı
   anahtar testi" diye sunmadım**.

7. **P87** — Aynı boru tuzağı mobilde de ısırdı: gördüğüm başarısızlık
   listesi `| tail -1` yüzünden kayboldu ve kök neden **bulunamaz** oldu.

**Ortak ders:** sessizlik, sıfır ve yeşil — üçü de tek başına kanıt değil.
Ve **kaybolan kanıt, olmayan kanıttan kötüdür**: insan "gördüm ama
bulamadım" diye bir şey bilmenin yükünü taşır.

---

## 6. YAPILMAYANLAR

### Bilerek yapılmadı (gerekçesi planda)
- ~~**P70** — Mobil enterpolasyonlu dizge kilidi.~~ **KAPANDI (P86).** P70'te
  bölge ölçülmüş (7 satır, yedisi de `debugPrint` → sızan metin yok) ama kilit
  üç denemede doğrulanamadığı için **commit edilmemişti**. P86'da neden
  başarısız olduğu çözüldü — **sıra**: kilit mevcut testin *içine* ekleniyordu
  ve o dosyanın süzgeçleri araya giriyordu. Ayrı bir dosyaya, **önce kendini
  test eden** bir belirteçleyiciyle yazıldı; iki ayrı enjeksiyonla doğrulandı.
- **P79** — Mobil `NumberFormat` panelin elle gruplamasıyla **birleştirilmedi**:
  iki ortamın risk profili farklı (mobilde yerel veri paketin içinde).
- **P83** — Ayarlarda **ters yön** zorlanmadı: `OPERASYON` bilinçli bir alt küme.
- **P66/P73** — `action` kodları ve `channel_type`/`auth_type` **çevrilmedi**:
  teknik terimler; çevirmek aranabilirliği ve belge eşleşmesini bozardı.

### Sende bekleyenler ([KEREM]/[DIŞ])
| Madde | Ne gerekiyor |
|---|---|
| **P2** | Prod runbook — prod yalnız sende |
| **P11** | **Cihaz doğrulama listesi — 45+ madde** birikti |
| **P12/P13** | Firebase + ödeme kimlik bilgileri |
| **P18** | Frigate pilotu |
| **P64** | **Vezne hareketinde çift kayıt riski** — ürün kararı (üç seçenek planda, önerim: `dues/payments` deseni) |
| — | `meta.total` O(tablo) sayımı — sözleşme değişikliği |

---

## 7. Nerede duruyor

- Plan: `docs/MASTER-PLAN.md` — **87 madde**, açık hash yer tutucusu yok.
- Cihaz listesi: P11 içinde, her kullanıcıya görünür değişiklik için bir madde.
- Devir notu: **STATUS REPORT #10** (P61–P65 devri) hâlâ geçerli; sonraki tur
  **P88**'den devam edebilir.
- Tüm iş `main` üzerinde ve push'lu.

**Not:** bağlam penceresi bu oturumun sonunda tamamen doldu. Son turlarda tek
tek satır aralıkları okuyarak ilerledim; bu, P70'te hata ayıklamayı güvenilmez
hale getirdi. `/clear` + aynı kickoff sonraki turların derinliğini geri getirir.
