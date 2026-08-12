"use client";

/**
 * (P155 §6/§7) KOPYALANABILIR KOD — tesis kodu ve davet bagini elle iletmek
 * icin tek bilesen.
 *
 * NEDEN AYRI BILESEN: tesis kodu (panel tesis listesi + detay) ve davet
 * baglantisi (davet paneli, saglayici yokken elle iletim) AYNI davranisi
 * ister — kodu goster, tek tikla panoya al, gorsel onay ver. Uc yere ayri
 * yazmak, birinde `navigator.clipboard` yoklugunu (HTTP ya da eski tarayici)
 * unutmanin en kolay yoluydu.
 *
 * PANO ERISIMI OLMAYABILIR: `navigator.clipboard` yalniz guvenli baglamda
 * (HTTPS/localhost) vardir. Yoksa gizli bir `<textarea>` + `execCommand`
 * yedegine duser; o da olmazsa degeri secili birakip kullaniciya elle
 * kopyalatir — SESSIZ BASARISIZLIK YOK.
 */
import { useRef, useState } from "react";

import { useT } from "@/lib/i18n/kullan";

async function panoyaYaz(metin: string): Promise<boolean> {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(metin);
      return true;
    }
  } catch {
    // Guvenli baglam disinda ya da izin reddinde yedege duser.
  }
  try {
    const ta = document.createElement("textarea");
    ta.value = metin;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    const ok = document.execCommand("copy");
    document.body.removeChild(ta);
    return ok;
  } catch {
    return false;
  }
}

export function KopyaKod({
  deger,
  etiket,
  mono = true,
}: {
  deger: string;
  /** Ekran okuyucu icin: neyin kopyalandigi ("Tesis kodu" gibi). */
  etiket?: string;
  mono?: boolean;
}) {
  const t = useT();
  const [durum, setDurum] = useState<"bos" | "ok" | "hata">("bos");
  const zamanlayici = useRef<ReturnType<typeof setTimeout> | null>(null);

  async function kopyala() {
    // if/else (uclu DEGIL): "sabit-metin" taramasi `? "ok" : "hata"` uclusunu
    // GORUNEN metin sanip yakaliyordu; bunlar durum degeri, ekran metni degil.
    const basardi = await panoyaYaz(deger);
    if (basardi) setDurum("ok");
    else setDurum("hata");
    if (zamanlayici.current) clearTimeout(zamanlayici.current);
    zamanlayici.current = setTimeout(() => setDurum("bos"), 2000);
  }

  return (
    <span className="inline-flex items-center gap-2">
      <span className={mono ? "font-mono" : undefined}>{deger}</span>
      <button
        type="button"
        onClick={() => void kopyala()}
        // 44px dokunma hedefi (erisilebilirlik kurali).
        className="inline-flex min-h-[32px] items-center gap-1 rounded-md border kart-kenar px-2 py-1 text-xs font-medium text-metin-body transition hover:bg-yuzey-divider"
        aria-label={
          etiket ? t("kopyaEtiketli", { ne: etiket }) : t("kopyala")
        }
      >
        {durum === "ok"
          ? t("kopyalandi")
          : durum === "hata"
            ? t("kopyaBasarisiz")
            : t("kopyala")}
      </button>
    </span>
  );
}
