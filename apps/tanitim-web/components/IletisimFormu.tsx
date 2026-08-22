"use client";

import { useState } from "react";

import { ILETISIM_EPOSTA } from "@/config/site";
import { HataDurumu } from "./HataDurumu";

/**
 * (P177 §2) ILETISIM FORMU.
 *
 * TELEFON VEYA E-POSTA ZORUNLU — backend semasi (`TanitimIletisimIstek`)
 * ikisinden birini ariyor. Kural ISTEMCIDE DE var ki kullanici formu
 * doldurup gonderdikten sonra sunucu hatasi gormesin; ama ASIL KAPI
 * backend'dedir (istemci dogrulamasi atlanabilir).
 */
export function IletisimFormu() {
  const [ad, setAd] = useState("");
  const [eposta, setEposta] = useState("");
  const [telefon, setTelefon] = useState("");
  const [mesaj, setMesaj] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderildi, setGonderildi] = useState(false);
  const [gonderiliyor, setGonderiliyor] = useState(false);

  async function gonder(olay: React.FormEvent) {
    olay.preventDefault();
    setHata(null);
    if (!eposta.trim() && !telefon.trim()) {
      setHata("Size dönebilmemiz için e-posta ya da telefon bilgisi gerekiyor.");
      return;
    }
    setGonderiliyor(true);
    try {
      const yanit = await fetch("/api/iletisim", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          ad,
          email: eposta.trim() || null,
          telefon: telefon.trim() || null,
          mesaj,
          dil: "tr",
        }),
      });
      if (!yanit.ok) {
        // ZARF: `{ error: { code, message } }` — backend ve BFF ayni bicimi
        // kullanir (bkz. `lib/backend.ts::hataZarfi`).
        const veri = (await yanit.json().catch(() => ({}))) as {
          error?: { message?: string };
        };
        setHata(
          yanit.status === 429
            ? "Kısa sürede çok fazla mesaj gönderildi. Lütfen bir süre sonra tekrar deneyin."
            : veri.error?.message?.trim() ||
              "Mesaj gönderilemedi. Lütfen bilgileri kontrol edip tekrar deneyin.",
        );
        return;
      }
      setGonderildi(true);
    } catch {
      setHata("Sunucuya ulaşılamadı. Lütfen birazdan tekrar deneyin.");
    } finally {
      setGonderiliyor(false);
    }
  }

  if (gonderildi) {
    return (
      <div className="kart">
        <p className="etiket">Alındı</p>
        <p className="mt-3 font-semibold text-baslik">Mesajınız bize ulaştı.</p>
        <p className="mt-2 text-kucuk text-soluk">
          Bıraktığınız iletişim bilgisinden en kısa sürede döneceğiz.
        </p>
      </div>
    );
  }

  return (
    <form className="kart space-y-4" onSubmit={gonder}>
      <div>
        <label className="alan-etiket" htmlFor="i-ad">Ad Soyad</label>
        <input id="i-ad" className="alan" required minLength={2} maxLength={150}
          value={ad} onChange={(e) => setAd(e.target.value)} />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label className="alan-etiket" htmlFor="i-eposta">E-posta</label>
          <input id="i-eposta" className="alan" type="email" maxLength={200}
            value={eposta} onChange={(e) => setEposta(e.target.value)} />
        </div>
        <div>
          <label className="alan-etiket" htmlFor="i-telefon">Telefon</label>
          <input id="i-telefon" className="alan" type="tel" maxLength={40}
            value={telefon} onChange={(e) => setTelefon(e.target.value)} />
        </div>
      </div>
      <p className="text-kucuk text-soluk">
        E-posta ya da telefondan en az birini yazın; size oradan döneriz.
      </p>
      <div>
        <label className="alan-etiket" htmlFor="i-mesaj">Mesajınız</label>
        <textarea id="i-mesaj" className="alan min-h-32" required minLength={5} maxLength={5000}
          value={mesaj} onChange={(e) => setMesaj(e.target.value)} />
      </div>
      <HataDurumu mesaj={hata} />
      <button className="dugme-birincil w-full sm:w-auto" type="submit" disabled={gonderiliyor}>
        {gonderiliyor ? "Gönderiliyor…" : "Mesajı gönder"}
      </button>
      <p className="text-kucuk text-soluk">
        Doğrudan yazmak isterseniz:{" "}
        <a className="font-semibold text-mavi underline" href={`mailto:${ILETISIM_EPOSTA}`}>
          {ILETISIM_EPOSTA}
        </a>
      </p>
    </form>
  );
}
