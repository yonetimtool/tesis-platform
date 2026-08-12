"use client";

/**
 * (P154 / Asama 4) SOSYAL GIRIS DONUS EKRANI.
 *
 * Saglayici -> arka uc callback -> BURASI (`?oauth=<sonuc_id>`).
 *
 * JETON URL'DE GELMEZ: adres cubugunda yalniz tek kullanimlik bir kimlik
 * vardir; jeton `POST /api/auth/oauth/sonuc` ile httpOnly cereze yazilir
 * ve JS onu HIC gormez.
 *
 * UC OLASI SONUC:
 *   1. niyet="bagla"       -> acik oturuma yontem eklenir, profile donulur,
 *   2. durum="giris"       -> oturum acildi, koke gidilir,
 *   3. durum="baglama_gerekli" -> tesis kodu + telefon + SMS adimi.
 *
 * (3) BRIEF'IN MERKEZ KURALI: "sosyal hesap kimlik dogrulama YONTEMI,
 * eslesme anahtari degil". Google hesabi kim oldugunu soylemez; onu tesis
 * ID + telefon soyler ve SMS kanitlar.
 */
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";

import { ErrorBox, Field, btnPrimary, cardCls, inputCls } from "@/components/form";
import {
  OAUTH_NIYET,
  kayitBilgisiOku,
  saglayiciEtiketi,
} from "@/components/SosyalGiris";
import { useT } from "@/lib/i18n/kullan";
import { telefonGiris, telefonHatasi, telefonNormalle } from "@/lib/telefon";

type Sonuc = {
  durum?: string;
  saglayici?: string | null;
  eposta?: string | null;
  relay?: boolean;
  baglama_jetonu?: string | null;
  error?: { message?: string };
};

type Adim = "yukleniyor" | "tesis" | "kod" | "hata";

// BFF uclari ve niyet degerleri MODUL DUZEYINDE sabit: ucluda dizge
// yazmak `sabit-metin` taramasini (hakli olarak) tetikliyor — o tarama
// ucludeki her dizgeyi cevrilmemis metin adayi sayar.
const NIYET_BAGLA = "bagla";
const NIYET_GIRIS = "giris";
const UC_SONUC = "/api/auth/oauth/sonuc";
const UC_BAGLANTILAR = "/api/auth/oauth/baglantilarim";
const UC_BAGLAN_BASLA = "/api/auth/oauth/baglan/basla";
const UC_BAGLAN_DOGRULA = "/api/auth/oauth/baglan/dogrula";

type BaslaYanit = {
  tesis_ad?: string;
  telefon_maskeli?: string;
  error?: { message?: string };
};

