# P180 — SSO ile yönetici kaydı akışı — Kararlar ve gerekçeleri

Bağlam: `yonetiyor.com/yonetici/kayit`'taki "Google/Microsoft/Apple ile devam et"
butonları sağlayıcı doğrulamasından sonra kullanıcıyı `app.yonetiyor.com` GİRİŞ
ekranına düşürüyordu. Sebep: OAuth başlatmada **niyet (kayıt/giriş) yok**; callback
sonrası dönüş adresi (`OAUTH_WEB_DONUS`) tek ve sabit → herkes girişe düşüyor.

Mevcut model (P154): sosyal giriş **ASLA kullanıcı yaratmaz**; ya kimlik zaten
bağlıdır (giriş) ya da "bağlama gerekli" (tesis kodu + telefon + SMS). Eşleşme
anahtarı **tesis ID + telefon**; e-posta yalnız görüntüleme (göç 0048). P180, bu
modele **yeni bir yetenek** ekler: niyet=kayıt olduğunda yönetici + tesis oluşturma.

---

## D1 — Niyet ayrımı state içinde (Kriter 1, 7)

- `/auth/oauth/baslat/{saglayici}` isteğine `niyet ∈ {giris, kayit}` eklenir
  (varsayılan `giris` → **mevcut davranış birebir korunur**). Redis `oauth:state`
  içine yazılır; callback niyeti **istekten değil state'ten** okur.
- **Neden state:** dönüş adresi ve callback davranışı sunucuda, state'teki niyete
  göre seçilir. İstemci niyeti/adresi değiştiremez → **açık yönlendirme (open
  redirect) açığı yok** (adresler ayarlardan gelir; modül başlığındaki kural).
- `niyet` beyaz-liste ile doğrulanır (`_NIYETLER`); geçersizse `giris`.

## D2 — Niyete duyarlı dönüş adresi (Kriter 1, 2)

- Yeni ayar **`OAUTH_KAYIT_DONUS`** (kayıt tamamlama sayfası). Dönüş adresi
  `f(yuzey, niyet)`: `giris`+web → `OAUTH_WEB_DONUS`, `giris`+mobil →
  `OAUTH_MOBIL_DONUS`, `kayit` → `OAUTH_KAYIT_DONUS`.
- Böylece kayıt niyetiyle gelen kullanıcı **giriş ekranına DÜŞMEZ**, kayıt
  tamamlama akışına gider. `OAUTH_KAYIT_DONUS` boşsa kayıt niyeti kapalı sayılır
  (kullanıcı sağlayıcıya gitmeden `basla`da 503 — sessiz yanlış-yapılandırma yok).

## D3 — Kayıt tamamlama (Kriter 1, 2)

