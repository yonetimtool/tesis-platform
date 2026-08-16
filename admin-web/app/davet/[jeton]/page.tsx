"use client";

/**
 * (P155 §7/§8) DAVET WEB YEDEGI — `https://<portal>/davet/‹jeton›`.
 *
 * IKI ISI BIRDEN:
 *   1. Uygulama KURULU DEGILSE (masaustu ya da app'siz mobil) kayit
 *      TARAYICIDA tamamlanir: jeton cozulur, kullanici yontem secer.
 *   2. Magaza dugmeleri: mobil kullanici uygulamayi indirebilir. (Derin
 *      baglanti kuruluysa iOS/Android bu sayfayi HIC gormeden dogrudan
 *      uygulamayi acar — bu sayfa yalniz YEDEKTIR.)
 *
 * JETON DUZ METIN PARAMETRE DEGIL: tesis kodu/daire URL'de TASINMAZ; onlar
 * jetonun ARKASINDA, sunucuda cozulur (sartname §7). Sayfa yalniz jetonu
 * backend'e verir ve cozulmus baglami alir.
 *
 * SOSYAL YONTEM: saglayiciya tam yonlendirme var; donuste `/giris/oauth`
 * jetonu `sessionStorage`dan okuyup `/davet/sosyal` ile tamamlar (kayit
 * akisindaki `kayitTaslagi` mekanizmasinin aynisi).
 */
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { DilSecici } from "@/components/DilSecici";
import { ErrorBox, btnGhost, btnPrimary, cardCls, inputCls } from "@/components/form";
import { ParolaAlani } from "@/components/ParolaAlani";
import { SosyalGiris } from "@/components/SosyalGiris";
import { YonetioLogo } from "@/components/YonetioLogo";
import { useT } from "@/lib/i18n/kullan";
import { APP_STORE_URL, PLAY_URL, platformSez } from "@/lib/magaza";

/** Rol kimliginden cevrilebilir etiket anahtari (dinamik `t()` anahtari
 *  yerine sabit esleme — i18n tipi bilinmeyen anahtari reddeder). */
const ROL_ANAHTARI: Record<string, string> = {
  yonetici: "kayitRolYonetici",
  resident: "kayitRolSakin",
  security: "kayitRolGuvenlik",
  tesis_gorevlisi: "kayitRolTesisGorevlisi",
  denetci: "kayitRolDenetci",
};

type Durum = "yukleniyor" | "gecerli" | "gecersiz" | "parola";

interface Cozum {
  tesis_ad: string;
  rol: string;
  ad: string;
  telefon_maskeli: string;
  daire_no: string | null;
}

const UC_COZ = "/api/auth/davet/coz";
const UC_PAROLA = "/api/auth/davet/parola";

