"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { DilSecici } from "@/components/DilSecici";
import { ErrorBox, btnGhost, btnPrimary, cardCls, inputCls } from "@/components/form";
import { SosyalGiris, kayitSosyalSonucOku } from "@/components/SosyalGiris";
import { YonetioLogo } from "@/components/YonetioLogo";
import { ParolaAlani } from "@/components/ParolaAlani";
import { useT } from "@/lib/i18n/kullan";
import { telefonGiris, telefonHatasi, telefonNormalle } from "@/lib/telefon";

/**
 * (P155r2) ROL SECIMLI KAYIT — web yuzeyi, SARTNAME SIRASIYLA.
 *
 * =========================================================================
 * SIRA DEGISTI: rol -> YONTEM -> bilgiler -> ROLE OZEL
 * =========================================================================
 * P154'te sira `rol -> tesis kodu+telefon -> yontem -> kod -> parola` idi.
 * Sartname §2 yontemi rol seciminden HEMEN SONRA istiyor; eski sirada
 * sosyal hesapla kaydolmak isteyen kisi once iki alan doldurmak
 * zorundaydi. Mobil yuzeyle de artik AYNI sira.
 *
 * ADIMLAR:
 *   1. ROL       — web'de yalniz Yonetici + Denetci (mobil dort rol sunar
 *                  ve o AYRI bir yuzeydir; sahada yapilacak isi masaustune
 *                  cagirmak olurdu)
 *   2. YONTEM    — once sosyal, sonra "E-posta/telefon ile kaydol"
 *   3. BILGILER  — ad soyad + telefon (+ parola, elle kayitta)
 *   4. ROLE OZEL — yonetici: TESIS ADI · denetci/katilan: TESIS KODU
 *   5. KOD       — yalniz eslesme yolunda (yonetici-yeni'de YOK)
 *
 * KUME NEDEN ISTEMCIDE: sunucu bes rolu de kabul eder ve GERCEK kapi
 * "tesis ID + telefon onceden tanimli kayitla eslesiyor mu" kontroludur —
 * bir sakin buradan `yonetici` secse bile eslesmedigi icin kod ALAMAZ.
 * Yani bu liste bir GUVENLIK siniri degil, bir UX secimidir.
 *
 * =========================================================================
 * SOSYAL DAL SAYFADAN AYRILIR — VE GERI DONER
 * =========================================================================
 * Web'de saglayiciya tam yonlendirme var. Yontem adiminda sosyal secilince
 * `SosyalGiris` rolu `sessionStorage`a birakip saglayiciya gider; arka uc
 * callback'i `/giris/oauth`a duser, ORASI sonucu cozup yine
 * `sessionStorage`a birakir ve BURAYA geri gonderir. Bu sayfa acilista onu
 * okuyup 3. adimdan (ad soyad saglayicidan DOLU) devam eder.
 *
 * Kayit formunu `/giris/oauth`ta da cizmek daha kisa gorunurdu ama iki
 * kopya uretirdi ve zamanla ayrisirlardi.
 *
 * =========================================================================
 * YONETICI ICIN IKI CIKIS
 * =========================================================================
 * "Tesis adini giriniz" alaninin ALTINDA "Zaten bir sitem var" bagi
 * (sartname §3). KATILMA TESIS ACMA DEGIL bir ROL ESLESMESIDIR: KISITLAR
 * geregi ikinci yonetici de mevcut yonetici tarafindan EKLENMIS olmali.
 * Aksi tasarim (kodu bilen yonetici olur) tesisin tamamen devralinmasi
 * demekti — kod kamuya acik ve tahmin edilebilir (goc 0037 guvenlik notu).
 *
 * DENETCI TESIS ACAMAZ: denetci bir tesise ATANIR, tesis kurmaz. Onun
 * 4. adimi her zaman tesis kodudur.
 *
 * =========================================================================
 * PAROLA IKI KEZ SORULMAZ
 * =========================================================================
 * Kullanici parolasini 3. adimda giriyor. Eslesme yolunda sunucu kod
 * dogrulaninca `setup_token` doner ve eski surumde 5. adimda parola BIR
 * KEZ DAHA soruluyordu. Artik jeton alinir alinmaz parola otomatik
 * gonderiliyor; ayri bir parola adimi YOK.
 */

type Adim = "rol" | "yontem" | "bilgiler" | "rolOzel" | "kod" | "sonuc";
type Rol = "yonetici" | "denetci";
type Yol = "parola" | "sosyal";

const UC_BASLA = "/api/auth/kayit/rol-basla";
const UC_DOGRULA = "/api/auth/kayit/rol-dogrula";
const UC_PAROLA = "/api/auth/set-password";
const UC_TESIS = "/api/auth/kayit/tesis-olustur";
const UC_BAGLAN_BASLA = "/api/auth/oauth/baglan/basla";
const UC_BAGLAN_DOGRULA = "/api/auth/oauth/baglan/dogrula";

