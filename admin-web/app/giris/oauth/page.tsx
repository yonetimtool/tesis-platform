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

import { ErrorBox, btnPrimary, cardCls } from "@/components/form";
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

type Adim = "yukleniyor" | "kayit_gerekli" | "hata" | "mevcut";

// BFF uclari ve niyet degerleri MODUL DUZEYINDE sabit: ucluda dizge
// yazmak `sabit-metin` taramasini (hakli olarak) tetikliyor — o tarama
// ucludeki her dizgeyi cevrilmemis metin adayi sayar.
const NIYET_BAGLA = "bagla";
const NIYET_GIRIS = "giris";
const NIYET_KAYIT = "kayit";
const UC_SONUC = "/api/auth/oauth/sonuc";
const UC_BAGLANTILAR = "/api/auth/oauth/baglantilarim";
const UC_DAVET_SOSYAL = "/api/auth/davet/sosyal";

function OauthDonus() {
  const t = useT();
  const router = useRouter();
  const arama = useSearchParams();
  const sonucId = arama.get("oauth");

  const [adim, setAdim] = useState<Adim>("yukleniyor");
  const [hata, setHata] = useState<string | null>(null);

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
          // (P185) GIRIS ekranindan gelen ve HICBIR hesaba bagli olmayan
          // sosyal kimlik. ESKIDEN burada "Tesis ID + telefon + SMS" formu
          // vardi ve "Baglama istegi gecersiz" hatasini uretiyordu. Artik
          // SMS istemiyoruz: kullaniciya kimliginin hentiz bir hesaba bagli
          // olmadigini soyleyip KAYDA yonlendiriyoruz. Kaydolurken sosyal
          // yolu tekrar secerse `/kayit` ayni saglayiciyla devam eder.
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

  return (
    <main className="mx-auto flex min-h-screen max-w-md items-center p-6">
      <div className={`${cardCls} w-full space-y-4 p-6`}>
        <h1 className="text-lg font-semibold">{t("sosyalBaslik")}</h1>

        {adim === "yukleniyor" ? (
          <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
        ) : null}

        {/* (P185) BAGLI DEGIL -> KAYDA YONLENDIR. Tesis ID + telefon + SMS
            YOK: kimlik dogrulama yontemi kaydolmayi degistirmez. */}
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
