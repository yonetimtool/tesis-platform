# P222 — Izgara şikayet sayısı + SSO e-posta ön-doldurma

Tarih: 2026-09-09

---

## §1 — Ana ekran ızgarasındaki şikayet sayısı

### Ölçüm önce

Izgaranın hangi uçtan beslendiği ölçüldü, tahmin edilmedi:

| Yer | Uç | Okunan alan | Pencere uygulanıyor mu |
|---|---|---|---|
| Mobil ızgara karosu "Şikayet Haritası" | `GET /unit-complaints?durum=acik&limit=1` | `meta.total` | **HAYIR** |
| Karonun açtığı harita | `GET /unit-complaints/building-map` | `complaint_count` | evet |
| Yoğunluk | `GET /unit-complaints/density` | `acik_sayisi` | evet |
| Sakin "Şikayetlerim" karosu | `GET /unit-complaints/mine` | `meta.total` | hayır (bilinçli, aşağıda) |

Yani karo **"5 Açık"** derken dokununca açılan harita **0** gösterebiliyordu.
Modül başlığındaki iki sayıdan (görünür / eşik) hiçbiri değil, **üçüncü,
sınıflandırılmamış bir sayı**ydı.

P220'de harita ve sakinin kendi sayımı pencereye bağlanmıştı; ızgara
karosu farklı bir uçtan beslendiği için o turda atlanmıştı.

### Karar

Yeni uç: `GET /unit-complaints/gorunur-sayi` → `{"acik_sayisi": N}`.
Haritayla **aynı** `_harita_penceresi()` fonksiyonundan geçer.

**Neden yeni bir uç, neden liste ucuna bayrak değil:** liste ucunun
`meta.total`'ı bir *sayfalama* toplamıdır; onu pencereyle şartlandırmak
listenin kendisini de daraltmayı davet ederdi. Ayrı uç, "görünür sayı"yı
adıyla ayırıyor ve ızgara için tek bir tam sayı taşıyor
(`/density` aynı sayıyı verir ama daire-başı tüm listeyi taşır).

**Liste ucu BİLEREK penceresiz kaldı.** Kuyruktan kayıt düşürmek,
yöneticinin açık kalmış eski bir şikayeti hiç görmemesi ve sakinin
"şikayetim kayboldu" demesi olurdu — P220'de kilitlenen karar
(`test_p220_gorunur_sayi.py::test_PENCERE_DISI_SIKAYET_LISTEDE_ve_MINE_
DA_DURUYOR`). Yeni test bu kilidin hâlâ geçerli olduğunu da ölçüyor.

**Sakinin "Şikayetlerim" karosu (`/mine`) değiştirilmedi:** o karo
sakinin *kendi kayıtlarını* sayar ve dokununca açtığı liste de aynı
kayıtları gösterir — ikisi tutarlı. Pencerelemek, sakinin kendi
şikayetini kaybetmesi olurdu.

**Eşik sayacına dokunulmadı** ve dokunulmadığı ölçüldü: harita penceresi
1 saatken 3 saat eskitilmiş 5 şikayetle eşik sayacı hâlâ 5 görüyor.

### Web

Web'de aynı kusur **yoktu**; **eksik bir yüzey** vardı: panoda şikayet
sayısı gösteren hiçbir rozet yoktu (pano `/api/dashboard/live`'dan
besleniyor ve yanıtında şikayet alanı yok). Parite gereği eklendi ve
mobille aynı uçtan besleniyor.

**`/schematic` varsayılan kısayol listesine EKLENMEDİ — ve eklenmeyecek.**
`WIDGET_SINIRI` 6; yedinci giriş `/olaylar`ı sessizce düşürürdü. Kullanıcı
kararı: *"hangi kısayolun çıkacağı yöneticiye göre değişir — birinin işine
yarayan diğerine yaramaz; sabit bir seçim yapıp birinin kısayolunu düşürmek
yanlış olur."*

Bu karar ancak yönetici kısayolu **kendisi ekleyebiliyorsa** doğru. Ölçüldü:

- `/schematic` `lib/menu.ts`te `grup: "tesis"` ile duruyor,
- `lib/yuzey.ts`te rol kapısı `["admin", "yonetici"]`,
- pano `adaylar` listesini `menuGruplari("tesis", rol)`ten türetiyor —
  yani menüde görünen her sayfa seçilebilir kısayol adayı,
- "Paneli düzenle" → "Kısayolları seç" kutusunda satır **işaretsiz ve
  etkin** geliyor, işaretlenince `/api/me/pano-tercihi`ye yazılıyor.

