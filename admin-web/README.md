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

### Tur 25 — DAR EKRAN surusu (gercek tarayici)

Tur 21 metni olcuyordu; bu YERLESIMI olcer. `tools/dar-ekran-surusu.mjs`
gercek Chromium'da **7 dil x 24 sayfa x 2 olcu (360/414 dp) = 336** kontrol
yapar ve her sayfada sorar:

1. `<html lang>` ve `dir` dogru mu,
2. **yatay tasma** var mi (`scrollWidth > clientWidth`),
3. viewport disina TASAN gorunur oge var mi — **kirpan ya da kaydirilan bir
   atasi olanlar haric** (tablolar ve dekoratif ogeler mesrudur).

```bash
npx next build && npx next start -p 3115
node tools/dar-ekran-surusu.mjs
```

**Sonuc: 336 kontrol, 0 bulgu** (duzeltmelerden sonra).

> **NE BULDU.** Iki gercek yerlesim hatasi — ikisi de **uzun ceviri + dar
> ekran**, mobil tur 24'teki 104x104 kutucugun web karsiligi:
>
> | Sayfa | Dil | Olcum | Sebep |
> |---|---|---|---|
> | `/reports/*` sekmeleri | `de` | **+84 px** (360 dp) | "Beitragseinzug / Rundgangsverlauf / Aufgabenverlauf" tek satira sigmiyor |
> | `/dues` filtre izgarasi | `ru` | **+23 px** (360 dp) | 4 sutunlu izgara + uzun Rusca etiketler |
>
> Sekmeler **sarmaz** (alt cizgi bozulur) — serit kendi icinde kaydirilir.
> Izgara dar ekranda 2 sutuna duser (`sm:`den itibaren 4).
>
### Tur 33 — KLAVYE surusu (odak sirasi + tuzak)

`tools/klavye-surusu.mjs` gercek Chromium'da **TAB'a basar**: 24 sayfa x
**tr (LTR) + ar (RTL)**. Klavye sirasi DOM sirasidir, dile gore degismez;
degisen RTL'de GORSEL siradir — asil risk `start/end` yerine `left/right`
kullanan bir yerlesimin sirayi tersine cevirmesidir. Bes sey olculur:
pozitif `tabindex`, ULASILABILIRLIK (her etkilesimli oge TAB ile
seciliyor mu), TUZAK, ODAK ISARETI (outline/ring), SIRA.

**Urunde 0 bulgu.** Ilk kosum 68 bulgu verdi ve **hepsi TARAMANIN kendi
hatasiydi** — bu turun asil urunu duzeltilmis dedektordur:

