"use client";

/**
 * (P161) SAHNE OLCUM TEZGAHI — YALNIZ GELISTIRME.
 *
 * =========================================================================
 * NEDEN VAR
 * =========================================================================
 * Brief: "60 FPS hedefle, orta seviye bir dizustunde 30'un altina dusme —
 * OLC VE RAPORLA". Panodan olcmek mumkun degil: `/dashboard` oturum ve
 * calisan bir sunucu ister, uustelik oradaki daire sayisi test verisine
 * baglidir. Bu sayfa sahneyi ISTENEN OLCEKTE, kimlik dogrulamasiz ve
 * yinelenebilir bicimde cizer.
 *
 * URETIMDE YOK: `notFound()` ile 404 doner. Olcum araci urun yuzeyinde
 * gezinemez.
 *
 * Kullanim: `/olcum/sahne?blok=6&kat=12&katbasi=8` — 6 blok x 12 kat x 8
 * daire = 576 daire.
 *
 * Cizim cagrisi sayimi BU SAYFADA YAPILMAZ: olcum betigi (`olcum/
 * sahne-fps.mjs`) WebGL cagrilarini tarayici tarafinda sarmalar. Boylece
 * urun kodu olcum icin hicbir sey tasimaz.
 */
import { notFound, useSearchParams } from "next/navigation";
import { Suspense, useMemo } from "react";

import { BinaSahnesiYukleyici } from "@/components/3d/sahne-yukleyici";
import type { SahneBlogu } from "@/components/3d/bina-sahnesi";

const GELISTIRME = "development";
const NORMAL = "normal" as const;
const ALARM = "alarm" as const;

function sayi(ham: string | null, varsayilan: number): number {
  const n = Number(ham);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : varsayilan;
}

function Tezgah() {
  const q = useSearchParams();
  const blokSayisi = sayi(q.get("blok"), 4);
  const katSayisi = sayi(q.get("kat"), 8);
  const katBasi = sayi(q.get("katbasi"), 6);

  const bloklar: SahneBlogu[] = useMemo(
    () =>
      Array.from({ length: blokSayisi }, (_, b) => ({
        id: `b${b}`,
        ad: `B${b + 1}`,
        daireler: Array.from({ length: katSayisi * katBasi }, (_, i) => ({
          id: `b${b}-d${i}`,
          no: String(i + 1),
          kat: Math.floor(i / katBasi),
          sira: i % katBasi,
          // Her onuncu daire alarmli: ornek-basina renk yolu da olculsun.
          durum: i % 10 === 0 ? ALARM : NORMAL,
        })),
      })),
    [blokSayisi, katSayisi, katBasi],
  );

  const toplam = blokSayisi * katSayisi * katBasi;

  return (
    <main className="h-screen w-screen">
      <p data-testid="olcum-ozet" className="p-2 text-sm">
        {blokSayisi} · {katSayisi} · {katBasi} · {toplam}
      </p>
      <div className="h-[calc(100vh-40px)] w-full">
        <BinaSahnesiYukleyici bloklar={bloklar} yukseklik="100%" />
      </div>
    </main>
  );
}

export default function OlcumSahnePage() {
  // URETIMDE YOK.
  if (process.env.NODE_ENV !== GELISTIRME) notFound();
  return (
    <Suspense>
      <Tezgah />
    </Suspense>
  );
}
