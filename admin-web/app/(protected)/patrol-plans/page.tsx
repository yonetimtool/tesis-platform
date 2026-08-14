"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { EksikVeriUyarisi } from "@/components/form";
import {
  Alan,
  AlanSarmal,
  Cekmece,
  Dugme,
  HataDurumu,
  Modal,
  Rozet,
  Secim,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
} from "@/components/ui";
import { RotaSahnesiYukleyici } from "@/components/3d/sahne-yukleyici";
import { useToast } from "@/components/Toast";
import { kisaKimlik } from "@/lib/kimlik";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { tamsayiCoz } from "@/lib/sayi";
import { useT } from "@/lib/i18n/kullan";
import { alarmHaritasi, noktaDurumu } from "@/lib/rota-durumu";
import type {
  AlarmGrubu,
  CheckpointList,
  DashboardLive,
  OkutmaRaporu,
  PatrolPlan,
  PatrolPlanCheckpoint,
  PatrolPlanList,
  ShiftList,
} from "@/lib/types";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DURUM_OLUMLU = "olumlu" as const;
const DURUM_NOTR = "notr" as const;
const DURUM_BEKLIYOR = "bekliyor" as const;
// UCLUDE DIZE YAZILMAZ — bunlar UC ADRESI, cevrilecek metin degil; kural
// yine de gecerli ve adresler modul duzeyinde duruyor.
const UC_OKUTMALAR = "/api/scans" as const;
const UC_PANO = "/api/dashboard/live" as const;

/** Nokta durumu -> rozet rengi. Sahnedeki renklerle AYNI aile. */
const ROZET_DURUMU = {
  okutuldu: "olumlu",
  gecikti: "uyari",
  atlandi: "kritik",
  bekliyor: "notr",
} as const;

/** Nokta durumu -> sozluk anahtari. */
const DURUM_ANAHTARI = {
  okutuldu: "rotaDurumOkutuldu",
  gecikti: "rotaDurumGecikti",
  atlandi: "rotaDurumAtlandi",
  bekliyor: "rotaDurumBekliyor",
} as const;

interface FormState {
  ad: string;
  shift_id: string;
  baslangic_saat: string;
  bitis_saat: string;
  periyot_dakika: string;
  aktif: boolean;
}
const EMPTY: FormState = {
  ad: "",
  shift_id: "",
  baslangic_saat: "00:00",
  bitis_saat: "06:00",
  periyot_dakika: "60",
  aktif: true,
};

function windowCount(bas: string, bit: string, per: number): number {
  if (!per || per <= 0) return 0;
  const [bh, bm] = bas.split(":").map(Number);
  const [eh, em] = bit.split(":").map(Number);
  let span = eh * 60 + em - (bh * 60 + bm);
  if (span <= 0) span += 1440; // gece sarkmasi
  return Math.floor(span / per);
}

