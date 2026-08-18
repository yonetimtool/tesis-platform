"use client";

/**
 * (P160 / Asama 3) SEKMELER · IPUCU · CEKMECE.
 *
 * Uc kucuk bilesen tek dosyada: ucu de "bir seyi ac/kapa" ailesinden ve
 * ayri dosyalara bolmek dort satirlik uc modul uretirdi.
 *
 * =========================================================================
 * SEKMELER — WAI-ARIA klavye deseni
 * =========================================================================
 * Sekme seridi TEK bir sekme durakli (`tabIndex`) olmali: Tab tusu
 * seride girer, ok tuslari sekmeler arasinda gezer. Her sekmeyi
 * odaklanabilir birakmak, on sekmeli bir sayfada klavye kullanicisini on
 * kez Tab'a bastirirdi.
 */
import {
  useEffect,
  useId,
  useRef,
  useState,
  type ReactNode,
} from "react";

import { useT } from "@/lib/i18n/kullan";
import { useKaydirmaKilidi } from "@/lib/kaydirma-kilidi";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const SEFFAF = "transparent";
const GOLGESIZ = "none";

/* ======================================================================
   SEKMELER
   ====================================================================== */

export interface Sekme {
  id: string;
  baslik: string;
  /** Sag ust kose sayaci (orn. acik talep sayisi). */
  rozet?: number;
  icerik: ReactNode;
}

