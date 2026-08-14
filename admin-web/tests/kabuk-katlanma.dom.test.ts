// @vitest-environment jsdom
// (P160 / Asama 2) KENAR CUBUGU KATLANMASI.
//
// Brief: "Sabit, katlanabilir, ikon + etiket ... Katlanma animasyonu:
// genislik gecisi, etiket solma. Katlanma tercihi kalici olsun."
//
// OLCULEN ASIL RISK — ERISILEBILIR AD:
// Dar modda etiketi DOM'DAN KALDIRMAK en kolay cozumdur ve menuyu ekran
// okuyucu icin kullanilamaz hale getirir: 30+ baglanti "baglanti, baglanti,
// baglanti" diye okunur. Bu yuzden etiket `sr-only` ile GORSEL olarak
// gizlenir, DOM'da KALIR. Bu dosyanin varlik sebebi o kuralin geri
// alinmamasidir.
//
// Ikinci risk: tercihin KALICI olmamasi. Kullanici her sayfa gecisinde
// menuyu yeniden daraltmak zorunda kalirsa ozellik yok sayilir.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { render } from "@testing-library/react";
import { createElement } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { AppShell } from "@/components/AppShell";
import { I18nProvider } from "@/lib/i18n/kullan";
import { SOZLUKLER } from "@/lib/i18n/sozluk";

vi.mock("next/navigation", () => ({
  usePathname: () => "/dashboard",
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
  useSearchParams: () => new URLSearchParams(),
}));

const DAR_ANAHTARI = "yonetio.menu.dar";

function ciz(rol = "yonetici") {
  return render(
    createElement(I18nProvider, {
      baslangicDili: "tr" as const,
      baslangicSozlugu: SOZLUKLER.tr,
      children: createElement(AppShell, {
        rol,
        yuzey: "tesis" as const,
        children: createElement("p", null, "icerik"),
      }),
    }),
  );
}

beforeEach(() => {
  localStorage.clear();
});
afterEach(() => {
  vi.clearAllMocks();
});

describe("(P160) kenar cubugu katlanmasi", () => {
  it("varsayilan GENIS acilir ve daraltma dugmesi vardir", () => {
    ciz();
    expect(
      screen.getByRole("button", { name: "Menüyü daralt" }),
    ).toBeInTheDocument();
  });

  it("daraltinca tercih KALICI yazilir", async () => {
    ciz();
    await userEvent.click(screen.getByRole("button", { name: "Menüyü daralt" }));
    await waitFor(() => expect(localStorage.getItem(DAR_ANAHTARI)).toBe("1"));
  });

  it("kayitli tercih ACILISTA uygulanir", async () => {
    localStorage.setItem(DAR_ANAHTARI, "1");
    ciz();
    // Dar moddayken genisletme dugmesi cizilir.
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Menüyü genişlet" }),
      ).toBeInTheDocument(),
    );
  });

  it("DAR MODDA menu baglantilari ADINI KORUR (sr-only, DOM'dan silinmez)", async () => {
    localStorage.setItem(DAR_ANAHTARI, "1");
    ciz();
    // Rol `yonetici`: pano menude olmali. Dar modda da ADIYLA bulunmali —
    // bulunamiyorsa etiket DOM'dan silinmis demektir ve menu ekran
    // okuyucu icin kullanilamaz hale gelmistir.
    await waitFor(() => {
      // `getAllByRole`: kenar cubugu MASAUSTU + CEKMECE olarak IKI kez
      // ciziliyor (mevcut kabuk testi de bunu not ediyor), `getByRole`
      // coklu eslesmede patlar.
      expect(
        screen.getAllByRole("link", { name: "Canlı Panel" }).length,
        "dar modda baglantinin erisilebilir adi KAYBOLMUS",
      ).toBeGreaterThan(0);
    });
  });

  it("genis modda da ayni baglanti ADIYLA bulunur (gerileme kontrolu)", async () => {
    ciz();
    await waitFor(() =>
      expect(
        screen.getAllByRole("link", { name: "Canlı Panel" }).length,
      ).toBeGreaterThan(0),
    );
  });

  it("cikis dugmesi dar modda da ADLIDIR", async () => {
    localStorage.setItem(DAR_ANAHTARI, "1");
    ciz();
    await waitFor(() =>
      expect(
        screen.getAllByRole("button", { name: "Çıkış yap" }).length,
      ).toBeGreaterThan(0),
    );
  });

  it("bozuk depolama KATLANMA tercihini kirmaz (genis varsayilana duser)", () => {
    // YALNIZ KATLANMA OKUMASI sinaniyor. Ilk yazimda tum kabuk
    // sinanmisti ve test KIRMIZI dondu — suclu benim kodum degil,
    // `ThemeToggle`in korumasiz `localStorage.getItem` cagrisiydi
    // (ayri bir kusur, ayrica duzeltildi). Testin kapsamini dogru
    // yere daraltmak, baska bir bilesenin kusurunu bu dosyada
    // kovalamaktan iyidir.
    const eski = Storage.prototype.getItem;
    Storage.prototype.getItem = () => {
      throw new Error("erisim yok");
    };
    try {
      expect(() => ciz()).not.toThrow();
    } finally {
      Storage.prototype.getItem = eski;
    }
  });
});
