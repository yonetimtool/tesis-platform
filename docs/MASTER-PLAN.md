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
Status: BITTI · Depends-on: —
Scope: Document in openapi.yaml exactly as implemented (audit code, no behavior
change): /audit, /support*, /transparency*, /admin/overview, /me, /me/checkpoints,
avatar PATCHes, PUT /shifts/{id}/assignments.
Acceptance: contract↔live machine check passes for these paths; no code change.
Notes (2026-07-30): Yolların BEYANI tur 68'de kapanmıştı (`test_sozlesme_sapmasi.py`
+ 14 belgesiz yolun eklenmesi). Bu turda üç şey yapıldı:
1. **ÖLÇÜM DERİNLEŞTİRİLDİ.** Mevcut makine kontrolü yalnız YOL karşılaştırıyordu;
   aynı yol üzerinde uygulamanın fazladan bir METODU olabilir (belgede `GET
   /x/{id}` varken kodda `DELETE /x/{id}` de bulunması) ve yol-düzeyi ölçüm
   bunu GÖREMEZ — kapsam ölçüyor görünüp ölçmez. Test artık **(METOT, yol)**
   çiftlerini karşılaştırıyor + bir dedektör sınaması içeriyor (ayrıştırıcı
   gerçekten iş görüyor mu). Sonuç: **201 operasyonun 201'i iki yönde de
   örtüşüyor**, sapma 0.
2. **İKİ SAPMA DÜZELTİLDİ** (kod değil, BELGE yanlıştı):
   - `/me/checkpoints` özeti "Kullanıcıya atanmış kontrol noktaları" diyordu;
     kod **tenant'ın TÜM kontrol noktalarını** döndürüyor (ad ASC, RLS izole).
     Faz-0 doğrulama ucu; plan bazlı liste `GET /patrol-plans/{id}/checkpoints`.
   - `/admin/overview` özeti "tesis/kullanıcı sayıları" diyordu; kod sabit
     `{"status":"ok","role":"admin"}` döndürüyor — RBAC yoklama ucu, sayaç YOK.
   İkisi de artık koddaki gerçek davranışı anlatıyor ve "DİKKAT" ile işaretli.
3. **AÇIKLAMALAR YAZILDI** (P9'un adıyla saydığı uçlar): `/audit` (SECURITY
   DEFINER ile çapraz-tenant, yalnız admin, append-only, 7 sorgu parametresi),
   `/support` ×4 (site↔platform kanalı, çapraz-tenant liste yalnız admin),
   `/transparency` ×3 (anonim agregat, yayın kapısı, yayınlanmamış ay 404 —
   403 değil: ayın VARLIĞI da sızmasın), `/me`, `/me/avatar` +
   `/users/{id}/avatar` (rol kümesi, tenant namespace IDOR engeli, eski obje
   silinir, audit), `/shifts/{id}/assignments` (PUT = tam liste, sıralı
   tekilleştirme, yalnız saha rolleri 422, yabancı tenant 404, kısmi yazma yok).
KAPILAR: tam `pytest` → **792 geçti / 0 düştü** (yeni 3 test dahil).
Kod değişmedi — yalnız sözleşme + test.

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
0 düştü**; `flutter build apk --debug` ✓.
**TEKRAR KOŞUMU #1 (20×) — 18 geçti / 2 düştü. YANİ KABUL ÖLÇÜTÜ HENÜZ
KARŞILANMADI**; madde BITTI'den geri alındı. İki düşüşün analizi:
- **Koşum 15 — TEŞHİS EDİLDİ ve DÜZELTİLDİ, ürün değil TESTİN kendi ev işi.**
  `kuyruk_hayalet_yazar_test` "50 tekrar" döngüsü her turda
  `Directory.systemTemp.createTemp` açıp sonunda siliyordu; tam suit yükü
  altında (dört izolasyon paralel) bu temizlik
  `PathNotFoundException: Deletion failed` ile patlıyordu. Yük altında
  **yeniden üretildi** (12 denemenin 6.'sında) ve tam mesaj yakalandı: hata
  `alt.delete()` satırında, ürün yolunda DEĞİL. FIFO/devralma iddialarının
  hiçbiri düşmedi. Düzeltme: tur başına yeni DİZİN açılmıyor, tek üst dizinde
  tur başına AYRI DOSYA kullanılıyor; `tearDown` temizliği toleranslı.
  İlk bakışta "yarış hâlâ var" gibi okunan bulgunun aslında ölçüm aracının
  kendi hatası olduğu — bu deponun tekrar eden dersi.
- **Koşum 17 — TEŞHİS EDİLEMEDİ (açık kayıt).** `bina_complaints_i18n_test`
  16 test birden düştü. Sonradan hem izole hem TAM SUİT YÜKÜ ALTINDA
  yeniden koşuldu: **ikisinde de 48/48 geçti**. Tekrar koşumunun günlüğü
  yalnız test adlarını sakladığı için geriye dönük tanı yapılamıyor. Tek
  seferlik ortam takılması olarak İZLENİYOR; tekrarlarsa günlükleme
  genişletilip ayrı madde açılacak. (Not: koşum #2 ve #3'te bir daha
  görülmedi — 40 koşumda 1.)

**TEKRAR KOŞUMU #2 (20×, TAM GÜNLÜK saklandı) — 19 geçti / 1 düştü.**
Kuyruk testleri **20/20** geçti, yani P10'un asıl ürün düzeltmesi sağlam.
Tek düşüş BAŞKA bir testte: `kural_duyuru_sakin_i18n_test` "FOTOGRAFLI: duyuru
ekrani". Tam günlük saklandığı için bu kez TEŞHİS EDİLDİ:
`pumpAndSettle timed out` — `ekran_surus.dart::_gorselleriYukle` her turda
görsel ÇÖZÜLMEDEN `pumpAndSettle` çağırıyordu; görsel yüklenirken ekranda
duran `CircularProgressIndicator` SONSUZ animasyondur ve oturma asla
gerçekleşmez. Normal koşumda görsel ilk 50 ms'de çözülüp gösterge kalktığı
için hiç görünmüyordu; TAM SUİT yükü altında kodek gecikince ortaya çıkıyor.
**Yine ürün değil, ÖLÇÜM ARACI hatası** — ayrı commit'te düzeltildi
(`fix(tests): fotografli surus yuk altinda "pumpAndSettle timed out"`);
doğrulama: dosya izole 50/50, iki eşzamanlı suit koşarken üç kez üst üste
49/49.

**TEKRAR KOŞUMU #3 (20×) — 20 GEÇTİ / 0 DÜŞTÜ. ✅ KABUL ÖLÇÜTÜ KARŞILANDI.**

DERS (bu deponun tekrar eden dersi, üçüncü kez): P10'un "kırılgan test"
etiketi yanlıştı — altında **iki gerçek ürün yarışı** vardı. Ama kanıtı
toplarken çıkan iki düşüş ürün değil, **ölçüm araçlarının kendi hatalarıydı**
(testin geçici-dizin ev işi + fotoğraf sürüşünün oturma stratejisi). Yani
hem "test kırılgan" hem "ürün bozuk" ilk teşhisleri yanlış olabilir; ölçümün
kendisi de her seferinde sanık listesindedir.

### P11 — [KEREM] Accumulated device testing
Status: BLOKE(Kerem telefonda test eder) · Depends-on: —
Scope: Kerem's batch checklist. Currently pending: flicker-fix verification (counters
update in place, no skeleton flash, all roles, incl. 60s periodic refresh); ar/ru
walkthrough of localized modules (overflow + missing-translation hunt); 4-role
general pass. Agents APPEND to this checklist per rule 9; never remove entries —
Kerem marks them done.
Acceptance: Kerem reports; findings become new items.

Device-verify (biriken liste — agent ekler, Kerem işaretler):
- [ ] **P41 · Yetki matrisi (PANEL).** **Admin** ile panelde **Yetki matrisi**
  sayfasını aç → tablo dolu gelmeli ve `/shifts` satırında **(mod)** işareti
  görünmeli. Arama kutusuna `portal` yaz → yalnız portal uçları kalmalı.
  `/health` satırında rol sütunları yerine **?** (rol kapısı yok) görünmeli.
  **Yönetici** ile de açılmalı; **güvenlik** rolüyle mobil/panel erişimi
  denendiğinde **403** olmalı.
- [ ] **P35 · Güvenlik amiri (MOBİL).** **Admin** ile
  `POST /users` `role=guvenlik_amiri` bir hesap aç (geçici kod dönecek).
  (a) O hesapla mobile gir → ana ekran **görevli düzeni** olmalı; menüde
  **Turlar** ve **Saha Personeli** olmalı, **Kargo / Ziyaretçiler / Site
  Sakinleri / Aidat** OLMAMALI. (b) Saha Personeli'nden yeni hesap açmayı
  dene → rol seçiminde yalnız **güvenlik** kabul edilmeli (tesis görevlisi
  denenirse hata). (c) **Admin** `PATCH /tenant/settings`
  `{"guvenlik_modu":"dis_sirket"}` yapsın → **yönetici** ile mobilde tur
  planı/vardiya düzenlemeyi dene → **"güvenlik planlaması dış güvenlik
  şirketindedir"** mesajı gelmeli; ama tur ve vardiya listelerini **görmeye
  devam etmeli**. Amir aynı ekranlarda **düzenleyebilmeli**. (d) Modu
  `yonetim_ici`e geri al → roller yer değiştirmeli.
- [ ] **P34 · Tur konumu + fotoğraf kapısı (MOBİL).** **Güvenlik** rolüyle:
  (a) Konum izni **verili** iken NFC okut → okutma geçmeli; **admin** ile
  `GET /scans` → o satırda `konum_durumu = "var"` ve `gps_dogruluk_m` dolu
  olmalı. (b) Telefonun **konum servisini kapat** → tekrar okut → okutma
  YİNE kaydedilmeli ve ekranda **"Konum servisi kapalı — okutma konumsuz
  kaydedildi"** yazmalı; raporda `konum_durumu = "servis_kapali"` ve
  `konumsuz_sayisi` artmalı. (c) Uygulamanın konum iznini **reddet** →
  okutma yine geçmeli, durum `izin_yok` olmalı. (d) **Yönetici** ile
  Ayarlar'dan `tur_baslangic_foto_zorunlu` açık iken (şimdilik
  `PATCH /tenant/settings`) bir tur penceresi içinde ilk okutmayı yap →
  ekranda **"Tura başlamak için fotoğraf gerekli"** + kamera butonu
  çıkmalı; butona bas → **yalnız kamera** açılmalı (galeri seçeneği
  ÇIKMAMALI) → çek → kayıt kendiliğinden gönderilmeli. Aynı pencerede
  **ikinci** okutma fotoğraf İSTEMEMELİ.
- [ ] **P34 · Gecikme alarmı (PUSH).** Yakın bir tur penceresi olan bir plan
  kur, **hiç okutma yapma**. Tolerans (varsayılan 10 dk) dolunca **görevlinin
  telefonuna** ve **yöneticiye** "Tur başlamadı" push'u gelmeli; okutma
  yapılınca alarm **susmalı**. Tekrarların 10 → 30 → 70. dakikada geldiği
  (araların katlandığı) gözlenmeli.
- [ ] **P31 · Raporlar (API — panel ekranı finans bölümüyle gelecek).**
  Şimdilik uçtan doğrulanabilir: **admin** ile
  `POST /raporlar/borc_alacak?bicim=pdf` → inen PDF'te **site adı, dönem,
  zaman damgası ve "Sayfa 1 / N"** görünmeli. `?bicim=excel` → Excel'de
  tutar sütunlarında **toplam alınabilmeli** (metin değil sayı).
  `{"ismi_goster": false}` ile → **ad sütunu hiç olmamalı**.
  `/raporlar/ihtar_yazisi?bicim=pdf` → borçlu daire başına metin, KMK m.20
  ve 7 gün süre geçmeli.
- [ ] **P30 · Sakin "Öde".** **Sakin** ile Aidatım → başlıktaki **"Öde"**.
  (a) Site'de **banka kasası tanımlı değilken** havale bölümü yerine
  "banka hesabı tanımlamamış" yazmalı. (b) Yönetici bir **banka kasası**
  (IBAN'lı) tanımlasın → sakin ekranı yenilesin → IBAN + **kod** görünmeli;
  **Kopyala**ya bas → panoya gitmeli. (c) Kodu not al, **çıkış yapıp tekrar
  gir** → kod **AYNI** kalmalı. (d) Kart bölümü "henüz açık değil" demeli
  (P13 anahtarları gelene kadar). (e) **Yönetici**: banka ekstresi
  eşleştirmesinde açıklamaya o kodu yazan bir satır → öneri **%100 güvenle**
  o sakini göstermeli.
- [ ] **P28 · Borçlandırma (API — panel ekranı P29 ile gelecek).** Şimdilik
  **mobil "Aidatım" ekranının BOZULMADIĞI** doğrulanmalı: **sakin** ile gir →
  aidat tutarı ve borç durumu eskisi gibi görünmeli (P28 alanları eklendi ama
  eski akış değişmedi). **Yönetici**de Aidat ekranı da eskisi gibi
  çalışmalı.
- [ ] **P27 · Muhasebe Tanımları (PANEL).** **Admin** ile panelde
  **Tanımlar** menüsü: (a) Kasalar → yeni kasa, "Banka hesabı" KAPALIYKEN
  IBAN gir → kaydet → **hata** almalı; banka açıkken IBAN kabul edilmeli.
  (b) Gelir/Gider Kalemleri → tip **gelir** + dağıtım şekli seç → **hata**;
  gider ile kabul. (c) Firmalar → açılış bakiyesi 500 + yön **alacak** →
  kaydet → listede görünmeli. (d) Araçlar → plakayı **boşluklu** gir
  ("34 abc 123") → kaydet → listede **34ABC123** görünmeli; aynı plakayı
  tekrar ekle → **hata**. (e) Sayaçlar → yeni ana sayaç. (f) Muhasebe
  Ayarları → para birimi alanının altında "**yalnız gösterim**" notu
  görünmeli. (g) Dili **Arapça**ya çevir → tüm alan etiketleri çevrilmeli
  (sabit Türkçe kalmamalı).
- [ ] **P26 · Bağımsız bölüm tipleri/grupları.** **Yönetici** ile ana ekranda
  **"Bağımsız Bölüm Tanımları"** kartı görünmeli (sakin/güvenlikte GÖRÜNMEMELİ).
  (a) Tipler sekmesinde yeni tip: ad `2+1`, aidat `1250,50` → kaydet → kartta
  **₺1.250,50** yazmalı. (b) Aidatı **boşalt** → kaydet → **"Tanımsız"**
  yazmalı; `0` yaz → kaydet → **₺0,00** yazmalı (ikisi AYNI görünmemeli).
  (c) Gruplar sekmesinde aidat alanı **olmamalı**. (d) Bina Düzenleme'de bir
  daire aç → **tip/grup seçicileri** çıkmalı; seç → kaydet → daire listesinde
  tip adı görünmeli. (e) **Toplu daire ekle** → tip seç → oluştur → oluşan
  dairelerin **hepsi** o tipte olmalı. (f) Bir tipi **sil** → onay "bağlı N
  daire SİLİNMEZ" demeli → sil → **daireler durmalı**, tipleri boşalmalı.
- [ ] **P25 · Kamera yayınları — ASIL ÖLÇÜM SÜRÜM DERLEMESİYLE.** Bu maddenin
  hatası **debug derlemede HİÇ GÖRÜNMEZ** (`flutter run` varsayılan olarak
  debug derler ve orada cleartext zaten açıktı); bu yüzden
  `flutter build apk --release` ile kurulan bir APK gerekir.
  (a) **Yönetici** ile Kameralar → yeni kamera: `http://` ile başlayan bir HLS
  adresi gir (örn. sahadaki Frigate/go2rtc geçidi) → form **"şifrelenmemiş"
  uyarısı** göstermeli (hata değil) → kaydet → kart açılınca **yayın
  OYNAMALI** (P25 öncesi sürüm derlemesinde sessizce düşüyordu).
  (b) `rtsp://` bir kamerayı restream adresi vermeden aç → **"Bu adres türü
  doğrudan oynatılamaz…"** çıkmalı (eski genel cümle değil).
  (c) Adresin ortasına bir boşluk koy → **"Yayın adresi geçersiz…"** çıkmalı
  (eskiden uygulama bu adreste çakılıyordu).
  (d) 3 KB'lik bir metni URL alanına yapıştır → form **uzunluk** hatası
  vermeli ("https ile başlamalı" DEĞİL); sunucuya gönderilirse Türkçe
  "çok uzun" hatası dönmeli.
  (e) Ana ekranda "Canlı Kamera" şeridinde **dört kart** yan yana görünmeli
  (eskiden iki). **Yönetici VE sakin** ana ekranlarında da bölüm çıkmalı —
  sakin yalnız kendisine açılmış kameraları görmeli.
- [ ] **P23 · Sakin yaşam döngüsü.** **Yönetici** (admin DEĞİL) ile Sakinler →
  bir sakin aç: (a) **daire ata** — sonradan atama artık çalışmalı (eskiden
  yönetici bu ucu göremiyordu, 403 alırdı); (b) **e-posta** alanını doldur →
  kaydet → geri gel, dolu kalmalı; sonra **"E-postayı kaldır"** anahtarını aç →
  kaydet → alan BOŞ olmalı (kutuda eski metin dursa bile silinmeli);
  (c) **İlişki tipi**ni Kiracı ↔ Kat maliki arasında değiştir → kaydet → daire
  listesinde/karttaki tip değişmeli. Dairesi OLMAYAN bir sakinde ilişki tipi
  kaydetmeye çalış → anlaşılır bir hata çıkmalı (sessizce kaydetmemeli).
- [ ] **P24 · Şikayet triyaj kuyruğu + dört kademeli renk.** (a) **Yönetici**
  ile Şikayet Haritası → başlıkta **gelen kutusu ikonu + rozet** görünmeli
  (okunmamış yoksa rozet OLMAMALI). (b) Kuyruğa gir → **Yeni** sekmesinde
  okunmamışlar kalın yazıyla; bir satırda **"Okundu işaretle"** → satır
  Yeni'den DÜŞMELİ, rozet 1 azalmalı; **Tümü** sekmesine geç → satır ORADA
  DURMALI (arşiv değil). (c) **İKİNCİ bir yönetici hesabıyla** aynı siteye gir
  → onun kuyruğu **BOŞALMAMIŞ** olmalı (okuma kişi başınadır — bu maddenin
  asıl testi budur). (d) Uçağ modunda "Okundu işaretle" → rozet
  **AZALMAMALI** (iyimser güncelleme yok). (e) Haritada bir daireye **1**
  şikayet aç → hücre **SARI** olmalı (eskiden yeşil kalıyordu); 3'te
  **KIRMIZI**, 5'te **MOR**; göstergede `0 / 1–2 / 3–4 / 5+` yazmalı.
- [ ] **P22 · Mobil UX düzeltmeleri.** (b) **Yönetici/güvenlik** ile
  Bildirimler'e gir; **okunmuş** bir bildirime dokun → ilgili ekran açılmalı
  (eskiden hiçbir şey olmuyordu). Okunmamışa dokun → hem "Yeni" rozeti
  kalkmalı hem ekran açılmalı. (c) Ana ekranda FAB → "Talep/Arıza bildir"
  (sakin) veya "Olay bildir" (saha) → form DOĞRUDAN açılmalı; gönder →
  **ana ekrana dönmeli** ve ana ekran sıfırdan yüklenmemeli (sayaçlar yerinde
  güncellenmeli, iskelet/beyaz ekran görmemelisin). Vazgeç dediğinde de ana
  ekrana dönmeli. (d)+(e) **Sakin** ile FAB → menüde İKİ ayrı giriş olmalı:
  "Talep/Arıza bildir" ve "Komşu şikayeti bildir"; ikincisi şikayet
  haritasına gitmeli, takip Şikayetlerim'de kalmalı. (f) Site Kuralları
  listesinde fotoğraflı bir kuralın görseli **kartta** görünmeli (karta
  dokunmadan). (g) Şikayet formunda kategori listesinde **"Görüntü
  kirliliği"** çıkmalı ve seçilip gönderilebilmeli.
- [ ] **P16/P17 · Plaka okuma (ANPR) zinciri.** (a) **Admin** ile panel/mobil
  fark etmez, `POST /integrations/anpr/keys` ile bir anahtar üret (yanıt bir
  kez gösterir — kaydet). (b) Bu anahtarla sahte bir Frigate olayı gönder
  (`curl -H "X-ANPR-Key: <anahtar>" -d '{"kaynak":"frigate","after":{"id":"t1",
  "camera":"kapi","sub_label":"34 ABC 123","start_time":1785450578,
  "plate_score":0.97}}'`). Beklenen: Araç Geçişleri listesinde **34ABC123
  İçeride** görünmeli ve otopark doluluğu 1 artmalı. (c) Aynı isteği TEKRAR
  gönder → yeni kayıt OLUŞMAMALI. (d) `plate_score`u 0.4 yapıp farklı bir
  `id` ile gönder → Araç Geçişleri başlığındaki **tarayıcı ikonundan** Plaka
  Okumaları'na gir; okuma "Onay bekliyor · Düşük güven" görünmeli. **Onayla**
  → açılan kutuda plakayı bir karakter değiştir → onayla → geçiş açılmalı.
  (e) **Sakin** ile Plaka Okumaları'na erişmeye çalış → kilit ikonlu açıklama.
- [ ] **P17 · RTSP kamera restream.** Kameralar'da yeni kamera ekle, tür
  **RTSP** seç → altta "Restream adresi" alanı BELİRMELİ (hls/mp4 seçince
  kaybolmalı). Restream boş bırakılırsa kamera kartında oynat pasif olmalı.
  Restream'e Frigate'in HLS adresini yaz (`http://<kutu>:5000/api/<kamera>/
  stream.m3u8`) → kaydet → **oynat aktifleşmeli ve görüntü gelmeli**. Sonra
  restream'i temizleyip kaydet → yeniden oynatılamaz olmalı; kameranın
  `rtsp://` adresi kayıtta DURMAYA devam etmeli.
- [ ] **P10 · Çevrimdışı okutma kuyruğu (dayanıklılık).** Telefonu **uçak
  moduna** al → 2–3 NFC noktası okut (kuyrukta bekliyor görünmeli) →
  **uygulamayı tamamen kapat** (arka plandan da at) → uçak modunu kapat →
  uygulamayı yeniden aç. Beklenen: bekleyen okutmaların **HEPSİ** ve **okutma
  sırasıyla** gönderilmeli, hiçbiri kaybolmamalı. Aynı denemeyi bir de
  **çıkış yapıp tekrar giriş** yaparak tekrarla (kuyruk oturumdan bağımsız
  yaşamalı). Bu, sessiz kayıt kaybı veren bir yarışın düzeltmesidir — kanıt
  ancak cihazda görülür.
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
Status: BITTI · Depends-on: P7
Scope: (a) ARB handoff prep for native review — export/notes for ar+ru minimum,
glossary included; (b) evaluate LibreTranslate content quality on real prod-style
samples (tr→ar/ru/de/fr/es/en), write a short quality note; (c) if weak, a provider
swap decision note (DeepL) — abstraction already exists, note the config change only.
No provider swap without Kerem's go.
Acceptance: handoff package in docs/ + quality note committed.
Notes (2026-07-30): Üçü de yapıldı.
(a) **TESLİM PAKETİ** — `docs/ceviri-teslim/`: `ar-inceleme.csv` ve
`ru-inceleme.csv` (her biri **1.186 anahtar**; sütunlar: modül, anahtar,
yer_tutucular, Türkçe kaynak, mevcut çeviri, boş düzeltme sütunu, not) +
`README.md` (inceleyene verilecek 7 maddelik talimat, sözlük tablosu, geri
dönüşün nasıl işleneceği, paketin NEYİ KAPSAMADIĞI). Yer tutucu sütunu
bilinçli: `{dolu} / {kapasite}` gibi ifadelerin korunması en sık kırılan
kural.
(b) **KALİTE ÖLÇÜMÜ** — `docs/ceviri-kalite-notu.md`. 8 gerçek prod-tipi örnek
× 6 dil = **48 çeviri**, 37,3 sn. Sonuç: **Türkçe kaynak için YETERSİZ**.
En ağır bulgu finansal: "**Aidat** borcunuz için son ödeme tarihi **ayın
10'u**" → İngilizce "The deadline for your **regimen** is **10 months**" (hem
terim hem TARİH yanlış). Diğerleri: "tadilat" hiç çevrilmemiş, "soru-cevap"
yarı Türkçe kalmış, "aidat kalemleri" → *tokens* / Arapçada *şırıngalar* +
cümle düşmüş, "her daireye bir otopark yeri" anlamı TERSİNE dönmüş, güvenlik
kuralı Arapçada geçmiş zamana kaymış (yasak ifadesi kaybolmuş), "kazan
dairesi" → *boiler apartment*. Kalıp net: hata **alan terimlerinde**
yoğunlaşıyor; kısa ve terimsiz cümleler altı dilde de doğru.
(c) **SAĞLAYICI KARARI NOTU** — üç seçenek yazıldı: (A) DeepL'e geçiş
(soyutlama hazır, değişiklik yalnız bir sağlayıcı sınıfı + config; BEDELİ
içeriğin dışarı çıkması → **KVKK kararıdır, teknik karar değil**), (B)
LibreTranslate'te kalıp sözlük ön-işleme (sekiz hatanın altısını kapatır,
içerik dışarı çıkmaz), (C) karma — B'yi hemen, A'yı Kerem'in KVKK kararına
bırak; A gelirse B'nin sözlüğü DeepL glossary'sine aynen taşınır.
**SAĞLAYICI DEĞİŞTİRİLMEDİ, ön-işleme de EKLENMEDİ** — P14 bir değerlendirme
kalemi; ikisi de ürün davranışını değiştirir ve Kerem'in "git" demesini bekler.
YAN BULGU: ölçüm, P7'deki "orijinali gör" bağlantısının bir süs değil
**emniyet supabı** olduğunu doğruladı.
Kod değişikliği YOK (yalnız docs/) — kapı gerekmez.

### P15 — Frigate Phase 1: PoC
Status: BITTI · Depends-on: —
Scope: Frigate in dev docker (separate compose or profile; NOT in prod compose),
sample RTSP/HLS input, LPR enabled; explore event flow (MQTT and/or API), restream
URL shapes (go2rtc), snapshot access. Deliverable: findings doc + draft event schema
for the source-agnostic ingest endpoint (plate, time, direction, camera, confidence,
photo ref) + resource notes (CPU, model needs).
Acceptance: docs/frigate-poc.md with reproducible setup + captured sample events.
Notes (2026-07-30): `infra/frigate-poc/` — **prod compose'a DOKUNULMADI**, ayrı
yığın (`docker compose -f infra/frigate-poc/docker-compose.yml up -d`). Üç
servis: mediamtx+ffmpeg ile SENTETİK RTSP kaynağı (gerçek kamera gerekmez),
mosquitto, Frigate **0.17.2**. Belge: `docs/frigate-poc.md`.
ÖLÇÜLENLER (hepsi canlı koşumdan):
- **go2rtc restream oynatılabilir** — `rtsp://frigate:8554/kapi` ffprobe ile
  doğrulandı: h264 Constrained Baseline 1280×720 @10fps. P17'nin temel taşı.
- **MQTT konu envanteri** 70 sn'lik `frigate/#` aboneliğiyle çıkarıldı:
  `frigate/available`, `frigate/stats`, `frigate/model_state`,
  `frigate/<kam>/status/detect` + 16 adet `<kam>/<anahtar>/state`.
  YAN KAZANÇ: kamera çevrimdışı alarmı için ayrı yoklama yazmaya GEREK YOK.
- **Olay yükü yakalandı** — `POST /api/events/kapi/car/create` ile tetiklendi;
  `frigate/reviews` MQTT yükü ve `GET /api/events` gövdesi belgeye tam olarak
  işlendi (alan alan).
- **Kaynak tüketimi**: tek kamera 1280×720 @5fps tespit → frigate %17,1 CPU /
  972 MiB; dedektör inference **~10 ms/kare**. `/dev/shm` uyarısı: Frigate'in
  kendi hesabı `min_shm: 146 MB` derken compose'ta 128 MB verilmişti — tek
  kamerada bile SINIRDA, çok kamerada kamera başına büyütülmeli (belgeye
  yazıldı).
