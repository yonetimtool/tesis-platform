"use client";

/**
 * (P160 / Asama 3) MODAL + ONAY DIYALOGU.
 *
 * Brief: "tum olusturma/duzenleme islemleri sayfa ortasinda modalda
 * acilir (sayfa ustunde alan acma deseni kaldirilacak). ESC ile kapanma,
 * disina tiklama (kayitsiz degisiklikte uyari), odak tuzagi, ekran
 * okuyucu basligi, uzun formda ic kaydirma, Iptal/Kaydet sabit altta."
 *
 * Envanterde olculdu: `Modal` bugun yalniz 3 sayfada; kalan ~20 ekran
 * "sayfa ustunde alan acma" deseninde. Bu bilesen o gecisin hedefi.
 *
 * =========================================================================
 * ESKI `components/Modal.tsx` NEDEN DURUYOR
 * =========================================================================
 * O, eski tasarim dilini kullanan 3 sayfaya hizmet ediyor. Ikisini ayni
 * dosyada birlestirmek, gecis boyunca hangi dilin gecerli oldugunu
 * belirsizlestirirdi. Gecis bitince eski kaldirilacak.
 *
 * =========================================================================
 * ODAK TUZAGI — neden elle yazildi
 * =========================================================================
 * Depoda odak tuzagi kutuphanesi yok ve tek bir modal icin bagimlilik
 * eklemek dogru degil. Kural basit: Tab/Shift+Tab modalin ICINDE doner,
 * acilista ilk odaklanabilir oge odaklanir, kapanista odak ACAN OGEYE
 * geri doner. Sonuncusu en cok atlanandir ve klavye kullanicisini
 * sayfanin basina firlatir.
 *
 * =========================================================================
 * KAYITSIZ DEGISIKLIK
 * =========================================================================
 * `kirliMi` verilirse ESC ve dis tiklama DOGRUDAN KAPATMAZ; `onKirliKapat`
 * cagrilir ve karari cagiran verir (genelde bir onay). Vermezse davranis
 * degismez — yani bu ozellik opt-in ve mevcut kullanimlari bozmaz.
 */
import { MotionConfig, motion } from "framer-motion";
import { useCallback, useEffect, useId, useRef, type ReactNode } from "react";

import { useT } from "@/lib/i18n/kullan";

import { Dugme } from "./dugme";

const ODAKLANABILIR =
  'a[href],button:not([disabled]),textarea:not([disabled]),input:not([disabled]),select:not([disabled]),[tabindex]:not([tabindex="-1"])';

