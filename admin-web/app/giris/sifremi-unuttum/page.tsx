"use client";

// (P181 Bölüm 2 + prod düzeltmeleri A–D) ŞİFREMİ UNUTTUM — e-posta ile parola
// sıfırlama. E-POSTA TABANLI, SMS YOK. İki adım: (1) tesis + e-posta ->
// kod-iste (SIZINTISIZ: hesap var/yok/doğrulanmamış AYNI yanıt), (2) kod + yeni
// parola -> dogrula-ve-ayarla -> girişe dön. Public (pre-auth) — BFF uçlarına
// düz fetch.
//
// (B) GÖRSEL: giriş ekranıyla aynı vitrin (`GirisKabuk`) — orbital arka plan +
//     marka + sol tanıtım. Beyaz-zemin-tek-kart yerine.
// (C) DOĞRULAMA: tesis (slug) biçimi + e-posta biçimi İSTEMCİDE denetlenir;
//     hatalı alan KIRMIZI. Bu yalnız BİÇİM denetimidir — hesabın var olup
//     olmadığını SIZDIRMAZ (o denetim sunucuda ve sessizdir).
// (D) İLK KULLANIM: açıklama, yalnız doğrulanmış e-postalı hesaplara kod
//     gittiğini (hesap varlığını sızdırmadan) anlatır.

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

import { ParolaAlani } from "@/components/ParolaAlani";
import { CTA_GRADYANI } from "@/components/giris/stil";
import {
  GirisKabuk,
  METIN,
  METIN_IKINCIL,
  METIN_SOLUK,
  girisAlanSinifi,
  girisAlanStili,
  girisEtiketSinifi,
  girisEtiketStili,
} from "@/components/giris/kabuk";
import { useT } from "@/lib/i18n/kullan";

const UC_ISTE = "/api/auth/sifre/kod-iste";
const UC_AYARLA = "/api/auth/sifre/dogrula-ve-ayarla";

