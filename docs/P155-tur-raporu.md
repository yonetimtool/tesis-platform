# P155 — Kayıt akışı + davet bağlantısı + derin bağlantı

> Dal: `main` · P154'ün üzerine · Canlıya deploy yok, build numarasına
> dokunulmadı · Test sunucusunda doğrulanacak (`api-test.yonetio.site`).

Şartname 8 bölümdü. Bu tur **davet + derin bağlantı çekirdeğini uçtan uca**
kapattı (§6, §7, §8) ve §2'nin sosyal-SMS-yok + ad-prefill davranışını
**davet yolunda** getirdi. Elle-kayıt yedek yolunun yeniden sıralaması ve
§3 yönetici self-signup **aşamalandı** (gerekçe §9).

---

## 1. ÖLÇÜM (şartname ↔ mevcut kod)

| § | Madde | Ölçüm | Sonuç |
|---|---|---|---|
| 1 | İlk açılış rol seçimi | P154'te vardı | ✅ değişmedi |
| 2a | Yöntem adımı | P154'te vardı | ✅ |
| 2b | Sosyal: ad dolu, telefon boş | Kayıtta ad toplanmıyordu | ✅ **davet yolunda** (ad daireden türeyip prefill) |
| 2c | Sosyal dalda **SMS yok** | Elle-kayıt sosyal SMS gönderiyordu | ✅ **davet yolunda** · ⏸ elle-kayıt yedeği aşamalı |
| 3 | Yönetici tesis oluşturma + "zaten sitem var" | `POST /auth/signup` kaldırılmış | ⏸ **aşamalı** (§9) |
| 4 | Elle kayıt yedek yol | P154 `rol-basla` var | ✅ (sıra/SMS §2 ile birlikte aşamalı) |
| 5 | Sonraki girişler | P154 | ✅ |
| 6 | Panel tesis kodu görünürlüğü | UUID gösteriyordu | ✅ **düzeltildi** |
| 7 | Davet gönderimi (jeton, SMS+e-posta, kayıt, panel) | Yoktu (gönderim katmanı vardı) | ✅ **yapıldı** |
| 8 | Derin bağlantı (well-known, Caddy, links, web yedek) | Yoktu | ✅ **yapıldı** (native config + mobil ekran + web yedek) |

**Özet: §6, §7, §8 tam; §2 davet yolunda tam; §2 elle-kayıt + §3 aşamalı.**

---

## 2. §6 — Tesis kodu panelde birincil

Panel "Tesisler" listesi Kimlik sütununda tenant **UUID**'sini gösteriyordu
(`18d9fb6c-…`); yöneticinin ileteceği `kayit_kodu` (`OLTU-260715`) hiç
görünmüyordu.

- **Göç 0050:** `list_all_tenants` + `tenant_detail` fonksiyonları
  `kayit_kodu` döndürüyor. Dönüş tipi değiştiği için `CREATE OR REPLACE`
  değil **DROP + CREATE** (PostgreSQL donüş tipini değiştirmeye izin vermez).
- Panel liste + detay artık `kayit_kodu`yu **birincil + kopyalanabilir**
  gösteriyor (yeni `KopyaKod` bileşeni); UUID küçük teknik alan olarak kalır.

## 3. §7 — Davet jetonu

**Akış:** yönetici sakin/personel ekler → o (parolasız) hesaba jetonlu bağ
SMS (+varsa e-posta) ile gider → `https://<portal>/davet/‹jeton›` → jeton
çözülünce tesis/rol/daire/telefon bellidir → kullanıcı yalnız yöntem seçer.

- **Göç 0051:** `davet` tablosu (RLS) + public çözüm fonksiyonu
  `davet_coz` (SECURITY DEFINER; kullanıcının henüz oturumu yok).
