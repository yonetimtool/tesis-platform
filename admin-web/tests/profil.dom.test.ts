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
    // (P184-ek düzeltme §1) E-posta ad/telefonla AYNI: düzenlenebilir INPUT.
    expect(screen.getByDisplayValue("ayse@ornek.com")).toBeInTheDocument();
  });

  it("(P184-ek düzeltme §1) E-POSTA ad/telefonla AYNI: kutu + Kaydet ile doğrulama", async () => {
    // E-posta AYRI bir "değiştir" bağlantısı/ekranı/akışı DEĞİL: ad/telefon gibi
    // doğrudan düzenlenebilir bir kutu. Kaydet'e basınca YENİ adrese kod gider,
    // "doğrulama bekliyor" durumu görünür; eski adres doğrulanana kadar geçerli.
    const cagrilar = fetchTaklidi(PROFIL);
    ciz(ProfilPage);
    const epostaAlani = await screen.findByDisplayValue("ayse@ornek.com");
    expect(epostaAlani).not.toBeDisabled();
    await userEvent.clear(epostaAlani);
    await userEvent.type(epostaAlani, "yeni@ornek.com");
    await userEvent.click(screen.getByRole("button", { name: /Kaydet/i }));
    // Yeni adrese doğrulama kodu istendi (eski adres henüz değişmedi).
    await waitFor(() =>
      expect(
        cagrilar.find((c) => c.url.includes("/me/eposta/kod-iste")),
      ).toBeTruthy(),
    );
    expect(
      cagrilar.find((c) => c.url.includes("/me/eposta/kod-iste"))?.body,
    ).toMatchObject({ eposta: "yeni@ornek.com" });
    expect(await screen.findByText("doğrulama bekliyor")).toBeInTheDocument();
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

// ===========================================================================
// (P212 §2) PROFIL FOTOGRAFI — YUKLEME, KALDIRMA, BAS HARFLER
// ===========================================================================
// Web tarafi "test edilmedi" diye isaretlenmisti. Olculen sey: dosyanin
// BFF'ten GECMEDIGI (presign + dogrudan PUT), `PATCH /me/avatar`e giden
// govde, kaldirmada `avatar_key: null`in GERCEKTEN gitmesi (alan gövdeden
// duserse sunucu "degistirme" diye yorumlar ve fotograf DURUR) ve fotograf
// yokken BAS HARFLERIN cizilmesi.
describe("(P212 §2) profil fotografi", () => {
  const FOTOLU = { ...PROFIL, avatar_url: "https://storage.test/eski.jpg" };

  /** Presign + PUT + PATCH yollarini ayri ayri yanitlar. */
  function fotoTaklidi(profil: unknown) {
    const cagrilar: { url: string; method: string; body: unknown }[] = [];
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      const url = String(girdi);
      const method = (init?.method ?? "GET").toUpperCase();
      const ikili = init?.body instanceof Blob || init?.body instanceof File;
      cagrilar.push({
        url,
        method,
        body: init?.body && !ikili ? JSON.parse(String(init.body)) : undefined,
      });
      if (url.startsWith("/api/uploads/presign")) {
        return new Response(
          JSON.stringify({
            foto_key: "t-1/tasks/yeni.jpg",
            upload_url: "https://storage.test/tesis-foto/t-1/tasks/yeni.jpg?imza=1",
            method: "PUT",
            expires_in: 900,
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }
      if (url.startsWith("https://storage.test/")) {
        return new Response(null, { status: 200 });
      }
      if (url.startsWith("/api/me/avatar")) {
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
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

  it("FOTOGRAF YOKKEN bas harfler cizilir (silüet DEGIL)", async () => {
    fotoTaklidi(PROFIL);
    ciz(ProfilPage);
    // "Ayşe Yılmaz" -> "AY". Genel bir ikon, iki hesabi olan kullanici
    // icin hangi hesapla girildigini silerdi.
    await waitFor(() => expect(screen.getAllByText("AY").length).toBeGreaterThan(0));
  });

  it("KALDIR: `avatar_key: null` GERCEKTEN gonderilir", async () => {
    const k = userEvent.setup();
    const cagrilar = fotoTaklidi(FOTOLU);
    ciz(ProfilPage);

    const dugme = await screen.findByRole("button", { name: /kaldır/i });
    await k.click(dugme);

    await waitFor(() =>
      expect(cagrilar.some((c) => c.url === "/api/me/avatar")).toBe(true),
    );
    const patch = cagrilar.find((c) => c.url === "/api/me/avatar")!;
    expect(patch.method).toBe("PATCH");
    // Alan GOVDEDE ve degeri null: "kaldir" ile "degistirme" farki.
    expect(patch.body).toEqual({ avatar_key: null });
  });

  it("KALDIR dugmesi fotograf YOKKEN cizilmez", async () => {
    fotoTaklidi(PROFIL);
    ciz(ProfilPage);
    // Ad bir GIRDI DEGERI; metin olarak aranmaz. Kart cizildiginde
    // "Fotoğraf yükle" dugmesi bulunur.
    await screen.findByRole("button", { name: /fotoğraf yükle/i });
    expect(screen.queryByRole("button", { name: /kaldır/i })).toBeNull();
  });

  it("YUKLEME: dosya BFF'ten GECMEZ, presign + dogrudan PUT + PATCH", async () => {
    const k = userEvent.setup();
    const cagrilar = fotoTaklidi(PROFIL);
    ciz(ProfilPage);
    await screen.findByRole("button", { name: /fotoğraf yükle/i });

    const girdi = document.querySelector(
      'input[type="file"]',
    ) as HTMLInputElement;
    await k.upload(
      girdi,
      new File([new Uint8Array([1, 2, 3])], "ben.jpg", { type: "image/jpeg" }),
    );

    await waitFor(() =>
      expect(cagrilar.some((c) => c.url === "/api/me/avatar")).toBe(true),
    );
    // 1) presign istendi, 2) dosya DOGRUDAN depoya PUT edildi,
    // 3) BFF'e yalniz ANAHTAR gitti.
    expect(cagrilar.some((c) => c.url === "/api/uploads/presign")).toBe(true);
    const put = cagrilar.find((c) => c.url.startsWith("https://storage.test/"))!;
    expect(put.method).toBe("PUT");
    expect(cagrilar.find((c) => c.url === "/api/me/avatar")!.body).toEqual({
      avatar_key: "t-1/tasks/yeni.jpg",
    });
  });
});

// ===========================================================================
// (P212-ek §1) E-POSTA DEGISTIRME: SESSIZ "BEKLIYOR" EKRANI YOK
// ===========================================================================
// OLCULEN KUSUR (prod): kullanici e-postasini degistirdi, ekran
// "dogrulama bekliyor" dedi ve kod kutusu acildi; `mesaj_gonderim`
// tablosunda O ADRESE AIT HIC KAYIT YOKTU. Sunucu, adres baskasindaysa
// kod URETMEDEN "gonderildi" donuyordu.
//
// Sunucu artik 409 donuyor (backend `test_p212_gonderim_izi.py`).
// Burada olculen sey ARAYUZUN o yaniti nasil ele aldigi: kod kutusu
// ACILMAMALI ve sebep GORUNMELI.
describe("(P212-ek §1) e-posta degistirme", () => {
  function epostaTaklidi(kodIsteDurumu: number, hataMetni = "Bu e-posta adresi başka bir hesapta kullanılıyor.") {
    const cagrilar: { url: string; method: string; body: unknown }[] = [];
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      const url = String(girdi);
      cagrilar.push({
        url,
        method: (init?.method ?? "GET").toUpperCase(),
        body: init?.body ? JSON.parse(String(init.body)) : undefined,
      });
      if (url.startsWith("/api/me/eposta/kod-iste")) {
        return new Response(
          JSON.stringify(
            kodIsteDurumu === 200
              ? { durum: "gonderildi" }
              : { error: { code: "conflict", message: hataMetni } },
          ),
          { status: kodIsteDurumu, headers: { "Content-Type": "application/json" } },
        );
      }
      if (url.startsWith("/api/me/contact")) return new Response(null, { status: 204 });
      if (url.startsWith("/api/me")) {
        return new Response(JSON.stringify(PROFIL), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      return new Response(JSON.stringify({}), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }) as typeof fetch;
    return cagrilar;
  }

  async function epostaDegistir(k: ReturnType<typeof userEvent.setup>) {
    ciz(ProfilPage);
    const alan = await screen.findByDisplayValue(PROFIL.email);
    await k.clear(alan);
    await k.type(alan, "yeni-adres@ornek.com");
    await k.click(screen.getByRole("button", { name: /kaydet/i }));
  }

  it("409: KOD KUTUSU ACILMAZ ve sebep GORUNUR", async () => {
    const k = userEvent.setup();
    epostaTaklidi(409);
    await epostaDegistir(k);

    await screen.findByText(/başka bir hesapta kullanılıyor/i);
    // "Doğrulama bekliyor" ekrani HIC GONDERILMEMISKEN GOSTERILMEZ.
    expect(screen.queryByPlaceholderText(/kod/i)).toBeNull();
  });

  it("200: kod kutusu ACILIR (gerileme yok)", async () => {
    const k = userEvent.setup();
    const cagrilar = epostaTaklidi(200);
    await epostaDegistir(k);

    await waitFor(() =>
      expect(cagrilar.some((c) => c.url === "/api/me/eposta/kod-iste")).toBe(true),
    );
    expect(
      cagrilar.find((c) => c.url === "/api/me/eposta/kod-iste")!.body,
    ).toEqual({ eposta: "yeni-adres@ornek.com" });
    expect(await screen.findByPlaceholderText(/kod/i)).toBeTruthy();
  });
});
