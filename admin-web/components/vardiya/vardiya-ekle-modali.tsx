"use client";

/**
 * (P235 §1) VARDIYA EKLEME — TEK MODAL, MOBILDEKI AKIS.
 *
 * =========================================================================
 * OLCULEN KUSUR: WEB'DE IKI AYRI EKRAN
 * =========================================================================
 * Vardiya planı sayfasında IKI giris vardi ve FARKLI seyler aciyorlardi:
 *
 *   * ustteki "Vardiya ekle" -> `page.tsx` icindeki modal: kisi ->
 *     BASLANGIC/BITIS TARIHI -> saatler -> not. TAKVIM YOK, COK GRUP YOK.
 *   * alttaki "Kalip uygula" -> `kalip-modali.tsx`: takvimden gun SECILMIS
 *     OLMALI; kalip dilimleri + dilim basina personel + rotasyon.
 *
 * Mobilde ise TEK akis var (`_HizliEkleDialogu`): takvim -> kisi/saat ->
 * gruba ekle -> onizleme. Yani ayni isin uc farkli hali vardi ve
 * kullanici hangisinin "gercek" oldugunu bilmiyordu.
 *
 * =========================================================================
 * NEDEN MOBILIN AKISI KAZANDI
 * =========================================================================
 * Cunku TAKVIM ONCE geliyor. Vardiya planlamak gun secmekle baslar;
 * "baslangic-bitis tarihi" alani duzensiz secimi (pazartesi + persembe)
 * ANLATAMIYOR — sunucu semasi bunu P207'de zaten kabul etmisti
 * (`gunler: list[date]`, aralik DEGIL). Web'in ust modali o gercege
 * ragmen aralik soruyordu.
 *
 * =========================================================================
 * KALIP VE ROTASYON KAYBOLMADI — BILINCLI
 * =========================================================================
 * `kalip-modali.tsx` SILINDI ama iki yetenegi buraya TASINDI:
 *   * KAYITLI KALIP (gun icinde birden cok dilim, orn. gunduz+gece),
 *   * ROTASYON (haftalik kaydirma).
 * Bunlari atmak "birlestirme" degil OZELLIK SILME olurdu; istek
 * ekranlarin birlesmesiydi, yeteneklerin azalmasi degil.
 *
 * MOBILDE ROTASYON YOK ve bu ONCEDEN VAR OLAN bir bosluk (bu tur
 * uretmedi) — teslimde acikca yaziliyor.
 */
