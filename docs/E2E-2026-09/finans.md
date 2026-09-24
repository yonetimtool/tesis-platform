# FİNANS — E2E bulguları (etiket: `finans`)

- Tesis: `e2e-finans-sitesi-ed2ecc` (tenant `7862c804-813c-47d5-9861-1ffefa4f3f3b`); boş tesis + sınır testleri: `finansbos` (`d2845d2a-…`).
- Betikler `$S/finans/s1…s13*.py`, rapor çıktıları `$S/finans/rapor/`, ekran görüntüleri `$S/finans/ekran/`, makbuz `$S/finans/makbuz.pdf` (+`makbuz_s1.png`).
- Tarih 2026-09-23 (dönem 2026-09). Otomasyon görevi YALNIZ kendi tesisim için worker içinde fonksiyon düzeyinde tetiklendi (`$S/finans/oto.py` → `aidat_planlari_isle / borc_hatirlatmalari / duzenli_giderleri_isle / gecikme_faizi_otomatik`); global `finans_otomasyonu()` başka ajanların tesislerine dokunacağı için ÇAĞRILMADI.
- Senaryo: KASA açılış 12.500 ₺, BANKA 84.300,50 ₺; 20 daire × 1.750 ₺ aidat (toplu, "Aidat" tanımı, kullanan öder), A-1 ve B-5'e 400 ₺ demirbaş (malik öder), A-1'e 125,50 ₺ elektrik; vezne / aidat ucu / banka ekstresi tahsilatları; 12.000 ₺ onaylı gider, 3.500 ₺ reddedilen gider, 4.250,75 ₺ elektrik, 6.000 ₺ baz istasyonu geliri; virman 2.500 ₺; iade; gecikme faizi %5; mesai 27 saat × 200 ₺ × 1,5 = 8.100 ₺.

## KONTROL LİSTESİ

