// @vitest-environment jsdom
// (P250 §8) Yonetici: teknik ayar YOK, kanal durumu VAR, hazir sablon
// kutuphanesi -> duzenle -> KENDI sablonu olarak kaydet; doldurulmamis
// [YER TUTUCU] kaydi engeller. Platform: tesis sec -> o tesisin ayari.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import MesajlarPage from "@/app/(protected)/mesajlar/page";
import PlatformPage from "@/app/(protected)/mesaj-ayarlari/page";
import { duzMetniHtmlYap, yerTutuculari } from "@/components/mesaj/hazir-sablonlar";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

afterEach(() => vi.restoreAllMocks());

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

function taklit(harita: Record<string, unknown>): Cagri[] {
  const c: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    c.push({ url, metot, govde: init?.body ? JSON.parse(String(init.body)) : {} });
    const anahtar = Object.keys(harita)
      .filter((k) => url.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    const govde = anahtar ? harita[anahtar] : { error: { message: "yok" } };
    return new Response(JSON.stringify(govde), {
      status: anahtar ? (metot === "POST" ? 201 : 200) : 404,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return c;
}

const TEMEL = {
  "/api/panel/mesaj-sablonlari": { meta: { limit: 100, offset: 0, total: 1 }, items: [
    { id: "s1", kanal: "sms", ad: "Var olan", konu: null, govde: "x", amac: "operasyonel", aktif: true }] },
  "/api/panel/mesaj-gecmis": { meta: { limit: 20, offset: 0, total: 0 }, items: [] },
  "/api/panel/mesaj-durumu": { sms_hazir: false, eposta_hazir: true, bugun_gonderilen: 4, gunluk_kota: 100 },
  "/api/panel/mesaj-sablonlari-hazir": { items: [
    { kod: "odeme_kodu", kanal: "sms", ad: "Ödeme kodu", konu: null,
      govde: "{site_adi}: {adres} için ödeme kodunuz {odeme_kodu}." },
    { kod: "su_kesintisi", kanal: "sms", ad: "Su kesintisi", konu: null,
      govde: "{site_adi}: [TARİH] [BAŞLANGIÇ]-[BİTİŞ] arası su kesintisi olacaktır." },
  ] },
};

it("yonetici: Ayarlar sekmesi yok, kanal durumu ve destek yonlendirmesi var", async () => {
  const c = taklit(TEMEL);
  ciz(MesajlarPage);
  const kart = await screen.findByText(tr.mesajDurumAciklama);
  expect(kart).toBeTruthy();
  const durum = document.querySelector('[data-test="mesaj-durumu"]') as HTMLElement;
  expect(within(durum).getByText(/E-posta/).textContent).toContain(tr.mesajHazir);
  expect(within(durum).getByText(/SMS/).textContent).toContain(tr.mesajYapilandirilmadi);
  expect(durum.textContent).toContain("4 / 100");
  expect(c.some((x) => x.url.includes("mesaj-ayarlari"))).toBe(false);
});

it("hazir sablon: sec -> forma duser -> kendi sablonu olarak kaydedilir", async () => {
  const c = taklit(TEMEL);
  const k = userEvent.setup();
  ciz(MesajlarPage);
  await k.click(await screen.findByRole("tab", { name: "SMS Şablonları" }));
  await k.click(await screen.findByRole("button", { name: tr.mesajHazirSablonlar }));
  const satir = await waitFor(() => {
    const el = document.querySelector('[data-test="hazir-odeme_kodu"]') as HTMLElement;
    expect(el).toBeTruthy();
    return el;
  });
  // Istek kullanicinin DILIYLE gider.
  expect(c.some((x) => x.url.includes("mesaj-sablonlari-hazir?kanal=sms&dil=tr"))).toBe(true);
  await k.click(within(satir).getByRole("button", { name: tr.mesajHazirSablonKullan }));
  expect((screen.getByLabelText(tr.mesajAd) as HTMLInputElement).value).toBe("Ödeme kodu");
  expect((screen.getByLabelText(tr.mesajGovde) as HTMLTextAreaElement).value).toContain("{odeme_kodu}");
  await k.click(screen.getByRole("button", { name: tr.mesajSablonKaydet }));
  await waitFor(() => expect(c.some((x) => x.metot === "POST")).toBe(true));
  const post = c.find((x) => x.metot === "POST")!;
  expect(post.url).toBe("/api/panel/mesaj-sablonlari");
  expect(post.govde).toMatchObject({ kanal: "sms", ad: "Ödeme kodu", konu: null });
  expect(String(post.govde.govde)).toContain("{odeme_kodu}");
});

it("doldurulmamis [YER TUTUCU] kaydi engeller", async () => {
  const c = taklit(TEMEL);
  const k = userEvent.setup();
  ciz(MesajlarPage);
  await k.click(await screen.findByRole("tab", { name: "SMS Şablonları" }));
  await k.click(await screen.findByRole("button", { name: tr.mesajHazirSablonlar }));
  const satir = await waitFor(() => {
    const el = document.querySelector('[data-test="hazir-su_kesintisi"]') as HTMLElement;
    expect(el).toBeTruthy();
    return el;
  });
  await k.click(within(satir).getByRole("button", { name: tr.mesajHazirSablonKullan }));
  expect(document.querySelector('[data-test="yer-tutucu-uyari"]')?.textContent).toContain("[TARİH]");
  await k.click(screen.getByRole("button", { name: tr.mesajSablonKaydet }));
  expect(c.some((x) => x.metot === "POST")).toBe(false);
});

it("yardimcilar: yer tutucu ve duz metin -> HTML (kacisli)", () => {
  expect(yerTutuculari("[A] {ad} [B] [A]")).toEqual(["[A]", "[B]"]);
  expect(yerTutuculari("{adi_soyadi}")).toEqual([]);
  expect(duzMetniHtmlYap("Merhaba <b>\nsatir\n\nikinci")).toBe(
    "<p>Merhaba &lt;b&gt;<br>satir</p><p>ikinci</p>",
  );
});

it("platform: tesis secilir, ayar o tesisin ucundan okunur ve yazilir", async () => {
  const c = taklit({
    "/api/tenants?": { items: [{ id: "t-1", ad: "Güneş Sitesi" }, { id: "t-2", ad: "Ay Sitesi" }] },
    "/api/tenants/t-2/mesaj-ayarlari": {
      sms_saglayici: null, sms_kullanici: null, sms_baslik: null, sms_parola_var: false,
      smtp_host: null, smtp_port: 587, smtp_kullanici: null, smtp_parola_var: true,
      smtp_gonderen: null, gunluk_kota: null, bugun_gonderilen: 0,
      sms_hazir: false, eposta_hazir: true, sms_kaynak: "yok", eposta_kaynak: "genel",
    },
  });
  const k = userEvent.setup();
  ciz(PlatformPage);
  expect(await screen.findByText(tr.mesajAyarTesisSec)).toBeTruthy();
  await k.click(await screen.findByRole("button", { name: "Ay Sitesi" }));
  await waitFor(() =>
    expect(c.some((x) => x.url === "/api/tenants/t-2/mesaj-ayarlari" && x.metot === "GET")).toBe(true),
  );
  await k.type(await screen.findByLabelText(tr.mesajGunlukKota), "50");
  await k.click(screen.getByRole("button", { name: tr.ortakKaydet }));
  await waitFor(() => expect(c.some((x) => x.metot === "PUT")).toBe(true));
  const put = c.find((x) => x.metot === "PUT")!;
  expect(put.url).toBe("/api/tenants/t-2/mesaj-ayarlari");
  expect(put.govde).toEqual({ gunluk_kota: 50 });
});
