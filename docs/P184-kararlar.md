# P184 — Mobil kayıt akışı: SMS varsayımını kaldır, e-posta doğrulamasına geçir — kararlar

Kesintisiz mod. Kararlar gerekçeleriyle. Cihaz testi kullanıcıda.

**Sorun:** Mobilde Google ile giriş → Site ID + telefon soruluyor → "telefonunuza
kod gelecek" deniyor, kod hiç gelmiyor. Sebep: SMS gönderimi YOK (`SMS_AKTIF=false`,
Verimor başlık onayı alınmadı). Tek doğrulama kanalı e-posta. P181 Böl. 1-4'te web
e-postaya geçirildi ama mobil eski SMS varsayımıyla kaldı → mobil bu akışla
kullanılamaz durumda.

---

## K0 — Kapsam: bu sürüm backend'i DE değiştirir (mobil-only DEĞİL)

Görev "backend zaten böyle" diyordu; keşif bunu YALNIZ parola-yollu rol kaydı için
doğruladı (`/auth/kayit/rol-eposta-basla` + `-dogrula`, P177 3-şart kuralı + onay
kuyruğu HAZIR). **Ama SSO (Google/Microsoft/Apple) ile rol (sakin/güvenlik/tesis
görevlisi) kaydı backend'de HİÇ yoktu:** SSO kimliğini bir rol hesabına bağlamanın
tek yolu `/auth/oauth/baglan/*` idi ve o **SMS'e** dayanıyor (`kodu_dogrula` telefon
üstünden). E-posta-tabanlı hesap eşleşmesi bilerek YALNIZ yöneticiye açık
(`yonetici_by_email`, P180 D5). Yani SMS kapalıyken SSO rol kaydının çalışan HİÇBİR
yolu yoktu — "OTP soruyor" değil, tamamen çıkmaz.

**Karar (kullanıcı onayı):** SSO tamamlama ucunu bu sürümde yaz. Gerekçe (kullanıcı):
sakinlerin çoğu Google ile girmek isteyecek; o yol yoksa mobil kayıt yarım kalır.

## K1 — Terminoloji: "Kayıt ol" değil "girişte Tesis ID ile tamamlama"

Yönetici bir sakini/görevliyi panelden ekler → o kişinin `app_user` satırı ZATEN
vardır (aktif, rolü belli, `password_set=false`). Kişi mobilde hesabı "sıfırdan
açmaz", **var olan hesabı sahiplenir**: e-posta sahipliğini (OTP ya da SSO
`email_verified`) + Tesis ID ile kanıtlar. Bu yüzden mobil metinleri "Kayıt ol"
yerine **"Tesis ID ile giriş/tamamlama"** dili kullanır. Yönetici kaydı mobilde HİÇ
sunulmaz — yönetici web'den (`yonetiyor.com`) kaydolur; mobilde yöneticiye yalnız
giriş vardır.

## K2 — Yeni backend ucu: `POST /auth/oauth/rol-tamamla` (+ `-dogrula`)

Doğrulanmış SSO kimliğini (sağlayıcı + subject + e-posta, `baglama_jetonu` içinde
imzalı) bir rol hesabına bağlar. **P177 üç şartı aynen:**

- **(a) Tesis ID geçerli** — `tenant_id_by_kayit_kodu` (secdef, mevcut).
- **(b) SSO e-postası o tesiste yöneticinin eklediği listede** — `_liste_kontrolu`
  (mevcut): aktif + doğru rol + `password_set=false`.
- **(c) OTP:** sağlayıcı `email_verified=true` döndürüyorsa **OTP ATLANIR** (SSO
  e-postayı zaten doğruladı). `email_verified=false` ise **e-posta OTP İSTENİR** —
  bu şart gevşetilmez.

