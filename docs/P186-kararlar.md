# P186 — Kararlar ve gerekçeleri

**Konu:** mobil yönetici girişi + eklenen kullanıcının bilgilerini düzenleme +
davet akışı/davet e-postası şablonu. Kesintisiz mod; prod dağıtımı ve cihaz
testi kullanıcıda. Dağıtım notları `docs/P186-dagitim.md`.

Bkz. [[p185-kayit-giris-yeniden]], [[p184-mobil-kayit-eposta-sso]].

---

## Bölüm 0 — İPTAL EDİLEN işler (uygulanmadı, bilerek)

P185'te "bilerek ertelenen" üç madde vardı. P186 kapsamında bunların üçü de
**iptal edildi** — yani hiçbiri yapılmayacak, çünkü ürün kararı bunları
istemiyor:

1. **Onay kuyruğu (kayıt_onay_kuyruğu) inceleme/onay paneli — İPTAL.**
   Gerekçe: "Mevcut tesise katıl"ın TEK yolu allowlist'tir (yönetici kişiyi
   önceden ekler). Ön-eklenmemiş biri kaydolamaz; bu **doğru** davranıştır,
   bir eksiklik değil. Dolayısıyla bir onay kuyruğu UI'sine gerek yok. Kuyruk
   tablosu backend'de yazılmaya devam eder (denetim izi) ama üzerinde işlem
   yapan bir panel **kasıtlı olarak yoktur**.

2. **Mobilde YÖNETİCİ kaydı — İPTAL.** Gerekçe: yönetici yalnızca web'de
   kaydolur. Mobil kayıt ekranı yalnız site sakini / güvenlik / tesis görevlisi
   sunar (P184/P186 kabul 1). "Tesis ID ile tamamlama" korunur. P185'te bu
   "geri istenmişti" diye not düşülmüştü; P186 bu isteği **geri çekiyor**.

3. **Telefonu tamamen opsiyonel yapmak — İPTAL.** Gerekçe: telefon **zorunlu**
   kalır (global-benzersiz iletişim anahtarı). Yalnızca "SMS yerine e-posta
   doğrulaması" isteniyordu ve o P184'te zaten yapıldı. Telefonu opsiyonele
   çevirmek istenmiyor.

---

## Bölüm 1 — Mobil yönetici girişi

### Mevcut durumun teşhisi (P184 "fazla kaldırma" neydi?)

Kod okuması (`mobile/lib/src/features/auth/presentation/login_screen.dart`,
`auth_controller.dart`, `sosyal_baglama_formu.dart`) şunu gösterdi:

- Giriş ekranında **SSO düğmeleri koşulsuz çiziliyor** (`SosyalGirisDugmeleri`,
  login_screen.dart:205) — sağlayıcı yapılandırılmamışsa hiç çizilmez, ama
  yöneticiye özel bir gizleme YOK.
- **Parola girişi** (`loginPhone`, login_screen.dart:65) rol filtresi
  içermiyor — yönetici telefon+parola ile girebiliyor.
- SSO dönüşü **bağlı bir kimlikse** (`durum='giris'` + jetonlar) →
  `oauthAkisi` doğrudan oturum açıyor (auth_controller.dart:391). Web'de SSO
  ile kaydolmuş yöneticinin kimliği **zaten bağlıdır** → mobilde SSO ile
  girişi **çalışıyor**.

Yani P184'ün "kaldırdığı" şey SSO girişi DEĞİLDİ. Kaldırılan, giriş ekranındaki
eski **"Tesis Kodu + telefon + SMS" ile mevcut hesaba bağlama formuydu**
(P185'te web'deki eşdeğeri "Bağlama isteği geçersiz" kök nedeni olarak
kaldırılmıştı). Bağlı olmayan bir SSO kimliği geldiğinde mobil, rol tamamlama
formunu (`SosyalBaglamaFormu`) gösteriyor; bu formun rol açılırında yönetici
YOK (yalnız 3 mobil rol). Bu yalnızca **yöntem-dışı** bir kenar durumu etkiler:
**parola ile** kaydolmuş bir yöneticinin mobilde **Google** denemesi.

### Karar

**Kabul 1/2/3 için ek koda gerek yok — akış zaten doğru:**

- **Kabul 1** (mobil kayıtta yönetici yok): `KayitRolu` yalnız 3 rol içerir
  (sakin/güvenlik/görevli). Değişmez. ✓
- **Kabul 2** (yönetici mobilde parola ile girer): `loginPhone` rol
  filtrelemez. ✓
