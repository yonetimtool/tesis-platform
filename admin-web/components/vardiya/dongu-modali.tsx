"use client";

/**
 * (P247 §1) VARDIYA ROTASYONU — DONGU TANIMLA, EKIBE DAGIT, ONIZLE.
 *
 * =========================================================================
 * TEK MODEL: GUN UZUNLUGUNDA ADIM DIZISI
 * =========================================================================
 * Sunucu donguyu `adimlar` olarak saklar: her gun o gun calisilan
 * dilimlerin sira numaralari, bos = tatil. Kullanici bunu gun gun
 * TIKLAMAZ — 28 gunluk bir 12/36 dongusu 28 tiklama olurdu. Ekranda
 * BLOK girilir ("Gece, 14 gun, gun asiri") ve blok listesi adim dizisine
 * ACILIR (`bloklariAc`). 12/36 bu yuzden ayri bir kavram degil, bir
 * blogun "gun asiri" duzenidir.
 *
 * =========================================================================
 * ONIZLEME: BOSLUK BELIRGIN
 * =========================================================================
 * Istegin sarti "kaydetmeden once kim ne zaman calisiyor, BOSLUK kalan
 * gun/saat belirgin". Sunucu gun basina kimsesiz saat araliklarini doner
 * (`kapsama`); en alttaki "Bosluk" satiri onlari KIRMIZI zeminle ve saat
 * araligiyla yazar. Renk tek basina tasiyici degil (saat metni de var).
 *
 * `kuru=true` AYNI uctur (P207 K1.4): onizleme ile kaydetme ayrismaz.
 */
import { useMemo, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, Dugme, Modal, Rozet, Secim } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { AsyncIs } from "@/lib/tipler";

const IKINCIL = "ikincil" as const;
const BIRINCIL = "birincil" as const;
const KUCUK = "kucuk" as const;
const TEHLIKE = "tehlike" as const;
const YENI = "__yeni__";
const TATIL = -1;
const HER_GUN = "her_gun";
const GUN_ASIRI = "gun_asiri";
/** Onizlemede cizilen gun sayisi — ufkun tamami (62 gun) okunmaz. */
const ONIZLEME_GUN = 28;
/** Dilim renkleri (sira numarasina gore) — tema degiskenlerinden
 *  karistirilir; koyu temada da ayni oranla okunur. */
const DILIM_RENK = [
  "color-mix(in srgb, var(--yz-accent) 22%, transparent)",
  "color-mix(in srgb, var(--yz-warning) 26%, transparent)",
  "color-mix(in srgb, var(--yz-success) 24%, transparent)",
  "color-mix(in srgb, var(--yz-text-2) 20%, transparent)",
];
const BOS_ZEMIN = "color-mix(in srgb, var(--yz-danger) 20%, transparent)";
const BOS_YAZI = "var(--yz-danger-ink)";
const SEFFAF = "transparent";

type Dilim = { ad: string; baslangic: string; bitis: string };
type Kalip = {
  id: string;
  ad: string;
  dilimler: Dilim[];
  aktif: boolean;
  adimlar?: number[][] | null;
};
type Personel = { id: string; ad: string; role: string };
type Blok = { dilim: number; gun: number; duzen: string };
type Satir = {
  tarih: string;
  dilim: string;
  baslangic: string;
  bitis: string;
  user_id: string;
  ad: string | null;
  durum: string;
};
type KapsamaGun = {
  tarih: string;
  bos_dakika: number;
  bosluklar: { baslangic: string; bitis: string }[];
};
type Sonuc = {
  uygulandi: boolean;
  parti_id: string | null;
  baslangic: string;
  bitis: string;
  eklenecek: number;
  eklenen: number;
  cakisan: number;
  izinli: number;
  satirlar: Satir[];
  kapsama: KapsamaGun[];
};
type Atama = {
  id: string;
  kalip_ad: string | null;
  user_id: string;
  ad: string | null;
  baslangic: string;
  bitis: string | null;
  uretildi_kadar: string | null;
  parti_id: string;
  durum: string;
  atlanan: unknown[];
};

/** Blok listesi -> sunucunun `adimlar` dizisi. Saf; test edilir. */
export function bloklariAc(bloklar: Blok[]): number[][] {
  const adimlar: number[][] = [];
  for (const b of bloklar) {
    for (let i = 0; i < b.gun; i++) {
      const calis = b.dilim !== TATIL && (b.duzen !== GUN_ASIRI || i % 2 === 0);
      adimlar.push(calis ? [b.dilim] : []);
    }
  }
  return adimlar;
}

