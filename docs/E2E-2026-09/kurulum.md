# Bulgular: kurulum (§1 Kurulum/Onboarding + §13 Platform paneli)

## ORTAM NOTU
- Paylaşılan Next dev (:3000) ana ajan düzeltene kadar bozuktu (`.next`e eski `next build` karışmış, main-app.js 404, sayfalar hidrasyonsuzdu).
  O sırada ölçmek için repo kopyasından kendi dev sunucumu **:3101**de açtım (§13 panel formu, geçici kod girişi o sunucuda ölçüldü; aynı kod ve aynı backend).
  Ana ajanın düzeltmesinden sonraki bütün ölçümler :3000'de yeniden yapıldı: tur, boş durumlar, yardım ve bina düzenleme.
  Hidrasyondan kaynaklanan yanlış pozitif yok, çünkü bulguların hepsi ya API ya da çalışan (hidrate) sayfa ile doğrulandı.
- Makine yükü çok yüksekti (load avg 28'den 115'e, Chromium bir kez "Page crashed"). Süre ölçümleri bu yükte alındı.

## Açılan tesisler
- **WEB panelinden:** "E2E Kurulum Web 5668068", tenant 47042135-…, slug `e2e-kurulum-web-5668068-305a20`, kayıt kodu EEKU-260923.
  Yönetici e2e.kurulum.web.5668068@example.com / +905355668068. Panelin verdiği geçici kod V9NS-N9CG web'de hiç kullanılamadı.
- **kur.py `kurulum`:** "E2E kurulum Sitesi" (186397f0-…). Arşivle / geri al, KVKK ve daire testlerinde kullanıldı; şu an geri alınmış (aktif) durumda.
- API ile açılıp silinen 2 boş tesis: silbos, arsiv.

## KONTROL LİSTESİ