Akış (tek şema, `durum` alanı yönlendirir):
- `rol-tamamla` {baglama_jetonu, tesis_kodu, rol}:
  - uygun + `email_verified=true` → kimlik bağlanır + `eposta_dogrulandi=true` +
    oturum → `durum="giris"`, `jetonlar`.
  - uygun + `email_verified=false` → e-posta OTP gönderilir → `durum="otp_gerekli"`,
    `tesis_ad`. (İstemci `rol-tamamla-dogrula` çağırır.)
  - uygun DEĞİL (liste dışı / rol uyuşmuyor / hesap kullanımda) → onay kuyruğuna
    yazılır → `durum="onay_bekliyor"`.
- `rol-tamamla-dogrula` {baglama_jetonu, tesis_kodu, rol, kod}: OTP doğrular →
  şartlar yeniden → bağlar + oturum (`durum="giris"`) ya da `onay_bekliyor`.

Kod TEK YAZIŞ noktası (`baglan/dogrula` ile aynı sınıf): bir `oauth_kimlik` satırı
açar, ama ancak `email_verified` VEYA doğrulanan OTP'den sonra.

## K3 — Hesap ele geçirmeyi tekrarlama (P180 dersi)

**Doğrulanmamış e-posta ile allowlist eşleşmesi YAPILMAZ.** `email_verified=false`
ise bağlama YAPILMADAN önce OTP zorunlu; OTP e-posta sahibine gider. Böylece
"Google hesabım var ama e-postam doğrulanmamış" durumu bir başkasının rol hesabını
ele geçirmeye yol açamaz. Apple **privaterelay** adresleri geçerli sayılır (Apple o
adresi kendi kontrol eder → `email_verified` gibi; P180 kararı, `oauth.py` `relay`
mantığı zaten uyguluyor).

## K4 — Sızdırmama: geçersiz Tesis ID = liste dışı e-posta = AYNI yanıt

Kullanıcı isteği (madde 6): "Liste dışı e-posta ile geçersiz Tesis ID aynı jenerik
mesajı vermeli; hata mesajları hesabın var olup olmadığını sızdırmasın."

Bu yüzden `rol-tamamla`:
- **Geçersiz Tesis ID** → 422 DEĞİL, `durum="onay_bekliyor"` (kuyruğa yazılmaz —
  tenant yok — ama kullanıcıya AYNI mesaj).
- **Liste dışı e-posta** → `durum="onay_bekliyor"` (kuyruğa yazılır).

Not: bu, mevcut `rol-eposta-basla`'nın davranışından (geçersiz Tesis ID → 422
`kayit_bilgileri_gecersiz`) **bilerek ayrılır**. Oradaki gerekçe "Tesis ID kamuya
açık, en sık yazım hatası orada" idi; P184'te kullanıcı sızdırmama tarafını seçti.
Mobil UI, backend hangi durumu dönerse dönsün **geçersiz-tesis ve liste-dışı için
aynı nötr mesajı** gösterir (istemci-taraflı ikinci savunma).

SSO'da e-posta zaten saldırganın KENDİ doğruladığı adres olduğundan liste-içi/dışı
ayrımı yalnız kendi durumunu sızdırır (başkalarını enumerate edemez) — kabul.

## K5 — Kişi birden çok tesise bağlanabilir

Model destekliyor (`tesis_uyelik`, göç 0068). `rol-tamamla` mevcut `TesisUyelik`
yoksa birincil üyelik yazar; aynı SSO kimliği farklı tenant'lara ait farklı rol
hesaplarına bağlanabilir. `oauth_kimlik` benzersizliği kullanıcı+sağlayıcı bazında
(göç 0048), tenant-kapsamlı; çatışma yok.

## K6 — Kimlik zaten başka hesaba bağlıysa: üzerine yazma, anlaşılır hata

