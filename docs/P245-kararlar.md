# P245 — ÖZET SAYFASI: REFERANSA UYDURMA

Referans: **`docs/tasarim-referans/ui5.png`**.

**Bir düzeltme:** brief `ui4.png` diyordu; ui4 **20 ekranın mozaiği**.
Tarif edilen özet düzeni (karşılama bandı + 4 KPI + büyük maket + sağ
sütun + alt sıra) **ui5**. Yanlış görselle çalışmak haftalarca yanlış
yöne gitmek olurdu, bu yüzden önce doğrulandı.

---

## 1. YÖNTEM: SONUCU GÖRMEK

Kök neden kabul edildi: **jsdom yerleşim hesaplamaz.** Genişlik, oran ve
boşluk ölçülemez; testler yeşilken sayfa referansa benzemeyebilir.

**YENİ `admin-web/scripts/ekran-goruntusu.mjs`** — gerçek Chromium,
1440×900, gerçek veri, gerçek oturum.

Hat kurulurken üç engel ölçüldü ve çözüldü:

| engel | ölçüm | çözüm |
|---|---|---|
| `localhost` = platform yüzeyi | yönetici girişi **403** ("panel yalnız platform yöneticisi") | `app.localhost:3000` — `konakYuzeyi()` ilk DNS etiketine bakar |
| İlk-giriş turu ekranı kaplıyordu | modal tıklamayla kapanmıyordu | işaret **sunucuda** (`POST /me/tur-goruldu`) |
| Kurulum hatırlatıcısı | hidrasyon bitmeden tıklama modalı geri getiriyordu | `localStorage` işareti **sayfa yüklenmeden** yazılıyor |

**Ve bir yöntem hatası kendi ölçümüm yakaladı:** ilk sürüm sabit
`waitForTimeout` kullanıyordu; görüntü iki kez **yarım** çıktı
(iskeletler, boş maket, "Henüz duyuru yok"). Sabit süre, derleme + SWR +
WebGL'in ne kadar süreceğini **tahmin etmektir**. Bekleme **içerik
koşuluna** bağlandı.

### 1.1 Hat ilk çalıştığında BİR HATA BULDU

Konsolda **hidrasyon uyuşmazlığı**: sunucu `"September 2026"`, istemci
`"Eylül 2026"`. React **tüm belgeyi** değiştiriyordu.

Sebep: `Intl.DateTimeFormat(undefined, …)` — sunucu kullanıcının dilini
bilmiyor. Dört kullanım `dil` parametresine geçti. **Hiçbir test bunu
görmüyordu**; ekran görüntüsü hattının ilk çıktısı buydu.

---

## 2. ÖLÇÜLEN FARKLAR ve KAPATILANLAR

| # | ui5 | ölçüm (önce) | şimdi |
|---|---|---|---|
| 1 | Bina görselli karşılama bandı + sağda ifade | düz gradyan, sağ taraf boş | nötr bina silueti + ifade |
| 2 | 4 KPI: büyük sayı, ikon, alt açıklama | 5 kısayol kartı, **sayı yok** | 4 kart, **gerçek veriyle** |
| 3 | Maket solda, ~%65, 3D/Harita geçişi, arama | sağda ~%38, geçiş yok | 2/1 satır, geçiş + arama |
| 4 | Sağda Hızlı İşlemler + Duyurular | **yok** | var |
| 5 | Alt sıra: tahsilat halkası + talepler + son işlemler | **yok** | üç eşit sütun |
| 6 | Tam genişlik | dev takvim sayfayı ele geçiriyordu | takvim aşağı indi |

### 2.1 Düzen motoru referansın oranlarını bilmiyordu

Motor yalnız `tam` ve `yarim` biliyordu — yani maket **ancak yarım
genişlikte** çizilebiliyordu. "Maket sağda küçük bir kutu" şikâyetinin
doğrudan sebebi buydu.

Eklenen: `genis` + `dar` → **2/1**, `uc` ×3 → **üç eşit**.

**Oran kayda yazılmaz**, bölümün kendi tanımından türer: aynı bilgiyi
iki yerde tutmak, biri değişince ötekini bayatlatmaktı. Kullanıcı satırı
elle kursa bile maket yine büyük çizilir.

### 2.2 KPI: gerçek veri, uydurma trend yok

| kart | kaynak |
|---|---|
| Toplam daire | `building-map` (sayfada zaten çekiliyor) |
| Tahsilat oranı | `/finans/tahsilat-gostergesi` — tahsil/tahakkuk + `degisim_puan` |
| Açık talepler | `/unit-complaints/gorunur-sayi` + `?oncelik=yuksek` |
| Toplam borç | `/finans/yaslandirma?ozet=true` — tutar + borçlu daire sayısı |

**Yeni sunucu ucu açılmadı**: beşi de backend'de vardı ve başka
ekranlarda kullanılıyordu. P244'ün "yeni uç yok" kilidi bu gerekçeyle
güncellendi — iddia hâlâ *"pano sunucuya yeni uç eklettirmez"*.

