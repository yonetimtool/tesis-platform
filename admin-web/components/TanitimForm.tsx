"use client";

// (P127.2) TANITIM SITESI ILETISIM FORMU.
//
// ONCEKI TUR BURAYA `mailto:` KOYMUSTU ve bunu acikca "kalan is" diye
// yazmisti: kabul kriteri "form TESLIM EDIYOR" diyordu. `mailto:`
// ziyaretcinin e-posta istemcisine bagimlidir — kurulu istemcisi olmayan
// (ya da web posta kullanan) biri icin hicbir sey olmaz.
//
// TESLIMAT ZINCIRI: form -> BFF -> `POST /public/tanitim-iletisim` ->
// veritabani (KAYIT ONCE) -> e-posta DENEMESI. Kayit atildigi icin SMTP
// yapilandirilmamis olsa bile mesaj KAYBOLMAZ; platform admini panelden
// gorur.
//
// DURUMLAR EKRANDA: gonderiliyor / gonderildi / hata. "Hicbir sey olmadi"
// hâli birakilmadi — bir iletisim formunda en pahali sonuc, kullanicinin
// mesajinin gidip gitmedigini bilememesidir.
import { useState } from "react";

import { useT } from "@/lib/i18n/kullan";
import { useI18n } from "@/lib/i18n/kullan";

type Durum = "hazir" | "gonderiliyor" | "gonderildi" | "hata";

export function TanitimForm() {
  const t = useT();
  const { dil } = useI18n();
  const [durum, setDurum] = useState<Durum>("hazir");
  const [hata, setHata] = useState<string | null>(null);

  async function gonder(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const veri = new FormData(e.currentTarget);
    setDurum("gonderiliyor");
    setHata(null);
    try {
      const res = await fetch("/api/tanitim-iletisim", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          ad: String(veri.get("ad") ?? ""),
          email: String(veri.get("email") ?? "") || null,
          telefon: String(veri.get("telefon") ?? "") || null,
          mesaj: String(veri.get("mesaj") ?? ""),
          dil,
        }),
      });
      if (!res.ok) {
        const govde = (await res.json().catch(() => null)) as
          | { error?: { message?: string } }
          | null;
        // SUNUCU METNI ONCE: hiz siniri (429) ve dogrulama (422) kendi
        // cumlesini istegin dilinde doner; genel metin yalniz yedektir.
        setHata(govde?.error?.message ?? t("tanitimFormHata"));
        setDurum("hata");
        return;
      }
      setDurum("gonderildi");
    } catch {
      setHata(t("ortakSunucuyaUlasilamadi"));
      setDurum("hata");
    }
  }

  if (durum === "gonderildi") {
    return (
      <p
        role="status"
        className="rounded-kart border border-accent-green/30 bg-accent-green/12 px-4 py-3 text-sm text-vurguInk-green"
      >
        {t("tanitimFormTesekkur")}
      </p>
    );
  }

  const alan =
    "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-ink outline-none focus:border-primary";

  return (
    <form onSubmit={gonder} className="mt-4 grid max-w-2xl gap-3 sm:grid-cols-2">
      <label className="block text-sm">
        <span className="mb-1 block font-medium">{t("tanitimFormAd")}</span>
        <input name="ad" required minLength={2} maxLength={150} className={alan} />
      </label>
      <label className="block text-sm">
        <span className="mb-1 block font-medium">{t("tanitimFormEposta")}</span>
        <input name="email" type="email" maxLength={200} className={alan} />
      </label>
      <label className="block text-sm">
        <span className="mb-1 block font-medium">{t("tanitimFormTelefon")}</span>
        <input name="telefon" maxLength={40} className={alan} />
      </label>
      <span className="hidden sm:block" />
      <label className="block text-sm sm:col-span-2">
        <span className="mb-1 block font-medium">{t("tanitimFormMesaj")}</span>
        <textarea
          name="mesaj"
          required
          minLength={5}
          maxLength={5000}
          rows={4}
          className={alan}
        />
      </label>
      {/* DONUS YOLU KURALI EKRANDA YAZILI: sunucu telefon VEYA e-posta
          istiyor; kullanici bunu gondermeden ONCE bilmeli. */}
      <p className="text-satiralt text-metin-mutedBg sm:col-span-2">
        {t("tanitimFormDonusYolu")}
      </p>
      {hata ? (
        <p role="alert" className="text-satiralt text-vurguInk-red sm:col-span-2">
          {hata}
        </p>
      ) : null}
      <div className="sm:col-span-2">
        <button
          type="submit"
          disabled={durum === "gonderiliyor"}
          className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
        >
          {durum === "gonderiliyor" ? t("tanitimFormGonderiliyor") : t("tanitimFormGonder")}
        </button>
      </div>
    </form>
  );
}