`_kimligi_bagla` (mevcut) başka bir kullanıcıya bağlı kimliği DEVRALMAZ →
`_BASKASINA_BAGLI` (409 `oauth_baska_hesaba_bagli`, METINLER'de kayıtlı). P184 bunu
`rol-tamamla`da da kullanır.

## K7 — Latent hata düzeltmesi: `_ROLLER` "gorevli" → "tesis_gorevlisi"

DB `user_role` enum'u `('admin','yonetici','security','tesis_gorevlisi','resident')`
(göç 0001). Ama `kayit.py:_ROLLER = ("resident","security","gorevli")` "gorevli"
kullanıyordu. `_liste_kontrolu` `user.role != rol` karşılaştırdığı için bir **tesis
görevlisi** e-posta/SSO ile kaydolmaya çalıştığında `user.role="tesis_gorevlisi"`
!= `"gorevli"` → HER ZAMAN `rol_uyusmuyor` → onay kuyruğuna düşerdi. Latent
(testlerde yalnız resident/security kullanılmış, hiç yakalanmamış). Hiçbir web/mobil
istemci "gorevli" kısa biçimini göndermiyor (hepsi `tesis_gorevlisi`).

**Karar:** `_ROLLER`'ı kanonik `("resident","security","tesis_gorevlisi")` yap;
mobil her yerde `tesis_gorevlisi` gönderir. Hem SSO hem parola yolu düzelir.
Regresyon testi eklendi.

## K8 — SMS yolları: kullanımdan kaldır, SİLME

Mobil ARTIK çağırmaz: `/auth/kayit/rol-basla`, `/auth/kayit/rol-dogrula`,
`/auth/giris/kod-iste`, `/auth/giris/kod-dogrula`, `/auth/oauth/baglan/basla`,
`/auth/oauth/baglan/dogrula` (hepsi SMS/telefon-kodu). Backend'de DURUYORLAR
(`SMS_AKTIF` ileride açılabilir). Kullanıcıya hiçbir ekranda SMS vaadi verilmez.

Parolasız giriş mobilde telefon-kodu yerine **e-posta koduna** geçer
(`/auth/giris/eposta-kod-iste` + `-dogrula`, backend'de HAZIR) — böylece "girişte
SMS gelmiyor" çıkmazı giriş ekranında da kapanır.

## K9 — Telefon alanı: yalnız iletişim, doğrulama aracı değil

Mobil kayıtta e-posta ZORUNLU; telefon OPSİYONEL iletişim bilgisi. Ekranda
"telefon yalnız iletişim içindir, doğrulama e-posta ile yapılır" açıklaması var.

## K10 — Kilit registreleri (aksi halde tam suite kırmızı)

Yeni uç eklendiği için ([[yeni-uc-error-kod-kilit-registreleri]]):
- `contracts/openapi.yaml` — iki yeni yol (canlı mount).
- `backend/tests/test_denetci_salt_okuma.py` — beklenen kümeye 2 uç (SOSYAL GİRİŞ,
  kimlik-öncesi sınıf).
- `backend/tests/yetki/rol-matrisi.txt` — yeniden üretildi.
- **Yeni APIError kodu YOK** — yalnız mevcut kodlar (`kayit_bilgileri_gecersiz`,
  `oauth_baska_hesaba_bagli`, `kod_gecersiz`) yeniden kullanıldı → METINLER'e
  ekleme gerekmedi.
- **Yeni SECURITY DEFINER YOK** — mevcut `tenant_id_by_kayit_kodu`/`tenant_id_by_oauth`
  yeniden kullanıldı → secdef envanteri değişmedi.

## K11 — Giriş ekranı: parolasız SMS bloğu KALDIRILDI (e-postaya çevrilmedi)

Giriş ekranındaki "Parolam yok, kodla giriş yap" bloğu SMS'e dayanıyordu
(`/auth/giris/kod-iste`, telefon). E-posta karşılığı (`/auth/giris/eposta-kod-iste`)
**`tenant_slug`** ister (`tenant_id_by_slug`) — bu, sakinlerin bildiği **Tesis ID**
(kayit_kodu) DEĞİLDİR; mobil kullanıcı slug'ı bilmez. Ayrıca P184 sonrası her rol
üyesi **parola VEYA SSO** ile tamamlar; ikisi de giriş sağlar. Bu yüzden dead+yanıltıcı
SMS bloğu **kaldırıldı** (kabul 1 — giriş ekranında SMS vaadi kalmadı). Bu "çalışan bir
yolu bozmak" değildir: SMS zaten kapalıydı.

## K12 — Eski SMS metotları koda BIRAKILDI, UI çağırmıyor

`auth_api.dart`/denetleyici/depo'daki `rolKayitBasla/Dogrula`, `oauthBaglan*`,
`girisKodu*` metotları DURUYOR (backend uçları da duruyor). Mobil UI **hiçbirini
çağırmıyor**. Gerekçe: `SMS_AKTIF` ileride açılırsa geri bağlanabilsinler ([[test uyumu]]
— mevcut controller/oauth testleri bu metotları hâlâ ölçüyor, silmek gereksiz kırılma
olurdu). "Kullanımdan kaldır ama silme" birebir uygulandı.

## K13 — Ayarlar → Hesabı sil (kodla): e-postaya geçirildi (ek iş, kullanıcı isteği)

Başta kapsam dışı bırakılmıştı; kullanıcı "e-posta kod ucunu da ekle" dedi → eklendi.
Yeni uç `POST /me/hesap-sil/eposta-kod-iste` doğrulanmış e-postaya `amac='hesap_silme'`
kodu gönderir (yoksa 422 `no_email`). `/me/hesap-sil` parolasız yolda **doğrulanmış
e-posta varsa e-posta kodunu**, yoksa telefon kodunu doğrular — kanallar karışmaz
(`kayit_dogrulama` vs telefon kod tablosu; ikisi de `amac='hesap_silme'`, göç YOK çünkü
`hesap_silme` zaten geçerli e-posta kod amacı [göç 0068/models `KOD_AMACI`]).
**Ek (kullanıcı isteği):** `PATCH /me/password`'ün parolasız yolu da e-postaya
geçirildi (aynı `amac='hesap_silme'` kanalı; doğrulanmış e-posta varsa e-posta,
yoksa telefon kodu). **Bulgu:** bu yol aslında **ölü koddu** — `PasswordChangeRequest`
şeması `current_password`'ı ZORUNLU tutuyor ve `kod` alanı YOKTU, yani parolasız dal
hiç erişilemiyordu. Şema `HesapSilmeIstek` desenine getirildi (`current_password`
opsiyonel + `kod` eklendi); böylece parolasız (SSO) kullanıcı **e-posta koduyla parola
KURABİLİR**. Parola sahibi kullanıcı hâlâ mevcut parolasını doğrular (zayıflama yok:
`password_hash is not None` dalında `current_password` yanlış/boşsa 400). Mobil UI yok
(backend yeteneği); `changePassword` yalnız parola yolunu gönderir. Böylece mobilde
hiçbir SMS kalıntısı kalmadı (kabul 1 tam).

## K14 — SSO rol-tamamla: rol BEYANI istenir (her iki yüzeyde)

Hem kayıt ekranı hem giriş-bağlama formu rol seçtirir ve `rol-tamamla` `body.rol`
gönderir (`_liste_kontrolu(user, body.rol)` — `rol-eposta-basla` ile aynı: liste'de ama
başka roldeyse `rol_uyusmuyor` ile kuyruğa düşer, yöneticinin göreceği doğru sebep).
Böylece backend'de rol-türetme değişikliğine gerek kalmadı.

---

## Kabul kriterleri karşılığı

1. Mobilde hiçbir ekran SMS kodu vaat etmiyor → K8, K9.
2. Sakin/güvenlik/tesis görevlisi mobilden tamamlıyor (rol + Tesis ID + e-posta OTP)
   → parola yolu `rol-eposta-*`; K1/K7.
3. Yöneticinin eklemediği e-posta hesap AÇMIYOR, onay kuyruğuna düşüyor, kullanıcı
   bilgilendiriliyor → K2/K4.
4. SSO ile (email_verified=true) OTP istenmiyor → K2 (c).
5. Mobilde yönetici kaydı sunulmuyor, yalnız giriş → K1.
6. Üç SSO butonu mobilde görünüyor+çalışıyor → mobil bölüm.
7. Hata mesajları hesap varlığını sızdırmıyor → K4.
8. flutter analyze temiz, flutter test yeşil, build apk başarılı → mobil bölüm.
9. Mevcut giriş yolları bozulmadı → SMS yolları duruyor; giriş (parola/SSO) değişmedi.
