"use client";

// (P168 §4.1/§4.2) ETIKET CIPLERI — imlecin oldugu yere ekler.
//
// =========================================================================
// NEDEN CIP, NEDEN "ipucu metni" DEGIL
// =========================================================================
// Onceki hâl govdenin altinda tek satirlik bir ipucuydu. Kullanicinin
// etiketi DOGRU YAZMASI gerekiyordu ve tek harf hatasi (`{bakiyee}`)
// mesajda oldugu gibi gorunuyordu — sunucu bilmedigi etiketi BILEREK
// koruyor, cunku bos birakmak hatayi gizlerdi.
//
// Cip, yazim hatasi ihtimalini SIFIRA indirir.
//
// =========================================================================
// LISTE SUNUCUNUN `ETIKETLER` KUMESIYLE AYNI OLMALI
// =========================================================================
// Burada olup sunucuda olmayan bir etiket, mesajda HAM kalirdi.
// `tests/mesaj-etiket.test.ts` bu esitligi backend kaynagindan okuyarak
// kilitler.

import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

export interface EtiketTanimi {
  /** Sunucudaki `ETIKETLER` kumesindeki ad — sussuz. */
  ad: string;
  etiket: SozlukAnahtari;
}

export const ETIKETLER: EtiketTanimi[] = [
  { ad: "bakiye", etiket: "mesajEtiketBakiye" },
  { ad: "borc", etiket: "mesajEtiketBorc" },
  { ad: "adi_soyadi", etiket: "mesajEtiketAdSoyad" },
  { ad: "adres", etiket: "mesajEtiketAdres" },
  { ad: "tarih", etiket: "mesajEtiketTarih" },
  { ad: "odeme_linki", etiket: "mesajEtiketOdemeLinki" },
  { ad: "site_adi", etiket: "mesajEtiketSiteAdi" },
  { ad: "aidat_tutari", etiket: "mesajEtiketAidat" },
  { ad: "kiraci_bakiyesi", etiket: "mesajEtiketKiraciBakiye" },
  { ad: "bakiye_detayli", etiket: "mesajEtiketBakiyeDetay" },
];

export function EtiketCipleri({ onEkle }: { onEkle: (metin: string) => void }) {
  const t = useT();
  return (
    <div className="flex flex-wrap gap-1">
      {ETIKETLER.map((e) => (
        <button
          key={e.ad}
          type="button"
          // `onMouseDown` + `preventDefault`: tiklama odagi cipe tasirsa
          // metin kutusundaki IMLEC KONUMU kaybolur ve etiket sona
          // eklenir — kullanicinin istedigi yere degil.
          onMouseDown={(evt) => evt.preventDefault()}
          onClick={() => onEkle(`{${e.ad}}`)}
          className="odak-ic yz-lift px-2 py-1"
          style={{
            borderRadius: "var(--yz-radius-btn)",
            border: "var(--yz-border-w) solid var(--yz-border)",
            background: "var(--yz-metal-1)",
            fontSize: "var(--yz-fs-xs)",
            color: "var(--yz-text)",
          }}
        >
          {t(e.etiket)}
        </button>
      ))}
    </div>
  );
}
