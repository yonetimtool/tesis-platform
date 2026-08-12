// @vitest-environment jsdom
// (P155 §7/§8) DAVET WEB YEDEGI — cozme, parola tamamlama, gecersiz jeton.
//
// Olculen sey: davet bagi TARAYICIDA calisir, jeton URL'de TASINMAZ (yalniz
// backend'e verilir), gecersiz/suresi dolmus jetonda dogru metin cikar ve
// magaza dugmeleri gorunur.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createElement } from "react";

import { ciz } from "./yardimci";

const replace = vi.fn();
vi.mock("next/navigation", () => ({
  useParams: () => ({ jeton: "test-jeton-123" }),
  useRouter: () => ({ replace, refresh: vi.fn(), push: vi.fn() }),
  usePathname: () => "/davet/test-jeton-123",
  useSearchParams: () => new URLSearchParams(),
}));

type Cagri = { url: string; body: unknown };

function taklit(cozHandler: (body: unknown) => Response): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const body = init?.body ? JSON.parse(String(init.body)) : undefined;
    cagrilar.push({ url, body });
    if (url.includes("/davet/coz")) return cozHandler(body);
    if (url.includes("/davet/parola")) {
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    }
    if (url.includes("saglayicilar")) {
      return new Response(JSON.stringify({ saglayicilar: [] }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response("{}", { status: 200 });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => {
  vi.restoreAllMocks();
  vi.clearAllMocks();
  sessionStorage.clear();
});

async function ciziver() {
  const mod = await import("@/app/davet/[jeton]/page");
  return ciz(mod.default);
}

const GECERLI = () =>
  new Response(
    JSON.stringify({
      tesis_ad: "Oltu Sitesi",
      rol: "resident",
      ad: "A-12 sakini",
      telefon_maskeli: "+9053***203",
      daire_no: "A-12",
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );

describe("(P155) davet web yedegi", () => {
  it("gecerli jeton: tesis + daire + telefon(maskeli) cizilir", async () => {
    const cagrilar = taklit(GECERLI);
    await ciziver();
    await waitFor(() => expect(screen.getByText("Oltu Sitesi", { exact: false })).toBeTruthy());
    expect(screen.getByText("A-12")).toBeTruthy();
    expect(screen.getByText("+9053***203")).toBeTruthy();
    // JETON YALNIZ GOVDEDE gider (URL'de tasinmaz); tesis kodu/daire
    // parametre DEGIL.
    const coz = cagrilar.find((c) => c.url.includes("/davet/coz"));
    expect(coz?.body).toEqual({ jeton: "test-jeton-123" });
  });

  it("parola yolu: ad + parola ile /davet/parola cagrilir", async () => {
    const cagrilar = taklit(GECERLI);
    await ciziver();
    await waitFor(() => screen.getByText("Oltu Sitesi", { exact: false }));

    // "Parola oluştur" -> parola formu
    await userEvent.click(screen.getByText("Parola oluştur"));
    const parolalar = document.querySelectorAll('input[type="password"]');
    expect(parolalar.length).toBe(2);
    await userEvent.type(parolalar[0] as HTMLInputElement, "DavetParola1!");
    await userEvent.type(parolalar[1] as HTMLInputElement, "DavetParola1!");
    await userEvent.click(screen.getByText("Kaydı tamamla"));

    await waitFor(() => {
      const p = cagrilar.find((c) => c.url.includes("/davet/parola"));
      expect(p).toBeTruthy();
      expect((p!.body as { jeton: string }).jeton).toBe("test-jeton-123");
      expect((p!.body as { new_password: string }).new_password).toBe("DavetParola1!");
    });
  });

  it("suresi dolmus jeton: dogru metin + magaza dugmeleri", async () => {
    taklit(() =>
      new Response(JSON.stringify({ error: { code: "davet_suresi_doldu" } }), {
        status: 410,
      }),
    );
    await ciziver();
    await waitFor(() =>
      expect(screen.getByText("Bu davet bağlantısının süresi dolmuş.")).toBeTruthy(),
    );
    // Magaza yedegi: Play dugmesi her zaman var.
    expect(screen.getByText("Google Play", { exact: false })).toBeTruthy();
  });

  it("bulunamayan jeton: gecersiz metni", async () => {
    taklit(() =>
      new Response(JSON.stringify({ error: { code: "davet_bulunamadi" } }), {
        status: 404,
      }),
    );
    await ciziver();
    await waitFor(() =>
      expect(screen.getByText("Bu davet bağlantısı geçersiz.")).toBeTruthy(),
    );
  });
});
