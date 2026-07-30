# İçerik çevirisi kalite notu — LibreTranslate ölçümü (P14b/c)

> Ölçüm tarihi: 2026-07-30 · Ortam: dev docker (`tesis-libretranslate-1`) ·
> Yön: `tr` → `en, ar, ru, de, fr, es` · 8 örnek × 6 dil = **48 çeviri**,
> toplam **37,3 sn** (ortalama ~0,8 sn/çeviri).

## Neden bu ölçüm

Yayın içeriği (duyuru / site kuralı / etkinlik) yazma anında 6 dile çevrilip
`Accept-Language` ile servis ediliyor (P6/P7). Çeviri motoru kendi
barındırdığımız **LibreTranslate** — içerik dışarı çıkmıyor, bu KVKK açısından
doğru karar. Ama şimdiye kadar **çıktının kalitesi hiç ölçülmemişti**: mobil
tarafta "otomatik çevrilmiştir · orijinali gör" bağlandığına göre (P7) artık
kullanıcı bu metinleri gerçekten okuyor.

Örnekler uydurma değil; seed verisi ve sahadaki gerçek duyuru/kural
kalıplarından seçildi: asansör bakımı, su kesintisi, otopark kuralı, gürültü
kuralı, **aidat son ödeme + gecikme tazminatı**, toplantı duyurusu, güvenlik
kuralı, teknik bakım.

## Sonuç: TÜRKÇE KAYNAK İÇİN YETERSİZ

48 çevirinin içinde **anlamı bozan** hatalar var ve bunlar kozmetik değil.
En ağır sekiz bulgu:

| # | Kaynak | Çıktı | Neden ciddi |
|---|---|---|---|
| 1 | "**Aidat** borcunuz için son ödeme tarihi ayın 10'udur" | en: "The deadline for your **regimen** is **10 months**" · de: "Die Frist für Ihr **Regime** beträgt **10 Monate**" | **İKİ katmanlı hata**: "aidat" tıbbi *regimen* sanıldı; "ayın 10'u" **"10 ay"** oldu. Bu bir **finansal tarih** — yanlış çeviri doğrudan zarar üretir. |
| 2 | "**Tadilat** çalışmaları hafta içi..." | en/de/ru/fr/es: "**Tadilat** studies / Tadilat-Studien / исследования тадилата" | Alan terimi hiç çevrilmemiş, üstelik "çalışma"yı *akademik çalışma* sanmış. |
| 3 | "**soru-cevap**" | en: "question-**cevap**" · ru: "вопрос-**севап**" · es: "cuestionamiento" | Yarısı Türkçe kalmış / uydurulmuş. |
| 4 | "aidat **kalemleri** sunumu" | en: "presentation of **tokens**" · ar: "عرض **المحاقن**" (= *şırıngalar*) | Anlamsız; Arapça sürüm ayrıca cümlenin bir bölümünü **düşürmüş**. |
| 5 | "**Her daireye bir** otopark yeri ayrılmıştır" | en: "A parking lot **is divided into each apartment**" | Anlam **tersine** dönmüş. |
| 6 | "**Su kesintisi**... **depolarınızı** doldurun" | de: "Wasser**versagen**" · en/fr/es: "your **warehouse/entrepôt/almacén**" | "kesinti"→*arıza*, "depo"→*ambar* (su deposu değil). |
| 7 | "Ziyaretçiler ... **içeri alınmaz**" | ar: "ولم **يتلق** الزوار" (geçmiş zaman, "almadılar") | **Kural cümlesi bildirim cümlesine** dönmüş — yasak ifadesi kaybolmuş. |
| 8 | "**Kazan dairesinde** bakım" | en: "in the boiler **apartment**" · de: "Kessel**wohnung**" | "daire"nin iki anlamı karışmış (*unit* vs *room*). |

