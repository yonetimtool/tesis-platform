// @vitest-environment jsdom
// (P169 §5) DOKUNMA KAPISI + PAYLASILAN KAYDIRMA KILIDI.
//
// =========================================================================
// NE OLCULUYOR
// =========================================================================
// 1. KAPI YALNIZ KABA ISARETCIDE CIKAR. Farede tek bir katman bile
//    cizilmemeli — aksi halde masaustunde 3D sahnenin ve haritanin onune
//    tiklamayi yiyen seffaf bir yuzey konmus olurdu (brief'in kirmizi
//    cizgisi: masaustu gorunumu BOZULMAYACAK).
// 2. KAPI ACILINCA CIKIS YOLU KALIR. Acildiktan sonra icerik dokunuslari
//    yutar; geri donus dugmesi olmasaydi tuzak kapiyla birlikte yeniden
//    kurulmus olurdu.
// 3. KILIT SAYILIR. Ic ice acilan iki ortuden ICTEKI kapaninca kilit
//    COZULMEMELI, yoksa disttaki hala aciken sayfa arkada kaymaya baslardi.
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import React, { useState } from "react";

import { DokunmaKapisi } from "@/components/ui/dokunma-kapisi";
import { useKaydirmaKilidi } from "@/lib/kaydirma-kilidi";

import { ciz } from "./yardimci";

// ISARETCI TIPI DEGISKENDE TUTULUR, TAKLITTE DEGIL.
//
// `useMedya` sorgu basina TEK bir `MediaQueryList` onbellekler (gercek
// tarayicida dogru olan davranis: MQL canlidir). Her testte yeni bir
// taklit nesnesi vermek ISE YARAMAZ — bilesen ilk testte onbellege giren
// nesneyi okumaya devam eder. Bu yuzden nesne SABIT, okudugu deger
// DEGISKEN; `matches` bir GETTER.
let kabaIsaretci = false;

vi.stubGlobal("matchMedia", (sorgu: string) => ({
  media: sorgu,
  get matches() {
    return kabaIsaretci && sorgu.includes("coarse");
  },
  addEventListener: () => {},
  removeEventListener: () => {},
}));
vi.stubGlobal("scrollTo", () => {});

function isaretciKur(kaba: boolean): void {
  kabaIsaretci = kaba;
}

afterEach(() => {
  document.body.style.cssText = "";
});

const kap = () =>
  React.createElement(
    DokunmaKapisi,
    null,
    React.createElement("p", null, "sahne"),
  );

describe("dokunma kapisi", () => {
  it("farede hicbir katman cizmez — masaustu davranisi degismez", () => {
    isaretciKur(false);
    ciz(kap);
    expect(screen.getByText("sahne")).toBeTruthy();
    expect(screen.queryAllByRole("button")).toHaveLength(0);
  });

  it("dokunmatikte once kapi cikar, dokununca acilir ve CIKIS kalir", async () => {
    isaretciKur(true);
    ciz(kap);

    const kapi = screen.getByRole("button");
    expect(kapi.className).toContain("inset-0");

    await userEvent.click(kapi);

    // Kapi kalkti; yerine SADECE cikis dugmesi geldi.
    const kalan = screen.getAllByRole("button");
    expect(kalan).toHaveLength(1);
    expect(kalan[0].className).not.toContain("inset-0");

    // Cikis calisiyor: kapi geri gelir.
    await userEvent.click(kalan[0]);
    expect(screen.getByRole("button").className).toContain("inset-0");
  });
});

function Ortu({ acik }: { acik: boolean }) {
  useKaydirmaKilidi(acik);
  return null;
}

/** Ic ice iki ortu — her biri kendi dugmesiyle acilip kapanir. */
function KilitDeneyi() {
  const [dis, setDis] = useState(false);
  const [ic, setIc] = useState(false);
  return React.createElement(
    React.Fragment,
    null,
    React.createElement(Ortu, { key: "d", acik: dis }),
    React.createElement(Ortu, { key: "i", acik: ic }),
    React.createElement(
      "button",
      { key: "bd", onClick: () => setDis((x) => !x) },
      "dis",
    ),
    React.createElement(
      "button",
      { key: "bi", onClick: () => setIc((x) => !x) },
      "ic",
    ),
  );
}

describe("kaydirma kilidi", () => {
  it("kilitler, cozer ve IC ICE acilanlari SAYAR", async () => {
    isaretciKur(false);
    ciz(KilitDeneyi);
    const dis = screen.getByRole("button", { name: "dis" });
    const ic = screen.getByRole("button", { name: "ic" });

    expect(document.body.style.position).toBe("");

    await userEvent.click(dis);
    expect(document.body.style.position).toBe("fixed");
    expect(document.body.style.overflow).toBe("hidden");

    await userEvent.click(ic);
    // ICTEKI KAPANINCA KILIT COZULMEZ — distaki hala acik.
    await userEvent.click(ic);
    expect(document.body.style.position).toBe("fixed");

    await userEvent.click(dis);
    expect(document.body.style.position).toBe("");
    expect(document.body.style.overflow).toBe("");
  });
});