function OauthDonus() {
  const t = useT();
  const router = useRouter();
  const arama = useSearchParams();
  const sonucId = arama.get("oauth");

  const [adim, setAdim] = useState<Adim>("yukleniyor");
  const [hata, setHata] = useState<string | null>(null);
  const [sonuc, setSonuc] = useState<Sonuc | null>(null);
  const [tesisKodu, setTesisKodu] = useState("");
  const [telefon, setTelefon] = useState("");
  const [tesisAd, setTesisAd] = useState("");
  const [maskeli, setMaskeli] = useState("");
  const [kod, setKod] = useState("");
  const [gonderiliyor, setGonderiliyor] = useState(false);

  // SONUC TEK KULLANIMLIKTIR: sunucu onu `getdel` ile tuketir. React 18
  // gelistirme modunda efektler IKI KEZ kosar ve ikinci cagri "gecersiz
  // oturum" alirdi — bu bayrak, kullanicinin sahte bir hata gormesini
  // engeller.
  const calisti = useRef(false);

  useEffect(() => {
    if (calisti.current) return;
    calisti.current = true;
    if (!sonucId) {
      setHata(t("sosyalOturumGecersiz"));
      setAdim("hata");
      return;
    }
    let niyet = NIYET_GIRIS;
    try {
      niyet = sessionStorage.getItem(OAUTH_NIYET) ?? NIYET_GIRIS;
      sessionStorage.removeItem(OAUTH_NIYET);
    } catch {
      // Depolama yoksa varsayilan giris.
    }
    void (async () => {
      const uc = niyet === NIYET_BAGLA ? UC_BAGLANTILAR : UC_SONUC;
      try {
        const r = await fetch(uc, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ sonuc_id: sonucId }),
        });
        const d = (await r.json().catch(() => null)) as Sonuc | null;
        if (!r.ok) {
          setHata(d?.error?.message ?? t("ortakHataOlustu"));
          setAdim("hata");
          return;
        }
        if (niyet === NIYET_BAGLA) {
          router.replace("/profil");
          return;
        }
        if (d?.durum === "baglama_gerekli") {
          setSonuc(d);
          setAdim("tesis");
          // (P154) KAYIT AKISINDAN GELINDIYSE tesis ID + telefon ZATEN
          // girilmisti; alanlari doldurup adimi KENDILIGINDEN gecelim.
          // Basarisiz olursa form dolu ve gorunur durumda kalir —
          // kullanici duzeltip yeniden deneyebilir.
          const saklanan = kayitBilgisiOku();
          if (saklanan) {
            setTesisKodu(saklanan.tesisKodu);
            setTelefon(saklanan.telefon);
            void tesisGonder({
              tesisKodu: saklanan.tesisKodu,
              telefon: saklanan.telefon,
              jeton: d.baglama_jetonu ?? undefined,
            });
          }
          return;
        }
        // `durum=giris`: cerez yazildi. KOKE gidilir, sabit bir sayfaya
        // degil — `/` middleware'de ROLE gore cozulur.
        router.replace("/");
        router.refresh();
      } catch {
        setHata(t("ortakSunucuyaUlasilamadi"));
        setAdim("hata");
      }
    })();
  }, [sonucId]); // eslint-disable-line react-hooks/exhaustive-deps

  /**
   * `acik` VERILEBILIR cunku bu islev iki yerden cagriliyor: kullanicinin
   * dugmesinden (durum okunur) ve kayit akisindan otomatik (durum HENUZ
   * yazilmadi — `setState` senkron degildir, ayni karede okunamaz).
   */
  async function tesisGonder(acik?: {
    tesisKodu: string;
    telefon: string;
    jeton?: string;
  }) {
    const kullanilanKod = (acik?.tesisKodu ?? tesisKodu).trim();
    const kullanilanTel = acik?.telefon ?? telefon;
    const th = telefonHatasi(kullanilanTel);
    if (th) {
      setHata(th === "gecersizOnEk" ? t("telefonHataOnEk") : t("telefonHataEksik"));
      return;
    }
    setHata(null);
    setGonderiliyor(true);
    try {
      const r = await fetch(UC_BAGLAN_BASLA, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          baglama_jetonu: acik?.jeton ?? sonuc?.baglama_jetonu,
          tesis_kodu: kullanilanKod,
          telefon: telefonNormalle(kullanilanTel),
        }),
      });
      const d = (await r.json().catch(() => null)) as BaslaYanit | null;
      if (!r.ok) {
        setHata(d?.error?.message ?? t("ortakHataOlustu"));
        return;
      }
      setTesisAd(d?.tesis_ad ?? "");
      setMaskeli(d?.telefon_maskeli ?? "");
      setAdim("kod");
    } catch {
      setHata(t("ortakSunucuyaUlasilamadi"));
    } finally {
      setGonderiliyor(false);
    }
  }

  async function kodGonder() {
    setHata(null);
    setGonderiliyor(true);
    try {
      const r = await fetch(UC_BAGLAN_DOGRULA, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          baglama_jetonu: sonuc?.baglama_jetonu,
          telefon: telefonNormalle(telefon),
          kod: kod.trim(),
        }),
      });
      const d = (await r.json().catch(() => null)) as Sonuc | null;
      if (!r.ok) {
        setHata(d?.error?.message ?? t("ortakHataOlustu"));
        return;
      }
      router.replace("/");
      router.refresh();
    } catch {
      setHata(t("ortakSunucuyaUlasilamadi"));
    } finally {
      setGonderiliyor(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md items-center p-6">
      <div className={`${cardCls} w-full space-y-4 p-6`}>
        <h1 className="text-lg font-semibold">{t("sosyalBaslik")}</h1>

        {adim === "yukleniyor" ? (
          <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
        ) : null}

        {adim === "tesis" ? (
          <>
            <p className="text-sm text-metin-body">
              {t("sosyalEslesmeAciklama", {
                saglayici: saglayiciEtiketi(sonuc?.saglayici ?? ""),
              })}
            </p>
            {/* APPLE PRIVATE RELAY: kullaniciya SOYLENIR, cunku o adrese
                posta gonderilemeyecegini bilmeli. */}
            {sonuc?.relay ? (
              <p className="text-sm text-metin-muted">{t("sosyalRelayUyari")}</p>
            ) : null}
            <Field label={t("kayitTesisKodu")}>
              <input
                className={inputCls}
                value={tesisKodu}
                onChange={(e) => setTesisKodu(e.target.value)}
                autoComplete="off"
              />
            </Field>
            <Field label={t("kullaniciTelefon")}>
              <input
                className={inputCls}
                value={telefonGiris(telefon)}
                onChange={(e) => setTelefon(telefonGiris(e.target.value))}
                placeholder={t("kullaniciTelefonOrnek")}
                inputMode="tel"
              />
            </Field>
            <ErrorBox message={hata} />
            <button
              className={btnPrimary}
              disabled={gonderiliyor || !tesisKodu.trim()}
              onClick={() => void tesisGonder(undefined)}
            >
              {gonderiliyor ? t("ortakKaydediliyor") : t("sosyalKodGonder")}
            </button>
          </>
        ) : null}

        {adim === "kod" ? (
          <>
            <p className="text-sm text-metin-body">
              {t("sosyalKodAciklama", { tesis: tesisAd, telefon: maskeli })}
            </p>
            <Field label={t("sosyalKod")}>
              <input
                className={inputCls}
                value={kod}
                onChange={(e) => setKod(e.target.value)}
                inputMode="numeric"
                autoComplete="one-time-code"
              />
            </Field>
            <ErrorBox message={hata} />
            <button
              className={btnPrimary}
              disabled={gonderiliyor || kod.trim().length < 4}
              onClick={() => void kodGonder()}
            >
              {gonderiliyor ? t("ortakKaydediliyor") : t("sosyalDogrula")}
            </button>
          </>
        ) : null}

        {adim === "hata" ? (
          <>
            <ErrorBox message={hata} />
            <button className={btnPrimary} onClick={() => router.replace("/login")}>
              {t("sosyalGiriseDon")}
            </button>
          </>
        ) : null}
      </div>
    </main>
  );
}

export default function OauthDonusSayfasi() {
  // `useSearchParams` Suspense sinirinda olmali (Next 15 statik uretim).
  return (
    <Suspense fallback={null}>
      <OauthDonus />
    </Suspense>
  );
}