- **Kabul 3** (yönetici mobilde SSO ile girer): **SSO ile kaydolmuş yönetici**
  = bağlı kimlik → `durum='giris'` → oturum. ✓ Web'de **parola ile** kaydolmuş
  yönetici zaten SSO kurmamıştır; o kişi **kaydolduğu yöntemle** (parola)
  girer — "aynı yöntemle giriş" ilkesi.

**Kanıt — mevcut testler zaten kapsıyor (yeni kod yok):**
- `mobile/test/sosyal_giris_test.dart` → "KIMLIK ZATEN BAGLIYSA oturum
  dogrudan acilir": bağlı SSO kimliği → `durum='giris'` → oturum. Bu test
  rol-bağımsızdır; mobil istemci role göre dallanmaz, backend bağlı her kimliğe
  (yönetici dahil) `giris` + jeton döner (`oauth.py:sonuc`, satır 502-549 —
  `tur=="giris"` düşer, jeton çifti üretir). Kabul 3.
- `mobile/test/kayit_rol_secimi_test.dart` → `KayitRolu.values.length==3` (mobil
  kayıtta yönetici yok). Kabul 1.
- `mobile/test/login_screen_phone_test.dart` → telefon+parola girişi. Kabul 2.

Backend `oauth.py:sonuc` doğrudan okundu ve doğrulandı: mobil `oauthBaslat`
niyet göndermez → varsayılan `giris`; bağlı kimlik → `tur=="giris"` → jeton +
`durum='giris'`. Bağlı-olmayan-SSO rol-tamamlama formunda "Vazgeç" zaten var —
yöntem-dışı deneme yapan yönetici oradan parola girişine dönebilir (çıkmaz yol
değil).

**Neden yönetici, bağlı-olmayan SSO formuna eklenmedi:** oraya yönetici
eklemek, mobilde yönetici KAYDINI geri getirmek olurdu — Bölüm 0/2 gereği
istenmiyor. Yönetici SSO'yu web'de bir kez bağlar (kayıt anında); sonrası her
cihazda çalışır.

---

## Bölüm 2 — Kullanıcı bilgisi düzenleme

Backend `PATCH /users/{id}` (update_user) zaten tüm alanları kabul ediyor,
denetime yazıyor, tenant + rol yetkisini uyguluyor, telefon çakışmasını
maskeliyor. Eksikler ve kararlar:

### 2.1 Blok/daire düzenlemede görünür (kabul 4)

Web formu blok/daire alanını yalnız **oluşturmada** gösteriyordu (`!editingId`
kapısı). Düzenlemede de gösterilir — **sakin VE yönetici** rolleri için
(P185 `DAIRE_ROLLERI`). Düzenleme açılınca kullanıcının mevcut daire ataması
yüklenir; kaydetmede değiştiyse atama güncellenir (ata/kaldır).

### 2.2 E-posta değişimi (kabul 5)

İki durum ayrılır, `password_set` alanına göre:

- **Kayıt TAMAMLANMAMIŞ (`password_set=false`):** kişi hesabı henüz
  sahiplenmemiş. Yönetici e-postayı değiştirince: alan güncellenir **+ davet
  tazelenir** (yeni jeton, `davet_olustur_veya_tazele` eski `jeton_hash`i
  ezer → **eski davet bağı ölür**) **+ davet e-postası YENİ adrese yeniden
  gönderilir**. Tümü sunucu tarafında, tek işlemde. ✓ kabul 5.

- **Kayıt TAMAMLANMIŞ (`password_set=true`):** hesap sahiplenilmiştir ve
  e-posta artık kişinin **giriş kimliğidir**. Yöneticinin bu alanı doğrudan
  ezmesine **izin verilmez** (409 `eposta_tamamlanan_hesapta_degistirilemez`);
  form bu alanı salt-okunur gösterir ve kişinin kendi **doğrulanmış e-posta
  değiştirme akışına** (`PATCH /me/eposta`: kod yeniye, bildirim eskiye)
  yönlendirir. **Gerekçe:** sahiplenilmiş bir hesabın giriş kimliğini yönetici
  panelinden değiştirmek bir **hesap-ele-geçirme** vektörüdür; platform bunun
  için zaten güvenli, sahibin sürdüğü doğrulamalı akışı sunuyor (mevcut
  `eposta_degistirme_bildirimi_metni`). Bu, §5'in "doğrulama yeniye / bildirim
  eskiye" güvenlik niyetini **korur** (o akış özünde sahibi gerektirir). Hiçbir
  kabul kriteri yöneticinin tamamlanmış hesabın e-postasını değiştirmesini
  gerektirmiyor (kabul 5 yalnız tamamlanmamış durumu kapsar).

