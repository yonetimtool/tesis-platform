"use client";

import { useCallback, useEffect, useRef, type ReactNode } from "react";

import { btnGhost, btnPrimary } from "@/components/form";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P154 / Asama 6.1) TEK MODAL BILESENI — tum olusturma/duzenleme buradan.
 *
 * NEDEN: bugun duzenleme "sayfanin ustunde alan aciyor" (`panelCls`).
 * Her ekran kendi acilir alanini kurdugu icin ESC, dis tiklama, odak
 * tuzagi ve "kaydedilmemis degisiklik" uyarisi HICBIR yerde yok. Bunlar
 * ekran ekran cozulecek seyler degil — biri unutuldugunda kullanici
 * yazdigini kaybeder ve klavyeyle calisan kisi modalin icine hic giremez.
 *
 * NEDEN `<dialog>` DEGIL: `showModal()` odak tuzagini ve inert arka plani
 * tarayicidan bedava verir, ama animasyon/gecis ve `::backdrop` stilinde
 * tarayici farklari var; ayrica test ortaminda (jsdom) `showModal`
 * uygulanmamis. Odak tuzagini elle kurmak burada 20 satir ve DAVRANISI
 * test edilebilir kiliyor.
 *
 * ERISILEBILIRLIK — dordu de zorunlu, hicbiri sus degil:
 *   * `role="dialog"` + `aria-modal` + `aria-labelledby` -> ekran okuyucu
 *     "hangi pencere" sorusunu yanitlayabilsin,
 *   * odak acilista ICERI girer, kapanista CAGIRAN ogeye doner,
 *   * Tab/Shift+Tab modalin icinde doner (arka plana kacmaz),
 *   * ESC kapatir.
 */

export interface ModalProps {
  /** Baslik — `aria-labelledby` bunu gosterir; bos gecilemez. */
  baslik: string;
  acik: boolean;
  /** Kapatma istegi (ESC, dis tik, Iptal, X). Kirli formda ONAY SORULUR. */
  kapat: () => void;
  children: ReactNode;
  /** Alt cubuk. Verilmezse yalniz "Kapat" cizilir. */
  altBilgi?: ReactNode;
  /** Kaydedilmemis degisiklik var mi — dis tik/ESC'de onay ister. */
  kirli?: boolean;
  /** `sm` dar formlar, `lg` tablo/uzun icerik. */
  genislik?: "sm" | "md" | "lg";
}

const _GENISLIK = { sm: "max-w-md", md: "max-w-xl", lg: "max-w-3xl" } as const;

/** Odaklanabilir oge secicisi — odak tuzagi bunun uzerinden calisir. */
const _ODAKLANABILIR =
  'a[href],button:not([disabled]),textarea:not([disabled]),input:not([disabled]),select:not([disabled]),[tabindex]:not([tabindex="-1"])';

