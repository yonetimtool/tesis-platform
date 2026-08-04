// @vitest-environment jsdom
// (P126.6) GOREVLERIM — saha rolunun kendi gorevleri.
//
// Uc kural olculur; ucu de sessizce yanlis olabilecek cinsten:
//  1. `foto_zorunlu` gorevde TAMAMLA DUGMESI YOK — sunucu fotografsiz
//     tamamlamayi 422 ile reddediyor (`gorev_foto_kaniti_zorunlu`).
//     Dugmeyi aktif birakip 422 aldirmak "bozuk" izlenimi verirdi.
//  2. Tamamlama `Idempotency-Key` ILE gider — sunucu zorunlu tutuyor ve
//     cift tiklama ayni gorevi iki kez tamamlamamali.
//  3. Kontrol noktasina bagli gorevde NFC kisiti YAZILI — gizlemek,
//     kullanicinin olusmayan bir kaniti olustu sanmasi demekti.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import GorevlerimPage from "@/app/(protected)/gorevlerim/page";

import { ciz } from "./yardimci";

function taklit(harita: Record<string, unknown>) {
  const cagrilar: {
    url: string;
    method: string;
    body: unknown;
    headers: Record<string, string>;
  }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
      headers: (init?.headers as Record<string, string>) ?? {},
    });
    const anahtar = Object.keys(harita)
      .filter((k) => url.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    if (anahtar === undefined) {
      return new Response(JSON.stringify({ error: { message: "yok" } }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify(harita[anahtar]), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const SADE = {
  id: "g1",
  ad: "Kazan dairesi kontrolü",
  aciklama: null,
  checkpoint_id: null,
  foto_zorunlu: false,
  sonraki_planlanan: "2026-08-05T08:00:00Z",
  aktif: true,
};
const FOTOLU = { ...SADE, id: "g2", ad: "Asansör bakımı", foto_zorunlu: true };
const NOKTALI = { ...SADE, id: "g3", ad: "Bahçe turu", checkpoint_id: "c1" };

afterEach(() => vi.restoreAllMocks());

describe("Görevlerim", () => {
  it("gorevler listelenir; PASIF olan gosterilmez", async () => {
    taklit({
      "/api/tasks": { items: [SADE, { ...SADE, id: "g9", ad: "Eski", aktif: false }] },
    });
    ciz(GorevlerimPage);
    expect(await screen.findByText("Kazan dairesi kontrolü")).toBeInTheDocument();
    expect(screen.queryByText("Eski")).toBeNull();
  });

  it("FOTO ZORUNLU gorevde TAMAMLA dugmesi YOK, sebebi YAZILI", async () => {
    taklit({ "/api/tasks": { items: [FOTOLU] } });
    ciz(GorevlerimPage);
    expect(await screen.findByText("Asansör bakımı")).toBeInTheDocument();
    expect(screen.getByText(/fotoğraf kanıtı istiyor/i)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Tamamlandı/i })).toBeNull();
  });

  it("KONTROL NOKTASINA bagli gorevde NFC kisiti YAZILI", async () => {
    taklit({ "/api/tasks": { items: [NOKTALI] } });
    ciz(GorevlerimPage);
    expect(await screen.findByText("Bahçe turu")).toBeInTheDocument();
    expect(screen.getByText(/NFC okutma kanıtı/i)).toBeInTheDocument();
  });

  it("TAMAMLAMA Idempotency-Key ILE gider", async () => {
    const c = taklit({ "/api/tasks": { items: [SADE] } });
    ciz(GorevlerimPage);
    await userEvent.click(
      await screen.findByRole("button", { name: /Tamamlandı/i }),
    );
    await waitFor(() => {
      const post = c.find((x) => x.method === "POST");
      expect(post?.url).toBe("/api/tasks/g1/completions");
      expect(post?.headers["Idempotency-Key"]).toBeTruthy();
      expect(post?.body).toMatchObject({});
    });
  });

  it("TAMAMLAMA zamani gonderilir", async () => {
    const c = taklit({ "/api/tasks": { items: [SADE] } });
    ciz(GorevlerimPage);
    await userEvent.click(
      await screen.findByRole("button", { name: /Tamamlandı/i }),
    );
    await waitFor(() => {
      const post = c.find((x) => x.method === "POST") as
        | { body: { tamamlanma_zamani?: string } }
        | undefined;
      expect(post?.body.tamamlanma_zamani).toBeTruthy();
    });
  });
});
