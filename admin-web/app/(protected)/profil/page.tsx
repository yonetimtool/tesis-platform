"use client";

// (P126.3 / P167 §1.7) PROFIL — her tesis rolunun kendi kaydi.
//
// `app.*`in ilk KENDINE AIT sayfasi: bugune kadar paneldeki 25 sayfa
// yonetimin BASKALARINI yonettigi ekranlardi; bu, kullanicinin kendi
// kaydina dokundugu ilk yer.
//
// =====================================================================
// (P167 §1.7) SAYFA KENDI SOL MENUSUYLE ACILIR
// =====================================================================
// Eskiden tek bir uzun kolondu (kimlik + iletisim + giris yontemleri) ve
// bu tur ona uc bolum daha ekliyor (cihazlar, bildirimler, sifre, hesap
// silme). Altisini alt alta dizmek, kullaniciyi "sifremi nereden
// degistiriyordum" sorusuyla her seferinde sayfayi kaydirmaya zorlardi.
//
// BOLUM LISTESI `lib/profil-bolumleri.ts`TE, BURADA DEGIL: ayni liste sag
// ust kullanici menusunde de ciziliyor. Iki yerde elle tekrar edilseydi,
// biri eklenip oteki unutuldugunda menude gorunen ama sayfada ACILMAYAN
// bir satir kalirdi.
//
// SECIM ADRESTEN OKUNUR (`?bolum=guvenlik`): sag ust menuden "Sifre
// degistir"e tiklayan kullanici dogrudan o bolumde acilmali. Sayfa ici
// bir sekme durumu, o baglantilari calismaz kilardi.
//
// SUNUCU UCLARI: `GET /me/profile`, `PATCH /me/contact`, `PATCH /me/password`,
// `PATCH /me/avatar`, `GET /me/cihazlar`, `DELETE /me/cihazlar/{id}`,
// `POST /me/cihazlar/tumunden-cik`, `GET /me/etkinlik`,
// `GET|PATCH /me/bildirim-tercihleri`, `POST /me/hesap-sil`.
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import useSWR from "swr";

import { Avatar } from "@/components/Avatar";
import { YasalMetinler } from "@/components/profil/yasal-metinler";
import { GirisYontemlerim } from "@/components/GirisYontemlerim";
import { EpostaDogrulaKart } from "@/components/profil/eposta-dogrula-kart";
import { ParolaAlani } from "@/components/ParolaAlani";
import { TelefonAlani, telefonHataMetni } from "@/components/TelefonAlani";
import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Secim,
  useOnay,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { DILLER, DIL_ADLARI, type Dil } from "@/lib/i18n/diller";
import { useI18n, useT } from "@/lib/i18n/kullan";
import {
  PROFIL_BOLUMLERI,
  PROFIL_BOLUM_IDLERI,
  type ProfilBolumId,
} from "@/lib/profil-bolumleri";
import { useSorguSecimi } from "@/lib/sorgu-secimi";
import { tarihSaatBicimi } from "@/lib/tarih";
import { telefonGiris, telefonNormalle } from "@/lib/telefon";

type Profil = {
  id: string;
  ad: string;
  email: string | null;
  eposta_dogrulandi: boolean;
  telefon: string | null;
  aranabilir: boolean;
  role: string;
  avatar_url: string | null;
};

type Cihaz = {
  id: string;
  platform: string;
  dil: string;
  aktif: boolean;
  created_at: string;
  updated_at: string;
};

type Etkinlik = {
  id: string;
  action: string;
  resource_type: string | null;
  resource_id: string | null;
  ts: string;
  meta: Record<string, unknown>;
};

type Bildirimler = {
  bildirim_eposta: boolean;
  bildirim_sms: boolean;
  bildirim_mobil: boolean;
};