export function Modal({
  baslik,
  acik,
  kapat,
  children,
  altBilgi,
  kirli = false,
  genislik = "md",
}: ModalProps) {
  const t = useT();
  const kutuRef = useRef<HTMLDivElement>(null);
  const oncekiOdakRef = useRef<HTMLElement | null>(null);

  // KIRLI FORMDA ONAY. `window.confirm` bilincli: projede zaten bu desen
  // kullaniliyor (blok silme, tesis silme) ve ikinci bir modal acmak,
  // modal icinde modal yonetmek demekti.
  const kapatmayiDene = useCallback(() => {
    if (kirli && !window.confirm(t("modalKirliUyari"))) return;
    kapat();
  }, [kirli, kapat, t]);

  // ODAK: acilista iceri al, kapanista CAGIRANA dondur.
  // Geri dondurmek "sus" degil: klavyeyle calisan kullanici modali
  // kapattiginda odak `<body>`ye duserse listenin basina savrulur ve
  // kaldigi yeri kaybeder.
  useEffect(() => {
    if (!acik) return;
    oncekiOdakRef.current = document.activeElement as HTMLElement | null;
    const ilk = kutuRef.current?.querySelector<HTMLElement>(_ODAKLANABILIR);
    (ilk ?? kutuRef.current)?.focus();
    return () => oncekiOdakRef.current?.focus?.();
  }, [acik]);

  // ESC + ODAK TUZAGI.
  useEffect(() => {
    if (!acik) return;
    function tus(e: KeyboardEvent) {
      if (e.key === "Escape") {
        e.preventDefault();
        kapatmayiDene();
        return;
      }
      if (e.key !== "Tab") return;
      const ogeler = Array.from(
        kutuRef.current?.querySelectorAll<HTMLElement>(_ODAKLANABILIR) ?? [],
      ).filter((o) => o.offsetParent !== null || o === document.activeElement);
      if (ogeler.length === 0) return;
      const ilk = ogeler[0];
      const son = ogeler[ogeler.length - 1];
      // SARMALAMA: son ogeden Tab ilke, ilkten Shift+Tab sona gider.
      // Bu olmadan odak arka plandaki sayfaya kacar ve kullanici
      // "kapali" sandigi bir formun arkasinda gezinir.
      if (!e.shiftKey && document.activeElement === son) {
        e.preventDefault();
        ilk.focus();
      } else if (e.shiftKey && document.activeElement === ilk) {
        e.preventDefault();
        son.focus();
      }
    }
    document.addEventListener("keydown", tus);
    return () => document.removeEventListener("keydown", tus);
  }, [acik, kapatmayiDene]);

  // ARKA PLAN KAYDIRMASI DURUR: modal acikken sayfanin kaymasi,
  // dokunmatikte modali "kaciran" bir his veriyor.
  useEffect(() => {
    if (!acik) return;
    const eski = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = eski;
    };
  }, [acik]);

  if (!acik) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-0 sm:items-center sm:p-4"
      // DIS TIKLAMA yalniz ORTUNUN KENDISINDE: iceriden gelen tiklama
      // yukari kabarip modali kapatmamali (metin secerken birakma
      // hareketi ortude biterse kullanici yazdigini kaybederdi).
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) kapatmayiDene();
      }}
    >
      <div
        ref={kutuRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-baslik"
        tabIndex={-1}
        // MOBILDE ALTTAN TAM GENISLIK, masaustunde ortada kart.
        // `max-h` + ic kaydirma: uzun form ekrani tasirmasin, alt cubuk
        // her zaman gorunur kalsin.
        className={`flex max-h-[92dvh] w-full flex-col rounded-t-2xl bg-yuzey-card shadow-xl sm:rounded-kart ${_GENISLIK[genislik]}`}
      >
        <div className="flex items-start justify-between gap-3 border-b border-yuzey-divider px-5 py-4">
          <h2 id="modal-baslik" className="text-lg font-semibold">
            {baslik}
          </h2>
          <button
            type="button"
            onClick={kapatmayiDene}
            aria-label={t("ortakKapat")}
            className="rounded-lg px-2 py-1 text-metin-muted transition hover:bg-yuzey-divider"
          >
            <span aria-hidden="true">×</span>
          </button>
        </div>

        {/* IC KAYDIRMA — baslik ve alt cubuk SABIT kalir. */}
        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">{children}</div>

        <div className="flex flex-wrap justify-end gap-2 border-t border-yuzey-divider px-5 py-4">
          {altBilgi ?? (
            <button type="button" className={btnGhost} onClick={kapatmayiDene}>
              {t("ortakKapat")}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

/**
 * Alt cubuk icin standart Iptal/Kaydet ikilisi.
 *
 * AYRI BIR BILESEN cunku her ekran ayni iki dugmeyi ayni sirada yaziyordu
 * ve sira tutarsizlastiginda kullanici yanlis dugmeye basar. Kaydet
 * SAGDA ve birincil; Iptal solda ve sessiz.
 */
export function ModalEylemler({
  kaydet,
  iptal,
  kaydediyor = false,
  kaydetEtiketi,
}: {
  kaydet?: () => void;
  iptal: () => void;
  kaydediyor?: boolean;
  kaydetEtiketi?: string;
}) {
  const t = useT();
  // UCLUDA DIZGE SABITI YOK: `sabit-metin` taramasi ucludaki her dizgeyi
  // (cevrilmemis metin adayi) hakli olarak isaretliyor. Deger modul
  // duzeyinde adlandirilinca hem tarama temiz kaliyor hem niyet okunuyor.
  const kaydetTipi: "button" | "submit" = kaydet ? "button" : "submit";
  return (
    <>
      <button type="button" className={btnGhost} onClick={iptal} disabled={kaydediyor}>
        {t("ortakIptal")}
      </button>
      <button
        type={kaydetTipi}
        className={btnPrimary}
        onClick={kaydet}
        disabled={kaydediyor}
      >
        {kaydediyor ? t("ortakKaydediliyor") : (kaydetEtiketi ?? t("ortakKaydet"))}
      </button>
    </>
  );
}
