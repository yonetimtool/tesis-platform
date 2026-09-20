"use client";

import { usePathname } from "next/navigation";
import { useState } from "react";

import { Modal } from "@/components/Modal";
import { ekranYardimi } from "@/lib/ekran-yardimi";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P243 §6e) BAGLAM ICI YARDIM — ust cubuktaki soru isareti.
 *
 * Brief: "Her ekranda soru işareti: bu ekran ne işe yarar, burada ne
 * yapabilirim."
 *
 * NEDEN KABUKTA, SAYFA BASINA DEGIL: sayfalar kendi `<h1>`ini ciziyor
 * ve ortak bir baslik yuvasi yok. Dugmeyi altmis kusur sayfaya tek tek
 * koymak, ayni davranisi altmis kez yazmak ve birini unuttugunda
 * kullaniciya "bazi ekranlarda yardim var" demek olurdu. Kabukta TEK
 * yer var ve rotayi zaten biliyor.
 *
 * KAYDI OLMAYAN EKRANDA DUGME CIZILMEZ: acip "aciklama yazilmadi"
 * demek, dugmenin hic olmamasindan kotudur — kullanici bir kez tiklar,
 * bos cikar, bir daha tiklamaz.
 */
export function EkranYardimi() {
  const t = useT();
  const yol = usePathname();
  const [acik, setAcik] = useState(false);
  const anahtar = ekranYardimi(yol);
  if (anahtar === null) return null;

  return (
    <>
      <button
        type="button"
        onClick={() => setAcik(true)}
        aria-label={t("yardimAc")}
        title={t("yardimAc")}
        data-test="ekran-yardimi"
        className="odak-ic kart-kenar rounded-lg border p-2 text-metin-body transition hover:bg-yuzey-divider"
      >
        <svg
          viewBox="0 0 24 24"
          className="h-5 w-5"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.75"
          strokeLinecap="round"
          aria-hidden="true"
        >
          <circle cx="12" cy="12" r="9" />
          <path d="M9.6 9.2a2.5 2.5 0 1 1 3.3 2.4c-.6.2-.9.7-.9 1.3v.6" />
          <line x1="12" y1="17" x2="12" y2="17" />
        </svg>
      </button>
      <Modal
        baslik={t("yardimBaslik")}
        acik={acik}
        kapat={() => setAcik(false)}
        genislik="sm"
      >
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t(anahtar)}
        </p>
      </Modal>
    </>
  );
}
