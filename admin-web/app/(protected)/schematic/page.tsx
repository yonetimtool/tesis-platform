"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { BosDurum, HataDurumu, IskeletMetin, Kart, Sekmeler } from "@/components/ui";
import { PlanHaritasiYukleyici } from "@/components/harita/harita-yukleyici";
import type { PlanBlogu, PlanHucresi } from "@/components/harita/plan-haritasi";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tarihBicimi } from "@/lib/tarih";
import type {
  BuildingMap,
  BuildingMapUnit,
  DensityRenk,
  UnitComplaint,
  UnitComplaintList,
} from "@/lib/types";

// Renk API'den gelir (yesil/sari/kirmizi = 0-2/3-4/5+); panel ESIK HESAPLAMAZ.
//
// (P160) ZEMIN RENGI BIRAKILDI, KENAR RENGI ALINDI. Eskiden hucre KOYU
// RENKLE doluydu ve uzerinde BEYAZ metin vardi; bu duzen 4.5 kontrast
// istiyor ve her iki temada ayri ayri olculmesi gerekiyordu (tur 30 axe
// denetimi -500 tonlarini tam bu yuzden dusurmustu). Yeni dilde hucre
// KABARTILMIS METAL yuzeydir: metin normal metin renginde (zaten AA) ve
// yogunluk KENAR + NOKTA ile anlatilir. Anlamli grafik esigi 3.0'dir ve
// `--yz-*-edge` tonlari tam bunun icin olculdu (WCAG 1.4.11).
//
// RENK TEK TASIYICI DEGIL: sayi zaten hucrede yaziyor.
const RENK_TOKEN: Record<DensityRenk, string> = {
  yesil: "var(--yz-success-edge)",
  sari: "var(--yz-warning-edge)",
  kirmizi: "var(--yz-danger-edge)",
};
const NOTR_TOKEN = "var(--yz-border)";
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const GORUNUM_SEMA = "sema" as const;
const GORUNUM_HARITA = "harita" as const;
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`) — CSS olcusu de dize.
const KENAR_SECILI = "3px" as const;
const KENAR_NORMAL = "2px" as const;

/** Yogunluk rengi -> kenar/nokta tonu. null (yapi gorunumu) -> notr. */
function renkTonu(renk: DensityRenk | null | undefined): string {
  return renk ? (RENK_TOKEN[renk] ?? RENK_TOKEN.yesil) : NOTR_TOKEN;
}

// METIN DEGIL KIMLIK: modul duzeyinde `t()` cagrilamaz (bilesen disi) ve
// cagrilabilse bile metin dil degisiminde donmus kalirdi. Harita ANAHTAR
// tutar, cozum cizim aninda yapilir.
const KATEGORI_ANAHTAR: Record<string, SozlukAnahtari> = {
  gurultu: "kategoriGurultu",
  kapi_onu_ayakkabi: "kategoriKapiOnu",
  zarar_verme: "kategoriZararVerme",
  diger: "ortakDiger",
};

const fmtDate = tarihBicimi;

function UnitCell({
  unit,
  onSelect,
  selected,
}: {
  unit: BuildingMapUnit;
  onSelect: (u: BuildingMapUnit) => void;
  selected: boolean;
}) {
  const t = useT();
  const ton = renkTonu(unit.color);
  return (
    <button
      onClick={() => onSelect(unit)}
      // (P160) SECILILIK eskiden yalniz HALKA ile belliydi; ekran okuyucu
      // hangi dairenin acik oldugunu soylemiyordu.
      aria-pressed={selected}
      title={t("haritaKartBaslik", { daire: unit.unit_no, sayi: unit.complaint_count ?? 0 })}
      className={`odak-ic yz-raised flex h-16 w-20 flex-col items-center justify-center gap-0.5 ${
        selected ? "" : "yz-lift"
      }`}
      style={{
        borderRadius: "var(--yz-radius-btn)",
        // Secili hucre KALIN kenar: renk zaten yogunlugu tasiyor, kalinlik
        // secimi tasir — ikisi ayri kanal.
        border: `${selected ? KENAR_SECILI : KENAR_NORMAL} solid ${ton}`,
        color: "var(--yz-text)",
        background: "var(--yz-metal-1)",
      }}
    >
      <span style={{ fontSize: "var(--yz-fs-sm)", fontWeight: 600 }}>{unit.unit_no}</span>
      <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
        {unit.complaint_count ?? 0}
      </span>
    </button>
  );
}

function Legend() {
  const t = useT();
  const item = (renk: DensityRenk, label: string) => (
    <span className="flex items-center gap-1.5">
      <span
        className="inline-block h-3.5 w-3.5"
        style={{ borderRadius: "var(--yz-radius-sm)", background: renkTonu(renk) }}
      />
      <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{label}</span>
    </span>
  );
  return (
    <Kart className="flex flex-wrap items-center gap-4 !p-3">
      <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
        {t("haritaYogunluk")}
      </span>
      {item("yesil", t("haritaYesil"))}
      {item("sari", t("haritaSari"))}
      {item("kirmizi", t("haritaKirmizi"))}
    </Kart>
  );
}

function DetailPanel({ unit }: { unit: BuildingMapUnit }) {
  const t = useT();
  // Sikayet listesi (durum=acik — sayimla tutarli). Rev-1: yonetim gorunumunde
  // notlar + complainant (sikayet eden) DOLU gelir (denetim; backend zorlar).
  const { data, error, isLoading } = useSWR<UnitComplaintList>(
    `/api/unit-complaints?target_unit_id=${unit.unit_id}&durum=acik`,
    jsonFetcher,
  );
  const ton = renkTonu(unit.color);
  const items: UnitComplaint[] = data?.items ?? [];

  return (
    <Kart className="space-y-3">
      <div className="flex items-center gap-2">
        <span
          className="inline-block h-4 w-4"
          style={{ borderRadius: "var(--yz-radius-sm)", background: ton }}
        />
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("haritaDaireNo", { no: unit.unit_no })}
        </h2>
        {/* SAYI metin renginde: renkli metin 4.5 ister ve iki temada ayri
            olcum demekti; nokta zaten rengi tasiyor. */}
        <span className="ms-auto" style={{ fontWeight: 600, color: "var(--yz-text)" }}>
          {t("haritaAcikSikayetSayisi", { n: unit.complaint_count ?? 0 })}
        </span>
      </div>
      {unit.blok != null && (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("haritaBlokKatSira", { blok: unit.blok })}
          {unit.kat != null ? ` · ${t("haritaKat", { kat: unit.kat })}` : ""}
          {unit.sira != null ? ` · ${t("haritaSira", { sira: unit.sira })}` : ""}
        </p>
      )}
      {error && <HataDurumu mesaj={t("haritaYuklenemedi")} />}
      {isLoading && <IskeletMetin satir={3} />}
      {/* (P61) `!error` SART. Eski kosul yalniz `!isLoading`e bakiyordu:
          istek dustugunde "Harita yuklenemedi" ile "Acik sikayet yok" YAN
          YANA cikiyordu — ustelik basliktaki sayac haritadan gelip "3 acik
          sikayet" yazarken. "Yuklenemedi" bir durumdur, "yok" bir
          IDDIADIR. */}
      {!isLoading && !error && items.length === 0 && (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("haritaAcikSikayetYok")}
        </p>
      )}
      <ul className="space-y-1">
        {items.map((it) => (
          <li
            key={it.id}
            className="px-3 py-2"
            style={{
              borderRadius: "var(--yz-radius-sm)",
              border: "1px solid var(--yz-border)",
              fontSize: "var(--yz-fs-sm)",
              color: "var(--yz-text)",
            }}
          >
            <div className="flex justify-between">
              <span style={{ fontWeight: 600 }}>
                {KATEGORI_ANAHTAR[it.kategori]
                  ? t(KATEGORI_ANAHTAR[it.kategori])
                  : it.kategori}
              </span>
              <span style={{ color: "var(--yz-text-3)" }}>{fmtDate(it.created_at)}</span>
            </div>
            {/* Rev-1: sikayet eden kimligi YALNIZ yonetime (denetim). */}
            {it.complainant_ad && (
              <p
                className="mt-0.5"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              >
                {t("haritaSikayetEden", { kisi: it.complainant_ad })}
              </p>
            )}
            {it.notlar && (
              <p className="mt-1" style={{ color: "var(--yz-text-2)" }}>
                {it.notlar}
              </p>
            )}
          </li>
        ))}
      </ul>
      <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
        {t("haritaKimlikNotu")}
      </p>
    </Kart>
  );
}

export default function SchematicPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<BuildingMap>("/api/building-map", jsonFetcher);
  const [selected, setSelected] = useState<BuildingMapUnit | null>(null);
  const [gorunum, setGorunum] = useState<string>(GORUNUM_SEMA);

  /**
   * (P160) PLAN HARITASININ GIRDISI — `blok`/`kat`/`sira` GERCEK VERI.
   *
   * Duzlem su sekilde kuruluyor: her blok yatayda kendi seridini alir,
   * blok icinde `sira` sutunu, `kat` ise dikey ekseni verir. Uydurulan
   * hicbir sey yok; kat/sira girilmemis daire zaten `unplaced` kovasinda
   * ve haritaya HIC girmiyor (asagida ayrica yaziyor).
   */
  const { hucreler, planBloklari, yerlesimsiz } = useMemo(() => {
    const h: PlanHucresi[] = [];
    const b: PlanBlogu[] = [];
    let x = 0;
    for (const blok of data?.bloklar ?? []) {
      let genislik = 1;
      for (const kat of blok.katlar) {
        for (const u of kat.units) {
          // `sira` yoksa hucre cizilemez: uydurma bir sutun, daireyi
          // olmadigi yere koymakti.
          if (u.sira == null || u.kat == null) continue;
          genislik = Math.max(genislik, u.sira);
          h.push({
            id: u.unit_id,
            etiket: u.unit_no,
            x: x + (u.sira - 1),
            y: u.kat,
            ton: renkTonu(u.color),
            ipucu: t("haritaKartBaslik", {
              daire: u.unit_no,
              sayi: u.complaint_count ?? 0,
            }),
            secili: selected?.unit_id === u.unit_id,
          });
        }
      }
      b.push({ ad: blok.blok, x, genislik });
      x += genislik + 1; // bloklar arasinda bir birim bosluk
    }
    // Kat/sira girilmemis daireler haritada YOK — sayisi yaziliyor ki
    // "haritada gormedigim daire yok" sanilmasin.
    const eksik =
      (data?.bloklar ?? []).reduce(
        (n, blok) =>
          n +
          blok.katlar.reduce(
            (m, kat) => m + kat.units.filter((u) => u.sira == null || u.kat == null).length,
            0,
          ),
        0,
      ) + (data?.unplaced?.length ?? 0);
    return { hucreler: h, planBloklari: b, yerlesimsiz: eksik };
  }, [data, selected, t]);

  return (
    <div className="space-y-5">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("kabukSikayetHaritasi")}
      </h1>

      <Legend />

      {error && <HataDurumu mesaj={error.message} />}
      {isLoading && !data && (
        <Kart>
          <IskeletMetin satir={4} />
        </Kart>
      )}

      <div className="grid gap-5 lg:grid-cols-[1fr_360px]">
        <Sekmeler
          aktifId={gorunum}
          onDegis={setGorunum}
          sekmeler={[
            {
              id: GORUNUM_SEMA,
              baslik: t("haritaGorunumSema"),
              // SEMA ERISILEBILIR YUZEYDIR ve VARSAYILANDIR: her hucre
              // gercek bir dugmedir, klavyeyle gezilir ve ekran okuyucu
              // adini okur. Harita onun yerine GECMEZ, yanina gelir.
              // Sema: blok -> kat (ust kat yukarida) -> renkli hucreler.
              icerik: (
                <div className="space-y-4">
          {(data?.bloklar ?? []).map((blok) => (
            <Kart key={blok.blok} className="space-y-3">
              <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
                {t("blokEtiketi", { ad: blok.blok })}
              </h2>
              {/* building-map kat'i ARTAN doner; kat plani icin AZALAN goster */}
              {[...blok.katlar].reverse().map((kat) => (
                <div key={kat.kat} className="flex items-start gap-3">
                  <span
                    className="w-14 shrink-0 pt-5"
                    style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                  >
                    {t("haritaKat", { kat: kat.kat })}
                  </span>
                  <div className="flex flex-wrap gap-2">
                    {kat.units.map((u) => (
                      <UnitCell
                        key={u.unit_id}
                        unit={u}
                        selected={selected?.unit_id === u.unit_id}
                        onSelect={setSelected}
                      />
                    ))}
                  </div>
                </div>
              ))}
            </Kart>
          ))}

          {/* Yerlesimi girilmemis daireler — ayni renk + tiklama */}
          {(data?.unplaced?.length ?? 0) > 0 && (
            <Kart
              className="space-y-3"
              style={{ borderColor: "var(--yz-warning-edge)" }}
            >
              <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
                {t("haritaYerlesimYok")}
              </h2>
              <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("haritaYerlesimNotu")}
              </p>
              <div className="flex flex-wrap gap-2">
                {(data?.unplaced ?? []).map((u) => (
                  <UnitCell
                    key={u.unit_id}
                    unit={u}
                    selected={selected?.unit_id === u.unit_id}
                    onSelect={setSelected}
                  />
                ))}
              </div>
            </Kart>
          )}

          {data && data.bloklar.length === 0 && (data.unplaced?.length ?? 0) === 0 && (
            <Kart>
              <BosDurum baslik={t("haritaDaireYok")} />
            </Kart>
          )}
        </div>
              ),
            },
            {
              id: GORUNUM_HARITA,
              baslik: t("haritaGorunumHarita"),
              // HARITA: buyuk sitelerde pan/zoom kazandirir. Tuval
              // uzerindeki dikdortgen ekran okuyucuya bir sey soylemez —
              // bu yuzden ALTERNATIF gorunum, tek gorunum degil.
              icerik: (
                <div className="space-y-2">
                  <PlanHaritasiYukleyici
                    hucreler={hucreler}
                    bloklar={planBloklari}
                    onSec={(id) => {
                      const bulunan = (data?.bloklar ?? [])
                        .flatMap((b) => b.katlar.flatMap((k) => k.units))
                        .find((u) => u.unit_id === id);
                      if (bulunan) setSelected(bulunan);
                    }}
                  />
                  {/* HARITANIN NE OLMADIGINI YAZAR. */}
                  <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                    {t("haritaPlanNotu")}
                  </p>
                  {/* SESSIZ EKSIK YOK: haritada olmayan daireler sayilir. */}
                  {yerlesimsiz > 0 && (
                    <p
                      role="status"
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}
                    >
                      {t("haritaPlanEksik", { sayi: yerlesimsiz })}
                    </p>
                  )}
                </div>
              ),
            },
          ]}
        />

        {/* Detay paneli — secili daire */}
        <div>
          {selected ? (
            <DetailPanel unit={selected} />
          ) : (
            <div
              className="p-8 text-center"
              style={{
                borderRadius: "var(--yz-radius-card)",
                border: "1px dashed var(--yz-border)",
                fontSize: "var(--yz-fs-sm)",
                color: "var(--yz-text-2)",
              }}
            >
              {t("haritaDaireSecin")}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
