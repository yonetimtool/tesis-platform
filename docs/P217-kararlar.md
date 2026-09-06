# P217 — Tahsilat ve tahakkuk arayüz hataları

> Not: bu numarayla ayrıca `docs/P217-push-yonlendirme.md` var (push
> yönlendirmesi turu). İçerikler ayrı.

---

## §1 — Toplu borçlandırma

### Ölçüm: iddia doğrulanmadı, iki gerçek kusur bulundu

Akışı **gerçekten sürdüm** — hem uçtan (`api` konteyneri içinden) hem
web BFF üzerinden, hem **admin** hem **yönetici** hesabıyla:

| Ölçüm | Sonuç |
|---|---|
| `POST /borclandirma/toplu/onizleme` | 200 · "15 daire işlenecek" |
| `POST /borclandirma/toplu` | 201 · `dues_assessment`'a **15 kayıt yazıldı** |
| Borçlandırmalar listesi | kayıtlar **görünüyor** ("P217 surus" açıklamasıyla) |
| Finans özeti | `acik_borc_kurus: 410175` — tahakkuku **sayıyor** |
| Tahsilat göstergesi | `tahakkuk_kurus: 225000` — **görüyor** |
| **Yönetici** rolü | önizleme 200, işleme 201 — **çalışıyor** |

Yani "toplu borçlandırma çalışmıyor" iddiası ölçümde çıkmadı. **P199'daki
403 gerçekten kapanmış**: P206'da `_ADMIN` kaldırılıp `_YONETIM`
(admin+yonetici) konmuş ve uçtan uca doğrulandı.

Buna rağmen kullanıcının gördüğü şey gerçek. İki kusur ölçüldü:

### Kusur 1 — sessiz başarısızlık (asıl açıklama)

Aynı dönem **ikinci kez** borçlandırılınca 15 satırın hepsi benzersizlik
çarpışmasıyla atlanıyor, **hiçbir tahakkuk yazılmıyor** — ama sunucu
`created: []` dönüyordu (bilerek, yanıtı şişirmemek için) ve **kaç tane
oluştuğunu söylemiyordu**. Web her durumda **"Kaydedildi"** yazıyordu.

Kullanıcının "işlem oldu ama ortada borç yok" deneyiminin en olası
açıklaması bu; ve bu turda **üçüncü kez** çıkan kalıbın (sessiz
başarısızlık) aynısı.

**Düzeltme:** `DuesAssessmentResult.olusan` eklendi — toplu, sayaç ve
tekil yolların **hepsinde** dolu. Web:
- `olusan > 0` → *"15 tahakkuk oluşturuldu"* + modal kapanır,
- `olusan == 0` → **hata tonunda** *"Hiçbir tahakkuk oluşturulmadı — bu
  dairelerin seçilen dönemde borcu zaten var. Başka bir dönem seçin ya da
  mevcut kayıtları düzeltin"* + **modal açık kalır** (dönem düzeltilebilsin).

### Kusur 2 — dairelerde borç görünmüyordu

`/units` yanıtı **borç alanı taşımıyordu**; "Daireler" ekranında borç
sütunu yoktu. Tahakkuklar yazılmıştı, finans özeti sayıyordu — görünmeyen
tek yer buydu ve kullanıcı "borçlandırma çalışmıyor" sonucuna buradan
varmış olabilir.

**Düzeltme:** `UnitOut.borc_kurus` (tahakkuk − tahsilat) + Daireler
ekranında "Açık borç" sütunu. **Tek toplu sorgu** — daire başına sorgu
elli daireli sitede elli sorgu demekti. **Negatif değer kırpılmıyor:**
fazla ödeme yapmış daire alacaklıdır ve bunu gizlemek yöneticiden bilgi
saklamaktır.

### Tek defter (P192): kabul kriteri 2 karşılanamaz — gerekçe

İstek "toplu borçlandırma `finansal_hareket`'e yazılsın" diyordu.
**Tasarım bunun tersi ve değiştirmedim:**

`hareket_tip` enum'u yalnızca **para hareketlerini** tanıyor:
`tahsilat, gider, gelir, virman, iade, acilis, iptal`. **`tahakkuk` diye
bir tür yok.** Tahakkuk bir *borç kaydıdır*, para hareketi değil; defterde
karşılığı ancak tahsil edildiğinde (`tip=tahsilat`) doğar. Tekil tahakkuk
yolu da aynı şekilde davranıyor — yani toplu yol bir istisna değil.

Deftere yazmak için önce enum'a yeni bir tür eklemek, yani P192'nin
"defter = para" tanımını değiştirmek gerekirdi. Bunun için bir gerekçe
görmedim: finans özeti tahakkuku `dues_assessment`'tan okuyor ve
`acik_borc_kurus`'u **doğru** veriyor (ölçüldü). Bu karar testle de
görünür kılındı (`test_TAHAKKUK_deftere_YAZILMAZ_ve_bu_KUSUR_DEGIL`).

### Ölçüm notları

Backend testleri **canlı sunucuya** gidiyor (mevcut desen); web testinde
taklit **`fetch` düzeyinde** — `apiSend` ve yanıt işleme gerçekten koşuyor
(P200 dersi). Kilitler kırılarak doğrulandı: `olusan`'ı sabit 0 yapınca 3
backend testi düştü.

Test yazarken üç ön koşul eksiği çıktı ve düzeltildi: `world` fixture'ında
gider tanımı ve daire yok (test kendi verisini kuruyor), tahsilat ucu
`yontem: elden` ve `Idempotency-Key` istiyor. İlk yazımda tahsilat testini
**atlıyordum** — atlanan test hiçbir şey korumaz, doğru değeri kullanmak
gerekiyordu.
