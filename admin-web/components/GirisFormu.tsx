"use client";

import { motion, MotionConfig } from "framer-motion";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import type { ApiError } from "@/lib/types";

import { DilSecici } from "@/components/DilSecici";
import { GirisSahnesi } from "@/components/giris/sahne";
import {
  CAM_KENAR,
  CAM_KENAR_ZAYIF,
  CAM_ZEMIN,
  CAM_ZEMIN_KOYU,
  CAM_ZEMIN_MOBIL,
  EGRI_DIZI,
  GIRIS_SIRASI,
  METIN,
  METIN_IKINCIL,
  METIN_SOLUK,
  TURKUAZ,
  TURKUAZ_ACIK,
  TURKUAZ_KOYU,
} from "@/components/giris/palet";
import { CTA_GRADYANI } from "@/components/giris/stil";
import { useHareket } from "@/lib/hareket";
import { MAGAZA_ANDROID, MAGAZA_IOS } from "@/lib/config";
import { ParolaAlani } from "@/components/ParolaAlani";
import { SosyalGiris } from "@/components/SosyalGiris";
import { useT } from "@/lib/i18n/kullan";
import { telefonGiris, telefonHatasi, telefonNormalle } from "@/lib/telefon";
import type { Yuzey } from "@/lib/yuzey";

const EASE = [0.22, 1, 0.36, 1] as const;

// "Beni hatırla" için localStorage anahtarları (namespace: yonetio.rememberMe.*).
// GÜVENLİK (bilinçli karar): YALNIZ gizli-olmayan tanımlayıcılar saklanır —
// tesis slug + e-posta. PAROLA localStorage'a YAZILMAZ; tarayıcının kendi kimlik
// yöneticisi (OS keychain), parola input'undaki autocomplete="current-password"
// ile parolayı doldurur — JS-okunur depoya sır düşmez. Saklananlar normal giriş
// isteği DIŞINDA hiçbir yere gönderilmez; çıkış (logout) bunları TEMİZLEMEZ
// (yalnızca oturum çerezini siler). İleride sertleştirme: sunucu tarafı httpOnly +
// Secure + SameSite opak "remember-me" token'ı (istemci sırrı hiç görmez).
const RM_TENANT = "yonetio.rememberMe.tenant";
const RM_EMAIL = "yonetio.rememberMe.email";
// `app.*` telefonla giriyor; hatirlanan tanimlayici da numaradir.
const RM_TELEFON = "yonetio.rememberMe.telefon";

// BFF uclari MODUL DUZEYINDE sabit: ucluda satir-ici dizge yazmak
// `sabit-metin` taramasini (hakli olarak) tetikliyor — o tarama ucludaki
// her dizgeyi "cevrilmemis metin" adayi sayar.
const UC_TELEFON = "/api/auth/login-phone";
const UC_EPOSTA = "/api/auth/login";