Uçtan uca sürüldü ve kilitlendi
(`tests/p222-sikayet-rozeti.dom.test.ts`). Kırarak doğrulandı: menüden
düşürmek de rol kapısını daraltmak da testi düşürüyor.

Rozet, `/schematic` widget'ını seçen kullanıcıda görünür.

Rozet **uydurulmaz**: sayı elimizde yoksa (yükleniyor, 500, yetkisiz)
alan hiç konmaz; `0` da çizilmez (boş rozet gürültüdür).

---

## §2 — SSO kaydında e-posta

### Ölçüm önce: e-posta nereye kadar taşınıyordu

| Katman | Durum |
|---|---|
| Sağlayıcı `id_token.email` | **geliyor** (Google, Microsoft, Apple ilk izinde) |
| `oauth.py::_kimlik_coz` | **çözüyor** (`eposta`, `email_verified`, `relay`) |
| `_baglama_jetonu` (imzalı) | **taşıyor** |
| `POST /auth/oauth/sonuc` yanıtı | **dönüyor** (`eposta`, `relay`) |
| Web `/giris/oauth` → `sessionStorage` | **DÜŞÜRÜYORDU** — yalnız `ad` taşınıyordu |
| Mobil `AuthState` | **DÜŞÜRÜYORDU** — `oauthAd` vardı, `oauthEposta` yoktu |

Yani sunucu biliyordu, istemciye geçmiyordu. Üç sağlayıcı için de aynı;
fark yalnız Apple'ın adresi **yalnız ilk yetkilendirmede** vermesi.

### Karar: alan SALT OKUNUR

Sunucu adresi **her SSO yolunda** imzalı `baglama_jetonu`nun içinden
okuyor:
- `kayit.py::tesis_olustur` → `eposta = kimlik["eposta"]`
- `oauth.py::rol_tamamla` → `eposta = kimlik.get("eposta")`

İstemcinin yolladığı bir değer **hiçbir yerde kullanılmıyor**. Web'de
alan düzenlenebilirdi ve `required` idi: kullanıcı bir adres yazıyor,
o adres **sessizce yok sayılıyordu**. Düzenlenebilir bırakmak bu sessiz
sapmayı sürdürmek olurdu.

İkinci gerekçe P180: elle yazılan adres **doğrulanmamış** olurdu ve
doğrulanmamış e-posta ile allowlist eşleşmesi hesap ele geçirmedir.

Mevcut kurallar korundu ve bu turda **hiç değiştirilmedi**:
`email_verified=true` → OTP yok; `false` → OTP; doğrulanmamış adresle
allowlist eşleşmesi yok.

**Apple private relay** adresleri de otomatik doluyor (P180 kararı:
Apple'ın kontrolünde, doğrulanmış sayılır) — ayrıca "bu adrese posta
gönderilemez" notu gösteriliyor, çünkü kullanıcı bunu kaydolmadan önce
bilmeli.

### Apple e-posta vermezse

Kullanıcı kaydı yarıda bırakıp tekrar denerse Apple adresi **vermez** ve
sunucu bu yolu `eposta_gerekli` (422) ile reddeder — e-postasız bir
yönetici hesabı daveti alamaz, parolasını sıfırlayamaz, silemez.

Boş ve salt okunur bir alanla kullanıcıyı çıkışsız bırakmak yerine
**sebep söyleniyor** ve iki çıkış sunuluyor: e-posta ile kaydol, ya da
Apple ayarlarından uygulamanın iznini kaldırıp yeniden dene (izin
kalkınca Apple adresi tekrar paylaşır).

### Yüzey farkı — açıkça

- **Web**: yönetici self-signup var; alan salt okunur, dolu gelir.
- **Mobil**: yönetici self-signup **YOK** (`KayitRolu` = sakin /
  güvenlik / tesis görevlisi) ve SSO yolunda e-posta zaten hiç
  sorulmuyordu. Eklenen şey: **bağlanan hesabın adresi gösteriliyor**.
  İki Google hesabı olan biri, yanlış olanla kaydolduğunu eskiden ancak
  iş işlerken anlıyordu.

---

## Ölçmediklerim

- Gerçek Google/Microsoft/Apple sunucularına karşı uçtan uca akış
  sürülmedi; taklit **HTTP adapter katmanında** (P200 dersi), yani
  gövdeyi çözen katman testten geçiyor. Sağlayıcının gerçekten hangi
  iddiaları döndüğü `oauth.py`nin mevcut davranışına dayanıyor.
- Cihazda çalıştırma yapılmadı.