| Yanlis alarm | Kok neden | Duzeltme |
|---|---|---|
| 44x `SIRA` | odaklanan oge kendini gorunume KAYDIRIR; gezinti sirasinda alinan dikdortgenler kiyaslanamaz (kenar cubugu 755 → 701 "geri zipliyor" gorunuyordu) | konumlar TAB'dan ONCE, tek seferde olculur |
| `SIRA` (kalan) | yan yana kartlar / "solda icerik sagda eylemler" duzeni — izgarada yukari zipmak DOGRU okuma sirasi | satir ekseninde ilerleme (RTL'de ters) istisnasi |
| 22x `ULASILAMAZ` | `<input type="date">` ic bolumleri (gg/aa/yyyy) arasinda TAB ayni ogede kalir; "daha once gorulen oge" ile kesen dongu taramasi erken bitiyordu | dongu yalniz ILK ogeye donunce kapanir |
| 2x `TUZAK` | sabit 200 TAB tavani — `/tenants` seed'de **251** odaklanabilir oge tasiyor | tavan = sayfadaki oge sayisi + pay |
| 2x `FARE-YALNIZ` | `<label>` icindeki "Beni hatirla" metni — tiklaninca kendi onay kutusunu etkinlestirir, o da odaklanabilir | denetim tasiyan `<label>` icerigi haric |

> **DEDEKTOR SINAMASI (`DENEY=1`).** "0 bulgu" ancak tarama gercekten
> olcuyorsa bir sey ifade eder. Deney kipi sayfaya BILEREK bes hata enjekte
> eder (pozitif tabindex, fare-yalniz `div`, `outline:none`, TAB'i yutan
> dugme) ve besinin de yakalandigini dogrular; yakalanmazsa **cikis kodu 1**.
>
> Ilk sinamada **TUZAK yakalanamadi**: TAB'i yutup odagi kendinde tutan
> dugme, tarama acisindan "dongu ilk ogeye dondu" gibi gorunuyordu. Kural
> duzeltildi — dongu kapandi AMA ogelerin yarisina bile ugranmadiysa bu bir
> tuzaktir.

```bash
npx next build && npx next start -p 3127
KOK=http://localhost:3127 node tools/klavye-surusu.mjs
KOK=http://localhost:3127 DENEY=1 node tools/klavye-surusu.mjs   # dedektor sinamasi
```

### Tur 32 — KOYU TEMA surusu (7 dil x 24 sayfa x 2 tema)

Onceki dort surus (dil / dar ekran / yazi olcegi / ekran okuyucu) **hepsi
acik temada** kostu. Renk temaya, metin uzunlugu dile gore degisir; koyu
zeminde okunmayan bir metin digerlerinin hicbirinde gorunmez.

`tools/okuyucu-surusu.mjs` artik `TEMALAR = ['light','dark']` ekseniyle
kosar: **336 sayfa-dil-tema**. Tema ILK BOYAMADAN once kurulur
(`addInitScript` ile `localStorage.theme`, ayrica `colorScheme` baglami) —
`app/layout.tsx`teki satir-ici script `.dark` sinifini kendisi atar.

**144 -> 0.** Acik tema **0** ile geldi (tur 31'in sonucunu dogruladi);
bulgularin **tamami** koyu temadaydi ve **tek bir kok nedene** iniyordu:

| Bulgu | Sebep | Duzeltme |
|---|---|---|
| 138x + 6x `color-contrast` (24 sayfanin HEPSI) | `text-brand-tealInk` (**#0B7A79**) tur 30'da ACIK tema icin koyulastirilmis marka tonuydu; koyu zeminde ayni koyuluk tersine calisiyor — slate-900 kart uzerinde **2.5:1**. `globals.css` yalniz `.dark .text-brand-teal` icin override tasiyordu, `tealInk` icin YOKTU | `.dark .text-brand-tealInk / .border-brand-tealInk -> #2cc4b7` (globals.css'te, dark mode'un tek merkezinde) |

> Etkilenen ogeler her sayfada duruyordu: **etkin menu ogesi** (`AppShell`),
> rapor **sekmesi** (`ReportsTabs`), dil seciciteki **etkin dil**,
> `EmptyState` ikonu. Yani "bir sayfanin hatasi" degil, **kabugun** hatasi.
>
> **ZEMIN olarak kullanildigi yerler bilerek disarida** (`bg-brand-tealInk`
> + beyaz yazi): orada kontrast zaten AA tutuyor, tonu aydinlatmak onu
> BOZARDI. Duzeltme metin/kenarlik ile sinirli.

```bash
npx next build && npx next start -p 3126
KOK=http://localhost:3126 node tools/okuyucu-surusu.mjs
```

### Tur 31 — TARIH BICIMI dile duyarli

Tur 17'de bulunup ayri alt is olarak kayda gecmisti: panel 7 dile acildi ama
tarihler `toLocaleString("tr-TR")` ile SABITTI — Almanca arayuzde tarih TR
biciminde kaliyordu. Mobil tarafta ayni sinif hata tur 15'te kapanmisti.

`lib/tarih.ts`: `tarihSaatBicimi` / `tarihSaatUzun` / `tarihBicimi`. Dili
cookie'den okur (React DISI modullerde de calisir — `lib/i18n/metin.ts` ile
ayni desen). `formatDateTime` IMZASI KORUNDU: 12 cagri yeri degismeden dile
duyarli hale geldi.

**PARA BILINCLI OLARAK DISARIDA.** `lib/money.ts` ve seffaflik panosundaki
`tl()` hala `tr-TR` kullanir — politika "TL + Turkce gruplama, arayuz dili ne
olursa olsun" (mobil README §15). Bu, `tests/tarih.test.ts` icinde AYRICA
dogrulanir ki ileride "tutarlilik" adina yanlislikla degistirilmesin.

> **TESTIN BULDUGU ONCEDEN VAR OLAN HATA.** `toLocaleString` bozuk girdide
> ISTISNA ATMAZ, `"Invalid Date"` DONDURUR — eski `formatDateTime`in
> `try/catch`i bu yuzden hicbir sey yakalamiyordu ve gecersiz tarihler
> ekrana "Invalid Date" diye basiliyordu. Artik `Number.isNaN(getTime())`
> kontrolu ortak yardimcida; gecersiz girdi HAM degeriyle doner.

### Tur 30 — EKRAN OKUYUCU surusu (axe-core, WCAG 2.1 AA)

`tools/okuyucu-surusu.mjs` gercek Chromium'da **axe-core** kosar:
**7 dil x 24 sayfa = 168 sayfa-dil**. Iki sey birden olculur:

1. **axe denetimi** (wcag2a/2aa/21a/21aa) — etiketsiz dugme, kontrast,
   bozuk liste/landmark yapisi...
2. **erisilebilirlik METINLERI cevrilmis mi** — `aria-label`, `title`, `alt`
   EKRANDA GORUNMEZ; gorunen metin cevrilip bunlar Turkce kalabilir
   (mobil tur 29'da ayni sinif hata bulunmustu).

```bash
npx next build && npx next start -p 3123
node tools/okuyucu-surusu.mjs
```

**171 -> 23 -> 17 -> 7 -> 0.** (Dort tur olcum; her adimda duzeltip
YENIDEN kostum — "duzelttim" demeden once olcum tekrarlanir.)

| Bulgu | Sebep | Duzeltme |
|---|---|---|
| ~148x `color-contrast` | marka teali `#0E9594`: beyazla **3.66**, acik teal zeminde **3.25** (esik 4.5) | `tealInk #0B7A79` (**5.15** / **4.58**) — YALNIZ metin + dugme zemini; gradyan/kenarlik/odak halkasi marka tonunda kaldi |
| 11x `color-contrast` | sema hucrelerinde beyaz metin `bg-*-500` uzerinde (~2.1–2.5), kutucuklarda `slate-500`/`red-600` | zeminler `-600/-700`e; metinler `slate-700`/`red-700`. Yogunluk kodlamasi (yesil/sari/kirmizi) KORUNDU |
| 7x `definition-list` | `<dl>` icinde dt/dd tasimayan oge | ILK DENEME YETMEDI: `<p>`yi `<div>` yapmak da gecersiz — ciplak `div` de kabul edilmiyor. Oge listenin DISINA alindi. |
| 6x "TR sizinti" | `alt="Image for {seed basligi}"` | **YANLIS ALARM** — dedektore VERI allowlist'i (mobil `surusVerisi` emsali) |

> **OLCUM ARACININ KENDI HATASI (tur 28'in tekrari).** `/login` gonder
> dugmesi duzeltmeden SONRA da "kontrast 4.01" veriyordu. Tarayicida
> olctum: gercek zemin `#0B7A79` (5.15, gecer). axe `#2b8c8b` goruyordu —
> cunku **framer-motion giris animasyonu surerken** olcmustu; dugme yari
> saydamken zemin beyazla karisiyordu.
>
> Cozum rengi daha da koyultmak DEGIL: surus artik `reducedMotion:
> 'reduce'` ile kosuyor. Animasyon aninda biter, olcum dogru olur — ve bu
> zaten erisilebilirlik kullanicisinin GERCEK deneyimidir (uygulama
> `MotionConfig reducedMotion="user"` ile bunu onurlandiriyor).
>
> Iki turda iki kez ayni ders: **olcum aracina da hata payi birakin.**
> Tur 28'de dedektor `overflow:hidden`i kirpma saymiyordu; burada animasyon
> bitmeden olcuyordu. Ikisi de "gercek hata" gibi gorundu ve ancak
> tarayicida ELLE dogrulayinca ortaya cikti.

### Tur 28 — BUYUK YAZI surusu (kok yazi boyu)

Mobil tur 27'nin web karsiligi. Tarayicinin **varsayilan yazi boyu** ayari
(Chrome: Ayarlar > Gorunum) `rem` tabanli olculeri buyutur; Tailwind rem
kullandigi icin **metin de bosluk da** buyur. Surus artik dort olcu kosar:

| Olcu | Amac |
|---|---|
| 360 dp / 16 px | en dar telefon |
| 414 dp / 16 px | tipik telefon |
| **360 dp / 20 px** | dar ekran + buyuk yazi (en sert) |
| **1280 px / 24 px** | masaustu + cok buyuk yazi |

**7 dil x 24 sayfa x 4 olcu = 672 kontrol; duzeltmelerden sonra 0 bulgu.**

> **NE BULDU.** Uc bulgunun ucu de **360 dp / 20 px**te cikti — yani ne dar
> ekran ne buyuk yazi TEK BASINA yetiyor, kesisim gerekiyor:
>
> | Sayfa | Dil | Olcum | Sebep / cozum |
> |---|---|---|---|
> | `/notifications` | `tr` +9 px, `ru` **+79 px** | filtre dugmeleri tek satirda | `flex-wrap` (sekme degil dugme — sarmak dogru) |
> | `/login` | `de` +6 px | GRID OGESI min-content'in altina inemiyor | `min-w-0` (asagi bak) |
>
> **`/login` ILK DUZELTME YETMEDI — dogrulama surusu yakaladi.** Once
> semptomu hedefledim: `p-6` + `break-words` (uzun Almanca birlesik
> sozcuk). Surus tekrar kosunca tasma AYNEN duruyordu. Sebep daha derinde:
> `overflow-wrap: break-word` tasmayi onler ama **intrinsic min-content
> genisligini DUSURMEZ**; grid ogesi de varsayilan `min-width: auto` ile
> min-content'in ALTINA INMEZ. Yani kelimeyi kirmak degil, **ogenin
> kuculebilmesi** gerekiyordu -> `min-w-0`.
>
> Ders: tasmayi gormek yetmiyor, DOGRU KATMANI bulmak gerekiyor — ve bunu
> ancak olcumu TEKRARLAYARAK anlarsiniz. "Duzelttim" demeden once surusu
> yeniden kosturun.
>
> `ru`nun +79 px'i dikkat cekici: "Прочитанные/Непрочитанные" Turkce
> karsiliklarinin nerdeyse iki kati. **Uzun ceviri + buyuk punto carpim
> etkisi yapiyor** — biri tek basina sigan bir satir, ikisi birlikte
> sigmiyor. `1280 px / 24 px` olcusu ise HIC bulgu vermedi: sorun buyuk
> yazinin kendisi degil, DAR ALANLA carpimidir.

> **DEDEKTOR HATASI da kayda gecti:** ilk surum yalniz `overflow-x: auto|
> scroll` atalarini mesru sayiyordu; `hidden`/`clip` DE KIRPAR. Bu yuzden
> giris ekranindaki bilincli dekoratif orb'ler 7 dilde birden "tasma" diye
> raporlandi. Yanlis alarm ureten bir dedektor zamanla susturulur — olcut
> duzeltildi.

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