**Trend yalnız verisi olanda.** Sözleşme yalnız tahsilat için
`degisim_puan` veriyor; talep ve borç için önceki-ay karşılaştırması
**hiçbir uçta yok**. Ok çizmek uydurmak olurdu.

**YAPILAMAYAN — açıkça:** referansın "Toplam Daire %87 dolu / %13 boş"
alt satırı **çizilemedi**. Doluluk bilgisi hiçbir uçta yok (`Unit`
şemasında sakin/doluluk alanı bulunmuyor) ve daire başına
`/units/{id}/residents` çağırmak bir KPI için N istek demekti. Yerine
gerçek olan yazıldı: "3 blokta". **Bu bir backend toplaması ister.**

### 2.3 Devriye sayaçları kaybolmadı — rol uyumlu oldu

Şerit eskiden "geciken okutma" ve "bugünkü tur"u gösteriyordu.
Referansın dört başlığı mali; mali yetkisi **olmayan** rolde o iki kart
zaten çizilmiyor ve şerit yarıya düşerdi.

Çözüm: yönetim referansın dördünü görür, **yetkisiz rol aynı yerde
kendi dört sayısını**. Hiçbir bilgi silinmedi.

### 2.4 Maket: iki görünüm zaten vardı, birleştirildi

3B sahne panoda, plan haritası `/schematic`te. Referans ikisini **aynı
kartta** yan yana koyuyor. Yeni görünüm yazılmadı; var olan ikisi tek
kartta birleşti ve **seçim ortak durumda** — sekme değişince seçili
daire korunur.

**Lejant referansın altısı değil, bizim ikimiz.** Referans
Dolu/Boş/Borçlu/Kiracı/Malik/Tadilat diyor; bizim maketimiz bu sayfada
yalnız **iki** durum üretiyor (şikâyeti var / yok). Altı durumlu bir
lejant, hiçbir zaman çizilmeyecek dört renk ilan ederdi.

**Etkileşim korundu** (P244 karar 6): geometri, kamera, tıklama, seçim
tek satır değişmedi.

### 2.5 Son işlemler yalnız platform adminine

Ölçüldü: `GET /audit` `require_role("admin")` ile korunuyor, yöneticiye
**403**. Denetim kaydı bir KVKK yüzeyidir; yöneticiye açmak bir arayüz
turunun vereceği karar değil. Yetkisiz rolde bölüm **hiç çizilmez** —
boş bir kart bırakmak, olmayan bir şeyin yerini ayırmaktı.

### 2.6 Kendi hatam: aynı metin iki anlamda

Hızlı işlem düğmesini "Aidat tahsilatı" diye adlandırdım — KPI kartının
etiketiyle **aynı dize**. Test "birden çok eleman" diyerek yakaladı.
P239'da kaydedilen dersin aynısı; düğme "Tahsilat gir" oldu.

---

## 3. EKRAN GÖRÜNTÜLERİ — `docs/P245/`

| dosya | ne |
|---|---|
| `ozet-yonetici-acik-standart.png` | ana referans karşılaştırması |
| `ozet-yonetici-koyu-standart.png` | koyu tema |
| `ozet-yonetici-acik-buyuk.png` | Büyük görünüm modu |
| `ozet-denetci-acik-standart.png` | denetçi (salt okuma) |
| `ozet-admin-acik-standart.png` | platform admini (`panel.*`) |

**ÖLÇÜLEN SINIR — istenen üç rolden ikisi alınamadı:** `security` ve
`resident` hesapları web girişinde **403** alıyor — *"Bu hesap türü
Yönetiyor mobil uygulamasında çalışır"* (P129 kararı). O iki rolün
**web özet sayfası yoktur**. Yerine web'de panoyu gören diğer iki rol
alındı: **denetçi** ve **admin**.

---

## 4. Bu turda YAPILMAYAN — açıkça

* **Karşılama bandında gerçek fotoğraf yok.** `Tenant` şemasında
  logo/kapak alanı bulunmuyor; fotoğraf çizilemezdi. Nötr bina silueti
  çizildi (ağ isteği yok, temayla kaymaz). Gerçek fotoğraf **sözleşme +
  backend** işi.
* **Daire doluluk oranı** (yukarıda).
* **Yan panel tek bölüm**: Hızlı İşlemler ve Duyurular birlikte
  gizlenir/taşınır, ayrı ayrı değil. Motor satır başına bir bölüm/sütun
  çizdiği için ikisini ayırmak onları yan yana koymak demekti.
* **Yalnız Özet sayfası.** Diğer altı grup bu turda açılmadı.

## 5. Doğrulama

`npm run dogrula` (tsc + next lint + vitest + **next build**) →
**çıkış kodu 0** · **2121 test yeşil** · **YENİ** `p245-ozet-duzeni`
(7 iddia); iki kırma denendi, ikisi de yakalandı.