export default function DavetSayfasi() {
  const t = useT();
  const router = useRouter();
  const params = useParams<{ jeton: string }>();
  const jeton = decodeURIComponent(params.jeton);

  const [durum, setDurum] = useState<Durum>("yukleniyor");
  const [cozum, setCozum] = useState<Cozum | null>(null);
  const [hataKodu, setHataKodu] = useState<string | null>(null);
  const [ad, setAd] = useState("");
  const [parola, setParola] = useState("");
  const [parola2, setParola2] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);

  useEffect(() => {
    let iptal = false;
    void (async () => {
      try {
        const r = await fetch(UC_COZ, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ jeton }),
        });
        const veri = (await r.json().catch(() => null)) as
          | (Cozum & { error?: { code?: string } })
          | null;
        if (iptal) return;
        if (!r.ok) {
          // 410 = suresi doldu / kullanilmis; 404 = bulunamadi. Kodu
          // sakla ki gecersiz ekrani DOGRU metni gostersin.
          setHataKodu(veri?.error?.code ?? String(r.status));
          setDurum("gecersiz");
          return;
        }
        setCozum(veri as Cozum);
        setAd((veri as Cozum).ad ?? "");
        setDurum("gecerli");
      } catch {
        if (!iptal) {
          setHataKodu("network");
          setDurum("gecersiz");
        }
      }
    })();
    return () => {
      iptal = true;
    };
  }, [jeton]);

  async function parolaGonder(e: React.FormEvent) {
    e.preventDefault();
    if (parola !== parola2) {
      setHata(t("kayitParolaUyusmuyor"));
      return;
    }
    setBekliyor(true);
    setHata(null);
    try {
      const r = await fetch(UC_PAROLA, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ jeton, ad: ad.trim() || undefined, new_password: parola }),
      });
      if (!r.ok) {
        const veri = (await r.json().catch(() => null)) as
          | { error?: { message?: string } }
          | null;
        throw new Error(veri?.error?.message ?? String(r.status));
      }
      // Cerezler yazildi; kok rota rolu cozup dogru sayfaya atar.
      router.replace("/");
      router.refresh();
    } catch (err) {
      setHata(err instanceof Error ? err.message : String(err));
      setBekliyor(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-md flex-col justify-center gap-6 px-5 py-10">
      <div className="flex items-center justify-between">
        <YonetioLogo size={40} />
        <DilSecici />
      </div>

      {durum === "yukleniyor" && (
        <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
      )}

      {durum === "gecersiz" && (
        <div className={`${cardCls} space-y-4 p-6`}>
          <h1 className="text-xl font-semibold">{t("davetGecersizBaslik")}</h1>
          <p className="text-sm text-metin-body">
            {hataKodu === "davet_suresi_doldu"
              ? t("davetSuresiDoldu")
              : hataKodu === "davet_kullanilmis"
                ? t("davetKullanilmis")
                : t("davetBulunamadi")}
          </p>
          {/* Yoneticiye yeniden davet gonderttiren yol: kullanici onu arar.
              (Panelde yonetici gitmeyeni gorup yeniden gonderebilir.) */}
          <p className="text-sm text-metin-muted">{t("davetYoneticinizeBasvurun")}</p>
          <MagazaDugmeleri />
        </div>
      )}

      {durum === "gecerli" && cozum && (
        <div className="space-y-5">
          <div>
            <h1 className="text-2xl font-semibold">{t("davetBaslik")}</h1>
            <p className="mt-1 text-sm text-metin-body">
              {t("davetOzet", {
                tesis: cozum.tesis_ad,
                rol: ROL_ANAHTARI[cozum.rol]
                  ? t(ROL_ANAHTARI[cozum.rol] as Parameters<typeof t>[0])
                  : cozum.rol,
              })}
            </p>
            <dl className="mt-3 space-y-1 text-sm">
              <div className="flex justify-between gap-4">
                <dt className="text-metin-muted">{t("davetTelefon")}</dt>
                <dd className="font-mono">{cozum.telefon_maskeli}</dd>
              </div>
              {cozum.daire_no ? (
                <div className="flex justify-between gap-4">
                  <dt className="text-metin-muted">{t("binaDaireNo")}</dt>
                  <dd>{cozum.daire_no}</dd>
                </div>
              ) : null}
            </dl>
          </div>

          <ErrorBox message={hata} />

          <div>
            <p className="mb-2 text-sm font-medium">{t("kayitYontemBaslik")}</p>
            <button
              type="button"
              className={`${btnPrimary} w-full py-3`}
              onClick={() => setDurum("parola")}
            >
              {t("kayitYontemParola")}
            </button>
            {/* Sosyal: davet jetonunu sakla, saglayiciya git; donuste
                `/giris/oauth` `/davet/sosyal` ile tamamlar. */}
            <div className="mt-3">
              <SosyalGiris niyet="giris" davetJetonu={jeton} />
            </div>
          </div>

          <MagazaDugmeleri />
        </div>
      )}

      {durum === "parola" && cozum && (
        <form onSubmit={parolaGonder} className="space-y-4">
          <h1 className="text-xl font-semibold">{t("kayitParolaBaslik")}</h1>
          <ErrorBox message={hata} />
          <label className="block">
            <span className="text-sm font-medium">{t("tesisAdSoyad")}</span>
            <input
              className={`${inputCls} mt-1`}
              value={ad}
              onChange={(e) => setAd(e.target.value)}
              autoComplete="name"
            />
          </label>
          <label className="block">
            <span className="text-sm font-medium">{t("kayitParola")}</span>
            <ParolaAlani
              className={`${inputCls} mt-1`}
              value={parola}
              onChange={setParola}
              required
              minLength={8}
              autoComplete="new-password"
            />
          </label>
          <label className="block">
            <span className="text-sm font-medium">{t("kayitParolaTekrar")}</span>
            <ParolaAlani
              className={`${inputCls} mt-1`}
              value={parola2}
              onChange={setParola2}
              required
              minLength={8}
              autoComplete="new-password"
            />
          </label>
          <div className="flex gap-2">
            <button type="submit" disabled={bekliyor} className={`${btnPrimary} flex-1 py-3`}>
              {t("kayitTamamla")}
            </button>
            <button
              type="button"
              className={`${btnGhost} px-4 py-3`}
              onClick={() => {
                setHata(null);
                setDurum("gecerli");
              }}
            >
              {t("kayitGeri")}
            </button>
          </div>
        </form>
      )}
    </main>
  );
}

/** Magaza dugmeleri — UST DUZEY bilesen (ic ice tanimlanirsa her render'da
 *  yeniden BAGLANIR ve efekt/durum sifirlanir). Platforma gore siralar. */
function MagazaDugmeleri() {
  const t = useT();
  // İlk kare sunucuda: `navigator` yok. Efekt sonrasi platform belli olur.
  const [platform, setPlatform] = useState<"ios" | "android" | "masaustu">("masaustu");
  useEffect(() => {
    setPlatform(platformSez(navigator.userAgent));
  }, []);

  const ios = APP_STORE_URL ? (
    <a href={APP_STORE_URL} className={`${btnGhost} block py-3 text-center`}>
      {t("davetAppStore")}
    </a>
  ) : null;
  const android = (
    <a href={PLAY_URL} className={`${btnGhost} block py-3 text-center`}>
      {t("davetPlayStore")}
    </a>
  );

  return (
    <div className="space-y-2 border-t kart-kenar pt-4">
      <p className="text-xs text-metin-muted">{t("davetUygulamaIndir")}</p>
      {/* Platforma gore SIRALA: kullanicinin magazasi ustte. */}
      {platform === "ios" ? (
        <>
          {ios}
          {android}
        </>
      ) : (
        <>
          {android}
          {ios}
        </>
      )}
    </div>
  );
}
