"use client";

// (P244 §3) DETAY CEKMECESI — sagdan acilan yan panel.
//
// ===========================================================================
// OLCULEN BOSLUK
// ===========================================================================
// 79 korumali sayfanin **1'inde** detay paneli var (`UnitDetail`). Referans
// ise daire, kamera, talep, demirbas, odeme ve kullanici detaylarinin
// hepsini yan panelde aciyor.
//
// Bunun "bos gorunuyor" sikayetiyle dogrudan ilgisi var: detayi olmayan bir
// tablo, satira tiklayinca YENI BIR SAYFAYA gitmek zorunda birakir;
// kullanici listedeki yerini kaybeder ve geri donunce suzgecleri yeniden
// kurar. Panel, listeyi YERINDE tutar.
//
// ===========================================================================
// NEDEN MODAL DEGIL
// ===========================================================================
// Modal "bir isi bitir, sonra devam et" der (olusturma/duzenleme). Cekmece
// "sunun ayrintisina bak, listede kal" der — arkadaki liste GORUNUR kalir
// ve kullanici bir sonraki satira gecebilir. Ikisini ayni bilesene
// sikistirmak, iki farkli niyeti tek bir davranisa indirger.
//
// ===========================================================================
// ERISILEBILIRLIK MODALLE AYNI SEVIYEDE
// ===========================================================================
// ESC, odak tuzagi, acilista ice / kapanista ACAN OGEYE odak, arka plan
// kaydirma kilidi, `role="dialog"` + `aria-modal` + `aria-labelledby`.
// Hicbiri yeniden yazilmadi: `lib/odak-tuzagi.ts` modalden CIKARILDI ve
// ikisi de onu kullaniyor (P161'de olculen jsdom tuzagi dahil).
import { MotionConfig, motion } from "framer-motion";
import { useCallback, useId, useRef, type ReactNode } from "react";

import { useT } from "@/lib/i18n/kullan";
import { useKaydirmaKilidi } from "@/lib/kaydirma-kilidi";
import { useOdakDonusu, useOdakTuzagi } from "@/lib/odak-tuzagi";

const GENISLIK = { dar: "sm:w-[22rem]", orta: "sm:w-[28rem]", genis: "sm:w-[36rem]" } as const;

export interface CekmeceProps {
  acik: boolean;
  onKapat: () => void;
  /** Baslik — `aria-labelledby` bunu gosterir; bos gecilemez. */
  baslik: string;
  /** Basligin altindaki bir satirlik baglam (daire no, plaka, durum). */
  altBaslik?: string;
  children: ReactNode;
  /** Alt cubuk: bu kayda ait eylemler (Duzenle, Sil, Is emri olustur). */
  eylemler?: ReactNode;
  genislik?: keyof typeof GENISLIK;
}

export function DetayCekmecesi({
  acik,
  onKapat,
  baslik,
  altBaslik,
  children,
  eylemler,
  genislik = "orta",
}: CekmeceProps) {
  const t = useT();
  const kutuRef = useRef<HTMLDivElement>(null);
  const govdeRef = useRef<HTMLDivElement>(null);
  const basId = useId();
  const kapat = useCallback(() => onKapat(), [onKapat]);

  useOdakDonusu(acik, kutuRef, govdeRef);
  useOdakTuzagi(acik, kutuRef, kapat);
  useKaydirmaKilidi(acik);

  if (!acik) return null;

  return (
    <MotionConfig reducedMotion="user">
      {/* ORTU: tiklayinca kapanir. Cekmecede "kirli form" uyarisi YOK ve
          bu bilincli — cekmece OKUMAK icindir; duzenleme modalde yapilir
          (bkz. sinif notu). */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        onClick={kapat}
        aria-hidden="true"
        className="fixed inset-0"
        style={{
          zIndex: "var(--yz-z-modal)" as unknown as number,
          background: "rgba(16, 24, 40, 0.35)",
        }}
      />
      <motion.div
        ref={kutuRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={basId}
        tabIndex={-1}
        initial={{ x: "100%" }}
        animate={{ x: 0 }}
        transition={{ type: "spring", stiffness: 420, damping: 40 }}
        // TAM EKRAN DAR BANTTA: 360 px'lik bir telefonda 28rem'lik bir
        // panel zaten ekranin tamami; `w-full` onu durustce soyler.
        // RTL'de SAGDAN degil SOLDAN girer: `end-0` yon farkindadir.
        className={`fixed inset-y-0 end-0 flex w-full flex-col ${GENISLIK[genislik]}`}
        style={{
          zIndex: "var(--yz-z-modal)" as unknown as number,
          background: "var(--yz-surface-1)",
          borderInlineStartWidth: "var(--yz-border-w)",
          borderInlineStartStyle: "solid",
          borderColor: "var(--yz-border)",
          boxShadow: "var(--yz-raised-hover)",
        }}
      >
        <div
          className="flex shrink-0 items-start justify-between gap-3 border-b px-5 py-4"
          style={{ borderColor: "var(--yz-border)", borderBottomWidth: "var(--yz-border-w)" }}
        >
          <div className="min-w-0">
            <h2
              id={basId}
              className="truncate"
              style={{
                fontSize: "var(--yz-fs-h3)",
                fontWeight: 600,
                color: "var(--yz-text)",
              }}
            >
              {baslik}
            </h2>
            {altBaslik ? (
              <p
                className="mt-0.5 truncate"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
              >
                {altBaslik}
              </p>
            ) : null}
          </div>
          <button
            type="button"
            onClick={kapat}
            aria-label={t("ortakKapat")}
            className="odak-ic yz-dokunma-48 -me-1 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg transition-colors hover:bg-[var(--yz-surface-2)]"
            style={{ color: "var(--yz-text-2)" }}
          >
            <svg
              viewBox="0 0 24 24"
              className="h-5 w-5"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              aria-hidden="true"
            >
              <path d="M6 6l12 12M18 6L6 18" />
            </svg>
          </button>
        </div>

        {/* GOVDE KAYDIRILIR, BASLIK VE EYLEMLER SABIT: uzun bir detayda
            kullanici "Sil" dugmesini aramak icin sonuna kadar inmemeli. */}
        <div ref={govdeRef} className="min-h-0 flex-1 overflow-y-auto px-5 py-4">
          {children}
        </div>

        {eylemler ? (
          <div
            className="flex shrink-0 flex-wrap items-center justify-end gap-2 border-t px-5 py-3"
            style={{
              borderColor: "var(--yz-border)",
              borderTopWidth: "var(--yz-border-w)",
              background: "var(--yz-surface-2)",
            }}
          >
            {eylemler}
          </div>
        ) : null}
      </motion.div>
    </MotionConfig>
  );
}

/**
 * Cekmece govdesinde ETIKET-DEGER satiri.
 *
 * NEDEN AYRI BILESEN: detay panellerinin govdesi neredeyse her zaman bir
 * alan listesidir. Her ekranin kendi `<div class="flex justify-between">`
 * ini yazmasi, hizalamanin ve bosluklarin ekran ekran kaymasi demekti —
 * P244'un olctugu "tutarsizlik" tam bu sinif.
 */
export function CekmeceSatiri({
  etiket,
  children,
}: {
  etiket: string;
  children: ReactNode;
}) {
  return (
    <div
      className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 border-b py-2.5 last:border-b-0"
      style={{ borderColor: "var(--yz-border)", borderBottomWidth: "var(--yz-border-w)" }}
    >
      <dt style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{etiket}</dt>
      <dd
        className="min-w-0 text-end"
        style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
      >
        {children}
      </dd>
    </div>
  );
}
