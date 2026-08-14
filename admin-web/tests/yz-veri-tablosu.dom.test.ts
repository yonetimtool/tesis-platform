// @vitest-environment jsdom
// (P160 / Asama 3) VERI TABLOSU — brief'in saydigi her yetenek.
//
// OLCULEN SEY GORUNUM DEGIL DAVRANIS:
//   siralama · sayfalama · SAYFA BASINA KAYIT SECIMI · kolon gorunurlugu ·
//   satir secimi · toplu islem · toplam kayit · bos/yukleniyor durumu ·
//   ve en kolay bozulan yani: ERISILEBILIRLIK (gercek <table>, aria-sort,
//   adli secim kutulari).
import { screen, render, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement, useState } from "react";
import { describe, expect, it, vi } from "vitest";

import { VeriTablosu, type Kolon } from "@/components/ui";
import { I18nProvider } from "@/lib/i18n/kullan";
import { SOZLUKLER } from "@/lib/i18n/sozluk";

type Kisi = { id: string; ad: string; yas: number | null };

const KISILER: Kisi[] = [
  { id: "1", ad: "Cem", yas: 40 },
  { id: "2", ad: "Ayse", yas: 25 },
  { id: "3", ad: "Bora", yas: null },
];

const KOLONLAR: Kolon<Kisi>[] = [
  { id: "ad", baslik: "Ad", hucre: (k) => k.ad, deger: (k) => k.ad },
  {
    id: "yas",
    baslik: "Yas",
    hucre: (k) => k.yas ?? "-",
    deger: (k) => k.yas,
    sayisal: true,
  },
];

function ciz(el: React.ReactElement) {
  return render(
    createElement(I18nProvider, {
      baslangicDili: "tr" as const,
      baslangicSozlugu: SOZLUKLER.tr,
      children: el,
    }),
  );
}

function tablo(ek: Record<string, unknown> = {}) {
  return createElement(VeriTablosu<Kisi>, {
    kolonlar: KOLONLAR,
    satirlar: KISILER,
    satirId: (k: Kisi) => k.id,
    ...ek,
  } as never);
}

/** Govdedeki ilk kolonun degerleri — siralama sonucunu okumanin en
 *  dogrudan yolu. */
function adSutunu(): string[] {
  const govde = screen.getAllByRole("rowgroup")[1];
  return within(govde)
    .getAllByRole("row")
    .map((r) => within(r).getAllByRole("cell")[0].textContent ?? "");
}

/* ==================================================================== */

describe("(P160) VeriTablosu — erisilebilirlik", () => {
  it("GERCEK tablo semantigi kullanir (div izgarasi degil)", () => {
    ciz(tablo());
    // `role=table` yalniz gercek <table> ile gelir; div izgarasi gorsel
    // olarak ayni durur ama satir/sutun iliskisi KAYBOLUR.
    expect(screen.getByRole("table")).toBeInTheDocument();
    expect(screen.getAllByRole("columnheader")).toHaveLength(2);
  });

  it("siralanabilir baslik DUGMEDIR ve aria-sort tasir", async () => {
    ciz(tablo());
    const basliklar = screen.getAllByRole("columnheader");
    // Baslangicta hicbiri sirali degil.
    expect(basliklar[0]).toHaveAttribute("aria-sort", "none");

    await userEvent.click(screen.getByRole("button", { name: /Ad sütununa göre/ }));
    expect(screen.getAllByRole("columnheader")[0]).toHaveAttribute(
      "aria-sort",
      "ascending",
    );
  });

  it("yatay kaydirma klavyeyle erisilebilir (role=region + tabindex)", () => {
    const { container } = ciz(tablo());
    const bolge = container.querySelector('[role="region"]');
    expect(bolge).not.toBeNull();
    expect(bolge).toHaveAttribute("tabindex", "0");
  });
});

describe("(P160) VeriTablosu — siralama", () => {
  it("artan/azalan cevrilir", async () => {
    ciz(tablo());
    const dugme = screen.getByRole("button", { name: /Ad sütununa göre/ });
    await userEvent.click(dugme);
    expect(adSutunu()).toEqual(["Ayse", "Bora", "Cem"]);
    await userEvent.click(dugme);
    expect(adSutunu()).toEqual(["Cem", "Bora", "Ayse"]);
  });

  it("BOS DEGERLER her iki yonde de SONA gider", async () => {
    ciz(tablo());
    const dugme = screen.getByRole("button", { name: /Yas sütununa göre/ });
    await userEvent.click(dugme);
    // Bora'nin yasi null — artan sirada sonda.
    expect(adSutunu()[2]).toBe("Bora");
    await userEvent.click(dugme);
    // Azalan sirada DA sonda: bosluklarin basa gelmesi "veri kayboldu"
    // hissi verirdi.
    expect(adSutunu()[2]).toBe("Bora");
  });
});

