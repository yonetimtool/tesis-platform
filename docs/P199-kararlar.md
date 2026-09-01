# P199 — Kurulum sihirbazına finans adımları

**Tarih:** 2026-09-01 · **Kapsam:** backend + admin-web + rehber

Sorun: sihirbaz "tamam" diyordu, tesisin finans modülü hâlâ
kullanılamaz kalıyordu. Aidat türü yok, plan yok, bütçe başlığı yok —
yönetici bunları kendi keşfetmek zorundaydı.

Referans: `docs/P192-test-yolharitasi.md` (bağımlılık sırası orada
ölçülmüştü: kasa → gelir/gider tanımı → tahakkuk → gecikme → otomasyon).

---

## K1 — Gelir/gider tanımı ZORUNLU, aidattan ÖNCE

**Karar:** yeni `gelir_gider_tanimi` adımı, `kasa` ile `aidat` arasına
zorunlu olarak kondu. Sihirbazın zorunlu adım sayısı 6 → **7**.

**Gerekçe — iddia değil ölçüm:** `POST /borclandirma/toplu/onizleme`
`gelir_gider_tanim_id` **ister**; tanımsız istek **422** döner (P193
§6'da ölçülmüştü, P199'da `test_TOPLU_BORCLANDIRMA_TANIMSIZ_reddeder`
ile kilitlendi). Yani tanım olmadan aylık aidat topluca yazılamaz —
"minimum çalışır kurulum" tanımına birebir uyar.

Sihirbaz aidatı önce sorsaydı, yönetici gidip 422 yiyecekti; kasa
adımında öğrenilen dersin (P193 §2) aynısı.

## K2 — Diğer dört finans adımı İSTEĞE BAĞLI

`aidat_plani`, `otomasyon`, `butce_kategorisi`, `duzenli_gider`
zorunlu **değil**.

**Gerekçe:** aidatını her ay eliyle yazan bir tesis de çalışan bir
tesistir. Zorunlu yapmak, çalışan bir tesise "eksiksin" demek olurdu —
P193 §8'de `daire_tipi` için verilen kararın aynısı.

## K3 — Otomasyonlar VARSAYILAN KAPALI kalır (P192 kararı korundu)

Sihirbaz hiçbir otomasyonu açmaz; yalnızca **sorar**.

Ölçülen varsayılanlar:
* `hatirlatma_ayari.aktif` → **false**
* `aidat_plani.aktif` → **true** — yani **planı oluşturmak otomasyonu
  açmaktır**. Tam da bu yüzden "aidat planı" adımı atlanabilir olmalı;
  zorunlu yapmak, kullanıcıya sormadan otomasyon açtırmak olurdu.

`test_OTOMASYON_adimi_...` bu kuralı iki yerden kilitler: ayar okuması
`aktif: false` döner ve kaydetme isteği de `aktif: false` bırakır.

## K4 — Otomasyon adımı VERİDEN sayılamaz → göç 0090

Sihirbazın bütün adımları "satır var mı" diye sayar. Otomasyon adımı bu
kalıbı **taşıyamaz**, iki ölçülmüş sebeple:

1. Doğru cevap "hepsini kapalı bırak" **olabilir**. Kapalı bir ayar
   satırı, "yöneticiye hiç sorulmadı" ile aynı görünür.
2. `routers/otomasyon.py::_ayar` **get-or-create**'tir: ayarı **GET**
   de yaratır. Finans ekranını açan herkes adımı "tamamlamış"
   görünürdü.

**Karar:** ölçülen şey kararın kendisi olsun. Göç **0090**
`tenant.kurulum_otomasyon_karari` (boolean, varsayılan `false`) ekler.
Bayrak yalnız **PATCH** uçlarından yazılır — `hatirlatma-ayari` ve
`borclandirma/gecikme-ayari` — yani **kaydetme anında**, GET'ten asla.

Otomasyon tercihi iki ekrana yayılır (hatırlatma / gecikme faizi);
hangisi kaydedilirse kaydedilsin yönetici sorulanı yanıtlamış olur.

Göç **geri alınabilir**: `downgrade` sütunu düşürür. Doğrulandı —
`downgrade 0089` → `upgrade head` ikisi de çalıştırıldı.

## K5 — Atlanan adımlar sihirbazın sonunda KALIR

Özet kartına ikinci bir bölüm eklendi: **"Sonraya bıraktıklarınız"**.
Atlanan **isteğe bağlı** adımlar, her birinin **neyi engellediğiyle**
birlikte listelenir. Daha önce atlanan adım listeden sessizce düşüyordu.

**Zorunlu bir adım atlansa bile bu listeye GİRMEZ:** o zaten üstteki
"Çalışır kurulum için eksikler" listesindedir ve atlanmış olması
gerçeği değiştirmez (P193 §2 kararı). Yumuşak listeye taşımak, onu
"isteğe bağlı" gibi gösterirdi.

## K6 — Metinler: teknik terim yok

Her adımın açıklaması, siteyi yöneten kişinin diliyle **ne olduğunu**
söyler; engel metni **yapmazsa ne olmadığını** söyler. 7 dilde yazıldı.

Örnek — aidat planı: *"Her ay aynı aidatı elle yazmamak için bir kural:
tutar, dairelere nasıl paylaştırılacağı, ayın kaçında yazılacağı ve son
ödeme günü."* Engel: *"Plan yoksa aidatı her ay elle yazarsınız;
unuttuğunuz ay kimseye borç düşmez."*

---

## Ölçümler

| Ne | Sonuç |
|---|---|
| Göç 0090 uygula | çalıştı |
| Göç geri al → yeniden uygula | ikisi de çalıştı (geri alınabilir) |
| Sihirbaz adım sayısı | 13 → **18**, zorunlu 6 → **7** |
| Kilit kanıtı — bayrak yazımı kaldırıldı | otomasyon testi **düştü**, geri konunca geçti |
| Kilit kanıtı — `!a.zorunlu` süzgeci kaldırıldı | "atlananlar" testi **düştü**, geri konunca geçti |
| Backend `test_kurulum` + `test_p199_*` | 15 geçti |
| Kilit registreleri (yetki / denetçi / sözleşme) | 41 geçti |

## Ölçerken çıkan, P199 kapsamı DIŞINDA kalan bulgu

`POST /borclandirma/toplu/onizleme` yöneticiye **kapalı** (403); yalnız
admin çağırabiliyor. Sihirbazın `aidat` adımı `/dues` üzerinden
tamamlanabildiği için akış tıkanmıyor, ama "toplu borçlandırma" ekranı
yöneticiye kapalı. P193 §3'te açık bırakılan finans yazma rolü
maddesiyle aynı kök. Not edildi, değiştirilmedi.
