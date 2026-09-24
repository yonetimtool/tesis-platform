# ARAYÜZ — Bölüm 10 (Arayüz/Erişilebilirlik) + 11 (Dayanıklılık)

Tesis: `e2e-arayuz-sitesi-aaac62` (tesisler/arayuz.json). Veri: 4+ duyuru, 6+ görev (kategori "Temizlik"),
Eylül tahakkuku (20 daire), 4 tahsilat (Ana Kasa), 3+ ziyaretçi, 2 kargo, 2+ talep, "Çekmeköy Işıkoğlu" adlı
sakin (A-5), emoji'li sakin "Ayşe 🌸 O'Brien <b>x</b> 中文" (A-7), 10k karakterli görev/kullanıcı kayıtları.
Betikler: `$S/arayuz/` (tara.mjs = rota tarayıcı, etkilesim.mjs = arama/klavye/çift tık/ağ, dayan*.py, es*.py, arama.py).
Ham sonuçlar: `$S/arayuz/sonuc-*.json`, `etk-*.json`, `dayan-sonuc.json`; ekranlar `$S/arayuz/ekran/`.

**ORTAM NOTU:** :3000'deki paylaşılan Next dev sunucusu ölçüm başında BOZUKTU (istemci JS'i 404 → hidrasyonsuz;
ana ajan sonradan düzeltti). Hiçbir web ölçümüm bozuk :3000'den alınmadı: repo HEAD'inin kopyasını
(`$S/arayuz/web`) **üretim derlemesiyle** (`next build` + `next start -p 3102`) koşturdum. Dev derlemesi makine
yükü (load 88-115, RAM+swap dolu) yüzünden rota başı 3-8 dk sürüp çöküyordu. Tarayıcı saat dilimi = host (UTC-4).

## KONTROL LİSTESİ

