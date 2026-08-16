// @vitest-environment jsdom
// (P162) SITE KURALI + ETKINLIK YONETIM EKRANLARI.
//
// Bu iki sayfa, `docs/web-mobil-esitlik.md`de olculen son iki farki
// kapatiyor: mobilde tam CRUD vardi, webde yalnizca okuma.
//
// EN ONEMLI KURAL — IKI YUZEY AYRI KALIR:
// Ilk denemede yazma dugmeleri SAKIN sayfasina (`/kurallar`) eklenmisti
// ve `sakin-okuma` kilidi hakli olarak dusurdu. Sakine, basinca 403
// alacagi bir dugme gostermek "yetkim var sandim" demektir. Asagidaki
// testler o ayrimin korundugunu olcer: yonetim sayfasi yazar, sakin
// sayfasi yazmaz.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import EtkinlikYonetimPage from "@/app/(protected)/etkinlik-yonetimi/page";
import SiteKurallariYonetimPage from "@/app/(protected)/site-kurallari/page";
import { ROTA_ROLLERI } from "@/lib/yuzey";

import { ciz } from "./yardimci";

interface Cagri {
  url: string;
  yontem: string;
  govde: unknown;
}

function taklit(items: unknown[]): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      yontem: init?.method ?? "GET",
      govde: init?.body ? JSON.parse(String(init.body)) : null,
    });
    if ((init?.method ?? "GET") !== "GET") {
      return new Response(JSON.stringify({ id: "yeni" }), {
        status: 201,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ items }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

const KURAL = { id: "k1", baslik: "Gürültü", icerik: "23:00 sonrası sessizlik.", sira: 2 };
const ETKINLIK = {
  id: "e1",
  baslik: "Bahar şenliği",
  aciklama: "Bahçede.",
  tarih: "2026-09-01T15:00:00Z",
  bitis_zamani: null,
  konum: "Bahçe",
};

describe("(P162) ROL KAPISI — sunucudaki `_MANAGER` ile ayni", () => {
  it("iki yonetim sayfasi da YALNIZ admin + yonetici", () => {
    // Sunucu tarafi `require_role("admin", "yonetici")`. Kume ayrisirsa
    // ya yetkisiz kullaniciya dugme gosterilir ya da yetkili kullanici
    // sayfayi hic goremez.
    expect(ROTA_ROLLERI["/site-kurallari"]).toEqual(["admin", "yonetici"]);
    expect(ROTA_ROLLERI["/etkinlik-yonetimi"]).toEqual(["admin", "yonetici"]);
  });

  it("SAKIN gorunumleri ayri rota olarak duruyor (birlestirilmedi)", () => {
    // Bos dizi = "sayfa var ama rol kisiti yok" (tesis rollerinin
    // tamamina acik). Bu satirlarin KAYBOLMASI, sakin sayfalarinin
    // yonetim sayfasina karistirildigi anlamina gelirdi.
    expect(ROTA_ROLLERI["/kurallar"]).toEqual([]);
    expect(ROTA_ROLLERI["/etkinlikler"]).toEqual([]);
  });
});

describe("(P162) site kurali yonetimi", () => {
  it("kayitlari listeler ve DOGRU uca gider", async () => {
    const c = taklit([KURAL]);
    ciz(SiteKurallariYonetimPage);
    await waitFor(() => expect(screen.getByText("Gürültü")).toBeInTheDocument());
    expect(c[0].url).toContain("/api/site-rules");
  });

  it("YENI kural POST eder — sira ONERISI en buyuk + 1", async () => {
    const c = taklit([KURAL]);
    ciz(SiteKurallariYonetimPage);
    await waitFor(() => expect(screen.getByText("Gürültü")).toBeInTheDocument());

    await userEvent.click(screen.getByRole("button", { name: "Yeni kural" }));
    const kutu = within(await screen.findByRole("dialog"));
    await userEvent.type(kutu.getByRole("textbox", { name: "Başlık" }), "Otopark");
    await userEvent.type(kutu.getByRole("textbox", { name: "Kural metni" }), "Ters park yok.");
    await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));

    await waitFor(() => {
      const p = c.find((x) => x.yontem === "POST");
      expect(p, "POST atilmadi").toBeTruthy();
      // Mevcut en buyuk sira 2 -> yeni kural 3. Varsayilan 0 birakmak
      // yeni kurali listenin BASINA atardi.
      expect((p!.govde as { sira: number }).sira).toBe(3);
    });
  });

  it("DUZENLE mevcut degerlerle acilir ve PATCH eder", async () => {
    const c = taklit([KURAL]);
    ciz(SiteKurallariYonetimPage);
    await waitFor(() => expect(screen.getByText("Gürültü")).toBeInTheDocument());

    await userEvent.click(screen.getByRole("button", { name: "Düzenle" }));
    const kutu = within(await screen.findByRole("dialog"));
    // Form ON DOLU gelmeli: bos acilsaydi duzenleme, silip yeniden
    // yazmaya donusurdu.
    expect(kutu.getByRole("textbox", { name: "Başlık" })).toHaveValue("Gürültü");
    await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));

    await waitFor(() => {
      const p = c.find((x) => x.yontem === "PATCH");
      expect(p, "PATCH atilmadi").toBeTruthy();
      expect(p!.url).toContain("/api/site-rules/k1");
    });
  });

  it("SILME once ONAY sorar — onaysiz istek ATILMAZ", async () => {
    const c = taklit([KURAL]);
    ciz(SiteKurallariYonetimPage);
    await waitFor(() => expect(screen.getByText("Gürültü")).toBeInTheDocument());

    await userEvent.click(screen.getByRole("button", { name: "Sil" }));
    // Onay diyalogu acildi; IPTAL edilirse hicbir DELETE gitmemeli.
    const kutu = within(await screen.findByRole("dialog"));
    await userEvent.click(kutu.getByRole("button", { name: "İptal" }));
    expect(c.some((x) => x.yontem === "DELETE")).toBe(false);
  });
});

