// @vitest-environment jsdom
// (P214) KATMAN DUZENI — modal haritanin ALTINDA kalmasin.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// `/checkpoints` -> "Yeni nokta" modali aciliyor ama Leaflet haritasi
// USTUNU kapatiyordu; yalnizca modalin haritadan TASAN alt seridi (Iptal/
// Kaydet) gorunuyordu.
//
// KOK NEDEN (varsayim degil, iki dosyadan OKUNAN sayilar):
//   uygulama olcegi : 0-80   (`--yz-z-modal: 60`, app/tasarim-sistemi.css)
//   Leaflet         : 200-1000 (`.leaflet-pane` 400, kontroller 1000,
//                               leaflet/dist/leaflet.css)
// Modal portal KULLANMIYOR (`fixed inset-0`, sayfa agacinda), yani ikisi
// AYNI kok yiginlama baglaminda yarisiyor ve 400 > 60.
//
// ===========================================================================
// COZUM ve BU DOSYANIN OLCTUGU SEY
// ===========================================================================
// Leaflet'in on kadar kuralini tek tek ezmek yerine harita KENDI
// yiginlama baglamina hapsedildi (`isolation: isolate`). Bu dosya UC
// SEYI olcer:
//   1. Olcek ic tutarli ve UCUNCU PARTI BANDINA (>=100) girmiyor,
//   2. Leaflet kullanan HER bilesen izole (yeni bir harita eklenirse
//      kilit duser),
//   3. Kodda olcek disi ham z-index degeri kalmadi.
//
// OLCEMEDIGIM: jsdom gercek yiginlama sirasini HESAPLAMAZ — "modal
// piksel olarak ustte" iddiasini bir birim testi kuramaz. Olculen sey
// KATMAN ILISKISI; gorsel dogrulama tarayicida yapildi (bkz. tur notu).
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = resolve(__dirname, "..");
const oku = (y: string) => readFileSync(resolve(KOK, y), "utf8");

const TASARIM = oku("app/tasarim-sistemi.css");
const LEAFLET = oku("node_modules/leaflet/dist/leaflet.css");

/** `--yz-z-*` tanimlari (ad -> sayi). */
function olcek(): Record<string, number> {
  const d: Record<string, number> = {};
  for (const m of TASARIM.matchAll(/--yz-z-([a-z]+)\s*:\s*(\d+)\s*;/g)) {
    d[m[1]] = Number(m[2]);
  }
  return d;
}

/** Leaflet'in KENDI kullandigi en yuksek katman degeri. */
function leafletAzami(): number {
  const hepsi = [...LEAFLET.matchAll(/z-index:\s*(\d+)/g)].map((m) => Number(m[1]));
  return Math.max(...hepsi);
}

describe("(P214) z-index olcegi", () => {
  it("olcek DOLU ve beklenen katmanlari tasiyor", () => {
    const o = olcek();
    // Olcum bosa dusmesin: regex bozulursa bu iddia once duser.
    for (const ad of ["base", "dropdown", "drawer", "modal", "toast", "tooltip"]) {
      expect(o[ad], ad).toBeTypeOf("number");
    }
  });

  it("SIRA anlamli: dropdown < drawer < modal < toast < tooltip", () => {
    const o = olcek();
    const sira = [o.base, o.sticky, o.sidebar, o.header, o.dropdown, o.drawer,
                  o.modal, o.toast, o.tooltip];
    expect(sira).toEqual([...sira].sort((a, b) => a - b));
    // Esitlik de bir hatadir: esit iki katmanda sirayi DOM konumu belirler
    // ve sonuc tesadufe kalir (Toast ile modal tam olarak boyleydi).
    expect(new Set(sira).size).toBe(sira.length);
  });

  it("olcek 0-99 BANDINDA kalir — 9999'a kacis yok", () => {
    for (const [ad, deger] of Object.entries(olcek())) {
      expect(deger, ad).toBeLessThan(100);
    }
  });
});

