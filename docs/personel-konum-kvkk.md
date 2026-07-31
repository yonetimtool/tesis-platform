# Personel konum verisi — KVKK aydınlatma notu (P34)

> Bu belge **hukuki metin değildir**; ürünün personel konumu hakkında ne
> topladığını, neden topladığını ve nerede durduğunu yazar. Aydınlatma
> metnini tesis yönetimi (veri sorumlusu) bu bilgiyle hazırlar.

## Ne toplanıyor

Tur okutması (`POST /scans`) sırasında, **yalnızca okutma anında** tek bir
konum ölçümü alınır:

| Alan | Anlamı |
|---|---|
| `gps_lat` / `gps_lng` | Okutmanın yapıldığı koordinat |
| `gps_dogruluk_m` | Ölçümün doğruluğu (metre) |
| `konum_durumu` | `var` / `izin_yok` / `servis_kapali` / `zaman_asimi` / `bilinmiyor` |

**Sürekli takip YOKTUR.** Arka planda konum izleme, rota kaydı, "şu an
neredesin" sorgusu yoktur ve mimaride de yeri yoktur: uygulama konumu yalnız
okutma anında ister ve ölçümü aldıktan sonra bırakır. Toplanan şey bir
**iz** değil, tekil bir **kanıt noktasıdır**.

## Neden toplanıyor

Hukuki dayanak, işverenin/site yönetiminin **hizmetin ifasını denetleme**
meşru menfaatidir (KVKK m.5/2-f). Somut amaç: NTAG424 SDM etiketin fiziksel
varlığını kriptografik olarak kanıtlar, ama **etiketin nerede olduğunu**
kanıtlamaz — sökülüp başka yere taşınmış bir etiket de geçerli imza üretir.
Konum bu boşluğu kapatır.

Amaçla sınırlılık (m.4/2-c) gereği veri **turun dışında hiçbir yerde**
kullanılmaz: vardiya dışı konum, mola takibi, personel değerlendirme
puanlaması gibi kullanımlar üründe yoktur.

## Konum alınamazsa ne olur

**Okutma her hâlükârda kaydedilir.** Konum izni reddedildiğinde okutmayı
reddetmek, görevlinin işini yapmasını engellemek olurdu; sessizce konumsuz
kaydetmek ise boşluğu gizlerdi. Bu yüzden kayıt `konum_durumu` ile **nedeni**
taşır ve gün raporunda `konumsuz_sayisi` olarak amire **görünür**.

Yani konum **bir ön koşul değil, bir kanıttır**: yokluğu işi durdurmaz ama
saklanmaz.

## Kimler görür

`GET /scans` (gün raporu) **admin + yönetici** ile sınırlıdır. Sakin, güvenlik
personeli ve tesis görevlisi başka personelin konumunu görmez. Görevlinin
kendi okutmaları `/me/checkpoints` üzerinden kendisine açıktır.

## Başlangıç fotoğrafı

`tur_baslangic_foto_zorunlu` **tenant ayarıdır ve varsayılan olarak
KAPALIDIR**. Açıldığında yalnız tur penceresinin **ilk** okutmasında,
uygulama içi **kamera** ile bir fotoğraf istenir (galeriden seçim yoktur —
eski bir fotoğraf tura hiç çıkmadan tur başlatmak olurdu).

Fotoğraf çevrenin ve saatin (gündüz/gece) kanıtıdır; **kişiyi tanımlamak için
değildir** ve yüz tanıma/biyometrik işleme yapılmaz. Ayarın tenant seçimine
bırakılmasının nedeni de budur: gece vardiyasında kamera kullanımı her sitede
personel mahremiyeti açısından kabul görmez.

Fotoğraflar diğer kanıt görselleri gibi nesne deposunda (MinIO) tenant
ad-alanında tutulur ve okunurken kısa ömürlü imzalı bağlantı ile verilir.

## Saklama ve silme

Tur kayıtları, uygulamanın genel KVKK saklama/imha işine (gecelik
`scheduler.run_retention`) tabidir; konum alanları `scan_event` satırının
parçasıdır ve satırla birlikte silinir. Ayrı bir konum arşivi yoktur.

## Aydınlatma yükümlülüğü

Personelin **işe başlarken** aydınlatılması gerekir (KVKK m.10): hangi
verinin, hangi amaçla, hangi hukuki sebeple işlendiği ve saklama süresi.
Yukarıdaki tablo ve amaç bölümü bu metnin içeriğini karşılar. Sürekli takip
olmadığının açıkça yazılması önerilir — personelin en sık ve en haklı
endişesi budur.

İlgili: [KVKK saklama/imha](../backend/app/retention.py),
`docs/MASTER-PLAN.md` → P34.