// (C) BİÇİM denetimi — yalnız istemcide. Slug backend'de `[a-z0-9-]`
// (slugify_tenant): küçük harf, rakam, tire; başta/sonda tire yok. E-posta
// için makul yapısal denetim. Hiçbiri "bu tesis/hesap var mı" bilgisini
// SIZDIRMAZ; yalnız girilen metnin biçimini denetler.
const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const EPOSTA_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

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
  // (C) Alan bazında biçim hatası — alanı kırmızı boyar + altında metin.
  const [tesisHata, setTesisHata] = useState<string | null>(null);
  const [epostaHata, setEpostaHata] = useState<string | null>(null);

  function tesisDenetle(v: string): boolean {
    const s = v.trim();
    if (!s || !SLUG_RE.test(s)) {
      setTesisHata(t("girisSlugGecersiz"));
      return false;
    }
    setTesisHata(null);
    return true;
  }
  function epostaDenetle(v: string): boolean {
    const s = v.trim();
    if (!s || !EPOSTA_RE.test(s)) {
      setEpostaHata(t("girisEpostaGecersiz"));
      return false;
    }
    setEpostaHata(null);
    return true;
  }

  async function kodIste(e: React.FormEvent) {
    e.preventDefault();
    setHata(null);
    // (C) GÖNDERİMDEN ÖNCE biçim denetimi — ikisi de geçmezse istek YOK.
    const okT = tesisDenetle(tesis);
    const okE = epostaDenetle(eposta);
    if (!okT || !okE) return;
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

  const ctaSinifi =
    "giris-cta odak-ters inline-flex w-full items-center justify-center gap-2 rounded-xl py-3 text-sm font-semibold transition-shadow disabled:opacity-70";
  const ctaStili: React.CSSProperties = {
    background: CTA_GRADYANI,
    color: "#04222A",
    boxShadow: "0 10px 30px rgba(20,200,190,0.20)",
  };

  return (
    <>
      <div>
        <h1 className="break-words text-xl font-semibold tracking-tight" style={{ color: METIN }}>
          {t("sifreSifirlaBaslik")}
        </h1>
        <p className="mt-1.5 text-sm leading-relaxed" style={{ color: METIN_SOLUK }}>
          {t("sifreSifirlaAciklama")}
        </p>
      </div>

      {adim === "bitti" ? (
        <div className="space-y-4">
          <p className="text-sm" style={{ color: METIN_IKINCIL }}>
            {t("sifreSifirlaBasarili")}
          </p>
          <button type="button" className={ctaSinifi} style={ctaStili} onClick={() => router.replace("/giris")}>
            {t("sifreSifirlaGirise")}
          </button>
        </div>
      ) : adim === "iste" ? (
        <form onSubmit={kodIste} className="space-y-5" noValidate>
          <label className="block">
            <span className={girisEtiketSinifi} style={girisEtiketStili}>
              {t("girisTesisSlug")}
            </span>
            <input
              className={`${girisAlanSinifi} giris-alan${tesisHata ? " giris-titre" : ""}`}
              style={girisAlanStili(!!tesisHata)}
              value={tesis}
              onChange={(e) => {
                setTesis(e.target.value);
                if (tesisHata) setTesisHata(null);
              }}
              onBlur={(e) => e.target.value.trim() && tesisDenetle(e.target.value)}
              autoComplete="organization"
              aria-invalid={!!tesisHata}
              placeholder="yonetio"
              required
            />
            {tesisHata && (
              <span className="mt-1.5 block text-xs" style={{ color: "#FFB4B4" }}>
                {tesisHata}
              </span>
            )}
          </label>

          <label className="block">
            <span className={girisEtiketSinifi} style={girisEtiketStili}>
              {t("girisEposta")}
            </span>
            <input
              className={`${girisAlanSinifi} giris-alan${epostaHata ? " giris-titre" : ""}`}
              style={girisAlanStili(!!epostaHata)}
              type="email"
              value={eposta}
              onChange={(e) => {
                setEposta(e.target.value);
                if (epostaHata) setEpostaHata(null);
              }}
              onBlur={(e) => e.target.value.trim() && epostaDenetle(e.target.value)}
              autoComplete="email"
              aria-invalid={!!epostaHata}
              required
            />
            {epostaHata && (
              <span className="mt-1.5 block text-xs" style={{ color: "#FFB4B4" }}>
                {epostaHata}
              </span>
            )}
          </label>

          {hata && <HataKutusu mesaj={hata} />}
          <button type="submit" className={ctaSinifi} style={ctaStili} disabled={yukleniyor}>
            {yukleniyor ? t("ortakKaydediliyor") : t("sifreSifirlaKodGonder")}
          </button>
        </form>
      ) : (
        <form onSubmit={parolayiKur} className="space-y-5">
          <p className="text-sm" style={{ color: METIN_IKINCIL }}>
            {t("sifreSifirlaGonderildi")}
          </p>
          <label className="block">
            <span className={girisEtiketSinifi} style={girisEtiketStili}>
              {t("girisKod")}
            </span>
            <input
              className={`${girisAlanSinifi} giris-alan`}
              style={girisAlanStili()}
              value={kod}
              onChange={(e) => setKod(e.target.value)}
              inputMode="numeric"
              autoComplete="one-time-code"
              required
            />
          </label>
          <label className="block">
            <span className={girisEtiketSinifi} style={girisEtiketStili}>
              {t("sifreSifirlaYeniParola")}
            </span>
            <ParolaAlani
              className={`${girisAlanSinifi} giris-alan`}
              style={girisAlanStili()}
              value={parola}
              onChange={setParola}
              autoComplete="new-password"
              minLength={8}
              required
            />
          </label>
          {hata && <HataKutusu mesaj={hata} />}
          <button type="submit" className={ctaSinifi} style={ctaStili} disabled={yukleniyor}>
            {yukleniyor ? t("ortakKaydediliyor") : t("sifreSifirlaKur")}
          </button>
        </form>
      )}

      <div className="text-center">
        <Link href="/giris" className="odak-ters text-xs underline" style={{ color: METIN_IKINCIL }}>
          {t("sifreSifirlaGirise")}
        </Link>
      </div>
    </>
  );
}

function HataKutusu({ mesaj }: { mesaj: string }) {
  return (
    <p
      role="alert"
      className="rounded-lg px-3 py-2 text-sm"
      style={{
        background: "rgba(220,80,80,0.12)",
        borderWidth: "1px",
        borderStyle: "solid",
        borderColor: "rgba(255,140,140,0.35)",
        color: "#FFC9C9",
      }}
    >
      {mesaj}
    </p>
  );
}

export default function SifremiUnuttumSayfasi() {
  return (
    <Suspense fallback={null}>
      <GirisKabuk>
        <SifirlamaFormu />
      </GirisKabuk>
    </Suspense>
  );
}
