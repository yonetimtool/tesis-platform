"use client";

import { motion, MotionConfig } from "framer-motion";

// Rota gecisi. template.tsx her gezinmede yeniden mount olur → dogal "enter"
// animasyonu (fade + kucuk yukari kayma), AnimatePresence gerekmeden. Yalnizca
// transform/opacity (GPU dostu); reducedMotion="user" ile hareket-azaltmada
// aninda gorunur, kaydirma geri-yukleme ve veri yuklemesi etkilenmez.
export default function ProtectedTemplate({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <MotionConfig reducedMotion="user">
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] as const }}
      >
        {children}
      </motion.div>
    </MotionConfig>
  );
}