| Madde | Durum | Kanıt |
|---|---|---|
| 10.1 açık tema kontrast (axe, 65 yönetici rotası) | KALDI | Her rotada 4 ortak kabuk ihlali (logo 1.51:1, altbilgi 3.72, kbd 3.61, hesap menüsü 4.18) → ARAYUZ-1, -2 |
| 10.1 koyu tema kontrast | KISMEN | 40 rota (html `dark` doğrulandı): logo sorunu YOK; `--yz-text-3` koyu (#989fa8) koyu yüzeylerde 3.03-4.32:1 (altbilgi, kbd, hesap menüsü, "Genel toplam"); duyuru "Sil" düğmesi #f8afaf/#47525d 4.45 → ARAYUZ-2 |
| 10.1 Büyük mod taşma/çakışma | KISMEN | 40 rota (`yz-buyuk` sınıfı doğrulandı): yatay taşma YOK (/tasks hariç, ARAYUZ-6), üst üste binme yok (tek eşleşme hero başlık/alıntı kutusu — görsel olarak çakışmıyor, yanlış pozitif); ama etiketler "…" ile kesiliyor → ARAYUZ-17. Ekran: `$S/arayuz/ekran/C2-buyukekran/_dashboard.jpg` |
| 10.1 mobil sistem yazı ölçeği (kod) | KISMEN | sistem ölçeği izleniyor, büyük mod ×1.3 ÇARPIYOR (üst sınır yok); borçlular kova kartı sabit 92px → ARAYUZ-12 |
| 10.2 kelime ortasından bölme (CSS) | GEÇTİ | `break-all` yalnız kod/URL/JSON (<code>, <pre>) öğelerinde; metinlerde `break-words` (yalnız bölünemez uzun kelimede kırar) |
| 10.2 DE/RU taşma + çevrilmemiş metin | GEÇTİ | DE ve RU, 768px, 40 rota (`lang=de/ru` doğrulandı): yatay taşma 0, taşan metin 0; sayfada kalan Türkçe yalnız VERİ (duyuru/talep içerikleri — dev'de EchoProvider "[de] …" öneki, `translate.py:61`, tasarım); sözlük 7 dilde 3437 anahtar eksiksiz; kodda sabit TR metin yok; API hata metinleri DE/RU çevrili. 1366px DE/RU koşulmadı (768 daha dar, taşma yoksa 1366'da da beklenmez) |
| 10.2 mobil 320dp sabit genişlik | KISMEN | 4 sabit ≥130 genişlik; 320dp'de sığıyor, ama borçlular kartı yükseklik sabiti → ARAYUZ-12 |
| 10.3 dokunma hedefleri | KISMEN | 24px altı: tablo sıralama başlık düğmeleri (h=18), "Tümünü Gör ›" bağlantıları (h=18-20), onay kutuları 13-16px → ARAYUZ-9 |
| 10.3 renk tek başına anlam | GEÇTİ | durum rozetleri metinli ("Orta", "Tamamlandı", "Gecikti"...); kontrol edilen ekranlarda yalnız-renk rozet yok |
| 10.3 axe ciddi ihlaller | KALDI | color-contrast (serious) 65/65 rotada; diğerleri moderate/minor (region, image-redundant-alt, heading-order, empty-table-header) |
| 10.3 klavye / modal odak tuzağı / Esc | GEÇTİ | Tab sırası mantıklı, "İçeriğe atla" var; duyuru modalında Tab modal içinde döngü yapıyor, Esc kapatıyor ve odak "Yeni duyuru"ya dönüyor |
| 10.3 odak görünürlüğü | KISMEN | çoğu öğede 2px mavi outline; "Menüyü daralt" ve "Bildirimler" düğmelerinde outline 0 (yalnız gölge) → ARAYUZ-10 |
| 10.4 arama Türkçe harf duyarsız | GEÇTİ | "cekmekoy"/"CEKMEKOY"/"ısık"/"IŞIK"/"isik"/"Isik" → "Çekmeköy Işıkoğlu" (API + web) |
| 10.4 kişi/daire/görev/talep + sayfa adları | GEÇTİ | musluk→talep, merdiven→görev, A-1→daire, telefon/e-posta→kişi; "finans"/"aidat"/"tahsilat"/"kamera" → sayfa sonuçları (web, istemci tarafı) |
| 10.4 rol bazlı | GEÇTİ | güvenlik amiri web'de "finans/aidat/tahsilat" → boş; API /arama tüm rollerde kaynak düzeyinde süzüyor (security/görevli/denetçi/sakin kişi göremiyor, sakin yalnız kendi talebi) |
| 10.4 arama kapsamı / joker | KISMEN | ziyaretçi/kargo aranamıyor; `%%` / `__` tüm kayıtları döndürüyor → ARAYUZ-11 |
| 10.4 mobil arama | GEÇTİ (kod) | `mobile/lib/src/features/arama/data/arama_api.dart:48` aynı `/arama` ucu, 300ms gecikme, ≥2 karakter |
| 11.1 çevrimdışı form gönderimi | GEÇTİ | modal açık kalıyor, veri kaybolmuyor, "Bağlantı kurulamadı — internet bağlantınızı kontrol edip tekrar deneyin." |
| 11.1 yavaş ağ (6 sn gecikme) | GEÇTİ | iskelet göstergeleri (53) + başlıklar çiziliyor |
| 11.1 SWR 500 hata durumu | KISMEN | "Tekrar dene" var ama mesaj sunucu metnini ham gösteriyor ve KPI'lar "0" gösteriyor → ARAYUZ-13 |
| 11.1 mobil zorunlu güncelleme sunucu erişilemezken | GEÇTİ (kod) | `surum_api.dart:28` hata → `guncel`; `surum_denetleyici.dart:60` paket bilgisi hatası → kilit yok |
| 11.2 çok uzun metin | KISMEN | çoğu uç 422 (max_length); görev `ad`/`aciklama`, kullanıcı `ad`, tahakkuk `aciklama` 10k kabul → web /tasks düzeni bozuluyor → ARAYUZ-6 |
| 11.2 özel karakter/emoji | KISMEN | kayıt + web + Excel doğru; XSS yok; **NUL (\u0000) → 500** (ARAYUZ-3); PDF'te emoji/CJK kayboluyor (ARAYUZ-8) |
| 11.2 büyük dosya / yanlış tür | KISMEN | presign yalnız BEYAN edilen boyutu (8MB) ve content-type'ı denetliyor; gerçek gövde boyutu/sihirli bayt denetimi yok (storage.py:104-111 kendi yorumunda kabul) → ARAYUZ-14 (Öneri). 50MB fiili PUT ÖLÇÜLEMEDİ (makine yükü) |
| 11.2 sıfır/negatif/büyük tutar | KISMEN | 0/negatif → 422 her yerde; **tahakkuk 2^31 kuruş → 500** (int32 kolon), **kasa açılış bakiyesi 10^20 → 500**, negatif açılış kabul → ARAYUZ-4 |
| 11.2 geçmiş/ileri tarih | KALDI | tahsilat 2000-2200 dışını 422 ile reddediyor (iyi); ama tahakkuk `donem`="2026-13"/"abcd"/"0000-00" → 201, `son_odeme_tarihi`=1900 → 201, `tarih`=1900 → 201; görev son_tarih 0001/9999 → 201 → ARAYUZ-5 |
| 11.2 500 toplama | yapıldı | 7 farklı 500 (NUL×4 uç, int32, int64); hepsi aşağıda traceback ile |
| 11.3 kaybolan güncelleme | KALDI | görev PATCH'te sürüm/If-Match yok; bayat form tüm alanları ezer → ARAYUZ-7 |
| 11.3 paralel çift oluşturma | KISMEN | rezervasyon: 6 paralel istekte 1 kayıt (doğru); tahsilat aynı belge_no → 409 (doğru); duyuru ×5, ziyaretçi ×5, talep ×5, belgesiz tahsilat ×3 → hepsi ayrı kayıt (idempotency yok) → ARAYUZ-7 |
| 11.3 web çift tıklama koruması | GEÇTİ | Kaydet'e dblclick ve 3'lü tık → tek `POST /api/announcements` (Dugme `yukleniyor` → disabled) |

## BULGULAR

### ARAYUZ-1: Sol menüdeki "yönetiyor" logosu açık temada okunmuyor (kontrast 1.51:1)
- Sınıf: Orta
- Rol / yüzey: tüm web rolleri / web, her sayfa
- Adımlar: açık temada herhangi bir sayfa; sol üst köşe.
- Beklenen: ≥4.5:1 (büyük metin ≥3:1).
- Olan: axe color-contrast: `#0e3c91` üstünde `#14263a` = 1.51:1, 65/65 rotada. Ekran: `$S/arayuz/ekran/A-acik/_aidatim.jpg` (sol üst "yönetiyor" koyu mavi/lacivert üstünde neredeyse görünmüyor).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `admin-web/components/YonetioLogo.tsx:109` — kelime `text-[#0E3C91] dark:text-white`; renk TEMAYA göre seçiliyor ama kenar çubuğu AÇIK temada da lacivert (`AppShell.tsx:645`). Logo görseli için de aynı sorun olabilir (açık varyant yalnız `dark:`da gösteriliyor).
- Önerilen düzeltme: kenar çubuğunda her zaman açık mürekkep varyantını kullan (ör. `kelimeRengi` prop'u / `text-white`).

### ARAYUZ-2: İkincil metin rengi `--yz-text-3` (#707d8f) AA'yı geçmiyor (altbilgi, kısayol ipucu, hesap menüsü)
- Sınıf: Küçük
- Rol / yüzey: tüm / web açık tema, her sayfa
- Olan: altbilgi "© 2026 Yönetiyor…" 3.72:1 (#707d8f / #eef2f7), arama kutusundaki `kbd` "Ctrl K" 3.61:1, hesap düğmesindeki tesis adı 4.18:1 (12px). 142+98+60 düğüm.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `admin-web/app/tasarim-sistemi.css:132` `--yz-text-3: #707d8f` 12px metinde kullanılıyor.
- Koyu tema: aynı token koyu değeri `tasarim-sistemi.css:256` `#989fa8` → altbilgi 4.32, hesap menüsü 3.6, kbd 3.03, "Genel toplam" 3.38 (koyu yüzeylerde). Açık tema ayrıca boş durum metinleri ("Bu dönemde planlanmış vardiya yok.", "doğrulanmadı") 4.18.
- Önerilen düzeltme: token'ı açıkta ~#5f6b7c'ye koyulaştır, koyuda ~#aab1ba'ya aç (her iki temada ≥4.5).

### ARAYUZ-3: Metin alanında NUL karakteri (\u0000) → 500 (duyuru, görev, talep, arama)
- Sınıf: Orta
- Rol / yüzey: yönetici, sakin / API
- Adımlar: `POST /announcements {"baslik":"nul\u0000test","govde":"x\u0000y"}`; aynısı `/tasks`, `/complaints`, `GET /arama?q=ab%00c`.
- Beklenen: 422 (ya da karakteri ayıklayıp 201).
- Olan: 500 Internal Server Error; api.log: `asyncpg.exceptions.CharacterNotInRepertoireError: invalid byte sequence for encoding "UTF8": 0x00` (4 traceback).
- Tekrarlanabilir: evet
- Şüpheli kök neden: Pydantic `str` alanları NUL'u geçiriyor, Postgres `text` reddediyor; genel `DBAPIError` işleyicisi yok.
- Önerilen düzeltme: ortak bir `str` doğrulayıcısı/ara katman ile `\x00` reddet (422) ya da `CharacterNotInRepertoireError`/`DataError`'ı 422'ye eşle.

### ARAYUZ-4: Tutar üst sınırı kolon tipiyle uyuşmuyor → 500 (tahakkuk 2^31, kasa açılış 10^20)
- Sınıf: Orta
- Rol / yüzey: yönetici / API (+ web formları)
- Adımlar: `POST /dues/assessments {"donem":"2026-12","tutar_kurus":2147483648,"unit_id":…}`; `POST /kasalar {"kod":"BIG","ad":"big","acilis_bakiye_kurus":100000000000000000000}`.
- Beklenen: 422.
- Olan: ikisi de 500. api.log: `DataError: invalid input for query argument $4: 2147483648 (value out of int32 range)` ve `$5: 100000000000000000000 (value out of int64 range)`.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/models.py:1731` `DuesAssessment.tutar_kurus = mapped_column(Integer)` (int32, üst ≈21,4 milyon TL) ama şema `schemas.py:4832` `le=KURUS_UST_SINIR (10**15)` izin veriyor; aynı işlem `finans/tahsilat`'ta BIGINT olduğu için 201. `schemas.py:5851` `KasaCreate.acilis_bakiye_kurus: int = 0` — ne alt ne üst sınır (negatif −5,00 ₺ açılış da kabul edildi ve /finans'ta "NEG −5,00 ₺" görünüyor).
- Önerilen düzeltme: `dues_assessment.tutar_kurus` → BIGINT göçü (ya da şemada `le=2**31-1`); `acilis_bakiye_kurus`'a `ge=-KURUS_UST_SINIR, le=KURUS_UST_SINIR`.

### ARAYUZ-5: Tahakkuk dönem/tarih doğrulaması yok — "2026-13", "abcd", "0000-00", 1900 son ödeme kabul
- Sınıf: Ciddi (defter verisini bozar)
- Rol / yüzey: yönetici / API
- Adımlar: `POST /dues/assessments {"donem":"abcd","tutar_kurus":100,"unit_id":…}` (ve "2026-13", "0000-00", "1900-01", "9999-12"); `son_odeme_tarihi:"1900-01-01"`; `tarih:"1900-01-01"`.
- Beklenen: `donem` YYYY-MM ve makul yıl aralığı (tahsilatta olduğu gibi 2000-2200) → aksi 422.
- Olan: hepsi 201; tahakkuklar oluştu (borç listelerine/raporlara geçersiz dönemle girer). Aynı anda `/finans/tahsilat` tarih 1900/0001/9999'u "Belge tarihi … seri aralığının dışında (2000-2200)" ile 422 reddediyor — iki para ucu tutarsız.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/schemas.py:4831` `donem: str = Field(..., min_length=1)` — kalıp yok; `son_odeme_tarihi`/`tarih` (4835, 4847) aralık denetimi yok. Görev `son_tarih` 0001/9999 da kabul (TaskCreate).
- Önerilen düzeltme: `donem` için `pattern=r"^\d{4}-(0[1-9]|1[0-2])$"` + yıl aralığı; tarih alanlarına `belge_no_uret`teki 2000-2200 kuralını paylaşan doğrulayıcı.

### ARAYUZ-6: Görev adı / kullanıcı adı sınırsız — 10.000 karakterlik kullanıcı adı /tasks sayfasını 90.000px genişliğe taşırıyor
- Sınıf: Orta
- Rol / yüzey: yönetici / API + web
- Adımlar: `POST /users {"ad":"a"*10000,…}` → 201; `POST /tasks {"ad":"a"*10000}` → 201; web'de /tasks aç.
- Beklenen: API'de makul `max_length` (ör. 150-200) → 422; web'de seçim kutusu genişliği sınırlı.
- Olan: `document.scrollWidth = 90430` (innerWidth 1366); "Tüm personel" süzgeci ekranın dışına uzanıyor (ekran: `$S/arayuz/ekran/etk/uzun_tasks.png`). Diğer uçlar tutarlı biçimde sınırlı (duyuru 200, talep 200, kasa 100, personel 150, blok 8).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/schemas.py:3515` `TaskCreate.ad: str = Field(..., min_length=1)` ve `3516` `aciklama` sınırsız; `schemas.py:451` `UserCreate.ad` sınırsız; tahakkuk `aciklama` sınırsız. Web: `admin-web/app/(protected)/tasks/page.tsx:682-689` `<Secim className="w-auto">` — seçenek metni kadar genişliyor.
- Önerilen düzeltme: şemalara `max_length`; `Secim`e `max-w-full`/`max-w-xs`.

### ARAYUZ-7: Eşzamanlılık — kaybolan güncelleme koruması ve oluşturma idempotency'si yok
- Sınıf: Orta
- Rol / yüzey: yönetici, güvenlik, sakin / API
- Adımlar: (a) Görev G; A kullanıcısı `PATCH {aciklama:"Kullanıcı A açıklaması"}`; ardından bayat formlu B `PATCH {ad:"Kullanıcı B adı", aciklama:"ilk"}`. (b) `If-Match: "eski"` ile PATCH. (c) Aynı gövdeyle 5 paralel `POST /announcements`, `/visitors`, `/complaints`; 3 paralel belge_no'suz `/finans/tahsilat`.
- Beklenen: (a/b) 409/412 ya da en azından alan-bazlı birleştirme; (c) istemci yeniden denemesinde çift kayıt oluşmaması (Idempotency-Key).
- Olan: (a) A'nın açıklaması sessizce "ilk"e döndü; (b) 200 (başlık yok sayılıyor); (c) 5 duyuru, 5 ziyaretçi, 5 talep, 3 tahsilat (43,21 ₺ ×3, `$S/arayuz/ekran/A-acik/_finans.jpg`). Olumlu: rezervasyonda 6 paralel istekten yalnız 1'i 201 (kilit doğru); tahsilatta aynı belge_no → 409; web Kaydet düğmesi çift/üçlü tıklamada tek istek atıyor.
- Tekrarlanabilir: evet
- Şüpheli kök neden: modellerde sürüm kolonu/`updated_at` karşılaştırması yok (`routers/tasks.py` PATCH); POST uçlarında idempotency anahtarı yok. Web formları tüm alanları gönderiyor (bayat alan ezilmesi).
- Önerilen düzeltme: para uçlarında (tahsilat) `Idempotency-Key` başlığı; düzenleme uçlarında `updated_at` ile iyimser kilit (409). Mobil zayıf ağda yeniden deneme yaparsa çift tahsilat riski en yüksek.

### ARAYUZ-8: PDF raporlarda emoji ve CJK/Arapça karakterler kayboluyor
- Sınıf: Küçük
- Rol / yüzey: yönetici / rapor PDF
- Adımlar: sakin adı "Ayşe 🌸 O'Brien <b>x</b> 中文" → `POST /raporlar/site_sakinleri?bicim=pdf`.
- Beklenen: karakterler görünür (ya da en azından yer tutucu).
- Olan: PDF metni `Ayşe   O'Brien <b>x</b>   ` — 🌸 ve 中文 boş. Excel'de hepsi doğru (`A-7 | A | Ayşe 🌸 O'Brien <b>x</b> 中文`). Türkçe harfler PDF'te doğru (DejaVuSans gömülü). Dosyalar: `$S/arayuz/rapor_site_sakinleri.pdf/.xlsx`.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/rapor_ciktilari.py:262-286` yalnız DejaVuSans kayıtlı; emoji/CJK glifi yok, yedek yazı tipi yok. Arapça (7 dilden biri) için de şekillendirme yok.
- Önerilen düzeltme: Noto Sans (CJK/Arabic) yedek yazı tipi veya glifsiz karakterler için "?" yer tutucu; Arapça ad desteği gerekiyorsa arabic-reshaper/bidi.

### ARAYUZ-9: Dokunma hedefleri 24px altında (tablo sıralama düğmeleri, "Tümünü Gör", onay kutuları)
- Sınıf: Küçük
- Rol / yüzey: yönetici / web (tablet dokunmatikte önemli)
- Olan: tablo başlık sıralama düğmeleri 48-77×18px (her listede), özet sayfası "Tümünü Gör ›" 79×18, onay kutuları 13×13 / 16×16. (WCAG 2.5.8 AA = 24×24.) Ana eylem düğmeleri ≥32px.
- Şüpheli kök neden: `components/ui/veri-tablosu.tsx:672-676` sıralama düğmesi `inline-flex` — yükseklik yalnız metin satırı (18px), dolgu/min-h yok; onay kutuları tarayıcı varsayılan boyutu.
- Önerilen düzeltme: `min-h-6` (24px) ve kutulara etiketle birlikte tıklama alanı.

### ARAYUZ-10: Bazı düğmelerde klavye odağı görünmüyor
- Sınıf: Küçük
- Rol / yüzey: yönetici / web
- Olan: Tab ile "Menüyü daralt" (outline 0, gölge yok) ve bazı sayfalarda "Bildirimler" (outline 0) odak aldığında görsel gösterge yok; ilk yüklemede "İçeriğe atla"/logo bağlantısında da outline 0 (sonraki sayfada 2px). Diğer tüm öğeler 2px mavi outline.
- Şüpheli kök neden: kesin belirlenmedi. Daralt düğmesi `components/AppShell.tsx:650-655` (`odak-ic`, outline'ı `globals.css:54` içeri çekiyor) — aynı sınıflı başka öğelerde outline 2px ölçüldü; kenar çubuğuna özgü bir kural outline'ı sıfırlıyor olabilir. Ölçüm: `$S/arayuz/etk-yonetici-1.json` `klavye`.
- Önerilen düzeltme: ortak `focus-visible:outline-2` sınıfı.

### ARAYUZ-11: Arama LIKE jokerlerini kaçırmıyor; ziyaretçi/kargo aranamıyor
- Sınıf: Küçük
- Rol / yüzey: tüm / API + web
- Adımlar: `GET /arama?q=%%` (ya da `__`).
- Olan: 200 ve her kaynaktan ilk 5 kayıt (ör. tüm kişiler) — sonuçlar rol süzgecinden geçtiği için sızıntı YOK, ama "%50" gibi aramalar yanlış eşleşir. "Mustafa" (ziyaretçi) ve "Yurtiçi" (kargo) hiçbir rolde bulunamıyor.
- Şüpheli kök neden: `backend/app/routers/arama.py:373` `desen = f"%{aranan}%"` — `%`/`_`/`\` kaçırılmıyor; KAYNAKLAR listesinde visitor/kargo yok (kargo/ziyaretçi yönetime kapalı olduğu için bilinçli olabilir — güvenlik rolü için eklenebilir).
- Önerilen düzeltme: `aranan.replace("\\","\\\\").replace("%","\\%").replace("_","\\_")` + `escape="\\"`.

### ARAYUZ-12: (Mobil, kod) Borçlular kova kartı sabit 92px yükseklik; büyük yazıda taşar. Büyük mod ölçeğine üst sınır yok
- Sınıf: Küçük
- Rol / yüzey: yönetici / mobil
- Olan (kod okuma): `mobile/lib/src/features/finans/presentation/borclular_screen.dart:105-140` `SizedBox(height: 92)` içinde Card(margin 4)+Padding(8)+3 satır Text (titleSmall + 2 body) ≈ 60px içerik alanına 3 satır; sistem ölçeği 1.3 ya da Büyük mod (×1.3) ile ~78px → RenderFlex overflow (sarı-siyah şerit). `core/gorunum/gorunum_modu.dart:121` büyük mod sistem ölçeğine ÇARPIYOR, kelepçe yok (sistem 2.0 × 1.3 = 2.6).
- ÖLÇÜLEMEDİ: cihaz/flutter test koşturulmadı (yalnız mobil ajanı koşturabilir).
- Önerilen düzeltme: sabit yükseklik yerine `IntrinsicHeight`/`minHeight`; `withClampedTextScaling(maxScaleFactor: 2.0)`.

### ARAYUZ-13: API 500 döndüğünde görev sayfası sunucunun ham mesajını gösteriyor, KPI'lar yanıltıcı "0"
- Sınıf: Küçük
- Rol / yüzey: yönetici / web
- Adımlar: Playwright ile `/api/tasks**` → 500 `{"error":{"message":"x"}}`.
- Olan: tabloda "x" + "Tekrar dene" (sunucu mesajı çevrilmeden gösteriliyor); üstteki "Aktif görev 0 / Gecikti 0 / Tamamlandı 0" gerçekmiş gibi duruyor. Ekran: `$S/arayuz/ekran/etk/tasks-500.png`.
- Önerilen düzeltme: 5xx'te genel çevrili metin; KPI'larda "—".

### ARAYUZ-14 (Öneri): Yükleme boyut/tür denetimi yalnız istemci beyanına dayanıyor
- Sınıf: Öneri
- Kanıt: `backend/app/storage.py:104-111` yorumu: "Boyut tavani ise yalnizca istemcinin BEYAN ETTIGI `boyut` alanina karsi… gercek PUT govdesinin boyutunu… dogrulamaz"; content-type imzaya bağlı ama içerik (sihirli bayt) denetlenmiyor → `.exe` baytları `image/jpeg` olarak yüklenebilir. Tasarım kararı olarak kayıtlı; zarar: depolama kötüye kullanımı. Öneri: presigned POST policy (`content-length-range`) ya da `ekle`/duyuru kaydında `head_object` boyut + ilk baytlar denetimi.

### ARAYUZ-15: Özet sayfası "Açık talep" kartı: "0 — 8 yüksek öncelikli" (BFF `oncelik` süzgecini düşürüyor)
- Sınıf: Orta
- Rol / yüzey: yönetici / web özet
- Adımlar: 8 açık, "normal" öncelikli talep varken /dashboard.
- Beklenen: yüksek öncelikli 0; ana sayı açık talep sayısı.
- Olan: kart "Açık talep 0" ve altında "8 yüksek öncelikli" (ilk ölçümde 2 talep varken "2 yüksek öncelikli"). API doğrudan: `durum=acik&oncelik=yuksek` → total 0.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `admin-web/app/api/complaints/route.ts:8-16` GET vekili yalnız `limit/offset/durum`u taşıyor, `oncelik`i DÜŞÜRÜYOR → `dashboard/page.tsx:909-910` sorgusu tüm açık talepleri sayıyor. Ana sayı ise `gorunurSikayet.acik_sayisi` (daire şikayeti = unit-complaint, farklı varlık, `dashboard/page.tsx:855`) — kart "talep" diyor ama daire şikayetlerini sayıyor. (P245 §7 visitors süzgeci ile aynı sınıf.)
- Önerilen düzeltme: vekilde `oncelik` (ve diğer süzgeçleri) beyaz listeye ekle; KPI ana sayısını `/complaints?durum=acik` total'inden al.

### ARAYUZ-16: Yalnız tarih olan alanlar saatli ve saat dilimine kaydırılmış gösteriliyor (/finans hareketleri)
- Sınıf: Küçük
- Rol / yüzey: yönetici / web
- Olan: 23.09.2026 tarihli tahsilatlar /finans "Hareketler" tablosunda "22.09.2026 20:00" (tarayıcı UTC-4). TR (UTC+3) kullanıcısında "23.09.2026 03:00" gibi uydurma bir saat görünür; UTC'nin batısındaki kullanıcıda GÜN kayar.
- Şüpheli kök neden: `admin-web/app/(protected)/finans/page.tsx:183` `formatDateTime(h.tarih)` — `tarih` `date` (saatsiz); `new Date("2026-09-23")` UTC gece yarısı olarak çözülüyor.
- Önerilen düzeltme: tarih-yalnız alanlar için `formatDate` (yerel bileşen ayrıştırma).

### ARAYUZ-17: Özet sayfasında etiketler kesiliyor (Büyük modda belirgin)
- Sınıf: Küçük
- Rol / yüzey: yönetici / web özet
- Olan: "Tahsilat durumu" göstergesinin açıklamaları standart modda "Tahsil e…", "Bekley…"; Büyük modda "Ta…", "B…" (anlamsız). Sol menüde "FİNANSAL İŞLEM…", finansal özet kartlarında "Onay bekleyen hareket…", "Ödenmiş faturalar (bu …". Ekran: `$S/arayuz/ekran/C2-buyukekran/_dashboard.jpg`, `$S/arayuz/ekran/A-acik/_aidatim.jpg`.
- Tekrarlanabilir: evet
- Şüpheli kök neden: sabit genişlikli ızgara + `truncate`; büyük mod yazıyı büyütüyor ama kolon genişliği aynı kalıyor (`tasarim-sistemi.css:720` `:root.yz-buyuk`).
- Önerilen düzeltme: açıklamaları alt satıra sar (`truncate` yerine `break-words`), büyük modda gösterge + açıklamayı dikey diz; kesilen yerlerde `title`.

## Bilgi / yanlış pozitif ayıklaması
- `/aidatim, /duyurular, /etkinlikler, /gorevlerim, /kargolar, /rezervasyonlarim` (sakin sayfaları) ve `/audit, /olaylar, /integrations, /kurallar, /kvkk-metinler` yönetici için /dashboard'a yönleniyor — rol kapısı tasarımı, bulgu değil.
- İlk "Server disconnected" hataları (surrogate, son_odeme 1900) tekrar edilince 422 / 201 döndü — ağ/yük kaynaklı, koda bağlı değil.
- api.log'daki `panik.py:142 'Unit' object has no attribute 'daire_no'` 500'ü başka bir ajanın isteği (tenant 547fd15e…), benim kapsamım dışı ama gerçek bir 500.
- /finans'ta 21.481.043,88 ₺ gibi 10+ haneli tutarlarda "₺" alt satıra kayıyor (kart 167px, içerik 175px) — kozmetik.
