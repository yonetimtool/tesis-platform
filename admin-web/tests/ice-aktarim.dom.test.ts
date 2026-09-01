// @vitest-environment jsdom
// (P154 / Asama 8) ICE AKTARIM — ISTEMCI TARAFI.
//
// Sunucu XLSX ayristirmaz (bir saldiri yuzeyidir); satirlari PANEL cozer
// ve KOLON ESLEMESINI de panel yapar. Bu donusum yanlis olursa sunucu
// dogru calissa bile aktarim bozulur — ve hicbir backend testi bunu
// gormez.
//
// Bu dosya `yonetisim.dom.test.ts`teki site-aktarim testlerinin YERINE
// gecti; olculen garantiler kaybolmadi, cati degisti.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import IceAktarimPage from "@/app/(protected)/ice-aktarim/page";

import { ciz, fetchSahtele } from "./yardimci";

const TURLER = [
  {
    kod: "daire",
    aciklama_kodu: "x",
    alanlar: [
      { kod: "blok", zorunlu: true, ornek: "A" },
      { kod: "daire_no", zorunlu: true, ornek: "A-1" },
    ],
  },
];
const GECMIS = { meta: { limit: 20, offset: 0, total: 0 }, items: [] };

/** (P193 §1) Sunucunun "sorunlu satir var, yazmadim" yaniti. */
const SORUNLU_YANIT = {
  satir_sayisi: 2, olusan: 1, atlanan: 0, hatali: 1,
  hatalar: [{ satir_no: 3, alan: "eposta", hata: "Zorunlu alan boş." }],
  aktarim_id: null, uygulanmadi: true,
  davet_gonderildi: 0, davet_basarisiz: 0, davet_hatalari: [],
};

function sahtele(sonuc?: Record<string, unknown>): Record<string, unknown>[] {
  fetchSahtele({
    "/api/panel/ice-aktarim-turler": TURLER,
    "/api/panel/ice-aktarim": GECMIS,
    "/api/panel/ice-aktarim-daire": sonuc ?? {
      satir_sayisi: 1, olusan: 1, atlanan: 0, hatali: 0,
      hatalar: [], aktarim_id: null, uygulanmadi: false,
      davet_gonderildi: 0, davet_basarisiz: 0, davet_hatalari: [],
    },
  });
  const govdeler: Record<string, unknown>[] = [];
  const onceki = globalThis.fetch;
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    if (String(girdi).includes("ice-aktarim-daire") && init?.body) {
      govdeler.push(JSON.parse(String(init.body)));
    }
    return onceki(girdi, init);
  }) as typeof fetch;
  return govdeler;
}

afterEach(() => vi.restoreAllMocks());

async function veriGir(metin: string) {
  // `Field` etiketi ipucu metnini de icerir; TAM ESLESME bu yuzden
  // tutmaz (erisilebilir ad = etiket + ipucu).
  const kutu = await screen.findByLabelText(/^Veri/);
  await userEvent.click(kutu);
  await userEvent.paste(metin);
}

