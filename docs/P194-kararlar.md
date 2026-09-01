# P194 — Mobilde yönetici SSO girişi

## Kusur: iki ayrı yerde iki ayrı sebep

Web'de kaydolmuş bir **yönetici**, mobil giriş ekranında "Google ile
devam" dediğinde giriş yapamıyordu.

### Sebep 1 — İSTEMCİ: giriş ekranı rol soruyordu

SSO dönüşünde kimlik henüz bağlı değilse giriş ekranı bir **bağlama
formuna** geçiyor. O formda bir **rol açılır listesi** vardı ve liste
`KayitRolu`ydan besleniyordu — yani **kayıt ekranının** listesinden.
Yönetici mobilden kaydolamadığı için o listede yönetici **yok**;
kullanıcı mecburen "Sakin" seçiyor, sunucu haklı olarak reddediyordu.

Yani **kayıt ekranının rol filtresi giriş ekranına da uygulanıyordu** —
sorunuzdaki dört şüpheden ikisi aynı anda doğruydu.

### Sebep 2 — SUNUCU: giriş niyetinde e-posta eşleşmesi yapılmıyordu

`niyet=giris`te kimlik bağlı değilse **daima** `baglama_gerekli`
dönüyordu. Oysa **aynı kimlik** `niyet=kayit` ile gelseydi (web kayıt
ekranı) doğrulanmış e-posta tek bir yönetici hesabıyla eşleşir ve giriş
yaptırırdı. Kural vardı, giriş yolunda uygulanmıyordu.

## Ölçümler (dev ortamı, gerçek yönetici hesabı)

**A. Kök nedenin kanıtı — aynı kimlik, aynı Tesis ID, tek fark rol beyanı:**

```
rol="resident" gönderildi  ->  durum="onay_bekliyor"   jeton YOK
rol GÖNDERİLMEDİ           ->  durum="giris"           jeton VAR
```

Yani sunucu (P191 §1) **zaten hazırdı**: rol beyanı yoksa rol hesaptan
okunur ve `_TAMAMLA_ROLLERI` yöneticiyi de kapsar. Eksik olan tek şey,
istemcinin beyanı bırakmasıydı.

**B. Web/mobil asimetrisi — aynı kimlik, iki niyet:**

```
niyet=kayit  ->  _kayit_coz  -> 'mevcut_hesap'   (giriş yapardı)
niyet=giris  ->  _kimligi_coz-> 'baglama'        (rol soran forma düşerdi)
```