| # | Madde | Sonuç | Kanıt |
|---|---|---|---|
| 1.1a | Panelden web formuyla tesis + yönetici açma | KISMEN | Form çalışıyor. Ülke seçmeden yazılan numarada hata alanın altında doğru ("Önce ülke kodunu seçin"), ama form altında ham "İstek gövdesi geçersiz." de çıkıyor (KURULUM-06). Başarılı gönderimde kod `window.alert` ile gösteriliyor (KURULUM-05). |
| 1.1b | Davet maili geldi mi, süre, içerik | KALDI | Panelden açılan yöneticiye HİÇ e-posta gitmiyor: api.log'da adres 0 kez geçiyor, `davet` tablosunda satır 0. Kod `routers/tenants.py:84-171` e-posta göndermiyor (KURULUM-01). |
| 1.1c | Davet bağlantısıyla kayıt (/davet/<jeton>) | KISMEN | Yöneticiye davet yok (KURULUM-01). Yöneticinin eklediği tesis görevlisi için: e-posta 0,2 s içinde log'a düştü. İçerikte tesis adı, Tesis Kimliği, davet bağlantısı, mağaza bağlantıları ve adımlar var. app.localhost:3000/davet/<jeton> → "Parola oluştur" → ad + parola ×2 → "Kaydı tamamla" çalıştı. Ancak mobil-yalnız rol web yönetici paneline alındı (KURULUM-15). Davet bağlantısı dev'de de `https://yönetiyor.com/davet/…` (prod alan adı, `PORTAL_BASE_URL` dev'de ayarlı değil; ortam notu). |
| 1.1d | Geçici kodla web'de giriş | KALDI | E-posta + kod: 401 "Giriş bilgileri hatalı.". Telefon + kod: 401. Web formu kodu tanımıyor (KURULUM-02). |
| 1.1e | İlk girişte tanıtım turu; atlanabiliyor mu; tekrar açılabiliyor mu | GEÇTİ | 4 ekran, "Turu atla / Geri / İleri / Başlayalım" var. Reload sonrası tekrar çıkmıyor. /kurulum'daki "Tanıtım turunu tekrar göster" turu 1/4'ten açıyor. Küçük kusur için bkz. KURULUM-07. |
| 1.1f | "Başlamak için gerekenler (0/2)" | GEÇTİ (+kusur) | /kurulum'da "Başlamak için gerekenler 0/2 hazır" görünüyor. Aynı sayfada 19. adımın başlığı ham şablon metni: `{gecilen}/{toplam} adım` (KURULUM-03). |
| 1.1g | Kaç adımda kullanıma başlanıyor | ÖLÇÜLDÜ | Aşağıda. En az 9 etkileşim; 2. adım ancak belgelenmemiş bir yan yolla geçilebiliyor. |
| 1.1h | Blok/daire sonrası duyuru | GEÇTİ (web) | Web'de Blok ekle A/B ve Toplu daire (A 12, B 4: B-2..B-5) toast'larla oluştu. Duyurular → Yeni duyuru → Başlık + metin → Kaydet ile duyuru listede göründü (`ekran/11-duyuru-sonra.png`). Boş durum metni çelişkili (KURULUM-08). |
| 1.1i | B blokta "1" → "Daire no bu tesiste zaten kayıtlı" | KISMEN | Ölçüm: B için "1" kabul edildi (201, no="1"). Sonra A için "1" girilince 409 "Daire no bu tesiste zaten kayıtlı." döndü. No blok önekli değil ve tesis çapında benzersiz; blok alanı ayrı olsa da "1" iki blokta birden var olamaz (KURULUM-04). |
| 1.2 | Boş durumlar (25 modül) | KISMEN | Çoğu iyi. Ayrıntılar aşağıdaki tabloda (KURULUM-08, -09, -10). |
| 1.3 | Bağlam içi yardım "?" | KISMEN | 21 rota önekinde var (16 ayrı metin). Eksik ve yanlış metinli ekranlar aşağıda (KURULUM-11). |
| 13a | Tesis listesi: numaralandırma, arama, kurulum süzgeci, performans | KISMEN | Numara, arama ve süzgeç çalışıyor. API `GET /tenants` sayfalamasız 3788 satır ve 805 KB döndürüyor (0,49 s). Web listesi ilk açılışta 11-27 s (KURULUM-12). |
| 13b | Platform tesisinde Sil yok ("Korumalı") | GEÇTİ | Listede `platform_admini_var` true olan tek tesis Acme Plaza; kodda Sil yerine "Korumalı" çiziliyor. API'de arşivleme 409 "Kendi bağlı olduğunuz tesisi arşivleyemezsiniz." |
| 13c | Boş tesis silme: önizleme + ad yazdırma | GEÇTİ | `silme-ozeti` sayıları geliyor. Yanlış onay ("SİL") ve küçük harfli ad 409; tam ad 204; ardından GET 404. |
| 13d | Geçmişi olan tesis arşivleme ve geri getirme | GEÇTİ (+not) | Şikâyetli tesiste doğrudan silme 409 ("önce arşivleyin"). Arşivleme 200: tesis normal listeden düşüyor, arşiv listesinde çıkıyor; giriş 401; refresh 401 "Bu tesis arşivlendi; oturum kapatıldı.". Geri alma 200: giriş yeniden 200. Mevcut access token'ın ömrü boyunca API erişimi sürüyor (KURULUM-13). |
| 13e | Son platform admini silinemez | GEÇTİ (kodla ve rollback'li DB denemesiyle) | `users.py:618-628` + trigger `trg_son_platform_admini_koru` (göç 0126). `BEGIN; DELETE …admin@acme.com; ROLLBACK` → "SON PLATFORM ADMINI SILINEMEZ". admin@acme.com silinmedi. |
| 13f | Sürüm politikası | GEÇTİ | PUT android: geçersiz sürüm 422, platform=windows 422, yönetici 403. `/surum/kontrol` zorunlu / önerilen / güncel doğru döndü. Eski değer (null/null/{}) geri yazıldı ve GET ile doğrulandı. Asgari > önerilen (2.0.0 / 1.0.0) kabul ediliyor (KURULUM-14). |
| 13g | KVKK metinleri | GEÇTİ | POST 201 surum=1. Aynı gövde 409. Sakinde `onay_gerekli` false'tan true'ya döndü. Yönetici POST 403. |

### §1.1g Adım sayısı (web, gerçek yol)
1. Admin → Tesisler → "Yeni tesis" → ad, ad-soyad, ülke seç + telefon, e-posta → Oluştur (native alert'teki kodu not al).
2. Yönetici app.* /login'de e-posta + geçici kod ile giriyor → **401**. Çalışan tek yol: "Parola yerine e-postaya kod gönder" → e-postadaki 6 haneli kod → Giriş. Hiçbir yerde anlatılmıyor.
3. Tanıtım turu (4 ekran veya "Turu atla") + kurulum hatırlatıcısı ("Daha sonra").
4. Bina düzenleme → Blok ekle (A).
5. Blok ekle (B).
6. Toplu daire oluştur (A).
7. Toplu daire oluştur (B).
8. Duyurular → Yeni duyuru → yayınla.

Toplam **~9 ekran etkileşimi**. Engel 2. adımda: kalıcı parola hiç kurulmuyor, yönetici her girişte e-posta kodu istemek zorunda.

### §1.2 Boş durum tablosu (yeni tesis, yönetici, :3000)
| Rota | Açıklayıcı metin | Eylem düğmesi | Not |
|---|---|---|---|
| /units | var ("Önce en az bir blok tanımlamalısınız…") | "Blok tanımla" | iyi |
| /residents | "Henüz sakin yok. Kullanıcılar ekranından sakin hesabı açabilirsiniz." | **yok** | KURULUM-09 |
| /tasks | "Görev yok / Filtreyi değiştirin ya da yeni bir görev ekleyin." | "Yeni görev" | Filtre yokken "filtreyi değiştirin" deniyor |
| /bakim | var | "Ekipman ekle" | iyi |
| /assets | "Demirbaş yok / Filtreyi değiştirin…" | "Yeni demirbaş" | aynı filtre cümlesi |
| /kameralar | var | "Yeni kamera" | iyi |
| /checkpoints | var | "Yeni nokta" | iyi |
| /patrol-plans | var | "Yeni plan" | iyi |
| /vardiya-plani | var | "Yeni vardiya", "Yeni şablon" | iyi |
| /announcements | **çelişkili**: "Duyurular site yöneticisi tarafından mobil uygulamadan oluşturulur." | "Yeni duyuru" (web'de) | KURULUM-08 |
| /anketler | "Anket yok / Aşağıdan yeni bir anket açın." | "Anketi aç" | düğme üstte, metin "aşağıdan" diyor |
| /etkinlik-yonetimi | var | "Yeni etkinlik" | iyi |
| /complaints | var ("mobil uygulamadan talep açtığında…") | yok (tasarım) | kabul |
| /dues | "Tahakkuk yok…" | "Toplu tahakkuk oluştur" | kasa/tür yokken ne olacağı söylenmiyor |
| /finans/tahsilatlar | yalnız "Bu listede kayıt yok." | "+ Yeni" | KURULUM-10 |
| /finans/giderler | yalnız "Bu listede kayıt yok." | "+ Yeni" | KURULUM-10 |
| /finans/gelirler | yalnız "Bu listede kayıt yok.", açıklama satırı da yok | "+ Yeni" | KURULUM-10 |
| /finans/butce | "Henüz kayıt yok" | form | KURULUM-10 |
| /finans/borclular | boş durum cümlesi yok, 0 kartları | yok | borç yoksa normal |
| /rezervasyon-yonetimi | var | "Yeni alan" | iyi |
| /ziyaretciler | yöneticiyi /dashboard'a atıyor | — | P129 tasarımı (`lib/yuzey.ts:526` boş rol listesi). Yönetici web'de ziyaretçi göremez |
| /arac-gecisleri | var | elle giriş yok (tasarım) | iyi |
| /akilli-ev | yalnız bölüm anahtarları; "merkez bağlı değil" türü boş durum yok | — | bilinen açık madde, not |
| diyafon | web rotası YOK (menüde yok) | — | bilinen açık madde |
| (vardiya /shifts, NFC, sayaç) | — | — | — |

Ekran görüntüleri: `$S/kurulum/ekran/12_*.png`, `11-*.png`.

---

### KURULUM-01: Panelden açılan yöneticiye hiçbir e-posta / davet gitmiyor
- Sınıf: **Engelleyici** (onboarding)
- Rol / yüzey: admin → yönetici / web paneli + API
- Adımlar: localhost:3000 → Tesisler → Yeni tesis → birincil yönetici e-postası e2e.kurulum.web.5668068@example.com → Oluştur.
- Beklenen: form ipucunun dediği gibi ("Davet bu adrese gider; adres olmadan yönetici hesabını sahiplenemez.") yöneticiye davet veya erişim e-postası gitmeli.
- Olan: api.log ve worker.log'da adres 0 kez geçiyor; `davet` tablosunda o kullanıcıya satır 0. Tek iletim kanalı, admin'e gösterilen native `alert` içindeki geçici kod ("Her yönetici telefonu + kendi kodu ile girip…").
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/tenants.py:84-171` (`create_tenant`): `davet_olustur_ve_gonder` çağrılmıyor (yalnız `users.py:433`, `residents.py:141` ve `ice_aktarim.py:470` çağırıyor). `add_yonetici` (`tenants.py:436-480`) için de aynı durum geçerli. Göç notu P197 "davet yalnız e-postadan gider" diyor, ama bu yolda davet yok.
- Önerilen düzeltme: parolasız açılan her yönetici için `davet_olustur_ve_gonder` çağrılmalı (users.py deseni). Ya da en azından mevcut "tesis erişim bilgileriniz" e-postası gönderilmeli. Form ipucu ile gerçek davranış aynı olmalı.

### KURULUM-02: Panelin verdiği geçici kod web girişinde çalışmıyor; yönetici kalıcı parola kuramıyor
- Sınıf: **Engelleyici**
- Rol / yüzey: yönetici / web (app.localhost)
- Adımlar: /login → kimlik e2e.kurulum.web.5668068@example.com (ya da 05355668068), parola V9NS-N9CG → Giriş.
- Beklenen: kodla girip parola belirleme ekranına düşmek (alert metni de bunu vaat ediyor).
- Olan: iki kimlikle de `POST /api/auth/login` **401 "Giriş bilgileri hatalı."**. API doğrudan denendiğinde de 401. Ekran: `ekran/11-web-gecici-kod-telefon.png`. Tek çıkış yolu "Parola yerine e-postaya kod gönder": kod 1 dk içinde log'a düştü, doğrulama 200 ile oturum açtı. Ancak `password_set=false` kalıyor ve kalıcı parola kurdurulmuyor.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/auth.py:246-249`. `/auth/login` yalnız `verify_password(body.password, r["password_hash"])` yapıyor ve `temp_code_hash`e bakmıyor. Geçici kod yalnız `/auth/login-phone`da (`auth.py:355-376`) işleniyor. Web formu `components/GirisFormu.tsx:58-61` P205'ten beri `login-phone`u çağırmıyor. BFF `app/api/auth/login-phone/route.ts` duruyor ama kullanılmıyor, web'de set-password ekranı da yok.
- Önerilen düzeltme: `/auth/login`de `password_set=false` ve `temp_code_hash` eşleşiyorsa `setup_token` dönülmeli; web'e parola belirleme adımı eklenmeli. Ya da KURULUM-01 ile birlikte geçici kodu tamamen davet bağlantısıyla değiştirip alert metni düzeltilmeli.

### KURULUM-03: Kurulum sihirbazının 19. adımının başlığı ham şablon metni: "{gecilen}/{toplam} adım"
- Sınıf: Orta
- Rol / yüzey: yönetici / web /kurulum
- Olan: "Şunları da yapabilirsiniz" listesinde ve 19 numaralı adım kartında başlık `{gecilen}/{toplam} adım` (ekran `11-kurulum.png`). Bu adım aslında "Sayaçlar".
- Şüpheli kök neden: `admin-web/lib/kurulum-adimlari.ts:200-204`, `sayac.etiket: "kurulumSayac"`. Bu anahtar sözlükte sayaç metni değil, adım sayacı: `tr.ts:1176 kurulumSayac: "{gecilen}/{toplam} adım"`. Anahtar adı çakışıyor.
- Önerilen düzeltme: sayaç adımına ayrı bir anahtar (ör. `kurulumSayacAdimi: "Sayaçlar"`) verilmeli.
- Ayrıca: sayfa alt başlığı "Sekiz adımda tesisi çalışır hâle getirin" diyor, listede 19 adım var ve hatırlatıcı "0/19 adım" gösteriyor (Küçük).

### KURULUM-04: Daire no tesis çapında benzersiz; blok alanı ayrıyken iki blokta "1" olamıyor
- Sınıf: Orta (Öneri sınırında)
- Rol / yüzey: yönetici / API `POST /units` (web bina düzenleme aynı ucu kullanıyor)
- Adımlar: B blok, no "1" → 201. A blok, no "1" → 409 "Daire no bu tesiste zaten kayıtlı.". B blok, no "B-1" → 409 (toplu oluşturmanın ürettiği B-1 ile çakıştı).
- Olan: kullanıcı blok alanını seçtiği için "1"i blok içi numara sanıyor. Hata mesajı hangi dairenin (hangi blokta) çakıştığını söylemiyor. Toplu oluşturma "A-1" biçimi üretirken tekil formda önek elle yazılmak zorunda, yoksa blok adı olmadan "1" oluşuyor.
- Şüpheli kök neden: `units.py:609-611` tesis içi `no` benzersizliği; `building-editor/page.tsx:388-406` no alanını olduğu gibi gönderiyor.
- Önerilen düzeltme: tekil formda no alanı blok önekini otomatik göstermeli/eklemeli ("B-" sabit + numara). Hata mesajına çakışan dairenin blok ve no bilgisi eklenmeli.
- Not: web'de tekil "+" hücresine Playwright ile tıklanamadı (erişilebilir adı yok); ölçüm API ile yapıldı.

### KURULUM-05: Geçici kod `window.alert` ile gösteriliyor (bir kez, kopyalanamaz)
- Sınıf: Küçük
- `app/(protected)/tenants/page.tsx` `save()`: `window.alert(...)`. Kod yalnız bir kez dönüyor; alert kapanınca kayboluyor ve tema/dil dışı native pencerede kalıyor. Kopyala düğmesi yok (projede `KopyaKod` bileşeni zaten var).
- Önerilen: `Modal` + `KopyaKod`.

### KURULUM-06: Yeni tesis formunda ülke seçilmezse alanın altında doğru hata, form altında ham "İstek gövdesi geçersiz." çıkıyor
- Sınıf: Küçük
- Adımlar: ülke seçmeden 5355668068 yaz → Oluştur → BFF 422.
- Beklenen: istemci doğrulaması gönderimi durdurmalı.
- Olan: istek sunucuya gidiyor, form altında "İstek gövdesi geçersiz." yazıyor (ekran `11-ulkesiz-telefon.png`).
- Kök neden: `TelefonAlani` hatası yalnız gösterim amaçlı, `save()` bu hatayı kontrol etmiyor.
- Önerilen: gönderimden önce `telefonHataMetni` kontrolü; ya da TR varsayılan önerisi.

### KURULUM-07: İlk girişte tur ve kurulum hatırlatıcısı üst üste açılıyor
- Sınıf: Küçük
- Olan: ilk girişte iki `role=dialog` aynı anda var: "Kurulumu tamamlayın 0/19 adım" ve "Yönetio'ya hoş geldiniz 1/4". Tur bitince hatırlatıcı da kapatılmak zorunda (`ekran/11-ilk-giris.png`: arkada ikinci modal görünüyor).
- Önerilen: tur açıkken hatırlatıcı bastırılmalı.

### KURULUM-08: Duyurular boş durumu "mobil uygulamadan oluşturulur" diyor, ama web'de "Yeni duyuru" düğmesi var
- Sınıf: Küçük
- Olan: /announcements metni: "Henüz duyuru yok | Duyurular site yöneticisi tarafından mobil uygulamadan oluşturulur." Hemen üstteki bant "Duyurular web'den ve mobilden oluşturulabilir".
- Önerilen: boş durum metni güncellenmeli (P190'da web oluşturma eklenmişti; metin eskimiş).

### KURULUM-09: Sakinler boş durumu eylem düğmesi vermiyor
- Sınıf: Küçük
- /residents: "Kullanıcılar ekranından sakin hesabı açabilirsiniz." Bağlantı veya düğme yok, kullanıcı menüden kendisi bulmak zorunda.
- Aynı sınıf: /tasks ve /assets boşken "Filtreyi değiştirin" cümlesi (filtre yokken yanıltıcı). /anketler "Aşağıdan yeni bir anket açın" diyor ama düğme üstte.

### KURULUM-10: Finans alt sayfaları boşken yalnız "Bu listede kayıt yok." diyor
- Sınıf: Küçük / Öneri
- /finans/tahsilatlar, /giderler, /gelirler, /butce: kasa veya tür tanımı yokken "+ Yeni"nin çalışmayacağı ya da önce ne yapılacağı söylenmiyor. /gelirler'de sayfa açıklama satırı da yok. Sihirbaz bu bilgiyi biliyor ("Kasa yoksa tahsilat ve gider kaydedilemez"); ekranlar göstermiyor.

### KURULUM-11: Bağlam içi yardım eksik veya yanlış ekranlar
- Sınıf: Küçük
- Yardımın olduğu yerler: `admin-web/lib/ekran-yardimi.ts` 21 rota öneki, 16 ayrı metin. Ölçüldü; aşağıdaki listede "?" düğmesi YOK:
  /units, /assets, /checkpoints, /patrol-plans, /anketler, /etkinlik-yonetimi, /complaints, /rezervasyon-yonetimi, /arac-gecisleri, /akilli-ev
  (ayrıca kodda eşlemesi yok: /olaylar, /sayac-okuma, /transparency, /audit, /tenants ve bütün platform ekranları, /kvkk-metinler, /surum-politikasi).
- Yanlış veya genel metin:
  - /finans/borclular, /finans/butce, /finans/giderler, /finans/tahsilatlar hep aynı "Tek defter: her para hareketi buraya yazılır…" metnini gösteriyor. Bütçe ve borçlular ekranını anlatmıyor.
  - /residents "Sakin, personel ve yönetici hesapları" (Kullanıcılar metni) gösteriyor, ama Sakinler ekranı hesap açmıyor.
- DOM'da iki `[data-test=ekran-yardimi]` var (mobil ve masaüstü üst çubuk). Görünmeyenine tıklama zaman aşımına düşüyor; test yazacaklara not.

### KURULUM-12: Tesis listesi sayfalamasız (3788 satır, 805 KB tek yanıt)
- Sınıf: Orta (performans)
- API `GET /tenants`: 3788 öğe, 805 KB, 0,49 s. `?kurulum=false` 1115 öğe. Web /tenants ilk yüklemesi yüklü makinede 11,6-26,9 s ("table tbody tr" görünene kadar). Tablo istemcide sayfalıyor (25 satır görünüyor), yani her açılışta bütün liste iniyor.
- Kök neden: `routers/tenants.py:174-249` limit/cursor yok. Kodun kendi yorumunda "Bugün 8 tesis var" varsayımı yazıyor (`tenants/page.tsx`).
- Önerilen: sunucu tarafı sayfalama (`limit`/`cursor`) + toplam sayı.

### KURULUM-13: Arşivlenen tesiste mevcut access token süresi dolana kadar çalışıyor
- Sınıf: Küçük / Öneri
- Arşivledikten sonra sakinin eski access token'ı ile `/me` ve `/complaints` → 200. Refresh 401 ("Bu tesis arşivlendi; oturum kapatıldı."). Etki penceresi en çok 15 dk (ACCESS_MAX_AGE). Arşiv yazma işlemlerini engellemek amaçlanıyorsa access token kontrolüne `arsivlendi_at` eklenmeli; değilse kabul edilebilir.

### KURULUM-14: Sürüm politikasında asgari sürüm > önerilen sürüm kabul ediliyor
- Sınıf: Küçük
- PUT android `{"asgari_surum":"2.0.0","onerilen_surum":"1.0.0"}` → 200. Tutarsız politika sessizce kaydediliyor. Önerilen: 422 (önerilen ≥ asgari). Test sonrası değerler null'a geri alındı.

### KURULUM-15: Davet bağlantısıyla kaydını tamamlayan mobil-yalnız rol (tesis görevlisi) web yönetici paneline alınıyor
- Sınıf: **Ciddi**
- Rol / yüzey: tesis_gorevlisi / web app.localhost `/davet/<jeton>`
- Adımlar: yönetici `POST /users` ile tesis_gorevlisi açtı. Davet e-postasındaki jeton app.localhost:3000/davet/<jeton>'da açıldı → Parola oluştur → Kaydı tamamla.
- Beklenen: P129 kararına göre saha/sakin rolleri app.* sayfası görmez. Normal girişte 403 `mobil_uygulama` ve mağaza bağlantıları gösteriliyor.
- Olan: oturum açılıp /dashboard'a yönlendirildi. Boş sol menü, "Tesis Görevlisi" etiketi, yönetici "Hızlı işlemler" (Tahsilat gir, Duyuru yayınla, Personel ekle), "Finansal özet: Bir hata oluştu." (`/api/panel/finans-ozet` 403), sonsuz iskeletler (`ekran/11-davet-sonrasi.png`).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `admin-web/app/api/auth/davet/parola/route.ts` jetonu `loginResponse` ile doğrudan çereze yazıyor. Normal girişin geçtiği `lib/oturum-kapisi.ts` `oturumAc` → `rolYuzeyeGirebilir` kapısını atlıyor. Davet sayfası (`app/davet/[jeton]/page.tsx:126`) sonra `router.replace("/")` yapıyor.
- Önerilen düzeltme: davet BFF'i de `oturumAc(…, yuzey)` üzerinden geçmeli. Mobil rolde oturum açmadan "Kaydınız tamam, uygulamayı indirin" ekranı ve mağaza bağlantıları gösterilmeli. Aynı kontrol `set-password` / `eposta-kod` BFF'lerinde de yapılmalı.
