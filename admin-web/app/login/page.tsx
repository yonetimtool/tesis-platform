"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import type { ApiError } from "@/lib/types";

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
        setError(data?.error?.message ?? "Giris basarisiz.");
        return;
      }
      router.replace("/dashboard");
      router.refresh();
    } catch {
      setError("Sunucuya ulasilamadi.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <form
        onSubmit={onSubmit}
        className="w-full max-w-sm space-y-4 rounded-2xl border border-slate-200 bg-white p-8 shadow-sm"
      >
        <div>
          <h1 className="text-xl font-semibold">Yonetim Paneli</h1>
          <p className="text-sm text-muted">Tesis operasyon SaaS</p>
        </div>

        <label className="block text-sm">
          <span className="mb-1 block font-medium">Tesis (slug)</span>
          <input
            className="w-full rounded-lg border border-slate-300 px-3 py-2 outline-none focus:border-slate-500"
            value={tenantSlug}
            onChange={(e) => setTenantSlug(e.target.value)}
            autoComplete="organization"
            required
          />
        </label>

        <label className="block text-sm">
          <span className="mb-1 block font-medium">E-posta</span>
          <input
            type="email"
            className="w-full rounded-lg border border-slate-300 px-3 py-2 outline-none focus:border-slate-500"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="username"
            required
          />
        </label>

        <label className="block text-sm">
          <span className="mb-1 block font-medium">Parola</span>
          <input
            type="password"
            className="w-full rounded-lg border border-slate-300 px-3 py-2 outline-none focus:border-slate-500"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            minLength={8}
            required
          />
        </label>

        {error && (
          <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-lg bg-ink py-2 font-medium text-white transition hover:bg-slate-700 disabled:opacity-60"
        >
          {loading ? "Giris yapiliyor..." : "Giris yap"}
        </button>
      </form>
    </main>
  );
}
