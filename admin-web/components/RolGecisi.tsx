"use client";

// (P247 §2) PROFILDEN ROL GECISI — YONETICI <-> SAKIN (web cizimi + eylem).
//
// =========================================================================
// GECIS NEDEN TAM SAYFA YUKLEMESIYLE BITER
// =========================================================================
// Istek "iki ayri hesaba gecmek gibi hissettirmeli; ekranda karisik bir
// durum HICBIR AN olusmamali" diyor. SWR onbellegi, Next'in istemci
// yonlendirici onbellegi ve kabugun sunucuda cozulmus rolu ESKI moda
// aittir; yumusak bir `router.replace`, yeni modda eski menuyu ya da eski
// listeyi bir kare de olsa gosterirdi. `location.replace` hepsini atar ve
// kabuk yeni jetonla SUNUCUDA yeniden cizilir (tesis degistirmenin P203
// karari da ayni). Istek surerken ekrani TAM ORTEN bir perde gosterilir:
// eski modun ekrani tiklanabilir kalmaz.
//
// Kok (`/`) hedeflenir: middleware yeni role gore dogru baslangici secer
// (sakin -> Aidatim, yonetici -> Ozet). Bildirimden gelen gecis ise
// dogrudan HEDEF ekrana gider.

import { useEffect, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import {
  ROL_GECIS_BILGI_ANAHTARI,
  gecisMenusuVar,
  type RolDurumu,
  type SunucuRolu,
} from "@/lib/rol-gecisi";
import { ROL_DURUMU_UC } from "@/lib/rol-kullan";

/** `GET /me` — aktif rol + roller. Kabuk boyunca TEK istek (SWR). */
export function useRolDurumu() {
  return useSWR<RolDurumu>(ROL_DURUMU_UC, jsonFetcher);
}

/** Gecis eylemi. `gecilen` doluyken perde cizilir. */
export function useRolGecisi() {
  const t = useT();
  const [gecilen, setGecilen] = useState<SunucuRolu | null>(null);
  const [hata, setHata] = useState<string | null>(null);

  async function gec(rol: SunucuRolu, hedef = "/"): Promise<void> {
    setGecilen(rol);
    setHata(null);
    try {
      const r = await fetch("/api/me/rol-gecis", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ rol }),
      });
      if (!r.ok) {
        const d = (await r.json().catch(() => null)) as
          | { error?: { message?: string } }
          | null;
        setHata(d?.error?.message ?? t("rolGecisHata"));
        setGecilen(null);
        return;
      }
      try {
        sessionStorage.setItem(ROL_GECIS_BILGI_ANAHTARI, rol);
      } catch {
        // Depo kapaliysa yalniz bilgi mesaji kaybolur; gecis surer.
      }
      // PERDE ACIK KALIR: sayfa bosaltilana kadar eski mod gorunmez.
      window.location.replace(hedef);
    } catch {
      setHata(t("ortakSunucuyaUlasilamadi"));
      setGecilen(null);
    }
  }

  return { gec, gecilen, hata };
}

/** Gecis surerken ekrani TAM orten perde. */
export function RolGecisPerdesi({ rol }: { rol: SunucuRolu }) {
  const t = useT();
  return (
    <div
      data-test="rol-gecis-perdesi"
      role="status"
      aria-live="assertive"
      className="fixed inset-0 flex flex-col items-center justify-center gap-4 px-4"
      style={{
        zIndex: 9999,
        background: "var(--yz-bg-app)",
        color: "var(--yz-text)",
      }}
    >
      <span
        aria-hidden="true"
        className="h-8 w-8 animate-spin rounded-full border-2"
        style={{
          borderColor: "var(--yz-border)",
          borderTopColor: "var(--yz-accent)",
        }}
      />
      <p style={{ fontSize: "var(--yz-fs-body)" }}>
        {rol === "resident" ? t("rolGecisSuruyorSakin") : t("rolGecisSuruyorYonetici")}
      </p>
    </div>
  );
}

/**
 * Kullanici menusundeki iki secenek. YALNIZ iki rolu olan kisi gorur
 * (`roller.length == 2`); tek rollu yoneticide ve guvenlikte HIC cizilmez.
 */
export function RolSecimi() {
  const t = useT();
  const { data } = useRolDurumu();
  const { gec, gecilen, hata } = useRolGecisi();
  if (!gecisMenusuVar(data)) return null;
  const aktif = data?.role ?? null;
  const secenekler: { rol: SunucuRolu; etiket: string }[] = [
    { rol: "yonetici", etiket: t("rolGecisYonetici") },
    { rol: "resident", etiket: t("rolGecisSakin") },
  ];
  return (
    <div
      role="group"
      aria-label={t("rolGecisBaslik")}
      data-test="rol-gecis"
      className="border-b py-1"
      style={{ borderColor: "var(--yz-border)" }}
    >
      <p
        className="px-3 pb-1 pt-1"
        style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
      >
        {t("rolGecisBaslik")}
      </p>
      {secenekler.map((s) => {
        const secili = s.rol === aktif;
        return (
          <button
            key={s.rol}
            type="button"
            role="menuitemradio"
            aria-checked={secili}
            data-test={`rol-gecis-${s.rol}`}
            disabled={secili || gecilen !== null}
            // MENU KAPATILMAZ: bu bilesen menunun icinde yasar ve kapanirsa
            // perde de (ve bekleyen istegin durumu da) onunla gider.
            onClick={() => void gec(s.rol)}
            className="odak-ic flex w-full items-center justify-between px-3 py-2 text-start transition-colors enabled:hover:bg-[var(--yz-metal-2)]"
            style={{
              fontSize: "var(--yz-fs-sm)",
              color: secili ? "var(--yz-text)" : "var(--yz-text-2)",
              fontWeight: secili ? 600 : 400,
            }}
          >
            <span>{s.etiket}</span>
            {secili ? (
              <svg
                viewBox="0 0 24 24"
                className="h-4 w-4"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.5"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <polyline points="20 6 9 17 4 12" />
              </svg>
            ) : null}
          </button>
        );
      })}
      {hata ? (
        <p role="alert" className="px-3 py-1 text-xs" style={{ color: "var(--yz-danger-ink)" }}>
          {hata}
        </p>
      ) : null}
      {gecilen ? <RolGecisPerdesi rol={gecilen} /> : null}
    </div>
  );
}

/**
 * Gecisten sonraki ILK yuklemede "Sakin moduna gecildi" bilgisi. Kabukta
 * TEK KEZ cizilir; bilgi oturum deposundan okunur ve hemen silinir.
 */
export function RolGecisBildirimi() {
  const t = useT();
  const toast = useToast();
  useEffect(() => {
    let rol: string | null = null;
    try {
      rol = sessionStorage.getItem(ROL_GECIS_BILGI_ANAHTARI);
      if (rol) sessionStorage.removeItem(ROL_GECIS_BILGI_ANAHTARI);
    } catch {
      rol = null;
    }
    if (rol === "resident") toast.info(t("rolGecildiSakin"));
    else if (rol === "yonetici") toast.info(t("rolGecildiYonetici"));
    // Yalniz ilk cizimde: bilgi bir kez gosterilir.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return null;
}
