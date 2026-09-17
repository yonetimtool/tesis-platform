# P239 — kararlar

Yedi bölüm. Her bölüm ayrı commit.

---

## §1 — Izgara kart adı kelime ortasından bölünüyordu

### P229 kilidi bunu neden yakalamadı

Kullanıcı haklı olarak sordu. Ölçtüm — `dugme_metni_tasmasi_test`
(P229 §1) iki sebeple göremezdi:

1. **DÜĞME etiketlerini** tarıyor; ızgara **kart adları** kapsamında değil.
2. **SATIR SAYISI** ölçüyor. Kart adı zaten iki satıra sarabilir (tasarım
   böyle) — "Görüntülem / e İzni" de iki satırdır. Yani sayım doğru,
   **bölünme yeri** yanlıştı; ölçülmeyen şey tam olarak oydu.

### Kök neden — `AutoSizeText`in seçim ölçütü yanlış

`AutoSizeText`, metnin **tamamının** `maxLines` içine sığdığı en büyük
puntoyu seçer. Bir kelime satıra sığmıyorsa Flutter onu **içinden böler**
ve metin yine iki satıra "sığmış" olur — yani `AutoSizeText`e göre sorun
yoktur. Ölçüt metne bakıyordu; **en uzun kelimeye** bakmalıydı. Kelime
satıra sığıyorsa Flutter onu asla bölmez.

### Çözüm — kullanıcının verdiği sırayla

| Madde | Uygulama |
|---|---|
| (a) kelime bütünlüğü korunsun | `kartBaslikPuntosu` en uzun **bölünmez parçanın** sığdığı puntoyu bulur |
| (b) sığmıyorsa küçült | aynı döngü, yarım punto adımlarıyla **8pt**'ye kadar |
| (c) yine sığmıyorsa sondan kes | `null` döner → kart `maxLines: 1` + ellipsis çizer; **iki satıra bölmez** |
| (d) tam metin erişilebilirlikte | `semanticsLabel` + `Tooltip` (uzun basma) |

**`AutoSizeText` ve grup KORUNDU.** Yalnızca punto **tavanı** bastırılıyor;
`AutoSizeText` bundan daha küçüğe inebilir ve küçükte de kelime bölünmez.
Grubu (`baslikGrubu`) kaldırmak kartların ortak puntosunu ve
`home_kart_titremesi_test`in koruduğu titremesizliği bozardı.

### Tire meşru bölünme yeridir

İlk dedektörüm `Site- | Budget`, `Rundgang- | Verfolgung` gibi **altı
Almanca bileşik adı** ihlal saydı. Bu yanlış: tireden sonraki bölünme bir
**hece** bölünmesi değil, Unicode'un zaten tanıdığı bir satır sonu
fırsatı ve tipografik olarak doğru. Hem dedektör hem punto seçimi
`- / ‐ – —` karakterlerini kelime sınırı sayıyor.

### Doğrulama

`mobile/test/p239_kelime_bolunmesi_test.dart` — 7 test.

**Düzeltmeden ÖNCE ölçülen ihlaller** (sabit 14pt, 320dp kart genişliği):
tr'de 9, en'de 4, de'de 8+ … bildirilen kart dahil:
`tr/modulGoruntulemeIzni: Görüntüle | me İzni`.

Kilit **üretim algoritmasının seçtiği puntoda** ölçüyor. İlk yazımım sabit
14pt'de ölçüyordu ve **düzeltmeden sonra da kırmızı kalırdı** — çünkü kart
14pt'de çizmiyor. Kilit böylece "metin kısa mı" değil "kart doğru mu
çiziyor" sorusunu soruyor.

| Ölçüm | Sonuç |
|---|---|
| 7 dil × `modul*` adları, 320dp | ihlal **0** |
| Büyük yazı tipi (**x1.6**) | ihlal **0** |
| En küçük puntoda da sığmayan ad | `null` → tek satır ✔ |
| Bölünmez parçalar (tire/boşluk) | ✔ |
| **KIRMA**: punto seçimi tabana sabitlendi | **üç test birden kırmızı** ✔ |

**Altın görüntü değişti** (`yonetici_ana_ekran`, `sakin_ana_ekran`):
"Vardiyalar" artık `69x20` (iki satır, ortadan bölünmüş) yerine `69x10`
(tek satır + üç nokta). Test fontu her glifi kare em çizdiği için
gerçekten olduğundan çok daha dar; cihazda bu ad rahat sığar.

### ÖLÇEMEDİĞİM

Gerçek cihazda ekran okuyucunun tam metni okuduğu ve uzun basma
ipucunun göründüğü sürülmedi (emülatör yok); ikisi de widget
seviyesinde bağlandı.
