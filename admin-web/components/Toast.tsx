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

const KIND_STYLE: Record<ToastKind, { dot: string; ring: string }> = {
  success: { dot: "bg-emerald-500", ring: "border-emerald-200" },
  error: { dot: "bg-red-500", ring: "border-red-200" },
  info: { dot: "bg-brand-teal", ring: "border-slate-200" },
};

export function ToastProvider({ children }: { children: ReactNode }) {
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
          className="pointer-events-none fixed bottom-4 right-4 z-[60] flex w-[min(92vw,22rem)] flex-col gap-2"
          role="status"
          aria-live="polite"
        >
          <AnimatePresence initial={false}>
            {items.map((t) => {
              const s = KIND_STYLE[t.kind];
              return (
                <motion.div
                  key={t.id}
                  layout
                  initial={{ opacity: 0, y: 12, scale: 0.96 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.96 }}
                  transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] as const }}
                  className={`pointer-events-auto flex items-start gap-3 rounded-xl border bg-white px-4 py-3 shadow-lift ${s.ring}`}
                >
                  <span className={`mt-1.5 h-2 w-2 shrink-0 rounded-full ${s.dot}`} />
                  <p className="flex-1 text-sm text-ink">{t.message}</p>
                  <button
                    onClick={() => remove(t.id)}
                    aria-label="Kapat"
                    className="-mr-1 shrink-0 rounded-md p-1 text-slate-400 transition hover:bg-slate-100 hover:text-slate-600"
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