export function GirisFormu({ yuzey }: { yuzey: Yuzey }) {
  // (P126 sonrasi) GIRIS YOLU YUZEYE GORE.
  //
  // `app.*` mobil uygulamanin web ikizidir: tesis kullanicisi mobilde
  // TELEFON + PAROLA ile giriyor (`POST /auth/login-phone`), tenant kodu
  // sorulmuyor (telefon global benzersiz). Ayni kisiye web'de tesis kodu ve
  // e-posta sormak, mobilde istenmeyen iki bilgiyi istemek olurdu — ustelik
  // `resident` hesaplarinda e-posta cogu zaman YOK.
  //
  // `panel.*` platform sahibinindir ve orada tam tersi gecerli: platform
  // admini bir tesise ait degildir, telefonu bir tenant'a cozulmez. Orada
  // e-posta + tesis kodu KALIR.
  const telefonla = yuzey === "tesis";
  const t = useT();
  const router = useRouter();
  const [telefon, setTelefon] = useState("");
  const [tenantSlug, setTenantSlug] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [rememberMe, setRememberMe] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [magazaGoster, setMagazaGoster] = useState(false);
  const [loading, setLoading] = useState(false);
  // (P162) BASARI ANIMASYONU (sartname §40): dugme loading -> onay -> kart
  // soluklasarak panele gecis. Yonlendirme bu bayrak dolayisiyla KISA BIR
  // SURE geciktirilir; akis degismez, yalnizca gorunur hale gelir.
  const [basarili, setBasarili] = useState(false);
  // Hata TITREMESI icin sayac: ayni hata iki kez gelirse de animasyon
  // tekrar calissin diye anahtar olarak kullaniliyor.
  const [hataSayaci, setHataSayaci] = useState(0);
  const hareketVar = useHareket();
  const [mobil, setMobil] = useState(false);
  useEffect(() => {
    setMobil(window.matchMedia?.("(max-width: 768px)").matches ?? false);
  }, []);

  // Mount: saklanmış tesis+e-posta varsa ÖN-DOLDUR + kutuyu işaretle. Parola
  // saklanmaz; tarayıcı autofill (autocomplete) parolayı kendi keychain'inden
  // önerir. (Yalnız istemcide çalışır — SSR/hydration uyumsuzluğu yok.)
  useEffect(() => {
    try {
      if (telefonla) {
        const tel = localStorage.getItem(RM_TELEFON);
        if (tel !== null) {
          setTelefon(telefonGiris(tel));
          setRememberMe(true);
        }
        return;
      }
      const t = localStorage.getItem(RM_TENANT);
      const e = localStorage.getItem(RM_EMAIL);
      if (t !== null && e !== null) {
        setTenantSlug(t);
        setEmail(e);
        setRememberMe(true);
      }
    } catch {
      // localStorage erişilemezse (özel mod vb.) sessizce ön-doldurma yok.
    }
  }, [telefonla]);

  function persistRememberMe() {
    try {
      if (rememberMe) {
        // YALNIZ gizli-olmayan tanımlayıcılar (parola değil).
        if (telefonla) {
          localStorage.setItem(RM_TELEFON, telefonNormalle(telefon));
        } else {
          localStorage.setItem(RM_TENANT, tenantSlug);
          localStorage.setItem(RM_EMAIL, email);
        }
      } else {
        localStorage.removeItem(RM_TELEFON);
        localStorage.removeItem(RM_TENANT);
        localStorage.removeItem(RM_EMAIL);
      }
    } catch {
      // Depolama yoksa sessizce geç (giriş yine de başarılı).
    }
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setMagazaGoster(false);
    // TELEFON DOGRULAMASI ISTEMCIDE (P123): eksik/hatali numarayla istek
    // gondermek sunucudan anlasilmaz bir 401 aldirirdi ("numara mi parola
    // mi yanlis?" — sunucu adimi bilincli olarak sizdirmiyor).
    if (telefonla) {
      const th = telefonHatasi(telefon);
      if (th) {
        setError(th === "gecersizOnEk" ? t("telefonHataOnEk") : t("telefonHataEksik"));
        setHataSayaci((n) => n + 1);
        return;
      }
    }
    setLoading(true);
    try {
      const govde = telefonla
        ? { phone: telefonNormalle(telefon), password }
        : { tenant_slug: tenantSlug, email, password };
      let uc = UC_EPOSTA;
      if (telefonla) uc = UC_TELEFON;
      const res = await fetch(uc, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(govde),
      });
      if (!res.ok) {
        const data = (await res.json().catch(() => null)) as ApiError | null;
        // Sunucu metni ONCE (tur 14'ten beri istegin dilinde gelir); yoksa
        // panel sozlugunden genel metin.
        setError(data?.error?.message ?? t("girisBasarisiz"));
        setHataSayaci((n) => n + 1);
        // (P129) MOBIL-YALNIZ ROL: sunucu 403 + `mobil_uygulama` kodu
        // doner. Magaza baglantilari ancak TANIMLIYSA cizilir (bkz.
        // lib/config.ts) — uygulama yayinda degilken 404'e giden bir
        // baglanti vermektense hic vermemek dogru.
        setMagazaGoster(data?.error?.code === "mobil_uygulama");
        return;
      }
      // Başarılı giriş: işaretliyse bilgileri sakla, değilse temizle.
      persistRememberMe();
      // BASARI: once onay durumu cizilir, sonra yonlendirilir. 520 ms
      // kartin soluklasmasina yeter ve kullaniciya "oldu" der; daha uzun
      // olsaydi bekleme hissi verirdi.
      setBasarili(true);
      await new Promise((c) => setTimeout(c, 520));
      // KOKE GIDILIR, PANOYA DEGIL: `/` middleware'de ROLE gore cozulur
      // (kokRotaRol) — yonetici Pano'ya, sakin Aidatim'a, guvenlik
      // Ziyaretciler'e, saha gorevlisi Gorevlerim'e duser. Burada sabit
      // `/dashboard` yazmak, panoyu goremeyen uc rolu bos ekrana yollardi.
      router.replace("/");
      router.refresh();
    } catch {
      setError(t("ortakSunucuyaUlasilamadi"));
    } finally {
      setLoading(false);
    }
  }

  // ------------------------------------------------------------------
  // (P162) SUNUM KATMANI — sartname `docs/design-refs`.
  //
  // MEVCUT KIMLIK AKISI DEGISMEDI: yukaridaki durum, dogrulama, uc
  // secimi, "beni hatirla" ve yonlendirme AYNEN duruyor. Burasi yalnizca
  // gorunum ve hareket.
  //
  // PALET AYRI (brief'in acik karari): giris VITRIN, panel CALISMA ALANI.
  // Vitrin deep navy + turkuaz; panelin `--yz-*` metalik dili buraya
  // GIRMEZ. Gecis sertligi `basarili` durumundaki soluklasmayla yumusar.
  // ------------------------------------------------------------------
  const alanSinifi =
    "w-full rounded-xl px-3.5 py-2.5 text-sm outline-none transition-[border-color,box-shadow,background] duration-[250ms]";
  const alanStili: React.CSSProperties = {
    background: CAM_ZEMIN_KOYU,
    // KENAR UC AYRI OZELLIK: `border: "1px solid X"` kisayolu bir SABLON
    // DIZGESI olurdu ve depo taramasi (hakli olarak) sablon icindeki
    // metni cevrilmemis dize sayiyor.
    borderWidth: "1px",
    borderStyle: "solid",
    borderColor: CAM_KENAR_ZAYIF,
    color: METIN,
  };
  const etiketSinifi = "mb-1.5 block text-sm font-medium";
  const etiketStili: React.CSSProperties = { color: METIN_IKINCIL };

  /** Sahne giris zamanlamasi (§28) — hareket kapaliysa hepsi 0. */
  const giris = (gecikme: number) => ({
    initial: { opacity: 0, y: 14 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: 0.62, ease: EGRI_DIZI, delay: hareketVar ? gecikme : 0 },
  });

  return (
    <MotionConfig reducedMotion="user">
      <main
        className="relative flex min-h-screen w-full flex-col overflow-hidden lg:grid lg:grid-cols-[1.15fr_1fr]"
        style={{ background: "#061426" }}
      >
        <GirisSahnesi hareketVar={hareketVar} mobil={mobil} />

        {/* ---- DIL SECICI (§23) — sag ust ---- */}
        <div className="absolute end-4 top-4 z-30 sm:end-6 sm:top-6">
          <DilSecici />
        </div>

        {/* ---- SOL: marka + hero (§2, §20) ---- */}
        <section className="relative z-10 flex min-w-0 flex-col justify-between px-6 pb-6 pt-20 sm:px-10 lg:px-14 lg:py-14">
          <motion.div {...giris(GIRIS_SIRASI.logo)}>
            {/* MARKA BANNERI — brief: "giris sayfasinin SOL tarafinda".
                ACIK (ters) varyant kullaniliyor: marka murekkebi koyu
                lacivert ve zemin de deep navy; olculdugunde kontrast
                orani ~1.2 cikiyordu, yani marka kayboluyordu. */}
            <Image
              src="/yonetio-marka-acik.png"
              alt="Yönetiyor"
              width={1271}
              height={339}
              priority
              className="h-9 w-auto transition-transform duration-300 hover:scale-[1.02] sm:h-11"
            />
          </motion.div>

          <div className="max-w-[520px] py-10 lg:py-0">
            <motion.h1
              {...giris(GIRIS_SIRASI.baslik)}
              className="break-words text-[28px] font-semibold leading-[1.1] tracking-[-1px] sm:text-[40px] lg:text-[52px] lg:tracking-[-1.5px]"
              style={{ color: METIN }}
            >
              {t("girisSloganBaslik")}
            </motion.h1>
            <motion.p
              {...giris(GIRIS_SIRASI.aciklama)}
              className="mt-5 break-words text-base leading-relaxed"
              style={{ color: METIN_IKINCIL }}
            >
              {t("girisSloganAlt")}
            </motion.p>
          </div>

          <motion.div
            {...giris(GIRIS_SIRASI.aciklama)}
            className="text-xs"
            style={{ color: METIN_SOLUK }}
          >
            © {t("girisAltBilgi")}
          </motion.div>
        </section>

        {/* ---- SAG: glassmorphism giris karti (§11, §12) ---- */}
        <section className="relative z-10 flex min-w-0 items-center justify-center px-4 pb-12 sm:px-8 lg:pb-0">
          <motion.form
            onSubmit={onSubmit}
            initial={{ opacity: 0, y: 30, scale: 0.97 }}
            animate={
              basarili
                ? { opacity: 0, y: 0, scale: 0.98 }
                : { opacity: 1, y: 0, scale: 1 }
            }
            transition={{
              duration: basarili ? 0.42 : 0.9,
              ease: EGRI_DIZI,
              delay: basarili || !hareketVar ? 0 : GIRIS_SIRASI.kart,
            }}
            // HOVER: cok kucuk kalkis (§13). `rotateX/Y` BILINCLI OLARAK
            // YOK — form alanlarinin uzerindeyken egilen bir yuzey, imleç
            // ile alanin gercek yeri arasinda kayma uretiyordu.
            whileHover={hareketVar ? { y: -3 } : undefined}
            className="w-[calc(100%-32px)] max-w-[420px] space-y-5 p-7 sm:w-full sm:p-8"
            style={{
              // MOBILDE DAHA OPAK ZEMIN — olculdu.
              //
              // Sartname §31 mobilde yogun blur'u yasakliyor, o yuzden
              // `backdrop-filter` kapali. Ama cam yuzey (%8 beyaz) tek
              // basina AYIRMIYOR: blur olmayinca arkadaki partikuller
              // kartin uzerinden KESKIN gorunuyor ve etiketler okunmuyor
              // (ekran goruntusuyle goruldu). Mobilde ayirmayi blur degil
              // OPAKLIK yapiyor.
              background: mobil ? CAM_ZEMIN_MOBIL : CAM_ZEMIN,
              backdropFilter: mobil ? undefined : "blur(25px)",
              WebkitBackdropFilter: mobil ? undefined : "blur(25px)",
              borderWidth: "1px",
              borderStyle: "solid",
              borderColor: CAM_KENAR,
              borderRadius: "18px",
              boxShadow: "0 25px 80px rgba(0,0,0,0.35)",
            }}
          >
            <div>
              <h2
                className="break-words text-xl font-semibold tracking-tight"
                style={{ color: METIN }}
              >
                {telefonla ? t("girisCalismaAlani") : t("girisYonetimPaneli")}
              </h2>
              <p className="mt-1 text-sm" style={{ color: METIN_SOLUK }}>
                {telefonla ? t("girisTumRoller") : t("girisYalnizAdmin")}
              </p>
            </div>

            {telefonla ? (
              <label className="block">
                <span className={etiketSinifi} style={etiketStili}>
                  {t("kullaniciTelefon")}
                </span>
                <input
                  key={`tel-${hataSayaci}`}
                  type="tel"
                  inputMode="numeric"
                  className={`${alanSinifi} giris-alan${error ? " giris-titre" : ""}`}
                  style={alanStili}
                  // (P123) TEK bicimlendirici — 05XX XXX XX XX.
                  value={telefonGiris(telefon)}
                  onChange={(e) => setTelefon(telefonGiris(e.target.value))}
                  placeholder={t("kullaniciTelefonOrnek")}
                  autoComplete="username"
                  aria-label={t("kullaniciTelefon")}
                  required
                />
                <span className="mt-1.5 block text-xs" style={{ color: METIN_SOLUK }}>
                  {t("girisTelefonYardim")}
                </span>
              </label>
            ) : (
              <>
                <label className="block">
                  <span className={etiketSinifi} style={etiketStili}>
                    {t("girisTesisSlug")}
                  </span>
                  <input
                    className={`${alanSinifi} giris-alan`}
                    style={alanStili}
                    value={tenantSlug}
                    onChange={(e) => setTenantSlug(e.target.value)}
                    placeholder="yonetio"
                    autoComplete="organization"
                    aria-label={t("girisTesisSlug")}
                    required
                  />
                </label>

                <label className="block">
                  <span className={etiketSinifi} style={etiketStili}>
                    {t("girisEposta")}
                  </span>
                  <input
                    key={`eposta-${hataSayaci}`}
                    type="email"
                    className={`${alanSinifi} giris-alan${error ? " giris-titre" : ""}`}
                    style={alanStili}
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    autoComplete="username"
                    aria-label={t("girisEposta")}
                    required
                  />
                </label>
              </>
            )}

            <label className="block">
              <span className={etiketSinifi} style={etiketStili}>
                {t("girisParola")}
              </span>
              <ParolaAlani
                className={`${alanSinifi} giris-alan`}
                style={alanStili}
                value={password}
                onChange={setPassword}
                autoComplete="current-password"
                minLength={8}
                required
              />
            </label>

            <label className="flex cursor-pointer select-none items-center gap-2.5">
              <input
                type="checkbox"
                checked={rememberMe}
                onChange={(e) => setRememberMe(e.target.checked)}
                className="h-4 w-4 rounded"
                style={{ accentColor: TURKUAZ }}
              />
              <span className="text-sm" style={{ color: METIN_IKINCIL }}>
                {t("girisBeniHatirla")}
              </span>
            </label>

            {error && (
              <motion.p
                role="alert"
                initial={{ opacity: 0, y: -4 }}
                animate={{ opacity: 1, y: 0 }}
                className="rounded-lg px-3 py-2 text-sm"
                style={{
                  background: "rgba(220,80,80,0.12)",
                  borderWidth: "1px",
                  borderStyle: "solid",
                  borderColor: "rgba(255,140,140,0.35)",
                  color: "#FFC9C9",
                }}
              >
                {error}
              </motion.p>
            )}

            {/* KAYIT BAGLANTISI YALNIZ `app.*`TA — `panel.*` platform
                sahibinindir ve oraya yalniz `admin` girer. */}
            {yuzey === "tesis" && (
              <p className="text-center text-sm">
                <a
                  href="/kayit"
                  className="giris-bag inline-block"
                  style={{ color: TURKUAZ_ACIK }}
                >
                  {t("kayitBaslik")}
                </a>
              </p>
            )}

            {magazaGoster && (MAGAZA_ANDROID || MAGAZA_IOS) && (
              <p className="flex gap-3 text-sm">
                {MAGAZA_ANDROID && (
                  <a
                    className="underline"
                    style={{ color: TURKUAZ_ACIK }}
                    href={MAGAZA_ANDROID}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {t("girisMagazaAndroid")}
                  </a>
                )}
                {MAGAZA_IOS && (
                  <a
                    className="underline"
                    style={{ color: TURKUAZ_ACIK }}
                    href={MAGAZA_IOS}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {t("girisMagazaIos")}
                  </a>
                )}
              </p>
            )}

            <motion.button
              {...(hareketVar
                ? { initial: { opacity: 0 }, animate: { opacity: 1 },
                    transition: { delay: GIRIS_SIRASI.cta, duration: 0.5, ease: EGRI_DIZI } }
                : {})}
              whileHover={hareketVar ? { y: -1, scale: 1.01 } : undefined}
              whileTap={hareketVar ? { scale: 0.985 } : undefined}
              type="submit"
              disabled={loading || basarili}
              className="giris-cta odak-ters inline-flex w-full items-center justify-center gap-2 rounded-xl py-3 text-sm font-semibold transition-shadow disabled:opacity-70"
              style={{
                background: CTA_GRADYANI,
                color: "#04222A",
                boxShadow: "0 10px 30px rgba(20,200,190,0.20)",
              }}
            >
              {basarili ? (
                <>
                  {/* ONAY (§40): metin yerine kisa bir tik. */}
                  <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                    <path d="M5 13l4 4L19 7" />
                  </svg>
                  {t("girisBasarili")}
                </>
              ) : (
                <>
                  {loading && (
                    <span className="h-4 w-4 animate-spin rounded-full border-2 border-black/25 border-t-black/70" />
                  )}
                  {loading ? t("girisYapiliyor") : t("girisYap")}
                </>
              )}
            </motion.button>

            {/* SOSYAL GIRIS — parola formunun ALTINDA (ek yol, ana yol degil). */}
            <div>
              <SosyalGiris niyet="giris" />
            </div>
          </motion.form>
        </section>
      </main>
    </MotionConfig>
  );
}
