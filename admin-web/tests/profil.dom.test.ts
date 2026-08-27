// @vitest-environment jsdom
// (P126.3) PROFIL — `app.*`in ilk KENDINE AIT sayfasi.
//
// Bugune kadar paneldeki 25 sayfa yonetimin BASKALARINI yonettigi
// ekranlardi; bu, kullanicinin KENDI kaydina dokundugu ilk yer ve tesis
// calisma alaninin (P126.3-.6) temel tasi.
//
// UC OLCUM, ucu de sessizce yanlis olabilecek cinsten:
//  1. Telefon P123 maskesinden GECIYOR mu (yoksa alan gruplanmadan yazilir);
//  2. Sunucuya NORMALLESTIRILMIS gidiyor mu (ayni numaranin iki yazimi,
//     telefon global benzersiz oldugu icin cakisma uretir);
//  3. Bos birakmak numarayi KALDIRIYOR mu (acik null) — "degistirme" ile
//     "kaldir" arasindaki fark.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import ProfilPage from "@/app/(protected)/profil/page";

import { ciz } from "./yardimci";

/**
 * YEREL fetch taklidi — paylasilan `fetchSahtele` GOVDE yakalamiyor ve bu
 * testin asil olcumu gonderilen govdedir (normallestirilmis telefon).
 * Paylasilan yardimciyi genisletmek, 40+ testin davranisini degistirme
 * riskiydi; yerel taklit o riski almadan ayni iSi yapiyor.
 */
function fetchTaklidi(profil: unknown) {
  const cagrilar: { url: string; method: string; body: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    if (url.startsWith("/api/me/contact")) {
      return new Response(null, { status: 204 });
    }
    if (url.startsWith("/api/me")) {
      return new Response(JSON.stringify(profil), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ error: { message: "yok" } }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const PROFIL = {
  id: "u1",
  ad: "Ayşe Yılmaz",
  email: "ayse@ornek.com",
  // (P181 Böl.1) DOĞRULANMIŞ: kimlik testleri e-posta ALANINA bakar; doğrulanmamış
  // olsaydı EpostaDogrulaKart mevcut adresi ön-doldurup ikinci bir eşleşme üretirdi
  // (kartın kendi testi ayrı). Bu testler doğrulama akışını ölçmüyor.
  eposta_dogrulandi: true,
  telefon: "+905431992904",
  aranabilir: true,
  role: "resident",
};

afterEach(() => vi.restoreAllMocks());

describe("Profilim", () => {
  it("KIMLIK bilgileri gosterilir", async () => {
    // (P167 §1.7) AD ARTIK DUZENLENEBILIR bir alan (salt okunur bir `dd`
    // degil): brief'in "Hesap Bilgileri" formu onu istiyor ve uc
    // (`PATCH /me/contact`) `ad` alanini bu turda kabul ediyor.
    fetchTaklidi(PROFIL);
    ciz(ProfilPage);
    expect(await screen.findByDisplayValue("Ayşe Yılmaz")).toBeInTheDocument();
    expect(screen.getByDisplayValue("ayse@ornek.com")).toBeInTheDocument();
  });

  it("(P167 §1.7) E-POSTA ALANI SALT OKUNUR — giris anahtaridir", async () => {
    // Dogrulama akisi olmadan degistirilebilseydi: odunc alinmis bir
    // oturum adresi degistirip hesabin sahibini kalici olarak disarida
    // birakabilir, yanlis yazilan bir adres parola sifirlamayi SESSIZCE
    // calismaz kilardi. Alan GOSTERILIR (gizlemek "neden yok?" sorusu
    // uretirdi) ama kilitlidir.
    fetchTaklidi(PROFIL);
    ciz(ProfilPage);
    const eposta = await screen.findByDisplayValue("ayse@ornek.com");
    expect(eposta).toBeDisabled();
  });

  it("(P167 §1.7) BOS AD kaydettirmez", async () => {
    // `app_user.ad` NOT NULL ve her ekranda kisinin tek tanimi; bos ad
    // listelerde adsiz satirlar uretirdi. Telefondan farki tam da bu:
    // orada bos deger "numarayi kaldir" demektir.
    const cagrilar = fetchTaklidi(PROFIL);
    ciz(ProfilPage);
    const adAlani = await screen.findByDisplayValue("Ayşe Yılmaz");
    await userEvent.clear(adAlani);
    await userEvent.click(screen.getByRole("button", { name: /Kaydet/i }));
    expect(
      await screen.findByText(/Ad soyad boş bırakılamaz/i),
    ).toBeInTheDocument();
    expect(cagrilar.find((c) => c.method === "PATCH")).toBeUndefined();
  });

  it("(P167 §1.7 · P170 §2) SOL MENU ALTI bolum cizer ve secim degistirir", async () => {
    fetchTaklidi(PROFIL);
    ciz(ProfilPage);
    const gezinme = await screen.findByRole("navigation", {
      name: "Profil bölümleri",
    });
    const bolumler = [...gezinme.querySelectorAll("button")].map(
      (b) => b.textContent,
    );
    // (P170 §2) "Yasal Metinler" EKLENDI: KVKK metinlerinin YONETIMI
    // panele tasindi, OKUMASI buraya. Yonetim tasindi diye kullanicinin
    // kendi aydinlatma metnini okuyamamasi, aydinlatmanin kendisini
    // imkansiz kilardi.
    expect(bolumler).toEqual([
      "Hesap bilgileri",
      "Güvenlik ve giriş",
      "Bildirim ayarları",
      "Yasal Metinler",
      "Şifre değiştir",
      "Hesabımı sil",
    ]);
    await userEvent.click(
      screen.getByRole("button", { name: "Şifre değiştir" }),
    );
    // Bolum degisti: parola formunun alanlari ekranda.
    expect(await screen.findByLabelText(/Mevcut şifre/)).toBeInTheDocument();
  });

  it("TELEFON P123 maskesiyle GRUPLANMIS gelir", async () => {
    // Sunucudan E.164 gelir; kullanici yerel bicimi gormeli.
    fetchTaklidi(PROFIL);
    ciz(ProfilPage);
    await waitFor(() =>
      expect(screen.getByDisplayValue("0543 199 29 04")).toBeInTheDocument(),
    );
  });

  it("KAYDETTE sunucuya NORMALLESTIRILMIS numara gider", async () => {
    const cagrilar = fetchTaklidi(PROFIL);
    ciz(ProfilPage);
    await waitFor(() =>
      expect(screen.getByDisplayValue("0543 199 29 04")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("button", { name: /Kaydet/i }));
    await waitFor(() => {
      const c = cagrilar.find((x) => x.url.includes("/api/me/contact"));
      expect(c?.body).toMatchObject({ telefon: "+905431992904" });
    });
  });

  it("GECERSIZ on ek KAYDETTIRMEZ", async () => {
    fetchTaklidi({ ...PROFIL, telefon: null });
    ciz(ProfilPage);
    const kutu = await screen.findByPlaceholderText(/05/);
    await userEvent.type(kutu, "02125554433");
    await userEvent.click(screen.getByRole("button", { name: /Kaydet/i }));
    expect(await screen.findByText(/5 ile başlamalı/i)).toBeInTheDocument();
  });
});