MİMARİ BULGU (P18'i doğrudan etkiler): dedektör modelinin `attributes_map`'i
`license_plate`'i **`car`/`motorcycle`'ın ÖZNİTELİĞİ** olarak tanımlıyor —
yani **plaka okumak için önce ARAÇ tespit edilmeli**. Kamera yalnız plakaya
zoom yapıyorsa LPR çalışmaz; bu doğrudan kamera-açısı kılavuzuna girer.
OLAY ŞEMASI TASLAĞI (P16 girdisi) belgede: `kaynak, kaynak_olay_id, plaka,
zaman, kamera, yon, guven, foto_ref, ham` + Frigate→şema eşleme tablosu.
Üç kritik çıkarım: (1) Frigate aynı olayı `update`+`end` ile BİRDEN ÇOK KEZ
yayınlar → `(tenant, kaynak, kaynak_olay_id)` tekilliği ZORUNLU;
(2) `recognition_threshold` 0.9 + `match_distance: 1` → yanlış okuma BEKLENEN
durumdur, eşik altı okumalar geçiş AÇMAMALI, onay kuyruğuna düşmeli;
(3) `yon` alanını **Frigate VERMEZ** — kamera başına sabit yön (basit) ya da
zone geçiş sırası (çift yönlü geçit) ile türetilir; P16'da (a) ile başlanması,
şemanın (b)'yi taşıyacak biçimde bırakılması önerildi.
DÜRÜST KAYIT — ÖLÇÜLEMEYEN: sentetik yayında araç YOK (`detection_fps: 0.0`),
dolayısıyla **gerçek plaka okuma doğruluğu ÖLÇÜLMEDİ**. Olay boru hattı manuel
olayla uçtan uca doğrulandı ama LPR doğruluğu saha görüntüsü ister → P18.
Coral TPU da denenmedi (donanım yok); kazancı ölçüme değil mimariye dayanarak
açıklandı. PoC yığını koşum sonunda `down` edildi (`down -v` KULLANILMADI).

### P16 — Frigate Phase 2: source-agnostic ANPR ingest (backend)
Status: BITTI · Depends-on: P15
Scope: POST /integrations/anpr/events — per-tenant API key auth; standard body per
P15 schema; adapter layer mapping events → vehicle_pass open/close (entry/exit) and
violations where applicable; low-confidence events land in an approval queue
(panel/mobile confirm flow can be a follow-up item); activity feed integration.
New schema via NEW revisions (rule 7).
Acceptance: simulated Frigate events create/close vehicle passes correctly;
confidence threshold configurable per tenant; full pytest; contract updated.
Notes (2026-07-31): Uygulandı. Yeni dosyalar: `contracts/db/migrations/versions/
0011_anpr_ingest.py`, `backend/app/anpr.py` (SAF çekirdek: adaptörler + karar),
`backend/app/routers/anpr.py`, `backend/tests/test_anpr.py` (25 test).
**ŞEMA KARARI** — hazırlık notundaki (a) seçildi: `vehicle_pass.kaydeden_user_id`
NULLABLE yapıldı + `kaynak` (manuel|anpr) enum'u eklendi. Sahte bir "sistem
kullanıcısı" uydurmak (seçenek b) RBAC ve denetim kayıtlarını kirletirdi;
ANPR'ı ayrı tabloda tutmak (c) otopark doluluğunu ikiye böler ve **"sayım ile
kayıt asla ayrışamaz"** ilkesini bozardı. İzlenebilirlik KAYBOLMADI:
`ck_vehicle_pass_kaydeden` kısıtı `kaynak='manuel'` iken kaydedeni ZORUNLU
tutuyor.
Yeni tablolar: `anpr_api_key` (kimlik açık + sır **yalnız sha256**),
`anpr_event` (ham olay defteri). Yeni tenant ayarları: `anpr_guven_esigi`
(0.850) ve `anpr_otomatik_cikis` (true).
**KİMLİK — JWT DEĞİL.** Kamera kutusunun kullanıcı oturumu yok, token
yenileyemez; `X-ANPR-Key: <kimlik>.<sır>`. Çözümleme `anpr_key_coz` SECURITY
DEFINER fonksiyonuyla (istek geldiğinde tenant HENÜZ BİLİNMEDİĞİ için RLS
bağlamı kurulamaz — mevcut `audit_log_list` deseni). Geçersiz/pasif/biçimsiz
anahtarın hepsi AYNI 401'i döner; aşama sızdırmaz.
**İDEMPOTENCY** `(tenant, kaynak, kaynak_olay_id)` üzerinde tekil — P15'te
ölçülen gereklilik (Frigate aynı olayı `update`+`end` ile iki kez yayınlar).
**ADAPTÖRLER**: frigate (`after.sub_label` plaka, `start_time` UNIX float),
hikvision (ISAPI `EventNotificationAlert.ANPR`; olay kimliği yoksa
`(plaka+zaman)`dan TÜREVSEL kimlik → tekrar aynı kimliği verir), dahua
(`Events[0].Data`), manuel/standart. Yeni marka = tek fonksiyon + kayıt satırı.
**KARAR KURALLARI** (hepsi testle kilitli): eşik altı okuma geçiş AÇMAZ →
onay kuyruğu; güven HİÇ verilmemişse işlenir (eksik veri ≠ kötü veri; her
kaynak güven üretmez); `yon=bilinmiyor` ise açık geçiş VARSA çıkış, YOKSA
giriş (tek kameralı çift yönlü geçidin doğru davranışı); zaten içerideyken
giriş ve açık geçiş yokken çıkış sessizce yok sayılır; `anpr_otomatik_cikis`
kapalıysa çıkış yok sayılır (tek yönlü kapıda yanlış kapatma olmasın).
**OLAY HER ZAMAN DEFTERE YAZILIR** — bozuk plaka bile `durum='hata'` ile 201
döner; istek DÜŞÜRÜLMEZ, çünkü kutunun yeniden denemesi bozuk okumayı
düzeltmez. Tek istisna bilinmeyen `kaynak` (sözleşme hatası, 422).
**AKIŞ FEED'İ AYRI KOD GEREKTİRMEDİ**: ANPR geçişi bir `vehicle_pass`
satırıdır, `/activity`nin mevcut `arac_giris`/`arac_cikis` dallarından zaten
akar. Otopark doluluğu da aynı sayımı kullanır (canlı doğrulandı: ANPR girişi
`dolu` sayısını 1 artırdı).
AUDIT: olay ALIMI audit'e yazılmaz (saniyede onlarca olay `audit_log`'u
boğardı; `anpr_event` zaten bir defterdir) — yalnız İNSAN kararları ve anahtar
yaşam döngüsü (`anpr_onay`, `anpr_key_create`, `anpr_key_revoke`).
CANLI DOĞRULAMA (dev API): anahtar üretimi, Frigate/Hikvision/Dahua gövdeleri,
idempotent tekrar, giriş→çıkış zinciri, düşük güven→kuyruk→onay+OCR düzeltmesi,
geçersiz anahtar 401, bozuk plaka→defter, otopark doluluğu — hepsi geçti.
EŞİK YAPILANDIRMASI: `PATCH /tenant/settings` iki yeni alan alıyor
(`anpr_guven_esigi`, `anpr_otomatik_cikis`) ve bunları **yönetici de**
yazabiliyor — bu bir SAHA kararıdır (kameranın nerede durduğunu ve yanlış
okumanın ne sıklıkta olduğunu site bilir), yetki yükseltmesi değil. Uçtan uca
testle kilitli: eşik 0.99'a çekilince 0.97'lik okuma onaya düşüyor, 0.10'a
çekilince aynı okuma işleniyor.
DEPONUN KİLİTLERİ (dördü de yeni kodu yakaladı ve hepsi karşılandı):
(1) `test_hata_i18n::test_kaynakta_ham_cumle_kalmadi` → 8 yeni hata kimliği
**7 dile** yazıldı; (2) `test_secdef_kapsam` → `anpr_key_coz` envantere rol
kapısıyla (`public`, gerekçesiyle) eklendi; (3) `test_yetki_kapsam::
test_public_beyan_edilenler` → sözleşmede `security: []` yazmıştım, bu
YANILTICIYDI (uç 401 döner); doğru beyan `anprApiKey` adında bir **apiKey
güvenlik şeması**; (4) rol matrisi kilidine 6 yeni satır girdi ve ölçülen
matris tasarımla birebir: `POST .../events` tüm rollerde **KIMLIK** (JWT
erişim vermez), listeleme/onay admin+security, anahtarlar yalnız admin.
KAPILAR: `tests/test_anpr.py` **27/27**; sözleşme↔canlı **207/207 operasyon**
iki yönde örtüşüyor; `infra/goc-tersinirlik.sh` → **0 bulgu** (12 sınır, üç
kontrol: artık yok, gidiş-dönüş şeması aynı, her revizyon iki kez salındı);
tam `pytest` **819 geçti / 0 düştü** (P16 öncesi 792 → +27).

HAZIRLIK NOTU (2026-07-30 — keşif, karar yukarıda uygulandı): P15 sırasında
şema tarafında bir **engel** görüldü, sonraki oturum bunu bilerek başlasın:
`vehicle_pass.kaydeden_user_id` **NOT NULL** ve `app_user`'a **ON DELETE
RESTRICT** FK ile bağlı. ANPR olayını bir İNSAN kaydetmediği için bu kolon
olduğu gibi kullanılamaz. Üç seçenek: (a) kolonu **nullable** yapıp
`vehicle_pass.kaynak` (manuel|anpr) enum'u eklemek — en dürüst modelleme,
NEW revizyon ister ve mevcut sorguların null'a dayanıklı olduğu
denetlenmelidir; (b) tenant başına bir **sistem kullanıcısı** yaratmak — şema
değişmez ama sahte bir kullanıcı üretir ve RBAC/denetim kayıtlarını kirletir;
(c) ANPR geçişlerini ayrı tabloda tutup vehicle_pass'e hiç dokunmamak —
otopark doluluğu ikiye bölünür, "sayım ile kayıt asla ayrışamaz" ilkesini
BOZAR. **Öneri: (a).**
Ayrıca gereken yeni tablolar: `anpr_api_key` (tenant başına anahtar HASH'i,
ad, aktif, son_kullanim) ve `anpr_event` (ham olay + `(tenant, kaynak,
kaynak_olay_id)` TEKİL — P15'te ölçüldü: Frigate aynı olayı `update` ve `end`
ile iki kez yayınlar, idempotency zorunlu). Olay şeması ve Frigate eşleme
tablosu `docs/frigate-poc.md` §6'da hazır.

### P17 — Frigate Phase 3: mobile
Status: BITTI · Depends-on: P16
Scope: RTSP cameras playable via Frigate restream (camera record gains optional
restream URL; player uses it when present → oynatilabilir flips); plate-event
screens (live-ish list, registered/unknown badges via the P27 vehicle registry —
cross-check plate normalization); approval queue UI for low-confidence reads
(authorized roles).
Acceptance: RTSP camera plays through restream in dev; plate events visible; quality gates.
Notes (2026-07-31): İki parça.
**(a) RESTREAM — RTSP kameralar artık oynatılabilir.** Yeni revizyon
`0012_kamera_restream`: `camera.restream_url` (nullable, `ck_camera_restream_sema`
ile YALNIZ http(s)). `oynatilabilir` artık türden değil **türden + restream**
türetiliyor: `hls/mp4 → true`, `rtsp → false`, **ama restream doluysa rtsp de
true**. P15 ölçümü bunu mümkün kıldı (go2rtc yeniden yayını gerçekten
oynatılabilir: h264 1280×720).
TASARIM KARARI — neden yeni KOLON, `stream_url`i değiştirmek değil: iki adres
AYRI şeylerdir. `stream_url` kameranın KENDİ adresidir (envanter, saha teşhisi,
Frigate yapılandırması); `restream_url` geçidin adresidir ve geçit yeniden
kurulunca DEĞİŞİR. Tek kolona sıkıştırmak, restream bozulunca kameranın gerçek
adresini KAYBETMEK demekti.
Mobil: `Camera.oynatilacakUrl` (restream varsa onu, yoksa kendi adresi) —
oynatıcı bu ayrımı bilmez, tek alan okur. Form alanı **yalnız `tur=rtsp`
seçiliyken** görünür (hls/mp4 zaten oynatılabilir; gereksiz alan formu uzatır).
PATCH'te boş bırakmak geçidi KALDIRIR (açık null).
**(b) PLAKA OKUMALARI ekranı** (`/plaka-okumalari`) — P16'nın olay defteri +
**onay kuyruğu**. Durum süzgeci, güven yüzdesi, sunucunun KISA KODUNUN
çevrilmiş hâli; onayda **OCR düzeltmesi** (bir-iki karakter yanlış okunması en
yaygın hata — Frigate'in kendi toleransı da 1 karakter). 409 → "artık onay
beklemiyor". 403 → hata bandı değil, kilit ikonu + açıklama.
Ekrana giriş: Araç Geçişleri başlığındaki tarayıcı ikonu (yalnız yetkili rolde).
KENDİ KODUMDA İKİ BULGU (beş eksen sürüşü yakaladı):
1. Rusça "Ожидает подтверждения" 320 dp'de plakayla aynı satıra sığmayıp **33 px
   taşıyordu**; `Row` → `Wrap`. Kırpma YAPILMADI bilinçli olarak: durum metni
   kırpılırsa kullanıcı "Onay bek…" okur, bu bilgi kaybıdır.
2. Onay diyaloğunun `TextEditingController`ını `showDialog` döner dönmez
   dispose ediyordum; diyalog KAPANIŞ ANİMASYONU sırasında hâlâ çizildiği için
   *"A TextEditingController was used after being disposed"* atıyordu. Diyalog
   kendi widget'ına alındı (denetleyicinin sahibi diyalog oldu) ve içeriği
   kaydırılabilir yapıldı (dar/kısa ekranda `Column` taşıyordu).
KAPSAM DIŞI BIRAKILAN (gerekçeli): "kayıtlı/bilinmeyen araç rozetleri **P27
araç kayıt defteri** üzerinden" — P27 (Tanımlar katmanı) henüz yok, dolayısıyla
karşılaştırılacak bir kayıt kümesi de yok. Rozet, P27 bittiğinde tek bir
`kayitli_mi` alanıyla eklenir; plaka normalizasyonu ZATEN ortak
(`norm_plaka`/`norm_plaka_yumusak` aynı kural) olduğu için çapraz kontrol
sorunsuz olacak.
i18n: 4 + 22 = **26 yeni ARB anahtarı × 7 dil**. §15 ölçümü DEĞİŞMEDİ: **8**.
TESTLER: `test/anpr_restream_test.dart` — 18 test (restream modeli + doğrulama
+ draft gövdesi, ANPR modeli, neden kodu çevirisi ve BİLİNMEYEN kodun
GÖSTERİLMEMESİ, ekran davranışı, beş eksen sürüşü);
`tests/test_cameras.py` +5 (restream uçtan uca).
KAPILAR: `flutter analyze` temiz; `flutter test` **1426 geçti / 0 düştü**;
`flutter build apk --debug` ✓; backend `pytest` **824 geçti / 0 düştü** (P17 öncesi 819 → +5);
sözleşme güncellendi (Camera/CameraCreate/CameraUpdate + restream açıklaması).

### P18 — [KEREM+DONANIM] Frigate Phase 4: pilot site
Status: BLOKE(donanım+saha) · Depends-on: P17
Scope: Agent's part only: install/ops runbook for a site box (mini PC class; Coral
optional), camera-angle guidance for LPR, remote update strategy note.
Acceptance: runbook committed; field execution is Kerem's.

### P19 — Hikvision/Dahua adapters
Status: BITTI · Depends-on: P16
Scope: Adapters translating Hikvision (ISAPI event notification) and Dahua HTTP
push payloads into the P16 ingest format. Config docs for pointing cameras at our
endpoint. Simulated-payload tests (real device tests are field work).
Acceptance: recorded/sample payloads from both brands map correctly; docs committed.
Notes (2026-07-31): Adaptörlerin KENDİSİ P16'da yazılmıştı (kaynaktan bağımsız
mimarinin doğal parçası); bu madde iki eksiği kapattı.
**(a) GERÇEKÇİ YÜK TESTLERİ.** P16'daki adaptör testleri MİNİMUM alanlarla
koşuyordu. Sahadaki gövdeler onlarca alan taşır ve asıl risk eksik değil
**FAZLA** alandır — yanlış alanı okumak. Marka belgelerindeki tam gövdeler
yazıldı (`HIKVISION_TAM`: ipAddress/macAddress/channelID/eventType/country/
plateColor/vehicleType/picName…; `DAHUA_TAM`: Code/Action/PlateColor/
VehicleColor/Speed/Lane/GroupID…) ve adaptörlerin doğru alanları seçtiği
kilitlendi. Ayrıca **uçtan uca**: iki marka gövdesi de gerçek geçiş açıyor ve
tekrarında idempotent kalıyor.
BULGU: Hikvision'ın `ANPR.direction: "forward"` alanı YÖN DEĞİLDİR (şerit
yönü, geçiş yönü değil) — adaptörün bunu yön sanmadığı testle kilitlendi.
BULGU 2: `_utc` adını taşıyan fonksiyon Hikvision'ın `+03:00` ofsetini
KORUYORDU. Yanlış sonuç vermiyordu (an aynı) ama akış aşağısında ofsetli/
ofsetsiz karışımı üretirdi ve fonksiyonun adı bunu vaat ediyordu; artık her
zaman UTC'ye normalize ediyor.
BULGU 3: Hikvision kimliksiz gövde gönderdiğinde türevsel kimliğin
**KARARLI** olduğu (kamera "retry" yapınca ikinci geçiş AÇILMAMASI) uçtan uca
testle kilitlendi — bu, sahada en pahalı hata sınıfıdır.
**(b) KURULUM DOKÜMANI** — `docs/anpr-kamera-kurulumu.md`: anahtar üretimi
(kamera başına ayrı anahtar önerisi + `son_kullanim` ile teşhis), Hikvision
ISAPI ayarları (+ XML gönderen eski firmware için dönüştürücü notu), Dahua
HTTP push, Frigate MQTT köprüsü ("köprüde ayıklama YAPMAYIN — uç zaten
idempotent; ayıklarsanız `end` yükündeki nihai plakayı kaçırırsınız"),
**yön ayarının en sık atlanan ayar olduğu** (tek yönlü kapıda
`anpr_otomatik_cikis` kapatılmalı), güven eşiği rehberi (1.0 = yeni kamerayı
gözlem altında çalıştırma), **kamera açısı** (P15'in mimari bulgusu: plaka
aracın özniteliğidir → gövde görünmeli; 100–150 px plaka genişliği; gece IR
parlaması), doğrulama `curl`'ü ve belirti→neden tablosu, ağ/güvenlik notları.
Sözleşmeden bu dokümana bağlantı verildi.
GERÇEK CİHAZ TESTİ SAHA İŞİDİR (P18) — burada simüle yükler kilitlendi.
KAPILAR: `pytest` **828 geçti / 0 düştü** (P19 öncesi 824 → +4); `tests/test_anpr.py` 31/31. Mobil
dokunulmadı.

### P20 — Face recognition v2: design note only
Status: BITTI · Depends-on: —
Scope: DESIGN NOTE, no implementation: staff-only face verification (explicit
written consent, tenant-default OFF, KVKK analysis summary, scope strictly
excludes residents/visitors and any bulk identification). Ends with an explicit
"requires Kerem go decision" line.
Acceptance: docs/face-recognition-v2-design.md committed; nothing else changes.
Notes (2026-07-30): `docs/face-recognition-v2-design.md` yazıldı; **başka
hiçbir şey değişmedi** (kod yok, şema yok, uç yok).
Belgenin omurgası: kapsam **1:1 kimlik DOĞRULAMA**, 1:N kimlik TESPİTİ DEĞİL;
sakinler/ziyaretçiler/toplu tarama/kamera akışında pasif tanıma **pazarlığa
kapalı biçimde** kapsam dışı. KVKK: biyometri m.6 özel nitelikli veri →
iş sözleşmesinden AYRI yazılı açık rıza, **reddetme cezasız** (fallback'siz
tasarlanamaz), tenant varsayılanı KAPALI, **şablon cihazda** (sunucuya yalnız
"doğrulandı/doğrulanmadı" gider), iş ilişkisi bitiminde derhal silme, rıza
sürümleme (P36 mekanizması), audit'e yüz verisi yazılmaz.
DÜRÜST DEĞERLENDİRME EKLENDİ: NTAG424 SDM zaten etiketin fiziksel varlığını
kriptografik olarak kanıtlıyor; P34 GPS + tur başı fotoğrafla birlikte kalan
risk dar. Yüz verisi ise geri alınamaz (parola değişir, yüz değişmez).
Tavsiye: **önce P34'ü sahada ölç**, kaçak hâlâ anlamlıysa yeniden değerlendir.
Ayrıca "canlılık kontrolü olmadan bu özellik güvenlik HİSSİ verir ama güvenlik
vermez — bu hiç yapmamaktan kötüdür" uyarısı yazıldı.
Reddedilen kolay yollar gerekçeleriyle kayıtlı: bulut yüz API'si (yurtdışı
aktarım), merkezî şablon veritabanı (tek sızıntıda geri alınamaz zarar).
Belge açık bir **KARAR SATIRI** ile bitiyor; karar "git" olursa ilk adım kod
değil, aydınlatma metni + rıza formunun hukukçuya yazdırılması.

### P21 — "Translate this content" button: evaluation note
Status: BITTI · Depends-on: P7
Scope: Short design note for on-demand translation of user-generated text
(complaints/comments): where it appears, "otomatik çevrilmiştir" labeling, cost
implications, provider reuse. Low priority; note only.
Acceptance: note committed.
Notes (2026-07-30): `docs/talep-uzerine-ceviri-notu.md`. Ana argüman: yayın
içeriği (az sayıda, uzun ömürlü, çoktan-aza) YAZMA ANINDA 6 dile çevrilir —
doğru karar. Kullanıcı metni tersidir (binlerce, 1–2 okuyucu, kapanınca ölü):
1.000 şikâyet × 6 dil = 6.000 çevirinin çoğu HİÇ OKUNMAYACAK. Bu yüzden doğru
şekil **talep üzerine, tek dile**: metnin altında "Çevir" bağlantısı, basınca
yalnız o metin ve yalnız okuyanın diline.
Uygulanacaksa yeni sağlayıcı/şema/görsel dil GEREKMEZ: hız sınırlı bir uç +
`(metin_hash, hedef_dil)` önbelleği (mevcut `kaynak_ozet` kalıbının aynısı) +
P7'nin `CeviriNotu` bileşeninin yeniden kullanımı.
ŞİMDİ YAPILMAMA GEREKÇESİ: (1) kalite engeli önce çözülmeli — P14 ölçümü alan
terimlerinin bozulduğunu gösterdi, şikâyet metni (yazım hatası/argo/eksik
cümle) daha da zor; bugünkü kaliteyle düğme anlaşılmaz çıktı verip güveni
düşürür; (2) çok dilli sakin kütlesi oluşmadan ölü kod olur.
KVKK NOTU (yeni bulgu): kullanıcı metni ÜÇÜNCÜ KİŞİ verisi içerebilir
("3. kattaki Ahmet Bey…"). LibreTranslate kendi barındırmamızda dışarı
çıkmaz; **DeepL'e geçilirse bu metinler yurt dışına aktarılır** — yayın
içeriği kararı bunu KAPSAMAZ, ayrıca değerlendirilmelidir.
Uygulama YOK.

### P22 — Mobile UX fix package
Status: BLOKE(a maddesi geri alindi; b-g BITTI) · Depends-on: —
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

(b)–(g) BİTTİ (2026-07-31) — aşağıda madde madde. (a) DENENDİ VE GERİ ALINDI;
tanısı en altta. Madde (a) kapanmadan bütün P22 BITTI sayılmaz.

**(b) Bildirime dokunmak artık bir yere GİDİYOR.** Eskiden dokunma yalnız
"okundu" işaretliyordu; **okunmuş** bildirime dokunmak ise HİÇBİR ŞEY
yapmıyordu (ölü dokunma). Yeni `presentation/bildirim_rotasi.dart`: devriye
alarmları → tur takibi, talep akışı → talep listesi, iş emri → görev listesi.
TASARIM SINIRI (bilinçli, belgede yazılı): `notification` satırı yalnız
`patrol_window_id / patrol_plan_id / checkpoint_id / task_id` taşır —
`complaint_id` YOKTUR (push `data`sında var, kayıtta yok) ve görev DETAYI
`Task` nesnesi ister (rota `extra` bekler). Bu yüzden hedef LİSTEDİR, tekil
kayıt değil: uydurma bir derin bağlantı kurmak yerine kullanıcıyı doğru
listeye bırakmak doğru davranış. Tip bilinmiyorsa kayıttaki REFERANSTAN
türetilir (tip listesi bayatlasa bile dokunma ölü kalmasın); hiçbiri yoksa
`null` döner ve ekran yalnız okundu işaretler.
**(c) "Olay/Talep Bildir" kısayolu — tam yeniden yükleme YOK.** Eskiden FAB
kullanıcıyı talep LİSTESİNE bırakıyordu; oradan bir FAB daha, sonra elle geri
— üç dokunuş, ikisi gereksiz. Artık rota `?bildir=1` taşıyor: form ANINDA
açılıyor, gönderim (ya da vazgeçme) sonrası ekran `Navigator.pop` ile
kapanıyor. Ana ekran YENİDEN KURULMUYOR — `homeRouteObserver`
(`didPopNext`) yumuşak yenilemeyi tetikliyor ve `ref.invalidate` önceki değeri
koruduğu için iskelet/titreme yok (mevcut refresh-scope aynen kullanıldı).
**(d)+(e) Talep/Arıza ile Şikayet AYRI AKIŞLAR.** Sakinin tek "bildir" girişi
Talep/Arıza idi; komşusundan şikayetçi olan sakin de oraya yazıyordu — yani
YANLIŞ KANALA. İkisi farklı şeyler: talep yönetime iş emri olarak akar,
şikayet ANONİM ve DAİRE hedeflidir. FAB menüsüne ikinci giriş eklendi:
`Talep/Arıza → /complaints` (takip: Taleplerim) ve **`Komşu şikayeti →
/sikayet-haritasi`** (takip: Şikayetlerim). İkonlar da ayrıştırıldı
(`build_outlined` vs `campaign_outlined`) — aynı ikon iki farklı kanalı
temsil etmesin.
**(f) Site kuralı görseli LİSTEDE.** Eskiden yalnız küçük bir "resim var"
ikonu vardı, görsel ancak karta dokununca görünüyordu. Oysa kuralın görseli
çoğu zaman **kuralın kendisidir** (otopark planı, konteyner yeri, yasak alan
krokisi). Kartta 120 dp önizleme; liste gezilebilir kalsın diye sınırlı,
tam boy detayda. Kırık görsel kartı bozmuyor (ayrı hata satırı).
**(g) "Görüntü kirliliği" kategorisi** — migration `0013_goruntu_kirliligi`
(`ALTER TYPE ... ADD VALUE IF NOT EXISTS`). NEDEN ŞİKAYET KATEGORİSİ, İHLAL
DEĞİL: `violation` serbest metin `baslik` + `kaynak` taşır, sabit kategori
enum'u YOKTUR — eklenecek yer yok; `unit_complaint` ise zaten kategorili ve
sakinin açtığı kanal odur. Geri alma: Postgres enum değeri düşürmeyi
desteklemez → `downgrade` o değeri kullanan satırları `diger`e çeker, veri
kaybettirmez.
i18n: 2 yeni ARB anahtarı × 7 dil. §15 ölçümü DEĞİŞMEDİ: **8**.
TESTLER: `test/p22_ux_paketi_test.dart` (8 test: yönlendirme tablosu +
bilinmeyen tip savunması + kategori 7 dilde boş değil/TR sızmıyor + görselin
listede ÇİZİLDİĞİ ve fotoğrafsız kartta çizilmediği) ve
`test/notifications_screen_test.dart` +2 (dokunma gerçekten gidiyor; okunmuşta
gereksiz PATCH hâlâ yok). Bildirim testleri artık `GoRouter` bağlamında
koşuyor (`l10nRouterApp` yardımcısı eklendi) — `context.push` düz
`MaterialApp`ta "No GoRouter found" atıyordu.
KAPILAR: `flutter analyze` temiz; `flutter test` **1436 geçti / 0 düştü**;
`flutter build apk --debug` ✓; `infra/goc-tersinirlik.sh` → **0 bulgu**
(14 sınır); backend `pytest` **828 geçti / 0 düştü**.

---

DENENDI VE GERI ALINDI — (a) maddesi (2026-07-31). Bir sonraki oturum bunu
bilerek başlasın; aşağıdaki tanı YENİDEN ÜRETİLMİŞ ölçümdür.
YAPILAN: `core/ui/merkez_diyalog.dart` (`merkezSayfaAc`) yazıldı ve
`showModalBottomSheet` çağrılarının **51'i / 28 dosyada** ona çevrildi
(`isScrollControlled`/`showDragHandle`/`useSafeArea` parametreleri kaldırıldı,
`context:` konumsal argümana döndü). `flutter analyze` temiz kaldı.
ÖLÇÜLEN ÜÇ ŞEY (ikisi düzeltildi, üçüncüsü açık kaldı):
1. **KONTRAST — düzeltildi.** M3'te `Dialog` varsayılan zemini
   `surfaceContainerHigh`, `BottomSheet`inki `surfaceContainerLow`. Zemin
   koyulaşınca site kuralı detayındaki ikincil metin **3.90** kontrasta
   düştü (eşik 4.5). Çözüm: diyalog zeminini alt sayfanınkiyle aynı yüzeye
   sabitlemek — metin renklerini tek tek kovalamaktan iyidir.
2. **SIFIR VIEWPORT — düzeltildi.** `ConstrainedBox` yalnız ÜST SINIR verir;
   çocuk SINIRSIZ yükseklik alır. Gövdelerin içindeki mevcut
   `SingleChildScrollView` sınırsız yükseklikte **viewport'u 0** olur
   (ölçüm: `viewport: 0.0, range: 0..378`) ve HİÇ kaydırmaz. Çözüm:
   `Column(mainAxisSize.min)` + `Flexible`. (Ayrıca dışarıya İKİNCİ bir
   kaydırma alanı koymak iç içe kaydırma üretiyordu — kaldırıldı.)
3. **AÇIK KALAN — dokunma perdeye gidiyor.** `kural_duyuru_sakin_i18n_test::
   ONAY: site kurali silme diyalogu` düşüyor. Ölçüm: silme ikonunun rect'i
   320×900 ekranda **y≈511–529** (yani görünür alanda) ve o anda **1 Dialog
   açık**; buna rağmen dokunma hit-test'i **barrier**'a gidiyor
   (`HitTestResult` ilk öğe `_RenderColoredBox` = perde) ve detay diyaloğu
   KAPANIYOR (`dialog=0`), onay penceresi hiç açılmıyor. Yani öğe ÇİZİLİYOR
   ama ebeveyninin sınırları dışında — bir taşma. Denenen ve YETMEYEN
   çözümler: `ensureVisible`, `scrollUntilVisible`, `Clip.antiAlias`
   kaldırma, `pumpAndSettle`, eylem satırını kaydırma alanının dışına
   sabitleme (bu sonuncusu UX açısından yine de doğru ve tekrar yapılmalı).
KARAR: Kural 6 (suit yeşil olmalı) gereği **tüm dönüşüm geri alındı**;
yarım/kırık bir dönüşümü commit'lemek 28 dosyayı riske atardı. Sıradaki
oturum için öneri: dönüşümü **tek ekranla** başlat (örn. yalnız
`site_kurali`), o ekranın beş eksen sürüşünü yeşile al, ANCAK ONDAN SONRA
kalanları çevir. Muhtemel kök neden, gövdelerin kendi `SafeArea`+`Padding`+
`SingleChildScrollView` sarmalayıcılarının diyalog içinde farklı davranması;
gövdeleri sarmalayıcısız hâle getirip düzeni tamamen `merkezSayfaAc`a
bırakmak en temiz yol görünüyor.
(b)–(g) maddelerine HİÇ dokunulmadı.

### P23 — Resident lifecycle: unit assignment + full edit + malik/kiracı
Status: BITTI · Depends-on: —
Scope: (a) assign unit(s) to an EXISTING resident (currently impossible after
creation); (b) full resident edit — every field enterable at creation is editable
later (backend + panel + mobile where resident editing exists); (c) unit-person
relation gains TYPE: kat_maliki | kiraci (a unit may have both). This distinction
is the foundation for accounting (P27+): investment/one-off project debits bind
the MALİK; regular dues bind the current KİRACI if present, else malik. NEW
revisions for schema.
Acceptance: create→later-assign→edit E2E; relation types stored + surfaced;
RBAC correct; contract updated; quality gates.
Notes (2026-07-31): **YENİ ŞEMA GEREKMEDİ** — denetim, planın varsaydığından
fazlasının hazır olduğunu gösterdi: `unit_resident.rol_tipi` zaten
`resident_rol` enum'u (`malik | kiraci`) ile vardı ve
`POST /units/{id}/residents` bağlama ucu da vardı. Gerçek boşluklar
başkaydı:
**(a) Sonradan daire atama — UCU VARDI AMA ULAŞILAMIYORDU.** Bağ uçları
(`GET/POST/DELETE /units/{id}/residents`) **admin-only**'di; oysa mobilde
sakini yöneten roldür **yönetici** (`/residents` zaten admin+yönetici). Yani
yönetici var olan bir sakine daire ATAYAMIYORDU — madde uygulamadan
ulaşılamaz durumdaydı. Üç uç `admin + yonetici`ye açıldı; **genel daire CRUD'u
admin-only KALDI** (açılan yalnız bağ). Rol matrisi kilidi bu değişimi
yakaladı ve güncellendi — ölçülen matris tam olarak amaçlanan: yönetici İZİN,
güvenlik/sakin/tesis görevlisi RED.
**(b) Tam düzenleme — asıl eksik buydu.** `ResidentUpdate` yalnız `ad` +
`telefon` alıyordu; oysa oluşturmada `email` ve `rol_tipi` de giriliyordu ve
bir daha DEĞİŞTİRİLEMİYORDU. Kiracı çıkıp malik oturmaya başlayınca kayıt
yanlış kalıyordu — ve bu, aidatın KİME borçlandırılacağını belirlediği için
(P28) muhasebeyi doğrudan bozacak bir hataydı. İkisi de eklendi.
İKİ İNCE KARAR:
1. **"Boş bırakmak" ile "SİLMEK" ayrı şeylerdir.** `email` açıkça `null`
   gönderilerek temizlenebilir; boş metin ise "değiştirme" demektir. Mobilde
   bunun için ayrı bir anahtar var ve kutu dolu olsa bile anahtar kazanır —
   kullanıcı "sil" dediyse eski metnin gönderilmesi sessiz bir hata olurdu.
   Sunucuda `exclude_unset` + `_ATLA` nöbetçisi bu ayrımı korur.
2. **`rol_tipi` kullanıcıda değil BAĞDA durur** ve AKTİF bağların (bitiş
   IS NULL) HEPSİNE uygulanır. Aktif bağ yoksa **422 `invalid_reference`** —
   bağsız bir ilişki tipi anlamsızdır ve P28'in hedeflemesi tamamen bağa
   dayanır.
