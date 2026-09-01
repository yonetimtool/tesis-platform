"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { DilSecici } from "@/components/DilSecici";
import { ErrorBox, btnGhost, btnPrimary, cardCls, inputCls } from "@/components/form";
import {
  SosyalGiris,
  kayitSosyalSonucOku,
  kayitTaslagiYaz,
  niyetiYaz,
} from "@/components/SosyalGiris";
import { YonetioLogo } from "@/components/YonetioLogo";
import { ParolaAlani } from "@/components/ParolaAlani";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { telefonGiris, telefonHatasi, telefonNormalle } from "@/lib/telefon";

/**
 * (P185 §2/§3) ROL SECIMLI KAYIT — web yuzeyi, KARAR VERILEN MODEL.
 *
 * =========================================================================
 * SIRA: rol -> YONTEM -> bilgiler -> [yonetici: SECIM] -> ROLE OZEL -> kod
 * =========================================================================
 * P155r2'de yol SMS'e dayaniyordu ("Baglama istegi gecersiz" hatasinin
 * kaynagi); P185 onu tamamen E-POSTA dogrulamasina cevirdi. Telefon HÂLÂ
 * bir alan (arka uc yoneticiden iletisim numarasi ister) ama ARTIK bir
 * "giris anahtari" degildir; hicbir yerde SMS/telefon kodu adimi YOK.
 *
 * ADIMLAR:
 *   1. ROL       — web'de yalniz Yonetici + Denetci.
 *   2. YONTEM    — once sosyal, sonra "E-posta ile kaydol".
 *   3. BILGILER  — ad soyad + E-POSTA(zorunlu) + telefon (+ parola, elle
 *                  kayitta) + iki zorunlu onay (sozlesme + KVKK) + ticari.
 *   4. SECIM     — YALNIZ yonetici: [Yeni tesis olustur] / [Mevcut tesise
 *                  katil]. Denetci bu adimi atlar (tesis acamaz, katilir).
 *   5. ROLE OZEL — yeni: TESIS ADI · katil/denetci: TESIS ID.
 *   6. KOD       — 6 haneli E-POSTA kodu (yeni-yonetici + katil parola
 *                  yolunda). Sosyal yolda saglayici e-postayi dogruladiysa
 *                  atlanir.
 *
 * =========================================================================
 * YENI TESIS OLUSTUR (Tesis ID SORULMAZ; sistem uretir + e-postayla yollar)
 * =========================================================================
 * PAROLA yolu — E-POSTA dogrulamali 3 adim:
 *   1) POST kayit/yonetici-basvuru  (ad/soyad/eposta/telefon/parola + onaylar)
 *   2) POST kayit/yonetici-dogrula  (eposta + 6 haneli kod) -> kurulum_jetonu
 *   3) POST kayit/yonetici-tesis    (kurulum_jetonu + tesis_ad) -> oturum + kod
 * SOSYAL yolu — saglayici e-postayi dogruladigi icin OTP yok:
 *   POST kayit/tesis-olustur (tesis_ad + ad + baglama_jetonu) -> oturum + kod
 *
 * =========================================================================
 * MEVCUT TESISE KATIL (kullanici TESIS ID girer)
 * =========================================================================
 * PAROLA yolu:
 *   POST kayit/rol-eposta-basla (tesis_kodu, eposta, rol, ad, telefon)
 *     -> 6 haneli E-POSTA kodu
 *   POST kayit/rol-eposta-dogrula (tesis_kodu, eposta, kod)
 *     -> durum=hazir  -> POST set-password (setup_token, parola) -> oturum
 *     -> durum=onay_bekliyor -> "yonetici onayi bekleniyor" bilgi ekrani
 * SOSYAL yolu:
 *   POST oauth/rol-tamamla (baglama_jetonu, tesis_kodu, rol)
 *     -> durum=giris        -> oturum
 *     -> durum=otp_gerekli  -> 6 haneli E-POSTA kodu
 *          -> POST oauth/rol-tamamla-dogrula (... + kod) -> oturum
 *     -> durum=onay_bekliyor -> "yonetici onayi bekleniyor" bilgi ekrani
 *
 * =========================================================================
 * SOSYAL DAL SAYFADAN AYRILIR — VE GERI DONER
 * =========================================================================
 * Yontem adiminda sosyal secilince `SosyalGiris` rolu `sessionStorage`a
 * birakip saglayiciya gider; arka uc callback'i `/giris/oauth`a duser,
 * ORASI sonucu cozup yine `sessionStorage`a birakir ve BURAYA geri
 * gonderir. Bu sayfa acilista onu okuyup 3. adimdan (ad soyad
 * saglayicidan DOLU) devam eder.
 */

