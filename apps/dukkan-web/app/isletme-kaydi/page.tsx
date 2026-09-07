"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { api, hataMetni, jetonAl } from "@/lib/istemci";

export default function IsletmeKaydi() {
  const yonlendir = useRouter();
  const [ad, setAd] = useState("");
  const [telefon, setTelefon] = useState("");
  const [aciklama, setAciklama] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [bekle, setBekle] = useState(false);

  useEffect(() => {
    if (!jetonAl()) yonlendir.replace("/giris");
  }, [yonlendir]);

  async function gonder(e: React.FormEvent) {
    e.preventDefault();
    setHata(null);
    setBekle(true);
    try {
      const y = await api<{ id: string }>("/isletme", {
        metot: "POST",
        govde: { ad, telefon, aciklama: aciklama || undefined },
      });
      yonlendir.push(`/panel/${y.id}`);
    } catch (h) {
      setHata(hataMetni(h));
    } finally {
      setBekle(false);
    }
  }

  return (
    <main className="mx-auto max-w-lg px-4 py-12">
      <h1 className="text-2xl font-bold text-marka-koyu">İşletme kaydı</h1>
      {/* Kaydin TASLAK basladigini ONCEDEN soyluyoruz: kullanici formu
          gonderince "yayina girdim" sanmasin. */}
      <p className="mt-2 text-sm text-[color:var(--dk-metin-soluk)]">
        Kayıt taslak olarak başlar. Hizmetlerinizi ve bölgelerinizi seçip
        telefonunuzu doğruladıktan sonra onaya gönderirsiniz.
      </p>

      <form onSubmit={gonder} className="mt-6 space-y-4">
        <label className="block">
          <span className="text-sm font-medium">İşletme adı *</span>
          <input
            required
            minLength={2}
            value={ad}
            onChange={(e) => setAd(e.target.value)}
            className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
          />
        </label>
        <label className="block">
          <span className="text-sm font-medium">İşletme telefonu *</span>
          <input
            type="tel"
            required
            value={telefon}
            onChange={(e) => setTelefon(e.target.value)}
            placeholder="05XX XXX XX XX"
            className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
          />
          <span className="mt-1 block text-xs text-[color:var(--dk-metin-soluk)]">
            Müşterilerin arayacağı numara. Doğrulanması gerekir.
          </span>
        </label>
        <label className="block">
          <span className="text-sm font-medium">Kısa tanıtım</span>
          <textarea
            rows={4}
            value={aciklama}
            onChange={(e) => setAciklama(e.target.value)}
            className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
          />
        </label>
        <button
          type="submit"
          disabled={bekle}
          className="w-full rounded bg-marka px-4 py-2 font-medium text-white disabled:opacity-60"
        >
          {bekle ? "Kaydediliyor…" : "Devam et"}
        </button>
      </form>

      {hata && (
        <p className="mt-4 rounded bg-red-50 px-3 py-2 text-sm text-red-800">
          {hata}
        </p>
      )}
    </main>
  );
}