describe("(P154/8) ice aktarim — istemci ayristirmasi", () => {
  it("ONIZLEME govdede yalniz_dogrula=true gonderir (hicbir sey yazilmaz)", async () => {
    const govdeler = sahtele();
    ciz(IceAktarimPage);
    await veriGir("blok;daire_no\nA;A-1");

    // Kolon esleme: iki kolon da kendi alanina.
    const secimler = await screen.findAllByRole("combobox");
    await userEvent.selectOptions(secimler[1], "blok");
    await userEvent.selectOptions(secimler[2], "daire_no");

    await userEvent.click(screen.getByRole("button", { name: /Önizle/ }));
    await waitFor(() => expect(govdeler.length).toBe(1));
    expect(govdeler[0].yalniz_dogrula).toBe(true);
  });

  it("`;` VE TAB ayiricilarinin IKISI de calisir", async () => {
    const govdeler = sahtele();
    ciz(IceAktarimPage);
    await veriGir("blok\tdaire_no\nA\tA-9");

    const secimler = await screen.findAllByRole("combobox");
    await userEvent.selectOptions(secimler[1], "blok");
    await userEvent.selectOptions(secimler[2], "daire_no");
    await userEvent.click(screen.getByRole("button", { name: /Aktar/ }));

    await waitFor(() => expect(govdeler.length).toBe(1));
    const satirlar = govdeler[0].satirlar as { degerler: Record<string, string> }[];
    expect(satirlar[0].degerler).toEqual({ blok: "A", daire_no: "A-9" });
  });

  it("BOS metinle istek ATILMAZ", async () => {
    const govdeler = sahtele();
    ciz(IceAktarimPage);
    await screen.findByLabelText(/^Veri/);
    // Esleme bolumu hic cizilmez -> gonderilecek dugme de yok.
    expect(screen.queryByRole("button", { name: /Önizle/ })).toBeNull();
    expect(govdeler.length).toBe(0);
  });

  it("ZORUNLU alan eslenmemisse istek ATILMAZ (yuz hata yerine tek mesaj)", async () => {
    const govdeler = sahtele();
    ciz(IceAktarimPage);
    await veriGir("blok;daire_no\nA;A-1");

    const secimler = await screen.findAllByRole("combobox");
    await userEvent.selectOptions(secimler[1], "blok"); // daire_no eslenmedi
    await userEvent.click(screen.getByRole("button", { name: /Aktar/ }));

    await waitFor(() =>
      expect(screen.getByText(/Zorunlu alan eşlenmedi/)).toBeInTheDocument(),
    );
    expect(govdeler.length).toBe(0);
  });

  // ==================== (P193 §1) SORUNLU SATIR KAPISI =================== //

  it("SORUNLU satir varken AKTAR dugmesi KAPALI ve neden yaziyor", async () => {
    sahtele(SORUNLU_YANIT);
    ciz(IceAktarimPage);
    await veriGir("blok;daire_no\nA;A-1\nB;B-2");

    const secimler = await screen.findAllByRole("combobox");
    await userEvent.selectOptions(secimler[1], "blok");
    await userEvent.selectOptions(secimler[2], "daire_no");
    await userEvent.click(screen.getByRole("button", { name: /Önizle/ }));

    // Sunucunun raporu ETIKETLI sayilarla ve satir numarasiyla goruluyor.
    await waitFor(() =>
      expect(screen.getByText(/Aktarım YAPILMADI/)).toBeInTheDocument(),
    );
    expect(screen.getByText(/Satır 3/)).toBeInTheDocument();
    expect(screen.getByText(/Zorunlu alan boş/)).toBeInTheDocument();

    // AKTAR KAPALI: sunucu zaten reddederdi; calismayan bir dugme
    // bastirmak kullaniciyi "sistem bozuk" sanmaya iter.
    expect(screen.getByRole("button", { name: /Aktar/ })).toBeDisabled();
  });

  it("SORUNLULARI ATLA isaretlenince dugme acilir ve bayrak GONDERILIR", async () => {
    const govdeler = sahtele(SORUNLU_YANIT);
    ciz(IceAktarimPage);
    await veriGir("blok;daire_no\nA;A-1\nB;B-2");

    const secimler = await screen.findAllByRole("combobox");
    await userEvent.selectOptions(secimler[1], "blok");
    await userEvent.selectOptions(secimler[2], "daire_no");
    await userEvent.click(screen.getByRole("button", { name: /Önizle/ }));
    await waitFor(() =>
      expect(screen.getByText(/Aktarım YAPILMADI/)).toBeInTheDocument(),
    );

    await userEvent.click(
      screen.getByLabelText(/Sorunlu satırları atla/),
    );
    const aktar = screen.getByRole("button", { name: /Aktar/ });
    expect(aktar).toBeEnabled();

    await userEvent.click(aktar);
    await waitFor(() => expect(govdeler.length).toBe(2));
    expect(govdeler[1].sorunlulari_atla).toBe(true);
  });

  it("DAVET OZETI gosterilir — gitmeyen davet UYARIYLA", async () => {
    sahtele({
      satir_sayisi: 2, olusan: 2, atlanan: 0, hatali: 0, hatalar: [],
      aktarim_id: "11111111-1111-1111-1111-111111111111", uygulanmadi: false,
      davet_gonderildi: 1, davet_basarisiz: 1,
      davet_hatalari: [{ satir_no: 3, alan: "eposta", hata: "Gönderilemedi." }],
    });
    ciz(IceAktarimPage);
    await veriGir("blok;daire_no\nA;A-1\nB;B-2");

    const secimler = await screen.findAllByRole("combobox");
    await userEvent.selectOptions(secimler[1], "blok");
    await userEvent.selectOptions(secimler[2], "daire_no");
    await userEvent.click(screen.getByRole("button", { name: /Aktar/ }));

    await waitFor(() =>
      expect(screen.getByText(/1 davet gönderildi/)).toBeInTheDocument(),
    );
    // "Kac kisi eklendi" ile "kac kisiye ULASILDI" ayri sorular.
    expect(
      screen.getByText(/Daveti gitmeyen kişiler sisteme giremez/),
    ).toBeInTheDocument();
  });

  it("ZORUNLU SUTUNLAR sablon bilgisinde yaziyor", async () => {
    sahtele();
    ciz(IceAktarimPage);
    await waitFor(() =>
      expect(screen.getByText(/Zorunlu sütunlar/)).toBeInTheDocument(),
    );
  });
});
