# Oturum Sonuç Raporu — 2026-08-01

**P51 → P100 arası 50 madde** kapandı. Aşağıda ne yapıldığı, ne bulunduğu ve
**ne yapılmadığı** var.

---

## 1. Kapılar (hepsi `infra/kapilar.sh` ile, borusuz, çıkış kodu okunarak)

| Kapı | Sonuç |
|---|---|
| `backend-pytest` | **1143 passed, 1 skipped** — çıkış 0 (20 dk 53 sn) |
| `goc-uyum` / `goc-tersinir` | **bulgu 0** / **bulgu 0** (28 sınır) |
| `web-tsc` / `web-vitest` / `web-build` | temiz / **282 passed** / yeşil |
| `mobil-analyze` / `mobil-test` / `mobil-apk` | temiz / **1561 passed** / APK |

---

## 2. Bulunan gerçek kusurlar

### Sessiz başarısızlık / sessiz veri kaybı
1. **P51** — Bildirimlerde ham `fetch`: 500 dönse bile "okundu işaretlendi".
2. **P52** — **Çıkış**: istek düşerse çerezler kalıyor ama kullanıcı çıktığını
   sanıyordu. Ortak bilgisayarda bedeli oturum devri.
3. **P55/P56** — `Number()` → `NaN` → `null` → **alan silinir**, altı yerde.
   En ağırı: **tanımlar sayfası `1.250` yazana 1,25 TL kaydediyordu.**
4. **P57** — Mobilde Türkçe klavyeyle girilen **koordinat sessizce siliniyordu**.
5. **P60/P61** — Hata varken "kayıt yok" iddiası (destek, harita, bina, tanımlar).
   Haritada "3 açık şikayet" ile "açık şikayet yok" **yan yanaydı**.
6. **P58/P59** — Düşen aramada boş liste "kayıt yok" gibi okunuyordu; kimlik
   parçası **ad sanılıyordu**.
7. **P65** — Aidat raporu tarayıcıdan **1.000 ardışık istek** atabiliyordu.

### Görünen ama yanlış bilgi
8. **P53/P66** — Ham tel değeri **dokuz yerde** ekrandaydı (en ağırı pano ve
   denetim kaydı).
9. **P54** — **Sekiz silme onayı** İngilizce arayüzde de Türkçe çıkıyordu.
10. **P62** — Koyu temada devrilmemiş renkler; ilki **benim eklediğimdi**.
11. **P63** — Dört form denetiminin adı yoktu; biri **tesis silme onayı**.
12. **P68** — `key={i}` (parola yöneticisi yanlış satıra bağlanabilir).

### Güvenlik / veri bütünlüğü
13. **P96** — `dial` iki yoldan çağrılıyor, **biri doğrulanmıyordu**: sunucu
    JSON'undan gelen `tel_uri` `launchUrl`a gidiyordu.
14. **P97** — `PATCH /users/{id} {"telefon": "//evil.example/x"}` → **200**,
    ham saklanıyordu. Telefon **global benzersiz giriş kimliği**.
15. **P99** — `yonetim_email`: `" "` truthy olduğu için "e-posta var" sayılıp
    boş adrese gönderim denenirdi.

---

## 3. Kalıcı hale getirilenler

Her biri **kusuru geri koyarak** doğrulandı.

| Kilit | Ne tutuyor |
|---|---|
| `sessiz-fetch` | Ham `fetch` yanıt denetimi |
| `ham-enum` | Tel değeri ekranda (önek toleranslı) |
| `hata-mesaji` | Korumasız `String(hata)` + boş-durum çelişkisi |
| `koyu-tema` | Devrilmemiş renk sınıfları |
| `erisilebilir-etiket` | Adsız form denetimi |
| `i18n` (+3 tarama) | `toast()`, tarayıcı diyalogları, şablon dizgeleri |
| `guvenlik-hijyeni` | `rel`siz `_blank`, değişkenli `dangerouslySetInnerHTML` |
| `enterpolasyon_sabit_metin` (mobil) | Enterpolasyonlu dizgede sabit metin |
| `conftest` koşum kilidi | İki eşzamanlı pytest koşumu |

