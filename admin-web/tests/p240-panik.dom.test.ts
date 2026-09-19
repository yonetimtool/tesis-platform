// @vitest-environment jsdom
// (P240 §1) PANIK BUTONU — WEB YUZEYI.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
//   1. ROL KAPISI: her rol YALNIZ tetikleyebildigi tipleri gorur.
//   2. IPTAL PENCERESI: geri sayim gorunur, iptal istegi gider.
//   3. GERI SAYIM BITINCE ISTEMCI IKINCI ISTEK ATMAZ — yayin sunucudaki
//      gecikmeli gorevin isi. Bunu ISTEMCIYE baglamak, sekme kapaninca
//      alarmin hic gitmemesi demekti.
//   4. YASAL UYARI dugmelere BASMADAN ONCE gorunur.
//   5. TAM EKRAN ALARM: kapatma dugmesi YOK; yalniz gordum/gidiyorum.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { afterEach, describe, expect, it, vi } from "vitest";

import { PanikAlarmi } from "@/components/panik/panik-alarmi";

import { ciz } from "./yardimci";

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

let cagrilar: { url: string; metot: string; govde?: unknown }[] = [];

function taklit(opts: { aktif?: unknown[] } = {}) {
  cagrilar = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({
      url,
      metot,
      govde: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    let govde: unknown = { ok: true };
    if (url === "/api/panik" && metot === "POST") {
      govde = { id: "p1", durum: "beklemede", iptal_penceresi_sn: 5 };
    } else if (url === "/api/panik/p1/iptal") {
      govde = { id: "p1", durum: "iptal" };
    } else if (url === "/api/panik/aktif") {
      govde = opts.aktif ?? [];
    }
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => {
  // SAHTE ZAMANLAYICI SIZINTISI: geri sayim testi `useFakeTimers`
  // kullaniyor ve `finally` ile geri aliyor; yine de afterEach'te
  // ACIKCA gercek zamanlayiciya donulur. Ilk yazimda bu satir yoktu ve
  // SONRAKI ALTI TEST 5 sn'de zaman asimina ugradi — sizinti, testi
  // yazdigim yerde degil BASKA testlerde patladigi icin ilk bakista
  // "bilesen hatali" gibi gorundu.
  vi.useRealTimers();
  vi.restoreAllMocks();
});

// ===========================================================================
// (P243 §5a) SOS TETIKLEME WEB'DEN KALDIRILDI
// ===========================================================================
// Eski testler `PanikDugmesi`nin rol kapisini ve 5 saniyelik iptal
// penceresini olcuyordu. Dugme ARTIK YOK: acil durumda kimse bilgisayar
// basina kosmaz, telefon elde olur. Ayni kurallar MOBILDE olculuyor
// (`test/p240_panik_test.dart`) ve SUNUCUDA (`test_p240_panik.py`) —
// yani kaldirilan sey kapi degil, YANLIS YUZEYDEKI KOPYASI.
//
// Asagidaki kilit, dugmenin GERI GELMEDIGINI ve takibin DURDUGUNU
// olcer.
describe("(P243 §5a) web'de TETIKLEME yok, TAKIP var", () => {
  it("panik dugmesi DOSYASI depoda YOK, alarm katmani VAR", () => {
    // DOSYA SISTEMINDEN olculur: dinamik `import` TypeScript'i de
    // memnun etmez (olmayan modulun tipi cozulemez) ve testi
    // derlenmez hale getirir.
    const kok = join(process.cwd(), "components", "panik");
    expect(existsSync(join(kok, "panik-alarmi.tsx"))).toBe(true);
    expect(
      existsSync(join(kok, "panik-dugmesi.tsx")),
      "tetikleme dugmesi geri gelmemeli",
    ).toBe(false);
  });

  it("DUZENDE tetikleme bileseni CIZILMIYOR", () => {
    const duzen = readFileSync(
      join(process.cwd(), "app", "(protected)", "layout.tsx"),
      "utf8",
    );
    expect(duzen).not.toContain("PanikDugmesi");
    // Takip katmani duruyor.
    expect(duzen).toContain("PanikAlarmi");
  });
});

describe("(P240 §1) gelen alarm — tam ekran", () => {
  const ALARM = {
    id: "a1",
    tip: "sakin",
    durum: "acik",
    olusturan_ad: "Ayşe Yılmaz",
    olusturan_telefon: "+905551110000",
    daire_no: "12",
    blok: "A",
    checkpoint_ad: null,
    gps_lat: null,
    gps_lng: null,
    aciklama: null,
    son_24s_yanlis_alarm: 0,
  };

  it("ALARM VARSA ekrani kaplar; KAPATMA dugmesi YOK", async () => {
    // Kapatilabilir bir uyari, yogun bir ekranda REFLEKSLE kapatilir ve
    // alarm hic okunmadan kaybolur.
    taklit({ aktif: [ALARM] });
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-tam-ekran")).toBeTruthy());
    expect(el("panik-alarm-kim")?.textContent).toBe("Ayşe Yılmaz");
    expect(el("panik-alarm-yer")?.textContent).toBe("A 12");
    expect(el("panik-gordum")).toBeTruthy();
    expect(el("panik-mudahale")).toBeTruthy();
    const kapat = document.querySelector('[data-test="panik-tam-ekran"] [aria-label="Kapat"]');
    expect(kapat, "kapatma dugmesi OLMAMALI").toBeNull();
  });

  it("ALARM YOKSA hicbir sey cizilmez", async () => {
    taklit({ aktif: [] });
    ciz(PanikAlarmi);
    await waitFor(() => expect(cagrilar.length).toBeGreaterThan(0));
    expect(el("panik-tam-ekran")).toBeNull();
  });

  it("GIDIYORUM istegi sunucuya gider", async () => {
    taklit({ aktif: [ALARM] });
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-mudahale")).toBeTruthy());
    await userEvent.click(el("panik-mudahale") as HTMLElement);
    await waitFor(() =>
      expect(cagrilar.some((c) => c.url === "/api/panik/a1/mudahale")).toBe(true),
    );
  });

  it("TELEFON DOKUNULABILIR — acil durumda numara gosterilir", async () => {
    // Gunluk iletisimdeki riza kapisindan AYRI bir karar: alici kumesi
    // zaten guvenlik+yonetim ve her gosterim denetim kaydinda.
    taklit({ aktif: [ALARM] });
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-alarm-telefon")).toBeTruthy());
    expect((el("panik-alarm-telefon") as HTMLAnchorElement).getAttribute("href")).toBe(
      "tel:+905551110000",
    );
  });

  it("YANLIS ALARM SAYACI baglam verir (engel DEGIL)", async () => {
    taklit({ aktif: [{ ...ALARM, son_24s_yanlis_alarm: 3 }] });
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-alarm-yanlis-sayaci")).toBeTruthy());
    expect(el("panik-alarm-yanlis-sayaci")?.textContent).toContain("3");
    // Sayac YUKSEK olsa da mudahale dugmeleri ACIK kalir.
    expect((el("panik-mudahale") as HTMLButtonElement).disabled).toBe(false);
  });
});