type Adim = "rol" | "yontem" | "bilgiler" | "secim" | "rolOzel" | "kod" | "onay" | "sonuc";
type Rol = "yonetici" | "denetci";
type Yol = "parola" | "sosyal";
/** Yonetici SECIMI: yeni tesis mi acar, mevcuda mi katilir. */
type YoneticiSecim = "yeni" | "katil";

const UC_YONETICI_BASVURU = "/api/auth/kayit/yonetici-basvuru";
const UC_YONETICI_DOGRULA = "/api/auth/kayit/yonetici-dogrula";
const UC_YONETICI_TESIS = "/api/auth/kayit/yonetici-tesis";
const UC_TESIS = "/api/auth/kayit/tesis-olustur";
const UC_ROL_EPOSTA_BASLA = "/api/auth/kayit/rol-eposta-basla";
const UC_ROL_EPOSTA_DOGRULA = "/api/auth/kayit/rol-eposta-dogrula";
const UC_PAROLA = "/api/auth/set-password";
const UC_ROL_TAMAMLA = "/api/auth/oauth/rol-tamamla";
const UC_ROL_TAMAMLA_DOGRULA = "/api/auth/oauth/rol-tamamla-dogrula";

const ROL_DENETCI = "denetci";

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
    throw new Error(veri?.error?.message ?? String(r.status));
  }
  return veri;
}

/**
 * (P198) IKI ZORUNLU ONAY + ISTEGE BAGLI TICARI — TEK YERDE.
 *
 * NEDEN BILESEN OLDU: onaylar `bilgiler` adiminda toplaniyordu, ama
 * SOSYAL yol `bilgiler`e HIC UGRAMADAN saglayiciya gidiyor ve backend
 * `niyet=kayit` icin onaylari `baslat` cagrisinda ISTIYOR. Iki adimda
 * iki kopya cizmek, birinin `data-test` kancasini ya da metnini
 * otekinden ayirmasi demekti.
 */
function OnayKutulari({
  sozlesme, kvkk, ticari, setSozlesme, setKvkk, setTicari, t,
}: {
  sozlesme: boolean;
  kvkk: boolean;
  ticari: boolean;
  setSozlesme: (v: boolean) => void;
  setKvkk: (v: boolean) => void;
  setTicari: (v: boolean) => void;
  t: (a: SozlukAnahtari) => string;
}) {
  return (
    <>
      <label className="flex items-start gap-2 text-sm">
        <input
          type="checkbox"
          className="mt-1"
          checked={sozlesme}
          onChange={(e) => setSozlesme(e.target.checked)}
          data-test="kayit-onay-sozlesme"
        />
        <span>{t("kayitOnaySozlesme")}</span>
      </label>
      <label className="flex items-start gap-2 text-sm">
        <input
          type="checkbox"
          className="mt-1"
          checked={kvkk}
          onChange={(e) => setKvkk(e.target.checked)}
          data-test="kayit-onay-kvkk"
        />
        <span>{t("kayitOnayKvkk")}</span>
      </label>
      <label className="flex items-start gap-2 text-sm">
        <input
          type="checkbox"
          className="mt-1"
          checked={ticari}
          onChange={(e) => setTicari(e.target.checked)}
          data-test="kayit-onay-ticari"
        />
        <span>{t("kayitOnayTicari")}</span>
      </label>
    </>
  );
}

