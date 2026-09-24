// (E2E 2026-09) /api/notifications BFF'i `q`yu backend'e TASIMIYORDU:
// web bildirim aramasi iki sekmede de hicbir seyi suzmuyordu. Taklit
// rota katmaninin ALTINDA (P213 dersi) — backend'e giden adres okunur.
import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const cagrilar: string[] = [];

vi.mock("@/lib/backend", () => ({
  proxyJson: (yol: string) => {
    cagrilar.push(yol);
    return new Response(JSON.stringify({ items: [] }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  },
}));

const { GET } = await import("@/app/api/notifications/route");

describe("/api/notifications arama", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("q backend'e gider (okundu ile birlikte)", async () => {
    await GET(new NextRequest("http://app.test/api/notifications?okundu=true&q=bak%C4%B1m"));
    const u = new URL(`http://x${cagrilar[0]}`);
    expect(u.searchParams.get("q")).toBe("bakım");
    expect(u.searchParams.get("okundu")).toBe("true");
  });

  it("bos q gonderilmez", async () => {
    await GET(new NextRequest("http://app.test/api/notifications?q=%20%20"));
    expect(new URL(`http://x${cagrilar[0]}`).searchParams.has("q")).toBe(false);
  });
});
