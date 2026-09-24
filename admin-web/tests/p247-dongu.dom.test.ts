// @vitest-environment jsdom
// (P247 §1) VARDIYA ROTASYONU — web dongu modali.
//
// NE OLCULUYOR: (1) blok -> adim dizisi acilimi (12/36 = gun asiri),
// (2) onizleme `kuru=true` ile gider ve ekip SIRASI + kaydirma TEL
// UZERINDEKI govdede, (3) sunucunun kapsama boslugu ekranda SAAT
// araligiyla gorunur, (4) kaydetme ayni uca `kuru=false` gider ve parti
// sayfaya iletilir, (5) klasik kalip modali dongu kalibini listelemez.
// Sozlesme uyumu (alan adlari) backend `test_p247_rotasyon.py`de sunucuya
// karsi olculuyor (P243 dersi: taklit fetch her govdeye 200 doner).
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { DonguModali, bloklariAc } from "@/components/vardiya/dongu-modali";
import { VardiyaEkleModali } from "@/components/vardiya/vardiya-ekle-modali";

import { ciz } from "./yardimci";

type Cagri = { url: string; govde: Record<string, unknown> };

const DONGU = {
  id: "k1", ad: "2-2-2", aktif: true,
  dilimler: [
    { ad: "Gündüz", baslangic: "08:00:00", bitis: "20:00:00" },
    { ad: "Gece", baslangic: "20:00:00", bitis: "08:00:00" },
  ],
  adimlar: [[1], [1], [0], [0], [], []],
};
const KLASIK = { ...DONGU, id: "k2", ad: "Klasik", adimlar: null };
const PERSONEL = [
  { id: "u1", ad: "Ali", role: "security" },
  { id: "u2", ad: "Veli", role: "security" },
  { id: "u3", ad: "Can", role: "security" },
];

function sonuc(uygulandi: boolean) {
  return {
    uygulandi, parti_id: uygulandi ? "p1" : null,
    baslangic: "2026-03-02", bitis: "2026-05-02",
    eklenecek: 4, eklenen: uygulandi ? 4 : 0, cakisan: 0, izinli: 0, zaten_var: 0,
    satirlar: [
      { tarih: "2026-03-02", dilim: "Gece", baslangic: "20:00:00", bitis: "08:00:00",
        user_id: "u1", ad: "Ali", durum: "eklenecek" },
      { tarih: "2026-03-02", dilim: "Gündüz", baslangic: "08:00:00", bitis: "20:00:00",
        user_id: "u3", ad: "Can", durum: "eklenecek" },
    ],
    kapsama: [
      { tarih: "2026-03-02", bos_dakika: 480,
        bosluklar: [{ baslangic: "00:00:00", bitis: "08:00:00" }] },
      { tarih: "2026-03-03", bos_dakika: 0, bosluklar: [] },
    ],
    ofsetler: { u1: 0, u2: 2, u3: 4 },
    uyarilar: [],
  };
}

function fetchSahtele(cagrilar: Cagri[]) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (girdi: RequestInfo | URL, init?: RequestInit) => {
      const url = String(girdi);
      const json = (v: unknown) =>
        new Response(JSON.stringify(v), {
          status: 200, headers: { "content-type": "application/json" },
        });
      if (url.startsWith("/api/vardiya-plani/kaliplar")) {
        return json({ items: [DONGU, KLASIK] });
      }
      if (url.startsWith("/api/vardiya-plani/dongu-atamalari")) {
        return json({
          ufuk_gun: 62,
          items: [{
            id: "a1", kalip_id: "k1", kalip_ad: "2-2-2", user_id: "u1", ad: "Ali",
            referans: "2026-03-02", baslangic: "2026-03-02", bitis: null,
            uretildi_kadar: "2026-05-02", parti_id: "p0", durum: "aktif", atlanan: [],
          }],
        });
      }
      const govde = JSON.parse(String(init?.body ?? "{}"));
      cagrilar.push({ url, govde });
      if (url.startsWith("/api/vardiya-plani/dongu-uygula")) {
        return json(sonuc(!govde.kuru));
      }
      return json({ iptal_edilen: 3 });
    }),
  );
}

afterEach(() => vi.restoreAllMocks());

describe("(P247 §1) bloklariAc", () => {
  it("2 gece - 2 gunduz - 2 tatil", () => {
    expect(
      bloklariAc([
        { dilim: 1, gun: 2, duzen: "her_gun" },
        { dilim: 0, gun: 2, duzen: "her_gun" },
        { dilim: -1, gun: 2, duzen: "her_gun" },
      ]),
    ).toEqual([[1], [1], [0], [0], [], []]);
  });

  it("12/36 = GUN ASIRI: iki hafta gece + iki hafta gunduz", () => {
    const a = bloklariAc([
      { dilim: 1, gun: 14, duzen: "gun_asiri" },
      { dilim: 0, gun: 14, duzen: "gun_asiri" },
    ]);
    expect(a).toHaveLength(28);
    expect(a.slice(0, 4)).toEqual([[1], [], [1], []]);
    expect(a.slice(14, 18)).toEqual([[0], [], [0], []]);
    expect(a.filter((x) => x.length).length).toBe(14);
  });
});