| # | Madde | Sonuç | Kanıt |
|---|---|---|---|
| 4.1a | Kasa aç (nakit + banka, IBAN) | GEÇTİ | 201; nakit kasaya IBAN → 422 (kasıtlı) |
| 4.1b | Kasa açılış bakiyesi doğrulaması | KALDI | −100 kabul (201), 10^20 → **500** (FINANS-15) |
| 4.1c | Gelir/gider tanımı, "kim öder" kuralı (malik / kiracı öncelikli) ayarlanabiliyor mu | GEÇTİ | POST + PATCH `hedef_kurali` 200 |
| 4.1d | Aidat planı oluştur | GEÇTİ | 201, listede; `son_donem` boş |
| 4.2a | Tekil tahakkuk | GEÇTİ | A-1 demirbaş 400 ₺ → hedef Zeynep Malik (malik) |
| 4.2b | Toplu borçlandırma, dairelerde borç görünüyor | GEÇTİ | 20 daire × 1.750 = 35.000 ₺; `/units/{id}/dues` bakiyeleri doğru |
| 4.2c | Aynı dönemi ikinci kez (Finans → Borçlandırma) | GEÇTİ | `olusan:0, atlanan:20` + web kırmızı "oluşmadı" |
| 4.2d | Aynı dönem, "Aidat" sayfasından (tanımsız toplu) | KALDI | aynı ay 2. kez aidat yazıldı — A-9: 2 × 1.750 (FINANS-10) |
| 4.2e | Malik/kiracı ayrımı | GEÇTİ (hedefleme) / KISMEN (tahsilat eşleme) | A-1 aidat+elektrik → kiracı, demirbaş → malik; B-5 hepsi → malik-oturan. Ama banka eşleşmesi FIFO'yu hedeften bağımsız yapıyor (FINANS-05) |
| 4.2f | Otomatik aylık tahakkuk (beat) | GEÇTİ | Elle yazılmış ayı atlıyor (idempotent, 20 atlanan), telafi çalışıyor (11-02'de önce 2026-10, sonra 2026-11), tekrar = 0. Öneri: FINANS-18 |
| 4.3a | Web: daire seç → kişi otomatik | GEÇTİ | B-5 → Elif Oturan otomatik; A-1 (2 sakin) → seçim kullanıcıda |
| 4.3b | Tahsilat → borç kapanıyor | KISMEN | daire seçilirse kapanıyor; kişi-yalnız (peşin kutusu / borçlu listesinden daire boş) kapanmıyor (FINANS-01) |
| 4.3c | Makbuz üretiliyor mu (PDF) | KISMEN | Yalnız banka eşleşmesinde üretiliyor (PDF güzel, Türkçe doğru). Vezne `/finans/tahsilat` ve `/dues/payments` makbuz ÜRETMİYOR (FINANS-02) |
| 4.3d | Sakine bildirim | KISMEN | Banka eşleşmesinde `aidat_odendi` bildirimi var; vezne tahsilatında 0 bildirim — mobil ekran "bildirim sunucuda üretilir" diyor (FINANS-02) |
| 4.3e | Çift tıklama (aynı anahtarla 2/5 paralel) | GEÇTİ | `/finans/tahsilat` ve `/dues/payments`: [201,200,200,200,200] → 1 kayıt |
| 4.3f | Farklı/anahtarsız paralel istek | Öneri | anahtarsız 2 ardışık istek = 2 kayıt; `/finans/tahsilat` başlığı zorunlu değil (bilinçli karar P64) — web+mobil gönderiyor |
| 4.3g | Kısmi ödeme | GEÇTİ | A-2 1.000 / 1.750 → bakiye 750 |
| 4.3h | Fazla ödeme → alacak | GEÇTİ | A-3 2.000 / 1.750 → bakiye −250 (alacak); daire bakiyesi net olduğu için sonraki tahakkuktan düşer |
| 4.4a | Gider onaya düşüyor, bakiyeyi düşürmüyor | GEÇTİ | KASA 16.505,67 değişmedi, "bekleyen çıkış" 12.000 |
| 4.4b | Onayla → bakiye düşer; tekrar onay 409 | GEÇTİ | 16.505,67 → 4.505,67; 409 |
| 4.4c | Reddet → bakiye değişmez | GEÇTİ | |
| 4.4d | Onay bekleyen / reddedilmiş gideri **iptal** | KALDI | kasaya olmayan para giriyor (+900 / +3.500 ₺) (FINANS-03) |
| 4.4e | Fiş/fatura ekleme | KISMEN | JPEG eklendi (presign+PUT+`/ekler` 201); **PDF fatura reddediliyor** (FINANS-17) |
| 4.5a | Kasa bakiyesi = açılış + hareketler | KISMEN | API = DB defter (birebir) — ama defterde hayali satırlar var (FINANS-03, 04) ve onaylanmış mesai gideri hiçbir kasada yok (FINANS-08) |
| 4.5b | Toplam borç = tahakkuk − tahsilat; daire ↔ finans ekranı | KALDI | Daire toplamı 33.269,83 ₺; `/finans/ozet` açık borç 31.119,83; Borç-Alacak raporu 30.764,83; yaşlandırma 3.500 — dört farklı rakam (FINANS-06) |
| 4.5c | Şeffaflık = yönetici ekranı | KALDI | Tahsilat oranı %3 (gerçek ~%28), "ödeyen daire 0"; gider dağılımı yüzdeleri toplamı %116 (FINANS-07, 12) |
| 4.5d | Sakin borcu = yönetici borcu | GEÇTİ (sayı) / Öneri (kapsam) | 4 sakinde de `/me/dues` = `/units/{id}/dues`. Kiracı malikin demirbaşını da kendi borcu gibi görüyor (FINANS-19) |
| 4.5e | Sakin `/finans/*` erişimi | GEÇTİ | 403 ×4 |
| 4.6a | Gecikme faizi | KALDI | Daire düzeyinde tamamen ödenmiş borca faiz yazıldı (FINANS-04); idempotent (2. koşum 0) |
| 4.6b | Borç hatırlatma | KISMEN | gönderiliyor (notification satırı, doğru alıcı); metin "son ödeme: 100" (gün sayısı), tutar ödenmiş parayı görmüyor (FINANS-13) |
| 4.6c | Virman | GEÇTİ | genel toplam değişmedi; aynı kasa 422 |
| 4.6d | İade (ters kayıt) | KALDI | iade + iptal birlikte uygulanabiliyor → çift ters kayıt, kasa ve borç bozuluyor (FINANS-09); virman bacağı tek başına iade edilebiliyor |
| 4.6e | Tahakkuk ters kaydı | GEÇTİ | 9.999 → geri; ikinci kez 409 |
| 4.6f | Banka ekstresi içe aktarma + eşleştirme | KISMEN | içe aktar 4, tekrar "0 eklendi 4 yinelenen"; ödeme kodu eşleşti, makbuz+bildirim; çıkış satırı onay bekleyen gider oldu. AMA borç dağıtımı yanlış kaleme (FINANS-05) |
| 4.6g | Bütçe hedef vs gerçekleşen | GEÇTİ | Bakım hedef 12.000, gerçekleşen 1.500, sapma −10.500 (%−88) |
| 4.6h | Borçlular / yaşlandırma | KALDI | ödenmiş A-4 "61-90 gün, 1.000 ₺" kovasında (FINANS-04 ile aynı kök) |
| 4.6i | Fazla mesai finansa düşüyor mu | KISMEN | onay bekleyen gider olarak düşüyor ama KASASIZ ve ikinci basışta İKİNCİ KEZ yazılıyor (FINANS-08) |
| 4.7a | PDF indiriliyor | GEÇTİ | 9 rapor × PDF 200, `application/pdf`, başlıkta tesis adı, tarih aralığı, "Sayfa n / m" |
| 4.7b | Excel (openpyxl ile açıldı) | KISMEN | 9 rapor açılıyor; grafikli sayfalarda tablo verisi sağa ikinci kez kopyalanmış (FINANS-16) |
| 4.7c | Grafik doğru mu | KISMEN | grafik ayrı sayfada, rakamlar tabloyla aynı; ama tablo başlığı veri olmadan tekrarlanıyor (FINANS-16) |
| 4.7d | Rapor rakamları birbirini tutuyor mu | KALDI | Eylül gideri: şeffaflık 22.365,75 / gelir-gider özet 16.250,75 / denetim 22.785,75 / muhasebe aktarım borç 30.885,75 (FINANS-11) |
| 4.7e | Boş tesiste "veri yok" / boş grafik | KISMEN | boş grafik çizilmiyor (iyi); ama "veri yok" cümlesi yok, yalnız "TOPLAM 0,00" satırı (FINANS-16) |
| 4.7f | Kasa ekstresi kasa süzgeci | KALDI | `kasa_id=KASA` verildi, 10 satır "Site Banka" + 2 kasasız satır geldi (FINANS-14) |
| 4.7g | SSLError (MinIO presign) | GEÇTİ | makbuz presign `http://192.168.20.101:9000/…` 200, 44 KB PDF indi |
| 11.2 | Sıfır / negatif / kesirli / metin tutar | GEÇTİ | 422 (tahsilat, tahakkuk, gider, plan, mesai) |
| 11.2 | KURUS_UST_SINIR | KISMEN | 10^15 kabul, 10^15+1 422; ama sınır JS güvenli tamsayıyı 10 satırda aşıyor, kasa açılışında sınır yok (FINANS-15) |
| 11.3 | Geçmiş/ileri tarih | KISMEN | tarih 1900 → 422 (anlaşılır mesaj), 2026-02-30 → 422; 2099-12-31 tahsilat KABUL; `donem` "2026-13", "abc", "1900-01" KABUL (FINANS-15) |
| 11.3 | Eşzamanlı tahsilat | GEÇTİ | bkz. 4.3e |
| 13.3 | Denetim kaydı | GEÇTİ | finans_hareket_create/onay/red, dues_payment_record, mesai_gidere_yaz satırları var |
| 13.5 | Denetçi okur, yazamaz | GEÇTİ | GET 200 ×4, POST 403 ×2 |
| 13.6 | Başka tesis kasası / hareketi | GEÇTİ | 422 kasa bulunamadı / 404 |
| — | Tahsilat oranı tek kaynak (Borçlular = rapor = şeffaflık) | KALDI | gösterge %3, şeffaflık %3, Tahsilat Performansı raporu %28 (FINANS-07) |

(Web ekran doğrulaması bölümü aşağıda ayrıca.)

---

## BULGULAR

### FINANS-01: Daire seçilmeden alınan tahsilat daire borcunu kapatmıyor (para kasada, borç açık)
- Sınıf: **Engelleyici**
- Rol / yüzey: yönetici / API + web ("Peşin ödeme" kutusu, ya da borçlu listesinden seçip daireyi boşaltma) + mobil (`finans_api.dart` `unit_id` opsiyonel)
- Adımlar: B-5 (Elif Oturan) borcu 2.150 ₺. `POST /finans/tahsilat {user_id: Elif, kasa_id: BANKA, tutar: 215000, yontem: havale}` (daire yok).
- Beklenen: B-5 bakiyesi 0.
- Olan: 201, BANKA +2.150 ₺ — ama `/units/B-5/dues` bakiye **2.150 ₺** kaldı; sakin `/me/dues` 2.150 ₺ borç görüyor; Borç-Alacak raporunda Elif'in tahsilatı **0**; banka eşleştirme de bu kişiyi hâlâ borçlu sayıyor. DB: `unit_id IS NULL` tahsilat 1 satır / 2.150 ₺.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/defter.py:198` `tahsilat_etkisi()` daireyi yalnız `FinansalHareket.unit_id` (ya da ters kaydın orijinali) üzerinden bulur; `daire_odenen` `unit_id IS NOT NULL` süzer (`defter.py:260`). `routers/finans.py:268` `tahsilat()` kişiden daireyi türetmiyor. Web `admin-web/app/(protected)/finans/tahsilatlar/page.tsx:227` `unit_id: daireId || null`.
- Önerilen düzeltme: tahsilatta `unit_id` yoksa kişinin aktif dairesinden türet (tek daire) ya da 422 iste; kişi çok daireliyse seçim zorunlu olsun. Mevcut `unit_id`siz tahsilatlar için onarım göçü.

### FINANS-02: Vezne tahsilatında makbuz üretilmiyor ve sakine bildirim gitmiyor — mobil ekran tersini söylüyor
- Sınıf: **Ciddi**
- Rol / yüzey: yönetici / web + mobil (`/finans/tahsilat`), `/dues/payments`
- Adımlar: 4 tahsilat (vezne ×2, aidat ucu ×2) + paralel denemeler; ardından `receipt` ve `notification` tabloları.
- Beklenen: her tahsilatta makbuz (PDF) + sakine "ödemeniz alındı" bildirimi (mobil `finansMakbuzNotu`: "Makbuz numarası ve sakine giden bildirim sunucuda üretilir — web ile aynı.", P206 K4.1).
- Olan: `receipt` 0 satır, `notification` artışı 0. Makbuz + `aidat_odendi` bildirimi YALNIZ banka eşleşmesinde (`routers/banka.py:239`) üretiliyor. Sakin `/me/makbuzlar` yalnız banka makbuzunu görüyor; vezneden ödeyen sakinin makbuz arşivi boş.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/finans.py:250-310` ve `routers/dues.py:660-800` makbuz/bildirim çağırmıyor; `makbuz_pdf` tek çağrı yeri `routers/banka.py:239`.
- Önerilen düzeltme: `_bildir_ve_makbuz` benzeri bir yardımcıyı üç tahsilat yolunun (vezne, aidat ucu, kart) ortak ucuna taşı; ya da mobil/web metnini düzelt.

### FINANS-03: Onay bekleyen ya da REDDEDİLMİŞ gideri "iptal" etmek kasaya hayali para ekliyor
- Sınıf: **Engelleyici**
- Rol / yüzey: yönetici / API (`POST /finans/hareketler/{id}/iptal`) — web "iptal" menüsü aynı ucu çağırıyor
- Adımlar: (a) 900 ₺ onay bekleyen gider → iptal. (b) 3.500 ₺ gider → reddet → iptal.
- Beklenen: bakiye değişmez (hiç çıkmamış para geri girmez); ya da 409 "gerçekleşmemiş hareket iptal edilemez".
- Olan: (a) KASA 4.505,67 → **5.405,67** (+900), bekleyen 900 hâlâ duruyor; ardından aynı "iptal edilmiş" gider **onaylanabildi** (200). (b) KASA 4.505,67 → **8.005,67** (+3.500 hayali). Muhasebe aktarımında `IPT-2026-000002 iptal x … alacak 3.500,00` satırı var; şeffaflık "toplam gider"i 3.500 düşük.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/finans.py:540-575` `hareket_iptal` orijinalin `durum`una bakmıyor; ters satır `durum` varsayılanı `'odendi'` (`models.py` FinansalHareket.durum server_default). `_onaylanabilir` (`finans.py:588`) iptal edilmiş olmayı kontrol etmiyor.
- Önerilen düzeltme: yalnız `durum='odendi'` satırlar iptal edilebilsin (onay bekleyen = reddet), ters satır orijinalin durumunu taşısın; ters kaydı olan satırda onay/red 409.

### FINANS-04: Daire düzeyinde ödenmiş borç "ödenmemiş" sayılıyor → haksız gecikme faizi, yanlış yaşlandırma/hatırlatma/banka eşleşmesi
- Sınıf: **Engelleyici**
- Rol / yüzey: yönetici / API + web (web tahsilat formu `assessment_id` GÖNDERMİYOR, yani web'den alınan her tahsilat bu sınıfta)
- Adımlar: A-4'e vadesi 2026-07-15 olan 1.000 ₺ tahakkuk; web'in yaptığı gibi `POST /finans/tahsilat {unit_id: A-4, tutar: 100000}` (kalemsiz); gecikme %5; önizleme + işle.
- Beklenen: A-4 için faiz yok, yaşlandırmada yok.
- Olan: önizleme "A-4 kalan 1.000 ₺, faiz 100 ₺"; işle → A-4'e **100 ₺ faiz kalemi yazıldı** (bakiye 1.705,49 → 1.805,49). `/finans/yaslandirma` A-4'ü 61-90 kovasında 1.000 ₺ gösteriyor; Tahsilat Performansı raporu "61-90 gün: 2.000,00". Aynı mantık banka eşleştirmesinde: A-1 kiracının 1.750 ₺'lik aidatı vezneden ödenmişken eşleştirme onu "açık" sayıp malikin 400 ₺'sinin 274,50'sini ona yazdı (FINANS-05).
- Tekrarlanabilir: evet
- Şüpheli kök neden: kalem düzeyinde "ödenen" yalnız `assessment_id` taşıyan tahsilatlardan: `defter.tahakkuk_odenen` (`defter.py:268`) ← `gecikme.py:123`, `yaslandirma.py:105`, `banka_servis.py:48 _acik_borclar`. Daire düzeyindeki (kalemsiz) tahsilat hiçbir kaleme FIFO ile mahsup edilmiyor.
- Önerilen düzeltme: kalemsiz tahsilatı yazarken FIFO ile kalemlere dağıt (banka eşleşmesinin `fifo_dagit`i var) ya da `tahakkuk_odenen`i "daire ödemesinin FIFO dağılımı" olarak hesapla; web formu borç kalemini göndersin.

### FINANS-05: Banka eşleştirmesi ödemeyi ödeyenin değil dairenin "en eski" kalemine dağıtıyor (malikin parası kiracının borcuna)
- Sınıf: **Ciddi**
- Rol / yüzey: yönetici / API `/banka/eslestir`
- Adımlar: A-1: kiracı Can'ın aidatı 1.750 (vezneden ödenmiş) + elektrik 125,50; malik Zeynep'in demirbaşı 400. Ekstre satırı "ZEYNEP MALIK CATI ONARIM 400,00" → eşleştir.
- Beklenen: 400 ₺ Zeynep'in demirbaş kalemine; makbuzda "demirbaş 400".
- Olan: `payment_match` 2 satır: 125,50 → **Can'ın elektrik** kalemi, 274,50 → **Can'ın (zaten ödenmiş) aidat** kalemi. Zeynep'in demirbaşı kalem düzeyinde açık kaldı. Muhasebe/Makbuz dökümünde tek transfer iki makbuz numarası (TAH-…021, …022) aldı.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `banka_servis.py:124 adaylari_topla` her adaya DAİRENİN tüm borçlarını veriyor (`borclar.get(unit_id)`), `hedef_user_id` süzgeci yok; `_acik_borclar` (`banka_servis.py:48`) `gecerli_tahakkuk()` süzgecini de uygulamıyor (ters kayıtlı tahakkuk açık borç sayılabilir) ve kalemsiz ödemeleri görmüyor (FINANS-04).
- Önerilen düzeltme: adayın borç listesini `hedef_user_id == aday.user_id` (+ hedefsiz daire borçları) ile sınırla; `gecerli_tahakkuk()` ekle.

### FINANS-06: "Açık borç" dört ekranda dört farklı rakam
- Sınıf: **Ciddi**
- Rol / yüzey: yönetici / web+API
- Adımlar: senaryo sonunda: daire bakiyeleri toplamı (API `/units/{id}/dues`, DB'den bağımsız hesapla birebir aynı) vs `/finans/ozet` vs Borç-Alacak raporu vs yaşlandırma.
- Olan: daire toplamı **33.269,83 ₺** (alacaklar hariç 33.519,83); `/finans/ozet.acik_borc_kurus` **31.119,83** (fark 2.150 = FINANS-01'in dairesiz tahsilatı); Borç-Alacak raporu bakiye **30.764,83** (A-2 satırı 2.602,72 — daire ekranı 1.377,72: aidat ucundan alınan 1.000 ₺ kişiye bağlanmadığı için rapora girmiyor, "dönem başı gecikme" 225 ₺ ekleniyor; A-7 satırı 1.750 — daire ekranı 2.550); yaşlandırma 3.500.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `/finans/ozet` (`routers/finans.py:1080`) tenant geneli `tahakkuk − tahsilat` (dairesiz tahsilat dahil); Borç-Alacak raporu kişi (`user_id`) bazlı gruplayıp `unit_id`li ama `user_id`siz tahsilatı düşürüyor ve iptal satırını saymıyor (`routers/rapor_motoru.py` borc_alacak).
- Önerilen düzeltme: açık borç tek fonksiyon (`defter.daire_bakiye` toplamı) üzerinden; raporda kişisiz tahsilat "Daire (kişi atanmamış)" satırında görünsün.

### FINANS-07: Tahsilat oranı %3 görünüyor (gerçek ≈ %28) — şeffaflıkta sakinlere "ödeyen daire 0, geciken 20" yayınlandı
- Sınıf: **Engelleyici** (sakinlere yanlış mali bilgi yayınlanıyor)
- Rol / yüzey: yönetici + sakin / web (Borçlular, finans özeti), şeffaflık (yayınlanmış), mobil gösterge
- Adımlar: Eylül'de 18 tahsilat (10.105,67 ₺). `GET /finans/tahsilat-gostergesi`, `GET /transparency/2026-09` (yayınla → sakin olarak oku), Tahsilat Performansı raporu.
- Beklenen: tek oran (P192 "TEK KAYNAK").
- Olan: gösterge `tahakkuk 36.125,50, tahsilat 1.150,00, oran %3`; şeffaflık (sakin görüyor) `tahsilat 1.150, oran %3, odeyen_daire 0, geciken_daire_sayisi 20`; Tahsilat Performansı raporu `tahsil 10.105,67, %28`. DB: `donem IS NULL` tahsilat **15 satır / 8.955,67 ₺**, dönemli 3 satır / 1.150 ₺.
- Tekrarlanabilir: evet
- Şüpheli kök neden: gösterge/şeffaflık `defter.tahsilat_toplami(donem=…)` ile DÖNEM süzüyor; web vezne formu `donem` göndermiyor ve `finans.py:271` yalnız `assessment_id` varsa dönemi türetiyor; `/dues/payments` da kalemsiz ödemede `donem=NULL` yazıyor (`dues.py:695`). Rapor ise işlem tarihiyle süzüyor.
- Önerilen düzeltme: kalemsiz tahsilatta dönemi FIFO ile kapattığı kalemin döneminden (yoksa işlem tarihinin ayından) türet; mevcut `donem IS NULL` satırlar için onarım.

### FINANS-08: Fazla mesai gideri kasasız yazılıyor ve her basışta yeniden yazılıyor
- Sınıf: **Ciddi**
- Rol / yüzey: yönetici / API `POST /mesai/gidere-yaz` (web `/finans/mesai`)
- Adımlar: security için 6 × 12 saat vardiya, saatlik 200 ₺ → özet 27 saat / 8.100 ₺. "Gidere yaz" iki kez; birini onayla.
- Beklenen: tek gider, bir kasaya bağlı; onayda kasadan düşer; özet "gidere yazıldı" ise ikinci istek reddedilir.
- Olan: iki ayrı 8.100 ₺ onay bekleyen gider (`kasa_id NULL`). Birini onaylayınca **hiçbir kasa bakiyesi değişmedi** (genel toplam 97.029,42 aynı) ama `/finans/ozet.odenmis_fatura_ay` 8.100 arttı, şeffaflıkta "Diğer" gideri oldu. Kasalar ekranında "bekleyen" sütununda da görünmüyor.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/mesai.py:259-272` `FinansalHareket(...)` `kasa_id` ve idempotency/tekillik yok; `/mesai/ozet`'teki `gidere_yazildi` bayrağı yazmayı engellemiyor.
- Önerilen düzeltme: isteğe `kasa_id` (ya da `defter.kasa_coz`), (kişi, dönem) tekilliği + 409.

### FINANS-09: İade ve iptal aynı tahsilata birlikte uygulanabiliyor (çift ters kayıt)
- Sınıf: **Ciddi**
- Rol / yüzey: yönetici / API `/finans/iade`, `/finans/hareketler/{id}/iptal`
- Adımlar: A-7'den 800 ₺ tahsilat → 300 ₺ kısmi iade → aynı tahsilatı iptal (201) → kalan 500 ₺ iade (201).
- Beklenen: iadesi olan tahsilat iptal edilemez (ya da iptal kalan kadar), iptal edilmiş tahsilat iade edilemez.
- Olan: kasadan 300 + 800 + 500 = **1.600 ₺ çıktı** (giren 800); A-7 bakiyesi 1.750 → **2.550** (sakin ödediği için borcu 800 ₺ ARTTI). Ayrıca virmanın tek bacağı `iade` edilebildi (KASA −10 ₺, karşı bacak yok) ve gider "iade" edilebildi (anlamı belirsiz).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/finans.py:470` iade tavanı yalnız önceki İADELERİ sayıyor (iptal değil); `hareket_iptal` (`:533`) önceki iadeleri saymıyor; `orijinal.tip` için tahsilat/gelir beyaz listesi yok.
- Önerilen düzeltme: "ters toplam = iade + iptal ≤ orijinal" tek kontrol; iade yalnız tahsilat/gelir için; virman grup halinde tersine çevrilsin.

### FINANS-10: "Aidat" sayfasından toplu tahakkuk aynı ayı İKİNCİ KEZ borçlandırıyor
- Sınıf: **Ciddi**
- Rol / yüzey: yönetici / web `/dues` (menü "Aidat") → `POST /dues/assessments` (tanımsız toplu)
- Adımlar: 2026-09 aidatı Finans → Borçlandırma'dan ("Aidat" tanımıyla) yazıldı. Aidat sayfasının toplu formu aynı dönem/tutar ile (A-9 için API'den).
- Beklenen: "bu dönem zaten borçlandırıldı".
- Olan: 201, A-9'da iki ayrı 2026-09 aidat (1.750 + 1.750), bakiye 3.500. Web bu formda sonuç ne olursa olsun `toast.success(aidatTopluOlusturuldu)` gösteriyor (`dues/page.tsx:158`).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `uq_assessment_unit_donem_kalem` `COALESCE(gelir_gider_tanim_id, 0…)` içeriyor — tanımsız ve tanımlı aidat farklı anahtar; `dues/page.tsx:150` tanım göndermiyor.
- Önerilen düzeltme: eski Aidat sayfası toplu formunu kaldır ya da Finans → Borçlandırma'ya yönlendir; ya da tanımsız aidatı varsayılan "Aidat" tanımına bağla.

### FINANS-11: Aynı ayın gider toplamı her raporda farklı
- Sınıf: **Ciddi** (muhasebeciye verilemez)
- Rol / yüzey: yönetici / raporlar + şeffaflık
- Adımlar: Eylül 2026, aynı veri.
- Olan: şeffaflık `toplam_gider` **22.365,75**; Gelir-Gider Özet **16.250,75** (yalnız gelir-gider TANIMI olan giderler; Bakım 1.500, mesai 8.100, banka masrafı 25 hiç yok; gelir tarafında aidat tahsilatları yok); Denetim Raporu gider **22.785,75** (virman çıkışı + iadeler gider sayılıyor); Muhasebeye Aktarım borç **30.885,75**; `/finans/ozet.odenmis_fatura_ay` **26.775,75** (iptal edilmiş 900 dahil). Kategori kırılımı (şeffaflık) toplamı 25.875,75 → yüzdeler 73+36+7 = **%116**.
- Tekrarlanabilir: evet
- Şüpheli kök neden: her rapor kendi sorgusunu yazıyor; `defter.gider_toplami` (iptal satırı düşer) ile `defter.gider_kategori_kirilimi` (iptal edilmişi dışlar) farklı kural (`defter.py:367` vs `:392`); FINANS-03'ün hayali iptali toplamı düşürüyor. Gelir-Gider Özet tanımsız kalemleri atıyor.
- Önerilen düzeltme: gider/gelir toplamı ve kırılımı tek fonksiyondan; tanımsız kalemler "Diğer" satırı; yüzde kırılım toplamı = toplam olmalı (test).

### FINANS-12: Şeffaflık ay listesindeki net ile ay detayındaki net farklı
- Sınıf: Küçük
- Rol / yüzey: sakin + yönetici / `/transparency` vs `/transparency/2026-09`
- Olan: liste `net_kurus −787.008`, detay `−786.008` (10 ₺ fark = virman bacağı iadesi).
- Şüpheli kök neden: `routers/transparency.py:218` liste tüm işaretli hareketleri topluyor (virman/iade/açılış dahil), detay `gelir − gider`.
- Önerilen düzeltme: liste de detayla aynı fonksiyonu kullansın.

### FINANS-13: Borç hatırlatma metni gün sayısını "son ödeme" diye yazıyor; tutar ödenmişi görmüyor
- Sınıf: Orta
- Rol / yüzey: sakin (bildirim) / `POST /finans/borclulara/hatirlat`
- Olan: `notification.mesaj`: "₺1500.00 tutarında ödenmemiş borcunuz var (son ödeme: 100)." — `100` gecikme günü, tarih değil; tutar Türkçe biçimde değil (`1.500,00 ₺` olmalı); A-2'nin daire bakiyesi 1.377,72 iken 1.500 yazıyor (FINANS-04 kökü).
- Şüpheli kök neden: `routers/finans_gosterge.py:236` `params = {"tutar": _tl(...), "vade": str(daire.en_eski_gun)}`; şablon `vade`yi "son ödeme" diye basıyor.
- Önerilen düzeltme: `vade` = en eski son ödeme TARİHİ (dd.MM.yyyy) ya da metni "x gündür gecikmiş" yap; tutar biçimi.

### FINANS-14: Kasa ekstresi raporu kasa süzgecini uygulamıyor
- Sınıf: Orta
- Rol / yüzey: yönetici / Raporlar → Kasa Ekstresi
- Adımlar: `POST /raporlar/kasa_ekstresi {kasa_id: KASA, 2026-09}`.
- Olan: 36 satır: 24 Merkez Kasa, **10 Site Banka, 2 kasasız**; toplam 65.501,42 anlamsız.
- Şüpheli kök neden: `routers/rapor_motoru.py` `kasa_ekstresi` üreticisi `p.kasa_id`'yi süzgece koymuyor.
- Önerilen düzeltme: süzgeç + açılış/kapanış bakiyesi satırı.

### FINANS-15: Sınır doğrulamaları: kasa açılışı, dönem biçimi, ileri tarih
- Sınıf: Orta
- Rol / yüzey: yönetici / API
- Olan: `POST /kasalar acilis_bakiye_kurus=10^20` → **500 Internal Server Error**; `-100` ve `9×10^18` kabul (denetim raporunda "K3 · Neg −1,00"); `POST /dues/assessments donem="2026-13" | "abc" | "1900-01"` → 201; tahsilat `tarih=2099-12-31` → 201 (kasa bakiyesine bugünden giriyor). `KURUS_UST_SINIR=10^15` (10 trilyon ₺): 10 satırda toplam 10^16 kuruş → JS `Number` güvenli aralığını (9×10^15) aşıyor; web'de kuruş kayması olur.
- Şüpheli kök neden: `schemas.py:5850` `KasaCreate.acilis_bakiye_kurus: int = 0` (ge/le yok); `DuesAssessmentCreate.donem` yalnız uzunluk; `schemas.py:102`.
- Önerilen düzeltme: açılışa `ge=0, le=KURUS_UST_SINIR` (banka eksi bakiye isteniyorsa ayrı alan), `donem` için `^\d{4}-(0[1-9]|1[0-2])$` ve makul yıl aralığı, ileri tarihli tahsilata sınır (ör. +7 gün), üst sınırı gerçekçi bir değere (Dukkan 10^9) indir.

### FINANS-16: Rapor çıktısı kalitesi (Excel yinelenen sütunlar, PDF'te boş başlık, "veri yok" yok)
- Sınıf: Küçük
- Rol / yüzey: yönetici, muhasebeci / Excel + PDF
- Olan: Grafikli raporların Excel sayfasında tablo E–H sütunlarına aynen ikinci kez kopyalanmış (grafik veri kaynağı tablonun yanına yazılmış; başlık satırı `Dönem, Borçlandırılan, …, Dönem, Borçlandırılan, …`). PDF'te grafik sayfasının başında veri olmayan tablo başlık satırı tekrar basılıyor. Boş tesiste yalnız "TOPLAM 0,00" satırı — "Bu dönemde kayıt yok" cümlesi yok (grafik doğru şekilde çizilmiyor). Oluşturma saati UTC (Türkiye saati değil). Muhasebe aktarımında iade/iptal satırlarında dönem/daire boş.
- Önerilen düzeltme: grafik verisini gizli yardımcı sayfaya yaz; boş veri cümlesi; saat Europe/Istanbul.

### FINANS-17: Gidere PDF fatura eklenemiyor
- Sınıf: Orta
- Rol / yüzey: yönetici / web + mobil gider fişi
- Olan: `POST /uploads/presign {content_type: application/pdf}` → 422 "content_type gorsel olmali (jpeg/png/webp/heic)". E-faturalar PDF gelir.
- Şüpheli kök neden: `schemas.py:3751 _ALLOWED_UPLOAD_CT`.
- Önerilen düzeltme: `finansal_hareket` eki için `application/pdf` izin ver (Dukkan zaten izin veriyor, `dukkan/isletme.py:518`).

### FINANS-18: Ayın ortasında açılan aidat planı vadesi geçmiş borç yazıyor (Öneri)
- Sınıf: Öneri
- Olan: 23 Eylül'de açılan plan (gün 1, vade 10) ilk koşumda Eylül'ü `tarih 2026-09-01, son ödeme 2026-09-11` ile yazdı — borç doğduğu anda 12 gün gecikmiş; gecikme faizi açıksa ilk koşumda faize girer.
- Kod: `otomasyon.py:236 tahakkuk_tarihi` + `vade_gun`.
- Öneri: ilk dönemde vade = max(hesaplanan vade, bugün + vade_gun).

### FINANS-19: Sakin, dairedeki diğer kişinin borç kalemlerini kendi borcu gibi görüyor (Öneri)
- Sınıf: Öneri
- Olan: A-1 kiracısı Can `/me/dues`'da malikin 400 ₺ demirbaş borcunu da görüyor ve toplam borcu malikle aynı; `hedef_ad` alanları boş dönüyor, sakin hangi kalemin kendisine ait olduğunu ayıramıyor.
- Kod: `routers/dues.py:854 me_dues` → `_unit_status` daire geneli, `_zenginlestir` çağrılmıyor.
- Öneri: kalemlerde hedef kişiyi göster, "sizin payınız" alt toplamı.

---

## WEB DOĞRULAMASI (Playwright, yönetici)

**ORTAM NOTU:** `app.localhost:3000` (ana Next dev sunucusu) bu oturumda KULLANILAMADI: `/_next/static/chunks/*.js` ve `layout.css` **404** döndü, sayfa hiç hidrate olmadı, giriş formu native gönderimde kaldı (`admin-web/.next/BUILD_ID` 22 Eylül tarihli, yani biri aynı klasörde `next build` koşmuş ve dev sunucusunun `.next`'ini ezmiş olabilir). Ürün kusuru DEĞİL; yeniden başlatma yasak olduğu için dokunmadım. Doğrulama, `arayuz` ajanının aynı kodla (`diff -rq app` fark yok) derlediği `next start` kopyası üzerinden yapıldı: `http://app.localhost:3102`, backend aynı (`localhost:8000`). Betik: `$S/finans/web.mjs`, `web2.mjs`; metin dökümü `$S/finans/web_metin.json`.

| Madde | Sonuç | Kanıt |
|---|---|---|
| Finans ekranındaki rakamlar = API | GEÇTİ | Kasa: BANKA 87.834,75 / KASA 9.195,67 / genel toplam 97.029,42 (API ile aynı); bu ay borçlandırılan 37.875,50; tahsil edilen 8.505,67; açık borç 32.869,83 |
| Borçlular ekranı | KALDI | "Toplam açık borç 3.500,00 ₺" (yalnız vadesi geçenler) ile Finans ekranındaki "Açık borç 32.869,83 ₺" aynı adla iki ayrı rakam; tahsilat oranı **%3 (1.150 / 37.875,50)** — aynı menüdeki Finans ekranı bu ay 8.505,67 tahsilat diyor (FINANS-06/07); ekran görüntüsü `ekran/borclular2.png` |
| Yaşlandırma grafiği | KALDI | eksen **kuruş** cinsinden (0–200000), satırlar TL (2.000,00 ₺) → 100 kat büyük (FINANS-20) |
| Tahsilat formu: daire seç → kişi | GEÇTİ | B-5 seçilince "Elif Oturan" kendiliğinden seçildi; A-1 (2 sakin) seçilince kişi boş kaldı ve yalnız "Zeynep Malik / Can Kiracı" listelendi (bilinçli karar) |
| Tahsilat listesi | KALDI | sütunlarda **daire ve kişi yok** (Tarih/Belge/Tutar/Durum/Açıklama); iptal edilmiş TAH-…024 hâlâ "Ödendi" + "İptal et" (FINANS-21) |
| Gider listesi | KALDI | reddedilmiş gider durum "iptal" (çevrilmemiş) ve yanında **"İptal et" düğmesi** (FINANS-03'ün web kapısı); iptal edilmiş GID-…004 "Ödendi"; mesai gideri onay bekliyor ama üstteki "Onay bekleyen gider 0,00 ₺" (kasasız, FINANS-08) |
| Hareketler listesi | KALDI | tür sütununda ham anahtar **`finansTip_iptal`**; salt tarih alanları saatli gösteriliyor ve saat dilimi kayıyor: 23.09 kaydı "22.09.2026 20:00" (tarayıcı UTC−4), İstanbul'da "23.09.2026 03:00" olur (FINANS-21) |
| Aidat sayfası | KISMEN | "Tahsilat oranı %3"; tabloda kalem türü sütunu yok — A-9'un iki 2026-09 1.750 ₺ satırı ayırt edilemiyor, faiz satırları "2026-09 100,00 ₺" türsüz; daire adı "A/A-9" (blok iki kez) |
| Bütçe | GEÇTİ | Bakım hedef 12.000 / gerçekleşen 1.500 / %13 / −10.500 (%−88) |
| Kurulum turu | Not | `/api/me/tur-goruldu` sonrasında da "Yönetio'ya hoş geldiniz 1/4" her sayfada açılıyor; ekran görüntüleri turla örtülü (`ekran/finans.png`) |

### FINANS-20: Borç yaşlandırma grafiğinin ekseni kuruş cinsinden
- Sınıf: Orta
- Rol / yüzey: yönetici / web `/finans/borclular`
- Olan: çubuklar 200000 ve 150000'e uzanıyor, eksen 0–200000; aynı kartın lejantı 2.000,00 ₺ / 1.500,00 ₺. Muhasebe dışı bir göz 200.000 ₺ borç okur. (`ekran/borclular2.png`)
- Şüpheli kök neden: `admin-web/app/(protected)/finans/borclular/page.tsx` grafik verisi `kalan_kurus`u 100'e bölmeden veriyor.
- Önerilen düzeltme: grafiğe TL ver ya da eksen biçimleyicide `kurusToTL`.

### FINANS-21: Hareket/tahsilat/gider listelerinde durum ve etiket kusurları
- Sınıf: Orta
- Rol / yüzey: yönetici / web `/finans`, `/finans/tahsilatlar`, `/finans/giderler`
- Olan: (1) tür sütununda i18n anahtarı ham: `finansTip_iptal`; (2) ters kaydı olan (iptal edilmiş) tahsilat/gider "Ödendi" ve yeniden "İptal et" düğmesiyle listeleniyor (`defter.iptal_edilmis()` listelerde uygulanmıyor, yorumu tersini söylüyor); (3) reddedilmiş giderin durumu çevrilmemiş "iptal", yanında "İptal et"; (4) tahsilat listesinde daire/kişi sütunu yok — kimin ödediği görünmüyor; (5) salt-tarih `tarih` alanı `new Date("2026-09-23")` gibi UTC gece yarısı yorumlanıp saatle basılıyor (UTC− bölgede bir gün geri).
- Önerilen düzeltme: sözlüğe `finansTip_iptal`; listelerde ters kaydı olanları "İptal edildi" göster ve düğmeyi kaldır; tarih-only alanları saatsiz biçimle.

### Yeniden ölçüm (ana ajan :3000 dev sunucusunu yeniden başlattıktan sonra)
- `http://app.localhost:3000` üzerinde `/finans` ve `/finans/giderler` yeniden çekildi (`web.mjs`, 0 konsol/ağ hatası): `finansTip_iptal` ham anahtarı **hâlâ var**; gider listesinde **7 "İptal et"** düğmesi (reddedilen ve zaten iptal edilmiş satırlar dahil) — FINANS-21 ve FINANS-03'ün web kapısı :3000'de de DOĞRULANDI. Rakamlar :3102 ile aynı.
- Tahsilat formu (daire → kişi) testi :3000'de zaman aşımına uğradı (sunucu derleme yükü); sonucu :3102 (aynı kaynak kod, `next start`) ölçümüne dayanıyor → GEÇTİ.
- Web'de kayda geçen bulguların hiçbiri hidrasyon sorununa bağlı değil: hepsi :3102'de hidrate sayfada ölçüldü ve backend verisiyle doğrulandı. Hidrasyonsuz :3000'den kaynaklanan bir bulgu yazılmadı.

## ÖZET
GEÇTİ ≈30, KALDI 16 (+2 web), KISMEN 14. En ciddi: FINANS-01, 03, 04, 07, 09 (ayrıca 02, 05, 06, 08, 10, 11).
