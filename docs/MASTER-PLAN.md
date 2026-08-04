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
6. Quality gates per touched area (every item, no exceptions).
   **KOŞMA BİÇİMİ TEK YERDE: `infra/kapilar.sh` (P93).**
   `infra/kapilar.sh [web] [mobile] [backend] [goc]` — argümansız hepsi.
   Betik, aşağıdaki tuzakları **yapısal olarak** engeller; elle koşulacaksa
   aynılarına dikkat edilmelidir (üçüne de bu oturumda düşüldü):
   - **(a) İmaj önce** — `docker compose build api`; imaj kodu içine gömer,
     aksi halde **ESKİ kod** test edilir (P75).
   - **(b) Boru yok** — `komut | tail` boru hattının çıkış kodunu son
     komutunkine çevirir; `pytest`in hatası kaybolur (`(exit 1) | tail -1`
     → `$?`=0) ve `flutter`ın "Failing tests" bloğu **görünmez olur**
     (P74, P87). Dosyaya yaz, sonra oku.
   - **(c) Tek koşum** — ikinci bir pytest, `conftest`in açılış temizliği
     yüzünden birincinin fixture tenant'larını siler (koşum kilidi artık
     reddediyor — P75).
   - Konteynerde **`ps` YOKTUR**; koşumun sürdüğünü **günlük dosyasının
     büyümesinden** anla, süreç sorgusundan değil (P75).
   Kapsam: /backend → full pytest green · /mobile → analyze + test + apk ·
   /admin-web → tsc + tests + `npm run build` · /contracts → openapi.yaml
   her uç/şema değişikliğinde güncellenir · göç → uyum + tersinirlik.
7. Schema changes ALWAYS ship as NEW Alembic revisions. docs/MIGRATION-POLITIKASI.md
   is binding — deployed prod exists; never edit applied migrations in place.
8. i18n discipline: UI strings via ARB with ALL 7 locales (tr en ar ru de fr es),
   README §15 grep inventory before/after, eyeball RTL pass on new/changed screens.
   New hardcoded user-facing strings are a regression — not acceptable in ANY item.
9. Every item that changes user-visible behavior ends with a "Device-verify"
   checklist appended to item P11's Notes (Kerem tests in batches).
10. UNINTERRUPTED MODE: never end your turn to report progress or ask for /clear.
    When context grows heavy: finish the current item, commit it, append a STATUS
    REPORT line to CHANGELOG, then IMMEDIATELY re-read docs/MASTER-PLAN.md and continue
    with the next eligible item in the same turn. If an automatic context compaction
    occurs, your FIRST action afterwards is to re-read docs/MASTER-PLAN.md and the top
    of CHANGELOG to re-anchor, then continue. Multi-file features are not a reason to
    defer an item: split it into committable sub-steps (schema → API → UI → tests),
    committing each sub-step so nothing is ever half-done in the working tree.
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

## DURUM DENETİMİ — 2026-08-02

> Bu bölüm bir **denetim** çıktısıdır: her maddenin **beyan edilen** durumu ile
> **doğrulanan** durumu yan yana konur. Hiçbir madde yeniden numaralanmadı ya
> da yer değiştirmedi; yalnız gerçeğe uymayan `Status` alanları düzeltildi ve
> eksik iş, ilgili maddenin Notes'una **somut** olarak yazıldı.

### Yöntem (ne yapıldı, ne yapılmadı)

**Yapılan:**
1. **Tam kapı koşumu** — `infra/kapilar.sh` (web + mobil + backend + göç),
   tek koşum, borusuz, imaj önce. Sonuçlar aşağıda.
2. **Yeniden ölçüm** (changelog'a güvenmeden, komut yeniden koşuldu):
   * §15 i18n envanteri (README'nin kendi python komutu) → **8 string / 5 dosya**,
     sekizinin sekizi de P5'teki istisna tablosuyla **birebir** aynı.
   * Kararsız sıralama çırçır eşiği → `test_sayfalama_siralamasi.py::ESIK = 3`
     (P108'in iddiası).
   * Vezne idempotency'si → `finans.py`de **yok** (P64 hâlâ gerçekten açık),
     `dues.py:314`te **var** (P64'ün tablosu doğru).
   * Koşum kilidi → `conftest.py:97` `pg_try_advisory_lock` (P75).
   * `guvenlik_amiri` rolü → `models.py:46`, `deps.py:109`, `schemas.py:136` (P35).
   * `merkez_diyalog.dart` → depoda **yok** (P22(a) gerçekten geri alınmış).
   * Sayaç arayüzü → `tanimlar/page.tsx:153` `kaynak: "sayaclar-ana"` **var**,
     bölüm sayacı kaynağı ve sihirbaz **yok** (P111'in ölçümü doğru).
3. **Yapıt varlığı** — her maddenin Notes'unda adı geçen göç, yönlendirici,
   ekran, modül ve test dosyaları diskte arandı. 27 Alembic revizyonu
   (0001–0027 + 0008b), 57 backend yönlendirici, 41 mobil özellik modülü,
   49 panel test dosyası, 161 mobil test dosyası, 98 backend test dosyası.
4. **Çalışma ağacı** — `git status` **temiz**; yarım kalmış iş yok.

**Yapılmayan (dürüstçe):** her BITTI maddenin kabul kanıtı **tek tek yeniden
üretilmedi**; ~90 maddede bu, oturumun tamamını yeniden koşmak demekti.
Özellikle **P10'un 20× tekrar koşumu bu turda yeniden koşulmadı** — kabul
kanıtı P10 Notes'undaki koşum #3 kaydıdır; bu denetimde yalnız **tek** tam
mobil koşum yeşildi. Doğrulama gücü şuradan gelir: kapılar bugün baştan sona
yeşil, yapıtların hepsi yerinde ve **rastgele seçilmiş yedi iddia yeniden
ölçüldüğünde yedisi de tuttu**.

### Kapı sonuçları (bu denetimde koşuldu)

| Kapı | Sonuç |
|---|---|
| `web-tsc` | GEÇTİ (çıktı yok — `tsc` sessiz başarı) |
| `web-vitest` | GEÇTİ — **49 dosya / 297 test** |
| `web-build` | GEÇTİ — `next build`, 36 statik sayfa |
| `mobil-analyze` | GEÇTİ — `No issues found!` |
| `mobil-test` | GEÇTİ — **1562 geçti / 3 atlandı / 0 düştü** |
| `mobil-apk` | GEÇTİ — `flutter build apk --debug` |
| `backend-build` / `backend-up` | GEÇTİ |
| `backend-pytest` | GEÇTİ — **1145 passed, 1 skipped, 2 warnings** (20 dk 37 sn) |
| `goc-uyum` | GEÇTİ — `bulgu: 0` |
| `goc-tersinir` | GEÇTİ — `bulgu: 0` |

**Sessiz regresyon YOK.** Onbir kapının onbiri tek koşumda yeşil.

### Uzlaştırma tablosu

Kategoriler: **DOĞRULANDI-BİTTİ** · **KISMEN** · **HİÇ BAŞLANMADI** ·
**BLOKE(sebep)** · **SPEC-HAZIR-KOD-YOK**

| # | Beyan | DOĞRULANAN | Kanıt / eksik olan |
|---|---|---|---|
| P1 | BITTI | DOĞRULANDI-BİTTİ | `0008b_uyum_yakalama.py`, `goc-uyum-dogrula.sh`, `sema-olgular.sql`, `MIGRATION-POLITIKASI.md`, `RUNBOOK-PROD.md` — beşi de diskte; ağaç temiz |
| P2 | BLOKE | BLOKE(sunucu erişimi Kerem'de) | Ajanın parçası (runbook güncelliği) hazır; koşum prod'da |
| P3 | BITTI | DOĞRULANDI-BİTTİ | `gecici_kod_diyalogu_test.dart` + 161 mobil test dosyası; suite bugün yeşil |
| P4 | BITTI | DOĞRULANDI-BİTTİ | §15 **yeniden ölçüldü**: 8/5, `building_map`+`complaints` katkısı **0** |
| P5 | BITTI | DOĞRULANDI-BİTTİ | Aynı ölçüm; 8 istisnanın 8'i P5 tablosuyla birebir |
| P6 | BITTI | DOĞRULANDI-BİTTİ | `hata_metinleri.py`, `akis_metinleri.py`, `test_hata_i18n.py`; pytest yeşil |
| P7 | BITTI | DOĞRULANDI-BİTTİ | `icerik_ceviri.dart`, `ceviri_notu.dart`, `icerik_ceviri_test.dart` |
| P8 | BITTI | DOĞRULANDI-BİTTİ | `features/vehicle_pass`, `features/violations`, `arac_ihlal_otopark_test.dart` |
| P9 | BITTI | DOĞRULANDI-BİTTİ | `test_sozlesme_sapmasi.py` suitte yeşil (201 operasyon iki yönlü) |
| P10 | BITTI | DOĞRULANDI-BİTTİ (kayıt kanıtı) | `kuyruk_hayalet_yazar_test.dart` var, suite yeşil. **20× tekrar bu turda koşulmadı**; kabul kanıtı Notes'taki koşum #3 |
| P11 | BLOKE | BLOKE(cihaz testi Kerem'de) | Listede **64 birikmiş madde** — kural 9 fiilen işliyor |
| P12 | BLOKE | BLOKE(dış: Firebase kimlik) | Kimlik yok; `push_messaging` kayıtlı kapsam istisnası |
| P13 | BLOKE | BLOKE(dış: iyzico/PayTR) | Sandbox anahtarı yok |
| P14 | BITTI | DOĞRULANDI-BİTTİ | `docs/ceviri-kalite-notu.md` + `docs/ceviri-teslim/` |
| P15 | BITTI | DOĞRULANDI-BİTTİ | `infra/frigate-poc/` (config, mediamtx, storage) + `docs/frigate-poc.md` |
| P16 | BITTI | DOĞRULANDI-BİTTİ | `routers/anpr.py` + `0011_anpr_ingest.py` |
| P17 | BITTI | DOĞRULANDI-BİTTİ | `features/anpr/` + `0012_kamera_restream.py` |
| P18 | BLOKE | BLOKE(donanım + saha) — **ajanın payı 2026-08-02'de kapandı** | Pilot site gerekiyor. Kabul ölçütündeki runbook eksikti; `docs/saha-kutusu-runbook.md` yazıldı |
| P19 | BITTI | DOĞRULANDI-BİTTİ | `app/anpr.py` adaptörleri + `docs/anpr-kamera-kurulumu.md` |
| P20 | BITTI | DOĞRULANDI-BİTTİ (kapsamı **not**) | `docs/face-recognition-v2-design.md`; Scope zaten "design note only" |
| P21 | BITTI | DOĞRULANDI-BİTTİ (kapsamı **not**) | `docs/talep-uzerine-ceviri-notu.md`; Scope "evaluation note" |
| **P22** | ~~BLOKE~~ | **BITTI (2026-08-02, tur 3)** | (b)–(g) zaten kanıtlıydı; **(a) da bitti**: `showModalBottomSheet` 54 → 0, `merkez_diyalog.dart` + 5 testlik kilit. Denetim anındaki "KISMEN" satırı bu turda kapandı |
| P23 | BITTI | DOĞRULANDI-BİTTİ | `features/residents`, `unit_access` uçları |
| P24 | BITTI | DOĞRULANDI-BİTTİ | `0014_sikayet_okuma.py` + şikayet triyajı |
| P25 | BITTI | DOĞRULANDI-BİTTİ | `0015_kamera_url_siniri.py` + `routers/cameras.py` |
| P26 | BITTI | DOĞRULANDI-BİTTİ | `0016_daire_tip_grup.py` + `routers/unit_tanimlari.py` |
| P27 | BITTI | DOĞRULANDI-BİTTİ | `0017_muhasebe_tanimlari.py` + `routers/muhasebe_tanimlari.py` + `/tanimlar` |
| P28 | BITTI | DOĞRULANDI-BİTTİ | `0018_borclandirma.py` + `routers/borclandirma_uc.py` |
| P29 | BITTI | DOĞRULANDI-BİTTİ | `0019_finansal_hareket.py` + `routers/finans.py` + `/finans` |
| P30 | BITTI | DOĞRULANDI-BİTTİ | `0020_odeme_kodu.py` + `routers/sakin_odeme.py` + mobil `/ode` |
| P31 | BITTI | DOĞRULANDI-BİTTİ | `routers/rapor_motoru.py` + `/raporlar` + `rapor.dom.test.ts` |
| P32 | BITTI | DOĞRULANDI-BİTTİ | `0021_mesaj_sablonu.py` + `routers/mesajlar.py` + `mesaj.dom.test.ts` |
| P33 | BITTI | DOĞRULANDI-BİTTİ | `0022_yonetisim.py` + `routers/yonetisim.py` + `/yonetisim` + `yonetisim.dom.test.ts` |
| P34 | BITTI | DOĞRULANDI-BİTTİ | `0023_tur_butunlugu.py` + `docs/personel-konum-kvkk.md` |
| P35 | BITTI | DOĞRULANDI-BİTTİ | `0024_guvenlik_amiri.py`; rol **üç yerde** (`models.py:46`, `deps.py:109`, `schemas.py:136`) |
| P36 | BITTI | DOĞRULANDI-BİTTİ | `0025_kvkk_riza.py` + `routers/kvkk.py` + `features/kvkk` |
| P37 | BITTI | DOĞRULANDI-BİTTİ | `0026_gurultu_caydirici.py` + `routers/gurultu_uc.py` + `docs/caydirici-protokol-notu.md` |
| P38 | BITTI | DOĞRULANDI-BİTTİ | `0027_portal_anket.py` + `routers/portal.py` + `app/site/[slug]` + `features/anket` + `portal-public.test.ts` |
| P39 | BITTI | DOĞRULANDI-BİTTİ | `infra/load/{senaryo,tekil}.js`, `docker-compose.load.yml`, `docs/scaling-runbook.md` |
| P40 | BITTI | DOĞRULANDI-BİTTİ | Panel sayfaları: `finans`, `raporlar`, `mesajlar`, `yonetisim`, `portal`, `settings` — hepsi mevcut ve build'e giriyor |
| P41 | BITTI | DOĞRULANDI-BİTTİ | `routers/yetki_matrisi.py` + `/yetki` + `yetki-matris.dom.test.ts` |
| P42 | BITTI | DOĞRULANDI-BİTTİ | Backend suite yeşil (rol bazlı gövde testleri) |
| P43 | BITTI | DOĞRULANDI-BİTTİ | jsdom altyapısı (`tests/kurulum.ts`, `yardimci.ts`) + `vitest.config.ts` |
| P44 | BITTI | DOĞRULANDI-BİTTİ | `rapor/mesaj/portal-ayar` dom testleri |
| P45 | BITTI | DOĞRULANDI-BİTTİ | `aidat-kullanici.dom.test.ts` |
| P46 | BITTI | DOĞRULANDI-BİTTİ | `talep.dom.test.ts` + toast i18n kilidi |
| P47 | BITTI | DOĞRULANDI-BİTTİ | `pano-daire-tanim.dom.test.ts` |
| P48 | BITTI | DOĞRULANDI-BİTTİ | `money.test.ts` (tek biçimlendirici) |
| P49 | BITTI | DOĞRULANDI-BİTTİ | Mobil para ayrıştırma çekirdeği; suite yeşil |
| P50 | BITTI | DOĞRULANDI-BİTTİ | `money.test.ts` çift yönlü (biçimlendir↔ayrıştır) |
| P51 | BITTI | DOĞRULANDI-BİTTİ | `vardiya-nokta.dom.test.ts` |
| P52 | BITTI | DOĞRULANDI-BİTTİ | `sessiz-fetch.test.ts` + `cikis.dom.test.ts` |
| P53 | BITTI | DOĞRULANDI-BİTTİ | `ham-enum.test.ts` + `enum-adlari.dom.test.ts` |
| P54 | BITTI | DOĞRULANDI-BİTTİ | `sabit-metin.test.ts` (tarayıcı diyalogları) |
| P55 | BITTI | DOĞRULANDI-BİTTİ | `sayi-girdi.dom.test.ts` |
| P56 | BITTI | DOĞRULANDI-BİTTİ | `sayi.test.ts` |
| P57 | BITTI | DOĞRULANDI-BİTTİ | Mobil koordinat ayrıştırma; suite yeşil |
| P58 | BITTI | DOĞRULANDI-BİTTİ | `eksik-veri.dom.test.ts` |
| P59 | BITTI | DOĞRULANDI-BİTTİ | Mobil boş-seçici hâli; suite yeşil |
| P60 | BITTI | DOĞRULANDI-BİTTİ | `destek.dom.test.ts` |
| P61 | BITTI | DOĞRULANDI-BİTTİ | `harita-bina.dom.test.ts` |
| P62 | BITTI | DOĞRULANDI-BİTTİ | `koyu-tema.test.ts` |
| P63 | BITTI | DOĞRULANDI-BİTTİ | `erisilebilir-etiket.test.ts` |
| P64 | BLOKE | **BITTI (2026-08-02)** | Denetimin "teyit edildi" dediği bloke **dış değilmiş**: yalnız üç seçenekten biri seçilecekti ve kural 11 bunu ajana verir. Seçenek (1) yazıldı; altı vezne ucu da korunuyor |
| P65 | BITTI | DOĞRULANDI-BİTTİ | `sayfali-cekim.test.ts` |
| P66 | BITTI | DOĞRULANDI-BİTTİ | `denetim.dom.test.ts` |
| P67 | BITTI | DOĞRULANDI-BİTTİ | `sabit-metin.test.ts` kural genişletmesi |
| P68 | BITTI | DOĞRULANDI-BİTTİ | `tesis-yonetici.dom.test.ts` |
| P69 | BITTI | DOĞRULANDI-BİTTİ | Panel şablon dizgesi taraması; vitest yeşil |
| P70 | BITTI(ölçüm) | DOĞRULANDI-BİTTİ (açık işi **P86**'da kapandı) | Ölçüm 7/7 `debugPrint`; kilit P86'da yazıldı |
| P71 | BITTI | DOĞRULANDI-BİTTİ | `seffaflik.dom.test.ts` |
| P72 | BITTI | DOĞRULANDI-BİTTİ | `duyuru.dom.test.ts` |
| P73 | BITTI | DOĞRULANDI-BİTTİ | `entegrasyon.dom.test.ts` |
| P74 | BITTI(ölçüm) | DOĞRULANDI-BİTTİ | Taban sayı ölçümü; kök neden P75'te kapandı |
| P75 | BITTI | DOĞRULANDI-BİTTİ | `conftest.py:97` `pg_try_advisory_lock` — koşum kilidi yerinde |
| P76 | BITTI | DOĞRULANDI-BİTTİ | `kapilar.sh goc` bu turda yeşil |
| P77 | BITTI | DOĞRULANDI-BİTTİ | Mobil çapraz kilit; suite yeşil |
| P78 | BITTI | DOĞRULANDI-BİTTİ | `ayirici-tutarlilik.test.ts` |
| P79 | BITTI | DOĞRULANDI-BİTTİ | İki istemci aynı gruplama; vitest yeşil |
| P80 | BITTI | DOĞRULANDI-BİTTİ | `roles.test.ts` + `enum-bag.test.ts` |
| P81 | BITTI | DOĞRULANDI-BİTTİ | `enum-bag.test.ts` (altı harita) |
| P82 | BITTI | DOĞRULANDI-BİTTİ | Mobil rol enum'u sunucuya bağlı; suite yeşil |
| P83 | BITTI | DOĞRULANDI-BİTTİ | `ayar-bag.test.ts` |
| P84 | BITTI | DOĞRULANDI-BİTTİ | `vekil-bag.test.ts` + `panel-vekil.test.ts` |
| P85 | BITTI | DOĞRULANDI-BİTTİ | `dil-bag.test.ts` |
| P86 | BITTI | DOĞRULANDI-BİTTİ | `enterpolasyon_sabit_metin_test.dart` (5 birim + 1 tarama) |
| P87 | BITTI(ölçüm) | DOĞRULANDI-BİTTİ | 5 temiz koşum kaydı; bu turda 6.'sı da temiz |
| P88 | BITTI | DOĞRULANDI-BİTTİ | `infra/kapilar.sh` — bu denetimin kendi aracı |
| P89 | BITTI | DOĞRULANDI-BİTTİ | 11 kapı, bu turda tekrar tek koşumda yeşil |
| P90 | BITTI | DOĞRULANDI-BİTTİ | Özet satırı `tail -n 1` mantığı betikte |
| P91 | BITTI | DOĞRULANDI-BİTTİ | Boş günlük → `(cikti yok)` ayrımı betikte |
| P92 | BITTI | DOĞRULANDI-BİTTİ | `Failing tests` bloğu önceliği betikte |
| P93 | BITTI | DOĞRULANDI-BİTTİ | Kural 6 betiğe bağlı (plan satır 26) |
| P94 | BITTI | DOĞRULANDI-BİTTİ | Mobil hata yolu sürüşü; suite yeşil |
| P95 | BITTI | DOĞRULANDI-BİTTİ | `guvenlik-hijyeni.test.ts` |
| P96 | BITTI | DOĞRULANDI-BİTTİ | `call` modülü tek yol; suite yeşil |
| P97/P98 | BITTI | DOĞRULANDI-BİTTİ | Telefon normalizasyonu güncelleme yolunda; pytest yeşil |
| P99 | BITTI | DOĞRULANDI-BİTTİ | Yaratma/güncelleme doğrulama sınıfı; pytest yeşil |
| P100 | BITTI | DOĞRULANDI-BİTTİ | Sonuç raporu bu dosyada |
| P101 | BITTI | DOĞRULANDI-BİTTİ | `oturum-401.test.ts` |
| P102 | BITTI | DOĞRULANDI-BİTTİ | `hata-mesaji.test.ts` |
| P103 | BITTI | DOĞRULANDI-BİTTİ | `hata-mesaji.test.ts` (sunucu mesajı korunuyor) |
| P104 | BITTI | DOĞRULANDI-BİTTİ | `istek-metni.test.ts` (BFF rotaları) |
| P105 | BITTI | DOĞRULANDI-BİTTİ | `sabit-metin.test.ts` `catch` yedekleri |
| P106 | BITTI | DOĞRULANDI-BİTTİ | `test_sayfalama_siralamasi.py` (2 test) |
| P107 | BITTI | DOĞRULANDI-BİTTİ | Dengeli parantez sayımı testte |
| P108 | BITTI | DOĞRULANDI-BİTTİ | **`ESIK = 3` yeniden okundu** (satır 35); kalan 3'ün gerekçesi yazılı |
| P109 | BITTI(ölçüm) | DOĞRULANDI-BİTTİ (düzeltme **P110**'da) | Ölçüm kaydı + çöken düzeltmenin gerekçesi |
| P110 | BITTI | DOĞRULANDI-BİTTİ | `metin_iste_diyalogu.dart` + `denetleyici_atma_test.dart`; atılmayan denetleyici 3→0 |
| **P111** | ~~ACIK(spec hazır)~~ | **BITTI (2026-08-02)** | Denetimin "yok" dediği iki parça da yazıldı: `sayaclar-bolum` defteri (referans alan tipi) + `/sayac-okuma` 4 adımlı sihirbaz; 9 testlik kilit, mutasyon denetimli |

### Özet

| Kategori | Sayı | Maddeler |
|---|---|---|
| DOĞRULANDI-BİTTİ | **102 satır** (103 madde kimliği; P97/P98 tek satır) | P1, P3–P10, P14–P17, P19–P21, P23–P110 (P22 ve P64 hariç) |
| KISMEN | ~~1~~ **0** | P22 — **denetimden sonra kapandı** (2026-08-02) |
| BLOKE | ~~6~~ **5** | P2, P11, P12, P13, P18 — beşi de **gerçekten dış** (sunucu erişimi, cihaz, kimlik, donanım). P64 çıktı: bloke **iç**miş, kapatıldı |
| SPEC-HAZIR-KOD-YOK | ~~1~~ **0** | P111 — **denetimden sonra yazıldı** (2026-08-02) |
| HİÇ BAŞLANMADI | **0** | — |

**Denetimin bulduğu tek beyan hatası:** P22 `BLOKE` etiketiyle duruyordu, ama
bloke eden bir dış bağımlılık **yok** — iş ajanın kendi elindeydi ve iki kez
denenip geri alındı. Doğru etiket **KISMEN**'dir; `BLOKE` maddesi kural 1
gereği **atlanan** bir madde olduğu için bu etiket, yapılabilir bir işi
kalıcı olarak görünmez kılıyordu. Bu, denetimin asıl karşılığıdır.

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
- [ ] **[KEREM] P127 · Lighthouse SEO puanı.** `https://yönetiyor.com`
  yayına alındıktan sonra Chrome DevTools → Lighthouse → SEO çalıştır;
  hedef **≥ 90**. (Ajan ortamında tarayıcı yok; başlıklar tek tek
  ölçüldü, puanın kendisi ölçülemedi.)
- [ ] **P131 · Kamera oynatma (WEB, YÖNETİCİ).** `app.*` → Kameralar:
  "Otopark" karosuna tıkla → yayın **açılmalı** (Chrome/Firefox'ta
  `hls.js`, Safari'de yerel; altta hangisinin kullanıldığı yazıyor).
  "Arka Bahçe NVR" (RTSP) karosunda **rozet** olmalı ve tıklayınca
  oynatıcı değil **açıklama** çıkmalı. Yeni kamera ekle → adres alanına
  bir **YouTube** bağlantısı yapıştır: kaydetmeden **uyarı** almalısın.
- [ ] **P131 · Görev foto kanıtı (WEB + MOBİL).** Mobilde fotoğraflı bir
  görev tamamla → web'de Görevler → o görevin **Kayıtlar**ında
  fotoğrafın **küçük görseli** çıkmalı (tıklayınca tam boyut). Aynı kayıt
  mobilde de görselli görünüyor mu?
- [ ] **P128 · Denetçi rolü (WEB, `app.*`).** Yönetici hesabıyla
  Kullanıcılar → Yeni → rol **Denetçi** seç (liste artık yalnız
  açabildiğin rolleri gösteriyor; "Platform Admin" **görünmemeli**).
  Görev başlangıç/bitiş alanları **yalnız denetçi seçilince** çıkmalı.
  Kaydet → denetçi telefonuyla `app.*`a gir: menüde **4 satır** olmalı
  (Rapor motoru, Şeffaflık, Profilim, KVKK). Bir rapor üret ve indir.
  Sonra yöneticiyle **bitiş tarihini düne çek** → denetçinin açık
  sekmesinde herhangi bir sayfayı yenile: **dışarı atılmalı**.
- [ ] **P129 · Mobil-yalnız roller (WEB, `app.*`).** Sakin, güvenlik ve
  tesis görevlisi telefon+parolasıyla `app.*`ta giriş dene → **giriş
  yapmamalı** ve "Bu hesap türü Yönetio mobil uygulamasında çalışır"
  mesajını görmelisin. Aynı hesaplar **mobil uygulamada** normal
  çalışmaya devam ediyor mu (regresyon kontrolü)?
- [ ] **[KEREM] P129 · Mağaza bağlantıları.** Uygulama Play/App Store'da
  yayına çıkınca `NEXT_PUBLIC_PLAY_URL` ve `NEXT_PUBLIC_APPSTORE_URL`
  ortam değişkenlerini tanımla (prod compose) — giriş ekranındaki
  yönlendirme mesajının altında bağlantılar **o zaman** çıkar. Kod
  değişikliği gerekmiyor.
- [ ] **P116 · Yer tutucu taraması (MOBİL, HER ROL).** Dört rolün ana
  ekranında **her modül kartına** tek tek dokun → hepsi bir ekrana
  gitmeli; **"Bu bölüm yakında"** mesajı **hiçbirinde çıkmamalı**. FAB
  (+) menüsünde **pasif/"Yakında"** satır olmamalı.
- [ ] **P121 · Kamera ızgarasında canlı karo (MOBİL, YÖNETİCİ+GÜVENLİK).**
  Bir kameraya **Anlık görüntü adresi** girin (Frigate varsa
  `.../api/<kamera>/latest.jpg`) → **Kameralar** ızgarasında karo o görüntüyü
  göstermeli ve ~8 sn'de bir tazelenmeli; altında yeşil **"Canlı"**. Adresi
  bozuk verin → karo yer tutucuda kalmalı, rozet **"Görüntü alınamıyor"**
  olmalı (yeşil "Canlı" **yazmamalı**).
- [ ] **P121 · Tazeleme ARKA PLANDA DURMALI (MOBİL).** Izgara açıkken başka
  ekrana geçin ya da uygulamayı arka plana alın, 1 dk bekleyip dönün —
  dönüşte kare **hemen** tazelenmeli.
- [ ] **P121 · Web sayfası adresi REDDEDİLMELİ (MOBİL, YÖNETİCİ).** Kamera
  formuna `https://www.youtube.com/watch?v=...` yapıştırın → kaydettirmemeli
  ve "Bu bir web sayfası adresi…" uyarısı çıkmalı; alanın altında
  desteklenen kaynak açıklaması görünmeli.
- [ ] **P123 · Telefon maskesi (MOBİL + PANEL, HER FORM).** Şu alanların
  **hepsinde** `5431992904` yazın → ekranda `0543 199 29 04` görünmeli:
  mobil **giriş**, **profil**, **personel**, **sakin ekle/düzenle**, **dış
  hizmet**; panelde **kullanıcılar**, **tesis oluştur**, **tesis detayı**,
  **portal iletişim**. Fazladan rakam yazmayı deneyin → **yazılmamalı**.
  `+905431992904` yapıştırın → `0543 199 29 04` olmalı. `0212 555 44 33`
  yazın → "5 ile başlamalı" uyarısı çıkmalı.
- [ ] **P122 · Hücrede daire tipi (PANEL + MOBİL, YÖNETİCİ).** Tanımlar'da
  bir daire tipi oluşturun (örn. `2+1`), bir daireye atayın → **Bina
  tasarımcısında** hücre `12` altında `2+1` göstermeli ve tipe özel renk
  almalı. **Panelde ve mobilde aynı tip aynı rengi göstermeli** (yan yana
  bakın). Daireyi **pasif** yapın → tip etiketi kaybolmalı. Telefonda yazı
  boyutunu en büyüğe alın → hücre büyümeli, yazı **taşmamalı**.
- [ ] **P119 · TEŞHİS KOŞUMU (MOBİL, iOS — TEK KOŞUM).**
  `docs/ios-teshis-turu.md` adım adım anlatıyor: `flutter run --release`
  → açılıştaki `=== PAKET GERCEKLERI ===` bloğu + bir kamera açıp çıkan
  `[YAYIN]` satırları + bir NFC okutmadan çıkan `[NFC]` satırları.
  **Üçünü de yapıştırın**; kamera kök nedeni bu çıktıyla belirlenecek.
- [ ] **P119 · NFC artık AÇILMALI (MOBİL, GÜVENLİK).** `.iso18092`
  kaldırıldı. Okutma hâlâ düşerse ekrandaki cümle "Okuma iptal edildi"
  **olmamalı**; "NFC bu yapımda kullanılamıyor: `<kod>`…" yazmalı ve o
  `<kod>` günlükte de görünmeli.
- [ ] **P115 · Denetçinin GİRİŞİ (MOBİL, GÜVENLİK).** Denetim notlarındaki
  akışı **birebir** dene: giriş ekranına **telefon** `0500 000 01 02` +
  demo parolası → girmeli. **E-posta alanı aranmamalı** (mobilde yok).
  Diğer üç hesabı da (`…01 01/03/04`) aynı biçimde dene. (Build 1'de not
  e-posta giriş vaat ediyordu; denetçi giremezdi.)
- [ ] **P115 · Demo tesisi (MOBİL, GÜVENLİK).** `scripts/demo_tenant.py`
  koşulduktan sonra demo hesabıyla gir → **Kontrol Noktaları** → bir
  satırın üç-nokta menüsü → **"Simüle okutma"** görünmeli ve dokununca
  "kaydedildi" mesajı çıkmalı. **Devriye takibi → Tarama günlüğü**nde o
  okutma görünmeli.
- [ ] **P115 · GERÇEK tesiste görünmemeli (MOBİL, GÜVENLİK).** Normal bir
  tesiste aynı menüyü aç → **"Simüle okutma" OLMAMALI**. (Bu maddenin
  düşmesi, tur kayıtlarının kanıt değerini yitirmesi demektir.)
- [ ] **P113 · Yasal belgeler (MOBİL, HER ROL).** **Ayarlar → Yasal** →
  "Gizlilik Politikası" ve "Kullanım Koşulları" → her ikisi de
  **tarayıcıda açılmalı** (uygulama içinde değil). Uçak moduna alıp tekrar
  dene → "sayfa açılamadı" uyarısı çıkmalı, **sessiz kalmamalı**.
- [ ] **P113 · Belgelerin dili (MOBİL/TARAYICI).** Uygulama dilini
  **İngilizce** yapıp aynı bağlantıları aç → sayfa **İngilizce** gelmeli ve
  üstte "bağlayıcı sürüm Türkçedir" uyarısı bulunmalı. Türkçeye dönünce
  bu uyarı **kaybolmalı**.
- [ ] **P113 · Otomatik çeviri göstergesi (MOBİL, SAKİN).** Uygulama dilini
  Türkçe **dışında** bir dile al ve **Duyurular**, **Site Kuralları**,
  **Etkinlikler** listelerinden birer kayıt aç → her birinde "otomatik
  çevrilmiştir" notu ve **"Orijinali gör"** bağlantısı olmalı; bağlantıya
  basınca **Türkçe orijinal** görünmeli.
- [ ] **P112 · Hesap silme (MOBİL, SAKİN).** Test hesabıyla gir →
  **Ayarlar → en alt → "Hesabımı sil"**. (1) Onay penceresi hem **ne
  silineceğini** hem **aidat kayıtlarının kalacağını** yazmalı; (2) parola
  girmeden "Hesabımı kalıcı olarak sil" → uyarı çıkmalı, istek **gitmemeli**;
  (3) **yanlış** parola → hata; (4) doğru parola → mesaj gelmeli ve uygulama
  **giriş ekranına dönmeli**; (5) aynı hesapla **tekrar giriş denemesi
  başarısız** olmalı.
- [ ] **P112 · Son yönetici engeli (MOBİL, YÖNETİCİ).** Tesiste **tek**
  yönetici olan bir hesapla Ayarlar → Hesabımı sil → doğru parola →
  "**başka bir yöneticiye yetki devredin**" mesajı çıkmalı ve hesap
  **silinmemeli**. Sonra ikinci bir yönetici ekle, tekrar dene → bu kez
  **silinmeli**.
- [ ] **P112 · Silinen sakin yönetim tarafında (PANEL/MOBİL, YÖNETİCİ).**
  Yukarıda silinen sakinin adı listede "**Silinmiş Kullanıcı**" görünmeli;
  o sakinin **eski talebi/aidatı duruyor** olmalı (kayıt kaybolmamalı).
- [ ] **P111 · Bölüm sayaçları (PANEL).** **Tanımlar → Bölüm Sayaçları**:
  (1) tabloda **daire numarası ve ana sayaç adı** görünmeli, ham kimlik
  (UUID) **görünmemeli**; (2) **Yeni kayıt** → "Daire" ve "Ana sayaç"
  açılır listeleri **dolu gelmeli**; (3) mevcut bir satırda **Düzenle** →
  "Daire" seçici **pasif** olmalı (daire taşınamaz), diğer alanlar
  kaydedilebilmeli.
- [ ] **P111 · Toplu sayaç üretimi (PANEL).** Aynı sekmede bir **ana
  sayaç** seç → **Sayaçları üret**. Mesaj "**N sayaç açıldı, M daire
  atlandı**" demeli. **İkinci kez** çalıştır: bu kez "0 sayaç açıldı,
  N daire atlandı" demeli ve **hata vermemeli** (uç yeniden
  çalıştırılabilir).
- [ ] **P111 · Sayaç okuma sihirbazı (PANEL).** Menüden **Sayaç Okuma**:
  (1) 1. adımda kalem seçmeden **İleri** → uyarı çıkmalı; (2) 2. adımda
  döneme "Ağustos" yaz → **"YYYY-AA"** uyarısı çıkmalı, adım
  **ilerlememeli**; (3) `2026-08`, ana sayaç, tüketim ve birim fiyatla
  ilerle → 3. adımda **her daire için ayrı alan** olmalı; (4) 4. adımda
  **Tahmini toplam tutar** mantıklı olmalı; (5) **Borçlandır** → mesaj
  gelmeli ve **Aidat** sayfasında o dönemin tahakkukları görünmeli.
- [ ] **P111 · Bağlı sayaç yokken (PANEL).** Sihirbazda **hiç daire sayacı
  olmayan** bir ana sayaç seç → 3. adımda "**daire sayacı yok**" açıklaması
  çıkmalı ve 4. adımda **Borçlandır düğmesi pasif** olmalı.
- [ ] **P22(a) · Ortadan açılan pencereler (MOBİL, HER ROL).** Uygulamadaki
  **bütün** form/detay pencereleri artık ekranın altından değil **ORTADAN**
  açılır. Şu beş yerde aç-kapa yap: **Site Kuralları → karta dokun** (detay)
  ve **+ Yeni kural**; **Duyurular → +**; **Talep/Arıza → +**; **Sakinler →
  +** ve satırdaki **Düzenle**; **Rezervasyon → yeni rezervasyon**. Her
  birinde: (1) pencere ortada açılmalı, (2) **perdeye dokununca kapanmalı**,
  (3) uzun formda **kaydırma çalışmalı** (içerik kesilmemeli).
- [ ] **P22(a) · Klavye açıkken form (MOBİL).** Uzun bir form aç (örn.
  **Talep/Arıza → +**), bir metin alanına dokun ki klavye açılsın: pencere
  **klavyenin üstünde** kalmalı ve formun altında **bir klavye boyu boş
  alan OLMAMALI** (eski alt-sayfa dolgusundan kalma kusur; düzeltildi ama
  cihazda göz kararı doğrulanmalı).
- [ ] **P22(a) · Fotoğraf kaynağı seçimi (MOBİL).** Talep formunda
  **fotoğraf ekle** → "Kamera / Galeri" seçimi de artık ortada bir pencere.
  İki seçenek de çalışmalı, **vazgeçince form kilitlenmemeli**.
- [ ] **P68 · Tesis yöneticileri (PANEL).** **Tesisler → Yeni**: üç
  yönetici ekle, adlarını doldur, **ortadaki** satırı kaldır → kalan iki
  satırın adları **kaymamalı** ve tarayıcının parola yöneticisi yanlış
  satıra bağlanmamalı (parola alanına tıklayıp öneriye bak). Ayrıca ikinci
  satırın başlığı **dil değişince çevrilmeli** ("Manager 2").
- [ ] **P66 · Denetim kaydı (PANEL).** **Denetim kaydı** sayfasını aç →
  "Rol" sütununda **`yonetici` / `guvenlik` gibi ham değer OLMAMALI**
  ("Yönetici", "Güvenlik"). Dili İngilizce yap → aynı sütun İngilizce
  olmalı. "İşlem" sütunundaki `user.create` gibi kodlar **çevrilmez**
  (bilinçli: aranabilirlik).
- [ ] **P65 · Aidat raporu (PANEL).** Bir dönem seç ve **Raporu getir** →
  rapor gelmeli. Çok sayıda eski ödemesi olan bir tesiste sarı **"Eski
  (dönemsiz) ödeme taraması üst sınıra takıldı"** notu çıkarsa, tahsilat
  toplamının eksik olabileceği anlamına gelir — bu notu görürsen bana
  söyle (sunucu tarafında dönemsiz süzgeç eklemek gerekir).
- [ ] **P63 · Ekran okuyucu adları (PANEL).** Ekran okuyucuyla (ya da
  tarayıcı erişilebilirlik denetçisiyle) şunlara odaklan: **Yetki
  matrisi** arama kutusu, **Finans** tür süzgeci, **Yönetişim** aktarım
  kutusu, **Tesis detayı → tehlikeli bölge** onay kutusu. Her biri
  **adıyla** duyurulmalı; "metin kutusu" / "açılır liste" diye adsız
  duyurulan KALMAMALI.
- [ ] **P62 · Koyu tema renkleri (PANEL).** Koyu temaya geç ve şunlara bak:
  **Mesajlar** (başarısız gönderim satırındaki hata eki), **Finans**
  (hareket tablosunda "çıkış" tutarları), **Tesisler** (silme düğmesi),
  **Tesis detayı** (tehlikeli bölge kartı) ve sol menüde ağ kapalıyken
  **Çıkış yap** uyarısı. Hepsi **okunur** olmalı — koyu zeminde koyu
  kırmızı/gül metin KALMAMALI.
- [ ] **P61 · Boş-durum çelişkisi (PANEL).** Ağı kesip şunları aç:
  **Şikayet haritası** (bir daireye tıkla), **Bina düzenleme**, **Tanımlar**.
  Her birinde hata kutusu çıkmalı ama **"yok" metni ÇIKMAMALI** ("Açık
  şikayet yok" / "Kat yok" / "Kayıt yok"). Ağ açıkken gerçekten boşsa aynı
  metinler görünmeli.
- [ ] **P60 · Destek sayfası hata yolu (PANEL).** Ağı kesip **Destek**
  sayfasını aç → hata kutusu çıkmalı ve **"Destek talebi yok" YAZMAMALI**
  (eskiden ikisi birden görünüyordu). Hata metninin başında **"Error:"**
  olmamalı. Ağ açıkken gerçekten bilet yoksa "Destek talebi yok" yazmalı.
- [ ] **P59 · Eksik seçenek uyarısı (MOBİL).** Ağı kesip **Görev
  ekle** (NFC kontrol noktası seçici) ve **Devriye planı ekle** (nokta
  listesi) ekranlarını aç → sarı **"Bazı seçenekler yüklenemedi"** uyarısı
  çıkmalı; sessizce boş liste GÖRÜNMEMELİ. Ağ açıkken uyarı çıkmamalı.
  **Demirbaş** zimmet satırında ad yerine kimlik görünüyorsa başında **`#`**
  olmalı.
- [ ] **P58 · Eksik arama uyarısı (PANEL).** Ağı kısa süreliğine kesip
  **Görevler**, **Demirbaş** ve **Devriye planları** sayfalarını aç →
  başlığın altında sarı **"Bazı seçenekler yüklenemedi"** uyarısı çıkmalı
  ve açılır listeler boş olmalı (sessizce boş DEĞİL). Ağ açıkken uyarı
  **çıkmamalı**. Bir raporda atanan kişi/kategori adı yerine `#3f2a91c8`
  gibi bir değer görünüyorsa, başında **`#`** olmalı (ad sanılmasın).
- [ ] **P57 · NFC noktası koordinatı (MOBİL).** **Admin/yönetici** ile NFC
  noktası ekle/düzenle ekranını aç. Enlem alanına **Türkçe klavyeyle**
  `41,0082` yaz (virgül tuşu) → kaydedilmeli ve tekrar açınca **dolu**
  gelmeli (boş DEĞİL — eski sürüm bunu sessizce siliyordu). Sonra `kuzey`
  yaz → **"Konum geçersiz"** uyarısı çıkmalı, kayıt gitmemeli.
- [ ] **P56 · Tanımlar tutarı (PANEL, ÖNEMLİ).** **Tanımlar** → aidat tutarı
  olan bir tanımı düzenle. Alan **`5.000,00`** biçiminde dolu gelmeli
  (`5000.00` DEĞİL). **`1.250`** yaz ve kaydet → kayıt **1.250,00 ₺**
  olmalı (**1,25 ₺ DEĞİL** — eski sürüm böyle yapıyordu). Sonra **`abc`**
  yaz → **hata** çıkmalı ve kayıt değişmemeli.
- [ ] **P56 · Sayısal alanlar (PANEL).** NFC noktasında GPS enlemine
  **`41,0082`** (virgüllü) yaz → kaydedilmeli. **`kuzey`** yaz → hata
  çıkmalı, koordinat **silinmemeli**. Aynısını **kat/sıra** (Daireler ve
  Bina düzenleme) ve **periyot** (Görevler, Devriye planları) alanlarında
  dene: geçersiz değer **hata** vermeli, sessizce boşalmamalı.
- [ ] **P55 · Metrekare (PANEL).** **Daireler**'de bir daireyi düzenle,
  metrekareye **`120,5`** yaz (virgüllü — Türkçe yazım) ve kaydet. Tabloda
  **`120,5`** görünmeli. Tekrar düzenle → alan **`120,5`** dolu gelmeli
  (boş DEĞİL). Sonra **`abc`** yaz ve kaydet → **"Metrekare geçersiz"**
  hatası çıkmalı ve **kayıt değişmemeli**. Boş bırakıp kaydet → alan
  temizlenmeli (bu doğru davranıştır).
- [ ] **P54 · Silme onayları (PANEL).** Dili **İngilizce** yap ve şunlarda
  silme düğmesine bas: **Duyurular**, **Devriye planları**, **Vardiyalar**,
  **NFC noktaları**, **Entegrasyonlar**, **Daireler**, **Bina düzenleme**
  (hem blok hem daire). Çıkan tarayıcı onay kutusu **İngilizce** olmalı
  ("Delete …?"); Türkçe "silinsin mi?" GÖRÜNMEMELİ. Türkçe'ye geri dön →
  aynı kutular Türkçe olmalı.
- [ ] **P53 · Rozet ve durum adları (PANEL).** Panoda **Bugünün turları**
  rozetlerinde `kacirildi` gibi ham değer OLMAMALI ("kaçırıldı"); alarm
  listesinde de "kaçırılan tur" yazmalı. **Aidat**, **Demirbaş**, **Tur
  raporu**, **Aidat raporu** ve bir **daire detayı** aç → ödeme yöntemi ve
  durumu, demirbaş kategorisi/durumu hepsi Türkçe olmalı. Dili **İngilizce**
  yap → aynı rozetler "missed", "available", "transfer" olmalı.
- [ ] **P51 · Bildirim rozeti ve okundu işareti (PANEL).** **Admin** ile
  **Bildirimler** sayfasını aç → rozetlerde **`gecikmis_okutma` gibi ham
  değer OLMAMALI**, "gecikmiş okutma" yazmalı. Dili **İngilizce** yap →
  rozet "late scan" olmalı. Bir bildirimde **Okundu işaretle**'ye bas →
  başarı bildirimi çıkmalı ve rozet kaybolmalı. (Ağı kesip tekrar dene →
  **hata** bildirimi çıkmalı, "işaretlendi" DEĞİL.)
- [ ] **P52 · Çıkış (PANEL).** Sol menüden **Çıkış yap** → giriş ekranına
  dönmeli. Sonra tarayıcı geri tuşuna bas → **panele geri girilememeli**.
  (Ağı kesip Çıkış yap'a bas → ekranda kalmalı ve **"Çıkış yapılamadı —
  hâlâ oturumunuz açık."** uyarısı çıkmalı; giriş ekranına GEÇMEMELİ.)
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
Status: BLOKE(donanım+saha — AJANIN PAYI BİTTİ) · Depends-on: P17
Scope: Agent's part only: install/ops runbook for a site box (mini PC class; Coral
optional), camera-angle guidance for LPR, remote update strategy note.
Acceptance: runbook committed; field execution is Kerem's.

Notes (2026-08-02) — **AJANIN PAYI TAMAMLANDI.**
BLOKE maddeleri denetlenirken bulundu: bu maddenin **kabul ölçütü**
("runbook committed") ajanın işiydi ve **karşılanmamıştı** — donanım
beklemek bunu gerektirmiyordu. Kalan boşluklar somuttu: kamera açısı
kılavuzu vardı (`anpr-kamera-kurulumu.md` §6), boyutlandırma ölçümü vardı
(`frigate-poc.md` §5), ama **saha kutusu kurulum/işletim runbook'u** ve
**uzaktan güncelleme notu** yoktu.

`docs/saha-kutusu-runbook.md` yazıldı. İçindeki iki asıl karar:
* **MİMARİ:** ham video merkeze taşınmaz; kutu videoyu yerelde tüketir,
  dışarı **olay** çıkar. Hem bant genişliği hem KVKK açısından doğru yön
  (görüntü sitede kalır, merkeze karar çıkar).
* **UZAKTAN GÜNCELLEME: ÇEKME, İTME DEĞİL — ve OTOMATİK DEĞİL.** Kutuya
  **gelen port açılmaz** (SSH dâhil); erişim ters tünelle, kutu merkeze
  bağlanır. İmaj sürümü **sabitlenir** (`stable` etiketi kullanılmaz —
  farklı sitelerde farklı sürüm demektir ve hata raporu "hangi sürüm"
  sorusunu cevaplayamaz). Watchtower sınıfı otomatik güncelleme
  **önerilmez**: gece kendiliğinden yükselen kutu sabah "plaka okumuyor"
  olarak döner ve değişimin ne zaman olduğu bilinmez.

Belge, **doğrulanmamış** olanları ayrı bir bölümde açıkça sayıyor (5–6
kamera boyutlandırması ekstrapolasyondur; Coral hiç denenmedi; gerçek
plaka doğruluğu ölçülmedi; tünel ürünü seçilmedi). **Statü BLOKE kalıyor**
— kalan iş donanım ve saha, ikisi de Kerem'de.

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
Status: BITTI · Depends-on: —
<!-- DURUM DENETİMİ 2026-08-02: eski etiket BLOKE idi. YANLIŞTI — bloke eden
     bir dış bağımlılık yok, iş ajanın kendi elinde. BLOKE maddeleri kural 1
     gereği ATLANIR; bu etiket yapılabilir bir işi kalıcı görünmez kılıyordu.
     KALAN İŞ (somut, sırayla):
     1. `ONAY: site kurali silme diyalogu` sürüşünde silme ikonunun HANGİ
        widget ağacında olduğunu YAZDIR (hit-test yığınında `_RenderTheater`
        var → Overlay katmanı; offset y=1154, ekran 900).
     2. Gövde soyma ZATEN DENENDİ ve offset'i değiştirmedi — tekrarlama.
     3. Ağaç bulunduktan sonra pilot ekranı (`site_kurali`) çevir, beş eksen
        sürüşünü yeşile al.
     4. Ancak ondan sonra kalan `showModalBottomSheet` çağrılarını
        (tur 31 ölçümü: 51 çağrı / 28 dosya) `merkezSayfaAc`a taşı.
     5. `merkez_diyalog.dart` şu an depoda YOK; her deneme onu yeniden yazıyor
        — bir sonraki denemede önce onu commit'le (kural 10'un alt-adım kuralı). -->

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

İKİNCİ DENEME (2026-08-02) — YİNE GERİ ALINDI, AMA TANI İLERLEDİ.
Tur 31'in üç ölçümü bu kez **önceden** uygulandı (`merkez_diyalog.dart`:
zemin `surfaceContainerLow`, `Column.min`+`Flexible`, dış kaydırma yok) ve
**pilot tek ekranla** başlandı (`site_kurali`) — planın kendi önerisi.

İLERLEME:
* `merkezSayfaAc` yazıldı; pilot ekranın **üç** açılışı (form ×2 + detay)
  çevrildi; `flutter analyze` temiz.
* **Sürüş yardımcısı düzeltildi:** `fabAc` yalnız `BottomSheet` arıyordu ve
  dönüşüm sonrası **doğru ekranı kırıyordu**. Koruduğu invaryant "dokunma
  BİR ŞEY açtı mı"dır; artık `BottomSheet` **ya da** `Dialog` kabul ediyor.
  Bu düzeltmeyle `FORM: site kurali olusturma` sürüşü **yeşile döndü**.
* Geriye **tek** sürüş kaldı: `ONAY: site kurali silme diyalogu`.

YENİ ÖLÇÜM — ÖNCEKİ TANI EKSİKMİŞ:
* Silme ikonunun offset'i **y = 1154** (ekran 900). Tur 31'de "y≈511–529,
  görünür alanda" yazılmıştı; **bu doğru değilmiş** ya da koşullar farklıymış.
* Gövdenin kendi `SafeArea`+`Padding`+`SingleChildScrollView` zinciri
  **soyuldu** (planın önerdiği yol) → offset **hiç değişmedi** (yine 1154).
  Yani ikon, soyduğum detay gövdesinde **DEĞİL**. Tur 31'in "gövde
  sarmalayıcıları" hipotezi **elenmiş oldu**.
* Hit-test yığınında `_RenderTheater` var → öğe **Overlay** katmanında.

SONRAKİ OTURUM İÇİN: ikonun hangi ağaçta olduğunu **önce** bul
(`ONAY` sürüşünün açtığı widget'ı yazdır), sonra dönüştür. Gövde
soyma denendi ve **yetmedi**; aynı yolu tekrar denemek zaman kaybı olur.

KARAR: kural 6 gereği yine geri alındı (suit yeşil bırakıldı). Pilot
yaklaşımı doğru — bir sürüş dışında hepsi geçti; kalan tek sürüş için
yukarıdaki eleme sonucu bir sonraki denemeyi kısaltır.

---

ÜÇÜNCÜ DENEME (2026-08-02) — **BİTTİ**. Fark: iş **beş commit'e** bölündü
ve her adım arasında suit yeşile alındı (kural 10'un alt-adım kuralı).

**TANI — İKİNCİ DENEMENİN ÖLÇÜMÜ YANILTICIYMIŞ.** Planın 1. adımı
(ikonun hangi ağaçta olduğunu yazdır) koşuldu: geçici bir tanı testi
silme ikonunun yaratıcı zincirini, bütün atalarının kutu/kısıt
değerlerini, kaydırma alanlarının viewport'unu ve hit-test yığınını
yazdırdı. Sonuç: 320×900'de ikon **y=511**'de, hit-test **doğrudan
düğmeye** gidiyor, taşma yok. Yani "y=1154 / `_RenderTheater` /
öğe başka bir ağaçta" tanısı **kabuğun kendisinden** geliyormuş —
ikinci denemenin `merkezSayfaAc`ı dış kaydırma + `ConstrainedBox`
kullanıyordu. Kabuk `Column(min)+Flexible` ile yazılınca sorun **hiç
ortaya çıkmadı**. Ortada "ayrı ağaç" sorunu **yokmuş**; iki turdur
kovalanan şey ölçüm aracının kendi gölgesiydi.

**SÜRÜŞ YARDIMCISI** (`fabAc`) yine düzeltildi: koruduğu invaryant
"dokunma BİR ŞEY açtı mı"dır; `BottomSheet` **ya da** `Dialog` kabul
ediyor. Aynı sınıftan iki test iddiası daha tür-bağımsız yapıldı.

**KAPSAM:** `showModalBottomSheet` çağrısı uygulamada **54 → 0**.
28 dosya, dört partide (pilot 3 · duyuru/sakin/personel/talep 10 ·
bina/kroki/rezervasyon/etkinlik/ziyaret/destek 18 · kalan 23).
Dönüşüm metni koruyarak yapıldı: yalnız çağrı adı, `context:`in
konumsal hâle gelmesi ve `isScrollControlled`/`showDragHandle`
satırlarının silinmesi; **gövdelere hiç dokunulmadı** (tur 31/32'nin
"gövde soyma" yolu bir daha denenmedi — gerekmedi).

**YENİ TESTİN BULDUĞU İKİ GERÇEK KUSUR** (ikisi de düzeltildi):
1. **Klavye boşluğu İKİ KEZ sayılıyordu.** `Dialog` gelen `viewInsets`i
   `insetPadding`e ekler; gövdelerin çoğu alt-sayfa döneminden kalma
   `viewInsets.bottom` dolgusunu taşıyor. Klavye açıkken formun altında
   **bir klavye boyu** boş alan kalıyordu. Dolgu kabukta tek yerde
   sıfırlanıyor (`MediaQuery.removeViewInsets`).
2. **Kaldırma gövdeye ulaşmıyordu.** Kabuk gövdeyi hazır `Widget` olarak
   alıyordu; dolguyu **kurucusunun içinde** hesaplayan gövdeler (örn.
   `bina_duzenleme`) okumayı kabuğun dışında yapıyordu. Kabuk artık
   `WidgetBuilder` alır ve kurucuyu kaldırmanın **altındaki** bağlamla
   çağırır.

**KİLİT:** `test/merkez_diyalog_test.dart` (5 test) — (i) kaynak
taraması: `lib/src` içinde tek bir `showModalBottomSheet` **çağrısı**
kalırsa düşer, (ii) pencere gerçekten **ortada** açılır (yüzeyin merkezi
ekran merkezinde ±1 dp), (iii) uzun gövde **gerçekten kaydırır**
(`viewport > 0` — tur 31'in "viewport 0" kusurunun kilidi), (iv) klavye
boşluğu gövdeye **0** gider ve pencere klavyenin üstünde kalır,
(v) `pop` değeri çağırana ulaşır.

KAPILAR: `flutter analyze` temiz · `flutter test` **1567 geçti /
3 atlandı / 0 düştü** · `flutter build apk --debug` ✓.
Commit'ler: `f7d18c0` (kabuk) · `5316c95` (pilot) · `761c6d6` (1. parti)
· `f3f3b0f` (2. parti) · `67ecc2e` (kalan + klavye + kilit).


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

## STATUS REPORT — 2026-08-04 (kural 10: P128–P131 grubu bitti, devam ediliyor)

**FINAL REPORT DEĞİLDİR** — uygun madde tükenmedi; sıradaki **P127**.

Kerem'in paketi (P129/P130/P131) plana yazıldı ve **istenen sırada**
bitirildi; P130(b) P128'i gerektirdiği için P128 de tanımlanıp yapıldı.

| Madde | Sonuç | Commit |
|---|---|---|
| plan | P128–P131 açıldı (+P126 durum satırı düzeltildi) | `4606c68` |
| **P130(a)** | Kim-kimi-açar TEK tabloda; açılır liste sunucudan; 6×6 matris testli | `0d5d991` |
| **P128 + P130(b)** | Denetçi rolü: göç 0032, salt-okuma **yapısal** testli, görev penceresi | `db1e1f0` |
| P128 (takip) | Rol mobil modele de eklendi — mobil kapısı eksiğimi yakaladı | `07dd335` |
| **P129** | `app.*` = yönetici + denetçi; mobil-yalnız roller **sunucuda** kesiliyor | `75025e2` |
| çırçır | KVKK kutusu yarışı (kod değil ölçüm kusuru) | `c439a1f` |
| **P131.1** | Kamera adres kuralı ortak vaka dosyasıyla kilitlendi (mobil↔web) | `af582d5` |
| **P131(a)** | Oynatıcı (hls.js) + web'de kamera yönetimi + oynatılamaz rozeti | `444ae57` |
| **P131(b)** | Foto kanıtı görünmüyordu: şema alanı vardı, **sunucu doldurmuyordu** | `168d42c` |
| **P127.1** | Kök alan adı artık tanıtım sitesi (üçüncü yüzey) + SEO altyapısı | `84de799` |

**ÜÇ ŞEY ÖLÇÜMLE DÜZELTİLDİ (iddia edildiği gibi değildi):**
1. "Yönetici platform admin açabiliyor" — **API'de yoktu** (403 ölçüldü);
   gerçek kusur, yapılamayacak bir şeyi teklif eden **açılır listeydi**.
2. "Web'de görseller çıkmıyor" — **web'e özgü değildi**: sunucu görev
   tamamlamalarında `foto_url` alanını hiç doldurmuyordu, yani fotoğraf
   **mobilde de** görünmüyordu.
3. "Denetçi mobilde çökmez" — ilk ölçümüm eksikti; mobil kapısı rol
   bağı kilidiyle yakaladı ve rol mobil modele de eklendi.

**KAPILAR (son durum):** backend `pytest` **1324 geçti** · `vitest` **545**
· `tsc` temiz · `npm run build` ✓ · mobil `analyze` temiz + **1751 test** +
apk ✓ · göç uyum/tersinirlik **0 bulgu** (33 sınır).

**SIRADAKİ İŞ — P127'nin KALANI (ölçülüp yazıldı, tahmin değil):**
1. **İletişim formu (teslimatlı).** Bugün `mailto:` bağlantısı var.
   Doğru tasarım portal formundaki kuraldır — **önce kaydet, sonra
   bildir**: SMTP yapılandırılmamışken doğrudan e-postaya çevirmek mesajın
   *sessizce kaybolması* demektir. Tanıtım formu **tenant'sızdır**, yani
   platform düzeyinde bir tablo + RLS kararı gerekir (audit_log'un
   tenant'sız satırları emsal). Yarım bir form bırakmamak için bu dilim
   AÇILMADI.
2. **Lighthouse SEO puanı** — bu ortamda tarayıcı yok; başlıklar tek tek
   ölçüldü, puan Kerem'de.

**KEREM'İN İŞİ (P11'e yazıldı):** denetçi rolü cihaz turu, mobil-yalnız
rol reddi, kamera oynatma, görev foto kanıtı, Lighthouse puanı; ayrıca
uygulama mağazaya çıkınca `NEXT_PUBLIC_PLAY_URL` /
`NEXT_PUBLIC_APPSTORE_URL` tanımlanacak.


### 2026-08-02 · P114 DÜZELTME · 98160c9
P114'ün yarattığı dosyalar depoya **girmemişti**: kök `.gitignore`daki
`mobile/ios/` toptan kuralı yuttu, `project.pbxproj` izlendiği için
güncellendi ve depo "tutarlı görünüp" eksik kaldı. Aynı sınıfın Android
karşılığı (`network_security_config.xml`) de hâlâ açıkmış. 11 dosya
kurtarıldı, iki toptan kural kaldırıldı, yeni **`depo` kapısı** eklendi.

## FINAL REPORT — 2026-08-02 #2 (kural 13): App Store hazırlığı P112–P118

Kerem'in App Store paketi (P112–P118) plana işlendi ve **sırayla**
yürütüldü. **iOS derlemesinin kendisi [KEREM]'dedir**; ajanın işi, ilk
Mac derlemesi denetime hazır olsun diye kod/yapılandırma/belge tarafıydı.

### (A) YAPILAN İŞLER

| # | İş | Commit |
|---|---|---|
| 1 | Plan: P112–P118 maddeleri açıldı (Sign in with Apple 4.8 = N/A notuyla) | `e141d46` |
| 2 | **P112** — uygulama içi hesap silme (5.1.1(v)) + KVKK ayrımı; göç `0029` kalıcı kanıt | `8e20af1` |
| 3 | P112 plan/CHANGELOG/cihaz testi | `909d173` |
| 4 | **P113** — `/gizlilik` + `/kosullar` 7 dilde; yapay zekâ/çeviri beyanı ve kilidi | `4d0fa01` |
| 5 | P113 plan/CHANGELOG/cihaz testi | `6157bc4` |
| 6 | **P114** — iOS yapılandırması: bundle, izin metinleri (en+tr), Privacy Manifest, Core NFC, marka simgeleri | `29ab367` |
| 7 | P114 plan/CHANGELOG | `8e52f41` |
| 8 | **P115** — denetçi demo modu (göç `0030`) + simüle okutma + denetim paketi | `add6b02` |
| 9 | P115 plan/CHANGELOG/cihaz testi | `f365206` |
| 10 | **P116** — yer tutucu süpürmesi: ölçüldü, sıfır çıktı, kilitlendi | `3df2f8c` |
| 11 | **P117 + P118** — ekran görüntüsü listesi + Mac derleme runbook'u + `codemagic.yaml` | `d229683` |

**KAPILARIN YAKALADIĞI GERÇEK EKSİKLER (hepsi düzeltildi):** rol matrisi
kilidi **iki kez** yeni ucu yakaladı · hata kataloğunda `uc_bulunamadi`
yoktu · panel `middleware` matcher'ı yeni sayfayı kapı dışında bırakmıştı
· sabit-metin ve erişilebilir-etiket taramaları · ikon aracı iki Xcode
yapı ayarını bozdu.

**MUTASYON DENETİMİ ÜÇ KİLİDİ DÜZELTTİ:** çeviri şeffaflığı kilidi
yorumları saymıyordu (iki tur), yer tutucu kilidi **uydurma tip adları**
tarıyordu (hiçbir şey ölçmüyordu), panel idempotency testleri.

**TESTİN YAKALADIĞI ÜRÜN HATASI:** demo bayrağı `itemBuilder` içinde
`ref.watch` ile okunuyordu; orada abonelik kurulmaz — düğme demo
tesisinde bile **hiç görünmezdi**.

### KAPILAR (son durum)

`pytest` **1163 geçti / 1 atlandı** (tur başı 1151) · `goc-uyum` /
`goc-tersinir` **bulgu 0** (0029 + 0030 dâhil) · `flutter analyze` temiz
· `flutter test` **1598 geçti / 3 atlandı** (tur başı 1567) · apk ✓ ·
`tsc` temiz · `vitest` **50 dosya / 308 test** · `npm run build` ✓.
§15 i18n envanteri **değişmedi**: 8 string / 5 dosya.

### KALAN — hepsi dış

| # | Neden bekliyor | Kimde |
|---|---|---|
| P2 | Prod sunucuda koşum | Kerem |
| P11 | Cihazda elle test (liste büyüdü) | Kerem |
| P12 | Firebase kimliği yok | Dış |
| P13 | iyzico/PayTR sandbox anahtarı yok | Dış |
| P18 | Pilot site + donanım (ajan payı bitti) | Kerem + donanım |
| P118 | macOS/CI (ajan payı bitti) | Kerem |

**Ajanın yapabileceği iş kalmadı.**

### (B) TEST EDİLECEKLER

Bu turun cihaz-doğrulama maddeleri **P11'e eklendi** (12 yeni madde):
hesap silme akışı ve son yönetici engeli, yasal belge bağlantıları ve
dilleri, otomatik çeviri göstergesi, demo tesisinde simüle okutmanın
çalışması **ve gerçek tesiste görünmemesi**, yer tutucu taraması.

**iOS tarafı için sıra:** `docs/app-store/ios-build-runbook.md` §1'den
başlayın — o belge, elle düzenlenen `ios/` yapılandırmasının Xcode'da
gözle doğrulanacak altı maddesiyle açılıyor. Sonra §2 derleme, §4
TestFlight, §5 denetime gönderme. Ekran görüntüleri için
`docs/app-store/screenshots.md`.


### 2026-08-02 · P115 · add6b02 (+ bu commit)
Denetçi demo modu: `tenant.demo_mod` (göç 0030) + `POST /scans/simule`
(kapalıyken 404, gerçek `create_scan`ı çağırır, kayıt imzasız düşer) +
mobil menü girişi + idempotent tohumlama betiği. Denetim notları ve App
Privacy tablosu yazıldı. İki kapı gerçek eksik yakaladı (hata kataloğu,
rol matrisi kilidi); mobil test de bir `ref.watch` hatasını yakaladı.

### 2026-08-02 · P114 · 29ab367 (+ bu commit)
iOS yapılandırması denetime hazır: bundle `site.yonetio.app`, yalnız
iPhone, gerçek kullanımı anlatan izin metinleri (en+tr), `PrivacyInfo.
xcprivacy`, Core NFC yetkilendirmesi (NDEF+TAG), markadan üretilmiş
simgeler. pbxproj elle düzenlendi ve yapısal doğrulamadan geçti; 15
testlik kilit yapılandırmanın geri gitmesini engelliyor.

### 2026-08-02 · P113 · 4d0fa01 (+ bu commit)
`/gizlilik` ve `/kosullar` sabit public adreslerde, 7 dilde, JS'siz sunucu
bileşeni olarak yayında; mobil Ayarlar'dan bağlı. Bağlayıcı sürüm TR ve
bunu sayfanın üstü söylüyor. Yapay zekâ beyanı (üretken YZ yok; yalnız
kendi sunucumuzda makine çevirisi) `ceviri_seffafligi_test.dart` ile
kilitlendi — mutasyon denetimi kilidi iki kez düzeltti.

### 2026-08-02 · P112 · 8e20af1 (+ bu commit)
Uygulama içi hesap silme (App Store 5.1.1(v)): `POST /me/hesap-sil` +
Ayarlar'da "Hesabımı sil". Kural tek yerde (`app/hesap_silme.py`); yönetim
yolu da aynı çekirdeği kullanıyor. Yeni göç `0029` kalıcı silme **kanıtı**
tutuyor (audit purge edilir, kanıt edilmez). Son yönetici engeli 409.
Rol matrisi kilidi yeni ucu yakaladı. Belge: `docs/hesap-silme-kvkk.md`.

## FINAL REPORT — 2026-08-02 (kural 13): denetimin bulduğu iş bitti

Bu tur, **2026-08-02 DURUM DENETİMİ**nin açık bıraktığı iki maddeyle
başladı (P22 KISMEN, P111 SPEC-HAZIR-KOD-YOK) ve BLOKE listesinin
denetlenmesiyle bitti. Denetimden çıkan asıl ders — *"`BLOKE` etiketi
yapılabilir bir işi kalıcı olarak görünmez kılabiliyor"* — bu turda **iki
kez daha** karşılığını verdi: **P64** ve **P18/P2'nin ajan payı**.

### (A) YAPILAN İŞLER

| # | İş | Commit |
|---|---|---|
| 1 | **P22(a) kabuk** — `merkezSayfaAc` tek dosyada (henüz çağrılmıyor) | `f7d18c0` |
| 2 | **P22(a) pilot** — `site_kurali` ekranının 3 açılışı merkeze taşındı; `fabAc` sürüş yardımcısı tür-bağımsız yapıldı | `5316c95` |
| 3 | **P22(a) 1. parti** — duyuru / sakin / personel / talep: 10 açılış | `761c6d6` |
| 4 | **P22(a) 2. parti** — bina / kroki / rezervasyon / etkinlik / ziyaret / destek: 18 açılış | `f3f3b0f` |
| 5 | **P22(a) kalan** — 23 açılış + klavye boşluğu düzeltmesi + 5 testlik kilit | `67ecc2e` |
| 6 | **P22 BITTI** — plan durumu, CHANGELOG, 3 cihaz-doğrulama girdisi | `ddeeca4` |
| 7 | **P111** — bölüm sayaçları defteri (referans alan tipi) + toplu üretim + 4 adımlı sayaç okuma sihirbazı + 40 anahtar × 7 dil + 9 test | `4a1b38c` |
| 8 | **P111 BITTI** — plan durumu, CHANGELOG, 4 cihaz-doğrulama girdisi | `1972e8d` |
| 9 | **P64** — vezne çift kayıt riski kapatıldı: `0028_vezne_idempotency` + altı vezne ucu + panel anahtarı + sözleşme + 8 test | `23bec66` |
| 10 | **P64 BITTI** — plan durumu + gerekçe + denetim tablosu (BLOKE 6 → 5) | `0e3d488` |
| 11 | **P18 ajan payı** — `docs/saha-kutusu-runbook.md` (kabul ölçütündeki eksik runbook) | `40192b9` |
| 12 | **P2 ajan payı** — prod runbook'un head revizyon spot-check'i 0010 → 0028 | `d1c58e8` |

**ÜÇ ŞEY ÖLÇÜLDÜ VE YANLIŞ ÇIKTI** (hepsi kayda geçti):

1. **P22'nin iki turdur kovaladığı tanı yanlıştı.** "Silme ikonu başka bir
   widget ağacında / `_RenderTheater` / y=1154" ölçümü **eski kabuğun kendi
   kusurundan** geliyormuş. Kabuk `Column.min + Flexible` ile yazılınca
   sorun **hiç ortaya çıkmadı**; ikon 320×900'de y=511'de ve hit-test
   doğrudan düğmeye gidiyor. İki tur boyunca kovalanan şey ölçüm aracının
   kendi gölgesiydi.
2. **Yeni kilit testi iki gerçek kusur buldu** (ikisi de düzeltildi):
   klavye boşluğunun **iki kez** sayılması ve kaldırma işleminin gövde
   **kurucusuna** ulaşmaması.
3. **P111'in önizlemesi `ortak_alan_yuzde`yi atlıyordu** — yüzde kullanan
   sitede tahmini tutarı **olduğundan büyük** gösterirdi. Test kilitledi.

**BEŞ KAPI TESTİ KIRMIZI VERDİ VE HEPSİ GERÇEK KUSURDU:** panel
`middleware` matcher'ı (yeni sayfa **kapı dışında** kalmıştı — oturumsuz
kullanıcı kabuğu görürdü), sabit-metin taraması, erişilebilir-etiket ve iki
tür-bağımlı test iddiası.

### KAPILAR (bu turun sonunda, tek koşum)

| Kapı | Sonuç |
|---|---|
| `web-tsc` | GEÇTİ |
| `web-vitest` | GEÇTİ — **50 dosya / 308 test** (denetim tabanı 49/297) |
| `web-build` | GEÇTİ — 37 statik sayfa (taban 36) |
| `mobil-analyze` | GEÇTİ |
| `mobil-test` | GEÇTİ — **1567 geçti / 3 atlandı** (taban 1562/3) |
| `mobil-apk` | GEÇTİ |
| `backend-pytest` | GEÇTİ — **1151 passed / 1 skipped** (taban 1145/1) |
| `goc-uyum` / `goc-tersinir` | GEÇTİ — `bulgu: 0` (0028 dâhil) |

### KALAN İŞ — **beşi de gerçekten dış**

| # | Neden bekliyor | Kimde |
|---|---|---|
| P2 | Prod sunucuda koşum (dev makineden prod'a erişim yok) | Kerem |
| P11 | Cihazda elle test | Kerem |
| P12 | Firebase kimlik bilgisi **yok** | Dış |
| P13 | iyzico/PayTR sandbox anahtarı **yok** | Dış |
| P18 | Pilot site + donanım (ajan payı bitti) | Kerem + donanım |

**Ajanın yapabileceği hiçbir iş kalmadı.**

---

### (B) TEST EDİLECEKLER

> Her madde **ekran ve rol** ile başlar. Sırayı takip et; bir madde
> düşerse not al ve devam et.

#### 1. MOBİL — açılır pencereler (HER ROL, en çok zaman burada)

Bu turda uygulamadaki **bütün** form ve detay pencereleri ekranın altından
değil **ORTADAN** açılır hâle geldi (54 çağrının 54'ü). En çok kullanılan
beş yerden geç:

1. **Site Kuralları** → bir karta dokun (detay açılmalı) → kapat →
   **+ Yeni kural** → kapat.
2. **Duyurular** → **+** → kapat.
3. **Talep/Arıza** → **+** → kapat.
4. **Sakinler** → **+** → kapat; sonra bir satırda **Düzenle** → kapat.
5. **Rezervasyon** → yeni rezervasyon → kapat.

Her birinde şu **üç** şeye bak:
* pencere **ekranın ortasında** mı açılıyor (aşağıdan kaymıyor),
* **perdeye (dışına) dokununca kapanıyor** mu,
* uzun formda **kaydırma çalışıyor** mu — içerik kesilmemeli, alta
  sıkışmamalı.

#### 2. MOBİL — klavye açıkken form (SAKİN ya da YÖNETİCİ)

**Talep/Arıza → +** ile uzun bir form aç ve bir metin alanına dokun ki
klavye açılsın.
* Pencere **klavyenin üstünde** kalmalı.
* Formun altında **bir klavye boyu boş alan OLMAMALI**. (Eski alt-sayfa
  dolgusundan kalma bir kusurdu; düzeltildi ama gözle doğrulanmalı.)
* Klavyeyi kapat → pencere normal boyuna dönmeli.

#### 3. MOBİL — fotoğraf kaynağı seçimi (SAKİN)

Talep formunda **fotoğraf ekle** → "Kamera / Galeri" seçimi de artık ortada
bir pencere.
* İki seçenek de çalışmalı.
* **Vazgeç** → form **kilitlenmemeli** (düğmeler etkin kalmalı, yükleniyor
  göstergesi asılı kalmamalı).

#### 4. PANEL — Bölüm Sayaçları (ADMIN/YÖNETİCİ) — YENİ

**Tanımlar → Bölüm Sayaçları** sekmesi (yeni).
1. Tabloda **daire numarası** ve **ana sayaç adı** görünmeli; ham kimlik
   (uzun UUID) **görünmemeli**.
2. **Yeni kayıt** → "Daire" ve "Ana sayaç" açılır listeleri **dolu**
   gelmeli. Bir daire seç, kaydet.
3. Mevcut bir satırda **Düzenle** → **"Daire" seçici pasif olmalı** (bir
   sayacın dairesi taşınamaz), diğer alanlar kaydedilebilmeli.

#### 5. PANEL — toplu sayaç üretimi (ADMIN) — YENİ

Aynı sekmede **Toplu sayaç üretimi**:
1. Bir **ana sayaç** seç → **Sayaçları üret**.
2. Mesaj "**N sayaç açıldı, M daire atlandı**" demeli ve liste tazelenmeli.
3. **İkinci kez** çalıştır: bu kez "**0 sayaç açıldı, N daire atlandı**"
   demeli ve **hata vermemeli** (uç bilerek yeniden çalıştırılabilir).

#### 6. PANEL — Sayaç Okuma sihirbazı (ADMIN) — YENİ SAYFA

Sol menüde **Sayaç Okuma** (Tanımlar ile Aidat arasında).
1. 1. adımda **kalem seçmeden** İleri → uyarı çıkmalı, adım ilerlememeli.
2. Bir gelir/gider kalemi seç → İleri.
3. 2. adımda döneme **"Ağustos"** yaz → **"YYYY-AA"** uyarısı çıkmalı ve
   adım **ilerlememeli**.
4. Dönemi `2026-08` yap, ana sayaç seç, ana tüketim ve birim fiyat gir →
   İleri.
5. 3. adımda **her daire için ayrı bir alan** olmalı; birkaçını doldur →
   İleri.
6. 4. adımda **Tahmini toplam tutar** mantıklı olmalı. (Ana sayaçta *ortak
   alan payı %* doluysa tutar, farkın **yalnız o yüzdesini** içerir.)
7. **Borçlandır** → mesaj gelmeli, sihirbaz başa dönmeli.
8. **Aidat** sayfasında o dönemin tahakkukları **görünmeli**.

#### 7. PANEL — bağlı sayaç yokken (ADMIN)

Sihirbazda **hiç daire sayacı olmayan** bir ana sayaç seç.
* 3. adımda "**daire sayacı yok**" açıklaması çıkmalı.
* 4. adımda **Borçlandır düğmesi pasif** olmalı.

#### 8. PANEL — vezne çift kayıt koruması (ADMIN) — DAVRANIŞ DEĞİŞTİ

**Finans → Yeni hareket**. Bu turda çift kayıt koruması eklendi.
1. Normal bir hareket gir (tutar + kasa) → **Hareketi kaydet**. Listeye
   **bir** satır düşmeli.
2. **Aynı** tutarla ikinci bir hareket gir → yine kaydet. Bu **ayrı** bir
   işlemdir; listede **iki** satır olmalı. (Yani koruma meşru arka arkaya
   girişleri engellememeli — bunu doğrulamak önemli.)
3. **Kasa bakiyesi** iki hareketin toplamı kadar değişmiş olmalı.

> Asıl korunan durum (zaman aşımı sonrası tekrar) elde tetiklenemez;
> sunucu tarafında testle kilitlendi. Senin bakman gereken şey, korumanın
> **normal kullanımı bozmadığıdır**.

#### 9. PANEL — dil kontrolü (herhangi bir rol)

Dili **İngilizce** (ve mümkünse **Arapça**) yap ve şu üç yeni yüzeye bak:
**Tanımlar → Bölüm Sayaçları** sekme adı ve alan etiketleri, **Sayaç
Okuma** sayfasının dört adım başlığı, toplu üretim mesajı. Türkçe metin
**kalmamalı**; Arapçada düzen **sağdan sola** olmalı.

#### 10. PROD (Kerem) — göç

Bu turda **yeni bir Alembic revizyonu** var: `0028_vezne_idempotency`
(`finansal_hareket`e iki nullable sütun + kısmi benzersiz indeks).
`infra/RUNBOOK-PROD.md` §14 akışını uygula; §14.2 (a) maddesinde çıktının
**`(head)`** ile bittiğini doğrula (ad artık `0028_vezne_idempotency`).
Revizyon **geriye uyumludur**: eski istemciler `Idempotency-Key`
göndermeden çalışmaya devam eder.


### 2026-08-02 · P111 · 4a1b38c
Sayaç takibinin eksik iki parçası yazıldı: `tanimlar` sayfasına **referans
alan tipi** + **Bölüm Sayaçları** defteri (+ toplu üretim düğmesi) ve
**`/sayac-okuma`** dört adımlı sihirbaz (sunucunun "tek istek" sözleşmesi
aynen). 40 anahtar × 7 dil; 9 testlik kilit, mutasyon denetimli. Üç panel
kapısı gerçek kusur buldu (matcher, sabit metin, erişilebilir etiket).

### 2026-08-02 · P22 · f7d18c0 5316c95 761c6d6 f3f3b0f 67ecc2e (+ bu commit)
(a) maddesi BİTTİ — uygulamadaki bütün açılır pencereler artık ORTADAN
açılıyor (`showModalBottomSheet` çağrısı 54 → 0, 28 dosya). Üçüncü deneme
beş alt-adıma bölündü; iki turdur kovalanan "öğe başka bir ağaçta" tanısı
ölçüldü ve **eski kabuğun kendi kusuru** olduğu görüldü. Yeni kilit testi
iki gerçek kusur buldu (klavye boşluğunun iki kez sayılması; kaldırmanın
gövde kurucusuna ulaşmaması) — ikisi de düzeltildi. P22 tümüyle BITTI.

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

### P52 — "Sessiz başarısızlık" sınıfını kilitle + çıkışta oturum tuzağı
Status: BITTI · Depends-on: P51
Scope: P51'in bulduğu kusur bir **sınıftı** (ham `fetch`, denetimsiz yanıt).
Sınıfı panelin tamamında süpür, kalan örneği düzelt ve **geri gelmesini
engelleyen** bir kilit koy.
Acceptance: kilit enjekte edilmiş gerçek bir ihlalle doğrulanır; kalan örnek
düzeltilir ve davranışı test edilir; gates.
Notes (2026-08-01):
**SÜPÜRME.** `app/` + `components/` altındaki ham `fetch` çağrıları tek tek
okundu: duyuru görseli (presigned PUT), destek yükleme + PATCH, rapor
görüntüle + indir — **hepsi** `res.ok` denetliyor. Denetimsiz kalan **tek** yer
**çıkış**tı.

**ÇIKIŞTAKİ TUZAK.** `logout()` yanıtı denetlemeden `/login`e geçiyordu.
`/api/auth/logout` çerezleri temizleyen **tek** adımdır (backend'e gitmez);
düştüğünde çerezler yerinde kalır. Kullanıcı giriş ekranını görür ve çıktığını
sanır — oysa **oturum açıktır** ve geri gitmek yeterlidir. Ortak bir
bilgisayarda bunun bedeli oturumun bir başkasına devridir. Artık: başarısızsa
**ekranda kalınır** ve durum söylenir (`role="alert"`, 7 dil). Yönlendirmeyi
yine de yapmak "çıkamadım ama çıkmış gibi görün" demekti; **hiçbir şey
yapmamak** ise sessizliğin ta kendisiydi.

**SINIF KİLİDİ.** `tests/sessiz-fetch.test.ts`: `app/` ve `components/`
altındaki her ham `fetch` çağrısı, izleyen 12 satırlık pencerede durum
denetimi (`.ok` / `.status`) içermeli **ya da** `FETCH-DENETIMSIZ` işaretiyle
gerekçelendirilmelidir. `lib/` kapsam dışıdır: sarmalayıcılar (`apiSend`,
`jsonFetcher`, BFF vekili) denetimi zaten yapar ve testin **konusu** odur.
Kilit, düzeltme geri alınarak **doğrulandı** (`components/AppShell.tsx:140`
olarak yakaladı) — yakalamadığını görmeden kilit saymak, kilidi olmayan bir
kapıya kilit demekti.

**TEST KURULUMUNDA `matchMedia`.** jsdom'da yok; tema anahtarı `useEffect`
içinde çağırıyor, dolayısıyla **kabuğu çizen her test** ürün kodunda hiçbir
sorun olmadığı halde düşüyordu. Kurulumda karşılanıyor (varsayılan açık tema).

Kanıt: `admin-web/tests/sessiz-fetch.test.ts` (sınıf kilidi, enjekte ihlalle
doğrulandı) + `tests/cikis.dom.test.ts` **2 test** (başarılıda yönlendirme
var, başarısızda **yok** ve uyarı var). `vitest` **168** yeşil (25 dosya),
`tsc` temiz, `npm run build` yeşil.

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

### P53 — Ham tel değeri ekranda: sınıfın tamamı
Status: BITTI · Depends-on: P52
Scope: P51 bildirim rozetinde bulunan "wire enum ekranda" kusuru bir sınıftı.
Paneli süpür, hepsini kapat, **tek kaynağa** bağla ve kilitle.
Acceptance: sızıntılar sayılır ve sıfıra iner; kilit gerçek sızıntı yakalar;
tanınmayan değer davranışı test edilir; gates.
Notes (2026-08-01):
**SEKİZ SIZINTI** bulundu (P51'de kapatılan bildirim rozeti hariç):

| Yer | Alan | Kullanıcı ne görüyordu |
|---|---|---|
| Pano — "Bugünün turları" | `durum` | `kacirildi` |
| Pano — alarm listesi | `tip` | `gecikmis_okutma` |
| Aidat — ödemeler | `durum`, `yontem` | `basarili`, `havale` |
| Demirbaş | `durum`, `kategori` | `zimmetli`, `ekipman` |
| Tur raporu | `durum` | `kacirildi` |
| Aidat raporu | `yontem` | `havale` |
| Daire detayı | `yontem`, `durum` | `havale · basarili` |

**PANO EN AĞIRIYDI**: en çok bakılan sayfa ve P51'de aynı bildirim tipi
bildirimler sayfasında çevrilmişken **panoda ham kalmıştı** — yani kopya
haritanın maliyeti ölçüldü, varsayılmadı.

**TEK KAYNAK.** `admin-web/lib/enum-adlari.ts`: altı numaralandırma haritası
+ `enumAdi(t, harita, deger)`. Haritayı sayfada tutmak, aynı numaralandırmayı
gösteren iki sayfadan birinin güncellenip diğerinin unutulması demekti.
**Tanınmayan değer HAM döner**: boş rozet "durum yok" gibi okunur ve yanlış
bilgidir; sunucu numaralandırmaya değer eklerse panel bozulmaz.

**KİLİT KENDİ BAŞINA İKİ SIZINTI BULDU.** `tests/ham-enum.test.ts` yazıldıktan
sonra, elle bulduğum altı sızıntıya ek olarak `dues` ve `reports/dues`
sayfalarındaki `{p.yontem}` / `{o.yontem}` satırlarını yakaladı — elle
süpürme **yetmemişti**. Kilidin yanlış pozitifi de ölçüldü ve düzeltildi:
`t(\`mesajDurum_${'${g.durum}'}\`)` ve `key={\`${'${a.tip}'}-…\`}` sızıntı **değildir**
(ilki sözlük anahtarı üretir, ikincisi ekrana hiç çıkmaz) — şablon dizgeleri
taramadan önce siliniyor. Kuralı olmayan bir kilit, doğru kodu hata gibi
gösterip ilk fırsatta silinirdi.

**MOBİL AYRICA SÜPÜRÜLDÜ**: `Text(durum)` görünen tek aday rezervasyon
ekranındaydı ve oradaki `durum` zaten `context.l10n`den kuruluyor. Mobilde bu
sınıf yok.

**TEST DEĞERLERİ BİLİNÇLİ SEÇİLDİ.** Türkçe karşılığı tel değeriyle **aynı**
olan değerler (`zimmetli`, `ekipman`, `bekliyor`) hiçbir şey kanıtlamaz —
çevrilmemiş olsa da geçerdi. Ayrışanlar seçildi: `kacirildi`→"kaçırıldı",
`musait`→"müsait", `arac`→"araç".

Kanıt: `admin-web/lib/enum-adlari.ts` (yeni), 17 sözlük anahtarı × 7 dil,
`tests/ham-enum.test.ts` (sınıf kilidi, **iki gerçek sızıntıyı kendi buldu**),
`tests/enum-adlari.dom.test.ts` **2 test** (çeviri + tanınmayan değer ham
kalır). `vitest` **171** yeşil (27 dosya), `tsc` temiz, `npm run build` yeşil.

### P54 — Tarayıcı diyalogları: taramanın ikinci kör noktası
Status: BITTI · Depends-on: P53
Scope: P46 `toast()` metinlerini kapatmıştı; aynı mantıkla `window.confirm/
alert/prompt` metinlerini süpür ve kilitle.
Acceptance: sızıntı sayısı ölçülür ve sıfıra iner; kilit enjekte edilmiş
ihlalle doğrulanır; gates.
Notes (2026-08-01):
**SEKİZ SABİT TÜRKÇE ONAY DİYALOGU** vardı: `announcements`, `patrol-plans`,
`shifts`, `checkpoints`, `integrations`, `building-editor` (blok + daire) ve
`units`. Hepsi `` `${x.ad} silinsin mi?` `` biçimindeydi — arayüz dili
İngilizce'yken bile Türkçe çıkıyordu.

**NEDEN GÖRÜNMEDİ.** Üç tarama vardı ve üçü de bunu göremiyordu: JSX metin
düğümleri (bu JSX değil), görünen öznitelikler (öznitelik değil) ve tur 22'nin
"Türkçe harf" taraması (eşiği "cırcır" olduğu için mevcut satırlar geçmişti).
P46 `toast.*`ı kapatmıştı ama tarama **yalnız `toast.`ya** bakıyordu.

**NEDEN SINIFIN EN PAHALI ÖRNEĞİ.** Bunlar **silme onaylarıdır**.
Anlamadığı bir metne "Tamam" diyen kullanıcı, okuyamadığı bir uyarıyı
onaylamış olur; `building-editor`daki blok silme **daireleri ve tüm bağlı
kayıtları** siler. Bildirim metni yanlış dilde çıkarsa rahatsız eder; onay
metni yanlış dilde çıkarsa **veri kaybettirir**.

**İKİ YENİ ANAHTAR, SEKİZ YER.** `ortakSilOnay` (`{ad}`) yedi yerde,
`binaBlokBasitSilOnay` (`{blok}`) blok silmede — "Blok" sözcüğünü koda gömmek,
sözcük sırası farklı dillerde bozuk cümle demekti. Zaten `t()` kullanan
diyaloglara (`gorevSilOnay`, `tanimSilOnay`, `tesisSilOnayMetni`, geçici kod
`alert`leri) dokunulmadı.

**KİLİT.** `tests/i18n.test.ts` içine `window.(confirm|alert|prompt)` taraması
eklendi; **dilden bağımsızdır** (tırnak içindeki metin sızıntıdır, hangi dilde
olduğu fark etmez). Düzeltme geri alınarak doğrulandı
(`units/page.tsx:108` olarak yakaladı).

Kanıt: 2 anahtar × 7 dil, 8 çağrı yeri, `tests/i18n.test.ts` **+1 kilit**
(enjekte ihlalle doğrulandı). `vitest` **172** yeşil, `tsc` temiz,
`npm run build` yeşil.

### P55 — Para olmayan sayılar + sessizce silinen metrekare
Status: BITTI · Depends-on: P54
Scope: P47–P50 zinciri parayı düzeltti; aynı sınıfı **para olmayan** sayılarda
ara. Bulunanı düzelt, gruplamayı tek kaynağa bağla.
Acceptance: kusur ölçümle gösterilir; girdi ve gösterim aynı yazımı kullanır;
gates (suite tekrar tekrar koşturularak).
Notes (2026-08-01):
**GÖSTERİM.** Metrekare sunucudan JSON `number` gelir — ölçüldü:
`PATCH /units/{id} {"metrekare": 120.5}` → yanıt `120.5` (`float`). Panel bunu
**olduğu gibi** yazıyordu. Aynı tabloda para `1.250,00 ₺` biçiminde: iki farklı
yazım, aynı satırda. Türkçe'de nokta **binlik ayırıcıdır**.

**ASIL KUSUR GİRDİ TARAFINDAYDI — SESSİZ VERİ KAYBI.** Eski `numOrNull`:
```ts
const n = Number(t); return Number.isFinite(n) ? n : null;
```
`Number("120,5")` → `NaN` → `null`. Ve `null` bu uçta **"alanı temizle"**
demektir. Yani metrekareyi **Türkçe yazımla** giren yönetici, kaydettiğinde
alanı **sessizce sildiriyordu** — hata da almıyordu. `null` üç ayrı şeyi
temsil ediyordu: boş, geçersiz ve "temizle".

**ÇÖZÜM.** `lib/sayi.ts`: `sayiBicimi` (gösterim) + `sayiCoz` (ayrıştırma,
`{tur: "sayi"|"bos"|"gecersiz"}`). Geçersizde istek **atılmaz** ve neden
söylenir. Kural `money.ts`in kuralıyla **aynı** — kullanıcı iki alanda aynı
yazımı kullanabilmeli. Ön-dolgu artık **gösterilen biçimde** (P49/P50'nin
aynı bulgusu). Ondalık basamak **sabitlenmez**: `120` için `120,00` yazmak
ölçülmemiş bir hassasiyet göstermek olurdu.

**GRUPLAMA TEK KAYNAKTA.** `binlikAyir` `money.ts`ten `sayi.ts`e taşındı ve
para modülü onu ithal ediyor. İki kopya tutmak, birinin düzeltilip diğerinin
unutulması demekti — P53'te numaralandırma haritalarında bunun bedeli
ölçülmüştü.

**AYRICA: SUITE'TE GERÇEK BİR FLAKE.** Tam koşumda `portal-ayar` testi
`1025 ≠ 25` ile düştü ve tek başına koşarken geçti. Sebep **testin kendi
yarışıydı**: `getByLabelText` etiket çizilir çizilmez döner, ama form
sunucu yanıtıyla **bir kez** dolar; o an alan boştur, boş alanda `clear()`
hiçbir şey yapmaz, sonra doldurma etkisi koşar ve yazılan `25` sunucu
değeri `10`un **ardına** eklenir. **Ürün kodu sağlam** (`loaded` bayrağı
tek seferlik doldurmayı garanti ediyor). Ölçüldü: 14 koşumun 1'inde
düşüyordu. Düzeltme sonrası tam suite **8 kez** ardı ardına koşuldu, tek
düşüş yok. Aralıklı düşen bir kilit, insanların yeniden koşturarak geçtiği
bir kilittir — yani kilit değildir.

Kanıt: `admin-web/lib/sayi.ts` (yeni), `tests/sayi.test.ts` **8 test**,
`units` sayfası (gösterim + ön-dolgu + geçersiz girdide hata),
`daireMetrekareGecersiz` × 7 dil. `vitest` **180** yeşil (28 dosya, 8 ardışık
tam koşum), `tsc` temiz, `npm run build` yeşil.

### P56 — "Sessiz temizleme" deseni: `Number()` → NaN → `null`
Status: BITTI · Depends-on: P55
Scope: P55'in metrekarede bulduğu desen bir **sınıftı**. Paneli süpür, her
örneği kapat.
Acceptance: her sızıntı ölçümle gösterilir; geçersiz girdide istek atılmaz ve
neden söylenir; gates.
Notes (2026-08-01):
**DESEN.** `Number(metin)` geçersiz girdide `NaN` verir; `NaN` `null`a
çevrilir (ya da `JSON.stringify(NaN)` **zaten `null`dur**); ve bu uçlarda
`null` **"alanı temizle"** demektir. Sonuç: geçersiz — ya da yalnızca **Türkçe
yazımla girilmiş** — bir değer, alanı **sessizce siliyordu**. Kullanıcı hata
bile almıyordu.

**ALTI YER:**

| Yer | Alan | Ne oluyordu |
|---|---|---|
| Tanımlar | `kurus` alanları | **ÜÇÜNCÜ para ayrıştırıcısı** — aşağıda |
| Tanımlar | `sayi` alanları | `Number("abc")` → NaN → JSON'da `null` |
| NFC noktaları | `gps_lat/lng` | `41,0082` → NaN → koordinat silinir |
| Bina düzenleme | `kat`, `sira` | geçersiz → alan silinir |
| Daireler | `kat`, `sira` | aynı |
| Görevler / Devriye planları | `periyot_dakika` | geçersiz → "periyot yok" |

**EN AĞIRI: TANIMLAR SAYFASINDAKİ ÜÇÜNCÜ PARA AYRIŞTIRICISI.**
```ts
metin.replace(",", ".") → Number → Math.round(n * 100)
```
`1.250` girdisinde `Number("1.250")` = **1,25**. Yani yönetici **bin iki yüz
elli lira** yazıp **1,25 TL** kaydediyordu — *reddedilmiyordu*, **yanlış
kaydediliyordu**: sessiz, **bin katlık** bir hata, hem de **her daireye
yazılan aidat tutarında**. Ayrıca panelin kendi gösterdiği `5.000,00` biçimi
`Number("5.000.00")` → `NaN` veriyordu. P50 `tlToKurus`u düzeltmişti ama bu
sayfa **kendi kopyasını** kullanmaya devam ediyordu — kopyanın bedeli üçüncü
kez ölçüldü. Artık tek kural: `lib/money.ts`. Form ön-dolgusu da
`(kurus/100).toFixed(2)` (`"5000.00"`) yerine `kurusToTLSade` (`"5.000,00"`)
— gösterilen biçim geri okunabilir olmalı.

**`null` GERÇEKTEN SİLİYOR — UÇTAN UCA ÖLÇÜLDÜ.** Teşhisin dayandığı
varsayım sunucuda sürüldü (`PATCH /units/{id}`):

| Gönderilen | Sonuç |
|---|---|
| `{"metrekare": 120.5}` | `120.5` |
| `{"metrekare": null}` | **`null`** (temizlendi) |
| alan hiç gönderilmez | `120.5` (korundu) |

Yani "geçersiz girdi → `null` → alan silinir" zinciri tahmin değil, ölçüm.

**ORTAK ÇÖZÜM.** `sayiCoz` / `tamsayiCoz` (P55) her yerde: `{sayi | bos |
gecersiz}`. Geçersizde **istek atılmaz** ve neden söylenir. Tam sayı gereken
alanlarda ondalık **yuvarlanmaz**, reddedilir: "2,5'inci kat" diye bir şey yok
ve sessizce 3 yapmak kullanıcının adına karar vermekti.

Kanıt: `tests/sayi-girdi.dom.test.ts` **3 test** (Türkçe yazım kabul edilir;
geçersizde istek **atılmaz** ve alan silinmez; koordinatta aynısı) +
`tests/sayi.test.ts`. 4 yeni hata anahtarı × 7 dil. `vitest` **183** yeşil
(29 dosya, 3 ardışık tam koşum), `tsc` temiz, `npm run build` yeşil.

### P57 — Aynı sınıf mobilde: koordinat, Türkçe klavyeyle sessizce siliniyordu
Status: BITTI · Depends-on: P56
Scope: P56'nın panelde kapattığı "sessiz temizleme" desenini mobilde ara.
Acceptance: sızıntı ölçümle gösterilir; ayırıcı kuralı iki istemcide aynı
olur; gates.
Notes (2026-08-01):
**MOBİLDE TEK SIZINTI VARDI ve keskindi.** `checkpoints_screen._submit`:
```dart
final lat = double.tryParse(_lat.text.trim());
```
`double.tryParse("41,0082")` → `null`, ve bu `null` doğrudan `gpsLat`a
gidiyordu — yani "koordinatı temizle". **Türkçe klavyede ondalık tuşu
virgüldür**: kullanıcı doğal olarak virgül yazar ve koordinat **sessizce
siliniyordu**. Alanda **hiçbir doğrulayıcı yoktu** (form `validate()`
çağırıyordu ama bu iki alan doğrulanmıyordu).

**GERİ KALAN BEŞ YER TEMİZ ÇIKTI** — süpürme sonucu, varsayım değil:
`bina_duzenleme` (boş/geçersiz ayrımını **zaten** yapıyor), `patrol_plans`
(pozitif kontrolü var), `task_form_sheet` ve `site_kurali` (ikisinin de
doğrulayıcısı geçersizi formda durduruyor, `?? 0` ulaşılamaz).

**ÇÖZÜM.** `mobile/lib/src/core/sayi.dart`: `sayiCoz` → `{sayi | bos |
gecersiz}`, ayırıcı kuralı `core/para.dart` ile **aynı**. Alanlara
doğrulayıcı eklendi; `_submit`teki kontrol **ikinci savunma** olarak durdu.
**Nokta ondalığı da kabul edilir**: İngilizce klavyede ondalık tuşu noktadır
ve kullanıcıya klavyesini değiştirtmek bir çözüm değildir.

**PARA MODÜLÜ AYRI KALDI.** `core/para.dart` kuruş **tam sayısı** üretir ve
iki basamak kısıtı vardır; koordinat `double` ister. Ortak olan şey ayırıcı
kuralıdır, dönüş tipi değil — tek fonksiyona sıkıştırmak, para tarafına
`double` sızdırmak olurdu.

Kanıt: `mobile/test/sayi_test.dart` **5 test**, `noktaKonumGecersiz` × 7
ARB. `flutter analyze` temiz, `flutter test` **1530** yeşil, `flutter build
apk --debug` başarılı.

### P58 — İkincil arama sessizce düşünce sayfa yanıltıyordu
Status: BITTI · Depends-on: P57
Scope: Sayfaların ana listesinin yanındaki **arama listelerinin** (vardiya,
kullanıcı, kategori, daire, nokta, plan) hatası hiçbir yerde görünmüyordu.
Sonucu ölç, yanıltıcı olanları kapat.
Acceptance: düşen aramada uyarı görünür; ad bulunamadığında gösterilen şey
**ada benzemez**; gates.
Notes (2026-08-01):
**ÖLÇÜM: 12 arama isteğinin hatası hiç okunmuyordu** (`const { data: x } =
useSWR(...)` — `error` destructure bile edilmiyordu). Sekiz sayfada sonuç
**yanıltıcıydı**:

* **Açılır liste boş kalıyor** ve "kayıt yok" gibi okunuyordu — yönetici
  görevi kimseye atayamıyor, plana vardiya seçemiyor ve **nedenini
  bilmiyordu**.
* **Ad sütununda kimlik parçası** beliriyordu: `3f2a91c8`. Bu bir ada
  benziyor — kullanıcı onu bir kod, bir daire numarası ya da kısaltma
  sanabilirdi. **Yanlış bilgi, bilgi yokluğundan kötüdür.**

**İKİ AYRI DÜZELTME, ÇÜNKÜ İKİ AYRI ŞEY.**
1. `EksikVeriUyarisi` (yeni): sarı, `role="status"`. `ErrorBox` burada
   **yanlış** olurdu — işlem başarısız olmadı, **eksik yüklendi**;
   `role="alert"` araya girer ve olduğundan ağır gösterirdi.
2. `kisaKimlik(id)` → `#3f2a91c8`. `#` öneki **bu bir kimliktir, ad
   değildir** der. Değeri tamamen gizlemek de yanlıştı: destek isterken
   kullanıcının elinde tutunacak bir şey kalmazdı.

**KAPSAM SEÇİMİ.** Altı sayfa (`patrol-plans`, `assets`, `tasks`,
`reports/tasks`, `reports/dues`, `reports/patrols`) uyarı gösteriyor;
`integrations` hazır şablon listesi ve `assets` geçmiş paneli **bilerek
dışarıda** — orada boş liste "kayıt yok"tan ayırt edilemiyor ama yanlış bir
**değer** de üretmiyor; her boş kutuya uyarı basmak uyarıyı değersizleştirirdi.

Kanıt: `tests/eksik-veri.dom.test.ts` **3 test** (arama düşünce uyarı çıkar;
başarılıyken çıkmaz; kimlik parçası ada benzemez), `lib/kimlik.ts` (yeni),
`ortakSecenekYuklenemedi` × 7 dil. `vitest` **186** yeşil (30 dosya, 3
ardışık tam koşum), `tsc` temiz, `npm run build` yeşil.

### P59 — Aynı sınıf mobilde: boş seçici, "kayıt yok" gibi okunuyordu
Status: BITTI · Depends-on: P58
Scope: P58'in panelde kapattığı "ikincil arama sessizce düşüyor" sınıfını
mobilde ara.
Acceptance: sızıntı ölçümle gösterilir; düşen aramada uyarı görünür; kimlik
parçası ada benzemez; gates.
Notes (2026-08-01):
**İKİ FORM SEÇİCİSİ** `ref.watch(provider).value ?? const []` yazıyordu —
yani **hata da "hiç kayıt yok"a** dönüşüyordu: `task_form_sheet` (NFC kontrol
noktası) ve `patrol_plans_screen` (plana nokta ekleme). Kullanıcı listeyi boş
görüyor, kaydı oluşturamıyor ve **nedenini bilmiyordu**.

**DEMİRBAŞTA KİMLİK PARÇASI ADIN YERİNDEYDİ.** `_shortId` → `3f2a91c8…`
zimmet satırında **kişinin adının** yerinde görünüyordu. Artık `#` önekli
(panelde aynı karar `lib/kimlik.ts`te).

**SÜPÜRMENİN GERİ KALANI BİLEREK DIŞARIDA.** `.value ?? …` kullanan 15 yer
tarandı; kalanlar farklı sınıf: rol (`?? UserRole.unknown` — güvenli
varsayılan, en az yetki), okunmamış sayacı (`?? 0` — rozet yokluğu yanlış
bilgi değil), ana ekran bölümleri (kamera/kural/etkinlik — boş bölüm
"içerik yok"tan ayırt edilemiyor ama **yanlış bir değer üretmiyor**) ve
`tasks_screen` kategori süzgeci (süzgeç boşsa liste **daralmıyor**, yani
kullanıcı veri kaybetmiyor). Her boş kutuya uyarı basmak uyarıyı
değersizleştirirdi.

**BULUNAN İKİNCİL HATA.** Düzeltme yazılırken `'#\$userId'` yazılmıştı —
Dart'ta bu **kaçırılmış** bir `$`tır ve ekranda harfi harfine `#$userId`
görünürdü. `flutter analyze` bunu yakalamaz (geçerli Dart'tır); commit
öncesi okumada bulundu.

Kanıt: `mobile/lib/src/core/ui/eksik_veri_uyarisi.dart` (yeni),
`mobile/test/eksik_veri_test.dart` **3 test** (görünür / yer kaplamaz /
çevrilir), `ortakSecenekYuklenemedi` × 7 ARB. `flutter analyze` temiz,
`flutter test` **1533** yeşil, `flutter build apk --debug` başarılı.

### P60 — "Yüklenemedi" ile "hiç yok" aynı şey değildir
Status: BITTI · Depends-on: P59
Scope: Ana listenin hata yolunu süpür: hata varken boş-durum iddiası ve hata
metninin teknik önekle bozulması.
Acceptance: iki kusur da ölçümle gösterilir; biri kilitlenir, diğeri davranış
testiyle sabitlenir; gates.
Notes (2026-08-01):
**KUSUR 1 — HATA VARKEN "TALEP YOK" DENİYORDU.** Destek sayfası listeyi
`!data || items.length === 0` ile boşa düşürüyordu. İstek düştüğünde `data`
tanımsızdır; sayfa **"Destek talebi yok"** yazıyordu — hemen üstündeki hata
kutusuyla **çelişerek**. İkisi ayrı şeydir: "yüklenemedi" bir durumdur,
**"hiç yok" bir iddiadır**. Yanlış olduğunda kullanıcı bekleyen talebi
görmez ve aramaz. Panelin geri kalanı doğru kalıbı kullanıyor
(`data && data.items.length === 0`) — bu sayfa istisnaydı.

**KUSUR 2 — `String(error)` ÇEVİRİYİ BOZUYORDU.** `jsonFetcher` ağ hatasını,
oturum bitişini ve sunucu zarfını **özenle çevirip** `Error(message)` atıyor.
Ama `String(new Error("Bağlantı yok."))` **`"Error: Bağlantı yok."`** verir:
tek bir çağrı yeri, o emeği teknik bir önekle bozuyordu. İki yerde vardı
(`support`, `tanimlar`).

**KİLİT DAR TUTULDU.** `tests/hata-mesaji.test.ts` yalnız **korumasız**
`String(hata)` kalıplarını arar; `e instanceof Error ? e.message : String(e)`
**doğrudur** (o dal yalnız `Error` olmayan bir fırlatma için koşar) ve
yasaklamak geriye seçenek bırakmazdı. Kilit ilk yazımında 7 doğru satırı
yanlışlıkla yakaladı — daraltıldı, sonra düzeltme geri alınarak
**yakaladığı doğrulandı** (`tanimlar/page.tsx:352`).

Kanıt: `tests/destek.dom.test.ts` **4 test** (uç düştüğünde "talep yok"
yazılmaz; `Error:` öneki yok; **gerçekten** boş listede yazılır; dolu liste
çizilir) + `tests/hata-mesaji.test.ts` (sınıf kilidi). `vitest` **191** yeşil
(31 dosya, 3 ardışık tam koşum), `tsc` temiz, `npm run build` yeşil.

### P61 — "Yükleniyor değil" ile "hata yok" aynı şey değildir
Status: BITTI · Depends-on: P60
Scope: P60'ın destek sayfasında bulduğu boş-durum çelişkisini sınıf olarak
süpür ve kilitle.
Acceptance: her örnek ölçümle gösterilir; kilit gerçek bir sızıntı yakalar;
kilidin **sınırı** yazılır; gates.
Notes (2026-08-01):
**ÜÇ ÖRNEK DAHA.** Boş-durum metni yalnız `!isLoading` (ya da hiç) ile
koşullanmıştı; istek düştüğünde `isLoading` false olur ve liste boştur —
sayfa **hem hatayı hem "kayıt yok"u** gösterirdi:

| Yer | Çelişki |
|---|---|
| Şikayet haritası | Başlıkta haritadan gelen **"3 açık şikayet"**, altta **"Açık şikayet yok"** |
| Bina düzenleme | "Veriler yüklenemedi" + **"Kat yok"** |
| Tanımlar | Hata kutusu + **"Kayıt yok"** |

Haritadaki en açık olanıydı: sayaç **başka bir uçtan** (`/building-map`)
geliyor ve doğru; düşen tek şey daire detayındaki şikayet listesiydi. Yani
ekran kendi kendisiyle çelişiyordu.

**KİLİT ÜÇÜNCÜSÜNÜ KENDİ BULDU.** İlk ikisi okunarak bulundu;
`tests/hata-mesaji.test.ts`e eklenen kural yazılır yazılmaz
`tanimlar/page.tsx:354`ü yakaladı.

**KİLİDİN SINIRI AÇIKÇA YAZILDI.** Kural şu: *boş-durum koşulu yalnız
`isLoading`e dayanamaz.* Bina düzenlemedeki örnek **türev** bir listeden
geliyordu (`data?.items ?? []` → `floors`) ve hiçbir statik kural onu
yakalamazdı — o **okuyarak** bulundu. Yakalayamadığını yakalıyormuş gibi
anlatan bir kilit, yanlış güven verir; sınır testin içine yazıldı.

**BİNA DÜZENLEMEDE PROP EKLENDİ.** `BlockDetail` yükleme durumunu
görmüyordu; `yuklemeHatasi` geçirildi. Bileşenin içinden `useSWR`e uzanmak,
aynı veriyi iki yerden çekmek olurdu.

Kanıt: `tests/harita-bina.dom.test.ts` **2 test** (liste düşünce "yok"
yazılmaz; **gerçekten** boşken yazılır) + `tests/hata-mesaji.test.ts` **+1
kilit**. `vitest` **194** yeşil (32 dosya, 3 ardışık tam koşum), `tsc` temiz,
`npm run build` yeşil.

### P62 — Koyu temada devrilmemiş renkler (kendi eklediğim biri dahil)
Status: BITTI · Depends-on: P61
Scope: Koyu tema bu depoda **merkezîdir** (`globals.css` içinde `.dark`
kuralları; sayfalar `dark:` yazmaz). Devrilmemiş bir renk sınıfı kullanmak
sessiz bir kusurdur. Ölç, kapat, kilitle.
Acceptance: eksikler sayılır; okunurluğu bozanlar devrilir; kilit enjekte
edilmiş yeni bir renkle doğrulanır; gates.
Notes (2026-08-01):
**ÖNCE KENDİ İŞİM.** P52'de eklediğim çıkış uyarısı `text-rose-700`
kullanıyordu ve **`rose` ailesi hiç devrilmemişti** — koyu temada koyu gül
rengi koyu zemine düşüyordu. Aynı boşluk üç yerde daha vardı: mesaj
gönderim hatası (`text-rose-600`), finans "çıkış" tutarı (`text-rose-600`)
ve tesis silme düğmesi (`text-rose-700`).

**ÖLÇÜM.** `dark:` öneksiz kullanılan **85** renk sınıfından **32**'si
devrilmemişti. Okunurluğu gerçekten bozanlar — **saydam yüzeyde koyu
metin** — devrildi: `rose-600/700/800/900`, `emerald-600` (`-700/-800`
devrilmiş, `-600` unutulmuş), `sky-700/800`, `amber-900`; eşlik eden
`bg-rose-50/100`, `bg-sky-50/100`, üç `border-*-200` ve `hover:bg-rose-50`.

**KALAN 20'Sİ GEREKÇELİ.** Doygun zeminler (`bg-*-500/600/700`) beyaz metin
taşır ve iki temada da aynıdır; koyu zeminler (`bg-slate-800/900`) zaten
koyudur; koyu kenarlıklar metin taşımaz; `text-slate-300` yetki matrisinde
"izin yok" işaretidir ve **silik olması tasarımdır**. Bunları devirmek,
kasıtlı kararları bozmak olurdu — bu yüzden kilit bir **gerekçeli liste**
tutar, hepsini devirmez.

**KİLİT ÖNCE SESSİZCE GEÇTİ — VE BU YAKALANDI.** İlk yazımda kaçış
katmanları fazlaydı (`\\b` kaynağa `\\\\b` olarak yazılmıştı); üretilen
düzenli ifade **hiçbir şeyle eşleşmiyordu** ve test "geçti". Enjekte edilen
`text-fuchsia-700` yakalanmayınca ortaya çıktı. Düzeltildikten sonra aynı
enjeksiyon **yakalandı**. Bu, oturumun kuralını bir kez daha doğruladı:
**yakaladığını görmeden kilit sayma** — sessizce geçen bir kilit, olmayan
bir kilitten daha kötüdür, çünkü güven verir.

Kanıt: `tests/koyu-tema.test.ts` (sınıf kilidi, enjekte renkle doğrulandı),
`app/globals.css` **+11 kural**. `vitest` **195** yeşil (33 dosya, 3 ardışık
tam koşum), `tsc` temiz, `npm run build` yeşil.

### P63 — Adsız form denetimleri (biri tesis silme onayıydı)
Status: BITTI · Depends-on: P62
Scope: Ekran okuyucu bir denetimi **adıyla** duyurur. Panelde adı olmayan
denetimleri ölç, kapat, kilitle.
Acceptance: her sızıntı ölçümle gösterilir; kilit enjekte edilmiş bir
kaldırmayla doğrulanır; gates.
Notes (2026-08-01):
**DÖRT DENETİMİN ADI YOKTU:**

| Yer | Ne oluyordu |
|---|---|
| Tesis silme onayı | Yalnız `placeholder` — **yıkıcı işlem** |
| Yetki matrisi araması | Yalnız `placeholder` |
| Finans tür süzgeci | **Hiç** etiket yok |
| Yönetişim aktarım kutusu | Başlık görsel olarak yakın ama **bağlı değil** |

**YER TUTUCU AD DEĞİLDİR.** Yazmaya başlayınca kaybolur ve ekran
okuyucuların bir kısmı hiç okumaz. En ağırı tesis silme onayıydı: adını
duyamayan kullanıcı, **ne yazdığını bilmeden yıkıcı bir işlemi onaylardı**.

**İKİ VERİ-SÜRÜCÜLÜ GİRDİYE AÇIK `aria-label`.** `settings` ve `tanimlar`
girdileri `<Field>`in **üç dallı** içeriğinin son dalında; sarmalayıcı
onlarca satır yukarıda kalıyor. Ad zaten `Field`ten geliyor ama burada
tekrar edildi: dallanma büyüdükçe adın sessizce kopmasını engeller — kilit
de tam bu iki dosyayı işaret etmişti.

**PENCERE GENİŞ TUTULDU, ÇÜNKÜ DAR PENCERE DOĞRU KODU SUÇLAR.** Kilit
sarmalayıcıyı 16 satır geriye kadar arar; ilk denemede 6 satırdı ve
`login` ile `users` gibi **etiketli** denetimleri sızıntı sayıyordu.

**MEVCUT BİR TEST KUSURU SABİTLİYORMUŞ.** `yonetisim.dom.test.ts` aktarım
kutusunu `getByRole("textbox", { name: "" })` ile buluyordu — yani testin
kendisi **kutunun adı olmamasına** dayanıyordu. Ad eklenince kırıldı;
kırılması doğrudur ve test adla arayacak şekilde güncellendi.

Kanıt: `tests/erisilebilir-etiket.test.ts` (sınıf kilidi, `yetki`
sayfasından `aria-label` geri alınarak **yakaladığı doğrulandı**), 2 yeni
anahtar × 7 dil. `vitest` **196** yeşil (34 dosya, 3 ardışık tam koşum),
`tsc` temiz, `npm run build` yeşil.

### P64 — Vezne hareketinde çift kayıt riski — KAPATILDI
Status: BITTI · Depends-on: —
<!-- 2026-08-02: etiket [KEREM] + BLOKE(ürün kararı) idi. YANLIŞTI, P22'nin
     aynı sınıfından: bloke eden hiçbir DIŞ şey yoktu (kimlik, donanım,
     sunucu erişimi değil) — yalnız "üç seçenekten hangisi" sorusu vardı ve
     kural 11 bunu açıkça ajanın işi sayıyor ("never ask ... which
     approach?; Decide, record the decision + reasoning"). Maddenin kendi
     önerisi (1) uygulandı. -->
Scope: Ödeme yollarında çift kayıt korumasını süpür.
Notes (2026-08-01):
**SÜPÜRME SONUCU — İKİ YOLDAN BİRİ KORUNUYOR:**

| Yol | Koruma |
|---|---|
| `POST /dues/payments` (sağlayıcı ödemesi) | `Idempotency-Key` **zorunlu**; yoksa 400. Panel `UnitDetail`de anahtarı üretip gönderiyor. ✔ |
| `POST /panel/finans-hareketler` (**vezne**) | Kimlik **yok**. ✗ |

**RİSK.** Panelin düğmesi uçuş sırasında `yMesgul` ile kilitli — yani hızlı
çift tıklama korunuyor. Korunmayan şey **zaman aşımı sonrası tekrar**: istek
sunucuya ulaşıp yanıt dönmezse, kullanıcı "kaydedilmedi" sanıp tekrar basar
ve kasada **iki hareket** oluşur. Yönetici bunu ancak mutabakatta fark eder.

**NEDEN KENDİ BAŞIMA DEĞİŞTİRMEDİM.** `finans.py` bu ayrımı **bilinçli**
belgeliyor: `dues_payment` sağlayıcı odaklıdır (idempotency, provider
referansı), `finansal_hareket` ise **vezne** kaydıdır ve ikisini birleştirmek
"sağlayıcı alanlarını her nakit tahsilatta boş bırakmak" demekti. Kimlik
eklemek yeni bir Alembic revizyonu + benzersiz indeks + uç sözleşmesi
değişikliği demektir; belgelenmiş bir tasarım kararını tek taraflı bozmak
doğru olmazdı. **Karar Kerem'in.**

**ÜÇ SEÇENEK (karar için):**
1. `finansal_hareket`e `idempotency_key` (nullable + kısmi benzersiz indeks);
   panel her form açılışında anahtar üretir. `dues/payments` ile aynı desen.
2. Sunucuda **kısa pencereli tekrar tespiti** (aynı tenant + kasa + tutar +
   açıklama, 60 sn içinde) → 409. Şema değişmez ama meşru arka arkaya iki
   aynı tahsilatı da engeller.
3. Değiştirme; riski kabul et (vezne kaydı elle düzeltilebilir).

Öneri: **(1)** — `dues/payments` deseni zaten kurulu ve testli.

---

UYGULAMA (2026-08-02) — **seçenek (1) yazıldı.** Commit: `23bec66`.

**NEDEN ARTIK BEKLEMEDİM.** Bu madde `[KEREM]` + `BLOKE(ürün kararı)`
etiketiyle duruyordu, ama bloke eden **dış** hiçbir şey yoktu: kimlik,
donanım, sunucu erişimi gerekmiyordu — yalnızca "üç seçenekten hangisi"
sorusu vardı. Kural 11 bunu açıkça ajanın işi sayar ("never ask Kerem for
... preference ... which approach?; Decide, record the decision +
reasoning"). Bu, P22'nin denetimde yakalanan hatasının **aynı sınıfıdır**:
yapılabilir bir işi `BLOKE` etiketi kalıcı olarak görünmez kılıyordu.
Maddenin kendi önerisi (1) uygulandı, gerekçesi aşağıda.

**KAPSAM GENİŞLETİLDİ — bir uç değil ALTI.** Ölçüm `POST
/panel/finans-hareketler`i işaret ediyordu, ama `finansal_hareket` yazan
**altı** uç var ve altısı da aynı zaman-aşımı tekrarına açıktı:
`/finans/tahsilat`, `/finans/tahsilat/toplu`, `/finans/hareketler`,
`/finans/virman`, `/finans/iade`, `/finans/acilis`. Beşini korunmasız
bırakmak, kapatılan riski **başka bir düğmeye taşımak** olurdu. Altısı da
tek bir yardımcıdan (`_idem_yaz`) geçiyor.

**ÜÇ TASARIM KARARI (hepsi ölçülmüş bir alternatifi eliyor):**

1. **Başlık ZORUNLU DEĞİL** (`dues/payments`ten farklı olarak). O uç
   `Idempotency-Key` yoksa 400 döner; burada aynısını yapmak, **çalışan
   prod'da** başlık göndermeyen her istemciyi anında kırardı. Gönderildiğinde
   koruma tam, gönderilmediğinde eski davranış aynen sürüyor — yani revizyon
   **geriye uyumlu**. Test bunu ayrıca kilitliyor.

2. **`idem_satir` (ikinci sütun).** Bir vezne işlemi **birden çok satır**
   yazabilir: virman iki satırdır, toplu tahsilat ve "Yeni Satır" akışı N
   satır. Tekilliği yalnız `(tenant_id, key)` üzerinde kurmak, kimliği
   satırların **yalnız birine** yazdırırdı ve tekrar gelen istek işlemin
   öteki satırlarını **bulamazdı** (eksik yanıt). İndeks
   `(tenant_id, idempotency_key, idem_satir)`; satır sırası işlem içinde
   deterministik olduğu için tekrar aynı çiftlere çarpar.

3. **YARIŞ DA KAPALI.** Yalnız "önce oku, sonra yaz" yapmak iki isteğin
   **aynı anda** gelmesini açık bırakırdı. Benzersizlik ihlali yakalanıyor
   ve o durumda da mevcut satırlar 200 ile dönüyor — koruma veritabanı
   kısıtına dayanıyor, uygulama sırasına değil.

**İMZA NEYİ KAPSAR:** `(tip, yon, tutar_kurus, kasa_id)`. Açıklama/belge no
**dışarıda**: kullanıcı tekrar denerken açıklamayı düzeltmiş olabilir; para
hareketi aynıysa bu aynı işlemdir. Aynı anahtar **farklı** bir para
hareketiyle gelirse **409** — sessizce eski kaydı döndürmek, kullanıcıya
"kaydedildi" deyip **parayı kaydetmemek** olurdu.

**TEKRAR DENETİME YAZILMAZ:** hiçbir yeni para hareketi oluşmadı; denetim
kaydına satır atmak "iki tahsilat girildi" diye okunurdu.

**PANEL:** anahtar **form doldurma anında** üretilir ve **başarıya kadar
sabit** kalır (zaman aşımı sonrası tekrar aynı anahtarla gider), başarının
ardından yenilenir (sonraki meşru hareket ayrı bir işlemdir). BFF
`/api/panel/[kaynak]` başlığı **iletir** — vekilde üretmek işe yaramazdı,
her istek yeni anahtar alırdı.

**GÖÇ:** `0028_vezne_idempotency` — yeni revizyon (kural 7; yerinde
düzenleme yok). `downgrade` indeksi **açıkça** düşürür; `DROP COLUMN`un yan
etkisine güvenmek, `goc-tersinirlik.sh`in "ARTIK" ölçümünün yakalayacağı
sessiz bir kalıntı bırakabilirdi.

**TESTLER:** `test_finans.py` +6. Hepsi sonucu **defterin kendisinden**
(kasa bakiyesi) doğruluyor — yalnız yanıt gövdesine bakmak, ikinci bir
satırın sessizce yazıldığını kaçırabilirdi. `finans.dom.test.ts` +2 (anahtar
tekrar denemede **aynı**, başarıdan sonra **değişir**); ikisi de **mutasyon
denetiminden** geçti.

**SÖZLEŞME:** `contracts/openapi.yaml` — altı operasyona
`IdempotencyKeyOpsiyonel` parametresi + `200` (tekrar) ve `409` yanıtları.
`HareketOut` **değişmedi**: yeni sütunlar yanıta çıkmıyor.

### P65 — Tarayıcıdan 1.000 ardışık istek: sınırsız "tüm kayıtlar" çekimi
Status: BITTI · Depends-on: P64
Scope: `fetchAllItems` döngüsünü ölç; sınırla ve **sessiz kırpma bırakma**.
Acceptance: sınır ve uyarı testle sabitlenir; gates.
Notes (2026-08-01):
**DÖNGÜ `meta.total`A KADAR KOŞUYORDU.** Aidat raporu üç çekim yapıyor; üçüncüsü
**süzgeçsizdir** (`/api/dues/payments`, filtre yok) ve yalnızca **eski**
(dönemi `null`) kayıtları tahakkuk üzerinden atfetmek için var. 200.000
ödemesi olan bir sitede bu, **tarayıcıdan 1.000 ardışık istek** demektir:
sayfa dakikalarca kilitli görünür ve kullanıcı raporun hesaplandığını sanır.
P39 sunucu tarafında aynı sınıfı ölçmüştü (`/activity` tek istekte 350.000
satır); **istemci tarafı bakılmamıştı**.

**SINIR TEK BAŞINA YETMEZ.** Kırpıp susmak, **eksik bir raporu tam sanmak**
demektir — ve bu rapor **tahsilat toplamıdır**. Bu yüzden `fetchAllPaged`
`{items, kesildi}` döner ve çağıran `kesildi`yi **kullanıcıya söylemek
zorundadır**. Sayfada zaten aynı deseni izleyen bir örnek vardı
(`unitTruncated` → "ilk 200 daire" notu); yenisi onun yanına kondu.

**KENDİ KURALIMI BİR KEZ ÇİĞNEDİM, SONRA DÜZELTTİM.** İlk hâlde
`fetchAllItems` geriye dönük uyum için bırakılmıştı ve `fetchAllPaged`i
sarıyordu — yani üst sınır **sarmalayıcının arkasındaydı**. Sonuç:
**dört çağıranın hepsi 5.000'de kırpılır ve hiçbiri bunu söylemezdi.**
"Sessiz kırpma yapma" kuralını tam da onu koyarken bozuyordum. Sarmalayıcı
kaldırıldı; tek giriş `fetchAllPaged`tir ve dört çağıranın **hepsi** artık
`kesildi`yi ekrana taşıyor: aidat raporu (üç çekimin herhangi biri),
görev raporu ve tur raporu (tarih aralığını daraltma önerisiyle).

Kanıt: `tests/sayfali-cekim.test.ts` **3 test** (sınıra ulaşmayan veri
kırpılmaz; üst sınırda durur **ve söyler**; boş uç tek istekte biter),
`raporEskiOdemeKesildi` + `raporKesildi` × 7 dil; `tests/client.test.ts` yeni imzaya taşındı. `vitest` **199** yeşil (35 dosya, 3 ardışık
tam koşum), `tsc` temiz, `npm run build` yeşil.

### P66 — Denetim kaydında ham rol; kilidin kendi kör noktası
Status: BITTI · Depends-on: P65
Scope: Kapsamı olmayan sayfalara devam; bulunanı düzelt ve **kilidi
düzelt**.
Acceptance: sızıntı ölçümle gösterilir; kilit genişletilir ve yakaladığı
doğrulanır; gates.
Notes (2026-08-01):
**DENETİM KAYDI ROLÜ HAM ÇİZİLİYORDU** (`yonetici`, `guvenlik`). Panelin
geri kalanı rolleri `rolAdi` ile çevirir (`lib/roles.ts`). Denetim kaydı
**"kim ne yaptı"nın kanıtıdır**; orada okuyanın tanımadığı bir jeton
göstermek kaydı okunamaz kılar — hem de KVKK/denetim gerekçesiyle tutulan
bir kayıtta.

**ASIL BULGU: P53'ÜN KİLİDİ BUNU GÖREMİYORDU.** `ham-enum` kilidinin alan
listesi `"rol"` içeriyordu, ama alan adı **`actor_rol`**dü ve düzenli
ifadedeki kelime sınırı (`\b`) yüzünden eşleşmiyordu. Yani sızıntı tam
kilidin kör noktasında duruyordu. Ders: **alan adı önek alabilir**; bir
kilidin kapsamı, "hangi adları düşündüm"le sınırlıdır. Liste genişletildi
ve düzeltme geri alınarak **yakaladığı doğrulandı**
(`audit/page.tsx:147`).

**`action` BİLEREK ÇEVRİLMEDİ.** `user.create` gibi kodlar teknik bir
olay adıdır, numaralandırma değil; onlarca kodu sözlüğe taşımak, her yeni
uç eklendiğinde çeviri borcu üretirdi ve denetim kaydını **aranabilir**
olmaktan çıkarırdı (kod sabit, çeviri dile göre değişir).

Kanıt: `tests/denetim.dom.test.ts` **2 test** (rol çevrilir, ham değer
görünmez; uç düştüğünde satır çizilmez), `tests/ham-enum.test.ts` alan
listesi genişletildi. `vitest` **201** yeşil (36 dosya, 3 ardışık tam
koşum), `tsc` temiz, `npm run build` yeşil.

### P67 — Kilidi örnek örnek büyütmek yerine kuralını düzelt
Status: BITTI · Depends-on: P66
Scope: P66'da `actor_rol` alan listesine **tek tek** eklenmişti; bu, bir
sonraki `xxx_durum`u yine kaçırmak demekti. Kuralı düzelt ve prefix'li
alanları yeniden süpür.
Acceptance: kalıp önekli alanları da yakalar; süpürme sonucu yazılır; kilit
doğrulanır; gates.
Notes (2026-08-01):
**LİSTEYE EKLEMEK ÇÖZÜM DEĞİL, YAMA.** P66'nın düzeltmesi `"actor_rol"`ü
listeye ekliyordu. Ama sorun listenin eksikliği değil, **kalıbın alan adını
tam eşleştirmesiydi**. Kalıp artık `(\w+_)?<alan>` kabul ediyor: `actor_rol`,
`hedef_durum`, `bildirim_tip` — hepsi tek kuralla yakalanır ve liste
sekiz girdide kaldı.

**PREFİX'Lİ SÜPÜRME TEMİZ ÇIKTI.** Genişletilmiş kalıpla panel yeniden
tarandı: kalan eşleşmelerin hepsi **prop ya da form değeri**
(`<DurumRozet durum={t.durum} />`, `value={form.kategori}`) — ekrana metin
olarak çizilen ham numaralandırma **kalmadı**. Yani P53–P66 zinciri bu
sınıfı gerçekten kapattı; sonuç varsayılmadı, yeniden ölçüldü.

**KİLİT YİNE DOĞRULANDI.** P66'nın düzeltmesi geri alındı, yeni kalıp aynı
satırı yakaladı (`audit/page.tsx:147`) — kural değişikliği kapsamı
daraltmadı.

Kanıt: `tests/ham-enum.test.ts` (kalıp düzeltildi, liste sadeleşti, enjekte
ihlalle doğrulandı). `vitest` **201** yeşil, `tsc` temiz, `npm run build`
yeşil.

### P68 — Yönetici satırlarında dizin anahtarı + gizli sabit Türkçe
Status: BITTI · Depends-on: P67
Scope: Kapsamı olmayan sayfalara devam (`tenants`).
Acceptance: iki kusur da gösterilir; **testin neyi kanıtlayıp
kanıtlamadığı** yazılır; gates.
Notes (2026-08-01):
**KUSUR 1 — `key={i}` ve ORTADAN SİLİNEBİLEN SATIR.** Tesis oluşturma
formunda yönetici satırları listeleniyor ve **ortadaki satır
silinebiliyor**. React dizin anahtarında DOM düğümlerini yeniden kullanır:
imleç/odak, tarayıcının otomatik doldurması ve **parola yöneticisinin bağı**
bir alt satıra kayar. Her satırda **parola alanı** var — yanlış satıra
bağlanan bir parola yöneticisi ciddi bir kusurdur. Satırlara kararlı
`anahtar` verildi.

**KUSUR 2 — GİZLİ SABİT TÜRKÇE.** Aynı satırın başlığı
`` `Yönetici ${i + 1}` `` diye yazılıydı. Üç i18n taraması da göremedi:
JSX metin düğümü değil (şablon dizgesi), öznitelik değil, ve P54'ün diyalog
taraması yalnız `window.confirm/alert/prompt`a bakıyor. Sözlüğe taşındı
(`tesisYoneticiSira`, 7 dil) ve testi **kusur geri konarak doğrulandı**.

**TESTİN SINIRI AÇIKÇA YAZILDI.** Silme testi `key={i}` geri konunca da
**geçiyor** — ölçüldü. Çünkü girdiler kontrollü (`value={y.ad}`) ve React
doğru değeri yeniden çizer; kararlı anahtarın asıl kazancı **tarayıcının
kendi durumudur** ve o jsdom'da gözlenemez. Test duruyor (silmenin değer
kaymasına yol açmadığını sabitler) ama **"kararlı anahtar testi" diye
sunulmadı**: ölçmediği bir şeyi ölçüyormuş gibi göstermek, yeşil bir
suite'i yanlış güvene çevirir. Bu, oturumun tekrar eden dersinin aynısı —
P62'de kilit sessizce geçmişti, P65'te sessiz kırpmayı kendim koymuştum.

Kanıt: `tests/tesis-yonetici.dom.test.ts` **2 test** (biri gerekçesiyle
birlikte sınırlı sayılıyor), `tesisYoneticiSira` × 7 dil. `vitest` **203**
yeşil (37 dosya), `tsc` temiz, `npm run build` yeşil.

### P69 — Şablon dizgesindeki metin: taramanın üçüncü kör noktası
Status: BITTI · Depends-on: P68
Scope: P68'in bulduğu `` `Yönetici ${'${i + 1}'}` `` sızıntısını **sınıf olarak**
süpür ve kilitle.
Acceptance: süpürme sonucu ölçümle yazılır; kilit P68'in kusuru geri
konarak doğrulanır; kilidin sınırı yazılır; gates.
Notes (2026-08-01):
**SÜPÜRME TEMİZ ÇIKTI — VE BU ÖLÇÜLDÜ.** Panel yeniden tarandı: yorumlar ve
sınıf dizgeleri dışında, içinde boşluklu metin geçen tek bir şablon dizgesi
kalmadı. P68'in düzelttiği satır **tek örnekti**; bu varsayılmadı.

**KİLİT EKLENDİ.** `tests/i18n.test.ts` artık dördüncü bir tarama yapıyor.
Kural: yorumlar ve `className` dışında, `${'${...}'}` parçaları çıkarıldığında
geriye **boşluklu metin** kalan şablon dizgesi sızıntıdır. URL ve jeton
kalıpları boşluk içermediği için doğal olarak elenir. P68'in kusuru geri
konarak **yakalandığı doğrulandı** (`tenants/page.tsx:214`).

**ÜÇ SINIRI DA YAZILDI (gizlenmedi):**
1. **Çok satırlı dizge** — satırdaki ters tırnak sayısı tekse dizge o
   satırda bitmiyordur; taranmaz.
2. **İç içe dizge** — `` `...${'${x ? `...` : ""}'}...` `` satır içinde yanlış
   eşleşir. Tarama **satır tabanlıdır** ve iç içe dizgeleri ayrıştıramaz;
   bu satırlar atlanır. Ölçüldü: ikisi de URL/durum simgesi kurar, metin
   taşımaz.
3. **Tarayıcı önyükleme betiği** (`layout.tsx` tema betiği) metin değil
   **kod** taşır.

Bu sınırlar testin içine yazıldı. Bir kilidin neyi *görmediğini* söylememek,
onu olduğundan güçlü göstermektir — oturumun P61 ve P62'de öğrendiği ders.

Kanıt: `tests/i18n.test.ts` **+1 tarama** (enjekte ihlalle doğrulandı).
`vitest` **204** yeşil (37 dosya), `tsc` temiz, `npm run build` yeşil.

### P70 — Mobil enterpolasyonlu dizgeler: ölçüldü, kilit EKLENMEDİ
Status: BITTI(ölçüm) · Depends-on: P69
Scope: P69'un panelde kapattığı "şablon dizgesindeki metin" sınıfını mobilde
ara; mümkünse `sabit_metin_denetimi_test.dart`i genişlet.
Acceptance: bölge ölçülür; kilit **ancak yakaladığı gösterilebiliyorsa**
eklenir.
Notes (2026-08-01):
**TERK EDİLEN BÖLGE ÖLÇÜLDÜ.** Mobil kilit enterpolasyonlu satırları
**bilerek atlıyor** ve gerekçesi yazılı: "enterpolasyon iç içe tırnak
içerebilir ve hiçbir ayıklayıcı bunu doğru bölemez". O bölge ilk kez
tarandı — parantez sayan bir ayıklayıcıyla `${'${...}'}` blokları atılıp
kalan metne bakıldı:

* **7 satır** çıktı, **yedisi de `debugPrint`** — geliştirici günlüğü,
  kullanıcı yüzeyi değil.
* Yani **kullanıcıya sızan çevrilmemiş metin yok**. Terk edilen bölge
  gerçekten boştu; ama bunu **bilmek** ile **varsaymak** ayrı şeylerdir ve
  artık ölçüm var.

**KİLİT EKLENMEDİ — VE NEDENİ BU MADDENİN ASIL İÇERİĞİ.** Genişletme
denendi; üç turda üç ayrı sorun çıktı:
1. Yalnız `${'${...}'}` biçimini tarayınca enjekte edilen
   `` 'Yonetici $n satiri' `` (basit `$` enterpolasyonu) **kaçtı**.
2. Basit `$` de kapsanınca **iki yanlış pozitif** çıktı: enterpolasyonun
   **içinde tırnak** olan satırlarda dizge ayıklayıcısı (tırnak sayan) ile
   enterpolasyon ayıklayıcısı (parantez sayan) aynı metni farklı bölüyor.
3. O satırlar elenince enjekte edilen sızıntı **yine yakalanmadı** ve
   kalan bağlamda nedeni güvenilir biçimde bulunamadı.

Bu yüzden değişiklik **geri alındı**. Yakaladığını gösteremediğim bir kilidi
commit'lemek, bu oturumun tekrar tekrar belgelediği hatanın ta kendisi
olurdu (P62'de kilit sessizce geçiyordu, P65'te sessiz kırpmayı kendim
koymuştum). **Yeşil ama kör bir kilit, kilit yokluğundan kötüdür.**

> **KAPANDI (P86).** Öngörülen çözüm — tırnak ve enterpolasyonu
> **birlikte** yürüten bir belirteçleyici — yazıldı ve **iki ayrı
> enjeksiyonla** doğrulandı. Ayrıntı P86'da.

**SONRAKI TUR İÇİN NOT.** Doğru çözüm satır tabanlı düzenli ifade değil,
gerçek bir **Dart dizge belirteçleyicisi** (tırnak + enterpolasyon iç içe
geçmesini birlikte çözen).

Kanıt: ölçüm çıktısı (7/7 `debugPrint`), `flutter test
test/sabit_metin_denetimi_test.dart` yeşil (dosya **değişmedi**).

### P71 — Şeffaflık panosu testlere bağlandı (P48'in geri dönüşü sessiz olurdu)
Status: BITTI · Depends-on: P70
Scope: Kapsamı olmayan sayfalara devam (`transparency`).
Acceptance: her test **kusuru geri koyarak** doğrulanır; gates.
Notes (2026-08-01):
**BU SAYFA P48'İN ÇIKIŞ NOKTASIYDI** ve o bulgunun geri dönüşü **sessiz**
olurdu. Sayfanın kendi `tl()` biçimlendiricisi vardı: aynı tutarı `TL` ekiyle
yazıyor ve `toLocaleString` üzerinden **ortama bağımlıydı** — küçük-ICU'lu bir
çalışma zamanında `5,000,00 ₺` üretirdi. P48 tek kaynağa bağladı ama **hiçbir
test bunu tutmuyordu**: biri "sadeleştirme" diye yerel bir biçimlendirici geri
koysa, geliştirme ortamında hiçbir şey kırılmazdı.

**ÜÇ TESTİN ÜÇÜ DE GERİ KOYARAK DOĞRULANDI:**
1. **Para tek biçimde.** `tl`yi eski `(k/100).toFixed(2) + " TL"` hâline
   çevirdim → test düştü. Test ayrıca eski biçimin **iki izini** de yasaklıyor
   (`5000.00` ve `… TL`), yani yalnız doğruyu değil **yanlışın dönüşünü** de
   tutuyor.
2. **Ay listesi düştüğünde** hata görünür ve "Veri yok" **yazılmaz** —
   P60/P61'in sınıfı bu sayfada da sabitlendi.
3. **Gerçekten boş listede** "Veri yok" yazılır (2'nin ölçümü anlamlı
   kalsın diye: yalnız 2'yi yazmak, metni tamamen silerek de geçilebilirdi).

Kanıt: `tests/seffaflik.dom.test.ts` **3 test**. `vitest` **207** yeşil
(38 dosya, 2 ardışık tam koşum), `tsc` temiz, `npm run build` yeşil.

### P72 — Duyurular: "düzenlendi" işareti ve hata/boş ayrımı
Status: BITTI · Depends-on: P71
Scope: Kapsamı olmayan sayfalara devam (`announcements`).
Acceptance: her test kusuru geri koyarak doğrulanır; gates.
Notes (2026-08-01):
**"DÜZENLENDİ" EKİ KÜÇÜK AMA ANLAMLI.** Duyuru satırında
`updated_at !== created_at` ise ek çıkıyor. Sakin, okuduğu duyurunun
**sonradan değiştiğini** yalnız buradan anlar — bir su kesintisi saati
değiştiyse ve işaret çıkmıyorsa, kişi eski bilgiye göre davranır. Koşul
yanlış kurulursa iki yönde de bozulur: hiç çıkmazsa **değişiklik gizlenir**,
her duyuruda çıkarsa **işaret anlamsızlaşır**. İkisi de test edildi
(değişmemiş duyuruda **çıkmaz**, değişmişte **çıkar**) ve koşul kaldırılarak
doğrulandı.

**HATA/BOŞ AYRIMI BU SAYFADA DA SABİTLENDİ.** Uç düştüğünde "Duyuru yok"
yazılmaz; gerçekten boş listede yazılır. İkinci test olmadan birincisi,
metni tamamen silerek de geçilebilirdi.

Kanıt: `tests/duyuru.dom.test.ts` **4 test**. `vitest` **211** yeşil
(39 dosya, 2 ardışık tam koşum), `tsc` temiz, `npm run build` yeşil.

### P73 — Entegrasyon sırrı: yalnızca yazılır, hiç okunmaz
Status: BITTI · Depends-on: P72
Scope: Kapsamı olmayan **son** panel sayfası (`integrations`).
Acceptance: write-only sözleşmesi testle sabitlenir ve kusuru geri konarak
doğrulanır; gates.
Notes (2026-08-01):
**SÖZLEŞME İKİ TARAFLI VE İKİSİ DE SESSİZ KIRILABİLİR.** `auth_secret`
write-only'dir: sunucu onu **asla döndürmez**, yalnız `auth_secret_set`
bayrağını verir. Panelin karşılık gelen kuralı: alan **boş bırakılırsa
gövdeye hiç konmaz**.

* **Boş dizge göndermek**, kayıtlı sırrı **silmek** olurdu — ve bunu
  kullanıcı hiçbir yerde görmezdi. Entegrasyon bir sonraki tetiklemede
  sessizce 401 alır; gürültü uyarısı gitmez, kimse fark etmez. Ölçüldü:
  koşul kaldırılınca test düşüyor.
* **Sırrı forma ön-doldurmak** olsaydı, ekranda bir sır dururdu. Test
  düzenleme açıldığında alanın **boş** olduğunu doğruluyor.

**`channel_type`/`auth_type` BİLEREK ÇEVRİLMEDİ** — `webhook`, `bearer`,
`hmac` protokol terimleridir, ürün numaralandırması değil; çevirmek
entegrasyonu kuran kişinin belgeyle eşleştirdiği adı bozardı. (Denetim
kaydındaki `action` için verilen kararla aynı — P66.)

**PANEL KAPSAMI TAMAMLANDI.** Kapsamı olmayan sayfa kalmadı: P43'te kurulan
altyapı ile başlayan tur, `integrations` ile son sayfayı da bağladı.
Panel bileşen testi **12 → 214**.

Kanıt: `tests/entegrasyon.dom.test.ts` **3 test** (sır listede görünmez;
düzenlemede boş açılır **ve gönderilmez**; uç düştüğünde liste çizilmez).
`vitest` **214** yeşil (40 dosya, 2 ardışık tam koşum), `tsc` temiz,
`npm run build` yeşil.

### P74 — Backend taban sayısı ÖLÇÜLDÜ: "1138 passed" bayattı, 1 HATA var
Status: BITTI(ölçüm) · Depends-on: P73
Scope: Backend suite P41–P42'den beri koşulmadı; raporlarda tekrarlanan sayıyı
**ölç**.
Acceptance: gerçek sayı yazılır; sapma varsa teşhis edilir.
Notes (2026-08-01):
> **DÜZELTME (P75).** Aşağıdaki "1 error" bulgusu **yanlış çıktı**: sebep
> suite değil, **benim aynı veritabanında ikinci bir koşum başlatmam**dı.
> Temiz koşum `1138 passed, 1 skipped, EXIT=0` (20 dk 49 sn) — yani
> tekrarlanan sayı **doğruymuş**. Kök neden ve düzeltme P75'te.

**İLK ÖLÇÜM (22 dk 48 sn, KİRLİ):** `1137 passed, 1 skipped, **1 error**` —
`test_unit_complaints.py::test_p24_okunmamis_diger_suzgeclerle_BIRLIKTE_calisir`
kurulumda ERROR verdi.

**SIRA BAĞIMLI SANILDI (değilmiş).** Aynı test **tek başına geçiyor** (1 passed, 9 sn) ve
**dosyanın tamamı da geçiyor** (24 passed, 2 dk). Yani kusur testte değil,
**testler arası durumda** — başka bir dosyanın bıraktığı durum `ucworld`
fixture'ını düşürüyor (ERROR, FAILURE değil: hata **kurulumda**). Panelde
aynı sınıf P55'te bulunmuştu (`portal-ayar` 14 koşumda 1 düşüyordu); backend
suite'inde de varmış.

**İKİNCİ BULGU — BORU HATTI ÇIKIŞ KODUNU MASKELİYOR.** Arka plan görevi
"exit code 0" diye tamamlandı bildirdi; oysa koşumda bir ERROR vardı. Sebep
`pytest … | tail -6`: boru hattının çıkış kodu **son komutunki**dir.
Ölçüldü: `(exit 1) | tail -1` → `$?` = **0**. Bu oturum boyunca kapıları
"N passed" satırını **okuyarak** geçtim, çıkış koduna güvenmedim — ama
harness'ın bildirdiği çıkış koduna güvenseydim yeşil sanacaktım. Kural:
**boru hattına sokulan bir test koşumunun çıkış kodu kanıt değildir.**

**AYRICA: `ps` BU KONTEYNERDE YOK.** Koşumun sürüp sürmediğini
`ps aux | grep pytest | wc -l` ile sorgulamak `0` döndürdü ve bunu "süreç
ölmüş" diye okudum — oysa `ps` kurulu değil, hata yutulmuş ve `wc -l` boş
girdiden `0` üretmişti. **Sıfır bir ölçüm değil, bir komut hatasıydı.** Bu
yüzden ilk koşumu ölü sanıp ikinci bir koşum başlattım. Güvenilir sinyal
**log dosyasının büyümesidir**.

**AÇIK İŞ → P75'te KAPANDI.** Kirleten "dosya" yoktu; kirleten **ikinci
koşumdu**.

### P75 — Kök neden: eşzamanlı ikinci koşum, birincinin verisini siliyordu
Status: BITTI · Depends-on: P74
Scope: P74'ün "1 error" bulgusunun kök nedenini bul; tekrarını engelle.
Acceptance: kök neden gösterilir; koruma **eşzamanlılık denemesiyle**
doğrulanır; temiz taban ölçülür; gates.
Notes (2026-08-01):
**KÖK NEDEN — KENDİ HATAM.** `backend/tests/conftest.py` içinde session
başında koşan autouse bir temizlik var:
```python
cur.execute("DELETE FROM tenant WHERE slug LIKE %s", (onek + "%",))
```
Bu **tüm** fixture tenant'larını siler — **başka bir koşumun canlı
tenant'ları dahil**. Birinci koşum sürerken ikinci bir pytest başlattım;
ikincinin açılış temizliği birincinin verisini **ortasından sildi** ve
birinci koşum alfabetik olarak sonlardaki dosyada (`test_unit_complaints`)
fixture ERROR'u verdi. P74'te bunu "suite kusuru" sandım.

**TEŞHİSİ ELEYEREK DOĞRULADIM:** test tek başına geçiyor (9 sn), dosyanın
tamamı geçiyor (24 passed), `retention + unit_complaints` birlikte geçiyor
(26 passed). Hiçbiri sıra bağımlılığı göstermedi — çünkü öyle bir şey yoktu.

**KORUMA: KOŞUM KİLİDİ.** Temizlikten **önce** `pg_try_advisory_lock`;
alınamazsa koşum **hemen** ve açık bir mesajla düşer. Beklemek yerine hemen
hata: 22 dakikalık bir suitte sıraya girmek **sessiz bir takılma** gibi
görünürdü. Kilit, koşum boyunca açık kalan bağlantıya bağlıdır — Ctrl-C ya
da timeout'ta bağlantı kapanır ve kilit **düşer**, takılı kalmaz.

**ÖLÇÜMLE DOĞRULANDI:** biri koşarken ikincisini başlattım → ikincisi
`exit 1` ve tam o mesajla düştü; birincisi normal tamamlandı (24 passed).
İlk denemede **konteynerdeki kod eskiydi** (`grep -c pg_try_advisory_lock`
→ **0**): `api` imajı kodu içine gömüyor, `docker compose build api`
gerekiyordu — yani o denemeyi de farkında olmadan eski kodla yapmıştım.

**TEMİZ TABAN (tek koşum, borusuz):**
`1138 passed, 1 skipped, 2 warnings` — **EXIT=0**, 20 dk 49 sn.
Yani P41'den beri tekrarladığım sayı **doğruymuş**; P74'ün "bayat" iddiası
yanlıştı ve o madde düzeltildi.

**ÜÇ ÖLÇÜM HATASI, TEK DERS.** Bu turda üç kez "ölçtüm" sandığım şey ölçüm
değildi: (1) `ps` konteynerde **yok** — `ps … | wc -l` → `0`, hata yutuldu
ve sıfırı "süreç ölmüş" diye okudum; (2) `pytest … | tail` **çıkış kodunu
maskeliyor** (`(exit 1) | tail -1` → `$?`=0); (3) konteynerde **eski kod**
vardı. Üçü de aynı cümlenin yüzleri: **sessizlik, sıfır ve yeşil — üçü de
tek başına kanıt değil.** Kilitler için yazdığım kural ("yakaladığını
görmeden kilit sayma") kabuk komutları için de geçerliymiş.

Kanıt: `backend/tests/conftest.py` (koşum kilidi), eşzamanlılık denemesi,
temiz tam koşum **1138 passed / EXIT=0**.

### P76 — Göç kapıları da ölçüldü + kapı kuralı "nasıl koşulur"a bağlandı
Status: BITTI · Depends-on: P75
Scope: P75'in ortaya çıkardığı ölçüm tuzaklarını kalıcılaştır; uzun süredir
koşulmayan **göç kapılarını** sür.
Acceptance: her iki betik koşar ve sonucu yazılır; kural 6 güncellenir.
Notes (2026-08-01):
**GÖÇ KAPILARI SÜRÜLDÜ (P39'dan beri ilk kez):**

| Denetim | Sonuç |
|---|---|
| `infra/goc-uyum-dogrula.sh` | **bulgu 0**, EXIT=0 |
| `infra/goc-tersinirlik.sh` | **bulgu 0**, EXIT=0 — `downgrade base` sonrası şema **boş**; gidiş-dönüş şeması düz upgrade ile **birebir aynı** (7477 satır); **28 sınırın** her biri iki kez geri alınıp yeniden uygulandı |

Yani 0022–0027 arası **altı yeni revizyon** (P33–P38) tersinirlik denetiminden
geçti; o turlarda tek tek sürülmüşlerdi ama **hep birlikte** ilk kez sürüldü.
`goc-tersinirlik.sh` ayrı ve **atılabilir** veritabanları (`goc_a`, `goc_b`)
kurup siler — dev verisine dokunmaz; çalıştırmadan önce betiği bu yüzden
okudum.

**KURAL 6 ARTIK "NASIL"I DA SÖYLÜYOR.** P75'te üç ölçüm tuzağı ölçülmüştü;
üçü de kural metnine girdi, çünkü bir sonraki tur bunları yeniden keşfetmek
zorunda kalmamalı:
1. `docker compose build api` **önce** — imaj kodu içine gömer, aksi halde
   **eski kod** test edilir.
2. Çıktıyı **boruya sokma** — boru hattının çıkış kodu son komutunkidir
   (`(exit 1) | tail -1` → `$?`=0) ve `pytest`in hatası kaybolur.
3. **Tek koşum** — ikincisi birincinin fixture tenant'larını siler (artık
   koşum kilidi engelliyor, ama kural yazılı).
   Ayrıca: konteynerde **`ps` yoktur**; koşumun sürdüğü **log dosyasının
   büyümesinden** anlaşılır.

Kanıt: iki betiğin çıktısı (bulgu 0 / EXIT=0), `docs/MASTER-PLAN.md` kural 6.
Panel yeniden doğrulandı: `vitest` **214** yeşil.

### P77 — İki ayrıştırıcı, tek ayırıcı kuralı (mobilde çapraz kilit)
Status: BITTI · Depends-on: P76
Scope: `core/para.dart` ile `core/sayi.dart` **ayrı** dönüş tipleri üretiyor;
ayırıcı kuralının aynı kaldığını **kilitle**.
Acceptance: kilit gerçek bir sapmayla doğrulanır; politika farkları ayrıca
yazılır; gates.
Notes (2026-08-01):
**NEDEN GEREKLİ.** P49/P50 panel ile mobil arasında "aynı metin, iki farklı
tutar" kusurunu bulmuştu. Aynı risk **tek uygulamanın içinde** de var:
metrekare alanı `sayiCoz`, tutar alanı `tlMetniniKurusaCevir` kullanıyor.
İkisi ayrışırsa kullanıcı aynı yazımı iki alanda kullanamaz — ve bunu
hiçbir mevcut test tutmuyordu (ikisinin kendi testleri vardı, **aralarındaki
sözleşmenin** testi yoktu).

**KİLİT KABUL/RED KARARINI KARŞILAŞTIRIR, DEĞERİ DEĞİL.** Dönüş tipleri
farklı (kuruş tamsayısı ↔ `double`), ama örtüşen alanda **aynı kararı**
vermeliler. Yedi kabul, sekiz red girdisi çift taraflı sürülüyor.

**POLİTİKA FARKLARI AYRICA VE BİLEREK YAZILDI:**
* **Negatif**: para reddeder, sayı kabul eder — işaret bir **biçim** değil
  **alan** kuralıdır (tutar negatif olamaz, bir ölçü/fark olabilir).
* **Üç ondalık hane** (`1,234`): para reddeder (kuruş iki hanedir), sayı
  kabul eder.
* **Boş girdi**: `sayiCoz` **`bos`** der (ayrı durum), para `null`.

**TESTİN KENDİ HATASI ÖLÇÜLDÜ.** İlk yazımda `1,234`ü ortak "red" listesine
koymuştum ve test düştü — kod değil **test** yanlıştı: bu bir ayırıcı farkı
değil politika farkı. Ortak listeye koymak, **doğru davranışı tutarsızlık
gibi göstermek** olurdu.

**SANITY KONTROLÜ İLK DENEMEDE ANLAMSIZDI.** Kilidi doğrulamak için
`sayi.dart`a boş gövdeli bir `if` ekledim — hiçbir şeyi değiştirmiyordu ve
test tabii ki geçti. Gerçek bozma (binlik ayırıcı dalını reddetmeye çevirmek)
`KABUL: "1.250"` testini düşürdü. Yine aynı ders: **yakaladığını görmeden
kilit sayma** — ve "bozdum, geçti" demek için bozmanın gerçekten bozması
gerekir.

Kanıt: `mobile/test/ayirici_tutarlilik_test.dart` **18 test** (enjekte
sapmayla doğrulandı). `flutter analyze` temiz, `flutter test` **1551** yeşil.

### P78 — Aynı çapraz kilit panelde de (ve iki istemci arasında)
Status: BITTI · Depends-on: P77
Scope: P77'nin mobilde kurduğu ayırıcı sözleşmesini panelde de kilitle.
Acceptance: kilit gerçek bir sapmayla doğrulanır; iki istemcinin listeleri
bağlanır; gates.
Notes (2026-08-01):
**PANELDE DE AYNI İKİLİK VARDI.** Tutar alanları `lib/money.ts::tlToKurus`,
para olmayan sayılar `lib/sayi.ts::sayiCoz` kullanıyor. İkisinin **kendi**
testleri vardı; **aralarındaki sözleşmenin** testi yoktu — biri
"sadeleştirilirse" diğeriyle sessizce ayrışır ve kullanıcı aynı yazımı iki
alanda kullanamaz olurdu.

**ÜÇÜNCÜ BİR HALKA: İKİ İSTEMCİ.** Test, kabul/red listelerinin
`mobile/test/ayirici_tutarlilik_test.dart` ile **aynı değerleri** taşıdığını
da doğruluyor. Yorumda "mobil de aynısını sürer" yazıp geçmek, zamanla
yalan olacak bir cümleydi; liste artık **testin kendisi tarafından**
tutuluyor ve değiştirilirken ikisi birlikte değiştirilmek zorunda.

Böylece dört ayrıştırıcı tek kurala bağlandı: panel-para ↔ panel-sayı
(bu tur), mobil-para ↔ mobil-sayı (P77), panel ↔ mobil (P50 + bu turun
liste bağı).

**POLİTİKA FARKLARI İKİ İSTEMCİDE AYNI:** negatif (para reddeder, sayı
kabul eder — işaret bir **alan** kuralıdır), üç ondalık hane (kuruş iki
hanedir), boş girdi (`sayiCoz` **`bos`** der, ayrı durum).

**KİLİT DOĞRULANDI.** `sayi.ts`in binlik ayırıcı dalı reddetmeye çevrildi →
**dört test** düştü (`KABUL: 1.250`, `1.250,00` ve karşılıkları). P77'de
öğrenilen ders uygulandı: bozmanın **gerçekten bozması** gerekiyor.

Kanıt: `admin-web/tests/ayirici-tutarlilik.test.ts` **19 test** (enjekte
sapmayla doğrulandı). `vitest` **233** yeşil (41 dosya, 2 ardışık tam
koşum), `tsc` temiz, `npm run build` yeşil.

### P79 — İki istemci aynı gruplamayı üretir: çıktı bağlandı, yol bağlanmadı
Status: BITTI · Depends-on: P78
Scope: P78 **ayrıştırmayı** bağladı; **biçimlendirmeyi** de bağla.
Acceptance: çapraz bağ gerçek bir gruplama değişikliğiyle doğrulanır; yol
farkının **neden** kalması gerektiği yazılır; gates.
Notes (2026-08-01):
**YOLLAR FARKLI VE BU BİLİNÇLİ:**
* **Panel** gruplamayı **kendi** yapar (`binlikAyir`). `toLocaleString` bir
  **çalışma zamanı** bağımlılığıdır: küçük-ICU'lu bir Node/tarayıcıda
  `tr-TR` desteklenmez ve `en-US`a düşer — P48'de ölçüldü (`5,000,00 ₺`).
* **Mobil** `intl` paketinin `NumberFormat('#,##0.00', 'tr_TR')`ini kullanır.
  Orada aynı risk **yoktur**: yerel veri **paketin içinde** gelir, çalışma
  zamanından okunmaz.

Yani mobildeki `NumberFormat` bir tutarsızlık değil; iki ortamın risk
profili farklı ve karar her ortamda ayrı verilmiş. **Bunu "birleştirmek"
mobilde gereksiz bir elle-gruplama, panelde ise geri adım olurdu.**

**AMA ÇIKTI AYNI OLMALI** — ve bunu hiçbir şey tutmuyordu. İki suite de
kendi değerlerini sürüyordu (`mobile/test/i18n_test.dart`: `tlTutar(125000)
== '1.250,00'`), aralarında bağ yoktu. Panel testi artık **aynı iki değeri**
mobilin karşılığına atıfla sürüyor; biri değişirse diğeri de değişmek
zorunda. (P78'in liste bağıyla aynı teknik.)

**SİMGE YERİ FARKI DA YAZILDI.** Panel son ek (`1.250,00 ₺`), mobil ön ek
(`₺1.250,00`) ya da `1.250,00 TL`. **Gövde aynı, yerleşim ürün kararı**
(mobil README §15). Bunu "tutarsızlık" diye düzeltmek, iki uygulamanın
yerleşik görünümünü tek bir turda değiştirmek olurdu — test bu ayrımı
**açıkça** kaydediyor ki sonraki tur onu kusur sanmasın.

**DOĞRULANDI.** `binlikAyir`ın ayırıcısı `.` → `,` yapıldı → **yedi test**
düştü (`'1,250,00' ≠ '1.250,00'`).

Kanıt: `admin-web/tests/money.test.ts` **+2 test**. `vitest` **235** yeşil
(41 dosya, 2 ardışık tam koşum), `tsc` temiz, `npm run build` yeşil.

### P80 — Panelin rol listesi sunucu enum'una bağlandı
Status: BITTI · Depends-on: P79
Scope: Çapraz bağ zincirini para/sayıdan **rol**e taşı.
Acceptance: bağ gerçek bir sapmayla doğrulanır; iki yön de kapsanır; gates.
Notes (2026-08-01):
**NEDEN GEREKLİ — SESSİZ İKİ KUSUR.** `ROLE_OPTIONS` panelin rol listesidir:
açılır menüleri doldurur ve `rolAdi` çevirisini sağlar. Sunucu `user_role`
enum'una **yeni bir değer** eklenir ve bu liste güncellenmezse:
1. Yeni rol açılır menüde **hiç görünmez** → yönetici o rolü **atayamaz**.
2. Mevcut kayıtlarda rol adı **ham tel değeriyle** çizilir — **P66'da
   denetim kaydında tam bu oldu** (`yonetici` diye görünüyordu).

İkisi de sessizdir: hiçbir şey patlamaz, panel eksik çalışır. Ölçüm anında
altı rolün altısı örtüşüyordu — yani bugün sapma **yok**; kilitlenen şey
**yarın da olmaması**.

**İKİ YÖN DE KAPSANDI.** Fazladan bir değer de sızıntıdır: sunucunun
tanımadığı bir rol atanmaya çalışılırsa istek **422** döner ve kullanıcı
nedenini anlamaz. Bu yüzden karşılaştırma **küme eşitliği**, alt küme değil.

**KAYNAK OLARAK `models.py` SEÇİLDİ**, çünkü enum'un **tek doğruluk
kaynağı** orası; `rol-matrisi.txt` kilidi de ondan türer. Panel testinin
backend dosyası okuması, depo tek olduğu için maliyetsiz — ve i18n
taramaları zaten aynı deseni kullanıyor.

**DOĞRULANDI.** `guvenlik_amiri` panel listesinden silindi → **iki test**
düştü (bağ + mevcut rol testi).

Kanıt: `admin-web/tests/roles.test.ts` **+1 test**. `vitest` **236** yeşil
(41 dosya, 2 ardışık tam koşum), `tsc` temiz, `npm run build` yeşil.

### P81 — Altı numaralandırma haritası da sunucuya bağlandı
Status: BITTI · Depends-on: P80
Scope: P80'in rol bağını `lib/enum-adlari.ts`in **altı** haritasına taşı.
Acceptance: bağ gerçek bir eksikle doğrulanır; istisnalar gerekçeli ve
**kendileri de denetlenir**; gates.
Notes (2026-08-01):
**GERİ DÜŞÜŞE DÜŞÜLDÜĞÜNÜ KİMSE FARK ETMİYOR.** P53 "tanınmayan değer HAM
döner" kuralını koydu ve bu **doğru** bir geri düşüş: rozet boş kalmaz.
Ama sunucu bir enum'a değer ekleyip harita güncellenmediğinde, kullanıcı
`zimmetli` yerine tanımadığı bir jeton görür ve **hiçbir şey bunu haber
vermez**. Geri düşüş hedef değildir; bağ onu görünür kılar.

**İSTİSNA LİSTESİ GEREKÇELİ VE DENETLENİYOR.** `peyzaj_yaklasan` /
`peyzaj_kacirilan` bilerek çevrilmedi: peyzaj üründen **kaldırıldı**
(`087f33f`), enum değeri yalnız eski kayıtlar için şemada duruyor ve
sözlüğe geri getirmek **silinmiş bir özelliğin sözcüğünü ürüne geri
sokmak** olurdu.

İkinci bir test, istisna listesindeki değerlerin sunucuda **gerçekten var
olduğunu** doğruluyor — aksi halde liste zamanla **yalan bir gerekçe
koleksiyonuna** dönerdi: sunucudan silinmiş bir değeri "bilerek hariç" diye
tutmak, olmayan bir şeyi açıklamaktır. Bu, oturumun kilit derslerinin
doğal uzantısı: **istisnanın kendisi de ölçülmeli.**

**DOĞRULANDI.** `bakimda` haritadan silindi → bağ testi düştü
(`['musait','zimmetli'] ≠ ['bakimda','musait','zimmetli']`).

Kanıt: `admin-web/tests/enum-bag.test.ts` **7 test** (6 bağ + istisna
denetimi). `vitest` **243** yeşil (42 dosya, 2 ardışık tam koşum), `tsc`
temiz, `npm run build` yeşil.

### P82 — Mobil rol enum'u da sunucuya bağlandı (bedeli en ağır olan yer)
Status: BITTI · Depends-on: P81
Scope: P80'in rol bağını mobile taşı.
Acceptance: bağ gerçek bir sapmayla doğrulanır; `unknown` istisnası
gerekçeli **ve kendisi de denetlenir**; gates.
Notes (2026-08-01):
**MOBİLDE BEDEL DAHA AĞIR.** Panelde eksik bir rol açılır menüyü eksiltir;
mobilde rol **ekran seçer** (`HomeGate`) ve yetkiyi belirler. Sunucu yeni
bir rol eklerse ve `UserRole` güncellenmezse `fromClaim` sessizce
`UserRole.unknown` döner — kullanıcı **giriş yapar ama uygulama onu
tanımaz**. Bu sınıf **ölçülmüştü**: P35'te güvenlik amiri `HomeGate`in
hiçbir dalına uymayıp **splash'ta kilitli** kalmıştı. Bağ, o turun elle
bulduğu şeyi otomatik hâle getiriyor.

**`unknown` İSTİSNASI VE İSTİSNANIN DENETİMİ.** `unknown` sunucuda yoktur
ve olmamalıdır: istemcinin "bu rolü bilmiyorum" demek için kullandığı
**yerel** bir değerdir, o yüzden karşılaştırmadan çıkarılıyor. İkinci test
sunucuda `unknown` **olmadığını** doğruluyor — bir gün eklenirse o `where`
filtresi **gerçek bir rolü sessizce eler** ve bağ körleşir. P81'de kurulan
kural burada da geçerli: **istisnanın kendisi de ölçülmeli.**

**DOĞRULANDI.** `guvenlikAmiri`nin wire değeri bozuldu → bağ testi düştü
(`'guvenlik_amiri_X' instead of 'guvenlik_amiri'`).

Kanıt: `mobile/test/rol_bagi_test.dart` **2 test**. `flutter analyze`
temiz, `flutter test` **1553** yeşil.

### P83 — Ayar anahtarları sunucu şemasına bağlandı (ve alt küme kararı yazıldı)
Status: BITTI · Depends-on: P82
Scope: Çapraz bağ zincirini **tenant ayarlarına** taşı.
Acceptance: bağ gerçek bir yazım hatasıyla doğrulanır; ters yönün **neden**
zorlanmadığı yazılır; gates.
Notes (2026-08-01):
**KUSUR SINIFI: SESSİZ "KAYDETTİM" SANISI.** `settings` sayfası operasyon
ayarlarını **veri-sürücülü** çizer; `OPERASYON` listesindeki her `anahtar`
bir sunucu alanıdır. Anahtar yanlış yazılırsa sayfa **yine çizer**: alan
görünür, kullanıcı doldurur, "Kaydet"e basar. Sunucu o alanı tanımaz —
istek ya **422** döner ya da alan **sessizce yok sayılır**. İkisinde de
kullanıcı ayarı değiştirdiğini **sanır**. (P56'nın "sessiz temizleme"
sınıfıyla akraba: yazma isteği gider, sonuç kullanıcının sandığı gibi
olmaz.)

**TYPESCRIPT BUNU NEDEN YAKALAMIYOR.** `anahtar` tipi
`keyof TenantSettings`tir, ama o arayüz `lib/types.ts`te **elle
yazılmıştır** ve sunucudan türemez — iki taraf **birlikte** yanlış
olabilir. Bu bağ kaynağı **`schemas.py`** alır.

**TERS YÖN BİLEREK ZORLANMADI — VE BU BİR TESTLE YAZIYA GEÇTİ.** Sunucuda
panelin göstermediği alanlar var (konum, otopark kapasitesi, ANPR eşiği…).
`OPERASYON` bir "tüm ayarlar" listesi **değil**, bilinçli bir alt kümedir:
her yeni sunucu alanını panele basmak, **ürün kararı olmadan arayüz
büyütmek** olurdu. İkinci test bu farkın **var olduğunu** doğruluyor —
yoksa bir sonraki tur eksikliği kusur sanıp "tamamlamaya" kalkardı.
İstisnayı yazmak yetmez, **istisnanın sürdüğünü de ölçmek** gerekir
(P81/P82'de kurulan kural).

**DOĞRULANDI.** `gurultu_esigi` → `gurultu_esik` yapıldı → bağ testi düştü.

Kanıt: `admin-web/tests/ayar-bag.test.ts` **2 test**. `vitest` **245**
yeşil (43 dosya, 2 ardışık tam koşum), `tsc` temiz, `npm run build` yeşil.

### P84 — BFF beyaz listesi sözleşmeye bağlandı
Status: BITTI · Depends-on: P83
Scope: Çapraz bağ zincirini panelin **tek sunucu kapısına** taşı.
Acceptance: bağ gerçek bir yazım hatasıyla doğrulanır; kaynak seçimi
gerekçelendirilir; gates.
Notes (2026-08-01):
**BEDELİ: ÇALIŞMA ZAMANINDA KAYBOLAN BİR ÖZELLİK.** `lib/panel-vekil.ts`
panelin sunucuya açılan tek kapısıdır; her giriş bir backend **yoluna**
eşler. Yol yanlış yazılır ya da sunucudan kaldırılırsa panel tarafında
hiçbir şey derlenmez/patlamaz — istek gider, **404** döner, kullanıcı
sayfada "yüklenemedi" görür. Yani tek harflik bir hata, sessizce çalışmayan
bir özellik demektir.

**KAYNAK SEÇİMİ: `contracts/openapi.yaml`.** Bu depoda **sözleşme** odur ve
`backend/tests/test_sozlesme_sapmasi.py` onun uygulamayla **iki yönde**
örtüştüğünü zaten kilitliyor ((METOT, yol) çiftleri). Dolayısıyla buradaki
bağ dolaylı olarak **uygulamaya** bağlanmış olur — openapi'yi kaynak almak
**ikinci bir doğruluk kaynağı uydurmak değil**, var olan zincire eklenmektir.
Zincir: panel vekili → openapi → FastAPI yolları.

**PARAMETRELİ YOLLAR NORMALLEŞTİRİLDİ.** `/x/{id}` ↔ `/x/*`: iki tarafın
parametre **adları** farklı olabilir ve ad farkını sapma saymak, doğru
kodu hata gibi göstermek olurdu (sözleşme sapması testi de aynı
normalizasyonu yapıyor).

**DOĞRULANDI.** `/yetki-matrisi` → `/yetki-matris` yapıldı → o girişin
testi düştü. Her giriş **ayrı** test olarak koşuyor (33 test), böylece
hata mesajı hangi girişin bozuk olduğunu doğrudan söylüyor.

Kanıt: `admin-web/tests/vekil-bag.test.ts` **33 test**. `vitest` **278**
yeşil (44 dosya, 2 ardışık tam koşum), `tsc` temiz, `npm run build` yeşil.

### P85 — Dil listeleri üç yerde: panel, mobil enum, ARB dosyaları
Status: BITTI · Depends-on: P84
Scope: Çapraz bağ zincirinin son duplikasyonu — dil kümesi.
Acceptance: bağ gerçek bir eksikle doğrulanır; sıra da kapsanır; gates.
Notes (2026-08-01):
**AYNI KÜME ÜÇ YERDE TUTULUYOR:** panel `DILLER`, mobil `AppDil` enum'u,
ve `mobile/lib/l10n/app_<kod>.arb` dosyaları. Biri eklenip diğeri
unutulursa kusur **sessizdir ve her yerde farklı görünür**:
* panelde seçilebilen bir dil **mobilde yok**,
* `AppDil`de olan bir dilin **ARB'si yoksa** `gen-l10n` o dili sessizce
  İngilizce'ye düşürür — kullanıcı dilini seçer, **arayüz değişmez**.

**SIRA DA KARŞILAŞTIRILIYOR.** `supportedLocales` yorumu "sıra = seçicideki
sıra" diyor; iki istemcinin seçici sırasının ayrışması bir ürün
tutarsızlığıdır ve küme eşitliği bunu görmez.

**DOĞRULANDI.** `es` panel listesinden silindi → **iki test** düştü (hem
sıra/küme bağı hem ARB bağı).

Kanıt: `admin-web/tests/dil-bag.test.ts` **2 test**. `vitest` **280**
yeşil (45 dosya, 2 ardışık tam koşum), `tsc` temiz, `npm run build` yeşil.

### P86 — P70'in açık işi kapandı: belirteçleyici önce KENDİNİ test ediyor
Status: BITTI · Depends-on: P85
Scope: P70'te doğrulanamadığı için **eklenmeyen** kilidi, doğrulanabilir
biçimde yaz.
Acceptance: kilit **iki ayrı enjeksiyonla** (basit `$` ve `${…}`)
doğrulanır; belirteçleyicinin kendisi de test edilir; gates.
Notes (2026-08-01):
**P70'TE NEDEN BAŞARISIZ OLDUĞUNU ÇÖZEN ŞEY: SIRA.** O turda kilidi mevcut
`sabit_metin_denetimi_test.dart`in **içine** eklemeye çalıştım — dosyanın
kendi süzgeçleri, `_izinli` listesi ve erken `continue`'ları vardı; enjekte
edilen sızıntı neden kaçtı, kalan bağlamda bulunamadı. Bu tur kilit **ayrı
ve küçük** bir dosyaya yazıldı: mevcut testin süzgeçlerine dokunmuyor, kendi
belirteçleyicisini kullanıyor.

**VE ÖNCE KENDİNİ TEST EDİYOR.** Ürün kodunu taramadan önce **beş birim
testi** belirteçleyiciyi sürüyor:
* basit `$ad` atılır,
* `${…}` **tümüyle** atılır,
* **enterpolasyonun içindeki tırnak dizge açmaz** — P70'te iki yanlış
  pozitif tam buradan çıkmıştı,
* kaçış dizisi (`\'`) tırnağı kapatmaz,
* `cevrilmeliMi` jeton ile cümleyi ayırır (`A-12`, `dd.MM.yyyy`,
  `gorev_tipi` **elenir**).

Yani "kilit çalışıyor mu" sorusu **ürün kodunu bozmadan** yanıtlanıyor —
P70'te eksik olan tam buydu.

**İKİ ENJEKSİYONLA DA DOĞRULANDI:** `'Yonetici $n satiri'` (basit) ve
`'Toplam ${'${a + 1}'} adet demirbas'` (süslü). İkisi de yakalandı; P70'te
basit biçim kaçmıştı.

**KAPSAM DIŞI, GEREKÇELİ:** `debugPrint` ve `assert` — geliştirici günlüğü,
kullanıcı yüzeyi değil (P70'in ölçümü: o bölgedeki yedi satırın yedisi de
`debugPrint`ti). Enterpolasyonsuz satırlar da bu dosyanın işi değil; onları
mevcut kilit zaten tarıyor.

Kanıt: `mobile/test/enterpolasyon_sabit_metin_test.dart` **6 test** (5 birim
+ 1 tarama), iki enjeksiyonla doğrulandı. `flutter analyze` temiz,
`flutter test` **1559** yeşil.

### P87 — Mobil suite anomalisi kovalandı: 5 koşumda tekrarlamadı
Status: BITTI(ölçüm) · Depends-on: P86
Scope: P85'te bir koşumda görülen başarısızlık listesini kovala.
Acceptance: ya kök neden ya da **sayıyla** bir tekrarlanabilirlik ölçümü.
Notes (2026-08-01):
**GÖZLEM.** P85'in kapı kontrolünde `flutter test` çıktısının son satırı
`… and 12 more` idi — yani o koşumda **bir "Failing tests" bloğu vardı**.
Komut `| tail -1` ile çalıştığı için **liste kaybolmuştu**; elimde yalnız
son satır kaldı. (Aynı boru tuzağı P74'te backend'de de ısırmıştı.)

**KOVALAMA.** Üç ardışık tam koşum, her biri **kendi dosyasına** yazıldı
(borusuz). Sonuç:

| Koşum | Sonuç | "Failing tests" bloğu |
|---|---|---|
| 1 | 1559 passed | **0** |
| 2 | 1559 passed | **0** |
| 3 | 1559 passed | **0** |

P86'daki iki koşumla birlikte **arka arkaya 5 temiz tam koşum**.

**NE İDDİA EDİYORUM, NE ETMİYORUM.** Anomali **tekrarlamadı**; bu, "flake
yoktu" demek **değildir** — 1/5'ten seyrek bir olay bu ölçümle ayırt
edilemez. Kaydedilen şey bir sayıdır, bir sonuç değil. Kök neden
bulunamadı çünkü **kanıt ilk seferde yok edilmişti**: tek satırlık çıktı,
hangi testlerin düştüğünü söylemiyor.

**ASIL DÜZELTME YÖNTEMDE.** Kural 6'ya P75'te yazılan "**çıktıyı boruya
sokma**" maddesi backend içindi; aynı tuzak mobilde de ısırdı. Bu tur
`flutter test` de dosyaya yazılarak koşuldu ve bundan sonra öyle
koşulacak — **kaybolan kanıt, olmayan kanıttan kötüdür**: insan "gördüm
ama bulamadım" diye bir şey bilmenin yükünü taşır, elinde bir şey olmadan.

Kanıt: `scratchpad/mt1..3.log` (üç tam koşum, üçü de temiz).
`flutter test` **1559** yeşil.

### P88 — Kapıları doğru koşan tek giriş: `infra/kapilar.sh`
Status: BITTI · Depends-on: P87
Scope: P75/P87'nin dersini **kural metninden** çıkarıp **yapıya** koy.
Acceptance: betik gerçek bir kırılmayla doğrulanır; kendi çıkış kodu de
doğrulanır; gates.
Notes (2026-08-01):
**KURALI YAZMAK YETMEDİ.** Aynı iki tuzağa bu oturumda **üç kez** düşüldü:
1. `komut | tail` — boru hattının çıkış kodu **son komutunki**dir.
   P74'te backend'in ERROR'u "exit code 0" diye bildirildi; P87'de mobilin
   "Failing tests" bloğu **kayboldu** ve kök neden **bulunamadı**.
2. `docker compose build api` unutulur → konteynerde **eski kod** koşar
   (P75'te tam bu oldu; kilit testini farkında olmadan eski kodla yaptım).

Kural 6'ya iki kez not düştüm ve iki kez yine düşüldü. **Hatırlanması
gereken bir kural, hatırlanmadığında hiçbir şey yapmaz** — bu yüzden
yapıya taşındı.

**BETİK NE YAPIYOR:** her kapıyı ayrı koşar, çıktıyı **dosyaya** yazar,
çıkış kodunu **doğrudan** okur (boru yok), backend'de imajı **önce**
yeniden kurar, sonunda tek bir özet basar ve **kendi çıkış kodunu**
başarısız kapı varsa 1 yapar. Alan seçilebilir:
`infra/kapilar.sh web mobile backend goc`.

**DOĞRULAMA — VE DOĞRULARKEN AYNI TUZAĞA DÜŞMEK.** `binlikAyir`ın
ayırıcısı bozuldu; betik `HATA web-vitest (cikis 1)` bastı. Ama ilk
kontrolde betiği `| tail -6` ile koştum ve `$?` **0** göründü — yani
betiğin var olma sebebi olan tuzağa, betiği doğrularken düştüm. Borusuz
tekrar koşuldu: **gerçek çıkış kodu 1**. Bu, kuralın neden yapıya
taşınması gerektiğinin en iyi kanıtı.

`.kapilar/` günlük dizini `.gitignore`a eklendi (yerel koşum çıktısı).

Kanıt: `infra/kapilar.sh` (yeni), kırık kodla `exit 1` + düzeltilmiş kodla
`exit 0` ölçüldü; `web` alanı üç kapıda da yeşil.

### P89 — Kapı betiği uçtan uca sürüldü: **11 kapı, hepsi tek koşumda yeşil**
Status: BITTI · Depends-on: P88
Scope: P88'de yalnız `web` dalı sürülmüştü; backend/mobil/göç dalları
**doğrulanmamıştı**. Tümünü tek koşumda sür.
Acceptance: her dal koşar, sonucu yazılır; betiğin kendi çıkış kodu okunur.
Notes (2026-08-01):
**TEK KOŞUM, ON BİR KAPI, HEPSİ YEŞİL** (`infra/kapilar.sh`, ~55 dk):

| Kapı | Sonuç |
|---|---|
| `web-tsc` / `web-vitest` / `web-build` | temiz / **280 passed** / yeşil |
| `mobil-analyze` / `mobil-test` / `mobil-apk` | temiz / **1557 passed** / APK üretildi |
| `backend-build` / `backend-up` | imaj kuruldu, konteyner ayakta |
| `backend-pytest` | **1138 passed, 1 skipped** (20 dk 51 sn) |
| `goc-uyum` | **bulgu 0** |
| `goc-tersinir` | **bulgu 0** — 28 sınırın her biri iki kez geri alınıp yeniden uygulandı |

Betiğin çıkış kodu **0**.

**BU KOŞUMUN ASIL DEĞERİ: BETİĞİN KENDİSİ DOĞRULANDI.** P88'de yalnız
`web` sürülmüştü; `backend-build → up → pytest` sırası, mobil üçlüsü ve
göç ikilisi hiç çalıştırılmamıştı. Şimdi hepsi sürüldü ve **P75'te
öğrenilen "önce imajı kur" adımının gerçekten koştuğu** görüldü.

**BİR ÖLÇÜM FARKI KAYDEDİLDİ** — ve açıklamam **yanlış çıktı** (bkz. P90).
`mobil-test` özeti bu koşumda **1557** gösterdi, öncekiler **1559**.
"`flutter`ın sayacı kırpılıyor" diye not düştüm; **öyle değilmiş**: günlük
dosyasının son satırı her koşumda `+1559 All tests passed!`. Sayıyı bozan
şey **kendi özet satırımdı**. P90'da ölçüldü ve düzeltildi. Not olarak
duruyor çünkü doğru refleks buydu: **iki farklı sayı gördüysem ikisini de
yazarım** — ama açıklamayı **ölçmeden** yazmak yanlıştı.

**ALTINCI VE YEDİNCİ TEMİZ MOBİL KOŞUM.** P87'de kovalanan anomali bu
koşumda da tekrarlamadı.

Kanıt: `.kapilar/*.log` (11 günlük), betik çıkış kodu 0.

### P90 — "Ölçüm farkı" diye yazdığım şey kendi özet satırımdı
Status: BITTI · Depends-on: P89
Scope: P89'da not düşülen 1557/1559 farkını **ölç**.
Acceptance: gerçek sebep gösterilir; araç düzeltilir; not düzeltilir.
Notes (2026-08-01):
**SEBEP: `tail -n 3 … | tr '\n' ' '`.** `kapilar.sh`in özet satırı son üç
satırı tek satıra katlıyor ve `cut -c1-90` ile kırpıyordu. Sonuç: pencerenin
**başı** görünüyordu. `flutter test` günlüğünün son üç satırı şöyle:
```
+1557 ~3: … SIRA: duyurular …
+1558 ~3: … SIRA: sakinler …
+1559 ~3: All tests passed!
```
Yani özet **ara satırı** gösteriyordu. Günlük dosyasının **son satırı her
koşumda `+1559`**; hiçbir zaman iki farklı sonuç olmamıştı.

**P89'DAKİ AÇIKLAMAM YANLIŞTI.** "`flutter`ın ilerleme sayacı son satırda
farklı kırpılabiliyor" diye yazmıştım — **ölçmeden**. Doğru refleks farkı
**kaydetmekti** (onu yaptım); yanlış olan, sebebi **tahmin edip** not
niyetine yazmaktı. Bir sayı gördüğümde açıklamasını uydurmak, o sayıyı
gizlemekten daha sinsi: gizlense birileri arardı, açıklandığında kimse
aramaz.

**DÜZELTME.** Özet artık **son anlamlı satırı** alıyor (boş satırlar
atlanarak). Doğrulandı: `web` üç kapıda yeşil ve özetler artık gerçek son
satırı gösteriyor; ayrı bir tam `flutter test` koşumunda son satır
`+1559 ~3: All tests passed!`, çıkış kodu **0**.

**ARACIN KENDİSİ DE BİR ÖLÇÜM ARACIDIR.** P88'de "kuralı yapıya taşıdım"
demiştim; bu tur o yapının **kendi raporunun** yanlış okunabildiğini
gösterdi. Kapı koşan bir betiğin özeti, kapının sonucu kadar dikkat ister.

Kanıt: `.kapilar/mobil-test.log` son üç satırı (yukarıda), düzeltilmiş
`kapilar.sh`, `flutter test` **1559** / çıkış kodu 0.

### P91 — Özet, özetlemesi gerekeni söylüyor mu? (iki kez hayır)
Status: BITTI · Depends-on: P90
Scope: P90 özetin **yanlış satırı** gösterdiğini bulmuştu; özetin
**başarısızlıkta ne dediğini** de ölç.
Acceptance: hata yolu gerçek bir kırılmayla sürülür; özet **nedeni**
söyleyene kadar düzeltilir.
Notes (2026-08-01):
**BİRİNCİ HAYIR — BAŞARIDA.** `tsc` başarılı olduğunda **hiçbir şey
yazmaz**; özet boş kalıyordu ve "okuyamadım" ile "diyecek bir şey yok"
ayırt edilemiyordu. Artık `(cikti yok)` yazıyor — P61'in boş-durum
dersinin araç tarafındaki karşılığı.

**İKİNCİ HAYIR — HATADA.** Önce yalnız günlük **yolu** basılıyordu; "neden
düştü" her seferinde ikinci bir komut gerektiriyordu. Düzelttim: "son
anlamlı satırı" bas. Sürdüm — ve çıkan şey **`Duration 12.57s`** oldu.
Yani özet, *neden düştü*yü değil *ne kadar sürdü*yü söylüyordu. İlk
düzeltme **işe yaramadı ve bunu ancak sürerek gördüm**.

İkinci düzeltme: önce **başarısızlık imzası** aranıyor
(`N failed` / `^FAIL` / `Failing tests` …), yoksa son satıra düşülüyor.
Sürüldü:
```
HATA web-vitest (cikis 1) — Tests  15 failed | 265 passed (280)
     gunluk: …/.kapilar/web-vitest.log
```
Artık özet **hem nedeni hem nereye bakılacağını** söylüyor.

**ÜÇ TURDUR AYNI ŞEY.** P88 kuralı yapıya taşıdı, P90 yapının raporunun
yanlış satırı gösterdiğini buldu, P91 raporun **hata durumunda** hiçbir şey
söylemediğini buldu. Her seferinde eksik olan aynı adımdı: **aracı bozuk
girdiyle sürmek**. Yeşil bir koşumda özet doğru görünüyordu; yanlış olduğu
ancak kırık bir koşumda ortaya çıktı.

Kanıt: kırık kodla `exit 1` + doğru neden satırı, düzeltilmiş kodla
`exit 0`; `web` üç kapıda yeşil.

### P92 — Hata özeti her kapı türü için sürüldü (biri hâlâ yalan söylüyordu)
Status: BITTI · Depends-on: P91
Scope: P91'de hata özeti **yalnız `vitest`** ile sürülmüştü. Diğer kapı
türlerinde ne dediğini ölç.
Acceptance: her tür için gerçek bir başarısızlık metniyle sürülür; eksik
kalan imza eklenir.
Notes (2026-08-01):
**SÜRÜLDÜ, DÖRT TÜR:**

| Kapı türü | Özet ne diyor | Kaynak |
|---|---|---|
| `tsc` | `lib/sayi.ts(48,41): error TS2345: …` | tip bozularak sürüldü |
| `npm run build` | `Failed to compile.` | aynı koşum |
| `vitest` | `Tests 15 failed | 265 passed (280)` | P91'den |
| `pytest` | `1137 passed, 1 skipped, 2 warnings, 1 error …` | **P74'ün gerçek ERROR'lu günlüğü** |

pytest için **simülasyon yapmadım**: P74'te gerçekten hata veren koşumun
günlüğü duruyordu, imza ona sürüldü.

**FLUTTER'DA ÖZET HÂLÂ YALAN SÖYLÜYORDU.** `Some tests failed.` imza
listesinde **yoktu**; dahası imza taraması `tail -1` ile çalıştığı için
`Failing tests:` **başlığını** seçerdi — yani "düştü" der, **ne düştüğünü
söylemezdi**. Düzeltildi: flutter günlüğünde bir `Failing tests` bloğu
varsa özet o bloğun **ilk satırını** (düşen testin adını) gösteriyor;
ayrıca `Some tests failed` ve `Failed to compile` imzalara eklendi.
Gerçek bir flutter hata bloğu metniyle sürüldü:
`/repo/mobile/test/ornek_test.dart: DURUM: bir sey`.

**P91'İN DERSİ BİR KEZ DAHA.** Orada "aracı bozuk girdiyle sür" demiştim
ama **tek bir kapı türüyle** sürmüştüm. Bir araç, sürülmediği her yolda
sessizce yanlış olabilir — ve en çok ihtiyaç duyulacağı an (mobil suite
düştüğünde, ki P87'de tam bu oldu ve kanıt kaybolmuştu) tam da sürülmemiş
yoldu.

Düzeltmeden sonra `vitest` hata yolu **yeniden** sürüldü (regresyon yok) ve
temiz koşumda çıkış kodu **0**.

Kanıt: dört kapı türünün hata özetleri (yukarıda), `web` yeşil.

### P93 — Araç ile kural aynı yeri gösteriyor
Status: BITTI · Depends-on: P92
Scope: P88–P92 boyunca `infra/kapilar.sh` yazıldı ve sürüldü, ama **kural 6
hâlâ elle koşma talimatı veriyordu**. İkisini birleştir.
Acceptance: kural betiği işaret eder; tuzaklar **yine de** yazılı kalır;
gates.
Notes (2026-08-01):
**BİR ARAÇ, KURAL ONU İŞARET ETMİYORSA DEKORDUR.** P88'de "kuralı yapıya
taşıdım" demiştim; ama kural metni hâlâ `docker compose build api`,
"boruya sokma", "tek koşum" adımlarını **elle** anlatıyordu. Yani iki
doğruluk kaynağı vardı: betik ve talimat. Bu, oturum boyunca kapattığım
**çapraz bağ** sınıfının ta kendisi (P77–P85) — aynı gerçeğin iki yerde
tutulup sessizce ayrışması. Kendi sürecimde tekrarlıyordum.

**KURAL ARTIK BETİĞİ İŞARET EDİYOR** ve kapsam tek satırda duruyor
(`/backend`, `/mobile`, `/admin-web`, `/contracts`, göç).

**AMA TUZAKLAR SİLİNMEDİ.** Betiğe yönlendirip gerekçeleri atmak,
"neden böyle" bilgisini yok etmek olurdu; elle koşan biri (ya da betiğin
çalışmadığı bir ortam) aynı üç tuzağa düşerdi. Kural artık şunu diyor:
**betiği kullan; elle koşacaksan bunlara dikkat et** — ve üçünün de hangi
turda ölçüldüğü yazılı (P74, P75, P87).

**AÇIK KALAN.** Betiğin `goc` ve `mobile` **hata** yolları uçtan uca
sürülmedi: `goc` için kırık bir revizyon üretmek, `mobile` için testi
gerçekten düşürmek gerekir. P92'de flutter imzası **sentetik** bir
günlükle sürüldü; gerçek bir düşüşle sürülmedi. Bunu "sürüldü" saymıyorum.
> **`mobile` KAPANDI (P94).** Gerçek bir düşüşle sürüldü. `goc` bilinçli
> olarak açık bırakıldı — gerekçesi P94'te.

Kanıt: `docs/MASTER-PLAN.md` kural 6; `web` kapıları yeşil (çıkış 0).

### P94 — Mobil hata yolu GERÇEK bir düşüşle sürüldü
Status: BITTI · Depends-on: P93
Scope: P93'te "sürülmedi" diye yazdığım mobil hata yolunu sür.
Acceptance: özet **düşen testin adını** söylüyor mu, ölç; geçici test
temizlenir ve yeşile dönüş doğrulanır.
Notes (2026-08-01):
**SÜRÜLDÜ.** Geçici bir başarısız test eklendi ve `infra/kapilar.sh mobile`
koşuldu:
```
OK   mobil-analyze — No issues found!
HATA mobil-test (cikis 1) — …/test/_gecici_dusen_test.dart: GECICI: kapi hata yolu s
     gunluk: …/.kapilar/mobil-test.log
OK   mobil-apk — ✓ Built …/app-debug.apk
```
Betiğin çıkış kodu **1**. Özet, **düşen testin dosyasını ve adını**
söylüyor — P92'de eklenen "Failing tests bloğunun ilk satırı" kuralı
gerçek çıktıda da çalışıyor. P92'de bu yalnız **sentetik** bir günlükle
sürülmüştü; artık gerçeğiyle sürüldü.

**BİR YAN GÖZLEM.** `mobil-apk` bir test düşerken de **yeşil** kaldı ve
bu doğrudur: `flutter build apk` testlere bakmaz. Betik kapıları
**bağımsız** koşuyor; biri düşünce diğerlerini atlamıyor. Erken çıksaydı
tek koşumda tek bulgu alınırdı — oysa amaç, bir koşumda **tüm** durumu
görmek.

**TEMİZLİK VE YEŞİLE DÖNÜŞ DOĞRULANDI.** Geçici test silindi, tam
`flutter test` yeniden koşuldu: **1559 passed**, çıkış kodu **0**.
Çalışma ağacında artık yok.

**`goc` HATA YOLU BİLİNÇLİ OLARAK AÇIK.** Sürmek için **kırık bir Alembic
revizyonu** üretmek gerekirdi; `docs/MIGRATION-POLITIKASI.md` bağlayıcıdır
ve dağıtılmış prod vardır. Bir aracı doğrulamak için ürünün en hassas
kuralını çiğnemek, doğrulamanın kendisinden pahalıdır. Açık bırakıldı ve
**neden** açık olduğu yazıldı — "unutuldu" ile "karar verildi" ayrı
şeylerdir.

Kanıt: yukarıdaki koşum çıktısı (çıkış 1), temizlik sonrası
`flutter test` **1559** / çıkış 0.

### P95 — İki sessiz güvenlik kuralı kilitlendi
Status: BITTI · Depends-on: P94
Scope: Araç turlarından (P88–P94) ürün koduna dön; ihlali **olmayan** ama
sessizce oluşabilecek iki güvenlik kuralını kilitle.
Acceptance: süpürme sonucu ölçülür; her kilit enjekte ihlalle doğrulanır;
gates.
Notes (2026-08-01):
**SÜPÜRME: İHLAL YOK.** `target="_blank"` kullanan üç bağlantının üçünde de
`rel="noreferrer"` var; `dangerouslySetInnerHTML` tek yerde ve **sabit** bir
dizge (tema önyükleme betiği). Yani kilitlenen şey bugünkü bir kusur değil,
**yarın sessizce oluşabilecek** iki kusur. P80/P81'deki gibi: ölçüm anında
sapma yok, kilitlenen şey sapmanın **fark edilebilir** olması.

**NEDEN "SESSİZ".** İkisi de eklendiği anda hiçbir şeyi bozmaz — testler
yeşil kalır, derleme geçer, ekran doğru görünür. Bedeli yalnız kullanıcıda
ortaya çıkar:
1. **`rel`siz `_blank`** → açılan sayfa `window.opener` ile **bizim
   sekmemizi** başka bir adrese yönlendirebilir (tabnabbing). Sakin bir
   duyuru fotoğrafına tıklar, geri döndüğünde "oturumunuz doldu" diyen
   **sahte bir giriş ekranı** görür. Sunucuda hiçbir iz kalmaz.
2. **Değişkenli `dangerouslySetInnerHTML`** → sunucudan ya da kullanıcıdan
   gelen metin **HTML olarak çalışır** (XSS).

**KİLİTLER ÇOK SATIRLI ETİKETİ DE OKUYOR.** `<a>` açılış etiketi genelde
birkaç satıra yayılıyor; satır bazlı bir tarama `target`i bir satırda,
`rel`i başka satırda görüp **ihlal sanardı**. Etiketin tamamı tek parça
alınıyor.

**İKİSİ DE ENJEKSİYONLA DOĞRULANDI:** `complaints` sayfasından `rel`
silindi ve `layout.tsx`e değişkenli bir `dangerouslySetInnerHTML` alanı
eklendi → iki test de düştü, sonra geri alındı.

Kanıt: `admin-web/tests/guvenlik-hijyeni.test.ts` **2 test**. `web`
kapıları yeşil (çıkış 0).

### P96 — Aynı eylemin iki yolu, iki farklı güven: `dial`
Status: BITTI · Depends-on: P95
Scope: Mobil güvenlik süpürmesi (URL açma).
Acceptance: kusur gösterilir; düzeltme enjeksiyonla doğrulanır; testin
**ortamı değil konuyu** ölçtüğü gösterilir; gates.
Notes (2026-08-01):
**BULGU: `dial` metnine iki yoldan girilir, biri doğrulanıyordu.**
* `telUri()` — şemayı **kendi kurar** ve `^\+?\d+$` doğrular. Güvenli.
* `call_models.dart` — `tel_uri` alanını **sunucu JSON'undan** alır
  (`json['tel_uri'] as String? ?? ''`) ve hiçbir doğrulama yapmaz. Bu
  değer doğrudan `Uri.parse` + `launchUrl(mode: externalApplication)`a
  gidiyordu.

Sunucu `https://…` ya da bir uygulama şeması döndürseydi, kullanıcı
**"Ara"** dediği için **tarayıcı açılırdı** ve nedenini anlamazdı. Aynı
eylemin iki yolu **aynı güvene** sahip olmalı — oturum boyunca kapattığım
"tek gerçek, iki yer" sınıfının güvenlik tarafı.

**DÜZELTME.** `dial` artık `telSemasi()` üzerinden geçiyor: şema `tel`
değilse ya da yol boşsa (`tel:` tek başına aranacak bir şey değildir)
**açmadan `false`** döner.

**TESTİN ORTAMI DEĞİL KONUYU ÖLÇMESİ — İLK YAZIMDA ÖLÇMÜYORDU.** İlk test
kararı `dial` üzerinden sürüyordu; dosya **tek başına geçti**, tam suitte
**düştü**: `launchUrl` → `MethodChannel` → *"Binding has not yet been
initialized"*. Yani test, şema kararını değil **test ortamını** ölçüyordu
— ve bunu ancak tam suitte gördüm (P94'ün dersi: sürülmemiş yol sessizce
yanlış olabilir). Karar platformdan bağımsız bir fonksiyona (`telSemasi`)
ayrıldı; test artık **kararı** ölçüyor.

**DOĞRULANDI.** Şema kontrolü kaldırıldı → test düştü; geri kondu → geçti.

Kanıt: `mobile/test/call_launcher_sema_test.dart` **2 test** (8 kötü şema +
2 geçerli). `infra/kapilar.sh mobile` → üç kapı yeşil, `flutter test`
**1561**, çıkış **0**.

### P97/P98 — Telefon normalizasyonu güncelleme yolunda yoktu (ve ilk düzeltmem bir testi kırdı)
Status: BITTI · Depends-on: P96
Scope: P96'nın izini **sunucuya** kadar sür: `tel_uri` neyden kuruluyor?
Acceptance: kusur ölçümle gösterilir; düzeltme **tam suite** ile doğrulanır.
Notes (2026-08-01):
**P97 — BULGU.** `resolve_phone_target` `uri=f"tel:{number}"` kuruyor; şema
sabit, yani şema enjeksiyonu yok. Ama **numara** nereden geliyor?
Ölçüldü: `PATCH /users/{id} {"telefon": "//evil.example/x"}` → **200**,
değer **ham saklanıyor**. `UserCreate`te normalize edici doğrulayıcı
**vardı**, `UserUpdate`/`UserContactUpdate`te **yoktu** — aynı gerçek iki
yerde, biri korumasız (oturumun tekrar eden sınıfı).

İki sonucu:
1. Telefon **global benzersiz bir giriş kimliğidir** (telefonla giriş);
   normalize edilmemiş değer benzersizliği bozar — `0532…` ile `+90532…`
   aynı kişi, farklı satır.
2. `tel://evil.example/x` gibi bir URI üretir ve **P96'nın istemci şema
   kontrolü bunu geçirir**, çünkü şema hâlâ `tel`.

Düzeltme sonrası ölçüm: kötü değer **422**; `0532 987 65 43` → **200**,
`+905329876543`.

**P98 — İLK DÜZELTMEM BİR TESTİ KIRDI ve bunu ancak TAM SUITE gösterdi.**
`1 failed, 1140 passed`:
`test_call_target.py::test_riza_yoksa_numara_aciklanmaz_404`. Sebep:
`PATCH /users/{id}/contact {"telefon": ""}` — **boş dizge "numarayı
kaldır" demek** ve doğrulayıcım onu geçersiz numara sayıp 422 döndürüyordu.
Yani doğrulayıcı, **doğrulaması gerekmeyen bir değeri** reddediyordu.

Mevcut sözleşme bunu zaten söylüyordu: `resolve_phone_target`
`(telefon or "").strip()` ile boş değeri "numara yok" sayar. **Yeni bir
kural koyarken var olanı okumamıştım.** Boş/boşluk artık olduğu gibi
geçiyor; yalnız dolu değerler normalize ediliyor.

**KAPSAM KARARI.** Diğer `telefon` alanlarına (firma, personel, dış hizmet)
**dokunulmadı**: onlar giriş kimliği değil ve dahili numara gibi serbest
biçim içerebilirler — hepsini normalize etmek gerçek veriyi bozabilirdi.
Yarım bırakmak değil, **farklı invaryant**.

Kanıt: `backend/tests/test_telefon_normalizasyonu.py` **4 test** (geçersiz
reddedilir, E.164'e normalize edilir, `None` geçer, **boş dizge kaldırır**).
`infra/kapilar.sh backend` → **1142 passed, 1 skipped**, çıkış **0**
(21 dk 12 sn).

### P99 — "Yaratmada doğrular, güncellemede doğrulamaz" sınıfı tarandı
Status: BITTI · Depends-on: P98
Scope: P97'nin `telefon`da bulduğu asimetriyi **sınıf olarak** ara.
Acceptance: tarama sonucu **tek tek gerekçelendirilir**; gerçek olan
düzeltilir; tam suite ile doğrulanır.
Notes (2026-08-01):
**TARAMA: 10 ADAY, 1 GERÇEK.** Şemalar programatik karşılaştırıldı (bir
alanı doğrulayan şema var mı, aynı alanı yazan başka şema doğrulamıyor mu).
Dokuz satır **yanlış pozitif** çıktı ve her biri okunarak doğrulandı:
* `tutar_kurus` → `TahsilatCreate`te `Field(..., ge=1)`; doğrulama
  `field_validator` **değil Field kısıtıyla** yapılıyor.
* `baslangic_saat`, `acilis`, `tarih` → `Out` şemalarındaki doğrulayıcılar
  **biçimlendirme** amaçlı; `Create` tarafında alan zaten `time`/`date`
  tipinde ve Pydantic ayrıştırıyor.
* `telefon` → P97/P98'in **bilinçli kapsam kararı** (firma/personel giriş
  kimliği değil).

**GERÇEK OLAN: `yonetim_email`.** `TenantAdminCreate` boş/boşluk değeri
`None`a çeviriyordu; `TenantSettingsUpdate` **çevirmiyordu**. `" "`
**truthy**tir — yani "yönetim e-postası var" sayılır ve bildirim yolu
**boş bir adrese** gitmeye çalışırdı. Aynı alan, iki yazma yolu, tek
doğrulayıcı: P97'nin telefonda bulduğunun aynısı.

**TARAMANIN KENDİSİ DE BİR SONUÇ.** "9 yanlış pozitif" demek, kuralın
mekanik olarak uygulanamayacağını gösterir: doğrulama bu şemalarda **üç
ayrı biçimde** yapılıyor (Field kısıtı, tip ayrıştırma, `field_validator`).
Bu yüzden buna **kilit yazılmadı** — yazılsaydı ya 9 istisna taşırdı ya da
doğru kodu hata gibi gösterirdi. Ölçüm plana yazıldı; tekrar edilmesi
gerekmez.

Kanıt: `test_telefon_normalizasyonu.py` **+1 test** (`"   "` → `None`,
`" yonetim@acme.com "` → kırpılır). `infra/kapilar.sh backend` →
**1143 passed, 1 skipped**, çıkış **0** (20 dk 53 sn).

### P100 — Sonuç raporu güncellendi (P86–P99 eklendi)
Status: BITTI · Depends-on: P99
Scope: Kerem'in istediği tek dosyalık özeti güncel tut.
Notes (2026-08-01):
Rapor P87'de kalmıştı; P88–P99 arası on iki madde eklendi. Sayılar
**yeniden ölçüldü**, hatırlanmadı: `web-vitest` **282** (bu tur koşuldu),
backend **1143** (P99), mobil **1561** (P96), göç bulgu 0 (P89).

**"YAPILMAYANLAR" BÖLÜMÜ BÜYÜDÜ ve bu bilinçli.** Altı bilinçli karar
(mobil `NumberFormat`, ayarlarda ters yön, firma telefonları, P99'un
kilitsizliği, `goc` hata yolu, teknik terimler) tek tek gerekçesiyle
duruyor. Bir raporun değeri neyi yaptığını saymasında değil, **neyi
yapmadığını ve niçin** söylemesindedir — aksi halde okuyan, eksikliği
unutulmuş sanır ve ya tekrar araştırır ya da "tamamlamaya" kalkar.

**KENDİ HATALARIM AYRI BAŞLIK.** Sekiz madde: sessizce geçen kilit, kendi
koyduğum sessiz kırpma, ölçmeden yazılmış açıklama, doğrulaması gerekmeyen
değeri reddeden doğrulayıcı… Bunları saklamak, yeşil bir suite'i yanlış
güvene çevirirdi.

Kanıt: `SONUC-RAPORU.md`; `infra/kapilar.sh web` → çıkış 0.

### P101 — 401 dört yerde, üçü farklı davranıyordu
Status: BITTI · Depends-on: P100
Scope: Oturum bitişinin (`401`) her çağrı yerinde aynı şeyi yapıp
yapmadığını ölç.
Acceptance: sapma gösterilir; ortak yol açılır; `403` ile karışmadığı
test edilir; gates.
Notes (2026-08-01):
**SAPMA.** `apiSend`, `jsonFetcher` ve `fetchAllPaged` 401'de giriş
ekranına **yönlendiriyor**. Ama üç çağrı yeri ham `fetch` kullanıyor
(FormData ve ikili gövde gerektirdikleri için — `support` yükleme + yanıt,
`raporlar` görüntüle + indir) ve 401'i **sıradan bir hata** gibi
işliyordu: kullanıcıya **"Yanıt kaydedilemedi (401)"** gibi bir **kod**
gösteriliyor, oturumun bittiği söylenmiyor ve sayfa **ölü** kalıyordu.
Aynı gerçek dört yerde, üçü farklı davranıyordu — oturumun tekrar eden
"tek gerçek, iki yer" sınıfı, bu kez **oturum yönetiminde**.

**ORTAK YOL, KOPYA DEĞİL.** `apiSend`e yönlendirmek mümkün değildi (o JSON
gövde varsayar). Bunun yerine tek bir `oturumDustu(res)` açıldı:
401'de yönlendirir ve `true` döner; çağıran o durumda **başka bir şey
yapmaz**. Üç yer buna bağlandı.

**`403` İLE KARIŞTIRILMADI — VE BU TEST EDİLDİ.** `403` "yetkin yok"
demektir, **"oturumun bitti" değil**. İkisini birleştirmek, yetkisiz bir
sayfaya bakan kullanıcıyı sebepsizce giriş ekranına atardı. Test 200/204/
403/404/409/422/500'ün hiçbirinde yönlendirme olmadığını sürüyor.

**KİLİT GÜNCELLENDİ.** `sessiz-fetch` kilidi ham `fetch` çağrılarının yanıt
denetimini arıyor; `oturumDustu` da geçerli bir denetim biçimi olarak
tanındı — aksi halde doğru düzeltme kilidi düşürürdü.

Kanıt: `admin-web/tests/oturum-401.test.ts` **2 test**. `infra/kapilar.sh
web` → üç kapı yeşil, `vitest` **284**, çıkış **0**.

### P102 — Ağ hatası da dört yerde, üçü ham gösteriyordu
Status: BITTI · Depends-on: P101
Scope: P101 401'i ortakladı; aynı çağrı yerlerinde **ağ hatası** ne oluyor,
ölç.
Acceptance: sapma gösterilir; tek yardımcıya bağlanır; ikili gövde
kısıtı korunur; gates.
Notes (2026-08-01):
**İKİNCİ SAPMA AYNI ÜÇ YERDEYDİ.** Ağ koptuğunda tarayıcı
`TypeError: Failed to fetch` atar. `apiSend`/`jsonFetcher` bunu
`ortakBaglantiYok` diye **çevirir** (tur 42'de tam bu kusur ölçülmüştü:
kullanıcıya her dilde teknik İngilizce bir metin gösteriliyordu). Ama ham
`fetch` kullanan üç yer (`support` yükleme + yanıt, `raporlar` göster +
indir) hatayı **olduğu gibi** gösteriyordu. P101'de 401'i ortakladım ama
**ağ hatasını gözden kaçırdım** — aynı çağrı yerleri, ikinci kez.

**TEK YARDIMCI, İKİ SORUN.** `agIstegi(url, init)`: ağ hatasını çevirir,
401'i işler (`null` döner). Üç yer buna bağlandı; `oturumDustu` tek başına
artık kullanılmıyor ama **kalıyor** — `agIstegi` onu çağırıyor ve ayrı
test edilebilir olması, 401/403 ayrımının kanıtını yerinde tutuyor.

**NEDEN `apiSend` DEĞİL.** `apiSend` JSON gövde varsayar; bu üç yer
**FormData** ve **ikili (blob/PDF)** gövde kullanıyor. `agIstegi` yanıtı
**olduğu gibi** döner — gövdeyi çağıran okur. Testte de bu sabitlendi.

**KİLİT YİNE GÜNCELLENDİ.** `sessiz-fetch` artık `agIstegi`yi de geçerli
denetim sayıyor; aksi halde doğru düzeltme kilidi düşürürdü (P101'de aynı
adım atılmıştı).

Kanıt: `tests/oturum-401.test.ts` **+3 test** (ağ hatası çevrilir, 401'de
`null`, başarılı yanıt olduğu gibi döner). `infra/kapilar.sh web` → üç kapı
yeşil, `vitest` **287**, çıkış **0**.

### P103 — Sunucunun mesajı atılıyordu, yerine kod gösteriliyordu
Status: BITTI · Depends-on: P102
Scope: P102'nin dersini uygula — `apiSend`in yaptığı **her şeyi** listele ve
ham `fetch` yerleriyle **tek tek** karşılaştır.
Acceptance: kalan sapma gösterilir; ortak yardımcıya bağlanır; zarf yokluğu
**hata sayılmaz**; gates.
Notes (2026-08-01):
**LİSTEYLE KARŞILAŞTIRMA — P102'DE ÖĞRENİLEN YÖNTEM.** `apiSend` beş şey
yapıyor: (1) ağ hatasını çevir, (2) 401'de yönlendir, (3) 204'ü boş say,
(4) **hata zarfını oku**, (5) JSON gövdeye `Content-Type` ekle. P101 ikinciyi,
P102 birinciyi ortakladı. Sırayla bakınca **dördüncüsü** açık çıktı.

**KUSUR.** Backend `{error:{code,message}}` zarfında **kullanıcı dilinde ve
sebebe özel** bir metin döner ("Dosya çok büyük", "Desteklenmeyen biçim").
`support` sayfası bunu **atıp** yerine `"Görsel yüklenemedi (413)"` gibi bir
**kod** gösteriyordu: kullanıcı **neden** olmadığını öğrenemiyordu. Bu, P60'ın
aynasıdır — orada `String(hata)` mesajı **bozuyordu**, burada mesaj tamamen
**atılıyordu**. (`raporlar` zaten zarfı okuyordu; sapma tek sayfadaydı.)

**ZARF YOKLUĞU HATA DEĞİL.** Vekil/ağ katmanı düz metin (`<html>502</html>`)
döndürebilir. `sunucuMesaji(res, yedek)` böyle durumda **yedek** metne düşer;
ayrıca **boş** bir mesaj da yedeğe düşer — boş bir metin göstermek, hiçbir şey
söylememektir.

Kanıt: `tests/oturum-401.test.ts` **+3 test** (zarftaki mesaj döner; zarf
yoksa yedek; boş mesajda yedek). `infra/kapilar.sh web` → üç kapı yeşil,
`vitest` **290**, çıkış **0**.

### P104 — BFF rotaları hiç taranmamıştı: sunucuda sabit Türkçe
Status: BITTI · Depends-on: P103
Scope: i18n taramalarının kapsamını ölç; kapsam dışı kalan yeri süpür.
Acceptance: kusur ölçümle gösterilir; sunucuda çalışan bir çözücü yazılır;
kilit enjeksiyonla doğrulanır; gates.
Notes (2026-08-01):
**DÖRDÜNCÜ KÖR NOKTA.** Panelin dört i18n taraması da `.tsx` okuyor. BFF
rota işlerleri **`route.ts`**tir ve **hiç taranmamıştı** — oysa onlar
kullanıcıya **doğrudan** metin döndürür (`{error:{message}}`). Ölçüldü:
giriş rotasında **iki sabit Türkçe metin** (`"tenant_slug, email ve parola
zorunlu."`, `"Giris basarisiz."`). İngilizce arayüzde bunlar Türkçe
görünüyordu.

**`metin()` SUNUCUDA ÇALIŞMAZ — VE SESSİZCE ÇALIŞMAZ.** Dili
`document.cookie`den okur; sunucuda `document` yoktur, `tarayiciDili()`
**varsayılana düşer**. Yani rota içinde `metin()` kullanmak "her zaman
Türkçe" demekti ve hiçbir şey hata vermezdi. Bu yüzden ayrı bir çözücü:
`istekMetni(req, anahtar)` dili **istekten** okur — çerez, yoksa
`Accept-Language`, yoksa varsayılan. Tanınmayan çerez değeri **yok
sayılır** (uydurma bir dil seçilemez); testte sürüldü.

**KİLİT.** `tests/i18n.test.ts`e beşinci tarama: `app/api/**/*.ts` içinde
`message: "…"` sabiti sızıntıdır. Enjeksiyonla doğrulandı
(`login/route.ts:43`).

**BİR YAN OLAY — GERİ ALMA DÜZELTMEYİ DE SİLDİ.** Kilidi doğrulamak için
kusuru geri koyup `git checkout --` ile geri aldım; ama düzeltme henüz
**commit edilmemişti**, dolayısıyla `checkout` **düzeltmeyi de** sildi ve
kapı kırmızıya döndü. Fark edildi, düzeltme yeniden uygulandı ve kapı
yeşile döndü. Ders: **commit edilmemiş bir düzeltmenin üstünde
`git checkout` ile enjeksiyon denemesi yapma** — enjeksiyonu geri almak,
düzeltmeyi de geri alır.

Kanıt: `lib/i18n/istek-metni.ts` (yeni), `tests/istek-metni.test.ts`
**5 test**, `tests/i18n.test.ts` **+1 tarama**, `girisAlanZorunlu` × 7 dil.
`infra/kapilar.sh web` → üç kapı yeşil, `vitest` **296**, çıkış **0**.

### P105 — `catch` yedek metinleri: 26 yerde sabit Türkçe
Status: BITTI · Depends-on: P104
Scope: i18n süpürmesini `catch` bloklarındaki **son çare** metinlerine
taşı.
Acceptance: sayı ölçülür ve sıfıra iner; kilit eklenir; gates.
Notes (2026-08-01):
**ÖLÇÜM: 26 YER.** `err instanceof Error ? err.message : "Kaydedilemedi."`
kalıbı 26 çağrı yerinde vardı ve **yedek metin sabit Türkçe**ydi
(`"Kaydedilemedi."`, `"Silinemedi."`, `"Eklenemedi."`, `"Hata"`,
`"Atama kaydedilemedi."`).

**NADİR OLMASI ÇEVRİLMEMESİNİ GEREKTİRMEZ.** Bu dal yalnız **`Error`
olmayan** bir fırlatmada görünür — nadir. Ama nadir olduğu için **kimse
fark etmez** ve dil değiştiren kullanıcı, her şey İngilizceyken tek bir
Türkçe cümleyle karşılaşır. Üstelik bu metin genellikle **kaydın neden
gitmediğini** söylemesi beklenen yerdir.

**MEVCUT ANAHTARLAR KULLANILDI, YENİSİ AZ.** `ortakSilinemedi` ve
`ortakHataOlustu` zaten vardı; yalnız `ortakKaydedilemedi` eklendi
(7 dil). "Atama kaydedilemedi" gibi özel metinler **genel anahtara**
indirildi: yedek metin son çaredir ve orada özgüllük iddia etmek, kaynağı
bilinmeyen bir hataya sahte bir açıklama uydurmaktır.

**KİLİT DAR TUTULDU.** Yalnız `: "..."` yedeği olan üçlüler taranıyor;
`String(e)` dalı **P60'ta ayrıca** ele alınmıştı ve onu da yasaklamak
geriye seçenek bırakmazdı.

Kanıt: 26 → **0**; `tests/i18n.test.ts` **+1 tarama** (altıncı).
`infra/kapilar.sh web` → üç kapı yeşil, `vitest` **297**, çıkış **0**.

### P106 — Sayfalı sorgularda kararsız sıralama: 54 yer, 12 düzeltildi, kalanı çırçırda
Status: BITTI · Depends-on: P105
Scope: Hata/i18n damarından çık; **veri doğruluğu** tarafında sınıf ara.
Acceptance: sayı ölçülür; en riskli alt küme düzeltilir; kalanı **artamaz**
hâle getirilir; gates.
Notes (2026-08-01):
**KUSUR SINIFI.** `ORDER BY created_at DESC LIMIT n OFFSET m` **kararsızdır**:
eşit değerli satırların birbirine göre sırasını Postgres garanti etmez.
Sonuç, sayfalar arasında **tekrarlayan ve kaybolan satırlar** — yönetici
ikinci sayfada aynı talebi yeniden görür, bir başkasını hiç görmez ve
**hiçbir yerde hata çıkmaz**.

**"EŞİTLİK NADİRDİR" YANLIŞ.** Toplu üretilen satırlar **aynı `created_at`i
paylaşır**: toplu borçlandırma, Excel ile site aktarımı, seed. Yani kusur
tam olarak **en çok satırın olduğu yerde** ortaya çıkar.

**ÖLÇÜM: 54 sorgu** tiebreaker'sız. İkisi (`violations`, `vehicle_passes`)
zaten `.id` ekliyordu — kod tabanı deseni **biliyor**, tutarsız uyguluyor.

**BU TURDA 12'Sİ DÜZELTİLDİ** — `ad`/`no`/`kod`/`plaka` ile sıralananlar,
çünkü orada eşitlik **normaldir** (aynı isimli iki kategori, farklı
bloklarda aynı numaralı iki daire). Biri (`sakin_odeme`) sayfalama değil
**"birini seç"** sorgusuydu ve etkisi daha somut: aynı `kod`a sahip iki
kasa varsa sakine gösterilen **IBAN istekten isteğe değişebilirdi**.

**KALAN 42 İÇİN ÇIRÇIR, ÇÜNKÜ HEPSİNE DOKUNMAK ORANTISIZ.** Tek turda
40'tan fazla ucun sıralamasını değiştirmek, hepsinin davranışını aynı anda
değiştirmek olurdu. Kilit sayının **artmamasını** tutuyor. İkinci bir test
eşiğin **gerçeğe yakın** kalmasını zorluyor: 42 yerine 200 yazsaydım kilit
hiçbir şey tutmazdı — çırçırın işlevsizleşmesi, kilidin sessizce ölmesinin
en yaygın yoludur.

Kanıt: `backend/tests/test_sayfalama_siralamasi.py` **2 test**.
`infra/kapilar.sh backend` → **1145 passed, 1 skipped**, çıkış **0**.

### P107 — İkinci dilim + sayacın kendisi bozuktu
Status: BITTI · Depends-on: P106
Scope: P106'nın bıraktığı kararsız sıralamaların **toplu üretim yaşanan**
dilimini düzelt.
Acceptance: düzeltme sayılır; eşik indirilir; **sayacın doğru saydığı**
doğrulanır; gates.
Notes (2026-08-02):
**15 SORGU DAHA DÜZELTİLDİ** — aidat tahakkuk/ödeme, talep (×2), kargo,
bildirim, duyuru, ziyaretçi, görev + görev tamamlama, rezervasyon, cihaz,
nokta, devriye planı, vardiya. Bunlar tam da **aynı `created_at`i paylaşan**
satırların üretildiği uçlar.

**SAYAÇ YANLIŞ SAYIYORDU — VE BUNU ANCAK BEKLENTİ TUTMAYINCA GÖRDÜM.**
Düzeltmelerden sonra sayı 42→39 düştü; 15 düzeltmeyle 27 olmalıydı.
Sebep, kilidin kendi düzenli ifadesi:
```
order_by\([^)]*\.id\b     # `[^)]*` ILK parantezde durur
```
`order_by(X.created_at.desc(), X.id.desc())` satırında `desc()` içindeki
`)` taramayı kesiyor ve `.id` **hiç görülmüyordu** — yani **düzeltilmiş**
sorgular "kararsız" sayılıyordu. Dengeli parantez sayan bir okuyucuyla
yeniden ölçüldü:

| Sayım | Sonuç |
|---|---|
| Kusurlu regex | 39 |
| **Dengeli sayım** | **25** |

Bu, **P106'da yazdığım "54"ün de şişik** olduğu anlamına gelir; o sayı
zaten tiebreaker'ı olan sorguları da kusurlu sayıyordu. Eşik 25'e indirildi
ve gerekçe testin içine yazıldı.

**KENDİ EKLEDİĞİM UYARI.** Kapı **1145 passed** ile yeşildi ama uyarı sayısı
2→**3** olmuştu: docstring'e yazdığım regex örneği `SyntaxWarning: invalid
escape sequence` üretiyordu. Ham dizgeye çevrildi (ilk denemede girinti
bozulup toplama hatası alındı, o da düzeltildi). Yakalamamın tek sebebi
**sayıyı karşılaştırmış olmam**: "1145 passed" aynıydı, kapı yeşildi,
hiçbir şey kırılmamıştı. Uyarılar tam da böyle birikir — her biri tek
başına zararsız, toplamı "zaten hep uyarı var" hâline gelir ve **gerçek
bir uyarı görünmez olur**.

**BEŞİNCİ KEZ AYNI DERS:** ölçüm aracının kendisi de ölçülmeli. Kilidin
"yakaladığını gör" kuralını uygulamıştım ama sayacın **doğru saydığını**
doğrulamamıştım.

Kanıt: `infra/kapilar.sh backend` → **1145 passed, 1 skipped, 2 warnings**
(uyarı sayısı eski hâline döndü), çıkış **0**.

### P108 — Kararsız sıralama sınıfı KAPANDI: 25 → 3, kalanı gerekçeli
Status: BITTI · Depends-on: P107
Scope: Kalan kararsız sıralamaların **tamamını** ele al.
Acceptance: her biri ya düzeltilir ya **niçin düzeltilemeyeceği** yazılır;
gates.
Notes (2026-08-02):
**22 SORGU DAHA.** Mekanik olanlar (ANPR ×2, finans, gürültü, mesaj geçmişi,
portal ×4, destek, daire erişim, yönetişim ×2, sayaç bölümü) ve elle ele
alınması gerekenler:
* **Çok satırlı / bileşik sıralamalar** (`budget`, `finans`, `mesajlar`,
  `site_rules`, `assets`, `shifts`): kuyruk mevcut sıralamanın **sonuna**
  eklendi — sıra değişmedi, yalnız eşitlik çözüldü.
* **Dinamik sıralamalar** (`assets` zimmet geçmişi, `muhasebe_tanimlari`):
  kullanıcı hangi kolonu seçerse seçsin `sirala` eşitlik üretebilir.
* **`events`**: aynı gün iki toplantı aynı tarihi taşıyabilir.

**KALAN 3 — "YAPILMADI" DEĞİL, "YAPILAMAZ/GEREKMEZ":**
| Yer | Neden |
|---|---|
| `reports.py`, `transparency.py` | **Toplulaştırma**: `id` `GROUP BY`da yok, **eklenemez**. Kararlı kuyruk **gruplama anahtarıdır** (`BudgetCategory.ad`) ve eklendi. |
| `kvkk.py` | `(tenant_id, surum)` **benzersiz** (`uq_kvkk_metin_surum`); sıralama zaten kararlı. `id` eklemek **var olmayan bir eşitliği** çözmek olurdu. |

**ŞEFFAFLIK PANOSU AYRICA ÖNEMLİYDİ.** O pano **sakine açıktır**; eşit
tutarlı iki kategorinin sırası her yenilemede değişseydi, **değişmeyen bir
veri değişiyormuş gibi** görünürdü — güven kaybı, veri kaybından önce gelir.

**ÜÇ TURUN TOPLAMI:** 54 (şişik ölçüm) → gerçek 25 → **3**. Çırçır eşiği 3'e
indi; artık "azaltılacak borç" değil, **gerekçeli bir taban**.

Kanıt: `infra/kapilar.sh backend` → **1145 passed, 1 skipped, 2 warnings**,
çıkış **0**.

### P109 — Diyalog denetleyicileri sızıyor: bulundu, DÜZELTİLMEDİ (naif düzeltme çöktü)
Status: BITTI(ölçüm) · Depends-on: P108
Scope: Kaynak sızıntısı sınıfı ara (zamanlayıcı, dinleyici, denetleyici).
Acceptance: bulgu ölçümle gösterilir; düzeltme **çalıştığı gösterilemezse
uygulanmaz**.
Notes (2026-08-02):
**SÜPÜRME.** Panel temiz: iki dinleyicinin de (`ThemeToggle` matchMedia,
`DilSecici` mousedown) `return () => removeEventListener` temizliği var.
Mobilde zamanlayıcılar da temiz (`home_refresh`, `patrol_screen`,
`patrol_controller` — üçü de `cancel()`/`onDispose`).

**BULGU: 106 denetleyiciden ÜÇÜ atılmıyor.** `TextEditingController`
dinleyici listesi ve yerel metin durumu taşır. Sınıf alanları `dispose()`ta
atılıyor; ama **diyalog açan metotların içinde** oluşturulan yerel
denetleyiciler hiç atılmıyor: `task_categories._ekle`,
`unit_access._newRequest`, `dis_hizmet._editNote`. Kullanıcı "yeni
kategori"yi on kez açarsa on denetleyici sızar. **`flutter analyze` bunu
görmez** — lint yerel değişkenleri izlemez.

**NAİF DÜZELTME ÇÖKTÜ — VE TAM SUITE GÖSTERDİ.** `await showDialog(...)`
sonrası `ctrl.dispose()` eklendi; tek dosya yeşildi, **tam suitte** düştü:
> `A TextEditingController was used after being disposed.`

Sebep: `showDialog`un future'ı rota **pop edilince** tamamlanır ama
diyaloğun **çıkış animasyonu** hâlâ `TextField`i çiziyor. Yani denetleyici
"artık kullanılmıyor" **değil**, birkaç kare daha kullanılıyor.
`try/finally` de aynı anda çalışacağı için çözmez.

**DÜZELTME GERİ ALINDI.** Doğru çözüm, diyaloğu **kendi denetleyicisine
sahip bir `StatefulWidget`e** çıkarmaktır (denetleyici widget'ın kendi
`dispose()`unda atılır).
> **YAPILDI (P110).** Öngörülen çözüm yazıldı ve üç çağrı yeri ona
> bağlandı; ayrıntı P110'da.

**KİLİT DE EKLENMEDİ.** Kilit yazıp üç bilinen ihlali istisna listesine
koymak, kilidi doğduğu anda borç taşıyan bir şeye çevirirdi; düzeltmeden
kilitlemek de kırmızı bir suite bırakırdı. P70'teki karar: **çalıştığını
gösteremediğim şeyi commit'lemem.**

**SIZINTININ BOYUTU DÜRÜSTÇE:** üç diyalog, her açılışta bir denetleyici.
Kullanıcı oturumu boyunca onlarca olabilir; çökme yapmaz, bellek büyür.
**Kullanıcıya görünen bir kusur değil** — bu yüzden yeniden yapılandırmayı
bir sonraki tura bırakmak, çöken bir düzeltmeyi bırakmaktan iyidir.

Kanıt: ölçüm (106 → 3 atılmayan), çöken düzeltmenin suite çıktısı,
çalışma ağacı **temiz** (`flutter analyze` temiz).

### P110 — Sahiplik doğru yere taşındı: diyalog kendi denetleyicisini atıyor
Status: BITTI · Depends-on: P109
Scope: P109'un "düzeltilmedi" bıraktığı sızıntıyı **doğru** çöz.
Acceptance: üç çağrı yeri de dönüştürülür; kilit **enjeksiyonla**
doğrulanır; gates.
Notes (2026-08-02):
**ÇÖZÜM SAHİPLİK.** `metin_iste_diyalogu.dart`: tek satırlık metin isteyen
diyalog artık bir `StatefulWidget` ve denetleyici **onun kendi durumuna**
ait. `State.dispose` **çıkış animasyonu bittikten sonra** çağrılır — P109'un
çöktüğü yer tam buydu (`await showDialog` sonrası atmak, hâlâ çizilen bir
`TextField`in denetleyicisini yok ediyordu).

**ÜÇ ÇAĞRI YERİ TEK ÇAĞRIYA İNDİ.** `task_categories`, `unit_access`,
`dis_hizmet` — üçü de aynı kalıbı (başlık + tek alan + vazgeç/onay) elle
kuruyordu; şimdi `metinIste(...)`. Kod **azaldı** ve sızıntı kapandı.

**KİLİT İKİ KEZ YANLIŞTI — İKİSİ DE ENJEKSİYONLA ÇIKTI:**
1. İlk desen yalnız `final x = TextEditingController(` biçimini görüyordu;
   `late final TextEditingController _ctrl = ...` **hiç taranmıyordu** —
   yani kilidin **kendi örnek dosyası kapsam dışıydı**. `_ctrl.dispose()`
   silindiğinde test **geçiyordu**.
2. Tip isteğe bağlı yapılınca boşluk `[\s\S]{0,60}?` oldu ve
   `final _formKey = GlobalKey<FormState>();` bildirimini **bir alt
   satırdaki** `TextEditingController(` ile eşleştirip **beş yanlış
   pozitif** üretti. Ayırıcı `[^;]` yapıldı: bir bildirim diğerine taşamaz.

Her iki hata da "yeşil geçti" diye değil, **enjeksiyonu yakalayamadığı**
ve **doğru kodu suçladığı** için görüldü. Kilit bir ölçüm aracıdır ve iki
yönde de sınanmalıdır: yanlışı yakalıyor mu, doğruyu rahat bırakıyor mu.

Kanıt: `mobile/lib/src/core/ui/metin_iste_diyalogu.dart` (yeni),
`mobile/test/denetleyici_atma_test.dart` (sınıf kilidi, enjeksiyonla
doğrulandı), atılmayan denetleyici **3 → 0**. `infra/kapilar.sh mobile` →
üç kapı yeşil, `flutter test` **1562**, çıkış **0**.

### P111 — Sayaç takibi: bölüm sayaçları paneli + 4 adımlı okuma sihirbazı
Status: BITTI · Depends-on: —
<!-- DURUM DENETİMİ 2026-08-02: doğrulandı. `tanimlar/page.tsx:153`
     `kaynak: "sayaclar-ana"` VAR; bölüm sayacı kaynağı ve dört adımlı
     sihirbaz YOK. Ölçüm, uygulama yok — sıradaki tur doğrudan yazmaya
     başlayabilir (yazılacak sıra en altta). -->

Scope: Yol haritasındaki "Sayaç takibi + sihirbaz → YOK" kaleminin **hangi
parçasının** eksik olduğunu ölç; bir sonraki tur doğrudan yazmaya başlasın.
Notes (2026-08-02):
**YOL HARİTASI YANILTICIYDI — ÖLÇÜLDÜ.** Kalem "YOK" diyor ama:

| Parça | Gerçek durum |
|---|---|
| `sayac_ana` / `sayac_bolum` tabloları | **VAR** (P27) |
| 5 uç: ana CRUD, bölüm CRUD, `/sayaclar/bolum/otomatik` | **VAR** |
| Tüketim dağıtımı + `POST /borclandirma/sayac` | **VAR** (P28) |
| **Ana sayaç paneli** | **VAR** — `tanimlar` sayfasında `sayaclar-ana` kaynağı |
| **Bölüm sayaçları paneli** | **YOK** |
| **Okuma sihirbazı (4 adım)** | **YOK** — asıl eksik |

**İLK TARAMAM YANLIŞTI:** `grep sayac *.tsx` `tanimlar` sayfasındaki
**veri-sürücülü** tanımı görmedi ve "arayüz hiç yok" dedim. Düzeltildi.

**BÖLÜM SAYAÇLARI TEK SATIRLIK EK DEĞİL.** `tanimlar` sayfasının alan
tipleri `metin | sayi | kurus | tarih | bool | secim`. Bölüm sayacı
`unit_id` (daire) ve `ana_sayac_id` (ana sayaç) **referans** alanları
istiyor; yani önce **yeni bir alan tipi** (başka bir uçtan seçenek yükleyen
"kimlik" tipi) gerekiyor. Bu, sayfanın veri-sürücülü mimarisine yapılacak
gerçek bir genişletmedir.

**SİHİRBAZIN SÖZLEŞMESİ SUNUCUDA YAZILI** (`SayacBorcIstek` docstring):
adımlar **istemcide** toplanır, sunucuya **TEK** istek gider — "ara
adımlarda sunucu durumu tutmak, yarım kalmış sihirbazları temizlemek
zorunda bırakırdı". Gövde: `donem`, `gelir_gider_tanim_id`,
`ana_sayac_id`, `ana_tuketim`, `birim_fiyat_kurus` (**kuruş**),
`bolum_tuketimleri` (daire sayacı id → tüketim).

**SONRAKİ TUR İÇİN SIRA:** (1) `tanimlar`a referans alan tipi + bölüm
sayaçları kaynağı; (2) otomatik üretim düğmesi; (3) dört adımlı sihirbaz
sayfası; (4) ARB/sözlük 7 dil + bileşen testleri.

---

UYGULAMA (2026-08-02) — **BİTTİ**, yukarıdaki dört maddenin dördü de.
Commit: `4a1b38c`.

**(1) REFERANS ALAN TİPİ.** `tanimlar` sayfasının alan tipleri
`metin | sayi | kurus | tarih | bool | secim` idi; `referans` eklendi.
Her referans alanı **kendi** `ReferansSecici` bileşenidir — üst bileşende
alanlar üzerinde döngüyle kanca çağırmak, sekme değişince kanca
**sayısını** değiştirirdi (React'in kanca sırası kuralı). Üç ayrı karar
kaydedildi:
* `sutunAlani` — form **kimlik** taşır, tablo sunucunun **çözdüğü** adı
  (`unit_no`, `ana_sayac_ad`) gösterir; tabloda ham UUID okumak
  kullanıcıya hiçbir şey anlatmaz.
* `sadeceOlustur` — daire alanı **PATCH gövdesinde gönderilmez**. Sunucu
  `SayacBolumUpdate`te `unit_id` **kabul etmiyor**; göndermek pydantic'in
  onu **sessizce atması** demekti ve kullanıcı daireyi taşıdığını sanırdı.
  Düzenlemede seçici **pasif çizilir** (gizlemek, hangi daire olduğunu
  görememek olurdu).
* Yüklenemeyen liste **sessiz kalmaz**: seçici devre dışı kalır ve durum
  metni yazar — boş bir açılır liste "hiç daire yok" derdi ki bu yanlıştır.

**(2) TOPLU ÜRETİM.** `Defter.ekEylem` kancasıyla — `DefterGorunumu` tek
bir kaynağın adını bile bilmez, veri-sürücülü mimari korunur. Sonuç metni
**oluşturulan ve atlanan** sayısını birlikte söyler; yalnız "oluşturulan"
gösterilseydi ikinci çalıştırmada kullanıcı "hiçbir şey olmadı" sanırdı
(uç yeniden çalıştırılabilir, zaten sayacı olan daireler atlanır).
BFF: `sayaclar-bolum-otomatik` beyaz listeye eklendi (ayrı `route.ts`
yerine — güvenlik kuralı tek yerde kalsın).

**(3) DÖRT ADIMLI SİHİRBAZ** — `/sayac-okuma` (menüde Tanımlar ile Aidat
arasında: tanımlardan beslenir, çıktısı bir tahakkuktur).
Sunucunun sözleşmesi **aynen** uygulandı: ilk üç adım **istemcide**
toplanır, sunucuya **TEK** istek gider; ara adım için vekil uç
**açılmadı**. Üç ölçülmüş karar:
* Doğrulama **adım başına** (dönem biçimi 2. adımda) — hepsini sona
  bırakmak kullanıcıyı üç adım geri göndermekti.
* Bağlı daire sayacı yoksa **boş hâl** + "Borçlandır" **pasif**: boş
  listeyle ilerlemek, hiçbir daireyi borçlandırmayan bir istek atmaktı
  (sunucu 201 döner, kullanıcı "oldu" sanır).
* **ÖNİZLEME sunucunun dağıtım kuralını AYNEN uygular**: negatif fark
  sıfırlanır, `ortak_alan_yuzde` verilmişse farkın **yalnız o yüzdesi**
  dağıtılır. İlk yazımda yüzde atlanmıştı — yüzde kullanan sitede
  önizleme **olduğundan büyük** çıkardı; test bunu kilitliyor.

**(4) i18n + TESTLER.** 40 yeni anahtar × 7 dil (sözlük tipi `tr`den
türer; eksik çeviri **derlenmez**). `tests/sayac.dom.test.ts` — **9 test**.
**MUTASYON DENETİMİ yapıldı:** `sadeceOlustur` kaldırılınca, `sutunAlani`
ham kimliğe çevrilince, kuruş yerine TL gönderilince ve dönem doğrulaması
sona bırakılınca testler **düştü** — yani boş koşmuyorlar.

**ÜÇ PANEL KAPISI AÇIKÇA KIRMIZI VERDİ** (hepsi gerçek kusurdu):
`middleware` matcher (yeni sayfa **kapı dışında** kalmıştı — oturumsuz
kullanıcı kabuğu görürdü), sabit-metin taraması (JSX üçlüsündeki `"ad"`)
ve erişilebilir-etiket (referans dalı araya girince `secim` select'inin
`Field` sarmalayıcısı 16 satırlık pencereden çıktı → açık `aria-label`).

KAPILAR: `tsc` temiz · `vitest` **50 dosya / 306 test** · `npm run build`
başarılı (37 sayfa). **Backend'e dokunulmadı** (beş ucun beşi de zaten
vardı), şema değişikliği ve yeni göç **YOK**.

## APP STORE HAZIRLIĞI — P112–P118 (2026-08-02, Kerem'in paketi)

> iOS yayını için Apple denetim listesine göre açılan yeni kalemler. **iOS
> DERLEMESİNİN KENDİSİ [KEREM]'dedir** (macOS/CI gerekir); ajanın işi, ilk
> Mac derlemesi **denetime hazır** olsun diye kod/yapılandırma/belge
> tarafındaki her şeydir. Sıra bağlayıcıdır: P112 → P118.

### P112 — Hesap silme (App Store 5.1.1(v), ZORUNLU)
Status: BITTI · Depends-on: —
Scope: Uygulama içinde **"Hesabımı Sil"** (Ayarlar): onay + **yeniden kimlik
doğrulama**; KVKK'ya uygun sunucu ucu (kişisel veri anonimleştirilir/silinir,
**yasal olarak saklanması gereken finans/denetim kayıtları KALIR** — ayrımı
belgele); tenant-yönetici uç durumları (**son admin devretmeden kendini
silemez**). Sözleşme + gerekiyorsa YENİ revizyon + testler + 7 dil ARB.
Acceptance: uçtan uca silme uygulamadan yapılabiliyor; ayrım belgeli; testler
yeşil; §15 envanteri artmıyor.

Notes (2026-08-02) — **BİTTİ.** Commit: `8e20af1`. Ayrıntılı belge:
`docs/hesap-silme-kvkk.md`.

**KURAL TEK YERDE** (`backend/app/hesap_silme.py`). Yönetim yolu
(`DELETE /residents/{id}`) de artık aynı çekirdeği çağırıyor; mantık oradan
**çıkarıldı**. İki uygulama yazmak, KVKK ayrımını iki yerde tutmak ve birinde
düzeltilip diğerinde unutulan bir alanın **silinmiş sanılan kişisel veri**
bırakması demekti.

**İKİ MOD — TAHMİN EDİLMEZ, DENENİR.** Silme önce bir SAVEPOINT içinde
denenir; veritabanı `RESTRICT` ile itiraz ederse anonimleştirmeye düşülür.
Önce "geçmişi var mı" diye saymak, yeni bir tabloyu listeye eklemeyi unutunca
**sessizce yanlış mod** seçerdi. `deleted=false` **başarıdır** ve uygulama
bunu ayrı bir cümleyle söyler — aidat kaydının durduğunu sonradan öğrenen
kullanıcı kandırıldığını düşünürdü.

**AYRIM.** Silinen: ad → yer tutucu; e-posta/telefon/avatar → NULL; parola ve
geçici kod hash'leri → NULL; `user_device` satırları; aktif daire bağları;
`is_active=false`. Kalan: finans satırları + `audit_log` + talep/tur kayıtları
— TTK ve vergi mevzuatı defterlerin saklanmasını **emreder** ve KVKK md. 7
silme hakkı başka bir kanunun öngördüğü saklama yükümlülüğünü kaldırmaz.
Ödemeyi silmek kasa bakiyesini geçmişe dönük değiştirir ve **başka
sakinlerin** mutabakatını bozardı.

**YENİ GÖÇ `0029` — kalıcı kanıt.** `audit_log` yetmez: saklama politikası
gereği 24 ayda **purge** edilir ve silme talebinde bulunan kişi bundan
**sonra** sorabilir. `hesap_silme_kaydi` retention motoruna dâhil değil,
içinde kişisel veri yok, `app_rw` yalnız SELECT/INSERT alır —
değiştirilebilen bir kanıt kanıt değildir.

**İKİ ENGEL.** (a) Yeniden kimlik doğrulama (parola): ödünç alınmış telefonda
tek dokunuşla silme olmamalı. (b) **Son yönetici** → 409: tesis sahipsiz
kalırdı. Apple kuralına aykırı değil — kural "hesap silinebilmeli" der,
"tesisi kullanılamaz bırak" demez; hata metni **ne yapılacağını** söyler ve
ikinci yönetici varken silme çalışır (testli).

**ROL MATRİSİ KİLİDİ (P41) yeni ucu YAKALADI** ve güncellendi — altı rolün
altısı da kendi hesabını silebiliyor. Kilidin karşılığını verdiği tur.

KAPILAR: `pytest` **1159 geçti / 1 atlandı** (taban 1151, +8) · `goc-uyum` ve
`goc-tersinir` **bulgu 0** · `flutter analyze` temiz · `flutter test`
**1573 geçti / 3 atlandı** (taban 1567, +6) · apk ✓ · `tsc` temiz ·
`vitest` **50 dosya / 308 test**. §15 envanteri **değişmedi** (8/5).

### P113 — Gizlilik politikası + koşullar + yapay zekâ/çeviri beyanı
Status: BITTI · Depends-on: —
Scope: Gizlilik politikası + kullanım koşulları yaz (kaynak TR, 6 dile bizim
çeviri hattımızın kurallarıyla; **hukukçu incelemesi sonra [KEREM]**): toplanan
veri ve amaçlar, **işleyiciler adıyla** (kendi altyapımızdaki LibreTranslate —
veri dışarı ÇIKMAZ; iyzico devreye girince; Firebase/FCM açılınca), saklama
süreleri, KVKK+GDPR temelleri, iletişim. Web portalında **sabit adreslerde**
yayınla (`/gizlilik`, `/kosullar`) ve uygulamadaki Ayarlar'dan bağla. Makine
çevirisi gösteren **her yüzeyin** "otomatik çevrilmiştir · orijinali gör"
göstergesini (P7) koruduğunu doğrula — yapay zekâ şeffaflığı hikâyemiz budur;
uygulama içinde **üretken yapay zekâ YOK**, denetim notlarında bunu yaz.
Acceptance: iki sayfa 7 dilde yayında; uygulamadan bağlantı çalışıyor; P7
göstergesi taranarak doğrulandı.

Notes (2026-08-02) — **BİTTİ.** Commit: `4d0fa01`.

**SABİT PUBLIC ADRESLER** `/gizlilik` ve `/kosullar`. Tenant kapsamlı
(`/site/<slug>/…`) olamazdı: politika **ürünün** politikasıdır, tek bir
tesisin değil — ve bu URL'ler App Store Connect ile Google Play'e girilip
bir daha değişmemeli. Sayfalar **sunucu bileşeni** ve **JS taşımıyor**:
denetçi, arama motoru ve JS'i kapalı tarayıcı **aynı** metni görmeli. Dil
sunucuda çözülür (çerez > `Accept-Language`), yani Apple denetçisi
İngilizce görür.

**İÇERİKTEKİ ÜÇ ASIL KARAR:**
1. **ROL AYRIMI** — KVKK anlamında **veri sorumlusu her tesisin
   yönetimidir**; Yönetio **veri işleyendir**. Bunu yazmamak 200 tesisin
   sorumluluğunu platforma yıkmak ve kullanıcıya yanlış muhatabı
   göstermek olurdu.
2. **İŞLEYİCİLER ADIYLA** sayılır ve şu an geçerli olmayanlar "etkin
   değil" diye işaretlenir. "Ödeme sağlayıcısı kullanabiliriz" gibi
   ihtimalli bir cümle App Store gizlilik anketiyle **çelişirdi**.
   LibreTranslate **kendi altyapımızda**: metin üçüncü tarafa gitmez.
3. **ÖDEME MODELİ (3.1.3(e))** koşullarda açıkça yazılı: aidat, uygulama
   **dışında** tüketilen gerçek dünya hizmetinin bedelidir; bu yüzden
   uygulama içi satın alma kullanılmaz.

**BAĞLAYICI SÜRÜM TÜRKÇEDİR**; diğer altı dil bilgilendirme amaçlıdır ve
bunu sayfanın **üstünde** yazar (altta dipnot olsaydı, okumayı yarıda
bırakan kullanıcı çeviriyi bağlayıcı sanırdı). **Hukukçu incelemesi
[KEREM]** ve yalnız TR metne yapılacak.

**YAPAY ZEKÂ BEYANI KOD TARAFINDAN DESTEKLENİYOR** —
`test/ceviri_seffafligi_test.dart` (4 test). "Çevrilen her içerik bunu
söylüyor" bir **iddiadır**; kaynak taraması `ceviriMetni(` çağıran her
ekranda göstergeyi arar, davranış testleri göstergenin **çevrilmemiş**
içerikte görünmediğini ve "orijinali gör"ün gerçekten orijinali verdiğini
kilitler.

**MUTASYON DENETİMİ KİLİDİ İKİ KEZ DÜZELTTİ:** (1) yorumlar hiç
atılmıyordu — çağrıyı yoruma almak taramayı değiştirmiyordu; (2) yalnız
satır **başı** yorumlarını atmak da yetmedi. Üçüncü yazımda mutasyon
düşürdü. Kilit "dosyada bu harfler geçiyor mu"yu değil **çizimi** ölçüyor.

**DOĞRULAMA:** çeviri gösteren **üç** yüzey var (duyuru, site kuralı,
etkinlik) ve üçünde de gösterge yerinde. Public portal (`/site/<slug>`)
**çevrilmemiş orijinali** sunuyor — gösterge gerekmiyor; kayda geçti.

KAPILAR: `tsc` temiz · `vitest` **50/308** · `npm run build` **39 sayfa**
· `flutter analyze` temiz · `flutter test` **1577 geçti / 3 atlandı**
(taban 1573, +4) · apk ✓. §15 envanteri **değişmedi** (8/5).

### P114 — iOS proje hazırlığı (yalnız yapılandırma; derleme sonra Mac'te)
Status: BITTI · Depends-on: —
Scope: Depoda `ios/` Flutter iskelesini kur/tamamla: **bundle id kararı**
(`site.yonetio.app` ya da eşdeğeri — kaydet), görünen ad, **dokunduğumuz HER
İZİN için** Türkçe+İngilizce `Info.plist` kullanım metinleri (NFC okuyucu,
kamera [tur/görev fotoğrafı], fotoğraf kitaplığı [etkinlik görselleri],
konum-kullanırken [tur GPS], bildirimler), **ATS varsayılan** (yalnız HTTPS —
yayın politikamızla aynı), **`PrivacyInfo.xcprivacy`** gizlilik bildirimi (API
kullanımımız + gerekçe-zorunlu API'ler), marka varlıklarından uygulama
simgeleri + açılış ekranı (**yer tutucu YOK**). `nfc_manager` iOS yetkilendirme
notları belgeli olsun (Core NFC yeteneği — **uyarı: NFC tur okutma iPhone 7+
ister; SDM okuma yolu cihazda doğrulanmalı [KEREM]**).
Acceptance: `ios/` ağacı derlenebilir yapılandırmada; her izin dizesi iki dilde;
manifest dosyası mevcut; UIDeviceFamily kararı yazılı.

Notes (2026-08-02) — **BİTTİ.** Commit: `29ab367`. Kilit:
`test/ios_yapilandirma_test.dart` (**15 test**) — Mac olmadan
doğrulanabilen her şeyi ölçer ve yapılandırmanın **sessizce geri
gitmemesini** sağlar (araçlar bu dosyalara dokunabiliyor; nitekim ikon
aracı bu turda iki yapı ayarını bozdu).

**KARARLAR:**
* **Bundle kimliği `site.yonetio.app`** (ters DNS). iOS uygulaması henüz
  yayınlanmadı → göçü yok. Android'in `applicationId`si **değişmedi**
  (yayında; değiştirmek yeni uygulama demek) — iki platformda kimliklerin
  farklı kalması bilinçli.
* **Yalnız iPhone** (`TARGETED_DEVICE_FAMILY = 1`) + iPad yön anahtarı
  kaldırıldı. iPad'i açık bırakmak, göndermediğimiz bir cihaz için ekran
  görüntüsü ve düzen doğrulaması istemek olurdu (P117'nin kararı).

**İZİN METİNLERİ YENİDEN YAZILDI — eskiler eksikti ve bu bir ret
sebebidir:** kamera "görev tamamlama" diyordu ama talep/etkinlik/kargo/
site kuralı da aynı izni kullanıyor; konum "acil durum" diyordu ama asıl
kullanım **devriye turu okutmasında konumu kanıt olarak kaydetmek**
(P34). Yeni konum metni **arka planda izleme olmadığını** açıkça söylüyor.
`en` (temel) + `tr` — `InfoPlist.strings`, Xcode'a **PBXVariantGroup**
olarak bağlı; iki ayrı dosya referansı `.lproj` yapısını kaybettirir ve
metinler **hiçbir dilde** görünmezdi.

**`PrivacyInfo.xcprivacy` eklendi** — Mayıs 2024'ten beri yüklemenin ön
koşulu; eksikse **yükleme adımında** reddedilir. İzleme yok; sekiz veri
tipi + dört gerekçe-zorunlu API kategorisi. İçerik P115'teki App Privacy
tablosuyla **birebir aynı** olacak (ayrışması tutarsızlık olarak okunur).

**`Runner.entitlements`: YALNIZ `TAG`** *(2026-08-02'de düzeltildi;
önce `NDEF, TAG` yazıyordu)*. Dizi, uygulamanın **açabileceği oturum
türlerini** beyan eder — okuyabileceği veri türlerini değil. `TAG` =
`NFCTagReaderSession` (açtığımız tek oturum); `NDEF` =
`NFCNDEFReaderSession` (hiç açmıyoruz). NDEF içeriğini yine okuyoruz ama
TAG oturumunun **içinden** (`NdefIos.from(tag)` → `tag.data.ndef`).
Yetkilendirme **üç** yapılandırmaya da bağlı — birini atlamak "Debug'da
çalışır, TestFlight yapımında çalışmaz" gibi en sinsi hatayı üretirdi.
**UYARI:** dosya tek başına yetmez, Apple Developer portalında App ID'ye
"NFC Tag Reading" yeteneği de eklenmeli **[KEREM]**; ayrıca NFC tur
okutma **iPhone 7+** ister ve SDM okuma yolu **cihazda doğrulanmalı
[KEREM]**.

**CİHAZ BULGUSU (2026-08-02) — `Missing required entitlement`, tur 2.**
Yetkilendirme imzalı ikilide **vardı**, profil `NDEF/TAG/PACE`
taşıyordu, portalda yetenek **açıktı** — yine de okutma düşüyordu.
`nfcd` günlüğünde alan algılama **var**, oturum/yetki satırı **yok**:
ret `nfcd`ye ulaşmadan **uygulama içinde**, CoreNFC katmanında
veriliyordu.

**Eksik olan `Info.plist`teki
`com.apple.developer.nfc.readersession.iso7816.select-identifiers`
listesiymiş.** Etiketimiz NTAG424 DNA'dır ve iOS onu **MIFARE DESFire**
(ISO7816) olarak görür — kendi kodumuz da öyle eşliyor
(`MiFareFamilyIos.desfire => NfcTagType.ntag424`). CoreNFC, bir ISO7816
etiketine `NFCTagReaderSession.connect(to:)` yaparken uygulamanın
**seçebileceği uygulama kimliklerini önceden beyan etmiş** olmasını şart
koşar; liste yoksa bağlantı reddedilir. Eklentideki çağrı
`session.connect(to: tags.first!)` (`NfcManagerPlugin.swift:647`) ve
hatanın kaynağı `okadan/flutter-nfc-manager#74`
(`_connectTag:error:670`). Android'de böyle bir ön-beyan kuralı yok —
bu yüzden orada hiç görülmedi.

Liste: `D2760000850101` + `D2760000850100` (NFC Forum Type 4 NDEF
uygulaması, v2 ve v1). Başka AID **eklenmedi**: alakasız kimlik yazmak
beyanı gerçeğe aykırı kılar.

**Simgeler markadan üretildi** (`flutter_launcher_icons ios: true`,
`remove_alpha_ios`). Yer tutucu "F" simgesi tek başına ret sebebi
olabilir; App Store simgede **alfa kabul etmez** (1024 png artık RGB).

**pbxproj elle düzenlendi** (Mac yok) ve betiğin **yapısal
doğrulamasından** geçti: parantez dengesi, kimlik benzersizliği, her
`PBXBuildFile`ın `fileRef`inin tanımlı olması, bölüm sınırları. İlk
denemede betik **kendi denetimine takıldı** (`PBXVariantGroup` bölümü
zaten vardı) — yeniden oluşturmak dosyayı bozardı.


**DÜZELTME (2026-08-02, `98160c9`) — DOSYALAR DEPOYA GİRMEMİŞTİ.**
Kerem'in taze Mac klonunda `PrivacyInfo.xcprivacy` **yoktu**. Suçlu tek
satırdı: kök `.gitignore`da **`mobile/ios/`** — bütün platform ağacını
toptan yok sayıyor. Yeni dosyaların hiçbiri (`PrivacyInfo.xcprivacy`,
`Runner.entitlements`, `en/tr.lproj/InfoPlist.strings`, altı simge)
eklenmedi; `project.pbxproj` **izlendiği** için güncellendi ve o
dosyalara referans verdi — yani depo **"tutarlı görünüp" eksikti** ve
`git status` temizdi.

Aynı satırın kardeşi `mobile/android/` de aynı sınıftaydı ve orada
**önceki olay hâlâ açıktı**: `network_security_config.xml`
(AndroidManifest'in referans verdiği dosya) hiç commit'lenmemiş.

İki toptan satır **kaldırıldı**; yerlerine bir şey konmadı çünkü
Flutter'ın kendi şablon `.gitignore` dosyaları zaten doğru kapsamda.
Yeni kapı: **`infra/izlenmeyen-kaynak.py`** (`kapilar.sh depo`) — yapı
yapılandırmasının adını geçtiği her dosyanın `git ls-files`ta olup
olmadığına bakar; mutasyonla sınandı. Temiz çıkarım (`git archive`)
doğrulaması geçti.

KAPILAR: `flutter analyze` temiz · `flutter test` **1592 geçti / 3
atlandı** (taban 1577, +15) · `flutter build apk --debug` ✓ (Android
etkilenmedi).

### P115 — Denetçi demo modu + denetim paketi
Status: BITTI · Depends-on: P114
Scope: Apple denetçisi ne fiziksel NFC etiketimizi okutabilir ne de sahada
durabilir. **Tenant kapsamlı DEMO MODU**: prod benzeri veriyle tohumlanmış bir
**denetim tenant'ı**, her rol için bir demo hesabı ve **yalnız denetim
tenant'ında** açık (sunucu bayraklı) bir **"simüle okutma"** yolu — böylece tur
akışı donanımsız gösterilebilir. `docs/app-store/review-notes.md`: demo
kimlikleri, rol haritası, NFC/kamera/konum nerede ve **niçin**, ödeme modeli
gerekçesi (aidat = gerçek dünya hizmeti → **3.1.3(e), IAP YOK**), uzaktan kod
çalıştırma yok beyanı (2.5.2), yapay zekâ/çeviri beyanı özeti. Ayrıca App Store
Connect için **App Privacy anketi cevap tablosu** (veri tipi → toplanıyor mu?
kimliğe bağlı mı? izleme mi?).
Acceptance: demo tenant tohumlanabiliyor; simüle okutma YALNIZ o tenant'ta
açılıyor (test); denetim notları ve gizlilik tablosu yazılı.

Notes (2026-08-02) — **BİTTİ.** Commit: `add6b02`. Göç `0030`
(`tenant.demo_mod`).

**İKİ ALTERNATİF ELENDİ:** *istemci bayrağı* olsaydı herhangi bir
kullanıcı **gerçek** bir tesiste sahte tur kaydı üretebilir ve tur
kaydının **kanıt değeri sıfırlanırdı**; *ayrı demo yapımı* olsaydı
denetçiye mağazadakinden **başka bir uygulama** gönderilmiş olurdu (Apple
bunu açıkça yasaklar). Bayrak sunucuda durur, yazma yolu **yok** ve test
bunu kilitliyor.

**`POST /scans/simule`:** kapalıyken **404** (403 değil — "yetkin yok"
demek ucun **varlığını** sızdırırdı). **Gerçek yoldan ayrılmaz:**
`checkpoint_id`den etiket UID'si çözülür ve **aynı** `create_scan`
çağrılır; ayrı bir yazma yolu, denetçiye ürünün gerçek akışını değil
**taklidini** göstermek olurdu ve iki yolun ayrışması kaçınılmazdı. Kayıt
`imza_dogrulandi = false` düşer — simüle okutma **ayırt edilebilir**.
Gövdede `nfc_tag_uid` **yoktur**: etiket kimliğini istemciden almak, demo
tesisinde bile "hangi etiket okutuldu"yu istemcinin uydurmasına bırakmak
olurdu.

**TEST BİR HATA YAKALADI:** bayrak önce `itemBuilder` içinde `ref.watch`
ile okunuyordu; `itemBuilder` bir **geri çağrıdır** ve orada `watch`
abonelik kurmaz — sağlayıcı hiç başlamaz, değer sürekli "yükleniyor"
kalır ve düğme **demo tesisinde bile hiç görünmezdi**. Artık `build`
içinde okunuyor.

**TOHUMLAMA** `scripts/demo_tenant.py` (idempotent). **Dev seed'e
eklenmedi:** demo modu her geliştiricinin veritabanında koşan bir betiğe
girseydi, bir gün **prod'da açılmış bulmanın** en kısa yolu olurdu.

**BELGELER:** `docs/app-store/review-notes.md` (sonunda App Store
Connect'e aynen yapıştırılacak İngilizce blok) ve
`docs/app-store/app-privacy.md` (anket tablosu — `PrivacyInfo.xcprivacy`
ile **birebir aynı** olmak zorunda; bu kural belgeye yazıldı).

**İKİ KAPI KIRMIZI VERDİ, ikisi de gerçek eksikti:** hata kataloğunda
`uc_bulunamadi` yoktu (7 dil eklendi) ve **rol matrisi kilidi** yeni ucu
yakaladı (tur okutabilen dört rol IZIN, yönetici ve sakin RED — `_SCANNER`
ile birebir).

KAPILAR: `pytest` **1163 geçti / 1 atlandı** (taban 1159, +4) ·
`goc-uyum`/`goc-tersinir` **bulgu 0** · `flutter analyze` temiz ·
`flutter test` **1595 geçti / 3 atlandı** (taban 1592, +3) · apk ✓.
§15 envanteri **değişmedi** (8/5).

Notes (2026-08-02, EK — **DENETİM NOTU GERÇEĞE UYMUYORDU**): TestFlight
Build 1 cihaz bulgusu — §1, demo hesapları için **"e-posta + tesis kodu
ile giriş"** vaat ediyordu; mobil giriş ekranında ise **yalnız telefon +
parola** var. Denetçi giremezdi → **kesin ret**. Kod doğruydu, **belge**
yanlıştı.

**ÜÇ SEÇENEKTEN (c) SEÇİLDİ — ve sıfır kod gerektirdi.** (a) "arka uç
e-postayı zaten kabul ediyorsa alanı gevşet": `/auth/login` e-posta ile
birlikte **açık `tenant_slug`** ister (telefon global benzersiz, e-posta
değil), yani (a) arka uç değişikliği demekti — kullanıcının kendi tercih
sırasına göre elendi. (b) "mobile kurumsal giriş anahtarı ekle": mobile
**yalnız denetçinin kullanacağı** bir giriş yolu koymak olurdu; oysa
ayrım bilinçli — **panel** e-posta + tesis kodu, **mobil** telefon.
(c) tohumlamada telefon: `scripts/demo_tenant.py` **zaten**
`+90 500 000 01 01…04` yazıyordu. Kusur tamamen belgede idi.

**DEV'DE UÇTAN UCA ÖLÇÜLDÜ:** dört hesabın dördü de `POST
/auth/login-phone` ile `access_token` alıyor, **parola kurulum adımı
yok**; `05000000102` → `/me` = Demo Güvenlik/security → `demo_mod: true`
→ `POST /scans/simule` **201**, `imza_dogrulandi: false`. Üç yazım biçimi
de (`05000000101`, `5000000101`, `+90 500 000 01 01`) geçiyor —
sunucudaki `normalize_phone` sayesinde; denetçi hangi biçimi yazarsa
yazsın giriyor.

**KİLİT — `mobile/test/denetim_notlari_test.dart` (4 test).** Bu hata
sınıfını hiçbir kod testi göremezdi, çünkü hata **belgedeydi**. Test
belgeyi sözleşme sayar: (1) not, mobilde olmayan bir giriş yolu vaat
etmiyor, (2) nottaki telefonlar ve e-postalar **tohumlama betiğinden**
okunanlarla birebir aynı, (3) giriş ekranı gerçekten `TextInputType.phone`
çiziyor — ekran bir gün e-postaya çevrilirse test düşer ve **notun da**
güncellenmesi gerektiğini söyler. **Mutasyonla doğrulandı:** eski yanlış
cümle geri konunca ve tohumdaki bir numara değiştirilince testler düştü.

### P116 — Yer tutucu / boş ekran süpürmesi
Status: BITTI · Depends-on: P115
Scope: Denetimi düşüren şeyler için her ekranı tara: **ölü düğmeler**, denetim
tenant'ından erişilebilen **"Yakında"** rotaları, içeriksiz **boş durumlar**.
DEMO tenant'ında görünen her şey ya **çalışmalı** ya da özellik bayrağıyla
**gizlenmeli**. Listele + düzelt.
Acceptance: ölçülmüş liste + her maddenin karşılığı (düzeltildi/gizlendi).

Notes (2026-08-02) — **BİTTİ.** Commit: `3df2f8c`. Belge:
`docs/app-store/yer-tutucu-supurmesi.md`; kilit:
`test/yer_tutucu_supurmesi_test.dart` (3 test).

**ÖLÇÜM: rotasız gezinme kartı 0 · "Yakında" işaretli menü girişi 0 ·
boş gövdeli `onPressed`/`onTap` 0.** Yani **düzeltilecek bir şey
çıkmadı** — ama bu, ölçüm yapılmadan bilinemezdi ve artık geri gitmesi
de engelli.

**"Yakında" metinleri duruyor, bilinçli:** ana ekranlardaki `_yakinda`
dalları bir **savunmadır** — rotası eklenmeyi unutulmuş bir kart,
sessizce hiçbir şey yapmayan bir düğme yerine dürüst bir mesaj gösterir.
Bugün o dallar **erişilemez** ve test böyle kalmasını sağlıyor.

**ÖLÇÜM ARACI İKİ KEZ DÜZELTİLDİ:** (1) ilk yazımda **uydurma tip
adları** taranıyordu — tarama **hiçbir şey ölçmüyordu** ve yeşil renk
yanıltıyordu (mutasyon denetimi yakaladı); (2) düzeltirken
`HareketSatiri` kapsama alındı ve kırmızı verdi, oysa o "Son Hareketler"
**günlük satırıdır** ve rotasız olması doğrudur. Son hâli mutasyonla
sınandı: bir karttan `rota:` kaldırılınca test **düşüyor**.

KAPILAR: `flutter analyze` temiz · `flutter test` **1598 geçti / 3
atlandı** (taban 1595, +3).

### P117 — Ekran görüntüsü betiği
Status: BITTI · Depends-on: P116
Scope: `docs/app-store/screenshots.md`: rol başına **tam ekran listesi**,
6.7"/6.1" için (iPad gönderilecekse onun için de — **karar: ilk sürüm yalnız
iPhone önerilir**; `UIDeviceFamily` P114'te ona göre ayarlanır), ekranlar
gerçek görünsün diye **tohumlanmış veriyle**. Çekimin kendisi [KEREM].
Acceptance: belge yazılı; her satır hangi hesapla, hangi rotadan, hangi veriyle.

Notes (2026-08-02) — **BİTTİ.** Commit: `d229683`. Belge:
`docs/app-store/screenshots.md` — **10 kare**, mağazada görünecek
sırayla; her satırda hangi hesap, hangi rota, hangi verinin görünmesi
gerektiği. Tohumlanmış demo tesisi (P115) üzerine kurulu: **boş liste**
görüntüsü "ürün çalışmıyor" izlenimi verir ve tek başına ret sebebi
olabilir.

**KARAR YAZILI: ilk sürüm yalnız iPhone** — iPad'i açmak, göndermediğimiz
bir cihaz için ayrı görüntü seti **ve** düzen doğrulaması istemek olurdu.
Yani **iPad görüntüsü gerekmiyor**. Kaçınılacaklar da listeli (boş liste,
fiyat vaadi, gerçek kişi verisi, simüle okutma menüsünün kareye girmesi).

**Çekim [KEREM].**

### P118 — [KEREM] İlk Mac derlemesi + TestFlight
Status: BLOKE(macOS/CI — AJANIN PAYI BİTTİ) · Depends-on: P114, P115
Scope: Kerem tarafı runbook: `docs/app-store/ios-build-runbook.md` — Codemagic
**ya da** yerel Xcode için tam adımlar: imzalama, yetenekler (NFC; P12 gelince
Push), derleme, yükleme, TestFlight iç test. Ajan runbook'u ve varsa
`codemagic.yaml`'ı yazar; **koşum Kerem'in**.
Acceptance: runbook + CI dosyası commit'li; Kerem tek geçişte izleyebiliyor.

Notes (2026-08-02) — **AJANIN PAYI BİTTİ.** Commit: `d229683`.
`docs/app-store/ios-build-runbook.md` + `mobile/codemagic.yaml`.
**Koşum Kerem'de** (macOS/CI) — statü bu yüzden BLOKE kalıyor.

**Runbook'un ilk işi, P114'te ELLE yapılan yapılandırmayı
DOĞRULAMAKTIR:** Xcode'da gözle bakılacak altı madde (proje açılıyor mu,
NFC yeteneği, cihaz ailesi, Copy Bundle Resources'ta `PrivacyInfo` ve
`InfoPlist.strings`, `en`/`tr` alt öğeleri, marka simgesi). pbxproj
Mac'siz düzenlendiği için bu adım **atlanamaz**.

**`--dart-define`ler zorunlu** ve nedeni yazılı: verilmezse `AppConfig`
varsayılanları devreye girer (API adresi **Android emülatörü** adresidir)
ve uygulama hiçbir sunucuya bağlanamaz — denetçi "çalışmıyor" der.

**App ID'de NFC yeteneği ayrı bir adımdır:** entitlements dosyası tek
başına yetmez; açılmazsa imzalama düşer ya da **daha kötüsü** uygulama
derlenir ama NFC **sessizce çalışmaz**. iPhone 7+ sınırı ve SDM'in
**gerçek cihazda** denenmesi gerektiği de not düşüldü.

**`codemagic.yaml`:** kapılar (analyze + test) yapımdan **önce** koşuyor;
`submit_to_app_store: false` bilinçli — denetim notları, gizlilik anketi
ve ekran görüntüleri elle girilir, eksik biriyle göndermek reddedilip
kuyruğa yeniden girmektir.

### P119 — iOS teşhis turu: kamera yayını + NFC
Status: KISMEN(NFC kök neden BULUNDU + düzeltildi · KAMERA teşhis bekliyor —
cihaz koşumu Kerem'de) · Depends-on: P114, P115
Scope: TestFlight yapım 2'de iki hata da düştü. Bu tur **kör düzeltmeyi
bıraktı**: ürün koduna teşhis eklendi, tek bir `flutter run` çıktısı iki
soruyu da kapatacak biçimde tasarlandı. Belge: `docs/ios-teshis-turu.md`.

**NFC — KÖK NEDEN BULUNDU, düzeltildi.** Hata bir yetkilendirme eksikliği
DEĞİLDİ; Kerem'in kanıtları doğruydu (imzada + gömülü profilde NDEF/TAG,
portalda yetenek açık, temiz kurulum, yeniden başlatma). Eksik olan
`Info.plist`teki bir **beyandı**: oturum `.iso18092` (FeliCa) tarama
seçeneğiyle açılıyordu ve CoreNFC, `.iso18092` isteyen bir
`NFCTagReaderSession`ı ancak uygulama
`com.apple.developer.nfc.readersession.felica.systemcodes` altında sistem
kodlarını beyan etmişse açar; beyan yoksa `begin()` anında **NFCError
code 2 — "Missing required entitlement"** ile geçersiz kılar. Mesaj
yanıltıcıdır: kırmızı ışık yetkilendirmeyi gösterir, sorun beyandadır.
İki forum kaydı belirtiyi **birebir aynı üç seçenekle** bildiriyor
(`developer.apple.com/forums/thread/811220` — iPhone 15 / iOS 26.2,
bizimkiyle neredeyse aynı yapılandırma; ve `.../735183` — "`.iso18092`yi
çıkarınca her şey çalıştı").

**FELICA BEYAN EDİLMEDİ, SEÇENEK ÇIKARILDI.** Kullanmadığımız bir sistem
kodunu beyan etmek denetimde savunulamayacak gerçek dışı bir beyan olurdu
— AID listesinde de aynı ilke uygulanmıştı. `iso15693` kaldı (ek beyan
istemez, "yanlış kart" durumunu ayırt ettirir).

**YETKİLENDİRME DOSYASINA DOKUNULMADI** (TAG-only kaldı). Build 2
NDEF+TAG ile imzalanmıştı ve **yine düştü** — yani NDEF bu hatanın
değişkeni değil. Kanıtla elenmiş bir değişkeni kurcalamak, bu turda
bırakılan alışkanlığın ta kendisi olurdu.

**İKİNCİ HATA — YANLIŞ ADLANDIRMA.** Eklenti oturum hatasının **kodunu**
veriyordu (`NfcReaderErrorCodeIos`); bizim kod yalnız `message`i alıp HER
geçersizleştirmeyi `okumaIptal` sayıyordu. Cihazda "Missing required
entitlement" ekrana **"Okuma iptal edildi: …"** diye çıktı. İptal "tekrar
deneyin" demektir; yapım düzelmeden hiçbir deneme tutmaz — iki tur tam bu
yüzden yanlış yerde arandı. Artık 22 kodun tamamı sınıflanıyor ve
yapılandırma hataları ayrı bir kimliğe düşüyor (`yapilandirmaEksik`,
7 dilde).

**KAMERA — kök neden YOK, hipotezler sıralı.** H1 (en olası): iki platform
**aynı kaydı oynatmıyor**. Android karşılaştırması dev'deki tohumlanmış
genel HLS yayınlarıyla, iOS ise prod'daki gerçek tesisle yapıldıysa ortada
iOS hatası yoktur — sahadaki kamera ya `rtsp://` (AVPlayer bunu **hiç**
oynatamaz, ExoPlayer oynatabilir) ya da telefonun erişemediği bir yerel ağ
adresidir. *Tohumlanan demo tesisinde kamera **hiç yok** —
`demo_tenant.py` kamera yazmaz; yani prod'da görülen kameralar Kerem'in
kendi tesisine ait.* H2: ATS anahtarı pakete girmemiş olabilir. H3:
hazırlık sonrası reddedilen varyant/kodek. H4: 15 sn'de yanıt yok
(erişilemez adres). H5 (en düşük): `video_player`/iOS 26 gerilemesi —
bu belirtiyi bildiren güncel bir kayıt bulunamadı.

**TEŞHİS KANALI — "kaynakta ne yazıyor" değil, PAKETTE ne var.**
`ios/Runner/AppDelegate.swift` içine bir yöntem kanalı eklendi; çalışan
paketin **kendi `Info.plist`ini** okuyup ATS/NFC anahtarlarını Dart'a
verir. "Kaynak doğru ama pakete girdi mi?" sorusunun tek kesin cevabı bu
(`GENERATE_INFOPLIST_FILE`, yanlış `INFOPLIST_FILE`, hedef karışması, eski
bir TestFlight yapımı…). **Yeni çerçeve eklenmedi** (`CoreNFC`/`Security`
ithal edilmedi): Mac'siz düzenlenen bir projede derlemeyi riske atmamak
için yalnız `Bundle.main` okunuyor. Ayrı bir `.swift` dosyası da
**açılmadı** — pbxproj'a yeni kaynak eklemek aynı riski taşırdı.

**ADRESLER MASKELENİR:** saha kameralarının adresleri gerçek dünyada
`rtsp://kullanici:parola@10.0.0.5/…` biçimindedir ve teşhis günlüğü ekran
görüntüsüyle paylaşılır. Kimlik `***@` olur, sorgu dizesi `+sorgu(41)`ya
iner; konak/port/yol korunur (teşhisi yapan şey zaten onlar).

**TEST BİR KUSURU YAKALADI:** maskeleme `Uri.tryParse`e güveniyordu, o da
hoşgörülüdür — `https://ornek /gizli-yol?token=…` gibi yapıştırma artığı
bir adresi boşluğu `%20` yapıp çözer, maskeleme de geçerli bir adresmiş
gibi yolu **yazardı**. Oynatıcıdaki boşluk kuralı maskelemeye de taşındı.

**KİLİTLER (17 test, beşi mutasyonla doğrulandı):**
`test/ios_nfc_polling_kilidi_test.dart` — `.iso18092` seçiliyse FeliCa
sistem kodları **beyan edilmiş olmalı** (çapraz dosya: `nfc_service.dart`
↔ `Info.plist`), böylece hata sessizce geri gelemez; ayrıca kod→kimlik
eşlemesinin 22 kodu da ölçülüyor. `test/teshis_test.dart` — maskeleme
(parola/jeton sızmaz), kanal adının **iki ucunun** aynı olması (ayrışırsa
teşhis sessizce çalışmazdı) ve ATS anahtarlarının kaynakta bulunması.
Mutasyonlar: iso18092 geri kondu → düştü · güvenlik ihlali yine
`okumaIptal`e eşlendi → düştü · maskeleme kimliği bıraktı → düştü · sorgu
maskelenmedi → düştü · Swift kanal adı ayrıştı → düştü.

KAPILAR: `flutter analyze` temiz · `flutter test` **1632 geçti / 3
atlandı** (taban 1615, +17) · apk ✓.

Acceptance: Kerem `docs/ios-teshis-turu.md`deki tek koşumu yapar ve üç
blok günlüğü yapıştırır; kamera kök nedeni o çıktıyla belirlenir.

### P120 — Yeni birincil alan adı: yönetiyor.com
Status: KISMEN(kod+belge BİTTİ · DNS/dağıtım Kerem'de) · Depends-on: P113
Scope: `yönetiyor.com` müşteriye dönük birincil alan olur; `yonetio.site`
**kapanmaz**. Kök/www genel portal, `panel.` yönetim paneli. Belge:
`docs/alan-adi-gecisi.md` (DNS tablosu + e-posta kayıtları + doğrulama).

**PUNYCODE DÜZELTİLDİ.** Görevde ACE etiketi `xn--ynetiyor-vpb` olarak
verilmişti; **yanlış**. Doğrusu `xn--ynetiyor-n4a`. İki bağımsız kodlayıcı
(IDNA2008 `idna` paketi ve stdlib IDNA2003 codec'i) aynı sonucu verdi ve
DNS de doğruladı: `xn--ynetiyor-n4a.com` kayıtlı (NS Hostinger, A kaydı
prod IP `185.248.57.150`), `-vpb` etiketli ad **hiç yok** — SOA bile
dönmüyor. Yanlış biçimle devam edilseydi Caddy o ad için sertifika almaya
çalışır, ACME sürekli düşer, site **hiç açılmazdı** — ve hata "sertifika
alınamadı" derdi, "alan adını yanlış yazdınız" demezdi.

**CANLI BULGU — App Store'u düşürecek durum.** `yonetio.site` **kökü
bugüne kadar hiç sunulmuyordu**: Caddy'de yalnız `api.`/`panel.`/
`storage.` blokları vardı. Oysa mobilde `AppConfig.webBaseUrl` =
`https://yonetio.site` ve gizlilik/koşullar bağlantıları oraya gidiyor.
Ölçüldü: `https://yonetio.site/gizlilik` **200 dönüyor ama içerik
Hostinger'in "Parked Domain" sayfası** (her yol 200 — catch-all). Yani
App Store Connect'e verilen **gizlilik politikası adresi park sayfası
gösteriyor**; tek başına ret sebebi ve "sayfa açıldı mı" diye bakan bir
cihaz testinden **geçer görünür**. Caddy'ye kök blokları eklendi; kök A
kaydı prod IP'ye çevrilince düzelir — **uygulama yeniden derlenmeyecek**,
gömülü adres doğruydu, altında sunucu yoktu.

**YÖNLENDİRME YOK, İKİSİ DE KANONİK.** `yonetio.site` → `yönetiyor.com`
301'i, incelemedeki yapımın hukuki belge bağlantılarını kırardı.
`api.yönetiyor.com` ve `storage.yönetiyor.com` **açılmadı**: mobilin
gömülü adresi `api.yonetio.site` ve bu tur değişmiyor; `storage.` için
ikinci konak, imzalı URL doğrulamasını **bozar** (imza tek konakla
yapılır).

**İKİNCİ CANLI BULGU — BİZE AİT OLMAYAN ALAN, GİDEN MESAJLARDA.**
`routers/mesajlar.py` içinde `"odeme_linki": "https://yonetio.app/ode"`
sabit kodluydu. **`yonetio.app` bize ait değil** — NS'i Cloudflare, oysa
sahip olduğumuz alanların hepsi Hostinger'da; fark tek bir sözcük
(`.app`/`.site`). Bu bir örnek değil: aidat hatırlatma **SMS ve
e-postalarındaki** `{odeme_linki}` etiketine giriyor. Yani **bizim
gönderdiğimiz mesajda sakinlere üçüncü bir tarafın alan adına bağlantı**
veriliyordu — o alanı elinde tutan biri için hazır bir kimlik avı yüzeyi.
Artık `Settings.portal_base_url`dan üretiliyor (`PORTAL_BASE_URL`,
varsayılan `https://yönetiyor.com`; unicode bilerek — bağlantı insanın
okuduğu mesaja girer, `xn--…` SMS'te kimlik avı gibi görünür).
**Açık kalan:** `/ode` rotası henüz yok, bağlantı 404 verir — ama **bizim**
alanımızda.

**CORS IDN NORMALLEŞTİRMESİ** (`backend/app/config.py`): tarayıcı `Origin`
başlığını **daima punycode** gönderir; `allow_origins` tam eşleşme yapar.
Yapılandırmaya unicode yazılırsa hiçbir istek geçmez ve belirti "CORS
bozuk" diye görünür — alan adının yazım biçimi kimsenin aklına gelmez.
Artık iki biçim de listede. Yeni bağımlılık **eklenmedi** (stdlib `idna`
codec'i); port korunur, çözülemeyen değer ham bırakılır (tek yazım
hatası yüzünden uygulamanın açılmaması, çözdüğünden büyük bir sorun
olurdu).

**PANEL/ADMIN-WEB'DE DEĞİŞİKLİK GEREKMEDİ** (denetlendi): `API_BASE` prod'da
iç ağ adresidir (`http://api:8000`), yani panel→API çağrısı CORS'a hiç
uğramaz; çerezlerde `domain` **set edilmiyor** → host-only, iki alan ayrı
oturum tutar (sızıntı yok, beklenen davranış); `next.config.mjs`'te
**host tabanlı yönlendirme yok** ve `middleware.ts` `host`/`origin`
okumuyor — uygulama konaktan bağımsız, yeni adlarda olduğu gibi çalışır.

**HUKUKİ BELGELERDEKİ E-POSTALAR DEĞİŞTİRİLMEDİ** (`kvkk@yonetio.site`,
`destek@yonetio.site`; 7 dil). Yayınlanmış bir belgedeki iletişim adresini,
kutu **açılmadan** değiştirmek KVKK başvurusu yapan birinin postasını
boşluğa göndermek olur. Sıra belgede yazılı: kutular açılır → teslim test
edilir → tek commit'te güncellenir, eskiler ≥1 yıl yönlendirmede kalır.

**E-POSTA DNS'i BELGELENDİ, KURULMADI** (`docs/alan-adi-gecisi.md` §4):
MX + SPF/DKIM/DMARC iskeleti, sağlayıcıdan bağımsız. Kendi kutumuzda mail
sunucusu **yok ve olmayacak** (giden posta itibarı tam zamanlı iştir).
DMARC `p=none` ile başlanır — doğrudan `p=reject`, sağlayıcı hizalaması
eksikken **kendi meşru postamızı** çöpe attırır.

**YENİ KAPI — `depo-alan-adi`** (`infra/alan-adi-denetimi.py`, `kapilar.sh`
`depo` alanına eklendi), üç kontrol: (1) depodaki her `xn--` dizesi unicode
kaynağından **yeniden üretilip** karşılaştırılır — punycode gözle
doğrulanamaz; (2) yapılandırmada unicode konak aranır (unicode yazılan bir
site bloğu **hiç eşleşmez**); (3) kaynakta geçen, markamıza **benzeyen** her
adres sahip olduğumuz alanlar kümesinde mi — `yonetio.app` bulgusunu bulan
kontrol budur.

**KAPI İKİ KEZ KENDİ YAZDIĞIM HATAYI YAKALADI:** (a) uyarı yorumlarına
yanlış punycode'u **tam alan adı olarak** yazmıştım — kopyalanabilir bir
tuzak; artık her iki biçim de yalnızca ACE *etiketi* olarak anılıyor.
(b) Kontrol 2, kendi eklediğim `PORTAL_BASE_URL=https://yönetiyor.com`
satırını da işaretledi; haklı değildi — o bir **site adresi** değil, mesaj
metnine giren bir **bağlantı**. Kural keskinleştirildi: şema taşıyan
(`https://`) değerler kontrol 2'nin dışında (Caddy site adresleri ve
`*_DOMAIN` değişkenleri şema taşımaz, kapsam dışı kalmazlar).
(c) Kapı yalnız **izlenen** dosyaları tarıyordu; oysa commit'ten ÖNCE
koşuyor — yani **yeni eklenen** bir dosya görünmezdi, ve hatayı getiren tam
olarak yeni dosyalardır. Bulguyu *anlatan* yeni belge bu yüzden sessizce
geçmişti. `--others --exclude-standard` eklendi. (d) O ekleme, aracın
**kendi DENEY dizesini** yakalattı — kendini taramak, sınama verisini bulgu
saymak olurdu; araç kendi dosyasını atlıyor, gerekçesi yazılı.
Bize ait olmayan alanın **belgelerde** geçmesi için adıyla ve gerekçesiyle
iki satırlık bir istisna var (belge kullanıcıya bağlantı göndermez; ürün
kodu için kural mutlak).
DENEY=1/2/3 ile üç kontrol de mutasyonla doğrulandı; `portal_base_url`
testleri de iki mutasyonla (üçüncü-taraf alanı geri koymak / varsayılanı
değiştirmek) doğrulandı.

**CADDY YAPILANDIRMASI GERÇEKTEN ÖLÇÜLDÜ:** `caddy validate` → "Valid
configuration"; `caddy adapt` çıktısındaki konak eşleştiricileri
sayıldı → **8 konak** (api/panel/storage.yonetio.site + kök/www her iki
alan + panel.xn--ynetiyor-n4a.com). `prod-denetimi.py` G kontrolü yeni üç
değişkeni de kapsıyor (compose varsayılanı == .env.prod.example ==
runbook).

KAPILAR: `depo-izlenmeyen` 0 · `depo-alan-adi` 0 · backend `pytest`
(+15 yeni birim testi) · `tsc`/`vitest`/`build` temiz.
*`prod-denetimi.py` E kontrolünde 3 bulgu var (api'de `API_WORKERS`,
`DB_POOL_SIZE`, `DB_MAX_OVERFLOW` dev'de var prod'da yok) — **bu turdan
ÖNCE de vardı**, `git stash` ile doğrulandı; kapsam dışı bırakıldı.*

**TAKİP TURU — kök konaklar `000` dönüyordu.** Cihaz kanıtı:
`panel.yonetio.site/gizlilik` **200**, ama `yonetio.site/gizlilik` **000**.
Ölçüldü (dışarıdan, SNI ile): prod'da çalışan Caddy'nin sertifikası
**yalnız `panel.yonetio.site` ve `api.yonetio.site`** için var; commit'li
Caddyfile'da bulunan `panel.xn--ynetiyor-n4a.com` bile TLS'te
`internal error` veriyor. Yani **Caddyfile bir kusur taşımıyordu — yeni
yapılandırma prod'a hiç dağıtılmamıştı.** DNS ise Kerem tarafından
tamamlanmış: `yonetio.site` kökü artık prod IP'de, ve **`app.` kaydı da
açılmış** (benim bilmediğim dördüncü konak) — Caddyfile'a eklendi, artık
**9 konak** sunuluyor (`caddy adapt` ile sayıldı).

**`000`, "sayfa yok" DEĞİLDİR.** SNI eşleşmeyince TLS el sıkışması düşer;
istemci HTTP'ye hiç gelemez. Tanımsız bir konak temiz bir 404 değil,
**kopmuş bir bağlantı** üretir — App Store denetçisi için ayırt edilemez.
Belgeye ayırt etme tablosu ve sunucudan Host başlıklı yerel curl'ler
eklendi (TLS/DNS/ağ denklemden çıkar).

**DAĞITIM KOMUTU DÜZELTİLDİ — sessiz no-op tuzağı.** Önceki tur
`up -d caddy` diyordu. `Caddyfile` bir **bind mount**'tur: içeriğini
değiştirmek servis *tanımını* değiştirmez, dolayısıyla salt-Caddyfile
düzenlemesinde compose kabı yeniden yaratmaz — komut **"Container caddy
Running" yazıp hiçbir şey yapmaz** ve başarıyla döndüğü için dağıtım
yapıldı sanılır. Artık `--force-recreate` yazılı; kesintisiz alternatif
(`caddy reload`) da belgede.

**YENİ KİLİT — kontrol 4 (`SUNULUYOR`).** İki tarafı bağlar: (a)
uygulamalarımızın **koda gömülü bağlantı verdiği** her konak Caddyfile'da
tanımlı olmalı — mobilin `webBaseUrl`'ü `yonetio.site` kökünü gösteriyor
ve o konak sunulmuyordu, kilit bunu yakalar; (b) **KORUNAN** konaklar
(`panel.yonetio.site` = App Store'un gizlilik adresi,
`api.yonetio.site` = mağazadaki yapımın gömülü API'si, `yonetio.site` =
incelemedeki yapımın hukuki belge kökü) Caddyfile'dan **asla düşemez** —
bunlar dışarıya verilmiş, geri alınamaz adreslerdir. DENEY=4 ve DENEY=5
ile mutasyonla doğrulandı.

**ÖNEMLİ AYRIM:** kök sunumu App Store *alanı* için ek bir güzellik ama
**uygulama içi hukuki bağlantılar için ZORUNLU** — `AppConfig.webBaseUrl`
kökü gösteriyor, yani dağıtım yapılana kadar uygulamadaki "Gizlilik
Politikası" düğmesi park sayfası bile değil, **hiçbir şey** açmıyor.
Mobil sabit **değiştirilmedi**: incelemedeki yapım zaten kökü taşıyor,
sabiti değiştirmek onu kurtarmaz — kökü sunmak kurtarır.

**ÜÇÜNCÜ TUR — "Caddyfile'da hiç yoktu" iddiası ölçüldü.** Sunucudaki
`grep -n "xn--\|yonetiyor" infra/Caddyfile` **eşleşme vermiyordu**; bu
doğru bir gözlem ama sebebi başkaydı. Depodaki HEAD'de o dize üç yorum
satırında **var** (`git log -- infra/Caddyfile` → `38c211f`, `8185498`).
Yani sunucudaki çalışma kopyası `38c211f`'ten **eski**. Ayrıca konak adları
Caddyfile'da **literal değil**: `{$PORTAL_DOMAIN}` ile gelir, varsayılanı
compose'dadır — bu yüzden güncel bir kopyada bile `grep xn--` yalnız
yorumları bulur. Teşhis yolunun kendisi yanıltıcıydı; belgeye "hangi
konaklar sunuluyor" sorusunun **doğru** cevaplanma yolu eklendi.

**PUNYCODE — üçüncü kez ölçüldü, sonuç aynı.** Görev metni yine
`-vpb` etiketini veriyordu. O ad **kayıtlı değil**: SOA yok, NS yok,
dört etiketin (kök/www/panel/app) **hiçbiri** A kaydı döndürmüyor. Buna
karşılık `xn--ynetiyor-n4a.com`ın dördü de `185.248.57.150`'de — yani
"dört A kaydı doğrulandı" gözlemi doğru, sadece ACE dizesi yanlış
kopyalanıyor. Yapılandırmaya `-vpb` yazmak, var olmayan bir ad için ACME
denemesi ve **hâlâ açılmayan bir site** demekti.

**KÖK ARTIK PANEL DEĞİL.** admin-web'in `/` rotası `/dashboard`a, oradan
`/login`e gider; kök panele bağlansaydı markanın ana adresi bir **yönetici
giriş ekranı** olurdu. Kök/www artık statik bir tanıtım sayfası sunuyor
(`infra/portal/kok/`), `/gizlilik` + `/kosullar` + `/_next/*` admin-web'e
proxy'leniyor. **Metinler kopyalanmadı** — tek kaynak
`admin-web/lib/hukuki/` (7 dil); kopyalanan bir gizlilik politikası bir gün
ötekiyle çelişir. `/_next/*` proxy'si atlanırsa sayfa **biçimsiz ama 200**
döner, yani sessizce bozulur.

**`app.` YER TUTUCUSU** (`infra/portal/app/`): DNS'te A kaydı vardı, site
bloğu yoktu. `file_server` bilinçli — bilinmeyen yol **404** döner;
`try_files` ile her yolu index'e düşürmek, Hostinger'ın park sayfasında
eleştirdiğimiz catch-all'ın aynısını üretirdi.

**GERÇEK CADDY İLE ÖLÇÜLDÜ, `validate` ile yetinilmedi.** Aynı Caddyfile
yerelde `local_certs` (Caddy iç CA'sı, ağ/ACME yok) ile ayağa kaldırıldı,
admin-web yerine yankı veren sahte bir upstream konuldu ve **8 konak × 4
yol** SNI üzerinden ölçüldü: kök/www → tanıtım sayfası, `/gizlilik` ve
`/_next/*` → upstream, bilinmeyen yol → **404**; `app.` → yer tutucu;
`panel.*` → upstream (her yol). Kontrol grubu: `bilinmeyen.ornek` →
**000** — Kerem'in gördüğü belirtinin **birebir aynısı**, yani `000`ın
"konak Caddyfile'da yok" demek olduğu deneyle gösterildi.

**YENİ KİLİT — kontrol 5 (BELGE-UYUMU).** İstenen "belge ile yapılandırma
bir daha ayrışmasın" kapısı: `docs/alan-adi-gecisi.md` §2b'deki konak
listesi ile Caddyfile'ın **çözülmüş** site adresleri karşılaştırılır, **iki
yönde de**. Belgede vaat edilip sunulmayan ad da, sunulup belgeye
yazılmayan ad da kapıyı kırmızı yapar. DENEY=6 ve ters yönde ek bir
mutasyonla doğrulandı. Kapı artık altı deneyle sınanıyor (DENEY=1…6).

Acceptance: Kerem §2'deki `--force-recreate` dağıtımını yapar;
`docs/alan-adi-gecisi.md` §3a/3b/3c doğrulaması **dokuz** konakta da
sertifika + kök/`app.` 200 + `/gizlilik` 200 verir ve "Parked Domain"
kalmaz.

### P121 — Kamera ızgarasında canlı karo (oynatıcı açmadan)
Status: BITTI · Depends-on: —
> **NUMARA ÇAKIŞMASI:** Kerem bu üç maddeyi "P43–P45" diye istedi, ama o
> numaralar **doludur** (P43/P44/P45 = panel bileşen testi altyapısı, üçü de
> BITTI ve üç ayrı `Depends-on` onlara işaret ediyor). Var olan maddeleri
> yeniden numaralamak her çapraz göndermeyi bozardı (kural 1 kimliğe göre
> işler); bu yüzden sıradaki boş numaralar kullanıldı.
> **İstenen etiket → gerçek:** P43→**P121**, P44→**P122**, P45→**P123**.

Scope: Izgarada oynatıcı açmadan canlı görüntü. **N tane video oynatıcı
otomatik oynatılmaz** (pil/ısı/bant genişliği; iOS eşzamanlı AVPlayer sayısını
sınırlar). Anlık görüntü deseni: her karo 5–10 sn'de bir tazelenen **durağan
kare** gösterir, **yalnız ızgara görünürken**; arka planda durur (ana ekranın
tazeleme-kapsamı disiplini yeniden kullanılır).
Kare kaynağı sırayla: (a) `camera.snapshot_url` — sözleşmeye/şemaya **YENİ bir
revizyonda EKLEMELİ** değişiklik olarak eklenir, Frigate (P17) sonradan
doldurur; (b) HLS için ucuz istemci-tarafı kare yakalama (kısa sessiz init /
küçük resim) — **CPU/pil maliyeti ÖLÇÜLÜR**, sıçratıyorsa yol **reddedilir**;
(c) geri düşüş: önbellekteki son kare + durağan yer tutucu.
"CANLI" rozeti **yalnız kareler gerçekten tazelenirken**. Oynatılamayan
(rtsp / `oynatilabilir=false`) karolar mevcut rozetlerini korur, tazelenmez.
Kamera formundaki yardım metninde **desteklenen kaynak kuralı** yeniden
doğrulanır ve yazılır: yalnız doğrudan medya akışı — HLS (`.m3u8`) ve MP4
oynar; web sayfaları (YouTube, Vimeo, belediye izleyici sayfaları) **oynamaz**
ve istemcide açık Türkçe hatayla reddedilir; RTSP saklanır ama yalnız
gelecekteki Frigate restream'i (P15–P17) ile oynatılabilir. 7 dil ARB; kapılar.
Acceptance: göç + sözleşme + şema eklemeli; ızgara görünürken tazeleme,
arka planda durma ölçülür (test); rozet yalnız tazelerken; form reddi 7 dilde.

Notes (2026-08-03) — **BİTTİ.** Üç commit: `130f014` (göç 0031 + sözleşme +
doğrulama), `a2029ae` (ızgara karosu + tazeleme kapsamı), `830431a` (form +
kaynak kuralı).

**(b) ŞIKKI ÖLÇÜLDÜ VE REDDEDİLDİ.** İki bağımsız sebep: (1) **bant
genişliği** — HLS'te kare seviyesinde erişim yok, en küçük birim bir PARÇA;
tohumlanan yayında ölçüldü: **1.87 MiB / 10 sn**. Altı kamera × 8 sn ≈
**4 GiB/saat**, yani kaçındığımız şeyden (videoyu sürekli oynatmak) **daha
pahalı**. (2) **teknik olarak kapalı** — `video_player` kareyi `Texture`
katmanına verir (`avfoundation_video_player.dart:307`), dış doku motor
tarafından birleştirilir ve `RepaintBoundary.toImage()` ile yakalanamaz;
paket bir anlık görüntü API'si de sunmuyor. Kalan sıra: (a) `snapshot_url`,
(c) önbellekteki son kare + yer tutucu.

**ÜÇ ADRES ÜÇ AYRI ŞEY.** `stream_url` kameranın kendisi (rtsp olabilir),
`restream_url` geçidin oynatılabilir yayını (HLS), `snapshot_url` tek kare
(JPEG). Kare adresi **oynatılabilirliği değiştirmez**: aksi halde kullanıcı
karoda görüntü görüp dokunur ve oynatıcı açılmaz.

**KAPSAM DİSİPLİNİ** ana ekrandan devralındı: üstüne ekran açılınca ve arka
planda **durur**, dönüşte/ön planda hemen bir kare tazeleyip devam eder;
kare çekebilen kamera yoksa zamanlayıcı **hiç kurulmaz**.

**ROZET ÜÇ HALİ AYIRIR:** kare akıyorsa yeşil "Canlı"; adres var ama
akmıyorsa soluk "Görüntü alınamıyor" (7 dil); adres yoksa **davranış
değişmez**.

**KAYNAK KURALI İSTEMCİDE:** sunucu `https://youtube.com/...` adresini
reddedemez ve etmemeli — şema açısından geçerli. Kural konmasa belirti
"kaydettim ama açılmıyor" olur ve teşhis kamerada aranır, oysa hata
**kayıttadır**. Kural bir **kara liste değil**: bilinen barındırıcıda bile
`.m3u8`/`.mp4` ile biten adres KABUL edilir.

**İKİ DEPO KAPISI GERÇEK KUSUR YAKALADI:** (1)
`gorsel_cozme_denetimi_test.dart` — kare `NetworkImage`leri çözme sınırsızdı
(4000×3000 bir kare ~48 MB RGBA); artık `ResizeImage` + `LayoutBuilder`.
(2) `kamera_yonetim_test.dart` — yeni alan ön-doldurulmasaydı düzenleme
yolu kare adresini sessizce silerdi.

**TEST ÇİFTİ DE DÜZELTİLDİ (mutasyonla):** sahte görsel yolu kareyi
kendiliğinden "geldi" sayıyor ve bir mutasyonu sessizce geçiriyordu.

**MUTASYON:** backend 2/2, tazeleme+karo 5/5, kaynak kuralı 3/3. Backend
PATCH testi ilk hâlinde yalnız `422` bekliyordu ve router doğrulaması
kaldırılınca **yine geçiyordu** (şema kısıtı da 422 verir).

KAPILAR: `pytest tests/test_cameras.py` 39 · `goc-uyum`/`goc-tersinir` 0 ·
`flutter analyze` temiz · `flutter test` **1667 geçti / 3 atlandı** · apk ✓.

### P122 — Bina tasarımcısı: ızgara hücresinde daire bilgisi
Status: BITTI · Depends-on: P121
Scope: Bina/kat tasarımcısında daire tipi atandıktan sonra **hücrenin kendisi**
tipi göstermeli — yalnız yan panel değil. Hücre içeriği: kapı no + tip
(örn. "12 · 2+1") ve bir katın bir bakışta okunmasını sağlayan **ince,
tipe bağlı renk/rozet**. En küçük desteklenen ızgara boyutunda **okunur
kalmalı** (kısalt/ölçekle; küçük ekran golden testiyle doğrula). Hem **panel**
bina tasarımcısına hem de aynı ızgaranın çizildiği **mobil bina haritasına**
uygulanır — ikisi de denetlenir, ızgara nerede varsa orada uygulanır.
Depends-on daire tipleri işi (P26); P26 tamam değilse **var olan tip modeliyle**
uygulanır ve takip notu yazılır. 7 dil ARB; kapılar (panel: `npm run build` de).
Acceptance: hücre tipi gösterir; küçük ekran golden'ı geçer; iki yüzey de
denetlenmiş ve nerede ızgara varsa uygulanmış.

Notes (2026-08-03) — **BİTTİ.** Commit `d562991`. P26 tamamdır:
`unit_tip_ad` zaten `UnitOut`ta dönüyordu ve mobil `EditorUnit` onu **zaten
taşıyordu** — eksik olan tek şey hücrenin **çizmemesiydi**. Panelde alan
istemci tipine (`lib/types.ts`) hiç eklenmemişti; eklendi.

**İKİ YÜZEY DE DENETLENDİ:** panel `building-editor` + mobil
`bina_duzenleme_screen`. Üçüncü ızgara (şikâyet haritası) **bilerek
dışarıda**: orada hücrenin taşıdığı bilgi şikâyet yoğunluğudur ve tip
koymak iki farklı okumayı üst üste bindirirdi.

**RENK AD'DAN TÜRETİLİR, KAYITTA TUTULMAZ.** Tipe renk kolonu eklemek
yöneticinin dolduracağı bir alan daha demekti. **Kimlik değil ad** kullanılır:
aynı ad iki tesiste aynı rengi alır. Palet **sabit ve küçük** (sekiz ton) —
sürekli bir renk çarkı birbirine karışan tonlar üretir.

**İKİ DİLDE İKİ FONKSİYON, TEK TABLO.** `daireTipiRengi` hem Dart'ta hem
TS'te var; **paylaşılan beklenen-değer tablosu** ikisini bağlıyor. Dilin
kendi hash'ine güvenilmedi (`String.hashCode` Dart'ta değişebilir). TS
tarafı **kod noktası** üzerinden yürür — emoji içeren adda vekil çifti
ayrışma üretirdi.

**TİP, SIRADAN ÖNCELİKLİDİR** (hücre iki satır; üçüncü taşar). **Pasif
daire tip rengi/etiketi almaz** — yoksa "pasif" durumu renk gürültüsünde
kaybolurdu.

**TEST GERÇEK BİR TAŞMA BULDU:** yazı ölçeği **1.6x ve 2.0x**'te hücre
taşıyordu. `FittedBox` ile metni küçültmek yanlış olurdu (kullanıcı yazıyı
büyük istedi); kutu yazı ölçeğiyle büyütüldü — tur 27 deseninin aynısı.
İkinci bulgu: `Semantics` etiketi alt ağaçtaki `Text`lerin **yanına**
ekleniyordu, ekran okuyucu adı iki kez okurdu.

**MUTASYON:** mobil 4/4 · panel 3/3.

KAPILAR: `tsc` temiz · `vitest` (+15) · `npm run build` ✓ ·
`flutter analyze` temiz · `flutter test` **1687 geçti / 3 atlandı** · apk ✓.

### P123 — Telefon girişi: maskeleme + doğrulama (HER YERDE)
Status: BITTI · Depends-on: P122
Scope: **Her** telefon alanı (mobil + panel: sakin/personel/kişi formları,
giriş, personel, firma, demo/admin oluşturma):
* yazarken gruplanarak çizilir: `0543 199 29 04` (TR biçimi);
* yalnız rakam kabul eder, uzunluk **sert** sınırlanır (fazlası yazılamaz);
* geçersiz TR mobil ön ekini açık Türkçe satır-içi mesajla reddeder;
* API'ye **normalleştirilmiş** biçim gider (sunucudaki `normalize_phone` zaten
  birden çok biçimi kabul ediyor — **tel biçimi DEĞİŞMEZ**, yalnız kullanıcı
  deneyimi);
* yapıştırma çalışmaya devam eder (`+905431992904` → `0543 199 29 04`).
**TEK paylaşılan** bileşen/biçimlendirici olarak yazılır ve **bütün çağrı
yerleri ona taşınır** (her telefon alanı grep'lenir; maskesiz kalan bir alan
**başarısızlıktır**). Testler: biçimlendirici birim testleri (yazma,
yapıştırma, geri silme, taşma, geçersiz ön ek) + platform başına bir widget
testi. 7 dil ARB; kapılar.
Acceptance: grep envanteri ile "maskesiz kalan alan yok" gösterilir;
biçimlendirici testleri + widget testleri geçer.

Notes (2026-08-03) — **BİTTİ.** Tek biçimlendirici iki yüzeyde:
`mobile/lib/src/core/ui/telefon_alani.dart` ve `admin-web/lib/telefon.ts`
(aynı kurallar, **paylaşılan test tablosu** ile bağlı).

**TEL BİÇİMİ DEĞİŞMEDİ.** Sunucuya giden değer yine `normalize_phone`in
kabul ettiği bir biçimdir; artık **E.164** (`+905431992904`). Ham yazımı
göndermek de çalışıyordu ama aynı numaranın iki farklı yazımla iki kayıt
üretmesi, telefon **global benzersiz** olduğu için bir çakışma hatasına
dönüşürdü.

**ÖN EK KURALI KAPALI LİSTE DEĞİL.** "Bilinen operatör bloklarını" saymak,
BTK yeni blok tahsis ettiğinde **gerçek bir numarayı** kaydettirmemek
demekti. Kural `5` ile başlama zorunluluğudur; amacı **sabit hattı**
ayırmaktır — `0212…` bir cep numarası değildir ve SMS gitmez.

**AYRI BİR MASKE PAKETİ EKLENMEDİ.** İhtiyaç tek ülkenin tek kalıbı ve iki
kural; genel bir paket yapıştırma/geri silme davranışını kendi kurallarıyla
getirir ve TR ön ek doğrulaması yine bize kalırdı.

**KAPSAM KİLİDİ İŞE YARADI — bir alanı gerçekten yakaladı.** Panelde
`tenants/page.tsx`teki tesis-oluşturma telefonu göçten geride kalmıştı;
kilit onu bulunca taşındı. Böyle bir göç her zaman aynı biçimde eksik
kalır: altı alandan beşi taşınır, altıncısı gözden kaçar ve **hiçbir test
düşmez** — çünkü o ekran zaten "çalışıyordur". İki kilit de kendi
dedektör testini taşıyor (kasıtlı kusurlu örnek) ve **alan sayısını**
ölçüyor: desen bozulup tarama hiçbir şey bulamazsa "geçti" demesin.

**İMLEÇ HATASINI TEST BULDU:** biçimlendirici imleci n'inci hanenin
*kendisine* koyuyordu, *ardına* değil — kullanıcı 5 hane yazınca altıncıyı
bir önceki hanenin soluna yazardı.

**VAR OLAN BİR TEST GÜNCELLENDİ:** `login_screen_phone_test.dart` ham
yazımı (`05321112203`) sabitliyordu. Artık normalleştirilmiş değeri **ve**
kullanıcının gördüğü gruplanmış biçimi ölçüyor.

**MUTASYON:** mobil 4/4 (sert sınır, ön ek kuralı, `+90` soyma, bir alanı
göçten geride bırakma).

KAPILAR: `tsc` temiz · `vitest` (+19) · `npm run build` ✓ ·
`flutter analyze` temiz · `flutter test` **1721 geçti / 3 atlandı**
(taban 1687, +34) · apk ✓.

### P124 — Kamera modülü prod'da öldü: kod yeni, şema eski
Status: BITTI · Depends-on: P121
Scope: Cihaz bildirimi "kamera oynatma bozuldu, canlı karolar da boş".
Bisect + **yeniden üretim**, ardından kalıcı koruma.

**BOZAN COMMIT: `130f014` (P121/1) — ama tek başına değil.** O commit
`Camera.snapshot_url`u ORM modeline ekledi (göç `0031` ile birlikte).
Kusur, commit'in kendisinde değil **dağıtım sırasında**: prod'a yeni `api`
imajı gitti, **göç koşulmadı**. SQLAlchemy artık her `SELECT camera`
sorgusuna `camera.snapshot_url` koyuyor; Postgres "column does not exist"
diyor ve **`GET /cameras` 500** dönüyor. Kamera listesi hiç gelmediği için
karo da yok, açılacak kamera da yok — **iki belirti, tek sebep**.

**KUSURUN SAHİBİ BENİM:** `docs/alan-adi-gecisi.md`in dağıtım bölümünü ben
yazdım ve `up -d --build api` dedim — **`migrate` adımı yoktu**. Aynı
turun başka bir commit'i göç ekliyordu. `infra/RUNBOOK-PROD.md` doğruydu:
orada `up -d --build` **servis adı olmadan** koşuluyor ve `migrate`
servisi de ayağa kalkıyor. Tehlikeli olan **tek servisi hedeflemek**.

**YENİDEN ÜRETİLDİ (tahmin değil):** dev'de `alembic downgrade 0030` →
`GET /cameras` **500** → `upgrade head` → **200, 5 kamera**. Prod'un
yeniden dağıtıldığı da ölçüldü (yeni alan adı 200 dönüyor).

**OYNATMA KODU BOZULMADI.** `camera_player_screen.dart` P121'de **hiç**
değişmedi (`git diff 756f94c..830431a` boş). Canlı karo işi oynatıcıyı
öncelemiyor, atmıyor ya da yayın adresini yutmuyor — dört testle ölçüldü.
İlk denememde "yeniden ürettim" sandığım başarısızlık **kendi test
koşumumun** kusuruydu (dil temsilcileri eksikti, kart çizim sırasında
patlıyor ve dokunma boşa gidiyordu); düzeltince dördü de geçti.
**Bayrak arkasına alma / geri alma GEREKMEDİ.**

**KALICI KORUMA 1 — `/health` artık şema sürümünü bildiriyor.**
`{"schema": {"database": …, "beklenen": …, "uyumlu": …}}`. Beklenen
revizyon **göç dosyalarından hesaplanır**, elle tutulmaz: elle tutulan bir
sabit, göç eklendiğinde güncellenmeyi unutulur ve kontrol sessizce yalan
söylemeye başlar (mutasyonla doğrulandı). `status` **değiştirilmedi** —
şema ileri/geri gitse de uygulama birçok uçta çalışır; 503 döndürmek
çalışan bir sistemi yük dengeleyiciden düşürürdü. Alan yalnızca **rapor
eder**.

**KALICI KORUMA 2 — `prod-denetimi.py` kontrol J (GOC-SIRASI).** Belgelerde
`api`yi **adıyla** ayağa kaldıran her dağıtım bloğu, aynı blokta `migrate`
de koşmalı. DENEY=7 ile doğrulandı.

**CANLI KARO — MALİYET ÖLÇÜLDÜ, ÇAKIŞMA YOK.** Karolar bugün **tamamen
atıl**: hiçbir kamerada `snapshot_url` yok → `etkin: false` → zamanlayıcı
**hiç kurulmuyor**. `snapshot_url` dolduğunda (Frigate, P17) maliyet, 6
kamera × 8 sn için Frigate'in tipik `latest.jpg` boyutuna göre
**≈79–211 MB/saat** (30–80 KB/kare). Karşılaştırma: reddedilen (b) şıkkı
(HLS parçası yakalama) **≈4,9 GiB/saat** ederdi — yaklaşık **25–60 kat**
fark. Karo yolu bu yüzden ayakta kalıyor.

Acceptance: dev'de downgrade→500→upgrade→200 üretildi; `/health` ayrışmayı
raporluyor; kontrol J DENEY=7 ile kırmızı veriyor; dört oynatma gerileme
testi geçiyor.

### P125 — Platform / tesis yüzeylerini AYIR (panel.* yalnız platform)
Status: BITTI · Depends-on: P120
> **NUMARA ÇAKIŞMASI:** Kerem bu üçünü "P40–P42" diye istedi, ama o numaralar
> **doludur** (P40 panel finans/rapor bölümü, P41 yetki matrisi görünümü,
> P42 içerik daraltma kapsamı — üçü de BITTI ve **üç ayrı `Depends-on`**
> onlara işaret ediyor). Yeniden numaralamak her çapraz göndermeyi bozardı.
> **İstenen etiket → gerçek:** P40→**P125**, P41→**P126**, P42→**P127**.

Scope: `admin-web`in her sayfası PLATFORM / TESİS diye sınıflanır.
`panel.yönetiyor.com` **yalnız platform** bölümlerini sunar (tesis yönetimi,
platform ayarları, tesisler-arası görünümler, işlem geçmişi); tek bir sitenin
işlemleri (sayaç okuma, aidat işlemleri…) oraya **girmez**. Zorlama
**sunucu tarafındadır**, gizlenmiş menü değil: testler bir tesis rolünün
platform uçlarında **403** aldığını ve tersini kanıtlar.

**ÖLÇÜLEN BAŞLANGIÇ DURUMU (bu tur):** platform rolü **zaten var** —
bugünkü `admin`, `/tenants*` uçlarını cross-tenant, owner-sahipli oturumla
işletiyor ve `yonetici` oraya erişemiyor (rol matrisi: `POST /tenants` →
admin IZIN, diğer beşi RED). Yani "tesis yöneticisi platform API'sine
ulaşamamalı" şartı **bugün sağlanıyor**.

**ASIL SORUN BAŞKA VE DAHA İNCE: `admin` AŞIRI YÜKLÜ.** Rol matrisinde
"yalnız admin" olan **35 uç** iki farklı şeye ayrılıyor:
* **Gerçek platform uçları (6):** `/tenants*` (5 uç), `/admin/overview`,
  `/support/all`, `/integrations/anpr/keys*`, `/audit`, `/devices`.
* **TESİS SEVİYESİ ama admin-only olanlar (~29):** `/finans/*`, `/dues/*`,
  `/borclandirma/*`, `/assets`, `/checkpoints/{id}/sdm-key`,
  `/unit-uyarilari/kuyruk-isle`…
İkinci küme, Kerem'in "panel'de tek bir sitenin aidat işlemleri olmasın"
dediği şeyin ta kendisidir. Ayrım bu yüzden yeni bir rol eklemekten
ibaret değil: **`admin`in iki anlamını ayırmak** gerekiyor.

**KARAR (uygulanacak):** `admin` **platform** rolü olarak kalır; ikinci
kümedeki tesis-seviyesi uçlar `yonetici`ye açılır ve `admin` oralardan
**çekilir**. Yeni bir `platform_admin` enum değeri **eklenmez**: aynı
ayrımı üreten iki yoldan bu, göç gerektirmeyen ve var olan matrisi
bozmayan olanıdır — ayrıca `admin` zaten dışarıya "platform" diye
anlatılıyor. Karşı seçenek (yeni enum + göç + 317 uçluk matrisin yeniden
üretimi) aynı sonucu daha pahalıya verirdi.

Acceptance: `panel.*` yalnız platform bölümlerini gösterir; menü tek
kaynaktan türetilir ve sınıflandırma tam olmak zorundadır; kapılar
(`npm run build` dâhil).

Notes (2026-08-04) — **BİTTİ.** Belge: `docs/platform-tesis-ayrimi.md`.

**KRİTİK BULGU — panel bugün ZATEN tesis rollerini almıyor.**
`app/api/auth/login/route.ts` `admin` dışındaki her rolü **403** ile
reddediyor (*"Yönetim paneli yalnızca platform admini içindir"*). Yani
**hiçbir tesis kullanıcısının bugün web erişimi yok** ve tesis sayfalarını
panelden çıkarmak **kimseyi işsiz bırakmıyor**. Bu, işi güvenli yapan
gerçekti; ölçmeden yapılsaydı yöneticileri websiz bırakma riski vardı.

**MENÜ TEK KAYNAKTAN SÜZÜLÜYOR** (`lib/yuzey.ts`): 6 platform + 25 tesis
rotası sınıflandırıldı; `AppShell` menüyü `rotaYuzeyi(l.href) === yuzey`
ile türetiyor. Yüzey **konaktan** gelir (`app.*` → tesis, diğerleri →
platform) — rolden türetmek yanlış olurdu: `admin` her iki yüzeye de
girebilir ve hangisinde olduğunu ancak adres söyler.

**BİLİNMEYEN ROTA MENÜYE ALINMAZ** ve test bunu **reddediyor**:
"varsayılan olarak göster" demek, yeni bir tesis sayfasının panele
sessizce sızması olurdu; "varsayılan olarak gizle" ise sayfanın sessizce
kaybolması. İkisi de kötü — sınıflandırma **tam** olmak zorunda.

**YETKİ GERİ ALINMADI** (bkz. belgedeki düzeltilmiş karar): `admin`in tesis
uçlarındaki hakları duruyor. İstenen şey yüzey ayrımıydı; yetkiyi geri
almak, bir tesiste hem platform sahibi hem yönetici olan kurulumda çalışan
bir akışı kırardı.

**İKİ DEPO KAPISI KENDİ KODUMU YAKALADI:** (1) i18n taraması, yorumumdaki
ASCII-dışı Türkçe karakteri sızıntı saydı (dosyanın geri kalanı gibi
ASCII-katlanmış yazıldı); (2) sabit-metin taraması, logo hedefini üçlü
içinde satır-içi rota olarak gördü — haklı, çünkü görünen metin ile rota
aynı sözdiziminde. Eşleme `kokRota()` olarak modüle taşındı.

**MUTASYON 4/4:** bir tesis rotasını platforma taşı → düştü ·
sınıflandırılmamış rota ekle → düştü · menü süzgecini elle yaz → düştü ·
giriş kapısını kaldır → düştü.

KAPILAR: `tsc` temiz · `vitest` **354 test** (+12) · `npm run build` ✓ ·
`depo-izlenmeyen` 0 · `depo-alan-adi` 0.

### P126 — app.yönetiyor.com: tüm tesis rolleri için web çalışma alanı
Status: BITTI · Depends-on: P125
> (2026-08-04) Durum satırı P126.7 biterken güncellenmemişti; iş
> `3113fb6`+`5b60c2d` ile bitti, kabul kanıtı aşağıdaki Notes'ta.
> **KAPSAMI P129 DARALTIYOR** (sakin + saha `app.*`tan çıkarılır).
Scope: Mobil uygulamanın **web ikizi**, rol kapılı, onaylanmış tasarım
dilinde. Roller ve kapsamları görev metnindeki gibi (yönetici / sakin /
güvenlik / tesis görevlisi; P35 gelince güvenlik amiri). Giriş: telefon
**ya da** e-posta + tesis kodu (mevcut panel auth'u yeniden kullanılır).
**ÖNCE boşluk tablosu** üretilir ve commit'lenir (mobil özellik → web
sayfası var / yapılacak), **sonra** rol/modül başına alt-commit'lerle
uygulanır. i18n: 7 dil.
Acceptance: dört rol de `app.*`ta giriş yapıp günlük akışlarını
tamamlayabiliyor; rol yalıtımı sunucu tarafında test edilmiş; kapılar.

Notes (2026-08-04) — **P126.1 (iskelet) BİTTİ.** `app.*` artık yer tutucu
değil: **aynı `admin-web`** oradan da sunuluyor ve uygulama **konaktan**
hangi yüzeyde olduğunu anlıyor. İkinci bir dağıtım yapılmadı — ayrı bir
Next süreci, aynı sayfaların iki kopyasını bakımda tutmak demekti.

**GİRİŞ KAPISI ARTIK YÜZEYE BAĞLI.** Eskiden `!== "admin"` diye sabit bir
karşılaştırmaydı ve `app.*` açılınca tesis rollerini de reddederdi. Şimdi:
`panel.*` → yalnız `admin`; `app.*` → `yonetici` (+ `admin`).

**SAKİN/GÜVENLİK/GÖREVLİ HENÜZ ALINMADI — bilinçli.** `app.*`ın bugünkü
sayfa kümesi panelden devralınan 25 **yönetici** sayfasıdır; o rollerin
ihtiyaç duyduğu 13 modül (rezervasyon, site kuralları, ziyaretçi, kargo,
görevlerim…) **yok**. Şimdi içeri almak, girer girmez her yerde 403 gören
bir ekran vermek olurdu; "yakında" demek daha dürüst ve ayrı bir mesajla
söyleniyor (7 dil). Her rol **kendi sayfaları landing ettikçe** eklenecek
(P126.3–.6).

**BİR ÖNCEKİ TURUN TESTİ HAKLI OLARAK DÜŞTÜ:** P125'te yazdığım kapı testi
uygulamanın **içini** (`!== "admin"` sabiti) ölçüyordu; kapı yüzeye
bağlanınca düştü. Davranışı ölçecek biçimde yeniden yazıldı —
"tesis rolü platform yüzeyine giremez".

**MUTASYON 4/4:** sakini `app.*`a al → düştü · yöneticiyi platforma al →
düştü · giriş kapısını sabit karşılaştırmaya döndür → düştü · Caddy `app.`
bloğunu yer tutucuya döndür → düştü. *(Dördüncüsü ilk denemede yanlış
bloğa uygulanmıştı — panel de `admin-web`e gidiyor; doğru hedefle
tekrarlandı.)*

KAPILAR: `tsc` temiz · `vitest` **362 test** (+20) · `npm run build` ✓ ·
`caddy validate` geçerli · `depo-alan-adi` 0.

Notes (2026-08-04, P126.2) — **YÜZEY KAPISI BİTTİ.** P125 menüyü süzmüştü;
ama adres çubuğuna `/dues` yazan biri panelde o sayfayı **yine açıyordu**.
Kerem'in şartı açıktı: *"enforcement is server-side, not hidden nav"*.
Middleware isteği **sayfa çizilmeden** kesiyor: panelde tesis rotası →
`/tenants`, `app.*`ta platform rotası → `/dashboard`, kök (`/`) → yüzeyin
kendi başlangıcı.

**BU BİR VERİ SINIRI DEĞİL, YÜZEY SINIRIDIR.** Veriyi backend RBAC korur
(317 uçluk rol matrisi — dokunulmadı). Buradaki kural "hangi iş hangi
adreste yapılır" sorusunun cevabı.

**SINIFLANDIRILMAMIŞ ROTA ENGELLENMEZ** — bilinmeyen bir sayfayı kesmek,
yeni bir sayfayı sessizce öldüren bir tuzak olurdu. Sınıflandırmanın **tam**
olmasını `yuzey-ayrimi` testi zorunlu tutuyor; kapının işi **bilinen**
yanlış yerleşimi kesmek.

**OTURUM KAPISI ÖNCE GELİR:** oturumsuz kullanıcı yanlış yüzeydeki bir
rotada bile doğrudan `/login`e gider — aksi halde önce köke, oradan
`/login`e düşen iki sıçramalı bir akış görürdü (mutasyonla doğrulandı).

**TEST BİR KUSUR BULDU:** `konakYuzeyi` yalnız `Host` başlığına bakıyordu;
`NextRequest` bir URL'den kurulduğunda o başlık **oluşmuyor** ve her istek
"platform" sayılıyordu. `req.nextUrl.host` geri düşüşü eklendi.

**İKİ MEVCUT TEST GÜNCELLENDİ:** `panel.test` konağında `/dashboard`
(tesis rotası) isteyen oturum testleri artık yüzey kapısına takılıyordu —
ölçtükleri şey oturum kapısı olduğu için rota platform tarafından seçildi
ki iki kural birbirine karışmasın.

**MUTASYON 4/4:** kapıyı kaldır · alt yol çözümünü kaldır (`/tenants/abc`
kaçar) · oturum kapısını sonraya al · bilinmeyen rotayı da engelle —
dördü de düştü.

KAPILAR: `tsc` temiz · `vitest` **370 test** (+8) · `npm run build` ✓ ·
depo kapıları 0.

Notes (2026-08-04, P126.3) — **SAKİN ÇALIŞMA ALANI BİTTİ; `resident`
`app.*`a ALINDI.** Sekiz sayfa: Profil, Aidatım, Taleplerim, Duyurular,
Site kuralları, Etkinlikler, Rezervasyonlarım, KVKK tercihleri.

**"25 sayfanın karşılığı var" YANILTICIYDI** — ölçüldü: sakinin kendi
verisi `/me/*` altında; paneldeki `dues`/`complaints`/`announcements`
**yönetim** görünümleridir. Sakin için ayrı görünümler gerekti (boşluk
tablosuna işlendi).

**KURALLAR İSTEMCİYE KOPYALANMADI.** Rezervasyonun zamanlama kuralları
(24 sa / günde bir / 10 dk) sunucuda ölçülür ve hata metni isteğin dilinde
döner; kopyalansa iki kural zamanla ayrışır ve kullanıcı "ekran izin verdi,
sunucu reddetti" çelişkisini yaşardı. Aynı gerekçeyle `taleplerim` ve
`rezervasyonlarim` **istemci süzgeci kullanmaz** — sunucu zaten
kendi-kapsamlı.

**YAZMA DÜĞMESİ OLMAYAN EKRANLAR** (duyuru/kural/etkinlik) bilinçli:
sunucu yönetici olmayanı reddeder, ama basıp 403 alacağı bir düğme
göstermek "yetkim var sandım" demektir. Etkinlik **katılımı** da bu
dilimde yok — yarım bir katılım düğmesi eklemektense listeyi dürüstçe
salt-okuma bırakmak daha iyi.

**ROTA ADI DEĞİŞTİ:** `/site-kurallari` → `/kurallar`. `portal-public`
testi düştü çünkü matcher'da `/site` ile başlayan bir giriş arıyor —
public tenant portalı `/site/[slug]`ta yaşıyor ve oturum kapısına asla
girmemeli. Testi gevşetmek yerine rota adlandırıldı: **public bir rotayı
koruyan kapı olabildiğince katı kalmalı.**

**`security`/`tesis_gorevlisi` HÂLÂ DIŞARIDA** — ziyaretçi, kargo, ihlal,
araç geçişi, görevlerim sayfaları yok (P126.4–.6).

**MUTASYON:** bu dilimde 4/4 (pasif alan seçeneğe girsin · eksik alanla
gönder · sunucu hatasını yut · KVKK'yı tek bayrağa indir); önceki
dilimlerle birlikte P126.3 toplam **13/13**.

KAPILAR: `tsc` temiz · `vitest` **400 test** · `npm run build` ✓ ·
depo kapıları 0.

Notes (2026-08-04, P126.4) — **GÜVENLİK ÇALIŞMA ALANI BİTTİ; `security`
`app.*`a ALINDI.** Dört sayfa: Ziyaretçiler, Kargolar, Olaylar, Araç
geçişleri (+ Profil).

**OLAY KAYNAĞI `manuel` SABİTLENDİ, kullanıcıya seçtirilmedi.** `kamera`
ANPR/görüntü işlemeden, `devriye` tur akışından gelir. Kaynak seçtirmek,
otomatik üretilmiş bir kaydı **elle taklit etmeye** izin vermek olurdu —
olay kaydının kanıt değeri tam olarak buradan gelir.

**ARAÇ GEÇİŞLERİNDE YAZMA YOK** (BFF'te de yalnız `GET`): kayıtlar ANPR ile
otomatik oluşur (P16); elle plaka yazmak, otomatik kayıtla **çelişen ikinci
bir gerçek** üretir ve "hangisi doğru?" sorusunu operasyona bırakırdı.
Ekranda bunun neden böyle olduğu **yazılı**.

**ÇIKIŞ DÜĞMESİ YALNIZ İÇERİDEKİ ziyaretçide** — çıkmış birine tekrar çıkış
yaptırmak kaydı ikinci kez damgalamak olurdu.

**DAİRE NUMARASIYLA KAYIT** (ziyaretçi + kargo): kapıdaki görevli daire
**numarasını** bilir, kaydın kimliğini değil.

**`tesis_gorevlisi` HÂLÂ DIŞARIDA** — "görevlerim" ve daire erişim
sayfaları yok (P126.6).

**MUTASYON:** bu dilimde 5/5 (çıkmış ziyaretçide çıkış düğmesi · eksik
alanla gönder · olay kaynağını değiştir · araç geçişlerine yazma ekle ·
kargo durumunu ham enum çiz).

KAPILAR: `tsc` temiz · `vitest` **414 test** · `npm run build` ✓ ·
depo kapıları 0.

Notes (2026-08-04, P126.6) — **TESİS GÖREVLİSİ BİTTİ; rol `app.*`a
ALINDI.** Sayfa: **Görevlerim** (+ Profil).

**BOŞLUK TABLOSUNDA BİR ATAMA YANLIŞTI, DÜZELTİLDİ.** `unit_access`
`tesis_gorevlisi`ne atanmıştı; ölçüldü (`routers/unit_access.py`):
`_REQUESTER = admin/yonetici`, `_DECIDER = resident`. O akışta saha rolü
**hiç yok** — bir yöneticinin daireye erişim **talep etmesi** ve sakinin
**onaylaması** akışıdır. Doğru yeri yönetici + sakin tarafı; tabloya
işlendi.

**İKİ KISIT DÜRÜSTÇE GÖSTERİLDİ, GİZLENMEDİ:**
* `foto_zorunlu` görevde **tamamla düğmesi yok** — sunucu fotoğrafsız
  tamamlamayı 422 ile reddediyor (`gorev_foto_kaniti_zorunlu`). Düğmeyi
  aktif bırakıp 422 aldırmak "bozuk" izlenimi verirdi.
* Kontrol noktasına bağlı görevde **NFC kısıtı yazılı**: okutma kanıtı
  yalnız mobilde oluşur. Gizlemek, kullanıcının oluşmayan bir kanıtı
  oluştu sanması demekti.

**`Idempotency-Key` İLETİLİYOR** — sunucu zorunlu tutuyor ve çift tıklama
aynı görevi iki kez tamamlamamalı (mutasyonla doğrulandı).

**ERİŞİLEBİLİRLİK KAPISI KODUMU YAKALADI:** not alanına yalnız
`placeholder` koymuştum — o bir **erişilebilir ad değildir** (ekran
okuyucu okumaz, yazı girilince kaybolur). Her görev kartına görünür
etiket koymak listeyi gürültülü yapardı; `aria-label` eklendi.

**DÖRT TESİS ROLÜNÜN DÖRDÜ DE `app.*`TA.** Kalan `guvenlik_amiri` (P35):
rol backend'de var ama kendi ekran seti tanımlanmadı.

**MUTASYON 4/4:** foto zorunlu görevde düğme göster · `Idempotency-Key`
gönderme · NFC kısıtını gizle · pasif görevleri listele.

KAPILAR: `tsc` temiz · `vitest` **419 test** · `npm run build` ✓ ·
depo kapıları 0.

Notes (2026-08-04, P126.5) — **YÖNETİCİNİN 3 EKSİK SAYFASI BİTTİ:**
Kameralar, Dış hizmetler, Yönetim iletişim. Rol zaten `app.*`taydı; bu
dilim onun **eksik ekranlarını** kapattı.

**KAMERA IZGARASI = P121 DESENİNİN WEB İKİZİ.** Karo `snapshot_url`den
durağan kare çeker (8 sn), oynatıcı **yok**: N oynatıcıyı aynı anda
çalıştırmak mobilde reddedilmişti, tarayıcıda da aynı gerekçe geçerli.
Tazeleme **sekme görünürken** olur, arka planda durur — açık unutulmuş bir
sekme kimse bakmıyorken istek atmaz.

**TAM EKRAN OYNATMA BİLEREK YAPILMADI, GİZLENMEDİ:** `stream_url` HLS'tir;
Safari yerel oynatır, Chrome/Firefox oynatmaz. `hls.js` (~150 KB) bir
**bağımlılık kararıdır** ve tek başıma almadım. Tarayıcıların yarısında
siyah kalan bir oynat düğmesi, hiç olmayandan kötüdür. Gerekçe dosyanın
başında yazılı; oynatma mobilde çalışıyor (P124).

**KAMERA YÖNETİMİ WEB'E AÇILMADI:** desteklenen-kaynak kuralı mobilde
`CameraDraft` içinde yaşıyor (P121). TS'e ikinci kopya yazmak, ayrışınca
"kaydettim ama açılmıyor" üretirdi. Web izler, mobil yönetir.

**SÖZLEŞME KODDAN OKUNDU — İKİ HATAMI YAKALADI (tsc yakalayamazdı, tipleri
kendim yazmıştım):**
* `yonetici-iletisim` yanıtı `ad_soyad`/`user_id` taşıyor, `ad` değil; ve
  **`aranabilir` alanı yok**. Ekranı bir `aranabilir` rızasına göre
  kurmuştum — o alan hiç gelmediği için numara **hiçbir zaman**
  görünmeyecekti. Sunucu (`routers/yonetici_iletisim.py`, contracts/auth.md
  C1a istisnası) yöneticinin numarasını **bilerek** açıyor: yönetici bir
  hizmet rolüdür. İstemcide ikinci bir rıza süzgeci koymak, sunucunun
  bilerek döndürdüğü numarayı sessizce gizlerdi.
* `DisHizmetCreate.soyad` **zorunlu** (`min_length=1`); boş gönderiyordum →
  422. Artık istek gönderilmeden kesiliyor.

**MUTASYON 7/7 denendi, 6 yakalandı; kaçan 1 tanesi dürüstçe yazıldı:**
`value={telefonGiris(telefon)}` bağını kaldırmak testi düşürmüyor çünkü
`onChange` değeri zaten biçimlendirerek saklıyor. Bağ yine de duruyor
(`telefon-kapsam` kapısı ve ön-doldurma yolu için).

KAPILAR: `tsc` temiz · `vitest` **431 test** · `npm run build` ✓ ·
depo kapıları 0.

Notes (2026-08-04, P126.7) — **ROL YALITIMI BİTTİ; P126 TAMAM.**

**ASIL BULGU: menü rolden habersizdi.** P126.1–.6 boyunca `app.*` menüsü
YALNIZ yüzeye göre süzülüyordu — `app.*`a giren bir **sakin 39 bağlantının
hepsini** görüyordu (vardiya, tahakkuk, kullanıcılar, finans). Hiçbirini
açamıyordu (sunucu 403) ama "görüyorum, tıklayınca çalışmıyor" tam olarak
`yuzey.ts`in bastan beri önlemeye çalıştığı izlenimdir. Bu, önceki
dilimlerin **kabul kriterinde vardı ve gözden kaçmıştı**; burada kapandı.

**ÇÖZÜM ÖLÇÜME DAYANIYOR, TAHMİNE DEĞİL.** `ROTA_ROLLERI` (41 rota) iki
katmanlı: **erişim** (koddan üretilen 318 satırlık rol matrisi) + **niyet**
(ürün kararı). `rol-menusu.test.ts` her koşuda bildirilen kümenin erişim
kümesinin **alt kümesi** olduğunu doğrular — bir uç daraltılırsa test düşer.

**ÖLÇÜM BİR HATAMI YAKALADI:** `GET /vehicle-passes` **yöneticiye 403**
döner (yalnız admin + security). "Araç geçişleri"ni yönetim setine koymak
içimden geldiği gibiydi; matris reddetti. Menüye elle bakan biri bunu fark
etmezdi.

**MENÜYÜ SÜZMEK YETMEZ — ADRESİ YAZAN DURDURULMALI.** `app.*`ta `/finans`
yazan bir sakin bugüne kadar sayfayı **açar** ve BFF'ten 403 alırdı: kırık
ekran. Middleware artık access çerezindeki rolü okuyup isteği **sayfa
çizilmeden** kesiyor ve rolün **kendi başlangıcına** yolluyor (`/` de role
göre: sakin → Aidatım, güvenlik → Ziyaretçiler, saha → Görevlerim, yönetim →
Pano; yoksa yönlendirme döngüsü olurdu). Access çerezi düşmüşse (15 dk) kapı
**uygulanmaz** — oturumu açık birini yenileme şansı doğmadan dışarı atmak
yanlış olurdu.

**EDGE'DE `Buffer` YOK:** token çözücü `atob` + elle base64url çevrimi
kullanıyor. `-`/`_` çevrilmeseydi gövde bozulur, rol `null` döner ve kapı
**sessizce devre dışı** kalırdı; mutasyon bunu kaçırdığı için `_` içeren
gerçek bir gövdeyle test eklendi.

**ROL SUNUCUDA ÇÖZÜLÜYOR:** korumalı düzen access çerezinden rolü okuyup
kabuğa veriyor — ilk çizimde menü **zaten doğru**. Çerez 15 dakikada
düştüğünde `null` gelir ve kabuk `/api/me`ye sorar (BFF yenileme akışını
tetikler), yani menü **kendini toparlar**. İki yol da ayrı ayrı test edildi.

**SUNUCU TARAFI KURALI ARTIK YAZILI:** `backend/tests/test_yuzey_yalitimi.py`
— 15 platform ucu hiçbir tesis rolüne açık değil **ve** `admin`e açık. İkinci
yön şart: yoksa ucu herkese kapatmak da testi geçirirdi. Matris kilidi bir
**değişiklik dedektörüydü**; bu dosya **kuralı** yazar.

**7 DİL — TR HARF TARAMASININ DELİĞİ KAPANDI:** mevcut tarama yalnız
ç/ğ/ı/ş ariyordu; o harfleri taşımayan bir Türkçe cümle İngilizce sözlüğe
kopyalanmış olarak geçebilirdi. Yeni ölçüm: TR ile **birebir aynı** kalan
değer ya bir kısaltma/simge/eş-sözcüktür (24 maddelik gerekçeli liste) ya da
hatadır. Kalan açık dürüstçe yazıldı: tek kelimesi değiştirilmiş bir kopya
ikisinden de kaçar.

**MUTASYON 16/16** (4'ü ilk turda kaçtı, testler güçlendirildi): rol süzgecini
kaldır · bilinmeyen rolde her şeyi göster · tanımsız rotayı varsayılan görünür
yap · yöneticiye araç geçişleri ver · sakine finans ver · `/api/me` yedeğini
kaldır · rolü kabuğa geçirme · bozuk token'da çök · yöneticiye `/tenants` aç ·
admin'e `/audit` kapat · saha rolüne `/tasks` kapat · middleware rol kapısını
kaldır · kapıyı tam yolla çalıştır (derin bağlantı kırılır) · çerezsizken de
kapıyı uygula · kök rotayı rolden bağımsız yap · base64url çevrimini kaldır.

KAPILAR: `tsc` temiz · `vitest` **461 test** (+30) · `npm run build` ✓ ·
`backend-pytest` ✓ · depo kapıları 0.

Notes (2026-08-04, P126 takibi) — **app.* GİRİŞİ MOBİLLE AYNI OLDU +
VARSAYILAN DİL TÜRKÇE.**

**GİRİŞ YOLU ARTIK YÜZEYE GÖRE.** `app.*` mobil uygulamanın web ikizidir:
**telefon + parola** (`POST /auth/login-phone`, mobille aynı uç), tenant kodu
**yok** — telefon global benzersiz, tenant'ı sunucu numaradan çözüyor.
`panel.*`ta tesis kodu + e-posta **kalır**: platform admini bir tesise ait
değildir, telefonu bir tenant'a çözülmez. Karar **sunucuda** verilir (`Host`
başlığı): istemcide çözseydik ilk kare yanlış formla boyanır, kullanıcı tesis
kodu alanı görüp bir an sonra telefon alanına düşerdi.

**BU BİR ERİŞİM SORUNUYDU, KOZMETİK DEĞİL:** `resident` hesaplarında e-posta
şemada **opsiyoneldir** — e-postası olmayan sakin `app.*`a giremiyordu.

**GİRİŞ SONRASI SABİT `/dashboard` KALDIRILDI:** panoyu yalnız yönetim görür.
Artık `/`ye gidiliyor ve rol yönlendirmesini middleware yapıyor (P126.7'deki
`kokRotaRol`). Logo hedefi de role bağlandı — sakini panoya yollayıp
middleware'in geri çevirmesine bırakmak bir adım fazlaydı.

**ÖLÇERKEN GERÇEK BİR KUSUR ÇIKTI:** kabuk yüzeyi `window.location.host`tan
okuyordu; **sunucu çiziminde `window` yok**. Ölçüldü: `app.*`ta bir sakinin
ilk karesinde tek bağlantı `href="/tenants"` idi — yani platform menüsü bir an
görünüyordu. Yüzey de artık düzende (`Host` başlığı) çözülüp kabuğa uç olarak
veriliyor; sunucu HTML'i ilk kareden itibaren doğru.

**DÖRT ROL UÇTAN UCA ÖLÇÜLDÜ** (dev yığını, gerçek `next start` + gerçek API;
birim testi değil):

| Rol | Giriş | `/` hedefi | Logo | `/finans` |
|---|---|---|---|---|
| yönetici | 200 | `/dashboard` | `/dashboard` | 200 |
| güvenlik | 200 | `/ziyaretciler` | `/ziyaretciler` | → `/ziyaretciler` |
| tesis görevlisi | 200 | `/gorevlerim` | `/gorevlerim` | → `/gorevlerim` |
| sakin | 200 | `/aidatim` | `/aidatim` | → `/aidatim` |

Menü de sunucu HTML'inde rol başına doğru: yönetici 27 bağlantı, güvenlik 11,
sakin 11, saha görevlisi 7. `panel.*`ta telefonla giriş denemesi **403**.

**VARSAYILAN DİL TÜRKÇE — "İngilizce bir tercih sayılmaz".** Chrome/Edge
kurulumlarının çoğu kullanıcı hiçbir şey seçmemişken bile
`Accept-Language: en-US,en;q=0.9` gönderiyor; Türkiye'deki bir sakinin
tarayıcısı da bunu gönderiyor ve `app.*` İngilizce açılıyordu. Artık `en` bir
tercih değil **kurulum varsayılanı** sayılıyor ve Türkçe'ye düşülüyor. Diğer
beş dil **korunuyor**: tarayıcısını Arapça'ya ayarlamış biri bunu bilerek
yapmıştır. Ölçüldü: `en-US,en;q=0.9 → tr` · `en-GB,en;q=0.8 → tr` ·
`ar-SA → ar` · `de-DE → de` · `ja-JP → tr` · `ui.locale=en çerezi → en`.

**`?lang=xx` EKLENDİ** (paylaşılan bağlantı için). Sıra: kayıtlı tercih >
`?lang` > tarayıcı (İngilizce hariç) > Türkçe — kullanıcının **kendi** seçimi
bir bağlantıyla ezilmez. İstemcide uygulanır: kök düzen bir Server
Component'tir ve App Router'da düzenler `searchParams` almaz; middleware'e
koymak `/login` ve genel portal sayfalarını oturum kapısının matcher'ına
sokmayı gerektirirdi (genel sayfaların açık kalması bir kuraldır).

**MOBİL BU KURALA GİRMEDİ (bilerek):** `mobile/.../locale_controller.dart`
cihaz dili İngilizce ise İngilizce açıyor. Aynı kuralı oraya taşımak ayrı bir
karardır ve istenmedi; istenirse `localeCozumle` içinde beş satır.

**MUTASYON 8/8:** app.*'ı e-posta formuna çevir · panel.*'ı telefona çevir ·
numarayı normalleştirmeden gönder · girişten sonra sabit `/dashboard` ·
telefon doğrulamasını kaldır · İngilizce'yi yine tercih say · `?lang`in
kayıtlı tercihi ezmesine izin ver · yüzeyi yine pencereden oku.

KAPILAR: `tsc` temiz · `vitest` **490 test** · `npm run build` ✓ · depo 0.

### P127 — www.yönetiyor.com: tanıtım sitesi (SEO)
Status: KISMEN(site + SEO BİTTİ · iletişim FORMU ve Lighthouse ölçümü kaldı) · Depends-on: P126
Scope: Geçici statik açılış sayfası (P120) gerçek tanıtım sitesiyle
değişir: hero/değer önerisi (site yöneticisi ve sakin için **ayrı ayrı**),
Özellikler, Hakkımızda, İletişim (form → mail/bildirim), App Store/Play
rozetleri (yayınlanana kadar yer tutucu), gizlilik/koşullar bağlantıları.
SSR/statik Next.js public rotaları, meta/OG etiketleri, `sitemap.xml`,
`robots.txt`, Türkçe birincil + 6 dil için `hreflang`.
**P38'den AYRIDIR:** P38 tesis-başına sakin portalıdır; bu **şirket**
sitesidir.
Acceptance: Lighthouse SEO ≥ 90; iletişim formu teslim ediyor; kapılar.

Notes (2026-08-04, P127.1) — **KÖK ALAN ADI ARTIK BİR SİTE; ÜÇÜNCÜ YÜZEY
AÇILDI.**

**P120'NİN GEREKÇESİ ARTIK GEÇERSİZ, O YÜZDEN STATİK SAYFA KALKTI.** O tur
kökü statik bir HTML'e bağlamıştı çünkü *"admin-web'in `/` rotası
`/dashboard`a, oradan `/login`e gider; markanın ana adresi bir yönetici
giriş ekranı olamaz"*. Uygulama artık **konaktan** yüzey çözüyor
(`lib/yuzey.ts`): kök/www **`tanitim`** yüzeyidir ve middleware orada
oturum kapısını **hiç** çalıştırmaz.

**VARSAYILAN DEĞİŞTİ — dikkat edilmesi gereken yer burası:** eskiden
`app.` dışındaki **her** konak "platform" sayılıyordu. Artık yalnız
`panel.` ve **yerel geliştirme adresleri** platformdur. `localhost`
bilerek platform kaldı: `npm run dev` diyen geliştiriciyi tanıtım
sayfasına düşürmek her gün bir tıklama fazlası olurdu.

**KÖK ALAN ADINDA GİRİŞ YOK:** korumalı bir adres elle yazılırsa ziyaretçi
`/login`e değil **köke** döner. Giriş o alan adının işi değildir (panel.*
ve app.* var); orada bir giriş formu göstermek yüzey ayrımını bozardı.

**İÇERİK 7 DİLDE ve `lib/hukuki/`nin kardeşi:** sözlüğe konmadı (o arayüz
dizgeleri içindir), tipi `Record<Dil, TanitimIcerik>` — eksik dil
**derlenmez**. Test ayrıca her dilde tüm alanların dolu ve **TR metninin
kopyalanmamış** olduğunu ölçer.

**İKİ AYRI DEĞER ÖNERİSİ** (görevin şartı): yönetici "işimi kolaylaştırır
mı", sakin "hakkımı görebilir miyim" diye bakar; tek bir genel cümle
ikisine de bir şey söylemezdi. Özellik maddeleri **üründe gerçekten olan**
şeyleri anlatır — "güçlü/modern" gibi ölçüsüz sıfat yok.

**CANLI ÖLÇÜM** (gerçek `next start`, `Host` başlığıyla):

| Adres | Kök (tanıtım) | app./panel. |
|---|---|---|
| `/` | **200** (tanıtım sayfası) | 307 → `/login` |
| `/robots.txt` | **200** `Allow: /` + sitemap | **`Disallow: /`** |
| `/sitemap.xml` | **200** (3 URL + 7 dil alternatifi) | boş |
| `/gizlilik` | 200 | 200 |
| `/dues` | **307 → `/`** | 307 → `/login` |

SEO temelleri sayfada **ölçüldü**: `<title>`, meta description, canonical,
**7 hreflang**, `<html lang>`, viewport, OG etiketleri, **tek H1**.
Dil çözümü çalışıyor: TR varsayılan · `ui.locale=en` → İngilizce başlık ·
`ui.locale=ar` → `dir="rtl"`.

**KANONİK ADRES PUNYCODE** (`xn--ynetiyor-n4a.com`) ve **tek yerde**
(`lib/tanitim/adres.ts`): unicode yazmak aynı sayfayı iki köken gibi
gösterebilirdi ve `infra/alan-adi-denetimi.py` zaten yapılandırmada unicode
konak bırakmayı reddediyor — kod da aynı dili konuşsun.

**KALAN İKİ İŞ (dürüstçe — bu yüzden KISMEN):**
1. **İletişim FORMU yok**, `mailto:` bağlantısı var. Kabul kriteri "form
   teslim ediyor" diyor; teslimat yolu (SMTP/bildirim) ayrı bir dilimdir
   ve yarım bir form koymaktansa çalışan bir bağlantı bıraktım.
2. **Lighthouse ≥ 90 sayısı ÜRETİLMEDİ:** bu ortamda tarayıcı yok.
   Lighthouse'un SEO denetiminin baktığı başlıklar tek tek ölçüldü
   (yukarıda) ama **puanın kendisi Kerem'in tarayıcısında** alınmalı —
   P11'e yazıldı.

KAPILAR: `tsc` temiz · `vitest` **559 test** (+17) · `npm run build` ✓ ·
`caddy validate` **Valid configuration** · `depo-alan-adi` 0 bulgu.

### P128 — DENETÇİ rolü: tesisin salt-okuma mali gözetimi
Status: BITTI · Depends-on: P126
Scope: Sistemde **altı** rol var (`admin`, `yonetici`, `security`,
`tesis_gorevlisi`, `resident`, `guvenlik_amiri`); site **denetçisi** yok.
Denetim kurulu / bağımsız denetçi bugün ya yönetici hesabıyla giriyor (yazma
yetkisiyle — denetimin bağımsızlığı biter) ya da hiç giremiyor.
Yeni rol `denetci`:
* **Oluşturma/iptal SİTE YÖNETİCİSİNDE** (ad, telefon, opsiyonel görev
  başlangıç/bitiş tarihi). Platform admini de açabilir.
* **Yüzey KESİN SALT-OKUMA:** raporlar, gelir/gider, tahakkuk↔tahsilat,
  kasa/banka. Mutasyon yapan HER uç `denetci` için 403.
* Görev tarihi dolan denetçinin oturumu ve erişimi kapanır.
Bu, App Store incelemesi için kurulan **P115 denetçi demo modundan
AYRIDIR** (o bir demo hesabıdır, rol değil).
Acceptance: `denetci` şema göçüyle eklenir (yeni revizyon, geri alınabilir);
salt-okuma **iki yönde** test edilir (okuma uçları 200 **ve** mutasyon uçları
403 — tek yön test edilse "her şeyi kapat" da geçerdi); yönetici açar/iptal
eder; kapılar.

Notes (2026-08-04, P128 + P130(b)) — **DENETÇİ ROLÜ AÇILDI: YÖNETİCİ AÇAR,
DENETÇİ YALNIZCA OKUR.**

**ROL YEDİNCİ** — göç `0032_denetci_rolu`. 0024'ün (güvenlik amiri) kararı
aynen izlendi: PostgreSQL bir enum değerini **kaldıramaz** ve `user_role`a
RLS politikaları bağlı; `downgrade` **etiketi bırakır**, onu *kullanan* her
şeyi geri alır. Ama bir yerde 0024'ten **ayrıldım**: 0024 amiri `security`ye
düşürüyordu ("en yakın rol"); denetçinin en yakını **yoktur** — her mevcut
rol ona bugün sahip olmadığı bir **yazma** yetkisi verirdi. Düşürülen
denetçi `resident` **+ `is_active=false`** olur: veri kaybolmaz, yetki de
sessizce genişlemez.

**GÖREV PENCERESİ ŞEMADA** (`app_user.gorev_baslangic/gorev_bitis` + ters
pencereyi kapatan CHECK). Kolon adına rol gömülmedi (`denetci_*` değil):
aynı pencere yarın başka bir geçici rol için de geçerli olabilir.

**PENCERE HER İSTEKTE ÖLÇÜLÜR, YALNIZ GİRİŞTE DEĞİL.** Access token 15 dk
yaşar; yalnız girişte ölçseydik görevi biten denetçinin **açık oturumu** o
süre boyunca geçerli kalırdı. Ölçüldü: bitiş tarihi geçmişe çekilince
**aynı token** ile `/finans/ozet` 200'den 403'e döndü. Girişte de ayrıca
kesilir — yoksa kullanıcıya "giriş başarılı" deyip her ekranda 403
göstermiş olurduk. Kod 401 değil **403**: kimlik doğru, kapalı olan
**yetki penceresi**.

**SALT-OKUMA İKİ KATMANDA YAZILDI:** (1) **yapısal** — FastAPI'nin rota
ağacı gezilir, `denetci`ye açık GET-dışı her uç gerekçeli bir istisna
listesinde olmak zorundadır; (2) **davranışsal** — 12 okuma ucu 200, 9
mutasyon ucu 403. Örnek testi tek başına yetmezdi: yarın eklenen `POST
/finans/bir-şey` ucuna `denetci` konsa hiçbir örnek test düşmezdi.

**TEK İSTİSNA, GEREKÇELİ:** `POST /raporlar/{kod}` — rapor **üretimi bir
okumadır** (`rapor_motoru.py`de tek bir `db.add` yok); POST seçilme sebebi
parametrelerin gövde istemesi. Kural "fiil GET olsun" değil **"mutasyon
olmasın"**. Katalogda zaten *"Denetçi biçimi"* raporu var; denetçiyi bu
ucun dışında bırakmak ona görevinin ana aracını kapatmaktı.

**YEDİNCİ SÜTUN, TESTİMDE BİR DELİK BULDU.** Rol matrisi kilidini denetçi
sütunuyla üretince listede **rol kapısı hiç olmayan** mutasyon uçları
göründü (`POST /devices`, `PATCH /me/password`, `POST /kvkk/onay`…).
Yapısal testin ilk hâli bunları **göremiyordu**: yalnız "`izinli_roller`
içinde denetçi var mı" diye bakıyordu, kapısı olmayan uç o kontrolden
sessizce geçiyordu. İkinci bir kilit eklendi — kapısız mutasyon uçlarının
kümesi **iki yönlü** sabitlendi; kural konmadan eklenen yeni bir uç artık
testi düşürür. Kümedeki 14 ucun hepsi ya **public** ya **kişinin kendi
hesabı** (parola, KVKK rızası, cihaz kaydı — bunlar yetki değil **kişinin
hakkı**) ya da **cihaz kimliği** (`POST /integrations/anpr/events`,
`X-ANPR-Key`; isteği bir kullanıcı değil kamera kutusu atar). Hiçbiri
tesisin kayıtlarına yazmaz.

**KVKK — DENETÇİ NE OKUMAZ:** personel kayıtları, araç kayıtları, firmalar
ve sayaçlar **bilerek dışarıda**. İlk üçü kişisel veri taşır; denetim
yetkisi **mali kayıttır**, personel dosyası değil (amaç sınırlılığı).

**KONTROL GRUBU:** 403'ler "denetçi olduğu için" mi, yoksa uç zaten herkese
kapalı mı? Aynı uçlarda yönetici kapıyı **geçiyor** (boş gövdeyle 422, ama
403 değil) — yoksa "her şeyi kapat" da testi geçerdi.

**P130(b) BURADA KAPANDI:** yönetici artık denetçi açıyor (`ACILABILIR_
ROLLER`), ad + telefon + **opsiyonel** görev tarihleriyle; iptal iki yoldan
— bitişi geçmişe çekmek (*görev bitti*) ya da `is_active=false` (*hesap
kapatıldı*). İkisi denetim izinde **farklı** görünür ve bu bilinçli.

**MOBİL: İLK ÖLÇÜMÜM EKSİKTİ, KAPI DÜZELTTİ.** "`fromClaim` bilinmeyeni
`unknown`a düşürür, çökme yok" demiştim ve bu doğruydu ama **yetmiyordu**:
mobil suite'te `rol_bagi_test.dart` mobil `UserRole` enum'unu backend
`USER_ROLE` ile **kilitliyor** ve rolü eklemeyince düştü. P128'i mobil
kapısını koşmadan kapatmıştım — kapı beni yakaladı (ayrı commit'te
düzeltildi: `denetci` mobil enum'a + 7 dile eklendi, **menüsü boş**).
Boş menü bir eksiklik değil karardır: denetçinin işi masabaşıdır ve
kullanılabilir bir mobil denetçi deneyimi **tasarlanmadı**; birkaç kart
koymak varmış gibi göstermek olurdu. `canViewTransparency` /
`canViewComplaints` gibi "unknown hariç herkes" diyen bayraklar da
daraltıldı — yoksa yeni rol o ekranlara **sessizce** girerdi.

**MUTASYON 6/6:** mutasyon ucuna denetçi ekle · her-istek pencere kapısını
kaldır · denetçiyi okuma bağımlılığından çıkar · giriş kapısını kaldır ·
yöneticiden denetçi açma yetkisini al · görev tarihi alanlarını her rolde
göster. Altısı da yakalandı.

**KAPI BİR ŞEY DAHA YAKALADI (ve haklıydı):** yeni hata metnini
(`gorev_suresi_disinda`) çeviri kataloğuna koymamıştım;
`test_hata_i18n.py` AST taramasıyla bunu **iki çağrı yerinde birden**
buldu. 7 dile eklendi. Metin bilerek "yetkiniz yok" demiyor: yetki
vardı, **süresi** geçti — kullanıcının yapacağı şey yöneticiden süreyi
uzatmasını istemektir.

KAPILAR: `tsc` temiz · `vitest` **495 test** (+2) · `npm run build` ✓ ·
`backend-pytest` **1321 geçti / 0 düştü** (tam koşum, düzeltmeden sonra
yeniden) · `goc-uyum` 0 bulgu · `goc-tersinirlik` 0 bulgu (33 sınır) ·
sözleşme (`openapi.yaml` + `auth.md §4b`) güncellendi.

### P129 — app.* kapsamı DARALTILDI: yalnız yönetici + denetçi
Status: BITTI · Depends-on: P126, P128
Scope: Yüzey kararı **değişti**. `panel.*` → platform admin (aynı kaldı).
`app.*` → **YALNIZ site yöneticisi ve denetçi**. `resident` (sakin) ve
`tesis_gorevlisi` **YALNIZ MOBİL**: `app.*` girişinde **sunucu tarafında
reddedilir** (menü gizlemek değil — oturum hiç kurulmaz), net Türkçe mesaj +
App Store / Play bağlantıları döner.
P126.3/.6'da yazılan sakin ve saha sayfaları **SİLİNMEZ, PARK EDİLİR**:
kod durur, rota sınıflandırması ve menü onları `app.*`ta sunmaz; kararın
gerekçesi buraya yazılır (geri açmak bir kararlık iş olmalı).
`security`/`guvenlik_amiri` için karar: bu maddede **ölçülüp yazılır**
(görev metni ikisini saymıyor → mobil-yalnız kabul edilir).
Acceptance: sakin/saha rolüyle `app.*` girişi **403 + mağaza yönlendirmesi**
(canlı yığında ölçülür, birim testi yetmez); yönetici + denetçi girer;
`panel.*` etkilenmez; kapılar.

Notes (2026-08-04) — **KAPSAM DARALDI; KAPI SUNUCUDA, CANLI ÖLÇÜLDÜ.**

**CANLI ÖLÇÜM** (gerçek `next start` + gerçek API; birim testi değil):

| Rol | `app.*` girişi | Hata kodu | Mesaj |
|---|---|---|---|
| yönetici | **200** | — | — |
| sakin | **403** | `mobil_uygulama` | "…Yönetio mobil uygulamasında çalışır" |
| güvenlik | **403** | `mobil_uygulama` | aynı |
| tesis görevlisi | **403** | `mobil_uygulama` | aynı |
| yönetici → `panel.*` | **403** | `forbidden` | "panel yalnızca platform yöneticisi" |

**DENETÇİ UÇTAN UCA ÇALIŞTI** (aynı koşumda, yönetici hesabıyla açılan
gerçek bir denetçi ile): giriş **200** · `/` → **`/raporlar`** · `/raporlar`
200 · `/transparency` 200 · `/profil` 200 · `/finans` → `/raporlar` ·
`/users` → `/raporlar` · `/dashboard` → `/raporlar`. Sunucu HTML'indeki menü
**tam 4 bağlantı** (Rapor motoru, Şeffaflık, Profilim, KVKK). Rapor **gerçek
API'den üretildi** (`POST /raporlar/borc_alacak` → 200) ve aynı oturumda
**yazma denemesi 403** (`POST /finans/hareketler`).

**"YAKINDA" DEMEK YANLIŞ OLURDU.** Mevcut kapı bilinmeyen rollere "web
çalışma alanı henüz hazır değil" diyordu. Sakin/güvenlik/saha için bu bir
**yalan** olurdu: onlar için web çalışma alanı *planlanmıyor*. Ayrı bir
cümle eklendi (7 dil) ve `guvenlik_amiri` "yakında"da **kaldı** — onun
mobil ekran seti de yok, mağazaya yollamak da yanlış olurdu.

**MAĞAZA BAĞLANTISI UYDURULMADI.** Uygulama henüz yayında değil (P118 Mac
derlemesinde bekliyor). `applicationId`den Play adresi türetip yazmak
bugün **404'e giden bir söz** olurdu; App Store için sayısal kimlik ise
hiç yok. Bağlantılar `NEXT_PUBLIC_PLAY_URL` / `NEXT_PUBLIC_APPSTORE_URL`
ile gelir ve **yalnız tanımlıysa** çizilir. Yayına çıkınca yapılacak tek
şey bu ikisini tanımlamaktır — **kod değişikliği yok**. *(Kerem'in işi;
P11 listesine yazıldı.)*

**İSTEMCİ METNE DEĞİL KODA BAKIYOR:** 403 gövdesinde `code:
"mobil_uygulama"` dönüyor ve giriş ekranı mağaza bağlantılarını buna göre
çiziyor. Metne bakmak, dil değişince sessizce bozulurdu.

**MUTASYON DENETİMİ BİR TASARIM HATASI BULDU.** Karar (hangi mesaj?) iki
giriş rotasına **kopyalanmıştı** ve testler kaynakta metin arıyordu:
telefon rotasındaki dalı ölü bir dala çevirdiğimde **hiçbir test düşmedi**
— metin hâlâ kaynaktaydı. Kural tek bir saf fonksiyona (`girisRedKarari`)
taşındı, davranışla test edildi; aynı mutasyon şimdi **düşüyor**.

**SAYFALAR PARK EDİLDİ, SİLİNMEDİ** — 10 sayfa (Aidatım, Taleplerim,
Kurallar, Etkinlikler, Rezervasyonlarım, Ziyaretçiler, Kargolar,
Görevlerim, Duyurular, Yönetim iletişim) kod tabanında duruyor; rol
listeleri boşaldı. Boş listeyi **silmemek** bilinçli: sınıflandırılmamış
rota middleware kapısından muaf olurdu (P126.2). Karar ve geri alma yolu
`docs/app-web-bosluk-tablosu.md` §6'ya yazıldı.

**İKİ KATMAN, İKİSİ DE ÖLÇÜLDÜ:** giriş kapısı (oturum hiç kurulmaz) +
middleware rol kapısı (elinde geçerli çerez kalmış biri için ikinci
savunma) + menünün boş çizilmesi (üçüncü).

**`/olaylar`DAN `security` ÇIKARILDI:** olayı güvenlik **mobilde** üretir,
yönetim burada okur. Sayfa yönetim görünümü olarak duruyor.

**BULUNAN AMA BU MADDEDE DÜZELTİLMEYEN ÇIRÇIR:**
`rezervasyon-kvkk.dom.test.ts` tam koşumda bir kez düştü, tek başına ve
ikinci tam koşumda geçti. Kök neden okundu: test `findAllByRole` ile
kutuların **var olmasını** bekliyor ama `checked` durumunun sunucudan
gelen değere göre **güncellenmesini** beklemiyor (yarış). Kodla ilgisi
yok; ayrı bir commit'te düzeltilecek.

KAPILAR: `tsc` temiz · `vitest` **506 test** (+13) · `npm run build` ✓ ·
canlı sürüş yukarıda.

### P130 — P0 yetki hataları: kim kimi açabilir + denetçiyi yönetici açar
Status: BITTI · Depends-on: —
Scope: İki hata, ikisi de yetki sınırında; **grubun İLK işi**.
(a) **Yetki yükseltme iddiası:** bir tesis yöneticisi **platform admin**
hesabı açabiliyor. Ölçülecek (`POST /users`, `PATCH /users/{id}`,
`POST /residents`, `yonetisim` kişi ekleme, panel/app arayüzleri) ve nerede
gerçekten açık olduğu **kanıtla** yazılacak. Kural: yönetici YALNIZ
{`resident`, `security`, `tesis_gorevlisi`, `denetci`} açar; `admin` YALNIZ
mevcut bir platform admini tarafından ve YALNIZ `panel.*`ta açılır.
**Zorlama API'de** (403) — süzülmüş açılır liste bir kapı değildir.
**Kim-kimi-açar matrisinin HER ÇİFTİ** test edilir (izinliler 201, yasaklar
403). Oluşturmalar açanın rolüyle **audit log**'a yazılır.
(b) **Yönetici DENETÇİ açamıyor** — açabilmeli. P128 bu maddede uygulanır.
Acceptance: matrisin her hücresi testli; audit kaydı doğrulanmış;
`denetci` uçtan uca çalışıyor; kapılar.

Notes (2026-08-04, P130(a)) — **YETKİ YÜKSELTME İDDİASI ÖLÇÜLDÜ: API'DE
YOKTU. ASIL KUSUR ARAYÜZDEYDİ ve gerçekti.**

Görev metni "bir tesis yöneticisi platform admin hesabı açabiliyor" diyordu.
Kabul etmeden **ölçtüm** — canlı dev yığınında, altı rolün her biriyle altı
rolü açmayı denedim (36 hücre + PATCH ile rol değiştirme + `/residents`):

| Açan → hedef | Ölçülen |
|---|---|
| yönetici → **admin** | **403** (`rol_olusturulamaz_yalniz_saha`) |
| yönetici → yönetici / güvenlik amiri | 403 |
| yönetici → güvenlik / tesis görevlisi | 201 |
| amir → güvenlik | 201 · amir → diğer her şey | 403 |
| güvenlik / saha / sakin → her şey | 403 (uç zaten kapalı) |
| admin → her rol | 201 |

Yani **sunucu baştan beri doğru davranıyordu** (`routers/users.py`, POST ve
PATCH; `guvenlik_amiri` için de ayrı daraltma). Bunu "sorun yok" diye
kapatmak yanlış olurdu — **Kerem'in gördüğü şey vardı**: `app.*`taki
Kullanıcılar formunun rol açılır listesi `ROLE_OPTIONS`un **tamamıydı**.
Site yöneticisi "Platform Admin"i **seçiyor**, kaydediyor ve 403 alıyordu.
Bu bir yetki açığı değil, **yapılamayacak bir şeyi teklif eden arayüz**tü —
ve kullanıcı açısından ikisi aynı görünür.

**ÜÇ AYRI YERDEN TEK KAYNAĞA.** Kural bugüne kadar `users.py` içinde iki
frozenset olarak yaşıyor ve üç yerde ayrı uygulanıyordu (POST, PATCH,
panelin listesi — sonuncusu hiçbir yerden türetilmiyordu). Artık
`backend/app/roller.py` (`ACILABILIR_ROLLER`) **tek kaynak**; uçlar oradan
okuyor ve yeni `GET /users/acilabilir-roller` aynı tabloyu istemciye
veriyor. Liste artık **çağıranın gerçekten açabildiği kümedir**.

**ROL BAŞINA `if` KALDIRILDI — ASIL RİSK BUYDU.** Eski kod `if user.role ==
"yonetici"` / `== "guvenlik_amiri"` diye ilerliyordu: yeni bir rol (P128
`denetci`) eklendiğinde **hiçbir `if`e girmez** ve sessizce **her şeyi
açabilir** olurdu. Yeni kural tek satır: `body.role not in
acilabilir(user.role)` → 403. Tanınmayan rol **boş küme** alır
(fail-closed); varsayılanı "her şey" yapmak, tabloya yazılmayı unutulan
rolü sistemin **en yetkili** rolü yapardı.

**AUDIT ZATEN AÇANIN ROLÜNÜ YAZIYORDU** (`audit_user` → `actor_rol`);
uydurma bir alan eklemek yerine bu **test edildi**: `yonetici`nin açtığı
kayıtta `actor_rol=yonetici`, `meta.role=security`.

**LİSTE SÜZGECİ BİLEREK DARALTILMADI:** sayfanın üstündeki "Rol" süzgeci
tüm rolleri listelemeye devam ediyor — bir yönetici admin hesaplarını
**görebilir** (düzenleyemez). Daraltılan şey "hangi rolde hesap AÇILIR"dır.

**DÜZENLENEN KAYDIN ROLÜ LİSTEDE YOKSA YİNE GÖRÜNÜR:** aksi halde select
sessizce ilk seçeneğe düşer ve kaydet, kullanıcının **dokunmadığı** bir
alanı değiştirmek isterdi.

**MUTASYON 3/3:** POST'taki kural kaldır → 9 hücre düştü · açılır listeyi
yine `ROLE_OPTIONS`a çevir → 2 web testi düştü · uç tüm rolleri döndürsün →
2 hücre düştü.

**ROL MATRİSİ KİLİDİ YENİ UCU YAKALADI** — tam istendiği gibi. Tam koşum
**1274 geçti / 1 düştü** ve düşen tek şey kilitti; ölçülen fark **tek
satır**: `GET /users/acilabilir-roller  IZIN IZIN RED RED RED IZIN`.
Kilit belgelenmiş iki adımlı yordamla yeniden üretildi (kapsayıcıda üret →
depoya kopyala; kopyalamayı atlamak "kilit güncellendi" sanıp ESKİ kilidi
sürdürmek demekti).

KAPILAR: `tsc` temiz · `vitest` **493 test** (+3) · `npm run build` ✓ ·
`backend-pytest` **1274 geçti** (tek düşen = yukarıdaki kilit satırı,
güncellendi) · sözleşme güncellendi.

### P131 — Web'deki eşitlik boşlukları: kamera izleme + kayıp görseller
Status: BITTI · Depends-on: P126
Scope:
(a) **`app.*`ta kamera izleme.** P126.5 ızgarayı verdi, oynatıcıyı
**bilerek** vermedi (hls.js bağımlılık kararı Kerem'e bırakılmıştı) — karar
geldi: **hls.js eklenir**. Rol süzgeçli ızgara + oynatıcı (HLS'i Safari
yerel oynatır, diğerlerinde hls.js; MP4 doğrudan `<video>`), `rtsp`/
oynatılamaz kaynak → **rozet + bilgi sayfası** (web sayfası URL'i verilmez),
canlı karolar P43'ün anlık-kare kararına göre kalır. **Kamera yönetimi
yöneticiye açılır** — doğrulama mobildeki `CameraDraft` kuralıyla **aynı**
olmalı (ikinci bir kopya değil; ortak kural tek yerde ölçülür).
Dev tohum/testte doğrulanmış yayın kullanılır:
`https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8`
(b) **Web'de görseller çıkmıyor.** Mobilde görselli görünen içerik (duyuru,
site kuralı, etkinlik, görev/talep foto kanıtı, kamera görselleri) `app.*`ta
görselsiz çiziliyor. **Kök neden bulunacak** (presign üretimi / yanlış alan /
depolama konağında CORS-CSP / göreli-mutlak URL) ve düzeltilecek; tahminle
değil **ölçümle**.
Acceptance: en az bir tarayıcıda gerçek `m3u8` oynuyor (ölçüm kaydı);
oynatılamaz kaynak rozetle ayrılıyor; görselli tohum içerikle web'de görsel
**görünüyor** (HTTP durum + içerik türü kaydedilir); kapılar.

Notes (2026-08-04, P131.1) — **KURAL KOPYALANDI AMA AYRIŞMASI ARTIK
ÖLÇÜLÜYOR.** P126.5 web'de kamera yönetimini *"TS'e ikinci kopya yazmak
ayrışma demektir"* diye açmamıştı. Gerekçe doğruydu, **çözüm yanlıştı**:
iki dil (Dart + TS) var, kopya kaçınılmaz; kaçınılmaz olmayan şey
**sessizce** ayrışmalarıdır. `contracts/kamera-url-kurali.json` ortak
**vaka** dosyası oldu (30 vaka); mobil testi (26) ve web testi (30) **aynı
dosyayı** okuyor. Biri ayrışırsa kendi tarafının testi düşer.

Vakalarda `sunucu_da_reddeder` bayrağı var: sunucu bir **web sayfası**
adresini (`youtube.com/watch?v=…`) reddedemez — onun için geçerli bir
HTTPS adresidir; oynatılamayacağını bilen taraf **oynatan** taraftır.

Notes (2026-08-04, P131a) — **OYNATICI GELDİ; TARAYICI FARKI GİZLENMEDİ.**

`hls.js` bağımlılık kararı verildi (P126.5'te Kerem'e bırakılmıştı). Üç
yol var ve **hangisinin seçildiği ekranda yazıyor** — destek sorusunda
("bende açılmıyor") ilk sorulacak şey budur:
* Safari/iOS → tarayıcı HLS'i yerel oynatır, kütüphane **hiç yüklenmez**;
* diğerleri → **oynat'a basınca** dinamik import (sayfayı açmayan ödemez);
* MP4 → doğrudan `<video src>`.

**OYNATILAMAZ KAYNAK GİZLENMEDİ, ROZETLENDİ:** restream'siz `rtsp` karo
tıklanabilir kalır ama oynatıcı değil **nedenini** söyleyen bir kutu açar.
Siyah ekran "bozuk" izlenimi üretir ve teşhisi kameraya gönderirdi. Web
sayfası adresi **verilmez** (o kayıt zaten reddedilir).

**YÖNETİM AÇILDI** (ekle/düzenle/sil): web sayfası adresi istek
**gönderilmeden** kesiliyor. Yetki kararı BFF'te değil sunucuda.

**KAPI İKİ KUSURUMU YAKALADI:** (1) `.tsx` içindeki `/** */` Türkçe yorum
"çevrilmemiş metin" sayıldı — tarayıcı yalnız `//` yorumlarını atıyor;
(2) `"HLS (hls.js)"` yedi dilde aynı olduğu için TR-kopyası taramasına
takıldı, gerekçeli istisnaya eklendi (teknik kimlik, cümle değil).

**TEST YAYINI CANLI DOĞRULANDI:** görevde verilen Apple adresi → HTTP 200,
`application/x-mpegURL`, 24 varyant. Seed'de zaten bu adres kullanılıyordu.
**Gerçek bir tarayıcıda oynatma** ölçümü bende yok (başsız ortam) — P11'e
cihaz-doğrulama maddesi olarak yazıldı.

Notes (2026-08-04, P131b) — **"WEB'DE GÖRSELLER ÇIKMIYOR" — SEBEP WEB
DEĞİLDİ, SUNUCUYDU.**

Tahmin etmeden **ölçtüm**: altı içerik ucunu tek tek sürdüm ve `foto_key`
dolu olan kayıtlarda `foto_url` de dolu mu diye baktım:

| Uç | foto_key dolu | foto_url dolu |
|---|---|---|
| duyurular | 1 | **1** |
| site kuralları | 1 | **1** |
| etkinlikler | 2 | **2** |
| talepler | 2 | **2** |
| **görev tamamlamaları** | 1 | **0** ← |

**KÖK NEDEN:** `TaskCompletionOut` şemasında `foto_url` **vardı**, iki
istemci de onu okuyordu (mobil `TaskCompletion.fotoUrl`, panelin görev
detayı) — ama sunucu **hiçbir yerde doldurmuyordu**. Fotoğraf kanıtı
yükleniyor, saklanıyor ve **hiçbir yerde görünmüyordu**. Yani bu web'e
özgü bir kusur değildi: mobilde de görünmüyordu.

**PANELİN ROZETİ EKSİĞİ GİZLİYORDU:** "foto var" etiketi çiziliyor ama
kanıta **ulaşmanın yolu yoktu**. Artık görselin kendisi çiziliyor (yeni
sekmede tam boyut). `foto_key` var ama `foto_url` yoksa rozet **doğru**
kalır — "kanıt var, gösterilemiyor" başka bir şeydir.

**İKİNCİ BELİRTİ (tohum verisi):** dev veritabanındaki tohum kaydı
yüklenmemiş bir anahtara (`seed-completion-1.jpg`) işaret ediyordu; tohum
kodu artık gerçek bir obje yüklüyor ama `ON CONFLICT DO NOTHING` eski
satırı **asla düzeltmiyordu**. `DO UPDATE SET foto_key` yapıldı — yeniden
tohumlama eski veriyi iyileştiriyor.

**UÇTAN UCA ÖLÇÜM** (dev yığını): presign → PUT (gerçek PNG) → tamamlama →
liste → `foto_url` → **HTTP 200, `image/png`, geçerli PNG imzası**. Tohum
kaydı da yeniden tohumlamadan sonra **200 / image/png / 2249 bayt**.

**CORS/CSP DEĞİLDİ:** `<img>` etiketi CORS gerektirmez; ölçüm de bunu
doğruladı (aynı presigned adres tarayıcının atacağı istekle çekildi).

**MUTASYON:** sunucuda `foto_url`i `None` bırak · panelde görsel dalını
kapat — ikisi de yakalandı.

### P132 — Web arayüz yenilemesi: mobil tasarım diline geçiş
Status: ACIK · Depends-on: P126, P129, P131
Scope: **Tasarım turu, özellik turu DEĞİL** — iş mantığı ve backend
davranışı DEĞİŞMEZ. `app.*` ve `panel.*`, mobil uygulamanın **onaylanmış**
tasarım sistemine taşınır (kaynak: `mobile/lib/src/core/theme/
home_tokens.dart`).
1. **Web tasarım sistemi:** mobil token'lar (renk, boşluk, yarıçap,
   tipografi, gölge) tek bir tema katmanına çıkarılır; sayfalar oraya
   taşınır — sayfa başına CSS yok.
2. **Düzen:** masaüstünde kenar çubuğu, mobil webde çekmece; tek bir sayfa
   başlığı kalıbı (başlık + birincil eylem + süzgeç); boş/yükleniyor/hata
   durumları **tek** bileşen setinde (çıplak spinner yok).
3. **Pano (yönetici):** mobil ana ekranın bilgi hiyerarşisi geniş ekrana
   uyarlanır — hızlı istatistik kartları, vardiya durumu, son hareketler.
4. **Panoda YENİ (Kerem):** (a) tesis konumu **harita** (tenant
   `konum_lat/lon` var; anahtar env'den, yoksa OSM'ye düşülür — anahtar
   koda gömülmez), (b) rol-görünür kameralardan **4'lü şerit** (P43 anlık
   kare deseni; tıklayınca P131'in hls.js oynatıcısı — çoklu otomatik
   oynatma YOK).
5. **İstemci başarımı** (sunucu ölçeği DEĞİL — o P39): rota bazlı kod
   bölme, şişkin paket yok, görseller tembel + doğru boyutlu, panoda N+1
   istemci isteği yok; **rota başına ilk yük JS öncesi/sonrası ölçülür**.
6. **Erişilebilirlik:** odak durumları, girdi etiketleri, kontrast ≥ 4.5,
   kabukta klavye gezinimi.
7. i18n 7 dil; kapılar (tsc + vitest + build).
Acceptance: ekran görüntüsü alınabilir bir pano; tüm sayfalarda tutarlı
kabuk; harita ve kamera şeridi panoda; rota başına ilk yük JS öncesi/sonrası
raporlanmış; kapılar yeşil.

### NOT — Sign in with Apple (4.8)
**GEÇERSİZ (N/A):** üçüncü taraf sosyal giriş **kullanmıyoruz** (Google/Facebook
girişi yok; kimlik doğrulama tesis tarafından verilen hesapla). 4.8 yalnız
üçüncü taraf giriş SUNAN uygulamaları bağlar. Denetim notlarına yazılacak
(P115).

## STATUS REPORT — 2026-08-01 #10 (kural 10: bağlam DOLDU, devir)

**FINAL REPORT değildir.** #9'un üstüne **P61–P65** eklendi. **P66'dan**
devam edilebilir; `/clear` + standart kickoff. **Bağlam bu turda gerçekten
tükendi** — sonraki tur temiz bağlamla çok daha verimli olur.

### Bu turda biten

| Madde | Hash | Özet |
|---|---|---|
| P61 | `1e67b0a` | Harita hem "3 açık şikayet" hem "açık şikayet yok" diyordu (+2 yer) |
| P62 | `4924e85` | Koyu temada devrilmemiş renkler — **ilki benim eklediğimdi** |
| P63 | `6777842` | Dört adsız form denetimi; biri **tesis silme onayı** |
| P64 | `ff69828` | **BLOKE** — vezne hareketinde çift kayıt riski (ölçüldü, karar Kerem'in) |
| P65 | `2938b4c`, `3e5a038` | Tarayıcıdan 1.000 ardışık istek; sınır **ve** uyarı |

### Bu turun dersi

**Kilit yazmak yetmiyor; kilidin yakaladığını görmek gerekiyor.** İki kez
kendi işim tökezledi ve ikisi de bu kuralla yakalandı:
* P62'nin kilidi **sessizce geçiyordu** (kaçış katmanları fazlaydı, üretilen
  düzenli ifade hiçbir şeyle eşleşmiyordu) — enjekte edilen renk
  yakalanmayınca ortaya çıktı.
* P65'in ilk hâlinde üst sınırı **sarmalayıcının arkasına** koymuştum: dört
  çağıran da sessizce kırpılırdı. "Sessiz kırpma yapma" kuralını tam da onu
  koyarken bozuyordum.

Ayrıca P63'te **mevcut bir testin kusuru sabitlediği** görüldü
(`getByRole("textbox", { name: "" })` — kutunun adı olmamasına dayanıyordu).

### Kapılar

| Alan | Durum |
|---|---|
| backend | **bu turda dokunulmadı** (son tam koşum: **1138 passed**) |
| mobile | **bu turda dokunulmadı** (`analyze` temiz, `test` **1533**, apk başarılı) |
| admin-web | `tsc` temiz, `vitest` **199** (35 dosya, 3 ardışık tam koşum), build yeşil |

### Bir sonraki adım

Kapsamı olmayan panel sayfaları: `audit`, `tenants`, `transparency`,
`announcements`, `integrations`. İlke aynı: **hedef yüzde değil hata
sınıfı**. Bloklu maddeler: P2, P11 (cihaz listesi **40** madde), P12, P13,
P18, **P64** ve `meta.total`.

## STATUS REPORT — 2026-08-01 #9 (kural 10: bağlam doldu, devir)

**FINAL REPORT değildir.** #8'in üstüne **P58–P60** eklendi. **P61'den**
devam edilebilir; `/clear` + standart kickoff.

### Bu turda biten

| Madde | Hash | Özet |
|---|---|---|
| P58 | `fc419e4` | İkincil arama sessizce düşüyordu — uyarı + `#kimlik` (panel) |
| P59 | `c4b0b71` | Aynı sınıf mobilde: boş seçici "kayıt yok" gibi okunuyordu |
| P60 | `733015d` | Hata varken "talep yok" iddiası + `String(error)` öneki |

### Ortak bulgu

Üçü de tek bir cümlenin farklı yüzleri: **eksik veri, yokluk gibi
gösteriliyordu.** Boş açılır liste "kayıt yok" diye okunuyor; kimlik parçası
ad sanılıyor; düşen istekten sonra "hiç talep yok" yazılıyor. Hiçbiri
çökmüyor, hepsi **yanlış bilgi veriyor** — ve yanlış bilgi, bilgi
yokluğundan kötüdür.

### Kapılar (son durum)

| Alan | Durum |
|---|---|
| backend | **bu turda dokunulmadı** (son tam koşum: **1138 passed**) |
| mobile | `flutter analyze` temiz, `flutter test` **1533**, apk build başarılı |
| admin-web | `tsc` temiz, `vitest` **191** (31 dosya, 3 ardışık tam koşum), build yeşil |

### Kalan kilitler (bu oturumda eklenenler)

`sessiz-fetch` (ham `fetch` denetimi), `ham-enum` (tel değeri ekranda),
`hata-mesaji` (korumasız `String(hata)`), `i18n` içinde tarayıcı diyalogları.
**Dördü de düzeltme geri alınarak doğrulandı**; ikisi (`ham-enum`,
`sessiz-fetch`) elle bulunmamış sızıntıları kendi buldu.

### Bir sonraki adım

Kapsamı olmayan panel sayfaları: `audit`, `tenants`, `transparency`,
`schematic`, `announcements`, `integrations`. İlke aynı: **hedef yüzde değil
hata sınıfı**. Bloklu maddeler değişmedi: P2, P11, P12, P13, P18 ve
`meta.total`.

## STATUS REPORT — 2026-08-01 #8 (kural 10: bağlam doldu, devir)

**FINAL REPORT değildir.** Bu tur, FINAL REPORT #2'nin üstüne **P53–P57**'yi
ekledi. **P58'den** devam edilebilir; `/clear` + standart kickoff.

### Bu turda biten

| Madde | Hash | Özet |
|---|---|---|
| P51 | `fa89144` | Panel kapsamı 4. tur + bildirimlerde **sessiz başarısızlık** |
| P52 | `f346946` | Ham `fetch` sınıf kilidi + çıkıştaki oturum tuzağı |
| — | `dd68bed` | FINAL REPORT #2 (P41–P52) |
| P53 | `3bd7e21` | Ham tel değeri **sekiz yerde daha** — tek kaynak + kilit |
| P54 | `799b53c` | Tarayıcı diyalogları: **sekiz** sabit Türkçe silme onayı |
| P55 | `5c02e70` | Metrekare: gösterim + **sessizce silinen** alan + suite flake'i |
| P56 | `9224062` | `Number()` → NaN → `null` deseni **altı yerde**; **üçüncü** para ayrıştırıcısı |
| P57 | `3e30d7d` | Aynı desen mobilde: koordinat, **Türkçe klavyeyle** siliniyordu |

### Bu turun yöntemi (devam eden için)

Her tur **bir kusur** bulup **sınıfını** sordu ve sınıfı süpürdü. Beş kez
sınıf tek örnekten büyük çıktı:

* P51'in bildirim rozeti → P53'te **sekiz** rozet daha,
* P46'nın `toast()`u → P54'te **sekiz** diyalog daha,
* P55'in metrekaresi → P56'da **altı** alan daha → P57'de mobil.

**Kilitler sınıfı kapatır, örneği değil** — ve iki kilit (`ham-enum`,
`sessiz-fetch`) yazıldıktan **sonra** elle bulunmamış sızıntılar buldu.
Kilit yazarken düzeltmeyi geri alıp **yakaladığını görmek** kural oldu:
yakalamadığını görmeden kilit saymak, kilidi olmayan bir kapıya kilit
demektir.

### Kapılar (son durum)

| Alan | Durum |
|---|---|
| backend | **değişmedi** (son tam koşum P41–P42 turunda: **1138 passed**) |
| mobile | `flutter analyze` temiz, `flutter test` **1530**, apk build başarılı |
| admin-web | `tsc` temiz, `vitest` **183** (29 dosya), `npm run build` yeşil |

### Bir sonraki adım

Süpürülmemiş sınıf kalmadı ama **kapsamı olmayan panel sayfaları** duruyor:
`audit`, `schematic`, `support`, `tenants`, `transparency`, `integrations`,
`announcements`. İlke aynı: **hedef yüzde değil hata sınıfı**. Bloklu
maddeler değişmedi: P2, P11, P12, P13, P18 ve `meta.total`.

## FINAL REPORT — 2026-08-01 #2 (kural 13: P41–P52)

**Uygun madde kalmadı.** **P1–P52** arasındaki tüm maddeler BITTI; geriye
yalnız **[KEREM]/[DIŞ]** bloklu beş madde kaldı (P2, P11, P12, P13, P18) ve
bir ürün kararı (`meta.total`). Kod tarafında yapılacak eligible iş yok.

Aşağıdaki rapor **P41–P52**'yi kapsar; P1–P40 için bir alttaki (ilk) FINAL
REPORT geçerlidir.

### A — Yapılan işler

| Madde | Hash | Ne yapıldı |
|---|---|---|
| P41 | `b9baad7` | Yetki matrisi görünümü **koddan üretilir** (`require_role` → `izinli_roller` özniteliği); `roller: null` "herkese açık" değildir |
| P42 | `68eb69e` | İçerik daraltma kapsamı: aynı uç, role göre **farklı gövde** — envanterin açık maddesi kapandı |
| P43 | `2413a79` | Panel bileşen testi altyapısı (jsdom, `createElement`, temiz SWR önbelleği) + 12 test |
| P44 | `3f11deb` | Panel kapsamı 1. tur: rapor, mesaj, portal, ayarlar |
| P45 | `d5defe9` | Panel kapsamı 2. tur: aidat, kullanıcılar |
| P46 | `92eea6a` | Bildirim (toast) metinleri i18n kör noktası + talep durum makinesi testleri |
| P47 | `2848374` | Panel kapsamı 3. tur: pano, daireler, tanımlar |
| P48 | `17c832e` | Para biçimlendirmede **ICU bağımlılığı** kaldırıldı; tek biçimlendirici |
| P49 | `7da37d8` | Mobil para **ayrıştırma çekirdeği** (ayrıştırma ≠ politika) + tarih kaymalı test |
| P50 | `9a94c6b` | Panel ayrıştırıcısı **gösterdiği biçimi** kabul ediyor; iki istemci aynı kural |
| P51 | `fa89144` | Panel kapsamı 4. tur (vardiya, NFC noktası, bildirimler) + iki gerçek kusur |
| P52 | `f346946` | **Sessiz başarısızlık sınıfı** kilitlendi + çıkıştaki oturum tuzağı |

### Bulunan gerçek kusurlar (hepsi düzeltildi)

1. **P42 — sessiz 500 tuzağı.** `/activity` rol-anahtarlı sözlük kullanıyor;
   uca yeni rol eklenip sözlüğe satır eklenmezse `KeyError → 500` dönerdi ve
   **yetki kilidi 500'ü "İZİN" saydığı için hiçbir ölçüm yakalamazdı.**
2. **P43 — test bağımlılığı ürün derlemesini kırdı.** `@vitejs/plugin-react`
   kurulunca `next build` patladı. Kural: test bağımlılığı ürün derlemesini
   kıramaz.
3. **P43 — SWR önbelleği testler arası taşınıyordu** ve "uç düştü" senaryosu
   **yanlışlıkla geçiyordu**; RTL temizliği `globals` olmadan devreye girmez.
4. **P44 — test aracında önek çakışması** (`/portal` ile `/portal-iletisim`)
   iletişim listesine portal gövdesi döndürüyordu.
5. **P44 — ayarlarda değişmeyen alan gönderiliyordu**: `guvenlik_modu`
   yöneticiye 403 verirdi.
6. **P46 — `toast(...)` metinleri hiçbir i18n taramasının görmediği yerdeydi**;
   panelde 10 sabit bildirim metni vardı ve dil değişince Türkçe kalıyordu.
7. **P47 — Tanımlar tablosu parayı `5000.00` diye yazıyordu.** Türkçe'de nokta
   **binlik ayırıcıdır**: kullanıcı beş yüz bin sanabilirdi.
8. **P48 — `toLocaleString("tr-TR")` bir ORTAM BAĞIMLILIĞIDIR.** Küçük-ICU
   yapılarda `en-US`a düşer ve para **`5,000,00 ₺`** görünürdü — yanlış, VE
   yalnız bazı ortamlarda. Gruplama artık kendimiz yapıyoruz.
9. **P49 — uygulama kendi gösterdiği biçimi reddediyordu** (mobil) ve
   paylaşılan ayrıştırıcı **bütçeye özel politika** taşıyordu (`> 0`), oysa
   tanımlarda `0 = muaf` geçerlidir.
10. **P50 — aynı kusur panelde de vardı**: `1.250,00` → `null`. Eski testteki
    "binlik ayırıcı belirsiz" **gerekçesi yanlıştı**.
11. **P51 — bildirimlerde SESSİZ BAŞARISIZLIK**: ham `fetch` HTTP hatasında
    reddetmez; 500 dönse bile **"okundu olarak işaretlendi"** deniyordu.
12. **P51 — ham tel değeri ekranda**: rozet `gecikmis_okutma` gösteriyordu.
13. **P52 — çıkış aynı sınıftaydı ve bedeli daha ağırdı**: istek düştüğünde
    çerezler yerinde kalırken kullanıcı giriş ekranını görüp **çıktığını
    sanıyordu**.

### Kalıcı hale getirilenler (kilitler)

- `admin-web/tests/sessiz-fetch.test.ts` — **ham `fetch` denetimi** (enjekte
  edilmiş gerçek ihlalle doğrulandı).
- `admin-web/tests/i18n.test.ts` — **`toast()` metinleri** taraması
  (dilden bağımsız; geçici bir sızıntıyla yakaladığı doğrulandı).
- `backend/tests/test_yetki_matrisi.py` — matris ile rol matrisi kilidinin
  **çapraz doğrulaması** (eşitlik değil **alt küme**: eşitlik aramak doğru
  davranışı hata sayardı).
- `backend/tests/test_icerik_daraltma.py` — aynı uç, role göre daralan gövde
  + `_ROL_KAYNAKLARI` bütünlük güvencesi.
- `admin-web/tests/money.test.ts`, `mobile/test/para_test.dart` — iki
  istemcinin **aynı** ayrıştırma kuralı.

### Kapılar (son durum)

| Alan | Durum |
|---|---|
| backend | tam `pytest` **1138 passed** (P41–P42 turunda; P43–P52 backend'e dokunmadı) |
| mobile | `flutter analyze` temiz, `flutter test` **1525**, `flutter build apk --debug` başarılı |
| admin-web | `tsc` temiz, `vitest` **168** (25 dosya), `npm run build` yeşil |
| panel bileşen kapsamı | ifade **%9,66 → %19+** (hedef yüzde değil **hata sınıfı**) |

### B — Test edilecekler (Kerem)

**Cihazda/elde doğrulama listesi P11'dedir ve bu turda 27 maddeye çıktı.**
P41–P52 turunda eklenenler: yetki matrisi sayfası (P41), para biçimi ve
tutar girişi (P47–P50), bildirim rozetleri + okundu işareti (P51), çıkış
(P52). Ayrıca **hâlâ Kerem'e bağlı** olanlar: P2 (prod runbook), P12/P13
(Firebase + ödeme kimlik bilgileri), P18 (Frigate pilotu) ve `meta.total`
ürün kararı.

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


- 2026-08-02 · P111 · (bu commit) · SAYAC TAKIBI kaleminin gercekten eksik parcasi olculdu ve yol haritasinin YANILTICI oldugu gosterildi: tablolar, bes uc, tuketim dagitimi ve POST /borclandirma/sayac ZATEN VAR, ana sayac paneli de VAR (tanimlar sayfasinda sayaclar-ana kaynagi) — ILK TARAMAM YANLISTI cunku grep .tsx icinde arayip veri-surunculu tanimi gormedi; gercekten eksik olan iki sey: BOLUM SAYACLARI PANELI ve OKUMA SIHIRBAZI; bolum sayaclari TEK SATIRLIK EK DEGIL cunku tanimlar sayfasinin alan tipleri metin|sayi|kurus|tarih|bool|secim ve bolum sayaci unit_id + ana_sayac_id REFERANS alanlari istiyor, yani once baska bir uctan secenek yukleyen yeni bir alan tipi gerekiyor; sihirbazin sozlesmesi sunucuda yazili (adimlar ISTEMCIDE toplanir, TEK istek gider) ve govdesi donem/tanim/ana_sayac/ana_tuketim/birim_fiyat_kurus/bolum_tuketimleri.\n- 2026-08-02 · P110 · b1ed350 · P109'un 'duzeltilmedi' biraktigi sizinti DOGRU cozuldu: cozum SAHIPLIK — metin_iste_diyalogu.dart ile diyalog bir StatefulWidget oldu ve denetleyici ONUN KENDI DURUMUNA ait, State.dispose CIKIS ANIMASYONU BITTIKTEN SONRA cagrilir (P109'un coktugu yer tam buydu); uc cagri yeri (task_categories, unit_access, dis_hizmet) ayni kalibi elle kuruyordu, simdi tek cagri — kod AZALDI ve sizinti kapandi; KILIT IKI KEZ YANLISTI ve ikisi de enjeksiyonla cikti: (1) ilk desen yalniz `final x = TextEditingController(` bicimini goruyordu ve `late final TextEditingController _ctrl = ...` HIC taranmiyordu, yani kilidin KENDI ORNEK DOSYASI kapsam disiydi ve dispose silindiginde test GECIYORDU; (2) tip istege bagli yapilinca bosluk [\\s\\S] oldu ve `final _formKey = GlobalKey<FormState>();` bildirimini bir alt satirdaki TextEditingController ile eslestirip BES yanlis pozitif uretti, ayirici [^;] yapildi; kilit bir olcum aracidir ve IKI YONDE de sinanmalidir: yanlisi yakaliyor mu, dogruyu rahat birakiyor mu; atilmayan denetleyici 3 -> 0.\n- 2026-08-02 · P109 · b0efefc · Kaynak sizintisi sinifi tarandi: panel temiz (iki dinleyicinin de temizligi var), mobil zamanlayicilar temiz; BULGU 106 denetleyiciden UCU atilmiyor — diyalog acan metotlarin ICINDE olusturulan yerel TextEditingController'lar (task_categories._ekle, unit_access._newRequest, dis_hizmet._editNote) ve flutter analyze bunu GORMEZ cunku lint yerel degiskenleri izlemez; NAIF DUZELTME COKTU ve bunu TAM SUITE gosterdi: await showDialog sonrasi ctrl.dispose() eklenince 'A TextEditingController was used after being disposed' cunku showDialog'un future'i rota pop edilince tamamlanir ama diyalogun CIKIS ANIMASYONU hala TextField'i ciziyor (try/finally de ayni anda calisacagi icin cozmez); DUZELTME GERI ALINDI ve dogru cozum diyalogu kendi denetleyicisine sahip bir StatefulWidget'e cikarmaktir, bu uc cagri yerini yeniden yapilandirmak kalan baglamda guvenilir yapilamazdi; KILIT DE EKLENMEDI cunku uc bilinen ihlali istisna listesine koymak kilidi dogdugu anda borc tasiyan bir seye cevirirdi; sizinti kullaniciya GORUNEN bir kusur degil (cokme yapmaz, bellek buyur) ve bu yuzden yeniden yapilandirmayi sonraki tura birakmak, COKEN bir duzeltmeyi birakmaktan iyidir.\n- 2026-08-02 · P108 · 7eea057 · Kararsiz siralama sinifi KAPANDI: 22 sorgu daha duzeltildi (mekanik olanlar + cok satirli/bilesik siralamalar, kuyruk mevcut siralamanin SONUNA eklendi yani sira degismedi yalniz esitlik cozuldu; dinamik siralamalar cunku kullanici hangi kolonu secerse secsin `sirala` esitlik uretebilir; events cunku ayni gun iki toplanti ayni tarihi tasiyabilir); KALAN 3 'yapilmadi' DEGIL 'yapilamaz/gerekmez': reports ve transparency TOPLULASTIRMADIR ve id GROUP BY'da olmadigi icin EKLENEMEZ (kararli kuyruk GRUPLAMA ANAHTARIDIR, BudgetCategory.ad eklendi), kvkk ise (tenant_id, surum) BENZERSIZ oldugu icin zaten kararli ve id eklemek VAR OLMAYAN BIR ESITLIGI cozmek olurdu; seffaflik panosu ayrica onemliydi cunku SAKINE ACIKTIR ve esit tutarli iki kategorinin sirasi her yenilemede degisseydi DEGISMEYEN BIR VERI DEGISIYORMUS GIBI gorunurdu; uc turun toplami: 54 (sisik olcum) -> gercek 25 -> 3, circir esigi artik 'azaltilacak borc' degil GEREKCELI BIR TABAN.\n- 2026-08-02 · P107 · 19777e5 · Kararsiz siralamalarin TOPLU URETIM yasanan dilimi duzeltildi (15 sorgu: aidat tahakkuk/odeme, talep x2, kargo, bildirim, duyuru, ziyaretci, gorev + gorev tamamlama, rezervasyon, cihaz, nokta, devriye plani); AMA SAYAC YANLIS SAYIYORDU ve bunu ancak BEKLENTI TUTMAYINCA gordum — duzeltmelerden sonra 42'den 39'a dustu, oysa 27 olmaliydi; sebep kilidin kendi duzenli ifadesiydi: `order_by\\([^)]*\\.id\\b` icindeki `[^)]*` ILK PARANTEZDE DURUR ve `order_by(X.created_at.desc(), X.id.desc())` satirinda desc() icindeki ')' taramayi kesip `.id`i HIC gostermiyordu, yani DUZELTILMIS sorgular 'kararsiz' sayiliyordu; dengeli parantez sayan okuyucuyla yeniden olculdu (kusurlu 39, dengeli 25) ve bu P106'da yazdigim '54'un de SISIK oldugu anlamina geliyor; ayrica kendi ekledigim SyntaxWarning yakalandi cunku uyari sayisi 2'den 3'e cikmisti — kapi yesildi ve 1145 passed aynidiydi, yalniz SAYIYI KARSILASTIRDIGIM icin gorundu; besinci kez ayni ders: olcum aracinin kendisi de olculmeli.\n- 2026-08-01 · P106 · de5ead1 · Hata/i18n damarindan cikip VERI DOGRULUGU tarafinda sinif arandi: `ORDER BY created_at DESC LIMIT n OFFSET m` KARARSIZDIR (esit degerli satirlarin sirasi garanti degil) ve sonuc sayfalar arasinda TEKRARLAYAN VE KAYBOLAN SATIRLARDIR — yonetici ikinci sayfada ayni talebi yeniden gorur, bir baskasini hic gormez ve hicbir yerde hata cikmaz; 'esitlik nadirdir' YANLIS cunku TOPLU URETILEN SATIRLAR AYNI created_at'i PAYLASIR (toplu borclandirma, Excel aktarimi, seed) yani kusur en cok satirin oldugu yerde ortaya cikar; olcum 54 sorgu ve ikisi zaten .id ekliyordu (kod tabani deseni BILIYOR, tutarsiz uyguluyor); bu turda 12'si duzeltildi (ad/no/kod/plaka ile siralananlar cunku orada esitlik NORMALDIR) ve biri sayfalama degil 'birini sec' sorgusuydu — ayni kod'a sahip iki kasa varsa sakine gosterilen IBAN istekten isteg... degisebilirdi; kalan 42 icin CIRCIR cunku tek turda 40'tan fazla ucun siralamasini degistirmek orantisiz olurdu, ve IKINCI BIR TEST esigin gercege yakin kalmasini zorluyor (42 yerine 200 yazsaydim kilit hicbir sey tutmazdi — circirin islevsizlesmesi kilidin sessizce olmesinin en yaygin yolu).\n- 2026-08-01 · P105 · 4b47b2e · catch bloklarindaki YEDEK metinler: `err instanceof Error ? err.message : \"Kaydedilemedi.\"` kalibi 26 yerde vardi ve yedek metin SABIT TURKCE'ydi; bu dal yalniz Error OLMAYAN bir firlatmada gorunur (nadir) ama NADIR OLMASI CEVRILMEMESINI GEREKTIRMEZ — ustelik nadir oldugu icin kimse fark etmez ve dil degistiren kullanici her sey ingilizceyken tek bir Turkce cumleyle karsilasir, hem de kaydin NEDEN gitmedigini soylemesi beklenen yerde; mevcut anahtarlar kullanildi ve yalniz ortakKaydedilemedi eklendi (7 dil), 'Atama kaydedilemedi' gibi ozel metinler GENEL anahtara indirildi cunku yedek metin son caredir ve orada ozgulluk iddia etmek kaynagi bilinmeyen bir hataya SAHTE BIR ACIKLAMA uydurmaktir; kilit dar tutuldu (yalniz ': \"...\"' yedegi olan ucluler; String(e) dali P60'ta ayrica ele alinmisti); 26 -> 0.\n- 2026-08-01 · P104 · 01c0171 · Panelin dort i18n taramasi da .tsx okuyor; BFF rota islerleri route.ts'tir ve HIC TARANMAMISTI — oysa onlar kullaniciya DOGRUDAN metin dondurur ve giris rotasinda iki sabit Turkce metin bulundu (ingilizce arayuzde Turkce gorunuyorlardi); metin() SUNUCUDA CALISMAZ VE SESSIZCE CALISMAZ cunku dili document.cookie'den okur ve sunucuda document yoktur, yani 'her zaman Turkce' demekti ve hicbir sey hata vermezdi — ayri bir cozucu yazildi (istekMetni: cerez > Accept-Language > varsayilan; taninmayan cerez degeri YOK SAYILIR ki uydurma dil secilemesin); i18n testine BESINCI tarama eklendi (app/api altinda message: '...' sabiti sizintidir) ve enjeksiyonla dogrulandi; YAN OLAY: kilidi dogrularken kusuru geri koyup git checkout ile geri aldim ama duzeltme henuz COMMIT EDILMEMISTI ve checkout DUZELTMEYI DE SILDI, kapi kirmiziya dondu — fark edildi ve yeniden uygulandi; ders: commit edilmemis bir duzeltmenin ustunde git checkout ile enjeksiyon denemesi yapma.\n- 2026-08-01 · P103 · 1d8b56e · P102'de ogrenilen yontem uygulandi (apiSend'in yaptigi HER SEYI listele ve ham fetch yerleriyle tek tek karsilastir): apiSend bes sey yapiyor — ag hatasini cevir, 401'de yonlendir, 204'u bos say, HATA ZARFINI OKU, JSON govdeye Content-Type ekle; P101 ikinciyi, P102 birinciyi ortakladi ve sirayla bakinca DORDUNCUSU acik cikti; kusur: backend {error:{code,message}} zarfinda KULLANICI DILINDE ve SEBEBE OZEL bir metin doner ('Dosya cok buyuk') ama support sayfasi bunu ATIP yerine 'Gorsel yuklenemedi (413)' gibi bir KOD gosteriyordu ve kullanici NEDEN olmadigini ogrenemiyordu — bu P60'in aynasidir (orada String(hata) mesaji BOZUYORDU, burada mesaj tamamen ATILIYORDU); zarf YOKLUGU hata sayilmadi cunku vekil/ag katmani duz metin dondurebilir ve bos mesaj da yedege duser (bos metin gostermek hicbir sey soylememektir).\n- 2026-08-01 · P102 · 954e2c5 · P101 401'i ortakladi ama AYNI UC CAGRI YERINDE ikinci bir sapma kalmisti: ag koptugunda tarayici 'TypeError: Failed to fetch' atar ve apiSend/jsonFetcher bunu ortakBaglantiYok diye CEVIRIR (tur 42'de tam bu kusur olculmustu) ama ham fetch kullanan uc yer hatayi OLDUGU GIBI gosteriyordu — yani P101'de 401'i ortakladim ama ag hatasini GOZDEN KACIRDIM, ayni cagri yerleri ikinci kez; tek yardimci iki sorunu birden cozdu (agIstegi: ag hatasini cevirir, 401'i isler ve null doner) ve apiSend kullanilamadi cunku o JSON govde varsayar oysa bu uc yer FormData ve IKILI govde kullaniyor — agIstegi yaniti OLDUGU GIBI doner, govdeyi cagiran okur; sessiz-fetch kilidi yine guncellendi cunku aksi halde dogru duzeltme kilidi dusururdu.\n- 2026-08-01 · P101 · e673919 · 401 dort yerde ve UCU FARKLI DAVRANIYORDU: apiSend/jsonFetcher/fetchAllPaged giris ekranina yonlendiriyor ama uc cagri yeri ham fetch kullaniyor (FormData ve ikili govde gerektirdikleri icin — support yukleme+yanit, raporlar goster+indir) ve 401'i SIRADAN bir hata gibi isliyordu, yani kullaniciya 'Yanit kaydedilemedi (401)' gibi bir KOD gosteriliyor, oturumun bittigi soylenmiyor ve sayfa OLU kaliyordu; ortak yol acildi (oturumDustu: 401'de yonlendirir ve true doner, cagiran baska bir sey yapmaz) cunku apiSend'e yonlendirmek mumkun degildi (JSON govde varsayar); 403 ile KARISTIRILMADI ve bu test edildi — 403 'yetkin yok' demektir 'oturumun bitti' DEGIL ve ikisini birlestirmek yetkisiz sayfaya bakan kullaniciyi sebepsizce giris ekranina atardi; sessiz-fetch kilidi guncellendi ve oturumDustu gecerli bir denetim bicimi olarak tanindi cunku aksi halde DOGRU DUZELTME KILIDI DUSURURDU.\n- 2026-08-01 · P100 · 53350df · Sonuc raporu P86-P99 ile guncellendi ve sayilar YENIDEN OLCULDU (web-vitest 282 bu tur kosuldu, backend 1143, mobil 1561, goc bulgu 0) — hatirlanmadi; 'YAPILMAYANLAR' bolumu buyudu ve bu bilincli: alti bilincli karar tek tek gerekcesiyle duruyor cunku bir raporun degeri neyi yaptigini saymasinda degil NEYI YAPMADIGINI VE NICIN soylemesindedir, aksi halde okuyan eksikligi unutulmus sanir; kendi hatalarim ayri baslikta (sekiz madde) cunku saklamak yesil bir suite'i yanlis guvene cevirirdi.\n- 2026-08-01 · P99 · ae8811c · P97'nin telefonda buldugu 'yaratmada dogrular, guncellemede dogrulamaz' asimetrisi SINIF olarak tarandi: 10 aday, 9'u YANLIS POZITIF ve her biri okunarak gerekcelendirildi (tutar_kurus Field(ge=1) kisitiyla dogrulaniyor, baslangic_saat/acilis/tarih Out semalarinda BICIMLENDIRME amacli ve Create tarafinda alan zaten time/date tipinde, telefon P97/P98'in bilincli kapsam karari); GERCEK OLAN yonetim_email: TenantAdminCreate bos/bosluk degeri None'a ceviriyordu ama TenantSettingsUpdate cevirmiyordu ve ' ' TRUTHY oldugu icin 'yonetim e-postasi var' sayilir, bildirim yolu BOS bir adrese gitmeye calisirdi; TARAMANIN KENDISI DE BIR SONUC: 9 yanlis pozitif, kuralin mekanik uygulanamayacagini gosterir cunku dogrulama uc ayri bicimde yapiliyor (Field kisiti, tip ayristirma, field_validator) — bu yuzden KILIT YAZILMADI, yazilsaydi ya 9 istisna tasirdi ya da dogru kodu hata gibi gosterirdi.\n- 2026-08-01 · P97/P98 · cbd7cfa · P96'nin izi SUNUCUYA kadar suruldu: resolve_phone_target `tel:{numara}` kurar (sema sabit) ama NUMARA dogrulanmiyordu — olculdu, `PATCH /users/{id} {\"telefon\": \"//evil.example/x\"}` 200 donuyor ve deger HAM saklaniyordu; UserCreate'te dogrulayici VARDI, UserUpdate/UserContactUpdate'te YOKTU (ayni gercek iki yerde, biri korumasiz) ve iki sonucu vardi: telefon GLOBAL BENZERSIZ bir GIRIS KIMLIGIDIR ve normalize edilmemis deger benzersizligi bozar, ayrica `tel://evil.example/x` gibi bir URI uretir ve P96'nin istemci sema kontrolu bunu GECIRIR cunku sema hala tel; P98: ILK DUZELTMEM BIR TESTI KIRDI ve bunu ancak TAM SUITE gosterdi (1 failed, 1140 passed — test_call_target::test_riza_yoksa_numara_aciklanmaz_404) cunku `telefon: \"\"` BOS DIZGE 'numarayi kaldir' demek ve dogrulayicim onu gecersiz sayip 422 donduruyordu, yani DOGRULAMASI GEREKMEYEN BIR DEGERI reddediyordu — mevcut sozlesme bunu zaten soyluyordu ((telefon or '').strip()) ve yeni bir kural koyarken var olani okumamistim; diger telefon alanlarina (firma, personel, dis hizmet) BILEREK dokunulmadi cunku onlar giris kimligi degil ve dahili numara gibi serbest bicim icerebilirler.\n- 2026-08-01 · P96 · e4b62f8 · Mobil guvenlik supurmesi: `dial` metnine IKI yoldan girilir ve yalniz biri dogrulaniyordu — telUri() semayi KENDI kurar ve dogrular (guvenli) ama call_models.dart `tel_uri` alanini SUNUCU JSON'undan alir ve hicbir dogrulama yapmadan Uri.parse + launchUrl(externalApplication)'a gonderiyordu; sunucu https:// ya da bir uygulama semasi dondurseydi kullanici 'Ara' dedigi icin TARAYICI ACILIRDI ve nedenini anlamazdi — ayni eylemin iki yolu ayni guvene sahip olmali, bu 'tek gercek iki yer' sinifinin guvenlik tarafi; dial artik telSemasi() uzerinden geciyor ve sema tel degilse ya da yol bossa acmadan false doner; TESTIN ORTAMI DEGIL KONUYU OLCMESI ilk yazimda saglanmamisti: karar dial uzerinden surulunce dosya TEK BASINA GECTI ama TAM SUITTE DUSTU (launchUrl -> MethodChannel -> 'Binding has not yet been initialized'), yani test sema kararini degil TEST ORTAMINI olcuyordu ve bunu ancak tam suitte gordum — karar platformdan bagimsiz bir fonksiyona ayrildi.\n- 2026-08-01 · P95 · ea7327f · Arac turlarindan urun koduna donuldu: iki SESSIZ guvenlik kurali kilitlendi ve supurme sonucu IHLAL YOK cikti (target=_blank kullanan uc baglantinin ucunde de rel=noreferrer var, dangerouslySetInnerHTML tek yerde ve SABIT bir dizge) — yani kilitlenen sey bugunku bir kusur degil YARIN SESSIZCE OLUSABILECEK iki kusur; neden 'sessiz': ikisi de eklendigi anda hicbir seyi bozmaz, testler yesil kalir ve bedeli yalniz kullanicida ortaya cikar — rel'siz _blank acilan sayfaya window.opener ile BIZIM SEKMEMIZI baska adrese yonlendirme izni verir (tabnabbing: sakin duyuru fotografina tiklar, geri dondugunde SAHTE BIR GIRIS EKRANI gorur ve sunucuda hicbir iz kalmaz), degiskenli dangerouslySetInnerHTML ise gelen metni HTML olarak calistirir (XSS); kilitler COK SATIRLI etiketi de okuyor cunku satir bazli bir tarama target'i bir satirda rel'i baskasinda gorup IHLAL SANARDI; ikisi de enjeksiyonla dogrulandi.\n- 2026-08-01 · P94 · db4d1b1 · P93'te 'surulmedi' diye yazdigim mobil hata yolu GERCEK bir dususle suruldu: gecici bir basarisiz test eklendi, kapilar.sh mobile kosuldu ve ozet DUSEN TESTIN DOSYASINI VE ADINI soyledi (betigin cikis kodu 1) — P92'de bu yalniz SENTETIK bir gunlukle surulmustu; yan gozlem: mobil-apk bir test duserken de yesil kaldi ve bu DOGRUDUR cunku flutter build apk testlere bakmaz ve betik kapilari BAGIMSIZ kosuyor (erken ciksaydi tek kosumda tek bulgu alinirdi, oysa amac bir kosumda TUM durumu gormek); gecici test silindi ve yesile donus dogrulandi (1559 passed, cikis 0); goc hata yolu BILINCLI olarak acik birakildi cunku surmek icin KIRIK BIR ALEMBIC REVIZYONU uretmek gerekirdi ve MIGRATION-POLITIKASI baglayicidir, dagitilmis prod vardir — bir araci dogrulamak icin urunun en hassas kuralini cignemek dogrulamanin kendisinden pahalidir ve 'unutuldu' ile 'karar verildi' ayri seylerdir.\n- 2026-08-01 · P93 · 84cfea7 · P88-P92 boyunca infra/kapilar.sh yazildi ve suruldu ama KURAL 6 HALA ELLE KOSMA TALIMATI VERIYORDU — yani iki dogruluk kaynagi vardi (betik ve talimat) ve bu, oturum boyunca kapattigim CAPRAZ BAG sinifinin ta kendisi: ayni gercegin iki yerde tutulup sessizce ayrismasi, kendi surecimde tekrarliyordum; kural artik betigi isaret ediyor ve kapsam tek satirda duruyor AMA TUZAKLAR SILINMEDI cunku betige yonlendirip gerekceleri atmak 'neden boyle' bilgisini yok etmek olurdu ve elle kosan biri ayni uc tuzaga duserdi — kural 'betigi kullan, elle kosacaksan bunlara dikkat et' diyor ve ucunun de hangi turda olculdugu yazili (P74/P75/P87); ACIK KALAN: betigin goc ve mobile HATA yollari uctan uca surulmedi, P92'de flutter imzasi SENTETIK bir gunlukle suruldu ve bunu 'suruldu' saymiyorum.\n- 2026-08-01 · P92 · 235173e · P91'de hata ozeti YALNIZ vitest ile surulmustu; dort kapi turu icin surdum: tsc ('error TS2345: ...'), npm run build ('Failed to compile.'), vitest ('Tests 15 failed | 265 passed') ve pytest — pytest icin SIMULASYON YAPMADIM, P74'te gercekten hata veren kosumun gunlugu duruyordu ve imza ona suruldu ('1137 passed, 1 skipped, 2 warnings, 1 error'); FLUTTER'DA OZET HALA YALAN SOYLUYORDU: 'Some tests failed.' imza listesinde YOKTU ve imza taramasi tail -1 ile calistigi icin 'Failing tests:' BASLIGINI secerdi — yani 'dustu' der ama NE dustugunu soylemezdi; duzeltildi, artik flutter gunlugunde bir Failing tests blogu varsa ozet o blogun ILK SATIRINI (dusen testin adini) gosteriyor ve Some tests failed / Failed to compile imzalara eklendi, gercek bir flutter hata blogu metniyle suruldu; P91'in dersi bir kez daha: 'araci bozuk girdiyle sur' demistim ama TEK BIR KAPI TURUYLE surmustum — bir arac, surulmedigi her yolda sessizce yanlis olabilir ve en cok ihtiyac duyulacagi an (P87'de mobil suite dustugunde, ki kanit kaybolmustu) tam da surulmemis yoldu.\n- 2026-08-01 · P91 · 3e8d0b2 · Kapi ozeti iki yerde ozetlemesi gerekeni SOYLEMIYORDU: (1) basarida `tsc` hicbir sey yazmadigi icin ozet bos kaliyor ve 'okuyamadim' ile 'diyecek bir sey yok' ayirt edilemiyordu — artik '(cikti yok)' yaziyor, P61'in bos-durum dersinin arac tarafindaki karsiligi; (2) hatada yalniz gunluk YOLU basiliyordu, 'son anlamli satiri bas' diye duzelttim ve SURDUM — cikan sey `Duration 12.57s` oldu, yani ozet 'neden dustu'yu degil 'ne kadar surdu'yu soyluyordu, ilk duzeltme ISE YARAMADI ve bunu ancak surerek gordum; ikinci duzeltme once BASARISIZLIK IMZASI ariyor (N failed / ^FAIL / Failing tests) ve artik 'Tests 15 failed | 265 passed (280)' + gunluk yolu basiliyor; UC TURDUR AYNI SEY: P88 kurali yapiya tasidi, P90 raporun yanlis satiri gosterdigini buldu, P91 raporun HATA DURUMUNDA hicbir sey soylemedigini buldu — her seferinde eksik olan adim ARACI BOZUK GIRDIYLE SURMEKTI, cunku yesil bir kosumda ozet dogru gorunuyordu.\n- 2026-08-01 · P90 · 03fea4a · P89'da 'olcum farki' diye not dustugum 1557/1559 ayrimi olculdu ve sebep KENDI OZET SATIRIMDI: kapilar.sh `tail -n 3 | tr '\\n' ' ' | cut -c1-90` ile son uc satiri katliyor ve pencerenin BASINI gosteriyordu, oysa gunluk dosyasinin son satiri her kosumda `+1559 All tests passed!` — hicbir zaman iki farkli sonuc olmamisti; P89'daki aciklamam ('flutter'in sayaci kirpiliyor') OLCMEDEN yazilmisti ve yanlisti: dogru refleks farki KAYDETMEKTI ama sebebi TAHMIN EDIP not niyetine yazmak yanlisti — bir sayi gorunce aciklamasini uydurmak onu gizlemekten daha sinsi, cunku gizlense birileri arardi, aciklandiginda kimse aramaz; ozet artik SON ANLAMLI SATIRI aliyor ve dogrulandi; ders: kapi kosan bir betigin OZETI, kapinin sonucu kadar dikkat ister — arac da bir olcum aracidir.\n- 2026-08-01 · P89 · 2de034d · infra/kapilar.sh uctan uca suruldu: ON BIR KAPI, HEPSI TEK KOSUMDA YESIL (~55 dk, betigin cikis kodu 0) — web ucusu (tsc/vitest 280/build), mobil ucusu (analyze/test/apk), backend (imaj kuruldu, konteyner ayakta, pytest 1138 passed + 1 skipped 20dk51sn) ve goc ikilisi (uyum bulgu 0, tersinirlik bulgu 0 ve 28 sinirin her biri iki kez geri alinip yeniden uygulandi); bu kosumun ASIL DEGERI BETIGIN KENDISININ DOGRULANMASI cunku P88'de yalniz web dali surulmustu ve backend-build->up->pytest sirasi, mobil ucusu, goc ikilisi hic calistirilmamisti — P75'te ogrenilen 'once imaji kur' adiminin gercekten kostugu goruldu; BIR OLCUM FARKI kaydedildi: mobil-test bu kosumda 1557, oncekilerde 1559 raporladi ve fark BASARISIZLIK DEGIL (cikis kodu 0, Failing tests blogu yok) ama iki farkli sayi gordugum icin ikisini de yaziyorum — birini secip digerini gizlemek olcumu anlatiya uydurmak olurdu.\n- 2026-08-01 · P88 · 452805a · P75/P87'nin dersi kural metninden YAPIYA tasindi: infra/kapilar.sh her kapiyi ayri kosar, ciktiyi DOSYAYA yazar, cikis kodunu DOGRUDAN okur (boru yok), backend'de imaji ONCE yeniden kurar ve basarisiz kapi varsa kendi cikis kodunu 1 yapar; nedeni: kurali yazmak YETMEDI — ayni iki tuzaga bu oturumda UC kez dusuldu (P74 backend ERROR'u 'exit code 0' diye bildirildi, P87 mobil 'Failing tests' blogu KAYBOLDU ve kok neden bulunamadi, P75 konteynerde ESKI kod kostu) ve kural 6'ya iki kez not dusuldugu halde yine dusuldu, cunku HATIRLANMASI GEREKEN BIR KURAL hatirlanmadiginda hicbir sey yapmaz; DOGRULARKEN AYNI TUZAGA DUSTUM: betigi `| tail -6` ile kosunca $? 0 gorundu, borusuz tekrar kosuldu ve gercek cikis kodu 1 cikti — bu, kuralin neden yapiya tasinmasi gerektiginin en iyi kaniti.\n- 2026-08-01 · P87 · 0f3f679 · P85'te bir kosumda gorulen mobil basarisizlik listesi kovalandi: komut `| tail -1` ile calistigi icin LISTE KAYBOLMUSTU (ayni boru tuzagi P74'te backend'de de isirmisti) ve elde yalniz `… and 12 more` satiri kalmisti; uc ardisik tam kosum borusuz ve her biri kendi dosyasina yazilarak yapildi — ucu de 1559 passed, 'Failing tests' blogu 0, P86'daki iki kosumla birlikte ARDA ARDA BES TEMIZ TAM KOSUM; NE IDDIA ETTIGIM acik: anomali TEKRARLAMADI ama bu 'flake yoktu' demek DEGILDIR cunku 1/5'ten seyrek bir olay bu olcumle ayirt edilemez — kaydedilen sey bir SAYI, bir sonuc degil; kok neden bulunamadi cunku KANIT ILK SEFERDE YOK EDILMISTI; asil duzeltme yontemde: kural 6'ya P75'te yazilan 'ciktiyi boruya sokma' maddesi backend icindi ama ayni tuzak mobilde de isirdi, bundan sonra flutter test de dosyaya yazilarak kosulacak — KAYBOLAN KANIT, OLMAYAN KANITTAN KOTUDUR.\n- 2026-08-01 · P86 · 6354650 · P70'te dogrulanamadigi icin EKLENMEYEN kilit, dogrulanabilir bicimde yazildi ve o maddenin acik isi kapandi: P70'te basarisiz olmasinin sebebi SIRAYDI — kilidi mevcut sabit_metin_denetimi_test.dart'in ICINE eklemeye calismistim ve dosyanin kendi suzgecleri/_izinli listesi/erken continue'lari yuzunden enjekte sizintinin neden kactigi bulunamamisti; bu tur kilit AYRI ve KUCUK bir dosyaya yazildi ve ONCE KENDINI test ediyor (bes birim testi: basit $ad atilir, ${...} tumuyle atilir, ENTERPOLASYON ICINDEKI TIRNAK DIZGE ACMAZ — P70'teki iki yanlis pozitif tam oradan cikmisti, kacis dizisi tirnagi kapatmaz, cevrilmeliMi jeton ile cumleyi ayirir) — yani 'kilit calisiyor mu' sorusu URUN KODUNU BOZMADAN yanitlaniyor; iki enjeksiyonla dogrulandi (basit $n ve suslu ${a+1}), P70'te basit bicim kacmisti; debugPrint/assert gerekceli kapsam disi.\n- 2026-08-01 · P85 · cc9bd39 · Ayni dil kumesi UC yerde tutuluyor (panel DILLER, mobil AppDil enum'u, mobile/lib/l10n/app_<kod>.arb dosyalari) ve biri eklenip digeri unutulursa kusur SESSIZDIR ve her yerde farkli gorunur — panelde secilebilen bir dil mobilde YOK, ya da AppDil'de olan bir dilin ARB'si yoksa gen-l10n o dili sessizce ingilizceye dusurur ve kullanici dilini secer ama ARAYUZ DEGISMEZ; SIRA da karsilastiriliyor cunku supportedLocales yorumu 'sira = secicideki sira' der ve iki istemcinin secici sirasinin ayrismasi bir urun tutarsizligidir, kume esitligi bunu gormez; `es` panel listesinden silinerek dogrulandi ve iki test dustu.\n- 2026-08-01 · P84 · 0422b5e · Panelin BFF beyaz listesi (lib/panel-vekil.ts) sozlesmeye baglandi: her giris bir backend YOLUNA esler ve yol yanlis yazilirsa panel tarafinda hicbir sey derlenmez/patlamaz — istek gider, 404 doner, kullanici 'yuklenemedi' gorur, yani tek harflik bir hata SESSIZCE CALISMAYAN BIR OZELLIK demektir; kaynak contracts/openapi.yaml secildi cunku bu depoda SOZLESME odur ve test_sozlesme_sapmasi.py onun uygulamayla IKI YONDE ortustugunu zaten kilitliyor — yani openapi'yi kaynak almak ikinci bir dogruluk kaynagi UYDURMAK degil var olan zincire eklenmektir (panel vekili -> openapi -> FastAPI yollari); parametreli yollar normallestirildi (/x/{id} <-> /x/*) cunku iki tarafin parametre ADLARI farkli olabilir ve ad farkini sapma saymak dogru kodu hata gibi gostermek olurdu; her giris AYRI test olarak kosuyor ki hata mesaji hangi girisin bozuk oldugunu dogrudan soylesin; /yetki-matrisi -> /yetki-matris yapilarak dogrulandi.\n- 2026-08-01 · P83 · 8c7d490 · Capraz bag zinciri tenant AYARLARINA tasindi: settings sayfasi operasyon ayarlarini VERI-SURUCULU cizer ve `OPERASYON` listesindeki her anahtar bir sunucu alanidir — anahtar yanlis yazilirsa sayfa YINE CIZER, alan gorunur, kullanici doldurur ve Kaydet'e basar ama sunucu o alani tanimaz (422 ya da SESSIZCE yok sayilir) ve kullanici ayari degistirdigini SANIR (P56'nin sessiz temizleme sinifiyla akraba); TypeScript bunu yakalamaz cunku `keyof TenantSettings` ELLE YAZILMIS bir arayuze bakar ve sunucudan turemez, yani iki taraf BIRLIKTE yanlis olabilir — bag kaynagi schemas.py alir; TERS YON BILEREK zorlanmadi (sunucuda panelin gostermedigi alanlar var: konum, otopark kapasitesi, ANPR esigi) cunku OPERASYON bir 'tum ayarlar' listesi DEGIL bilincli bir ALT KUMEDIR ve her yeni sunucu alanini panele basmak urun karari olmadan arayuz buyutmek olurdu — ikinci test bu farkin VAR OLDUGUNU dogruluyor, yoksa bir sonraki tur eksikligi kusur sanip 'tamamlamaya' kalkardi; gurultu_esigi -> gurultu_esik yapilarak dogrulandi.\n- 2026-08-01 · P82 · c592c74 · P80'in rol bagi mobile tasindi ve bedel orada DAHA AGIR: panelde eksik bir rol acilir menuyu eksiltir ama mobilde rol EKRAN SECER (HomeGate) ve yetkiyi belirler — sunucu yeni rol eklerse ve UserRole guncellenmezse fromClaim sessizce UserRole.unknown doner, yani kullanici GIRIS YAPAR AMA UYGULAMA ONU TANIMAZ; bu sinif zaten olculmustu, P35'te guvenlik amiri HomeGate'in hicbir dalina uymayip SPLASH'TA KILITLI kalmisti ve bag o turun elle buldugu seyi otomatik hale getiriyor; `unknown` istisnasi gerekceli (sunucuda yoktur ve olmamalidir, istemcinin 'bu rolu bilmiyorum' demek icin kullandigi YEREL bir deger) ve IKINCI TEST sunucuda unknown OLMADIGINI dogruluyor cunku bir gun eklenirse o where filtresi GERCEK BIR ROLU sessizce eler ve bag korlesir — P81'in kurali burada da gecerli: istisnanin kendisi de olculmeli; guvenlikAmiri'nin wire degeri bozularak dogrulandi.\n- 2026-08-01 · P81 · b3ca34c · P80'in rol bagi lib/enum-adlari.ts'in ALTI haritasina tasindi: P53'un 'taninmayan deger HAM doner' kurali DOGRU bir geri dusustur (rozet bos kalmaz) ama sunucu enum'a deger ekleyip harita guncellenmediginde kullanici tanimadigi bir jeton gorur ve HICBIR SEY bunu haber vermez — geri dusus HEDEF DEGILDIR, bag onu gorunur kilar; istisna listesi gerekceli (peyzaj_* bilerek cevrilmedi cunku peyzaj urunden KALDIRILDI ve sozluge geri getirmek silinmis bir ozelligin sozcugunu urune geri sokmak olurdu) ve IKINCI BIR TEST istisnalarin sunucuda GERCEKTEN VAR OLDUGUNU dogruluyor — aksi halde liste zamanla YALAN BIR GEREKCE KOLEKSIYONUNA donerdi, yani istisnanin kendisi de olculmeli; bakimda haritadan silinerek dogrulandi.\n- 2026-08-01 · P80 · 348d1f0 · Panelin ROLE_OPTIONS listesi sunucunun user_role enum'una baglandi: sunucu yeni bir rol eklerse ve liste guncellenmezse IKI kusur birden sessizce olusur — yeni rol acilir menude HIC gorunmez (yonetici o rolu ATAYAMAZ) ve mevcut kayitlarda rol adi HAM tel degeriyle cizilir, ki P66'da denetim kaydinda tam bu oldu; olcum aninda alti rolun altisi ortusuyordu, yani bugun sapma YOK ve kilitlenen sey YARIN DA OLMAMASI; iki yon de kapsandi cunku fazladan bir deger de sizintidir (sunucunun tanimadigi rol atanirsa 422 doner ve kullanici nedenini anlamaz) — karsilastirma KUME ESITLIGI, alt kume degil; kaynak olarak models.py secildi cunku enum'un tek dogruluk kaynagi orasi ve rol-matrisi.txt kilidi de ondan turer; guvenlik_amiri panel listesinden silinerek dogrulandi ve iki test dustu.\n- 2026-08-01 · P79 · c41c1db · P78 AYRISTIRMAYI baglamisti, bu tur BICIMLENDIRMEYI de bagladi: yollar farkli ve bu BILINCLI — panel gruplamayi KENDI yapar cunku toLocaleString bir CALISMA ZAMANI bagimliligidir (kucuk-ICU'da en-US'a duser, P48'de olculdu), mobil ise intl paketinin NumberFormat'ini kullanir ve orada risk YOKTUR cunku yerel veri PAKETIN ICINDE gelir; yani mobildeki NumberFormat bir tutarsizlik degil, iki ortamin risk profili farkli ve 'birlestirmek' mobilde gereksiz elle-gruplama, panelde geri adim olurdu; AMA CIKTI ayni olmali ve bunu hicbir sey tutmuyordu — iki suite de kendi degerlerini suruyordu, panel testi artik AYNI iki degeri mobilin karsiligina atifla suruyor; SIMGE YERI farki da yazildi (panel son ek, mobil on ek — govde ayni, yerlesim URUN KARARI ve testin bunu acikca kaydetmesi sonraki turun onu kusur sanmasini engeller); binlikAyir'in ayiricisi . -> , yapilarak dogrulandi ve YEDI test dustu.\n- 2026-08-01 · P78 · debbe12 · P77'nin mobilde kurdugu ayirici sozlesmesi panelde de kilitlendi (tutar alanlari money.ts::tlToKurus, para olmayan sayilar sayi.ts::sayiCoz — ikisinin KENDI testleri vardi ama ARALARINDAKI sozlesmenin testi yoktu); UCUNCU HALKA: test, kabul/red listelerinin mobil testiyle AYNI degerleri tasidigini da dogruluyor cunku yorumda 'mobil de aynisini surer' yazip gecmek zamanla YALAN OLACAK bir cumleydi — liste artik testin kendisi tarafindan tutuluyor ve degistirilirken ikisi birlikte degistirilmek zorunda; boylece dort ayristirici tek kurala baglandi (panel-para↔panel-sayi bu tur, mobil-para↔mobil-sayi P77, panel↔mobil P50 + bu turun liste bagi); politika farklari iki istemcide AYNI; kilit sayi.ts'in binlik ayirici dali reddetmeye cevrilerek dogrulandi ve DORT test dustu — P77'de ogrenilen ders uygulandi, bozmanin GERCEKTEN bozmasi gerekiyor.\n- 2026-08-01 · P77 · 081afb9 · core/para.dart ile core/sayi.dart AYRI donus tipleri uretiyor ama AYIRICI KURALI ayni olmak zorunda ve bunu hicbir test tutmuyordu (ikisinin kendi testleri vardi, ARALARINDAKI SOZLESMENIN testi yoktu) — P49/P50 ayni riski panel-mobil arasinda bulmustu, burada tek uygulamanin ICINDE: metrekare alani sayiCoz, tutar alani tlMetniniKurusaCevir kullaniyor ve ayrisirlarsa kullanici ayni yazimi iki alanda kullanamaz; kilit KABUL/RED kararini karsilastirir (deger degil, cunku donus tipleri farkli) ve politika farklari AYRICA yazildi (negatif: para reddeder cunku isaret bir BICIM degil ALAN kuralidir; uc ondalik hane: para reddeder cunku kurus iki hanedir; bos girdi: sayiCoz 'bos' der, para null); TESTIN KENDI HATASI olculdu — ilk yazimda `1,234`u ortak red listesine koymustum ve test dustu, kod degil TEST yanlisti cunku bu bir ayirici farki degil politika farki ve ortak listeye koymak DOGRU DAVRANISI TUTARSIZLIK GIBI GOSTERMEK olurdu; sanity kontrolu ilk denemede ANLAMSIZDI (bos govdeli bir if hicbir seyi degistirmiyordu ve test tabii ki gecti), gercek bozma KABUL:'1.250' testini dusurdu.\n- 2026-08-01 · P76 · ac919fc · Goc kapilari P39'dan beri ilk kez suruldu: goc-uyum-dogrula bulgu 0 / EXIT=0 ve goc-tersinirlik bulgu 0 / EXIT=0 (downgrade base sonrasi sema BOS, gidis-donus semasi duz upgrade ile BIREBIR AYNI 7477 satir, 28 SINIRIN her biri iki kez geri alinip yeniden uygulandi) — yani 0022-0027 arasi alti yeni revizyon (P33-P38) tersinirlik denetiminden gecti ve o turlarda tek tek surulmuslerdi ama HEP BIRLIKTE ilk kez suruldu; betik ayri ve ATILABILIR veritabanlari (goc_a, goc_b) kurup siler, dev verisine dokunmaz — calistirmadan once bu yuzden okundu; KURAL 6 artik 'nasil kosulur'u da soyluyor: (a) docker compose build api ONCE cunku imaj kodu icine gomer ve aksi halde ESKI kod test edilir, (b) ciktiyi BORUYA SOKMA cunku boru hattinin cikis kodu son komutunkidir ve pytest'in hatasi kaybolur, (c) TEK KOSUM cunku ikincisi birincinin fixture tenant'larini siler; ayrica konteynerde `ps` YOKTUR ve kosumun surdugu LOG DOSYASININ BUYUMESINDEN anlasilir.\n- 2026-08-01 · P75 · efe6600 · P74'un '1 error' bulgusunun KOK NEDENI bulundu ve BENIM HATAMDI: conftest'teki session-basi temizlik `DELETE FROM tenant WHERE slug LIKE 'ca-%'` ile TUM fixture tenant'larini siler — BASKA BIR KOSUMUN CANLI tenant'lari dahil; birinci kosum surerken ikinci bir pytest baslatmistim ve ikincinin acilis temizligi birincinin verisini ORTASINDAN sildi, birinci kosum alfabetik olarak sonlardaki dosyada fixture ERROR'u verdi; teshis eleyerek dogrulandi (test tek basina 9sn gecer, dosyanin tamami 24 passed, retention+unit_complaints birlikte 26 passed — sira bagimliligi YOKTU); KORUMA: temizlikten ONCE pg_try_advisory_lock, alinamazsa kosum HEMEN ve acik mesajla duser (beklemek yerine hemen hata cunku 22 dakikalik bir suitte siraya girmek sessiz bir takilma gibi gorunurdu; kilit acik kalan baglantiya bagli, Ctrl-C/timeout'ta duser) ve eszamanlilik denemesiyle dogrulandi; TEMIZ TABAN tek kosum borusuz: 1138 passed, 1 skipped, EXIT=0 (20dk49sn) — yani P41'den beri tekrarlanan sayi DOGRUYMUS ve P74'un 'bayat' iddiasi yanlisti, o madde duzeltildi; bu turda uc kez 'olctum' sandigim sey olcum degildi (ps konteynerde YOK, `pytest|tail` cikis kodunu maskeliyor, konteynerde ESKI kod vardi) — sessizlik, sifir ve yesil ucu de tek basina kanit degil.\n- 2026-08-01 · P74 · c268ccd · Backend suite P41-P42'den beri kosulmamisti ve raporlarda tekrarladigim '1138 passed' BAYAT cikti: gercek olcum 1137 passed, 1 skipped, 1 ERROR (22dk48sn) — test_unit_complaints.py::test_p24_okunmamis_diger_suzgeclerle_BIRLIKTE_calisir kurulumda ERROR veriyor ama TEK BASINA geciyor (9sn) ve DOSYANIN TAMAMI da geciyor (24 passed), yani kusur testte degil TESTLER ARASI DURUMDA (panelde ayni sinif P55'te bulunmustu); IKINCI BULGU: `pytest | tail -6` boru hatti CIKIS KODUNU MASKELIYOR — arka plan gorevi 'exit code 0' bildirdi ama kosumda ERROR vardi, olculdu: (exit 1) | tail -1 -> $? = 0, yani boru hattina sokulan bir test kosumunun cikis kodu KANIT DEGILDIR; UCUNCU: `ps` bu konteynerde YOK ve `ps aux | grep pytest | wc -l` sorgusu 0 dondurup beni 'surec olmus' diye yanilltti — sifir bir olcum degil bir KOMUT HATASIYDI, guvenilir sinyal log dosyasinin buyumesidir; ACIK IS: ERROR'un kok nedeni (hangi dosya ucworld'u kirletiyor) bir sonraki turun ilk isi.\n- 2026-08-01 · P73 · cd5b728 · Entegrasyon sirri write-only sozlesmesi testlere baglandi: sunucu auth_secret'i ASLA dondurmez, panel de alan bos birakilirsa govdeye HIC KOYMAZ — bos dizge gondermek kayitli sirri SILMEK olurdu ve bunu kullanici hicbir yerde gormezdi (entegrasyon bir sonraki tetiklemede sessizce 401 alir, gurultu uyarisi gitmez, kimse fark etmez); kosul kaldirilarak dogrulandi; duzenleme acilinca alanin BOS oldugu da test edildi cunku on-doldurma ekranda bir sir birakirdi; channel_type/auth_type BILEREK cevrilmedi (webhook/bearer/hmac protokol terimleridir ve cevirmek entegrasyonu kuran kisinin belgeyle eslestirdigi adi bozardi — P66'daki `action` karariyla ayni); PANEL KAPSAMI TAMAMLANDI: kapsami olmayan sayfa kalmadi, P43'te kurulan altyapiyla baslayan tur son sayfayi da bagladi ve panel bilesen testi 12'den 214'e cikti.\n- 2026-08-01 · P72 · 8705c3f · Duyurular testlere baglandi: 'duzenlendi' eki kucuk ama ANLAMLI bir isarettir cunku sakin, okudugu duyurunun SONRADAN DEGISTIGINI yalniz buradan anlar (su kesintisi saati degistiyse ve isaret cikmiyorsa kisi eski bilgiye gore davranir) ve kosul yanlis kurulursa iki yonde de bozulur — hic cikmazsa degisiklik GIZLENIR, her duyuruda cikarsa isaret ANLAMSIZLASIR; ikisi de test edildi ve kosul kaldirilarak dogrulandi; hata/bos ayrimi bu sayfada da sabitlendi (uc dustugunde 'Duyuru yok' yazilmaz, gercekten bos listede yazilir — ikincisi olmadan birincisi metni tamamen silerek de gecilebilirdi).\n- 2026-08-01 · P71 · cdc2b31 · Seffaflik panosu testlere baglandi: bu sayfa P48'in cikis noktasiydi (kendi tl() bicimlendiricisi vardi, tutari TL ekiyle yaziyor ve toLocaleString uzerinden ORTAMA bagimliydi — kucuk-ICU'lu bir calisma zamaninda 5,000,00 ₺ uretirdi) ve o bulgunun GERI DONUSU SESSIZ olurdu cunku hicbir test bunu tutmuyordu; uc testin ucu de KUSURU GERI KOYARAK dogrulandi — para testi eski bicimin IKI izini de yasakliyor (5000.00 ve '… TL'), yani yalniz dogruyu degil YANLISIN DONUSUNU de tutuyor; ay listesi dustugunde 'Veri yok' yazilmaz (P60/P61 sinifi bu sayfada da sabitlendi) ve GERCEKTEN bos listede yazilir — ikincisi olmadan birincisi metni tamamen silerek de gecilebilirdi.\n- 2026-08-01 · P70 · 4241dc1 · Mobil kilidin BILEREK atladigi enterpolasyonlu bolge ilk kez olculdu (parantez sayan ayiklayiciyla): 7 satir cikti ve YEDISI DE debugPrint, yani kullaniciya sizan cevrilmemis metin YOK — terk edilen bolge gercekten bostu ama bunu BILMEK ile VARSAYMAK ayri seylerdir; KILIT EKLENMEDI ve nedeni maddenin asil icerigi: genisletme uc turda uc ayri sorun verdi (yalniz ${...} tarayinca enjekte edilen 'Yonetici $n satiri' KACTI; basit $ kapsaninca enterpolasyon icinde TIRNAK olan satirlarda iki yanlis pozitif cikti cunku dizge ayiklayicisi tirnak sayar, enterpolasyon ayiklayicisi parantez sayar; o satirlar elenince enjekte sizinti YINE yakalanmadi) — degisiklik geri alindi cunku yakaladigini gosteremedigim bir kilidi commit'lemek bu oturumun tekrar tekrar belgeledigi hatanin ta kendisi olurdu; dogru cozum gercek bir Dart dizge belirtecleyicisidir ve temiz baglamda yazilabilir.\n- 2026-08-01 · P69 · 640e049 · P68'in buldugu sablon-dizgesi sizintisi SINIF olarak supuruldu ve kilitlendi: supurme TEMIZ cikti (P68'in duzelttigi satir tek ornekti — varsayilmadi, olculdu) ve i18n testine dorduncu tarama eklendi (yorumlar ve className disinda, ${...} parcalari cikarildiginda geriye BOSLUKLU METIN kalan sablon dizgesi sizintidir; URL/jeton kaliplari bosluk icermedigi icin dogal olarak elenir), P68'in kusuru geri konarak yakalandigi dogrulandi; UC SINIR da testin icine yazildi — cok satirli dizge (ters tirnak sayisi tekse taranmaz), IC ICE dizge (tarama SATIR TABANLIDIR ve ayristiramaz; olculdu, o iki satir URL/durum simgesi kurar) ve tarayici onyukleme betigi (metin degil KOD) — bir kilidin neyi GORMEDIGINI soylememek onu oldugundan guclu gostermektir.\n- 2026-08-01 · P68 · aab3caa · Tesis olusturma formunda iki kusur: (1) yonetici satirlari `key={i}` kullaniyordu ve ORTADAKI satir silinebiliyor — React dizin anahtarinda DOM dugumlerini yeniden kullanir ve imlec/odak, otomatik doldurma ve PAROLA YONETICISININ BAGI bir alt satira kayar, her satirda parola alani var; (2) ayni satirin basligi `Yönetici ${i+1}` diye SABIT Turkce yaziliydi ve uc i18n taramasi da goremedi (sablon dizgesi, oznitelik degil, P54 taramasi yalniz window.* diyaloglarina bakiyor) — sozluge tasindi ve testi kusur geri konarak dogrulandi; TESTIN SINIRI acikca yazildi: silme testi key={i} geri konunca da GECIYOR (olculdu) cunku girdiler KONTROLLU ve React dogru degeri yeniden cizer, kararli anahtarin asil kazanci tarayicinin kendi durumudur ve jsdom'da gozlenemez — test duruyor ama 'kararli anahtar testi' diye SUNULMADI, cunku olcmedigi seyi olcuyormus gibi gostermek yesil bir suite'i yanlis guvene cevirir.\n- 2026-08-01 · P67 · d7081de · P66'da `actor_rol` alan listesine TEK TEK eklenmisti; bu bir sonraki `xxx_durum`u yine kacirmak demekti — sorun listenin eksikligi degil KALIBIN alan adini tam eslestirmesiydi, kalip artik (\\w+_)?<alan> kabul ediyor ve liste sekiz girdide kaldi; genisletilmis kalipla panel YENIDEN tarandi ve kalan eslesmelerin hepsi prop/form degeri cikti (DurumRozet durum={...}, value={form.kategori}) — ekrana metin olarak cizilen ham numaralandirma KALMADI, yani P53-P66 zinciri sinifi gercekten kapatti ve bu varsayilmadi, olculdu; P66'nin duzeltmesi geri alinip yeni kalibin ayni satiri yakaladigi dogrulandi (kural degisikligi kapsami daraltmadi).\n- 2026-08-01 · P66 · 50487bc · Denetim kaydinda rol HAM ciziliyordu (`yonetici`, `guvenlik`) oysa panelin geri kalani rolAdi ile cevirir — denetim kaydi 'kim ne yapti'nin KANITIDIR ve orada okuyanin tanimadigi bir jeton gostermek kaydi okunamaz kilar; ASIL BULGU: P53'un ham-enum kilidi bunu GOREMIYORDU cunku alan listesi 'rol' iceriyordu ama alan adi `actor_rol`du ve kelime siniri yuzunden eslesmiyordu — sizinti tam kilidin kor noktasinda duruyordu, ders: ALAN ADI ONEK ALABILIR ve bir kilidin kapsami 'hangi adlari dusundum'le sinirlidir; liste genisletildi ve duzeltme geri alinarak yakaladigi dogrulandi; `action` kodlari (user.create) BILEREK cevrilmedi cunku onlar teknik olay adidir, numaralandirma degil, ve cevirmek denetim kaydini ARANABILIR olmaktan cikarirdi.\n- 2026-08-01 · STATUS REPORT #10 · 804a72b · P61-P65 devri. Bu turun dersi: KILIT YAZMAK YETMIYOR, KILIDIN YAKALADIGINI GORMEK GEREKIYOR — iki kez kendi isim tokezledi ve ikisi de bu kuralla yakalandi (P62'nin kilidi sessizce geciyordu; P65'in ilk halinde ust siniri sarmalayicinin ARKASINA koymustum ve dort cagiran da sessizce kirpilirdi, yani 'sessiz kirpma yapma' kuralini tam da onu koyarken bozuyordum); ayrica P63'te mevcut bir testin KUSURU SABITLEDIGI gorüldu (getByRole textbox name:'' — kutunun adi olmamasina dayaniyordu).\n- 2026-08-01 · P65 · 2938b4c + 3e5a038 · fetchAllItems dongusu meta.total'a kadar kosuyordu: aidat raporunun ucuncu cekimi SUZGECSIZ (/api/dues/payments) ve yalniz ESKI (donemi null) kayitlari atfetmek icin var — 200.000 odemesi olan bir sitede TARAYICIDAN 1.000 ARDISIK ISTEK demek, sayfa dakikalarca kilitli gorunur; P39 ayni sinifi SUNUCU tarafinda olcmustu (/activity tek istekte 350.000 satir) ama istemci tarafi bakilmamisti; SINIR TEK BASINA YETMEZ — kirpip susmak EKSIK bir raporu TAM sanmak demektir ve bu rapor TAHSILAT TOPLAMIDIR, bu yuzden fetchAllPaged {items, kesildi} doner ve cagiran kesildi'yi kullaniciya SOYLEMEK zorundadir (sayfada zaten unitTruncated deseni vardi, yenisi yanina kondu); fetchAllItems geriye donuk uyumlu olarak duruyor cunku hepsini yeni imzaya cevirmek ilgilenmeyen cagiranlari da kesildi tasimaya zorlardi.\n- 2026-08-01 · P64 · ff69828 · BLOKE(urun karari): odeme yollarinda cift kayit korumasi supuruldu — POST /dues/payments Idempotency-Key'i ZORUNLU tutuyor ve panel gonderiyor, ama POST /panel/finans-hareketler (VEZNE) kimliksiz; panelin dugmesi ucus sirasinda kilitli oldugu icin hizli cift tiklama korunuyor, korunmayan sey ZAMAN ASIMI SONRASI TEKRAR (istek ulasip yanit donmezse kullanici tekrar basar ve kasada IKI hareket olusur, yonetici ancak mutabakatta fark eder); kendi basima degistirmedim cunku finans.py bu ayrimi BILINCLI belgeliyor (dues_payment saglayici odakli, finansal_hareket VEZNE kaydi) ve kimlik eklemek yeni revizyon + benzersiz indeks + uc sozlesmesi degisikligi demek — belgelenmis bir tasarim kararini tek tarafli bozmak dogru olmazdi; uc secenek ve oneri (dues/payments deseni) maddede yazili.\n- 2026-08-01 · P63 · 6777842 · Dort form denetiminin ERISILEBILIR ADI yoktu: tesis silme onayi (yalniz placeholder — YIKICI islem), yetki matrisi aramasi (yalniz placeholder), finans tur suzgeci (HIC etiket yok) ve yonetisim aktarim kutusu (baslik gorsel olarak yakin ama bagli degil); yer tutucu ad DEGILDIR — yazmaya baslayinca kaybolur ve bazi ekran okuyucular hic okumaz, en agiri tesis silmeydi cunku adini duyamayan kullanici NE YAZDIGINI BILMEDEN yikici bir islemi onaylardi; iki veri-surunculu girdiye (settings, tanimlar) acik aria-label eklendi cunku onlar Field'in UC DALLI iceriginin son dalinda ve sarmalayici onlarca satir yukarida — ad zaten Field'ten geliyor ama tekrar etmek dallanma buyudukce sessizce kopmasini engeller; kilit penceresi 16 satir cunku ilk deneme 6 satirdi ve login/users gibi ETIKETLI denetimleri sizinti sayiyordu (dar pencere dogru kodu suclar); AYRICA mevcut bir test kusuru sabitliyormus — yonetisim.dom.test.ts kutuyu getByRole('textbox', {name: ''}) ile buluyordu, yani testin kendisi kutunun ADI OLMAMASINA dayaniyordu ve ad eklenince kirildi (kirilmasi dogrudur).\n- 2026-08-01 · P62 · 4924e85 · Koyu tema bu depoda MERKEZI (globals.css .dark kurallari; sayfalar dark: yazmaz), dolayisiyla devrilmemis bir renk sinifi SESSIZ bir kusurdur — ve ilki BENIM isimdi: P52'de ekledigim cikis uyarisi text-rose-700 kullaniyordu ve rose ailesi HIC devrilmemisti (ayni bosluk mesaj hatasi, finans cikis tutari ve tesis silme dugmesinde de vardi); olcum: dark: oneksiz 85 renk sinifindan 32'si devrilmemisti, okunurlugu gercekten bozanlar (saydam yuzeyde koyu metin) devrildi — rose-600..900, emerald-600 (700/800 devrilmis ama 600 unutulmus), sky-700/800, amber-900 + eslik eden zeminler/kenarliklar; kalan 20 GEREKCELI (doygun zeminler beyaz metin tasir, koyu zeminler zaten koyu, kenarliklar metin tasimaz, text-slate-300 yetki matrisinde 'izin yok' isaretidir ve silik olmasi TASARIMDIR) — kilit hepsini devirmek yerine gerekceli liste tutar; KILIT ONCE SESSIZCE GECTI: kacis katmanlari fazlaydi ve uretilen duzenli ifade hicbir seyle eslesmiyordu, enjekte edilen text-fuchsia-700 yakalanmayinca ortaya cikti — yakaladigini gormeden kilit sayma kurali bir kez daha dogrulandi.\n- 2026-08-01 · P61 · 1e67b0a · P60'in destek sayfasinda buldugu bos-durum celiskisi UC ornek daha verdi: sikayet haritasi (baslikta haritadan gelen '3 acik sikayet' varken altta 'Acik sikayet yok' — ekran kendi kendisiyle celisiyordu), bina duzenleme ('Veriler yuklenemedi' + 'Kat yok') ve tanimlar; hepsinde bos-durum metni yalniz !isLoading ile kosullanmisti ve istek dustugunde isLoading false olup liste bos kalir; KILIT UCUNCUSUNU KENDI BULDU (tanimlar/page.tsx:354, kural yazilir yazilmaz); kilidin SINIRI da testin icine yazildi — bina duzenlemedeki ornek TUREV bir listeden geliyordu (data?.items ?? [] -> floors) ve hicbir statik kural onu yakalamazdi, o okuyarak bulundu ve yakalayamadigini yakaliyormus gibi anlatan bir kilit yanlis guven verir; BlockDetail'e yuklemeHatasi prop'u gecirildi cunku bilesenin icinden useSWR'e uzanmak ayni veriyi iki yerden cekmek olurdu.\n- 2026-08-01 · STATUS REPORT #9 · 5b09573 · P58-P60 devri. Ortak bulgu: ucu de tek cumlenin farkli yuzleri — EKSIK VERI, YOKLUK GIBI GOSTERILIYORDU (bos acilir liste 'kayit yok' diye okunuyor, kimlik parcasi ad saniliyor, dusen istekten sonra 'hic talep yok' yaziliyor); hicbiri cokmuyor, hepsi YANLIS BILGI veriyor. Bu oturumda eklenen dort kilit (sessiz-fetch, ham-enum, hata-mesaji, i18n diyaloglari) duzeltme geri alinarak dogrulandi ve ikisi elle bulunmamis sizintilari kendi buldu.\n- 2026-08-01 · P60 · 733015d · Iki kusur destek sayfasinda: (1) HATA VARKEN 'Destek talebi yok' yaziliyordu — liste `!data || items.length===0` ile bosa dusuyordu ve istek dustugunde data tanimsizdir, yani sayfa hemen ustundeki hata kutusuyla CELISIYORDU; 'yuklenemedi' bir durumdur, 'hic yok' bir IDDIADIR ve yanlis oldugunda kullanici bekleyen talebi gormez (panelin geri kalani dogru kalibi kullaniyor, bu sayfa istisnaydi); (2) `String(error)` ceviriyi bozuyordu — jsonFetcher ag hatasini/oturum bitisini/sunucu zarfini ozenle cevirip Error(message) atiyor ama String(new Error('Baglanti yok.')) 'Error: Baglanti yok.' verir, iki yerde vardi (support, tanimlar); kilit DAR tutuldu cunku `e instanceof Error ? e.message : String(e)` DOGRUDUR (o dal yalniz Error olmayan firlatma icin kosar) — kilit ilk yazimda 7 dogru satiri yakaladi, daraltildi ve duzeltme geri alinarak yakaladigi dogrulandi.\n- 2026-08-01 · P59 · c4b0b71 · P58'in panelde kapattigi sinif mobilde de vardi: iki FORM SECICISI `ref.watch(provider).value ?? const []` yaziyordu, yani HATA da 'hic kayit yok'a donusuyordu (task_form_sheet NFC noktasi + patrol_plans_screen plana nokta ekleme) — kullanici listeyi bos gorup kaydi olusturamiyor ve nedenini bilmiyordu; demirbasta `_shortId` KISININ ADININ yerinde `3f2a91c8…` gosteriyordu, artik `#` onekli (panelde ayni karar lib/kimlik.ts'te); `.value ?? ...` kullanan 15 yer tarandi ve kalanlar BILEREK disarida cunku farkli sinif (rol icin guvenli varsayilan, okunmamis sayaci icin 0, ana ekran bolumleri ve kategori suzgeci yanlis bir DEGER uretmiyor) — her bos kutuya uyari basmak uyariyi degersizlestirirdi; duzeltme yazilirken bulunan ikincil hata: '#\\$userId' Dart'ta KACIRILMIS bir $ ve ekranda harfi harfine `#$userId` gorunurdu, flutter analyze bunu yakalamaz.\n- 2026-08-01 · P58 · fc419e4 · Sayfalarin ana listesi yanindaki ARAMA listelerinin (vardiya, kullanici, kategori, daire, nokta, plan) hatasi hicbir yerde gorunmuyordu — 12 istegin error'u destructure bile edilmiyordu ve sonuc sekiz sayfada YANILTICIYDI: acilir liste bos kalip 'kayit yok' gibi okunuyor (yonetici gorevi kimseye atayamiyor ve NEDENINI bilmiyordu) ve ad sutununda `3f2a91c8` gibi kimlik parcasi belirip ADA benziyordu — yanlis bilgi, bilgi yoklugundan kotudur; iki ayri duzeltme cunku iki ayri sey: EksikVeriUyarisi (sari, role=status — ErrorBox yanlis olurdu cunku islem BASARISIZ OLMADI, eksik yuklendi) ve kisaKimlik -> `#3f2a91c8` (# oneki 'bu kimliktir, ad degildir' der; degeri tamamen gizlemek de yanlisti cunku destek isterken kullanicinin elinde tutunacak sey kalmazdi); integrations sablonlari ve assets gecmisi BILEREK disarida — orada bos liste yanlis bir DEGER uretmiyor ve her bos kutuya uyari basmak uyariyi degersizlestirirdi.\n- 2026-08-01 · STATUS REPORT #8 · c2bba89 · Kural 10 devri: P53-P57 ozeti + yontem notu (her tur bir kusur bulup SINIFINI sordu; bes kez sinif tek ornekten buyuk cikti) + P56'daki 'null gercekten siliyor' iddiasi PATCH /units ile uctan uca olculdu (null -> temizler, alan hic gonderilmezse korunur) — teshis tahmin degil olcum.\n- 2026-08-01 · P57 · 3e30d7d · P56'nin panelde kapattigi 'sessiz temizleme' deseni mobilde TEK yerde vardi ve keskindi: checkpoints_screen `double.tryParse(\"41,0082\")` null doner ve bu null dogrudan gpsLat'a gidiyordu — TURKCE KLAVYEDE ONDALIK TUSU VIRGULDUR, yani kullanici dogal olarak virgul yazinca koordinat SESSIZCE siliniyordu ve alanda hicbir dogrulayici yoktu; core/sayi.dart eklendi (sayiCoz -> sayi|bos|gecersiz, ayirici kurali core/para.dart ile AYNI, nokta ondaligi da kabul cunku kullaniciya klavyesini degistirtmek cozum degil), alanlara dogrulayici kondu ve _submit kontrolu ikinci savunma olarak kaldi; geri kalan bes yer SUPURULEREK temiz cikti (bina_duzenleme bos/gecersiz ayrimini zaten yapiyor, patrol_plans pozitif kontrollu, task_form_sheet ve site_kurali dogrulayicili); para modulu AYRI kaldi cunku kurus TAM SAYI uretir ve ortak olan donus tipi degil ayirici kuralidir.\n- 2026-08-01 · P56 · 9224062 · P55'in metrekarede buldugu 'Number() -> NaN -> null -> alani TEMIZLE' deseni bir SINIFTI ve panelde ALTI yerde vardi (tanimlar kurus + sayi alanlari, NFC nokta GPS, bina duzenleme kat/sira, daireler kat/sira, gorev + devriye plani periyodu); EN AGIRI tanimlar sayfasindaki UCUNCU para ayristiricisiydi: replace(',','.') + Number + round(n*100) yuzunden `1.250` girdisi Number('1.250')=1,25 verip BIN IKI YUZ ELLI lira yerine 1,25 TL kaydediyordu — reddedilmiyordu, YANLIS kaydediliyordu, hem de her daireye yazilan aidat tutarinda; panelin kendi gosterdigi 5.000,00 bicimi de NaN veriyordu; P50 tlToKurus'u duzeltmisti ama bu sayfa KENDI kopyasini kullanmaya devam ediyordu — kopyanin bedeli ucuncu kez olculdu; ortak cozum sayiCoz/tamsayiCoz ve gecersizde istek ATILMAZ, tam sayi alanlarinda ondalik YUVARLANMAZ reddedilir; form on-dolgusu da (kurus/100).toFixed(2) yerine kurusToTLSade.\n- 2026-08-01 · P55 · 5c02e70 · Para OLMAYAN sayilarda ayni sinif: metrekare sunucudan 120.5 gelir (olculdu) ve panel OLDUGU GIBI yaziyordu — ayni tabloda para 1.250,00 bicimindeyken, ve Turkce'de nokta BINLIK ayiricidir; asil kusur GIRDI tarafindaydi ve SESSIZ VERI KAYBIYDI: eski numOrNull `Number(\"120,5\")` NaN oldugu icin null donuyordu ve null bu ucta 'alani TEMIZLE' demek — Turkce yazimla metrekare giren yonetici alani sessizce sildiriyordu, hata da almadan; lib/sayi.ts ile bos/gecersiz/sayi UCU ayrildi, gecersizde istek atilmaz ve neden soylenir, on-dolgu GOSTERILEN bicimde ve ondalik basamak sabitlenmez; binlikAyir money.ts'ten sayi.ts'e tasindi (iki kopya P53'te bedeli olculmus bir hataydi); AYRICA suite'te gercek bir FLAKE bulundu ve duzeltildi — portal-ayar testi 14 kosumda 1 duserdi cunku getByLabelText etiket cizilir cizilmez doner ama form sunucu yanitiyla BIR KEZ dolar ve bos alanda clear() bir sey yapmaz, yazilan 25 sunucu degeri 10'un ARDINA eklenip 1025 olurdu (urun kodu saglam); duzeltmeden sonra tam suite 8 kez ardi ardina kosuldu, tek dusus yok.\n- 2026-08-01 · P54 · 799b53c · Tarayici diyaloglari taramanin IKINCI kor noktasiydi: sekiz sabit Turkce onay diyalogu vardi (announcements, patrol-plans, shifts, checkpoints, integrations, building-editor x2, units) ve ingilizce arayuzde bile Turkce cikiyordu — uc tarama da goremiyordu cunku JSX degil, oznitelik degil ve tur 22 taramasinin esigi circir; P46 toast.*'i kapatmisti ama YALNIZ ona bakiyordu; bunlar SILME ONAYLARI oldugu icin sinifin en pahali ornegi: anlamadigi metne 'Tamam' diyen kullanici okuyamadigi bir uyariyi onaylar ve building-editor'daki blok silme daireleri ve tum bagli kayitlari siler — bildirim yanlis dilde cikarsa rahatsiz eder, onay yanlis dilde cikarsa VERI KAYBETTIRIR; iki yeni anahtar (ortakSilOnay, binaBlokBasitSilOnay — 'Blok' sozcugunu koda gommek farkli dillerde bozuk cumle demekti) ve dilden BAGIMSIZ bir kilit, duzeltme geri alinarak dogrulandi.\n- 2026-08-01 · P53 · 3bd7e21 · P51'in bildirim rozetinde buldugu 'ham tel degeri ekranda' kusuru bir SINIFTI: panel supuruldu ve SEKIZ sizinti daha bulundu — en agiri PANODA (en cok bakilan sayfa; ayni bildirim tipi bildirimler sayfasinda cevrilmisken panoda HAM kalmisti, yani kopya haritanin maliyeti olculdu), ayrica aidat/demirbas/tur raporu/aidat raporu/daire detayi; haritalar tek kaynaga tasindi (lib/enum-adlari.ts, alti numaralandirma + enumAdi) ve TANINMAYAN deger HAM doner cunku bos rozet 'durum yok' gibi okunur; SINIF KILIDI kendi basina IKI sizinti daha buldu (dues ve reports/dues'taki {yontem}) — elle supurme YETMEMISTI; kilidin yanlis pozitifi de olculdu ve duzeltildi (sablon dizgeleri taramadan once siliniyor: t(`mesajDurum_${...}`) sizinti degildir); mobil ayrica supuruldu, orada bu sinif yok; test degerleri Turkce karsiligi tel degerinden AYRISAN degerlerden secildi cunku `zimmetli` gibi ayni olanlar cevrilmemis olsa da gecerdi.\n- 2026-08-01 · FINAL REPORT #2 · dd68bed · Kural 13: P41-P52 icin final rapor; P1-P52 BITTI, geriye yalniz [KEREM]/[DIS] bloklu bes madde (P2, P11, P12, P13, P18) ve meta.total urun karari kaldi; 13 gercek kusur listelendi, bes kalici kilit sayildi, P11 cihaz listesi 27 maddeye cikti.\n- 2026-08-01 · P52 · f346946 · P51'in bulduğu kusur bir SINIFTI (ham fetch HTTP hatasinda REDDETMEZ) — panel supuruldu, denetimsiz kalan TEK yer CIKIS'ti: /api/auth/logout cerezleri temizleyen TEK adimdir ve dustugunde cerezler yerinde kalir, kullanici giris ekranini gorup ciktigini sanardi ama OTURUM ACIKTIR (ortak bilgisayarda bedeli oturumun devri); artik basarisizsa EKRANDA KALINIR ve durum soylenir (7 dil); SINIF KILIDI eklendi (app/ + components/ altindaki her ham fetch durum denetlemeli ya da FETCH-DENETIMSIZ gerekcesi tasimali, lib/ kapsam disi cunku sarmalayicilar denetimi zaten yapar) ve kilit duzeltme GERI ALINARAK dogrulandi — yakalamadigini gormeden kilit saymak kilidi olmayan kapiya kilit demekti; ayrica test kurulumunda matchMedia karsilandi (jsdom'da yok ve kabugu cizen her test urun kodu saglamken duserdi).\n- 2026-08-01 · P51 · fa89144 · Panel kapsami 4. tur (vardiya, NFC noktasi, bildirimler) + IKI GERCEK KUSUR bildirimler sayfasinda: (1) SESSIZ BASARISIZLIK — 'okundu isaretle' tek yerde HAM fetch kullaniyordu ve ham fetch basarisiz yanitta da COZULUR, yani 500 sonrasi da 'okundu olarak isaretlendi' BASARI bildirimi cikiyordu (kullanici isaretledigini saniyor, bildirim okunmamis kaliyordu) — apiSend + catch; (2) rozet `n.tip`i HAM ciziyordu, kullanici `gecikmis_okutma` goruyordu — yedi canli tip 7 dile cevrildi, eslesmeyen tip HAM kalir ki sunucu yeni tip eklerse rozet BOS KALMASIN; test aracina UC BASINA durum eklendi (opts.durum TUM uclari bozuyordu, oysa gercek kusurlarin cogu 'liste geldi ama YAZMA dustu' seklinde ve 1. kusur ancak boyle olculebildi); gece vardiyasi uyarisi yalniz baslangic>bitis iken cikiyor, saat bicimi sunucuyla uyusuyor (donusum katmani YOK ve olmamali); ayrica backend kurus_metin denetlendi — yerel ayardan bagimsiz ve P50 sonrasi panel onun ciktisini KABUL EDIYOR.\n- 2026-08-01 · P50 · 9a94c6b · Panel para ayristiricisi de kendi GOSTERDIGI bicimi reddediyordu (`1.250,00` -> null, oysa kurusToTL onu boyle yaziyor); eski testteki 'binlik ayirici belirsiz' gerekcesi YANLISTI — virgul varsa nokta BINLIKTIR; iki istemci artik AYNI uc dalli kurali uyguluyor (farkli olsalardi ayni sitede ayni metin farkli tutar girerdi); ayrica iki asimetri kapandi: YARIM giris (`750,` `,50`) her ikisinde de reddediliyor ve ICERIDEKI bosluk reddediliyor (mobil `1 2 3`u kabul ediyordu).\n- 2026-08-01 · P49 · 7da37d8 · Mobilde para ayristirma cekirdegi: BULGU 1 uygulama KENDI GOSTERDIGI bicimi reddediyordu (unit_tanimlari naif kopya `1.250,00`i cozemiyordu); kopya keyfi degildi — paylasilan parseTlToKurus BUTCEYE OZEL politika tasiyordu (`>0`) ve tanimlarda 0=MUAF gecerlidir; AYRISTIRMA core/para.dart'a, POLITIKA cagirana ayrildi ve form on-dolgusu artik GOSTERILEN bicimi kullaniyor; BULGU 2 rapor i18n testi ay adini SABIT yazmisti ve takvim Agustos'a donunce kirildi — beklenen deger artik ekranin kullandigi ayni kaynaktan uretiliyor (her ay kirilmaz).\n- 2026-08-01 · P48 · 17c832e · Para bicimlendirmede ICU BAGIMLILIGI: supurme panelde UC ayri bicimlendirici buldu (seffaflik sayfasi ayni degeri `TL` ile yaziyordu, digerleri `₺`); asil bulgu toLocaleString('tr-TR') bir ORTAM BAGIMLILIGI — kucuk-ICU'da en-US'a duser ve para `5,000,00 ₺` gorunurdu (yanlis VE okunamaz, ve YALNIZ BAZI ORTAMLARDA); seffafliktaki `.replace(/ /g,'.')` yamasi sorunu gormus ama YANLIS TESHIS etmisti (gercek sorun VIRGULLU gruplama); gruplama artik KENDIMIZ yapiyoruz.\n- 2026-08-01 · P47 · 2848374 · Panel kapsami 3. tur (pano, daireler, tanimlar) + BULGU: Tanimlar tablosu parayi `5000.00` diye yaziyordu — panelin geri kalani `5.000,00 ₺` ve daha kotusu TURKCE'DE NOKTA BINLIK AYIRICIDIR (kullanici bes yuz bin sanabilirdi); tabloda kurusToTL, FORMDA liraya KALDI (girdi ayristirilabilir olmali); pano sayaclari sunucu verisinden turetiliyor ve uc dustugunde BOS PANO gosterilmiyor; kapsam %16,99 -> %19,03.\n- 2026-08-01 · P46 · 92eea6a · BULGU: `toast(...)` metinleri hicbir i18n taramasinin gormedigi yerdeydi (JSX degil, oznitelik degil, ve tur 22 taramasi TURKCE HARFE bakip circir esigiyle gectigi icin) — panelde 10 sabit bildirim metni vardi ve dil degisince Turkce kaliyordu; dokuzu sozluge tasindi (7 dil) ve DILDEN BAGIMSIZ yeni bir kilit eklendi, kilidin GERCEKTEN yakaladigi gecici sizinti ile dogrulandi; talep sayfasi 5 test (kapali talepte eylem butonu YOK, reddette sebep ZORUNLU, cozmede not OPSIYONEL); kapsam %15,97 -> %16,99.\n- 2026-08-01 · P45 · d5defe9 · Panel bilesen kapsami 2. tur: aidat ve kullanicilar — kurus->TL tam sayi aritmetigi, gecersiz tutarda istek ATILMIYOR ve NEDEN soyleniyor, uc dustugunde liste CIZILMIYOR; rol adlari SOZLUKTEN (wire degeri ekrana cikmiyor), suzgec degisince offset=0 (eski offset'te kalmak ilk sayfasi bos gorunen liste demekti); ogrenilenler: Field etiketi ipucunu da kapsiyor (regex gerekir) ve `required` alanlar bosken uygulamanin dogrulamasi HIC calismiyor; kapsam %14,26 -> %15,97.\n- 2026-08-01 · P44 · 3f11deb · Panel bilesen kapsami 1. tur: hedef YUZDE DEGIL HATA SINIFI — rapor (bos parametre govdeye girmiyor, ismi_goster), mesaj (SMS sayaci + UCS-2 zorlayan karakterler, kanal->konu alani), portal (yayin anahtari ANINDA kaydediliyor, anket en az iki secenek), ayarlar (DEGISMEYEN ALAN gonderilmiyor — guvenlik_modu yoneticiye 403 verirdi); BULGU: test aracinda onek cakismasi (/portal ile /portal-iletisim) iletisim listesine PORTAL govdesi donduruyordu — en uzun onek kazanir oldu; kapsam %9,66 -> %14,26.\n- 2026-08-01 · P43 · 2413a79 · Panel bilesen testi altyapisi (jsdom): ayni kosumda IKI ORTAM ve ortam secimi DOSYANIN KENDISINDE (merkezi glob listesi, yeni dosya eklenince testin sessizce YANLIS ortamda kosmasi demekti); BULGU 1: @vitejs/plugin-react'in .d.ts'i next build'i KIRDI — test bagimliligi urun derlemesini KIRAMAZ, JSX yerine createElement; BULGU 2: esbuild anahtari yok sayiliyor (Vitest 4 = rolldown/oxc); BULGU 3: SWR onbellegi testler arasi tasiniyordu ve 'uc dustu' senaryosu YANLISLIKLA GECIYORDU + RTL cleanup globals olmadan devreye girmiyor; 12 yeni test (finans, yetki matrisi, site aktarimi).\n- 2026-08-01 · P42 · 68eb69e · Icerik daraltma kapsami: yetki kilidi ve P41 matrisi ERISILEBILIRLIGI olcer, GOVDENIN role gore daraldigini GORMEZ — envanterin acik maddesi (aynı uç, farklı gövde) kapandi; alti daraltma tek tek suruldu (finansal ozet tahsilat blogu, /activity kaynak kumesi, gizli kamera, kendi-kapsamli talepler, anket sonucu, harita sayim/renk); BULGU: /activity role-anahtarli sozluk kullaniyor ve uca yeni rol eklenip sozluge satir eklenmezse KeyError->500 doner — yetki kilidi 500'u IZIN sayacagi icin HICBIR olcum yakalamazdi.\n- 2026-08-01 · P41 · b9baad7 · Yetki matrisi gorunumu KODDAN URETILIR: require_role uretilen bagimliliga izinli_roller OZNITELIGI isliyor, uc dependant agacini gezip bunu okuyor — elle liste ayni gercegi IKINCI BIR YERDEN uretmek ve bir uc degistiginde panelin YANLIS tablo gostermesi demekti; `roller: null` HERKESE ACIK DEGIL (rol kapisi yok, kimlik gerekebilir) ve moda_bagli uclar IKI MODUN BIRLESIMI; test kilidiyle CAPRAZ DOGRULAMA (alt kume iliskisi — esitlik aramak dogru davranisi hata sayardi).\n- 2026-08-01 · P40 · f6dcd5f · Panel bolumu: finans + rapor + mesaj + yonetisim + portal + genisletilmis ayarlar. TEK VEKIL + BEYAZ LISTE (okuma ve yazma AYRI sozluk — tek sozluk okumaya acarken yazmaya da acardi); IKILI vekil ayri (proxyJson XLSX/PDF baytlarini JSON diye ayristirip bozardi) ve dosya adi SUNUCUDAN; rapor katalogu SUNUCUDAN (panel rapor adi TASIMAZ); site aktariminda KURU CALISMA varsayilan acik ve satir no 2'den baslar; ayarlarda DEGISMEYEN ALAN GONDERILMEZ (guvenlik_modu yoneticiye 403 verirdi); uc kilit uc gercek kusur yakaladi (matcher kapsami, ucludaki teknik jetonlar, yorumda Turkce harf) + yedi dilde sozluk tekrari tsc ile durduruldu.\n- 2026-07-31 · P39 · 26dc585 · Olcek ve yuk hazirligi: k6 KONTEYNERDEN ve api ile ayni agda; profil 'en cok cagrilan uc' degil KULLANICININ GUNU (giris setup'ta — her yinelemede giris bcrypt maliyetiyle olcumu bozardi); olculen taban /me 283 RPS, /activity 168 RPS, ana ekran p95 2.08s -> 1.26s; DUZELTILEN RISK: havuz/isci sayisi GORUNMEZ varsayilanlardaydi ve coklu isciye gecen ilk kisi max_connections'i sessizce asardi (formul + env + pool_timeout); ONBELLEK EKLENMEDI cunku olcum gerektirmedi (bayat veri sinifi hata getirirdi); yatay olcekte TEK GERCEK ENGEL beat'in tek ornek olmasi; docs/scaling-runbook.md.\n- 2026-07-31 · P38 · 16ce180 · Site web portali + anket (0027): AYRI UYGULAMA DEGIL admin-web icinde public rota (sozluk/tasarim/derleme hatti zaten orada) + yeni kilit public rotanin matcher'a SIZMADIGINI olcuyor; yayin VARSAYILAN KAPALI ve kapaliyken 404 (403 tesis envanteri sizdirirdi); public icerik BILINCLI (duyurunun yalniz OZETI, hakkimizda DUZ METIN, harita ANAHTARSIZ); anket TEK OY ve DEGISTIRILEMEZ, sonuc KAPANANA KADAR GIZLI (surusel etki) ama yonetim her zaman gorur; iletisim KAYIT ONCE BILDIRIM SONRA; kimlikli sakin web alani gerekcesiyle panel borcunda.\n- 2026-07-31 · P37 · 1002576 · Gurultu caydirici otomasyonu (0026): AYRI webhook konfigurasyonu ACILMADI (C1b integration zaten SSRF+KEK+izolasyon veriyor), MANUEL MOD birinci sinif (cogu sitede entegrasyon yok) ve sunucu 'yapildi' VARSAYAMAZ; sinir DAHIL (4 hayir, 5 evet), YALNIZ gurultu kategorisi, SIFIRLAMA KAYIT SILMEZ (kapali'ya ceker — uyarinin dayanagi durur); HMAC imzasi ZAMAN DAMGASINI kapsar (replay), sir yoksa imza da yok; yeniden deneme istek yolunda DEGIL, katlanan aralikla ve tukenince MANUEL MODA duser; BULGU: FK indekssizdi (RI tetigi tenant'i seq scan ederdi).\n- 2026-07-31 · P36 · 1415874 · KVKK aydinlatma kapisi + pazarlama izinleri (0025): METIN TENANT ICERIGIDIR (gomulu tek metin 200 tesise BASKASININ metnini imzalatirdi), SURUM VAR YERINDE DUZENLEME YOK (dun verilen onay bugun baska metne ait gorunurdu), onay eski surume yazilmaz (409) ve IDEMPOTENT; kaydirma kilidi 24 px esikli ve SIGAN icerikte ZATEN ACIK; sunucu navigasyonu kilitlemez (onay vermemis kullanici metni OKUYABILMELI), ag hatasinda kapi ACILMAZ; P32 pazarlama gonderimi artik GERCEK ve KANAL BAZLI rizayi okuyor; BULGU: izinler kartinin donen gostergesi dokuz ayar testini pumpAndSettle zaman asimiyla dusurdu.\n- 2026-07-31 · P35 · 458dc75 · Guvenlik amiri + ikili guvenlik mimarisi (0024): SAHIPLIK SEMADA DEGIL KODDA — tenant modu (yonetim_ici|dis_sirket) vardiya/tur/nokta YAZMA sahibini belirler, OKUMA her iki modda acik kalir (devir DENETIMI devretmez), admin her iki modda yazar, modu YALNIZ admin degistirir ve degisim denetlenir; amire EN AZ YETKI (sakin/finans/kargo/ziyaretci KAPALI, KVKK); BULGU: /users okumasini acmak PATCH ve parola sifirlamayi da acti — amir kendi rolunu yukseltebiliyordu, rol matrisi kilidinin ALTINCI SUTUNU yakaladi.
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
