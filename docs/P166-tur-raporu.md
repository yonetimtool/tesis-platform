# P166 — tur raporu

Brief on maddelik geldi. **§3, §4 ve §5 bu tur açılmadan önce zaten
kapanmıştı** (P163–P165 commit'leri); ölçüldü ve doğrulandı, aşağıda
"önceden kapalı" olarak işaretli. Kalan yedi madde bu turda yapıldı.

| Madde | Durum | Commit |
|---|---|---|
| §1 Sol menü — "Daha fazla" kalktı | yapıldı | `2229e667` |
| §2 Global arama — sayfalar | yapıldı | `2229e667` |
| §3 Daireler sekmesi sadeleştirme | önceden kapalı (P163/P165) | `e84eacc7`, `ced6641b` |
| §4 Bina düzenleme — kat silme | önceden kapalı (P165) | `ced6641b`, `c60bf7f7` |
| §5 Rezervasyon — geçmiş ayrımı | önceden kapalı (P165) | `ced6641b`, `c60bf7f7` |
| §6 Marka adı + logo + ikon | yapıldı | `2b91f8a3` |
| §7 Tema ve kontrast | yapıldı | `591982ce` |
| §8 Kurulum sihirbazı | yapıldı | `939dd32b` |
| §9 Form kısıtları (telefon) | yapıldı | `f6b24cb8` |
| §10 Mobil gizli aksiyonlar | yapıldı | `9574201b` |

---

## 1. "yönetio" → "yönetiyor": değişen ve dokunulmayan yerler

**Ayrım kuralı:** diacritic taşıyan yazım (`Yönetio`/`yönetio`) kullanıcıya
görünen metindir; ASCII yazım (`Yonetio`/`yonetio`) teknik tanımlayıcıdır.
63 dosya değişti, 79 dosyada teknik tanımlayıcı **bilerek** korundu.

### Değiştirilenler
- **7 dil sözlüğü** (web `lib/i18n/sozluk/*`) ve **7 `.arb` + üretilen l10n** (mobil)
- **Sayfa başlığı** (`metaBaslik`, `metaAciklama`) — tarayıcı sekmesi
- **Giriş ekranı**, **kenar çubuğu logosu**, **davet** ve **kayıt** ekranları
- **Hukuki metinler**: gizlilik, kullanım koşulları, hesap silme
- **Tanıtım içeriği** ve tanıtım e-postası
- **Davet SMS/e-posta gövdesi** (`backend/app/davet.py`), telefon kodu mesajı
- **Android `android:label`**, **iOS `CFBundleDisplayName`** (uygulama adı)
- **Portal açılış sayfası** (`infra/portal/kok/index.html`)
- README'ler, MASTER-PLAN, App Store inceleme notları, RUNBOOK, codemagic iş akışı adı

**Türkçe ekler elle çözüldü** (kör bul-değiştir yanlış Türkçe üretirdi):

| eski | yeni | neden |
|---|---|---|
| Yönetio'ya | Yönetiyor'**a** | son ünlü "o" → ek "a" |
| Yönetio'yu | Yönetiyor'**u** | ünsüzle biter, kaynaştırma yok |
| Yönetio'nun | Yönetiyor'**un** | aynı |
| Yönetio's | Yönetiyor's | İngilizce iyelik (gizlilik metni) |

### Bilerek dokunulmayanlar
- **Alan adları:** `yonetio.site`, `yonetio.app` ve tüm alt alanlar
  (`api.`, `panel.`, `storage.`, `app-test.` …). Değiştirmek DNS, TLS ve her
  istemcinin taban adresini kırardı.
- **Paket/uygulama kimliği**, veritabanı ve konteyner adları
  (`yonetio-prod`, `yonetio-test`), sunucu yolu `/opt/yonetio`
- **Kod tanımlayıcıları:** `YonetioLogo.tsx`, `yonetio_logo.dart`,
  `YonetioColors`, `YonetioSimpleMarkPainter`, `YonetioWordmark`
- **Depolama anahtarları:** `yonetio.menu.*`, `yonetio.rememberMe.*`,
  `yonetio.oauth.*` — değiştirmek herkesin tercihini sıfırlardı
- **HTTP başlığı** `X-Yonetio-Timestamp`, Android renk adları (`yonetio_navy`),
  bildirim ikonu `ic_stat_yonetio`, varsayılan tenant slug'ı, CSV şablon dosya adı
- **Tarihli kayıtlar:** `P155r2-tur-raporu`, logo tasarım spec'i, çeviri teslim
  CSV'leri, kapalı-test sürüm notları — geçmişi yeniden yazmak onu kayıt
  olmaktan çıkarır

**PWA manifest yok:** brief listede sayıyor ama depoda manifest dosyası
bulunmuyor (Next `app/icon.png`'i kendisi bağlıyor). Uydurulmadı.

### Logo (§6.2) ve uygulama ikonu (§6.3)
Koyu temada işaret **kayboluyordu**: opak piksel ortalaması RGB (27, 65, 124).
Çözüm depoda zaten vardı — `yonetio-logo-acik.png` (ters varyant, ortalama
RGB (190, 201, 218)) P162'de üretilmiş, hiç kullanılmamıştı. Bağlandı.
Boyut 28→34 (kenar çubuğu 26→32, davet/kayıt 32→40).

**Uygulama ikonu neden değişmemişti:** `generate_branding_assets.dart`
**çalışmıyordu**. İki kök neden:
1. P162'de `logo_master.png` kare tuval olmaktan çıkıp 637×170 yatay banner
   olmuş; araç ondan kare kırpma çıkarmaya çalışıp `clamp(0.0, negatif)`
   fırlatıyordu.
2. İşaret çıkarma ölçütü "beyazlık"tı (eski logo gradyan üzerinde beyazdı);
   yeni marka şeffaf zeminde koyu lacivert — hiçbir piksel bulunmuyordu.
   Ölçüt **alfa**ya çevrildi: şeffaf zeminli bir varlıkta siluet zaten
   alfa kanalıdır.

Üretilenler: adaptive fg/bg, Android `ic_launcher` beş yoğunluk,
`ic_launcher_foreground` beş yoğunluk, `splash_logo` beş yoğunluk, bildirim
ikonu, iOS AppIcon tüm boyutlar. **Build numarasına dokunulmadı** (`1.0.0+2`).

---

## 2. Kat silme davranış kararı (§4 — P165'te alınmıştı)

Ölçüm önce: `unit` tablosuna **15 tablo** bağlı ve silme `ON DELETE CASCADE`.
Bir katı silmek daireleri değil **sakinleri, tahakkukları, tahsilatları,
talepleri ve rezervasyonları** da götürüyor.

**Üç kademe:**
- **Boş kat** (daire yok): tek onay. Kaybedilecek bir şey yok. Uç 404 değil
  **sıfırlarla** döner — kullanıcı henüz daire eklenmemiş bir kat görüyor olabilir.
- **Daireli, mali kayıtsız:** somut özet gösterilir ("2 daire · 3 sakin ·
  1 açık şikâyet"), tek onay.
- **Mali kayıt varsa** (tahakkuk/tahsilat): ayrı kırmızı uyarı + **ikinci kapı** —
  "Sil" düğmesi, kullanıcı kat numarasını yazana kadar kapalı.

**Neden mali kayıt ayrı:** sakin ya da talep yeniden oluşturulabilir, bir
**tahsilat kaydı oluşturulamaz**. Silmek denetimde açıklanamayan bir boşluk
bırakır. İşlev kaldırılmadı; yalnızca kazayla olması engellendi.

Özet ayrı bir uçtan gelir (`GET /units/kat-onizleme`, **sayar, silmez**):
`POST /units/kat-sil` zaten `cascade=false` iken 409 dönüyordu ama o yanıt
ancak kullanıcı **silmeye bastıktan sonra** görünür. Hata yolunu bilgi yolu
olarak kullanmak, kullanıcıyı önce denemeye zorlamaktı.

---

## 3. Rezervasyon saklama önerisi (§5 — P165'te uygulandı)

İstek: "10 rezervasyon sonrasında en eski 1 kayıt **silinsin**."
**Üç noktada değiştirildi ve gerekçesi:**

1. **Sayı değil süre.** Sayı bazlı saklama öngörülemez: haftada iki kez
   ayırtan sakin on kaydı beş haftada doldurup **geçen ayınkini** kaybeder;
   yılda bir ayırtan on yıl öncesini taşır. Aynı kural iki kullanıcıya zıt
   davranır. "Son 12 ay" herkes için aynı anlama gelir.
2. **Kalıcı silme değil gizleme.** Rezervasyon bir **kullanım kaydıdır**:
   ortak alanda hasar çıkarsa, iki sakin aynı gün için anlaşmazlığa düşerse
   ya da bir iptalin kimin yaptığı sorulursa (`iptal_eden_user_id` satırda
   duruyor) **kanıttır**. Veri kalır, liste kısalır. Brief "arşivleme/gizleme
   seçersen doğrudan uygula" dediği için onay sorulmadan uygulandı.
3. **Tesis başına değil kayıt yaşına göre.** "Tesis başına 10" 50 daireli bir
   sitede bir haftada dolardı. Yaş ölçüsü tesis büyüklüğünden bağımsız.

Göç 0054: `tenant.rezervasyon_gecmis_ay` (NOT NULL DEFAULT 12, CHECK 0..120).
**`0 = sınırsız`** — ayar bir politikayı zorlamamalı. Panelden yönetici
değiştirebilir.

---

## 4. Sihirbazdaki bağımlılık çıkmazlarının tam listesi (§8.3)

Sekiz adımın hepsi tek tek gezildi. **İki gerçek çıkmaz** bulundu.

### ÇIKMAZ 1 — "Görev alanları": web'de kategori oluşturma ekranı yoktu ✅ kapandı
Adımın sunucudaki ölçüsü `TaskCategory` sayısı. Sihirbaz `/tasks`e
yolluyordu; o sayfa kategorileri **yalnız okuyor**. Kategori sadece mobilde
açılabiliyordu — kullanıcı "önce bir kategori atamalısınız" uyarısıyla
karşılaşıp yapacak bir şey bulamıyordu.

**Kapatma:** `/tanimlar`a yeni defter (`gorev-kategorileri`) + menü girişi;
sihirbazın hedefi bu ekrana çevrildi.

**Yan bulgu:** backend'de `/task-categories` için **PATCH yoktu**
(POST/GET/DELETE vardı). Liste/form deseni "Düzenle" sunuyor, sunucuda
karşılığı yok — "Kaydet" 405 dönerdi. PATCH eklendi; iki gerçek ihtiyacı
karşılıyor: ad düzeltme (sil-yeniden-oluştur, kategoriyi kullanan görevleri
pasif bir kategoriye bağlardı) ve soft-delete'i **geri alma** (DELETE
`aktif=false` yapıyordu, tersi yoktu).

### ÇIKMAZ 2 — "Aidat": adım admin-only, sihirbaz yöneticiye açık ⚠️ işaretlendi
`POST /dues/assessments` **yalnız admin** (`rol-matrisi.txt`: yonetici RED),
ama sihirbaz admin+yönetici'ye görünüyor. Bir yönetici "Git"e basıp `/dues`a
gidiyor ve toplu tahakkuk düğmesinde **403** alıyordu.

**Yetki kuralı değiştirilmedi:** bir yöneticiye tüm daireler için borç yazma
yetkisi vermek bir politika kararıdır ve tek taraflı alınmaz. Yapılan şey
kullanıcıyı duvara **yollamamak**: adım "senin rolünle tamamlanamaz" diye
işaretlenir, düğme "Görüntüle"ye döner ve nedeni yazılır.

> **Karar sende:** yönetici toplu tahakkuk yapabilmeli mi? Cevap "evet" ise
> `rol-matrisi.txt` + `dues.py` tek satırla açılır.

### Temiz çıkan altı adım (iddia değil, ölçüm)
| Adım | Hedef | Gerçek oluşturma yolu |
|---|---|---|
| blok | `/building-editor` | `POST /api/blocks` ✓ |
| daire | `/building-editor` | `POST /api/units/bulk` ✓ (P163'te oraya taşınmıştı) |
| daire_tipi | `/tanimlar?defter=unit-tipleri` | defter CRUD ✓ |
| sakin | `/users` | `POST` ✓ |
| personel | `/tanimlar?defter=personel-kayitlari` | defter CRUD ✓ |
| nfc_noktasi | `/checkpoints` | `POST /api/checkpoints` ✓ |

### Mobil tarafta bilinen boşluk
`aidat` adımının **mobilde ekranı yok** (uç zaten admin-only). Çalışmayacak
bir düğme çizmek yerine nedeni yazılıyor. Mobil toplu tahakkuk ekranı **ayrı
bir iş** olarak duruyor.

---

## 5. Mobildeki gizli aksiyonlar ve seçilen çözüm (§10)

40 ekranın app bar aksiyonları tek tek geçildi. Kusur "sağ üstte küçük simge"
olmaktan çok **tek girişin o simge olmasıydı**. Üç sınıf çıktı.

### A — Yalnız ikonla ulaşılan ekranlar (gerçek kusur, düzeltildi)
| Ne | Eski tek giriş | Çözüm |
|---|---|---|
| Görev kategorileri | "Görev yönetimi" sağ üstü | ana ekran menüsüne **kendi kartı** |
| Plaka okumaları (ANPR) | "Araç Geçişleri" sağ üstü | menü girişi (görünürlük `aracGecis`ten türedi) |
| Yapısal araçlar (kat sil, toplu daire, sıralama) | bina düzenleme sağ üstü | **gövdeye etiketli giriş** |
| Tüm dairelere izin iste | izin ekranı sağ üstü | **etiketli açılır menü öğesi** |

### B — İkon kaldı, giriş başka yerde var (dokunulmadı)
Devriye planları ve kontrol noktaları: P154'te menü girişleri açılmıştı; app
bar ikonları bağlam içi **kısayol** olarak duruyor. Bir özelliğin iki yolu
olması kusur değil; **tek** yolunun gizli olması kusurdu.

### C — `Icons.refresh` (18 ekran, dokunulmadı)
Hiçbir yetenek yalnızca ona bağlı değil: her liste `RefreshIndicator` ile
aşağı çekilerek de yenileniyor. Etiketlemek 18 app bar'ı şişirir ve hiçbir
bulunabilirlik sorunu çözmez.

### Boş durumda çağrı düğmesi
Depoda **beş ayrı** `_Empty`/`_EmptyState` sınıfı vardı; beşi de aynı şeyi
çiziyor ve beşinde de aynı şey eksikti: **bir sonraki adım**. Ortak
`core/ui/bos_durum.dart` yazıldı (ikon + başlık + açıklama + çağrı düğmesi),
kontrol noktaları / devriye planları / personel / sakinler ekranlarına bağlandı.

**Neden boş durum, "FAB'i büyüt" değil:** liste yokken göz ekranın
**ortasındadır**.

**Bir metin kısaldı:** "Henüz kontrol noktası yok. **Sağ alttan** NFC noktası
ekleyin." → "Henüz kontrol noktası yok." Bir düğmenin yerini yazıyla tarif
etmek zorunda kalmak, o düğmenin bulunamadığının itirafıdır.

### İki denemem testlerce çürütüldü — ve haklıydılar
1. **Etiketi app bar'a yazmak:** 320dp dar-ekran testi hem bina düzenlemede
   hem izin ekranında **taşma** yakaladı (43 piksel). Çözüm ekrana göre
   ayrıldı: biri gövdeye, biri açılır menüye.
2. **Alt sayfa:** `merkez_diyalog_test` (P22a: "tüm açılır pencereler ortadan
   açılsın") onu durdurdu. `merkezSayfaAc`a çevrildi.

---

## 6. Test sunucusunda ne göreceksin

### Sol menü (§1)
- "Daha fazla / Daha az" satırı **yok**. Güvenlik, Tesis, Finans, Para
  Hareketleri, İcra, İletişim, Tanımlar, Yönetim, Platform — hepsi açık.
- Liste uzunsa menü **kaydırılıyor** (gizleme yok).
- Grup başlıklarına tıklayarak yine kapatabilirsin; karar kaydediliyor.
- Eski tarayıcı kaydın **etkisiz** (anahtar sürümlendi) — ilk açılışta hepsi açık gelir.

### Arama (§2)
- Üst bardaki kutuya "aidat" yaz → **Sayfalar** başlığı altında "Aidat" çıkar,
  tıklayınca `/dues`a gider. "devriye" → Devriye Planları. "gelirler" →
  `/finans?tip=gelir` (süzgeç dahil).
- Aksansız yazım da bulur ("guvenlik" → Güvenlik).
- Ctrl+K paletinde de aynı grup var, ok tuşları sayfalar ve kayıtlar arasında
  kesintisiz geziyor.
- Sakin hesabıyla gir: "kullanıcı", "denetim", "kvkk" **sonuç vermez**.

### Tema (§7)
- **Açık temada sol menü mavi** (`#d8e4f5`) — beyaz değil, içerikten ayrışıyor.
- Kartlar zeminden **görünür şekilde** yükseliyor (oran 1.03 → 1.13).
- Koyu tema **bir kademe açıldı** (zemin `#2A333B` → `#313A44`); üç katman
  artık ayırt ediliyor.
- Mobilde de aynısı: açık zemin `#EAEEF5`, koyu zemin `#1B222C`, koyu kart `#262E3A`.
- Bildirim rozeti koyu temada açık kırmızı + koyu metin (WCAG için).

### Marka (§6)
- Her yerde **Yönetiyor**. Kenar çubuğu logosu büyüdü; koyu temaya geçince
  işaret **açık varyanta** dönüyor.
- Telefonda uygulama ikonu **yeni logo** (Android + iOS). Sürüm numarası aynı.

### Kurulum sihirbazı (§8)
- Web'de yönetici olarak ilk girişte **modal** çıkıyor ("3/8 adım"), "Daha
  sonra" ile kapanıyor, Ayarlar → "Kurulum sihirbazını tekrar göster" ile geri geliyor.
- **Mobilde de aynısı**: ilk girişte pop-up, Ayarlar'da satır (dokun = aç,
  yenile ikonu = hatırlatıcıyı geri getir), ana ekranda "Tüm Modüller" kartı.
- Web'de **Tanımlar → Görev kategorileri** açıldı; ekle/düzenle/pasifleştir çalışıyor.
- Yönetici hesabıyla bak: "Aidat" adımı "Görüntüle" der ve yanında
  "yalnızca platform yöneticisi tamamlayabilir" notu vardır.

### Telefon (§9)
- Tanımlar → Personel → yeni kayıt: telefon alanı `0543 199 29 04` biçiminde
  gruplanıyor, **10 haneden fazlası girilemiyor**, alandan çıkınca eksik/sabit
  hat için alan bazında hata çıkıyor.
- Aynısı kullanıcılar, tesis detayı, tesis listesi, dış hizmetler ve profilde.
- Mobilde personel/sakin formlarında yarım numara artık **kaydedilmiyor**.

### Gizli aksiyonlar (§10)
- Mobilde bina düzenlemede **"Yapısal araçlar"** yazılı bir düğme var (gövdede).
- Kontrol noktaları boşken ortada **"Nokta ekle"** düğmesi ve "NFC etiketleridir"
  açıklaması çıkıyor.
- Ana ekran "Tüm Modüller"de **Görev kategorileri**, **Kurulum Sihirbazı** ve
  (güvenlik amirinde) **Plaka okumaları** kartları var.

---

## 7. Ölçüm

| Alan | Sonuç |
|---|---|
| web | **1174 test yeşil**, `tsc` temiz, `next lint` temiz, `next build` geçti |
| mobil | **1897 test yeşil** (3 atlandı), `flutter analyze` temiz¹ |
| backend | kategori 6 · yetki+sözleşme+kurulum 166 yeşil |

¹ İki `unused_import` uyarısı bu turda **dokunulmayan** test dosyalarında ve
öncesinde de vardı.

**Yeni testler:** `sayfa-aramasi` (11 — yetki sızıntısı alt-küme kilidi
dahil), `telefon-alani.dom` (10), `menu-katlama` (12, yeniden yazıldı),
`kurulum_sihirbazi_test` (7), `gizli_aksiyon_test` (5), kontrast kademe
kilitleri (9), backend kategori PATCH (2).
