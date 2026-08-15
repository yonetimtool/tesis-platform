// @vitest-environment jsdom
// (P161) YENI `components/ui/modal` — DAVRANIS testi + `useOnay`.
//
// NEDEN AYRI DOSYA: `modal.dom.test.ts` ESKI `components/Modal`i olcuyor
// (3 sayfa kullaniyor). P161'de butun olusturma/duzenleme ekranlari YENI
// modala tasindi — yani artik ~25 sayfa bu bilesenin davranisina bagli ve
// o davranisin kendi testi YOKTU.
//
// OLCULEN SEY GORUNUM DEGIL: ESC, dis tik, kirli formda onay, odagin
// iceri girip cagirana donmesi, Tab sarmasi, basligin diyaloga BAGLI
// olmasi. Bir de `useOnay`: sozun HER YOLDA cozulmesi — cozulmezse
// "Sil"e basan kullanicinin cagirdigi fonksiyon sonsuza dek beklerdi.
import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement, useState } from "react";
import { describe, expect, it } from "vitest";

import { Dugme, Modal, useOnay } from "@/components/ui";

import { ciz } from "./yardimci";

/** Acma dugmesi + modal — odagin CAGIRANA donusunu olcebilmek icin. */
function Sarmal({ kirli = false }: { kirli?: boolean }) {
  const [acik, setAcik] = useState(false);
  const [uyari, setUyari] = useState(false);
  return createElement(
    "div",
    null,
    createElement(
      "button",
      { onClick: () => setAcik(true), "data-testid": "ac" },
      "Ac",
    ),
    uyari ? createElement("p", null, "kirli uyarisi") : null,
    createElement(Modal, {
      baslik: "Kasa ekle",
      acik,
      kirliMi: kirli,
      onKirliKapat: () => setUyari(true),
      onKapat: () => setAcik(false),
      eylemler: createElement(
        Dugme,
        { onClick: () => setAcik(false) },
        "İptal",
      ),
      children: [
        createElement("input", { key: "kod", "aria-label": "Kod" }),
        createElement("input", { key: "ad", "aria-label": "Ad" }),
      ],
    }),
  );
}

describe("(P161) ui/Modal — erisilebilirlik ve kapanma", () => {
  it("kapaliyken HICBIR SEY cizmez", () => {
    ciz(() => createElement(Sarmal));
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("acilinca baslik diyaloga BAGLI gelir (adsiz diyalog olmaz)", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    await k.click(screen.getByTestId("ac"));
    const d = await screen.findByRole("dialog");
    // Erisilebilir ad = baslik. `aria-labelledby` kopuksa bu bos donerdi.
    expect(d).toHaveAccessibleName("Kasa ekle");
  });

  it("ODAK ILK ALANA girer, kapaninca CAGIRANA doner", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    const ac = screen.getByTestId("ac");
    await k.click(ac);
    expect(await screen.findByLabelText("Kod")).toHaveFocus();
    await k.keyboard("{Escape}");
    expect(ac).toHaveFocus();
  });

  it("ESC ve DIS TIK kapatir; IC tik KAPATMAZ", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    await k.click(screen.getByTestId("ac"));
    await k.click(await screen.findByLabelText("Ad"));
    expect(screen.getByRole("dialog")).toBeInTheDocument();

    // Ortu `aria-hidden` bir div; role ile bulunamaz, kardes olarak alinir.
    const ortu = document.querySelector("[aria-hidden='true']") as HTMLElement;
    await k.click(ortu);
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("KIRLI formda dis tik DOGRUDAN kapatmaz, karari cagirana birakir", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal, { kirli: true }));
    await k.click(screen.getByTestId("ac"));
    await screen.findByRole("dialog");
    await k.keyboard("{Escape}");
    expect(screen.getByRole("dialog")).toBeInTheDocument();
    expect(screen.getByText("kirli uyarisi")).toBeInTheDocument();
  });

  it("ODAK TUZAGI: son ogeden Tab ILKE doner", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    await k.click(screen.getByTestId("ac"));
    const d = within(await screen.findByRole("dialog"));
    const iptal = d.getByRole("button", { name: "İptal" });
    iptal.focus();
    await k.tab();
    // Sarma hedefi kutunun ILK odaklanabilir ogesidir — o da basliktaki
    // kapatma dugmesi. (Acilis odagi ayri bir kural: bkz. ustteki test.)
    expect(d.getByRole("button", { name: "Kapat" })).toHaveFocus();
  });
});

/** `useOnay` sarmali — cozulen degeri ekrana yazar. */
function OnaySarmal() {
  const { onayla, diyalog } = useOnay();
  const [sonuc, setSonuc] = useState<string>("");
  return createElement(
    "div",
    null,
    createElement(
      "button",
      {
        "data-testid": "sil",
        onClick: () => {
          void onayla({
            baslik: "Silinsin mi?",
            mesaj: "A-12 silinsin mi?",
            onayMetni: "Sil",
            tehlikeli: true,
          }).then((o) => setSonuc(o ? "evet" : "hayir"));
        },
      },
      "Sil",
    ),
    createElement("p", { "data-testid": "sonuc" }, sonuc),
    diyalog,
  );
}

describe("(P161) useOnay — yerel confirm() yerine", () => {
  it("ONAYLANINCA soz TRUE cozülür", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(OnaySarmal));
    await k.click(screen.getByTestId("sil"));
    const d = within(await screen.findByRole("dialog"));
    // "NE SILINECEK" govdededir — brief'in acik istegi.
    expect(d.getByText("A-12 silinsin mi?")).toBeInTheDocument();
    await k.click(d.getByRole("button", { name: "Sil" }));
    expect(await screen.findByTestId("sonuc")).toHaveTextContent("evet");
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("IPTAL EDILINCE soz FALSE cozulur — cagiran ASILI KALMAZ", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(OnaySarmal));
    await k.click(screen.getByTestId("sil"));
    const d = within(await screen.findByRole("dialog"));
    await k.click(d.getByRole("button", { name: "İptal" }));
    expect(await screen.findByTestId("sonuc")).toHaveTextContent("hayir");
  });

  it("ESC de FALSE cozer (kapanmanin her yolu sozu cozmeli)", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(OnaySarmal));
    await k.click(screen.getByTestId("sil"));
    await screen.findByRole("dialog");
    await k.keyboard("{Escape}");
    expect(await screen.findByTestId("sonuc")).toHaveTextContent("hayir");
  });
});
