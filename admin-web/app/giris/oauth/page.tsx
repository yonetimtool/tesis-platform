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
 * OLASI SONUCLAR:
 *   1. niyet="bagla"           -> acik oturuma yontem eklenir, profile donulur,
 *   2. durum="giris"           -> oturum acildi, koke gidilir,
 *   3. durum="mevcut_hesap"    -> e-posta zaten kayitli; oturum acildi,
 *   4. durum="baglama_gerekli" -> kimlik bir hesaba bagli DEGIL.
 *
 * (P185) (4) ARTIK SMS ISTEMEZ. Eskiden burada "Tesis ID + telefon + SMS"
 * baglama formu vardi; o form ve `oauth/baglan/*` cagrilari "Baglama istegi
 * gecersiz" hatasinin KAYNAGIYDI ve kaldirildi. Davetten ya da kayit
 * taslagindan gelindiyse akis onceki gibi surer; bunlarin disindaki
 * "bagli degil" durumunda kullanici KAYDA (`/kayit`) yonlendirilir —
 * kimlik dogrulama YONTEMI kaydolmayi degistirmez.
 */
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";

import { ErrorBox, btnGhost, btnPrimary, cardCls, inputCls } from "@/components/form";
import {
  OAUTH_NIYET,
  davetJetonuOku,
  kayitSosyalSonucYaz,
  kayitTaslagiOku,
} from "@/components/SosyalGiris";
import { useT } from "@/lib/i18n/kullan";

type Sonuc = {
  durum?: string;
  saglayici?: string | null;
  eposta?: string | null;
  relay?: boolean;
  /** (P155r2 §2) Saglayicinin bildirdigi ad soyad — kayit formunun
   *  on-doldurmasi. Apple vermez; bos gelir ve akis kirilmaz. */
  ad?: string | null;
  baglama_jetonu?: string | null;
  error?: { message?: string };
};

type Adim =
  | "yukleniyor"
  // (P191 §1) Kimlik bir hesaba bagli DEGIL -> once TESIS ID sorulur.
  | "tamamla"
  // Tesis ID verildi ama saglayici e-postayi dogrulamamis -> e-posta OTP.
  | "tamamla_kod"
  // (b)/(a) tutmadi: yoneticinin onay kuyruguna dustu.
  | "onay_bekliyor"
  | "kayit_gerekli"
  | "hata"
  | "mevcut";

// BFF uclari ve niyet degerleri MODUL DUZEYINDE sabit: ucluda dizge
// yazmak `sabit-metin` taramasini (hakli olarak) tetikliyor — o tarama
// ucludeki her dizgeyi cevrilmemis metin adayi sayar.
const NIYET_BAGLA = "bagla";
const NIYET_GIRIS = "giris";
const NIYET_KAYIT = "kayit";
const UC_SONUC = "/api/auth/oauth/sonuc";
const UC_BAGLANTILAR = "/api/auth/oauth/baglantilarim";
const UC_DAVET_SOSYAL = "/api/auth/davet/sosyal";
// (P191 §1) GIRISTE TAMAMLAMA — `rol` GONDERILMEZ, hesaptan okunur.
const UC_TAMAMLA = "/api/auth/oauth/rol-tamamla";
const UC_TAMAMLA_DOGRULA = "/api/auth/oauth/rol-tamamla-dogrula";
const DURUM_GIRIS = "giris";
const DURUM_OTP = "otp_gerekli";

