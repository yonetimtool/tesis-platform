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
  /** (P211 §1) COK TESISLI YONETICI: tek kullanimlik secim jetonu +
   *  aday tesislerin ADLARI. Tesis ID ezberlemek GEREKMEZ. */
  secim_jetonu?: string | null;
  tesisler?: TesisSecenegi[] | null;
  error?: { message?: string };
};

type TesisSecenegi = { tenant_id: string; ad: string; slug: string };

type Adim =
  | "yukleniyor"
  // (b)/(a) tutmadi: yoneticinin onay kuyruguna dustu.
  | "onay_bekliyor"
  | "kayit_gerekli"
  // (P211 §1) COK TESISLI YONETICI: hangi tesise girecegi SORULUR —
  // Tesis ID DEGIL, adlardan secim.
  | "tesis_secimi"
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
const UC_TESIS_SEC = "/api/auth/oauth/tesis-sec";
const DURUM_GIRIS = "giris";
const DURUM_OTP = "otp_gerekli";

function OauthDonus() {
  const t = useT();
  const router = useRouter();
  const arama = useSearchParams();
  const sonucId = arama.get("oauth");

  const [adim, setAdim] = useState<Adim>("yukleniyor");
  // (P211 §1) Secim jetonu TEK KULLANIMLIK ve hicbir tesise yetki
  // VERMEZ; yalnizca "bu dogrulanmis adres su tesislerde yonetici"
  // bilgisini tasir.
  const [secimJetonu, setSecimJetonu] = useState<string | null>(null);
  const [tesisler, setTesisler] = useState<TesisSecenegi[]>([]);
  const [hata, setHata] = useState<string | null>(null);
  // (P191 §1) Girişte tamamlama formu.

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
    // (P201) NIYET SUNUCUDAN DA OKUNUR — sessionStorage TEK KAYNAK DEGIL.
    //
    // OLCULEN KUSUR: niyet yalniz `sessionStorage`da tutuluyordu ve
    // `sessionStorage` KOKEN BASINADIR. Akis `app.*`ta baslayip donus
    // `panel.*`a dusuyorsa (ya da kullanici arada sekme degistirdiyse)
    // deger KAYBOLUYOR, kayit niyeti giris sanilip kullaniciya TESIS ID
    // soruluyordu — kayit akisinin cikmazi tam olarak buydu.
    //
    // Sunucu niyeti ZATEN biliyor: `basla`da redis oturumuna yazildi ve
    // `sonuc` yanitinda `durum` olarak geri geliyor (`kayit` /
    // `mevcut_hesap`). Istemci tarafi kopya artik yalnizca HANGI UCUN
    // cagrilacagini (`baglantilarim` vs `sonuc`) secer; KARAR yanittan
    // verilir.
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
        // (P201) Yanit "kayit niyetiydi" diyorsa dal BUDUR — yerel
        // kopya ne derse desin.
        if (niyet === NIYET_KAYIT || d?.durum === "kayit" || d?.durum === "mevcut_hesap") {
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
        // (P211 §1) COK TESISLI YONETICI: TESIS ID sormadan SECIM.
        //
        // Sunucu, dogrulanmis e-posta birden cok tesiste yonetici
        // eslesirse `tesis_secimi` doner. Eskiden `baglama_gerekli`
        // donuyor ve kullanici ezberlemedigi bir kodu yazmak zorunda
        // kaliyordu (P205'te parola yolunda kaldirilan sartin aynisi).
        if (d?.durum === "tesis_secimi" && d.secim_jetonu) {
          setSecimJetonu(d.secim_jetonu);
          setTesisler(d.tesisler ?? []);
          setAdim("tesis_secimi");
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
          // (P211-ek3) HICBIR HESABA BAGLI OLMAYAN KIMLIK -> KAYIT.
          //
          // P191'de burasi Tesis ID soruyordu. KURAL DEGISTI ve mobille
          // AYNI: Tesis ID YALNIZ KAYIT akisinda sorulur (davet
          // e-postasindaki kod), GIRISTE ASLA. Iki yuzeyin ayni soruyu
          // farkli yerlerde sormasi, kullaniciya "giris icin bir kod
          // gerekiyor" izlenimi veriyordu — vermedigimiz bir soz.
          //
          // Jeton `/kayit`a TASINIR: orada rol secilir, Tesis ID kayit
          // adimi olarak sorulur ve saglayici akisi TEKRARLANMAZ.
          if (d.baglama_jetonu) {
            kayitSosyalSonucYaz({
              // ROL BOS: kullanici giristen geldi, hangi rolde kaydolacagi
              // BILINMIYOR. `/kayit` bos rolu gorunce ROL ADIMINDAN
              // baslar — varsayilan bir rol secmek, kisiyi yanlis kayit
              // turune sokmanin sessiz yoluydu.
              rol: "",
              baglamaJetonu: d.baglama_jetonu,
              saglayici: d.saglayici ?? "",
              ad: d.ad ?? undefined,
            });
            router.replace("/kayit");
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

  // (P211-ek3) `tamamlaGonder` VE Tesis ID formu KALDIRILDI.
  //
  // P191'de bu sayfa, hicbir hesaba bagli olmayan bir SSO kimligine
  // "Tesis ID" soruyordu. Kural degisti ve mobille AYNI: Tesis ID
  // YALNIZ kayit akisinda sorulur. Bagli olmayan kimlik artik jetonuyla
  // birlikte `/kayit`a devredilir; olu kodu birakmak, kurali sessizce
  // geri getirmenin en kolay yoluydu.


  /// (P211 §1) Secilen tesisle oturumu acar. Jeton tuketilir; sunucu
  /// secilen tesisin ADAY LISTESINDE oldugunu dogrular.
  async function tesisSec(tenantId: string) {
    if (!secimJetonu) return;
    const r = await fetch(UC_TESIS_SEC, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ secim_jetonu: secimJetonu, tenant_id: tenantId }),
    });
    if (r.ok) {
      router.replace("/");
      router.refresh();
      return;
    }
    const v = (await r.json().catch(() => null)) as Sonuc | null;
    setHata(v?.error?.message ?? t("ortakHataOlustu"));
    setAdim("hata");
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md items-center p-6">
      <div className={`${cardCls} w-full space-y-4 p-6`}>
        <h1 className="text-lg font-semibold">{t("sosyalBaslik")}</h1>

        {adim === "yukleniyor" ? (
          <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
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
        {/* (P211 §1) TESIS SECIMI — Tesis ID formunun YERINE. */}
        {adim === "tesis_secimi" ? (
          <div className="space-y-3" data-test="oauth-tesis-secimi">
            <h2 className="font-medium">{t("girisTesisSecBaslik")}</h2>
            <p className="text-sm text-metin-body">{t("girisTesisSecAlt")}</p>
            {tesisler.map((x) => (
              <button
                key={x.tenant_id}
                type="button"
                className={`${cardCls} w-full p-3 text-start`}
                data-test={`oauth-tesis-${x.slug}`}
                onClick={() => void tesisSec(x.tenant_id)}
              >
                {x.ad}
              </button>
            ))}
          </div>
        ) : null}

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