describe("(P160) VeriTablosu — sayfalama", () => {
  it("toplam kayit ve sayfa araligi gosterilir", () => {
    ciz(tablo());
    expect(screen.getByText(/Toplam: 3/)).toBeInTheDocument();
  });

  it("SAYFA BASINA KAYIT secilebilir (10/25/50/100)", async () => {
    ciz(tablo());
    const secim = screen.getByRole("combobox");
    const secenekler = within(secim)
      .getAllByRole("option")
      .map((o) => o.textContent);
    expect(secenekler).toEqual(["10", "25", "50", "100"]);
  });

  it("boy degisince ILK SAYFAYA doner (var olmayan sayfada kalinmaz)", async () => {
    ciz(tablo({ satirlar: Array.from({ length: 120 }, (_, i) => ({ id: String(i), ad: `K${i}`, yas: i })) }));
    // 25'lik sayfada 5. sayfaya git.
    const sonraki = screen.getByRole("button", { name: "Sonraki sayfa" });
    await userEvent.click(sonraki);
    await userEvent.click(sonraki);
    // Boy 100'e cekilince 3. sayfa YOK; ilk sayfaya donulmeli.
    await userEvent.selectOptions(screen.getByRole("combobox"), "100");
    expect(screen.getByText(/1-100/)).toBeInTheDocument();
  });

  it("ilk sayfada Onceki, son sayfada Sonraki KAPALI", async () => {
    ciz(tablo());
    expect(screen.getByRole("button", { name: "Önceki sayfa" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Sonraki sayfa" })).toBeDisabled();
  });
});

describe("(P160) VeriTablosu — secim ve toplu islem", () => {
  function Sarmal() {
    const [secili, setSecili] = useState<string[]>([]);
    return createElement(VeriTablosu<Kisi>, {
      kolonlar: KOLONLAR,
      satirlar: KISILER,
      satirId: (k: Kisi) => k.id,
      secilebilir: true,
      secili,
      onSeciliDegisti: setSecili,
      topluEylemler: () => createElement("button", null, "Sil"),
    } as never);
  }

  it("satir secilir, sayac ve toplu islem serit CIKAR", async () => {
    ciz(createElement(Sarmal));
    const kutular = screen.getAllByRole("checkbox", { name: "Satırı seç" });
    await userEvent.click(kutular[0]);
    expect(screen.getByText("1 kayıt seçili")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sil" })).toBeInTheDocument();
  });

  it("tumunu sec KISMI secimde indeterminate olur", async () => {
    ciz(createElement(Sarmal));
    const tumu = screen.getByRole("checkbox", {
      name: "Tümünü seç",
    }) as HTMLInputElement;
    await userEvent.click(screen.getAllByRole("checkbox", { name: "Satırı seç" })[0]);
    expect(tumu.indeterminate, "kismi secimde indeterminate degil").toBe(true);
    expect(tumu.checked).toBe(false);
  });

  it("tumunu sec hepsini secer, tekrar basinca birakir", async () => {
    ciz(createElement(Sarmal));
    const tumu = screen.getByRole("checkbox", { name: "Tümünü seç" });
    await userEvent.click(tumu);
    expect(screen.getByText("3 kayıt seçili")).toBeInTheDocument();
    await userEvent.click(tumu);
    expect(screen.queryByText(/kayıt seçili/)).toBeNull();
  });
});

describe("(P160) VeriTablosu — kolon gorunurlugu", () => {
  it("kolon gizlenip geri acilir", async () => {
    ciz(tablo());
    await userEvent.click(screen.getByRole("button", { name: "Sütunlar" }));
    const kutu = screen.getByRole("checkbox", { name: "Yas" });
    await userEvent.click(kutu);
    expect(screen.getAllByRole("columnheader")).toHaveLength(1);
    await userEvent.click(kutu);
    expect(screen.getAllByRole("columnheader")).toHaveLength(2);
  });
});

describe("(P160) VeriTablosu — durumlar", () => {
  it("yuklenirken ISKELET cizilir, tablo degil", () => {
    ciz(tablo({ yukleniyor: true }));
    expect(screen.queryByRole("table")).toBeNull();
  });

  it("bos listede BOS DURUM cizilir", () => {
    ciz(tablo({ satirlar: [] }));
    expect(screen.getByText("Gösterilecek kayıt yok.")).toBeInTheDocument();
  });

  it("SUNUCU TARAFLI kipte tablo kendi sayfalamaz, durumu BILDIRIR", async () => {
    const bildir = vi.fn();
    ciz(
      tablo({
        sunucuTarafli: true,
        toplam: 500,
        durum: { sayfa: 1, boy: 25, siraKolon: null, siraYonu: "artan" },
        onDurumDegisti: bildir,
      }),
    );
    // 500 kayit var ama elde 3 satir — tablo dilimlemedi.
    expect(screen.getByText(/Toplam: 500/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Sonraki sayfa" }));
    expect(bildir).toHaveBeenCalledWith(
      expect.objectContaining({ sayfa: 2 }),
    );
  });
});
