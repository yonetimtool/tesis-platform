# Yüz tanıma v2 — TASARIM NOTU (uygulanmadı)

> **Bu belge kod üretmez.** MASTER-PLAN P20'nin çıktısıdır: kapsamı, hukuki
> zemini ve teknik sınırları yazıya döker. Sonunda açık bir **karar satırı**
> vardır; o karar verilmeden hiçbir satır kod yazılmayacaktır.

## 1. Kapsam — dar ve kasıtlı

**YALNIZCA personel doğrulaması.** Site çalışanı (güvenlik, tesis görevlisi,
temizlik) vardiya başlangıcında/devriye başında **kendi kimliğini doğrular**.

Kapsam DIŞI — pazarlığa kapalı:

| Dışarıda | Neden |
|---|---|
| **Sakinler** | Rıza gerçek anlamda özgür olmaz (oturduğu binaya girmek için "hayır" diyemez); ayrıca hiçbir operasyonel gereklilik yok |
| **Ziyaretçiler / kuryeler** | Bilgilendirme ve rıza alınması pratikte imkânsız |
| **Toplu kimliklendirme** | "Kim geçti" taraması, kalabalıkta arama, kara liste eşleştirme — HİÇBİRİ |
| **Kamera akışında sürekli tarama** | Sistem yalnız KULLANICININ BAŞLATTIĞI tek bir doğrulama anında çalışır |
| **Duygu/yaş/cinsiyet çıkarımı** | Hiçbir biçimde |

Tek cümlelik sınır: **kimlik DOĞRULAMA (1:1), kimlik TESPİTİ (1:N) DEĞİL.**

## 2. Neden istenebilir — ve alternatifleri

İhtiyaç: "devriye kaydını gerçekten o kişi mi yaptı, yoksa telefonu
arkadaşına mı verdi?"

Mevcut savunmalar zaten var:
* **NTAG424 SDM** — etiketin FİZİKSEL varlığını kriptografik olarak kanıtlar
  (kopyalanamaz). Yani "noktaya gidildi" zaten kanıtlı.
* **P34 GPS** — okutmanın konumu.
* **P34 tur başı fotoğraf** — ortam + zaman kanıtı (gündüz/gece), kamera-only.

Yüz tanımanın eklediği TEK şey: *"telefonu tutan kişi hesap sahibi mi"*.

> **Değerlendirme:** P34 paketinden sonra kalan risk dardır. Yüz verisi ise
> KVKK'da **özel nitelikli kişisel veri**dir (biyometrik). Fayda/risk oranı
> düşüktür. Bu notun tavsiyesi: **önce P34'ü sahada ölç**, kaçak hâlâ
> anlamlıysa yeniden değerlendir.

## 3. KVKK analizi (özet)

Biyometrik veri **KVKK m.6 özel nitelikli kişisel veri**dir. İşlenmesi için
kural: **açık rıza** (m.6/2) — ya da kanunlarda öngörülme.

Bu tasarımın uyması gereken asgarî koşullar:

1. **Yazılı açık rıza**, iş sözleşmesinden **AYRI bir metinle**. İş
   sözleşmesine gömülü rıza geçerli sayılmaz (özgür irade tartışması).
2. **Reddetme cezasız olmalı.** Reddeden personel eski yöntemle (NFC + kod)
   çalışmaya devam eder; hiçbir hak kaybı olmaz. Sistem **fallback'siz
   tasarlanamaz**.
3. **Tenant varsayılanı KAPALI.** Özellik site bazında açılır; açan tenant
   aydınlatma metnini ve rıza kayıtlarını üstlenir.
4. **Şablon saklanır, GÖRÜNTÜ saklanmaz.** Yüzden çıkarılan matematiksel
   şablon (embedding) saklanır; ham fotoğraf doğrulamadan hemen sonra silinir.
   Şablon geri döndürülemez olmalı ve **tenant başına ayrı anahtarla**
   şifrelenmelidir.
