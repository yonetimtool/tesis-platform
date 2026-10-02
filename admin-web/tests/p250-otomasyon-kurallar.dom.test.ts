// @vitest-environment jsdom
// (P250 §9) OTOMASYON KURALLARI: her kural duz cumle, ac/kapat, son
// calisma + sonucu, "bugun calissaydi", 4 adimli sihirbaz ve onizleme.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/finans/otomasyon/page";
import { ilkAylikTarih } from "@/components/otomasyon/kurallar";
import { giderCumlesi, planCumlesi, sonCalismaCumlesi } from "@/lib/otomasyon-cumle";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/finans/otomasyon",
  useSearchParams: () => new URLSearchParams(),
}));

afterEach(() => vi.restoreAllMocks());

const PLAN = {
  id: "p1", ad: "Aidat", gelir_gider_tanim_id: "t1", dagitim: "daire_basina",
  tutar_kurus: 120000, toplam_tutar_kurus: null, tahakkuk_gunu: 1, vade_gun: 10,
  onizleme_gun: 3, aktif: true, son_donem: "2026-10", ertelenen_donem: null,
};
const GIDER = {
  id: "g1", ad: "Kapıcı maaşı", tutar_kurus: 1500000, periyot: "aylik",
  sonraki_tarih: "2026-11-05", otomatik_onay: false, aktif: false, kasa_id: null,
};
const HARITA: Record<string, unknown> = {
  "/api/panel/aidat-planlari": { items: [PLAN] },
  "/api/panel/duzenli-giderler": { items: [GIDER] },
  "/api/panel/hatirlatma-ayari": {
    aktif: true, vade_oncesi_gun: 0, kademeler: [3], metin: null, eposta: false,
    ilk_gun: 3, tekrar_sayisi: 1, aralik_gun: 7,
  },
  "/api/panel/gecikme-ayari": { gecikme_aylik_yuzde: 5, gecikme_uygula: true },
  "/api/panel/otomasyon-son-calismalar": { items: [
    { kural: "p1", tur: "aidat_tahakkuk", zaman: "2026-10-01T03:00:00Z", adet: 47, tutar_kurus: 5640000, durum: null },
  ] },
  "/api/panel/hatirlatma-onizleme": { adet: 12, toplam_kurus: 900000, atlanan: 0 },
  "/api/panel/gecikme-faizi-onizleme": {
    donem: "2026-10", uygulaniyor: true, aylik_yuzde: 5, toplam_fark_kurus: 25000,
    items: [{ fark_kurus: 15000 }, { fark_kurus: 10000 }, { fark_kurus: 0 }],
  },
  "/api/panel/aidat-plani-onizleme": {
    adet: 47, toplam_kurus: 5640000, atlanan: 2, donem: "2026-10", ilk_tarih: "2026-11-05",
  },
  "/api/tanimlar/gelir-gider-tanimlari": { items: [{ id: "t1", ad: "Aidat" }] },
  "/api/panel/kasalar": { items: [{ id: "k1", ad: "Banka", kod: "B" }] },
  // (P252 §2) Maas kurali — personelsiz tesis.
  "/api/panel/maas-ayari": {
    aktif: true, otomatik_onay: true, gruplar: [], personel_sayisi: 0,
    aylik_toplam_kurus: 0, onay_bekleyenler: [],
  },
};