import { useEffect, useMemo, useRef, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  AyTakvimi,
  Dugme,
  HataDurumu,
  Modal,
  Rozet,
  Secim,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { rolAdi } from "@/lib/roles";
import { ISTEMCI_SINIR } from "@/lib/girdi-siniri";

/** JSX ucluda sabit metin yazilamaz (`sabit-metin` taramasi). */
const IKINCIL = "ikincil" as const;
const ROTASYON_YOK = "yok" as const;
const ROTASYON_HAFTALIK = "haftalik" as const;
const ROTASYON_AYLIK = "aylik" as const;
/** "Kayitli kalip degil, serbest saat" secimi. */
const SERBEST = "" as const;
const BIRINCIL = "birincil" as const;
/** (P241 §2) Izin turleri — sozluk anahtarlariyla. */
const IZIN_TURLERI = [
  { kod: "yillik", anahtar: "vardiyaIzinYillik" },
  { kod: "mazeret", anahtar: "vardiyaIzinMazeret" },
  { kod: "hastalik", anahtar: "vardiyaIzinHastalik" },
  { kod: "ucretsiz", anahtar: "vardiyaIzinUcretsiz" },
  { kod: "resmi_tatil", anahtar: "vardiyaIzinResmiTatil" },
] as const;

type Dilim = { ad: string; baslangic: string; bitis: string };
type Kalip = {
  id: string;
  ad: string;
  dilimler: Dilim[];
  aktif: boolean;
  /** (P247 §1) Dolu = DONGU kalibi; bu modalda secilemez (dongu modali). */
  adimlar?: number[][] | null;
};
type Personel = { id: string; ad: string; role: string };
type Grup = {
  gunler: string[];
  dilimler: Dilim[];
  atamalar: Record<number, string[]>;
  /** (P243 §1f) Kalip GRUBA ait — coklu kalip boyle olur. */
  kalip_id: string | null;
};
type Satir = {
  tarih: string;
  dilim: string;
  baslangic: string;
  bitis: string;
  user_id: string;
  ad: string | null;
  durum: string;
};
type Sonuc = {
  uygulandi: boolean;
  parti_id: string | null;
  eklenecek: number;
  eklenen: number;
  /** ADET (sunucu semasi: `cakisan: int`). Satirlarin kendisi `satirlar`da. */
  cakisan: number;
  satirlar: Satir[];
};

export function VardiyaEkleModali({
  acik,
  onKapat,
  onBitti,
  onParti,
  baslangicAyi,
  onSecilenGunler,
  personel,
}: {
  acik: boolean;
  onKapat: () => void;
  onBitti: () => void;
  /** (P235 §1) Olusan PARTI kimligi — sayfadaki "geri al" dugmesi buna
   *  bagli. Birlestirmede bu geri cagriyi dusurmustum ve dugme HIC
   *  cikmiyordu; test yakaladi. Otuz gunluk yanlis plani tek tek silmek
   *  istegin KRITIK sartiydi. */
  onParti?: (partiId: string | null) => void;
  /** Sayfanin ZATEN cektigi personel listesi — ikinci bir istek acmayiz. */
  personel: Personel[];
  /** Takvimin acilacagi ay (sayfadaki gorunumle ayni yer). */
  baslangicAyi: string;
  /** Sayfadaki seritten gelen on-secim; bos olabilir. */
  onSecilenGunler: string[];
}) {
  const t = useT();
  const toast = useToast();

  // KALIPLAR BURADAN CEKILIYOR (sayfadan gecirilmiyor): yalnizca bu
  // modal kullaniyor ve `acik` degilken istek atilmiyor.
  const { data: kaliplar } = useSWR<{ items: Kalip[] }>(
    acik ? "/api/vardiya-plani/kaliplar" : null,
    jsonFetcher,
  );

  const [seciliGunler, setSeciliGunler] = useState<Set<string>>(new Set());

  // (P235 §1) SERIT SECIMI MODAL ACILIRKEN AKTARILIR.
  //
  // OLCULEN KUSUR: baslangic degerini `useState(() => new Set(prop))` ile
  // vermistim. Modal sayfada HEP MONTELI duruyor (`acik` bir prop) —
  // yani o baslatici YALNIZ BIR KEZ, modal KAPALIYKEN ve prop BOSKEN
  // calisiyordu. Sonuc: kullanici cizelgede gunleri isaretleyip "Kalip
  // uygula"ya basinca modal BOS aciliyordu. Test yakaladi.
  //
  // `acik` KENARINDA calisir, her cizimde DEGIL: aksi halde kullanicinin
  // modal icinde yaptigi secim her render'da geri alinirdi.
  const oncekiAcik = useRef(false);
  useEffect(() => {
    if (acik && !oncekiAcik.current) {
      setSeciliGunler(new Set(onSecilenGunler));
      setSonuc(null);
      setCakisanGunler(null);
    }
    oncekiAcik.current = acik;
  }, [acik, onSecilenGunler]);
  const [kalipId, setKalipId] = useState<string>(SERBEST);
  const [userId, setUserId] = useState("");
  /**
   * (P243 §1d) ROL SUZGECI — KAYDEDILEN BIR ALAN DEGIL.
   *
   * Personel listesi uzun bir sitede "Ali"yi bulmak icin once rolu
   * secmek dogal yol. Secilmezse TUM personel gorunur: suzgec bir
   * KISITLAMA degil, bir KOLAYLIK.
   */
  const [rolSuzgeci, setRolSuzgeci] = useState("");
  const [basSaat, setBasSaat] = useState("08:00");
  const [sonSaat, setSonSaat] = useState("16:00");
  const [dilimAtama, setDilimAtama] = useState<Record<number, string>>({});
  const [not, setNot] = useState("");
  const [rotasyon, setRotasyon] = useState<string>(ROTASYON_YOK);
  const [gruplar, setGruplar] = useState<Grup[]>([]);
  const [sonuc, setSonuc] = useState<Sonuc | null>(null);
  const [cakisanGunler, setCakisanGunler] = useState<string[] | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);
  // --------------------- (P241 §2) IZIN SEKMESI ------------------------- #
  const [sekme, setSekme] = useState<"mesai" | "izin">("mesai");
  const [izinKisi, setIzinKisi] = useState("");
  const [izinTur, setIzinTur] = useState<string>(IZIN_TURLERI[0].kod);
  const [izinBas, setIzinBas] = useState(() => baslangicAyi);
  const [izinBit, setIzinBit] = useState(() => baslangicAyi);
  const [izinTumGun, setIzinTumGun] = useState(true);
  const [izinBasSaat, setIzinBasSaat] = useState("09:00");
  const [izinBitSaat, setIzinBitSaat] = useState("11:00");
  // --------------------- (P241 §2) MOLA / ROL / LOKASYON ---------------- #
  const [molaDakika, setMolaDakika] = useState("");
  /**
   * Yasal mola onerisi SUNUCUDAN (4857 md. 68). Saat degistikce yeniden
   * sorulur; istemcide hesaplamak, kanunun kademelerini web ve mobilde
   * ayri ayri yazmak olurdu.
   */
  const { data: molaOneri } = useSWR<{ onerilen_dakika: number }>(
    basSaat && sonSaat
      ? `/api/vardiya-plani/mola-onerisi?baslangic_saat=${basSaat}&bitis_saat=${sonSaat}`
      : null,
    jsonFetcher,
  );
  const molaOnerisi = molaOneri?.onerilen_dakika ?? null;
  const [vardiyaRolu, setVardiyaRolu] = useState("");
  const [lokasyon, setLokasyon] = useState("");

  async function izinKaydet() {
    setBekliyor(true);
    setHata(null);
    try {
      await apiSend("/api/vardiya-izin", "POST", {
        user_id: izinKisi,
        tur: izinTur,
        baslangic: izinBas,
        bitis: izinTumGun ? izinBit : izinBas,
        tum_gun: izinTumGun,
        baslangic_saat: izinTumGun ? null : izinBasSaat,
        bitis_saat: izinTumGun ? null : izinBitSaat,
      });
      onBitti();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  /** Sistemdeki personel ROLLERI — listeden turer, elle yazilmaz. */
  const roller = useMemo(
    () => [...new Set(personel.map((p) => p.role))].sort(),
    [personel],
  );
  const suzulmusPersonel = useMemo(
    () => (rolSuzgeci ? personel.filter((p) => p.role === rolSuzgeci) : personel),
    [personel, rolSuzgeci],
  );

  const kalip = (kaliplar?.items ?? []).find((k) => k.id === kalipId);
  const dilimler: Dilim[] = kalip
    ? kalip.dilimler
    : [{ ad: `${basSaat}-${sonSaat}`, baslangic: basSaat, bitis: sonSaat }];

  function gunDegistir(g: string) {
    setSeciliGunler((s) => {
      const y = new Set(s);
      if (y.has(g)) y.delete(g);
      else y.add(g);
      return y;
    });
  }

  /** Ekranda kurulmakta olan grup. */
  function buGrup(): Grup | null {
    if (seciliGunler.size === 0) return null;
    const atamalar: Record<number, string[]> = {};
    if (kalip) {
      dilimler.forEach((_, i) => {
        const u = dilimAtama[i];
        if (u) atamalar[i] = [u];
      });
      if (Object.keys(atamalar).length === 0) return null;
    } else {
      if (!userId) return null;
      atamalar[0] = [userId];
    }
    return {
      gunler: Array.from(seciliGunler).sort(),
      dilimler,
      atamalar,
      // (P243 §1f) KALIP GRUBA AIT — COKLU KALIP BOYLE OLUR.
      //
      // Olculdu: `VardiyaGunGrubu` ZATEN `kalip_id` tasiyor (P232).
      // "Birden cok kalip" icin yeni bir kavram gerekmiyordu; eksik
      // olan, modalin kalibi GRUBA degil formun tamamina baglamasiydi.
      // Artik her "Gruba ekle" kendi kalibini tasir: pazartesi
      // 2-vardiyali kalip, cumartesi 3-vardiyali kalip.
      kalip_id: kalipId || null,
    };
  }

  function grubaEkle() {
    const g = buGrup();
    if (!g) return;
    setGruplar((l) => [...l, g]);
    // Sonraki grup BOS baslar: yoksa kullanici ayni gunleri ikinci gruba
    // da yazar ve kendi kendine cakisma uretirdi (mobildeki ayni not).
    setSeciliGunler(new Set());
    setSonuc(null);
  }
  // (P243 §1) TEKIL YOL SILINDI — VE ZATEN KIRIKTI.
  //
  // =====================================================================
  // OLCULEN KUSUR
  // =====================================================================
  // Modal, "serbest saat + tek kisi" durumunda `/vardiya-plani/toplu`
  // ucuna `baslangic`/`bitis` gonderiyordu; SEMA `baslangic_tarih` /
  // `bitis_tarih` istiyor. Yani web'in EN SIK yapilan islemi P235'ten
  // beri 422 aliyordu. Sunucuya birebir o govde gonderilerek olculdu:
  // `422 baslangic_tarih: Field required`.
  //
  // Duzeltme alan adlarini yamalamak DEGIL, IKINCI YOLU KALDIRMAK
  // oldu: `/kalip-uygula` serbest saati ZATEN tek dilimli bir grup
  // olarak isliyor ve cakisma akisi, onizleme, parti kimligi ve
  // rotasyon hep orada. Iki yol demek bu kurallarin iki kopyasi
  // demekti — ve biri sessizce eskimisti.

  async function gonder(kuru: boolean, atla: boolean) {
    // Ekranda kurulmakta olan grup da dahil: kullanicinin "gruba ekle"ye
    // basmayi unutmasi, son grubun SESSIZCE kaybolmasi demekti.
    const acik_ = buGrup();
    const hepsi = [...gruplar, ...(acik_ ? [acik_] : [])];
    if (hepsi.length === 0) return;
    setBekliyor(true);
    setHata(null);
    try {
      const y = (await apiSend("/api/vardiya-plani/kalip-uygula", "POST", {
        gruplar: hepsi,
        rotasyon,
        not_metni: not || null,
        kuru,
        cakisanlari_atla: atla,
      })) as Sonuc;
      setSonuc(y);
      // (P243 §1) CAKISAN GUNLER TEK YOLDAN: tekil yol silindigi icin
      // bu liste artik kalip sonucundan turetiliyor. Turetilmeseydi
      // "hangi gunler cakisti" bilgisi kaybolur ve kullanici yine tek
      // tek aramak zorunda kalirdi (P205'in acik sarti).
      if (!kuru && !y.uygulandi) {
        setCakisanGunler([
          ...new Set(
            (y.satirlar ?? [])
              .filter((r) => r.durum === "cakisma")
              .map((r) => r.tarih),
          ),
        ]);
      } else if (!kuru) {
        setCakisanGunler(null);
      }
      if (!kuru && y.uygulandi) {
        toast.success(t("vardiyaKalipUygulandi", { n: y.eklenen }));
        onParti?.(y.parti_id);
        onBitti();
        onKapat();
      }
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setBekliyor(false);
    }
  }

  // (P243 §1c) TAKVIM TEK GERCEK KAYNAK: gun secilmeden gonderilemez.
  //
  // Onceki kosul "tekil kipte takvim bos olabilir" diyordu; o kip
  // (aralik alanlari) kaldirildi, cunku ZATEN sunucuda 422 aliyordu ve
  // ayni zamanda onizlemeyi de olduruyordu (§1g): grup SECILI
  // GUNLERDEN kuruluyor, gun yoksa grup da yok.
  const gonderilebilir = gruplar.length > 0 || buGrup() !== null;

  // (P241 §2) IKI SEKME: MESAI ve IZIN — referansin "Mesai ekle"
  // penceresinin bizdeki karsiligi. Izni AYRI BIR EKRANA koymak,
  // yoneticinin "bu hafta Ali yok" bilgisini girmek icin baska bir
  // yere gitmesi demekti; oysa karar AYNI anda veriliyor.
  const izinSekmesi = sekme === "izin";

  return (
    <Modal
      acik={acik}
      onKapat={onKapat}
      baslik={t("vardiyaYeni")}
      eylemler={
        <>
          <Dugme type="button" tur={IKINCIL} onClick={onKapat}>
            {t("ortakIptal")}
          </Dugme>
          {izinSekmesi ? (
            <Dugme
              type="button"
              disabled={!izinKisi || bekliyor}
              data-test="vardiya-izin-kaydet"
              onClick={() => void izinKaydet()}
            >
              {t("vardiyaIzinEkle")}
            </Dugme>
          ) : (
            <>
          <Dugme
            type="button"
            tur={IKINCIL}
            disabled={!gonderilebilir || bekliyor}
            data-test="vardiya-onizle"
            onClick={() => void gonder(true, false)}
          >
            {t("vardiyaOnizle")}
          </Dugme>
          <Dugme
            type="button"
            disabled={!gonderilebilir || bekliyor}
            data-test="vardiya-ekle-gonder"
            // (P243 §1) TEK YOL: serbest saat de kalip da AYNI uctan
            // gider. Kosullu ikinci yol kaldirildi (yukaridaki gerekce).
            onClick={() => void gonder(false, false)}
          >
            {t("vardiyaEkleGonder")}
          </Dugme>
            </>
          )}
        </>
      }
    >
      <div className="space-y-3">
        <HataDurumu mesaj={hata} />

        {/* SEKME SECICI — MESAI / IZIN */}
        <div className="flex gap-1" role="group" aria-label={t("vardiyaYeni")}>
          {(["mesai", "izin"] as const).map((x) => (
            <Dugme
              key={x}
              type="button"
              boy="kucuk"
              tur={sekme === x ? BIRINCIL : IKINCIL}
              aria-pressed={sekme === x}
              data-test={`vardiya-sekme-${x}`}
              onClick={() => setSekme(x)}
            >
              {x === "izin" ? t("vardiyaIzin") : t("vardiyaMesai")}
            </Dugme>
          ))}
        </div>

        {izinSekmesi && (
          <div className="space-y-3" data-test="vardiya-izin-formu">
            <AlanSarmal etiket={t("vardiyaPersonel")}>
              {(baglar) => (
                <Secim
                  {...baglar}
                  value={izinKisi}
                  data-test="vardiya-izin-kisi"
                  onChange={(e) => setIzinKisi(e.target.value)}
                >
                  <option value="" />
                  {personel.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.ad}
                    </option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("vardiyaIzinTuru")}>
              {(baglar) => (
                <Secim
                  {...baglar}
                  value={izinTur}
                  data-test="vardiya-izin-tur"
                  onChange={(e) => setIzinTur(e.target.value)}
                >
                  {IZIN_TURLERI.map((x) => (
                    <option key={x.kod} value={x.kod}>
                      {t(x.anahtar)}
                    </option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("vardiyaIzinBaslangic")}>
              {(baglar) => (
                <Alan
                  {...baglar}
                  type="date"
                  data-test="vardiya-izin-bas"
                  value={izinBas}
                  onChange={(e) => setIzinBas(e.target.value)}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("vardiyaIzinBitis")}>
              {(baglar) => (
                <Alan
                  {...baglar}
                  type="date"
                  data-test="vardiya-izin-bit"
                  value={izinBit}
                  onChange={(e) => setIzinBit(e.target.value)}
                />
              )}
            </AlanSarmal>
            <label
              className="flex items-center gap-2"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
            >
              <input
                type="checkbox"
                className="h-4 w-4"
                data-test="vardiya-izin-tumgun"
                checked={izinTumGun}
                onChange={(e) => setIzinTumGun(e.target.checked)}
              />
              {t("vardiyaIzinTumGun")}
            </label>
            {!izinTumGun && (
              <div className="flex gap-2">
                <AlanSarmal etiket={t("vardiyaBaslangicSaati")}>
                  {(baglar) => (
                    <Alan
                      {...baglar}
                      type="time"
                      data-test="vardiya-izin-bas-saat"
                      value={izinBasSaat}
                      onChange={(e) => setIzinBasSaat(e.target.value)}
                    />
                  )}
                </AlanSarmal>
                <AlanSarmal etiket={t("vardiyaBitisSaati")}>
                  {(baglar) => (
                    <Alan
                      {...baglar}
                      type="time"
                      data-test="vardiya-izin-bit-saat"
                      value={izinBitSaat}
                      onChange={(e) => setIzinBitSaat(e.target.value)}
                    />
                  )}
                </AlanSarmal>
              </div>
            )}
          </div>
        )}

        {!izinSekmesi && (
        <>

        {/* 1) TAKVIM ONCE — mobildeki sira. Vardiya planlamak gun secmekle
            baslar; "baslangic-bitis tarihi" duzensiz secimi anlatamiyordu. */}
        <div>
          <p
            className="mb-1"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            {t("vardiyaTakvimIpucu")}
          </p>
          {/* (P240 §5c) ORTAK `AyTakvimi`.

              Burada ELDE cizilmis bir gun seridi vardi: sarilabilir bir
              dugme yigini, haftaya HIZALI DEGIL. Yani "tum pazartesiler"
              secmek isteyen kullanici sutun goremiyordu; ustelik hucre
              36px'ti (dokunma hedefi degil, yogun-baglam olcusu).

              Gorev formu ikinci tuketici olunca kopyalamak yerine
              tasindi — mobildeki `GunTakvimi` ile ayni goruntu. `kanca`
              oneki DEGISMEDI: `vardiya-ekle-gun-<iso>` kilitleri
              oldugu gibi duruyor. */}
          <AyTakvimi
            ay={baslangicAyi.slice(0, 7)}
            kanca="vardiya-ekle"
            secili={seciliGunler}
            onSec={gunDegistir}
          />
          <div className="mt-1 flex items-center gap-2">
            <span
              data-test="vardiya-ekle-secili-sayi"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {t("vardiyaSeciliGun", { n: seciliGunler.size })}
            </span>
            <Dugme
              type="button"
              boy="kucuk"
              tur={IKINCIL}
              disabled={seciliGunler.size === 0}
              data-test="vardiya-ekle-secim-temizle"
              onClick={() => setSeciliGunler(new Set())}
            >
              {t("vardiyaSecimiTemizle")}
            </Dugme>
          </div>
        </div>

        {/* (P241 §2) MOLALAR — YASAL ONERI SUNUCUDAN.
            Kademe sayilarini burada yazmak, kanunu istemciye kopyalamak
            olurdu; guncellenmesi gerektiginde web ve mobil ayri ayri
            degistirilirdi. */}
        <div className="flex flex-wrap items-end gap-2" data-test="vardiya-mola">
          <AlanSarmal etiket={t("vardiyaMolaDakika")} ipucu={t("vardiyaMolaDuser")}>
            {(baglar) => (
              <Alan maxLength={ISTEMCI_SINIR.SAYI}
                {...baglar}
                inputMode="numeric"
                data-test="vardiya-ekle-mola"
                value={molaDakika}
                onChange={(e) => setMolaDakika(e.target.value)}
              />
            )}
          </AlanSarmal>
          {molaOnerisi !== null && (
            <span
              data-test="vardiya-mola-onerisi"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {t("vardiyaMolaOnerisi", { n: molaOnerisi })}
            </span>
          )}
          <Dugme
            type="button"
            boy="kucuk"
            tur={IKINCIL}
            disabled={molaOnerisi === null}
            data-test="vardiya-mola-uygula"
            onClick={() => setMolaDakika(String(molaOnerisi ?? ""))}
          >
            {t("vardiyaMolaEkle")}
          </Dugme>
        </div>

        {/* (P243 §1a/§1b) "BU VARDIYADAKI ROL" ve "LOKASYON" KALDIRILDI.

            ROL: kisi sisteme eklenirken rolu ZATEN belirleniyor
            (guvenlik / tesis gorevlisi / yonetim). Vardiya basina
            tekrar sormak ayni bilgiyi ikinci kez istemekti — ve iki
            kaynak birbirinden sapabilirdi.

            LOKASYON: referanstaki "sube" kavraminin karsiligiydi;
            bizde sube YOK. Doldurulmayan bir alan, formu uzatmaktan
            baska bir sey yapmiyordu.

            SUTUNLAR SILINMEDI (goc 0145): P241'de yazilmis kayitlar
            duruyor ve izgara onlari hâlâ gosteriyor. Sutunu dusurmek
            var olan veriyi silmek olurdu; yapilan sey YENI KAYITTA
            SORMAMAK. */}
        {/* 2) KALIP — serbest saat ya da kayitli kalip.
            `kalip-modali.tsx`ten TASINDI: gun icinde birden cok dilim
            (gunduz+gece) yalniz orada yapilabiliyordu. */}
        <AlanSarmal etiket={t("vardiyaKalip")}>
          {(baglar) => (
            <Secim
              {...baglar}
              value={kalipId}
              data-test="vardiya-ekle-kalip"
              onChange={(e) => {
                setKalipId(e.target.value);
                setDilimAtama({});
              }}
            >
              <option value={SERBEST}>{t("vardiyaSerbestSaat")}</option>
              {(kaliplar?.items ?? [])
                // (P247 §1) DONGU KALIBI BURADA YOK: bu modal her secili
                // gune TUM dilimleri yazar; sunucu dongu kalibini 422 ile
                // reddeder (`vardiya_kalibi_dongu`). Dongu kendi modalinda.
                .filter((k) => k.aktif && !k.adimlar)
                .map((k) => (
                  <option key={k.id} value={k.id}>
                    {k.ad}
                  </option>
                ))}
            </Secim>
          )}
        </AlanSarmal>

        {/* 3) KISI + SAAT (serbest) ya da DILIM BASINA KISI (kalip) */}
        {kalip ? (
          <div className="space-y-2" data-test="vardiya-ekle-dilimler">
            {dilimler.map((d, i) => (
              <AlanSarmal
                key={`${d.ad}-${i}`}
                etiket={`${d.ad} · ${d.baslangic}-${d.bitis}`}
              >
                {(baglar) => (
                  <Secim
                    {...baglar}
                    value={dilimAtama[i] ?? ""}
                    data-test={`vardiya-ekle-dilim-${i}`}
                    onChange={(e) =>
                      setDilimAtama((a) => ({ ...a, [i]: e.target.value }))
                    }
                  >
                    <option value="">{t("ortakSeciniz")}</option>
                    {personel.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.ad}
                      </option>
                    ))}
                  </Secim>
                )}
              </AlanSarmal>
            ))}
          </div>
        ) : (
          <div className="flex flex-wrap gap-2">
            {/* (P243 §1d) ROL SUZGECI — KAYDEDILEN BIR ALAN DEGIL.
                Personel listesi uzun bir sitede once rolu secmek dogal
                yol; secilmezse TUM personel gorunur. */}
            <AlanSarmal
              etiket={t("vardiyaRolSuzgeci")}
              ipucu={t("vardiyaRolSuzgeciIpucu")}
            >
              {(baglar) => (
                <Secim
                  {...baglar}
                  value={rolSuzgeci}
                  data-test="vardiya-ekle-rol-suzgeci"
                  onChange={(e) => {
                    setRolSuzgeci(e.target.value);
                    // SECILI KISI SUZGECIN DISINDA KALDIYSA DUSURULUR:
                    // gorunmeyen bir kisiyle vardiya olusturmak,
                    // kullanicinin gormedigi bir sonuc uretirdi.
                    if (
                      e.target.value &&
                      personel.find((p) => p.id === userId)?.role !==
                        e.target.value
                    ) {
                      setUserId("");
                    }
                  }}
                >
                  <option value="">{t("ortakTumu")}</option>
                  {roller.map((r) => (
                    <option key={r} value={r}>
                      {rolAdi(t, r)}
                    </option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("vardiyaPersonel")}>
              {(baglar) => (
                <Secim
                  {...baglar}
                  value={userId}
                  data-test="vardiya-ekle-kisi"
                  onChange={(e) => setUserId(e.target.value)}
                >
                  <option value="">{t("ortakSeciniz")}</option>
                  {suzulmusPersonel.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.ad}
                    </option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
            {/* (P243 §1c) BASLANGIC/BITIS TARIHI ALANLARI KALDIRILDI.

                Ustte ZATEN takvim var ve gunler oradan seciliyor. Iki
                yol birden acik oldugunda hangisinin gecerli oldugu
                belirsizdi — ve bu belirsizlik ONIZLEMEYI OLDURUYORDU
                (§1g): tarih alanlarini doldurup takvimden gun secmeyen
                kullanicinin "Onizle" dugmesi SESSIZCE hicbir sey
                yapmiyordu, cunku onizleme grup uzerinden gidiyor ve
                grup SECILI GUNLERDEN kuruluyor.

                Saatler KALDI: onlar takvimden turetilemez. */}
            <AlanSarmal etiket={t("vardiyaBaslangicSaati")}>
              {(baglar) => (
                <Alan
                  {...baglar}
                  type="time"
                  value={basSaat}
                  data-test="vardiya-ekle-bas-saat"
                  onChange={(e) => setBasSaat(e.target.value)}
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("vardiyaBitisSaati")}>
              {(baglar) => (
                <Alan
                  {...baglar}
                  type="time"
                  value={sonSaat}
                  data-test="vardiya-ekle-son-saat"
                  onChange={(e) => setSonSaat(e.target.value)}
                />
              )}
            </AlanSarmal>
          </div>
        )}

        {/* 4) COK GRUP (P232) — "pazartesi gunduz, sali-carsamba gece" */}
        <div className="flex flex-wrap items-center gap-2">
          <Dugme
            type="button"
            boy="kucuk"
            tur={IKINCIL}
            disabled={buGrup() === null}
            data-test="vardiya-ekle-gruba-ekle"
            onClick={grubaEkle}
          >
            {t("vardiyaGrubaEkle")}
          </Dugme>
          {gruplar.length > 0 && (
            <span
              data-test="vardiya-ekle-grup-sayisi"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {t("vardiyaGrupSayisi", { n: gruplar.length })}
            </span>
          )}
          {gruplar.length > 0 && (
            <Dugme
              type="button"
              boy="kucuk"
              tur={IKINCIL}
              data-test="vardiya-ekle-gruplari-temizle"
              onClick={() => setGruplar([])}
            >
              {t("vardiyaGruplariTemizle")}
            </Dugme>
          )}
        </div>

        <AlanSarmal
          etiket={t("vardiyaRotasyon")}
          ipucu={
            rotasyon === ROTASYON_AYLIK
              ? t("vardiyaRotasyonAylikIpucu")
              : undefined
          }
        >
          {(baglar) => (
            <Secim
              {...baglar}
              value={rotasyon}
              data-test="vardiya-ekle-rotasyon"
              onChange={(e) => setRotasyon(e.target.value)}
            >
              <option value={ROTASYON_YOK}>{t("vardiyaRotasyonYok")}</option>
              <option value={ROTASYON_HAFTALIK}>
                {t("vardiyaRotasyonHaftalik")}
              </option>
              {/* (P243 §1e) AYLIK = TAKVIM AYI, "dort haftalik dongu"
                  DEGIL: dongu ayin ortasinda kayar ve yoneticinin
                  takviminde karsiligi yoktur; takvim ayi ise
                  SOYLENEBILIR bir sey ("mart gunduz, nisan gece"). */}
              <option value={ROTASYON_AYLIK}>
                {t("vardiyaRotasyonAylik")}
              </option>
            </Secim>
          )}
        </AlanSarmal>

        <AlanSarmal etiket={t("vardiyaNot")}>
          {(baglar) => (
            <Alan maxLength={500 /* sunucu: VardiyaAtamaIstek.not_metni */}
              {...baglar}
              value={not}
              data-test="vardiya-ekle-not"
              onChange={(e) => setNot(e.target.value)}
            />
          )}
        </AlanSarmal>

        <p
          data-test="vardiya-ekle-bilgi"
          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
        >
          {t("vardiyaEkleBilgi")}
        </p>

        {/* TEKIL KIPTE CAKISMA — gunler YAZILIR, karar kullanicinin. */}
        {cakisanGunler && cakisanGunler.length > 0 && (
          <div data-test="vardiya-cakisma-uyarisi">
            <Rozet durum="uyari">
              {t("vardiyaCakisanGunler", { n: cakisanGunler.length })}
            </Rozet>
            <p
              className="mt-1 tabular-nums"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
            >
              {cakisanGunler.join(", ")}
            </p>
            <div className="mt-2 flex flex-wrap gap-2">
              <Dugme
                type="button"
                boy="kucuk"
                disabled={bekliyor}
                data-test="vardiya-cakisan-haric"
                onClick={() => void gonder(false, true)}
              >
                {t("vardiyaCakisanHaric")}
              </Dugme>
              <Dugme
                type="button"
                boy="kucuk"
                tur={IKINCIL}
                data-test="vardiya-cakisma-iptal"
                onClick={() => {
                  setCakisanGunler(null);
                  onKapat();
                }}
              >
                {t("ortakIptal")}
              </Dugme>
            </div>
          </div>
        )}

        {/* 5) ONIZLEME + CAKISMA — `kalip-modali`daki akisin aynisi. */}
        {sonuc && (
          <div data-test="vardiya-ekle-onizleme" className="space-y-2">
            <Rozet durum={sonuc.cakisan > 0 ? "uyari" : "bilgi"}>
              {t("vardiyaKalipOnizleme", { n: sonuc.eklenecek })}
            </Rozet>
            {sonuc.cakisan > 0 && (
              <>
                {/* HANGI gun/dilim/KIM oldugu YAZILIR: "bir yerde cakisma
                    var" demek, kullaniciyi tek tek aramaya gondermekti
                    (P205 kurali). */}
                <p
                  className="tabular-nums"
                  style={{
                    fontSize: "var(--yz-fs-xs)",
                    color: "var(--yz-text-2)",
                  }}
                >
                  {(sonuc.satirlar ?? [])
                    .filter((c) => c.durum === "cakisma")
                    .map((c) => `${c.tarih} ${c.dilim} ${c.ad ?? ""}`.trim())
                    .join(", ")}
                </p>
                <Dugme
                  type="button"
                  boy="kucuk"
                  disabled={bekliyor}
                  data-test="vardiya-cakisan-haric"
                  onClick={() => void gonder(false, true)}
                >
                  {t("vardiyaCakisanHaric")}
                </Dugme>
              </>
            )}
          </div>
        )}
        </>
        )}
      </div>
    </Modal>
  );
}