export default function KayitSayfasi() {
  const t = useT();
  const router = useRouter();

  const [adim, setAdim] = useState<Adim>("rol");
  const [rol, setRol] = useState<Rol>("yonetici");
  const [yol, setYol] = useState<Yol>("parola");
  /** Yonetici YENI tesis mi aciyor, MEVCUDA mi katiliyor. Denetci daima
   *  "katil" gibi davranir (tesis ID girer) ama SECIM adimini gormez. */
  const [secim, setSecim] = useState<YoneticiSecim>("yeni");

  const [ad, setAd] = useState("");
  const [soyad, setSoyad] = useState("");
  const [eposta, setEposta] = useState("");
  const [telefon, setTelefon] = useState("");
  const [parola, setParola] = useState("");
  const [parola2, setParola2] = useState("");
  const [onaySozlesme, setOnaySozlesme] = useState(false);
  const [onayKvkk, setOnayKvkk] = useState(false);
  const [onayTicari, setOnayTicari] = useState(false);
  const [tesisAdi, setTesisAdi] = useState("");
  const [tesisKodu, setTesisKodu] = useState("");
  const [kod, setKod] = useState("");

  const [baglamaJetonu, setBaglamaJetonu] = useState("");
  const [tesisAd, setTesisAd] = useState("");
  const [uretilenKod, setUretilenKod] = useState("");
  const [kopyalandi, setKopyalandi] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);

  /** Yonetici YENI tesis aciyorsa "tesis acar" — SECIM adimi gorunur. */
  const yoneticiKatil = rol === "yonetici" && secim === "katil";
  const tesisAcar = rol === "yonetici" && secim === "yeni";
  /** Denetci SECIM adimini atlar: tesis ID yolunu her zaman izler. */
  const secimGoster = rol === "yonetici";
  // (P198) SOSYAL NIYET ROL'E BAGLI — bkz. `yontem` adimindaki uzun not.
  // Uclu ifade YOK: `sabit-metin` taramasi ucludaki dize sabitlerini
  // cevrilmemis metin adayi sayiyor (P193'te olculdu).
  const yoneticiKaydi = rol === "yonetici";
  let sosyalNiyet: "giris" | "kayit" = "giris";
  if (yoneticiKaydi) sosyalNiyet = "kayit";
  const onaylarTam = onaySozlesme && onayKvkk;
  // Yonetici kaydinda onaylar ALINMADAN saglayiciya gidilmez: backend
  // `niyet=kayit`i onaysiz 422 ile reddeder ve kullanici sebebini
  // goremeden geri donerdi.
  const sosyalNiyetiHazir = !yoneticiKaydi || onaylarTam;

  const toplamAdim = tesisAcar ? 5 : secimGoster ? 6 : 5;
  const adimNo = {
    rol: 1,
    yontem: 2,
    bilgiler: 3,
    secim: 4,
    rolOzel: secimGoster ? 5 : 4,
    kod: secimGoster ? 6 : 5,
    onay: secimGoster ? 6 : 5,
    sonuc: toplamAdim,
  }[adim];

  /** Geri dugmesinin adim haritasi. Rol yoluna gore dallanir. */
  function geriAdim(): Adim {
    switch (adim) {
      case "yontem":
        return "rol";
      case "bilgiler":
        return "yontem";
      case "secim":
        return "bilgiler";
      case "rolOzel":
        if (secimGoster) return "secim";
        return "bilgiler";
      case "kod":
      case "onay":
        return "rolOzel";
      default:
        return adim;
    }
  }

  /**
   * (P201) SAGLAYICI DOGRUDAN BURAYA DONDUYSE (`/kayit?oauth=<id>`).
   *
   * =======================================================================
   * PROD'DA OLCULEN CIKMAZ
   * =======================================================================
   * Callback 303 ile `OAUTH_KAYIT_DONUS` adresine gider. Bu sayfa sonucu
   * `sessionStorage`dan okur — `?oauth=` parametresini OKUMAZ; onu cozen
   * TEK sayfa `/giris/oauth`tur. `OAUTH_KAYIT_DONUS` bu sayfaya
   * (`.../kayit`) ayarlanirsa sonuc kimligi HICBIR YERDE tuketilmez:
   * sayfa bombos acilir, kullanici kayda BASTAN baslar ve DONGUYE girer.
   *
   * Prod izinde tam olarak bu gorunuyordu: `callback -> 303` ve hemen
   * ardindan `GET /auth/oauth/saglayicilar` (yani sayfa yeniden
   * yuklenmis) — arada `POST /auth/oauth/sonuc` YOK.
   *
   * Depodaki `.env.prod.example` de operatore bu YANLIS adresi
   * onermisti; ornek duzeltildi. Ama kod artik yapilandirmaya BAGIMLI
   * DEGIL: iki adres de calisir. Yanlis yapilandirmanin cezasi
   * "kullanici kaydolamaz" olmamali.
   *
   * Sonucu burada COZMEK yerine `/giris/oauth`a DEVREDIYORUZ: o sayfa
   * dort durumu (kayit / mevcut_hesap / baglama_gerekli / giris) zaten
   * dogru ele aliyor ve mantigi ikinci kez yazmak, biri degistiginde
   * otekinin eskimesi demekti.
   */
  useEffect(() => {
    const sp = new URLSearchParams(window.location.search);
    const sonucId = sp.get("oauth");
    if (!sonucId) return;
    window.location.replace(`/giris/oauth?oauth=${encodeURIComponent(sonucId)}`);
  }, []);

  /**
   * SAGLAYICIDAN DONULDU MU? `/giris/oauth` sonucu birakip buraya
   * yonlendirdiyse 3. adimdan devam edilir ve ad soyad ON-DOLDURULUR.
   */
  useEffect(() => {
    const s = kayitSosyalSonucOku();
    if (!s) return;
    if (s.rol === ROL_DENETCI) setRol(ROL_DENETCI);
    setYol("sosyal");
    setBaglamaJetonu(s.baglamaJetonu);
    // Saglayicidan gelen ad soyad forma OTOMATIK DOLAR; kullanici
    // duzeltebilir. Apple ad vermez -> alan bos kalir.
    if (s.ad) setAd(s.ad);
    setAdim("bilgiler");
  }, []);

  /**
   * (P180) TANITIM'DAN GELINDI mi? `/kayit?saglayici=X&niyet=kayit&os=1&ok=1&ot=`
   * -> OAuth'u niyet=kayit + onaylarla OTOMATIK baslat.
   */
  useEffect(() => {
    const sp = new URLSearchParams(window.location.search);
    const saglayici = sp.get("saglayici");
    if (sp.get("niyet") !== "kayit" || !saglayici) return;
    void (async () => {
      try {
        const govde = JSON.stringify({
          yuzey: "web",
          niyet: "kayit",
          onay_sozlesme: sp.get("os") === "1",
          onay_kvkk: sp.get("ok") === "1",
          onay_ticari: sp.get("ot") === "1",
        });
        const r = await fetch(
          `/api/auth/oauth/baslat/${encodeURIComponent(saglayici)}`,
          { method: "POST", headers: { "Content-Type": "application/json" }, body: govde },
        );
        const d = (await r.json().catch(() => null)) as { adres?: string } | null;
        if (!r.ok || !d?.adres) return;
        niyetiYaz("kayit");
        kayitTaslagiYaz({ rol: "yonetici" });
        window.location.href = d.adres;
      } catch {
        // Sessiz: baslatilamazsa kullanici normal kayit ekranini gorur.
      }
    })();
  }, []);

  // ============================ ADIM 3 =================================== //

  function bilgileriGonder(e: React.FormEvent) {
    e.preventDefault();
    // Telefon HÂLÂ bir alan (arka uc yoneticiden iletisim numarasi ister)
    // ama artik bir giris anahtari degil — yalniz bicim dogrulanir.
    const telHata = telefonHatasi(telefon);
    if (telHata) {
      setHata(telHata === "gecersizOnEk" ? t("telefonHataOnEk") : t("telefonHataEksik"));
      return;
    }
    if (yol === "parola" && parola !== parola2) {
      setHata(t("kayitParolaUyusmuyor"));
      return;
    }
    if (!onaySozlesme || !onayKvkk) {
      setHata(t("kayitOnayZorunlu"));
      return;
    }
    setHata(null);
    // Yonetici once YENI/KATIL secer; denetci dogrudan tesis ID'ye gider.
    if (secimGoster) {
      setAdim("secim");
    } else {
      setAdim("rolOzel");
    }
  }

  // ============================ ADIM 4 (yonetici secimi) ================= //

  function secimSec(s: YoneticiSecim) {
    setSecim(s);
    setHata(null);
    setAdim("rolOzel");
  }

  // ============================ ADIM 5 (role ozel) ======================= //

  async function rolOzelGonder(e: React.FormEvent) {
    e.preventDefault();
    setBekliyor(true);
    setHata(null);
    try {
      // --- YENI TESIS OLUSTUR --- //
      if (tesisAcar) {
        if (yol === "sosyal") {
          // Saglayici e-postayi dogruladi -> OTP yok, oturum hemen acilir.
          const y = (await gonder(UC_TESIS, {
            tesis_ad: tesisAdi.trim(),
            ad: ad.trim(),
            baglama_jetonu: baglamaJetonu,
          })) as { tesis_ad?: string; tesis_kodu?: string };
          setTesisAd(y.tesis_ad ?? tesisAdi.trim());
          setUretilenKod(y.tesis_kodu ?? "");
          setAdim("sonuc");
          return;
        }
        // PAROLA yolu: e-posta dogrulamasi ONCE gerekir. Basvuru yazilir,
        // e-postaya kod gider; TESIS ADI kod dogrulandiktan SONRA (yonetici-
        // tesis) gonderilir. Adi simdiden saklariz.
        await gonder(UC_YONETICI_BASVURU, {
          ad: ad.trim(),
          soyad: soyad.trim(),
          eposta: eposta.trim(),
          telefon: telefonNormalle(telefon),
          parola,
          onay_sozlesme: onaySozlesme,
          onay_kvkk: onayKvkk,
          onay_ticari: onayTicari,
        });
        setAdim("kod");
        return;
      }

      // --- MEVCUT TESISE KATIL --- //
      if (yol === "sosyal") {
        const y = (await gonder(UC_ROL_TAMAMLA, {
          baglama_jetonu: baglamaJetonu,
          tesis_kodu: tesisKodu.trim(),
          rol,
        })) as { durum: string; tesis_ad?: string };
        if (y.durum === "giris") {
          router.replace("/");
          router.refresh();
          return;
        }
        if (y.durum === "otp_gerekli") {
          setTesisAd(y.tesis_ad ?? "");
          setAdim("kod");
          return;
        }
        // onay_bekliyor: hesap acilmadi, yonetici onayi gerekiyor.
        setAdim("onay");
        return;
      }
      // PAROLA yolu: e-posta ile katilma baslatilir.
      const y = (await gonder(UC_ROL_EPOSTA_BASLA, {
        tesis_kodu: tesisKodu.trim(),
        eposta: eposta.trim(),
        rol,
        ad: ad.trim(),
        telefon: telefonNormalle(telefon),
      })) as { tesis_ad: string };
      setTesisAd(y.tesis_ad);
      setAdim("kod");
    } catch (err) {
      setHata(err instanceof Error ? err.message : String(err));
    } finally {
      setBekliyor(false);
    }
  }

  // ============================ ADIM 6 (e-posta kodu) ==================== //

  async function kodGonder(e: React.FormEvent) {
    e.preventDefault();
    setBekliyor(true);
    setHata(null);
    try {
      // --- YENI TESIS · PAROLA: kod dogrula -> tesis adini gonder --- //
      if (tesisAcar) {
        const d = (await gonder(UC_YONETICI_DOGRULA, {
          eposta: eposta.trim(),
          kod: kod.trim(),
        })) as { kurulum_jetonu: string };
        // Tesis adi ZATEN girildi (rolOzel'de) — kurulum jetonu ile hemen
        // tesisi ac. Ayri bir "tesis adi" adimina dusmeyiz.
        const y = (await gonder(UC_YONETICI_TESIS, {
          kurulum_jetonu: d.kurulum_jetonu,
          tesis_ad: tesisAdi.trim(),
        })) as { tesis_ad?: string; tesis_kodu?: string };
        setTesisAd(y.tesis_ad ?? tesisAdi.trim());
        setUretilenKod(y.tesis_kodu ?? "");
        setAdim("sonuc");
        return;
      }

      // --- MEVCUT TESIS · SOSYAL OTP --- //
      if (yol === "sosyal") {
        const y = (await gonder(UC_ROL_TAMAMLA_DOGRULA, {
          baglama_jetonu: baglamaJetonu,
          tesis_kodu: tesisKodu.trim(),
          rol,
          kod: kod.trim(),
        })) as { durum: string };
        if (y.durum === "onay_bekliyor") {
          setAdim("onay");
          return;
        }
        router.replace("/");
        router.refresh();
        return;
      }

      // --- MEVCUT TESIS · PAROLA --- //
      const y = (await gonder(UC_ROL_EPOSTA_DOGRULA, {
        tesis_kodu: tesisKodu.trim(),
        eposta: eposta.trim(),
        kod: kod.trim(),
      })) as { durum: string; setup_token?: string };
      if (y.durum === "onay_bekliyor" || !y.setup_token) {
        setAdim("onay");
        return;
      }
      // Parola kullanicinin 3. adimda yazdigidir — tekrar sorulmaz.
      await gonder(UC_PAROLA, { setup_token: y.setup_token, new_password: parola });
      router.replace("/");
      router.refresh();
    } catch (err) {
      setHata(err instanceof Error ? err.message : String(err));
      setBekliyor(false);
    }
  }

  function geri() {
    setHata(null);
    setAdim(geriAdim());
  }

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-md flex-col justify-center gap-6 px-5 py-10">
      <div className="flex items-center justify-between">
        <YonetioLogo size={40} />
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
              className={`${cardCls} w-full px-4 py-3 text-start transition hover:bg-yuzey-divider ${
                rol === deger ? "ring-2 ring-primary" : ""
              }`}
              aria-pressed={rol === deger}
              data-test={`kayit-rol-${deger}`}
              onClick={() => {
                setRol(deger);
                setSecim("yeni");
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
          {/* Sosyal ONCE geliyor; SosyalGiris saglayici yoksa kendini
              cizmez ve geriye yalniz elle kayit kalir. */}
          {/* ===================================================
              (P198) YONETICIDE NIYET "kayit" — "giris" DEGIL.
              ===================================================
              OLCULEN KUSUR: burasi `niyet="giris"` gonderiyordu.
              Sunucuda o niyet "bu kimlik hangi hesaba BAGLI?" sorusudur;
              yeni bir yonetici hicbir hesaba bagli olmadigi icin yanit
              `baglama_gerekli` oluyor ve `/giris/oauth` kullaniciyi
              TESIS ID formuna dusuruyordu. P185'in kabul kriteri ise
              "yeni tesis / katil" ayrimiydi — o ekran HIC gorunmuyordu.

              OLCULDU (ayni bagli-olmayan kimlik, dev API):
                  niyet=kayit -> durum='kayit'            (baglama jetonu VAR)
                  niyet=giris -> durum='baglama_gerekli'  (Tesis ID formu)

              `durum='kayit'` donunce `/giris/oauth` sonucu saklayip
              `/kayit`a geri yolluyor; sayfa `bilgiler` adimindan devam
              ediyor ve YONETICIDE `secim` (yeni/katil) adimi cikiyor.

              ROL DUYARLI: yalniz YONETICI yeni tesis acabilir. Sakin ve
              saha rolleri VAR OLAN bir tesise katilir; onlarin dogru yolu
              baglama akisidir (Tesis ID) ve `niyet="giris"` KALIR.

              ONAYLAR BURADA ALINIYOR: backend `niyet=kayit` icin iki
              zorunlu onayi `baslat` cagrisinda dogrular ve saglayiciya
              GITMEDEN once verilmis olmalari gerekir (tanitim sitesinden
              gelen akis da onlari sorgu dizesinde tasiyor). Bu yuzden
              onay kutulari bu adimda da cizilir. */}
          {yoneticiKaydi ? (
            <div className="space-y-2">
              <OnayKutulari
                sozlesme={onaySozlesme} kvkk={onayKvkk} ticari={onayTicari}
                setSozlesme={setOnaySozlesme} setKvkk={setOnayKvkk}
                setTicari={setOnayTicari} t={t}
              />
              {!onaylarTam && (
                <p className="text-sm text-metin-muted" data-test="kayit-sosyal-onay-uyari">
                  {t("kayitOnayZorunlu")}
                </p>
              )}
            </div>
          ) : null}
          {sosyalNiyetiHazir ? (
            <SosyalGiris
              niyet={sosyalNiyet}
              kayitRolu={rol}
              onaylar={{
                sozlesme: onaySozlesme,
                kvkk: onayKvkk,
                ticari: onayTicari,
              }}
            />
          ) : null}
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
            <span className="text-sm font-medium">{t("kayitAd")}</span>
            <input
              className={`${inputCls} mt-1`}
              value={ad}
              onChange={(e) => setAd(e.target.value)}
              required
              minLength={2}
              autoFocus
              autoComplete="given-name"
              data-test="kayit-ad"
            />
          </label>
          <label className="block">
            <span className="text-sm font-medium">{t("kayitSoyad")}</span>
            <input
              className={`${inputCls} mt-1`}
              value={soyad}
              onChange={(e) => setSoyad(e.target.value)}
              required
              minLength={2}
              autoComplete="family-name"
              data-test="kayit-soyad"
            />
          </label>
          <label className="block">
            <span className="text-sm font-medium">{t("kayitEposta")}</span>
            <input
              className={`${inputCls} mt-1`}
              type="email"
              value={eposta}
              onChange={(e) => setEposta(e.target.value)}
              required
              inputMode="email"
              autoComplete="email"
              data-test="kayit-eposta"
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
            {/* Telefon ARTIK bir giris anahtari degil — yalniz iletisim. */}
            <span className="mt-1 block text-xs text-metin-muted">
              {t("kayitTelefonIpucu")}
            </span>
          </label>
          {/* PAROLA YALNIZ ELLE KAYITTA: sosyal yolda kimlik
              saglayicidadir ve parola HIC yazilmaz. */}
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
          {/* IKI ZORUNLU ONAY + ISTEGE BAGLI TICARI. Arka uc de dogrular
              (istemci kilidine guvenilmez); burada UX icin engelleriz.
              (P198) Sosyal yolda AYNI kutular `yontem` adiminda cikar —
              onaylar saglayiciya gitmeden ONCE alinmali. */}
          <OnayKutulari
            sozlesme={onaySozlesme} kvkk={onayKvkk} ticari={onayTicari}
            setSozlesme={setOnaySozlesme} setKvkk={setOnayKvkk}
            setTicari={setOnayTicari} t={t}
          />
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

      {/* ============================ ADIM 4 (yonetici secimi) ========== */}
      {adim === "secim" && (
        <div className="space-y-4">
          <h2 className="font-medium">{t("kayitSecimBaslik")}</h2>
          <button
            type="button"
            data-test="kayit-secim-yeni"
            className={`${cardCls} w-full px-4 py-4 text-start transition hover:bg-yuzey-divider`}
            onClick={() => secimSec("yeni")}
          >
            <span className="block font-medium">{t("kayitSecimYeni")}</span>
            <span className="block text-sm text-metin-muted">
              {t("kayitSecimYeniAciklama")}
            </span>
          </button>
          <button
            type="button"
            data-test="kayit-secim-katil"
            className={`${cardCls} w-full px-4 py-4 text-start transition hover:bg-yuzey-divider`}
            onClick={() => secimSec("katil")}
          >
            <span className="block font-medium">{t("kayitSecimKatil")}</span>
            <span className="block text-sm text-metin-muted">
              {t("kayitSecimKatilAciklama")}
            </span>
          </button>
          <button type="button" className={`${btnGhost} w-full px-4 py-3`} onClick={geri}>
            {t("kayitGeri")}
          </button>
        </div>
      )}

      {/* ============================ ADIM 5 (role ozel) =============== */}
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
            </>
          ) : (
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

      {/* ============================ ADIM 6 (e-posta kodu) ============ */}
      {adim === "kod" && (
        <form onSubmit={kodGonder} className="space-y-4">
          <h2 className="font-medium">{t("kayitKodBaslik")}</h2>
          {/* Kod E-POSTAYA gonderildi; adres listede degilse gelmeyebilir. */}
          <p className="text-sm text-metin-body">
            {t("kayitKodEpostaAciklama", { eposta: eposta.trim() })}
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

      {/* ============================ ONAY BEKLIYOR ==================== */}
      {adim === "onay" && (
        <div className="space-y-4">
          <h2 className="font-medium">{t("kayitOnayBekliyorBaslik")}</h2>
          <p className="text-sm text-metin-body">{t("kayitOnayBekliyorAciklama")}</p>
          <Link href="/login" className="block">
            <span className={`${btnPrimary} block w-full py-3 text-center`}>
              {t("kayitGirisLinki")}
            </span>
          </Link>
        </div>
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

      {adim !== "sonuc" && adim !== "onay" ? (
        <Link href="/login" className="text-center text-sm text-primary underline">
          {t("kayitGirisLinki")}
        </Link>
      ) : null}
    </main>
  );
}
