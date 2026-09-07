"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { api, hataMetni, jetonAl } from "@/lib/istemci";

type Talep = {
  id: string;
  baslik: string | null;
  aciklama: string;
  durum: string;
  kategori: string;
  mahalle: string;
  ilce: string;
  teklif_sayisi: number;
};

const DURUM: Record<string, string> = {
  acik: "Teklif bekleniyor",
  teklif_var: "Teklifler geldi",
  is_verildi: "İş verildi",
  iptal: "İptal edildi",
  suresi_doldu: "Süresi doldu",
};

export default function Taleplerim() {
  const yonlendir = useRouter();
  const [liste, setListe] = useState<Talep[] | null>(null);
  const [hata, setHata] = useState<string | null>(null);

  useEffect(() => {
    if (!jetonAl()) {
      yonlendir.replace("/giris");
      return;
    }
    api<{ items: Talep[] }>("/talep")
      .then((d) => setListe(d.items))
      .catch((h) => setHata(hataMetni(h)));
  }, [yonlendir]);

  return (
    <main className="mx-auto max-w-3xl px-4 py-12">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-marka-koyu">Taleplerim</h1>
        <Link
          href="/talep-olustur"
          className="rounded bg-marka px-4 py-2 text-sm font-medium text-white"
        >
          Yeni talep
        </Link>
      </div>

      {hata && (
        <p className="mt-6 rounded bg-red-50 px-3 py-2 text-sm text-red-800">
          {hata}
        </p>
      )}

      {liste?.length === 0 && (
        <p className="mt-8 text-[color:var(--dk-metin-soluk)]">
          Henüz talebin yok.
        </p>
      )}

      <ul className="mt-6 space-y-3">
        {liste?.map((t) => (
          <li
            key={t.id}
            className="rounded border border-[color:var(--dk-cizgi)] p-4"
          >
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <Link
                  href={`/taleplerim/${t.id}`}
                  className="font-medium text-marka-koyu hover:underline"
                >
                  {t.baslik || t.kategori}
                </Link>
                <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
                  {t.mahalle} · {t.ilce}
                </p>
                <p className="mt-1 line-clamp-2 text-sm">{t.aciklama}</p>
              </div>
              <div className="shrink-0 text-right">
                <span className="text-xs text-[color:var(--dk-metin-soluk)]">
                  {DURUM[t.durum] ?? t.durum}
                </span>
                {t.teklif_sayisi > 0 && (
                  <span className="mt-1 block rounded bg-marka-acik px-2 py-0.5 text-xs text-marka-koyu">
                    {t.teklif_sayisi} teklif
                  </span>
                )}
              </div>
            </div>
          </li>
        ))}
      </ul>
    </main>
  );
}
