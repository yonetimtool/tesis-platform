// @vitest-environment jsdom
// (P66) Denetim kaydi — rol CEVRILIR, hata varken "kayit yok" YAZILMAZ.
//
// Denetim kaydi "kim ne yapti"nin kanitidir. Rol sutununda `yonetici`
// gibi ham bir tel degeri gostermek, kaydi okuyan kisinin taniyamadigi
// bir jeton demektir — panelin geri kalani rolleri `rolAdi` ile cevirir.
// Sizinti kilidin ALAN LISTESINDEN kacmisti: liste "rol" iceriyordu ama
// alan adi `actor_rol`di ve kelime siniri yuzunden eslesmiyordu.
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import AuditPage from "@/app/(protected)/audit/page";

import { ciz, fetchSahtele } from "./yardimci";

const KAYITLAR = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{
    id: "a1", ts: "2026-02-01T10:00:00Z", tenant_id: null,
    actor_user_id: "u1", actor_rol: "yonetici", action: "user.create",
    resource_type: "user", resource_id: "3f2a91c8-1111-2222-3333-444444444444",
    meta: {},
  }],
};

afterEach(() => vi.restoreAllMocks());

describe("Denetim kaydı", () => {
  it("rol CEVRILIR — ham tel degeri gorunmez", async () => {
    fetchSahtele({ "/api/audit": KAYITLAR });
    ciz(AuditPage);
    await waitFor(() =>
      expect(screen.getByText("user.create")).toBeInTheDocument(),
    );
    expect(screen.getByText("Yönetici")).toBeInTheDocument();
    expect(screen.queryByText("yonetici")).not.toBeInTheDocument();
  });

  it("UC DUSTUGUNDE hata gorunur, satir cizilmez", async () => {
    fetchSahtele({});
    ciz(AuditPage);
    await waitFor(() =>
      expect(screen.getByText(/yüklenemedi/i)).toBeInTheDocument(),
    );
    expect(screen.queryByText("user.create")).not.toBeInTheDocument();
  });
});
