"use client";

import { AnimatePresence, motion, MotionConfig } from "framer-motion";
import {
  createContext,
  useCallback,
  useContext,
  useRef,
  useState,
  type ReactNode,
} from "react";

import { useT } from "@/lib/i18n/kullan";

// Hafif toast sistemi (Faz 2). Harici bag yok — framer-motion zaten mevcut.
// create/update/delete sonrasi kisa basari/hata geri bildirimi; NE iletildigini
// degistirmez, yalniz gorunumu. Cok satirli kritik bilgiler (or. tek-seferlik
// gecici kodlar) hala window.alert ile kalir — toast auto-dismiss oldugundan
// kopyalanmasi gereken bilgi icin uygun degil.

type ToastKind = "success" | "error" | "info";
interface ToastItem {
  id: number;
  kind: ToastKind;
  message: string;
}
interface ToastApi {
  success: (message: string) => void;
  error: (message: string) => void;
  info: (message: string) => void;
}

const ToastCtx = createContext<ToastApi | null>(null);

export function useToast(): ToastApi {
  const ctx = useContext(ToastCtx);
  if (!ctx) throw new Error("useToast must be used within <ToastProvider>");
  return ctx;
}

/**
 * (P160) TEMA TOKENLERI. Bildirim kutusu `bg-white` ile sabitlenmisti:
 * KOYU TEMADA ekranin kosesinde BEYAZ bir kart cikiyordu ve metin rengi
 * (`text-ink`) da acik tema icin secilmisti. Kutu artik iki temada da
 * yuzey rengini okuyor.
 *
 * NOKTA RENGI anlamli grafiktir (3.0 esigi) — `-edge` tonlari tam bunun
 * icin olculdu; metin zaten `--yz-text` ile AA.
 */
const KIND_NOKTA: Record<ToastKind, string> = {
  success: "var(--yz-success-edge)",
  error: "var(--yz-danger-edge)",
  info: "var(--yz-accent)",
};

export function ToastProvider({ children }: { children: ReactNode }) {
  // `t` bu dosyada TOAST OGESIDIR (map degiskeni); ceviri fonksiyonu bu
  // yuzden `ceviri` adiyla alinir (tur 47).
  const ceviri = useT();
  const [items, setItems] = useState<ToastItem[]>([]);
  const idRef = useRef(0);

  const remove = useCallback((id: number) => {
    setItems((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const push = useCallback(
    (kind: ToastKind, message: string) => {
      const id = ++idRef.current;
      setItems((prev) => [...prev, { id, kind, message }]);
      setTimeout(() => remove(id), 3800);
    },
    [remove],
  );

  const api = useRef<ToastApi>({
    success: (m) => push("success", m),
    error: (m) => push("error", m),
    info: (m) => push("info", m),
  });
  // push referansi stabil (bagimlilik yok) — api'yi bir kez kurdugumuz yeterli.

  return (
    <ToastCtx.Provider value={api.current}>
      {children}
      <MotionConfig reducedMotion="user">
        <div
          className="pointer-events-none fixed bottom-4 end-4 z-[60] flex w-[min(92vw,22rem)] flex-col gap-2"
          role="status"
          aria-live="polite"
        >
          <AnimatePresence initial={false}>
            {items.map((t) => {
              const nokta = KIND_NOKTA[t.kind];
              return (
                <motion.div
                  key={t.id}
                  layout
                  initial={{ opacity: 0, y: 12, scale: 0.96 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.96 }}
                  transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] as const }}
                  className="pointer-events-auto flex items-start gap-3 px-4 py-3"
                  style={{
                    borderRadius: "var(--yz-radius-card)",
                    background: "var(--yz-metal-1)",
                    borderWidth: "var(--yz-border-w)",
                    borderStyle: "solid",
                    borderColor: "var(--yz-border)",
                    boxShadow: "var(--yz-raised-hover)",
                  }}
                >
                  <span
                    className="mt-1.5 h-2 w-2 shrink-0 rounded-full"
                    style={{ background: nokta }}
                  />
                  <p
                    className="flex-1"
                    style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                  >
                    {t.message}
                  </p>
                  <button
                    onClick={() => remove(t.id)}
                    aria-label={ceviri("ortakKapat")}
                    className="odak-ic -me-1 shrink-0 rounded-md p-1"
                    style={{ color: "var(--yz-text-2)" }}
                  >
                    <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                      <line x1="6" y1="6" x2="18" y2="18" /><line x1="18" y1="6" x2="6" y2="18" />
                    </svg>
                  </button>
                </motion.div>
              );
            })}
          </AnimatePresence>
        </div>
      </MotionConfig>
    </ToastCtx.Provider>
  );
}
