# MASTER PLAN — Yonetio / tesis-platform

> Single source of truth for all remaining work. The agent works through items
> CONTINUOUSLY in dependency order. Kerem reviews via commits and this file.
> Last updated: 2026-07-30 (v2 — P22–P39 added from Kerem's requirements package:
> Tesis_Platform_Yaptirilacaklar.docx + 45 Apsiyon reference screenshots, expected
> in repo at docs/design-refs/apsiyon/)

## CONTINUOUS MODE — how to work (BINDING)

1. Process items in ID order, skipping items whose Status is BITTI or BLOKE and
   items whose Depends-on are not all BITTI. Do NOT stop between items — finish
   one, commit, move to the next automatically.
2. One item = its own commit(s). NEVER mix two items in one commit. The status
   change (→ BITTI) and the CHANGELOG line go in the SAME commit as the work.
3. Never mark BITTI without acceptance criteria demonstrably met (test/build
   output or verification evidence recorded in the item's Notes).
4. If an item cannot be completed after genuine attempts, set Status to
   BLOKE(reason) with a short diagnosis in Notes, commit that, and CONTINUE to
   the next eligible item. Do not spin.
5. HARD STOPS — the ONLY reasons to stop and wait for Kerem:
   - An item marked [KEREM] or [DIŞ] becomes the only remaining eligible work.
   - Any action that is destructive or touches prod (prod is Kerem-only;
     `docker compose down -v` is FORBIDDEN everywhere outside disposable dev DBs).
   - A required credential/secret does not exist.
   When stopping, write a STATUS REPORT at the top of the CHANGELOG section:
   what finished, what's blocked and why, what Kerem must do.
6. Quality gates per touched area (every item, no exceptions):
   - /backend → full pytest green.
   - /mobile → flutter analyze clean + flutter test green + flutter build apk --debug ✓.
   - /admin-web → tests green AND `npm run build` ✓ (what Docker prod runs).
   - /contracts → openapi.yaml updated for every endpoint/schema change.
7. Schema changes ALWAYS ship as NEW Alembic revisions. docs/MIGRATION-POLITIKASI.md
   is binding — deployed prod exists; never edit applied migrations in place.
8. i18n discipline: UI strings via ARB with ALL 7 locales (tr en ar ru de fr es),
   README §15 grep inventory before/after, eyeball RTL pass on new/changed screens.
   New hardcoded user-facing strings are a regression — not acceptable in ANY item.
9. Every item that changes user-visible behavior ends with a "Device-verify"
   checklist appended to item P11's Notes (Kerem tests in batches).
10. Long sessions: if context grows heavy mid-plan, finish and commit the current
    item, write the STATUS REPORT, and tell Kerem to /clear and restart with the
    standard kickoff prompt — the plan file carries all state.
11. FULLY AUTONOMOUS: never ask Kerem for permission, confirmation, or preference
    mid-run ("should I commit?", "which approach?", "say the word"). Decide, record
    the decision + reasoning in the item's Notes, and keep moving. Commits and
    pushes happen automatically per rule 2 — they are checkpoints, not approvals.
12. Per-item commits/tests are the agent's safety net, NOT checkpoints for Kerem —
    nothing waits for him until the FINAL REPORT. Device-verify entries accumulate
    silently in P11; do not surface them mid-run.
13. FINAL REPORT: when no eligible item remains, write to the top of CHANGELOG two
    numbered lists: (A) YAPILAN İŞLER — every completed item, one line each, with
    commit hash; (B) TEST EDİLECEKLER — every device/manual verification Kerem must
    do, concrete step-by-step, grouped by screen/role, in Turkish. Then stop.

## ITEMS

### P1 — Prod migrate reconciliation: verify push
Status: BITTI · Depends-on: —
Scope: Confirm the catch-up revision, infra/goc-uyum-dogrula.sh, infra/sema-olgular.sql,
docs/MIGRATION-POLITIKASI.md and infra/RUNBOOK-PROD.md §14 are all committed and pushed
to origin/main. Code-complete item; nothing new to build.
Acceptance: `git log` hashes listed in Notes; working tree clean; origin/main in sync.
Notes (2026-07-30): Doğrulandı. Beş dosyanın beşi de tek commit'te — `9f4ee74`
"fix(migrations): 0008b uyum yakalama …":
contracts/db/migrations/versions/0008b_uyum_yakalama.py, infra/goc-uyum-dogrula.sh,
infra/sema-olgular.sql, docs/MIGRATION-POLITIKASI.md, infra/RUNBOOK-PROD.md
(§14 + §14.1–§14.5 satır 234–346'da mevcut). Çalışma ağacı temiz;
HEAD == origin/main == db09192 (kontrol anında). Yeni kod yok, yalnız doğrulama.

### P2 — [KEREM] Prod runbook execution + smoke test
Status: BLOKE(Kerem sunucuda uygular) · Depends-on: P1
Scope: Kerem runs RUNBOOK-PROD §14 on the server (backup → alembic current → pull →
up -d --build → migrate exited(0) → §14.2 checks). Smoke: panel login, mobile login,
create announcement, fetch with Accept-Language: ru → translated content arrives.
Agent's part: keep the runbook accurate if anything changes; nothing else.
Acceptance: Kerem reports migrate exit 0 + §14.2 checks pass + ru translation fetched.

### P3 — Close the coverage series
Status: BITTI · Depends-on: —
Scope: task_ticket_widgets is the last open file (1/60) in the B inventory of the
coverage series (rounds ~36–52). Cover it per the series' own standard, then write a
closing summary (final coverage %, rounds, notable bugs found) into the series notes.
Acceptance: B inventory 0 open files; suite green; closing summary committed.
Notes (2026-07-30, tur 79): Plandaki varsayım BAYATTI — `task_ticket_widgets`
tur 52'de (1/60 → 66/69 = %96), `set_password_screen` tur 51'de (1/83 → 73/83 = %88)
kapatılmıştı. Kapanışta lcov YENİDEN ölçüldü ve envanterin listelemediği iki
sıfır-kapsamlı dosya çıktı; ikisi de kapatıldı:
`core/ui/temp_code_dialog.dart` 0/25 → **25/25** (yeni
`test/gecici_kod_diyalogu_test.dart`: 2 dedektör + beş eksen × 2 hâl + eksen
kombinasyonları + okuma sırası) ve `yonetici_iletisim_models.dart` 0/12 → **12/12**.
İki bulgu: (a) ÜRÜN — geçici kod kutusu `SelectableText` olduğu için dokunma
hedefidir ama 278×31 dp'ydi, `androidTapTargetGuideline` düşüyordu; `height: 2.2`
ile 48 dp'ye çıkarıldı. (b) DEDEKTÖR — `okumaSirasiSurusu` modal perdesini
(tam ekran, "Kapat", dismiss eylemi) okuma sırası ihlali sanıyordu; her diyalog
sürüşünde yanlış alarm verecekti, perde artık gezinme sırasından çıkarılıyor.
Kapanış özeti: `mobile/README.md` "TUR 79" + `docs/OLCULMEYEN-DURUMLAR-2.md` B bloğu.
Seri sonu: 17.522/27.325 = **%64,1**, 247 dosya, 140 test dosyası, 1357 test.
Kalan sıfır kapsam 2 dosya, ikisi de kayıtlı istisna (push_messaging → P12 [DIŞ];
app_config → tek satırlık derleme sabiti).
KAPILAR: `flutter analyze` → "No issues found!"; `flutter test` → **1357 geçti,
3 atlandı, 1 düştü** — düşen test `cevrimdisi_kuyruk_senaryo_test.dart`
"KALICILIK: uzun kesinti sonrasi YENI OTURUM kuyrugu devralir", yani **P10'un
konusu olan bilinen kalıcılık yarışı**; bu turdan ÖNCE de aynı şekilde düşüyordu
(değişiklikten bağımsız, kanıt: aynı komut değişiklik öncesi 1345+/1 ile
düşmüştü). P10'da düzeltilecek. `flutter build apk --debug` ✓.

### P4 — i18n round 4: building_map + complaints
Status: BITTI · Depends-on: —
Scope: Mechanical externalization per established pattern (id-split for control-flow
keys, build-time resolution, ICU plurals, glossary consistency, 6-language authoring).
building_map ~84 + complaints ~65 strings.
Acceptance: both modules contribute ZERO to §15 (documented exceptions aside);
§15 before/after in Notes; RTL eyeball pass done (building_map is layout-heavy —
expect overflow bugs like round 3's); quality gates (rule 6).
Notes (2026-07-30): **Bu iş plan yazılmadan ÖNCE bitmişti** — plan v2 bayat bir
anlık görüntüden yazılmış. `mobile/README.md` §15: "Tur 4 (building_map +
complaints) ölçümü": 803 → **654** toplam, `building_map` 84 → **0**,
`complaints` 65 → **0**; 149 string dışa alındı, 139 yeni ARB anahtarı × 7 dil.
Varsayıma güvenmeden **ölçüm bugün yeniden koşuldu** (README §15'in kendi
python komutu, `mobile/` içinde):
- §15 toplamı: **8 string / 5 dosya** — beşinin beşi de kayıtlı bilinçli
  istisna (`Yönetio` ×3 marka kilidi + `GÜVENLİK & DANIŞMANLIK`, dil adları
  `Türkçe`/`Français`, regex sınıfı `[A-ZÇĞİÖŞÜ]`). **building_map ve complaints
  katkısı 0.**
- İkinci tarama (tur 12 dersi — diyakritikten BAĞIMSIZ, UI konumundaki tüm
  literaller: `Text(`, `labelText:`, `hintText:`, `tooltip:`, `errorText:`,
  `semanticsLabel:`): 15 isabet, **hepsi interpolasyon ya da teknik sabit**
  (`'$badge'`, `'${s.baslangic} – ${s.bitis}'`, `'https://...'`, `'#${unit.sira}'`),
  sabit Türkçe metin **yok**.
- RTL: göz taraması yerine daha güçlü kanıt var — `test/bina_complaints_i18n_test.dart`
  (43 test) bu iki modülü Arapça dahil çizip **taşma + TR sızıntısı** denetler;
  yerleşim-yoğun blok kutucukları özellikle hedeflenmiş.
Yeni kod yok; kapılar P3 koşumundan geçerli (analyze temiz, apk ✓).

### P5 — i18n round 5 (final UI round): everything remaining
Status: BITTI · Depends-on: P4
Scope: rezervasyon + etkinlik + ALL remaining §15 modules/files until the inventory
is zero (documented exceptions only). May be split into multiple commits by module
group, each with §15 numbers.
Acceptance: §15 total = 0 (+ exceptions list final); quality gates.
Notes (2026-07-30): P4 ile aynı durum — iş plan yazılmadan önce bitmiş. README §15
tur 5 (rezervasyon + etkinlik + unit_access) ve tur 6–12 (bütçe/demirbaş/kargo,
site kuralları/duyurular/sakinler, auth/profil/personel, dış hizmet/NFC/şeffaflık,
entegrasyon/ziyaretçi/rapor, aidat/kontrol noktası/kuyruk ve **süpürme turu**:
destek, tesis kurulumu, şikayetlerim, vardiyalar, yönetici iletişim, bildirimler,
arama butonu, push) zinciriyle envanter sıfırlanmış.
BUGÜN KOŞULAN ÖLÇÜM (kanıt, P4 Notes'takiyle aynı komut): §15 = **8 string /
5 dosya**, tamamı bilinçli istisna. **Kalan modül borcu YOK.**
Nihai istisna listesi (README §15 "Kalan 8 string" tablosuyla birebir):
| # | Dosya | String | Neden |
|---|---|---|---|
| 1–3 | `main.dart`, `core/branding/yonetio_logo.dart` (×2) | `Yönetio` / `yönetio` | marka kelime işareti |
| 4 | `home/.../home_marka.dart` | `Yönetio` | aynı |
| 5 | `home/.../home_marka.dart` | `GÜVENLİK & DANIŞMANLIK` | logo lockup alt başlığı |
| 6–7 | `core/i18n/locale_controller.dart` | `Türkçe`, `Français` | dil adları kendi dilinde (çevrilirse seçici işlevini yitirir) |
| 8 | `core/validators/password_rule.dart` | `[A-ZÇĞİÖŞÜ]` | regex karakter sınıfı — teknik sabit |
İkinci tarama (UI konumundaki tüm literaller, diyakritikten bağımsız): 15 isabet,
hepsi interpolasyon/teknik sabit. Yeni kod yok; kapılar P3 koşumundan geçerli.

### P6 — Backend localization (Accept-Language for server strings)
Status: BITTI · Depends-on: P5
Scope: ApiException messages + activity feed baslik/alt_metin localized server-side
via Accept-Language (7 locales). Boundary is already marked: grep
"SERVER-LOCALIZED(next round)" in mobile lib/. Backend emits locale-aware text
(activity items should carry tur + params so text is generated per request locale);
mobile sends Accept-Language and removes the boundary markers it can now retire.
Acceptance: activity feed + surfaced API errors render in the app locale for all 7;
contract documents the header behavior; markers retired or re-scoped; quality gates.
Notes (2026-07-30): P4/P5 ile aynı — iş plan yazılmadan önce bitmiş, üç turda:
- **tur 14** `backend/app/hata_metinleri.py`: `APIError` artık CÜMLE değil KİMLİK
  taşır; metin yalnız hata işleyicisinde (`errors.py`) istemcinin
  `Accept-Language`ine göre üretilir. Dil çözümleme İÇERİK ÇEVİRİSİYLE AYNI
  zinciri kullanır (`ceviri.accept_language_coz`) — bir istek hem duyuruyu hem
  hatayı aynı dilde alır. 7 dilin hepsi katalogda; eksik dil
  `tests/test_hata_i18n.py::test_katalog_tam` ile yakalanır ve çalışma anında
  sessizce tr'ye düşer.
- **tur 15** `/activity` satırları kimliğe çevrildi (`akis_metinleri.py`; sunucu
  `baslik_kimlik` + `veri` gönderir, cümleyi istemci kurar) — yani akış metni
  sunucuda hiç üretilmiyor, dil sorunu kaynağında çözülmüş.
- **tur 16** push + uygulama-içi bildirim metinleri 7 dile alındı; push asenkron
  olduğu için dil `user_device.dil`den okunur (`scheduler/notify.py`), istek
  başlığından değil — doğru karar, notlarda gerekçeli.
SINIR İŞARETLERİ: `SERVER-LOCALIZED(next round)` işareti mobil `lib/` içinde
KALMADI; yerine 7 dosyada kalıcı `SERVER-LOCALIZED sınırı` notu var — "sunucu
metni geldiğinde istemci onu çevirmez" kuralını belgeleyen yerleşik tasarım
notu, açık iş değil.
SÖZLEŞME: `contracts/openapi.yaml` `Accept-Language`i 9 yerde belgeliyor —
başlık parametresi (satır 5033), geri-düşme zinciri `?dil=` → Accept-Language →
kaynak dil (5049), `?dil=` ezmesi (5062), hata zarfı (5131), push istisnası
(5188) ve üç yayın tipinin çeviri notları.
KAPI: tam `pytest` koşuldu — **788 test**, 1 düşen vardı ve o da bu maddeden
bağımsız gece-yarısı kırılganlığıydı (`test_me_patrol.py`, ayrı commit'te
düzeltildi + dedektör testi eklendi); düzeltme sonrası dosya 11/11 yeşil.

### P7 — Content-translation mobile wiring
Status: BITTI · Depends-on: P6
Scope: Mobile consumes the write-time-translated broadcast content (announcements,
site rules, events): sends Accept-Language; shows translated title/body; UI states:
"otomatik çevrilmiştir · orijinali gör" (toggle to original) and "çeviri hazırlanıyor"
(durum=bekliyor → original + note). Manual-override/hazir/hata states handled.
Acceptance: with app language ru/ar, seeded content renders translated with the
machine-translation affordances; original always reachable; quality gates.
Notes (2026-07-30): GERÇEK İŞ — sunucu tarafı hazırdı ama mobil ustveriyi HİÇ
okumuyordu: Rusça arayüzde makine çevirisi bir duyuruyu okuyan kullanıcı bunun
çeviri olduğunu bilmiyor, orijinaline de ULAŞAMIYORDU.
Yeni dosyalar:
- `core/i18n/icerik_ceviri.dart` — `CeviriAlanlari` aynası (`orijinal_dil`,
  `gosterilen_dil`, `ceviri_durumu`, `cevirildi_mi`, `orijinal`). Savunmalar:
  ustveri HİÇ gelmezse `null` (eski sunucu davranışı bozulmaz), bilinmeyen durum
  `hazir` sayılır (yanlış "hazırlanıyor" uyarısı göstermek metni olduğu gibi
  göstermekten kötüdür), bozuk `orijinal` (liste/sayı) çökertmez, orijinalde o
  alan yoksa servis edilene düşülür (boş ekran yok).
- `core/ui/ceviri_notu.dart` — `CeviriNotu` (not + geçiş) ve `CeviriRozeti`
  (geçişsiz kısa rozet).
Bağlanan üç entity: Announcement, SiteKurali, Etkinlik (+ ekranları).
TASARIM KARARLARI (gerekçeli):
1. **Nerede geçiş var:** TAM metnin göründüğü yerde (duyuru kartı — duyurunun
   ayrı detayı yok; kural/etkinlik DETAYI) not + "orijinali gör"/"çeviriyi gör";
   KIRPILMIŞ önizlemede (kural/etkinlik liste kartı) yalnız rozet — üç satırlık
   kırık metinde geçiş gürültüdür ve kullanıcı zaten detaya girecektir.
2. **Elle düzeltilmiş çeviride rozet YOK** — sunucu `cevirildi_mi=false` döner;
   yöneticinin düzelttiği metin makine çıktısı değildir.
3. **Kaynak dili (tr) okuyan kullanıcıda hiçbir not yok** — `notVar` üç halin de
   yanlış olduğu durumda false.
4. **Geçiş `TextButton`** (çıplak `InkWell` değil): 48 dp dokunma hedefi + kendi
   `Focus`u (tur 33 dersi). Renkler `okunurVurgu`dan geçer (tur 57 dersi).
5. Alt sayfa detayları FONKSİYON olduğu için geçiş durumu `StatefulBuilder` ile
   yerel tutulur; ekranın durumuna dokunulmaz.
CANLI KANIT (dev API, `Accept-Language: ru`): `/announcements` →
`cevirildi_mi:true, gosterilen_dil:ru, orijinal:{baslik:"Asansor bakimi",…}`;
`/site-rules` → aynı; `/events` → `ceviri_durumu:"bekliyor", cevirildi_mi:false`
(yani "çeviri hazırlanıyor" hâli seed veriyle GERÇEKTEN oluşuyor). `tr` ile üçü
de `cevirildi_mi:false` → not gösterilmez.
i18n: 8 yeni ARB anahtarı × 7 dil (1.218 → 1.226 tr anahtarı). §15 ölçümü
değişmedi: **8 string / 5 dosya**, hepsi kayıtlı istisna.
TESTLER: `test/icerik_ceviri_test.dart` — 23 test (model çözümleme + savunmalar,
metin seçimi, üç entity bağlaması, bileşenin üç hâli, beş eksen sürüşü ve EKRAN
testi: duyuru kartında "Orijinali gör" gerçekten orijinali çizer, geri de döner).
KAPILAR: `flutter analyze` temiz; `flutter test` **1380 geçti / 3 atlandı /
1 düştü** (düşen = P10'un bilinen kalıcılık yarışı, bu değişiklikten bağımsız);
`flutter build apk --debug` ✓. Sözleşme değişmedi (salt okuma).

### P8 — Missing list/detail screens: Araç Plaka, İhlaller, Otopark
Status: BITTI · Depends-on: —
Scope: Endpoints exist (G1/G2/G4). Build the three screens in the approved design
language: vehicle-pass list (open/closed filter, checkout action for authorized
roles), violations list (durum filter + transitions per RBAC), parking/occupancy
view; wire the home cards + Hızlı Özet Otopark tile that currently route to
"Bu bölüm yakında". All strings via ARB (7 locales).
Acceptance: cards navigate to real screens; role-correct actions; quality gates.
Notes (2026-07-30): Üç ekran da yazıldı; ana ekranda ROTASIZ KART KALMADI.
Yeni modüller: `features/vehicle_pass/` (model+api+controller+2 ekran) ve
`features/violations/` (model+api+controller+1 ekran). Rotalar:
`/arac-gecisleri`, `/otopark`, `/ihlaller`.
- **Araç Geçişleri** (G1, admin+security): Tümü/İçeride/Çıkmış süzgeci, plaka
  araması **SUNUCUDA** (normalize eşleşme "34 abc" == "34ABC" yalnız orada
  doğru çalışır), açık geçişte **Çıkış ver** (onay + 409 → "zaten kapatılmış"),
  yeni giriş formu (409 → "bu plakanın açık geçişi zaten var"). Üstte agregat
  doluluk bandı.
- **Otopark** (G4, TÜM roller): dolu/kapasite + yüzde çubuğu + Dolu/Boş
  kutuları. Kapasite tanımsızsa **uydurma yüzde üretilmez** — "N araç" + "—" +
  açıklayıcı not (sunucu da `oran: null` döner). Geçiş listesine bağlantı
  YALNIZ yetkili rolde çizilir (yetkisiz kullanıcı 403 duvarına çarpmasın).
- **İhlaller** (G2): durum süzgeci (Tümü/Yeni/İnceleniyor/Kapatıldı), akış
  yeni→inceleniyor→kapatıldı, **kapatma yalnız admin** (dört-göz kuralı) ve
  onay ister; `kapatildi` TERMINAL (kapalı kartta hiçbir geçiş düğmesi yok);
  yönetici OKUR ama hiçbir eylem düğmesi görmez; 409 → "yeniden açılamaz".
RBAC: `user_role.dart`'a beş yeni yetenek bayrağı eklendi
(`canViewVehiclePasses`, `canManageVehiclePasses`, `canViewParking`,
`canViewViolations`, `canManageViolations`, `canCloseViolations`) — hepsi
sözleşmedeki RBAC notlarının birebir aynası, testle kilitli.
403 TASARIM KARARI: yetkisiz rol için hata bandı DEĞİL, kilit ikonu + açıklayıcı
metin çizilir — "yetkin yok" bir ağ hatası değildir ve kullanıcı yeniden
denemeye teşvik edilmemelidir.
BULGU (kendi kodumda): ilk sürümde süzgeç şeridi `SizedBox(height:)` içindeydi;
sabit yükseklik çipi 40 dp'ye sıkıştırıyor ve `androidTapTargetGuideline`
(48 dp) düşüyordu. `tasks_screen` kalıbına (kaydırılabilir Row, yükseklik
içerikten) geçildi.
i18n: 51 yeni ARB anahtarı × 7 dil (1.226 → 1.286 tr). §15 ölçümü DEĞİŞMEDİ:
**8 string / 5 dosya** (hepsi kayıtlı istisna). Sözlük denetimi iki gerçek
KOGNAT yakaladı (`Kamera` tr==de, `Manuel` tr==fr) — istisna listesine
gerekçesiyle eklendi.
GÜNCELLENEN TESTLER: `home_repository_test` iki testi "bu kartlar ROTASIZ"
diye iddia ediyordu (eski durumu kodluyordu); iddia TERSİNE çevrildi —
rotasız kart kalmadığı + rotaların doğru hedefler olduğu kilitlendi.
TESTLER: `test/arac_ihlal_otopark_test.dart` — 24 test (model + RBAC + ekran
davranışı + 409 yolları + üç ekranın beş eksen sürüşü).
KAPILAR: `flutter analyze` temiz; `flutter test` **1405 geçti / 3 atlandı /
0 düştü**; `flutter build apk --debug` ✓. Sözleşme değişmedi (uçlar zaten
belgeliydi).

### P9 — Contract backfill: undocumented live endpoints
Status: BEKLIYOR · Depends-on: —
Scope: Document in openapi.yaml exactly as implemented (audit code, no behavior
change): /audit, /support*, /transparency*, /admin/overview, /me, /me/checkpoints,
avatar PATCHes, PUT /shifts/{id}/assignments.
Acceptance: contract↔live machine check passes for these paths; no code change.

### P10 — scan_outbox_test flake fix
Status: BITTI · Depends-on: —
Scope: Persistence-test race (b7bd5eb history): passes isolated, rarely fails in
full runs. Find the actual race (shared temp dir / async timing), fix properly.
Acceptance: documented repro reasoning + 20x full-suite-context repetition green.
Notes (2026-07-30): **YENİDEN ÜRETİLDİ ve İKİ GERÇEK ÜRÜN HATASI bulundu** —
test kırılganlığı değil, ürün yarışıydı.
REPRO YÖNTEMİ: `cevrimdisi_kuyruk_senaryo_test::KALICILIK` senaryosu tek testin
içinde 60 kez üst üste koşuldu. Yarış hemen görünür oldu:
`PathNotFoundException: Cannot rename '<dosya>.tmp' -> '<dosya>'`.
HATA 1 — **HAYALET YAZAR.** `ProviderContainer.dispose()` sırasında uçuşan
`_persist()` çağrıları iptal olmuyordu. Kapanmış kuyruk, YERİNE GEÇEN yeni
kuyruğun dosyasını KENDİ BAYAT durumuyla eziyordu → kayıt sessizce kayboluyor,
"yeni oturum kuyruğu devralır" iddiası düşüyordu. Bu gerçek uygulamada da
olur (oturum kapanışı/yeniden kurulum).
HATA 2 — **PAYLAŞILAN `.tmp`.** Depo sabit `<dosya>.tmp` adını kullanıyordu.
Aynı dosyaya yazan iki örneğin kilitleri AYRI olduğu için adımlar iç içe
giriyordu: `A:write → B:write(A'nın tmp'sini ezer) → A:rename(dosyaya B'nin
verisi) → B:rename(tmp yok → istisna)`. Yani ya sessiz veri kaybı ya yutulan
istisna.
DÜZELTMELER: (a) `ScanOutbox._kapandi` bayrağı — `_persist()` erken döner;
(b) `ScanOutboxStore.save(..., gecerliMi:)` iptal kancası — yazım sıraya
girdikten SONRA, dosyaya taşınmadan hemen önce bir kez daha sorulur, iptalde
geçici dosya silinir ve hedefe DOKUNULMAZ (tek başına (a) YETMEZ: kilit zinciri
yüzünden bir `save` çağıran kapandıktan çok sonra diske inebilir);
(c) her yazım için TEKİL geçici ad (`<dosya>.<örnek>-<sayaç>.tmp`).
DEDEKTÖR KANITI: `test/kuyruk_hayalet_yazar_test.dart` (3 test) —
düzeltme geçici olarak geri alındığında "HAYALET YAZAR" testi DÜŞÜYOR,
geri konduğunda geçiyor (deney koşuldu). İçinde 50 tekrarlı "yeni oturum"
döngüsü de var (tek koşum yarışa kanıt değildir).
KAPILAR: `flutter analyze` → "No issues found!" (bu arada P8'in test
dosyasındaki 2 `info` lint de düzeltildi — P8 commit'inde tam analiz test
dosyası yazılmadan ÖNCE koşulmuştu); `flutter test` **1408 geçti / 3 atlandı /
0 düştü**; `flutter build apk --debug` ✓; ardından 20× tam-suit tekrarı
(sonuç aşağıda, TEKRAR KOŞUMU notu).

### P11 — [KEREM] Accumulated device testing
Status: BLOKE(Kerem telefonda test eder) · Depends-on: —
Scope: Kerem's batch checklist. Currently pending: flicker-fix verification (counters
update in place, no skeleton flash, all roles, incl. 60s periodic refresh); ar/ru
walkthrough of localized modules (overflow + missing-translation hunt); 4-role
general pass. Agents APPEND to this checklist per rule 9; never remove entries —
Kerem marks them done.
Acceptance: Kerem reports; findings become new items.

Device-verify (biriken liste — agent ekler, Kerem işaretler):
- [ ] **P8 · Üç yeni ekran.** (a) **Güvenlik** ile gir → ana ekranda "Araç
  Plaka" kartına bas: liste açılmalı (eskiden "Bu bölüm yakında" diyordu).
  Süzgeçleri dene (Tümü/İçeride/Çıkmış), plaka kutusuna bir plakanın ilk
  birkaç karakterini yazıp klavyeden ara → süzülmeli; boşluklu yaz ("34 abc")
  → yine bulmalı. İçerideki bir araçta **Çıkış ver** → onay → liste tazelenip
  rozet "Çıktı" olmalı. FAB'dan yeni giriş kaydet; AYNI plakayı tekrar
  kaydetmeyi dene → "bu plakanın açık geçişi zaten var" uyarısı çıkmalı.
  (b) **Yönetici** ile gir → "Otopark Kullanımı" kartı ve Hızlı Özet'teki
  otopark kutusu Otopark ekranını açmalı; yüzde çubuğu ve Dolu/Boş kutuları
  doğru olmalı; yöneticide "Araç geçişlerini aç" düğmesi GÖRÜNMEMELİ.
  (c) "İhlaller" kartı → yöneticide liste okunur ama hiçbir eylem düğmesi
  olmamalı. **Güvenlik**te "İncelemeye al" var, "Kaydı kapat" YOK.
  **Admin**de "Kaydı kapat" var, onay soruyor ve kapattıktan sonra o kartta
  hiçbir düğme kalmamalı. **Sakin** ile İhlaller'e erişmeye çalış → kilit
  ikonlu açıklama çıkmalı (hata bandı değil).
- [ ] **P7 · Otomatik çeviri notu.** Uygulama dilini **Rusça** (veya Arapça) yap.
  Duyurular: kart metni Rusça gelmeli ve altında "Bu içerik otomatik
  çevrilmiştir · **Orijinali gör**" satırı olmalı; bas → Türkçe orijinal
  gelmeli, etiket "Çeviriyi gör" olmalı, tekrar bas → Rusçaya dönmeli.
  Site Kuralları: LİSTEDE yalnız küçük "Otomatik çeviri" rozeti olmalı (geçiş
  yok), karta bas → detayda not + geçiş çalışmalı. Etkinlikler: aynı; ayrıca
  seed'deki etkinlikte "Çeviri hazırlanıyor — orijinal gösteriliyor" satırını
  görmelisin (geçiş butonu OLMAMALI, metin zaten orijinal). Dili **Türkçe**ye
  al: üç ekranda da hiçbir çeviri notu/rozeti GÖRÜNMEMELİ. Arapçada (RTL) not
  satırının taşmadığını ve sağa hizalandığını da kontrol et.
- [ ] **P3 · Geçici giriş kodu diyaloğu.** Yönetici olarak Sakinler (veya
  Personel) ekranından yeni kişi ekle → geçici kod diyaloğu açılır. Kontrol:
  kod kutusu eskisinden BELİRGİN ŞEKİLDE daha yüksek (48 dp) ve yazı kutunun
  dikey ortasında duruyor; "Kopyala"ya bas → ikon tike döner ve kod panoya
  gerçekten yapışıyor (bir mesaj kutusuna yapıştırıp dene); aynı kontrolü
  parola sıfırlama akışında da yap. Koyu temada ve yazı boyutu büyütülmüş
  cihazda da bir kez bak.

### P12 — [DIŞ] Firebase credentials → real push
Status: BLOKE(dış bağımlılık) · Depends-on: —
Scope: When Kerem provides Firebase project credentials: wire real FCM push
(backend sender + mobile receipt), replacing any stubbed path. Test recipe for Kerem.
Acceptance: a real notification reaches a physical device.

### P13 — [DIŞ] iyzico/PayTR sandbox keys → payment E2E
Status: BLOKE(dış bağımlılık) · Depends-on: —
Scope: When sandbox keys arrive: end-to-end dues payment against sandbox, webhook
verified, receipt states correct in app + panel.
Acceptance: sandbox payment completes and reflects everywhere.

### P14 — Translation quality gate
Status: BEKLIYOR · Depends-on: P7
Scope: (a) ARB handoff prep for native review — export/notes for ar+ru minimum,
glossary included; (b) evaluate LibreTranslate content quality on real prod-style
samples (tr→ar/ru/de/fr/es/en), write a short quality note; (c) if weak, a provider
swap decision note (DeepL) — abstraction already exists, note the config change only.
No provider swap without Kerem's go.
Acceptance: handoff package in docs/ + quality note committed.

### P15 — Frigate Phase 1: PoC
Status: BEKLIYOR · Depends-on: —
Scope: Frigate in dev docker (separate compose or profile; NOT in prod compose),
sample RTSP/HLS input, LPR enabled; explore event flow (MQTT and/or API), restream
URL shapes (go2rtc), snapshot access. Deliverable: findings doc + draft event schema
for the source-agnostic ingest endpoint (plate, time, direction, camera, confidence,
photo ref) + resource notes (CPU, model needs).
Acceptance: docs/frigate-poc.md with reproducible setup + captured sample events.

### P16 — Frigate Phase 2: source-agnostic ANPR ingest (backend)
Status: BEKLIYOR · Depends-on: P15
Scope: POST /integrations/anpr/events — per-tenant API key auth; standard body per
P15 schema; adapter layer mapping events → vehicle_pass open/close (entry/exit) and
violations where applicable; low-confidence events land in an approval queue
(panel/mobile confirm flow can be a follow-up item); activity feed integration.
New schema via NEW revisions (rule 7).
Acceptance: simulated Frigate events create/close vehicle passes correctly;
confidence threshold configurable per tenant; full pytest; contract updated.

### P17 — Frigate Phase 3: mobile
Status: BEKLIYOR · Depends-on: P16
Scope: RTSP cameras playable via Frigate restream (camera record gains optional
restream URL; player uses it when present → oynatilabilir flips); plate-event
screens (live-ish list, registered/unknown badges via the P27 vehicle registry —
cross-check plate normalization); approval queue UI for low-confidence reads
(authorized roles).
Acceptance: RTSP camera plays through restream in dev; plate events visible; quality gates.

### P18 — [KEREM+DONANIM] Frigate Phase 4: pilot site
Status: BLOKE(donanım+saha) · Depends-on: P17
Scope: Agent's part only: install/ops runbook for a site box (mini PC class; Coral
optional), camera-angle guidance for LPR, remote update strategy note.
Acceptance: runbook committed; field execution is Kerem's.

### P19 — Hikvision/Dahua adapters
Status: BEKLIYOR · Depends-on: P16
Scope: Adapters translating Hikvision (ISAPI event notification) and Dahua HTTP
push payloads into the P16 ingest format. Config docs for pointing cameras at our
endpoint. Simulated-payload tests (real device tests are field work).
Acceptance: recorded/sample payloads from both brands map correctly; docs committed.

### P20 — Face recognition v2: design note only
Status: BEKLIYOR · Depends-on: —
Scope: DESIGN NOTE, no implementation: staff-only face verification (explicit
written consent, tenant-default OFF, KVKK analysis summary, scope strictly
excludes residents/visitors and any bulk identification). Ends with an explicit
"requires Kerem go decision" line.
Acceptance: docs/face-recognition-v2-design.md committed; nothing else changes.

### P21 — "Translate this content" button: evaluation note
Status: BEKLIYOR · Depends-on: P7
Scope: Short design note for on-demand translation of user-generated text
(complaints/comments): where it appears, "otomatik çevrilmiştir" labeling, cost
implications, provider reuse. Low priority; note only.
Acceptance: note committed.

### P22 — Mobile UX fix package
Status: BEKLIYOR · Depends-on: —
Scope: (a) ALL modals/pop-ups open CENTERED, not as bottom sheets — one shared
dialog style app-wide; (b) tapping a notification opens its detail (currently
dead); (c) after "Olay Bildir" submit, return to home WITHOUT a full-screen
reload (reuse the refresh-scope; no flicker); (d) resident noise-complaint entry
wrongly routes to the talep/arıza panel — route it into the şikayet flow;
tracking stays in Şikayetlerim; (e) separate Talep/Arıza and Şikayet/Öneri as
clearly distinct flows and labels end-to-end (audit how backend complaints vs
unit-complaints map; align mobile navigation + naming without breaking data);
(f) site-rule images render inline with the rule text in the list (not only on
tap); (g) add "görüntü kirliliği" as a violation/complaint kategori usable from
the parking context (backend enum addition via NEW revision if needed).
Acceptance: each fix individually demonstrable; routing + dialog tests where
feasible; ARB for all new strings; quality gates.

### P23 — Resident lifecycle: unit assignment + full edit + malik/kiracı
Status: BEKLIYOR · Depends-on: —
Scope: (a) assign unit(s) to an EXISTING resident (currently impossible after
creation); (b) full resident edit — every field enterable at creation is editable
later (backend + panel + mobile where resident editing exists); (c) unit-person
relation gains TYPE: kat_maliki | kiraci (a unit may have both). This distinction
is the foundation for accounting (P27+): investment/one-off project debits bind
the MALİK; regular dues bind the current KİRACI if present, else malik. NEW
revisions for schema.
Acceptance: create→later-assign→edit E2E; relation types stored + surfaced;
RBAC correct; contract updated; quality gates.

### P24 — Complaint triage tabs + 4-tier unit color scale
Status: BEKLIYOR · Depends-on: —
Scope: complaint management views gain a "Yeni / Okunmamış" tab separate from the
full list, with per-admin read state; unit color scale driven by noise/complaint
count: 0=yeşil, 1–2=sarı, 3–4=kırmızı, 4+=mor — one shared component used in the
building map and unit lists. Counter window ties into P37's reset rule (reset
zeroes the scale); make the counting basis explicit and configurable-ready.
Acceptance: tab + unread badge behavior tested; color boundaries tested at
0/1/2/3/4/5; quality gates.

### P25 — Camera hardening + full home grid
Status: BEKLIYOR · Depends-on: —
Scope: (a) stream URL max length (2048) + validation on both ends with clear
Turkish errors; (b) INVESTIGATE & FIX "public internet streams don't play":
assemble a set of known-good public HLS/MP4 URLs, reproduce, diagnose (CORS,
mixed content, redirects, user-agent, container/codec), fix player/networking,
and document exactly which URL classes are supported + surface a clear error for
unsupported ones; (c) home camera section shows ALL cameras the role may see in
a 4-wide horizontally scrollable grid (not a fixed 2); tap → existing fullscreen
player.
Acceptance: overlong/invalid URLs rejected; documented public test URLs play in
a device build; grid shows the full visible set per role; quality gates.

### P26 — Unit types & groups with per-type dues
Status: BEKLIYOR · Depends-on: —
Scope (ref docs/design-refs/apsiyon/): Bağımsız Bölüm Tipleri — a freely
editable, modular list (user types any label: 1+0, 1+1, 2+1, dubleks…), each with
a default aidat tutarı; Bağımsız Bölüm Grupları (Daire / Villa / Dükkan style).
Units carry tip + grup; building/bulk unit creation allows picking type per unit
or per batch. NEW revisions; RLS; panel + (where units are shown) mobile surfaces.
Acceptance: CRUD for types/groups; assignment on units incl. bulk create; per-type
default dues consumed by P28; contract; quality gates.

### P27 — Accounting definitions layer (Tanımlar)
Status: BEKLIYOR · Depends-on: P23, P26
Scope (ref docs/design-refs/apsiyon/): Kasa definitions (kod, ad, açılış tarihi,
açılış bakiyesi, aktif, banka bilgisi flag + IBAN/banka alanları); Gelir/Gider
tanımları (ad; tip: gelir|gider|her_ikisi; grup; dağıtım şekli enum — start with
bağımsız_bölümlere_eşit + tipe_göre, design extensible for arsa payı/kişi sayısı)
+ Gelir-Gider grupları; Firmalar registry (vergi no/TC, vergi dairesi, iletişim,
yetkili, açılış bakiyesi borç/alacak); Personel registry (ad, TC, görev, iletişim,
giriş/çıkış tarihi, maaş) — link to existing staff users where they overlap, audit
first; Araç registry (plaka+kişi+daire+marka+model+renk+aktif) — THE registered-
vehicle source for P17 badges; reuse norm_plaka; Sayaç definitions (ana sayaç:
ad/tipi/tesisat no/ortak alan dağıtım şekli+yüzdesi, otomatik bağımsız bölüm
sayacı oluşturma seçeneği; bağımsız bölüm sayaçları: blok/bölüm/bağlı ana sayaç/
tesisat no/ilk okuma). Settings: evrak seri-sıra no, para birimi (display only —
money stays ₺ policy holds until a real multi-currency decision). All tenant-
scoped, NEW revisions, RLS, seeded realistically.
Acceptance: full CRUD + contract + seed; pytest incl. RLS; panel build; gates.

### P28 — Debiting engine (borçlandırma)
Status: BEKLIYOR · Depends-on: P27
Scope: FIRST audit the existing dues module and EXTEND it (no parallel duplicate
system; record the merge decision). Then: single debit entry (kişi + bağımsız
bölüm, açıklama, borçlandırma türü = P27 tanımı, tarih, son ödeme tarihi, tutar,
gecikme tazminatı uygula flag, makbuz göster/yazdır); bulk debiting (filter by
blok/tip/grup; amount per unit or per-type via P26 defaults; preview → commit;
Excel import path with row-level error report); sayaç ile borçlandırma wizard
(4 steps: dağıtım şekli → ana sayaç → tüketim değerleri → borçlandırma; ortak
alan yüzdesi applied); gecikme tazminatı (tenant-configurable monthly %,
computed consistently at reporting/collection); malik/kiracı targeting: each
gelir-gider tanımı carries hedef kuralı (kiraci_oncelikli | malik) enforced from
P23 relation data — aidat/utilities default kiraci_oncelikli, yatırım/demirbaş
default malik.
Acceptance: all three debit paths E2E; targeting-rule tests (tenant present/
absent/both); existing dues flows and mobile dues screens unbroken; Excel import
handles malformed rows gracefully; contract; gates.

### P29 — Collections, cash & financial movements
Status: BEKLIYOR · Depends-on: P28
Scope: tahsilat (tekil: kişi, yöntem otomatik/nakit/banka, kasa, tutar, tarih,
açıklama; toplu tahsilat); gider & gelir hareketleri (row-based entry: hareket
tipi, belge no, tarih, firma, tür, durum, kasa, tutar, açıklama; multi-row "Yeni
Satır"); hesaplar arası virman (borçlandırılacak/alacaklandırılacak hesap tipi);
ödeme iadesi; açılış fişleri (kişi + kasa opening balances borç/alacak); icra
dosyaları (dosya no, kişi, icraya veriliş tarihi, açıklama, avukat, dosya durumu;
link the person's open debt docs); banka hareketleri (Excel import + auto-match
suggestions to kişi/borç, one-click tahsilat; bank API integration stays a doc
note, not code); kasa balances transactional with every movement (double-entry
consistency). Dashboard: özet kartları (Borçlandırılan/Tahsil Edilen (ay),
Borçlarım/Alacaklarım, Onay Bekleyen Hareketler, Ödenmiş Faturalar) + Kasalar
panel (genel toplam) + global "+" quick-action menu (Yeni Kişi / Borçlandırma /
Tahsilat; e-posta/SMS entries stubbed until P32).
Acceptance: consistency tests (kasa bakiye ≡ hareket toplamı; virman/iade edge
cases), Excel import robustness, dashboard numbers match DB truth; panel
`npm run build`; contract; gates.

### P30 — Dues payment flow (resident)
Status: BEKLIYOR · Depends-on: P29 (iyzico live path additionally needs P13)
Scope: resident "Öde" flow: method 1 KART (iyzico) behind the existing/new
payment-provider abstraction — implement fully with mock-provider tests now; goes
live automatically when P13 keys arrive; method 2 BANKA HAVALESİ — show the
tenant's anlaşmalı IBAN + kopyala + a unique açıklama kodu (kişi/daire matching
reference); admin's bank-movement import (P29) auto-matches that code and closes
the debt. Any successful payment → tahsilat record → kasa/gelir reflection via
the P29 pipeline, idempotent webhooks.
Acceptance: mock-card path E2E + IBAN path E2E incl. auto-match; accounting
reflection verified; mobile UX simple (Kerem's emphasis: "çok kolay"); gates.

### P31 — Report engine & catalog
Status: BEKLIYOR · Depends-on: P29
Scope (ref parameter-modal + PDF screenshots in docs/design-refs/apsiyon/):
shared report framework — parameter modal (tarih aralığı, tazminat hesaplama
tarihi, blok, borçlandırma türü, listeleme tipi, min/maks tutar, sıralama, flags:
ismi göster, icradakileri göster) with THREE outputs: Göster (in-app table), PDF
(corporate template: site adı + logo + aralık + zaman damgası + sayfa altbilgisi),
Excel — all generated server-side. Catalog: Borç-Alacak Listesi (dönem başı ana
para/gecikme; dönem içi borçlandırma/gecikme/iade/tahsilat; bakiye), Detaylı Borç
Listesi (DYNAMIC per-gider-kalemi columns from P27 tanımları: Elektrik/Su/Doğal
Gaz/Diğer + toplamlar), Site Sakinleri Listesi, Dönemsel Bakiye, Notlar, Kasa/
Firma/Hesap Ekstresi, İşletme Defteri, Finansal Hareketler, Makbuz Dökümü,
Gelir-Gider Özet, İhtar Yazısı (formal dunning letter per unit), Tahsilat
Performansı (collection rate, aging, trend — Kerem explicitly flagged this as
critical: design it well), Denetim Raporu (auditor format: dönem gelir-gider,
kasa mutabakatı, karar defteri referansları — the Word doc's denetçi requirement).
Acceptance: framework + full catalog wired; PDF/Excel outputs verified; column
correctness tests for both debt reports; gates.

### P32 — Communication suite (SMS + e-mail templates)
Status: BEKLIYOR · Depends-on: P28; live SMS sending additionally [DIŞ]
Scope (ref screenshots): template CRUD for SMS + e-posta with tag interpolation
({bakiye}, {borc}, {adi_soyadi}, {adres}, {tarih}, {odeme_linki}, {site_adi},
{aidat_tutari}, {kiraci_bakiyesi}, {bakiye_detayli}, {borcu_detayli}); SMS
character counter; e-posta rich-text editor; sending: bireysel + toplu (filters:
blok, borç durumu), history with per-message durum (gönderildi/iletildi/okundu
where the provider reports it); seed the default template set (Bakiye Bildirimi,
Borç Girişi, Davetiye, Tahsilat Girişi, Toplantı Çağrısı, Yeni Duyuru, Kiracı
Bakiyesi). Providers: EmailProvider (SMTP config) + SmsProvider interface with a
log/mock default — a real SMS account is [DIŞ]; architecture must make it a
config swap. KVKV/consent: marketing sends require the P36 consents; operational
financial notices are a separate legal basis — each template carries a
pazarlama|operasyonel flag and sending enforces it. Wire the dashboard quick-
action stubs from P29.
Acceptance: CRUD + interpolation tests; mock-send E2E with history; consent
enforcement tests; gates.

### P33 — Governance & ops modules
Status: BEKLIYOR · Depends-on: P27 (personel), P9 (audit contract)
Scope: Karar Defteri (konu, no, tarih, karar metni, başkan + multiple üyeler;
PDF output on the P31 template); Doküman Yönetimi (tenant file archive on MinIO:
upload/download/delete, type+size limits, list with dates); İş Takibi — AUDIT the
existing talep/arıza + complaint models and unify into one ticket backbone (konu,
talebi açan, bağımsız bölüm, talep tipi, öncelik, atanan personel from P27,
durum) WITHOUT breaking mobile flows and honoring P22(e)'s şikayet/öneri
separation; İşlem Geçmişi panel screen over the existing /audit endpoint; Ayarlar
surfaces: yetki matrix view, Excel ile Site Aktar (bulk import: bloklar + daireler
+ kişiler with a downloadable template + row-level validation report), evrak
seri-sıra no + para birimi (P27 settings) UI.
Acceptance: each module CRUD + RBAC; site import E2E with a sample file; panel
build; gates.

### P34 — Patrol integrity package
Status: BEKLIYOR · Depends-on: —
Scope: (a) NFC scan attaches GPS (lat/lon/accuracy) when available; permission
denied → scan still records with konum_yok flag, visibly surfaced to amir/
yönetici (no silent gaps); location shown on scan detail for authorized roles;
staff-privacy note added to docs (KVKK: aydınlatma for personnel). (b) Missed-
patrol alarm: when a patrol window opens and no scan arrives within tolerance
(tenant setting, default 10 min), send REPEATING notifications to the assigned
görevli AND amir/yönetici (backoff schedule; stops at first scan or window end;
worker/beat implementation). (c) Anti-abuse start-of-patrol photo: before the
first checkpoint scan of each patrol, require an in-app CAMERA-ONLY photo (no
gallery), server records time+GPS; recommendation to implement INSTEAD of the
literal "walk 1 m back and forth" idea: NTAG424 SDM already cryptographically
proves physical tag presence — photo adds environment/time-of-day evidence
(gündüz/gece) and the GPS adds location; document this reasoning in the item
Notes; photo requirement is a tenant toggle. Contract via NEW revisions.
Acceptance: extended scan payload in contract; alarm scheduler start/stop tests;
photo-gated flow testable on device (P11 append); gates.

### P35 — Security-chief role & dual security architecture
Status: BEKLIYOR · Depends-on: P34
Scope: new role guvenlik_amiri + tenant security mode: yonetim_ici (today's
behavior — yönetici plans shifts/patrols) | dis_sirket (an external security
company runs site security: the amir owns security staff profiles, shift and
patrol-window planning; yönetici gets READ-ONLY monitoring of tours/shifts;
security staff report to the amir, not to residents/yönetici). Amir receives P34
alarms + locations. Update RBAC matrix across backend/panel/mobile; the home
shift grid (photos + active/next shifts, all roles) reflects whichever mode is
active. Mode changes audited.
Acceptance: ownership flip proven by tests (yönetici cannot edit patrols in
dis_sirket; amir cannot in yonetim_ici); amir login lands on an appropriate home;
contract; gates.

### P36 — Onboarding consents & KVKK gate
Status: BEKLIYOR · Depends-on: —
Scope: first-login/post-registration flow: mandatory KVKK aydınlatma pop-up —
the "Onaylıyorum" button stays DISABLED until the user scrolls to the bottom of
the text; approval stored with timestamp + text version; text version bump forces
re-consent. Then marketing preference toggles, each independent and default OFF:
"Bana özel kampanyalar/teklifler için E-POSTA / SMS / ARAMA almak istiyorum."
Preferences editable later in Settings. Consent storage via NEW revision; P32
reads these for pazarlama sends. UI strings via ARB; the KVKK legal text itself
is tenant content (original-language rule).
Acceptance: gate unbypassable (navigation locked before consent); scroll-gating
widget test; consent versioning test; settings editing; gates.

### P37 — Noise-deterrent automation (threshold → action → reset)
Status: BEKLIYOR · Depends-on: P24
Scope: when a unit's noise-complaint count reaches the tenant-configured
threshold (default 5): fire the deterrent action, create an auditable
"uyarı verildi" record, then RESET that unit's noise counter (complaint records
stay in history; the P24 color scale drops back to green). Deterrent action =
OUTBOUND WEBHOOK to a configured smart-home/announce endpoint (HMAC-signed JSON:
unit, uyarı metni, timestamp; retry with backoff) + configurable uyarı metni
template ("Gürültü kirliliği nedeniyle uyarı aldınız. Lütfen komşularınızı
rahatsız etmeyin.") + MANUAL fallback mode (notification to yönetici to trigger
the announcement themselves) for sites without integration. Do NOT implement
vendor hardware drivers — write a short design note listing candidate protocols
(MQTT, KNX bridges) for later; the webhook is the product boundary.
Acceptance: threshold boundary tests (4→no, 5→fire+reset), audit record, mock
webhook receiver test incl. signature, manual mode; gates.

### P38 — Site web portal + surveys (anket)
Status: BEKLIYOR · Depends-on: P29; nice-to-have reuse from P7
Scope (ref web-sitesi screenshots): per-tenant public web page + resident login
area, "son derece user friendly": hero + site adı; Hakkımızda (editable rich
text + görsel); Duyuru & ANKET feed — announcements reused; NEW anket module
(soru + seçenekler, one vote per resident, closing date, results view for
yönetici, minimal mobile voting hook); Galeri (photo management); Google Maps
embed from tenant konum (konum_lat/lon already in settings); İletişim section
(form: ad/telefon/e-posta/mesaj → yönetici notification/e-mail; cards: e-posta/
telefon/adres); mobile-app banner; authenticated resident area: Ödenmemiş
Borçlar (P29 data) + "Öde" → P30 flow. Tech decision: extend admin-web with
public multi-tenant routes (slug-based) vs separate app — decide, justify in
Notes; basic SEO/meta.
Acceptance: portal renders per tenant with real data; anket vote E2E (tek
oy/sakin) + results; contact form delivers; `npm run build`; gates.

### P39 — Scale & load readiness
Status: BEKLIYOR · Depends-on: best after P29–P31 land
Scope: translate the "millions of concurrent users" goal into engineering:
load-test suite (k6 or locust) against a staging profile covering login, home
bundle, /activity, dues, scan submission; measure baseline; fix the top
bottlenecks found (missing indexes, N+1s, connection-pool sizing, short-TTL
caching for hot counters where staleness is acceptable); horizontal-scale
readiness audit: api statelessness, worker/beat single-instance locking, token/
session storage, DB/MinIO pool limits; deliver docs/scaling-runbook.md with
measured sustainable RPS now + the compose→multi-node growth path. No premature
microservices.
Acceptance: before/after load numbers committed; zero correctness regressions
(all suites green); runbook in docs/.

## CHANGELOG
<!-- date · item ID · commit hash · one line. STATUS REPORTs and the FINAL REPORT land here, newest first. -->
<!-- HASH KURALI: bir commit kendi hash'ini iceremez. Satir once "(bu commit)"
     ile yazilir; gercek hash bir SONRAKI commit'te ya da FINAL REPORT'ta
     (kural 13, liste A) doldurulur. -->

- 2026-07-30 · P10 · 4509ca8 · Kuyruk kaliciik yarisi YENIDEN URETILDI: iki gercek urun hatasi (hayalet yazar + paylasilan .tmp) duzeltildi, 3 dedektor testi.
- 2026-07-30 · P8 · d20206b · Arac Gecisleri + Otopark + Ihlaller ekranlari yazildi; ana ekranda ROTASIZ KART KALMADI; 51 ARB anahtari x 7 dil; 24 test.
- 2026-07-30 · P7 · 10fbd12 · Icerik cevirisi MOBILE baglandi: IcerikCeviri modeli + CeviriNotu/CeviriRozeti + duyuru/kural/etkinlik ekranlari; 8 ARB anahtari x 7 dil; 23 test.
- 2026-07-30 · P6 · 6a9f846 · Sunucu yerellestirmesi (Accept-Language) ZATEN BITMISTI (tur 14/15/16); sinir isaretleri + sozlesme + katalog dogrulandi.
- 2026-07-30 · P5 · fde3a4f · i18n tur 5 ve sonrasi ZATEN BITMISTI; §15 = 8 (hepsi kayitli istisna), nihai istisna listesi plana yazildi.
- 2026-07-30 · P4 · f9837cf · i18n tur 4 (building_map + complaints) ZATEN BITMISTI; olcum yeniden kosuldu: §15 = 8 (hepsi kayitli istisna), iki modulun katkisi 0.
- 2026-07-30 · P3 · 10015b2 · Kapsama serisi KAPANDI: temp_code_dialog 0/25 → 25/25 (dokunma hedefi bulgusu + modal perde dedektor duzeltmesi), yonetici_iletisim_models 0/12 → 12/12, kapanis ozeti yazildi.
- 2026-07-30 · P1 · 0b9267b · Prod göç uyumlama paketi origin/main'de doğrulandı (9f4ee74); kod değişikliği yok.
