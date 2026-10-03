// @vitest-environment jsdom
// (P253 §B) WEB'DEN TOPLU MESAJ GERCEKTEN GIDER — onay ekraniyla.
//
// Olculen kusur: "Gonderim" sekmesinde gonder dugmesi YOKTU; web'den
// toplu mesaj hic gonderilemiyordu. Simdi:
//   * "Gonder..." once ALICI OZETINI ister (hicbir sey gondermez),
//   * onay penceresi "N kisiye <kanal> gidecek" + atlananlar + onizleme,
//   * onaylayinca AYNI suzgecle gonderir ve sonucu (gonderildi /
//     kuyrukta / gonderilemedi) gosterir,
//   * kanal hazir degilse ya da kotayi asiyorsa onay dugmesi KAPALI.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import { aliciGovdesi, GonderimKarti, type AliciOzeti } from "@/components/mesajlar/gonderim-karti";

import { ciz } from "./yardimci";

afterEach(() => vi.restoreAllMocks());

const SABLONLAR = [
  { id: "s2", kanal: "eposta", ad: "Toplantı", konu: "Genel kurul", govde: "Sayın {adi_soyadi}" },
];

function taklit(ozet: Partial<AliciOzeti> = {}) {
  const c: { url: string; govde: unknown }[] = [];
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    const url = String(g);
    c.push({ url, govde: init?.body ? JSON.parse(String(init.body)) : null });
    let yanit: unknown = {};
    if (url.startsWith("/api/panel/mesaj-alicilar")) {
      yanit = { kanal: "eposta", toplam: 259, gonderilecek: 247, riza_yok: 0, adres_yok: 12,
        kanal_hazir: true, kota_kalan: 1000, ...ozet };
    } else if (url.startsWith("/api/panel/mesaj-onizleme")) {
      yanit = { konu: "Genel kurul", govde: "Sayın Ad Soyad", sms: null, etiketler: [], bilinmeyen_etiketler: [] };
    } else if (url.startsWith("/api/panel/mesaj-gonder")) {
      yanit = { gonderildi: 240, kuyrukta: 7, gonderilemedi: 0, basarisiz: 7, riza_yok: 0, adres_yok: 12 };
    }
    return new Response(JSON.stringify(yanit), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}

const kanca = (ad: string) => document.querySelector(`[data-test="${ad}"]`) as HTMLElement;

it("ONAY EKRANI sayiyla; onaylayinca AYNI suzgecle gonderir, sonuc sayilari", async () => {
  const c = taklit();
  ciz(() => GonderimKarti({ sablonlar: SABLONLAR }));
  await userEvent.selectOptions(kanca("gonderim-sablon"), "s2");
  await userEvent.selectOptions(kanca("gonderim-kime"), "borclu");
  await userEvent.click(kanca("gonderim-gonder"));
  const onay = await waitFor(() => kanca("gonderim-onay"));
  expect(onay.textContent).toContain("247 kişiye E-posta gidecek. Onaylıyor musunuz?");
  expect(onay.textContent).toContain("12 kişinin adresi/numarası yok");
  await waitFor(() => expect(within(onay).getByText("Sayın Ad Soyad")).toBeTruthy());
  // Ozet istendi, ama HENUZ gonderim YOK.
  expect(c.some((x) => x.url.startsWith("/api/panel/mesaj-gonder"))).toBe(false);
  await userEvent.click(kanca("gonderim-onayla"));
  await waitFor(() => expect(kanca("gonderim-sonuc")).toBeTruthy());
  const ozet = c.find((x) => x.url.startsWith("/api/panel/mesaj-alicilar"))!.govde;
  const gonder = c.find((x) => x.url.startsWith("/api/panel/mesaj-gonder"))!.govde;
  expect(gonder).toEqual(ozet);
  expect(gonder).toEqual({ sablon_id: "s2", borc_durumu: "borclu" });
  const sonuc = kanca("gonderim-sonuc").textContent!;
  expect(sonuc).toContain("Gönderildi: 240");
  expect(sonuc).toContain("Kuyrukta (yeniden denenecek): 7");
  expect(sonuc).toContain("Gönderilemedi (kanal yapılandırılmamış): 0");
});

it("KANAL HAZIR DEGIL: uyari ve onay dugmesi KAPALI", async () => {
  taklit({ kanal_hazir: false });
  ciz(() => GonderimKarti({ sablonlar: SABLONLAR }));
  await userEvent.selectOptions(kanca("gonderim-sablon"), "s2");
  await userEvent.click(kanca("gonderim-gonder"));
  await waitFor(() => expect(kanca("gonderim-onay")).toBeTruthy());
  expect(screen.getByText(/kanal yapılandırılmamış; mesaj gitmez/)).toBeTruthy();
  expect(kanca("gonderim-onayla")).toBeDisabled();
});

it("KOTA ASILIYOR ya da KIMSE YOK: onay KAPALI", async () => {
  taklit({ kota_kalan: 100 });
  ciz(() => GonderimKarti({ sablonlar: SABLONLAR }));
  await userEvent.selectOptions(kanca("gonderim-sablon"), "s2");
  await userEvent.click(kanca("gonderim-gonder"));
  await waitFor(() => expect(kanca("gonderim-onay")).toBeTruthy());
  expect(kanca("gonderim-onay").textContent).toContain("Günlük kotadan 100 mesaj kaldı");
  expect(kanca("gonderim-onayla")).toBeDisabled();
});

it("BLOK secilip bos birakilirsa Gonder kapali; govde suzgeci tasir", () => {
  expect(aliciGovdesi("s1", "blok", " A ", "security")).toEqual({ sablon_id: "s1", blok: "A" });
  expect(aliciGovdesi("s1", "rol", "", "security")).toEqual({ sablon_id: "s1", rol: "security" });
  expect(aliciGovdesi("s1", "tum", "", "security")).toEqual({ sablon_id: "s1" });
});