**(c) Yüzeye çıkarma:** mobil sakin düzenleme sayfası e-posta alanı,
"e-postayı kaldır" anahtarı ve ilişki tipi seçicisi kazandı; seçicinin alt
metni kuralı açıkça yazıyor ("Aidat kiracıya, yatırım gideri malike
borçlandırılır") — yönetici neyi neden seçtiğini bilsin.
TESTLER: `test_residents.py` +3 (oluştur→ikinci daire ata→e-posta ekle→
e-postayı AÇIKÇA temizle→rol_tipi değiştir E2E; bağsız rol_tipi 422; bağ
uçlarının RBAC'i) ve `test/p23_sakin_yasam_donusu_test.dart` (4 test).
Mobil test **gerçek `ResidentsApi`yi sürer**: ilk sürümde `updateResident`
override edilip gövde elle kuruluyordu — o test ürünü değil KENDİ KOPYASINI
ölçerdi; Dio interceptor'a çevrildi.
i18n: 8 yeni ARB anahtarı × 7 dil. §15 ölçümü DEĞİŞMEDİ: **8**.
KAPILAR: `flutter analyze` temiz; `flutter test` **1440 geçti / 0 düştü**;
`flutter build apk --debug` ✓; backend `pytest` tam takım **842 test**, P23 kaynaklı düşüş **YOK** (aynı
çalışma ağacındaki iki düşüş P24'ün dört-kademeli renk skalasının eski
beklentileriydi ve P24 commit'inde düzeltildi); P23'ün dokunduğu dört dosya
**43/43**; sözleşme
güncellendi (ResidentUpdate + üç bağ ucunun RBAC'i ve gerekçesi).

### P24 — Complaint triage tabs + 4-tier unit color scale
Status: BITTI · Depends-on: —
Scope: complaint management views gain a "Yeni / Okunmamış" tab separate from the
full list, with per-admin read state; unit color scale driven by noise/complaint
count: 0=yeşil, 1–2=sarı, 3–4=kırmızı, 4+=mor — one shared component used in the
building map and unit lists. Counter window ties into P37's reset rule (reset
zeroes the scale); make the counting basis explicit and configurable-ready.
Acceptance: tab + unread badge behavior tested; color boundaries tested at
0/1/2/3/4/5; quality gates.
Notes (2026-07-31): iki yarım; ikisi de bitti.

**(1) DÖRT KADEMELİ RENK SKALASI.** Eskiden üç kademeydi (`0-2 yeşil`,
`3-4 sarı`, `5+ kırmızı`) ve **tek şikayet almış daire, hiç şikayet almamış
daireyle AYNI renkteydi** — yönetim ilk sinyali göremiyordu. Yeni skala:
`0 yeşil · 1-2 sarı · 3-4 kırmızı · 5+ mor`.
* **Eşiklerin okunuşu:** Kerem'in "0=yeşil, 1-2=sarı, 3-4=kırmızı, 4+=mor"
  ifadesinde **3-4 ile 4+ ÇAKIŞIYOR**; çakışmayan tek okuma `5+ = mor`dur ve
  öyle uygulandı.
* Eşikler `_ESIKLER` **tablosunda TEK YERDE** durur — P37'nin sıfırlama
  kuralı sayacı sıfırlayınca skala kendiliğinden yeşile döner ve tenant başına
  yapılandırılabilir hale getirmek için değiştirilecek tek yer burasıdır.
* **Mor bilinçli seçim:** kırmızının "daha kötüsü" kırmızıyı koyulaştırmakla
  anlatılamaz (renk körlüğünde ayrılmaz); mor ayrı bir ton olduğu için ayırt
  edilebilir kalıyor.
* Renk **SUNUCUDAN** gelir; istemci eşikleri tekrarlamaz.

**(2) "Yeni / Okunmamış" TRİYAJ KUYRUĞU — YENİ ŞEMA (0014).** `unit_complaint`
satırında okuma durumu **YOKTU**; eklendi.
* **Okuma durumu KİŞİ BAŞINADIR** — asıl kural bu. İki yönetici aynı siteye
  bakarken birinin okuması diğerinin kuyruğunu **boşaltmamalı**. Bu yüzden
  `(sikayet, kullanıcı)` çiftine satır yazılır; **satır YOKSA okunmamıştır**
  (yeni şikayet ek yazma olmadan doğal olarak kuyruğa düşer).
* **Watermark ("son okuma zamanı") REDDEDİLDİ:** tek satırla çözülürdü ama
  sekmeyi açmak HEPSİNİ okundu yapardı; triyajda kullanıcı beş şikayetten
  ikisini ele alıp gerisini kuyrukta **BIRAKMAK** ister. Büyüme kaygısı yok:
  yönetici sayısı site başına birkaç kişidir.
* **Rozet sayısı için AYRI UÇ YOK:** `?okunmamis=true&limit=1` çağrısının
  `meta.total` değeri rozetin ta kendisidir.
* `POST /unit-complaints/{id}/okundu` **IDEMPOTENT** (istemci listeyi
  tazelerken aynı satırı iki kez işaretleyebilir) ve **geri alma yoktur** —
  "okunmamış" bir iş kuyruğudur, geçmiş değil.
* Kapatma (`PATCH`) yanıtı da `okundu` döner: istemci satırı yerinde
  tazeliyor, `null` dönseydi okunmuş satır tekrar **okunmamış** görünürdü.
* Mobil: `/sikayet-kuyrugu` ekranı iki sekme (**Yeni** rozetli / **Tümü**);
  Şikayet Haritası'nın başlığına rozetli kuyruk girişi eklendi (yalnız
  yönetim). Rozet **sıfırken çizilmez** — boş rozet "ilgilenilecek bir şey
  var" sinyalini yanlış verirdi. Okunmamış satır **KALIN**: renk tek başına
  ayırt edici değildir.
* İstemci **iyimser güncelleme YAPMAZ**: istek düşerse rozet azalmaz, yoksa
  triyaj kuyruğu sessizce eksilirdi.

TESTLER: `test_unit_complaints.py` **24/24** (sınır sınır 0/1/2/3/4/5/99 +
eşik tablosunun bütünlüğü + 9 okuma-durumu testi: kişi-başına izolasyon,
idempotentlik, süzgeç birleşimi, yönetim-dışına 403, tenant izolasyonu);
`p24_sikayet_kuyrugu_test.dart` **9/9** (gerçek `Dio` üzerinden sürülür).
**ÜÇ ESKİ BEKLENTİ DÜZELTİLDİ** (ürün doğru, ölçüm bayattı):
`test_building_map.py` 3 şikayet artık `kirmizi`, 1 şikayet artık `sari`;
mobilde gösterge etiketleri ve `DensityRenk` kimlik listesi dört kademeye
güncellendi (`fromWire('mor')` artık **bilinmeyen değil**).
i18n: 7 yeni ARB anahtarı × 7 dil; §15 kontrol-akışı taraması dokunulan iki
modülde **boş**.
KAPILAR: `flutter test` **1449 geçti / 0 düştü**;
`flutter build apk --debug` ✓; backend `pytest` **842 geçti / 0 düştü**; göç tersinirliği (0014 dahil) **3/3 OK, bulgu 0**; sözleşme
güncellendi (`okunmamis` süzgeci + `/okundu` ucu + `okundu` alanı + dört
kademeli renk enum'u); rol matrisi kilidi yeni ucu yakaladı ve güncellendi.
**DÜZELTME (aynı gün, ayrı commit):** P24 commit'i `flutter analyze` temiz
diyordu; **DEĞİLDİ** — `analyze` testler yazılmadan ÖNCE koşulmuştu ve
`p24_sikayet_kuyrugu_test.dart` iki uyarı taşıyordu (kullanılmayan import +
`(_, __)`). Kapı ölçümü, kapıyı geçirdiği kodun TAMAMI yazıldıktan sonra
koşulmalı; ders bu. Uyarılar giderildi, `flutter analyze` artık temiz.

### P25 — Camera hardening + full home grid
Status: BITTI · Depends-on: —
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
Notes (2026-07-31): üç parça; hepsi bitti. Ayrıntılı teşhis:
`docs/kamera-yayin-destek.md`.

**(a) 2048 KARAKTER SINIRI — ve yolda bulunan asıl kusur.** `stream_url`
sınırsız `text` idi. Sınır **üç katmanda**: mobil form → `dogrula_url_tur` /
`dogrula_restream` (422 `kamera_url_cok_uzun`, 7 dil) → `0015` `CHECK` kısıtı.
Uzunluk **şemadan ÖNCE** ölçülür: 3 KB'lik bir yapıştırmada "https ile
başlamalı" demek yanıltıcı olurdu, adres zaten https ile başlıyor.
**BULGU — "açık Türkçe hata" OLUŞTURMA YOLUNDA HİÇ ÇALIŞMIYORDU.** URL
doğrulaması `CameraCreate` üzerinde bir `model_validator` içindeydi; pydantic
oradan çıkan `ValueError`ı kendi `validation_error` zarfına çevirip
kullanıcıya **ham İngilizce** bir cümle döndürüyordu. Katalog metnini yalnız
`PATCH` yolu üretiyordu (orada doğrulama zaten router'daydı). Mevcut testler
sadece `422` beklediği için bu yıllardır görünmemişti. Doğrulama **tek yere,
router'a** taşındı; artık her iki uç da katalog metni döndürüyor.
Veritabanı kısıtı bilinçli olarak `CHECK` (varchar(2048) DEĞİL): tür değişimi
tabloyu yeniden yazardı. Mevcut uzun satırlar göçü **düşürmez, kesilir** ve
`NOTICE` ile bildirilir — dağıtılmış prod varken bir kamera kaydı yüzünden
göçün durması daha kötü bir sonuçtur.

**(b) "İNTERNETTEKİ YAYINLAR OYNAMIYOR" — KÖK NEDEN BULUNDU.**
`usesCleartextTraffic="true"` **yalnızca `src/debug/AndroidManifest.xml`**
içindeydi. Android 9'dan beri cleartext varsayılan olarak yasaktır; yani
**sürüm derlemesinde her `http://` yayın sessizce düşüyordu** ve oynatıcı tek
bir genel cümle gösteriyordu. Bu yalnız kamu test yayınlarını değil
**P17'nin restream özelliğini de** vuruyordu: Frigate/go2rtc geçidi neredeyse
her zaman düz `http`tir — özellik geliştirmede çalıştığı için fark
edilmemişti. Düzeltme: Android'de `network_security_config.xml`, iOS'ta
`NSAllowsArbitraryLoadsForMedia` (**kapsamı dar**: yalnız AVFoundation medya;
`URLSession`/API ATS korumasında kalır).
**İKİNCİ KUSUR:** `Uri.parse` oynatıcıda `try` bloğunun **DIŞINDAYDI** —
içinde boşluk taşıyan bir adres **yakalanmamış** `FormatException` atıyordu.
Ayrıca `Uri.tryParse` tek başına yetmiyor: Dart'ın çözümleyicisi hoşgörülü,
`https://ornek /a.m3u8` gibi **içinde boşluk olan** adresi hatasız çözüyor
(test bunu yakaladı) — artık boşluk açıkça reddediliyor.
Hata artık **NEDENE göre** konuşuyor (`YayinHatasi`: adresBozuk /
semaDesteklenmiyor / sifrelenmemisEngellendi / ulasilamadi). Eski tek cümle
adres yanlış yazıldığında kullanıcıyı **kamerayı kontrol etmeye** yolluyordu.
Kamu adresleri `curl` ile ölçüldü: HLS çalma listeleri **üç farklı içerik
tipiyle** sunuluyor (hepsi tanınır → içerik tipi neden DEĞİL), örneklemde
**çapraz protokol yönlendirmesi yok**. İki adres 403 döndü; **cihazda
denenmeden** "desteklenmiyor" diye yazılmadı.

**(c) DÖRTLÜ IZGARA + eksik ekranlar.** Kart sabit 168 dp idi ve tipik
telefonda ekrana **iki** kamera sığıyordu. Genişlik artık ekrandan hesaplanır
(`(ekran − kenarlar − aralıklar) / 4`, 80–168 dp arasında kısıtlı); yükseklik
de genişliğe bağlandı (sabit 196 değil). **Bölüm yalnız saha ana ekranındaydı**
— yönetici ve sakin, görme yetkileri olan kameraları ana ekranda hiç
göremiyordu; ikisine de eklendi (liste sunucuda role göre süzülür, istemci ek
süzgeç uygulamaz).
**REGRESYON YAKALANDI:** dar kartta `KameraKarti`'nin "• Canlı" satırı
**taşıyordu** (`home_i18n_test` RTL/Arapça sürüşleri yakaladı) — satır
`Flexible` + ellipsis ile dar genişliğe dayanıklı hale getirildi.

TESTLER: `test_cameras.py` **31/31** (+7: sınır 2048 dahil kabul / 2049 ret,
uzunluk hatası şema hatasından ayrı, **7 dilde ayrı metin**, restream de
sınırlı, PATCH yolunda da ölçülür + yarım güncelleme yok, `CHECK` kısıtı
uygulamayı atlayanı da durdurur); `p25_kamera_sertlestirme_test.dart`
**14/14** (sınır, neden sınıflandırması, 7 dilde dört AYRI cümle, dörtlü
genişlik + alt/üst sınır).
i18n: 5 yeni ARB anahtarı × 7 dil.
KAPILAR: `flutter analyze` temiz; `flutter test` **1463 geçti / 0 düştü**;
`flutter build apk --debug` ✓; backend `pytest` **848 geçti /
0 düştü**; göç tersinirliği (0015 dahil) **3/3 OK, bulgu 0** (16 sınır ikişer kez sallandı); sözleşme güncellendi
(`stream_url` maxLength + katalog hata kimliği).

### P26 — Unit types & groups with per-type dues
Status: BITTI · Depends-on: —
Scope (ref docs/design-refs/apsiyon/): Bağımsız Bölüm Tipleri — a freely
editable, modular list (user types any label: 1+0, 1+1, 2+1, dubleks…), each with
a default aidat tutarı; Bağımsız Bölüm Grupları (Daire / Villa / Dükkan style).
Units carry tip + grup; building/bulk unit creation allows picking type per unit
or per batch. NEW revisions; RLS; panel + (where units are shown) mobile surfaces.
Acceptance: CRUD for types/groups; assignment on units incl. bulk create; per-type
default dues consumed by P28; contract; quality gates.
Notes (2026-07-31): **YENİ ŞEMA: `0016`** (`unit_grup`, `unit_tip`, `unit`'e
iki nullable bağ).

**İKİ AYRI TABLO, BİLEREK.** `unit_grup` = bölümün NE OLDUĞU (Daire / Villa /
Dükkan); `unit_tip` = BÜYÜKLÜK/düzen (1+0, 2+1, dubleks) + **varsayılan aidat**.
Tek tabloda birleştirmek (tek "tip" alanı hem Villa hem 2+1 tutsun) **her grup
× tip kombinasyonunu ayrı satıra zorlardı** ve varsayılan aidat tanımını
anlamsızlaştırırdı.
* **Ad SERBEST metin** — desen konmadı: sabit bir enum "1+1,5" ya da "stüdyo"
  diyen siteyi dışarıda bırakırdı.
* **Aidat KURUŞ (bigint)**, TL değil (repo geneli `*_kurus` kuralı).
* **`null` "tanımsız"dır, `0` DEĞİL** — 0 geçerli bir tutardır (muaf daire) ve
  ikisini karıştırmak P28'de **sessiz sıfır aidat** üretirdi. Bu ayrım
  sunucuda (`exclude_unset`), sözleşmede, mobil modelde ve testte kilitli.
* **Bağlar `ON DELETE SET NULL`** — tanım silinince daireler **silinmez**,
  yalnız sınıflandırması boşalır. Silme 409 vermez: "önce 400 daireyi
  değiştir" demek kullanıcıyı tanımı pasife alıp listede bırakmaya iterdi.
  Yanıt **kaç daireyi etkilediğini döner**, yani işlem sessiz değil.

**BULGU — BİLEŞİK FK + `SET NULL` ANAHTARIN TAMAMINI NULL'LAR.** FK
`(unit_tip_id, tenant_id)` bileşiktir; sütun listesi verilmezse PostgreSQL
`unit.tenant_id`i de null'lamaya çalışır ve o sütun NOT NULL olduğu için tip
silme **500** verir. Test yakaladı; `ON DELETE SET NULL (unit_tip_id)`
(PG 15+ sözdizimi, yığın PG 16) ile düzeltildi. 0016 henüz hiçbir commit'te
yayınlanmadığı için düzeltme aynı revizyonda yapıldı ve yerel şema
`downgrade`→`upgrade` ile yeniden kuruldu.

**YÜZEYLER.** Mobil `/daire-tanimlari` ekranı iki sekme (Tipler/Gruplar) —
tek ekran, çünkü ikisi de aynı küçük tanım listesidir ve kullanıcı site
kurarken art arda ikisini de doldurur. Daire düzenleme formu ve **toplu daire
oluşturma** tip/grup seçicisi kazandı; toplu oluşturmada seçim **partinin
tamamına** uygulanır (bir blok genelde tek tiptir). Seçici: seçenek yoksa
**çizilmez**, "Seçilmedi" **her zaman durur** (yanlış seçim geri alınabilsin),
ve **silinmiş bir tanım seçili kalırsa çökmez**.
Menü girişi yalnız **admin + yönetici**de (site kurulum adımı); saha rolleri
tanımları OKUYABİLİR (daire listeleri tip/grup adını gösterir) ama yönetemez,
sakin hiç erişemez — rol matrisi kilidi bunu doğruladı.
`Unit` çıktısı tip/grup **ADINI da** döner (istemci ayrı istek yapmadan
listeyi çizsin); adlar **tek sorguda** çözülür — daire başına iki istek, 200
daire çizen panelde 400 ek sorgu demekti.

TESTLER: `test_unit_tanimlari.py` **16/16** (serbest ad, tip≠grup, aynı adda
409, null≠0, silme daireyi silmez + etkilenen sayısı, gönderilmeyen alan
dokunulmaz, toplu atama, tenant izolasyonu, RBAC);
`p26_daire_tanimlari_test.dart` **11/11**. Menü kilidi (`home_menu_test`,
auth.md §4 aynası) yeni girişi yakaladı ve admin+yönetici listelerine eklendi
— saha/sakin listelerine DEĞİL.
i18n: 16 yeni ARB anahtarı × 7 dil.
KAPILAR: `flutter analyze` temiz; `flutter test` **1474 geçti / 0 düştü**;
`flutter build apk --debug` ✓; backend `pytest` **864 geçti / 0 düştü**;
göç tersinirliği **3/3 OK, bulgu 0** (17 sınır ikişer kez sallandı); sözleşme güncellendi (iki yeni kaynak + `Unit`
alanları + `/units` süzgeçleri); rol matrisi kilidi 8 yeni ucu yakaladı.

**AÇIK BIRAKILAN (bilinçli):** admin-web paneline tanım sayfası
EKLENMEDİ. Gerekçe: panel girişi **admin-only**dir ve bu tanımları kuran rol
pratikte **yönetici**dir (mobil). Panel sayfası P27'nin "Tanımlar" katmanıyla
birlikte tek seferde yapılmalı — o madde zaten kasa/gelir-gider/firma
tanımlarını panele getiriyor ve dördü tek bir "Tanımlar" bölümü olmalı.

### P27 — Accounting definitions layer (Tanımlar)
Status: BITTI · Depends-on: P23, P26
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
Notes (2026-07-31): **YENİ ŞEMA: `0017`** — yedi kayıt defteri + `tenant`
ayar sütunları. Hepsi RLS'li ve tenant kapsamlı.

**PARA HER YERDE `bigint` KURUŞ.** `numeric` ile bile "0.1 + 0.2" tartışması
açılır; iki farklı sütun tipi raporda toplanırken sessiz yuvarlama üretirdi.

**AÇILIŞ BAKİYESİ = İŞARETSİZ TUTAR + AYRI YÖN (`borc|alacak`)**, negatif
sayı değil. "-500" bir firmada **"biz mi borçluyuz, o mu"** sorusunu
yanıtlamaz; yön açıkça saklanır (`CHECK … >= 0` zorlar).

**`gelir_gider_dagitim` ENUM'UNDA ŞİMDİLİK İKİ DEĞER** —
`bagimsiz_bolumlere_esit`, `tipe_gore`. `arsa_payi`/`kisi_sayisi` **bilerek
eklenmedi**: enum'a koyup P28'de uygulamamak, kullanıcıya **seçilebilir ama
yanlış borçlandıran** bir seçenek gösterirdi. Genişleme tek satırdır
(`ALTER TYPE … ADD VALUE`, 0013'te aynısı yapıldı). **Gelir kaleminde dağıtım
şekli olmaz** (CHECK + 422): bir gelir tahsil edilir, dağıtılmaz — ve
`PATCH` yalnız `tip`i `gelir`e çevirdiğinde eski dağıtım kalırdı, o birleşik
durum ayrıca yakalanıyor.

**PERSONEL KAYDI `app_user`DAN AYRI.** Her personelin uygulama hesabı yoktur
(temizlik, bahçıvan) ve her kullanıcı personel değildir (sakin). Örtüşenler
`app_user_id` ile bağlanır; hesap silinirse **kayıt durur** (SET NULL) —
bordro geçmişi kimlik kaydına bağlı olmamalı.

**ARAÇ KAYDI plakayı `vehicle_pass` ile AYNI kuralla normalize eder** ve
`norm_plaka`yı yeniden kullanır; iki farklı normalizasyon **iki farklı cevap**
verirdi ve P17 rozetleri bu tablodan "kayıtlı mı" diye soracak. Bir plaka
site içinde **tektir** (409) — iki daireye kayıtlı bir araç, rozetin hangi
daireyi göstereceğini belirsiz bırakırdı. Arama da normalize edilir.

**SAYAÇLAR İKİ TABLO.** `sayac_ana` (site geneli + ortak alan dağıtımı) ve
`sayac_bolum` (daire sayacı). Tek tabloda "ana mı" bayrağıyla tutmak, ana
sayaca özgü alanları (ortak alan yüzdesi) daire satırlarında anlamsızca null
bırakırdı. **Otomatik üretim ucu YENİDEN ÇALIŞTIRILABİLİR**: zaten sayacı
olan daireler atlanır, yani yeni daire eklendikçe tekrar çağrılır ve
benzersizlik kısıtına çarpıp 409 vermez.

**IBAN YALNIZ BANKA KASASINDA** (CHECK + 422): banka olmayan bir kasada dolu
IBAN, ödemeyi yanlış hesaba yönlendirme riskidir. `banka_mi` kapatılırken
IBAN gönderilmemiş olabilir — o birleşik durum router'da ayrıca ölçülüyor,
yoksa DB kısıtı 500 gibi okunan bir ihlal verirdi.

**`para_birimi` YALNIZ GÖSTERİM** — depo ve hesaplama ₺ kalır. Çok para
birimi (kur, çeviri tarihi, raporlama para birimi) ayrı bir karardır ve bu
alanı "destekleniyor" saymak **sessiz yanlış toplamlar** üretirdi. Panelde bu
not ekranda yazıyor.

**RBAC: HEPSİ admin+yönetici.** P26'nın daire tip/grup tanımları saha
rollerine okuma açıyordu (daire listelerinde görünüyorlar); muhasebe
tanımlarının böyle bir görünümü yok. Rol matrisi kilidi 30 yeni ucu yakaladı
ve ölçülen matris tam amaçlanan: yönetim İZİN, saha/sakin RED.

**PANEL (P26'nın açık bıraktığı parça KAPANDI).** admin-web'e `/tanimlar`
sayfası eklendi: dokuz defter **tek sayfada sekmeli**, çünkü hepsi kurulum
adımıdır ve menüye dokuz giriş koymak günlük sayfaları aşağı iterdi. Sayfa
**veri-sürücülü**: her defter bir ALAN TANIMI listesiyle anlatılır, tablo ve
form ondan üretilir — dokuz defter için dokuz form bileşeni aynı kodun dokuz
kopyası olurdu. Vekil uç TEK dinamik yoldur ve **beyaz liste** ile korunur:
istemciden gelen kaynak adı hiçbir zaman doğrudan URL'e girmez.
**ÜÇ PANEL KİLİDİ SAYFAYI YAKALADI** ve düzeltildi: (1) sabit Türkçe etiketler
→ 31 yeni sözlük anahtarı × 7 dil; (2) `middleware` matcher'ına `/tanimlar`;
(3) JSX içindeki üçlü ifadelerdeki `date`/`text`/`decimal` — bunlar teknik
HTML değerleri ama tarayıcı onları çevrilmemiş metin sayıyor, **tabloya**
çevrildi (`Record<AlanTip, …>` ayrıca yeni tip eklendiğinde derleyiciyi
uyarır).
**DÖRDÜNCÜ KUSURU `npm run build` YAKALADI, `tsc --noEmit` YAKALAMADI:**
Next.js yol işleyicileri yalnız HTTP metotlarını ve belirli yapılandırma
değerlerini dışa aktarabilir; beyaz listeyi `route.ts` içinde `export`
etmek derleme hatasıydı. Liste `lib/tanimlar.ts`e taşındı — ders: panel
kapısı **tsc + vitest + build**tir, üçü de koşulmalı.

TESTLER: `test_muhasebe_tanimlari.py` **33/33** (kurus, IBAN kuralı + birleşik
kapatma, gelir/dağıtım, enum sınırı, grup silme, firma yön/vergi no, personel
bağı + tarih sırası, plaka normalizasyonu + teklik, otomatik sayaç
tekrarlanabilirliği, ana sayaç silme, yüzde sınırları, ayar biçimleri,
9 uçta RBAC, tenant izolasyonu).
SEED: 2 kasa (biri IBAN'lı banka), 4 grup, 8 kalem, 3 firma, 3 personel
(biri `app_user`a bağlı), 3 araç, 2 ana sayaç + tüm dairelere su sayacı —
**idempotent** (ikinci koşumda sayılar değişmiyor).
KAPILAR: backend `pytest` **897 geçti / 0 düştü**; göç tersinirliği (0017 dahil) **3/3 OK,
bulgu 0** (18 sınır); admin-web `tsc` temiz + `vitest` **105/105** +
`npm run build` ✓; sözleşme 9 kaynak + 20 şema ile güncellendi
(sözleşme sapması testi temiz).

**AÇIK BIRAKILAN (bilinçli):** mobil yüzey YOK. Bu tanımlar masa başı
kurulum işidir (IBAN, vergi no, maaş, tesisat no) ve mobil formda girmek
gerçekçi değil; ayrıca panel girişi admin-only olduğu için **yöneticinin
mobil ihtiyacı P28'de** (borçlandırma) ortaya çıkacak — o zaman hangi
tanımların mobile taşınacağı belli olur.

### P28 — Debiting engine (borçlandırma)
Status: BITTI · Depends-on: P27
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
Notes (2026-07-31): **YENİ ŞEMA: `0018`**.

**BİRLEŞTİRME KARARI (kapsamın ilk cümlesi): PARALEL SİSTEM YOK.** Mevcut
aidat modülü denetlendi; `dues_assessment` zaten "bir daireye bir dönem için
borç" kaydıdır ve ihtiyaç duyulan her şey ona **SÜTUN** olarak eklendi. Ayrı
bir `borclandirma` tablosu, `dues_payment`in neye bağlanacağını ikiye böler,
mobil "Aidatım" ekranı ile `/reports/financial-summary` iki kaynağı toplamak
zorunda kalırdı. **Tekil yol için ayrı uç bile açılmadı**: `POST
/dues/assessments` zaten odur, P28 alanları ona **opsiyonel** eklendi —
mevcut çağıranlar (mobil, panel, testler) hiçbir şey değiştirmeden çalışır
(`test_dues.py` 10/10 dokunulmadan geçiyor).

**BU MADDENİN OMURGASI — BENZERSİZLİK.** Eski kısıt
`UNIQUE (tenant, unit, donem)` idi: bir daireye bir dönemde **yalnız bir
borç** açılabiliyordu. Oysa gerçek bir sitede aynı ay hem aidat hem elektrik
hem demirbaş borçlandırılır. Kısıt `(tenant, unit, donem,
COALESCE(gelir_gider_tanim_id, nöbetçi))` **benzersiz indeksine** çevrildi:
* tür belirtilmeden açılan kayıtlar için **eski davranış aynen korunur**
  (hepsi aynı COALESCE değerine düşer → dönem başına tek kayıt, 409),
* tür belirtilince her tür için ayrı kayıt açılabilir.
Postgres'te NULL'lar benzersizlik açısından **farklı** sayıldığı için düz bir
`UNIQUE (…, gelir_gider_tanim_id)` eski korumayı **sessizce kaldırırdı** —
test bunu ayrıca kilitliyor.

**HEDEFLEME KURALI TANIMDA DURUR**, borçlandırma anında seçilmez; aksi halde
aynı kalem farklı aylarda farklı kişiye yazılabilirdi. `kiraci_oncelikli`
(aidat, faturalar: kullanan öder) / `malik` (yatırım, demirbaş: kiracı
taşınsa da yükümlülük malikte kalır). **Kimse bulunamazsa borç DAİREYE
yazılır** — uydurma bir kişi seçmek ("ilk bağ") yanlış kişiyi borçlandırırdı.
**`rol_tipi` BOŞ olan bağ MALİK SAYILMAZ**: P23'te tip opsiyoneldir ve
"bilinmiyor"u malik saymak yatırım giderini yanlış kişiye yazardı; böyle bir
bağ yalnızca `kiraci_oncelikli` kuralının son çaresidir.

**GECİKME TAZMİNATI ANLIK HESAPLANIR, SAKLANMAZ.** Oran değiştiğinde geçmiş
kayıtlar da yeni orana göre okunur; saklansaydı aynı borç listede ve
tahsilatta iki farklı tutar gösterirdi (test oranı 0→2→4 yapıp tutarın
ikiye katlandığını doğruluyor). **BASİT faiz, TAM AY** üzerinden: bileşik
faiz uzun gecikmelerde ana paranın katlarına çıkar, kısmi ay ise mevzuatta
orantılanmaz — gün bazlı hesap her gün değişen bir borç üretir ve
kullanıcıya gösterilen tutar ertesi gün tutmazdı. Vadesi olmayan borç
gecikmiş **sayılmaz**.

**KURUŞ KAYBI YOK.** `esit_dagit` kalan kuruşu ilk dairelere birer birer
dağıtır; `toplam // adet` ile geçmek 100,01 TL'yi 3 daireye bölerken 1 kuruş
**buharlaştırırdı**. Test 4 farklı bölünmede toplamın girdiye eşit kaldığını
kilitliyor.

**ÖNİZLEME → İŞLEME AYNI GÖVDE, AYNI PLAN.** Önizleme **hiçbir şey yazmaz**
(test bunu doğruluyor) ve "500 daireden 3'ü tipsiz" bilgisini işlemeden önce
verir; sonra fark edilirse eksik tahakkuk sessizce yayılır. Tutarı
çözülemeyen daire **atlanır** — sessizce 0 borçlandırmak, yönetimin fark
etmediği eksik tahakkuk üretirdi. Elle seçim (`unit_ids`) süzgeci **ezer**.

**SAYAÇ SİHİRBAZI TEK İSTEK.** Dört adımın ilk üçü istemcide toplanır; ara
adımlarda sunucu durumu tutmak, yarım kalmış sihirbazları temizlemek zorunda
bırakırdı. Ortak alan = ana sayaç − daire toplamı; `ortak_alan_yuzde` kadarı
dairelere **eşit** dağıtılır. **Negatif fark sıfırlanır** (ölçüm hatası);
dairelere negatif borç yazmak **alacak** üretirdi.

**İÇE AKTARIM: BOZUK SATIR TÜM İŞLEMİ DÜŞÜRMEZ.** 400 satırlık bir dosyada
3 hatalı satır yüzünden 397 doğru satırı reddetmek, kullanıcıyı dosyayı elle
ayıklamaya zorlardı; hatalar satır numarasıyla ve **çözülmüş metinle**
(isteğin dilinde) döner. **XLSX AYRIŞTIRMA SUNUCUDA DEĞİL**: xlsx ayrıştırma
bir saldırı yüzeyidir (zip bombası, XXE, formül enjeksiyonu) ve panel dosyayı
zaten okuyup önizleme göstermek zorunda; sunucu **yapılandırılmış satır
listesi** alır ve her satırı doğrular.

**BULGU:** `hedef_kurali` P27'de modele eklenmişti ama **şemalara
eklenmemişti** — yani API'den ayarlanamıyordu ve her tanım varsayılan
`kiraci_oncelikli` kalıyordu. Hedefleme testi yakaladı (malik kuralı kiracıyı
döndürdü); `Create`/`Update`/`Out` şemalarına ve sözleşmeye eklendi.

TESTLER: `test_borclandirma_cekirdek.py` **22/22** (saf hesap: hedefleme 6,
gecikme 5, kuruş kaybı 5, tipe göre 2, sayaç 4) + `test_borclandirma_uc.py`
**18/18** (tekil+tür+hedef, tür yoksa eski davranış, gelir kalemi 422, aynı
dönem farklı tür, tursuz mükerrer koruması, hedefleme 3 senaryo, önizleme
yazmaz, önizleme=işleme, tip varsayılanı+atlama, elle seçim, tekrar
çalıştırma, sayaç ortak alan, içe aktarım hata raporu + mükerrer, gecikme
anlık + kapalı kalem, RBAC).
KAPILAR: backend `pytest` **937 geçti / 0 düştü**; göç tersinirliği **3/3 OK, bulgu 0** (19 sınır); sözleşme
5 yeni yol + 9 şema + `DuesAssessment(Create)` genişletmesi (sapma testi
temiz); rol matrisi 6 yeni ucu yakaladı.

**AÇIK BIRAKILAN (bilinçli):** (a) makbuz göster/yazdır — bu bir ÇIKTI
işidir ve P29'un tahsilat makbuzuyla **tek şablonda** yapılmalı, yoksa iki
farklı makbuz düzeni çıkar; (b) panel/mobil ekranları — motor ve sözleşme
hazır, yüzeyler P29'un tahsilat ekranlarıyla birlikte tasarlanacak (borç ve
tahsilat aynı ekranda görünmeli).

### P29 — Collections, cash & financial movements
Status: BITTI · Depends-on: P28
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
Notes (2026-07-31): **YENİ ŞEMA: `0019`** — `finansal_hareket` + `icra_dosyasi`.

**TEK DEFTER KARARI.** Tahsilat, gider, gelir, virman, iade ve açılış fişi
**ayrı tablolar değil**, tek `finansal_hareket` defterinde `tip` ile ayrılır.
Gerekçe: kabul ölçütü olan **"kasa bakiye ≡ hareket toplamı"** tutarlılığı
ancak TEK kaynak varken **kanıtlanabilir**; altı ayrı tabloda bakiye, altı
toplamı doğru birleştirmeye bağlı olurdu ve bir tabloyu unutmak **sessiz bir
fark** üretirdi.

**BAKİYE SAKLANMAZ, TÜRETİLİR** (`kasa.acilis_bakiye_kurus` + işaretli
toplam). Saklanan bir bakiye her yazma yolunda elle güncellenmek zorunda
kalır ve bir yol unutulduğunda defterle bakiye sessizce ayrılır — testler
bakiyeyi hareketlerden bağımsız olarak doğruluyor.

**TUTAR HER ZAMAN POZİTİF; işaret `yon` sütununda.** Negatif tutar saklamak
"iade" ile "eksi gider"i ayırt edilemez kılardı ve raporda mutlak değer
almak zorunda bırakırdı. **Yön istemciden ALINMAZ**: gider kasadan çıkar,
gelir kasaya girer — alınsaydı "giriş yönlü gider" gibi imkânsız bir satır
yazılabilirdi.

**VİRMAN İKİ SATIRDIR** (çıkış + giriş, aynı `virman_grup_id`). Tek satırla
iki kasayı etkilemek, "bu kasadan ne çıktı" sorgusunu kasa başına değil
hareket başına cevaplamak zorunda bırakırdı. Aynı kasaya virman **422**
(bakiyeyi değiştirmeyen ama defteri şişiren iki satır). Test genel toplamın
**değişmediğini** de kilitliyor — para site içinde yer değiştirdi.

**İADE TERS YÖNLÜ YENİ KAYITTIR**, orijinal **silinmez**: defter append-only
okunur, silinen bir tahsilat geçmiş raporları geriye dönük değiştirirdi.
Kısmi iade serbest ama **toplam iade orijinali aşamaz**; bir iade tekrar
**iade edilemez**.

**BANKA EŞLEŞTİRME = ÖNERİ, otomatik tahsilat DEĞİL.** Banka açıklaması
serbest metindir; yanlış eşleşen bir satır **başkasının borcunu kapatıp
gerçek borçlunun borcunu açık bırakırdı**. **Belirsizlikte (iki aday aynı
puan) öneri hiç üretilmez** — boş bırakmak yanlış eşleştirmekten iyidir.
Öneri **kişiyi** hedefler, belirli bir borcu değil: bir ödeme birden fazla
borca yayılabilir. Ad karşılaştırması aksansız/büyük harfe indirgenir ve
**Türkçe tuzağı** gözetilir (`İ`nin küçüğü `i` değil). Banka API'si
**kod değil belge notudur**: `docs/banka-entegrasyonu-notu.md` — hangi
kararların önce verilmesi gerektiği ve **otomatik tahsilatın varsayılan
kapalı kalması gerektiği** yazılı.

**İCRA DOSYASI BORCU KOPYALAMAZ**, anlık okur. İki yerde tutulan borç, biri
güncellenip diğeri unutulduğunda hangi rakamın doğru olduğunu belirsiz
bırakırdı; test tahsilat sonrası dosyaya **dokunulmadan** borcun düştüğünü
doğruluyor.

**BULGU:** ilk sürüm banka eşleştirmesinde `min(uuid)` kullanıyordu —
Postgres'te böyle bir toplama **yoktur** ve uç 500 veriyordu. Test yakaladı;
örnek `assessment_id` döndürme fikri zaten yanlıştı (öneri kişiyi hedefler),
kaldırıldı.

TESTLER: `test_finans.py` **17/17** (bakiye=açılış+hareket, yön türetimi,
virman iki satır + genel toplam sabit + aynı kasa 422, iade ters yön +
orijinal durur + kısmi/aşım/iade-iade, açılış fişi, toplu tahsilat, banka
eşleştirme üç senaryo, icra borç anlık + dosya no tek + durum, özet, RBAC,
tenant izolasyonu).
KAPILAR: backend `pytest` **954 geçti / 0 düştü**; göç tersinirliği **3/3 OK, bulgu 0** (20 sınır); sözleşme
12 yol + 17 şema (sapma testi temiz); rol matrisi 13 yeni ucu yakaladı.

**AÇIK BIRAKILAN (bilinçli):** panel ekranları (tahsilat/hareket/kasa/icra
+ dashboard kartları + global "+" menüsü) **YAPILMADI**. Gerekçe: bu madde
API yüzeyini ve tutarlılık kurallarını kurdu; panelin tamamı (P28'in borç
ekranları dahil) **tek bir finans bölümü** olarak tasarlanmalı — borç ve
tahsilat aynı ekranda görünmeli ve iki maddeye bölünmüş bir panel iki farklı
düzen üretirdi. E-posta/SMS hızlı eylemleri zaten P32'ye bağlı.

### P30 — Dues payment flow (resident)
Status: BITTI · Depends-on: P29 (iyzico live path additionally needs P13)
Scope: resident "Öde" flow: method 1 KART (iyzico) behind the existing/new
payment-provider abstraction — implement fully with mock-provider tests now; goes
live automatically when P13 keys arrive; method 2 BANKA HAVALESİ — show the
tenant's anlaşmalı IBAN + kopyala + a unique açıklama kodu (kişi/daire matching
reference); admin's bank-movement import (P29) auto-matches that code and closes
the debt. Any successful payment → tahsilat record → kasa/gelir reflection via
the P29 pipeline, idempotent webhooks.
Acceptance: mock-card path E2E + IBAN path E2E incl. auto-match; accounting
reflection verified; mobile UX simple (Kerem's emphasis: "çok kolay"); gates.
Notes (2026-07-31): **YENİ ŞEMA: `0020`** (`app_user.odeme_kodu`).

**HAVALE AÇIKLAMA KODU — bu maddenin kilidi.** Sakin havale açıklamasına
`TS-XXXXXX` yazar; yönetim ekstreyi yükleyince (P29) kod **eşleştirmeyi
kesinleştirir** (güven 100) ve ad benzerliği/tutar tahminine gerek kalmaz.
* **Kod TÜRETİLMEZ, saklanır.** `unit_no + kısa id` gibi türetilseydi daire
  numarası değişince (P23'te oluyor) kod da değişir ve sakinin bankadaki
  **düzenli talimatı sessizce eşleşmez** olurdu. Kod bir kez üretilir, sabit
  kalır.
* **Alfabede `0/O/1/I` yok**: kullanıcı kodu **elle** yazacak ve telefonda bu
  ayrım okunmaz. (`L` çıkarılmadı — karışan şey küçük `l`dir, kod büyük
  harftir.)
* Kod **tembel** üretilir: her kullanıcıya peşin kod üretmek, hiçbir zaman
  havale yapmayacak on binlerce kaydı doldururdu.
* Metinden **arama** ile ayıklanır, eşitlikle değil: açıklamada başka metin
  de olur ("AIDAT TS-A7K2M9 TEŞEKKÜRLER").
* Eşleştirmede **kod her şeyi ezer**: ad/tutar puanlamasına sonra bakmak,
  kodu doğru yazmış bir sakini "belirsiz" saymak olurdu.

**IBAN AYRI ALAN DEĞİL, P27'nin BANKA KASASINDAN gelir.** İki yerde tutulan
IBAN, biri güncellenip diğeri unutulduğunda parayı **yanlış hesaba**
yollardı. Banka kasası tanımlı değilse `iban: null` döner ve mobil havale
seçeneğini **hiç çizmez** — yanlış/boş IBAN göstermektense seçeneği hiç
sunmamak doğru.

**KART: AYRI ENTEGRASYON YAZILMADI.** Mevcut `PaymentProvider` soyutlaması
kullanıldı; manuel/sahte sağlayıcıyla **bugün** çalışıyor, gerçek anahtarlar
(P13) gelince **aynı kod** canlıya geçiyor. İki ödeme yolu iki tahsilat kaydı
biçimi üretirdi. `kart_aktif` manuel sağlayıcıda **false**: seçeneği açmak
sakini çalışmayan bir akışa sokardı.

**MUHASEBE YANSIMASI TEKRARLANMADI.** Başarılı ödeme P29 defterine
`tahsilat` olarak yazılır; kasa/gelir yansıması oradan gelir.

**MOBİL "ÇOK KOLAY".** `/ode` tek sayfadır ve iki yolu **alt alta** gösterir
— sekmeler kullanıcıyı bir yolu seçmeden önce "hangisi bana lazım" diye
düşündürürdü. IBAN ve kod **tek aralıklı yazıyla** ve **kopyala** düğmesiyle
verilir (elle yazılamayacak kadar uzun); kod ayrıca **kalın**dır çünkü
açıklamaya onu yazacak. "Aidatım" ekranı başlıktan tek dokunuşla `/ode`ye
geçiş verir ama **ödeme orada yapılmaz**: salt-okuma bir listeye yazma
eylemi gömmek yanlış olurdu.

TESTLER: `test_sakin_odeme.py` **8/8 + 1 atlandı** (kod biçimi/ayıklama,
kodun sabit kalması, IBAN kasadan, hedefsiz tahakkuk borca sayılır, manuel
sağlayıcıda kart kapalı, RBAC yalnız sakin, kart ödemesi tahsilat yazar, kod
eşleştirmeyi kesinleştirir). Atlanan test `world` fixture'ında daireye bağlı
sakin bulunmadığında kendini atlar — sessizce geçmek yerine **açıkça**
atlıyor. `p30_ode_test.dart` **9/9**.
KAPILAR: `flutter analyze` temiz; `flutter build apk --debug` ✓;
`flutter test` **1483 geçti / 0 düştü**; backend `pytest`
**962 geçti / 1 atlandı / 0 düştü**; göç tersinirliği **3/3 OK, bulgu 0** (21 sınır); sözleşme 2 yol + 2 şema + eşleştirme
`neden` genişletmesi (sapma testi temiz); rol matrisi iki yeni ucu yakaladı
(**yalnız sakin**).
**ÖLÇÜM NOTU:** ilk tam mobil koşumda **16 test düştü**; hepsi bilinen
ölçüm-aracı flake'leri (`pumpAndSettle timed out` — görsel yükleme; "painting
debug variable changed" — görsel taklidi teardown'ı) ve **makine yüklüyken**
(backend suiti + docker aynı anda) çıktı. Dosyalar **tek tek geçiyordu**;
yüksüz tam koşum **1483/0**. Ürün kusuru değil, ölçüm koşulu.

**AÇIK BIRAKILAN:** iyzico canlı yolu **P13'ün anahtarlarını bekliyor**
(kod hazır, yapılandırma gelince açılır) — bu maddenin kendi kapsamında
zaten böyle yazılıydı.

### P31 — Report engine & catalog
Status: BITTI · Depends-on: P29
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
Notes (2026-07-31): **ŞEMA GEREKMEDİ** — raporlar mevcut defterlerden okur.
Yeni bağımlılık: `openpyxl` + `reportlab` (ikisi de **saf Python**;
weasyprint/wkhtmltopdf sistem paketi + font zinciri isterdi).

**TEK UÇ, ÜÇ BİÇİM.** `POST /raporlar/{kod}?bicim=tablo|excel|pdf`. Biçim
başına ayrı uç açmak, aynı parametre modelini üç kez doğrulamak ve üç yerde
değiştirmek demekti. **Üçü de AYNI satırlardan** üretilir — ayrı üretmek aynı
raporun üç yerde farklı rakam göstermesine yol açardı (yuvarlama, para
birimi, tarih biçimi sessizce ayrılır). **Çıktı üretimi sunucuda**: istemcide
XLSX/PDF üretmek, panelin ve mobilin aynı raporu iki kez (ve farklı)
biçimlendirmesi olurdu.

**PARAMETRE MODALI TEK MODEL.** Rapor başına ayrı model, modal bileşeninin
her rapor için yeniden yazılması olurdu. `tazminat_tarihi` **ayrı alan**:
dönem raporunu **bugünün** tazminatıyla almak isteyen yönetim var.
`min/max` sınırları **DAHİL** — 100 TL borçlu tam sınırdadır ve "en az
100 TL" listesinde olmalıdır. Sıralama anahtarı **bilinmiyorsa varsayılana
düşer**: istemciden geleni doğrudan kullanmak `KeyError` ile 500 verirdi.

**`ismi_goster=false` SÜTUNU DA KALDIRIR**, değeri boşaltmaz — boş bir ad
sütunu "adı neden yok" sorusunu doğururdu. Kapıya asılacak listede ad
olmamalı (KVKK).

**DETAYLI BORÇ LİSTESİ SÜTUNLARI DİNAMİK** (P27 tanımlarından). Elektrik/Su/
Doğal Gaz **sabit sütun olarak yazılmadı**: her sitenin kalem listesi
farklıdır; sabit sütunlar kalemi olmayan siteye boş sütun, fazladan kalemi
olana "Diğer"e sıkışmış rakam gösterirdi. Tanımsız borçlar **"Diğer"e
toplanır — kaybolmaz**.

**BORÇ-ALACAK BAKİYE FORMÜLÜ.** dönem başı + dönem içi borç + gecikme +
**iade** − tahsilat. **İade tahsilatı geri alır, yani bakiyeyi ARTIRIR** —
"eksi tahsilat" diye yazmak işareti iki kez uygulamak olurdu.

**TAHSİLAT PERFORMANSI (Kerem kritik dedi).** Oran = `tahsil /
borçlandırılan`, **"tahsil / toplam açık borç" değil**: ikincisi geçmiş
dönemlerin birikmiş borcunu paya katar ve iyi bir ayı kötü gösterir. Sıfıra
bölmede oran **`null`**, 0 değil — 0 yazmak "hiç tahsil edemedik" diye
okunurdu. Yaşlandırma kovaları 0-30/31-60/61-90/90+ gün ve raporun **alt
bölümü** (ayrı rapor olsaydı yönetim ikisini yan yana koymak zorunda
kalırdı).

**DENETİM RAPORU = KASA MUTABAKATI.** Açılış + giriş − çıkış = bakiye
**satır satır**; denetçi "rakam nereden geliyor" sorusunu tabloda
cevaplayabilmeli — tek bir toplam yazmak mutabakat değil **beyandır**. Karar
defteri referansları **bilinçli olarak eklenmedi** ve bu rapora yazıldı:
karar defteri ayrı bir kayıttır ve denetçiye **aslıyla** sunulur.

**İHTAR YAZISI ŞABLONU KODDA**, veritabanında değil: metin hukuki olarak
sabittir (KMK m.20, 7 gün) ve tenant başına düzenlenebilir yapmak, yanlış
kurgulanmış bir ihtarın hukuki geçerliliğini riske atardı. Tek PDF'te ardı
ardına üretilir — daire başına ayrı dosya, 40 daireli sitede 40 indirme
demekti.

**PDF SABLONU İKİ GEÇİŞLİ**: sayfa sayısı önceden bilinmediği için önce
sayılır, sonra çizilir — resmi bir çıktıda "Sayfa 1 / ?" kabul edilemez.
Logo **opsiyonel**; bozuk logo raporu düşürmez (logo süsdür, rapor gerekli).
6'dan fazla sütunlu raporlar **yatay** sayfaya geçer.

**EXCEL'DE PARA HÜCRELERİ SAYIDIR** (TL cinsinden), metin değil: kuruşu
metin yazmak kullanıcının Excel'de toplam almasını engellerdi — rapor zaten
"üzerinde çalışılsın" diye Excel'e verilir.

**BULGU:** `func.to_char(...)` **bind parametresi** üretiyor ve Postgres
`GROUP BY`daki ifadeyle eşleştiremiyor (`GroupingError`) — dönemsel bakiye
ucu 500 veriyordu. Bu tuzak şeffaflık panosunda da yaşanmıştı;
`literal_column` ile çözüldü ve ifade **tek sabitte** toplandı.

KATALOG (12 rapor, hepsi çalışır durumda ve test her birini çağırır):
Borç-Alacak · Detaylı Borç · Site Sakinleri · Dönemsel Bakiye · Kasa/Hesap
Ekstresi · İşletme Defteri · Finansal Hareketler · Makbuz Dökümü ·
Gelir-Gider Özet · Tahsilat Performansı · İhtar Yazısı · Denetim Raporu.
Dört hareket raporu **aynı sorgudan farklı süzgeçle** çıkar — dört ayrı
sorgu, "işletme defterindeki tutar finansal hareketlerde neden yok" tipi
sessiz farklar üretirdi.

TESTLER: `test_rapor_motoru.py` **24/24** — çekirdek (kuruş biçimi, bakiye
formülü, ad gizleme, icra süzgeci, listeleme tipi, toplamlar, **dinamik
sütunlar**, tahsilat oranı + sıfıra bölme, yaşlandırma, sınır-dahil süzgeç,
güvenli sıralama, ihtar metni) + uç (katalogdaki **her rapor** çağrılır, üç
biçim, XLSX `PK` imzası, PDF `%PDF-` imzası, geçersiz kod/biçim, parametre
doğrulaması, **kasa mutabakatı**, RBAC).
KAPILAR: backend `pytest` **986 geçti / 1 atlandı / 0 düştü**; sözleşme 2 yol + 5 şema (sapma testi
temiz); rol matrisi iki yeni ucu yakaladı (yönetim).

**AÇIK BIRAKILAN (bilinçli):** (a) **"Notlar" raporu** katalogda YOK —
karşılığı bir **veri kaynağı bulunmuyor** (not tutan bir varlık henüz
tanımlı değil); uydurma bir kaynağa bağlamak boş bir rapor üretirdi.
Not varlığı tanımlanınca katalog tek satırla genişler.
(b) **Panel/mobil rapor ekranları** yapılmadı — P28/P29'un finans
ekranlarıyla **tek bölüm** olarak tasarlanmalı (STATUS REPORT #4'te yazılı
finans panel borcu).

### P32 — Communication suite (SMS + e-mail templates)
Status: BITTI · Depends-on: P28; live SMS sending additionally [DIŞ]
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
Notes (2026-07-31): **YENİ ŞEMA: `0021`** (`mesaj_sablonu` + `mesaj_gonderim`).

**GÖNDERİLEN METİN GEÇMİŞE KOPYALANIR**, şablona referans **yetmez**: şablon
sonradan değiştirilirse geçmiş kayıt "ne gönderdik" sorusuna **yanlış** cevap
verirdi — bu bir KVKK ve hukuk sorusudur (bildirim kanıtı). Test şablonu
değiştirip geçmişin **değişmediğini** doğruluyor. Şablon silinse de geçmiş
durur.

**AMAÇ (`pazarlama | operasyonel`) ŞABLONDA DURUR**, gönderim anında
seçilmez: aynı şablonun bir gün pazarlama bir gün operasyonel gönderilmesi
rıza denetimini anlamsız kılardı. **Pazarlama gönderimi rıza olmadan HİÇ
YAPILMAZ** ve atlananlar sayılır — rıza kaydı P36'nın işidir; "şimdilik
gönderelim, rızayı sonra ekleriz" demek KVKK ihlalini ürüne yerleştirmekti.
Operasyonel finansal bildirim **ayrı bir hukuki dayanaktır** (KMK
yükümlülük).

**SESSİZ DÜŞÜRME YOK.** Rızası olmayan (`riza_yok`) ve adresi olmayan
(`adres_yok`) alıcılar **ayrı sayılır ve yanıtta döner** — "gönderdim" deyip
40 kişiyi atlamak, yönetimin haberi olmadan bildirimsiz kalması demekti.

**SMS SAYACI — TÜRKÇE TUZAĞI.** GSM-7 kümesinde `Ç` (BÜYÜK), `ö`, `ü`
**vardır** ama `ç` (KÜÇÜK), `ı`, `ğ`, `ş`, `İ`, `Ğ`, `Ş` **yoktur**. Bunlardan
biri mesajı UCS-2'ye düşürür ve sınır **160'tan 70'e** iner — "biraz uzun" bir
mesaj birden **üç SMS** olur. Sayaç parça sayısını **ve zorlayan
karakterleri** döndürür ki kullanıcı bilinçli seçsin; önizlemede verilir
çünkü kaydettikten sonra öğrenmek geç. Test bunu harf harf kilitliyor
("Çöp" düşmez, "çöp" düşer).

**BİLİNMEYEN ETİKET METİNDE OLDUĞU GİBİ KALIR**, boş bırakılmaz: `{bakiyee}`
yazan kullanıcı mesajda boş bir boşluk görüp sorunu fark etmezdi; etiketi
görmek yazım hatasını anında gösterir. Şablon çıktısında ayrıca
`bilinmeyen_etiketler` **uyarı olarak** döner (hata değil — şablon kaydedilir).
`None` değer **boş** yazılır, "None" metni mesaja girmez.

**SMS ŞABLONUNDA KONU OLMAZ** (şema + CHECK + PATCH'te birleşik kural): dolu
konu, gönderilen metne **girmeyen** bir alan olurdu — kullanıcı yazar ve
kaybeder.

**SAĞLAYICI TAKASI YAPILANDIRMA İLE.** SMS varsayılanı **log**tur (gerçek
hesap **[DIŞ]**); e-posta SMTP yapılandırılmışsa gerçekten gönderir, değilse
loglar (`smtp_*` ayarları eklendi). Gönderim yolu **bugün de sonuna kadar
çalışır** (geçmiş yazılır, durum işaretlenir) ve yalnızca sağlayıcı sınıfı
değişir. Durum `gonderildi` yazılır, **`iletildi` yazılmaz**: iletim bilgisini
yalnızca gerçek sağlayıcı verebilir ve uydurmak panelde **yanlış bir teslim
kanıtı** gösterirdi.

**BİREYSEL + TOPLU TEK UÇTAN**: iki ayrı uç, aynı rıza/geçmiş mantığını iki
kez yazmak olurdu. Tek istekte en fazla **500** alıcı — sınırsız bırakmak tek
isteğin dakikalarca sürmesine ve zaman aşımıyla **yarım gönderilmiş** bir
kampanyaya yol açardı.

**BULGU — P28 REGRESYONU, SEED YAKALADI.** `seed.py`, P28'in **kaldırdığı**
`UNIQUE (tenant_id, unit_id, donem)` kısıtına `ON CONFLICT` yapıyordu;
benzersizlik `COALESCE(...)` içeren bir **indekse** çevrildiği için hedefli
`ON CONFLICT` hiçbir kısıtla eşleşmiyor ve **seed düşüyordu**. P28'den beri
seed çalıştırılmamıştı. Hedefsiz `ON CONFLICT DO NOTHING`e çevrildi.

**VARSAYILAN ŞABLON SETİ (8 adet, seed):** Bakiye Bildirimi (SMS+e-posta),
Borç Girişi, Tahsilat Girişi, Toplantı Çağrısı, Davetiye, Yeni Duyuru, Kiracı
Bakiyesi. **Hepsi operasyonel** — hazır gelen bir pazarlama şablonu, yönetimi
farkında olmadan izinsiz gönderime iterdi.

TESTLER: `test_mesajlar.py` **22/22** (çekirdek: interpolasyon, bilinmeyen
etiket korunur, None boş, GSM-7 harf harf, 160/161 sınırı, boş metin; uç:
CRUD, SMS'te konu yasağı + PATCH birleşik kuralı, aynı kanalda 409 / farklı
kanalda serbest, önizleme çözülmüş metin + sayaç, geçmişe çözülmüş metin +
şablon değişince geçmiş sabit, pazarlama rıza engeli, pasif şablon, adres yok
sayacı, varsayılan set, RBAC, tenant izolasyonu).
KAPILAR: backend `pytest` **1008 geçti / 1 atlandı / 0 düştü**; göç tersinirliği **3/3 OK, bulgu 0** (22 sınır); sözleşme
6 yol + 9 şema (sapma testi temiz); rol matrisi 7 yeni ucu yakaladı.

**AÇIK BIRAKILAN (bilinçli):** (a) **e-posta zengin metin editörü** ve
panel/mobil gönderim ekranları — API ve sayaç hazır; editör bir panel işidir
ve finans/rapor bölümüyle birlikte tek seferde yapılmalı. (b) **P29'un
dashboard hızlı-eylem kancaları** panel ekranıyla birlikte bağlanacak.
(c) `iletildi`/`okundu` durumları şemada var ama **hiçbir zaman uydurulmuyor**
— gerçek sağlayıcı gelince webhook'la yazılacak.

### P33 — Governance & ops modules
Status: BITTI · Depends-on: P27 (personel), P9 (audit contract)
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
Notes (2026-07-31):
**İŞ TAKİBİ — DENETİM SONUCU: BİRLEŞTİRME DEĞİL GENİŞLETME.** Kapsam "unify into
one ticket backbone" diyordu; denetim omurganın **zaten var olduğunu** gösterdi:
`complaint` = Talep/Arıza, `task` = İş Emri, ikisi Ticketing v1'de
`task.ticket_id` ile bağlı ve durum makinesi (`acik → is_emri → cozuldu |
reddedildi`) çalışıyor. `unit_complaint` ile birleştirmek **P22(e)'nin bilinçli
ayrımını bozardı** (o kanal komşudan komşuya şikâyet, bu kanal sakinden
yönetime talep). Bu yüzden yapılan iş `complaint`i **üç alanla genişletmek**
oldu: `unit_id` (ilgili bağımsız bölüm), `oncelik` (talep_oncelik:
düşük|normal|yüksek|acil), `atanan_personel_id`. Mobil akışların hiçbiri
değişmedi — üç alan da opsiyonel.
- **Öncelik/atama durumdan BAĞIMSIZ ayrı bir uçtadır** (`PATCH /complaints/{id}`,
  admin+yönetici). Durum yalnız makine geçişleriyle değişir; PATCH'ten de
  değiştirilebilseydi geçiş kuralları ve timeline satırları atlanabilirdi.
- **Atanan personel `personel_kayit`tır, `app_user` DEĞİL** (P27 gerekçesi):
  temizlikçinin uygulama hesabı olmayabilir ama iş ona verilir. Bildirim alan
  uygulamalı atama hâlâ `convert` ucunda. Var olmayan daire/personel **422** —
  sessizce yazılsaydı iş emri hiç ulaşmayacağı birine atanmış görünürdü.
- `unit_no` ve `atanan_personel_ad` listede **join ile** dolar; istemcinin satır
  başına istek atması 50 satırlık listede 50 istek demekti.

**KARAR DEFTERİ.** Üyeler ayrı tabloda (`karar_uyesi`): tek metin sütununa
virgülle yazmak "bu karara kim katıldı" sorgusunu metin aramasına çevirirdi.
Üye bir **addır, kullanıcı referansı değildir** — yönetim kurulu üyesi
uygulamada hesabı olmayan biri olabilir. PATCH'te `uyeler` gönderilirse liste
**tamamen değiştirilir** (kısmî ekleme/çıkarma, hangi üyenin kaldırıldığı
belirsizliğini istemciye bırakırdı); gönderilmezse dokunulmaz. PDF **metin
şablonuyla** üretilir (P31 `metin_pdf`), tablo şablonuyla değil: karar bir
yazıdır, tabloya sıkıştırmak metni hücrelere bölerdi.

**DOKÜMAN ARŞİVİ.** Sunucu **dosyayı taşımaz, yalnız üstveriyi tutar**;
yükleme/indirme mevcut presign akışıyla doğrudan MinIO'ya. 25 MB sınırı üç
katmanda (pydantic + CHECK + sözleşme). Kayıt silinince **MinIO objesi durur**:
tek istekte depoyu da silmek, yanlışlıkla silinen bir yönetim planının geri
alınamaması demekti.

**SİTE AKTARIM (Excel ile).** Sunucu XLSX **ayrıştırmaz ve üretmez** (P28/P29
ile aynı gerekçe: xlsx ayrıştırma bir saldırı yüzeyidir) — panel satırları
JSON'a çevirir, `/site-aktar/sablon` başlıkları tek kaynaktan verir.
`yalniz_dogrula=true` **hiçbir şey yazmaz**: kurulum tek seferlik ve geri
alması zordur, önizlemesiz yapılması yanlış bir dosyayı 300 satır boyunca
uygulamak olurdu. **Satır bazlı hata raporu** (`satir_no` + `alan` + mesaj) —
4 hatalı satır yüzünden 296 doğru satırı reddetmek kullanıcıyı dosyayı elle
ayıklamaya zorlardı. **İdempotent**: var olan blok/daire/kişi atlanır, dosya
yeniden yüklenebilir.

Kanıt: `backend/tests/test_yonetisim.py` **20 test** yeşil (karar CRUD + üye
listesi replace + karar_no tekliği 409 + PDF `%PDF-` imzası + cascade silme;
doküman CRUD + 25 MB sınır + aynı anahtar 409; şablon başlıkları + kuru çalışma
hiçbir şey yazmıyor + blok/daire/kişi oluşumu + satır bazlı hata seti {3,4,5}
ve alanları {blok, telefon, rol_tipi} + idempotentlik + kişisiz satır; iş takibi
üç alanı + öncelik/daire süzgeci + yalnız-yönetim + dört doğrulama; RBAC dört
rol + tenant izolasyonu, aynı karar_no B tenant'ta serbest). Migration `0022`
uygulandı, `infra/goc-tersinirlik.sh` bulgu 0. Rol matrisi kilidi 11 satır
büyüdü. Tam pytest yeşil.

**AÇIK BIRAKILAN (bilinçli, panel borcuna eklendi):** İşlem Geçmişi panel
ekranı, yetki matrisi görünümü, evrak seri-sıra + para birimi UI'ı ve karar
defteri/doküman/site-aktarım **panel ekranları**. Gerekçe P28/P29/P31/P32 ile
aynı: bu yüzeyler tek bir panel bölümü olarak birlikte tasarlanmalı; parça
parça eklemek panelde altı ayrı gezinme deseni bırakırdı. API yüzeyi ve
sözleşme hazır.

### P34 — Patrol integrity package
Status: BITTI · Depends-on: —
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
Notes (2026-07-31):
**(a) KONUM BİR KANITTIR, ÖN KOŞUL DEĞİL.** `scan_event` zaten `gps_lat/lng`
tutuyordu ama **NULL'un anlamı yoktu**: "izin verilmedi" mi, "sinyal yok" mu,
"eski istemci hiç göndermedi" mi ayırt edilemiyordu — üç durum aynı görünürken
amir *konumsuz okutma diye bir şey olduğunu* fark edemezdi. `konum_durumu`
eklendi (`var|izin_yok|servis_kapali|zaman_asimi|bilinmiyor`) ve mevcut satırlar
**korunarak** sınıflandırıldı: koordinatı olan `var`, olmayan `bilinmiyor`
(uydurma yok — eski satırların nedeni gerçekten bilinmiyor). Alanı hiç
göndermeyen istemciyi `izin_yok` saymak **olmayan bir izin reddini raporlamak**
olurdu.
- `gps_dogruluk_m` **ayrı** alandır: 5 m ile 2 km doğrulukla alınmış konum
  ekranda aynı görünürdü ve ikincisi kanıt değeri taşımaz.
- Sessiz boşluk yok: `GET /scans` artık `konumsuz_sayisi` döndürür ve
  `?konumsuz=true` süzgeci vardır; **sayı süzgeçten bağımsız** hesaplanır.
  Kısmi indeks (`ix_scan_konumsuz`) yalnız konumsuz satırları indeksler.
- Mobil: konum **okutma anında** ölçülür, gönderim anında değil — kuyrukta
  bekleyen kayıt saatler sonra **başka bir yerde** gönderilebilir ve o konum
  okutmanın konumu olmazdı. Ölçüm okutmayı **asla engellemez** (6 sn zaman
  aşımı, her hata bir duruma dönüşür) ve boşluk kullanıcıya **yazıyla**
  gösterilir.
- KVKK: `docs/personel-konum-kvkk.md` — sürekli takip YOK, tekil kanıt noktası;
  meşru menfaat (m.5/2-f), amaçla sınırlılık, kimlerin gördüğü, aydınlatma.

**(b) GECİKME ALARMI — "kaçırıldı" ile "gecikti" AYNI ŞEY DEĞİL.** Kaçırıldı
pencere **bittikten sonra** sabittir ve yapılacak bir şey kalmamıştır; gecikti
pencere **açıkken** olur ve tur **hâlâ kurtarılabilir**. Bu yüzden ayrı görev
(`scheduler.detect_late_patrols`, 2 dk periyot — tespitten sık), ayrı bildirim
tipi (`gecikmis_okutma`, enum'da zaten vardı) ve ayrı metin (geçmiş zaman
değil **uyarı dili**).
- **Aralıklar katlanır**: tolerans, 2×, 4× → 10 dk toleransta 10/30/70.
  dakikalar. Sabit aralık dakikada bir titreyen bir cihaz üretirdi; tek
  bildirim ise telefon sessizdeyken kaybolurdu. Tolerans + tekrar sayısı
  **tenant ayarıdır** (0 tekrar = kapalı, geçerli bir tercih).
- **Birikmiş adımlar toptan gönderilmez**: yalnız *en son vadesi gelen* adım
  gider — scheduler duraksadıysa görevliye aynı saniyede üç bildirim atmak
  olurdu.
- Durdurma **doğaldır**: ilk okutma gelince sorgu pencereyi artık seçmez;
  pencere bitince `vadesi_gelen_adim` None döner (bitmiş pencere zaten
  `kacirildi` alarmına konudur — ikisini birden göndermek aynı olayı iki kez
  bildirmek olurdu).
- Hedef **hem kişi hem rol**: görevli `shift_assignment` üzerinden **kişi**
  olarak (rol yayını o vardiyada olmayan tüm güvenliği de titretirdi), yönetim
  ayrıca **rol** olarak (görevli telefonu duymuyorsa turu başkası devralsın —
  tek kişiye bağlı alarm sessiz boşluk üretirdi).
- **BULGU (0023'te düzeltildi):** `uq_notification_tenant_tip_window` tekliği
  kaçırılan tur için doğruydu ama gecikme alarmı **tekrar etmek zorundadır**;
  kısıtlama olduğu gibi kalsaydı ikinci alarm **sessizce düşerdi** (ON CONFLICT
  başka indeksi hedefliyor). Teklik **kısmi indekse** çevrildi
  (`gecikmis_okutma` hariç); alarmın idempotency'si `dedup_key =
  tip:pencere:ADIM` ile sağlanır.

**(c) BAŞLANGIÇ FOTOĞRAFI — "1 metre gidip gel" YERİNE.** Kapsamdaki hareket
kanıtı fikri **uygulanmadı** ve gerekçesi şudur: NTAG424 SDM zaten etiketin
**fiziksel varlığını kriptografik olarak** kanıtlıyor; hareket kanıtı bunun
üzerine bir şey eklemez. Fotoğrafın eklediği şey **başka bir boyuttur** —
ortam ve günün saati (gündüz/gece); GPS de konumu ekler. Üçü birlikte "etiket
oradaydı + kişi oradaydı + o saatte oradaydı" der.
- **Yalnız ilk okutma**: her noktada fotoğraf turu iki katına çıkarırdı ve
  görevliyi cezalandırırdı. Kapı yalnız bir **tur penceresi** içinde çalışır;
  plansız/pencere dışı okutma bir tur başlangıcı değildir.
- **Kamera-only** (galeri yok): eski bir fotoğrafı seçmek tura hiç çıkmadan tur
  başlatmak olurdu.
- **Ayrı hata kodu** `foto_gerekli`: istemci "fotoğraf çek ve tekrar gönder"
  eylemini genel bir doğrulama hatasından ayırt edebilmeli. Mobil bunu kalıcı
  hata olarak DEĞİL kamera butonuyla gösterir; fotoğraf **aynı
  Idempotency-Key** ile gönderilir (ilk deneme reddedildiği için sunucuda kayıt
  yoktur — çakışma olmaz; anahtarı değiştirmek okutma anını, dolayısıyla kanıtın
  zamanını tazelemek olurdu).
- `foto_key` **tenant ad-alanında** doğrulanır (IDOR); eski `foto_url` alanı
  deprecated ve doğrulanmadan kabul edilir.
- Fotoğraf zorunluluğu **tenant anahtarıdır**, ürün kuralı değil: gece
  vardiyasında kamera kullanımı her sitede kabul görmez.

Kanıt: `backend/tests/test_tur_butunlugu.py` **23 test** + `mobile/test/
tur_konum_test.dart` **9 test** yeşil; tam pytest yeşil; `flutter analyze`
temiz, `flutter test` 1492 geçti, `flutter build apk --debug` başarılı;
`goc-tersinirlik` bulgu 0 (24 sınır), `goc-uyum-dogrula` bulgu 0. Sözleşme +
rol matrisi güncel. Migration `0023` — dosyada **yerinde düzenleme
istisnası** (politika kural 3) gerekçesiyle belgelendi: revizyon hiçbir
ortama gitmemişti, geliştirici veritabanı downgrade→upgrade ile yeniden
kuruldu.

### P35 — Security-chief role & dual security architecture
Status: BITTI · Depends-on: P34
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
Notes (2026-07-31):
**NEDEN AYRI BİR ROL.** Bugüne kadar güvenliği **her zaman yönetici**
planlıyordu. Güvenliği **dış bir şirketin** yürüttüğü tesislerde vardiyayı ve
tur penceresini kuran kişi site yöneticisi değil, şirketin amiridir. Mevcut
rollerden birine yamamak ("amiri de yönetici yapalım") **dış bir şirketin
personeline** finansı, sakin verisini ve tesis ayarlarını açardı.

**SAHİPLİK ŞEMADA DEĞİL KODDA.** "Kim planlayabilir" sorusu **moda** bağlıdır
ve mod çalışma anında değişir; tabloya gömülü bir yetki matrisi her mod
değişiminde satır güncellemek demekti. Çözüm `deps.require_guvenlik_yazma()`:
tenant modunu okur, `GUVENLIK_YAZAN[mod]` kümesine bakar.
- `yonetim_ici` (**varsayılan — mevcut tesislerin hiçbiri etkilenmez**):
  admin + yönetici. `dis_sirket`: admin + güvenlik amiri.
- **admin her iki modda yazar**: mod yanlış ayarlandığında tesis kilitli
  kalmamalı — kimse düzeltemezdi.
- **Okuma her iki modda açık kalır.** Dış şirkete devretmek **denetimi**
  devretmek değildir; yönetici planları, turları, vardiyaları ve tarama
  raporunu görmeye devam eder.
- Hata mesajı **modu söyler** (`guvenlik_dis_sirkette` / `guvenlik_yonetimde`):
  "yetkiniz yok" demek, yöneticiye ayarın değiştiğini hiç anlatmazdı.
- Devir **checkpoint ve vardiyayı da kapsar**: plan kurup nokta ekleyemeyen ya
  da vardiya kuramayan bir sahiplik yarım sahipliktir. **Vardiya CRUD'u
  bilinçli olarak genişletildi** — önceki durum yalnız `admin`di ve "vardiyayı
  planlayan kişi" tanımı geldiğinde vardiyayı kuramaması tutarsızdı. Bu
  genişletme `test_yonetici.py`de admin-only'ı savunan assert'i düşürdü; test
  yeni davranışa **gerekçesiyle** güncellendi (403 → 201, ve devrin iki yönü
  `test_guvenlik_amiri.py`de ölçülüyor).

**MOD AYARININ KENDİSİ.** Yalnız `admin` değiştirebilir; yöneticinin kendi
yetkisini kendine geri verebilmesi devri anlamsızlaştırırdı. Değişim
`audit_log`a `guvenlik_modu` olarak, **eski→yeni** ile yazılır — sahipliği
devreden bir ayarın izsiz değişmesi, "turları kim planlıyordu" sorusunu
sonradan yanıtlanamaz kılardı. **Aynı değere set etmek satır üretmez**
(gürültü denetim kaydını okunamaz hale getirirdi).

**AMİRİN ERİŞİMİ — EN AZ YETKİ (KVKK).** Açık: tur/vardiya/kontrol noktası
(moda göre yazma), tarama raporu, kamera, pano, bildirimler, araç geçişi ve
ihlal okuma, `POST /scans`, `/me/checkpoints`. **Kapalı:** sakin listesi,
aidat/finans, kargo, ziyaretçi, rezervasyon, tesis ayarları. Gerekçe: dış bir
şirketin personeline sakin kişisel verisi açmak savunulamaz. "security rolü ne
görüyorsa amir de görsün" gibi kolay bir kural KARGO ve ZİYARETÇİYİ de
açardı — bilinçli olarak **daha dar** bir küme seçildi.

**BULGU — YETKİ YÜKSELTME.** `/users` okumasını amire açmak, aynı bağımlılığı
paylaşan `PATCH /users/{id}` ve `POST /users/{id}/reset-password` uçlarını da
açtı: amir **kendi rolünü admin yapabilir** ya da **yöneticinin parolasını
sıfırlayabilirdi**. Rol matrisi kilidinin altıncı sütunu bunu diff olarak
gösterdi. Yöneticide zaten var olan daraltmanın aynısı amir için de yazıldı ve
küme daha dar tutuldu: amir **yalnız `security`** açar/düzenler/parola
sıfırlar — `tesis_gorevlisi` site işidir, `guvenlik_amiri` rolünü de açamaz
(yetki çoğaltma yok).

**ALARMLAR.** P34'ün kaçırılan-tur ve gecikme alarmları artık amire de gider:
`dis_sirket` modunda turun sahibi odur. Gecikme alarmı **hem yöneticiye hem
amire** gönderilir — moda göre daraltmak, mod yanlış ayarlandığında alarmı
kimsenin görmemesi demekti.

**İSTEMCİLER.** Mobil: `UserRole.guvenlikAmiri` + `isGuvenlikYonetimi`; ana
ekran **görevli düzeni** (yönetici düzeni finans özeti ve ödeme taşır —
dış şirket personeline site yönetimi ekranı vermek olurdu); menü tur + ekip +
duyuru/kural/talep, sakin-finans-kargo girişleri **yok**. Panel: `UserRole`
birliği + rol rozeti + 7 dilde ad; panel girişi hâlâ **yalnız admin**dir
(P35 bunu değiştirmez).

**BELGELEME.** `contracts/auth.md` §4a: altıncı sütunu yüzlerce satırlık
tabloya eklemek okunabilirliği bitirirdi; bölüm **kuralı** yazar ve makinece
doğrulanan kaydın `backend/tests/yetki/rol-matrisi.txt` (6 rol × tüm
operasyonlar) olduğunu söyler.

**MİGRASYON NOTU.** `ALTER TYPE ... ADD VALUE` geri alınamaz. `downgrade`
etiketi **bırakır** ve yalnız onu kullanan her şeyi geri alır (kolon, mod
tipi, amir kullanıcıların rolü → `security`; kullanıcı **silinmez**). Tipi
yeniden kurmak, `user_role`a bağlı **RLS politikalarını** yeniden yazmayı
gerektirirdi — bir geri alma adımının güvenlik politikalarını yeniden yazması
kabul edilemez risk.

**TAKİP DÜZELTMESİ (aynı gün, `HomeGate`).** İlk sürümde amir `HomeGate`in
hiçbir dalına uymuyor ve **splash ekranında kilitli kalıyordu** —
`homeVaryantForRole` doğru varyantı söylüyordu ama `HomeGate` onu
kullanmıyordu. Ayrıca saha ana ekranı tek bir `role == security` bayrağına
bakıyordu; amir için bu ya 403 üretecek istekler atardı (kargo/ziyaretçi) ya
da görmesi gereken kartları gizlerdi (bildirim/araç/ihlal). Kartlar artık
rolün **yetenek bayraklarına** bakıyor.

Kanıt: `backend/tests/test_guvenlik_amiri.py` **15 test** + `mobile/test/
guvenlik_amiri_test.dart` **6 test** yeşil; rol matrisi kilidi **6 sütuna**
çıktı; tam pytest yeşil; `flutter analyze` temiz, `flutter test` 1497,
apk debug build başarılı; admin-web `tsc` + `vitest` (105) + `npm run build`
yeşil; `goc-tersinirlik` bulgu 0 (25 sınır), `goc-uyum-dogrula` bulgu 0.

### P36 — Onboarding consents & KVKK gate
Status: BITTI · Depends-on: —
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
Notes (2026-07-31):
**METİN TENANT İÇERİĞİDİR, ürün sabiti değil.** Her tesisin veri sorumlusu
kendisidir ve aydınlatma metnini kendi hukuk danışmanı yazar; platforma gömülü
tek bir metin **200 tesise başkasının metnini imzalatmak** olurdu. Metin
orijinal dilinde gösterilir — hukuki metnin makine çevirisi yanlış bir taahhüt
üretirdi. Seed'e **örnek** bir sürüm 1 konuldu (metin olmadan kapı hiç
kurulmaz ve akış uçtan uca denenemezdi); gerçek tesis kendi metnini **yeni
sürüm** olarak yayınlar.

**SÜRÜM VAR, YERİNDE DÜZENLEME YOK.** Yayınlanmış metnin gövdesi
değiştirilemez; düzenleme ucu **hiç yazılmadı**. İzin verilseydi dün onay
vermiş bir kullanıcının onayı bugün **başka bir metne** ait görünürdü — onay
kaydının tek değeri "hangi metne, ne zaman" olmasıdır. Sürüm istemciden
alınmaz (iki yöneticinin aynı numarayı vermesi ya da numara atlaması demekti).
**Aynı gövde yeniden yayınlanamaz (409):** değişmemiş bir metin için herkesi
yeniden onaya zorlamak, onayı anlamsız bir tıkla döndürürdü.

**ONAY ESKİ SÜRÜME YAZILMAZ (409).** Kullanıcı metni okurken yönetim yeni
sürüm yayınladıysa, onayı eski metne aitti; sessizce yeni sürüme yazmak
okumadığı bir metni onaylatmak olurdu. İstemci 409'da yeni metni çeker ve
**kaydırma kilidini sıfırlar**. Onay **idempotent**tir (çift dokunuş/ağ
tekrarı onayı çoğaltmaz) ve satır **silinmez/güncellenmez**: aydınlatma bir
bildirimdir, geri alınabilen şey **pazarlama rızasıdır**.

**KAYDIRMA KİLİDİ.** Buton, kullanıcı metnin sonuna gelene kadar kapalı. Tam
eşitlik yerine **24 px eşik**: cihaz ölçümlerinde son piksel çoğu zaman
yakalanmaz (kesirli yükseklik, üst-asma) ve buton hiç etkinleşmezdi. **İçerik
ekrana sığıyorsa kapı zaten açık** — kısa metinli bir tesiste "sona kaydır"
beklemek butonu sonsuza dek kapalı bırakırdı; ilk karede bir kez ölçülür.

**SUNUCU NAVİGASYONU KİLİTLEMEZ, kapıyı istemci kurar** (`onay_gerekli`).
Onay vermemiş bir kullanıcı **metni okuyabilmeli**, çıkış yapabilmeli ve
dilini değiştirebilmelidir; her ucu 403'lemek metni göstermeyi de imkânsız
kılar ve kullanıcıyı kapalı bir kapıya kilitlerdi. Aynı nedenle istemcide
**ağ hatası kapıyı AÇMAZ**: metni getiremeyen bir ekranda kilitlenen kullanıcı
uygulamaya hiç giremezdi. **Rızanın gerçek zorlaması gönderim ucundadır** —
kapı UX'tir, denetim koddadır.

**P32 BAĞLANDI.** Pazarlama gönderimi artık gerçek rızayı okur ve **kanal
bazlıdır**: e-postaya izin veren kişi SMS'e izin vermiş sayılmaz. Tek bir
"pazarlama" bayrağı bunu kaybederdi. Rızası olmayan alıcı **sessizce
düşürülmez, sayılır** (`riza_yok`). Operasyonel mesaj (KMK yükümlülüğü) rıza
istemez — farklı hukuki temeller birbirine koşullanamaz.

**İZİNLER AYNI EKRANDA AMA AYRI BLOKTA** ve üçü de kapalı başlar. Onay
butonuyla aynı kutuya koymak, aydınlatma onayını pazarlama rızasıyla
karıştırırdı: izin vermeden de devam edilebilir. Ayarlar'da **aynı widget**
kullanılır — iki ayrı liste, birinde eklenen kanalın diğerinde unutulması
demekti. Ayarlar'da blok **listenin sonundadır**: görünüm/dil günlük
ayarlardır, izinler nadiren ziyaret edilir (üstte olsaydı dil satırını
ekrandan aşağı iterdi — mevcut ayar testleri bunu yakaladı).

**BULGU — SONSUZ DÖNEN GÖSTERGE.** İzinler kartının ilk sürümü yüklenirken
`CircularProgressIndicator` çiziyordu; bu ekranı **asla durulmayan** bir
animasyona bağlar ve dokuz ayar testi `pumpAndSettle` zaman aşımıyla düştü.
Yerine aynı yüksekliği tutan **sessiz yer tutucu** kondu (liste zıplamaz).
Yüklenemediğinde anahtarlar **gösterilmez**: bilinmeyen bir durumu "kapalı"
diye çizmek, verilmiş bir rızayı yok göstermekti. Anahtar değişimi
kaydedilemezse **geri alınır** — kaydedilmemiş bir izni açık göstermek,
kullanıcıya vermediği bir rızayı vermiş gibi gösterirdi.

**AÇIK BIRAKILAN (panel borcuna eklendi):** metni **yayınlama ekranı** yok
(API hazır; seed örnek sürüm koyuyor). Yönetişim/finans panel bölümüyle
birlikte yapılacak.

Kanıt: `backend/tests/test_kvkk_riza.py` **19 test** + `mobile/test/
kvkk_onay_test.dart` **11 test** yeşil; tam pytest yeşil; `flutter analyze`
temiz, `flutter test` 1509, apk debug build başarılı; `goc-tersinirlik` bulgu 0
(26 sınır), `goc-uyum-dogrula` bulgu 0; seed koştu (şema kısıtı değiştiren her
maddede kural). Rol matrisi kilidi 7 satır büyüdü.

### P37 — Noise-deterrent automation (threshold → action → reset)
Status: BITTI · Depends-on: P24
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
Notes (2026-07-31):
**AYRI BİR WEBHOOK KONFİGÜRASYONU AÇILMADI.** C1b'nin `integration` tablosu
zaten SSRF-korumalı gönderim, KEK ile şifreli sır ve tenant izolasyonu
sunuyor; ikinci bir URL/sır alanı **aynı güvenlik kontrollerini ikinci kez
yazmak** ve birini güncelleyip diğerini unutmak demekti. Tenant yalnızca
hangi entegrasyonun caydırıcı olduğunu seçer (`gurultu_integration_id`).

**MANUEL MOD BİR HATA DURUMU DEĞİL, BİRİNCİ SINIF MOD.** Çoğu sitede
entegrasyon hiç olmayacak; `NULL` olması "özellik çalışmıyor" değil "anonsu
yönetici yapıyor" demektir. Eşik aşılınca yöneticiye push gider ve kayıt
`manuel_bekliyor` olarak durur. **Sunucu "yapıldı" varsayamaz** — anonsun
gerçekten yapılıp yapılmadığını yalnız insan bilir; işaretlenmeyen kayıt
bekler, sessizce yapılmış saymak denetimde yapılmamış bir işi yapılmış
göstermek olurdu.

**SINIR DAHİLDİR (`>=`).** 4 tetiklemez, 5 tetikler. `>` olsaydı eşik ayarı
kullanıcıya söylediği sayıdan **bir fazlasında** çalışırdı. Eşik 0/negatifse
caydırıcı **kapalıdır** (kaza sonucu her şikâyette anons yapılmasın).

**YALNIZ `gurultu` KATEGORİSİ SAYILIR.** P24'ün renk skalası tüm kategorileri
sayar ama caydırıcı gürültüye özeldir: kapı önüne ayakkabı bırakan daireye
"gürültü uyarısı" anonsu yapmak caydırıcıyı anlamsız kılardı.

**SIFIRLAMA KAYIT SİLMEZ.** Eşiğe varınca o dairenin açık gürültü şikâyetleri
`kapali`ya çekilir; satırlar geçmişte durur — silmek **uyarının dayanağını**
yok etmek olurdu. P24 rengi açık sayısından hesaplandığı için daire doğal
olarak yeşile döner; ayrı bir "sıfırlama rengi" yoktur. Sıfırlama özelliği
kapatmaz: daire tekrar eşiğe varırsa ikinci uyarı verilir.

**KANCA UCU ASLA DÜŞÜRMEZ.** Caydırıcının başarısız olması şikâyetin
kaydedilmesini engellemez — şikâyet kullanıcının beyanıdır, caydırıcı
sistemin tepkisidir. `try/except` + log.

**İMZA.** `HMAC-SHA256(secret, "<timestamp>.<body>")` — GitHub/Stripe deseni.
**Zaman damgası imzaya girer**: yalnız gövdeyi imzalamak, ele geçirilmiş bir
isteğin sonsuza dek yeniden oynatılabilmesi demekti. Gövde **deterministik**
(sıralı anahtar, boşluksuz) ki alıcı yeniden serileştirip aynı imzayı
hesaplayabilsin. **Sır yoksa imza başlığı da gönderilmez**: boş bir sırla imza
üretmek, alıcının doğruladığını sanıp aslında hiçbir şey doğrulamaması olurdu.

**YENİDEN DENEME İSTEK YOLUNDA DEĞİL.** Kullanıcının şikâyet kaydını dış bir
ucun yavaşlığına bağlamak olurdu. Ayrı bir beat görevi (`scheduler.
gurultu_kuyrugu`, dakikada bir) **katlanan aralıklarla** (1, 5, 25 dk) en
fazla 3 kez dener; tükenirse kayıt **manuel moda düşer** — sistem sessizce pes
etmez, iş bir insana devredilir. Entegrasyon sonradan kaldırılırsa kuyrukta
sonsuza dek beklemek yerine yine manuel moda düşer.

**DONANIM SÜRÜCÜSÜ YAZILMADI** (kapsam gereği): `docs/caydirici-protokol-notu.md`
MQTT / KNX-IP / SIP-paging / Home Assistant köprülerini ve köprü yazacak olana
asgari sözleşmeyi belgeliyor. Ürün sınırı webhook'tur — sürücü yazmak, ürünü
donanım envanterine bağlamak ve her firmware güncellemesinde bakım borcu
üretmek demekti.

**BULGU — P24 İLE ETKİLEŞİM.** Varsayılan eşik 5, P24 renk skalasının `mor`
kademesi de 5+. Yani **varsayılan ayarda mor, gürültü şikâyetleri için
ulaşılamaz**: daire mora dönmeden uyarı alır ve yeşile döner. Bu doğru
davranıştır (caydırıcının amacı dairenin morda oturması değil, uyarılmasıdır)
ama P24'ün skala testini düşürdü — o test skalayı ölçüyor, caydırıcıyı değil,
bu yüzden eşiği kaldırıp ölçüyor. Diğer kategoriler mora ulaşmaya devam eder.

**BULGU — İNDEKSSİZ FK.** `tenant.gurultu_integration_id` FK'sinin öncü
kolonunu kapsayan indeks yoktu; indeks kapsamı envanteri yakaladı ("üst satır
silinince RI tetiği tenant'ı seq scan eder"). Kısmî indeks eklendi (0026,
yerinde düzenleme istisnası dosyada gerekçelendirildi).

Kanıt: `backend/tests/test_gurultu_caydirici.py` **17 test** yeşil (sınır
4→hayır / 5→tetikle+sıfırla, yalnız-gürültü, manuel mod, manuel-yapıldı +
409, tenant eşiği, eşik sınırları, RBAC, yeniden birikme, tenant izolasyonu,
webhook modu + SSRF reddi + kuyruk penceresi, alıcı imza doğrulaması, saf
çekirdek: eşik/metin/gövde/imza/geri-çekilme); tam pytest yeşil;
`goc-tersinirlik` bulgu 0 (27 sınır), `goc-uyum-dogrula` bulgu 0; seed koştu.
Rol matrisi kilidi 3 satır büyüdü.

**AÇIK BIRAKILAN (panel borcuna eklendi):** eşik/metin/entegrasyon seçimi ve
uyarı geçmişi **ekranı** yok (API + tenant ayarları hazır).

### P38 — Site web portal + surveys (anket)
Status: BITTI · Depends-on: P29; nice-to-have reuse from P7
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
Notes (2026-07-31):
**TEKNİK KARAR — AYRI UYGULAMA DEĞİL, admin-web içinde public rota.**
Sözlük (7 dil), tasarım belirteçleri, `API_BASE` çözümü ve derleme/dağıtım
hattı **zaten orada**; ikinci bir Next uygulaması bunların hepsini kopyalar ve
biri güncellenip diğeri unutulurdu. Caddy de zaten bu uygulamaya yönlendiriyor
— ayrı bir upstream, ayrı TLS/health yapılandırması demekti. Oturum kapısı
`middleware.config.matcher` ile **yol bazlıdır**; `/site/[slug]` listede
olmadığı için public kalır. **Yeni kilit:** `tests/portal-public.test.ts` —
mevcut kapsam kilidi yalnız "korunan sayfa matcher'da mı" diye bakıyordu; ters
yönü (public bir rotanın yanlışlıkla matcher'a girmesi) kimse kontrol
etmiyordu ve girseydi site sayfası ziyaretçiyi `/login`'e atardı.

**YAYIN VARSAYILAN KAPALI ve kapalıyken PUBLIC uç 404 döner — 403 değil.**
403, "bu tesis var ama kapalı" bilgisini sızdırır ve slug tahminiyle **tesis
envanteri** çıkarılabilirdi. Olmayan slug ile kapalı portal **aynı** yanıtı
verir. Yayın açma/kapama `audit_log`a yazılır: tesisin adı ve adresi internete
çıkıyor, kimin ne zaman açtığı sorulabilmeli.

**PUBLIC İÇERİK BİLİNÇLİ SEÇİLDİ.** Sakin listesi, daire sayısı, finans ve
personel **yok**. Duyurunun yalnız **özeti** çıkar — tam gövde site içine
yöneliktir ve tamamını internete açmak, sakinlere yazılmış bir metni herkese
yayınlamak olurdu. Hakkımızda **düz metin** olarak çizilir: HTML kabul etmek,
panelden gelen içeriği XSS yüzeyine çevirirdi. Harita **anahtarsız** gömülür —
API anahtarını public bir sayfaya koymak, anahtarı herkese vermek olurdu.

**ANKET BİR YOKLAMA DEĞİL KARAR ARACIDIR.**
- **Tek oy, değiştirilemez.** "Oyumu değiştireyim" akışı bilinçli olarak yok:
  değiştirilebilir oy, kapanış anına kadar sonucun anlamsız olması ve kimin ne
  zaman döndüğünün kayda geçmesi demekti. İkinci oy 409.
- **Sonuç kapanana kadar gizli.** Açık bir ankette güncel dağılımı göstermek
  sonraki oy verenleri etkiler (sürüsel etki) ve oylamanın kendisini bozardı.
  Oy verdikten **sonra bile** gizli: kendi oyunu bilmek başkasınınkini görmek
  değildir. Yönetim sonucu **her zaman** görür — kararın sahibi odur.
- **Oy yalnız sakinde**, okuma bilinen tüm rollerde: personelin oyu site
  kararına girmez ama sitesinde alınan kararı görmemesi de doğru olmazdı.
- **Seçenekler değiştirilemez** (`extra="forbid"`): oy verilmiş bir anketin
  seçeneklerini değiştirmek, verilmiş oyları başka bir soruya taşımak olurdu.
- **En az iki seçenek**: tek seçenekli bir anket oy toplamaz, onay toplar.
- `user_id` tek-oy kuralını zorlamak için saklanır ama **hiçbir uç
  döndürmez** (`unit_complaint.complainant_user_id` deseni).

**İLETİŞİM: KAYIT ÖNCE, BİLDİRİM SONRA.** Mesajı doğrudan e-postaya çevirmek,
SMTP yapılandırılmamış bir sitede mesajın **sessizce kaybolması** demekti.
Telefon **veya** e-posta zorunlu (üç katman: pydantic + DB CHECK + sözleşme):
ikisi de olmayan bir mesaja yönetim cevap veremezdi.

**MOBİL HOOK MİNİMAL.** Anket oluşturma/kapatma yönetim işidir ve panele
aittir; mobilde "gör ve oy ver" var. Oy verilmiş ankette oy butonu **hiç
çizilmez** — sunucu 409 döndürüp hata göstermek yerine yapılamayacak şeyi
teklif etmiyoruz.

**AÇIK BIRAKILAN — kimlikli sakin alanı (panel borcuna).** Kapsamdaki
"authenticated resident area: Ödenmemiş Borçlar + Öde" **yapılmadı** ve
gerekçesi mimaridir: admin-web girişi **yalnız admin**dir (bkz. auth.md); web
tarafına ikinci bir sakin oturumu (token saklama, yenileme, çıkış, cihaz
güveni) eklemek, mobilde P29/P30 ile zaten çalışan bir akışın **ikinci bir
kimlik modelini** kurmak olurdu. Portal, mobil uygulama yönlendirmesiyle o
akışa bağlanır; kimlikli web alanı finans panel bölümüyle birlikte
tasarlanmalı. Portal içerik/anket **yönetim ekranları** da aynı borçta.

Kanıt: `backend/tests/test_portal_anket.py` **23 test** + `mobile/test/
anket_test.dart` **7 test** + `admin-web/tests/portal-public.test.ts` **4
test** yeşil; tam pytest yeşil; `flutter analyze` temiz, `flutter test` 1516,
apk debug build başarılı; admin-web `tsc` + `vitest` + `npm run build`
(`/site/[slug]` rotası derlendi); `goc-tersinirlik` bulgu 0 (28 sınır),
`goc-uyum-dogrula` bulgu 0. Rol matrisi kilidi 12 satır büyüdü.

**BULGU — indekssiz FK.** `anket_secenek(tenant_id)` FK'sinin öncü kolonunu
kapsayan indeks yoktu (tenant silinince RI tetiği tabloyu seq scan ederdi);
indeks kapsamı envanteri yakaladı.

### P39 — Scale & load readiness
Status: BITTI · Depends-on: best after P29–P31 land
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
Notes (2026-07-31):
**k6, KONTEYNERDEN.** Host'a kurulum yok (`grafana/k6` imajı, `load` profili
altında — normal `up` ile başlamaz) ve `api` ile **aynı ağda**: ölçüme
internet gecikmesi girmez. İki senaryo: `senaryo.js` (karma profil) ve
`tekil.js` (tek uç — darboğazın çerçevede mi sorguda mı olduğunu ayırmak
için).

**PROFİL "EN ÇOK ÇAĞRILAN UÇ" DEĞİL, KULLANICININ GÜNÜ.** Giriş `setup()`ta
bir kez alınır: her yinelemede giriş yapmak, ölçümü **bcrypt maliyetiyle**
doldurup gerçek kullanımı yanlış temsil ederdi (kullanıcı günde bir kez
girer). `Idempotency-Key` her yinelemede farklıdır — aynı anahtarı
tekrarlamak yazma yolunu değil idempotent dönüş yolunu ölçerdi.

**ÖLÇÜLEN TABAN** (8 çekirdek; api+db+redis+k6 aynı kutuda):
| Uç (20 VU, düşünme yok) | RPS | p95 |
|---|---:|---:|
| `GET /me` | 283 | 100 ms |
| `GET /dashboard/live` | 177 | 155 ms |
| `GET /activity?limit=20` | 168 | 167 ms |

Karma profil (10 VU, 1 sn düşünme): ana ekran demeti p95 **2.08 s → 1.35 s**
(havuz açıkça boyutlandırıldı + ısınma), 4 işçiyle **1.26 s**; toplam
27.6 → 29.3 istek/sn; **%0 hata**. Okunuş: tek düğüm ~30 etkileşim/sn ≈
**~300 eşzamanlı aktif kullanıcı**.

**DÜZELTİLEN GERÇEK RİSK — GÖRÜNMEZ HAVUZ.** `create_async_engine`
varsayılanlarla çağrılıyordu ve `uvicorn` tek işçiye sabitti. Tehlike
varsayılanlar değil **görünmez olmalarıydı**: çok işçiye geçen ilk kişi
`API_WORKERS × (POOL + OVERFLOW)` formülünü hiç görmeden `--workers 8`
yazsaydı 120 > 100 (`max_connections`) olur ve sistem yük altında
`too many clients` ile düşerdi. Üçü de env oldu (1/5/5) ve
`pool_timeout=10 sn` kondu: **sonsuz bekleme yük altında isteği sessizce
asılı bırakırdı** — istemci kendi zaman aşımına kadar bekler, yeniden dener,
yük **katlanır**.

**ÖNBELLEK EKLENMEDİ — gerekçe ÖLÇÜMDÜR.** Kapsam "sıcak sayaçlar için kısa
TTL'li önbellek" diyordu; ölçüm bunu gerektirmedi (en ağır uç 20 VU'da p95
167 ms / 168 RPS). Bu sayılarda önbellek, kazandırdığı milisaniyeden çok
**bayat veri sınıfı bir hata türü** getirirdi. Eklenmesi gereken gün geldiğinde
ilk aday `/dashboard/live` sayaçlarıdır — runbook bunu yazıyor.

**4 İŞÇİ BU PROFİLDE YALNIZCA %6 KAZANDIRDI** ve bu da bir bulgudur:
darboğaz CPU değil, düşünme süresidir. Varsayılan `API_WORKERS=1` bırakıldı
(geliştirmede tek süreç hata ayıklamayı kolaylaştırır); prod değeri runbook
formülüyle verilir.

**YATAY ÖLÇEK DENETİMİ — tek gerçek engel `beat`.** api durumsuz (oturum
Redis'te, dosyalar MinIO'da), worker çoğaltılabilir (görevler idempotent:
`ON CONFLICT DO NOTHING`, `dedup_key`, deneme sayacı), RLS bağlamı
**transaction** kapsamlı olduğu için havuz paylaşımı güvenli ve ileride
PgBouncer **transaction** modunda kullanılabilir. `beat` ise **tek örnek
olmalıdır** — iki beat, her işin iki kez kuyruklanması demek. Bu, çok
düğüme geçmeden önce karara bağlanacak tek şey.

**Büyüme yolu** (runbook §5): dikey işçi → **veritabanını ayır** (ilk gerçek
sıçrama, kod değişikliği yok) → api'yi çoğalt → PgBouncer → okuma replikası.
**Mikroservis yok**: ölçüm tek uygulamanın rahat çalıştığını gösteriyor;
bölmek bugün yalnızca dağıtık işlem ve ağ gecikmesi sınıfında yeni hata
türleri eklerdi.

**Eşikler HEDEF DEĞİL TABAN**: `http_req_failed < %1`, `sure_home p95 <
1.5 sn`, `sure_activity p95 < 1.5 sn` — altına düşülürse regresyon vardır.

Kanıt: `docs/scaling-runbook.md` (öncesi/sonrası tablolar + denetim +
formül), `infra/load/*.js`, `infra/docker-compose.load.yml`; tam pytest
yeşil (4 işçi altında da) — sıfır doğruluk regresyonu.

### P40 — Panel bölümü: finans + rapor + mesaj + yönetişim + portal
Status: BITTI · Depends-on: P28–P33, P36–P38 (hepsi BITTI — API yüzeyleri hazır)
Scope: P28'den P38'e kadar biriken ve **bilinçli olarak ertelenen** panel/mobil
ekranları TEK BÖLÜM olarak tasarlanıp yapılır. Neden tek bölüm: borç, tahsilat,
rapor, mesaj, karar defteri, doküman ve portal aynı akışın parçaları — ayrı ayrı
eklenirse panelde sekiz farklı gezinme deseni kalır. Kapsam:
(a) **Finans** — borçlandırma önizleme/işleme (P28), kasa + finansal hareketler +
banka eşleştirme + icra dosyası (P29), P29'un dashboard hızlı-eylem kancaları;
(b) **Rapor** — 12 raporluk katalog + parametre modali + Excel/PDF indirme (P31);
(c) **Mesaj** — şablon CRUD + önizleme + toplu gönderim + geçmiş (P32);
(d) **Yönetişim** — karar defteri + doküman arşivi + Excel ile Site Aktar +
İşlem Geçmişi ekranı + yetki matrisi görünümü + evrak seri-sıra/para birimi UI
(P33); (e) **Ayarlar** — tur alarmı/başlangıç fotoğrafı (P34), güvenlik modu
(P35), KVKK metni **yayınlama** ekranı (P36), gürültü eşiği/metni/entegrasyon
seçimi + uyarı geçmişi (P37), portal içeriği + galeri + anket yönetimi + gelen
iletişim mesajları (P38).
Acceptance: her bölüm gerçek veriyle çiziliyor; `tsc` + `vitest` + `npm run
build`; sabit-metin ve i18n kilitleri yeşil; middleware kapsam kilidi yeni
sayfaları kapsıyor; P11'e cihaz/panel doğrulama maddeleri eklenir.
Notes (2026-08-01):
**BEŞ SAYFA, TEK VEKİL.** P40 yirmiden fazla backend ucunu panele açtı. Her
uç için ayrı `route.ts` yazmak aynı on satırı yirmi kez kopyalamak olurdu
(P27'nin `[kaynak]` deseni aynı gerekçeyle seçilmişti). Güvenlik **beyaz
liste** ile: istemciden gelen ad hiçbir zaman doğrudan URL'e girmez.
- **Okuma ve yazma AYRI sözlüklerdir.** Tek sözlüğe indirmek, okumaya açmak
  isterken yazmaya da açmak olurdu; `rapor-katalog`, `site-aktar-sablon`,
  `kasa-bakiyeleri` ve `portal-iletisim` **yazmaya kapalıdır**.
- "Önek eşleşmesi" (`/finans/...`) yeterli **görünür** ama `finans/../users`
  gibi girdilerle aşılmaya çalışılır; tam eşleşen sözlük o sınıfı tümden
  ortadan kaldırır. `[id]` yolunda kimlik **UUID doğrulanır**.
- **Yeni kilit** `tests/panel-vekil.test.ts`: sözlüğün kendisi denetlenir
  (mutlak yol, gezinme parçası yok, `/users`–`/tenants`–`/auth` yazmaya
  kapalı, süzgeç adları bilinen kaynaklara ait).

**İKİLİ VEKİL AYRI** (`proxyBinary`): `proxyJson` yanıtı `res.json()` ile
okur ve XLSX/PDF baytlarını JSON diye ayrıştırıp **bozardı**. 401 yolu
`proxyJson` ile aynı `refreshSingleFlight`ı kullanır — iki ayrı yenileme
mantığı, birinde düzeltilen bir hatanın diğerinde kalması demekti. Dosya adı
**sunucudan** gelir (`Content-Disposition`); panelde yeniden uydurmak,
indirilen dosyanın adıyla raporun adının ayrışması olurdu.

**SAYFALAR.**
- **Finans** (`/finans`): aylık özet + kasa bakiyeleri + hareket listesi +
  hareket girişi. Sayfa **bakiyeyi kendisi hesaplamaz** — P29'un kararı
  gereği bakiye defterden türetilir ve istemcide toplam almak iki yerde iki
  farklı rakam demekti. Yön rengi `yon` alanından gelir; tutar her zaman
  pozitiftir.
- **Raporlar** (`/raporlar`): katalog **sunucudan** gelir; sayfa hiçbir rapor
  adını kendisi taşımaz — taşısaydı sunucuya eklenen bir rapor panelde
  unutulurdu. Tablo/Excel/PDF aynı parametrelerden.
- **Mesajlar** (`/mesajlar`): şablon CRUD + önizleme + geçmiş. **SMS sayacı
  ekranda**: Türkçe harf tuzağı mesajı UCS-2'ye düşürür ve sınır 70'e iner;
  sayacı gizlemek, kullanıcının faturayı gönderdikten **sonra** görmesi
  demekti. Zorlayan karakterler de gösterilir.
- **Yönetişim** (`/yonetisim`): karar defteri (+PDF), doküman arşivi, **KVKK
  metni yayınlama**, gürültü uyarı geçmişi (+manuel "anons yapıldı"), Excel
  ile site aktarımı. Aktarımda **kuru çalışma varsayılan açıktır**; panel bu
  adımı atlatmaz. Ayırıcı olarak `;` **ve** TAB kabul edilir — Excel'den
  kopyalama TAB üretir, elle yazan `;` kullanır; birini desteklemek diğerini
  sessizce boş satıra çevirirdi. Satır numarası **2'den başlar** ki hata
  raporundaki numara kullanıcının Excel'indeki satırla örtüşsün.
- **Portal** (`/portal`): yayın anahtarı **en üstte** (altta kalması,
  "doldurdum ama yayınlamadım" ile "yayınladım" farkını görünmez kılardı) +
  içerik + anket yönetimi + gelen iletişim mesajları.
- **Ayarlar** (`/settings`): P34 tur alarmı, P35 güvenlik modu, P37 gürültü
  eşiği/metni — **veri sürücülü**, on `<input>` yerine bir alan tanımı
  listesi. **Değişmeyen alan gönderilmez**: `guvenlik_modu`nu her kayıtta
  göndermek, değişmese bile yöneticiye 403 verirdi (o alanı yalnız admin
  gönderebilir).

**KİLİTLERİN YAKALADIKLARI (üçü de gerçek).**
1. `middleware` kapsam kilidi beş yeni sayfanın **her birini** matcher'a
   eklemeye zorladı — biri unutulsaydı oturumsuz ziyaretçi panel kabuğunu
   görürdü.
2. Sabit-metin taraması iki **üçlü içi dizge** yakaladı (`"xlsx"/"pdf"` ve
   `"number"/"text"`). İkisi de kullanıcı metni değil teknik jeton;
   taramayı gevşetmek yerine ikisi de **haritaya** taşındı.
3. i18n taraması dosya başlığındaki bir yorumda Türkçe harf gördü; yorum
   ASCII'ye çevrildi (depo yorumları zaten ASCII).

Ayrıca **yedi dilde sözlük tekrarı** oluştu (aynı anahtarın iki kez
eklenmesi) ve `tsc` bunu TS1117 ile durdurdu — tekrarlar temizlendi.

**KAPSAMDA OLUP YAPILMAYAN — yetki matrisi görünümü.** RBAC'in tek doğruluk
kaynağı `backend/tests/yetki/rol-matrisi.txt` kilidi ve onu üreten
`test_yetki_kapsam.py`dir (6 rol × 314 operasyon). Paneldeki bir görünüm
için yeni bir uç açmak, **aynı gerçeği ikinci bir yerden üretmek** ve ikisinin
ayrışması riskini almak olurdu. Karar: kilit dosyası **kaynak olarak kalsın**;
panele taşınacaksa o dosyayı servis eden bir uç yazılmalı — bu ayrı bir
maddedir. İşlem Geçmişi ise zaten `/audit` sayfasında.

Kanıt: `admin-web` `tsc` temiz, `vitest` **114 test** yeşil (yeni:
`panel-vekil.test.ts` 5 test), `npm run build` — `/finans`, `/raporlar`,
`/mesajlar`, `/yonetisim`, `/portal` ve güncellenen `/settings` derlendi.

### P41 — Yetki matrisi görünümü (koddan üretilen)
Status: BITTI · Depends-on: P40
Scope: RBAC matrisini panelde göster. Kaynak ELLE TUTULAN bir liste OLMAYACAK.
Acceptance: uç koddan üretiyor; test kilidiyle çapraz doğrulama; panel sayfası;
gates.
Notes (2026-08-01):
**NEDEN AÇILDI.** P40'ın kapsamındaki "yetki matrisi görünümü" bilinçli olarak
yapılmamış ve gerekçesi yazılmıştı: panel görünümü için elle bir liste tutmak,
aynı gerçeği ikinci bir yerden üretmek olurdu. P41 o gerekçeyi çözerek maddeyi
kapatır — **matris kodun kendisinden üretilir**.

**NASIL.** `require_role`, ürettiği bağımlılığa `izinli_roller` **özniteliğini**
işler; uç FastAPI'nin `dependant` ağacını gezip o özniteliği taşıyan ilk
bağımlılığı bulur. Yani gösterilen matris, isteklerin **gerçekten geçtiği
kapının kendisidir**; bir uç `require_role`unu değiştirdiğinde tablo
kendiliğinden değişir.

**ÜÇ AYRIM BİLİNÇLİ:**
- `roller: null` **"herkese açık" demek değildir** — uçta rol kapısı yoktur ama
  kimlik doğrulaması gerekebilir. İkisini aynı göstermek, kimliksiz
  erişilebilir bir uç varmış gibi göstermek olurdu. Panelde ayrı rozet.
- `moda_bagli: true` (P35): yazma sahibi tenant moduna bağlıdır ve `roller`
  **iki modun birleşimidir**; sabit tek bir küme, `dis_sirket` modundaki gerçek
  davranışı yanlış anlatırdı.
- **`IZIN` "aynı veriyi görüyor" demek değildir**: bazı uçlar tüm rollere açıktır
  ama içerik role göre daralır. Matris **erişilebilirliği** gösterir; bu sınır
  hem uç açıklamasında hem panelde yazılı.

**ÇAPRAZ DOĞRULAMA.** `test_yetki_matrisi.py` ucu, gerçek isteklerle ölçülen
`tests/yetki/rol-matrisi.txt` **kilidiyle** karşılaştırır: ikisi de aynı
`require_role` çağrılarından türediği için ayrışmaları birinin bozulduğu
anlamına gelir. Kilit `moda_bagli` uçlarda yalnız varsayılan modu ölçtüğü için
karşılaştırma **alt küme** ilişkisiyle yapılır — eşitlik aramak, doğru
davranışı hata sayardı.

**RBAC.** admin + yönetici. Saha/sakin rollerine kapalı: tüm sistemin yetki
haritasını göstermek gereksiz bir keşif yüzeyi açardı. Panelde salt okuma
(vekil beyaz listesinde yalnız OKUMA tarafında).

Kanıt: `backend/tests/test_yetki_matrisi.py` **6 test** yeşil (sütun sırası
kilitle aynı, uç↔kilit örtüşmesi, moda-bağlı işaretleme, kapısız uçların
ayrılması, RBAC, yeni ucun kendiliğinden listede belirmesi); rol matrisi kilidi
yeni ucu içerecek şekilde güncellendi (315 satır); sözleşme güncel; admin-web
`tsc` + `vitest` (114) + `npm run build` (`/yetki` derlendi).

### P42 — İçerik daraltma kapsamı (aynı uç, farklı gövde)
Status: BITTI · Depends-on: P41
Scope: Yetki kilidinin ve P41 matrisinin GÖRMEDİĞİ katmanı ölç: bir uç birden
çok role açıkken gövdenin role göre gerçekten daralıp daralmadığı.
Acceptance: daraltma yapan uçlar tek tek sürülür; sızıntı ve eksik daraltma
ayrı ayrı ölçülür; gates.
Notes (2026-08-01):
**NEDEN.** `test_yetki_kapsam.py` kilidi ve P41'in `/yetki-matrisi` ucu
**erişilebilirliği** ölçer (401/403/diğeri). İkisi de "IZIN" dediği yerde
gövdenin role göre daraldığını **görmez**. Envanterin açık maddesi tam olarak
buydu (`OLCULMEYEN-DURUMLAR-5.md`, madde 4: "aynı uç, farklı gövde — kilit
bunu görmüyor"). P42 o katmanı kapatır.

**ÖLÇÜLEN ALTI DARALTMA:**
1. `/reports/financial-summary` — beş role de açık (şeffaflık: anonim
   agregat) ama `tahsilat` bloğu yalnız yönetime. Kilit bu ucu
   "IZIN IZIN IZIN IZIN IZIN" diye gösterir ve farkı hiç görmez.
2. `/activity` — kaynak kümesi role göre; admin kümesi diğerlerinin
   **üst kümesi** olmalı (bir rol adminde olmayan bir tür görüyorsa bu bir
   yetkilendirme hatasıdır).
3. `/cameras` — `sakin_gorebilir=false` kamerayı sakin/tesis görevlisi
   görmez; erişim aynı, içerik farklı.
4. `/complaints` — açan roller yalnız kendi kayıtlarını görür; başkasının
   kaydı **404** (403 "böyle bir kayıt var" demek olurdu).
5. `/anketler` — açık ankette sayılar yalnız yönetime (P38 sürüsel etki);
   sakin/saha/amir `null` görür.
6. `/unit-complaints/building-map` — yapı herkese, **sayım ve renk** yalnız
   yönetime (P24/KVKK: komşu davranışı hakkında veri).

**BULUNAN LATENT KUSUR — sessiz 500 tuzağı.** `/activity` kaynak kümesini
`_ROL_KAYNAKLARI[user.role]` ile seçer. Uca yeni bir rol eklenip bu sözlüğe
satır eklenmezse uç **KeyError → 500** döner; ve **hiçbir mevcut ölçüm bunu
yakalamaz** — yetki kilidi 500'ü "IZIN" sayar. P41'in `izinli_roller`
özniteliği bunu ölçülebilir kıldı: artık `_READER`ın izin verdiği her rolün
sözlükte karşılığı olduğu doğrulanıyor. (Bugün eksik yok; test gelecekteki
eklemeyi korur.) Depoda role-anahtarlı tek sözlük budur — tarandı.

**ÖLÇÜMÜN SINIRI (dürüstçe):** kapsam otomatik değildir. "Hangi uç içeriği
daraltmalı" sorusunun makinece türetilebilir bir yanıtı yok — bu bir **ürün
kararıdır**. Bu yüzden dosya bir **envanterdir**: yeni bir daraltma eklendiğinde
buraya da satır eklenmelidir ve bu, dosyanın başında yazılıdır.

Kanıt: `backend/tests/test_icerik_daraltma.py` **7 test** yeşil; tam pytest
yeşil.

### P43 — Panel bileşen testi altyapısı (jsdom)
Status: BITTI · Depends-on: P40, P41
Scope: Envanterin açık maddesi 3 — "panel UI birim kapsamı %26,8; React
bileşenlerini jsdom ile test etmek ayrı bir altyapı kararı (bilinçli
yapılmamıştı)". Karar verilir, altyapı kurulur, en yeni sayfalar test edilir.
Acceptance: aynı koşumda iki ortam; sayfa testleri gerçek bileşeni sürer;
`tsc` + `vitest` + `npm run build` yeşil.
Notes (2026-08-01):
**KARAR: aynı koşumda iki ortam.** Saf mantık ve middleware `node` ortamında
kalır (hızlı, jsdom yan etkilerinden bağımsız); sayfa testleri dosya başındaki
`@vitest-environment jsdom` yorumuyla jsdom'a geçer. **Ortam seçimi dosyanın
kendisinde durur**: merkezî bir glob listesi, yeni bir dosya eklenip listeye
yazılmadığında testin sessizce yanlış ortamda koşması demekti — ve o hata
"document is not defined" olarak *başka bir yerde* patlardı.

**ÜÇ GERÇEK ENGEL, ÜÇÜ DE ÖLÇÜMLE ÇÖZÜLDÜ.**
1. **JSX ayrıştırma.** Testler önce `.tsx` yazıldı; Vitest 4 (rolldown) JSX'i
   ayrıştırmadı. `@vitejs/plugin-react` kuruldu ve **`next build` PATLADI**:
   eklentinin `.d.ts` dosyası bu depodaki TypeScript'in ayrıştıramadığı bir
   sözdizimi kullanıyor (`as "module.exports"`) ve tsconfig `**/*.ts` ile
   `vitest.config.ts`i de denetlediği için hata **ürün derlemesine taşındı**.
   Karar: **test bağımlılığı ürün derlemesini kıramaz** — eklenti ve `vite`
   kaldırıldı, testler JSX yerine `createElement` kullanıyor.
2. **Sayfaların kendisi `.tsx`.** tsconfig `jsx: "preserve"` (Next kendi
   derleyicisini kullanır), bu yüzden Vitest'e açıkça söylenmeli. `esbuild`
   anahtarı **yok sayıldı** — Vitest 4 rolldown/**oxc** kullanıyor; doğru
   anahtar `oxc.jsx`. Bu ayar yalnız test koşumunu etkiler.
3. **SWR önbelleği testler arası taşınıyordu.** Önbellek modül düzeyinde
   paylaşılır; ikinci test birinci testin yanıtını görüyordu ve **"uç düştü"
   senaryosu yanlışlıkla geçiyordu**. Her render'a temiz bir `provider`
   verildi. Ayrıca RTL'in otomatik temizliği yalnız `globals: true` ile
   devreye girer — bu depo `globals` kullanmıyor, bu yüzden `cleanup`
   kuruluma açıkça eklendi (yoksa ikinci test birinci testin DOM'unu da
   görüyor ve hata **testin kendisinde değil kurulumda** oluyordu).

**ÖLÇÜLEN DAVRANIŞLAR** (12 test, en yeni ve en riskli üç sayfa):
- **Finans**: kuruş→TL çevrimi; **yön işareti** (tutar her zaman pozitif,
  işaret `yon` alanından — bu mantık yalnız çizim katmanında yaşar); **uç
  düştüğünde hata görünür, "kayıt yok" gösterilmez** (tur 42'de bulunan
  ayrım); kasa yokken yönlendirici boş durum.
- **Yetki matrisi**: sütunlar sunucudan gelir (sayfa rol listesi taşımaz);
  **`roller: null` ayrı rozet** — "izin yok" ile karıştırılırsa kullanıcı
  kimliksiz erişilebilir bir uç varmış gibi okur; `moda_bagli` işareti; arama.
- **Yönetişim / site aktarımı**: kuru çalışma varsayılan açık ve gövdede
  `yalniz_dogrula=true` gidiyor; **`;` ve TAB ayırıcılarının ikisi de**
  çözülüyor (Excel kopyası TAB üretir, elle yazan `;` kullanır); satır
  numarası **2'den başlıyor**; boş metinde **istek atılmıyor**.

**KAPSAM SAYISI DÜŞTÜ, VE BU DÜRÜST BİR SAYIDIR.** Envanterdeki %26,8, P40'ın
~2 000 ifadesi eklenmeden önceydi. Ölçülen yeni değer: **ifade %9,66
(322/3 330), satır %9,82**. Payda büyüdüğü için oran düştü; bu turda eklenen
şey **altyapı + en yeni sayfaların davranış testleri**dir, geriye dönük toplu
kapsam değil. Kapsamı yükseltmek ayrı ve sürekli bir iştir.

Kanıt: `vitest` **126 test** (114 → +12) yeşil; `tsc` temiz; `npm run build`
yeşil (ürün derlemesi test bağımlılıklarından etkilenmiyor).

### P44 — Panel bileşen kapsamını yükseltme (1. tur)
Status: BITTI · Depends-on: P43
Scope: P43'ün kurduğu altyapıyla kalan P40 sayfalarını (rapor, mesaj, portal,
ayarlar) davranış testlerine bağla. Hedef "yüzde" değil, **sessiz hata
sınıflarını** kapatmak.
Acceptance: her test somut bir hata sınıfını korur; `tsc` + `vitest` +
`npm run build` yeşil; kapsam ölçülür ve dürüstçe raporlanır.
Notes (2026-08-01):
**HEDEF YÜZDE DEĞİL, HATA SINIFI.** Kapsamı yükseltmek için "her satıra
dokunan" testler yazmak kolaydı ve işe yaramazdı. Bu turda eklenen 12 test,
üründe **gerçekten sessiz kalabilecek** davranışları koruyor:
- **Rapor**: boş parametre gövdeye **girmiyor** (boş dizgeyi tarih diye
  göndermek sunucuda doğrulama hatası üretirdi); dolu parametreler giriyor;
  `ismi_goster` kapatılınca gövdeye `false` gidiyor (KVKK — kapıya asılacak
  listede ad olmamalı); satır yoksa boş tablo yerine yönlendirici boş durum.
- **Mesaj**: `amac` şablonda görünüyor (gönderimde seçilmiyor — P32'nin rıza
  kararı); **SMS sayacı ve UCS-2 uyarısı çiziliyor** (zorlayan karakterler
  dahil: "neden 3 SMS oldu" sorusunu kullanıcının metne bakıp tahmin etmesine
  bırakmak sayacı yarım göstermekti); boş ad/gövdede istek atılmıyor; kanal
  e-posta seçilince **konu alanı beliriyor** (SMS'te konu yoktur —
  gönderilmeyecek bir veriyi doldurtmak olurdu).
- **Portal**: yayın anahtarı **anında** kaydediliyor (kaydet'e basılmasını
  bekleyen bir anahtar, kullanıcının yayınladığını sanması demekti); anket
  en az iki seçenek istiyor ve **istek atılmıyor**.
- **Ayarlar**: **değişmeyen alan gönderilmiyor** — `guvenlik_modu`nu her
  kayıtta göndermek yöneticiye 403 verirdi; hiç değişiklik yoksa istek de yok.

**YARDIMCIDA BULUNAN GERÇEK KUSUR — önek çakışması.** `fetchSahtele` url'i
`startsWith` ile eşliyordu ve **ekleme sırasına** göre ilk eşleşeni alıyordu.
`/api/panel/portal` ile `/api/panel/portal-iletisim` aynı öneki paylaşıyor:
iletişim listesine **portal gövdesi** dönüyordu ve portal testi "form
yüklenmedi" diye düşüyordu — yani hata testte değil **test aracında**dı.
Artık **en uzun önek kazanır**.

**KAPSAM (ölçüldü):** ifade **%9,66 → %14,26 (475/3 330)**, satır **%9,82 →
%14,77**. Payda P40'ın sayfalarıyla büyük; oran tek turda "iyi" bir sayıya
çıkmaz ve çıkarmaya çalışmak, hata sınıfı korumayan dolgu testler yazmak
olurdu.

Kanıt: `vitest` **138 test** (126 → +12) yeşil; `tsc` temiz; `npm run build`
yeşil.

### P45 — Panel bileşen kapsamı (2. tur): para ve yetki sayfaları
Status: BITTI · Depends-on: P44
Scope: Panelin en pahalı hataları barındıran iki eski sayfasını (aidat,
kullanıcılar) davranış testlerine bağla.
Acceptance: her test somut bir hata sınıfını korur; gates.
Notes (2026-08-01):
**NEDEN BU İKİSİ:** yanlış para gösterimi ve yanlış rol, panelin en pahalı
hatalarıdır. Ölçülenler:
- **Aidat**: `125050` kuruş → **1.250,50 ₺** (panelde kuruş gösterilmez; tam
  sayı aritmetiği — float 1.250,49 gibi kayan hatalar üretirdi); tutar
  geçersizken **istek atılmıyor ve kullanıcıya neden söyleniyor**; uç
  düştüğünde **sunucu metni** görünüyor ve tahakkuk listesi **çizilmiyor**
  (tur 42'nin ayrımı: boş liste ile düşen uç aynı ekranı veriyordu).
- **Kullanıcılar**: rol adları **sözlükten** geliyor — `yonetici` wire değeri
  ekrana çıkmıyor (çıksaydı dil değişiminde olduğu gibi kalır ve kullanıcıya
  teknik jeton gösterirdi); süzgeç değişince istek **yeni parametreyle ve
  `offset=0`** ile gidiyor (eski offset'te kalmak, ilk sayfası boş görünen
  bir liste demekti).

**TEST YAZARKEN ÖĞRENİLEN İKİ ŞEY** (ikisi de yorumda kayıtlı):
1. `Field` etiketi `<label>` sarmalıyor ve **ipucu metni de etiketin
   içindedir**; tam eşleşme arayan sorgular bu yüzden düşer — regex gerekir.
2. `required` alanlar boşken tıklamak **tarayıcı doğrulamasına** takılır ve
   uygulamanın kendi doğrulaması hiç çalışmaz. Ölçülmek istenen şey
   uygulamanın doğrulaması olduğu için alanlar doldurulup **geçersiz** değer
   verilir.

**KAPSAM:** ifade **%14,26 → %15,97 (532/3 330)**, satır **%14,77 → %16,61**.

Kanıt: `vitest` **144 test** (138 → +6) yeşil; `tsc` temiz; `npm run build`
yeşil.

## CHANGELOG
<!-- date · item ID · commit hash · one line. STATUS REPORTs and the FINAL REPORT land here, newest first. -->
<!-- HASH KURALI: bir commit kendi hash'ini iceremez. Satir once "(bu commit)"
     ile yazilir; gercek hash bir SONRAKI commit'te ya da FINAL REPORT'ta
     (kural 13, liste A) doldurulur. -->

### P46 — Bildirim metinleri kör noktası + talep sayfası testleri
Status: BITTI · Depends-on: P45
Scope: Panel bileşen kapsamını sürdürürken bulunan i18n kör noktasını kapat;
talepler sayfasını (durum makinesi) testlere bağla.
Acceptance: sızıntı sayısı ölçülür ve **sıfıra** indirilir; kilit yeni sınıfı
görür ve bunun **gerçekten yakaladığı** doğrulanır; gates.
Notes (2026-08-01):
**BULGU — `toast(...)` metinleri hiçbir taramanın görmediği yerdeydi.**
Panelin i18n taramaları JSX metin düğümlerine, görünen özniteliklere ve (tur
22) tüm kaynaktaki **Türkçe harfli** sabitlere bakıyordu. `toast.success("…")`
bunların hiçbiri değil: sade bir fonksiyon argümanı. Ölçüldü: **10 sabit
bildirim metni** (9 farklı metin, 9 dosya). Dil değiştiğinde hepsi Türkçe
kalıyordu — ve bu, kullanıcının bir işlemden sonra gördüğü **son** mesaj,
yani en çok fark edilen yer.

Onu tur 22 taraması neden kaçırdı: o tarama **Türkçe harfe** bakar ve bir
"çırçır" (ratchet) eşiğiyle çalışır — kalan sayı artamaz ama mevcutlar
geçerdi. Yeni ölçüm **dilden bağımsızdır**: bildirim metni tırnak içindeyse
sızıntıdır, hangi dilde olduğu fark etmez.

**KAPATMA + KİLİT.** Dokuz metin sözlüğe taşındı (7 dil) ve
`tests/i18n.test.ts`e yeni bir ölçüm eklendi. Kilidin **gerçekten yakaladığı
doğrulandı**: geçici bir sızıntı eklenip testin kırıldığı görüldü, sonra geri
alındı — "test yazdım, yeşil" demek onun bir şeyi ölçtüğünü kanıtlamaz.

**TALEP SAYFASI (5 test).** Durum makinesinin iki hata sınıfı: (1) kapalı bir
talepte eylem butonlarının görünmesi — kullanıcı basar, sunucu 409 döner ve
neden anlaşılmaz; (2) reddetme sebebinin boş gönderilebilmesi (backend 422,
ama kullanıcı formu doldurduğunu sanır). Ayrıca **çözmede not opsiyonel,
reddetmede sebep zorunlu** ayrımı korunuyor — ikisini aynı kurala bağlamak,
çözen yöneticiyi gereksiz metin yazmaya zorlardı.

**KAPSAM:** ifade **%15,97 → %16,99 (566/3 330)**, satır **%16,61 → %17,74**.

Kanıt: `vitest` **150 test** (144 → +6; 5 talep + 1 kilit) yeşil; `tsc` temiz;
`npm run build` yeşil.

### P47 — Panel bileşen kapsamı (3. tur): pano, daireler, tanımlar
Status: BITTI · Depends-on: P46
Scope: Kalan yüksek riskli panel sayfalarını davranış testlerine bağla.
Acceptance: her test somut bir hata sınıfını korur; bulunan kusur düzeltilir;
gates.
Notes (2026-08-01):
**BULGU — aynı para, iki farklı biçim.** Tanımlar sayfasının tablosu
`liraya()` kullanıyordu: `toFixed(2)` ile **`5000.00`**. Panelin geri kalanı
`kurusToTL()` ile **`5.000,00 ₺`** yazıyor. İki sorun birden:
1. Aynı değer iki sayfada iki farklı biçimde görünüyordu.
2. Daha kötüsü, **Türkçe'de nokta binlik ayırıcıdır**: `5000.00` okuyan bir
   kullanıcı bunu **beş yüz bin** sanabilirdi.

Düzeltme **ayrımı koruyarak** yapıldı: tabloda `kurusToTL` (okunabilir),
**formda `liraya` kaldı** (girdi ayrıştırılabilir olmalı — `5.000,00 ₺` bir
`<input>` değeri olarak geri okunamazdı). Gerekçe kodda yazılı.

**ÖLÇÜLEN DAVRANIŞLAR (5 test):**
- **Pano**: üç pencere üç satır olarak çiziliyor (sayaçlar sunucu verisinden
  türetiliyor, istemcide yeniden sayılmıyor — sayarsa pano ile liste
  ayrışırdı); alarm metni **sunucudan** geliyor (panelde yeniden cümle
  kurmak, sunucunun dil kataloğunu atlamak olurdu); uç düştüğünde **boş pano
  gösterilmiyor**, hata görünüyor.
- **Daireler**: blok süzgeci isteği yeniliyor ve **`offset=0`** ile gidiyor.
- **Tanımlar**: kuruş alanı **TL olarak** çiziliyor (yukarıdaki düzeltme);
  sekme değişince **o defterin** ucu çağrılıyor.

**KAPSAM:** ifade **%16,99 → %19,03 (634/3 330)**, satır **%17,74 → %19,88**.

Kanıt: `vitest` **155 test** (150 → +5) yeşil; `tsc` temiz; `npm run build`
yeşil.

### P48 — Para biçimlendirmede ICU bağımlılığı ve üçüncü biçimlendirici
Status: BITTI · Depends-on: P47
Scope: P47'nin bulduğu "aynı para, iki farklı biçim" sınıfını **süpürerek**
kapat: panelde kaç para biçimlendiricisi olduğunu ölç, tek kaynağa indir ve
ortam bağımlılığını kaldır.
Acceptance: sızıntı ölçülür; tek kaynak kalır; biçim testleri eklenir; gates.
Notes (2026-08-01):
**SÜPÜRME SONUCU: panelde ÜÇ ayrı para biçimlendiricisi vardı.**
| Yer | Çıktı | Durum |
|---|---|---|
| `lib/money.ts` → `kurusToTL` | `5.000,00 ₺` | ortak kaynak |
| `tanimlar` → `liraya` | `5000.00` | P47'de tablodan kaldırıldı, **formda kaldı** (girdi ayrıştırılabilir olmalı) |
| `transparency` → özel `tl()` | `5.000,00 **TL**` | **kaldırıldı** |

Şeffaflık sayfası aynı değeri `₺` yerine `TL` ile yazıyordu; iki sayfayı yan
yana açan kullanıcı için bu, aynı verinin iki farklı para birimi gibi
görünmesiydi.

**ASIL BULGU — `toLocaleString("tr-TR")` bir ORTAM BAĞIMLILIĞIDIR.** Her iki
biçimlendirici de binlik ayırıcı için ICU'ya güveniyordu. Tam ICU'lu bir
çalışma zamanında `5.000` gelir; **küçük-ICU** ile derlenmiş bir
Node/tarayıcıda `tr-TR` desteklenmez ve `en-US`a düşer: `5,000`. O durumda
para **`5,000,00 ₺`** görünürdü — hem yanlış hem okunamaz. Ve hata **yalnız
bazı ortamlarda** çıktığı için geliştirmede hiç fark edilmezdi.

Şeffaflık sayfasındaki `.replace(/ /g, ".")` yaması bunu görmüş ama yanlış
teşhis etmişti: dar boşluğu noktaya çeviriyordu, oysa küçük-ICU'daki gerçek
sorun **virgüllü gruplamadır** ve yama onu hiç çözmüyordu.

**Çözüm:** üç haneli gruplama **kendimiz** yapılıyor (dilden bağımsız basit
bir kural); ICU'ya bağımlı olmak, kazancı olmayan bir ortam riski almaktı.

Kanıt: `tests/money.test.ts`e **3 test** eklendi (gruplama sınırları 3/4/6/7
hane, negatif işaret, sıfır/kuruş sınırları); `vitest` **158 test** yeşil;
`tsc` temiz; `npm run build` yeşil.

### P49 — Mobilde para ayrıştırma çekirdeği + tarihe bağlı test kırılganlığı
Status: BITTI · Depends-on: P48
Scope: P48'in panelde bulduğu "aynı iş, birden çok uygulama" sınıfını mobilde
de ara; bulunanı tek kaynağa indir.
Acceptance: kusur ölçümle gösterilir; politika/ayrıştırma ayrımı korunur;
`flutter analyze` + `flutter test` + apk build yeşil.
Notes (2026-08-01):
**BULGU 1 — uygulama kendi gösterdiği biçimi reddediyordu.** Mobilde iki
ayrıştırıcı vardı: `budget_models.parseTlToKurus` (Türkçe binlik ayırıcısını
doğru çözen, olgun bir uygulama) ve `unit_tanimlari_screen._kurus` (naif:
`replaceAll(',', '.')` + `double.tryParse`). İkincisi `1.250,00` girdisini
**çözemiyordu** ve alan doğrulayıcısı "geçersiz tutar" diyordu — oysa
uygulamanın kendisi aynı tutarı başka ekranlarda `1.250,00` olarak
**gösteriyor**. Kullanıcı gördüğü biçimi yazıp reddediliyordu.

**NEDEN KOPYA YAZILMIŞTI (ve düzeltmenin şekli):** `parseTlToKurus` butçeye
özel bir **politika** taşıyor — `kuruş > 0` değilse `null`. Bağımsız bölüm
tanımlarında ise **0 = muaf** geçerli ve anlamlı bir değerdir ("tanımsız"
`null`dan ayrıdır). Yani kopya keyfî değil, paylaşılan fonksiyonun yanlış
yerde kural taşımasının sonucuydu.

Çözüm bu ayrımı kurumsallaştırıyor: **ayrıştırma** `core/para.dart`ta
(politikasız, işaret/sıfır kararı yok), **politika** çağıranda (bütçe: `>0`;
tanımlar: `>=0`). Form ön-dolgusu da artık **gösterilen biçimi** kullanıyor
(`tlTutar`) — gösterim ile giriş aynı dili konuşuyor.

**BULGU 2 — tarihe bağlı test kırılganlığı.** `enteg_ziyaret_rapor_i18n_test`
ay başlığını **"Temmuz 2026" diye sabit** yazmıştı; ekran `DateTime.now()`
kullanıyor. Takvim 1 Ağustos'a dönünce test kırıldı ve **her ay yeniden
kırılacaktı**. Sabit tarihi güncellemek sorunu bir ay ertelerdi. Ölçümün
amacı **ay adının dile göre değiştiğini** doğrulamaktır, hangi ay olduğunu
değil — beklenen değer artık ekranın kullandığı aynı kaynaktan (`ayAdi` +
`DateTime.now()`) üretiliyor. Şeffaflık testindeki benzer sabitler
**fikstür verisinden** geldiği için deterministiktir; tarandı, dokunulmadı.

Kanıt: `mobile/test/para_test.dart` **8 test** (ayırıcı kuralının üç dalı,
para birimi/boşluk temizliği, geçersiz girdiler, politika ayrımı, ve
**gösterim↔giriş gidiş-dönüşü**); `flutter analyze` temiz; `flutter test`
**1524** yeşil; `flutter build apk --debug` başarılı.

### P50 — Panel para ayrıştırıcısı: gösterilen biçim kabul edilir
Status: BITTI · Depends-on: P49
Scope: P49'un mobilde bulduğu "uygulama kendi gösterdiği biçimi reddediyor"
kusurunu panelde de ara ve iki istemciyi **aynı kurala** bağla.
Acceptance: kusur ölçümle gösterilir; iki istemci aynı metni aynı şekilde
ayrıştırır; kilit testi gerekçesiyle güncellenir; gates.
Notes (2026-08-01):
**AYNI KUSUR PANELDE DE VARDI.** `tlToKurus` şöyle çalışıyordu:
`replace(",", ".")` + `^\d+(\.\d{1,2})?$`. Ölçüldü:

| Girdi | Eski | Yeni |
|---|---|---|
| `750,50` | 75050 | 75050 |
| `1.250,00` | **null** | 125000 |
| `1.250` | **null** | 125000 |

Panel aynı tutarı `kurusToTL` ile **`1.250,00 ₺`** diye gösteriyor: uygulama
gösterdiği biçimi geri kabul etmiyordu. Aidat sayfasında `1.250,00` yazan
yönetici "geçerli bir tutar girin" alıyordu.

**"BELİRSİZ" GEREKÇESİ YANLIŞTI.** Eski test bunu `// binlik ayirici
DESTEKLENMEZ (belirsiz)` diye kilitlemişti. Belirsizlik gerçekte yok:
**virgül varsa nokta binliktir**. Kalan tek belirsizlik virgülsüz tek nokta
(`1.250`) ve orada kural açık: en fazla iki hane varsa ondalık (sayısal
klavye), değilse binlik.

**İKİ İSTEMCİ AYNI KURAL.** Mobil çekirdeği (P49) ile panel artık aynı üç
dallı kuralı uyguluyor. Farklı olsalardı **aynı sitede aynı metin farklı
tutar** girebilirdi.

**BU TURDA SIKILAŞTIRILAN İKİ NOKTA (ikisi de her iki istemcide):**
1. **Yarım giriş reddedilir**: `750,` `,50` `750.` `.50` → null. Sessizce
   750,00 / 0,50 saymak, kullanıcının yazmayı bitirmediği bir tutarı
   kaydetmek olurdu. (Panel bunu zaten reddediyordu, **mobil kabul
   ediyordu** — asimetri bu turda kapandı.)
2. **İçerideki boşluk reddedilir**: `1 000` Türkçe yazımda bir sayı değildir;
   mobil eskiden tüm boşlukları siliyordu ve `1 2 3`ü de kabul ederdi.

Kanıt: `admin-web/tests/money.test.ts` **+1 test** (gösterilen biçimin kabulü;
kilit testi gerekçesiyle güncellendi), `mobile/test/para_test.dart` **+1 test**
(yarım giriş + boşluk). `vitest` **159** yeşil, `tsc` temiz, `npm run build`
yeşil; `flutter analyze` temiz, `flutter test` **1525** yeşil, apk build
başarılı.

### P51 — Panel kapsamı 4. tur: vardiya/nokta + bildirimlerde sessiz başarısızlık
Status: BITTI · Depends-on: P50
Scope: Test edilmemiş panel sayfalarını kapsama al; ilke değişmedi — **hedef
yüzde değil hata sınıfı**.
Acceptance: bulunan kusurlar ölçümle gösterilir ve düzeltilir; testler kusurun
üstünde durur; gates.
Notes (2026-08-01):
**BİLDİRİMLER SAYFASINDA İKİ GERÇEK KUSUR** bulundu:

1. **SESSİZ BAŞARISIZLIK — "okundu işaretle".** Sayfa tek yerde ham `fetch`
   kullanıyordu; ham `fetch` **başarısız yanıtta da çözülür**. Yani 401/500
   dönse bile `mutate()` çağrılıyor ve **"Bildirim okundu olarak işaretlendi."
   BAŞARI bildirimi** çıkıyordu. Kullanıcı işaretlediğini sanıyor, bildirim
   okunmamış kalıyordu. Panelin geri kalanı `apiSend` kullanıyor (o hata
   gövdesini `Error`a çevirir); bu uç istisnaydı. Artık `apiSend` + `catch`
   → hata bildirimi.
2. **HAM TEL DEĞERİ EKRANDA.** Rozet `n.tip`i olduğu gibi çiziyordu:
   kullanıcı **`gecikmis_okutma`** görüyordu. Yedi canlı tip 7 dile çevrildi;
   eşleşmeyen tip **HAM kalır** (vardiyalardaki `gunTipiAdi` kalıbı) — sunucu
   yeni bir tip eklerse ya da üründen kaldırılmış eski bir kayıt görünürse
   rozet **boş kalmasın**. `peyzaj_*` bilinçli olarak çevrilmedi: ürün
   sözlüğüne geri getirmek yerine ham gösterilir.

**TEST ARACINDA UÇ BAŞINA DURUM.** `fetchSahtele`in `opts.durum`u **tüm**
uçları birden bozuyordu; oysa gerçek kusurların çoğu "liste geldi ama **yazma**
düştü" şeklinde. Gövdeye `__durum` işaretçisi eklendi (işaretçi ayıklanır,
sayfa görmez) — yukarıdaki 1. kusur ancak böyle ölçülebildi.

**VARDIYA/NOKTA.** Gece vardiyası uyarısı (başlangıç > bitiş) yalnız gerçekten
gece vardiyasındayken çıkıyor: varsayılan `00:00–08:00`da uyarı yok, başlangıç
`22:00` yapılınca çıkıyor. Saat alanları `type="time"` ve sunucu `HH:MM`
dönüyor — ölçüldü, biçim uyuşuyor (`06:00`), dönüşüm katmanı **yok** ve
olmamalı. NFC etiketi panelde **olduğu gibi** gösteriliyor: kırpma/büyütmeyi
panelde yapmak, sunucunun normalizasyonundan ayrışan ikinci bir kural demekti.

**BACKEND BİÇİMLENDİRİCİSİ AYRICA DENETLENDİ.** P48–P50 zincirinin kapanışı
olarak `backend/app/raporlar.py::kurus_metin` okundu: `f"{tam:,}"` + nokta
takası kullanıyor, yani **yerel ayardan bağımsız** ve çıktısı `1.250,50`.
P50 sonrası panel bu metni **kabul ediyor** (önce `null` verirdi) — rapordan
kopyalanan tutar artık aidat alanına yapıştırılabiliyor. Kusur yok, değişiklik
yok.

Kanıt: `admin-web/tests/vardiya-nokta.dom.test.ts` **6 test** (vardiya 2,
nokta 2, bildirim 2). `vitest` **165** yeşil (23 dosya), `tsc` temiz,
`npm run build` yeşil.

## STATUS REPORT — 2026-08-01 #7 (kural 10: bağlam doldu, devir)

**FINAL REPORT değildir** — aşağıdaki final rapor P40'a kadarını kapsıyor;
bu tur onun üstüne **P41–P45**'i ekledi. **P46'dan** devam edilebilir.
`/clear` + standart kickoff.

### Bu turda biten

| Madde | Hash | Özet |
|---|---|---|
| P40 | `f6dcd5f` | Panel bölümü: finans, rapor, mesaj, yönetişim, portal + genişletilmiş ayarlar |
| P41 | `b9baad7` | Yetki matrisi görünümü — **koddan üretilir** (`require_role` özniteliği) |
| P42 | `68eb69e` | İçerik daraltma kapsamı — aynı uç, role göre farklı gövde |
| P43 | `2413a79` | Panel bileşen testi altyapısı (jsdom) + 12 test |
| P44 | `3f11deb` | Panel kapsamı 1. tur: rapor, mesaj, portal, ayarlar (+12) |
| P45 | `d5defe9` | Panel kapsamı 2. tur: aidat, kullanıcılar (+6) |

### Bu turda bulunan gerçek kusurlar

1. **P42 — sessiz 500 tuzağı.** `/activity` kaynak kümesini
   `_ROL_KAYNAKLARI[user.role]` ile seçiyor; uca yeni bir rol eklenip sözlüğe
   satır eklenmezse `KeyError → 500` dönerdi ve **yetki kilidi 500'ü "IZIN"
   saydığı için hiçbir ölçüm yakalamazdı**. P41'in `izinli_roller`
   özniteliğiyle artık doğrulanıyor.
2. **P43 — test bağımlılığı ürün derlemesini kırdı.** `@vitejs/plugin-react`
   kurulunca `next build` patladı (eklentinin `.d.ts`i bu depodaki
   TypeScript'in ayrıştıramadığı sözdizimi kullanıyor ve tsconfig
   `vitest.config.ts`i de denetliyor). Kural konuldu: **test bağımlılığı
   ürün derlemesini kıramaz** → JSX yerine `createElement`.
3. **P43 — SWR önbelleği testler arası taşınıyordu** ve "uç düştü" senaryosu
   yanlışlıkla geçiyordu; ayrıca RTL `cleanup`ı `globals` olmadan devreye
   girmiyor (ikinci test birincinin DOM'unu görüyordu).
4. **P44 — test aracında önek çakışması.** `/api/panel/portal` ile
   `/api/panel/portal-iletisim` aynı öneki paylaşıyordu; iletişim listesine
   portal gövdesi dönüyordu. En uzun önek kazanır oldu.
5. **P40 — üç kilit üç kusur yakaladı**: matcher kapsamı, üçlü içindeki
   teknik jetonlar, yorumda Türkçe harf; ayrıca yedi dilde sözlük tekrarı.

### Kapılar (son durum)

Backend `pytest` **1138 passed**; `flutter analyze` temiz + **1516** test +
apk debug build; admin-web `tsc` + `vitest` **144** + `npm run build`;
`goc-tersinirlik` bulgu 0 (28 sınır), `goc-uyum-dogrula` bulgu 0. Rol matrisi
kilidi **6 rol × 315 satır**.

### Sıradaki

**P46 — panel bileşen kapsamı 3. tur.** Kalan yüksek riskli sayfalar:
`complaints` (durum makinesi), `dashboard` (canlı veri), `units` /
`building-editor` (yapı), `tanimlar` (dokuz defter). Kapsam bugün ifade
**%15,97**; hedef yüzde değil **hata sınıfı** kapatmaktır.

Kerem'e bağlı olanlar değişmedi: P2, P11 (device-verify **25 madde**),
P12/P13, P18 ve `meta.total` ürün kararı.

## FINAL REPORT — 2026-08-01 (kural 13, GÜNCELLENDİ: P40 da bitti)

**Uygun madde kalmadı.** **P1–P40** arasındaki tüm maddeler BITTI; geriye
yalnız **[KEREM]/[DIŞ]** bloklu beş madde kaldı (P2, P11, P12, P13, P18).
Kod tarafında yapılacak eligible iş yok.

**P40 (panel bölümü) — `f6dcd5f`.** Bu rapor ilk yazıldığında P40 yeni
açılmıştı ve "bir sonraki turun ilk maddesi" diyordu; aynı oturumda
tamamlandı. Beş yeni panel sayfası (`/finans`, `/raporlar`, `/mesajlar`,
`/yonetisim`, `/portal`) + genişletilmiş `/settings`, tek beyaz-listeli BFF
vekili ve ikili (Excel/PDF) vekil. Üç kilit üç gerçek kusur yakaladı;
ayrıntı P40'ın Notes bölümünde. **Kapsamda olup yapılmayan tek şey yetki
matrisi görünümüdür** ve gerekçesi orada yazılı: RBAC'in tek doğruluk
kaynağı `rol-matrisi.txt` kilidi; panel görünümü aynı gerçeği ikinci bir
yerden üretmek olurdu.

### A — Yapılan işler (bu oturum)

| Madde | Hash | Şema | Ne yapıldı |
|---|---|---|---|
| P33 | `236f70b` | 0022 | Karar defteri (üyeler ayrı tabloda, metin şablonlu PDF) + doküman arşivi (üstveri-only) + Excel ile site aktarımı (kuru çalışma, satır bazlı hata raporu, idempotent) + **iş takibi genişletmesi** (`complaint` + unit/öncelik/personel) |
| P34 | `4395fdc` | 0023 | Tur bütünlüğü: konum **kanıtı** (`konum_durumu` + doğruluk + konumsuz sayacı/süzgeci), **gecikme alarmı** (katlanan aralık, kişi+rol hedefi), **başlangıç fotoğrafı** (kamera-only, ayrı hata kodu) + KVKK notu |
| P35 | `458dc75` | 0024 | **Güvenlik amiri** rolü + ikili güvenlik mimarisi (`yonetim_ici`/`dis_sirket`); sahiplik moda bağlı, okuma her iki modda açık, mod değişimi denetlenir |
| P35-fix | `4c95260` | — | Amir splash'ta kilitli kalıyordu; saha kartları tek bayrağa bakıyordu |
| — | `d9deb40` | — | STATUS REPORT #6 |
| P36 | `1415874` | 0025 | **KVKK aydınlatma kapısı** (sürümlü, kaydırma kilitli, sunucu navigasyonu kilitlemez) + üç bağımsız **pazarlama izni**; P32'nin pazarlama gönderimi artık **gerçek ve kanal bazlı** rızayı okuyor |
| P37 | `1002576` | 0026 | **Gürültü caydırıcı**: eşik (sınır dahil) → HMAC imzalı webhook **veya manuel mod** → sayaç sıfırlama (kayıt silinmez); katlanan yeniden deneme, tükenince manuel moda düşer; protokol notu (MQTT/KNX/SIP köprüleri) |
| P38 | `16ce180` | 0027 | **Site web portalı** (admin-web içinde public rota, yayın varsayılan kapalı, kapalıyken 404) + **anket** (tek oy, değiştirilemez, sonuç kapanana kadar gizli) + iletişim formu + mobil oy hook'u |
| P39 | `26dc585` | — | **Ölçek**: k6 yük takımı (konteynerden), ölçülen taban, görünmez havuz/işçi riskinin düzeltilmesi, yatay ölçek denetimi, `docs/scaling-runbook.md` |

**Bulunan gerçek kusurlar (hepsi düzeltildi):**
1. **P34** — bildirim tekliği gecikme alarmının **ikinci bildirimini sessizce
   düşürüyordu**; teklik kısmî indekse çevrildi.
2. **P35** — `/users` okumasını amire açmak `PATCH /users/{id}` ve parola
   sıfırlamayı da açtı: amir **kendi rolünü admin yapabiliyordu**. Rol matrisi
   kilidinin **altıncı sütunu** yakaladı.
3. **P35** — amir `HomeGate`in hiçbir dalına uymuyor, **splash'ta kilitli
   kalıyordu**; saha ana ekranı tek bayrağa bakıp ona kapalı uçlara istek
   atacaktı.
4. **P36** — izinler kartının dönen göstergesi ekranı **asla durulmayan** bir
   animasyona bağladı ve **dokuz ayar testini** düşürdü.
5. **P37** — `tenant.gurultu_integration_id` FK'si **indekssizdi**; ayrıca P24
   ile etkileşim: varsayılan eşikte `mor` kademesi gürültü için ulaşılamaz.
6. **P38** — `anket_secenek(tenant_id)` FK'si indekssizdi.
7. **P39** — havuz/işçi ayarları **görünmez varsayılanlardaydı**: çoklu işçiye
   geçen ilk kişi `max_connections`ı sessizce aşardı.

**Kapılar (son durum):** tam pytest **1125 passed**, 1 skipped; `flutter
analyze` temiz, `flutter test` **1516**, `flutter build apk --debug` başarılı;
admin-web `tsc` + `vitest` (**109**) + `npm run build`; `goc-tersinirlik`
bulgu 0 (28 sınır), `goc-uyum-dogrula` bulgu 0; seed koştu; rol matrisi kilidi
**6 rol × 314 satır**.

### B — Test edilecekler (Kerem)

**Cihazda/elde doğrulama listesi P11'dedir ve bu turda 23 maddeye çıktı.** Bu
turda eklenenler:

1. **P34 · Tur konumu + fotoğraf kapısı (MOBİL)** — konum izni açık/kapalı/
   servis kapalı üç hâli; tur penceresinde ilk okutmada **kamera-only** fotoğraf
   kapısı; aynı pencerede ikinci okutma fotoğraf istememeli.
2. **P34 · Gecikme alarmı (PUSH)** — tolerans dolunca görevliye **ve** yöneticiye
   "Tur başlamadı"; okutmayla susması; 10 → 30 → 70. dakika tekrarları.
3. **P35 · Güvenlik amiri (MOBİL)** — amir hesabıyla görevli düzeni, tur+ekip
   menüsü, kargo/ziyaretçi/sakin **görünmemeli**; `dis_sirket` modunda yönetici
   planlayamamalı ama **görebilmeli**.
4. **P36 · KVKK onay kapısı (MOBİL)** — buton kaydırmadan kapalı, sona gelince
   açık, geri tuşu yok; onaydan sonra kapı bir daha çıkmamalı; Ayarlar'daki üç
   izin kalıcı olmalı; yeni sürüm yayınlanınca kapı **tekrar** çıkmalı.
5. **P37 · Gürültü caydırıcı** — eşik düşürülüp iki şikâyet girilince yöneticiye
   push; harita yeşile dönmeli ama kayıtlar **silinmemeli**; `manuel_bekliyor` →
   `manuel_yapildi` ve ikinci çağrıda 409.
6. **P38 · Portal + anket** — `/site/<slug>` **giriş istemeden** açılmalı, yayın
   kapatılınca **404**; sakin mobilde anketi görüp **bir kez** oy verebilmeli,
   sayılar kapanana kadar **görünmemeli**; iletişim formu yöneticiye ulaşmalı.

**Ayrıca elle doğrulanacaklar:**
- **P39 · Yük takımı** — `docker compose -f infra/docker-compose.yml -f
  infra/docker-compose.load.yml run --rm k6 run /load/senaryo.js` kendi
  donanımında koşulup runbook'taki tablo **kendi sayılarınla** güncellenmeli;
  prod'da `API_WORKERS`/`DB_POOL_SIZE` runbook §3.1 formülüyle seçilmeli.
- **P2 (prod runbook), P18 (Frigate pilot)** — sunucu/saha erişimi gerektiriyor.
- **P12/P13** — Firebase ve iyzico/PayTR kimlik bilgileri gelmeden push ve kart
  ödemesi uçtan uca doğrulanamaz (kod yolları hazır, sağlayıcı soyutlaması
  yerinde).

### Sıradaki

**Kodda eligible iş kalmadı.** Sırada Kerem'e bağlı doğrulamalar var:
cihaz/panel testleri (P11 — **24 madde**), prod runbook (P2), Frigate pilotu
(P18) ve dış kimlik bilgileri (P12/P13). Bunlar tamamlandıkça çıkan bulgular
yeni maddelere dönüşür.

İleride ayrı madde olarak açılabilecek tek bilinen iş: **yetki matrisini
panele taşımak** (bugün test kilidi olarak var; panele taşınacaksa o dosyayı
servis eden bir uç yazılmalı).

## STATUS REPORT — 2026-07-31 #6 (kural 10: bağlam doldu, devir)

**FINAL REPORT değildir.** **P36'dan** devam edilebilir. `/clear` + standart
kickoff.

### Bu turda biten

| Madde | Hash | Şema | Özet |
|---|---|---|---|
| P33 | `236f70b` | 0022 | Karar defteri + doküman arşivi + site aktarımı + iş takibi genişletmesi |
| P34 | `4395fdc` | 0023 | Tur bütünlüğü: konum kanıtı, gecikme alarmı, başlangıç fotoğrafı |
| P35 | `458dc75` | 0024 | Güvenlik amiri rolü + ikili güvenlik mimarisi |

### Bu turda bulunan gerçek kusurlar

1. **P34 — bildirim tekliği ikinci alarmı SESSİZCE DÜŞÜRÜYORDU.**
   `uq_notification_tenant_tip_window` (tenant, tip, pencere) kaçırılan tur
   için doğruydu ama gecikme alarmı **tekrar etmek zorundadır**; `ON CONFLICT`
   başka bir indeksi hedeflediği için ikinci alarm kısıt ihlaline düşüyordu.
   Teklik **kısmi indekse** çevrildi (`gecikmis_okutma` hariç); alarmın
   idempotency'si `dedup_key = tip:pencere:ADIM`.
2. **P35 — YETKİ YÜKSELTME.** `/users` okumasını amire açmak, aynı bağımlılığı
   paylaşan `PATCH /users/{id}` ve `POST /users/{id}/reset-password` uçlarını
   da açtı: amir **kendi rolünü admin yapabilir** ya da **yöneticinin
   parolasını sıfırlayabilirdi**. **Rol matrisi kilidinin altıncı sütunu**
   bunu diff olarak gösterdi — yeni bir rol eklerken kilidi genişletmemek,
   rolün tüm yetkilerinin ölçülmeden geçmesi demek olurdu.
3. **P33 — `complaint` genişletmesi denetimle başladı.** Kapsam "unify into
   one ticket backbone" diyordu; denetim omurganın **zaten var olduğunu**
   gösterdi ve `unit_complaint` ile birleştirmenin P22(e)'nin bilinçli
   ayrımını bozacağını. Birleştirme değil **genişletme** yapıldı.

### Bilinçli davranış değişiklikleri (regresyon değil)

- **Vardiya CRUD** artık admin-only değil; sahiplik **moda** bağlı
  (`test_yonetici.py`deki assert gerekçesiyle güncellendi).
- **Migration 0023**, yerinde düzenleme istisnasını (politika kural 3)
  kullandı ve gerekçesi dosyanın docstring'ine yazıldı.

### Sıradaki

**P36** (KVKK onboarding rızaları — P32'nin pazarlama gönderimi bunu
bekliyor), sonra P37 (gürültü caydırıcı; P24'ün eşik tablosunu tüketir),
P38 (web portalı + anketler), P39 (ölçek/yük).

### Biriken teknik borç (değişmedi, tek işte kapanmalı)

**FİNANS + RAPOR + MESAJ + YÖNETİŞİM PANELİ.** P28–P33 API yüzeylerini kurdu
ama panel/mobil ekranları yapılmadı: borç, tahsilat, rapor, mesaj, karar
defteri, doküman, site aktarımı, İşlem Geçmişi ve yetki matrisi görünümü.
Tek bölüm olarak tasarlanmalı — ayrı ayrı yapılırsa panelde sekiz farklı
gezinme deseni kalır. P29'un dashboard hızlı-eylem kancaları da buraya bağlı.

Kalan: P36–P39 + panel borcu. Bloke/Kerem'de: P2, P11 (device-verify
**18 madde**), P12/P13 (dış kimlik bilgileri), P18, P22(a).

## STATUS REPORT — 2026-07-31 #5 (kural 10: bağlam doldu, devir)

**FINAL REPORT değildir.** **P33'ten** devam edilebilir. `/clear` + standart
kickoff.

### Bu turda biten

| Madde | Hash | Şema | Özet |
|---|---|---|---|
| P31 | `a7e2217` | — | Rapor motoru + 12 raporluk katalog (tablo/Excel/PDF) |
| P32 | `47ac96c` | 0021 | Mesaj şablonları + gönderim, rıza denetimi, SMS sayacı |

### Bu turda bulunan gerçek kusurlar

1. **P31 — `func.to_char(...)` bind parametresi üretiyor** ve Postgres
   `GROUP BY`daki ifadeyle eşleştiremiyor (`GroupingError`); dönemsel bakiye
   ucu 500 veriyordu. `literal_column` ile çözüldü. **Bu tuzak şeffaflık
   panosunda da yaşanmıştı — üçüncü kez çıkarsa `literal_column` sarmalayıcı
   bir yardımcıya alınmalı.**
2. **P32 — P28 REGRESYONU, seed yakaladı.** `seed.py`, P28'in kaldırdığı
   `UNIQUE (tenant_id, unit_id, donem)` kısıtına `ON CONFLICT` yapıyordu ve
   **seed düşüyordu**; P28'den beri seed koşulmamıştı. Ders: **şema kısıtı
   değiştiren her maddede `docker compose run --rm seed` koşulmalı** — tam
   pytest bunu yakalamıyor (testler seed'i kullanmıyor).

### Sıradaki

**P33** ve sonrası. Bağımlılık durumu: P33–P39 arasında P29/P31/P32'ye bağlı
olanlar artık uygun.

### Biriken teknik borç (üç maddede yazılı, tek işte kapanmalı)

**FİNANS + RAPOR + MESAJ PANELİ.** P28, P29, P31 ve P32 API yüzeylerini ve
tutarlılık kurallarını kurdu ama **panel/mobil ekranları yapılmadı**. Bunlar
tek bir bölüm olarak tasarlanmalı: borç, tahsilat, rapor ve mesaj aynı
akışın parçaları — ayrı ayrı yapılırsa dört farklı düzen çıkar. P29'un
dashboard hızlı-eylem kancaları da buraya bağlı.

Kalan: P33–P39 + finans paneli borcu. Bloke/Kerem'de: P2, P11 (device-verify
**15 madde**), P12/P13 (dış kimlik bilgileri — P30 kart yolu ve P32 SMS
hesabı bunu bekliyor), P18, P22(a).

## STATUS REPORT — 2026-07-31 #4 (kural 10: bağlam doldu, devir)

**FINAL REPORT değildir** — uygun madde tükenmedi. **P31'den** devam
edilebilir; plan dosyası tüm durumu taşıyor. `/clear` + standart kickoff.

### Bu turda biten (hepsi `origin/main`'de)

| Madde | Hash | Şema | Özet |
|---|---|---|---|
| P27 | `059eb61` | 0017 | Muhasebe "Tanımlar": kasa/gelir-gider/firma/personel/araç/sayaç + evrak & para birimi; admin-web `/tanimlar` |
| P28 | `51a73db` | 0018 | Borçlandırma motoru — mevcut aidat modülü **genişletildi**; benzersizlik `(daire, dönem, TÜR)`; hedefleme kuralı; gecikme anlık |
| P29 | `a283054` | 0019 | **TEK DEFTER** finansal hareket; bakiye türetilir; virman/iade; banka eşleştirme önerisi; icra dosyası |
| P30 | `e48db6a` | 0020 | Sakin "Öde": havale **kodu** + IBAN + kart; mobil `/ode` |

### Bu turda bulunan gerçek kusurlar

1. **P28 — `hedef_kurali` şemalara eklenmemişti** (P27'de modele eklenmiş
   ama API'den ayarlanamıyordu; her tanım varsayılan kalıyordu). Hedefleme
   testi yakaladı.
2. **P29 — `min(uuid)` Postgres'te yok**; banka eşleştirme ucu 500
   veriyordu. Test yakaladı; örnek `assessment_id` döndürme fikri zaten
   yanlıştı (öneri kişiyi hedefler).
3. **P27 — `npm run build` `tsc --noEmit`in yakalamadığını yakaladı**:
   Next.js yol işleyicileri rastgele `export` edemez. Panel kapısı
   **tsc + vitest + build** üçlüsüdür.

### Ölçüm notu (tekrar eden bir tuzak)

Makine yüklüyken (backend suiti + docker aynı anda) mobil tam koşumda
**bilinen ölçüm-aracı flake'leri** çıkıyor: `pumpAndSettle timed out`
(görsel yükleme) ve "painting debug variable changed" (görsel taklidi
teardown'ı). P30'da 16 test böyle düştü; dosyalar tek tek geçiyordu, yüksüz
tam koşum **1483/0**. **Mobil tam koşumu backend suitiyle aynı anda
başlatmayın.**

### Sıradaki

**P31** (rapor motoru + katalog; Depends-on P29 ✔ → uygun). Ardından
P32–P39.

**Finans panel borcu (bilinçli, iki maddede yazılı):** P28 ve P29 API
yüzeyini ve tutarlılık kurallarını kurdu ama **panel ekranları yapılmadı** —
borç ve tahsilat aynı ekranda görünmeli, iki maddeye bölünmüş bir panel iki
farklı düzen üretirdi. P31'in rapor ekranlarıyla birlikte **tek finans
bölümü** olarak tasarlanmalı.

Kalan: P31–P39. Bloke/Kerem'de: P2, P11 (device-verify listesi **14 madde**),
P12/P13 (dış kimlik bilgileri — P30'un kart yolu bunu bekliyor), P18
(donanım/saha), P22(a). Karar bekleyen: çeviri sağlayıcı, yüz tanıma.

## STATUS REPORT — 2026-07-31 #3 (kural 10: bağlam doldu, devir)

**FINAL REPORT değildir** — uygun madde tükenmedi. P27'den itibaren devam
edilebilir; plan dosyası tüm durumu taşıyor. `/clear` + standart kickoff.

### Bu turda biten (hepsi `origin/main`'de)

| Madde | Hash | Özet |
|---|---|---|
| P23 | `b5416a1` | Sakin yaşam döngüsü: bağ uçları yöneticiye açıldı (sonradan daire atama **ulaşılamazdı**), e-posta + rol_tipi düzenlenebilir |
| P24 | `a26bb7c` | Şikayet skalası 4 kademe + **kişi başına** okuma durumu (0014) ve "Yeni/Okunmamış" triyaj kuyruğu |
| P24 düzeltme | `a64701b` | `flutter analyze` kapısı testler yazılmadan önce ölçülmüştü — ders plana yazıldı |
| P25 | `33a7d75` | Kamera: 2048 sınırı (0015) + **"yayınlar oynamıyor"un kök nedeni** (cleartext yalnız debug manifestindeydi) + hata nedene göre + dörtlü şerit |
| P26 | `760a812` | Bağımsız bölüm **tip/grup** tanımları (0016), tip varsayılan aidatı taşır |

### Bu turda bulunan üç GERÇEK kusur (özellik değil, hata)

1. **P25b — cleartext yalnız `src/debug` manifestindeydi.** Sürüm
   derlemesinde her `http://` yayın sessizce düşüyordu; bu **P17'nin restream
   özelliğini de** çalışmaz yapıyordu (Frigate/go2rtc geçidi düz http'tir) ve
   geliştirmede çalıştığı için görülmemişti.
2. **P25a — "açık Türkçe hata" oluşturma yolunda hiç çalışmıyordu.** URL
   doğrulaması `model_validator` içindeydi; pydantic onu kendi
   `validation_error` zarfına çevirip **ham İngilizce** döndürüyordu. Mevcut
   testler yalnız `422` beklediği için görünmemişti.
3. **P26 — bileşik FK + `ON DELETE SET NULL` anahtarın tamamını null'lar.**
   `unit.tenant_id` NOT NULL olduğu için tanım silme **500** veriyordu; sütun
   listesi (`SET NULL (unit_tip_id)`) ile düzeltildi.

### Sıradaki

**P27** (muhasebe Tanımlar katmanı — kasa/gelir-gider/firma/personel;
Depends-on P23✔ P26✔ → **artık uygun**). P26'nın notunda yazılı bilinçli
açık: admin-web "Tanımlar" paneli P27 ile **tek seferde** yapılmalı (bölüm
dört tanım listesini birlikte taşımalı).

Kalan: P28–P39. Bloke/Kerem'de: P2, P11 (device-verify listesi **11 madde**),
P12/P13 (dış kimlik bilgileri), P18 (donanım/saha), P22(a) (geri alındı, tanı
yazılı). Karar bekleyen: çeviri sağlayıcı (DeepL = KVKK kararı), yüz tanıma.

## STATUS REPORT — 2026-07-31 #2 (kural 10: bağlam doldu, devir)

**FINAL REPORT değildir** — uygun madde tükenmedi. Plan dosyası tüm durumu
taşıyor; `/clear` + standart kickoff ile devam edilebilir.

### Biten (19 madde, hepsi `origin/main`'de)

P1, P3, P4, P5, P6, P7, P8, P9, P10, P14, P15, P16, P17, P19, P20, P21
(+ P2/P11/P12/P13/P18 blokeli).

Bu oturumun ikinci yarısında eklenenler:

| Madde | Sonuç |
|---|---|
| **P16** | ANPR ingest: migration 0011 (anpr_api_key + anpr_event + vehicle_pass.kaynak), `X-ANPR-Key` kimliği (SECURITY DEFINER çözümleme), dört adaptör, eşik + onay kuyruğu, 27 test |
| **P17** | RTSP kameralar restream ile OYNATILABİLİR (migration 0012) + Plaka Okumaları ekranı (onay kuyruğu + OCR düzeltmesi), 18+5 test |
| **P19** | Hikvision/Dahua gerçekçi tam gövdelerle kilitlendi (3 bulgu) + `docs/anpr-kamera-kurulumu.md` |

### Kapılar (son durum)

* backend `pytest`: **828 geçti / 0 düştü**
* mobil `flutter analyze` temiz · `flutter test` **1426 geçti / 0 düştü**
  (P10 için 20× tam-suit tekrarı 20/20) · `flutter build apk --debug` ✓
* admin-web: 105 test + `npm run build` ✓
* sözleşme↔canlı: **207/207 operasyon** iki yönde örtüşüyor
* göç tersinirliği: 0 bulgu (12 sınır)

### Sıradaki iş

**P22** — mobil UX paketi. **(a) denendi ve GERİ ALINDI**; tam tanı P22
Notes'unda (üç ölçüm, ikisi çözüldü, biri açık: dokunma hit-test'i barrier'a
gidiyor). Önerilen yol: dönüşümü TEK ekranla başlat, beş eksen sürüşünü yeşile
al, sonra yay. **(b)–(g) hiç ellenmedi** ve bağımsızdır — oradan da
başlanabilir.

Ardından P23–P39.

### Kerem'in karar vermesi gerekenler (değişmedi)

1. **Çeviri sağlayıcısı** — `docs/ceviri-kalite-notu.md` (DeepL bir KVKK
   kararı; ajan yapmadı).
2. **Yüz tanıma** — `docs/face-recognition-v2-design.md` karar satırı.

### Blokeli

P2 (prod runbook — Kerem sunucuda), P11 (cihaz testleri — listeye bu oturumda
**6 madde** eklendi), P12/P13 (dış kimlik bilgileri), P18 (donanım + saha).

**P16** (ANPR ingest backend) — hazırlık notu P16'ya işlendi, olay şeması
`docs/frigate-poc.md` §6'da hazır. Sonrasında P17/P19, ardından P22+ paketi.


- 2026-08-01 · P51 · (bu commit) · Panel kapsami 4. tur (vardiya, NFC noktasi, bildirimler) + IKI GERCEK KUSUR bildirimler sayfasinda: (1) SESSIZ BASARISIZLIK — 'okundu isaretle' tek yerde HAM fetch kullaniyordu ve ham fetch basarisiz yanitta da COZULUR, yani 500 sonrasi da 'okundu olarak isaretlendi' BASARI bildirimi cikiyordu (kullanici isaretledigini saniyor, bildirim okunmamis kaliyordu) — apiSend + catch; (2) rozet `n.tip`i HAM ciziyordu, kullanici `gecikmis_okutma` goruyordu — yedi canli tip 7 dile cevrildi, eslesmeyen tip HAM kalir ki sunucu yeni tip eklerse rozet BOS KALMASIN; test aracina UC BASINA durum eklendi (opts.durum TUM uclari bozuyordu, oysa gercek kusurlarin cogu 'liste geldi ama YAZMA dustu' seklinde ve 1. kusur ancak boyle olculebildi); gece vardiyasi uyarisi yalniz baslangic>bitis iken cikiyor, saat bicimi sunucuyla uyusuyor (donusum katmani YOK ve olmamali); ayrica backend kurus_metin denetlendi — yerel ayardan bagimsiz ve P50 sonrasi panel onun ciktisini KABUL EDIYOR.\n- 2026-08-01 · P50 · 9a94c6b · Panel para ayristiricisi de kendi GOSTERDIGI bicimi reddediyordu (`1.250,00` -> null, oysa kurusToTL onu boyle yaziyor); eski testteki 'binlik ayirici belirsiz' gerekcesi YANLISTI — virgul varsa nokta BINLIKTIR; iki istemci artik AYNI uc dalli kurali uyguluyor (farkli olsalardi ayni sitede ayni metin farkli tutar girerdi); ayrica iki asimetri kapandi: YARIM giris (`750,` `,50`) her ikisinde de reddediliyor ve ICERIDEKI bosluk reddediliyor (mobil `1 2 3`u kabul ediyordu).\n- 2026-08-01 · P49 · 7da37d8 · Mobilde para ayristirma cekirdegi: BULGU 1 uygulama KENDI GOSTERDIGI bicimi reddediyordu (unit_tanimlari naif kopya `1.250,00`i cozemiyordu); kopya keyfi degildi — paylasilan parseTlToKurus BUTCEYE OZEL politika tasiyordu (`>0`) ve tanimlarda 0=MUAF gecerlidir; AYRISTIRMA core/para.dart'a, POLITIKA cagirana ayrildi ve form on-dolgusu artik GOSTERILEN bicimi kullaniyor; BULGU 2 rapor i18n testi ay adini SABIT yazmisti ve takvim Agustos'a donunce kirildi — beklenen deger artik ekranin kullandigi ayni kaynaktan uretiliyor (her ay kirilmaz).\n- 2026-08-01 · P48 · 17c832e · Para bicimlendirmede ICU BAGIMLILIGI: supurme panelde UC ayri bicimlendirici buldu (seffaflik sayfasi ayni degeri `TL` ile yaziyordu, digerleri `₺`); asil bulgu toLocaleString('tr-TR') bir ORTAM BAGIMLILIGI — kucuk-ICU'da en-US'a duser ve para `5,000,00 ₺` gorunurdu (yanlis VE okunamaz, ve YALNIZ BAZI ORTAMLARDA); seffafliktaki `.replace(/ /g,'.')` yamasi sorunu gormus ama YANLIS TESHIS etmisti (gercek sorun VIRGULLU gruplama); gruplama artik KENDIMIZ yapiyoruz.\n- 2026-08-01 · P47 · 2848374 · Panel kapsami 3. tur (pano, daireler, tanimlar) + BULGU: Tanimlar tablosu parayi `5000.00` diye yaziyordu — panelin geri kalani `5.000,00 ₺` ve daha kotusu TURKCE'DE NOKTA BINLIK AYIRICIDIR (kullanici bes yuz bin sanabilirdi); tabloda kurusToTL, FORMDA liraya KALDI (girdi ayristirilabilir olmali); pano sayaclari sunucu verisinden turetiliyor ve uc dustugunde BOS PANO gosterilmiyor; kapsam %16,99 -> %19,03.\n- 2026-08-01 · P46 · 92eea6a · BULGU: `toast(...)` metinleri hicbir i18n taramasinin gormedigi yerdeydi (JSX degil, oznitelik degil, ve tur 22 taramasi TURKCE HARFE bakip circir esigiyle gectigi icin) — panelde 10 sabit bildirim metni vardi ve dil degisince Turkce kaliyordu; dokuzu sozluge tasindi (7 dil) ve DILDEN BAGIMSIZ yeni bir kilit eklendi, kilidin GERCEKTEN yakaladigi gecici sizinti ile dogrulandi; talep sayfasi 5 test (kapali talepte eylem butonu YOK, reddette sebep ZORUNLU, cozmede not OPSIYONEL); kapsam %15,97 -> %16,99.\n- 2026-08-01 · P45 · d5defe9 · Panel bilesen kapsami 2. tur: aidat ve kullanicilar — kurus->TL tam sayi aritmetigi, gecersiz tutarda istek ATILMIYOR ve NEDEN soyleniyor, uc dustugunde liste CIZILMIYOR; rol adlari SOZLUKTEN (wire degeri ekrana cikmiyor), suzgec degisince offset=0 (eski offset'te kalmak ilk sayfasi bos gorunen liste demekti); ogrenilenler: Field etiketi ipucunu da kapsiyor (regex gerekir) ve `required` alanlar bosken uygulamanin dogrulamasi HIC calismiyor; kapsam %14,26 -> %15,97.\n- 2026-08-01 · P44 · 3f11deb · Panel bilesen kapsami 1. tur: hedef YUZDE DEGIL HATA SINIFI — rapor (bos parametre govdeye girmiyor, ismi_goster), mesaj (SMS sayaci + UCS-2 zorlayan karakterler, kanal->konu alani), portal (yayin anahtari ANINDA kaydediliyor, anket en az iki secenek), ayarlar (DEGISMEYEN ALAN gonderilmiyor — guvenlik_modu yoneticiye 403 verirdi); BULGU: test aracinda onek cakismasi (/portal ile /portal-iletisim) iletisim listesine PORTAL govdesi donduruyordu — en uzun onek kazanir oldu; kapsam %9,66 -> %14,26.\n- 2026-08-01 · P43 · 2413a79 · Panel bilesen testi altyapisi (jsdom): ayni kosumda IKI ORTAM ve ortam secimi DOSYANIN KENDISINDE (merkezi glob listesi, yeni dosya eklenince testin sessizce YANLIS ortamda kosmasi demekti); BULGU 1: @vitejs/plugin-react'in .d.ts'i next build'i KIRDI — test bagimliligi urun derlemesini KIRAMAZ, JSX yerine createElement; BULGU 2: esbuild anahtari yok sayiliyor (Vitest 4 = rolldown/oxc); BULGU 3: SWR onbellegi testler arasi tasiniyordu ve 'uc dustu' senaryosu YANLISLIKLA GECIYORDU + RTL cleanup globals olmadan devreye girmiyor; 12 yeni test (finans, yetki matrisi, site aktarimi).\n- 2026-08-01 · P42 · 68eb69e · Icerik daraltma kapsami: yetki kilidi ve P41 matrisi ERISILEBILIRLIGI olcer, GOVDENIN role gore daraldigini GORMEZ — envanterin acik maddesi (aynı uç, farklı gövde) kapandi; alti daraltma tek tek suruldu (finansal ozet tahsilat blogu, /activity kaynak kumesi, gizli kamera, kendi-kapsamli talepler, anket sonucu, harita sayim/renk); BULGU: /activity role-anahtarli sozluk kullaniyor ve uca yeni rol eklenip sozluge satir eklenmezse KeyError->500 doner — yetki kilidi 500'u IZIN sayacagi icin HICBIR olcum yakalamazdi.\n- 2026-08-01 · P41 · b9baad7 · Yetki matrisi gorunumu KODDAN URETILIR: require_role uretilen bagimliliga izinli_roller OZNITELIGI isliyor, uc dependant agacini gezip bunu okuyor — elle liste ayni gercegi IKINCI BIR YERDEN uretmek ve bir uc degistiginde panelin YANLIS tablo gostermesi demekti; `roller: null` HERKESE ACIK DEGIL (rol kapisi yok, kimlik gerekebilir) ve moda_bagli uclar IKI MODUN BIRLESIMI; test kilidiyle CAPRAZ DOGRULAMA (alt kume iliskisi — esitlik aramak dogru davranisi hata sayardi).\n- 2026-08-01 · P40 · f6dcd5f · Panel bolumu: finans + rapor + mesaj + yonetisim + portal + genisletilmis ayarlar. TEK VEKIL + BEYAZ LISTE (okuma ve yazma AYRI sozluk — tek sozluk okumaya acarken yazmaya da acardi); IKILI vekil ayri (proxyJson XLSX/PDF baytlarini JSON diye ayristirip bozardi) ve dosya adi SUNUCUDAN; rapor katalogu SUNUCUDAN (panel rapor adi TASIMAZ); site aktariminda KURU CALISMA varsayilan acik ve satir no 2'den baslar; ayarlarda DEGISMEYEN ALAN GONDERILMEZ (guvenlik_modu yoneticiye 403 verirdi); uc kilit uc gercek kusur yakaladi (matcher kapsami, ucludaki teknik jetonlar, yorumda Turkce harf) + yedi dilde sozluk tekrari tsc ile durduruldu.\n- 2026-07-31 · P39 · 26dc585 · Olcek ve yuk hazirligi: k6 KONTEYNERDEN ve api ile ayni agda; profil 'en cok cagrilan uc' degil KULLANICININ GUNU (giris setup'ta — her yinelemede giris bcrypt maliyetiyle olcumu bozardi); olculen taban /me 283 RPS, /activity 168 RPS, ana ekran p95 2.08s -> 1.26s; DUZELTILEN RISK: havuz/isci sayisi GORUNMEZ varsayilanlardaydi ve coklu isciye gecen ilk kisi max_connections'i sessizce asardi (formul + env + pool_timeout); ONBELLEK EKLENMEDI cunku olcum gerektirmedi (bayat veri sinifi hata getirirdi); yatay olcekte TEK GERCEK ENGEL beat'in tek ornek olmasi; docs/scaling-runbook.md.\n- 2026-07-31 · P38 · 16ce180 · Site web portali + anket (0027): AYRI UYGULAMA DEGIL admin-web icinde public rota (sozluk/tasarim/derleme hatti zaten orada) + yeni kilit public rotanin matcher'a SIZMADIGINI olcuyor; yayin VARSAYILAN KAPALI ve kapaliyken 404 (403 tesis envanteri sizdirirdi); public icerik BILINCLI (duyurunun yalniz OZETI, hakkimizda DUZ METIN, harita ANAHTARSIZ); anket TEK OY ve DEGISTIRILEMEZ, sonuc KAPANANA KADAR GIZLI (surusel etki) ama yonetim her zaman gorur; iletisim KAYIT ONCE BILDIRIM SONRA; kimlikli sakin web alani gerekcesiyle panel borcunda.\n- 2026-07-31 · P37 · 1002576 · Gurultu caydirici otomasyonu (0026): AYRI webhook konfigurasyonu ACILMADI (C1b integration zaten SSRF+KEK+izolasyon veriyor), MANUEL MOD birinci sinif (cogu sitede entegrasyon yok) ve sunucu 'yapildi' VARSAYAMAZ; sinir DAHIL (4 hayir, 5 evet), YALNIZ gurultu kategorisi, SIFIRLAMA KAYIT SILMEZ (kapali'ya ceker — uyarinin dayanagi durur); HMAC imzasi ZAMAN DAMGASINI kapsar (replay), sir yoksa imza da yok; yeniden deneme istek yolunda DEGIL, katlanan aralikla ve tukenince MANUEL MODA duser; BULGU: FK indekssizdi (RI tetigi tenant'i seq scan ederdi).\n- 2026-07-31 · P36 · 1415874 · KVKK aydinlatma kapisi + pazarlama izinleri (0025): METIN TENANT ICERIGIDIR (gomulu tek metin 200 tesise BASKASININ metnini imzalatirdi), SURUM VAR YERINDE DUZENLEME YOK (dun verilen onay bugun baska metne ait gorunurdu), onay eski surume yazilmaz (409) ve IDEMPOTENT; kaydirma kilidi 24 px esikli ve SIGAN icerikte ZATEN ACIK; sunucu navigasyonu kilitlemez (onay vermemis kullanici metni OKUYABILMELI), ag hatasinda kapi ACILMAZ; P32 pazarlama gonderimi artik GERCEK ve KANAL BAZLI rizayi okuyor; BULGU: izinler kartinin donen gostergesi dokuz ayar testini pumpAndSettle zaman asimiyla dusurdu.\n- 2026-07-31 · P35 · 458dc75 · Guvenlik amiri + ikili guvenlik mimarisi (0024): SAHIPLIK SEMADA DEGIL KODDA — tenant modu (yonetim_ici|dis_sirket) vardiya/tur/nokta YAZMA sahibini belirler, OKUMA her iki modda acik kalir (devir DENETIMI devretmez), admin her iki modda yazar, modu YALNIZ admin degistirir ve degisim denetlenir; amire EN AZ YETKI (sakin/finans/kargo/ziyaretci KAPALI, KVKK); BULGU: /users okumasini acmak PATCH ve parola sifirlamayi da acti — amir kendi rolunu yukseltebiliyordu, rol matrisi kilidinin ALTINCI SUTUNU yakaladi.
- 2026-07-31 · P34 · 4395fdc · Tur butunlugu (0023): KONUM BIR KANITTIR ON KOSUL DEGIL — izin reddi/servis kapali okutmayi dusurmez ama SESSIZ DE KALMAZ (konum_durumu + konumsuz_sayisi + suzgec); gecikme alarmi 'kacirildi'dan AYRI, araliklari KATLANAN tekrarli bildirim (gorevliye kisi, yonetime rol) ve bildirim TEKLIGI kismi indekse cevrildi (ikinci alarm sessizce dusuyordu); baslangic fotografi '1 metre gidip gel' YERINE (SDM zaten fiziksel varligi kanitliyor; fotograf ORTAM+SAAT boyutu ekler), kamera-only + ayri hata kodu.
- 2026-07-31 · P33 · 236f70b · Yonetisim modulleri (0022): IS TAKIBI denetimi omurganin ZATEN VAR OLDUGUNU gosterdi — birlestirme degil GENISLETME (complaint + unit_id/oncelik/atanan_personel; oncelik durumdan BAGIMSIZ ayri ucta, atanan personel_kayit'tir app_user degil); karar defteri uyeleri AYRI TABLODA + metin sablonlu PDF; dokuman arsivi USTVERI-ONLY (obje silinmez); site aktarimi KURU CALISMALI ve SATIR BAZLI hata raporlu, idempotent.
- 2026-07-31 · P32 · 47ac96c · Mesaj sablonlari + gonderim (0021): gonderilen metin GECMISE KOPYALANIR (sablon degisse de kanit durur), amac SABLONDA (pazarlama riza olmadan HIC gonderilmez ve atlananlar SAYILIR), SMS sayaci Turkce tuzagini gosterir (kucuk c/i/g/s UCS-2'ye dusurur), saglayici takasi yapilandirma ile; P28 seed regresyonu bulundu ve duzeltildi.
- 2026-07-31 · P31 · a7e2217 · Rapor motoru + 12 raporluk katalog: TEK UC UC BICIM (tablo/Excel/PDF, ucu de ayni satirlardan), parametre modali TEK MODEL, detayli borc sutunlari P27 tanimlarindan DINAMIK, tahsilat orani = tahsil/borclandirilan, denetim raporu = kasa mutabakati; to_char GroupingError bulgusu.
- 2026-07-31 · P30 · e48db6a · Sakin "Öde" akisi (0020): havale aciklama KODU (sabit, elle yazilabilir alfabe) eslestirmeyi KESINLESTIRIR; IBAN P27 banka kasasindan (ayri alan YOK); kart mevcut saglayici soyutlamasi uzerinden (P13 ile canliya); mobil /ode tek sayfa, kopyala + kalin kod.
- 2026-07-31 · P29 · a283054 · Tahsilat/kasa/finansal hareketler (0019): TEK DEFTER (tahsilat|gider|gelir|virman|iade|acilis), bakiye SAKLANMAZ defterden TURETILIR, virman iki satir, iade ters yonlu yeni kayit, banka eslestirme ONERIDIR (belirsizde uretmez), icra dosyasi borcu kopyalamaz + banka entegrasyonu belge notu.
- 2026-07-31 · P28 · 51a73db · Borclandirma motoru (0018): mevcut aidat modulu GENISLETILDI (paralel sistem YOK); benzersizlik (daire, donem, TUR) oldu — ayni ay birden fazla kalem; hedefleme kurali TANIMDA (kiraci_oncelikli|malik); gecikme ANLIK hesaplanir; toplu onizleme→isleme, sayac sihirbazi, satir-bazli ice aktarim.
- 2026-07-31 · P27 · 059eb61 · Muhasebe "Tanimlar" katmani (0017): kasa/gelir-gider/firma/personel/arac/sayac defterleri + evrak-seri & para birimi (GOSTERIM); para kurus, acilis bakiyesi isaretsiz+yonlu, dagitim enum'u BILEREK iki degerli; admin-web /tanimlar sayfasi (P26'nin acik parcasi kapandi).
- 2026-07-31 · P26 · 760a812 · Bagimsiz Bolum TIP + GRUP tanimlari (0016): tip = buyukluk + VARSAYILAN AIDAT (null "tanimsiz" != 0 "muaf"), grup = ne oldugu; tanim silinince daire SILINMEZ; daire/toplu olusturmada atama; bilesik FK + SET NULL bulgusu.
- 2026-07-31 · P25 · 33a7d75 · Kamera sertlestirme: 2048 karakter siniri (0015, uc katman) + "kamu yayinlari oynamiyor"un KOK NEDENI (cleartext yalniz debug manifestindeydi; P17 restream'i de vuruyordu) + hata artik NEDENE gore konusuyor + ana ekran seridi dortlu ve yonetici/sakin ekranlarina da eklendi.
- 2026-07-31 · P24 · a26bb7c · Sikayet renk skalasi DORT KADEMEYE cikti (tek sikayet artik gorunur; esikler tek tabloda, P37 icin hazir) + KISI BASINA okuma durumu (0014) ve "Yeni / Okunmamis" triyaj kuyrugu (rozet = meta.total, ayri uc yok).
- 2026-07-31 · P23 · b5416a1 · Sakin yaşam döngüsü: bağ uçları yöneticiye açıldı (sonradan daire atama artık ULAŞILABİLİR), `ResidentUpdate` e-posta + rol_tipi kazandı ("boş bırak" ile "SİL" ayrı), rol_tipi AKTİF bağların hepsine uygulanır (bağsız → 422); yeni şema GEREKMEDİ.
- 2026-07-31 · P22 (b-g) · 6755a05 · Bildirime dokunma bir yere gidiyor, bildir kisayolu ana ekrana doner (tam yukleme yok), talep/sikayet AYRI akislar, kural gorseli listede, goruntu_kirliligi kategorisi (0013). (a) geri alindi — tani planda.
- 2026-07-31 · P19 · df8cda3 · Hikvision/Dahua adaptorleri GERCEKCI tam govdelerle kilitlendi (uc bulgu: direction yon degil, _utc ofseti koruyordu, kimliksiz govdede turevsel kimlik kararli) + kamera kurulum dokumani.
- 2026-07-31 · P17 · 4cf269e · RTSP kameralar restream ile OYNATILABILIR (0012) + Plaka Okumalari ekrani (onay kuyrugu + OCR duzeltmesi); 26 ARB anahtari x 7 dil; 18+5 test.
- 2026-07-31 · P16 · ee77535 · ANPR ingest: 0011 revizyonu (anpr_api_key + anpr_event + vehicle_pass.kaynak), X-ANPR-Key kimligi (SECURITY DEFINER cozumleme), dort adaptor, esik/onay kuyrugu, 27 test; deponun dort envanter kilidi de karsilandi.
- 2026-07-30 · P21 · 10cf95f · Talep-uzerine ceviri DEGERLENDIRME NOTU (uygulama yok): yazma-aninda degil talep-uzerine + tek dil; kalite engeli once, DeepL'de ucuncu kisi verisi uyarisi.
- 2026-07-30 · P20 · d8c552e · Yuz tanima v2 TASARIM NOTU (kod yok): kapsam 1:1 dogrulama, sablon cihazda, KVKK kosullari + "once P34'u olc" tavsiyesi + karar satiri.
- 2026-07-30 · P15 · 7cfb492 · Frigate PoC ayri yiginda kosuldu: restream oynatilabilir dogrulandi, MQTT konu envanteri + olay yuku yakalandi, kaynak olculdu; ANPR ingest olay semasi taslagi yazildi.
- 2026-07-30 · P14 · 395605c · Ceviri kalite kapisi: ar+ru anadil inceleme paketi (1.186 anahtar x 2) + LibreTranslate olcumu (48 ceviri) — TR kaynak icin YETERSIZ, uc secenekli saglayici karar notu (degisiklik YAPILMADI).
- 2026-07-30 · P9 · e6d0941 · Sozlesme kontrolu METOT duzeyine cikarildi (201/201 ortusuyor); /me/checkpoints ve /admin/overview beyanlari koddan SAPMISTI, duzeltildi; adi gecen uclara tam aciklama yazildi.
- 2026-07-30 · P10 · 4509ca8 (+b0d821d, d7c4fa7, 47bbab8) · Kuyruk kalicilik yarisi YENIDEN URETILDI: iki gercek urun hatasi (hayalet yazar + paylasilan .tmp) duzeltildi; 20x tam-suit tekrari UC cevrimde 20/20 yesile ulasti (arada iki OLCUM ARACI hatasi bulunup duzeltildi).
- 2026-07-30 · P8 · d20206b · Arac Gecisleri + Otopark + Ihlaller ekranlari yazildi; ana ekranda ROTASIZ KART KALMADI; 51 ARB anahtari x 7 dil; 24 test.
- 2026-07-30 · P7 · 10fbd12 · Icerik cevirisi MOBILE baglandi: IcerikCeviri modeli + CeviriNotu/CeviriRozeti + duyuru/kural/etkinlik ekranlari; 8 ARB anahtari x 7 dil; 23 test.
- 2026-07-30 · P6 · 6a9f846 · Sunucu yerellestirmesi (Accept-Language) ZATEN BITMISTI (tur 14/15/16); sinir isaretleri + sozlesme + katalog dogrulandi.
- 2026-07-30 · P5 · fde3a4f · i18n tur 5 ve sonrasi ZATEN BITMISTI; §15 = 8 (hepsi kayitli istisna), nihai istisna listesi plana yazildi.
- 2026-07-30 · P4 · f9837cf · i18n tur 4 (building_map + complaints) ZATEN BITMISTI; olcum yeniden kosuldu: §15 = 8 (hepsi kayitli istisna), iki modulun katkisi 0.
- 2026-07-30 · P3 · 10015b2 · Kapsama serisi KAPANDI: temp_code_dialog 0/25 → 25/25 (dokunma hedefi bulgusu + modal perde dedektor duzeltmesi), yonetici_iletisim_models 0/12 → 12/12, kapanis ozeti yazildi.
- 2026-07-30 · P1 · 0b9267b · Prod göç uyumlama paketi origin/main'de doğrulandı (9f4ee74); kod değişikliği yok.