describe("(P214) ucuncu parti katmanlari IZOLE edilir", () => {
  it("Leaflet olcegimizin USTUNDE — bu yuzden yarismamali", () => {
    // Kok nedenin kendisi: kutuphanenin degeri bizim EN YUKSEK
    // katmanimizdan buyuk. Bu iddia dusesiye kadar izolasyon ZORUNLU.
    const enYuksek = Math.max(...Object.values(olcek()));
    expect(leafletAzami()).toBeGreaterThan(enYuksek);
  });

  it("Leaflet kullanan HER bilesen KENDI baglamina hapsedilmis", () => {
    // Yeni bir harita bileseni eklenip izolasyon unutulursa bu duser.
    const kaynaklar = ["components/harita/konum-haritasi.tsx",
                       "components/harita/plan-haritasi.tsx"];
    for (const y of kaynaklar) {
      const s = oku(y);
      expect(s, y).toContain("MapContainer");
      expect(s, `${y}: isolation yok`).toContain('isolation: "isolate"');
    }
  });

  it("izolasyon LEAFLET'IN IC SIRASINI ezmiyor", () => {
    // Alternatif cozum (`.leaflet-pane { z-index: 4 }` gibi ezmeler) hem
    // ic sirayi bozar hem surum degisince sessizce kirilir. Boyle bir
    // ezme yazildiysa bu kilit haber verir.
    const css = oku("app/globals.css") + oku("app/tasarim-sistemi.css");
    const ezme = [...css.matchAll(/\.leaflet-[a-z-]+[^{]*\{[^}]*z-index/g)];
    expect(ezme.map((m) => m[0])).toEqual([]);
  });
});

describe("(P214) kodda olcek disi ham z-index kalmadi", () => {
  it("`z-[<sayi>]` ve `zIndex: <sayi>` KULLANILMIYOR", () => {
    const dosyalar = [
      "components/Toast.tsx",
      "components/ui/dokunma-kapisi.tsx",
      "components/ui/modal.tsx",
      "components/AppShell.tsx",
    ];
    for (const y of dosyalar) {
      // Yorum satirlari haric (kaldirilan degerler ORADA anlatiliyor).
      const kod = oku(y)
        .split("\n")
        .filter((s) => !s.trim().startsWith("//") && !s.trim().startsWith("*"))
        .join("\n");
      expect(kod.match(/z-\[\d+\]/), `${y}: ham tailwind z-index`).toBeNull();
      expect(kod.match(/zIndex:\s*\d/), `${y}: ham zIndex`).toBeNull();
    }
  });

  it("modal olcekteki `--yz-z-modal`i kullanir", () => {
    expect(oku("components/ui/modal.tsx")).toContain("var(--yz-z-modal)");
  });
});

// ===========================================================================
// DAVRANIS OLCUMU — modal ile harita AYNI SAYFADA cizilirken
// ===========================================================================
// Yukaridaki iddialar kaynak/olcek duzeyinde. Bu blok gercek sayfayi
// cizer, modali GERCEKTEN acar ve iki seyi olcer:
//   1. Form alanlari CIZILDI mi (kullanicinin goremedigi seyler),
//   2. Modal olcekteki katmani tasiyor mu ve harita kutusu IZOLE mi.
//
// jsdom boyama yapmaz: "modal piksel olarak ustte" iddiasini burada
// kuramam. Kurulabilen en yakin iddia, catismayi ureten ILISKININ
// ortadan kalkmis olmasi.
describe("(P214) /checkpoints — modal acikken form GORUNUR", () => {
  it("form alanlari cizilir ve modal olcekteki katmanda", async () => {
    const { screen, waitFor } = await import("@testing-library/react");
    const userEvent = (await import("@testing-library/user-event")).default;
    const { ciz, fetchSahtele } = await import("./yardimci");
    const CheckpointsPage = (await import("@/app/(protected)/checkpoints/page"))
      .default;

    fetchSahtele({
      "/api/checkpoints": {
        meta: { limit: 20, offset: 0, total: 1 },
        items: [{ id: "c1", ad: "Ana Kapı", nfc_tag_uid: "04A1B2C3D4E5F6",
                  gps_lat: 41.0, gps_lng: 29.0, aktif: true,
                  created_at: "2026-01-01T00:00:00Z" }],
      },
    });
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("Ana Kapı")).toBeInTheDocument());

    await userEvent.click(screen.getAllByRole("button", { name: /Ekle|Yeni/ })[0]);

    // 1. KULLANICININ GOREMEDIGI SEY: form alanlari.
    const diyalog = await screen.findByRole("dialog");
    expect(diyalog).toBeInTheDocument();
    const alanlar = diyalog.querySelectorAll("input, select, textarea");
    expect(alanlar.length, "modalda hic form alani yok").toBeGreaterThan(0);

    // 2. Modal olcekteki katmani tasir (ham bir sayi DEGIL).
    const katman = diyalog.closest<HTMLElement>("[style*='z-index']")
      ?? (diyalog.parentElement as HTMLElement);
    expect(katman.getAttribute("style") ?? "").toContain("--yz-z-modal");
  });
});
