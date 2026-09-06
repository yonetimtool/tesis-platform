// @vitest-environment jsdom
// (P217 §1) TOPLU BORCLANDIRMA — "Kaydedildi" HER DURUMDA CIKIYORDU.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Sunucu tarafi GERCEKTEN SURULDU (admin + yonetici, uc ve BFF): akis
// calisiyor, tahakkuklar yaziliyor. Ama ayni donem IKINCI kez
// borclandirilinca 15 satirin HEPSI benzersizlik carpismasiyla atlaniyor,
// HICBIR TAHAKKUK yazilmiyor — ve ekranda YINE "Kaydedildi" cikiyordu.
// Kullanicinin "toplu borclandirma calismiyor" demesinin en olasi
// aciklamasi bu: islem basarili gorunuyor, ortada yeni borc yok.
//
// TAKLIT HTTP KATMANINDA (P200 dersi): `apiSend`i degil `fetch`i
// sahteliyoruz, boylece BFF cagrisi ve yanit isleme GERCEKTEN kosuyor.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import BorclandirmalarPage from "@/app/(protected)/finans/borclandirmalar/page";

import { ciz } from "./yardimci";

const TANIMLAR = {
  meta: { limit: 50, offset: 0, total: 1 },
  items: [{ id: "t1", ad: "Asansör", tip: "gider", aktif: true }],
};

/** `olusan` degerine gore yanit veren SAHTE SUNUCU (fetch duzeyinde). */
function sunucu(olusan: number, atlananlar: unknown[] = []) {
  const cagrilar: string[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push(`${init?.method ?? "GET"} ${url}`);
    const govde = url.includes("borclandirma-toplu-onizleme")
      ? { islenecek: 15, atlanacak: 0, toplam_kurus: 150000, satirlar: [] }
      : url.includes("borclandirma-toplu")
        ? { created: [], olusan, atlanan: atlananlar.length, atlananlar }
        : url.includes("gelir-gider-tanimlari") || url.includes("tanimlar")
          ? TANIMLAR
          : url.includes("dues-assessments")
            ? { meta: { limit: 20, offset: 0, total: 0 }, items: [] }
            // BILINMEYEN uc icin de LISTE BICIMI donuyoruz: sayfa birkac
            // ayri SWR cagrisi yapiyor (gecikme ayari, onizleme, kullanici
            // listesi) ve bos `{}` donmek `meta.total` okuyan kodu
            // patlatiyordu — testin olctugu sey bu degil.
            : { meta: { limit: 20, offset: 0, total: 0 }, items: [],
                kovalar: [], satirlar: [] };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

describe("(P217 §1) toplu borçlandırma sonucu", () => {
  async function modaliAcVeIsle(olusan: number, atlananlar: unknown[] = []) {
    sunucu(olusan, atlananlar);
    ciz(BorclandirmalarPage);
    const k = userEvent.setup();
    await k.click(await screen.findByRole("button", { name: /toplu borçlandırma/i }));
    // TUR SECIMI ZORUNLU: secilmezse `onizle()` erken donuyor ve
    // "Kaydet" hic cizilmiyor (ilk yazimda testi burada takildi).
    // ARAMA ACIK MODALIN ICINDE: sayfada iki modal var (tekil + toplu)
    // ve ikisi de DOM'da duruyor; `screen` uzerinden aramak "birden cok
    // oge" hatasi veriyordu.
    // Sayfada BIRDEN COK dialog var (tekil + toplu) ve kapalilar da
    // DOM'da kaliyor; dogru olani BASLIGINDAN sec.
    const modallar = await screen.findAllByRole("dialog");
    const modal = modallar.find((m) =>
      /toplu borçlandırma/i.test(m.textContent ?? "")) ?? modallar[0];
    const { getByRole, findByRole, getAllByRole } = within(modal);
    // Modalda birkac secim var (tur, donem, dagitim); TUR olani
    // secenegimizi (`t1`) TASIYAN combobox'tir.
    const secimler = getAllByRole("combobox");
    const turSecim = secimler.find((sc) =>
      Array.from(sc.querySelectorAll("option")).some((o) => o.getAttribute("value") === "t1"));
    expect(turSecim, "tür seçimi bulunamadı").toBeTruthy();
    await k.selectOptions(turSecim!, "t1");
    await k.click(await findByRole("button", { name: /önizle/i }));
    await waitFor(() =>
      expect(getByRole("button", { name: /^kaydet$/i })).toBeInTheDocument(),
    );
    await k.click(getByRole("button", { name: /^kaydet$/i }));
  }

  it("OLUSTUYSA kac tane oldugunu SOYLER", async () => {
    await modaliAcVeIsle(15);
    expect(await screen.findByText(/15 tahakkuk oluşturuldu/i)).toBeInTheDocument();
  });

  it("HICBIRI OLUSMADIYSA 'kaydedildi' DEMEZ — ne yapilacagini soyler", async () => {
    // Kusurun ta kendisi: eskiden burada da "Kaydedildi" yaziyordu.
    await modaliAcVeIsle(0, [{ unit_no: "A-1", neden: "benzersizlik_carpismasi" }]);
    const uyari = await screen.findByText(/hiçbir tahakkuk oluşturulmadı/i);
    expect(uyari).toBeInTheDocument();
    expect(screen.queryByText(/^Kaydedildi/i)).toBeNull();
    // Kullanici ne yapacagini bilmeli.
    expect(uyari.textContent).toMatch(/başka bir dönem|düzeltin/i);
  });

  it("HICBIRI OLUSMADIYSA MODAL ACIK KALIR (donem duzeltilebilsin)", async () => {
    await modaliAcVeIsle(0, [{ unit_no: "A-1", neden: "benzersizlik_carpismasi" }]);
    await screen.findByText(/hiçbir tahakkuk oluşturulmadı/i);
    // Basliktan modalin acik oldugunu anlariz.
    expect(screen.getByRole("dialog")).toBeInTheDocument();
  });

  it("BASARIDA modal KAPANIR", async () => {
    await modaliAcVeIsle(15);
    await screen.findByText(/15 tahakkuk oluşturuldu/i);
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  });
});
