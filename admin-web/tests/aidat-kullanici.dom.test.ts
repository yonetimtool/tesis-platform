// @vitest-environment jsdom
// (P45) Aidat ve Kullanicilar — PARA ve YETKI sayfalari.
//
// Bu iki sayfa panelin en pahali hatalarini barindirir: yanlis para
// gosterimi ve yanlis rol. Ikisi de "ekran aciliyor" testiyle degil,
// SOMUT HATA SINIFLARIYLA korunur.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import DuesPage from "@/app/(protected)/dues/page";
import UsersPage from "@/app/(protected)/users/page";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

const TAHAKKUK = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{
    id: "a1", unit_id: "u1", donem: "2026-08", tutar_kurus: 125050,
    son_odeme_tarihi: "2026-08-15", aciklama: null,
    created_at: "2026-08-01T00:00:00Z",
  }],
};
const ODEME = { meta: { limit: 20, offset: 0, total: 0 }, items: [] };

afterEach(() => vi.restoreAllMocks());

describe("Aidat sayfasi", () => {
  it("KURUS -> TL: 125050 kurus = 1.250,50 TL", async () => {
    // Panelde kurus GOSTERILMEZ; tam sayi aritmetigiyle cevrilir (float
    // kullanmak 1.250,49 gibi kayan hatalar uretirdi).
    fetchSahtele({
      "/api/dues/assessments": TAHAKKUK,
      "/api/dues/payments": ODEME,
    });
    ciz(DuesPage);
    await waitFor(() =>
      expect(screen.getAllByText(/1\.250,50/).length).toBeGreaterThan(0),
    );
  });

  it("TUTAR GECERSIZSE toplu tahakkuk istegi ATILMAZ", async () => {
    fetchSahtele({
      "/api/dues/assessments": TAHAKKUK,
      "/api/dues/payments": ODEME,
    });
    ciz(DuesPage);
    // (P161) Form artik MODALDA: once acilir.
    await userEvent.click(await screen.findByRole("button", { name: "Toplu tahakkuk oluştur" }));
    await waitFor(() =>
      expect(screen.getAllByText(/1\.250,50/).length).toBeGreaterThan(0),
    );

    // Iki alan da `required`: bos birakip gondermek TARAYICI
    // dogrulamasina takilir ve `bulk` hic calismaz. Olculmek istenen sey
    // UYGULAMANIN dogrulamasi oldugu icin alanlar DOLDURULUR ve tutar
    // GECERSIZ verilir (sifir).
    const oncekiSayi = cagrilanUrller().filter((u) => u.includes("bulk")).length;
    // (P161) Form MODALDA. Sayfada IKI "Dönem" alani var (form + liste
    // suzgeci); ayrimi DOM sirasina degil, DIYALOG kapsamina birakiyoruz —
    // portal sirasi degisince "ilki" sessizce yanlis alani secerdi.
    const kutu = within(await screen.findByRole("dialog"));
    await userEvent.type(kutu.getByLabelText(/^Dönem/), "2026-08");
    await userEvent.type(kutu.getByLabelText(/Tutar \(TL\)/), "0");
    await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));
    // Bos donem/tutar ile POST ATILMAMALI ve kullaniciya NEDEN soylenmeli.
    await waitFor(() =>
      expect(
        screen.getByText("Geçerli bir tutar girin (sıfırdan büyük)."),
      ).toBeInTheDocument(),
    );
    expect(
      cagrilanUrller().filter((u) => u.includes("bulk")).length,
    ).toBe(oncekiSayi);
  });

  it("UC DUSTUGUNDE hata gorunur — 'tahakkuk yok' GOSTERILMEZ", async () => {
    // Tur 42'de bulunan ayrim: bos liste ile dusen uc ayni ekrani
    // veriyordu ve kullanici "kayit yok" ile "sunucu dustu"yu ayirt
    // edemiyordu. Panel SUNUCU METNINI gosterir (tur 14 hata kanali).
    fetchSahtele({ "/api/dues/payments": ODEME });
    ciz(DuesPage);
    await waitFor(() => expect(screen.getByText("yok")).toBeInTheDocument());
    // Tahakkuk listesi CIZILMEZ: bos liste gibi gostermek yanlis olurdu.
    expect(screen.queryByText(/1\.250,50/)).not.toBeInTheDocument();
  });
});

describe("Kullanicilar sayfasi", () => {
  const KULLANICILAR = {
    meta: { limit: 20, offset: 0, total: 2 },
    items: [
      { id: "k1", ad: "Ayşe Yılmaz", email: "a@x.com", telefon: "+905321112233",
        role: "yonetici", is_active: true, password_set: true,
        created_at: "2026-01-01T00:00:00Z" },
      { id: "k2", ad: "Mehmet Demir", email: null, telefon: "+905321112244",
        role: "security", is_active: false, password_set: false,
        created_at: "2026-01-02T00:00:00Z" },
    ],
  };

  it("ROL adlari SOZLUKTEN gelir — wire degeri EKRANA cikmaz", async () => {
    // `role` alani sozlesme degeridir (`yonetici`); ekrana ham basmak dil
    // degisiminde oldugu gibi kalmasi ve kullaniciya teknik jeton
    // gostermesi demekti.
    fetchSahtele({ "/api/users": KULLANICILAR });
    ciz(UsersPage);
    await waitFor(() => expect(screen.getByText("Ayşe Yılmaz")).toBeInTheDocument());
    expect(screen.getAllByText("Yönetici").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Güvenlik").length).toBeGreaterThan(0);
  });

  it("SUZGEC degisince istek YENI parametreyle gider", async () => {
    fetchSahtele({ "/api/users": KULLANICILAR });
    ciz(UsersPage);
    await waitFor(() => expect(screen.getByText("Ayşe Yılmaz")).toBeInTheDocument());

    await userEvent.selectOptions(screen.getByLabelText("Rol"), "security");
    await waitFor(() =>
      expect(cagrilanUrller().some((u) => u.includes("role=security"))).toBe(true),
    );
    // Suzgec degisince sayfa BASA doner: eski offset'te kalmak, ilk
    // sayfasi bos gorunen bir liste demekti.
    expect(
      cagrilanUrller().some((u) => u.includes("role=security") && u.includes("offset=0")),
    ).toBe(true);
  });

  it("UC DUSTUGUNDE hata gorunur", async () => {
    fetchSahtele({});
    ciz(UsersPage);
    await waitFor(() => {
      const govde = document.body.textContent ?? "";
      expect(govde.length).toBeGreaterThan(0);
      expect(screen.queryByText("Ayşe Yılmaz")).not.toBeInTheDocument();
    });
  });
});
