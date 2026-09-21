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

---

# P245 §2 — GÜVENLİK GRUBU (ui3)

Referans: **`ui3.png`** — dokuz güvenlik ekranı.

## 6. Ölçülen ortak desen

ui3'teki dokuz ekranın **hepsinde** aynı iskelet var: başlık + bir
cümlelik açıklama → **KPI şeridi** → filtre çubuğu → yoğun tablo.

Playwright ile yedi ekranı topluca görüntüledim. Ölçüm:

| ekran | başlık | KPI | filtre |
|---|---|---|---|
| `/arac-gecisleri` | ✔ | ✔ | ✔ (P244 §6a) |
| `/kameralar`, `/olaylar` | ✔ | ✔ | ✘ |
| `/patrol-plans`, `/checkpoints`, `/panik`, `/akilli-ev`, `/vardiya-plani`, `/kamera-kayitlari` | ✘ | ✘ | ✘ |

Yani altı ekran **üçünden hiçbirine** sahip değildi — `/patrol-plans`
çıplak bir başlık ve tek satırlık bir tablodan ibaretti.

Bu turda **dördü** kapatıldı: `/patrol-plans`, `/checkpoints`,
`/panik`, `/akilli-ev`.

## 7. UYDURULMAYAN SAYILAR — açıkça

Referansın KPI'ları her zaman bizde karşılığı olan sayılar değil:

* **Devriye Planları** — ui3 *"%92 Tamamlanma"* ve *"2 Aksama"* diyor.
  İkisi de plan listesinde **yok**, tur geçmişinde. Yerine bu listenin
  gerçekten yanıtladığı dört soru kondu (aktif plan, toplam plan,
  kontrol noktası, vardiya).
* **Acil Durum Çağrıları** — ui3 *"4 dk Ort. Müdahale"* ve *"%96
  Zamanında"* diyor. İkisi de çağrı başına **müdahale başlangıcı**
  damgası ister; kayıtta `created_at` ve `kapandi_at` var, **aradaki
  adım yok**. Sunucu onu vermeden hesaplanan bir "4 dk" ölçülmemiş bir
  sayıdır.
* **NFC Noktaları** — ui3 "Aktif / Pasif / **Bakımda**" diyor; bizde
  durum alanı iki değerli (`aktif`). Üç durumlu bir şerit, hiçbir zaman
  dolmayacak bir kart ilan ederdi. Üçüncü kart yerine **bugün okutulan**
  kondu — bu ekranın asıl sorusu "noktalar çalışıyor mu".

## 8. Hat iki GERÇEK KUSUR daha buldu

### 8.1 Giriş formu parolayı ADRES ÇUBUĞUNA yazıyordu

Ekran görüntüsü betiği formu **hidrasyon tamamlanmadan** gönderdi ve
tarayıcı **native** gönderim yaptı. `<form>`un varsayılanı GET olduğu
için kimlik ve **parola** adres çubuğuna düştü:

```
/login?username=...&password=...
```

Oradan tarayıcı geçmişine, `Referer` başlığına ve sunucu erişim
günlüklerine gider.

`onSubmit` bunu normalde engeller — **ama yalnız JS hazırsa**.
Hidrasyon gecikmesi, JS hatası ya da yavaş ağ formu bir anlığına
korumasız bırakıyordu. `method="post"` eklendi: o pencerede de gönderim
gövdeye gider. Sunucuda bu yolu karşılayan bir POST işlevi **yok** (405)
ve olması da gerekmiyor — istenen şey başarılı bir gönderim değil,
**sızmayan bir başarısızlık**.

### 8.2 `npm run build` çalışan dev sunucusunu bozuyor

Yarım saat "giriş çalışmıyor" diye aradım. Kök neden: `next.config`
`output: "standalone"` ve `npm run dogrula` içindeki `next build`,
çalışan `next dev`in `.next` dizinini **eziyor**. Statik parçalar 404
dönüyor, React hiç yüklenmiyor, sayfa sunucu çizimi olarak "çalışıyor"
görünüyor ama **hiçbir şey tıklanmıyor**.