function taklit() {
  const c: { url: string; metot: string; govde: Record<string, unknown> }[] = [];
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    const url = String(g);
    const metot = (init?.method ?? "GET").toUpperCase();
    c.push({ url, metot, govde: init?.body ? JSON.parse(String(init.body)) : {} });
    const anahtar = Object.keys(HARITA).filter((k) => url.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    const yanit = metot === "GET" || url.includes("onizleme")
      ? (anahtar ? HARITA[anahtar] : { items: [], meta: { total: 0 } })
      : { id: "yeni" };
    return new Response(JSON.stringify(yanit), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}

const kural = (id: string) => document.querySelector(`[data-test="kural-${id}"]`) as HTMLElement;

it("her kural DUZ CUMLE + son calisma + bugun calissaydi", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kural("p1")).toBeTruthy());
  const p = within(kural("p1"));
  expect(p.getByText(/Her ayın 1\. günü tüm dairelere daire başına 1\.200,00 ₺ “Aidat” borcu/)).toBeTruthy();
  expect(kural("p1").textContent).toContain("47 daireye toplam 56.400,00 ₺ borç yazıldı");
  await waitFor(() => expect(kural("g1")).toBeTruthy());
  expect(kural("g1").textContent).toContain("Her ay “Kapıcı maaşı” için 15.000,00 ₺ ödeme kaydı açılır");
  expect(kural("g1").textContent).toContain(tr.otoKuralSonYok);
  await waitFor(() => expect(kural("borc_hatirlatma")?.textContent).toContain("12 kişiye hatırlatma giderdi"));
  await waitFor(() => expect(kural("gecikme_faizi")?.textContent).toContain("%5 gecikme faizi"));
  expect(kural("gecikme_faizi").textContent).toContain("2 borca toplam 250,00 ₺ faiz eklenirdi");
  // TEKNIK TERIM YOK.
  const liste = document.querySelector('[data-test="kurallar"]')!.textContent!.toLowerCase();
  for (const terim of ["tahakkuk", "kademe", "periyot", "dağıtım"]) expect(liste).not.toContain(terim);
});

it("ac/kapat: kuralin kendi kaydina PATCH aktif", async () => {
  const c = taklit();
  const k = userEvent.setup();
  ciz(Sayfa);
  await waitFor(() => expect(kural("g1")).toBeTruthy());
  const anahtar = within(kural("g1")).getByRole("switch");
  expect((anahtar as HTMLInputElement).checked).toBe(false);
  await k.click(anahtar);
  await waitFor(() => expect(c.some((x) => x.metot === "PATCH")).toBe(true));
  const patch = c.find((x) => x.metot === "PATCH")!;
  expect(patch.url).toBe("/api/panel/duzenli-giderler/g1");
  expect(patch.govde).toEqual({ aktif: true });

  await k.click(within(kural("gecikme_faizi")).getByRole("switch"));
  await waitFor(() => expect(c.some((x) => x.url === "/api/panel/gecikme-ayari" && x.metot === "PATCH")).toBe(true));
  expect(c.find((x) => x.url === "/api/panel/gecikme-ayari" && x.metot === "PATCH")!.govde)
    .toEqual({ gecikme_uygula: false });
});

it("sihirbaz: ne zaman -> kime -> ne -> onizleme (sunucudan) -> kaydet", async () => {
  const c = taklit();
  const k = userEvent.setup();
  ciz(Sayfa);
  await k.click(await screen.findByRole("button", { name: tr.otoKuralYeni }));
  const baslik = () => document.querySelector('[data-test="sihirbaz-baslik"]')!.textContent;
  expect(baslik()).toBe(tr.otoSihirbazNeZaman);
  const gun = screen.getByLabelText(tr.otoSihirbazAyinGunu);
  await k.clear(gun);
  await k.type(gun, "5");
  await k.click(screen.getByRole("button", { name: tr.otoSihirbazIleri }));
  expect(baslik()).toBe(tr.otoSihirbazKime);
  // Secim yapmadan ilerlenmez.
  await k.click(screen.getByRole("button", { name: tr.otoSihirbazIleri }));
  expect(screen.getByText(tr.otoSihirbazEksik)).toBeTruthy();
  await k.click(screen.getByLabelText(new RegExp(tr.otoSihirbazKimeDaireler)));
  await k.click(screen.getByRole("button", { name: tr.otoSihirbazIleri }));
  expect(baslik()).toBe(tr.otoSihirbazNe);
  await k.type(screen.getByLabelText(new RegExp(tr.otoSihirbazAd)), "Aylık aidat");
  await waitFor(() => expect(screen.getByRole("option", { name: "Aidat" })).toBeTruthy());
  await k.selectOptions(screen.getByLabelText(new RegExp(tr.otoSihirbazKalem)), "t1");
  await k.type(screen.getByLabelText(new RegExp(tr.otoSihirbazTutarDaire.replace(/[()₺]/g, "."))), "1200");
  await k.click(screen.getByRole("button", { name: tr.otoSihirbazIleri }));

  await waitFor(() => expect(baslik()).toBe(tr.otoSihirbazOnizleme));
  const oniz = c.find((x) => x.url === "/api/panel/aidat-plani-onizleme")!;
  expect(oniz.metot).toBe("POST");
  expect(oniz.govde).toMatchObject({
    ad: "Aylık aidat", gelir_gider_tanim_id: "t1", dagitim: "daire_basina",
    tutar_kurus: 120000, tahakkuk_gunu: 5,
  });
  const alan = document.querySelector('[data-test="sihirbaz-onizleme"]')!.textContent!;
  expect(alan).toContain("Her ayın 5. günü tüm dairelere daire başına 1.200,00 ₺ “Aylık aidat” borcu");
  expect(alan).toContain("Bu kural bugün çalışsaydı 47 daireye toplam 56.400,00 ₺ borç yazılırdı.");
  expect(alan).toContain("2 dairenin tutarı belirlenemediği için atlanırdı.");
  // Onizleme KAYDETMEDI.
  expect(c.some((x) => x.url === "/api/panel/aidat-planlari" && x.metot === "POST")).toBe(false);

  await k.click(screen.getByRole("button", { name: tr.otoSihirbazKaydet }));
  await waitFor(() =>
    expect(c.some((x) => x.url === "/api/panel/aidat-planlari" && x.metot === "POST")).toBe(true),
  );
});

