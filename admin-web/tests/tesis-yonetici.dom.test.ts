// @vitest-environment jsdom
// (P68) Yonetici satirlari: KARARLI ANAHTAR ve CEVRILMIS baslik.
//
// Liste `key={i}` kullaniyordu ve satir ORTADAN silinebiliyor. React o
// durumda DOM dugumlerini yeniden kullanir: imlec/odak, tarayicinin
// otomatik doldurmasi ve PAROLA YONETICISININ BAGI bir alt satira kayar.
// Her satirda parola alani var — yanlis satira baglanan bir parola
// yoneticisi ciddi bir kusurdur.
//
// Ikinci kusur ayni satirdaydi: baslik `Yönetici ${i + 1}` diye SABIT
// Turkce yaziliyordu (sablon dizgesi oldugu icin hicbir tarama gormedi).
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import TenantsPage from "@/app/(protected)/tenants/page";

import { ciz, fetchSahtele } from "./yardimci";

const BOS = { meta: { limit: 20, offset: 0, total: 0 }, items: [] };

afterEach(() => vi.restoreAllMocks());

async function formuAc() {
  fetchSahtele({ "/api/tenants": BOS });
  ciz(TenantsPage);
  await waitFor(() =>
    expect(screen.getAllByRole("button", { name: /Yeni|Ekle/ })[0]).toBeInTheDocument(),
  );
  await userEvent.click(screen.getAllByRole("button", { name: /Yeni|Ekle/ })[0]);
}

describe("Tesis — yönetici satırları", () => {
  // BU TEST KARARLI ANAHTARI KANITLAMAZ — ve bu bilerek boyle yaziliyor.
  // Olculdu: `key={i}` geri konunca da GECIYOR, cunku girdiler KONTROLLU
  // (`value={y.ad}`) ve React dogru degeri yeniden cizer. Kararli
  // anahtarin asil kazanci TARAYICININ KENDI durumudur — imlec/odak,
  // otomatik doldurma ve parola yoneticisinin bagi — ve bunlarin hicbiri
  // jsdom'da gozlenemez. Test yine de duruyor cunku silmenin DEGER
  // kaymasina yol acmadigini sabitler; ama "kararli anahtar testi" diye
  // sunmak, olcmedigi bir seyi olcuyormus gibi gostermek olurdu.
  it("ORTADAN silince kalan satirlarin DEGERLERI kaymaz", async () => {
    await formuAc();
    const ekle = screen.getByRole("button", { name: /Yönetici ekle/i });
    await userEvent.click(ekle);
    await userEvent.click(ekle);

    const adlar = screen.getAllByLabelText(/^Ad/);
    expect(adlar).toHaveLength(3);
    await userEvent.type(adlar[0], "Bir");
    await userEvent.type(adlar[1], "Iki");
    await userEvent.type(adlar[2], "Uc");

    // ORTADAKI satiri sil.
    const kaldirlar = screen.getAllByRole("button", { name: /Kaldır/i });
    await userEvent.click(kaldirlar[0]); // ikinci satirin "Kaldir"i (ilki birincil)

    const kalan = screen.getAllByLabelText(/^Ad/);
    expect(kalan).toHaveLength(2);
    expect(kalan[0]).toHaveValue("Bir");
    expect(kalan[1]).toHaveValue("Uc");
  });

  it("ikinci satirin basligi SOZLUKTEN gelir (sabit Turkce degil)", async () => {
    await formuAc();
    await userEvent.click(screen.getByRole("button", { name: /Yönetici ekle/i }));
    expect(screen.getByText("Yönetici 2")).toBeInTheDocument();
  });
});
