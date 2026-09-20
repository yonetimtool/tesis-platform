"use client";

// (P244 §2) KENAR CUBUGU DIBINDEKI SITE KARTI.
//
// ===========================================================================
// NEDEN VAR
// ===========================================================================
// Referansta (`ui5.png`) kenar cubugunun dibinde bir site karti duruyor:
// bina kucuk gorseli + site adi + rol + `›`. Iki soruyu birden yanitliyor:
// "hangi sitedeyim" ve "baskasina nasil gecerim".
//
// Bizde bugune kadar yaniti YALNIZ sag ust hesap menusunun icindeydi —
// yani kullanicinin menuyu ACMASI gerekiyordu. Birden cok tesise giren bir
// yonetici icin (P155) bu, en sik sorulan soruyu en derine gommekti.
//
// ===========================================================================
// TEK KAYNAK: SECICI HESAP MENUSUNDEN KALDIRILDI
// ===========================================================================
// Iki yerde birden durmasi "hangisi gecerli?" sorusunu ureten bir tekrardir
// — dil secici P140.4'te tam bu gerekceyle tek yere indirilmisti. Gecis
// MANTIGI (`useTesisGecis`) paylasilan bir kancada; burada yalniz cizim var.
//
// ===========================================================================
// TEK TESISLIDE DE CIZILIR — AMA DUGME DEGIL
// ===========================================================================
// "Hangi sitedeyim" sorusu tek tesisli kullanici icin de gecerli; kart
// bilgi olarak kalir. Tiklanabilir GORUNMEZ: olmayan bir karari sunan bir
// dugme, basildiginda hicbir sey yapmayan bir dugmedir.

import { useEffect, useRef, useState } from "react";
import useSWR from "swr";

import { useT } from "@/lib/i18n/kullan";
import { jsonFetcher } from "@/lib/fetcher";
import { rolAdi } from "@/lib/roles";
import { useTesisGecis, type TesisUyeligi } from "@/lib/tesis-gecis";

type Kimlik = { tenant_id?: string; role?: string };
type TesisAyari = { ad: string };

function BinaIkonu() {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-5 w-5"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M4 20V6a1 1 0 0 1 1-1h7a1 1 0 0 1 1 1v14" />
      <path d="M13 20V10h6a1 1 0 0 1 1 1v9" />
      <path d="M7 9h2M7 13h2M16 14h1" />
      <path d="M3 20h18" />
    </svg>
  );
}

function Chevron() {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-4 w-4 shrink-0"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="m9 18 6-6-6-6" />
    </svg>
  );
}

