"use client";

// (P181 Bölüm 2) ŞİFREMİ UNUTTUM — e-posta ile parola sıfırlama. E-POSTA
// TABANLI, SMS YOK. İki adım: (1) tesis + e-posta -> kod-iste (SIZINTISIZ:
// hesap var/yok/doğrulanmamış AYNI yanıt), (2) kod + yeni parola ->
// dogrula-ve-ayarla -> girişe dön. Public (pre-auth) — BFF uçlarına düz fetch.

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

import { ErrorBox, Field, btnPrimary, cardCls, inputCls } from "@/components/form";
import { ParolaAlani } from "@/components/ParolaAlani";
import { useT } from "@/lib/i18n/kullan";

const UC_ISTE = "/api/auth/sifre/kod-iste";
const UC_AYARLA = "/api/auth/sifre/dogrula-ve-ayarla";

function SifirlamaFormu() {
  const t = useT();
  const router = useRouter();
  const sp = useSearchParams();

  const [tesis, setTesis] = useState(sp.get("tesis") ?? "");
  const [eposta, setEposta] = useState(sp.get("eposta") ?? "");
  const [kod, setKod] = useState("");
  const [parola, setParola] = useState("");
  const [adim, setAdim] = useState<"iste" | "ayarla" | "bitti">("iste");
  const [hata, setHata] = useState<string | null>(null);
  const [yukleniyor, setYukleniyor] = useState(false);

  async function kodIste(e: React.FormEvent) {
    e.preventDefault();
    setHata(null);
    setYukleniyor(true);
    try {
      const r = await fetch(UC_ISTE, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ tenant_slug: tesis.trim(), eposta: eposta.trim() }),
      });
      // SIZINTISIZ: kod-iste yalnız hız sınırında (429) hata verir; aksi halde
      // hesap olsun olmasın AYNI 200. İkinci adıma her durumda geçilir.
      if (r.status === 429) {
        const d = await r.json().catch(() => null);
        setHata(d?.error?.message ?? t("girisBasarisiz"));
        return;
      }
      setAdim("ayarla");
    } catch {
      setHata(t("ortakHataOlustu"));
    } finally {
      setYukleniyor(false);
    }
  }

  async function parolayiKur(e: React.FormEvent) {
    e.preventDefault();
    setHata(null);
    setYukleniyor(true);
    try {
      const r = await fetch(UC_AYARLA, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          tenant_slug: tesis.trim(),
          eposta: eposta.trim(),
          kod: kod.trim(),
          yeni_parola: parola,
        }),
      });
      if (!r.ok) {
        const d = await r.json().catch(() => null);
        setHata(d?.error?.message ?? t("girisBasarisiz"));
        return;
      }
      setAdim("bitti");
    } catch {
      setHata(t("ortakHataOlustu"));
    } finally {
      setYukleniyor(false);
    }
  }

  return (
    <div className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-4 py-10">
      <div className={`${cardCls} p-6`}>
        <h1 className="mb-1 text-xl font-semibold text-metin">
          {t("sifreSifirlaBaslik")}
        </h1>
        <p className="mb-5 text-sm text-metin-muted">{t("sifreSifirlaAciklama")}</p>

        {adim === "bitti" ? (
          <div className="space-y-4">
            <p className="text-sm text-metin">{t("sifreSifirlaBasarili")}</p>
            <button
              type="button"
              className={btnPrimary}
              onClick={() => router.replace("/giris")}
            >
              {t("sifreSifirlaGirise")}
            </button>
          </div>
        ) : adim === "iste" ? (
          <form onSubmit={kodIste} className="space-y-4">
            <Field label={t("girisTesisSlug")}>
              <input
                className={inputCls}
                value={tesis}
                onChange={(e) => setTesis(e.target.value)}
                autoComplete="organization"
                required
              />
            </Field>
            <Field label={t("girisEposta")}>
              <input
                className={inputCls}
                type="email"
                value={eposta}
                onChange={(e) => setEposta(e.target.value)}
                autoComplete="email"
                required
              />
            </Field>
            <ErrorBox message={hata} />
            <button type="submit" className={btnPrimary} disabled={yukleniyor}>
              {yukleniyor ? t("ortakKaydediliyor") : t("sifreSifirlaKodGonder")}
            </button>
          </form>
        ) : (
          <form onSubmit={parolayiKur} className="space-y-4">
            <p className="text-sm text-metin-muted">{t("sifreSifirlaGonderildi")}</p>
            <Field label={t("girisKod")}>
              <input
                className={inputCls}
                value={kod}
                onChange={(e) => setKod(e.target.value)}
                inputMode="numeric"
                autoComplete="one-time-code"
                required
              />
            </Field>
            <Field label={t("sifreSifirlaYeniParola")}>
              <ParolaAlani
                className={inputCls}
                value={parola}
                onChange={setParola}
                autoComplete="new-password"
                minLength={8}
                required
              />
            </Field>
            <ErrorBox message={hata} />
            <button type="submit" className={btnPrimary} disabled={yukleniyor}>
              {yukleniyor ? t("ortakKaydediliyor") : t("sifreSifirlaKur")}
            </button>
          </form>
        )}

        <div className="mt-5 text-center">
          <Link href="/giris" className="text-xs underline text-metin-muted">
            {t("sifreSifirlaGirise")}
          </Link>
        </div>
      </div>
    </div>
  );
}

export default function SifremiUnuttumSayfasi() {
  return (
    <Suspense fallback={null}>
      <SifirlamaFormu />
    </Suspense>
  );
}