function OauthDonus() {
  const t = useT();
  const router = useRouter();
  const arama = useSearchParams();
  const sonucId = arama.get("oauth");

  const [adim, setAdim] = useState<Adim>("yukleniyor");
  const [hata, setHata] = useState<string | null>(null);
  // (P191 §1) Girişte tamamlama formu.
  const [baglamaJetonu, setBaglamaJetonu] = useState<string | null>(null);
  const [eposta, setEposta] = useState<string>("");
  const [tesisKodu, setTesisKodu] = useState("");
  const [kod, setKod] = useState("");
  const [bekliyor, setBekliyor] = useState(false);

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
        if (niyet === NIYET_KAYIT) {
          // (P180) Kayit niyeti. durum=kayit -> kayit tamamlama (/kayit);
          // mevcut_hesap -> oturum acildi + "zaten hesabiniz var"; giris ->
          // kimlik zaten bagliydi, oturum acildi.
          if (d?.durum === "kayit" && d.baglama_jetonu) {
            kayitSosyalSonucYaz({
              rol: "yonetici",
              baglamaJetonu: d.baglama_jetonu,
              saglayici: d.saglayici ?? "",
              ad: d.ad ?? undefined,
            });
            router.replace("/kayit");
            return;
          }
          if (d?.durum === "mevcut_hesap") {
            setAdim("mevcut");
            return;
          }
          router.replace("/");
          router.refresh();
          return;
        }
        if (d?.durum === "baglama_gerekli") {
          // (P155 §7) DAVETTEN GELINDIYSE: jeton tesis/rol/daire/telefonu
          // biliyor. Dogrudan `/davet/sosyal` ile bagla ve oturum ac.
          const davetJetonu = davetJetonuOku();
          if (davetJetonu && d.baglama_jetonu) {
            void (async () => {
              const dr = await fetch(UC_DAVET_SOSYAL, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  jeton: davetJetonu,
                  baglama_jetonu: d.baglama_jetonu,
                }),
              });
              if (dr.ok) {
                router.replace("/");
                router.refresh();
              } else {
                const dv = (await dr.json().catch(() => null)) as Sonuc | null;
                setHata(dv?.error?.message ?? t("ortakHataOlustu"));
                setAdim("hata");
              }
            })();
            return;
          }
          // (P155r2) KAYIT AKISINDAN GELINDIYSE `/kayit`a devret ve kaldigi
          // yerden surdur (ad soyad saglayicidan on-dolar).
          const taslak = kayitTaslagiOku();
          if (taslak && d.baglama_jetonu) {
            kayitSosyalSonucYaz({
              rol: taslak.rol,
              baglamaJetonu: d.baglama_jetonu,
              saglayici: d.saglayici ?? "",
              ad: d.ad ?? undefined,
            });
            router.replace("/kayit");
            return;
          }
          // (P191 §1) GIRIS ekranindan gelen ve hicbir hesaba bagli OLMAYAN
          // kimlik. P185'te burasi dogrudan "Kaydol"a yolluyordu ve OLCULEN
          // KUSUR buydu: yoneticinin PANELDEN ekledigi, tesis kodlu davet
          // e-postasini almis kisi de bu dala dusuyor ve kendi hesabi
          // dururken "kaydol" cikmazina giriyordu. Dogru soru once "Tesis
          // ID'niz var mi?"dir — varsa hesap eslesir ve giris tamamlanir.
          //
          // KAYIT YOLU KAPANMADI: form altinda "Tesisim yok" baglantisi
          // duruyor (o baglanti `app.*`taki kayit yuzeyine gider).
          if (d.baglama_jetonu) {
            setBaglamaJetonu(d.baglama_jetonu);
            setEposta(d.eposta ?? "");
            setAdim("tamamla");
            return;
          }
          setAdim("kayit_gerekli");
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

  /** (P191 §1) Tesis ID (+ varsa e-posta kodu) ile hesabi tamamla. */
  async function tamamlaGonder(e: React.FormEvent, kodla: boolean): Promise<void> {
    e.preventDefault();
    if (!baglamaJetonu) return;
    setBekliyor(true);
    setHata(null);
    try {
      const r = await fetch(kodla ? UC_TAMAMLA_DOGRULA : UC_TAMAMLA, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          baglama_jetonu: baglamaJetonu,
          tesis_kodu: tesisKodu.trim(),
          // `rol` YOK: rol hesaptan okunur (backend `_tamamla_uygunluk`).
          ...(kodla ? { kod: kod.trim() } : {}),
        }),
      });
      const d = (await r.json().catch(() => null)) as Sonuc | null;
      if (!r.ok) {
        setHata(d?.error?.message ?? t("ortakHataOlustu"));
        return;
      }
      if (d?.durum === DURUM_GIRIS) {
        // Cerez BFF'te yazildi. Kok middleware'de ROLE gore cozulur.
        router.replace("/");
        router.refresh();
        return;
      }
      if (d?.durum === DURUM_OTP) {
        setAdim("tamamla_kod");
        return;
      }
      // `onay_bekliyor` — hangi sartin tutmadigi BILINCLI olarak sizmaz.
      setAdim("onay_bekliyor");
    } catch {
      setHata(t("ortakSunucuyaUlasilamadi"));
    } finally {
      setBekliyor(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md items-center p-6">
      <div className={`${cardCls} w-full space-y-4 p-6`}>
        <h1 className="text-lg font-semibold">{t("sosyalBaslik")}</h1>

        {adim === "yukleniyor" ? (
          <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
        ) : null}

        {/* (P191 §1) BAGLI DEGIL -> ONCE TESIS ID. Telefon/SMS YOK. */}
        {adim === "tamamla" ? (
          <form className="space-y-4" onSubmit={(e) => void tamamlaGonder(e, false)}>
            <h2 className="font-medium">{t("sosyalTamamlaBaslik")}</h2>
            <p className="text-sm text-metin-body">{t("sosyalTamamlaAciklama")}</p>
            <label className="block">
              <span className="text-sm font-medium">{t("kayitTesisKodu")}</span>
              <input
                className={`${inputCls} mt-1`}
                value={tesisKodu}
                onChange={(e) => setTesisKodu(e.target.value)}
                required
                minLength={3}
                autoFocus
                autoComplete="off"
                data-test="oauth-tesis-kodu"
              />
              <span className="mt-1 block text-xs text-metin-muted">
                {t("kayitTesisKoduIpucu")}
              </span>
            </label>
            {hata ? <ErrorBox message={hata} /> : null}
            <button
              type="submit"
              disabled={bekliyor}
              data-test="oauth-tamamla-gonder"
              className={`${btnPrimary} w-full py-3`}
            >
              {t("sosyalTamamlaGonder")}
            </button>
            <button
              type="button"
              className={`${btnGhost} w-full px-4 py-3`}
              onClick={() => setAdim("kayit_gerekli")}
            >
              {t("sosyalTamamlaYeniKayit")}
            </button>
          </form>
        ) : null}

        {/* Saglayici e-postayi dogrulamamis -> e-posta OTP (P184 yolu). */}
        {adim === "tamamla_kod" ? (
          <form className="space-y-4" onSubmit={(e) => void tamamlaGonder(e, true)}>
            <h2 className="font-medium">{t("kayitKodBaslik")}</h2>
            <p className="text-sm text-metin-body">
              {t("kayitKodEpostaAciklama", { eposta })}
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
                data-test="oauth-tamamla-kod"
              />
            </label>
            {hata ? <ErrorBox message={hata} /> : null}
            <button
              type="submit"
              disabled={bekliyor}
              data-test="oauth-tamamla-kod-gonder"
              className={`${btnPrimary} w-full py-3`}
            >
              {t("kayitTamamla")}
            </button>
          </form>
        ) : null}

        {/* Tesis ID gecersiz / e-posta listede yok / hesap uygun degil —
            HANGISI OLDUGU SOYLENMEZ (backend K4 sizdirmama kurali). */}
        {adim === "onay_bekliyor" ? (
          <>
            <h2 className="font-medium">{t("kayitOnayBekliyorBaslik")}</h2>
            <p className="text-sm text-metin-body">{t("kayitOnayBekliyorAciklama")}</p>
            <button className={btnPrimary} onClick={() => router.replace("/login")}>
              {t("sosyalGiriseDon")}
            </button>
          </>
        ) : null}

        {/* (P185) Kimligi hicbir hesaba baglanamayan ve tesisi OLMAYAN
            kullanici: kayit yuzeyi. */}
        {adim === "kayit_gerekli" ? (
          <>
            <p className="text-sm text-metin-body">{t("sosyalBagliDegil")}</p>
            <button className={btnPrimary} onClick={() => router.replace("/kayit")}>
              {t("sosyalKaydolDevam")}
            </button>
          </>
        ) : null}

        {/* (P180 kriter 4) E-posta zaten kayitli: oturum ACILDI (cerez yazildi),
            kullaniciya durum soylenir. Hesabin VARLIGI yalniz saglayici e-postayi
            DOGRULADIYSA buraya duser (backend email_verified kapisi) -> var
            olmayan/dogrulanmamis hesap bu mesaji GORMEZ, sizinti yok. */}
        {adim === "mevcut" ? (
          <>
            <p className="text-sm text-metin-body">{t("sosyalMevcutHesap")}</p>
            <button
              className={btnPrimary}
              onClick={() => {
                router.replace("/");
                router.refresh();
              }}
            >
              {t("kayitDevam")}
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