const ROL_DENETCI = "denetci";

/**
 * Geri dugmesinin adim haritasi. UCLU DEGIL SOZLUK: `sabit-metin`
 * taramasi ucludeki her dizgeyi "cevrilmemis metin" adayi sayar ve
 * HAKLIDIR — orada gercek bir cumle de durabilirdi. (Ayni gerekce
 * `SosyalGiris.DUGME_ANAHTARI`de yazili.)
 */
const GERI_ADIM: Record<Adim, Adim> = {
  rol: "rol",
  yontem: "rol",
  bilgiler: "yontem",
  rolOzel: "bilgiler",
  kod: "rolOzel",
  sonuc: "sonuc",
};

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
  const [yol, setYol] = useState<Yol>("parola");
  /** Yonetici VAR OLAN bir tesise mi katiliyor ("Zaten bir sitem var")? */
  const [katil, setKatil] = useState(false);

  const [ad, setAd] = useState("");
  const [telefon, setTelefon] = useState("");
  const [parola, setParola] = useState("");
  const [parola2, setParola2] = useState("");
  const [tesisAdi, setTesisAdi] = useState("");
  const [tesisKodu, setTesisKodu] = useState("");
  const [kod, setKod] = useState("");

  const [baglamaJetonu, setBaglamaJetonu] = useState("");
  const [tesisAd, setTesisAd] = useState("");
  const [telefonMaskeli, setTelefonMaskeli] = useState("");
  const [uretilenKod, setUretilenKod] = useState("");
  const [kopyalandi, setKopyalandi] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);

  /** Yonetici YENI tesis aciyorsa SMS adimi yok → 4 adim; degilse 5. */
  const tesisAcar = rol === "yonetici" && !katil;
  const toplamAdim = tesisAcar ? 4 : 5;
  const adimNo = { rol: 1, yontem: 2, bilgiler: 3, rolOzel: 4, kod: 5, sonuc: toplamAdim }[
    adim
  ];

  /**
   * SAGLAYICIDAN DONULDU MU? `/giris/oauth` sonucu birakip buraya
   * yonlendirdiyse 3. adimdan devam edilir ve ad soyad ON-DOLDURULUR.
   *
   * Okuma TEK KULLANIMLIK (`kayitSosyalSonucOku` okuyup siler), bu yuzden
   * `[]` bagimlilikla bir kez kosar; ikinci kosumda zaten `null` doner.
   */
  useEffect(() => {
    const s = kayitSosyalSonucOku();
    if (!s) return;
    if (s.rol === ROL_DENETCI) setRol(ROL_DENETCI);
    setYol("sosyal");
    setBaglamaJetonu(s.baglamaJetonu);
    // SARTNAME §2: saglayicidan gelen ad soyad forma OTOMATIK DOLAR ve
    // kullanici duzeltebilir. Apple ad vermez → alan bos kalir.
    if (s.ad) setAd(s.ad);
    setAdim("bilgiler");
  }, []);

  // ============================ ADIM 3 =================================== //

  function bilgileriGonder(e: React.FormEvent) {
    e.preventDefault();
    // `telefonHatasi` KIMLIK doner (metin degil) — cevirisi burada
    // cozulur; GirisFormu ile AYNI esleme kullaniliyor ki iki ekran ayni
    // numaraya farkli sey demesin.
    const telHata = telefonHatasi(telefon);
    if (telHata) {
      setHata(telHata === "gecersizOnEk" ? t("telefonHataOnEk") : t("telefonHataEksik"));
      return;
    }
    if (yol === "parola" && parola !== parola2) {
      setHata(t("kayitParolaUyusmuyor"));
      return;
    }
    setHata(null);
    setAdim("rolOzel");
  }

  // ============================ ADIM 4 =================================== //

  async function rolOzelGonder(e: React.FormEvent) {
    e.preventDefault();
    setBekliyor(true);
    setHata(null);
    try {
      if (tesisAcar) {
        const y = (await gonder(UC_TESIS, {
          tesis_ad: tesisAdi.trim(),
          ad: ad.trim(),
          telefon: telefonNormalle(telefon),
          ...(yol === "sosyal"
            ? { baglama_jetonu: baglamaJetonu }
            : { parola }),
        })) as { tesis_ad?: string; tesis_kodu?: string };
        // Cerezler BFF'te yazildi; oturum ACIK. Kullaniciyi hemen panoya
        // atmiyoruz: TESIS KODUNU gostermeliyiz (sartname §4 — SMS
        // saglayicisi baglanana kadar yonetici kodu ELLE iletecek).
        setTesisAd(y.tesis_ad ?? tesisAdi.trim());
        setUretilenKod(y.tesis_kodu ?? "");
        setAdim("sonuc");
        return;
      }

      const uc = yol === "sosyal" ? UC_BAGLAN_BASLA : UC_BASLA;
      const y = (await gonder(uc, {
        ...(yol === "sosyal"
          ? { baglama_jetonu: baglamaJetonu }
          : { rol }),
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

  // ============================ ADIM 5 =================================== //

  async function kodGonder(e: React.FormEvent) {
    e.preventDefault();
    setBekliyor(true);
    setHata(null);
    try {
      if (yol === "sosyal") {
        // Kod dogrulaninca kimlik BAGLANIR ve oturum acilir — parola yok.
        await gonder(UC_BAGLAN_DOGRULA, {
          baglama_jetonu: baglamaJetonu,
          telefon: telefonNormalle(telefon),
          kod: kod.trim(),
        });
      } else {
        const y = (await gonder(UC_DOGRULA, {
          telefon: telefonNormalle(telefon),
          kod: kod.trim(),
        })) as { setup_token: string };
        // PAROLA IKI KEZ SORULMAZ: kullanici 3. adimda yazdi. Ayri bir
        // parola adimi gostermek, az once yazdigini tekrar sordurmak olurdu.
        await gonder(UC_PAROLA, { setup_token: y.setup_token, new_password: parola });
      }
      // Cerezler BFF'te yazildi; kok rota rolu cozup dogru sayfaya atar.
      router.replace("/");
      router.refresh();
    } catch (err) {
      setHata(err instanceof Error ? err.message : String(err));
      setBekliyor(false);
    }
  }

  function geri() {
    setHata(null);
    setAdim(GERI_ADIM[adim]);
  }

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-md flex-col justify-center gap-6 px-5 py-10">
      <div className="flex items-center justify-between">
        <YonetioLogo size={32} />
        <DilSecici />
      </div>

      <div>
        <p className="text-xs font-medium text-metin-muted">
          {t("kayitAdim", { n: String(adimNo), toplam: String(toplamAdim) })}
        </p>
        <h1 className="mt-1 text-2xl font-semibold">{t("kayitBaslik")}</h1>
      </div>

      <ErrorBox message={hata} />

      {/* ============================ ADIM 1 ============================ */}
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
              data-test={`kayit-rol-${deger}`}
              onClick={() => {
                setRol(deger);
                setKatil(false);
                setAdim("yontem");
              }}
            >
              <span className="block font-medium">{baslik}</span>
              <span className="block text-sm text-metin-muted">{aciklama}</span>
            </button>
          ))}
        </div>
      )}

      {/* ============================ ADIM 2 ============================ */}
      {adim === "yontem" && (
        <div className="space-y-4">
          <h2 className="font-medium">{t("kayitYontemBaslik")}</h2>
          {/* SAGLAYICI LISTESI SUNUCUDAN: hicbiri yapilandirilmamissa
              bilesen KENDINI cizmez ve geriye yalniz elle kayit kalir —
              sartnamenin "OAuth tikanirsa normal kayit tek basina
              calissin" kurali. Sosyal ONCE geliyor (sartname §2). */}
          <SosyalGiris niyet="giris" kayitRolu={rol} />
          <button
            type="button"
            disabled={bekliyor}
            data-test="kayit-yontem-parola"
            className={`${btnPrimary} w-full py-3`}
            onClick={() => {
              setYol("parola");
              setHata(null);
              setAdim("bilgiler");
            }}
          >
            {t("kayitYontemEposta")}
          </button>
          <button
            type="button"
            className={`${btnGhost} w-full px-4 py-3`}
            onClick={() => setAdim("rol")}
          >
            {t("kayitGeri")}
          </button>
        </div>
      )}

      {/* ============================ ADIM 3 ============================ */}
      {adim === "bilgiler" && (
        <form onSubmit={bilgileriGonder} className="space-y-4">
          <h2 className="font-medium">{t("kayitBilgilerBaslik")}</h2>
          {yol === "sosyal" ? (
            <p className="text-sm text-metin-muted">{t("kayitSosyalAdNotu")}</p>
          ) : null}
          <label className="block">
            <span className="text-sm font-medium">{t("kayitAdSoyad")}</span>
            <input
              className={`${inputCls} mt-1`}
              value={ad}
              onChange={(e) => setAd(e.target.value)}
              required
              minLength={2}
              autoFocus
              autoComplete="name"
              data-test="kayit-ad"
            />
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
              data-test="kayit-telefon"
            />
          </label>
          {/* PAROLA YALNIZ ELLE KAYITTA: sosyal yolda kimlik
              saglayicidadir ve parola HIC yazilmaz (sunucu da kabul etmez —
              iki yontem birden 422). */}
          {yol === "parola" ? (
            <>
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
            </>
          ) : null}
          <div className="flex gap-2">
            <button
              type="submit"
              disabled={bekliyor}
              data-test="kayit-bilgi-gonder"
              className={`${btnPrimary} flex-1 py-3`}
            >
              {t("kayitDevam")}
            </button>
            <button type="button" className={`${btnGhost} px-4 py-3`} onClick={geri}>
              {t("kayitGeri")}
            </button>
          </div>
        </form>
      )}

      {/* ============================ ADIM 4 ============================ */}
      {adim === "rolOzel" && (
        <form onSubmit={rolOzelGonder} className="space-y-4">
          {tesisAcar ? (
            <>
              <h2 className="font-medium">{t("kayitTesisAdBaslik")}</h2>
              <label className="block">
                <span className="text-sm font-medium">{t("kayitTesisAd")}</span>
                <input
                  className={`${inputCls} mt-1`}
                  value={tesisAdi}
                  onChange={(e) => setTesisAdi(e.target.value)}
                  required
                  minLength={2}
                  autoFocus
                  autoComplete="off"
                  data-test="kayit-tesis-ad"
                />
                <span className="mt-1 block text-xs text-metin-muted">
                  {t("kayitTesisAdIpucu")}
                </span>
              </label>
              {/* SARTNAME §3: "Tesis adini giriniz" alaninin ALTINDA. */}
              <button
                type="button"
                data-test="kayit-zaten-sitem-var"
                className="text-sm text-primary underline"
                onClick={() => {
                  setKatil(true);
                  setHata(null);
                }}
              >
                {t("kayitZatenSitemVar")}
              </button>
            </>
          ) : (
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
                data-test="kayit-tesis-kodu"
              />
              <span className="mt-1 block text-xs text-metin-muted">
                {t("kayitTesisKoduIpucu")}
              </span>
            </label>
          )}
          <div className="flex gap-2">
            <button
              type="submit"
              disabled={bekliyor}
              data-test="kayit-rol-ozel-gonder"
              className={`${btnPrimary} flex-1 py-3`}
            >
              {t("kayitDevam")}
            </button>
            <button type="button" className={`${btnGhost} px-4 py-3`} onClick={geri}>
              {t("kayitGeri")}
            </button>
          </div>
        </form>
      )}

      {/* ============================ ADIM 5 ============================ */}
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
              data-test="kayit-kod"
            />
          </label>
          <div className="flex gap-2">
            <button
              type="submit"
              disabled={bekliyor}
              data-test="kayit-kod-gonder"
              className={`${btnPrimary} flex-1 py-3`}
            >
              {t("kayitTamamla")}
            </button>
            <button type="button" className={`${btnGhost} px-4 py-3`} onClick={geri}>
              {t("kayitGeri")}
            </button>
          </div>
        </form>
      )}

      {/* ============================ SONUC ============================= */}
      {adim === "sonuc" && (
        <div className="space-y-4">
          <h2 className="font-medium">{tesisAd}</h2>
          <p className="text-sm text-metin-body">{t("kayitTesisKoduBaslik")}</p>
          <div className={`${cardCls} flex items-center gap-3 px-4 py-3`}>
            <span
              className="flex-1 select-all text-xl font-semibold tracking-wide"
              data-test="kayit-uretilen-kod"
            >
              {uretilenKod}
            </span>
            <button
              type="button"
              data-test="kayit-kod-kopyala"
              className={`${btnGhost} px-3 py-2 text-sm`}
              onClick={() => {
                void navigator.clipboard
                  ?.writeText(uretilenKod)
                  // Pano izni yoksa SESSIZ KALINIR: kod zaten `select-all`
                  // ile elle secilebiliyor, yani kullanici tikanmaz.
                  .then(() => setKopyalandi(true))
                  .catch(() => undefined);
              }}
            >
              {kopyalandi ? t("kayitKopyalandi") : t("kayitKopyala")}
            </button>
          </div>
          <p className="text-sm text-metin-muted">{t("kayitTesisKoduPaylas")}</p>
          <button
            type="button"
            data-test="kayit-sonuc-devam"
            className={`${btnPrimary} w-full py-3`}
            onClick={() => {
              router.replace("/");
              router.refresh();
            }}
          >
            {t("kayitPanoyaGit")}
          </button>
        </div>
      )}

      {adim !== "sonuc" ? (
        <Link href="/login" className="text-center text-sm text-primary underline">
          {t("kayitGirisLinki")}
        </Link>
      ) : null}
    </main>
  );
}