export interface ModalProps {
  acik: boolean;
  onKapat: () => void;
  /** Ekran okuyucunun okudugu baslik — ZORUNLU (adsiz diyalog olmaz). */
  baslik: string;
  children: ReactNode;
  /** Altta sabit duran eylemler. Verilmezse yalnizca kapatma cizilir. */
  eylemler?: ReactNode;
  /** Kayitsiz degisiklik var mi? Varsa ESC/dis tiklama onaya duser. */
  kirliMi?: boolean;
  onKirliKapat?: () => void;
  /** Genislik sinifi (Tailwind). Uzun formlar icin genisletilebilir. */
  genislikSinifi?: string;
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`) — CSS degerleri de dize.
const ORTU_RENGI = "rgba(0,0,0,.55)";
const ORTU_BULANIK = "blur(6px)";
const SURE_ORTU = 0.2;
const SURE_KUTU = 0.22;
/** Kurumsal easing — hizli baslar, hedefte yumusar. */
const YUMUSAK = [0.22, 1, 0.36, 1] as const;

export function Modal({
  acik,
  onKapat,
  baslik,
  children,
  eylemler,
  kirliMi = false,
  onKirliKapat,
  genislikSinifi = "max-w-lg",
}: ModalProps) {
  const t = useT();
  const kutuRef = useRef<HTMLDivElement | null>(null);
  const acanRef = useRef<HTMLElement | null>(null);
  const baslikId = useId();

  /** Kapatma istegi — kirliyse cagirana devret. */
  const kapatIstegi = useCallback(() => {
    if (kirliMi && onKirliKapat) {
      onKirliKapat();
      return;
    }
    onKapat();
  }, [kirliMi, onKirliKapat, onKapat]);

  // ODAK: acilista ice, kapanista ACAN OGEYE geri.
  useEffect(() => {
    if (!acik) return;
    acanRef.current = document.activeElement as HTMLElement | null;
    const ilk = kutuRef.current?.querySelector<HTMLElement>(ODAKLANABILIR);
    // Odaklanabilir oge yoksa kutunun kendisi odaklanir (`tabIndex={-1}`)
    // ki ekran okuyucu basligi okusun.
    (ilk ?? kutuRef.current)?.focus();
    return () => {
      acanRef.current?.focus?.();
    };
  }, [acik]);

  // ESC + ODAK TUZAGI.
  useEffect(() => {
    if (!acik) return;
    function tus(e: KeyboardEvent) {
      if (e.key === "Escape") {
        e.stopPropagation();
        kapatIstegi();
        return;
      }
      if (e.key !== "Tab") return;
      const kutu = kutuRef.current;
      if (!kutu) return;
      const ogeler = [...kutu.querySelectorAll<HTMLElement>(ODAKLANABILIR)].filter(
        (o) => o.offsetParent !== null,
      );
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
  }, [acik, kapatIstegi]);

  // ARKA PLAN KAYDIRMASI KILITLENIR: modal acikken sayfanin arkada
  // kaymasi, kullanicinin nerede oldugunu kaybetmesine yol acar.
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
    // (P161) HAREKET. `MotionConfig reducedMotion="user"`: isletim
    // sistemi "hareketi azalt" diyorsa framer-motion butun gecisleri
    // KENDISI kapatir — her bilesende ayri kosul yazmak, birini unutmak
    // demekti.
    <MotionConfig reducedMotion="user">
    <div
      className="fixed inset-0 flex items-center justify-center p-4"
      style={{ zIndex: "var(--yz-z-modal)" as unknown as number }}
    >
      {/* ORTU — tiklama kapatir. `button` DEGIL `div`: ekran okuyucuya
          "dugme" diye duyurulan bir ortu, gercek eylemleri gizler.
          Klavye yolu ESC'tir ve o zaten var. */}
      <motion.div
        aria-hidden="true"
        onClick={kapatIstegi}
        className="absolute inset-0"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: SURE_ORTU }}
        // ARKA PLAN BULANIKLASIR (brief): 2px "biraz bulanik" degil
        // "kirli cam" gibi duruyordu; 6px odagi gercekten modala tasir.
        style={{ background: ORTU_RENGI, backdropFilter: ORTU_BULANIK }}
      />
      <motion.div
        ref={kutuRef}
        // SOLUKLASARAK OLCEKLENME 0.96 -> 1 (brief).
        initial={{ opacity: 0, scale: 0.96 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: SURE_KUTU, ease: YUMUSAK }}
        role="dialog"
        aria-modal="true"
        aria-labelledby={baslikId}
        tabIndex={-1}
        className={`relative flex max-h-[90vh] w-full flex-col ${genislikSinifi}`}
        style={{
          borderRadius: "var(--yz-radius-card)",
          background: "var(--yz-metal-1)",
          borderWidth: "var(--yz-border-w)",
          borderStyle: "solid",
          borderColor: "var(--yz-border)",
          boxShadow: "var(--yz-raised-hover)",
          color: "var(--yz-text)",
        }}
      >
        <div
          className="flex shrink-0 items-start justify-between gap-4 border-b p-4"
          style={{
            borderColor: "var(--yz-border)",
            borderBottomWidth: "var(--yz-border-w)",
          }}
        >
          <h2
            id={baslikId}
            style={{ fontSize: "var(--yz-fs-h2)", lineHeight: "var(--yz-lh-tight)" }}
          >
            {baslik}
          </h2>
          <Dugme
            tur="sessiz"
            boy="kucuk"
            onClick={kapatIstegi}
            aria-label={t("ortakKapat")}
            className="!px-2"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <path d="M6 6l12 12M18 6L6 18" />
            </svg>
          </Dugme>
        </div>

        {/* UZUN FORMDA IC KAYDIRMA — govde kayar, baslik ve eylemler sabit. */}
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
      </motion.div>
    </div>
    </MotionConfig>
  );
}

/**
 * ONAY DIYALOGU — yikici islemler icin.
 *
 * `tehlikeli` isaretlendiginde onay dugmesi tehlike turune gecer.
 * Metinlerin HEPSI cagirandan gelir (i18n kurali); bilesen yalnizca
 * `Iptal` icin sozlukten okur cunku o her yerde ayni.
 */
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const TUR_TEHLIKE = "tehlike" as const;
const TUR_BIRINCIL = "birincil" as const;

export function OnayDiyalogu({
  acik,
  baslik,
  mesaj,
  onayMetni,
  onOnay,
  onIptal,
  tehlikeli = false,
  yukleniyor = false,
}: {
  acik: boolean;
  baslik: string;
  mesaj: string;
  onayMetni: string;
  onOnay: () => void;
  onIptal: () => void;
  tehlikeli?: boolean;
  yukleniyor?: boolean;
}) {
  const t = useT();
  return (
    <Modal
      acik={acik}
      onKapat={onIptal}
      baslik={baslik}
      genislikSinifi="max-w-sm"
      eylemler={
        <>
          <Dugme tur="sessiz" onClick={onIptal} disabled={yukleniyor}>
            {t("ortakIptal")}
          </Dugme>
          <Dugme
            tur={tehlikeli ? TUR_TEHLIKE : TUR_BIRINCIL}
            onClick={onOnay}
            yukleniyor={yukleniyor}
          >
            {onayMetni}
          </Dugme>
        </>
      }
    >
      <p style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text-2)" }}>
        {mesaj}
      </p>
    </Modal>
  );
}