type PresignBileti = { upload_url: string; foto_key: string };

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`) — `AppShell` ile ayni desen.
const SEFFAF = "transparent";
const GOLGESIZ = "none";

export default function ProfilPage() {
  const t = useT();
  const [bolum, setBolum] = useSorguSecimi<ProfilBolumId>(
    "bolum",
    PROFIL_BOLUM_IDLERI,
    "hesap",
  );
  const { data, error, isLoading, mutate } = useSWR<Profil>(
    "/api/me",
    jsonFetcher,
  );

  return (
    <div className="space-y-6">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("profilBaslik")}
      </h1>

      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}

      {/* (P181 Bölüm 1) E-postasız/doğrulanmamış kullanıcıya beklemede kartı; kilitleme yok, yalnız davet. */}
      {data && !data.eposta_dogrulandi ? (
        <div
          className="space-y-3 rounded-xl border p-4"
          style={{
            borderColor: "var(--yz-border)",
            background: "var(--yz-surface-1)",
          }}
        >
          <EpostaDogrulaKart
            mevcutEposta={data.email}
            dogrulandi={Boolean(data.eposta_dogrulandi)}
            onDone={() => void mutate()}
          />
        </div>
      ) : null}

      <div className="grid gap-6 lg:grid-cols-[13rem_minmax(0,1fr)]">
        {/* SAYFA ICI SOL MENU — `nav` etiketi bilincli: ekran okuyucu
            kullanicisi bunu bir gezinme bolgesi olarak atlayabilmeli. */}
        {/* (P169 §4) DAR EKRANDA YATAY SERIT, GENISTE DIKEY MENU.
            Dikey menu dar ekranda icerigin USTUNE bes satirlik bir blok
            koyuyor ve kullanici asil formu gormek icin her girisinde
            asagi kaydiriyordu. Karar SALT CSS: `useBant` gerekmedi,
            dolayisiyla sunucu/istemci farki ve hidrasyon riski de yok.
            `lg` ve ustu HIC DEGISMEDI. */}
        <nav
          aria-label={t("profilBolumMenusu")}
          className="-mx-1 flex gap-1 overflow-x-auto px-1 pb-1 lg:mx-0 lg:block lg:space-y-1 lg:overflow-visible lg:px-0 lg:pb-0"
        >
          {PROFIL_BOLUMLERI.map((b) => {
            const aktif = b.id === bolum;
            return (
              <button
                key={b.id}
                type="button"
                onClick={() => setBolum(b.id)}
                aria-current={aktif ? "page" : undefined}
                // `shrink-0` + `whitespace-nowrap` seridin sikismasini
                // onler; `lg:w-full` dikey kipte eski genisligi geri verir.
                className="odak-ic block shrink-0 whitespace-nowrap px-3 py-2 text-start transition lg:w-full"
                style={{
                  borderRadius: "var(--yz-radius-btn)",
                  fontSize: "var(--yz-fs-sm)",
                  // Aktiflik RENKLE degil YUZEYLE anlatilir — kenar
                  // cubugundaki (P160) dille ayni.
                  background: aktif ? "var(--yz-metal-2)" : SEFFAF,
                  boxShadow: aktif ? "var(--yz-raised)" : GOLGESIZ,
                  color: b.tehlikeli
                    ? "var(--yz-danger-ink)"
                    : aktif
                      ? "var(--yz-text)"
                      : "var(--yz-text-2)",
                }}
              >
                {t(b.anahtar)}
              </button>
            );
          })}
        </nav>

        <div className="min-w-0">
          {isLoading ? (
            <IskeletMetin satir={5} />
          ) : bolum === "hesap" ? (
            <HesapBilgileri profil={data} tazele={() => void mutate()} />
          ) : bolum === "guvenlik" ? (
            <GuvenlikVeGiris />
          ) : bolum === "bildirim" ? (
            <BildirimAyarlari />
          ) : bolum === "yasal" ? (
            <YasalMetinler />
          ) : bolum === "sifre" ? (
            <SifreDegistir parolaVar={Boolean(data)} />
          ) : (
            <HesabimiSil />
          )}
        </div>
      </div>
    </div>
  );
}

/* ===================================================================== */
/* 1. HESAP BILGILERI                                                    */
/* ===================================================================== */

function HesapBilgileri({
  profil,
  tazele,
}: {
  profil: Profil | undefined;
  tazele: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const { dil, dilDegistir } = useI18n();
  const dosyaRef = useRef<HTMLInputElement>(null);

  const [ad, setAd] = useState("");
  const [adHatasi, setAdHatasi] = useState<string | null>(null);
  const [telefon, setTelefon] = useState("");
  const [telefonHatasiMetni, setTelefonHatasiMetni] = useState<string | null>(null);
  const [aranabilir, setAranabilir] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);
  const [fotoYukleniyor, setFotoYukleniyor] = useState(false);

  // Sunucudan gelen deger forma BIR KEZ yuklenir; kullanici yazarken
  // SWR yeniden dogrulamasi yazdigini EZMESIN.
  useEffect(() => {
    if (!profil) return;
    setAd(profil.ad);
    setTelefon(telefonGiris(profil.telefon ?? ""));
    // `?? false` SART: onay kutusu DENETIMLIDIR ve `undefined` gormesi
    // React'te denetimliden denetimsize gecis demek.
    setAranabilir(profil.aranabilir ?? false);
  }, [profil?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  async function kaydet() {
    // (P166 §9) HATA ALANIN YANINA yazilir, sayfanin ustundeki kutuya
    // DEGIL: ikisi birden cizilirse kullanici ayni cumleyi iki yerde
    // okur ve ikinci bir sorun oldugunu sanir.
    if (!ad.trim()) {
      setAdHatasi(t("profilAdZorunlu"));
      return;
    }
    const telHata = telefonHataMetni(telefon, false, t);
    if (telHata) {
      setTelefonHatasiMetni(telHata);
      return;
    }
    setAdHatasi(null);
    setTelefonHatasiMetni(null);
    setHata(null);
    setKaydediyor(true);
    try {
      await apiSend("/api/me/contact", "PATCH", {
        ad: ad.trim(),
        // Sunucuya NORMALLESTIRILMIS gider (P123); bossa acik null → kaldir.
        telefon: telefonNormalle(telefon) || null,
        aranabilir,
      });
      toast.success(t("profilKaydedildi"));
      tazele();
    } catch (e) {
      // SUNUCU metni aynen gosterilir (tur 14: istegin dilinde gelir).
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setKaydediyor(false);
    }
  }

  /**
   * FOTOGRAF: presign → dogrudan MinIO'ya PUT → anahtar sunucuya.
   *
   * Dosya BFF'ten GECMEZ (duyuru gorseliyle ayni akis): Next sunucusunu
   * megabaytlarca ikili veriye araci yapmak, hem bellek hem zaman asimi
   * riski demekti.
   *
   * SECILIR SECILMEZ KAYDEDILIR, "Kaydet"i BEKLEMEZ: avatar formun bir
   * alani degil, kendi basina bir islem. Kaydet'e baglasaydik kullanici
   * fotografi degistirip telefon alaninda hata alinca fotografi da
   * kaybederdi.
   */
  async function fotoSec(e: React.ChangeEvent<HTMLInputElement>) {
    const dosya = e.target.files?.[0];
    if (!dosya) return;
    setFotoYukleniyor(true);
    setHata(null);
    try {
      const bilet = await apiSend<PresignBileti>("/api/uploads/presign", "POST", {
        content_type: dosya.type || "image/jpeg",
        dosya_adi: dosya.name,
      });
      const put = await fetch(bilet.upload_url, {
        method: "PUT",
        headers: { "Content-Type": dosya.type || "image/jpeg" },
        body: dosya,
      });
      if (!put.ok) throw new Error(t("yuklemeBasarisiz", { kod: put.status }));
      await apiSend("/api/me/avatar", "PATCH", { avatar_key: bilet.foto_key });
      toast.success(t("profilFotoGuncellendi"));
      tazele();
    } catch (err) {
      setHata(err instanceof Error ? err.message : t("profilFotoYuklenemedi"));
    } finally {
      setFotoYukleniyor(false);
      // Girdi TEMIZLENIR: ayni dosya ikinci kez secildiginde `change`
      // olayi tetiklenmezdi (deger degismiyor) ve "hicbir sey olmuyor"
      // gibi gorunurdu.
      if (dosyaRef.current) dosyaRef.current.value = "";
    }
  }

  async function fotoKaldir() {
    setFotoYukleniyor(true);
    try {
      // `null` = kaldir. Eski obje MinIO'dan SUNUCUDA silinir — erisilemez
      // cop birakilmaz.
      await apiSend("/api/me/avatar", "PATCH", { avatar_key: null });
      toast.success(t("profilFotoGuncellendi"));
      tazele();
    } catch (err) {
      setHata(err instanceof Error ? err.message : t("ortakHataOlustu"));
    } finally {
      setFotoYukleniyor(false);
    }
  }

  return (
    <Kart>
      <div className="space-y-6">
        <section className="space-y-3">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("profilFotograf")}
          </h2>
          <div className="flex flex-wrap items-center gap-4">
            <Avatar ad={profil?.ad ?? ""} src={profil?.avatar_url} boy={72} />
            <div className="flex flex-wrap gap-2">
              {/* GIZLI GIRDI + GORUNUR DUGME: tarayicinin yerel dosya
                  dugmesi temayi tanimaz ve her platformda baska gorunur.
                  Etiket yerine dugme kullanildi ki odak halkasi ortak
                  `odak-ic` sinifiyla ayni olsun. */}
              <input
                ref={dosyaRef}
                type="file"
                accept="image/*"
                className="sr-only"
                onChange={(e) => void fotoSec(e)}
                aria-label={t("profilFotoYukle")}
              />
              <Dugme
                tur="ikincil"
                boy="kucuk"
                disabled={fotoYukleniyor}
                onClick={() => dosyaRef.current?.click()}
              >
                {fotoYukleniyor ? t("profilFotoYukleniyor") : t("profilFotoYukle")}
              </Dugme>
              {profil?.avatar_url && (
                <Dugme
                  tur="ikincil"
                  boy="kucuk"
                  disabled={fotoYukleniyor}
                  onClick={() => void fotoKaldir()}
                >
                  {t("profilFotoKaldir")}
                </Dugme>
              )}
            </div>
          </div>
        </section>

        <section className="grid gap-4 sm:max-w-md">
          <AlanSarmal etiket={t("profilAd")} hata={adHatasi} zorunlu>
            {(baglar) => (
              <Alan
                {...baglar}
                value={ad}
                hatali={Boolean(adHatasi)}
                autoComplete="name"
                onChange={(e) => {
                  setAd(e.target.value);
                  setAdHatasi(null);
                }}
              />
            )}
          </AlanSarmal>

          {/* E-POSTA SALT OKUNUR ve bu bilincli bir karar.
              Bu sistemde e-posta LOGIN ANAHTARIDIR ve dogrulama akisi
              yoktur. Dogrulamasiz degistirilebilseydi (a) odunc alinmis
              bir oturum adresi degistirip hesabin sahibini kalici olarak
              disarida birakabilir, (b) yanlis yazilan bir adres parola
              sifirlamayi SESSIZCE calismaz kilardi. Alan gosterilir —
              gizlemek "neden yok?" sorusu uretirdi — ama nedeni yazili. */}
          <AlanSarmal etiket={t("profilEposta")} ipucu={t("profilEpostaKilitli")}>
            {(baglar) => (
              <Alan {...baglar} value={profil?.email ?? ""} readOnly disabled />
            )}
          </AlanSarmal>

          <TelefonAlani
            etiket={t("kullaniciTelefon")}
            ipucu={t("profilTelefonIpucu")}
            deger={telefon}
            hata={telefonHatasiMetni}
            onDegisti={(v) => {
              setTelefon(v);
              setTelefonHatasiMetni(null);
            }}
          />

          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={aranabilir}
              onChange={(e) => setAranabilir(e.target.checked)}
            />
            {t("profilAranabilir")}
          </label>

          {/* DIL SECIMI SAG USTTEKIYLE AYNI DEGERI YAZAR (`dilDegistir`
              cerezi gunceller). Ikinci bir tercih kaydi acmadik: iki
              yerde iki farkli dil ayari, "hangisi gecerli?" sorusunu
              ureten tam olarak o tekrardir. */}
          <AlanSarmal etiket={t("profilDil")}>
            {(baglar) => (
              <Secim
                {...baglar}
                value={dil}
                onChange={(e) => dilDegistir(e.target.value as Dil)}
              >
                {DILLER.map((d) => (
                  <option key={d} value={d}>
                    {DIL_ADLARI[d]}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>

          <HataDurumu mesaj={hata} />
          <div>
            <Dugme tur="birincil" disabled={kaydediyor} onClick={() => void kaydet()}>
              {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </div>
        </section>
      </div>
    </Kart>
  );
}

/* ===================================================================== */
/* 2. GUVENLIK VE GIRIS                                                  */
/* ===================================================================== */

function GuvenlikVeGiris() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();
  const { data: cihazlar, mutate: cihazTazele } = useSWR<Cihaz[]>(
    "/api/me/cihazlar",
    jsonFetcher,
  );
  const { data: etkinlik } = useSWR<Etkinlik[]>(
    "/api/me/etkinlik?limit=20",
    jsonFetcher,
  );
  const [acikSatir, setAcikSatir] = useState<string | null>(null);

  async function kaldir(id: string) {
    try {
      await apiSend(`/api/me/cihazlar/${id}`, "DELETE");
      toast.success(t("profilCihazKaldirildi"));
      void cihazTazele();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  async function tumunuKaldir() {
    if (
      !(await onayla({
        baslik: t("profilTumundenCik"),
        mesaj: t("profilTumundenCikOnay"),
        onayMetni: t("profilTumundenCik"),
        tehlikeli: true,
      }))
    ) {
      return;
    }
    try {
      const sonuc = await apiSend<{ kaldirilan: number }>(
        "/api/me/cihazlar/tumunden-cik",
        "POST",
        {},
      );
      toast.success(t("profilTumundenCikildi", { adet: String(sonuc.kaldirilan) }));
      void cihazTazele();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  return (
    <div className="space-y-6">
      {diyalog}

      {/* GIRIS YONTEMLERI BU BOLUME TASINDI: sosyal hesap baglamak bir
          "iletisim bilgisi" degil bir GIRIS yontemidir; bolumun adi da
          "Guvenlik ve giris". */}
      <GirisYontemlerim />

      <Kart>
        <div className="space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {t("profilCihazlar")}
            </h2>
            {(cihazlar?.some((c) => c.aktif) ?? false) && (
              <Dugme tur="ikincil" boy="kucuk" onClick={() => void tumunuKaldir()}>
                {t("profilTumundenCik")}
              </Dugme>
            )}
          </div>
          {/* DURUST ETIKET: dugme oturumlari sonlandirmiyor, bildirim
              kayitlarini kaldiriyor. Kullaniciyi guvende SANDIGI ama
              olmadigi bir yerde birakmamak icin bu cumle sart. */}
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
            {t("profilCihazNot")}
          </p>
          {!cihazlar ? (
            <IskeletMetin satir={2} />
          ) : cihazlar.length === 0 ? (
            <BosDurum baslik={t("profilCihazYok")} />
          ) : (
            <ul className="space-y-2">
              {cihazlar.map((c) => (
                <li
                  key={c.id}
                  className="flex flex-wrap items-center justify-between gap-2 border-b pb-2 last:border-b-0"
                  style={{ borderColor: "var(--yz-border)" }}
                >
                  <span
                    className="min-w-0"
                    // Pasif satir SOLUK: "kaldirdim mi?" sorusunun cevabi
                    // listede gorunmeli ama aktifle karismamali.
                    style={{ opacity: c.aktif ? 1 : 0.55 }}
                  >
                    <span
                      className="block"
                      style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                    >
                      {c.platform}
                      {!c.aktif && ` — ${t("profilCihazPasif")}`}
                    </span>
                    <span
                      className="block"
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                    >
                      {t("profilCihazSonEtkinlik")}: {tarihSaatBicimi(c.updated_at)}
                    </span>
                  </span>
                  {c.aktif && (
                    <Dugme tur="ikincil" boy="kucuk" onClick={() => void kaldir(c.id)}>
                      {t("sosyalYontemKaldir")}
                    </Dugme>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      </Kart>

      <Kart>
        <div className="space-y-3">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("profilEtkinlik")}
          </h2>
          {!etkinlik ? (
            <IskeletMetin satir={3} />
          ) : etkinlik.length === 0 ? (
            <BosDurum baslik={t("profilEtkinlikYok")} />
          ) : (
            <ul className="space-y-1">
              {etkinlik.map((e) => (
                <li
                  key={e.id}
                  className="border-b py-1 last:border-b-0"
                  style={{ borderColor: "var(--yz-border)" }}
                >
                  <div className="flex flex-wrap items-baseline justify-between gap-2">
                    <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                      {e.action}
                    </span>
                    <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                      {tarihSaatBicimi(e.ts)}
                    </span>
                  </div>
                  {/* `details` KULLANILDI, kendi acilir durumumuz DEGIL:
                      klavye ve ekran okuyucu destegi tarayicidan gelir,
                      20 satir icin 20 ayri `useState` gerekmez. */}
                  <details
                    open={acikSatir === e.id}
                    onToggle={(ev) =>
                      setAcikSatir(
                        (ev.currentTarget as HTMLDetailsElement).open ? e.id : null,
                      )
                    }
                  >
                    <summary
                      className="cursor-pointer"
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                    >
                      {t("profilDetaylariGor")}
                    </summary>
                    <pre
                      className="mt-1 overflow-x-auto whitespace-pre-wrap break-all"
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                    >
                      {JSON.stringify(
                        {
                          resource_type: e.resource_type,
                          resource_id: e.resource_id,
                          ...e.meta,
                        },
                        null,
                        2,
                      )}
                    </pre>
                  </details>
                </li>
              ))}
            </ul>
          )}
        </div>
      </Kart>
    </div>
  );
}

/* ===================================================================== */
/* 3. BILDIRIM AYARLARI                                                  */
/* ===================================================================== */

function BildirimAyarlari() {
  const t = useT();
  const toast = useToast();
  const { data, mutate } = useSWR<Bildirimler>(
    "/api/me/bildirim-tercihleri",
    jsonFetcher,
  );
  const [hata, setHata] = useState<string | null>(null);

  /**
   * ANAHTAR CEVRILIR CEVRILMEZ KAYDEDILIR — ayri bir "Kaydet" yok.
   *
   * Uc anahtar icin bir kaydet dugmesi, kullanicinin anahtari cevirip
   * sayfadan ciktiginda degisikligi SESSIZCE kaybetmesi demekti. Uc
   * KISMI guncelleme kabul ettigi icin tek alan gondermek yeterli;
   * iki sekme acik olan kullanicida otekinin degisikligi ezilmez.
   */
  async function cevir(alan: keyof Bildirimler, deger: boolean) {
    setHata(null);
    // IYIMSER GUNCELLEME: anahtar aninda hareket etmeli, ag turunu
    // beklemek "tikladim ama olmadi" hissi verir. Hata olursa
    // `mutate()` sunucudaki gercegi geri yazar.
    void mutate((o) => (o ? { ...o, [alan]: deger } : o), false);
    try {
      await apiSend("/api/me/bildirim-tercihleri", "PATCH", { [alan]: deger });
      toast.success(t("profilBildirimKaydedildi"));
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      void mutate();
    }
  }

  const satirlar: { alan: keyof Bildirimler; anahtar: "profilBildirimEposta" | "profilBildirimSms" | "profilBildirimMobil" }[] = [
    { alan: "bildirim_eposta", anahtar: "profilBildirimEposta" },
    { alan: "bildirim_sms", anahtar: "profilBildirimSms" },
    { alan: "bildirim_mobil", anahtar: "profilBildirimMobil" },
  ];

  return (
    <Kart>
      <div className="space-y-4">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("profilBildirimAyarlari")}
        </h2>
        {/* PAZARLAMA IZINLERIYLE KARISMASIN diye acik cumle: biri KVKK
            rizasi (varsayilani kapali), oteki kullanim tercihi
            (varsayilani acik). Ikisi ayni ekranda dursaydi kullanici
            "hepsini kapattim" sanip aidat bildirimini de kaybederdi. */}
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("profilBildirimAciklama")}
        </p>
        <HataDurumu mesaj={hata} />
        {!data ? (
          <IskeletMetin satir={3} />
        ) : (
          <div className="space-y-3">
            {satirlar.map((s) => (
              <label key={s.alan} className="flex items-center gap-3 text-sm">
                <input
                  type="checkbox"
                  checked={data[s.alan]}
                  onChange={(e) => void cevir(s.alan, e.target.checked)}
                />
                {t(s.anahtar)}
              </label>
            ))}
          </div>
        )}
      </div>
    </Kart>
  );
}

/* ===================================================================== */
/* 4. SIFRE DEGISTIR                                                     */
/* ===================================================================== */

function SifreDegistir({ parolaVar }: { parolaVar: boolean }) {
  const t = useT();
  const toast = useToast();
  const [mevcut, setMevcut] = useState("");
  const [yeni, setYeni] = useState("");
  const [tekrar, setTekrar] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);

  async function kaydet(e: React.FormEvent) {
    e.preventDefault();
    // TEKRAR KONTROLU ISTEMCIDE: sunucuya iki alan da gitmiyor (uc yalniz
    // `new_password` aliyor), dolayisiyla bunu sunucu OLCEMEZ. Yazim
    // hatasini yakalayan tek yer burasi.
    if (yeni !== tekrar) {
      setHata(t("profilSifreUyusmuyor"));
      return;
    }
    setHata(null);
    setKaydediyor(true);
    try {
      await apiSend("/api/me/password", "PATCH", {
        current_password: mevcut,
        new_password: yeni,
      });
      toast.success(t("profilSifreDegisti"));
      setMevcut("");
      setYeni("");
      setTekrar("");
    } catch (err) {
      // Parola politikasi metni SUNUCUDAN gelir ve kullanicinin dilinde
      // olur — istemcide ikinci bir kural yazmak, ikisinin ayrismasi
      // demekti.
      setHata(err instanceof Error ? err.message : t("ortakHataOlustu"));
    } finally {
      setKaydediyor(false);
    }
  }

  return (
    <Kart>
      <form className="grid gap-4 sm:max-w-md" onSubmit={(e) => void kaydet(e)}>
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("profilSifreDegistir")}
        </h2>
        {/* UCUNDE DE GOSTER/GIZLE: `ParolaAlani` bunu tek yerde cozuyor
            (P154 §7.2) — uc ayri goz dugmesi yazmak ayni sekiz satiri uc
            kez kopyalamak ve birinde `aria-label`i unutmak olurdu. */}
        <AlanSarmal etiket={t("profilMevcutSifre")} zorunlu>
          {(baglar) => (
            <ParolaAlani
              id={baglar.id}
              value={mevcut}
              onChange={setMevcut}
              autoComplete="current-password"
              required
            />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("profilYeniSifre")} zorunlu>
          {(baglar) => (
            <ParolaAlani
              id={baglar.id}
              value={yeni}
              onChange={setYeni}
              autoComplete="new-password"
              minLength={8}
              required
            />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("profilYeniSifreTekrar")} zorunlu>
          {(baglar) => (
            <ParolaAlani
              id={baglar.id}
              value={tekrar}
              onChange={setTekrar}
              autoComplete="new-password"
              minLength={8}
              required
            />
          )}
        </AlanSarmal>
        <HataDurumu mesaj={hata} />
        <div>
          <Dugme tur="birincil" type="submit" disabled={kaydediyor || !parolaVar}>
            {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
          </Dugme>
        </div>
      </form>
    </Kart>
  );
}

/* ===================================================================== */
/* 5. HESABIMI SIL                                                       */
/* ===================================================================== */

function HesabimiSil() {
  const t = useT();
  const router = useRouter();
  const { onayla, diyalog } = useOnay();
  const [parola, setParola] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [siliniyor, setSiliniyor] = useState(false);

  async function sil(e: React.FormEvent) {
    e.preventDefault();
    if (
      !(await onayla({
        baslik: t("profilHesabimiSil"),
        mesaj: t("profilHesapSilOnay"),
        onayMetni: t("profilHesapSilButon"),
        tehlikeli: true,
      }))
    ) {
      return;
    }
    setHata(null);
    setSiliniyor(true);
    try {
      // `deleted=false` donmesi silme YAPILMADI demek DEGILDIR: hesabin
      // gecmisi oldugu icin satir anonimlestirilerek korundu demektir.
      // Istemci IKI DURUMDA DA oturumu kapatir (sozlesmenin acik notu).
      await apiSend("/api/me/hesap-sil", "POST", { current_password: parola });
      // CEREZ TEMIZLIGI BASARISIZ OLSA DA /login'e GIDILIR ve bu, kenar
      // cubugundaki cikis dugmesinin TERSI bir karar — bilincli:
      // orada oturum hâlâ gecerlidir (kullaniciyi cikmis SANDIRMAK
      // tehlikeli), burada hesap SUNUCUDA silinmistir. Elde kalan cerez
      // artik hicbir kapiyi acmaz; kullaniciyi silinmis bir hesabin
      // ekraninda birakmak ise tek gercek zarar olurdu.
      const cikis = await apiSend("/api/auth/logout", "POST", {}).then(
        () => true,
        () => false,
      );
      if (!cikis) {
        // Tam yenileme: sunucu bilesenleri gecersiz oturumu yeniden
        // degerlendirir ve middleware kullaniciyi girise dusurur.
        window.location.assign("/login");
        return;
      }
      router.replace("/login");
    } catch (err) {
      // "Son yonetici — once devredilmeli" (409) metni SUNUCUDAN gelir;
      // istemcide o kuralin kopyasi YOK (iki yerde yasasaydi ayrisirdi).
      setHata(err instanceof Error ? err.message : t("ortakHataOlustu"));
    } finally {
      setSiliniyor(false);
    }
  }

  return (
    <Kart>
      {diyalog}
      <form className="grid gap-4 sm:max-w-md" onSubmit={(e) => void sil(e)}>
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-danger-ink)" }}>
          {t("profilHesabimiSil")}
        </h2>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("profilHesapSilAciklama")}
        </p>
        {/* YENIDEN KIMLIK DOGRULAMA: odunc alinmis (kilidi acik birakilmis)
            bir oturum tek dokunusla baskasinin hesabini silememeli.
            Sunucu da ayni sarti ariyor — buradaki alan onun karsiligi,
            yerine gecen bir kontrol degil. */}
        <AlanSarmal etiket={t("profilMevcutSifre")} zorunlu>
          {(baglar) => (
            <ParolaAlani
              id={baglar.id}
              value={parola}
              onChange={setParola}
              autoComplete="current-password"
              required
            />
          )}
        </AlanSarmal>
        <HataDurumu mesaj={hata} />
        <div>
          <Dugme tur="tehlike" type="submit" disabled={siliniyor}>
            {siliniyor ? t("ortakKaydediliyor") : t("profilHesapSilButon")}
          </Dugme>
        </div>
      </form>
    </Kart>
  );
}
