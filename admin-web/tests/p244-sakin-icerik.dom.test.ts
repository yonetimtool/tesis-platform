// @vitest-environment jsdom
//
// (P244 §8d) SAKIN ICERIK EKRANLARI — SOZLESMENIN VERDIGI VERI EKRANA CIKAR.
//
// ===========================================================================
// OLCULEN KUSUR — tasarim degil, GORUNMEYEN VERI
// ===========================================================================
// Sozlesme `Announcement`, `Etkinlik` ve `SiteKurali` semalarinin
// UCUNDE de `foto_url` (kisa omurlu presigned GET) soz veriyor ve
// yonetim ekranlari gorsel YUKLUYOR — kural gorseli P190 §3'te
// OZELLIKLE eklenmisti.
//
// Sakin taraftaki uc ekran bu alani yerel tiplerine HIC KOYMAMISTI:
// yonetici duyuruya/kurala kapak gorseli ekliyor, sakin onu HIC
// GORMUYORDU. Ayni sekilde `olusturan_ad` ve etkinliklerin SEFFAF
// katilim sayilari da cizilmiyordu.
//
// ===========================================================================
// NEDEN BU KILIT GEREKLI
// ===========================================================================
// Bu kusur GORUNMEZ: ekran hatasiz calisir, test yesildir, yalnizca
// veri eksiktir. Tek yakalayan sey, "uc ne veriyorsa ekran onu
// gosteriyor mu" diye SORAN bir iddiadir.
//
// `uc-sozlesme-kapisi` kilidi TERS yonu olcer (sozlesmenin vermedigi
// alan okunmasin); bu dosya eksik kalan yonu olcer.
import { screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import DuyurularPage from "@/app/(protected)/duyurular/page";
import EtkinliklerPage from "@/app/(protected)/etkinlikler/page";
import KurallarPage from "@/app/(protected)/kurallar/page";
import YonetimIletisimPage from "@/app/(protected)/yonetim-iletisim/page";

import { ciz, fetchSahtele } from "./yardimci";

const FOTO = "https://depo.test/duyuru.jpg?imza=1";
const KURAL_FOTO = "https://depo.test/kural.jpg?imza=1";
const AVATAR = "https://depo.test/avatar.jpg?imza=1";

afterEach(() => vi.restoreAllMocks());

describe("(P244 §8d) duyurular — sakin gorunumu", () => {
  it("KAPAK GORSELI CIZILIR (uc `foto_url` veriyor)", async () => {
    fetchSahtele({
      "/api/announcements": {
        items: [
          {
            id: "d1",
            baslik: "Su kesintisi",
            govde: "Yarın 09:00-12:00 arası su kesintisi olacaktır.",
            foto_url: FOTO,
            olusturan_ad: "Ayşe Yönetici",
            created_at: "2026-09-01T08:00:00Z",
          },
        ],
      },
    });
    ciz(DuyurularPage);
    const gorsel = await screen.findByRole("img", { name: /Su kesintisi/ });
    expect(gorsel.getAttribute("src")).toBe(FOTO);
  });

  it("DUYURUYU YAZAN KISI gorunur (`olusturan_ad`)", async () => {
    fetchSahtele({
      "/api/announcements": {
        items: [
          {
            id: "d1",
            baslik: "Su kesintisi",
            govde: "Metin",
            foto_url: null,
            olusturan_ad: "Ayşe Yönetici",
            created_at: "2026-09-01T08:00:00Z",
          },
        ],
      },
    });
    ciz(DuyurularPage);
    expect(await screen.findByText(/Ayşe Yönetici/)).toBeInTheDocument();
  });

  it("GORSEL YOKSA BOS KUTU CIZILMEZ", async () => {
    // `foto_url` null iken bir yer tutucu cizmek, her duyuruya
    // olmayan bir gorselin yerini ayirmakti.
    fetchSahtele({
      "/api/announcements": {
        items: [
          {
            id: "d1",
            baslik: "Su kesintisi",
            govde: "Metin",
            foto_url: null,
            olusturan_ad: null,
            created_at: "2026-09-01T08:00:00Z",
          },
        ],
      },
    });
    ciz(DuyurularPage);
    await screen.findByText("Su kesintisi");
    expect(screen.queryByRole("img", { name: /Su kesintisi/ })).toBeNull();
  });
});

describe("(P244 §8d) etkinlikler — seffaf katilim sayilari", () => {
  function kur(over: Record<string, unknown> = {}) {
    fetchSahtele({
      "/api/events": {
        items: [
          {
            id: "e1",
            baslik: "Maç izleme akşamı",
            aciklama: "Açıklama",
            tarih: "2026-09-10T18:00:00Z",
            konum: "Sosyal tesis",
            foto_url: null,
            olusturan_ad: null,
            katiliyorum_sayisi: 12,
            katilmiyorum_sayisi: 3,
            ...over,
          },
        ],
      },
    });
  }

  it("KATILIM SAYILARI GORUNUR (sema: sayilar herkese acik)", async () => {
    kur();
    ciz(EtkinliklerPage);
    expect(await screen.findByText(/12 katılıyor/)).toBeInTheDocument();
    expect(screen.getByText(/3 katılmıyor/)).toBeInTheDocument();
  });

  it("KATILIM BEYANI DUGMESI YOK — bu ekran SALT OKUR", async () => {
    // Sayilar okunur, beyan YAZMA akisidir ve bu ekranda yok. Basilinca
    // hicbir sey yapmayan bir dugme cizmek kullaniciyi aldatirdi.
    kur();
    ciz(EtkinliklerPage);
    await screen.findByText(/12 katılıyor/);
    expect(screen.queryByRole("button", { name: /Katıl/i })).toBeNull();
  });
});

describe("(P244 §8d) kurallar — P190 §3 gorseli nihayet gorunur", () => {
  it("KURAL GORSELI CIZILIR", async () => {
    fetchSahtele({
      "/api/site-rules": {
        items: [
          {
            id: "k1",
            baslik: "Otopark planı",
            icerik: "Araçlar numaralı yerlere park edilir.",
            foto_url: KURAL_FOTO,
            sira: 1,
          },
        ],
      },
    });
    ciz(KurallarPage);
    const gorsel = await screen.findByRole("img", { name: /Otopark planı/ });
    expect(gorsel.getAttribute("src")).toBe(KURAL_FOTO);
  });

  it("SIRA YAPISI KORUNDU — kurallar hala `<ol>` icinde", async () => {
    // Kurallar numaralandirilmis bir metindir; ekran okuyucu sira
    // bilgisini ancak listeden alir. Kart yuzeyi eklenirken bu
    // kaybedilebilirdi.
    fetchSahtele({
      "/api/site-rules": {
        items: [{ id: "k1", baslik: "Otopark planı", icerik: "Metin", foto_url: null, sira: 1 }],
      },
    });
    ciz(KurallarPage);
    const baslik = await screen.findByText("Otopark planı");
    expect(baslik.closest("ol"), "kurallar sirali listede degil").not.toBeNull();
  });
});

describe("(P244 §8d) yonetim iletisim — kullanilmayan avatar", () => {
  it("AVATAR CIZILIR (uc onu ZATEN donduruyordu)", async () => {
    fetchSahtele({
      "/api/yonetici-iletisim": {
        yonetim_email: null,
        yoneticiler: [
          {
            user_id: "u1",
            ad_soyad: "Ayşe Yönetici",
            telefon: "+905321112233",
            avatar_url: AVATAR,
          },
        ],
      },
    });
    ciz(YonetimIletisimPage);
    await screen.findByText("Ayşe Yönetici");
    const gorsel = screen.getByRole("img", { name: /Ayşe Yönetici/ });
    expect(gorsel.getAttribute("src")).toBe(AVATAR);
  });
});