export function TesisKarti({ dar = false }: { dar?: boolean }) {
  const t = useT();
  const [acik, setAcik] = useState(false);
  const kutu = useRef<HTMLDivElement>(null);
  const { data: kimlik } = useSWR<Kimlik>("/api/me", jsonFetcher);
  const { data: tesis } = useSWR<TesisAyari>("/api/tenant/settings", jsonFetcher);
  const { data: uyelikler } = useSWR<{ tesisler: TesisUyeligi[] }>(
    "/api/me/tesislerim",
    jsonFetcher,
  );
  const { gec, bekliyor, hata } = useTesisGecis();

  useEffect(() => {
    if (!acik) return;
    function disari(e: MouseEvent) {
      if (!kutu.current?.contains(e.target as Node)) setAcik(false);
    }
    function esc(e: KeyboardEvent) {
      if (e.key === "Escape") setAcik(false);
    }
    document.addEventListener("mousedown", disari);
    document.addEventListener("keydown", esc);
    return () => {
      document.removeEventListener("mousedown", disari);
      document.removeEventListener("keydown", esc);
    };
  }, [acik]);

  const liste = uyelikler?.tesisler ?? [];
  const coklu = liste.length > 1;
  // TESIS ADI GELMEDEN YER TUTUCU CIZILMEZ: bos bir kart, yuklenirken
  // "site yok" gibi okunurdu. Ad gelene kadar kart hic cizilmez.
  if (!tesis?.ad) return null;

  const rol = kimlik?.role ? rolAdi(t, kimlik.role) : null;

  // DAR MODDA yalniz ikon: 68 px'lik seritte site adi sigmaz. Erisilebilir
  // ad `aria-label` ile KALIR.
  const govde = dar ? (
    <span style={{ color: "var(--yz-sidebar-text-2)" }}>
      <BinaIkonu />
    </span>
  ) : (
    <>
      <span
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg"
        style={{
          background: "var(--yz-sidebar-hover)",
          color: "var(--yz-sidebar-text)",
        }}
      >
        <BinaIkonu />
      </span>
      <span className="min-w-0 flex-1 text-start">
        <span
          className="block truncate"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-sidebar-text)" }}
        >
          {tesis.ad}
        </span>
        {rol ? (
          <span
            className="block truncate"
            style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-sidebar-label)" }}
          >
            {rol}
          </span>
        ) : null}
      </span>
      {coklu ? (
        <span style={{ color: "var(--yz-sidebar-label)" }}>
          <Chevron />
        </span>
      ) : null}
    </>
  );

  const ortakSinif = `flex w-full items-center gap-3 rounded-lg ${
    dar ? "justify-center px-2 py-2" : "px-2 py-2"
  }`;

  if (!coklu) {
    return (
      <div
        className={ortakSinif}
        data-test="tesis-karti"
        aria-label={t("tesisKartiAd", { ad: tesis.ad })}
      >
        {govde}
      </div>
    );
  }

  return (
    <div className="relative" ref={kutu}>
      <button
        type="button"
        onClick={() => setAcik((a) => !a)}
        aria-expanded={acik}
        aria-haspopup="menu"
        data-test="tesis-karti"
        aria-label={t("tesisKartiDegistir", { ad: tesis.ad })}
        className={`odak-ic transition-colors hover:bg-[var(--yz-sidebar-hover)] ${ortakSinif}`}
      >
        {govde}
      </button>
      {acik ? (
        <div
          role="menu"
          data-test="tesis-secici"
          // YUKARI ACILIR: kart zaten kenar cubugunun DIBINDE; asagi acilan
          // bir menu ekranin disina tasardi.
          className="absolute bottom-full start-0 mb-2 w-64 overflow-hidden p-1"
          style={{
            zIndex: "var(--yz-z-dropdown)" as unknown as number,
            background: "var(--yz-surface-1)",
            border: "var(--yz-border-w) solid var(--yz-border)",
            borderRadius: "var(--yz-radius-card)",
            boxShadow: "var(--yz-raised-hover)",
          }}
        >
          <p
            className="px-2 pb-1 pt-1"
            style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
          >
            {t("tesisDegistirBaslik")}
          </p>
          {liste.map((u) => {
            const secili = u.tenant_id === kimlik?.tenant_id;
            return (
              <button
                key={u.tenant_id}
                type="button"
                role="menuitem"
                disabled={secili || bekliyor}
                onClick={() => void gec(u.tenant_id)}
                data-test={`tesis-sec-${u.tenant_id}`}
                className="odak-ic flex w-full items-center justify-between gap-2 rounded px-2 py-1.5 text-start transition-colors hover:bg-[var(--yz-surface-2)] disabled:opacity-100"
                style={{
                  fontSize: "var(--yz-fs-sm)",
                  color: "var(--yz-text)",
                  background: secili ? "var(--yz-surface-2)" : undefined,
                }}
              >
                <span className="min-w-0 truncate">{u.ad}</span>
                {/* ROL HER TESISTE FARKLI OLABILIR: kullanici birinde
                    yonetici, otekinde sakin olabilir — hangi yetkiyle
                    girecegini SECMEDEN ONCE bilmeli. */}
                <span
                  className="shrink-0"
                  style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                >
                  {secili ? t("tesisDegistirSecili") : rolAdi(t, u.rol)}
                </span>
              </button>
            );
          })}
          {hata ? (
            <p
              role="alert"
              className="px-2 pt-1"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-danger-ink)" }}
            >
              {hata}
            </p>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