**Kural:** ekran görüntüsü alırken `npm run dogrula` koşulmaz; zincir
en sona bırakılır ve sonrasında dev sunucusu yeniden başlatılır.

## 9. Betikteki iki yöntem hatası (ikisi de ölçümle bulundu)

* **Ard arda giriş**: her rota için yeniden giriş yapılıyordu; sekiz
  ardışık denemede hepsi zaman aşımına düştü. Tek oturum, çok rota.
* **"İçerik var" yetmedi**: `innerText.length > 200` koşulu sayfa
  başlığı çizilir çizilmez doğru oluyordu ve tablo hâlâ iskeletken
  görüntü alınıyordu (`/patrol-plans` yarım çıktı). Koşul artık
  **içerik var VE iskelet yok**.

## 10. Bu turda YAPILMAYAN — açıkça

* `/vardiya-plani` (1353 satır) ve `/kamera-kayitlari` (270) —
  başlık/KPI/filtre üçlüsü **eklenmedi**.
* Altı ekranın hiçbirine **filtre çubuğu** eklenmedi; bu tur KPI
  şeridine ve başlığa odaklandı.
* `ui3`ün "Bildirimler" ekranı (`/notifications`) ölçülmedi.
* Diğer beş grup (tesis, finans, operasyon, iletişim, tanımlar) bu turda
  açılmadı.

## 11. Doğrulama

`npm run dogrula` → **çıkış kodu 0** · **2121 test yeşil**.
Ekran görüntüleri: `docs/P245/` altında güvenlik grubundan yedi ekran.

---

# P245 §3 — GÜVENLİK GRUBU TAMAMLANDI

## 12. Kalan iki ekran

* **`/kamera-kayitlari`** — başlık + açıklama + iki kartlık şerit.
  **Sayılar kamera listesinden**, kayıt sayısından değil: bu ekranın ucu
  bir **aralık** sorar ve kayıt listesi **döndürmez**; "kaç kayıt var"
  sorusunu yanıtlayan bir uç **yok**. Ayrıca NVR kaydı sitede kalır
  (P213) — bulutta bir kayıt sayacı zaten olamaz.
  **Mevcut sorgu kutusu `FiltreCubugu`'na çevrilmedi:** o kutu bir liste
  süzgeci değil, kaydı getirmek için **zorunlu** alanlar; "temizle" ve
  "aktif süzgeç sayısı" orada anlamsız olurdu.
* **`/vardiya-plani`** — yalnız başlık paylaşılan bileşene taşındı.
  P240 §5a'nın kararı korundu ve güçlendi: asıl eylem başlık satırında,
  tek birincil düğme. Kontrol kümesine (görünüm seçici, filtreler,
  tazele, araçlar) **dokunulmadı** — P240/P241/P207'de ölçülmüş bir
  düzen. **KPI şeridi eklenmedi:** referansta da (ui3) bu ekranda şerit
  **yok**; eklemek referansı aşmak olurdu.

## 13. Filtre çubukları — ve sayaç tuzağı

Dört ekrana süzgeç geldi: `/olaylar` (durum), `/patrol-plans` (aktiflik),
`/checkpoints` (aktiflik), `/panik` (durum). **Hepsi sunucuda** —
istemcide süzmek yalnız görünen sayfayı arar.

