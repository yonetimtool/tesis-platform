# /admin-web — Yonetim Paneli (Next.js)

Multi-tenant tesis operasyon SaaS yonetim paneli. **Next.js 14 (App Router) + TypeScript +
Tailwind**. Backend'e (FastAPI, `/contracts/openapi.yaml`) **BFF** deseniyle baglanir:
token'lar **httpOnly cookie**'de tutulur, istemci JS'i ASLA gormez.

> **Panel yalnizca `admin` (platform admini) icindir** (`contracts/auth.md` §4).
> Login'de BFF, access token'daki `role` claim'ine bakar; `admin` degilse
> **403** doner ve oturum cookie'si set edilmez — `yonetici` (site yoneticisi)
> dahil diger tum roller mobil uygulamayi kullanir. Bu UX kapisidir; gercek
> yetki her istekte backend RBAC'ta zorlanir.

## Kurulum

```bash
cd admin-web
cp .env.example .env.local      # gerekirse API adresini degistir
npm install
npm run dev                     # http://localhost:3000
# uretim derlemesi:
npm run build && npm run start
```

## Ortam degiskenleri

| Degisken | Aciklama | Varsayilan |
|----------|----------|------------|
| `NEXT_PUBLIC_API_BASE_URL` | Backend API koku (`/v0` ONEKI YOK) | `http://localhost:8000` |

- **Dev:** backend `http://localhost:8000` (asagidaki "Backend'i calistirma").
- **Prod:** `https://api.example.com` gibi gercek domain; panel ayni origin veya CORS'suz
  cunku istemci backend'e **dogrudan gitmez** — hep same-origin `/api/*` (BFF) cagrilir.

## Backend'i calistirma (panel bagimliligi)

Panel calisan bir backend ister. Repo kokunden:
```bash
cd infra && docker compose up -d --build
docker compose exec api python -m scripts.seed
```
Backend `http://localhost:8000`'de ayaga kalkar (194 test gecer). `/health` 200 doner.

## Test giris bilgisi (seed)

| Alan | Deger |
|------|-------|
| Tesis (slug) | `acme-plaza` |
| E-posta | `admin@acme.com` |
| Parola | `Admin123!` |

> Seed'deki diger hesaplar (`yonetici@acme.com`, `guard@acme.com`,
> `cleaner@acme.com`, `resident@acme.com`) panele GIREMEZ (403) — rol modeli
> geregi mobil hesaplaridir.