describe("(P162) etkinlik yonetimi", () => {
  it("kayitlari listeler ve DOGRU uca gider", async () => {
    const c = taklit([ETKINLIK]);
    ciz(EtkinlikYonetimPage);
    await waitFor(() => expect(screen.getByText("Bahar şenliği")).toBeInTheDocument());
    expect(c[0].url).toContain("/api/events");
  });

  it("TARIH sunucuya UTC gider (yerel giris kaydirma yapmaz)", async () => {
    const c = taklit([]);
    ciz(EtkinlikYonetimPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni etkinlik" }));
    const kutu = within(await screen.findByRole("dialog"));
    await userEvent.type(kutu.getByRole("textbox", { name: "Başlık" }), "Toplantı");
    await userEvent.type(kutu.getByRole("textbox", { name: "Açıklama" }), "Salonda.");
    // `datetime-local` YEREL saat verir; ham gonderilirse etkinlik saat
    // dilimi kadar kayardi.
    const alan = document.querySelector('input[type="datetime-local"]') as HTMLInputElement;
    await userEvent.type(alan, "2026-09-01T18:00");
    await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));

    await waitFor(() => {
      const p = c.find((x) => x.yontem === "POST");
      expect(p, "POST atilmadi").toBeTruthy();
      const govde = p!.govde as { tarih: string; bitis_zamani: string | null };
      // ISO + UTC (`Z`) olmali ve yerel metnin aynisi OLMAMALI.
      expect(govde.tarih).toMatch(/Z$/);
      expect(govde.tarih).toBe(new Date("2026-09-01T18:00").toISOString());
      // Bos bitis `null` gider — alani hic gondermemek "degistirme"
      // demek olurdu ve bitis IPTAL edilemezdi.
      expect(govde.bitis_zamani).toBeNull();
    });
  });
});