Ek gözlem: **Arapça çıktı en zayıfı** — cümle düşürme (#4) ve kip kayması (#7)
yalnız Arapçada görüldü. Rusça ve Almanca "anlaşılır ama hatalı", İngilizce
ortalama, İspanyolca/Fransızca ortalamanın biraz üstü.

### Ne İYİ çalışıyor

Kısa, düz, terim içermeyen cümleler kabul edilebilir:
"Yarın sabah 09:00 ile 12:00 arasında asansör bakımda olacak" altı dilde de
doğru çevrildi. Saat/tarih biçimleri korunuyor. Gecikme yok (~0,8 sn).

### Kalıp: hata TERİMDE yoğunlaşıyor

Bozulan her cümlede **alana özgü bir Türkçe terim** var: aidat, tadilat,
kalem, kazan dairesi, depo, kesinti. LibreTranslate'in Türkçe modeli bu
kelimeleri günlük anlamlarıyla çözüyor. Yani sorun "Türkçe desteklenmiyor"
değil, **terminoloji**.

## Karar önerisi (Kerem'in onayı gerekir — SAĞLAYICI DEĞİŞTİRİLMEDİ)

Üç seçenek var; ikisi birleştirilebilir.

**A. Sağlayıcıyı DeepL'e çevirmek.** DeepL Türkçe'yi kaynak dil olarak
destekliyor ve terim tutarlılığı için **glossary** özelliği var (bizim
`@@x-glossary` sözlüğümüz doğrudan oraya beslenebilir). Soyutlama zaten
mevcut (`backend/app/translate.py`), yani **kod değişikliği yalnız bir
sağlayıcı sınıfı + config**; şema, kuyruk, durum makinesi, mobil taraf aynen
kalır.
_Bedel:_ içerik **dışarı çıkar** — KVKK açısından yeni bir işleme/aktarım
kaydı ve aydınlatma metni güncellemesi gerekir (DeepL AB'de barındırılıyor;
"Pro" planında girdi eğitim için kullanılmıyor). Ayrıca karakter başına
ücret. Bu **KVKK kararıdır, teknik karar değildir** — bu yüzden Kerem'in
onayı olmadan yapılmaz.

**B. LibreTranslate'te kalıp SÖZLÜK ÖN-İŞLEME eklemek.** Çeviriye göndermeden
önce bilinen alan terimlerini hedef dildeki karşılığıyla değiştirmek
(aidat → *dues/رسوم الإدارة/взносы*, kazan dairesi → *boiler room*, tadilat →
*renovation*). Yukarıdaki sekiz hatanın **altısı** doğrudan bu sınıftan.
_Bedel:_ sözlük bakımı; içerik dışarı çıkmaz, ücret yok. Kalite "iyi" olmaz
ama "yanlış"tan "kaba ama doğru"ya çıkar.

**C. Karma (önerilen).** B'yi hemen uygula (ucuz, KVKK'yı bozmaz), A'yı
Kerem'in KVKK kararına bırak. A gelirse B'nin sözlüğü DeepL glossary'sine
aynen taşınır — boşa iş olmaz.

> **Yapılmayacaklar (bilinçli):** bu turda sağlayıcı DEĞİŞTİRİLMEDİ, ön-işleme
> de EKLENMEDİ. P14 bir **değerlendirme** kalemidir; ikisi de ürün davranışını
> değiştirir ve Kerem'in "git" demesini bekler.

## Kullanıcıya ne görünüyor (bu ölçümün ışığında)

P7 ile gelen "otomatik çevrilmiştir · **orijinali gör**" bağlantısı bu kalite
seviyesinde **zorunlu bir emniyet supabı**: kullanıcı saçmalayan bir çeviri
gördüğünde tek dokunuşla Türkçe orijinale inebiliyor. Ölçüm bu tasarım
kararını doğruluyor — rozet "hoş bir ayrıntı" değil, **gereklilik**.

## Yeniden ölçüm

Ölçüm betiği bu notun içindeki örneklerle birebir tekrarlanabilir:
`infra/` altından `docker compose exec -T api python` ile LibreTranslate'in
`/translate` ucuna 8 örnek × 6 dil gönderilir. Sağlayıcı değişirse aynı 8
örnekle yeniden koşulup bu tablo güncellenmelidir — **kıyas ancak aynı
örneklerle anlamlıdır**.

## İlgili

* Arayüz metinlerinin anadil incelemesi: `docs/ceviri-teslim/` (ayrı iş —
  orası ARB sabitleri, burası kullanıcı içeriği).
* Mobil taraftaki çeviri durumu arayüzü: MASTER-PLAN P7.