> Login formu `tenant_slug + email + password` alir (`/contracts` `LoginRequest`'e birebir).

## Mimari

```
app/
  login/page.tsx              giris formu (-> /api/auth/login)
  page.tsx                    "/" -> /dashboard
  (protected)/
    layout.tsx                Nav + duzen (oturum middleware'de korunur)
    dashboard/page.tsx        GET /dashboard/live (SWR, 15 sn polling)
    notifications/page.tsx    GET /notifications (filtre + sayfalama + okundu)
    announcements/page.tsx    duyurular (olustur/duzenle/sil; tum cihazlara push)
  api/                        BFF route handler'lari (backend'e proxy)
    auth/login, auth/logout
    dashboard/live
    notifications, notifications/[id]
lib/
  backend.ts                  proxyJson: access cookie + 401'de single-flight refresh + cookie rotasyonu
  cookies.ts                  httpOnly cookie isim/secenekleri
  fetcher.ts                  istemci SWR fetcher (401 -> /login)
  types.ts                    /contracts sema TS karsiliklari
middleware.ts                 korumali route'lar: oturum yoksa /login
components/Nav.tsx            ust menu + cikis
```

### Token guvenligi (neden httpOnly cookie + BFF)
- access/refresh **httpOnly + SameSite=Lax + (prod) Secure** cookie'de; XSS ile calinamaz.
- Istemci backend'i **dogrudan cagirmaz**; same-origin `/api/*` route handler'lari proxy'ler
  ve cookie'deki token'i Authorization header'ina koyar.
- **401 -> refresh:** `proxyJson` access 401 alinca `POST /auth/refresh` ile yeniler ve yeni
  cookie cifti yazar. Backend refresh **rotation** yaptigi icin es zamanli istekler
  **single-flight** ile tek yenilemeye indirgenir (reuse-revoke onlenir).
- refresh de olunce cookie'ler temizlenir, 401 doner; istemci/middleware `/login`'e yonlendirir.
- Korumali sayfalar: `middleware.ts` oturum (refresh cookie) yoksa `/login`'e ceker.

## Sayfalar

- **Canli Panel** (`/dashboard`): bugunku turlar (bekliyor/tamamlandi/kacirildi rozetli) +
  okutulan/beklenen sayilari + son alarmlar (`created_at DESC` — backend siralar).
  15 sn'de bir otomatik yenilenir.
- **Bildirimler** (`/notifications`): liste, okundu/okunmamis filtresi, sayfalama (limit/offset),
  `PATCH /notifications/{id}` ile okundu isaretleme.

## Coklu dil (i18n) — 7 dil + RTL

Panel tur 17'ye kadar **tek dilliydi**: `<html lang="tr">`, Turkce sabitler ve
BFF'te sabit `Accept-Language: tr`. Mobil uygulama (tur 1-13) ve backend
(tur 14-16) 7 dile gecmisti; panel geride kalan son parcaydi.

### Mimari

| Parca | Yer |
|---|---|
| Dil kumesi + cozumleme | `lib/i18n/diller.ts` (`DILLER`, `istekDili`, `acceptLanguageCoz`, `yon`) |
| Sozlukler | `lib/i18n/sozluk/{tr,en,ar,ru,de,fr,es}.ts` |
| Sozluk TIPI | `lib/i18n/sozluk/tipler.ts` — **`typeof tr`den turer** |
| Baglam + `t()` | `lib/i18n/kullan.tsx` (`I18nProvider`, `useT`) |
| Dil secici | `components/DilSecici.tsx` (kabukta + giris ekraninda) |
| Kilit | `tests/i18n.test.ts` (18 test) |

**KUTUPHANE YOK — bilincli.** Sozluk duz bir TS nesnesidir ve tipi kaynak
dilden (`tr`) turer: eksik ya da fazla anahtar **derleme hatasidir**
(`npx tsc --noEmit` eksik anahtarlari tek tek sayar). Bir i18n kutuphanesi bunu
calisma anina ("missing key" uyarisi) ertelerdi. Bu, mobil taraftaki
"`switch`in `default` dalini yazma, derleyici ceviriyi zorlasin" kuralinin
TypeScript karsiligidir.

### Dil nasil secilir

```
KULLANICI SECIMI (cookie `ui.locale`)  ->  tarayici `Accept-Language`  ->  tr
```

Secim **cookie**dedir, localStorage'da degil: sunucu bileseni ilk boyamada
`<html lang/dir>` icin, **BFF** ise backend'e gonderdigi `Accept-Language`
basligi icin ayni degeri okur. Yani **tek secim** hem paneli hem SUNUCU
metinlerini (hata mesajlari — tur 14, icerik cevirisi, bildirimler) ayni dile
getirir. localStorage olsaydi sunucu bileseni onu goremez, ilk kare yanlis
dilde boyanir ve backend Turkce hata donerdi.

### RTL

`<html dir>` sunucuda uretilir. Kabukta sabit yon siniflari yerine
**mantiksal** karsiliklari kullanilir: `start-`/`end-`, `ps-`/`pe-`,
`border-e`, `text-start`. Arapcada kenar cubugu saga gecer, mobil cekmece
sagdan girer (`rtl:translate-x-full` — Tailwind'in `-translate-x-full`u yon
farkindaligi TASIMAZ). `tests/i18n.test.ts` kabukta sabit `left-0`/`pl-64`/
`border-r` kalmadigini dogrular.

### Tamamlanan sayfalar

| Tur | Yuzey |
|---|---|
| 17 | kabuk (21 menu + cikis + mobil cekmece), giris ekrani, tema dugmesi, dil secici, sayfa ust verisi, rol adlari, BFF oturum-doldu mesaji |
| 18 | **denetim kaydi, canli panel, bildirimler, ayarlar, sikayet haritasi, vardiyalar, duyurular, NFC noktalari, seffaflik panosu** + `lib/client.ts`, `lib/fetcher.ts`, `ReportsTabs` |
| 19 | **devriye planlari, gorev gecmisi raporu, aidat tahsilat raporu, tur gecmisi raporu, daireler, aidat, destek** |
| 20 | **demirbas, kullanicilar, entegrasyonlar, gorevler, talepler, bina duzenleme, tesisler, tesis detayi, daire detayi** + `app/api/uploads` (BFF) — **PANEL TAMAMLANDI** |

Bir sayfa ancak **tamami** cevrildiginde listeye girer ve
`tests/i18n.test.ts`teki `CEVRILEN` dizisine eklenir — o dizideki dosyalarda
Turkce sabit kalmadigi her kosumda dogrulanir. Yarim cevrilmis sayfa listeye
GIRMEZ: "bitti" gorunup karisik dilde kalmasi, hic cevrilmemis olmasindan
daha kotudur.

### Tur 21 — paneli 7 dilde GOZLE SUR

Statik tarama kaynagi okur; **gozle surus** calisan panelin URETTIGI HTML'e
bakar. Otomatiklestirildi (`/tmp` degil, tekrarlanabilir olsun diye adimlar):

```bash
npx next build && npx next start -p 3113          # panel
curl -s -c c.txt -X POST localhost:3113/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"tenant_slug":"acme-plaza","email":"admin@acme.com","password":"Admin123!"}'
# 7 dil x 23 sayfa: her biri icin Cookie: ui.locale=<dil> ile cek ve
# cizilen METINDE (script/etiket ayiklanmis) su uce bak:
#   1) <html lang> ve dir dogru mu,
#   2) ham sozluk ANAHTARI sizmis mi (orn. "ortakKaydet" ekranda),
#   3) TR'ye OZGU harf (ğışĞİŞ) kalmis mi — marka kelimesi haric.
```

**Sonuc: 161 sayfa-dil kontrolu, 0 bulgu** (duzeltmelerden sonra).

> **NE BULDU — ve neden statik tarama goremedi.** Ilk kosum UC Turkce
> paragraf cikardi (`building-editor`, `announcements`, `complaints`).
> Sebep: o metinler **JSX icinde cok satirli DUZ METIN**tir — ne tirnak
> icindedir (literal taramasi gormez) ne de tek satirda `>...<` kalibina
> uyar. Yani tur 20'nin "sayac 3'e indi" olcumu YANILTICIYDI: tarama
> baktigi yerde dogruydu, sorun nereye bakmadigiydi. (Ayni sinif: tur 20'de
> `app/api` route handler'lari, tur 16'da `notify_opener`, tur 15'te
> `_REASON_ERRORS`.)

Tarama artik cok satirli JSX metnini de olcuyor. **Tur 22'de esik SIFIRA
indi** (`KALAN_ESIK = 0`): panelde — string literali, cok satirli JSX metni,
sablon dizesi, `confirm()`/`throw new Error()` metinleri dahil — Turkce
sabit KALMADI. Tek istisna `Yönetio` marka kelimesidir.

> **TUR 22'DE BULUNAN SON HATA — metne bakan kontrol akisi.** `tenants`
> sayfasi telefon cakismasini
> `/telefon|zaten kayitli|conflict/i.test(mesaj)` ile tespit ediyordu.
> Sunucu metni tur 14'te 7 dile cevrilince bu regex **Turkce disi her dilde
> sessizce calismaz** oldu: kullanici "Bu telefon zaten kayitli" yerine ham
> sunucu hatasini gorurdu. `lib/client.ts` artik `ApiHatasi` firlatiyor
> (`code` + `status` tasiyor) ve karar `err.code === "conflict"` ile
> veriliyor — mobil tur 11'de kapatilan hatanin panel karsiligi.

Gozle surusun ayrica dogruladigi: 7 dilin hepsinde `<html lang>` dogru,
Arapcada `dir="rtl"`, hicbir sayfada ham sozluk anahtari sizmiyor.

### Tur 18'de ogrenilen iki sey

**Modul duzeyinde `t()` cagrilamaz** — ve cagrilabilse bile YANLIS olurdu:
sabit bir haritada (`KATEGORI_LABEL`, `GUN_TIPI_OPTS`, `ROLE_OPTIONS`) metin
tutmak, dil degisiminde donmus metin birakir. Cozum her uc yerde ayni:
harita **anahtar** tutar, cozum cizim aninda yapilir
(`Record<string, SozlukAnahtari>` + `t(...)`).

**Ay adlari sozluge YAZILMADI.** `Intl.DateTimeFormat(dil, { month: "long" })`
7 dilin hepsini zaten biliyor; 12 ay x 7 dil elle yazmak hem gereksiz hem de
dillerin kendi kurallarini (orn. Rusca'da tamlayan hali) yeniden uydurmak
olurdu. Sozluge yalniz **uygulamaya ozgu** metinler girer.

### Tur 17'de cevrilen yuzey

Kabuk (21 menu ogesi + cikis + mobil cekmece), **giris ekrani** (dil secici
dahil — Turkce bilmeyen kullanici oturum acmadan once dilini secebilmeli),
tema dugmesi, sayfa ust verisi (`<title>`/description `generateMetadata` ile),
rol adlari (`lib/roles.ts` artik METIN degil **KIMLIK** tasir: `roleAnahtari`
+ `rolAdi(t, deger)`), BFF'in kendi urettigi oturum-doldu mesaji.

### Kalan is — modul modul (sonraki turlar)

Olcum (repo kokunden `admin-web/` icinde):

```bash
# 1) TR'ye ozgu karakter VEYA yaygin TR UI kelimesi
python3 - <<'EOF'
import re, pathlib
tr=set('çğıöşüÇĞİÖŞÜ')
kw=re.compile(r'\b(Yeni|Aktif|Bekliyor|Kayıt|Açık|Giriş|Sil|Kaydet|Ekle|Düzenle|Tamam|İptal|Vazgeç|Ara|Filtre)\b')
n=0
for f in list(pathlib.Path('app').rglob('*.tsx'))+list(pathlib.Path('components').rglob('*.tsx'))+list(pathlib.Path('lib').rglob('*.ts')):
    if 'i18n/sozluk' in str(f): continue
    body='\n'.join(l for l in f.read_text().split('\n') if not l.strip().startswith('//'))
    for m in re.finditer(r'"([^"\\\n]{2,})"|\'([^\'\\\n]{2,})\'|>([^<>{}\n]{2,})<', body):
        v=(m.group(1) or m.group(2) or m.group(3) or '').strip()
        if any(c in tr for c in v) or kw.search(v): n+=1
print(n)
EOF
```

| | Olcum 1 (diyakritik/kelime) | Dosya |
|---|---|---|
| Tur 17 oncesi | 473 | 35 |
| Tur 17 sonrasi (kabuk + giris) | 450 | 32 |
| Tur 18 sonrasi | 386 | 22 |
| Tur 19 sonrasi | 251 | 12 |
| **Tur 20 sonrasi** | **3** | **3** — ucu de MARKA kelimesi (`Yönetio`) |

> **IKINCI OLCUM ZORUNLUDUR.** Mobil §15'in en pahali dersi: birinci olcum
> yalnizca Turkce'ye ozgu karakter **veya** listedeki kelimeyi arar.
> `"Tamamlanan"`, `"Bekleyen"`, `"Toplam"` gibi metinler ikisini de tasimaz ve
> sayima **girmez** — nitekim `dashboard/page.tsx` birinci olcumde 7 string
> gosterirken ekranda bundan fazlasi Turkcedir. Bir sayfayi "bitti" ilan
> etmeden once UI konumundaki (`label=`, `title=`, `placeholder=`,
> `aria-label=`, `>metin<`) **tum** literalleri de taramak gerekir.

**KALAN SAYFA YOK.** Olcumdeki son 3 hit `Yönetio` marka kelimesidir
(`login`, `AppShell`, `YonetioLogo`) — bilincli istisna, cevrilmez.

Tur 20'den itibaren kaynak taramasi **dosya listesiyle degil TUM agacla**
calisir (`tests/i18n.test.ts` -> "PANELIN TAMAMINDA Turkce sabit kalmadi"):
Turkce sabitle eklenen YENI bir sayfa testi kirar. Iki muafiyet var ve ikisi
de gerekcelidir: sozlugun kendisi ve `lib/i18n/diller.ts` (dil adlari her
zaman kendi dilinde yazar).

> **TUR 20'DE BULUNAN KOR NOKTA:** onceki turlarin olcumu `app/**/*.tsx`,
> `components` ve `lib`e bakiyordu; **`app/api/**/*.ts` route handler'lari
> kapsam disindaydi. Tam agac taramasi `app/api/uploads/route.ts` icinde uc
> Turkce hata mesaji buldu — BFF'in KENDI urettigi, istemciye giden metinler.
> Ders: "tum kaynagi tara" derken dizin listesini elle yazmak, listeye
> girmeyen her yeri sessizce muaf tutar.

**Ayri bir alt is — TARIH BICIMI.** `lib/fetcher.ts` ve 5 sayfa tarihi
`toLocaleString("tr-TR")` ile bicimliyor: dil degisse de tarih Turkce
bicimde kalir (mobil tur 15'te ayni sinif hata `tarihBicimi(dil)` ile
kapanmisti). Toplam 42 cagri yeri; kendi turunu hak ediyor.
`lib/money.ts`in `tr-TR` kullanimi ise **DOGRUDUR** ve kalir: para politikasi
"TL + Turkce gruplama, arayuz dili ne olursa olsun" der (mobil README §15).

## Testler

```bash
npm test          # vitest run  (birim testleri)
npm run test:watch
npx tsc --noEmit  # tip denetimi
npm run lint      # ESLint (next/core-web-vitals)
npm run build     # prod derleme (tip + lint dahil)
```

**Kapsam (80 test, `tests/`):** saf mantik (`lib/`) + BFF cekirdegi
(`lib/backend.ts`) + oturum kapisi (`middleware.ts`). Ortam `node`; jsdom/Testing Library **yok** — React/sayfa
testleri bilincli olarak kapsam disi (ayri bir is). `window`a dokunan
modullerde (`fetcher`, `client`) global test icinde `vi.stubGlobal` ile
taklit edilir, aga cikilmaz.

| Dosya | Ne kilitleniyor |
|---|---|
| `money.test.ts` | TL↔kurus TAM SAYI aritmetigi, gecersiz girdi `null` (sessiz 0 degil), tr-TR bicim, gidis-donus |
| `roles.test.ts` | `auth.md` §4 aynasi: 5 bilinen rol, bilinmeyen rolde ham deger, `SAHA_ROLLERI` = yalniz security + tesis_gorevlisi |
| `cookies.test.ts` | isimler, sozlesme omurleri (15 dk / 30 gun), httpOnly + sameSite=lax, `secure` yalniz production |
| `fetcher.test.ts` | 401 → `/login` + firlat, sunucu hata mesajinin tasinmasi, zarf yoksa genel mesaj |
| `client.test.ts` | `Content-Type` yalniz govde varken, 204 → `undefined`, sayfali `fetchAllItems` (ayirici, ilerleme, **bos sayfada durma** = sonsuz dongu yok), idempotency anahtari |
| `backend.test.ts` | BFF: `Bearer` ekleme, `cache: no-store`, 204/`content-length: 0` govdesiz gecis, upstream durum kodu; **401 → refresh → tekrar dene + rotasyonu cookie'ye yaz**; refresh olurse 401 zarfi + cookie temizligi; 403 refresh TETIKLEMEZ; **tek-ucus** (es zamanli iki 401 → BIR refresh) |
| `middleware.test.ts` | oturum yok → `/login` (307, sorgu korunur), bos/yabanci cookie oturum sayilmaz, token GECERLILIGI burada denetlenmez; **matcher kapsami** |

`next/headers` sunucuya ozgudur; `backend.test.ts` onu `vi.mock` ile taklit
edip cookie kavanozunu test basina doldurur. **Neden onemli:** backend refresh'te
ROTATION yapar (eski token gecersizlesir) — es zamanli iki 401 iki ayri refresh
cagirirsa ikincisi "reuse" sayilip oturumu komple iptal ettirir; ayrica donen
yeni cift cookie'ye yazilmazsa kullanici bir sonraki istekte yine 401 alir
("rastgele atiliyorum"). Bu iki davranis artik testle kilitli.

**Yapisal matcher testi (onemli):** `middleware.test.ts` `app/(protected)`
agacini dosya sisteminden gezer ve her sayfanin `config.matcher`'da bir girisi
oldugunu dogrular; karsiligi olmayan gereksiz giris de olmamalidir. Bu test
yazilirken **7 sayfanin kapi disinda kaldigi** ortaya cikti (`audit`,
`complaints`, `integrations`, `schematic`, `support`, `tenants`,
`transparency`) — matcher'a eklendi. Yeni sayfa ekleyip matcher'a yazmayi
unutursan bu test kirmizi yanar.

## Notlar
- Backend ve sozlesme **degistirilmedi** (yalniz `/admin-web`).
- `npm run build` TypeScript + ESLint (`next/core-web-vitals`) kontrolunu calistirir.

## Güvenlik notu (bağımlılıklar)

- Next.js `14.2.5` → **`14.2.35`** yükseltildi (kritik güvenlik yamaları; App Router uyumlu, build sorunsuz).
- `npm audit` kalan uyarıları (Next/glob/minimatch/postcss) yalnızca **Next 16 / eslint-config-next 16 major** yükseltmesiyle kapanıyor (`npm audit fix --force`) — bu kırıcı bir değişiklik olduğundan **şimdilik uygulanmadı.**
- Kalan uyarıların çoğu ya **dev-only** araçlarda (eslint/glob/minimatch — production bundle'a girmez) ya da **kullanılmayan Next özelliklerinde** (next/image Optimizer, Pages Router i18n, beforeInteractive — panel bunları kullanmıyor; App Router + BFF deseni).
- Production öncesi plan: Next 15/16'ya kontrollü major geçiş ayrı bir görev olarak ele alınacak.
