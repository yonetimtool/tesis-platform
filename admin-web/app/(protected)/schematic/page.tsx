"use client";

import { useState } from "react";
import useSWR from "swr";

import { ErrorBox } from "@/components/form";
import { jsonFetcher } from "@/lib/fetcher";
import type {
  BuildingMap,
  BuildingMapUnit,
  DensityRenk,
  UnitComplaint,
  UnitComplaintList,
} from "@/lib/types";

// Renk API'den gelir (yesil/sari/kirmizi = 0-2/3-4/5+); panel ESIK HESAPLAMAZ.
const RENK_CLS: Record<DensityRenk, { cell: string; dot: string; text: string }> = {
  yesil: { cell: "bg-emerald-500 border-emerald-600", dot: "bg-emerald-500", text: "text-emerald-700" },
  sari: { cell: "bg-amber-500 border-amber-600", dot: "bg-amber-500", text: "text-amber-700" },
  kirmizi: { cell: "bg-red-500 border-red-600", dot: "bg-red-500", text: "text-red-700" },
};

function cls(renk: DensityRenk) {
  return RENK_CLS[renk] ?? RENK_CLS.yesil;
}

const KATEGORI_LABEL: Record<string, string> = {
  gurultu: "Gürültü",
  ayakkabi: "Kapı önü / ayakkabı",
  diger: "Diğer",
};

function fmtDate(s: string): string {
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? s : d.toLocaleDateString("tr-TR");
}

function UnitCell({
  unit,
  onSelect,
  selected,
}: {
  unit: BuildingMapUnit;
  onSelect: (u: BuildingMapUnit) => void;
  selected: boolean;
}) {
  const c = cls(unit.color);
  return (
    <button
      onClick={() => onSelect(unit)}
      title={`${unit.unit_no} — ${unit.complaint_count} açık şikayet`}
      className={`flex h-16 w-20 flex-col items-center justify-center rounded-lg border text-white transition ${c.cell} ${
        selected ? "ring-2 ring-ink ring-offset-2" : "hover:opacity-90"
      }`}
    >
      <span className="text-sm font-semibold">{unit.unit_no}</span>
      <span className="text-xs opacity-90">{unit.complaint_count}</span>
    </button>
  );
}

function Legend() {
  const item = (renk: DensityRenk, label: string) => (
    <span className="flex items-center gap-1.5">
      <span className={`inline-block h-3.5 w-3.5 rounded ${cls(renk).dot}`} />
      <span className="text-sm text-slate-600">{label}</span>
    </span>
  );
  return (
    <div className="flex flex-wrap items-center gap-4 rounded-xl border border-slate-200 bg-white p-3">
      <span className="text-sm font-medium">Yoğunluk:</span>
      {item("yesil", "0–2 (yeşil)")}
      {item("sari", "3–4 (sarı)")}
      {item("kirmizi", "5+ (kırmızı)")}
    </div>
  );
}

function DetailPanel({ unit }: { unit: BuildingMapUnit }) {
  // ANONIM sikayet listesi (durum=acik — sayimla tutarli). notlar admin/yonetici
  // icin dolu (backend zorlar); complainant ASLA gelmez.
  const { data, error, isLoading } = useSWR<UnitComplaintList>(
    `/api/unit-complaints?target_unit_id=${unit.unit_id}&durum=acik`,
    jsonFetcher,
  );
  const c = cls(unit.color);
  const items: UnitComplaint[] = data?.items ?? [];

  return (
    <div className="space-y-3 rounded-xl border border-slate-300 bg-white p-5">
      <div className="flex items-center gap-2">
        <span className={`inline-block h-4 w-4 rounded ${c.dot}`} />
        <h2 className="text-lg font-medium">Daire {unit.unit_no}</h2>
        <span className={`ml-auto font-semibold ${c.text}`}>
          {unit.complaint_count} açık şikayet
        </span>
      </div>
      {unit.blok != null && (
        <p className="text-sm text-muted">
          Blok {unit.blok}
          {unit.kat != null ? ` · Kat ${unit.kat}` : ""}
          {unit.sira != null ? ` · Sıra ${unit.sira}` : ""}
        </p>
      )}
      {error && <ErrorBox message="Şikayetler yüklenemedi." />}
      {isLoading && <p className="text-sm text-muted">Yükleniyor...</p>}
      {!isLoading && items.length === 0 && (
        <p className="text-sm text-muted">Bu daire için açık şikayet yok.</p>
      )}
      <ul className="space-y-1 text-sm">
        {items.map((it) => (
          <li key={it.id} className="rounded border border-slate-100 px-3 py-2">
            <div className="flex justify-between">
              <span className="font-medium">
                {KATEGORI_LABEL[it.kategori] ?? it.kategori}
              </span>
              <span className="text-muted">{fmtDate(it.created_at)}</span>
            </div>
            {it.notlar && <p className="mt-1 text-slate-600">{it.notlar}</p>}
          </li>
        ))}
      </ul>
      <p className="text-xs text-muted">
        Şikayetler anonimdir — şikayet edenin kimliği hiçbir yerde gösterilmez.
      </p>
    </div>
  );
}

export default function SchematicPage() {
  const { data, error, isLoading } = useSWR<BuildingMap>("/api/building-map", jsonFetcher);
  const [selected, setSelected] = useState<BuildingMapUnit | null>(null);

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Şikayet Haritası</h1>
      </div>

      <Legend />

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      <div className="grid gap-5 lg:grid-cols-[1fr_360px]">
        {/* Sema: blok -> kat (ust kat yukarida) -> renkli hucreler */}
        <div className="space-y-4">
          {(data?.bloklar ?? []).map((blok) => (
            <div
              key={blok.blok}
              className="space-y-3 rounded-xl border border-slate-200 bg-white p-5"
            >
              <h2 className="font-medium">Blok {blok.blok}</h2>
              {/* building-map kat'i ARTAN doner; kat plani icin AZALAN goster */}
              {[...blok.katlar].reverse().map((kat) => (
                <div key={kat.kat} className="flex items-start gap-3">
                  <span className="w-14 shrink-0 pt-5 text-xs text-slate-500">
                    Kat {kat.kat}
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
              <h2 className="font-medium">Haritada yerleşimi girilmemiş</h2>
              <p className="text-xs text-muted">
                Bu dairelere blok/kat girilmemiş; “Daireler” ekranından yerleşim
                eklenebilir.
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
            <div className="rounded-xl border border-slate-200 bg-white p-8 text-center text-muted">
              Henüz daire yok.
            </div>
          )}
        </div>

        {/* Detay paneli — secili daire */}
        <div>
          {selected ? (
            <DetailPanel unit={selected} />
          ) : (
            <div className="rounded-xl border border-dashed border-slate-300 bg-white p-8 text-center text-muted">
              Detay için bir daire seçin.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