export function Sekmeler({
  sekmeler,
  aktifId,
  onDegis,
}: {
  sekmeler: Sekme[];
  /** Denetimli kullanim; verilmezse bilesen kendi tutar. */
  aktifId?: string;
  onDegis?: (id: string) => void;
}) {
  const [icAktif, setIcAktif] = useState(sekmeler[0]?.id ?? "");
  const aktif = aktifId ?? icAktif;
  const temelId = useId();
  const seritRef = useRef<HTMLDivElement | null>(null);

  function sec(id: string) {
    if (onDegis) onDegis(id);
    if (!aktifId) setIcAktif(id);
  }

  function tus(e: React.KeyboardEvent) {
    const i = sekmeler.findIndex((s) => s.id === aktif);
    if (i < 0) return;
    let hedef = i;
    if (e.key === "ArrowRight") hedef = (i + 1) % sekmeler.length;
    else if (e.key === "ArrowLeft") hedef = (i - 1 + sekmeler.length) % sekmeler.length;
    else if (e.key === "Home") hedef = 0;
    else if (e.key === "End") hedef = sekmeler.length - 1;
    else return;
    e.preventDefault();
    sec(sekmeler[hedef].id);
    // Odak da tasinir: ARIA deseninde ok tusu SECER ve ODAKLAR.
    seritRef.current
      ?.querySelectorAll<HTMLElement>('[role="tab"]')
      ?.[hedef]?.focus();
  }

  const aktifSekme = sekmeler.find((s) => s.id === aktif);

  return (
    <div>
      <div
        ref={seritRef}
        role="tablist"
        onKeyDown={tus}
        className="flex gap-1 overflow-x-auto border-b"
        style={{
          borderColor: "var(--yz-border)",
          borderBottomWidth: "var(--yz-border-w)",
        }}
      >
        {sekmeler.map((s) => {
          const bu = s.id === aktif;
          return (
            <button
              key={s.id}
              type="button"
              role="tab"
              id={`${temelId}-t-${s.id}`}
              aria-selected={bu}
              aria-controls={`${temelId}-p-${s.id}`}
              // SERITTE TEK DURAK: yalniz aktif sekme Tab ile bulunur.
              tabIndex={bu ? 0 : -1}
              onClick={() => sec(s.id)}
              className="odak-ic flex shrink-0 items-center gap-2 px-3 py-2"
              style={{
                fontSize: "var(--yz-fs-body)",
                color: bu ? "var(--yz-text)" : "var(--yz-text-2)",
                background: bu ? "var(--yz-metal-2)" : SEFFAF,
                borderTopLeftRadius: "var(--yz-radius-btn)",
                borderTopRightRadius: "var(--yz-radius-btn)",
                boxShadow: bu ? "var(--yz-raised)" : GOLGESIZ,
              }}
            >
              {s.baslik}
              {typeof s.rozet === "number" && s.rozet > 0 && (
                <span
                  aria-hidden="true"
                  className="px-1.5"
                  style={{
                    borderRadius: "var(--yz-radius-chip)",
                    background: "var(--yz-surface-sunken)",
                    color: "var(--yz-text-2)",
                    fontSize: "var(--yz-fs-xs)",
                  }}
                >
                  {s.rozet}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {aktifSekme && (
        <div
          role="tabpanel"
          id={`${temelId}-p-${aktifSekme.id}`}
          aria-labelledby={`${temelId}-t-${aktifSekme.id}`}
          tabIndex={0}
          className="odak-ic pt-4"
        >
          {aktifSekme.icerik}
        </div>
      )}
    </div>
  );
}

/* ======================================================================
   IPUCU
   ======================================================================
   `title` ozniteligi YETMEZ: dokunmatik cihazda hic gorunmez, klavye
   odaginda cogu tarayicida cikmaz ve gecikmesi ayarlanamaz. Bu yuzden
   elle ciziliyor — ama `aria-describedby` ile baglanip ekran okuyucuya
   da veriliyor.

   IPUCU TEK BILGI KAYNAGI OLMAMALI: icinde yalniz orada bulunan bir
   bilgi varsa, dokunmatik kullanici onu HIC goremez. Bilesen bunu
   zorlayamaz; kural burada yazili.
   ====================================================================== */

export function Ipucu({
  metin,
  children,
}: {
  metin: string;
  children: ReactNode;
}) {
  const [acik, setAcik] = useState(false);
  const id = useId();
  return (
    <span
      className="relative inline-flex"
      onMouseEnter={() => setAcik(true)}
      onMouseLeave={() => setAcik(false)}
      // KLAVYE: odak alinca da cikar, ESC ile kapanir.
      onFocus={() => setAcik(true)}
      onBlur={() => setAcik(false)}
      onKeyDown={(e) => e.key === "Escape" && setAcik(false)}
      // (P169 §5) DOKUNMAYLA DA ACILIR. Dokunmatikte hover YOKTUR ve
      // ipucunun icerigi odaklanamayan bir isarete (ornegin bir simge)
      // asilmissa, telefondan HIC gorulemiyordu. `onClick` her iki
      // isaretcide de calisir; farede zaten acik oldugu icin davranis
      // DEGISMEZ.
      onClick={() => setAcik((x) => !x)}
    >
      <span aria-describedby={acik ? id : undefined}>{children}</span>
      {acik && (
        <span
          id={id}
          role="tooltip"
          className="pointer-events-none absolute bottom-full start-1/2 z-50 mb-1 -translate-x-1/2 whitespace-nowrap px-2 py-1 rtl:translate-x-1/2"
          style={{
            borderRadius: "var(--yz-radius-btn)",
            background: "var(--yz-surface-sunken)",
            borderWidth: "var(--yz-border-w)",
            borderStyle: "solid",
            borderColor: "var(--yz-border)",
            boxShadow: "var(--yz-raised)",
            color: "var(--yz-text)",
            fontSize: "var(--yz-fs-xs)",
          }}
        >
          {metin}
        </span>
      )}
    </span>
  );
}

/* ======================================================================
   CEKMECE
   ======================================================================
   Yandan acilan panel — uzun formlar ve detay gorunumleri icin. Modal
   ile AYNI erisilebilirlik sozlesmesi (odak tuzagi, ESC, kapanista
   odagin geri donmesi); fark yalnizca konum ve giris yonu.
   ====================================================================== */

const ODAKLANABILIR =
  'a[href],button:not([disabled]),textarea:not([disabled]),input:not([disabled]),select:not([disabled]),[tabindex]:not([tabindex="-1"])';

export function Cekmece({
  acik,
  onKapat,
  baslik,
  children,
  eylemler,
}: {
  acik: boolean;
  onKapat: () => void;
  baslik: string;
  children: ReactNode;
  eylemler?: ReactNode;
}) {
  const t = useT();
  const kutuRef = useRef<HTMLDivElement | null>(null);
  const acanRef = useRef<HTMLElement | null>(null);
  const baslikId = useId();

  useEffect(() => {
    if (!acik) return;
    acanRef.current = document.activeElement as HTMLElement | null;
    const ilk = kutuRef.current?.querySelector<HTMLElement>(ODAKLANABILIR);
    (ilk ?? kutuRef.current)?.focus();
    return () => {
      acanRef.current?.focus?.();
    };
  }, [acik]);

  useEffect(() => {
    if (!acik) return;
    function tus(e: KeyboardEvent) {
      if (e.key === "Escape") {
        e.stopPropagation();
        onKapat();
        return;
      }
      if (e.key !== "Tab") return;
      // GORUNURLUK SUZGECINDE GERI CEKILME: `offsetParent` yerlesim
      // gerektirir ve yerlesimi olmayan ortamlarda HER SEY icin `null`
      // doner — suzgeci oldugu gibi uygulamak tuzagi BOS birakirdi.
      // Hicbir sey gorunmuyorsa hepsi tuzaklanir: fazladan tuzaklamak,
      // hic tuzaklamamaktan iyidir.
      const hepsi = [
        ...(kutuRef.current?.querySelectorAll<HTMLElement>(ODAKLANABILIR) ?? []),
      ];
      const gorunur = hepsi.filter((o) => o.offsetParent !== null);
      const ogeler = gorunur.length > 0 ? gorunur : hepsi;
      if (ogeler.length === 0) return;
      const ilk = ogeler[0];
      const son = ogeler[ogeler.length - 1];
      if (e.shiftKey && document.activeElement === ilk) {
        e.preventDefault();
        son.focus();
      } else if (!e.shiftKey && document.activeElement === son) {
        e.preventDefault();
        ilk.focus();
      }
    }
    document.addEventListener("keydown", tus, true);
    return () => document.removeEventListener("keydown", tus, true);
  }, [acik, onKapat]);

  // (P169) ARKA PLAN KAYDIRMA KILIDI — burada HIC YOKTU. Yan panel
  // aciken telefonda parmak arkadaki sayfayi kaydiriyor, panel kapaninca
  // kullanici bambaska bir yerde buluyordu kendini.
  useKaydirmaKilidi(acik);

  if (!acik) return null;

  return (
    <div
      className="fixed inset-0"
      style={{ zIndex: "var(--yz-z-drawer)" as unknown as number }}
    >
      <div
        aria-hidden="true"
        onClick={onKapat}
        className="absolute inset-0"
        style={{ background: "rgba(0,0,0,.5)" }}
      />
      <div
        ref={kutuRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={baslikId}
        tabIndex={-1}
        className="absolute inset-y-0 end-0 flex w-full max-w-md flex-col"
        style={{
          background: "var(--yz-metal-1)",
          borderInlineStartWidth: "var(--yz-border-w)",
          borderInlineStartStyle: "solid",
          borderColor: "var(--yz-border)",
          boxShadow: "var(--yz-raised-hover)",
          color: "var(--yz-text)",
        }}
      >
        <div
          className="flex shrink-0 items-center justify-between gap-4 border-b p-4"
          style={{
            borderColor: "var(--yz-border)",
            borderBottomWidth: "var(--yz-border-w)",
          }}
        >
          <h2 id={baslikId} style={{ fontSize: "var(--yz-fs-h2)" }}>
            {baslik}
          </h2>
          <button
            type="button"
            onClick={onKapat}
            aria-label={t("ortakKapat")}
            className="odak-ic yz-dokunma-44 flex h-8 w-8 items-center justify-center rounded-lg"
            style={{ color: "var(--yz-text-2)" }}
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <path d="M6 6l12 12M18 6L6 18" />
            </svg>
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto p-4">{children}</div>
        {eylemler && (
          <div
            className="flex shrink-0 items-center justify-end gap-2 border-t p-4"
            style={{
              borderColor: "var(--yz-border)",
              borderTopWidth: "var(--yz-border-w)",
            }}
          >
            {eylemler}
          </div>
        )}
      </div>
    </div>
  );
}