export default function PatrolPlansPage() {
  const t = useT();
  const toast = useToast();
  // (P160) SAYFALAMA `VeriTablosu` durumuna gecti; `offset` ondan
  // TURETILIR ve sayfa basina kayit secimi bedava geldi.
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 25,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;
  const { data, error, isLoading, mutate } = useSWR<PatrolPlanList>(
    `/api/patrol-plans?limit=${tabloDurumu.boy}&offset=${offset}`,
    jsonFetcher,
  );
  const { data: shifts, error: shiftsErr } = useSWR<ShiftList>(
    "/api/shifts?limit=200&offset=0",
    jsonFetcher,
  );
  // `assignPlan` SWR ANAHTARLARINDA kullanildigi icin BURADA tanimli:
  // asagida kalsaydi "kullanimdan once tanimlanmis olmali" hatasi verirdi.
  const [assignPlan, setAssignPlan] = useState<PatrolPlan | null>(null);
  const { data: checkpoints } = useSWR<CheckpointList>(
    "/api/checkpoints?limit=200&offset=0",
    jsonFetcher,
  );
  // (P160 / Asama 5) ROTA SAHNESININ IKI GERCEK KAYNAGI. Ikisi de
  // CEKMECE ACIKKEN cekilir (`assignPlan` yoksa anahtar `null`):
  // sayfaya girer girmez iki ek istek atmak, sahneyi hic acmayacak
  // kullaniciya bedel odetirdi.
  const { data: okutmalar } = useSWR<OkutmaRaporu>(
    assignPlan ? UC_OKUTMALAR : null,
    jsonFetcher,
  );
  const { data: pano } = useSWR<DashboardLive>(
    assignPlan ? UC_PANO : null,
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // atama
  const [selected, setSelected] = useState<string[]>([]);
  const [assignErr, setAssignErr] = useState<string | null>(null);
  // MEVCUT ATAMA CEKILEBILDI MI — asagida neden onemli oldugu yaziyor.
  const [assignOkundu, setAssignOkundu] = useState(false);
  const [assignSaving, setAssignSaving] = useState(false);
  const [addPick, setAddPick] = useState<string>("");

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(p: PatrolPlan) {
    setEditingId(p.id);
    setForm({
      ad: p.ad,
      shift_id: p.shift_id ?? "",
      baslangic_saat: p.baslangic_saat,
      bitis_saat: p.bitis_saat,
      periyot_dakika: String(p.periyot_dakika),
      aktif: p.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    // (P56) `Number(...)` NaN uretebiliyordu ve JSON'da **null** olurdu:
    // sunucuya periyotsuz bir plan gidiyordu.
    const per = tamsayiCoz(form.periyot_dakika);
    if (per.tur !== "sayi") {
      setFormErr(t("planPeriyotGecersiz"));
      setSaving(false);
      return;
    }
    const body = {
      ad: form.ad,
      shift_id: form.shift_id || null,
      baslangic_saat: form.baslangic_saat,
      bitis_saat: form.bitis_saat,
      periyot_dakika: per.deger,
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/patrol-plans/${editingId}`, "PATCH", body);
      else await apiSend("/api/patrol-plans", "POST", body);
      setOpen(false);
      mutate();
      toast.success(editingId ? t("planGuncellendi") : t("planOlusturuldu"));
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : t("ortakKaydedilemedi"));
    } finally {
      setSaving(false);
    }
  }

  async function remove(p: PatrolPlan) {
    if (!window.confirm(t("ortakSilOnay", { ad: p.ad }))) return;
    try {
      await apiSend(`/api/patrol-plans/${p.id}`, "DELETE");
      mutate();
      toast.success(t("planSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  async function openAssign(p: PatrolPlan) {
    setAssignPlan(p);
    setAssignErr(null);
    setAssignOkundu(false);
    setAddPick("");
    setSelected([]);
    try {
      const list = await apiSend<PatrolPlanCheckpoint[]>(
        `/api/patrol-plans/${p.id}/checkpoints`,
        "GET",
      );
      const ordered = [...list].sort((a, b) => a.sira - b.sira).map((x) => x.checkpoint_id);
      setSelected(ordered);
      setAssignOkundu(true);
    } catch (err) {
      // (P160) KUSUR DUZELTILDI — sessiz `catch { setSelected([]) }`.
      // Mevcut atama CEKILEMEDIGINDE liste BOS aciliyordu; ekranda hicbir
      // uyari yoktu. Kaydet'e basan kullanici planin butun noktalarini
      // SILIYORDU (`PUT` tam listeyi degistirir) ve devriye o gece bos
      // kaliyordu. Artik sebep gorunuyor ve `assignOkundu` false oldugu
      // surece KAYDETMEK KAPALI: bilmedigimiz bir listeyi ezemeyiz.
      setAssignErr(err instanceof Error ? err.message : t("ortakVeriYuklenemedi"));
    }
  }

  async function saveAssign() {
    if (!assignPlan || !assignOkundu) return;
    setAssignSaving(true);
    setAssignErr(null);
    try {
      await apiSend(`/api/patrol-plans/${assignPlan.id}/checkpoints`, "PUT", {
        items: selected.map((cid, i) => ({ checkpoint_id: cid, sira: i })),
      });
      setAssignPlan(null);
      toast.success(t("atamaKaydedildi"));
    } catch (err) {
      setAssignErr(err instanceof Error ? err.message : t("ortakKaydedilemedi"));
    } finally {
      setAssignSaving(false);
    }
  }

  // (P160 / Asama 5) SAHNENIN NOKTALARI. Durum kurali `lib/rota-durumu`
  // dosyasinda TEK YERDE tanimli — ayni kural `/checkpoints`te de
  // kullaniliyor ve iki kopya tutmak birinin unutulmasi demekti.
  const okutulanIdler = useMemo(
    () => new Set((okutmalar?.items ?? []).map((o) => o.checkpoint_id)),
    [okutmalar],
  );
  const alarmlar = useMemo(
    () => alarmHaritasi((pano?.alarm_gruplari ?? []) as AlarmGrubu[]),
    [pano],
  );
  const rotaNoktalari = useMemo(
    () =>
      selected.map((cid, i) => ({
        id: cid,
        ad: cpName(cid),
        sira: i,
        durum: noktaDurumu(cid, { okutulanIdler, alarmGruplari: [] }, alarmlar),
      })),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [selected, okutulanIdler, alarmlar, checkpoints],
  );

  function cpName(id: string): string {
    return checkpoints?.items.find((c) => c.id === id)?.ad ?? kisaKimlik(id);
  }
  function shiftName(id?: string | null): string {
    if (!id) return "—";
    return shifts?.items.find((s) => s.id === id)?.ad ?? kisaKimlik(id);
  }
  function move(i: number, dir: -1 | 1) {
    const j = i + dir;
    if (j < 0 || j >= selected.length) return;
    const next = [...selected];
    [next[i], next[j]] = [next[j], next[i]];
    setSelected(next);
  }

  const available = (checkpoints?.items ?? []).filter((c) => !selected.includes(c.id));
  const previewWindows = windowCount(
    form.baslangic_saat,
    form.bitis_saat,
    Number(form.periyot_dakika),
  );

  const kolonlar: Kolon<PatrolPlan>[] = useMemo(
    () => [
      { id: "ad", baslik: t("ortakAd"), hucre: (p) => p.ad, gizlenebilir: false },
      { id: "vardiya", baslik: t("devriyeVardiya"), hucre: (p) => shiftName(p.shift_id) },
      {
        id: "saat",
        baslik: t("devriyeSaatPeriyot"),
        hucre: (p) =>
          `${p.baslangic_saat}–${p.bitis_saat} · ${t("devriyePeriyotN", {
            n: p.periyot_dakika,
          })}`,
      },
      {
        id: "durum",
        baslik: t("ortakDurum"),
        hucre: (p) => (
          <Rozet durum={p.aktif ? DURUM_OLUMLU : DURUM_NOTR}>
            {p.aktif ? t("ortakAktif") : t("ortakPasif")}
          </Rozet>
        ),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (p) => (
          <div className="flex justify-end gap-2">
            <Dugme boy="kucuk" onClick={() => void openAssign(p)}>
              {t("planNoktalar")}
            </Dugme>
            <Dugme boy="kucuk" onClick={() => openEdit(p)}>
              {t("ortakDuzenle")}
            </Dugme>
            <Dugme boy="kucuk" tur="tehlike" onClick={() => void remove(p)}>
              {t("ortakSil")}
            </Dugme>
          </div>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, shifts],
  );

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kabukDevriyePlanlari")}
        </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
          {t("planYeni")}
        </Dugme>
      </div>

      {/* Vardiya listesi cekilemediyse SECIM EKSIK olur; sessiz kalmak
          "bu planin vardiyasi yok" yanilgisini uretir. */}
      <EksikVeriUyarisi mesaj={shiftsErr ? t("ortakSecenekYuklenemedi") : null} />

      {/* PLAN FORMU — modalda. */}
      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("planDuzenle") : t("planYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="plan-form" yukleniyor={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="plan-form" onSubmit={save} className="space-y-4">
          <AlanSarmal etiket={t("ortakAd")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            )}
          </AlanSarmal>

          <AlanSarmal etiket={t("devriyeVardiyaOpsiyonel")}>
            {(b) => (
              <Secim
                {...b}
                value={form.shift_id}
                onChange={(e) => setForm({ ...form, shift_id: e.target.value })}
              >
                <option value="">{t("ortakSecimYok")}</option>
                {(shifts?.items ?? []).map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.ad}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>

          <div className="grid grid-cols-3 gap-4">
            <AlanSarmal etiket={t("ortakBaslangic")} ipucu={t("ortakSaatBicimi")} zorunlu>
              {(b) => (
                <Alan
                  {...b}
                  type="time"
                  value={form.baslangic_saat}
                  onChange={(e) => setForm({ ...form, baslangic_saat: e.target.value })}
                  required
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("ortakBitis")} ipucu={t("ortakSaatBicimi")} zorunlu>
              {(b) => (
                <Alan
                  {...b}
                  type="time"
                  value={form.bitis_saat}
                  onChange={(e) => setForm({ ...form, bitis_saat: e.target.value })}
                  required
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("devriyePeriyotDk")} zorunlu>
              {(b) => (
                <Alan
                  {...b}
                  type="number"
                  min={1}
                  value={form.periyot_dakika}
                  onChange={(e) => setForm({ ...form, periyot_dakika: e.target.value })}
                  required
                />
              )}
            </AlanSarmal>
          </div>

          {/* Kac tur gezilecegi ONIZLEME: periyot/aralik hatasi ancak
              sayiya donusunce fark ediliyor ("6 saatte 1 tur" gibi). */}
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("planOnizleme", { sayi: previewWindows })}
          </p>

          <label className="flex items-center gap-2" style={{ fontSize: "var(--yz-fs-sm)" }}>
            <input
              type="checkbox"
              checked={form.aktif}
              onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
            />
            {t("ortakAktif")}
          </label>

          {formErr && (
            <p
              role="alert"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
            >
              {formErr}
            </p>
          )}
        </form>
      </Modal>

      {/* NOKTA ATAMA — CEKMECEDE, modalda degil: sirali liste uzun olabilir
          ve kullanici sirayi verirken plan tablosunu yaninda gormeli. */}
      <Cekmece
        acik={assignPlan != null}
        onKapat={() => setAssignPlan(null)}
        baslik={assignPlan ? t("planNoktalariBaslik", { ad: assignPlan.ad }) : ""}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setAssignPlan(null)}>
              {t("ortakKapat")}
            </Dugme>
            <Dugme
              tur="birincil"
              onClick={() => void saveAssign()}
              yukleniyor={assignSaving}
              // MEVCUT LISTE OKUNAMADIYSA KAYDETME KAPALI: `PUT` tam
              // listeyi degistirir, bos kaydetmek atamalari SILERDI.
              disabled={!assignOkundu}
            >
              {assignSaving ? t("ortakKaydediliyor") : t("planAtamayiKaydet")}
            </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("planSiraliListe")}
          </p>

          {/* ROTA SAHNESI — yalniz nokta VARSA. Bos bir egri, olmayan bir
              rotayi cizmek olurdu. */}
          {assignOkundu && rotaNoktalari.length > 0 && (
            <div className="space-y-1">
              <RotaSahnesiYukleyici noktalar={rotaNoktalari} />
              {/* SAHNENIN NE OLMADIGINI YAZAR: konum verisi yok, bu bir
                  harita degil akis semasi. */}
              <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                {t("rotaSahneNot")}
              </p>
            </div>
          )}

          {assignErr && !assignOkundu ? (
            <HataDurumu
              mesaj={assignErr}
              onTekrar={() => assignPlan && void openAssign(assignPlan)}
            />
          ) : (
            <>
              <ol className="space-y-2">
                {selected.map((cid, i) => (
                  <li
                    key={cid}
                    className="yz-raised flex items-center justify-between gap-2 px-3 py-2"
                    style={{
                      borderRadius: "var(--yz-radius-btn)",
                      fontSize: "var(--yz-fs-sm)",
                      color: "var(--yz-text)",
                    }}
                  >
                    <span className="flex items-center gap-2">
                      <span style={{ color: "var(--yz-text-3)" }}>{i + 1}.</span>
                      {cpName(cid)}
                      {/* DURUM METINDIR: sahnedeki renk tek tasiyici
                          olsaydi renk koru kullanici ayrimi kaybederdi. */}
                      <Rozet durum={ROZET_DURUMU[rotaNoktalari[i]?.durum ?? DURUM_BEKLIYOR]}>
                        {t(DURUM_ANAHTARI[rotaNoktalari[i]?.durum ?? DURUM_BEKLIYOR])}
                      </Rozet>
                    </span>
                    <span className="flex gap-1">
                      <Dugme boy="kucuk" onClick={() => move(i, -1)} disabled={i === 0}>
                        {t("ortakYukari")}
                      </Dugme>
                      <Dugme
                        boy="kucuk"
                        onClick={() => move(i, 1)}
                        disabled={i === selected.length - 1}
                      >
                        {t("ortakAsagi")}
                      </Dugme>
                      <Dugme
                        boy="kucuk"
                        tur="tehlike"
                        onClick={() => setSelected(selected.filter((x) => x !== cid))}
                      >
                        {t("kullaniciCikar")}
                      </Dugme>
                    </span>
                  </li>
                ))}
                {selected.length === 0 && (
                  <li
                    className="px-3 py-4 text-center"
                    style={{
                      borderRadius: "var(--yz-radius-btn)",
                      border: "1px dashed var(--yz-border)",
                      fontSize: "var(--yz-fs-sm)",
                      color: "var(--yz-text-2)",
                    }}
                  >
                    {t("planNoktaYok")}
                  </li>
                )}
              </ol>

              <div className="flex items-end gap-2">
                <div className="grow">
                  <AlanSarmal etiket={t("devriyeNoktaEkle")}>
                    {(b) => (
                      <Secim
                        {...b}
                        value={addPick}
                        onChange={(e) => setAddPick(e.target.value)}
                      >
                        <option value="">{t("planSec")}</option>
                        {available.map((c) => (
                          <option key={c.id} value={c.id}>
                            {c.ad} ({c.nfc_tag_uid})
                          </option>
                        ))}
                      </Secim>
                    )}
                  </AlanSarmal>
                </div>
                <Dugme
                  disabled={!addPick}
                  onClick={() => {
                    if (addPick) setSelected([...selected, addPick]);
                    setAddPick("");
                  }}
                >
                  {t("ortakEkle")}
                </Dugme>
              </div>

              {assignErr && (
                <p
                  role="alert"
                  style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
                >
                  {assignErr}
                </p>
              )}
            </>
          )}
        </div>
      </Cekmece>

      <VeriTablosu<PatrolPlan>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(p) => p.id}
        hata={error ? error.message : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        bosBaslik={t("devriyePlanYok")}
        bosAciklama={t("planYokAlt")}
        sunucuTarafli
        toplam={data?.meta.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
      />
    </div>
  );
}
