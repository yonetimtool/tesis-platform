// @vitest-environment jsdom
// (P52) CIKIS: istek DUSERSE giris ekranina gecilmez.
//
// `/api/auth/logout` cerezleri temizleyen tek adimdir. Yaniti
// denetlemeden `/login`e gecmek, OTURUMU HALA ACIK bir kullaniciya
// cikmis gibi gostermek demekti — ortak bir bilgisayarda bunun bedeli
// oturumun bir baskasina devri olur.
import { screen, waitFor } from "@testing-library/react";
import { createElement } from "react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import { AppShell } from "@/components/AppShell";

import { ciz, fetchSahtele } from "./yardimci";

const replace = vi.fn();
vi.mock("next/navigation", () => ({
  usePathname: () => "/dashboard",
  useRouter: () => ({ replace, refresh: vi.fn(), push: vi.fn() }),
}));

// JSX YOK (P43 gerekcesi): kabuk `children` alir, bos govdeyle cizilir.
// (P126.7) `rol` artik ZORUNLU bir ucludur — menu ona gore suzuluyor;
// cikis dugmesi menuden bagimsiz oldugu icin buradaki deger onemsiz.
function Kabuk() {
  return createElement(AppShell, { children: null, rol: "admin", yuzey: "platform" });
}

afterEach(() => {
  vi.restoreAllMocks();
  replace.mockClear();
});

describe("Cikis", () => {
  it("BASARILI cikista giris ekranina gecilir", async () => {
    fetchSahtele({ "/api/auth/logout": { ok: true } });
    ciz(Kabuk);
    await userEvent.click(screen.getAllByRole("button", { name: "Çıkış yap" })[0]);
    await waitFor(() => expect(replace).toHaveBeenCalledWith("/login"));
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
  });

  it("BASARISIZ cikista giris ekranina GECILMEZ ve durum soylenir", async () => {
    fetchSahtele({
      "/api/auth/logout": { __durum: 500, error: { message: "hata" } },
    });
    ciz(Kabuk);
    await userEvent.click(screen.getAllByRole("button", { name: "Çıkış yap" })[0]);
    await waitFor(() =>
      expect(screen.getAllByRole("alert")[0]).toHaveTextContent(/hâlâ oturumunuz açık/i),
    );
    expect(replace).not.toHaveBeenCalled();
  });
});