### 2.3 Rol değişimi (kabul 6) + daire ataması kararı

Rol değişimi izinleri **anında** günceller (`AppUser.role` yazılır; yetki her
istekte `role`den okunur — oturum/token'da gömülü rol yok). ✓ kabul 6.

**Karar — rol değişince daire atamasına ne olur:** Daire (unit_resident)
ataması bu üründe **yalnız daire-tutan roller** için anlamlıdır: `resident` ve
`yonetici` (P185 `DAIRE_ROLLERI`). Rol değişimi kişiyi bu kümeden **çıkarırsa**
(ör. `resident` → `security`/`tesis_gorevlisi`/`denetci`), o kişinin
`unit_resident` bağları **kaldırılır** ve bu denetime yazılır. **Gerekçe:**
(a) "daire başına rolden tek hesap" kuralını bir güvenlikçi işgal edip gerçek
sakini engellememeli; (b) daire listelerinde bir güvenlikçinin "sakin/malik"
olarak görünmesi veriyi bozar. Rol daire-tutan küme **içinde** kalırsa
(`resident` ↔ `yonetici`) bağ **korunur**. Kişi gerçekten hem güvenlikçi hem
malikse yönetici düzenlemeden sonra daireyi elle yeniden atar — ama varsayılan,
bir daireyi yanlış rolde işgal bırakmamaktır.

### 2.4 Telefon değişimi (global-benzersiz, sızıntısız)

Telefon global-benzersizdir. Çakışmada backend jenerik 409
(`telefon_veya_email_zaten_kayitli`) döner — hangi hesabın numarayı tuttuğunu
**sızdırmaz**. Zaten mevcut (`_CONTACT_CONFLICT`). ✓

### 2.5 Denetim (kabul 7)

Her değişiklik `Action.USER_UPDATE` ile denetime yazılır: kim, ne zaman, hangi
**alanlar** (yalnız alan ADLARI), hedefin rolü. **Hassas değerler (parola, ad,
telefon, e-posta içerikleri) YAZILMAZ** — yalnız hangi alanın değiştiği. Davet
yeniden gönderimi ve daire-bağı kaldırma da meta'ya işlenir. ✓

### 2.6 Yetki sunucu-tarafı (kabul 8)

Tenant sınırı **RLS** ile (`get_tenant_db`), rol sınırı `_yonetim_kapisi` +
`yonetilebilir(user.role)` ile uygulanır. Başka tesisin yöneticisi bu
kullanıcıyı **göremez/düzenleyemez** (RLS satırı hiç döndürmez → 404). Sunucu
tarafı testle kanıtlanır. ✓

---

## Bölüm 3 — Davet akışı + davet e-postası

### 3.1 Excel içe aktarımda davet (kabul 9)

**Bulgu:** tekil ekleme (residents/users) daveti gönderiyordu, ama **Excel
içe aktarım (`_uygula_kisi`) davet GÖNDERMİYORDU.** Düzeltildi: içe aktarımla
oluşturulan (parolasız) her kişiye tekil eklemeyle **aynı** davet
(e-posta+SMS) gönderilir. ✓ kabul 9.

### 3.2 Davet e-postası şablonu (kabul 11-13)

Yeni modül `backend/app/davet_eposta.py`: davet e-postasını **HTML + düz
metin** çifti olarak, **7 dilde** üretir. `davet.py` bunu kullanır; SMTP
sağlayıcısı çok-parçalı (multipart) gönderir (aşağıda 3.3).

Teknik kurallar (§4): TABLO tabanlı yerleşim (Outlook), **Tesis ID HTML METİN**
olarak (Gmail görseli engeller → seçilebilir büyük metin), mağaza düğmeleri
metin-tabanlı (görsel engellense de çalışır), Outlook için `mso` koşullu blok +
karanlık mod, `text/plain` alternatifi, marka renkleri (lacivert `#102060`,
açık mavi `#2060A0`), **dinamik telif yılı**, TÜM bağlantılar env'den, Arapça
için `dir="rtl"`. **app.yonetiyor.com bağlantısı YOK** (tek bağlantılar: davet
bağı + iki mağaza + isteğe bağlı logo). Değerler `html.escape`'lenir
(enjeksiyon/kırılma önlenir). ✓ kabul 11/12/13.

**Dil seçimi kararı:** Alıcının henüz seçilmiş bir uygulama dili yoktur
(davet.py'nin kendisi bunu belgeliyor). En iyi mevcut sinyal, kişiyi **ekleyen
yöneticinin istek dilidir** (Accept-Language → `istek_dili`). Davet e-postası o
dilde gönderilir; varsayılan Türkçe. Uygulama açılınca kişi kendi dilini seçer.
Bu, şema değişikliği (kullanıcı/tenant `dil` alanı) gerektirmez.

**Panel-düzenlenebilirlik kararı (§4'ten bilinçli SAPMA — kullanıcı onayına
sunulur):** Davet e-postası bir **işlemsel (transactional)** e-postadır ve
katı gönderilebilirlik garantileri taşır (Outlook tablo, karanlık mod, 7 dil,
düz-metin paritesi, enjeksiyon güvenliği). Bu kod tabanında **tüm işlemsel
e-postalar** (OTP kodları, e-posta-değiştirme bildirimi — `eposta_sablonlari.py`)
**kasıtlı olarak kod-sahipli** ve panel-düzenlenebilir DEĞİLDİR; P179 panel
şablon sistemi **operasyonel/pazarlama** şablonları içindir (bakiye/toplantı),
orada serbest metin güvenlidir. Davet e-postasının yapısını serbest panel HTML
düzenlemesine açmak, §4'ün TALEP ETTİĞİ garantilerin tam da kendisini bozardı.
**Bu yüzden davet e-postası yapısı kod-sahipli tutuldu** ve mevcut işlemsel
e-posta mimarisiyle tutarlı hale getirildi. İçeriğin (karşılama/not) tenant
başına panelden özelleştirilmesi isteniyorsa, yapıyı bozmayan bir "davet notu"
enjeksiyon noktası ayrı bir iş olarak eklenebilir — kullanıcı isterse yapılır.
Bu sapma dağıtım notunda ve kullanıcıya ayrıca bildirilir.

### 3.3 Çok-parçalı (multipart) e-posta

`MesajSaglayici.gonder(...)` imzasına geriye-uyumlu isteğe bağlı `html=None`
parametresi eklendi. SMS/log sağlayıcıları yok sayar; `SmtpEpostaSaglayici`
`html` verildiğinde `set_content(metin)` + `add_alternative(html, "html")` ile
çok-parçalı gönderir. Böylece davet e-postası HTML gövde + düz-metin alternatif
taşır; diğer tüm çağrılar değişmeden çalışır.

### 3.4 Mağaza bağlantıları (env, uydurma YOK)

`play_store_url` biliniyor (`com.app.yonetiyor`, config varsayılanı dolu).
`app_store_url` **boş** (Apple App Store id'si henüz tahsis edilmedi) — boşken
düğme çizilmez (kırık bağlantı göndermek, hiç göndermemekten kötüdür). İkisi de
zaten env değişkeni. **App Store id'si tahsis edilince** `APP_STORE_URL`
prod env'e girilir; kod değişmez. `.env.prod.example` ikisini de içerir.
**Gerçek App Store adresi kullanıcıdan istenir** (uydurulmaz) — bkz. dağıtım
notu ve oturum sonu sorusu.

---

## Kabul kriterleri eşlemesi

| # | Kriter | Karar/Uygulama |
|---|--------|----------------|
| 1 | Mobil kayıtta yönetici rolü yok | Zaten öyle (`KayitRolu`=3 rol) ✓ |
| 2 | Yönetici mobilde parola ile girer | `loginPhone` rol filtrelemez ✓ |
| 3 | Yönetici mobilde SSO ile girer | Bağlı kimlik → oturum ✓ (mevcut test) |
| 4 | Kullanıcı listesinde tüm alanlarla düzenleme | Blok/daire düzenlemede açıldı ✓ |
| 5 | Tamamlanmadan e-posta değişimi → davet yeniden + eski geçersiz | password_set=false yolu ✓ |
| 6 | Rol değişimi izinleri anında günceller | role'den okunur ✓ |
| 7 | Değişiklikler denetimde | USER_UPDATE, yalnız alan adları ✓ |
| 8 | Başka tesis yöneticisi düzenleyemez (sunucu) | RLS + rol matrisi ✓ (test) |
| 9 | Ekleme VE Excel'de davet e-postası | `_uygula_kisi`'ye davet eklendi ✓ |
| 10 | Tüm test takımı yeşil (backend+web+flutter) | Koşulur |
| 11 | Tesis ID görsel engelli olsa da okunur | HTML metin blok ✓ |
| 12 | İki mağaza bağı çalışır + app.* bağı yok | env bağları, app.* yok ✓ |
| 13 | Gmail/Outlook/Apple Mail'de render | tablo+mso+karanlık mod+plain ✓ (cihazda doğrulanır) |

Cihazda/gerçek istemcide doğrulanacaklar dağıtım notunda listelenir.
