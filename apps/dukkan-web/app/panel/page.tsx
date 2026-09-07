"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { api, hataMetni, jetonAl } from "@/lib/istemci";

type Isletme = {
  id: string;
  ad: string;
  slug: string;
  durum: string;
  dogrulama_seviyesi: number;
  red_sebebi: string | null;
  askiya_alma_sebebi: string | null;
};

/** Durum rozetinin METNI — kullaniciya ne yapacagini SOYLER.
 *
 * "taslak" kelimesi tek basina bir sonraki adimi anlatmaz; kullanici
 * kaydettim sanip bekler. Her durum, YAPILACAK ISI icerir. */
const DURUM: Record<string, { etiket: string; renk: string; ipucu: string }> = {
  taslak: {
    etiket: "Taslak",
    renk: "bg-gray-100 text-gray-800",
    ipucu: "Profili tamamlayıp başvuruya gönderin.",
  },
  onay_bekliyor: {
    etiket: "Onay bekliyor",
    renk: "bg-amber-100 text-amber-900",
    ipucu: "Başvurunuz incelemede. Genelde 2 iş günü sürer.",
  },
  onayli: {
    etiket: "Yayında",
    renk: "bg-emerald-100 text-emerald-900",
    ipucu: "İşletmeniz aramalarda görünüyor.",
  },
  reddedildi: {
    etiket: "Reddedildi",
    renk: "bg-red-100 text-red-900",
    ipucu: "Gerekçeyi okuyup düzeltin, tekrar başvurabilirsiniz.",
  },
  askida: {
    etiket: "Askıda",
    renk: "bg-red-100 text-red-900",
    ipucu: "İşletmeniz aramalarda görünmüyor.",
  },
};

export default function Panel() {
  const yonlendir = useRouter();
  const [liste, setListe] = useState<Isletme[] | null>(null);
  const [hata, setHata] = useState<string | null>(null);

  useEffect(() => {
    if (!jetonAl()) {
      yonlendir.replace("/giris");
      return;
    }
    api<{ items: Isletme[] }>("/isletme/benim")
      .then((d) => setListe(d.items))
      .catch((h) => setHata(hataMetni(h)));
  }, [yonlendir]);

  return (
    <main className="mx-auto max-w-3xl px-4 py-12">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-marka-koyu">İşletmelerim</h1>
        {/* (F6-ek) Isletme sahibinin bildirim girisi: "yeni talep" ve
            "is verildi" buradan okunur. */}
        <Link href="/bildirimler" className="text-sm text-marka">
          Bildirimler
        </Link>
        <Link
          href="/isletme-kaydi"
          className="rounded bg-marka px-4 py-2 text-sm font-medium text-white"
        >
          Yeni işletme
        </Link>
      </div>

      {hata && (
        <p className="mt-6 rounded bg-red-50 px-3 py-2 text-sm text-red-800">
          {hata}
        </p>
      )}

      {liste === null && !hata && (
        <p className="mt-6 text-[color:var(--dk-metin-soluk)]">Yükleniyor…</p>
      )}

      {liste?.length === 0 && (
        <div className="mt-8 rounded border border-[color:var(--dk-cizgi)] p-6">
          <h2 className="font-medium">Henüz işletme kaydınız yok</h2>
          <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
            Bölgenizdeki müşterilere ulaşmak için işletmenizi kaydedin. Kayıt
            ücretsiz.
          </p>
          <Link
            href="/isletme-kaydi"
            className="mt-4 inline-block rounded bg-marka px-4 py-2 text-sm font-medium text-white"
          >
            İşletme kaydet
          </Link>
        </div>
      )}

      <ul className="mt-6 space-y-3">
        {liste?.map((i) => {
          const d = DURUM[i.durum] ?? {
            etiket: i.durum,
            renk: "bg-gray-100",
            ipucu: "",
          };
          return (
            <li
              key={i.id}
              className="rounded border border-[color:var(--dk-cizgi)] p-4"
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <Link
                    href={`/panel/${i.id}`}
                    className="font-medium text-marka-koyu hover:underline"
                  >
                    {i.ad}
                  </Link>
                  <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
                    {d.ipucu}
                  </p>
                  {i.red_sebebi && (
                    <p className="mt-2 rounded bg-red-50 px-2 py-1 text-sm text-red-900">
                      Ret gerekçesi: {i.red_sebebi}
                    </p>
                  )}
                  {i.askiya_alma_sebebi && (
                    <p className="mt-2 rounded bg-red-50 px-2 py-1 text-sm text-red-900">
                      Askı gerekçesi: {i.askiya_alma_sebebi}
                    </p>
                  )}
                </div>
                <span className={`shrink-0 rounded px-2 py-1 text-xs ${d.renk}`}>
                  {d.etiket}
                </span>
              </div>
            </li>
          );
        })}
      </ul>
    </main>
  );
}
