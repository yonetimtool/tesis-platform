import type { Metadata } from "next";
import Link from "next/link";

import { IsletmeKarti, type IsletmeOzet } from "@/components/IsletmeKarti";
import { sunucudanAl } from "@/lib/backend";

/**
 * ARAMA SONUCLARI — `noindex`.
 *
 * Filtre kombinasyonlari sonsuz sayida URL uretir ve her biri ayni
 * isletmeleri farkli siralarla gosterir. Indekslenirlerse KENDI bolge
 * sayfalarimizla yarisirlar (ic kopya icerik) — `robots.ts`te de yol
 * kapali, burada meta ile pekistiriliyor.
 */
export const metadata: Metadata = {
  title: "Arama",
  robots: { index: false, follow: true },
};

// Arama her istekte taze: filtreler kullaniciya ozel ve onbellege
// alinmasi yanlis sonuc gosterirdi.
export const dynamic = "force-dynamic";

type Sonuc = {
  items: IsletmeOzet[];
  /** (F8) SPONSORLU — organik `items`tan AYRI ANAHTAR.
   *
   * Sunucu ikisini bilerek ayirdi: karistirmak, kullanicinin "en iyi
   * sonuc" sandigi seyi satmak olurdu. Arayuz de ayri blokta gosterir. */
  sponsorlu?: IsletmeOzet[];
  toplam: number;
  sayfa: number;
  boyut: number;
};

export default async function Ara({
  searchParams,
}: {
  searchParams: Record<string, string | undefined>;
}) {
  const sorgu = new URLSearchParams();
  for (const k of ["il", "ilce", "mahalle", "kategori", "q", "sirala", "sayfa"]) {
    const v = searchParams[k];
    if (v) sorgu.set(k, v);
  }
  const d = await sunucudanAl<Sonuc>(`/dukkan/isletme-ara?${sorgu}`, 0);

  return (
    <main className="mx-auto max-w-4xl px-4 py-10">
      <h1 className="text-2xl font-bold text-marka-koyu">Arama sonuçları</h1>

      <form action="/ara" className="mt-6 flex flex-wrap gap-2">
        <input
          name="q"
          defaultValue={searchParams.q ?? ""}
          placeholder="İşletme adı"
          className="flex-1 rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
        />
        {["il", "ilce", "mahalle", "kategori"].map((k) =>
          searchParams[k] ? (
            <input key={k} type="hidden" name={k} value={searchParams[k]} />
          ) : null,
        )}
        <button className="rounded bg-marka px-4 py-2 text-white">Ara</button>
      </form>

      {d === null ? (
        // SESSIZ BASARISIZLIK YOK: bos liste cizip "sonuc yok" demek,
        // backend cokmusken kullaniciya YANLIS bilgi vermek olurdu.
        <p className="mt-8 rounded bg-red-50 px-3 py-2 text-sm text-red-800">
          Arama şu anda yapılamıyor. Lütfen birazdan tekrar deneyin.
        </p>
      ) : d.toplam === 0 ? (
        <div className="mt-8 rounded border border-[color:var(--dk-cizgi)] p-6">
          <h2 className="font-medium">Bu aramada işletme bulunamadı</h2>
          <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
            Bölgeni genişletmeyi deneyebilir ya da ihtiyacını anlatıp teklif
            isteyebilirsin — bölgende hizmet veren işletmelere ulaştırırız.
          </p>
          <Link
            href="/talep-olustur"
            className="mt-4 inline-block rounded bg-marka px-4 py-2 text-sm font-medium text-white"
          >
            Ücretsiz teklif al
          </Link>
        </div>
      ) : (
        <>
          <p className="mt-4 text-sm text-[color:var(--dk-metin-soluk)]">
            {d.toplam} işletme bulundu
          </p>
          {d.sponsorlu && d.sponsorlu.length > 0 && (
            <ul className="mt-4 space-y-3">
              {d.sponsorlu.map((i) => (
                <IsletmeKarti key={`sp-${i.slug}`} i={i} />
              ))}
            </ul>
          )}
          {/* AYRI BLOK, AYRI LISTE: sponsorlu sonuclar organik listenin
              USTUNDE ve gorsel olarak ayri. Ayni <ul> icine koymak,
              ayrimi yalniz rozete birakirdi. */}
          <ul className="mt-4 space-y-3">
            {d.items.map((i) => (
              <IsletmeKarti key={i.slug} i={i} />
            ))}
          </ul>
        </>
      )}
    </main>
  );
}