- Backend zaten hazır: `/auth/kayit/tesis-olustur` `baglama_jetonu` (OAuth kimlik
  JWT'si) ile **parolasız** yönetici + tesis açar, `oauth_kimlik` bağlar. P180
  bunu YENİDEN YAZMAZ; niyet=kayıt callback'i bu jetonu üretip kayıt dönüşüne
  taşır.
- Eksik alan (telefon) tamamlama ekranında sorulur; **parola sorulmaz** (sağlayıcı
  ile gelen kullanıcıya parola gerekmez — `password_set=false`).
- Kayıt tamamlanınca `tesis-olustur` oturum açar ve **site adı ekranı = tesis_ad
  girişi** aynı adımdır; kullanıcı doğrudan ana ekrana geçer.

## D4 — Onaylar (Kriter 3)

- SSO butonları iki zorunlu onay (Sözleşme + KVKK) işaretlenmeden tıklanamaz —
  tanıtım formundaki mevcut `onaylarTamam` kilidi SSO'ya da uygulanır (zaten var).
- **Savunma derinliği:** backend niyet=kayıt için iki zorunlu onayı `baslat`ta
  ZORUNLU kılar (yoksa hata) — istemci kilidine güvenilmez.
- **IP + zaman damgası:** onaylar `baslat` anında (onayın verildiği an) sunucuda
  IP + zaman ile alınır, state'te taşınır, `tesis-olustur`'da **append-only
  audit_log**'a yazılır (`method: signup:oauth:{saglayici}`, meta: onaylar+ip).
  Parola yolundaki `yonetici_basvuru` satırının SSO karşılığı bu audit kaydıdır.
  `onay_ticari` → `user.pazarlama_eposta`; `TICARI_ILETI_AKTIF=false` olduğu için
  hiçbir ileti gönderilmez.

## D5 — Mevcut hesap durumu (Kriter 4)

Sıralı çözüm (niyet=kayıt callback'inde):
1. **Kimlik zaten bağlı** (`tenant_id_by_oauth`): tek anlamlı → o hesaba **giriş**.
2. **Kimlik bağlı değil AMA e-posta tek bir yönetici hesabıyla eşleşiyor**
   (yeni `yonetici_by_email` SECURITY DEFINER, göç 0069): yeni kimlik o hesaba
   **bağlanır + giriş**. "Aynı e-posta farklı sağlayıcıdan → tek hesap" böyle
   sağlanır.
3. **Eşleşme yok ya da BİRDEN ÇOK yönetici hesabı**: yeni kayıt (tesis oluştur).
   - Neden e-posta eşleşmesi yalnız `yonetici` rolüne: e-posta tesis-kapsamlı
     benzersizdir (global değil); bir kişi A tesisinde sakin, B tesisinde yönetici
     olabilir. Yönetici kaydında yalnız önceki YÖNETİCİ kaydıyla eşleştirmek, farklı
     bağlamdaki (sakin) hesaba yanlış bağlamayı önler.
   - Birden çok yönetici eşleşmesi (birden çok tesis yöneten kişi) belirsizdir;
     bu kişi zaten "kayıt" butonuna bastığına göre **yeni tesis** açması meşrudur.
- Kullanıcıya durum açıkça bildirilir ("Bu e-posta ile zaten hesabınız var, giriş
  yapıldı") — callback sonucundaki `durum` alanıyla.
- **GÜVENLİK (hesap ele geçirme önlemi):** e-posta tabanlı eşleşme YALNIZ
  sağlayıcı e-postayı **doğruladıysa** (`id_token.email_verified` = true; Apple
  private relay Apple-kontrollü → doğrulanmış) yapılır. Doğrulanmamışsa yeni kayıt
  gibi devam edilir — aksi halde saldırgan kurbanın adresini iddia eden
  doğrulanmamış bir hesapla mevcut yönetici hesabına bağlanabilirdi. Kimlik
  eşleşmesi (sağlayıcı+subject) bu riskten etkilenmez. (Otomatik güvenlik
  taraması bu açığı yakaladı; `Kimlik.email_verified` ile kapatıldı.)

## D6 — Apple özel durumu (Kriter 4, 5)

- **Private relay** (`xxx@privaterelay.appleid.com`): geçerli. E-posta zaten
  eşleşmede kullanılmaz (göç 0048); `Kimlik.relay` bayrağı arayüz içindir. Kayıtta
  e-posta olduğu gibi saklanır (relay dahil).
- **Ad yalnız ilk yetkilendirmede:** Apple ad-soyadı yalnız ilk seferde gönderir.
  `Kimlik.ad` ilk seferde alınır; hesap/oauth_kimlik oluşturulurken saklanır.
  Sonraki girişlerde ad boş gelir → **var olan ad korunur, üzerine yazılmaz**.

## D7 — app.yonetiyor.com giriş ekranı (Kriter 5, 6)

- Oradaki SSO butonları `niyet=giris` ile çalışmaya devam eder (**değişmez**).
- Hesabı olmayan biri giriş dener → callback `giris` niyetinde kullanıcı YARATMAZ
  (mevcut kural). Kimlik bağlı değilse `baglama_gerekli` döner; frontend bu ekrana
  "Hesabınız yok mu? **yonetiyor.com/yonetici/kayit**" bağlantısı ekler. **Sessizce
  hesap açılmaz** (backend zaten açmıyor; bu yalnız frontend yönlendirme eklemesi).

---

## Dönüş adresleri (dağıtım — build/çalışma zamanı)

- `OAUTH_KAYIT_DONUS` (YENİ, çalışma zamanı — api/worker): kayıt tamamlama sayfası.
- Tanıtım SSO butonları `app.yonetiyor.com` kayıt tamamlamaya niyet+onay taşır
  (build-time `NEXT_PUBLIC_*` — bkz. docs/P180-dagitim.md).

## Kapsam dışı (bilinçli)
- Mobil SSO **kayıt** (yuzey=mobil + niyet=kayit): bu tur web odaklı; mobil giriş
  değişmez. Mobil kayıt ayrı iş.
- Diğer 6 dil hukuki çeviri (P179 açık işi) bu turda değil.
