// @vitest-environment jsdom
// (P211 §4) TAHSILATTA DAIRE -> KISI.
//
// ===========================================================================
// EKSIK OLAN NEYDI
// ===========================================================================
// P206 §2 ters yonu kurmustu (borclu secilince daire dolar). Daireden
// KISIYE giden yon YOKTU: yonetici daireyi secip yuzlerce ad arasindan
// dogru kisiyi kendisi buluyordu — kapida bekleyen biriyle konusurken
// yapilacak is degil ve YANLIS KISIYE makbuz kesmenin en kolay yolu.
//
// Kilitlenen davranis:
//   1. TEK sakinli daire -> kisi KENDILIGINDEN secilir,
//   2. COK sakinli daire -> secici O DAIREYE suzulur (secim kullanicinin),
//   3. SAKINSIZ daire -> kullaniciya SOYLENIR, liste suzulmez,
//   4. "Bu daire disindan biri oduyor" -> suzgec KALKAR (kilit degil),
//   5. Gonderilen govdede dogru `user_id` + `unit_id` gider.
//
// Taklit HTTP KATMANINDA (P200 dersi): sayfa gercek istekleri yapar.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/finans/tahsilatlar/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

const SAKINLER: Record<string, unknown[]> = {
  // Tek sakin -> otomatik secim.
  "u-1": [{ user_id: "k-1", user_ad: "Ahmet Sakin", rol_tipi: "malik" }],
  // Iki sakin -> secim kullanicinin.
  "u-2": [
    { user_id: "k-2", user_ad: "Ayse Kiraci", rol_tipi: "kiraci" },
    { user_id: "k-3", user_ad: "Veli Malik", rol_tipi: "malik" },
    // ADI OLMAYAN bag: secicide bos satir CIKMAMALI.
    { user_id: "k-4", user_ad: null, rol_tipi: null },
  ],
  // Sakinsiz daire.
  "u-3": [],
};

function taklit(): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      metot: (init?.method ?? "GET").toUpperCase(),
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    let govde: unknown = { items: [], meta: { total: 0 } };
    const sakin = /\/api\/units\/(u-\d)\/residents/.exec(url);
    if (sakin) {
      govde = SAKINLER[sakin[1]] ?? [];
    } else if (url.includes("/api/panel/yaslandirma")) {
      govde = { kovalar: [] };
    } else if (url.startsWith("/api/users")) {
      govde = {
        items: [
          { id: "k-9", ad: "Disaridan Odeyen" },
          { id: "k-1", ad: "Ahmet Sakin" },
        ],
        meta: { total: 2 },
      };
    } else if (url.includes("/api/panel/kasalar")) {
      govde = { items: [{ id: "kasa-1", ad: "Merkez Kasa", kod: "K1" }] };
    } else if (url.includes("/api/units")) {
      govde = {
        items: [
          { id: "u-1", no: "A-1" },
          { id: "u-2", no: "A-2" },
          { id: "u-3", no: "A-3" },
        ],
        meta: { total: 3 },
      };
    }
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const kanca = (ad: string) =>
  document.querySelector(`[data-test="${ad}"]`) as HTMLElement | null;

async function pencereyiAc(k: ReturnType<typeof userEvent.setup>) {
  ciz(Sayfa);
  await waitFor(() => expect(screen.getAllByText(tr.finansYeni).length).toBeGreaterThan(0));
  await k.click(screen.getAllByText(tr.finansYeni)[0]);
  await waitFor(() => expect(kanca("tahsilat-daire")).toBeTruthy());
}

afterEach(() => vi.restoreAllMocks());

it("TEK sakinli daire: kisi KENDILIGINDEN secilir", async () => {
  const k = userEvent.setup();
  taklit();
  await pencereyiAc(k);
  await k.selectOptions(kanca("tahsilat-daire")!, "u-1");
  await waitFor(() =>
    expect((kanca("tahsilat-kisi") as HTMLSelectElement).value).toBe("k-1"),
  );
});

it("COK sakinli daire: secici O DAIREYE suzulur, otomatik secim YAPILMAZ", async () => {
  // Iki kisiden birini sistem secseydi, yanlis kisiye makbuz kesme
  // riskini "kolaylik" adina bedavaya eklerdik.
  const k = userEvent.setup();
  taklit();
  await pencereyiAc(k);
  await k.selectOptions(kanca("tahsilat-daire")!, "u-2");
  await waitFor(() => {
    const s = kanca("tahsilat-kisi") as HTMLSelectElement;
    const adlar = Array.from(s.options).map((o) => o.textContent);
    expect(adlar).toContain("Ayse Kiraci");
    expect(adlar).toContain("Veli Malik");
    // Daire disindaki kisi suzuldu; adsiz bag hic cizilmedi.
    expect(adlar).not.toContain("Disaridan Odeyen");
    expect(adlar.filter((a) => a === "").length).toBe(0);
  });
  expect((kanca("tahsilat-kisi") as HTMLSelectElement).value).toBe("");
});

it("SAKINSIZ daire: SOYLENIR ve liste suzulmez", async () => {
  const k = userEvent.setup();
  taklit();
  await pencereyiAc(k);
  await k.selectOptions(kanca("tahsilat-daire")!, "u-3");
  await waitFor(() => expect(kanca("tahsilat-sakin-yok")).toBeTruthy());
  expect(kanca("tahsilat-sakin-yok")!.textContent).toBe(tr.finansDaireSakiniYok);
  // Suzgec yok: pesin kutusuyla tum kisilere ulasilabiliyor.
  await k.click(kanca("tahsilat-pesin")!);
  await waitFor(() => {
    const s = kanca("tahsilat-kisi") as HTMLSelectElement;
    expect(Array.from(s.options).some((o) => o.textContent === "Disaridan Odeyen")).toBe(true);
  });
});

it("'daire disindan biri oduyor' -> suzgec KALKAR (kilit degil)", async () => {
  // KARAR: odeyen her zaman sakin degildir (kiraci adina ev sahibi oder).
  const k = userEvent.setup();
  taklit();
  await pencereyiAc(k);
  await k.selectOptions(kanca("tahsilat-daire")!, "u-2");
  await waitFor(() => expect(kanca("tahsilat-daire-disi")).toBeTruthy());
  await k.click(kanca("tahsilat-daire-disi")!);
  await k.click(kanca("tahsilat-pesin")!);
  await waitFor(() => {
    const s = kanca("tahsilat-kisi") as HTMLSelectElement;
    expect(Array.from(s.options).some((o) => o.textContent === "Disaridan Odeyen")).toBe(true);
  });
});

it("govdede dogru user_id + unit_id GIDER", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  await pencereyiAc(k);
  await k.selectOptions(kanca("tahsilat-daire")!, "u-1");
  await waitFor(() =>
    expect((kanca("tahsilat-kisi") as HTMLSelectElement).value).toBe("k-1"),
  );
  await k.type(screen.getByLabelText(new RegExp(tr.finansAlanTutar, "i")), "100");
  await k.click(screen.getByText(tr.ortakKaydet));

  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/panel/finans-tahsilat")).toBe(true),
  );
  const post = cagrilar.find((c) => c.url === "/api/panel/finans-tahsilat")!;
  expect(post.govde.user_id).toBe("k-1");
  expect(post.govde.unit_id).toBe("u-1");
});
