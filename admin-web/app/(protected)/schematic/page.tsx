"use client";

import { useState } from "react";
import useSWR from "swr";

import { ErrorBox, PageHeader, cardCls } from "@/components/form";
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
// HUCRE ZEMINI: uzerinde BEYAZ metin var, bu yuzden -500 tonlari yetmiyordu
// (beyaz/amber-500 ~2.1, beyaz/emerald-500 ~2.5 — WCAG AA esigi 4.5).
// Tur 30 axe denetimi yakaladi. Nokta (`dot`) ve etiket (`text`) tonlari
// DEGISMEDI: onlar beyaz zemin uzerinde ve zaten gecerli.
const RENK_CLS: Record<DensityRenk, { cell: string; dot: string; text: string }> = {
  yesil: { cell: "bg-emerald-700 border-emerald-800", dot: "bg-emerald-500", text: "text-emerald-700" },
  sari: { cell: "bg-amber-700 border-amber-800", dot: "bg-amber-500", text: "text-amber-700" },
  kirmizi: { cell: "bg-red-600 border-red-700", dot: "bg-red-500", text: "text-red-700" },
};

// Renk API'den gelir; null (yapi gorunumu) -> notr. admin/yonetici panelinde
// harita hep yonetim modundadir (shows_density=true), yine de savunmaci.
const NEUTRAL = { cell: "bg-slate-500 border-slate-600", dot: "bg-slate-300", text: "text-metin-body" };
function cls(renk: DensityRenk | null | undefined) {
  return renk ? (RENK_CLS[renk] ?? RENK_CLS.yesil) : NEUTRAL;
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
  const c = cls(unit.color);
  return (
    <button
      onClick={() => onSelect(unit)}
      title={t("haritaKartBaslik", { daire: unit.unit_no, sayi: unit.complaint_count ?? 0 })}
      className={`odak-ters flex h-16 w-20 flex-col items-center justify-center rounded-lg border text-white transition ${c.cell} ${
        selected ? "ring-2 ring-ink ring-offset-2" : "hover:opacity-90"
      }`}
    >
      <span className="text-sm font-semibold">{unit.unit_no}</span>
      <span className="text-xs opacity-90">{unit.complaint_count ?? 0}</span>
    </button>
  );
}

function Legend() {
  const t = useT();
  const item = (renk: DensityRenk, label: string) => (
    <span className="flex items-center gap-1.5">
      <span className={`inline-block h-3.5 w-3.5 rounded ${cls(renk).dot}`} />
      <span className="text-sm text-metin-body">{label}</span>
    </span>
  );
  return (
    <div className={`flex flex-wrap items-center gap-4 ${cardCls} p-3`}>
      <span className="text-sm font-medium">{t("haritaYogunluk")}</span>
      {item("yesil", t("haritaYesil"))}
      {item("sari", t("haritaSari"))}
      {item("kirmizi", t("haritaKirmizi"))}
    </div>
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
  const c = cls(unit.color);
  const items: UnitComplaint[] = data?.items ?? [];

  return (
    <div className={`space-y-3 ${cardCls} p-5`}>
      <div className="flex items-center gap-2">
        <span className={`inline-block h-4 w-4 rounded ${c.dot}`} />
        <h2 className="text-lg font-medium">
          {t("haritaDaireNo", { no: unit.unit_no })}
        </h2>
        <span className={`ms-auto font-semibold ${c.text}`}>
          {t("haritaAcikSikayetSayisi", { n: unit.complaint_count ?? 0 })}
        </span>
      </div>
      {unit.blok != null && (
        <p className="text-sm text-metin-muted">
          {t("haritaBlokKatSira", { blok: unit.blok })}
          {unit.kat != null ? ` · ${t("haritaKat", { kat: unit.kat })}` : ""}
          {unit.sira != null ? ` · ${t("haritaSira", { sira: unit.sira })}` : ""}
        </p>
      )}
      {error && <ErrorBox message={t("haritaYuklenemedi")} />}
      {isLoading && <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>}
      {/* (P61) `!error` SART. Eski kosul yalniz `!isLoading`e bakiyordu:
          istek dustugunde "Harita yuklenemedi" ile "Acik sikayet yok" YAN
          YANA cikiyordu — ustelik basliktaki sayac haritadan gelip "3 acik
          sikayet" yazarken. "Yuklenemedi" bir durumdur, "yok" bir
          IDDIADIR. */}
      {!isLoading && !error && items.length === 0 && (
        <p className="text-sm text-metin-muted">{t("haritaAcikSikayetYok")}</p>
      )}
      <ul className="space-y-1 text-sm">
        {items.map((it) => (
          <li key={it.id} className="rounded border border-yuzey-divider px-3 py-2">
            <div className="flex justify-between">
              <span className="font-medium">
                {KATEGORI_ANAHTAR[it.kategori]
                  ? t(KATEGORI_ANAHTAR[it.kategori])
                  : it.kategori}
              </span>
              <span className="text-metin-muted">{fmtDate(it.created_at)}</span>
            </div>
            {/* Rev-1: sikayet eden kimligi YALNIZ yonetime (denetim). */}
            {it.complainant_ad && (
              <p className="mt-0.5 text-xs text-metin-muted">
                  {t("haritaSikayetEden", { kisi: it.complainant_ad })}
                </p>
            )}
            {it.notlar && <p className="mt-1 text-metin-body">{it.notlar}</p>}
          </li>
        ))}
      </ul>
      <p className="text-xs text-metin-muted">
        {t("haritaKimlikNotu")}
      </p>
    </div>
  );
}

export default function SchematicPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<BuildingMap>("/api/building-map", jsonFetcher);
  const [selected, setSelected] = useState<BuildingMapUnit | null>(null);

  return (
    <div className="space-y-5">
      <PageHeader title={t("kabukSikayetHaritasi")} />

      <Legend />

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>}

      <div className="grid gap-5 lg:grid-cols-[1fr_360px]">
        {/* Sema: blok -> kat (ust kat yukarida) -> renkli hucreler */}
        <div className="space-y-4">
          {(data?.bloklar ?? []).map((blok) => (
            <div
              key={blok.blok}
              className={`space-y-3 ${cardCls} p-5`}
            >
              <h2 className="font-medium">{t("blokEtiketi", { ad: blok.blok })}</h2>
              {/* building-map kat'i ARTAN doner; kat plani icin AZALAN goster */}
              {[...blok.katlar].reverse().map((kat) => (
                <div key={kat.kat} className="flex items-start gap-3">
                  <span className="w-14 shrink-0 pt-5 text-xs text-metin-muted">
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
            </div>
          ))}

          {/* Yerlesimi girilmemis daireler — ayni renk + tiklama */}
          {(data?.unplaced?.length ?? 0) > 0 && (
            <div className="space-y-3 rounded-xl border border-amber-200 bg-amber-50 p-5">
              <h2 className="font-medium">{t("haritaYerlesimYok")}</h2>
              <p className="text-xs text-metin-muted">
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
            </div>
          )}

          {data && data.bloklar.length === 0 && (data.unplaced?.length ?? 0) === 0 && (
            <div className={`${cardCls} p-8 text-center text-metin-muted`}>
              {t("haritaDaireYok")}
            </div>
          )}
        </div>

        {/* Detay paneli — secili daire */}
        <div>
          {selected ? (
            <DetailPanel unit={selected} />
          ) : (
            <div className="rounded-xl border border-dashed border-slate-300 bg-white p-8 text-center text-metin-muted">
              {t("haritaDaireSecin")}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