- **Jeton düz metin SAKLANMAZ** — `sha256` hash'i saklanır; düz jeton yalnız
  bağda ve bir kez üretilir (parola hash'i ile aynı ilke). Tesis kodu/daire
  URL'de **taşınmaz** — hepsi jetonun arkasında.
- **Kullanıcı başına tek davet** (`uq_davet_user`): yeniden gönderim aynı
  satırı tazeler (yeni jeton, eski bağ ölür) → panel hep güncel durumu
  gösterir.
- **Uçlar:** `POST /davet/coz` · `/davet/parola` · `/davet/sosyal` (public)
  + `GET /davet` · `POST /davet/{user_id}/yeniden` (yönetici).
- **SMS YOK** (parola VE sosyal): jeton, yöneticinin bu kişiyi eklediğinin
  kanıtıdır; sosyal sağlayıcı kimliği kanıtlar. İkisi SMS'in yerini tutar.
- **Süre 30 gün** (karar): ilk SMS'i haftalarca göz ardı edeni kurtaracak
  kadar uzun, sızmış bir bağ sonsuza yaşamayacak kadar kısa; yönetici
  yeniden göndererek taze jeton üretir.
- **Sağlayıcı yokken sessiz başarısızlık YOK:** gönderim katmanı
  `YapilandirilmamisSaglayici` ile `gonderildi=false` döner (istisna
  fırlatmaz); sakin/personel ekleme yanıtı bunu taşır, panel gösterir.

**Panel `/davetler` (web):** yönetici gitmeyen daveti görür, **yeniden
gönderir**, sağlayıcı yokken **tesis kodunu kopyalayıp** elle iletir (kişi
§4 yedek yoluyla kaydolur).

## 4. §8 — Derin bağlantı

- **Well-known dosyaları:** `infra/portal/.well-known/apple-app-site-
  association` + `assetlinks.json` (Team ID / SHA256 yer tutuculu). Caddy
  onları portal kökünde `application/json` ile **yönlendirmesiz** servis
  eder (`(wellknown)` snippet'i). Test ve prod **aynı dosyaları** kullanır;
  yalnız alan adı Caddy env değişkeninden gelir.
- **Mobil native config:** iOS Associated Domains entitlement +
  `FlutterDeepLinkingEnabled`; Android `autoVerify` intent-filter (üç alan,
  `/davet` öneki) + `flutter_deeplinking_enabled`. **Ek paket yok** —
  Flutter'ın yerleşik deep-link'i gelen yolu (`/davet/‹jeton›`) go_router'a
  verir.
- **Mobil davet ekranı** (`DavetScreen`): jeton çözer, yöntem sectirir
  (parola/sosyal, SMS yok), gecersiz/süresi dolmuş jetonda doğru metin.
- **Web yedeği** (`/davet/‹jeton›`): tarayıcıda kayıt tamamlanır +
  platforma göre mağaza düğmeleri.
- **Ertelenmiş derin bağlantı kararı:** üçüncü taraf servis (Branch/Firebase
  Dynamic Links) **eklenmedi** — şartname ondan kaçınmayı istedi ve
  ikisi de ek bağımlılık + gizlilik yüzeyidir. Bunun yerine: kurulu değilse
  web yedeği + mağaza düğmesi gösterilir; kullanıcı mağazadan kurup
  **bağlantıya bir daha tıklar** (bağ SMS/e-postada durur). Pano-tabanlı
  eşleştirme de elendi: iOS pano erişimi artık kullanıcıya sorulur
  (rahatsız edici) ve güvenilmez. "Bir daha tıkla" en az sürprizli,
  bağımlılıksız yoldur.

> **App Store build 3 uyarısı (şartname §8):** prod uygulaması bu
> yetkilendirmelere sahip DEĞİL. Derin bağlantı ancak **yeni sürümle**
> çalışır; bu tur test ortamında doğrulanacak. Konsol işleri:
> `docs/derin-baglanti-kurulum.md`.

## 5. §2 — Sosyal dalda SMS yok + ad prefill (davet yolunda)

Davet yolunda sosyal yöntem **SMS göndermez** (`/davet/sosyal`); ad,
daireden türetilen değerle prefill gelir ve kullanıcı düzeltebilir. Bu,
şartname §2'nin sosyal davranışını davet (birincil) yolunda tam karşılar.

---

## 6. VERİLEN KARARLAR

1. **`app_user.ad` nullable YAPILMADI** (P154'te olduğu gibi): ad
   verilmezse daireden türetilir; davet çözümünde o ad prefill gelir.
2. **Jeton hash saklanır, düz metin değil** — sızma direnci.
3. **Kullanıcı başına tek davet, yeniden gönderim tazeler** — panel tutarlı.
4. **`mesaj_amac` enum'una `davet` EKLENMEDI** — `operasyonel` yeterli;
   enum değeri eklemek geri-alınamazdı (`goc-tersinirlik` kapısı).
5. **`portal_base_url` link tabanı** — test/prod tek ortam değişkeniyle;
   kod değişmez.
6. **Üçüncü taraf deep-link servisi yok** (§4 kararı yukarıda).

---

## 7. TESTLER

| Nerede | Ne |
|---|---|
| `test_davet.py` (11) | çözme (sakin daire / yönetici daire-yok / 404 / 410) · parola tamamlama + giriş · tek-kullanım · zayıf parola · **sakin eklemede davet gider** · parolalı hesaba davet yok · panel listele + yeniden gönder · rol kapısı |
| `test_yetki_matrisi` + `test_yetki_kapsam` | davet uçları matriste (public hepsi-İZİN; `GET /davet`+yeniden yalnız admin/yönetici) · kilit yeniden üretildi |
| `test_sozlesme_sapmasi` | davet yolları uygulama ↔ openapi örtüşüyor |
| `davet-web.dom.test.ts` (4) | çözme + parola + süresi-dolmuş + bulunamadı; jeton URL'de taşınmıyor |
| `davet_ekrani_test.dart` (4) | çözme + parola (jeton+parola+ad prefill) + yönetici daire-yok + süresi dolmuş |
| `rol-menusu.test.ts` | `/davetler` birincil uç + rol kümesi kilitle örtüşüyor |

**Sonuç:** backend tam takım (koşuyor), mobil **1858 ✓**, web **736 ✓**.

---

## 8. DEĞİŞEN DOSYALAR (özet)

- **Göç:** `0050_tesis_kodu_panelde`, `0051_davet_jetonu`.
- **Backend:** `davet.py` (servis) + `routers/davet.py` (uçlar) +
  `models.Davet` + şemalar + `residents/users` davet tetikleme + tenant
  fonksiyonları + `openapi.yaml` + `rol-matrisi.txt`.
- **Web:** `app/davet/[jeton]` (yedek sayfa) + `(protected)/davetler` (panel)
  + `KopyaKod` + `magaza.ts` + BFF davet rotaları + `SosyalGiris` davet
  jetonu + `/giris/oauth` davet tamamlama + tenant panel kayit_kodu + i18n×7.
- **Mobil:** `DavetScreen` + auth_api/repo/controller davet metotları +
  go_router `/davet/:jeton` + iOS entitlements/Info.plist + Android manifest
  + ARB×7.
- **Infra:** `Caddyfile` `(wellknown)` + `portal/.well-known/*`.
- **Docs:** `derin-baglanti-kurulum.md` (konsol işleri).

---

## 9. AŞAMALANAN İŞ (gerekçeyle)

Şartnamenin **primer** yolu davet bağlantısıdır (§7/§8) ve o uçtan uca
bitti. Aşağıdakiler **ayrılabilir** ve bu tura sığmadı; her biri için
gerekçe + sonraki adım:

### 9a. §2 elle-kayıt (YEDEK) yolunun sıra + sosyal-SMS-yok
- **Durum:** P154'te elle-kayıt sırası `rol → kimlik(tesis+telefon) →
  yöntem`; sosyal dal `oauth/baglan` ile **SMS gönderiyor**.
- **Gerekli:** sırayı `rol → yöntem → tesis` yap; sosyal seçilince
  `oauth/baglan`ı SMS'siz bir eşleşme ucuyla değiştir (tesis+telefon
  mevcut parolasız hesapla eşleşince doğrudan bağla).
- **Neden aşamalı:** bu, elle-kayıt sosyal yolunun **güvenlik modelini
  değiştirir** (SMS kanıtı kalkar; şartname bunu kabul ediyor ama tek
  başına bir backend ucu + mobil yeniden sıralama + testler ister) ve
  **birincil yol (davet) zaten SMS'siz ve tam**. Elle-kayıt, davet
  bağı olmadan gelenler için yedektir.

### 9b. §3 yönetici self-signup + "Zaten bir sitem var"
- **Durum:** `POST /auth/signup` geçmişte kaldırılmış; bugün tesis yalnız
  admin panelinden açılıp `setup_tenant` ile adlandırılıyor.
- **Gerekli:** public `POST /auth/signup` (tesis + ilk yönetici, kod üret,
  auto-login) + mobil "Tesis adını giriniz" ekranı + "Zaten bir sitem var"
  → tesis ID ile ikinci yönetici katılımı.
- **Neden aşamalı:** yeni bir **public tenant-yaratma yüzeyi**dir (IP hız
  sınırı, slug üretimi, kötüye kullanım yüzeyi) ve davet akışından
  bağımsızdır; kendi tasarım + test turunu hak eder. Yapı taşları hazır:
  `create_tenant_with_yonetici` SECURITY DEFINER fonksiyonu + kod
  tetikleyici + onboarding adlandırma ekranı deseni.
