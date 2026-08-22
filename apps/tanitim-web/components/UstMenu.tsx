"use client";

import Link from "next/link";
import { useState } from "react";

import { Logo } from "./Logo";

/**
 * (P177 §2) YAPISKAN UST MENU — capa bagli tek sayfa duzeni.
 *
 * BAGLANTILAR MUTLAK KOK YOLUYLA (`/#yetenekler`), yalniz `#yetenekler`
 * DEGIL: menu `/yonetici` ve `/site-sakini` sayfalarinda da cizilir ve
 * orada cipla bir capa, o sayfada var olmayan bir bolumu arardi.
 *
 * TEK BIRINCIL EYLEM: "Kayıt Ol". Sartname "tekrar eden tek birincil
 * CTA" istiyor; menude ikinci bir dolu dugme (orn. "Giris Yap") koymak
 * o kurali ilk ekranda bozardi. Giris, altbilgide ve kayit sayfasinin
 * altinda metin bagi olarak duruyor.
 *
 * MOBIL MENU JS ILE ACILIR ve bu bilincli bir istisna: `<details>` ile
 * JS'siz de yapilabilirdi ama yapiskan bir seritte `<details>` acilinca
 * akisi itiyor ve capa kaydirmasi bozuluyor. Durum tek bir `useState`;
 * baska istemci mantigi yok.
 */
const BAGLANTILAR = [
  { yol: "/#ne-ise-yarar", ad: "Ne işe yarar" },
  { yol: "/#yetenekler", ad: "Yetenekler" },
  { yol: "/#nasil-calisir", ad: "Nasıl çalışır" },
  { yol: "/#sorular", ad: "Sık sorulanlar" },
  { yol: "/#uygulama", ad: "Uygulama" },
  { yol: "/#iletisim", ad: "İletişim" },
];

export function UstMenu() {
  const [acik, setAcik] = useState(false);

  return (
    <header className="sticky top-0 z-50 border-b border-cizgi bg-zemin/90 backdrop-blur">
      <div className="kapsayici flex h-[4.5rem] items-center justify-between gap-4">
        <Logo />

        <nav aria-label="Ana menü" className="hidden lg:block">
          <ul className="flex items-center gap-7">
            {BAGLANTILAR.map((b) => (
              <li key={b.yol}>
                <Link
                  href={b.yol}
                  className="text-kucuk font-semibold text-govde hover:text-mavi"
                >
                  {b.ad}
                </Link>
              </li>
            ))}
          </ul>
        </nav>

        <div className="flex items-center gap-2">
          <Link href="/yonetici/kayit" className="dugme-birincil hidden px-5 py-2.5 sm:inline-flex">
            Kayıt Ol
          </Link>
          <button
            type="button"
            onClick={() => setAcik((o) => !o)}
            aria-expanded={acik}
            aria-controls="mobil-menu"
            className="rounded-[10px] border border-cizgiDenetim p-2.5 text-lacivert lg:hidden"
          >
            <span className="gizli-erisilebilir">Menüyü {acik ? "kapat" : "aç"}</span>
            <svg viewBox="0 0 24 24" aria-hidden="true" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
              {acik ? (
                <>
                  <path d="M6 6l12 12" />
                  <path d="M18 6L6 18" />
                </>
              ) : (
                <>
                  <path d="M4 7h16" />
                  <path d="M4 12h16" />
                  <path d="M4 17h16" />
                </>
              )}
            </svg>
          </button>
        </div>
      </div>

      {acik ? (
        <nav id="mobil-menu" aria-label="Ana menü (mobil)" className="border-t border-cizgi bg-zemin lg:hidden">
          <ul className="kapsayici flex flex-col py-2">
            {BAGLANTILAR.map((b) => (
              <li key={b.yol}>
                <Link
                  href={b.yol}
                  onClick={() => setAcik(false)}
                  className="block border-b border-cizgi py-3 font-semibold text-govde"
                >
                  {b.ad}
                </Link>
              </li>
            ))}
            <li className="pt-4">
              <Link href="/yonetici/kayit" onClick={() => setAcik(false)} className="dugme-birincil w-full">
                Kayıt Ol
              </Link>
            </li>
          </ul>
        </nav>
      ) : null}
    </header>
  );
}
