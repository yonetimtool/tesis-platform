"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { DilSecici } from "@/components/DilSecici";
import { ErrorBox, btnGhost, btnPrimary, cardCls, inputCls } from "@/components/form";
import { YonetioLogo } from "@/components/YonetioLogo";
import { useT } from "@/lib/i18n/kullan";
import { telefonGiris, telefonHatasi, telefonNormalle } from "@/lib/telefon";

/**
 * (P154 / Asama 3) ROL SECIMLI KAYIT — web yuzeyi.
 *
 * BRIEF: web'de yalniz **Yonetici** ve **Denetci**. Mobil dort rol sunar
 * (sakin, guvenlik, tesis gorevlisi de) ve o AYRI bir yuzeydir; burada
 * gostermek, telefonda yapilacak isi masaustune cagirmak olurdu.
 *
 * KUME NEDEN ISTEMCIDE: sunucu bes rolu de kabul eder ve GERCEK kapi
 * "tesis ID + telefon onceden tanimli kayitla eslesiyor mu" kontroludur —
 * bir sakin buradan `yonetici` secse bile eslesmedigi icin kod ALAMAZ.
 * Yani bu liste bir GUVENLIK siniri degil, bir UX secimidir; ikisini
 * karistirmamak icin yaziya dokuldu.
 *
 * DORT ADIM: rol -> tesis+telefon -> kod -> parola. Tek sayfada dort
 * form yerine adimlar, cunku kullanicinin elindeki bilgi de sirayla
 * geliyor (kodu ancak telefonu girdikten sonra aliyor).
 */

type Adim = "rol" | "kimlik" | "kod" | "parola";
type Rol = "yonetici" | "denetci";

const UC_BASLA = "/api/auth/kayit/rol-basla";
const UC_DOGRULA = "/api/auth/kayit/rol-dogrula";
const UC_PAROLA = "/api/auth/set-password";

interface HataGovdesi {
  error?: { message?: string };
}

async function gonder(uc: string, govde: unknown): Promise<unknown> {
  const r = await fetch(uc, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(govde),
  });
  const veri = (await r.json().catch(() => null)) as HataGovdesi | null;
  if (!r.ok) {
    // SUNUCU METNI AYNEN GOSTERILIR: "adimlari ayirt ETTIRMEYEN" cumleyi
    // burada yeniden yazmak, sunucunun bilincli belirsizligini bozardi.
    throw new Error(veri?.error?.message ?? String(r.status));
  }
  return veri;
}