### Çapraz bağ zinciri (P77–P85)
Aynı gerçeğin iki yerde tutulup **sessizce ayrışmasını** engeller: ayrıştırma
kuralı (iki istemci), biçimlendirme çıktısı, rol listesi (panel + mobil), altı
enum haritası, ayar anahtarları, BFF beyaz listesi ↔ `openapi.yaml`, dil
listeleri (panel ↔ mobil ↔ ARB).

### Kapı altyapısı (P88–P94)
`infra/kapilar.sh` — çıktı dosyaya, çıkış kodu doğrudan, imaj önce.
Kural 6 artık **betiği işaret ediyor** (P93).

---

## 4. Panel bileşen kapsamı

**12 → 282 test.** Kapsamı olmayan sayfa kalmadı (`integrations` sonuncusuydu).
İlke baştan sona aynıydı: **hedef yüzde değil hata sınıfı.**

---

## 5. Kendi hatalarım (hepsi ölçümle yakalandı)

1. **P62** — Kilit **sessizce geçiyordu**; enjekte edilen renk yakalanmayınca çıktı.
2. **P65** — Sessiz kırpmayı **kendi elimle** koydum.
3. **P70** — Kilit doğrulanamadı → **eklenmedi**; P86'da nedeni bulundu (sıra).
4. **P74/P75** — "Suite'te 1 ERROR var" dedim, **yanlıştı**: sebep benim
   eşzamanlı ikinci koşumumdu. Üç kez "ölçtüm" sandığım şey ölçüm değildi
   (`ps` yok, `| tail` çıkış kodunu maskeliyor, konteynerde eski kod).
5. **P77** — Sanity kontrolü ilk denemede **anlamsızdı** (boş gövdeli `if`).
6. **P89/P90** — "Ölçüm farkı" diye yazdığım şey **kendi özet satırımdı**;
   açıklamayı **ölçmeden** yazmıştım.
7. **P91/P92** — Özet, hata durumunda "ne kadar sürdü"yü söylüyordu.
8. **P97/P98** — Doğrulayıcım **doğrulaması gerekmeyen bir değeri** (`""` =
   "numarayı kaldır") reddetti ve bir testi kırdı; var olan sözleşmeyi
   okumamıştım.

**Ortak ders:** sessizlik, sıfır ve yeşil — üçü de tek başına kanıt değil.
**Kaybolan kanıt, olmayan kanıttan kötüdür.**

---

## 6. YAPILMAYANLAR

### Bilerek (gerekçesi planda)
- **P79** — Mobil `NumberFormat` panelin elle gruplamasıyla birleştirilmedi:
  iki ortamın risk profili farklı.
- **P83** — Ayarlarda ters yön zorlanmadı: `OPERASYON` bilinçli alt küme.
- **P97** — Firma/personel/dış hizmet telefonları normalize edilmedi: giriş
  kimliği değiller, dahili numara içerebilirler.
- **P99** — "Create doğrular, Update doğrulamaz" kuralına **kilit yazılmadı**:
  9 yanlış pozitif, doğrulama üç ayrı biçimde yapılıyor.
- **P94** — `goc` hata yolu sürülmedi: kırık bir Alembic revizyonu üretmek göç
  politikasını çiğnerdi.
- **P66/P73** — `action` kodları, `channel_type`/`auth_type` çevrilmedi.

### Sende bekleyenler ([KEREM]/[DIŞ])
| Madde | Ne gerekiyor |
|---|---|
| **P2** | Prod runbook — prod yalnız sende |
| **P11** | **Cihaz doğrulama listesi — 45+ madde** |
| **P12/P13** | Firebase + ödeme kimlik bilgileri |
| **P18** | Frigate pilotu |
| **P64** | **Vezne çift kayıt riski** — ürün kararı (üç seçenek planda) |
| — | `meta.total` O(tablo) — sözleşme değişikliği |

---

## 7. Nerede duruyor

- Plan: `docs/MASTER-PLAN.md` — **100 madde**, açık hash yer tutucusu yok.
- Kapılar: `infra/kapilar.sh [web|mobile|backend|goc]`, günlükler `.kapilar/`.
- Tüm iş `main` üzerinde ve push'lu.

**Not:** bağlam penceresi doldu. `/clear` + aynı kickoff, sonraki turların
derinliğini geri getirir; devir notu STATUS REPORT #10'da.