**C. Bağlı kimlikle giriş (web'de Google ile kaydolmuş yönetici):**

```
_kimligi_coz -> 'giris'
POST /auth/oauth/sonuc -> durum='giris', jetonlar VAR
jeton içindeki rol: 'yonetici'
```

**D. Düzeltmeden sonra, giriş niyetinde e-posta eşleşmesi:**

```
A) DOĞRULANMIŞ e-posta   -> çöz='mevcut_hesap' -> durum='giris'  jeton VAR
                            jetondaki rol='yonetici'
B) DOĞRULANMAMIŞ e-posta -> çöz='baglama'      -> 'baglama_gerekli' jeton YOK
```

Güvenlik kapısı duruyor: doğrulanmamış adresle mevcut hesaba bağlanmak
hesap ele geçirmedir (P180 dersi).

**E. Parola yolu (mobil: telefon + parola):**

```
POST /auth/login-phone -> 200
jeton içindeki rol: 'yonetici'
GET /me -> 200  rol='yonetici'  ad='Acme Yonetici'
```

**F. UÇTAN UCA — mobil istemcinin kendi HTTP katmanı, çalışan sunucu:**

`AuthApi.oauthRolTamamla` (mobil kod) → `http://localhost:8000`:

```
MOBIL ISTEMCI -> POST /auth/oauth/rol-tamamla  (rol GÖNDERİLMİYOR)
  durum=giris  jetonlar=VAR
  JETONDAKİ ROL: yonetici
```

## Kararlar

**K1 — Giriş ekranından rol seçimi kaldırıldı.**
Giriş kimlik sorar, rol sormaz; kim olduğunu sistem bilir. `rol` alanı
istemci zincirinin tamamında (`AuthApi` → repository → controller →
ekran) **opsiyonel** oldu ve giriş akışı hiç göndermiyor.

**K2 — İki adımda da rol gönderilmez.**
`rol-tamamla-dogrula` (e-posta OTP yolu) da beyansız çağrılıyor; birinci
adımda beyansız geçip ikincide rol göndermek, OTP yolundaki yöneticiyi
yine çıkmaza atardı.

**K3 — Kayıt ekranı değişmedi.** Rol seçimi orada anlamlıdır ve duruyor;
yönetici mobilden hâlâ **kaydolamaz** (`kayit_rol_secimi_test.dart`
bunu ölçmeye devam ediyor).

**K4 — Giriş niyetinde de e-posta eşleşmesi (web ile simetri).**
Kural `_yoneticiyi_epostayla_bul` içine **tek yere** çıkarıldı ve iki
niyet de onu çağırıyor; kopyalamak, birinde yapılan bir sıkılaştırmanın
ötekinde unutulması demekti. Sonuç: web'de e-posta+parola ile kaydolmuş
bir yönetici mobilde "Google ile devam" deyince **Tesis ID bile
sorulmadan** giriyor.

**K5 — `mevcut_hesap` dalı çıplak INSERT yapmayacak (yan bulgu).**
`uq_oauth_kimlik_user_saglayici` bir kullanıcıya sağlayıcı başına tek
kimlik bırakır. Kişi aynı sağlayıcıdan **ikinci** bir hesapla gelirse
(iş → kişisel Google, aynı doğrulanmış e-posta) çıplak INSERT
`UniqueViolationError` atıyordu — kullanıcı 500 görürdü. Ölçüldü:
`duplicate key ... uq_oauth_kimlik_user_saglayici`. Artık
`_kimligi_bagla` çağrılıyor: eskisini yenisiyle değiştirir, başkasına
bağlı kimliği devralmayı reddeder.

## Giriş sonrası yönlendirme

`home_gate.dart` rolü jetondan okur; `yonetici` → `YoneticiHomeScreen`
(sakin arayüzü değil). Jetondaki rolün `yonetici` geldiği yukarıda üç
ayrı ölçümde görüldü (C, E, F).

## Testte çıkan bir tuzak (P187'nin aynısı)

Yeni testlerden ikisi **izolasyonda geçip tam takımda düşüyordu**:

```
RuntimeError: ... got Future ... attached to a different loop
```

Sebep, P187'de Celery tarafında düzeltilen tuzağın aynısı: asyncpg
bağlantıları **oluşturuldukları event loop'a bağlıdır**. Daha önce koşan
bir test `asyncio.run` ile bir döngü açıp kapatmış ve `app.db.engine`
havuzunda o **ölü döngüye** bağlı bağlantılar bırakmıştı; benim yeni
döngüm onlardan birini alınca patlıyordu.

Çözüm testte `_kendi_dongusunde()` yardımcısı:
* **başta** `dispose(close=False)` — ölü döngüye bağlı havuzu *ellemeden*
  bırakır (`close=True` olsaydı SQLAlchemy onları kapatmaya çalışır ve
  "Event loop is closed" atardı),
* **sonda** `dispose()` — kendi açtıklarımızı döngü kapanmadan düzgün
  kapatır; yoksa aynı tuzağı bir sonraki teste biz kurardık.

`test_p191ek_cihaz_hijyeni` aynı dersi kendi motorunu kurarak çözüyor; o
yol burada yok çünkü ölçülen fonksiyon `SessionLocal`i kendi içinde
kullanıyor ve dışarıdan oturum almıyor.

## Ölçemediklerim

- **Gerçek Google/Microsoft/Apple oturumu.** Sağlayıcıya çıkan gerçek ağ
  akışı (kod takası, JWKS) dev'de kurulu değil; kimlik doğrulama
  katmanı `test_oauth.py`de gerçek kripto ile ölçülüyor ama gerçek bir
  Google hesabıyla uçtan uca akış **denenmedi**.
- **Emülatör.** Bu makinede tanımlı AVD yok (`flutter emulators` →
  "Unable to find any emulator sources"), yalnız Linux masaüstü cihazı
  görünüyor. Ekran davranışı bu yüzden **widget testleriyle** ölçüldü:
  giriş ekranı gerçekten çizildi, üç sağlayıcı düğmesi doğrulandı, rol
  açılır listesinin **olmadığı** ve çağrının **rolsüz** gittiği
  görüldü.
- **Cihazda gerçek giriş** (APK ile telefonda Google akışı) — sizde.

## Dev ortamı notu

`YENI_KAYIT_AKISI` dev'de varsayılan **kapalı**; prod'da açık
(`docker-compose.prod.yml` → `${YENI_KAYIT_AKISI:-true}`). Ölçümler
bayrak **açık** koşuldu (`YENI_KAYIT_AKISI=true docker compose up -d api`),
çünkü prod'un durumu budur. Bayrak kapalıyken `rol-tamamla` 503 döner ve
mobil SSO tamamlama zaten çalışmaz — dev'de bu akışı denerken bayrağı
açmak gerekir.