**Her birinde aynı tuzak vardı ve dördünde de kapatıldı:** şerit
sayıları aynı listeden besleniyordu; süzgeç eklenince *"Kapatılmış"*
seçildiğinde **"Açık olay: 0"** yazacaktı — yani ekran, açık olay
**olmadığını** söyleyecekti. Sayaçlar artık **ayrı, süzgeçsiz** bir
istekten (P244 §8c'de bakım ekranında ölçülüp kilitlenen dersin aynısı).

`/kameralar` ve `/kamera-kayitlari`ya süzgeç **eklenmedi**: ui3'te o
ekranlardaki kontroller (ızgara yoğunluğu, harita, tam ekran, aralık)
**görünüm** kontrolleri, liste süzgeci değil.

## 14. BEŞİNCİ KEZ: `/api/violations` `durum`u düşürüyordu

Arka uç `durum`u destekliyor; vekil yalnız `limit`/`offset` taşıyordu.
Yani ekrana bir durum süzgeci eklendiği anda **sessizce çalışmayacaktı**.

Aynı kusur sınıfının **beşinci** örneği (P173, P189, P213 + P244 §6, §8a,
§8c). Kilitlendi; kırma denendi, yakalandı.

## 15. Hat ÜÇ KUSUR DAHA buldu

### 15.1 `<tr>` içinde `<tr>` — sekiz dosyada hidrasyon çöküyordu

`TabloBasligi` `<tr>`i **kendi** çiziyor. On beş çağrı yerinin
**dokuzu** içeriği ayrıca bir `<Tr>` ile sarıyordu → `<tr><tr>`,
**geçersiz HTML**. Tarayıcı iç `<tr>`i dışarı taşıyor, sunucu
çiziminden **farklı** bir ağaç oluşuyor ve React hidrasyonu **düşüyor**:
*"Hydration failed because the initial UI does not match what was
rendered on the server."* Sonuçta sayfanın tamamı istemcide yeniden
çiziliyordu.

**Hiçbir test görmedi:** `tsc` JSX'in HTML geçerliliğini denetlemez,
jsdom iç içe `<tr>`i sessizce kabul eder ve görünüm neredeyse aynı
kalır. Gerçek tarayıcıda, ekran görüntüsü alınırken konsolda çıktı.

Bileşenin sözleşmesi yazıldı, dokuz çağrı yeri düzeltildi, **yeni
`p245-tablo-basligi-tek-tr`** kilidi eklendi (kırma yakalandı).

### 15.2 `w-full` kazanıyordu, `w-auto` kaybediyordu

Filtre çubuğundaki durum seçimi şeridin **tamamını** kaplıyordu.
`Secim`in taban sınıfı `w-full` ve çağıranın verdiği `w-auto`
kazanmıyor: iki sınıfın **özgüllüğü aynı**, hangisinin kazandığını
`className` sırası değil **üretilen CSS'teki sıra** belirler. Kural
açıkça yazıldı: çağıran bir genişlik sınıfı verdiyse taban `w-full`
**eklenmez**.

### 15.3 `/panik`: yüklenirken boş tablo, boş durumda "alert" yazısı

Koşul yalnız "boş durum"u ayırıyordu; `isLoading` doğruyken else dalına
düşerek **başlıksız, satırsız bir tablo** çiziyordu. İskelet eklendi.

Ayrıca `ikon="alert"` — `BosDurum.ikon` bir `ReactNode` bekler; dize
verilince **aynen çizilir** ve ekranda "alert" yazıyordu. jsdom'da da
öyleydi ama **hiçbir iddia onu sorgulamıyordu**.

## 16. Bilinçli güncellenen iddia

`guvenlik-ekranlari` testi "kaynak seçtirilmez" kuralını *"sayfada hiç
`combobox` yok"* diye ölçüyordu — kuralın kendisi değil bir **vekil**.
Sayfaya durum süzgeci gelince düştü. Sorgu **diyaloğa** kapsamlandı;
iddia değişmedi.

## 17. Bu turda YAPILMAYAN — açıkça

* `/kameralar`a başlık/şerit **vardı**, süzgeç eklenmedi (yukarıda).
* `ui3`ün "Bildirimler" ekranı (`/notifications`) hâlâ ölçülmedi.
* Diğer beş grup açılmadı.

## 18. Doğrulama

`npm run dogrula` → **çıkış kodu 0** · **2126 test yeşil**.
