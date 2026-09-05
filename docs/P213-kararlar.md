# P213 — gürültü eşiği ayarı, kamera görüntüleme ve kayıt

## §1 — Gürültü eşikleri yönetici ayarında

### ÖLÇÜM — biri eksikti, üçü SESSİZCE bozuktu
| Ayar | Şema | `_to_settings` (GET) | Yönetici yazabilir mi |
|---|---|---|---|
| `gurultu_esigi` | ✅ | ✅ | ✅ |
| `gurultu_pencere_gun` | ✅ (P208) | ❌ **yok** | ❌ **403** |
| `gurultu_susma_gun` | ✅ (P208) | ❌ **yok** | ❌ **403** |
| `gurultu_sakin_uyarisi` | ✅ (P208) | ❌ **yok** | ❌ **403** |
| eskalasyon eşiği | ❌ **yok** (kod sabiti `asama >= 2`) | — | — |

İkinci sütun sessiz bir kusurdu: `TenantSettings` şeması alanları
tanımlıyor ama `_to_settings` doldurmuyordu → **GET her tesiste şema
varsayılanını dönüyordu** (30/7/true), yani ekran gerçek değeri hiç
göstermemişti. P165'te birebir aynı sınıf ölçülmüş ve o zaman
`rezervasyon_gecmis_ay` için not düşülmüştü — aynı tuzağa üç alan daha
düşmüş.

Web tarafında alanlar **zaten çizilmişti** (`lib/tesis-ayar-alanlari.ts`);
yani arayüz vardı, sunucu tarafı eksikti. Kullanıcının gördüğü şey
"değiştiriyorum ama değişmiyor"du.

### KARAR K1.1 — Dört ayar da yöneticide, dördü de yanıtta
`_YONETICI_YAZABILIR` kümesine ve `_to_settings`e eklendi. Gerekçe P37/P34
ile aynı: eşiği ve pencereyi **komşuluk ilişkisini bilen kişi** ayarlar;
platform operatörüne bırakmak her değişikliği destek talebine çevirirdi.

### KARAR K1.2 — Eskalasyon eşiği ayar oldu (göç 0105)
`gurultu_eskalasyon_esigi` (1..10, varsayılan **1**): N. eşik aşımından
**sonraki** her aşımda güvenliğe gider. Varsayılan 1 ⇒ ikinci 5'te —
P212'nin bugünkü davranışı **aynen** korunur.

**Neden 0 yok:** "her uyarıda güvenliği çağır" demek olurdu ve birinci
eşiğin anlamını silerdi. **Neden üst sınır 10:** daha büyüğü pratikte
"hiç çağırma"dır ve bunu ifade etmenin doğru yolu ayrı bir açma/kapama
anahtarıdır, kocaman bir sayı değil.

### KARAR K1.3 — Eşik 1: **uç reddetmez, arayüz uyarır**
İstek "1 yaparsa kullanılamaz hale gelir; uyar" diyordu. Eşiği 1'de
yasaklamadım: küçük bir sitede bu **bilinçli** bir tercih olabilir ve 422
dönmek meşru bir kullanımı imkânsız kılardı. Bunun yerine alan 1 olunca
ipucu satırı **uyarıya** dönüşüyor: *"Eşik 1: her gürültü şikâyetinde
daireye uyarı gider… 3 ve üzeri önerilir."* (7 dil)

### KARAR K1.4 — Değişiklikler denetime
Bu ayarlar paraya değil **bildirime** dönüşüyor: eşiği 1 yapan her
şikâyette daireye anons gönderir, eskalasyon eşiğini düşüren güvenliği
daha sık çağırır. "Kim ne zaman değiştirdi" bir anlaşmazlıkta sorulacak
ilk sorulardan. Denetim kaydı **eski + yeni** değerleri taşır ve yalnız
**gerçekten değişen** alanlar için yazılır.

Sınırlar üç yerde **aynı**: Pydantic `Field`, DDL `CHECK`, web alan
tablosu. Tesis bazında — testle kilitli (A'nın eşiği B'yi etkilemiyor).

### Kilit
Backend 7 test (dördü de yanıtta; yönetici değiştirebiliyor ve yanıt
**gerçek** değeri dönüyor; 7 geçersiz değer 422; eşik 1 kabul; denetim
kaydı; tesis izolasyonu; denetçi 403) + eskalasyon eşiğinin **gerçekten
kullanıldığı** (eşik 2 → üçüncü aşımda eskalasyon) P212 dosyasına eklendi.
Web 2 DOM testi (alan çizilir ve gönderilir; eşik 1'de uyarı görünür).
Göç geri alınabilir — downgrade→upgrade koşuldu.