5. **Cihazda mı sunucuda mı:** tercih **cihazda** doğrulama (şablon telefonda,
   sunucuya yalnız "doğrulandı/doğrulanmadı" + zaman gider). Bu, veri
   minimizasyonunun en güçlü hâlidir. Cihaz değişiminde yeniden kayıt gerekir
   — kabul edilebilir bedel.
6. **Saklama süresi:** iş ilişkisi bitiminde şablon **derhal** silinir
   (mevcut gecelik retention/erasure işine bağlanır).
7. **Aydınlatma + rıza sürümü:** metin sürümlenir; metin değişirse rıza
   yenilenir (P36'daki KVKK kapısıyla aynı mekanizma).
8. **Denetim kaydı:** her doğrulama denemesi `audit_log`'a yazılır (kim, ne
   zaman, sonuç) — ama **yüz verisi olmadan**.
9. **VERBİS / envanter:** biyometrik işleme faaliyeti kişisel veri işleme
   envanterine eklenmelidir. Bu **hukukçu işidir**, yazılım işi değil.

## 4. Teknik taslak (uygulanacaksa)

```
[mobil] kamera → yüz tespiti (cihazda) → embedding (cihazda)
                                   ↓
                      cihazdaki şifreli şablonla karşılaştır
                                   ↓
        POST /me/face-verify  { sonuc: true|false, zaman, cihaz_id }
                                   ↓
              audit_log + devriye/vardiya kaydına "dogrulandi" bayrağı
```

* **Sunucuya yüz verisi GİTMEZ.** Uç yalnız sonucu alır.
* Kayıt (enrollment) akışı: kullanıcı rıza ekranını geçer → 3–5 kare → şablon
  cihazın güvenli deposunda saklanır (`flutter_secure_storage` yeterli
  değildir; Android Keystore / iOS Secure Enclave ile sarılmalı).
* **Canlılık (liveness) olmadan bu sistem fotoğrafla aldatılır.** Basit göz
  kırpma/hareket kontrolü asgarî şarttır; aksi hâlde özellik güvenlik
  hissi verir ama güvenlik vermez — bu, **hiç yapmamaktan kötüdür**.
* Yeni şema: `personel_yuz_kayit` (user_id, cihaz_id, olusturma, rıza_sürümü,
  aktif) — **şablon SUNUCUDA TUTULMAZ**, yalnız "bu kullanıcı bu cihazda
  kayıtlı" bilgisi. Yeni Alembic revizyonu (kural 7).

## 5. Bu tasarımın reddettiği kolay yollar

* **Hazır bulut yüz API'si** (AWS Rekognition / Azure Face): yüz görüntüsü
  yurt dışına aktarılır → KVKK m.9 yurtdışı aktarım rejimi devreye girer.
  Reddedildi.
* **Sunucuda merkezî şablon veritabanı**: tek bir sızıntı tüm personelin
  biyometrisini açığa çıkarır ve geri alınamaz (parola değiştirilir, yüz
  değiştirilemez). Reddedildi.
* **Kamera akışında pasif tanıma**: §1'de kapsam dışı.

## 6. Maliyet ve karmaşıklık dürüst tahmini

| Kalem | Yük |
|---|---|
| Mobil: kayıt + doğrulama + canlılık + güvenli depo | yüksek (platform-özel kod, iki OS) |
| Backend: rıza sürümleme, uç, audit, silme | orta |
| Hukuk: aydınlatma metni, rıza formu, envanter | **dışarıdan alınmalı** |
| Bakım: cihaz değişimi, yanlış-red destek yükü | süreklidir |

## 7. KARAR SATIRI

> **Bu özellik Kerem'in açık "git" kararını gerektirir.** Karar verilmeden
> hiçbir kod yazılmayacaktır. Kararın teknik değil **hukuki + ürün** kararı
> olduğu, faydanın P34 paketinden sonra dar kaldığı ve reddetmenin geçerli bir
> sonuç olduğu bu notta kayıtlıdır.
>
> Karar "git" olursa ilk adım kod değil, **aydınlatma metni + rıza formunun
> hukukçuya yazdırılmasıdır**.
