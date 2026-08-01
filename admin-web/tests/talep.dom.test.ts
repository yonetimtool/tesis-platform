// @vitest-environment jsdom
// (P46) Talepler sayfasi — DURUM MAKINESI ve ZORUNLU SEBEP.
//
// Iki hata sinifi korunur: (1) kapali bir talepte eylem butonlarinin
// gorunmesi (kullanici basar, sunucu 409 doner ve neden anlasilmaz),
// (2) reddetme sebebinin bos gonderilebilmesi (backend 422; ama kullanici
// formu doldurdugunu sanir).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import ComplaintsPage from "@/app/(protected)/complaints/page";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

function talep(over: Record<string, unknown> = {}) {
  return {
    id: "t1", acan_user_id: "u1", acan_ad: "Ali Veli",
    baslik: "Musluk akıtıyor", mesaj: "Mutfak musluğu damlıyor",
    kategori_id: null, kategori_ad: null, durum: "acik",
    fotograflar: [], gecmis: [], is_emri_id: null, is_emri_durum: null,
    created_at: "2026-08-01T08:00:00Z", updated_at: "2026-08-01T08:00:00Z",
    ...over,
  };
}

const LISTE = (t: Record<string, unknown>) => ({
  meta: { limit: 20, offset: 0, total: 1 },
  items: [t],
});

afterEach(() => vi.restoreAllMocks());

describe("Talepler sayfasi", () => {
  it("ACIK talepte eylemler gorunur", async () => {
    fetchSahtele({ "/api/complaints": LISTE(talep()) });
    ciz(ComplaintsPage);
    await waitFor(() => expect(screen.getByText("Musluk akıtıyor")).toBeInTheDocument());
    expect(screen.getByRole("button", { name: "Çöz" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Reddet" })).toBeInTheDocument();
  });

  it("COZULMUS talepte eylem butonu YOK", async () => {
    // Butonu gostermek, kullanicinin basip 409 almasi ve nedenini
    // anlamamasi demekti.
    fetchSahtele({ "/api/complaints": LISTE(talep({ durum: "cozuldu" })) });
    ciz(ComplaintsPage);
    await waitFor(() => expect(screen.getByText("Musluk akıtıyor")).toBeInTheDocument());
    expect(screen.queryByRole("button", { name: "Çöz" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Reddet" })).not.toBeInTheDocument();
  });

  it("REDDET: sebep BOSKEN gonderim KAPALI, dolunca ACILIR", async () => {
    fetchSahtele({ "/api/complaints": LISTE(talep()) });
    ciz(ComplaintsPage);
    await waitFor(() => expect(screen.getByText("Musluk akıtıyor")).toBeInTheDocument());

    await userEvent.click(screen.getByRole("button", { name: "Reddet" }));
    // Form acildi: gonderim butonu ayni etiketi tasir ama artik `submit`.
    const gonder = screen.getByRole("button", { name: "Reddet" });
    expect(gonder).toBeDisabled();

    await userEvent.type(screen.getByRole("textbox"), "Yetki alanımız dışında");
    expect(screen.getByRole("button", { name: "Reddet" })).toBeEnabled();
  });

  it("COZ: not OPSIYONEL — bos notla gonderim ACIK", async () => {
    // Reddetmede sebep zorunlu, cozmede not opsiyoneldir (backend boyle
    // zorlar); ikisini ayni kurala baglamak, cozen yoneticiyi gereksiz
    // metin yazmaya zorlardi.
    fetchSahtele({ "/api/complaints": LISTE(talep()) });
    ciz(ComplaintsPage);
    await waitFor(() => expect(screen.getByText("Musluk akıtıyor")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Çöz" }));
    expect(screen.getByRole("button", { name: "Çöz" })).toBeEnabled();
  });

  it("SUZGEC secilince istek durum parametresiyle gider", async () => {
    fetchSahtele({ "/api/complaints": LISTE(talep()) });
    ciz(ComplaintsPage);
    await waitFor(() => expect(screen.getByText("Musluk akıtıyor")).toBeInTheDocument());

    await userEvent.click(screen.getByRole("button", { name: "Çözüldü" }));
    await waitFor(() =>
      expect(cagrilanUrller().some((u) => u.includes("durum=cozuldu"))).toBe(true),
    );
  });
});
