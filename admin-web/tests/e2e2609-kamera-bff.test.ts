// (E2E 2026-09 / GUVENLIK-14/15) KAMERA TESTI + DAIRE ARAMA VEKILLERI.
//
// Vekil beyaz listeyle tasir; alan DUSERSE hata SESSIZDIR (P173/P189/P213/
// P245 sinifi). DOM testi `fetch`i taklit eder ve rota HIC calismaz — bu
// yuzden rota islevleri DOGRUDAN cagrilir.
import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const cagrilar: { yol: string; govde: unknown }[] = [];

vi.mock("@/lib/backend", () => ({
  proxyJson: (yol: string, _y: string, govde?: unknown) => {
    cagrilar.push({ yol, govde });
    return new Response("{}", {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  },
}));

const test = await import("@/app/api/cameras/test-baglanti/route");
const ara = await import("@/app/api/units/ara/route");

function post(govde: unknown): NextRequest {
  return new NextRequest("http://app.test/api/cameras/test-baglanti", {
    method: "POST",
    body: JSON.stringify(govde),
    headers: { "Content-Type": "application/json" },
  });
}

describe("GUVENLIK-15 /api/cameras/test-baglanti", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("`camera_id` BACKEND'E ULASIR (duzenlemede kayitli kimlik)", async () => {
    await test.POST(post({ stream_url: "rtsp://10.0.0.4/s", tur: "rtsp", camera_id: "c-1" }));
    expect(cagrilar[0].govde).toEqual({
      stream_url: "rtsp://10.0.0.4/s",
      tur: "rtsp",
      camera_id: "c-1",
    });
  });

  it("ayri kimlik alanlari tasinir, BOS/BILINMEYEN alan tasinmaz", async () => {
    await test.POST(
      post({
        stream_url: "rtsp://10.0.0.4/s",
        stream_kullanici: "op",
        stream_parola: "Gizli1",
        camera_id: "",
        tenant_id: "baska",
      }),
    );
    expect(cagrilar[0].govde).toEqual({
      stream_url: "rtsp://10.0.0.4/s",
      tur: "rtsp",
      stream_kullanici: "op",
      stream_parola: "Gizli1",
    });
  });
});

describe("GUVENLIK-14 /api/units/ara", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("`q` ve `limit` tasinir, baskasi tasinmaz", async () => {
    await ara.GET(new NextRequest("http://app.test/api/units/ara?q=Can&limit=10&rol=admin"));
    expect(cagrilar[0].yol).toBe("/units/ara?q=Can&limit=10");
  });

  it("Turkce harfli sorgu kodlanarak tasinir", async () => {
    await ara.GET(new NextRequest("http://app.test/api/units/ara?q=%C4%B0kinci"));
    expect(cagrilar[0].yol).toBe(`/units/ara?${new URLSearchParams({ q: "İkinci" })}`);
  });
});