/** Hazir ornekler — sahadaki iki standart dongu. Dilim ADLARI kullanicinin
 *  dilinde gelir (kaydedilen veri olur, sonradan duzenlenebilir). */
function ikiDilim(gunduz: string, gece: string): Dilim[] {
  return [
    { ad: gunduz, baslangic: "08:00", bitis: "20:00" },
    { ad: gece, baslangic: "20:00", bitis: "08:00" },
  ];
}
const HAZIR_BLOK: Record<string, Blok[]> = {
  // 2 gece -> 2 gunduz -> 2 tatil (6 gun)
  ikiIkiIki: [
    { dilim: 1, gun: 2, duzen: HER_GUN },
    { dilim: 0, gun: 2, duzen: HER_GUN },
    { dilim: TATIL, gun: 2, duzen: HER_GUN },
  ],
  // 2 hafta gece 12/36 -> 2 hafta gunduz 12/36 (28 gun)
  onIkiOtuzAlti: [
    { dilim: 1, gun: 14, duzen: GUN_ASIRI },
    { dilim: 0, gun: 14, duzen: GUN_ASIRI },
  ],
};

function kisa(saat: string): string {
  return saat.slice(0, 5);
}

function gunEkle(iso: string, n: number): string {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

export function DonguModali({
  acik,
  onKapat,
  onBitti,
  onParti,
  personel,
  varsayilanBaslangic,
}: {
  acik: boolean;
  onKapat: () => void;
  onBitti: () => void;
  onParti?: (partiId: string | null) => void;
  personel: Personel[];
  varsayilanBaslangic: string;
}) {
  const t = useT();
  const toast = useToast();
  const kaliplar = useSWR<{ items: Kalip[] }>(
    acik ? "/api/vardiya-plani/kaliplar" : null,
    jsonFetcher,
  );
  const atamalar = useSWR<{ items: Atama[]; ufuk_gun: number }>(
    acik ? "/api/vardiya-plani/dongu-atamalari" : null,
    jsonFetcher,
  );
  const donguler = (kaliplar.data?.items ?? []).filter((k) => k.adimlar);

  const [kalipId, setKalipId] = useState<string>("");
  const [ad, setAd] = useState("");
  const [dilimler, setDilimler] = useState<Dilim[]>(() =>
    ikiDilim(t("donguGunduz"), t("donguGece")),
  );
  const [bloklar, setBloklar] = useState<Blok[]>(HAZIR_BLOK.ikiIkiIki);
  const [kisiler, setKisiler] = useState<string[]>([]);
  const [baslangic, setBaslangic] = useState(varsayilanBaslangic);
  const [kaydirma, setKaydirma] = useState(0);
  const [sonuc, setSonuc] = useState<Sonuc | null>(null);
  const [bekliyor, setBekliyor] = useState(false);
  const [sonTarih, setSonTarih] = useState<Record<string, string>>({});

  const yeniMi = kalipId === YENI;
  const secili = donguler.find((k) => k.id === kalipId) ?? null;
  const adimlar = useMemo(() => bloklariAc(bloklar), [bloklar]);
  const adayPersonel = personel.filter((p) =>
    ["security", "guvenlik_amiri", "tesis_gorevlisi", "yonetici"].includes(p.role),
  );

  function hata(e: unknown) {
    toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
  }

  async function calistir(is: AsyncIs) {
    setBekliyor(true);
    try {
      await is();
    } catch (e) {
      hata(e);
    } finally {
      setBekliyor(false);
    }
  }

  async function donguKaydet() {
    await calistir(async () => {
      const k = (await apiSend("/api/vardiya-plani/kaliplar", "POST", {
        ad: ad.trim(),
        dilimler,
        adimlar,
      })) as Kalip;
      toast.success(t("donguKaydedildi"));
      await kaliplar.mutate();
      setKalipId(k.id);
    });
  }

  async function gonder(kuru: boolean, cakisanlariAtla = false) {
    if (!secili) return;
    await calistir(async () => {
      const s = (await apiSend("/api/vardiya-plani/dongu-uygula", "POST", {
        kalip_id: secili.id,
        baslangic,
        kisiler,
        kaydirma,
        kuru,
        cakisanlari_atla: cakisanlariAtla,
      })) as Sonuc;
      setSonuc(s);
      if (s.uygulandi) {
        toast.success(t("donguUygulandi", { n: s.eklenen }));
        onParti?.(s.parti_id);
        await atamalar.mutate();
        onBitti();
      }
    });
  }

  function kisiDegistir(id: string) {
    setSonuc(null);
    setKisiler((k) => (k.includes(id) ? k.filter((x) => x !== id) : [...k, id]));
  }

  // ---------------- ONIZLEME IZGARASI ----------------
  const gunler = useMemo(
    () =>
      sonuc
        ? Array.from({ length: ONIZLEME_GUN }, (_, i) => gunEkle(sonuc.baslangic, i))
        : [],
    [sonuc],
  );
  const hucre = useMemo(() => {
    const m = new Map<string, Satir[]>();
    for (const s of sonuc?.satirlar ?? []) {
      const k = `${s.user_id}|${s.tarih}`;
      m.set(k, [...(m.get(k) ?? []), s]);
    }
    return m;
  }, [sonuc]);
  const kapsama = new Map((sonuc?.kapsama ?? []).map((k) => [k.tarih, k]));
  const bosGun = (sonuc?.kapsama ?? []).filter((k) => k.bos_dakika > 0).length;
  const dilimSirasi = new Map((secili?.dilimler ?? []).map((d, i) => [d.ad, i]));
  const adlar = new Map(personel.map((p) => [p.id, p.ad]));

  const gruplar = useMemo(() => {
    const m = new Map<string, Atama[]>();
    for (const a of atamalar.data?.items ?? []) {
      if (a.durum !== "aktif") continue;
      m.set(a.parti_id, [...(m.get(a.parti_id) ?? []), a]);
    }
    return Array.from(m.entries());
  }, [atamalar.data]);

  return (
    <Modal
      acik={acik}
      onKapat={onKapat}
      baslik={t("donguBaslik")}
      genislikSinifi="max-w-5xl"
      eylemler={
        <div className="flex flex-wrap justify-end gap-2">
          <Dugme type="button" tur={IKINCIL} onClick={onKapat}>
            {t("ortakKapat")}
          </Dugme>
          <Dugme
            type="button"
            tur={IKINCIL}
            disabled={!secili || kisiler.length === 0 || bekliyor}
            data-test="dongu-onizle"
            onClick={() => void gonder(true)}
          >
            {t("donguOnizle")}
          </Dugme>
          {sonuc && !sonuc.uygulandi && sonuc.cakisan > 0 && (
            <Dugme
              type="button"
              tur={IKINCIL}
              disabled={bekliyor}
              data-test="dongu-cakisan-haric"
              onClick={() => void gonder(false, true)}
            >
              {t("donguCakisanHaric")}
            </Dugme>
          )}
          <Dugme
            type="button"
            tur={BIRINCIL}
            disabled={!sonuc || sonuc.uygulandi || bekliyor}
            data-test="dongu-uygula"
            onClick={() => void gonder(false)}
          >
            {t("donguUygula")}
          </Dugme>
        </div>
      }
    >
      <div className="space-y-5" data-test="dongu-modali">
        {/* 1) DONGU SECIMI / TANIMI */}
        <AlanSarmal etiket={t("donguKalip")}>
          {(baglar) => (
            <Secim
              {...baglar}
              value={kalipId}
              data-test="dongu-kalip"
              onChange={(e) => {
                setKalipId(e.target.value);
                setSonuc(null);
              }}
            >
              <option value="">{t("ortakSeciniz")}</option>
              {donguler.map((k) => (
                <option key={k.id} value={k.id}>
                  {k.ad}
                </option>
              ))}
              <option value={YENI}>{t("donguYeni")}</option>
            </Secim>
          )}
        </AlanSarmal>

        {secili && (
          <p
            data-test="dongu-kalip-ozet"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            {t("donguUzunluk", { n: secili.adimlar?.length ?? 0 })}
          </p>
        )}

        {yeniMi && (
          <div className="space-y-3 rounded-lg p-3" data-test="dongu-tanim"
               style={{ background: "var(--yz-surface-sunken)" }}>
            <div className="flex flex-wrap gap-2">
              <Dugme type="button" boy={KUCUK} tur={IKINCIL} data-test="dongu-hazir-222"
                onClick={() => { setDilimler(ikiDilim(t("donguGunduz"), t("donguGece"))); setBloklar(HAZIR_BLOK.ikiIkiIki); }}>
                {t("donguHazir222")}
              </Dugme>
              <Dugme type="button" boy={KUCUK} tur={IKINCIL} data-test="dongu-hazir-1236"
                onClick={() => { setDilimler(ikiDilim(t("donguGunduz"), t("donguGece"))); setBloklar(HAZIR_BLOK.onIkiOtuzAlti); }}>
                {t("donguHazir1236")}
              </Dugme>
            </div>
            <AlanSarmal etiket={t("donguAd")}>
              {(baglar) => (
                <Alan maxLength={60 /* sunucu: VardiyaKalibiCreate.ad */} {...baglar} value={ad} data-test="dongu-ad"
                  onChange={(e) => setAd(e.target.value)} />
              )}
            </AlanSarmal>
            <fieldset className="space-y-2">
              <legend style={{ fontSize: "var(--yz-fs-sm)" }}>{t("donguDilimler")}</legend>
              {dilimler.map((d, i) => (
                <div key={i} className="flex flex-wrap items-end gap-2">
                  <AlanSarmal etiket={t("donguDilimAd")}>
                    {(baglar) => (
                      <div className="w-32"><Alan maxLength={40 /* sunucu: VardiyaDilim.ad */} {...baglar} value={d.ad}
                        onChange={(e) => setDilimler((ds) => ds.map((x, j) => (j === i ? { ...x, ad: e.target.value } : x)))} /></div>
                    )}
                  </AlanSarmal>
                  <AlanSarmal etiket={t("vardiyaBaslangicSaati")}>
                    {(baglar) => (
                      <div className="w-32"><Alan {...baglar} type="time" value={d.baslangic}
                        onChange={(e) => setDilimler((ds) => ds.map((x, j) => (j === i ? { ...x, baslangic: e.target.value } : x)))} /></div>
                    )}
                  </AlanSarmal>
                  <AlanSarmal etiket={t("vardiyaBitisSaati")}>
                    {(baglar) => (
                      <div className="w-32"><Alan {...baglar} type="time" value={d.bitis}
                        onChange={(e) => setDilimler((ds) => ds.map((x, j) => (j === i ? { ...x, bitis: e.target.value } : x)))} /></div>
                    )}
                  </AlanSarmal>
                </div>
              ))}
              {dilimler.length < 6 && (
                <Dugme type="button" boy={KUCUK} tur={IKINCIL}
                  onClick={() => setDilimler((ds) => [...ds, { ad: String(ds.length + 1), baslangic: "08:00", bitis: "16:00" }])}>
                  {t("donguDilimEkle")}
                </Dugme>
              )}
            </fieldset>
            <fieldset className="space-y-2">
              <legend style={{ fontSize: "var(--yz-fs-sm)" }}>{t("donguAdimlar")}</legend>
              {bloklar.map((b, i) => (
                <div key={i} className="flex flex-wrap items-end gap-2" data-test={`dongu-blok-${i}`}>
                  <AlanSarmal etiket={t("donguAdimDilim")}>
                    {(baglar) => (
                      <div className="w-36"><Secim {...baglar} value={b.dilim}
                        onChange={(e) => setBloklar((bs) => bs.map((x, j) => (j === i ? { ...x, dilim: Number(e.target.value) } : x)))}>
                        {dilimler.map((d, j) => (
                          <option key={j} value={j}>{d.ad}</option>
                        ))}
                        <option value={TATIL}>{t("donguTatil")}</option>
                      </Secim></div>
                    )}
                  </AlanSarmal>
                  <AlanSarmal etiket={t("donguGunSayisi")}>
                    {(baglar) => (
                      <div className="w-24"><Alan {...baglar} type="number" min={1} max={84} value={b.gun}
                        onChange={(e) => setBloklar((bs) => bs.map((x, j) => (j === i ? { ...x, gun: Math.max(1, Number(e.target.value) || 1) } : x)))} /></div>
                    )}
                  </AlanSarmal>
                  <AlanSarmal etiket={t("donguDuzen")}>
                    {(baglar) => (
                      <div className="w-44"><Secim {...baglar} value={b.duzen}
                        onChange={(e) => setBloklar((bs) => bs.map((x, j) => (j === i ? { ...x, duzen: e.target.value } : x)))}>
                        <option value={HER_GUN}>{t("donguHerGun")}</option>
                        <option value={GUN_ASIRI}>{t("donguGunAsiri")}</option>
                      </Secim></div>
                    )}
                  </AlanSarmal>
                  <Dugme type="button" boy={KUCUK} tur={IKINCIL} disabled={bloklar.length === 1}
                    onClick={() => setBloklar((bs) => bs.filter((_, j) => j !== i))}>
                    {t("ortakSil")}
                  </Dugme>
                </div>
              ))}
              <Dugme type="button" boy={KUCUK} tur={IKINCIL}
                onClick={() => setBloklar((bs) => [...bs, { dilim: 0, gun: 1, duzen: HER_GUN }])}>
                {t("donguAdimEkle")}
              </Dugme>
            </fieldset>
            {/* Adim seridi: kaydetmeden once dongunun kendisi gorunsun. */}
            <div className="flex flex-wrap gap-1" data-test="dongu-serit" aria-label={t("donguAdimlar")}>
              {adimlar.map((a, i) => (
                <span key={i} className="rounded px-1"
                  style={{
                    fontSize: "var(--yz-fs-xs)",
                    background: a.length ? DILIM_RENK[a[0] % DILIM_RENK.length] : SEFFAF,
                    border: "1px solid var(--yz-border)",
                  }}>
                  {a.length ? dilimler[a[0]]?.ad : t("donguTatil")}
                </span>
              ))}
            </div>
            <p style={{ fontSize: "var(--yz-fs-sm)" }}>{t("donguUzunluk", { n: adimlar.length })}</p>
            <Dugme type="button" tur={BIRINCIL} data-test="dongu-kaydet"
              disabled={!ad.trim() || adimlar.length > 84 || bekliyor || !adimlar.some((a) => a.length)}
              onClick={() => void donguKaydet()}>
              {t("donguKaydet")}
            </Dugme>
          </div>
        )}

        {/* 2) EKIP */}
        {secili && (
          <div className="space-y-3">
            <fieldset>
              <legend style={{ fontSize: "var(--yz-fs-sm)" }}>{t("donguKisiler")}</legend>
              <div className="mt-1 flex flex-wrap gap-2">
                {adayPersonel.map((p) => {
                  const sira = kisiler.indexOf(p.id);
                  return (
                    <label key={p.id} className="flex items-center gap-1" style={{ fontSize: "var(--yz-fs-sm)" }}>
                      <input type="checkbox" checked={sira >= 0} data-test={`dongu-kisi-${p.id}`}
                        onChange={() => kisiDegistir(p.id)} />
                      {p.ad}
                      {sira >= 0 && <Rozet>{t("donguOfset", { n: sira * kaydirma })}</Rozet>}
                    </label>
                  );
                })}
              </div>
            </fieldset>
            <div className="flex flex-wrap gap-3">
              <AlanSarmal etiket={t("donguBaslangic")}>
                {(baglar) => (
                  <div className="w-44"><Alan {...baglar} type="date" value={baslangic} data-test="dongu-baslangic"
                    onChange={(e) => { setBaslangic(e.target.value); setSonuc(null); }} /></div>
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("donguKaydirma")} ipucu={t("donguKaydirmaIpucu")}>
                {(baglar) => (
                  <div className="w-24"><Alan {...baglar} type="number" min={0} max={83} value={kaydirma}
                    data-test="dongu-kaydirma"
                    onChange={(e) => { setKaydirma(Math.max(0, Number(e.target.value) || 0)); setSonuc(null); }} /></div>
                )}
              </AlanSarmal>
            </div>
          </div>
        )}

        {/* 3) ONIZLEME */}
        {sonuc && secili && (
          <div className="space-y-2" data-test="dongu-onizleme">
            <p style={{ fontSize: "var(--yz-fs-sm)" }} data-test="dongu-ozet">
              {t("donguOzet", {
                eklenecek: sonuc.uygulandi ? sonuc.eklenen : sonuc.eklenecek,
                cakisan: sonuc.cakisan,
                izinli: sonuc.izinli,
                bos: bosGun,
              })}
            </p>
            <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {t("donguUfuk", { bitis: sonuc.bitis })}
            </p>
            <div style={{ overflowX: "auto" }}>
              <table className="border-collapse" style={{ fontSize: "var(--yz-fs-xs)" }}>
                <thead>
                  <tr>
                    <th />
                    {gunler.map((g) => (
                      <th key={g} className="px-1" style={{ fontWeight: 500 }}>{g.slice(8, 10)}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {kisiler.map((uid) => (
                    <tr key={uid}>
                      <th className="pe-2 text-start" style={{ fontWeight: 500, whiteSpace: "nowrap" }}>
                        {adlar.get(uid)}
                      </th>
                      {gunler.map((g) => {
                        const ss = hucre.get(`${uid}|${g}`) ?? [];
                        const s = ss[0];
                        const izin = s?.durum === "izinli";
                        const cak = s?.durum === "cakisma";
                        return (
                          <td key={g} className="px-1 text-center"
                            data-test={`dongu-hucre-${uid}-${g}`}
                            style={{
                              border: "1px solid var(--yz-border)",
                              background: s && !izin && !cak
                                ? DILIM_RENK[(dilimSirasi.get(s.dilim) ?? 0) % DILIM_RENK.length]
                                : SEFFAF,
                              color: cak ? BOS_YAZI : undefined,
                            }}>
                            {izin ? t("donguIzinli") : cak ? t("donguCakisma") : s ? s.dilim.slice(0, 3) : ""}
                          </td>
                        );
                      })}
                    </tr>
                  ))}
                  <tr data-test="dongu-bosluk-satiri">
                    <th className="pe-2 text-start" style={{ color: BOS_YAZI }}>{t("donguBosluk")}</th>
                    {gunler.map((g) => {
                      const k = kapsama.get(g);
                      const bos = !!k && k.bos_dakika > 0;
                      return (
                        <td key={g} className="px-1 text-center"
                          data-test={bos ? `dongu-bosluk-${g}` : undefined}
                          title={bos ? k!.bosluklar.map((b) => `${kisa(b.baslangic)}–${kisa(b.bitis)}`).join(", ") : undefined}
                          style={{
                            border: "1px solid var(--yz-border)",
                            background: bos ? BOS_ZEMIN : SEFFAF,
                            color: BOS_YAZI,
                            whiteSpace: "nowrap",
                          }}>
                          {bos ? k!.bosluklar.map((b) => `${kisa(b.baslangic)}–${kisa(b.bitis)}`).join(" ") : ""}
                        </td>
                      );
                    })}
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* 4) ETKIN DONGULER — sonlandir / geri al */}
        <section className="space-y-2" data-test="dongu-etkinler">
          <h3 style={{ fontSize: "var(--yz-fs-sm)", fontWeight: 600 }}>{t("donguEtkinler")}</h3>
          {gruplar.length === 0 && (
            <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("donguEtkinYok")}</p>
          )}
          {gruplar.map(([parti, liste]) => (
            <div key={parti} className="rounded-lg p-2" style={{ border: "1px solid var(--yz-border)" }}>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span style={{ fontSize: "var(--yz-fs-sm)", fontWeight: 600 }}>{liste[0].kalip_ad}</span>
                <Dugme type="button" boy={KUCUK} tur={TEHLIKE} disabled={bekliyor}
                  data-test={`dongu-geri-al-${parti}`}
                  onClick={() => void calistir(async () => {
                    const y = (await apiSend(`/api/vardiya-plani/parti/${parti}/geri-al`, "POST", {})) as { iptal_edilen?: number };
                    toast.success(t("vardiyaPartiGeriAlindi", { n: y?.iptal_edilen ?? 0 }));
                    await atamalar.mutate();
                    onBitti();
                  })}>
                  {t("donguGeriAl")}
                </Dugme>
              </div>
              {liste.map((a) => (
                <div key={a.id} className="mt-1 flex flex-wrap items-center gap-2" style={{ fontSize: "var(--yz-fs-sm)" }}>
                  <span className="min-w-[8rem]">{a.ad}</span>
                  <span style={{ color: "var(--yz-text-2)" }}>
                    {t("donguUretildi", { tarih: a.uretildi_kadar ?? "" })}
                  </span>
                  {a.atlanan.length > 0 && (
                    <Rozet durum="uyari">{t("donguAtlanan", { n: a.atlanan.length })}</Rozet>
                  )}
                  <div className="w-40"><Alan type="date" aria-label={t("donguSonlandirTarih")}
                    value={sonTarih[a.id] ?? ""}
                    onChange={(e) => setSonTarih((s) => ({ ...s, [a.id]: e.target.value }))} /></div>
                  <Dugme type="button" boy={KUCUK} tur={IKINCIL}
                    disabled={!sonTarih[a.id] || bekliyor}
                    data-test={`dongu-sonlandir-${a.id}`}
                    onClick={() => void calistir(async () => {
                      const y = (await apiSend(`/api/vardiya-plani/dongu-atamalari/${a.id}/sonlandir`, "POST", { tarih: sonTarih[a.id] })) as { iptal_edilen: number };
                      toast.success(t("donguSonlandirildi", { n: y.iptal_edilen }));
                      await atamalar.mutate();
                      onBitti();
                    })}>
                    {t("donguSonlandir")}
                  </Dugme>
                </div>
              ))}
            </div>
          ))}
        </section>
      </div>
    </Modal>
  );
}
