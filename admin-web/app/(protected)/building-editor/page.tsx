"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";
import { daireTipiKisa, daireTipiRengi } from "@/lib/daire-tipi-rengi";

import { Field, ErrorBox, PageHeader, inputCls, btnPrimary, btnGhost, panelCls, cardCls } from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { Block, BlockList, Unit, UnitList } from "@/lib/types";
import { tamsayiCoz } from "@/lib/sayi";
import { useT } from "@/lib/i18n/kullan";

// Bloksuz kova (implicit tek blok) icin sentinel — gercek blok etiketi
// alfanumerik ve >=1 karakter, bu deger asla cakismaz.
const BLOCKLESS = "__bloksuz__";

// (P56) `intOrNull` KALDIRILDI: gecersiz girdi de `null` donuyordu ve
// `null` "alani temizle" demek — kullanici kat/sira degerini yanlis
// yazdiginda alan SESSIZCE siliniyordu. `tamsayiCoz` ucunu ayirir.

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
  const t = useT();
  const toast = useToast();
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
      toast.success(blockForm.editingId ? t("binaBlokGuncellendi") : t("binaBlokOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setBlockForm((f) => ({
        ...f,
        saving: false,
        err: /zaten kayitli|conflict/i.test(m) ? t("binaBlokZatenKayitli") : m,
      }));
    }
  }

  async function removeBlock(b: Block) {
    const count = unitItems.filter((u) => u.blok === b.ad).length;
    let cascade = false;
    if (count === 0) {
      if (!window.confirm(t("binaBlokBasitSilOnay", { blok: b.ad }))) return;
    } else {
      // Yikici: daireleri + bagli kayitlari siler. Sert onay: blok adini yaz.
      const typed = window.prompt(
        t("binaBlokSilOnay", { blok: b.ad, sayi: count }),
      );
      if (typed == null) return; // iptal
      if (typed.trim() !== b.ad) {
        toast.error(t("binaBlokAdEslesmedi"));
        return;
      }
      cascade = true;
    }
    try {
      await apiSend(`/api/blocks/${b.id}${cascade ? "?cascade=true" : ""}`, "DELETE");
      if (openBlock === b.ad) closeDetail();
      refresh();
      toast.success(
        cascade
          ? t("blokVeDaireSilindi", { ad: b.ad, n: count })
          : t("blokSilindi"),
      );
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("blokSilinemedi"));
    }
  }

  // --- unit CRUD -----------------------------------------------------------
  async function saveUnit(e: React.FormEvent) {
    e.preventDefault();
    const kat = tamsayiCoz(unitForm.kat);
    const sira = tamsayiCoz(unitForm.sira);
    if (kat.tur === "gecersiz" || sira.tur === "gecersiz") {
      setUnitForm((f) => ({ ...f, err: t("daireKatSiraGecersiz") }));
      return;
    }
    setUnitForm((f) => ({ ...f, saving: true, err: null }));
    const body = {
      no: unitForm.no.trim(),
      blok: unitForm.blok,
      kat: kat.tur === "sayi" ? kat.deger : null,
      sira: sira.tur === "sayi" ? sira.deger : null,
      aktif: true,
    };
    try {
      if (unitForm.editingId) await apiSend(`/api/units/${unitForm.editingId}`, "PATCH", body);
      else await apiSend("/api/units", "POST", body);
      setUnitForm(EMPTY_UNIT);
      refresh();
      toast.success(unitForm.editingId ? t("daireGuncellendi") : t("daireOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setUnitForm((f) => ({
        ...f,
        saving: false,
        err: /zaten kayitli|conflict|no /i.test(m) ? t("daireNoZatenKayitli") : m,
      }));
    }
  }

  async function removeUnit(u: Unit) {
    if (!window.confirm(t("ortakSilOnay", { ad: u.no }))) return;
    try {
      await apiSend(`/api/units/${u.id}`, "DELETE");
      refresh();
      toast.success(t("daireSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
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
      <PageHeader
        title={t("kabukBinaDuzenleme")}
        subtitle={t("binaAciklama")}
        action={
          drilledIn ? (
            <button className={btnGhost} onClick={closeDetail}>{t("binaBloklaraDon")}</button>
          ) : undefined
        }
      />

      <div className="rounded-lg border kart-kenar bg-yuzey-bg px-4 py-2 text-xs text-metin-body">
        {t("binaYetkiNotu", { ekran: t("kabukBinaDuzenleme") })}
      </div>

      {loadError && <ErrorBox message={t("binaVerilerYuklenemedi")} />}

      {/* YUKLENIYOR: veri gelene kadar ekran BOS gorunuyordu ve kullanici
          "hic blok yok" saniyordu (tur 44 yavas-ag surusu). */}
      {(blocks.isLoading || units.isLoading) && (
        <p role="status" className="text-sm text-metin-muted">
          {t("ortakYukleniyor")}
        </p>
      )}

      {/* Blok ekle/duzenle formu */}
      {blockForm.open && (
        <form onSubmit={saveBlock} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">{blockForm.editingId ? t("binaBlokDuzenle") : t("binaBlokYeni")}</h2>
          <div className="grid grid-cols-1 gap-4 sm:max-w-xs">
            <Field label={t("binaBlokEtiketi")} hint={t("binaBlokIpucu")}>
              <input
                className={inputCls}
                value={blockForm.ad}
                onChange={(e) => setBlockForm({ ...blockForm, ad: e.target.value })}
                pattern="[A-Za-z0-9]+"
                maxLength={8}
                title={t("blokGecersiz")}
                placeholder="A"
                required
              />
            </Field>
          </div>
          <ErrorBox message={blockForm.err} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={blockForm.saving}>
              {blockForm.saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </button>
            <button type="button" className={btnGhost} onClick={() => setBlockForm(EMPTY_BLOCK)}>
              {t("ortakIptal")}
            </button>
          </div>
        </form>
      )}

      {/* Daire ekle/duzenle formu */}
      {unitForm.open && (
        <form onSubmit={saveUnit} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">
            {unitForm.editingId ? t("daireDuzenle") : t("daireYeni")}
            <span className="ml-2 text-sm text-metin-muted">
              {unitForm.blok
                ? t("daireBlokEki", { ad: unitForm.blok })
                : t("daireBloksuzEki")}
            </span>
          </h2>
          <div className="grid grid-cols-3 gap-4">
            <Field label={t("binaDaireNo")} hint={t("binaDaireNoIpucu")}>
              <input
                className={inputCls}
                value={unitForm.no}
                onChange={(e) => setUnitForm({ ...unitForm, no: e.target.value })}
                pattern="[A-Za-z0-9-]+"
                maxLength={50}
                title={t("binaDaireNoGecersiz")}
                placeholder="A-12"
                required
              />
            </Field>
            <Field label={t("binaKat")} hint={t("binaZeminIpucu")}>
              <input
                className={inputCls}
                inputMode="numeric"
                value={unitForm.kat}
                onChange={(e) => setUnitForm({ ...unitForm, kat: e.target.value })}
                placeholder="1"
              />
            </Field>
            <Field label={t("binaSira")} hint={t("binaKattakiKonum")}>
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
              {unitForm.saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </button>
            <button type="button" className={btnGhost} onClick={() => setUnitForm(EMPTY_UNIT)}>
              {t("ortakIptal")}
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
          yuklemeHatasi={Boolean(loadError)}
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
  const t = useT();
  return (
    <div className="flex flex-wrap gap-3">
      {labels.map((label) => (
        <div
          key={label}
          className="relative flex h-32 w-40 flex-col rounded-xl border border-indigo-200 bg-indigo-50 p-3"
        >
          <button className="flex flex-1 flex-col items-center justify-center" onClick={() => onOpen(label)}>
            <span className="text-lg font-semibold text-indigo-900">
              {t("blokEtiketi", { ad: label })}
            </span>
            <span className="text-xs text-metin-body">
              {t("daireSayisiN", { n: unitCountFor(label) })}
            </span>
            {!registeredFor(label) && (
              <span className="mt-1 text-[10px] text-amber-600">{t("binaKayitsiz")}</span>
            )}
          </button>
          {registeredFor(label) && (
            <div className="flex justify-center gap-2">
              <button className="text-xs text-metin-body hover:underline" onClick={() => onEditBlock(label)}>
                {t("ortakDuzenle")}
              </button>
              <button className="text-xs text-red-700 hover:underline" onClick={() => onRemoveBlock(label)}>{t("ortakSil")}</button>
            </div>
          )}
        </div>
      ))}

      {/* t("daireBlokAtanmamis") kova: YALNIZ mevcut bloksuz daireler varken gorunur
          (goruntuleme + tasima/silme icin). Yeni daire buradan EKLENEMEZ —
          her yeni daire bir bloga baglanir (canli-site kurali). */}
      {blocklessCount > 0 && (
        <button
          onClick={onOpenBlockless}
          className="flex h-32 w-40 flex-col items-center justify-center rounded-xl border kart-kenar bg-yuzey-bg"
        >
          <span className="text-lg font-semibold text-metin-body">{t("daireBlokAtanmamis")}</span>
          <span className="text-xs text-metin-body">
            {t("daireSayisiN", { n: blocklessCount })}
          </span>
        </button>
      )}

      <button
        onClick={onAddBlock}
        className="flex h-32 w-40 flex-col items-center justify-center rounded-xl border border-dashed border-slate-300 bg-white text-metin-muted hover:bg-yuzey-bg"
      >
        <span className="text-3xl leading-none">+</span>
        <span className="text-sm">{t("binaBlokEkle")}</span>
      </button>
    </div>
  );
}

function BlockDetail({
  label, units, pendingFloors, yuklemeHatasi,
  onAddFloor, onAddUnit, onEditUnit, onRemoveUnit,
}: {
  label: string;
  units: Unit[];
  /** (P61) Liste `data?.items ?? []`den turer: yukleme dustugunde de BOS
   *  gorunur. Bu bayrak olmadan "Kat yok" iddiasi hatayla CELISIRDI. */
  yuklemeHatasi: boolean;
  pendingFloors: number[];
  onAddFloor: () => void;
  onAddUnit: (kat?: number) => void;
  onEditUnit: (u: Unit) => void;
  onRemoveUnit: (u: Unit) => void;
}) {
  const t = useT();
  const blockless = label === BLOCKLESS;

  const floorSet = new Set<number>(pendingFloors);
  for (const u of units) if (u.kat != null) floorSet.add(u.kat);
  const floors = [...floorSet].sort((a, b) => b - a); // ust kat yukarida
  const katsiz = units.filter((u) => u.kat == null);

  const bySira = (a: Unit, b: Unit) => (a.sira ?? 1e9) - (b.sira ?? 1e9) || a.no.localeCompare(b.no);

  return (
    <div className={`space-y-3 ${cardCls} p-5`}>
      <div className="flex items-center justify-between">
        <h2 className="font-medium">{blockless ? t("binaBloksuzDaireler") : `Blok ${label}`}</h2>
        {/* Bloksuz kovaya yeni daire EKLENMEZ (her daire bir bloga baglanir). */}
        {!blockless && (
          <button className={btnGhost} onClick={onAddFloor}>{t("binaKatEkleKisa")}</button>
        )}
      </div>

      {blockless && (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-700">
          {t("binaBloksuzNot")}
        </p>
      )}

      {/* (P61) `!loadError` SART: kat listesi `data?.items ?? []`den
          turer, yani istek dustugunde de BOS gorunur ve sayfa "Kat yok"
          derdi — hemen ustundeki "Veriler yuklenemedi" kutusuyla
          celiserek. */}
      {!yuklemeHatasi && !blockless && floors.length === 0 && katsiz.length === 0 && (
        <p className="py-6 text-center text-sm text-metin-muted">
          {t("binaKatYok")}
        </p>
      )}

      {floors.map((kat) => (
        <FloorRow
          key={kat}
          katLabel={`Kat ${kat}`}
          units={units.filter((u) => u.kat === kat).sort(bySira)}
          canAdd={!blockless}
          onAddUnit={() => onAddUnit(kat)}
          onEditUnit={onEditUnit}
          onRemoveUnit={onRemoveUnit}
        />
      ))}

      {katsiz.length > 0 && (
        <FloorRow
          katLabel="Kat yok"
          units={[...katsiz].sort(bySira)}
          canAdd={!blockless}
          onAddUnit={() => onAddUnit()}
          onEditUnit={onEditUnit}
          onRemoveUnit={onRemoveUnit}
        />
      )}
    </div>
  );
}

function FloorRow({
  katLabel, units, canAdd, onAddUnit, onEditUnit, onRemoveUnit,
}: {
  katLabel: string;
  units: Unit[];
  canAdd: boolean;
  onAddUnit: () => void;
  onEditUnit: (u: Unit) => void;
  onRemoveUnit: (u: Unit) => void;
}) {
  const t = useT();
  return (
    <div className="flex items-start gap-3 border-t border-yuzey-divider pt-3">
      <span className="w-16 shrink-0 pt-3 text-xs font-medium text-metin-muted">{katLabel}</span>
      <div className="flex flex-wrap gap-2">
        {units.map((u) => (
          <div
            key={u.id}
            // (P122) TIP RENGI YALNIZ AKTIF dairede: pasif daire her tipte
            // ayni soluk grivi tasimali, yoksa "pasif" durumu renk
            // gurultusunde kaybolur.
            style={u.aktif ? { backgroundColor: daireTipiRengi(u.unit_tip_ad) } : undefined}
            // Gorsel kisaltma ekran okuyucuya TAM adi vermeli.
            title={[u.no, u.unit_tip_ad, u.sira != null ? `#${u.sira}` : null]
              .filter(Boolean)
              .join(" · ")}
            className={`group relative flex h-16 w-20 flex-col items-center justify-center rounded-lg border text-white ${
              u.aktif ? "border-black/20" : "border-slate-400 bg-slate-400"
            }`}
          >
            <span className="text-sm font-semibold">{u.no}</span>
            {/* (P122) TIP, SIRADAN ONCELIKLIDIR. Hucre 64 px yuksektir;
                ucuncu bir satir tasar. Tip atanmissa kullanici icin degerli
                olan odur ("12 · 2+1"); sira yalnizca yerlesim ayrintisidir
                ve tip yokken gosterilir. */}
            {/* (Duzeltme) TIP HER ZAMAN GORUNUR: atanmamissa "-".
                Eskiden tip yokken hucre sessizce `#sira` gosteriyordu ve
                kullanici "tip mi yok, sira mi?" diye ayirt edemiyordu.
                Sira bilgisi KAYBOLMADI - ipucuna (title) tasindi. */}
            {u.aktif ? (
              <span
                data-testid="daire-tip-etiketi"
                className="max-w-[72px] truncate text-[10px] font-semibold opacity-95"
              >
                {u.unit_tip_ad ? daireTipiKisa(u.unit_tip_ad) : "—"}
              </span>
            ) : null}
            <div className="absolute inset-x-0 bottom-0 hidden justify-center gap-2 rounded-b-lg bg-black/40 py-0.5 text-[10px] group-hover:flex">
              <button className="hover:underline" onClick={() => onEditUnit(u)}>{t("binaDuzenleKucuk")}</button>
              <button className="hover:underline" onClick={() => onRemoveUnit(u)}>{t("ortakSil")}</button>
            </div>
          </div>
        ))}
        {canAdd && (
          <button
            onClick={onAddUnit}
            className="flex h-16 w-20 items-center justify-center rounded-lg border border-dashed border-slate-300 bg-yuzey-bg text-2xl text-metin-muted hover:bg-slate-100"
          >
            +
          </button>
        )}
      </div>
    </div>
  );
}
