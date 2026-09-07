"use client";

import { useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

import { api, hataMetni } from "@/lib/istemci";

/**
 * SIKAYET FORMU — KIMLIKSIZ.
 *
 * Giris istemiyoruz ve bu bilinçli: dolandirilan bir kullanicinin
 * Dukkan hesabi OLMAYABILIR (numarayi profilden alip telefonla aramis
 * olabilir). Kimlik zorunlu olsaydi en cok duyulmasi gereken ses
 * kesilirdi.
 *
 * `iletisim` alani opsiyonel ve NEDEN istendigi yazili — zorunlu
 * yapmak, anonim kalmak isteyen kisiyi sikayet etmekten caydirirdi.
 */
export default function SikayetSayfa() {
  return (
    <Suspense
      fallback={<main className="mx-auto max-w-lg px-4 py-12">Yükleniyor…</main>}
    >
      <Sikayet />
    </Suspense>
  );
}

const TIPLER: [string, string][] = [
  ["odeme", "Ödeme / kapora"],
  ["hizmet", "Hizmet kalitesi"],
  ["sahte_isletme", "Sahte işletme şüphesi"],
  ["yorum", "Yorumla ilgili"],
  ["kisisel_veri", "Kişisel verilerim"],
  ["diger", "Diğer"],
];

function Sikayet() {
  const isletme = useSearchParams().get("isletme") ?? "";
  const [tip, setTip] = useState("odeme");
  const [metin, setMetin] = useState("");
  const [iletisim, setIletisim] = useState("");
  const [gonderildi, setGonderildi] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [bekle, setBekle] = useState(false);

  async function gonder(e: React.FormEvent) {
    e.preventDefault();
    setHata(null);
    setBekle(true);
    try {
      await api("/sikayet", {
        metot: "POST",
        govde: {
          tip,
          metin,
          isletme_slug: isletme || undefined,
          iletisim: iletisim || undefined,
        },
      });
      setGonderildi(true);
    } catch (h) {
      setHata(hataMetni(h));
    } finally {
      setBekle(false);
    }
  }

  if (gonderildi) {
    return (
      <main className="mx-auto max-w-lg px-4 py-12">
        <h1 className="text-2xl font-bold text-marka-koyu">Şikâyetiniz alındı</h1>
        <p className="mt-3 text-[color:var(--dk-metin-soluk)]">
          İnceleyip gereğini yapacağız. İletişim bilgisi bıraktıysanız sonucu
          size bildireceğiz.
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-lg px-4 py-12">
      <h1 className="text-2xl font-bold text-marka-koyu">Şikâyet bildir</h1>
      <p className="mt-2 text-sm text-[color:var(--dk-metin-soluk)]">
        Hesabınız olmasa da şikâyet bildirebilirsiniz.
      </p>

      <form onSubmit={gonder} className="mt-6 space-y-4">
        {isletme && (
          <p className="rounded bg-[color:var(--dk-zemin-alt)] px-3 py-2 text-sm">
            İşletme: <strong>{isletme}</strong>
          </p>
        )}
        <label className="block">
          <span className="text-sm font-medium">Konu *</span>
          <select
            value={tip}
            onChange={(e) => setTip(e.target.value)}
            className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
          >
            {TIPLER.map(([d, ad]) => (
              <option key={d} value={d}>
                {ad}
              </option>
            ))}
          </select>
        </label>
        <label className="block">
          <span className="text-sm font-medium">Ne oldu? *</span>
          <textarea
            required
            minLength={10}
            rows={6}
            value={metin}
            onChange={(e) => setMetin(e.target.value)}
            className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
          />
        </label>
        <label className="block">
          <span className="text-sm font-medium">
            İletişim (isteğe bağlı)
          </span>
          <input
            value={iletisim}
            onChange={(e) => setIletisim(e.target.value)}
            placeholder="Telefon veya e-posta"
            className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
          />
          <span className="mt-1 block text-xs text-[color:var(--dk-metin-soluk)]">
            Yalnızca sonucu size bildirebilmek için. Boş bırakabilirsiniz.
          </span>
        </label>
        <button
          type="submit"
          disabled={bekle}
          className="w-full rounded bg-marka px-4 py-3 font-medium text-white disabled:opacity-60"
        >
          {bekle ? "Gönderiliyor…" : "Şikâyeti gönder"}
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
