"use client";

import { motion, MotionConfig } from "framer-motion";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useState } from "react";

import type { ApiError } from "@/lib/types";

const EASE = [0.22, 1, 0.36, 1] as const;

export default function LoginPage() {
  const router = useRouter();
  const [tenantSlug, setTenantSlug] = useState("acme-plaza");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ tenant_slug: tenantSlug, email, password }),
      });
      if (!res.ok) {
        const data = (await res.json().catch(() => null)) as ApiError | null;
        setError(data?.error?.message ?? "Giriş başarısız.");
        return;
      }
      router.replace("/dashboard");
      router.refresh();
    } catch {
      setError("Sunucuya ulaşılamadı.");
    } finally {
      setLoading(false);
    }
  }

  const field =
    "w-full rounded-lg border border-slate-300 bg-white px-3.5 py-2.5 text-sm text-ink outline-none transition focus:border-brand-teal focus:ring-2 focus:ring-brand-teal/25";
  const labelText = "mb-1.5 block text-sm font-medium text-slate-700";

  const container = {
    hidden: {},
    show: { transition: { staggerChildren: 0.06, delayChildren: 0.1 } },
  };
  const item = {
    hidden: { opacity: 0, y: 10 },
    show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: EASE } },
  };

  return (
    <MotionConfig reducedMotion="user">
      <main className="grid min-h-screen lg:grid-cols-[1.05fr_1fr]">
        {/* ---- Sol: marka gradyan paneli (navy → teal) + suzulen orb'ler ---- */}
        <section className="relative flex min-h-[36vh] flex-col justify-between overflow-hidden bg-brand-gradient p-8 lg:min-h-screen lg:p-12">
          {/* Imza: yumusak suzulen orb'ler (GPU transform; reduced-motion durur) */}
          <div aria-hidden className="pointer-events-none absolute inset-0">
            <div className="animate-drift absolute -left-16 top-8 h-72 w-72 rounded-full bg-white/10 blur-3xl" />
            <div className="animate-driftAlt absolute -right-10 top-1/3 h-80 w-80 rounded-full bg-brand-teal/25 blur-3xl" />
            <div className="animate-drift absolute bottom-0 left-1/3 h-64 w-64 rounded-full bg-white/10 blur-3xl" />
          </div>

          <motion.div
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.4, ease: EASE }}
            className="relative z-10 flex items-center gap-2.5"
          >
            <Image
              src="/yonetio-master.png"
              alt="Yönetio"
              width={36}
              height={36}
              priority
              className="shrink-0 rounded-md"
            />
            <span className="text-2xl font-semibold tracking-tight text-white">
              yönetio
            </span>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 14 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, ease: EASE, delay: 0.12 }}
            className="relative z-10 max-w-md"
          >
            <h1 className="text-3xl font-semibold leading-tight tracking-tight text-white sm:text-4xl">
              Tesis operasyonunuz,
              <br />
              tek panelden.
            </h1>
            <p className="mt-4 text-base leading-relaxed text-white/75">
              Devriye, görev, aidat ve sakin akışlarını tek yerden yönetin —
              canlı durum, net raporlar, sade bir arayüz.
            </p>
          </motion.div>

          <div className="relative z-10 text-xs text-white/60">
            © Yönetio · çok kiracılı tesis operasyon platformu
          </div>
        </section>

        {/* ---- Sag: temiz form karti ---- */}
        <section className="flex items-center justify-center bg-[#fafbfc] px-4 py-10 sm:px-8 dark:bg-transparent">
          <motion.form
            onSubmit={onSubmit}
            variants={container}
            initial="hidden"
            animate="show"
            className="w-full max-w-sm space-y-5 rounded-2xl border border-slate-200 bg-white p-8 shadow-card"
          >
            <motion.div variants={item}>
              <h2 className="text-xl font-semibold tracking-tight">Yönetim Paneli</h2>
              <p className="mt-1 text-sm text-muted">
                Yalnızca platform admini giriş yapabilir.
              </p>
            </motion.div>

            <motion.label variants={item} className="block">
              <span className={labelText}>Tesis (slug)</span>
              <input
                className={field}
                value={tenantSlug}
                onChange={(e) => setTenantSlug(e.target.value)}
                autoComplete="organization"
                required
              />
            </motion.label>

            <motion.label variants={item} className="block">
              <span className={labelText}>E-posta</span>
              <input
                type="email"
                className={field}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="username"
                required
              />
            </motion.label>

            <motion.label variants={item} className="block">
              <span className={labelText}>Parola</span>
              <input
                type="password"
                className={field}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
                minLength={8}
                required
              />
            </motion.label>

            {error && (
              <motion.p
                initial={{ opacity: 0, y: -4 }}
                animate={{ opacity: 1, y: 0 }}
                className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
              >
                {error}
              </motion.p>
            )}

            <motion.button
              variants={item}
              whileHover={{ y: -1 }}
              whileTap={{ y: 1 }}
              type="submit"
              disabled={loading}
              className="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-brand-teal py-2.5 text-sm font-medium text-white shadow-soft transition-shadow hover:shadow-lift disabled:opacity-60"
            >
              {loading && (
                <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/40 border-t-white" />
              )}
              {loading ? "Giriş yapılıyor..." : "Giriş yap"}
            </motion.button>
          </motion.form>
        </section>
      </main>
    </MotionConfig>
  );
}
