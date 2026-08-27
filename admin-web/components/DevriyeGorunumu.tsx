"use client";

import Link from "next/link";

import { Rozet } from "@/components/ui";
import { formatDateTime } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { AktifTur } from "@/lib/types";

// (P181 7.3) Devriye turu GÖRSEL bileşeni. Önce düz cümleydi ("X / Y checkpoint").
// Artık: ilerleme halkası (yüzde METİN olarak da var — renk-yalnız değil),
// tamamlanan/kalan nokta sayısı ve SON OKUTMA zamanı. Halka rengi bir durum
// sinyalidir; bilgi ayrıca sayı/etiketle taşınır.
export function DevriyeGorunumu({
  tur,
  suren,
}: {
  tur: AktifTur;
  suren: boolean;
}) {
  const t = useT();
  const okutulan = tur.okutulan_checkpoint_sayisi ?? 0;
  const beklenen = tur.beklenen_checkpoint_sayisi ?? 0;
  const kalan = Math.max(0, beklenen - okutulan);
  const yuzde = beklenen > 0 ? Math.round((okutulan / beklenen) * 100) : 0;

  const R = 34;
  const cevre = 2 * Math.PI * R;
  const dolu = (cevre * yuzde) / 100;

  return (
    <Link href="/patrol-plans" className="block rounded-kart">
      <div className="flex items-center gap-4 p-1">
        {/* İlerleme halkası; merkezde yüzde metni (bilgi yalnız renkte değil). */}
        <div className="relative shrink-0" style={{ width: 84, height: 84 }}>
          <svg
            width={84}
            height={84}
            viewBox="0 0 84 84"
            role="img"
            aria-label={`%${yuzde}`}
          >
            <circle
              cx="42"
              cy="42"
              r={R}
              fill="none"
              stroke="var(--yz-border)"
              strokeWidth="8"
            />
            <circle
              cx="42"
              cy="42"
              r={R}
              fill="none"
              stroke={suren ? "var(--yz-olumlu, var(--yz-accent))" : "var(--yz-accent)"}
              strokeWidth="8"
              strokeLinecap="round"
              strokeDasharray={`${dolu} ${cevre - dolu}`}
              transform="rotate(-90 42 42)"
            />
          </svg>
          <div className="absolute inset-0 flex items-center justify-center">
            <span
              style={{
                fontSize: "var(--yz-fs-h3)",
                color: "var(--yz-text)",
                fontWeight: 600,
              }}
            >
              %{yuzde}
            </span>
          </div>
        </div>

        <div className="min-w-0 flex-1 space-y-1.5">
          <div className="flex items-center gap-2">
            <Rozet durum={suren ? "olumlu" : "bilgi"} nokta>
              {suren ? t("pano2HeroUst") : t("pano2HeroSiradakiUst")}
            </Rozet>
            <span
              className="truncate"
              style={{
                fontSize: "var(--yz-fs-body)",
                color: "var(--yz-text)",
                fontWeight: 600,
              }}
            >
              {tur.patrol_plan_ad ?? "—"}
            </span>
          </div>
          <div
            className="flex flex-wrap gap-x-4 gap-y-1"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            <span>
              {t("devriyeTamamlanan")}:{" "}
              <b style={{ color: "var(--yz-text)" }}>
                {okutulan}/{beklenen}
              </b>
            </span>
            <span>
              {t("devriyeKalan")}:{" "}
              <b style={{ color: "var(--yz-text)" }}>{kalan}</b>
            </span>
          </div>
          <div style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}>
            {t("devriyeSonOkutma")}:{" "}
            {tur.son_okutma
              ? formatDateTime(tur.son_okutma)
              : t("devriyeOkutmaYok")}
          </div>
        </div>
      </div>
    </Link>
  );
}