async function hazirla(onParti = vi.fn()) {
  const cagrilar: Cagri[] = [];
  fetchSahtele(cagrilar);
  ciz(() =>
    createElement(DonguModali, {
      acik: true, personel: PERSONEL, varsayilanBaslangic: "2026-03-02",
      onKapat: () => {}, onBitti: () => {}, onParti,
    }),
  );
  const secim = await waitFor(() => {
    const s = document.querySelector<HTMLSelectElement>('[data-test="dongu-kalip"]');
    expect(s?.querySelectorAll("option").length).toBeGreaterThan(2);
    return s!;
  });
  return { cagrilar, secim, onParti };
}

describe("(P247 §1) dongu modali", () => {
  it("YALNIZ DONGU kaliplari listelenir", async () => {
    const { secim } = await hazirla();
    const degerler = Array.from(secim.options).map((o) => o.value);
    expect(degerler).toContain("k1");
    expect(degerler).not.toContain("k2");
  });

  it("ONIZLEME kuru=true + ekip SIRASI + kaydirma; BOSLUK saatle gorunur", async () => {
    const { cagrilar, secim } = await hazirla();
    await userEvent.selectOptions(secim, ["k1"]);
    for (const id of ["u1", "u2", "u3"]) {
      await userEvent.click(document.querySelector(`[data-test="dongu-kisi-${id}"]`)!);
    }
    const kay = document.querySelector<HTMLInputElement>('[data-test="dongu-kaydirma"]')!;
    await userEvent.clear(kay);
    await userEvent.type(kay, "2");
    await userEvent.click(document.querySelector('[data-test="dongu-onizle"]')!);

    await waitFor(() => expect(cagrilar.length).toBe(1));
    const g = cagrilar[0].govde;
    expect(cagrilar[0].url).toBe("/api/vardiya-plani/dongu-uygula");
    expect(g.kuru).toBe(true);
    expect(g.kalip_id).toBe("k1");
    expect(g.kisiler).toEqual(["u1", "u2", "u3"]);
    expect(g.kaydirma).toBe(2);
    expect(g.baslangic).toBe("2026-03-02");

    const bos = await waitFor(() => {
      const h = document.querySelector('[data-test="dongu-bosluk-2026-03-02"]');
      expect(h).toBeTruthy();
      return h!;
    });
    expect(bos.textContent).toContain("00:00–08:00");
    expect(document.querySelector('[data-test="dongu-bosluk-2026-03-03"]')).toBeNull();
    expect(
      document.querySelector('[data-test="dongu-hucre-u1-2026-03-02"]')?.textContent,
    ).toContain("Gec");
  });

  it("KAYDET ayni uca kuru=false gider ve PARTI sayfaya iletilir", async () => {
    const { cagrilar, secim, onParti } = await hazirla();
    await userEvent.selectOptions(secim, ["k1"]);
    await userEvent.click(document.querySelector('[data-test="dongu-kisi-u1"]')!);
    const uygula = document.querySelector<HTMLButtonElement>('[data-test="dongu-uygula"]')!;
    expect(uygula.disabled, "onizlemeden once kaydedilemez").toBe(true);
    await userEvent.click(document.querySelector('[data-test="dongu-onizle"]')!);
    await waitFor(() => expect(uygula.disabled).toBe(false));
    await userEvent.click(uygula);
    await waitFor(() => expect(cagrilar.length).toBe(2));
    expect(cagrilar[1].govde.kuru).toBe(false);
    await waitFor(() => expect(onParti).toHaveBeenCalledWith("p1"));
  });

  it("ETKIN dongu: ekip partisi GERI ALINIR", async () => {
    const { cagrilar } = await hazirla();
    const d = await waitFor(() => {
      const b = document.querySelector('[data-test="dongu-geri-al-p0"]');
      expect(b).toBeTruthy();
      return b!;
    });
    await userEvent.click(d);
    await waitFor(() =>
      expect(cagrilar.map((c) => c.url)).toContain("/api/vardiya-plani/parti/p0/geri-al"),
    );
  });
});

describe("(P247 §1) klasik kalip modali", () => {
  it("DONGU kalibini listelemez (sunucu 422 verirdi)", async () => {
    fetchSahtele([]);
    ciz(() =>
      createElement(VardiyaEkleModali, {
        acik: true, personel: PERSONEL, baslangicAyi: "2026-03-01",
        onSecilenGunler: [], onKapat: () => {}, onBitti: () => {},
      }),
    );
    const s = await waitFor(() => {
      const x = document.querySelector<HTMLSelectElement>('[data-test="vardiya-ekle-kalip"]');
      expect(x?.querySelectorAll("option").length).toBeGreaterThan(1);
      return x!;
    });
    const degerler = Array.from(s.options).map((o) => o.value);
    expect(degerler).toContain("k2");
    expect(degerler).not.toContain("k1");
  });
});
