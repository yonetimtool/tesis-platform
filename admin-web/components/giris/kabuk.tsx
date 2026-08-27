"use client";

// (P181 A–D) GIRIS KABUGU — kimlik (auth) sayfalari icin ORTAK vitrin cercevesi.
//
// NEDEN: "sifremi unuttum" sayfasi beyaz zeminde tek kart olarak duruyordu
// (prod bulgusu B) — kullanici ayni uygulamada oldugunu hissetmiyordu. Giris
// ekraninin gorsel dili (orbital arka plan + marka + sol tanitim metni + cam
// kart) BURADA tek yerde toplanip hem `GirisFormu` disindaki auth sayfalarina
// verilir. GirisFormu'nun kendi ic yerlesimi (basari animasyonu forma bagli)
// DEGISMEDI; bu kabuk yeni auth sayfalari (sifremi-unuttum vb.) icindir.
//
// Palet giris ekraniyla AYNI kaynaktan (`./palet`) gelir — vitrin deep navy +
// turkuaz; panelin `--yz-*` metalik dili buraya girmez.

import { motion, MotionConfig } from "framer-motion";
import Image from "next/image";

import { DilSecici } from "@/components/DilSecici";
import { GirisSahnesi } from "@/components/giris/sahne";
import {
  CAM_KENAR,
  CAM_KENAR_HATA,
  CAM_KENAR_ZAYIF,
  CAM_ZEMIN,
  CAM_ZEMIN_KOYU,
  CAM_ZEMIN_MOBIL,
  EGRI_DIZI,
  GIRIS_SIRASI,
  METIN,
  METIN_IKINCIL,
  METIN_SOLUK,
} from "@/components/giris/palet";
import { useHareket } from "@/lib/hareket";
import { useBantEnAz } from "@/lib/kirilma-kullan";
import { useT } from "@/lib/i18n/kullan";

// Ortak alan (input) sunumu — GirisFormu'ndaki degerlerle BIREBIR ayni
// (ayni paletten). Auth sayfalari bunu import ederek gorsel tutarlilik
// garanti eder; kenar UC AYRI ozellik verilir (sablon-dizge taramasi
// `border: "1px solid X"` kisayolunu cevrilmemis metin sayar).
export const girisAlanSinifi =
  "w-full rounded-xl px-3.5 py-2.5 text-sm outline-none transition-[border-color,box-shadow,background] duration-[250ms]";
export function girisAlanStili(hatali?: boolean): React.CSSProperties {
  return {
    background: CAM_ZEMIN_KOYU,
    borderWidth: "1px",
    borderStyle: "solid",
    // HATA: alan kirmizi cerceve alir (prod bulgusu C — bicimsel dogrulama).
    borderColor: hatali ? CAM_KENAR_HATA : CAM_KENAR_ZAYIF,
    color: METIN,
  };
}
export const girisEtiketSinifi = "mb-1.5 block text-sm font-medium";
export const girisEtiketStili: React.CSSProperties = { color: METIN_IKINCIL };
export { METIN, METIN_IKINCIL, METIN_SOLUK };

/**
 * Auth sayfasi cercevesi: orbital sahne + dil secici + sol marka/tanitim +
 * sag cam kart. Kart icerigi `children` olarak verilir.
 */
export function GirisKabuk({ children }: { children: React.ReactNode }) {
  const t = useT();
  const hareketVar = useHareket();
  const mobil = !useBantEnAz("lg");

  const giris = (gecikme: number) => ({
    initial: { opacity: 0, y: 14 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: 0.62, ease: EGRI_DIZI, delay: hareketVar ? gecikme : 0 },
  });

  return (
    <MotionConfig reducedMotion="user">
      <main
        className="relative flex min-h-screen w-full flex-col overflow-hidden lg:grid lg:grid-cols-[1.15fr_1fr]"
        style={{ background: "#061426" }}
      >
        <GirisSahnesi hareketVar={hareketVar} mobil={mobil} />

        {/* ---- DIL SECICI — sag ust ---- */}
        <div className="absolute end-4 top-4 z-30 sm:end-6 sm:top-6">
          <DilSecici />
        </div>

        {/* ---- SOL: marka + tanitim ---- */}
        <section className="relative z-10 flex min-w-0 flex-col justify-between px-6 pb-6 pt-20 sm:px-10 lg:px-14 lg:py-14">
          <motion.div {...giris(GIRIS_SIRASI.logo)}>
            <Image
              src="/yonetio-marka-acik.png"
              alt="Yönetiyor"
              width={1271}
              height={339}
              priority
              className="h-9 w-auto transition-transform duration-300 hover:scale-[1.02] sm:h-11"
            />
          </motion.div>

          <div className="max-w-[520px] py-10 lg:py-0">
            <motion.h1
              {...giris(GIRIS_SIRASI.baslik)}
              className="break-words text-[28px] font-semibold leading-[1.1] tracking-[-1px] sm:text-[40px] lg:text-[52px] lg:tracking-[-1.5px]"
              style={{ color: METIN }}
            >
              {t("girisSloganBaslik")}
            </motion.h1>
            <motion.p
              {...giris(GIRIS_SIRASI.aciklama)}
              className="mt-5 break-words text-base leading-relaxed"
              style={{ color: METIN_IKINCIL }}
            >
              {t("girisSloganAlt")}
            </motion.p>
          </div>

          <motion.div
            {...giris(GIRIS_SIRASI.aciklama)}
            className="text-xs"
            style={{ color: METIN_SOLUK }}
          >
            © {t("girisAltBilgi")}
          </motion.div>
        </section>

        {/* ---- SAG: cam kart (giris kartiyla ayni yuzey) ---- */}
        <section className="relative z-10 flex min-w-0 items-center justify-center px-4 pb-12 sm:px-8 lg:pb-0">
          <motion.div
            initial={{ opacity: 0, y: 30, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            transition={{
              duration: 0.9,
              ease: EGRI_DIZI,
              delay: hareketVar ? GIRIS_SIRASI.kart : 0,
            }}
            className="w-[calc(100%-32px)] max-w-[420px] space-y-5 p-7 sm:w-full sm:p-8"
            style={{
              background: mobil ? CAM_ZEMIN_MOBIL : CAM_ZEMIN,
              backdropFilter: mobil ? undefined : "blur(25px)",
              WebkitBackdropFilter: mobil ? undefined : "blur(25px)",
              borderWidth: "1px",
              borderStyle: "solid",
              borderColor: CAM_KENAR,
              borderRadius: "18px",
              boxShadow: "0 25px 80px rgba(0,0,0,0.35)",
            }}
          >
            {children}
          </motion.div>
        </section>
      </main>
    </MotionConfig>
  );
}
