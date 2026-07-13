"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, inputCls, btnPrimary, btnGhost } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { Block, BlockList, Unit, UnitList } from "@/lib/types";

// Bloksuz kova (implicit tek blok) icin sentinel — gercek blok etiketi
// alfanumerik ve >=1 karakter, bu deger asla cakismaz.
const BLOCKLESS = "__bloksuz__";

function intOrNull(s: string): number | null {
  const t = s.trim();
  if (t === "") return null;
  const n = Number(t);
  return Number.isInteger(n) ? n : null;
}

interface BlockFormState {
  open: boolean;
  editingId: string | null;
  ad: string;
  err: string | null;
  saving: boolean;
}
const EMPTY_BLOCK: BlockFormState = {
  open: false, editingId: null, ad: "", err: null, saving: false,
};

interface UnitFormState {
  open: boolean;
  editingId: string | null;
  blok: string | null; // null → bloksuz
  no: string;
  kat: string;
  sira: string;
  err: string | null;
  saving: boolean;
}
const EMPTY_UNIT: UnitFormState = {
  open: false, editingId: null, blok: null, no: "", kat: "", sira: "", err: null, saving: false,
};

export default function BuildingEditorPage() {
  const blocks = useSWR<BlockList>("/api/blocks", jsonFetcher);
  const units = useSWR<UnitList>("/api/units?limit=200&offset=0", jsonFetcher);

  const [openBlock, setOpenBlock] = useState<string | null>(null); // null=liste; BLOCKLESS/label=detay
  const [pendingFloors, setPendingFloors] = useState<number[]>([]);
  const [blockForm, setBlockForm] = useState<BlockFormState>(EMPTY_BLOCK);
  const [unitForm, setUnitForm] = useState<UnitFormState>(EMPTY_UNIT);

  const blockItems = useMemo(() => blocks.data?.items ?? [], [blocks.data]);
  const unitItems = useMemo(() => units.data?.items ?? [], [units.data]);

  const labels = useMemo(() => {
    const s = new Set<string>();
    for (const b of blockItems) s.add(b.ad);
    for (const u of unitItems) if (u.blok) s.add(u.blok);
    return [...s].sort();
  }, [blockItems, unitItems]);

  const blocklessUnits = useMemo(() => unitItems.filter((u) => !u.blok), [unitItems]);
  const blockByLabel = (label: string): Block | undefined => blockItems.find((b) => b.ad === label);

  // Bloklu ve bloksuz (blok=null) AYNI akista: kutucuk listesi + bir "Bloksuz"
  // kovasi (mod anahtari yok). Detay: openBlock null degil.
  const drilledIn = openBlock !== null;
  const isBlockless = openBlock === BLOCKLESS;

  function refresh() {
    void blocks.mutate();
    void units.mutate();
  }

  function openTile(label: string) {
    setOpenBlock(label);
    setPendingFloors([]);
  }
  function closeDetail() {
    setOpenBlock(null);
    setPendingFloors([]);
  }

  // --- block CRUD ----------------------------------------------------------
  async function saveBlock(e: React.FormEvent) {
    e.preventDefault();
    setBlockForm((f) => ({ ...f, saving: true, err: null }));
    const body = { ad: blockForm.ad.trim() };
    try {
      if (blockForm.editingId) await apiSend(`/api/blocks/${blockForm.editingId}`, "PATCH", body);
      else await apiSend("/api/blocks", "POST", body);
      setBlockForm(EMPTY_BLOCK);
      refresh();
    } catch (err) {
      const m = err instanceof Error ? err.message : "Kaydedilemedi.";
      setBlockForm((f) => ({
        ...f,
        saving: false,
        err: /zaten kayitli|conflict/i.test(m) ? "Bu blok etiketi zaten kayıtlı." : m,
      }));
    }
  }

  async function removeBlock(b: Block) {
    if (!window.confirm(`Blok ${b.ad} silinsin mi?`)) return;
    try {
      await apiSend(`/api/blocks/${b.id}`, "DELETE");
      if (openBlock === b.ad) closeDetail();
      refresh();
    } catch (err) {
      // 409: blogu kullanan daire var → net mesaj (backend zarfindan gelir).
      window.alert(err instanceof Error ? err.message : "Blok silinemedi.");
    }
  }

  // --- unit CRUD -----------------------------------------------------------
  async function saveUnit(e: React.FormEvent) {
    e.preventDefault();
    setUnitForm((f) => ({ ...f, saving: true, err: null }));
    const body = {
      no: unitForm.no.trim(),
      blok: unitForm.blok,
      kat: intOrNull(unitForm.kat),
      sira: intOrNull(unitForm.sira),
      aktif: true,
    };
    try {
      if (unitForm.editingId) await apiSend(`/api/units/${unitForm.editingId}`, "PATCH", body);
      else await apiSend("/api/units", "POST", body);
      setUnitForm(EMPTY_UNIT);
      refresh();
    } catch (err) {
      const m = err instanceof Error ? err.message : "Kaydedilemedi.";
      setUnitForm((f) => ({
        ...f,
        saving: false,
        err: /zaten kayitli|conflict|no /i.test(m) ? "Bu daire no zaten kayıtlı." : m,
      }));
    }
  }

  async function removeUnit(u: Unit) {
    if (!window.confirm(`${u.no} silinsin mi?`)) return;
    try {
      await apiSend(`/api/units/${u.id}`, "DELETE");
      refresh();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  function openNewBlock() {
    setBlockForm({ ...EMPTY_BLOCK, open: true });
  }
  function openEditBlock(b: Block) {
    setBlockForm({
      open: true, editingId: b.id, ad: b.ad,
      err: null, saving: false,
    });
  }
  function openNewUnit(blok: string | null, kat?: number) {
    // Sira onerisi: bu blok+kattaki en yuksek sira + 1.
    const bucket = blok ? unitItems.filter((u) => u.blok === blok) : blocklessUnits;
    const onKat = bucket.filter((u) => (u.kat ?? null) === (kat ?? null));
    const maxSira = onKat.reduce((m, u) => Math.max(m, u.sira ?? 0), 0);
    setUnitForm({
      ...EMPTY_UNIT, open: true, blok,
      kat: kat != null ? String(kat) : "",
      sira: String(maxSira + 1),
    });
  }
  function openEditUnit(u: Unit) {
    setUnitForm({
      open: true, editingId: u.id, blok: u.blok ?? null, no: u.no,
      kat: u.kat != null ? String(u.kat) : "",
      sira: u.sira != null ? String(u.sira) : "",
      err: null, saving: false,
    });
  }

  function addFloor() {
    const bucket = isBlockless
      ? blocklessUnits
      : unitItems.filter((u) => u.blok === openBlock);
    const kats = new Set<number>(pendingFloors);
    for (const u of bucket) if (u.kat != null) kats.add(u.kat);
    const next = kats.size ? Math.max(...kats) + 1 : 1;
    setPendingFloors((p) => [...new Set([...p, next])]);
  }

  const loadError = blocks.error || units.error;

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Bina Düzenleme</h1>
          <p className="text-sm text-muted">
            Blok, kat ve daireleri görsel olarak oluşturun. Şikayet Haritası bu yapıyı yansıtır.
          </p>
        </div>
        {drilledIn ? (
          <button className={btnGhost} onClick={closeDetail}>← Bloklara dön</button>
        ) : null}
      </div>

      <div className="rounded-lg border border-slate-200 bg-slate-50 px-4 py-2 text-xs text-slate-600">
        Bu düzenleyici panelde yalnızca platform adminine açıktır; site yöneticileri (yönetici)
        aynı düzenlemeyi mobil <span className="font-medium">Bina Düzenleme</span> ekranından yapar.
        Yetki backend’de admin+yönetici olarak tanımlıdır.
      </div>

      {loadError && <ErrorBox message="Veriler yüklenemedi." />}

      {/* Blok ekle/duzenle formu */}
      {blockForm.open && (
        <form onSubmit={saveBlock} className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="font-medium">{blockForm.editingId ? "Blok düzenle" : "Yeni blok"}</h2>
          <div className="grid grid-cols-1 gap-4 sm:max-w-xs">
            <Field label="Blok etiketi" hint="Kısa alfanumerik (örn. A, B1) — tire yok">
              <input
                className={inputCls}
                value={blockForm.ad}
                onChange={(e) => setBlockForm({ ...blockForm, ad: e.target.value })}
                pattern="[A-Za-z0-9]+"
                maxLength={8}
                title="Yalnızca harf ve sayı (örn. A, B1)"
                placeholder="A"
                required
              />
            </Field>
          </div>
          <ErrorBox message={blockForm.err} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={blockForm.saving}>
              {blockForm.saving ? "Kaydediliyor..." : "Kaydet"}
            </button>
            <button type="button" className={btnGhost} onClick={() => setBlockForm(EMPTY_BLOCK)}>
              İptal
            </button>
          </div>
        </form>
      )}

      {/* Daire ekle/duzenle formu */}
      {unitForm.open && (
        <form onSubmit={saveUnit} className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="font-medium">
            {unitForm.editingId ? "Daire düzenle" : "Yeni daire"}
            <span className="ml-2 text-sm text-muted">
              {unitForm.blok ? `· Blok ${unitForm.blok}` : "· Bloksuz"}
            </span>
          </h2>
          <div className="grid grid-cols-3 gap-4">
            <Field label="Daire no" hint="Alfanumerik + tire (örn. A-12, B3, 12)">
              <input
                className={inputCls}
                value={unitForm.no}
                onChange={(e) => setUnitForm({ ...unitForm, no: e.target.value })}
                pattern="[A-Za-z0-9-]+"
                maxLength={50}
                title="Yalnızca harf, sayı ve tire"
                placeholder="A-12"
                required
              />
            </Field>
            <Field label="Kat" hint="0 = zemin">
              <input
                className={inputCls}
                inputMode="numeric"
                value={unitForm.kat}
                onChange={(e) => setUnitForm({ ...unitForm, kat: e.target.value })}
                placeholder="1"
              />
            </Field>
            <Field label="Sıra" hint="Kattaki konum">
              <input
                className={inputCls}
                inputMode="numeric"
                value={unitForm.sira}
                onChange={(e) => setUnitForm({ ...unitForm, sira: e.target.value })}
                placeholder="1"
              />
            </Field>
          </div>
          <ErrorBox message={unitForm.err} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={unitForm.saving}>
              {unitForm.saving ? "Kaydediliyor..." : "Kaydet"}
            </button>
            <button type="button" className={btnGhost} onClick={() => setUnitForm(EMPTY_UNIT)}>
              İptal
            </button>
          </div>
        </form>
      )}

      {/* Icerik: kutucuk listesi veya blok detayi */}
      {drilledIn ? (
        <BlockDetail
          label={isBlockless ? BLOCKLESS : (openBlock as string)}
          units={isBlockless ? blocklessUnits : unitItems.filter((u) => u.blok === openBlock)}
          pendingFloors={pendingFloors}
          onAddFloor={addFloor}
          onAddUnit={(kat) => openNewUnit(isBlockless ? null : (openBlock as string), kat)}
          onEditUnit={openEditUnit}
          onRemoveUnit={removeUnit}
        />
      ) : (
        <BlockTiles
          labels={labels}
          unitCountFor={(l) => unitItems.filter((u) => u.blok === l).length}
          registeredFor={(l) => blockByLabel(l) != null}
          blocklessCount={blocklessUnits.length}
          onOpen={openTile}
          onOpenBlockless={() => openTile(BLOCKLESS)}
          onEditBlock={(l) => { const b = blockByLabel(l); if (b) openEditBlock(b); }}
          onRemoveBlock={(l) => { const b = blockByLabel(l); if (b) removeBlock(b); }}
          onAddBlock={openNewBlock}
        />
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------

function BlockTiles({
  labels, unitCountFor, registeredFor, blocklessCount,
  onOpen, onOpenBlockless, onEditBlock, onRemoveBlock, onAddBlock,
}: {
  labels: string[];
  unitCountFor: (label: string) => number;
  registeredFor: (label: string) => boolean;
  blocklessCount: number;
  onOpen: (label: string) => void;
  onOpenBlockless: () => void;
  onEditBlock: (label: string) => void;
  onRemoveBlock: (label: string) => void;
  onAddBlock: () => void;
}) {
  return (
    <div className="flex flex-wrap gap-3">
      {labels.map((label) => (
        <div
          key={label}
          className="relative flex h-32 w-40 flex-col rounded-xl border border-indigo-200 bg-indigo-50 p-3"
        >
          <button className="flex flex-1 flex-col items-center justify-center" onClick={() => onOpen(label)}>
            <span className="text-lg font-semibold text-indigo-900">Blok {label}</span>
            <span className="text-xs text-slate-500">{unitCountFor(label)} daire</span>
            {!registeredFor(label) && (
              <span className="mt-1 text-[10px] text-amber-600">kayıtsız (yalnızca dairede)</span>
            )}
          </button>
          {registeredFor(label) && (
            <div className="flex justify-center gap-2">
              <button className="text-xs text-slate-500 hover:underline" onClick={() => onEditBlock(label)}>
                Düzenle
              </button>
              <button className="text-xs text-red-600 hover:underline" onClick={() => onRemoveBlock(label)}>
                Sil
              </button>
            </div>
          )}
        </div>
      ))}

      {/* Bloksuz kova: bloksuz daire varken VEYA hic blok yokken erisilebilir
          (mod anahtari olmadan bloksuz siteler de buradan daire ekleyebilsin). */}
      {(blocklessCount > 0 || labels.length === 0) && (
        <button
          onClick={onOpenBlockless}
          className="flex h-32 w-40 flex-col items-center justify-center rounded-xl border border-slate-200 bg-slate-50"
        >
          <span className="text-lg font-semibold text-slate-700">Bloksuz</span>
          <span className="text-xs text-slate-500">{blocklessCount} daire</span>
        </button>
      )}

      <button
        onClick={onAddBlock}
        className="flex h-32 w-40 flex-col items-center justify-center rounded-xl border border-dashed border-slate-300 bg-white text-slate-500 hover:bg-slate-50"
      >
        <span className="text-3xl leading-none">+</span>
        <span className="text-sm">Blok ekle</span>
      </button>
    </div>
  );
}

function BlockDetail({
  label, units, pendingFloors, onAddFloor, onAddUnit, onEditUnit, onRemoveUnit,
}: {
  label: string;
  units: Unit[];
  pendingFloors: number[];
  onAddFloor: () => void;
  onAddUnit: (kat?: number) => void;
  onEditUnit: (u: Unit) => void;
  onRemoveUnit: (u: Unit) => void;
}) {
  const blockless = label === BLOCKLESS;

  const floorSet = new Set<number>(pendingFloors);
  for (const u of units) if (u.kat != null) floorSet.add(u.kat);
  const floors = [...floorSet].sort((a, b) => b - a); // ust kat yukarida
  const katsiz = units.filter((u) => u.kat == null);

  const bySira = (a: Unit, b: Unit) => (a.sira ?? 1e9) - (b.sira ?? 1e9) || a.no.localeCompare(b.no);

  return (
    <div className="space-y-3 rounded-xl border border-slate-200 bg-white p-5">
      <div className="flex items-center justify-between">
        <h2 className="font-medium">{blockless ? "Bloksuz daireler" : `Blok ${label}`}</h2>
        {/* Ust "+ Daire" kaldirildi: her katin kendi "+" dugmesi daire ekler. */}
        <button className={btnGhost} onClick={onAddFloor}>+ Kat</button>
      </div>

      {floors.length === 0 && katsiz.length === 0 && (
        <p className="py-6 text-center text-sm text-muted">
          Henüz kat yok. “+ Kat” ile başlayın, sonra kattaki “+” ile daire ekleyin.
        </p>
      )}

      {floors.map((kat) => (
        <FloorRow
          key={kat}
          katLabel={`Kat ${kat}`}
          units={units.filter((u) => u.kat === kat).sort(bySira)}
          onAddUnit={() => onAddUnit(kat)}
          onEditUnit={onEditUnit}
          onRemoveUnit={onRemoveUnit}
        />
      ))}

      {katsiz.length > 0 && (
        <FloorRow
          katLabel="Kat yok"
          units={[...katsiz].sort(bySira)}
          onAddUnit={() => onAddUnit()}
          onEditUnit={onEditUnit}
          onRemoveUnit={onRemoveUnit}
        />
      )}
    </div>
  );
}

function FloorRow({
  katLabel, units, onAddUnit, onEditUnit, onRemoveUnit,
}: {
  katLabel: string;
  units: Unit[];
  onAddUnit: () => void;
  onEditUnit: (u: Unit) => void;
  onRemoveUnit: (u: Unit) => void;
}) {
  return (
    <div className="flex items-start gap-3 border-t border-slate-100 pt-3">
      <span className="w-16 shrink-0 pt-3 text-xs font-medium text-slate-500">{katLabel}</span>
      <div className="flex flex-wrap gap-2">
        {units.map((u) => (
          <div
            key={u.id}
            className={`group relative flex h-16 w-20 flex-col items-center justify-center rounded-lg border text-white ${
              u.aktif ? "border-indigo-600 bg-indigo-500" : "border-slate-400 bg-slate-400"
            }`}
          >
            <span className="text-sm font-semibold">{u.no}</span>
            {u.sira != null && <span className="text-[10px] opacity-90">#{u.sira}</span>}
            <div className="absolute inset-x-0 bottom-0 hidden justify-center gap-2 rounded-b-lg bg-black/40 py-0.5 text-[10px] group-hover:flex">
              <button className="hover:underline" onClick={() => onEditUnit(u)}>düzenle</button>
              <button className="hover:underline" onClick={() => onRemoveUnit(u)}>sil</button>
            </div>
          </div>
        ))}
        <button
          onClick={onAddUnit}
          className="flex h-16 w-20 items-center justify-center rounded-lg border border-dashed border-slate-300 bg-slate-50 text-2xl text-slate-400 hover:bg-slate-100"
        >
          +
        </button>
      </div>
    </div>
  );
}