export default function KayitSayfasi() {
  const t = useT();
  const router = useRouter();

  const [adim, setAdim] = useState<Adim>("rol");
  const [rol, setRol] = useState<Rol>("yonetici");
  const [tesisKodu, setTesisKodu] = useState("");
  const [telefon, setTelefon] = useState("");
  const [kod, setKod] = useState("");
  const [parola, setParola] = useState("");
  const [parola2, setParola2] = useState("");
  const [tesisAd, setTesisAd] = useState("");
  const [telefonMaskeli, setTelefonMaskeli] = useState("");
  const [jeton, setJeton] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);

  const adimNo = { rol: 1, kimlik: 2, kod: 3, parola: 4 }[adim];

  async function kimlikGonder(e: React.FormEvent) {
    e.preventDefault();
    // `telefonHatasi` KIMLIK doner (metin degil) — cevirisi burada
    // cozulur; GirisFormu ile AYNI esleme kullaniliyor ki iki ekran ayni
    // numaraya farkli sey demesin.
    const telHata = telefonHatasi(telefon);
    if (telHata) {
      setHata(telHata === "gecersizOnEk" ? t("telefonHataOnEk") : t("telefonHataEksik"));
      return;
    }
    setBekliyor(true);
    setHata(null);
    try {
      const y = (await gonder(UC_BASLA, {
        rol,
        tesis_kodu: tesisKodu.trim(),
        telefon: telefonNormalle(telefon),
      })) as { tesis_ad: string; telefon_maskeli: string };
      setTesisAd(y.tesis_ad);
      setTelefonMaskeli(y.telefon_maskeli);
      setAdim("kod");
    } catch (err) {
      setHata(err instanceof Error ? err.message : String(err));
    } finally {
      setBekliyor(false);
    }
  }

  async function kodGonder(e: React.FormEvent) {
    e.preventDefault();
    setBekliyor(true);
    setHata(null);
    try {
      const y = (await gonder(UC_DOGRULA, {
        telefon: telefonNormalle(telefon),
        kod: kod.trim(),
      })) as { setup_token: string };
      setJeton(y.setup_token);
      setAdim("parola");
    } catch (err) {
      setHata(err instanceof Error ? err.message : String(err));
    } finally {
      setBekliyor(false);
    }
  }

  async function parolaGonder(e: React.FormEvent) {
    e.preventDefault();
    if (parola !== parola2) {
      setHata(t("kayitParolaUyusmuyor"));
      return;
    }
    setBekliyor(true);
    setHata(null);
    try {
      await gonder(UC_PAROLA, { setup_token: jeton, new_password: parola });
      // Cerezler BFF'te yazildi; kok rota rolu cozup dogru sayfaya atar.
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
        <YonetioLogo size={32} />
        <DilSecici />
      </div>

      <div>
        <p className="text-xs font-medium text-metin-muted">
          {t("kayitAdim", { n: String(adimNo) })}
        </p>
        <h1 className="mt-1 text-2xl font-semibold">{t("kayitBaslik")}</h1>
      </div>

      <ErrorBox message={hata} />

      {adim === "rol" && (
        <div className="space-y-3">
          <p className="text-sm text-metin-body">{t("kayitAltBaslik")}</p>
          {(
            [
              ["yonetici", t("kayitRolYonetici"), t("kayitRolAciklamaYonetici")],
              ["denetci", t("kayitRolDenetci"), t("kayitRolAciklamaDenetci")],
            ] as const
          ).map(([deger, baslik, aciklama]) => (
            <button
              key={deger}
              type="button"
              // 44pt dokunma hedefi (erisilebilirlik kurali) — `py-3` +
              // metin yuksekligi bunu asiyor.
              // SECILI HÂL RENKLE DEGIL, KENARLA + halkayla anlatiliyor:
              // ham Tailwind rengi kullanmak koyu temada devrilmemis bir
              // yuzey birakirdi (`tests/koyu-tema.test.ts` bunu reddediyor)
              // ve tema tek yerden (globals.css) yonetiliyor.
              className={`${cardCls} w-full px-4 py-3 text-start transition hover:bg-yuzey-divider ${
                rol === deger ? "ring-2 ring-primary" : ""
              }`}
              aria-pressed={rol === deger}
              onClick={() => {
                setRol(deger);
                setAdim("kimlik");
              }}
            >
              <span className="block font-medium">{baslik}</span>
              <span className="block text-sm text-metin-muted">{aciklama}</span>
            </button>
          ))}
        </div>
      )}

      {adim === "kimlik" && (
        <form onSubmit={kimlikGonder} className="space-y-4">
          <label className="block">
            <span className="text-sm font-medium">{t("kayitTesisKodu")}</span>
            <input
              className={`${inputCls} mt-1`}
              value={tesisKodu}
              onChange={(e) => setTesisKodu(e.target.value)}
              required
              minLength={4}
              autoFocus
              autoComplete="off"
            />
            <span className="mt-1 block text-xs text-metin-muted">
              {t("kayitTesisKoduIpucu")}
            </span>
          </label>
          <label className="block">
            <span className="text-sm font-medium">{t("kayitTelefon")}</span>
            <input
              className={`${inputCls} mt-1`}
              value={telefonGiris(telefon)}
              onChange={(e) => setTelefon(telefonGiris(e.target.value))}
              required
              inputMode="tel"
              autoComplete="tel"
            />
          </label>
          <div className="flex gap-2">
            <button
              type="submit"
              disabled={bekliyor}
              className={`${btnPrimary} flex-1 py-3`}
            >
              {t("kayitDevam")}
            </button>
            <button
              type="button"
              className={`${btnGhost} px-4 py-3`}
              onClick={() => setAdim("rol")}
            >
              {t("kayitGeri")}
            </button>
          </div>
        </form>
      )}

      {adim === "kod" && (
        <form onSubmit={kodGonder} className="space-y-4">
          <h2 className="font-medium">{t("kayitKodBaslik")}</h2>
          {/* METIN BILEREK BELIRSIZ: sunucu numaranin kayitli olup
              olmadigini SOYLEMIYOR (tarama araci olmasin diye). Ekranin
              "kod gonderildi" demesi o korumayi bozardi; bunun yerine
              kodun GELMEYEBILECEGI yaziyor. */}
          <p className="text-sm text-metin-body">
            {t("kayitKodAciklama", { tesis: tesisAd, telefon: telefonMaskeli })}
          </p>
          <label className="block">
            <span className="text-sm font-medium">{t("kayitKodAlani")}</span>
            <input
              className={`${inputCls} mt-1 tracking-widest`}
              value={kod}
              onChange={(e) => setKod(e.target.value)}
              required
              inputMode="numeric"
              autoComplete="one-time-code"
              autoFocus
            />
          </label>
          <div className="flex gap-2">
            <button
              type="submit"
              disabled={bekliyor}
              className={`${btnPrimary} flex-1 py-3`}
            >
              {t("kayitDevam")}
            </button>
            <button
              type="button"
              className={`${btnGhost} px-4 py-3`}
              onClick={() => setAdim("kimlik")}
            >
              {t("kayitGeri")}
            </button>
          </div>
        </form>
      )}

      {adim === "parola" && (
        <form onSubmit={parolaGonder} className="space-y-4">
          <h2 className="font-medium">{t("kayitParolaBaslik")}</h2>
          <label className="block">
            <span className="text-sm font-medium">{t("kayitParola")}</span>
            <input
              type="password"
              className={`${inputCls} mt-1`}
              value={parola}
              onChange={(e) => setParola(e.target.value)}
              required
              minLength={8}
              autoComplete="new-password"
              autoFocus
            />
          </label>
          <label className="block">
            <span className="text-sm font-medium">{t("kayitParolaTekrar")}</span>
            <input
              type="password"
              className={`${inputCls} mt-1`}
              value={parola2}
              onChange={(e) => setParola2(e.target.value)}
              required
              minLength={8}
              autoComplete="new-password"
            />
          </label>
          <button
            type="submit"
            disabled={bekliyor}
            className={`${btnPrimary} w-full py-3`}
          >
            {t("kayitTamamla")}
          </button>
        </form>
      )}

      <Link href="/login" className="text-center text-sm text-primary underline">
        {t("kayitGirisLinki")}
      </Link>
    </main>
  );
}
