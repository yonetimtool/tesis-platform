// @vitest-environment jsdom
// (P170 §4) OZET SAYFASI — WIDGET IZGARASI VE TAKVIM.
//
// =========================================================================
// NE OLCULUYOR
// =========================================================================
// 1. IZGARA KIRILMA NOKTALARI: 2 -> 3 -> 4 -> 7. Sutun sayilari zaten
//    dogruydu; bozuk olan HIZAYDI, o yuzden asil olcum TEK KALAN KARTIN
//    tam genislik almasi.
// 2. TAK KALAN KART: 7 kart iki sutuna sigmaz ve sonuncusu satirin sol
//    yarisinda tek kalirdi; sagdaki bosluk "eksik kart" gibi okunuyordu.
// 3. TAKVIMDE AJANDA GERCEK BIR GORUNUM: P169'da `sm`de ay izgarasinin
//    YERINE geciyordu ve arac cubugundaki "Ay" dugmesi BASILIYOR AMA
//    HICBIR SEY OLMUYORDU — yani bir anahtar vardi ve yalan soyluyordu.
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";

const WIDGET = readFileSync("components/pano/widget-seridi.tsx", "utf8");
const TAKVIM = readFileSync("components/pano/takvim.tsx", "utf8");

describe("(P170 §4.1) widget izgarasi", () => {
  it("kirilma noktalari 2 -> 3 -> 4 -> 6", () => {
    // (P182 §3) Masaustu 6 sutun: sinir 6 iken 6 widget tam doldurur, sagda
    // bos sutun kalmaz. Dokunma katmanlari (2/3/4) korunur.
    expect(WIDGET).toContain("grid-cols-2");
    expect(WIDGET).toContain("sm:grid-cols-3");
    expect(WIDGET).toContain("md:grid-cols-4");
    expect(WIDGET).toContain("lg:grid-cols-6");
  });

  it("TEK KALAN kart iki sutunlu bantta TAM GENISLIK alir", () => {
    // `col-span-2` YALNIZ iki sutunlu bantta; `sm:col-span-1` onu geri
    // alir, yoksa uc sutunlu izgarada da genis kalirdi.
    expect(WIDGET).toContain("col-span-2 sm:col-span-1");
    expect(WIDGET).toContain("gosterilen.length % 2 === 1");
  });

  it("kart icerigi DIKEY ORTALI ve kartlar esit yukseklikte", () => {
    // `h-full` izgarada esit yukseklik verir; `justify-center` ikonlari
    // ayni yataya oturtur (etiketler bir ya da iki satir olabiliyor).
    expect(WIDGET).toMatch(/flex h-full min-h-24 flex-col items-center justify-center/);
  });

  it("duzenleme oklari DOKUNMA HEDEFI sinifini tasir", () => {
    // `px-2` bir ok dugmesini ~20 px birakir; kaba isaretcide 44 px.
    expect(WIDGET).toContain("yz-dokunma-44");
  });
});

describe("(P170 §4.2) takvim", () => {
  it("AJANDA gercek bir gorunum ve arac cubugunda YER ALIR", () => {
    expect(TAKVIM).toContain('const GORUNUM_AJANDA = "ajanda"');
    expect(TAKVIM).toContain('{ id: GORUNUM_AJANDA, anahtar: "takvimAjanda" }');
    // Tip de genislemis olmali; aksi halde dugme derlenmezdi.
    expect(TAKVIM).toContain('"gun" | "hafta" | "ay" | "ajanda"');
  });

  it("(P176) VARSAYILAN HER BANTTA AY — bant otomatigi KALKTI", () => {
    // =====================================================================
    // BU IDDIA YON DEGISTIRDI
    // =====================================================================
    // P170'te dar ekranda ajanda VARSAYILANDI; gerekce P169'dan
    // devralinmisti ("ay izgarasi okunmuyor"). Ama okunmazligin sebebini
    // P170'in KENDISI ortadan kaldirdi: dar ekranda hucre 56 px'e indi ve
    // olay adi yerine NOKTA cizilir oldu (asagidaki iddialar bunu hâlâ
    // olcuyor). Geriye yalniz varsayilan kalmisti.
    //
    // P176 varsayilani AY yapti. Bant otomatigi ve `secildiRef` bayragi
    // GEREKSIZ kaldi: artik ezilecek bir otomatik karar yok, kullanicinin
    // secimi `localStorage`ta duruyor.
    //
    // Ayrintili kilit: `takvim-gorunum.dom.test.ts`.
    expect(TAKVIM).not.toContain("secildiRef");
    expect(TAKVIM).not.toContain("setGorunum(GORUNUM_AJANDA)");
    // AJANDA KALDIRILMADI — arac cubugunda duruyor.
    expect(TAKVIM).toContain('{ id: GORUNUM_AJANDA, anahtar: "takvimAjanda" }');
    // SECIM KALICI.
    expect(TAKVIM).toContain("GORUNUM_ANAHTARI");
  });

  it("AY IZGARASI DAR EKRANDA OKUNUR KALIR: nokta var, metin gizli", () => {
    // Olay adi 45 px'lik bir hucrede iki harfe duser; nokta ise "bu gunde
    // bir sey var" bilgisini TAM tasir.
    expect(TAKVIM).toContain("flex flex-wrap gap-0.5 sm:hidden");
    expect(TAKVIM).toContain("hidden space-y-0.5 sm:block");
    expect(TAKVIM).toContain("min-h-14 rounded-lg border p-1 text-start align-top sm:min-h-20");
  });

  it("AJANDA SABIT YUKSEKLIKTE ve icinde kayar", () => {
    // Ay degistirmek olay sayisini degistirir; kap serbest buyuseydi
    // sayfanin ALTINDAKI her sey yukari cekilirdi.
    expect(TAKVIM).toContain("AJANDA_YUKSEKLIGI");
    expect(TAKVIM).toContain('className="overflow-y-auto"');
  });

  it("ACILISTA BUGUNE kaydirilir — SAYFA degil KAP", () => {
    // `scrollIntoView` ATALARI da kaydirir: pano sayfasi takvimin
    // bulundugu yere ziplardi.
    expect(TAKVIM).toContain("kap.scrollTop = hedef.offsetTop - kap.offsetTop");
    // `scrollIntoView` KOD OLARAK cagrilmamali (yorumda gecmesi serbest:
    // orada NEDEN kullanilmadigi yaziyor).
    expect(TAKVIM).not.toMatch(/\.scrollIntoView\(/);
  });

  it("BUGUN vurgusu RENKTEN IBARET DEGIL — rozet de var", () => {
    // Renk tek basina yeterli bir isaret degil: renk korlugunde ve dusuk
    // kontrastli ortamda kaybolur.
    expect(TAKVIM).toContain('{t("takvimBugun")}');
    expect(TAKVIM).toContain("bugunMu && (");
  });

  it("BOS GUNLER AJANDADA CIZILMEZ", () => {
    expect(TAKVIM).toContain("(gunlukKume.get(g.toDateString()) ?? []).length > 0");
  });
});