it("sihirbaz: aylik degilse dairelere borc secilemez; gider kaydi kurulur", async () => {
  const c = taklit();
  const k = userEvent.setup();
  ciz(Sayfa);
  await k.click(await screen.findByRole("button", { name: tr.otoKuralYeni }));
  await k.click(screen.getByLabelText(tr.otoKuralSiklikUcAylik));
  await k.type(screen.getByLabelText(tr.otoSihirbazIlkTarih), "2026-12-01");
  await k.click(screen.getByRole("button", { name: tr.otoSihirbazIleri }));
  expect((screen.getByLabelText(new RegExp(tr.otoSihirbazKimeDaireler)) as HTMLInputElement).disabled).toBe(true);
  expect(screen.getByText(tr.otoSihirbazYalnizAylik)).toBeTruthy();
  await k.click(screen.getByLabelText(new RegExp(tr.otoSihirbazKimeGider)));
  await k.click(screen.getByRole("button", { name: tr.otoSihirbazIleri }));
  await k.type(screen.getByLabelText(new RegExp(tr.otoSihirbazAd)), "Asansör bakımı");
  await k.type(screen.getByLabelText(new RegExp(`^${tr.otoSihirbazTutar.replace(/[()₺]/g, ".")}`)), "3000");
  await k.click(screen.getByRole("button", { name: tr.otoSihirbazIleri }));
  const alan = document.querySelector('[data-test="sihirbaz-onizleme"]')!.textContent!;
  expect(alan).toContain("Üç ayda bir “Asansör bakımı” için 3.000,00 ₺ ödeme kaydı açılır");
  await k.click(screen.getByRole("button", { name: tr.otoSihirbazKaydet }));
  await waitFor(() =>
    expect(c.some((x) => x.url === "/api/panel/duzenli-giderler" && x.metot === "POST")).toBe(true),
  );
  expect(c.find((x) => x.url === "/api/panel/duzenli-giderler" && x.metot === "POST")!.govde)
    .toMatchObject({ periyot: "uc_aylik", sonraki_tarih: "2026-12-01", tutar_kurus: 300000 });
});

it("yardimcilar: cumleler ve ilk aylik tarih", () => {
  const t = ((a: keyof typeof tr, p?: Record<string, string | number>) =>
    tr[a].replace(/\{(\w+)\}/g, (_m, k) => String(p?.[k] ?? ""))) as never;
  expect(planCumlesi({ ...PLAN, dagitim: "arsa_payi", tutar_kurus: null, toplam_tutar_kurus: 900000 }, t))
    .toContain("toplam 9.000,00 ₺ “Aidat” borcu tüm dairelere arsa payına göre bölünerek");
  expect(giderCumlesi({ ...GIDER, otomatik_onay: true }, t, (x) => x)).toContain("ödenmiş sayılır");
  expect(sonCalismaCumlesi(undefined, t, (x) => x)).toBe(tr.otoKuralSonYok);
  expect(ilkAylikTarih(5, new Date(2026, 9, 3))).toBe("2026-10-05");
  expect(ilkAylikTarih(5, new Date(2026, 9, 6))).toBe("2026-11-05");
  expect(ilkAylikTarih(1, new Date(2026, 11, 20))).toBe("2027-01-01");
});
