"use client";

// (P167 §2.3) TAKVIM — alti kaynak tek izgarada + kisisel hatirlatma.
//
// =====================================================================
// GORUNUM PENCEREYI BELIRLER, TERSI DEGIL
// =====================================================================
// Gun / Hafta / Ay ucu de AYNI uctan (`GET /takvim`) besleniyor; degisen
// tek sey istenen ARALIK. Her gorunume ayri bir uc acmak, ayni alti
// kaynagi uc kez birlestirmek olurdu.
//
// TARIHLER YEREL SAATTE HESAPLANIR, UTC'de DEGIL. Kullanicinin "bugun"u
// tarayicisinin saat dilimindedir; UTC'ye gore hesaplamak, saat 02:00'de
// bakan bir kullaniciya dunun kutusunu bugun diye gosterirdi. Sunucuya
// giden pencere ise ISO (UTC) — cevirimi `toISOString` yapiyor.
//
// =====================================================================
// TEKRAR EDEN HATIRLATMA
// =====================================================================
// Genisletme SUNUCUDA yapiliyor (`/takvim` pencereye gore ornek uretir).
// Istemci ayni kayittan birden fazla satir gorur ve BU BEKLENEN bir sey:
// `id` tekrar eder, `key` icin zaman da kullanilir.

import Link from "next/link";
import { useMemo, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { useBant } from "@/lib/kirilma-kullan";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  CokSatir,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Modal,
  Secim,
  useOnay,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

type TakvimTip =
  | "etkinlik" | "devriye" | "aidat" | "gorev" | "rezervasyon" | "hatirlatma";

interface TakvimOgesi {
  tip: TakvimTip;
  id: string;
  baslik: string;
  baslangic: string;
  bitis: string | null;
  hedef: string | null;
  renk: string | null;
}

type Gorunum = "gun" | "hafta" | "ay";

/**
 * Silme geri cagrimi.
 *
 * CAGRI IMZASI olarak yazildi, ok gosterimiyle DEGIL: `sabit-metin`
 * taramasi `=> Promise<void>` yazimindaki `> Promise <` parcasini bir
 * JSX METIN dugumu sanip cevrilmemis metin bildiriyor. Tarama bu
 * noktada kaba ama HAKLI bir kaba — gevsetmek, gercek bir sizintiyi de
 * gormez kilardi. Imza gosterimi ayni turu uretir ve `>` icermez.
 */
interface SilmeIslemi {
  (id: string): Promise<void>;
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const GORUNUM_GUN = "gun" as const;
const GORUNUM_HAFTA = "hafta" as const;
const GORUNUM_AY = "ay" as const;
const TIP_HATIRLATMA = "hatirlatma" as const;
const TIP_AIDAT = "aidat" as const;
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;
/** Bugunun hucresi KENARLIKLA vurgulanir; dolgu, icindeki olay
 *  noktalarinin kontrastini dusururdu. */
const KENAR_BUGUN = "2px";
const HATIRLATMA_YOLU = "/api/hatirlatmalar";

const GORUNUMLER: { id: Gorunum; anahtar: SozlukAnahtari }[] = [
  { id: GORUNUM_GUN, anahtar: "takvimGun" },
  { id: GORUNUM_HAFTA, anahtar: "takvimHafta" },
  { id: GORUNUM_AY, anahtar: "takvimAy" },
];

const TIP_ANAHTARI: Record<TakvimTip, SozlukAnahtari> = {
  etkinlik: "takvimTipEtkinlik",
  devriye: "takvimTipDevriye",
  aidat: "takvimTipAidat",
  gorev: "takvimTipGorev",
  rezervasyon: "takvimTipRezervasyon",
  hatirlatma: "takvimTipHatirlatma",
};

/** Kaynak tipi -> nokta rengi. Renk TOKEN'dan; anlam burada. */
const TIP_RENGI: Record<TakvimTip, string> = {
  etkinlik: "var(--yz-accent-edge)",
  devriye: "var(--yz-nfc-edge)",
  aidat: "var(--yz-warning-edge)",
  gorev: "var(--yz-success-edge)",
  rezervasyon: "var(--yz-accent-edge)",
  hatirlatma: "var(--yz-text-3)",
};

const RENKLER: { id: string; anahtar: SozlukAnahtari; deger: string }[] = [
  { id: "mavi", anahtar: "takvimRenkMavi", deger: "var(--yz-accent-edge)" },
  { id: "yesil", anahtar: "takvimRenkYesil", deger: "var(--yz-success-edge)" },
  { id: "turuncu", anahtar: "takvimRenkTuruncu", deger: "var(--yz-warning-edge)" },
  { id: "kirmizi", anahtar: "takvimRenkKirmizi", deger: "var(--yz-danger-edge)" },
  { id: "mor", anahtar: "takvimRenkMor", deger: "var(--yz-accent-edge)" },
];

const TEKRARLAR: { id: string; anahtar: SozlukAnahtari }[] = [
  { id: "yok", anahtar: "takvimTekrarYok" },
  { id: "gunluk", anahtar: "takvimTekrarGunluk" },
  { id: "haftalik", anahtar: "takvimTekrarHaftalik" },
  { id: "aylik", anahtar: "takvimTekrarAylik" },
];

/** Gunun basi — YEREL saatte. */
function gunBasi(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

/**
 * Haftanin ilk gunu — PAZARTESI.
 *
 * `getDay()` pazar=0 doner; Turkiye ve cogu Avrupa takviminde hafta
 * pazartesi baslar. Duzeltmeyi atlamak, ay izgarasini bir gun kaydirir
 * ve HER hucreyi yanlis gune yazardi.
 */
function haftaBasi(d: Date): Date {
  const g = gunBasi(d);
  const kaydir = (g.getDay() + 6) % 7;
  g.setDate(g.getDate() - kaydir);
  return g;
}

function gunEkle(d: Date, n: number): Date {
  const y = new Date(d);
  y.setDate(y.getDate() + n);
  return y;
}

/** Iki tarih AYNI GUN mu (yerel)? */
function ayniGun(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

/** `datetime-local` girdisi icin yerel ISO (saniyesiz). */
function yerelIso(d: Date): string {
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** Gorunume gore [baslangic, bitis) penceresi — YEREL. */
function pencere(gorunum: Gorunum, capa: Date): [Date, Date] {
  if (gorunum === GORUNUM_GUN) return [gunBasi(capa), gunEkle(gunBasi(capa), 1)];
  if (gorunum === GORUNUM_HAFTA) {
    const b = haftaBasi(capa);
    return [b, gunEkle(b, 7)];
  }
  const ayBasi = new Date(capa.getFullYear(), capa.getMonth(), 1);
  // AY IZGARASI TAM HAFTALARDAN OLUSUR: onceki ayin son gunleri ve
  // sonraki ayin ilk gunleri de cizilir, yoksa ilk satir bosluklarla
  // baslar ve hucreler gunlerle hizalanmaz.
  const bas = haftaBasi(ayBasi);
  return [bas, gunEkle(bas, 42)];
}

export function PanoTakvim() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();

  const [gorunum, setGorunum] = useState<Gorunum>(GORUNUM_AY);
  const [capa, setCapa] = useState<Date>(() => new Date());
  const [tamEkran, setTamEkran] = useState(false);
  const [secilenGun, setSecilenGun] = useState<Date | null>(null);
  const [formAcik, setFormAcik] = useState(false);
  const [duzenlenen, setDuzenlenen] = useState<string | null>(null);

  const [bas, bit] = useMemo(() => pencere(gorunum, capa), [gorunum, capa]);

  // ANAHTAR ISO PENCEREDEN TURETILIR: SWR ayni pencereyi iki kez
  // cekmez ve ay degisince otomatik tazelenir.
  const { data, error, isLoading, mutate } = useSWR<{ items: TakvimOgesi[] }>(
    `/api/takvim?baslangic=${encodeURIComponent(bas.toISOString())}&bitis=${encodeURIComponent(bit.toISOString())}`,
    jsonFetcher,
  );

  const bugun = new Date();

  // (P169 §4) DAR EKRANDA AJANDA. `grid-cols-7` KIRILAMAZ: yedi sutun
  // haftanin yedi gunudur, altiya dusurulemez. 360 px'te bir hucre ~48 px
  // olur; gun numarasi ile bir olay noktasi ayni kutuya sigmaz.
  //
  // Cozum sutun sayisini degil GORUNUMU degistirmek: ayni `gunlukKume`den
  // beslenen, YALNIZ OLAYI OLAN gunlerin listesi. Iki gorunum tek
  // kaynaktan cizildigi icin ayrisamazlar.
  const ajanda = useBant() === "sm";

  /** Gun -> o gune dusen ogeler. Tek gecis; hucre basina filtre YOK
   *  (42 hucre x N oge, ay gorunumunde gereksiz kare hesaplamasi).
   *
   *  `?? []` CAGRININ ICINDE: disarida yazilsaydi her cizimde YENI bir
   *  dizi uretir ve `useMemo`nun bagimliligini her karede degistirirdi
   *  (lint yakaladi; pano sayfasindaki ayni tuzak). */
  const gunlukKume = useMemo(() => {
    const m = new Map<string, TakvimOgesi[]>();
    for (const o of data?.items ?? []) {
      const g = gunBasi(new Date(o.baslangic));
      const k = g.toDateString();
      (m.get(k) ?? m.set(k, []).get(k)!).push(o);
    }
    return m;
  }, [data]);

  /** Ajandada cizilecek gunler: OLAYI OLANLAR. Ay gorunumunde AY DISI
   *  gunler ELENIR — izgarada tam hafta olsun diye cizilirler, duz bir
   *  listede ise komsu ayin gunu, kullanicinin bakmadigi bir aya ait
   *  satir olarak gorunurdu. */
  const ajandaGunleri = useMemo(() => {
    if (!ajanda || gorunum === GORUNUM_GUN) return [];
    return Array.from(
      { length: gorunum === GORUNUM_HAFTA ? 7 : 42 },
      (_, i) => gunEkle(bas, i),
    ).filter(
      (g) =>
        (gunlukKume.get(g.toDateString()) ?? []).length > 0 &&
        (gorunum !== GORUNUM_AY || g.getMonth() === capa.getMonth()),
    );
  }, [ajanda, gorunum, bas, capa, gunlukKume]);

  function kaydir(yon: -1 | 1) {
    if (gorunum === GORUNUM_GUN) setCapa(gunEkle(capa, yon));
    else if (gorunum === GORUNUM_HAFTA) setCapa(gunEkle(capa, 7 * yon));
    else setCapa(new Date(capa.getFullYear(), capa.getMonth() + yon, 1));
  }

  const baslikMetni = new Intl.DateTimeFormat(undefined, {
    month: "long",
    year: "numeric",
    ...(gorunum === GORUNUM_GUN ? { day: "numeric" } : {}),
  }).format(capa);

  const govde = (
    <div className="space-y-3">
      {/* --- ARAC CUBUGU --------------------------------------------- */}
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-1">
          <Dugme tur="ikincil" boy="kucuk" onClick={() => kaydir(-1)}>
            {t("takvimOnceki")}
          </Dugme>
          <Dugme tur="ikincil" boy="kucuk" onClick={() => setCapa(new Date())}>
            {t("takvimBugun")}
          </Dugme>
          <Dugme tur="ikincil" boy="kucuk" onClick={() => kaydir(1)}>
            {t("takvimSonraki")}
          </Dugme>
          <span className="ms-2" style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
            {baslikMetni}
          </span>
        </div>
        <div className="flex flex-wrap items-center gap-1">
          {GORUNUMLER.map((g) => (
            <Dugme
              key={g.id}
              boy="kucuk"
              tur={g.id === gorunum ? TUR_BIRINCIL : TUR_IKINCIL}
              aria-pressed={g.id === gorunum}
              onClick={() => setGorunum(g.id)}
            >
              {t(g.anahtar)}
            </Dugme>
          ))}
          <Dugme
            tur="ikincil"
            boy="kucuk"
            onClick={() => setTamEkran((x) => !x)}
          >
            {tamEkran ? t("takvimDaralt") : t("takvimGenislet")}
          </Dugme>
          <Dugme
            tur="birincil"
            boy="kucuk"
            onClick={() => {
              setDuzenlenen(null);
              setSecilenGun(gunBasi(capa));
              setFormAcik(true);
            }}
          >
            {t("takvimHatirlatmaEkle")}
          </Dugme>
        </div>
      </div>

      {error ? <HataDurumu mesaj={t("takvimYuklenemedi")} /> : null}

      {/* --- IZGARA --------------------------------------------------- */}
      {isLoading && !data ? (
        <IskeletMetin satir={6} />
      ) : gorunum === GORUNUM_GUN ? (
        <GunListesi
          ogeler={gunlukKume.get(gunBasi(capa).toDateString()) ?? []}
          onSecim={(o) => {
            if (o.tip === TIP_HATIRLATMA) {
              setDuzenlenen(o.id);
              setFormAcik(true);
            }
          }}
        />
      ) : ajanda ? (
        // AJANDA: gun basligi TIKLANABILIR kalir — izgarada bir hucreye
        // dokunmanin islevi o gunu SECMEKTIR ve "Hatirlatma ekle" secili
        // gunu on-doldurur. Baslik duz metin olsaydi bu kisayol dar
        // ekranda kaybolurdu.
        ajandaGunleri.length === 0 ? (
          <BosDurum baslik={t("takvimOlayYok")} />
        ) : (
          <ul className="space-y-3">
            {ajandaGunleri.map((gun) => (
              <li key={gun.toISOString()}>
                <button
                  type="button"
                  onClick={() => setSecilenGun(gun)}
                  aria-pressed={secilenGun ? ayniGun(gun, secilenGun) : false}
                  className="odak-ic mb-1 block w-full text-start"
                  style={{
                    fontSize: "var(--yz-fs-sm)",
                    color: ayniGun(gun, bugun)
                      ? "var(--yz-accent-ink)"
                      : "var(--yz-text)",
                  }}
                >
                  {new Intl.DateTimeFormat(undefined, {
                    weekday: "long",
                    day: "numeric",
                    month: "long",
                  }).format(gun)}
                </button>
                <GunListesi
                  ogeler={gunlukKume.get(gun.toDateString()) ?? []}
                  onSecim={(o) => {
                    if (o.tip === TIP_HATIRLATMA) {
                      setDuzenlenen(o.id);
                      setFormAcik(true);
                    }
                  }}
                />
              </li>
            ))}
          </ul>
        )
      ) : (
        <div
          className="grid gap-1"
          style={{ gridTemplateColumns: "repeat(7, minmax(0, 1fr))" }}
        >
          {/* GUN BASLIKLARI AKTIF DILDEN: sabit "Pzt Sal..." yazmak yedi
              dilden altisinda yanlis olurdu. */}
          {Array.from({ length: 7 }, (_, i) => (
            <div
              key={i}
              className="px-1 pb-1 text-center"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
            >
              {new Intl.DateTimeFormat(undefined, { weekday: "short" }).format(
                gunEkle(haftaBasi(new Date()), i),
              )}
            </div>
          ))}
          {Array.from(
            { length: gorunum === GORUNUM_HAFTA ? 7 : 42 },
            (_, i) => gunEkle(bas, i),
          ).map((gun) => {
            const gunun = gunlukKume.get(gun.toDateString()) ?? [];
            const ayDisi =
              gorunum === GORUNUM_AY && gun.getMonth() !== capa.getMonth();
            return (
              <button
                key={gun.toISOString()}
                type="button"
                onClick={() => {
                  setSecilenGun(gun);
                  setDuzenlenen(null);
                }}
                className="odak-ic min-h-20 rounded-lg border p-1 text-start align-top"
                style={{
                  borderColor: ayniGun(gun, bugun)
                    ? "var(--yz-accent-edge)"
                    : "var(--yz-border)",
                  // BUGUN KENARLIKLA VURGULANIR, dolguyla DEGIL: dolgu,
                  // icindeki olay noktalarinin kontrastini dusururdu.
                  borderWidth: ayniGun(gun, bugun) ? KENAR_BUGUN : "var(--yz-border-w)",
                  // AY DISI GUNLER SOLUK ama GIZLI DEGIL: izgaranin tam
                  // hafta olmasi icin cizilirler, tiklanabilir kalirlar.
                  opacity: ayDisi ? 0.45 : 1,
                  background: "var(--yz-surface-1)",
                }}
              >
                <span
                  className="block text-end"
                  style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                >
                  {gun.getDate()}
                </span>
                <span className="mt-0.5 block space-y-0.5">
                  {gunun.slice(0, 3).map((o, i) => (
                    <span
                      key={`${o.id}-${o.baslangic}-${i}`}
                      className="flex items-center gap-1"
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                    >
                      <span
                        aria-hidden
                        className="inline-block h-1.5 w-1.5 shrink-0 rounded-full"
                        style={{
                          background:
                            o.tip === TIP_HATIRLATMA && o.renk
                              ? (RENKLER.find((r) => r.id === o.renk)?.deger ??
                                 TIP_RENGI[o.tip])
                              : TIP_RENGI[o.tip],
                        }}
                      />
                      <span className="truncate">
                        {o.tip === TIP_AIDAT
                          ? t("takvimAidatOzet", { sayi: o.baslik })
                          : o.baslik}
                      </span>
                    </span>
                  ))}
                  {gunun.length > 3 && (
                    <span
                      className="block"
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                    >
                      +{gunun.length - 3}
                    </span>
                  )}
                </span>
              </button>
            );
          })}
        </div>
      )}

      {/* --- SECILEN GUNUN LISTESI ------------------------------------ */}
      {/* Ajandada her gunun listesi ZATEN cizili; secilen gunu bir daha
          cizmek ayni olaylari iki kez gostermek olurdu. */}
      {secilenGun && gorunum !== GORUNUM_GUN && !ajanda && (
        <GunListesi
          ogeler={gunlukKume.get(secilenGun.toDateString()) ?? []}
          onSecim={(o) => {
            if (o.tip === TIP_HATIRLATMA) {
              setDuzenlenen(o.id);
              setFormAcik(true);
            }
          }}
        />
      )}

      {diyalog}
      <HatirlatmaFormu
        acik={formAcik}
        hatirlatmaId={duzenlenen}
        baslangicOnerisi={secilenGun ?? capa}
        onKapat={() => setFormAcik(false)}
        onDegisti={() => void mutate()}
        onSil={async (id) => {
          if (
            !(await onayla({
              baslik: t("takvimHatirlatmaDuzenle"),
              mesaj: t("takvimHatirlatmaSilOnay"),
              onayMetni: t("ortakSil"),
              tehlikeli: true,
            }))
          ) {
            return;
          }
          await apiSend(`/api/hatirlatmalar/${id}`, "DELETE");
          toast.success(t("takvimHatirlatmaSilindi"));
          setFormAcik(false);
          void mutate();
        }}
      />
    </div>
  );

  // TAM EKRAN BIR MODAL DEGIL, SABIT BIR KATMAN: modal odagi hapseder ve
  // takvimin icindeki hatirlatma modali ikinci bir katman acardi
  // (ic ice diyalog, klavye tuzagi).
  if (tamEkran) {
    return (
      <div
        className="fixed inset-0 overflow-y-auto p-4"
        style={{ zIndex: "var(--yz-z-drawer)" as unknown as number, background: "var(--yz-bg-app)" }}
      >
        <Kart className="p-kart">{govde}</Kart>
      </div>
    );
  }
  return <Kart className="p-kart">{govde}</Kart>;
}

/** Bir gunun olaylari — okunur liste (izgara hucresi ozet gosterir). */
function GunListesi({
  ogeler,
  onSecim,
}: {
  ogeler: TakvimOgesi[];
  onSecim: (o: TakvimOgesi) => void;
}) {
  const t = useT();
  if (ogeler.length === 0) return <BosDurum baslik={t("takvimOlayYok")} />;
  return (
    <ul className="space-y-1">
      {ogeler.map((o, i) => (
        <li
          key={`${o.id}-${o.baslangic}-${i}`}
          className="flex flex-wrap items-center justify-between gap-2 border-b py-1 last:border-b-0"
          style={{ borderColor: "var(--yz-border)" }}
        >
          <span className="flex min-w-0 items-center gap-2">
            <span
              aria-hidden
              className="inline-block h-2 w-2 shrink-0 rounded-full"
              style={{ background: TIP_RENGI[o.tip] }}
            />
            <span className="min-w-0">
              <span
                className="block truncate"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
              >
                {o.tip === TIP_AIDAT
                  ? t("takvimAidatOzet", { sayi: o.baslik })
                  : o.baslik}
              </span>
              <span
                className="block"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
              >
                {t(TIP_ANAHTARI[o.tip])} ·{" "}
                {new Intl.DateTimeFormat(undefined, {
                  hour: "2-digit",
                  minute: "2-digit",
                }).format(new Date(o.baslangic))}
              </span>
            </span>
          </span>
          <span className="flex shrink-0 gap-2">
            {o.tip === TIP_HATIRLATMA && (
              <Dugme tur="ikincil" boy="kucuk" onClick={() => onSecim(o)}>
                {t("ortakDuzenle")}
              </Dugme>
            )}
            {/* BAGLANTI, DUGME DEGIL: bir sayfaya gidiyor. `Dugme`
                bileseninin `as` alani yok ve eklemek, "dugme mi baglanti
                mi" ayrimini her cagri yerinde belirsizlestirirdi. */}
            {o.hedef && (
              <Link
                href={o.hedef}
                className="odak-ic rounded-btn px-2 py-1 underline"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-accent-ink)" }}
              >
                {t("takvimKaydaGit")}
              </Link>
            )}
          </span>
        </li>
      ))}
    </ul>
  );
}

/** Hatirlatma ekleme/duzenleme formu. */
function HatirlatmaFormu({
  acik,
  hatirlatmaId,
  baslangicOnerisi,
  onKapat,
  onDegisti,
  onSil,
}: {
  acik: boolean;
  hatirlatmaId: string | null;
  baslangicOnerisi: Date;
  onKapat: () => void;
  onDegisti: () => void;
  onSil: SilmeIslemi;
}) {
  const t = useT();
  const toast = useToast();
  const [baslik, setBaslik] = useState("");
  const [aciklama, setAciklama] = useState("");
  const [baslangic, setBaslangic] = useState("");
  const [bitis, setBitis] = useState("");
  const [renk, setRenk] = useState(RENKLER[0].id);
  const [tekrar, setTekrar] = useState(TEKRARLAR[0].id);
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);

  // KAYITLI LISTE DUZENLEME ICIN CEKILIR. Takvim yaniti hatirlatmanin
  // aciklamasini ve tekrar kuralini TASIMAZ (takvim bir gorunum, kayit
  // degil); duzenleme formu kaydin kendisine ihtiyac duyar.
  const { data: kayitlar } = useSWR<
    { id: string; baslik: string; aciklama: string | null; baslangic: string;
      bitis: string | null; renk: string; tekrar: string }[]
  >(acik ? HATIRLATMA_YOLU : null, jsonFetcher);

  // Form ACILISTA doldurulur; kullanici yazarken SWR tazelemesi ezmesin.
  const [yuklenen, setYuklenen] = useState<string | null>(null);
  if (acik && yuklenen !== (hatirlatmaId ?? "")) {
    const k = hatirlatmaId ? kayitlar?.find((x) => x.id === hatirlatmaId) : null;
    if (hatirlatmaId && !k) {
      // Kayit henuz gelmedi — bu karede doldurma.
    } else {
      setYuklenen(hatirlatmaId ?? "");
      setBaslik(k?.baslik ?? "");
      setAciklama(k?.aciklama ?? "");
      setBaslangic(yerelIso(k ? new Date(k.baslangic) : baslangicOnerisi));
      setBitis(k?.bitis ? yerelIso(new Date(k.bitis)) : "");
      setRenk(k?.renk ?? RENKLER[0].id);
      setTekrar(k?.tekrar ?? TEKRARLAR[0].id);
      setHata(null);
    }
  }
  if (!acik && yuklenen !== null) setYuklenen(null);

  async function kaydet() {
    setHata(null);
    setKaydediyor(true);
    try {
      const govde = {
        baslik: baslik.trim(),
        aciklama: aciklama.trim() || null,
        // YEREL GIRDI -> UTC: `datetime-local` saat dilimi tasimaz;
        // `new Date(...)` onu YEREL kabul eder ve `toISOString` UTC'ye
        // cevirir. Ham dizeyi gondermek, sunucuda saatin kaymasi demekti.
        baslangic: new Date(baslangic).toISOString(),
        bitis: bitis ? new Date(bitis).toISOString() : null,
        renk,
        tekrar,
      };
      if (hatirlatmaId) {
        await apiSend(`/api/hatirlatmalar/${hatirlatmaId}`, "PATCH", govde);
      } else {
        await apiSend(HATIRLATMA_YOLU, "POST", govde);
      }
      toast.success(t("takvimHatirlatmaEklendi"));
      onDegisti();
      onKapat();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setKaydediyor(false);
    }
  }

  return (
    <Modal
      acik={acik}
      baslik={hatirlatmaId ? t("takvimHatirlatmaDuzenle") : t("takvimHatirlatmaEkle")}
      onKapat={onKapat}
      eylemler={
        <div className="flex w-full items-center justify-between gap-2">
          {hatirlatmaId ? (
            <Dugme tur="tehlike" boy="kucuk" onClick={() => void onSil(hatirlatmaId)}>
              {t("ortakSil")}
            </Dugme>
          ) : (
            <span />
          )}
          <span className="flex gap-2">
            <Dugme tur="ikincil" onClick={onKapat}>{t("ortakIptal")}</Dugme>
            <Dugme tur="birincil" disabled={kaydediyor} onClick={() => void kaydet()}>
              {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </span>
        </div>
      }
    >
      <div className="grid gap-3">
        <AlanSarmal etiket={t("takvimAlanBaslik")} zorunlu>
          {(b) => (
            <Alan {...b} value={baslik} onChange={(e) => setBaslik(e.target.value)} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("takvimAlanAciklama")}>
          {(b) => (
            <CokSatir {...b} rows={3} value={aciklama}
              onChange={(e) => setAciklama(e.target.value)} />
          )}
        </AlanSarmal>
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("takvimAlanBaslangic")} zorunlu>
            {(b) => (
              <Alan {...b} type="datetime-local" value={baslangic}
                onChange={(e) => setBaslangic(e.target.value)} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("takvimAlanBitis")}>
            {(b) => (
              <Alan {...b} type="datetime-local" value={bitis}
                onChange={(e) => setBitis(e.target.value)} />
            )}
          </AlanSarmal>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("takvimAlanRenk")}>
            {(b) => (
              <Secim {...b} value={renk} onChange={(e) => setRenk(e.target.value)}>
                {RENKLER.map((r) => (
                  <option key={r.id} value={r.id}>{t(r.anahtar)}</option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("takvimAlanTekrar")}>
            {(b) => (
              <Secim {...b} value={tekrar} onChange={(e) => setTekrar(e.target.value)}>
                {TEKRARLAR.map((r) => (
                  <option key={r.id} value={r.id}>{t(r.anahtar)}</option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
        </div>
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}
