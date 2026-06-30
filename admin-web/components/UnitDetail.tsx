"use client";

import { useState } from "react";
import useSWR from "swr";

import { ErrorBox, Field, btnDanger, btnGhost, btnPrimary, inputCls } from "@/components/form";
import { apiSend, genIdempotencyKey } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { kurusToTL, tlToKurus } from "@/lib/money";
import type {
  DuesYontem,
  ResidentRol,
  Unit,
  UnitDuesStatus,
  UnitResident,
  UserListResponse,
} from "@/lib/types";

// Manuel tahsilat: elden/havale/diger. (kart = provider/webhook akisi, panelde manuel odak.)
const YONTEM: { value: DuesYontem; label: string }[] = [
  { value: "elden", label: "Elden" },
  { value: "havale", label: "Havale" },
  { value: "diger", label: "Diger" },
];
const ROL: { value: ResidentRol; label: string }[] = [
  { value: "malik", label: "Malik" },
  { value: "kiraci", label: "Kiraci" },
];

export function UnitDetail({ unit }: { unit: Unit }) {
  const { data: dues, mutate: mutateDues } = useSWR<UnitDuesStatus>(
    `/api/units/${unit.id}/dues`,
    jsonFetcher,
  );
  const { data: residents, mutate: mutateRes } = useSWR<UnitResident[]>(
    `/api/units/${unit.id}/residents`,
    jsonFetcher,
  );
  // Sakin picker: resident rolundeki kullanicilar (GET /users?role=resident).
  const { data: residentUsers } = useSWR<UserListResponse>(
    "/api/users?role=resident&is_active=true&limit=200&offset=0",
    jsonFetcher,
  );

  // --- tahakkuk ekle ---
  const [aDonem, setADonem] = useState("");
  const [aTl, setATl] = useState("");
  const [aSon, setASon] = useState("");
  const [aDesc, setADesc] = useState("");
  const [aErr, setAErr] = useState<string | null>(null);
  const [aOk, setAOk] = useState<string | null>(null);
  const [aBusy, setABusy] = useState(false);

  async function addAssessment(e: React.FormEvent) {
    e.preventDefault();
    setAErr(null);
    setAOk(null);
    const k = tlToKurus(aTl);
    if (k === null || k <= 0) {
      setAErr("Gecerli bir tutar girin (sifirdan buyuk).");
      return;
    }
    setABusy(true);
    try {
      await apiSend("/api/dues/assessments", "POST", {
        unit_id: unit.id,
        donem: aDonem,
        tutar_kurus: k,
        son_odeme_tarihi: aSon || null,
        aciklama: aDesc || null,
      });
      setADonem("");
      setATl("");
      setASon("");
      setADesc("");
      setAOk("Tahakkuk eklendi.");
      mutateDues();
    } catch (err) {
      const m = err instanceof Error ? err.message : "Hata";
      setAErr(
        /zaten var|conflict|donem/i.test(m)
          ? "Bu daireye bu donem icin zaten tahakkuk var."
          : m,
      );
    } finally {
      setABusy(false);
    }
  }

  // --- tahsilat (odeme) ---
  const [pOpen, setPOpen] = useState(false);
  const [pKey, setPKey] = useState("");
  const [pTl, setPTl] = useState("");
  const [pYontem, setPYontem] = useState<DuesYontem>("elden");
  const [pMakbuz, setPMakbuz] = useState("");
  const [pAssessment, setPAssessment] = useState("");
  const [pErr, setPErr] = useState<string | null>(null);
  const [pBusy, setPBusy] = useState(false);

  function openPay() {
    setPOpen(true);
    setPKey(genIdempotencyKey()); // ayni odeme intentinin tekrarinda sabit -> cift kayit yok
    setPTl("");
    setPYontem("elden");
    setPMakbuz("");
    setPAssessment("");
    setPErr(null);
  }

  async function pay(e: React.FormEvent) {
    e.preventDefault();
    setPErr(null);
    const k = tlToKurus(pTl);
    if (k === null || k <= 0) {
      setPErr("Gecerli bir tutar girin (sifirdan buyuk).");
      return;
    }
    setPBusy(true);
    try {
      await apiSend(
        "/api/dues/payments",
        "POST",
        {
          unit_id: unit.id,
          tutar_kurus: k,
          yontem: pYontem,
          makbuz_no: pMakbuz || null,
          assessment_id: pAssessment || null,
        },
        { "Idempotency-Key": pKey },
      );
      setPOpen(false);
      mutateDues();
    } catch (err) {
      setPErr(err instanceof Error ? err.message : "Odeme kaydedilemedi.");
    } finally {
      setPBusy(false);
    }
  }

  // --- sakin ekle/cikar ---
  const [rUser, setRUser] = useState("");
  const [rRol, setRRol] = useState<ResidentRol | "">("");
  const [rErr, setRErr] = useState<string | null>(null);
  const [rBusy, setRBusy] = useState(false);

  async function addResident(e: React.FormEvent) {
    e.preventDefault();
    setRErr(null);
    setRBusy(true);
    try {
      await apiSend(`/api/units/${unit.id}/residents`, "POST", {
        user_id: rUser.trim(),
        rol_tipi: rRol || null,
      });
      setRUser("");
      setRRol("");
      mutateRes();
    } catch (err) {
      setRErr(err instanceof Error ? err.message : "Eklenemedi.");
    } finally {
      setRBusy(false);
    }
  }

  async function removeResident(userId: string) {
    if (!window.confirm("Sakin daireden cikarilsin mi?")) return;
    try {
      await apiSend(`/api/units/${unit.id}/residents/${userId}`, "DELETE");
      mutateRes();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Hata");
    }
  }

  const bakiye = dues?.bakiye_kurus ?? 0;
  const aktifSakinler = (residents ?? []).filter((r) => !r.bitis);
  const atanmisIds = new Set(aktifSakinler.map((r) => r.user_id));
  const residentChoices = (residentUsers?.items ?? []).filter((u) => !atanmisIds.has(u.id));

  return (
    <div className="space-y-5 rounded-xl border border-slate-300 bg-white p-5">
      <h2 className="text-lg font-medium">Daire {unit.no} — borc durumu</h2>

      {/* Bakiye ozeti */}
      <div className="grid grid-cols-3 gap-3">
        <div className="rounded-lg bg-slate-50 p-3">
          <div className="text-xs text-muted">Toplam tahakkuk</div>
          <div className="text-lg font-semibold">
            {kurusToTL(dues?.toplam_tahakkuk_kurus ?? 0)}
          </div>
        </div>
        <div className="rounded-lg bg-slate-50 p-3">
          <div className="text-xs text-muted">Odenen</div>
          <div className="text-lg font-semibold">{kurusToTL(dues?.toplam_odenen_kurus ?? 0)}</div>
        </div>
        <div className={`rounded-lg p-3 ${bakiye > 0 ? "bg-red-50" : "bg-emerald-50"}`}>
          <div className="text-xs text-muted">Bakiye (borc)</div>
          <div className={`text-lg font-semibold ${bakiye > 0 ? "text-red-700" : "text-emerald-700"}`}>
            {kurusToTL(bakiye)}
          </div>
        </div>
      </div>

      <div className="flex gap-2">
        <button className={btnPrimary} onClick={openPay}>
          Tahsilat kaydet
        </button>
      </div>

      {pOpen && (
        <form onSubmit={pay} className="space-y-3 rounded-lg border border-slate-200 p-4">
          <h3 className="font-medium">Manuel tahsilat</h3>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Tutar (TL)" hint="Ornek: 250 veya 250,50 — kismi odeme olabilir">
              <input
                className={inputCls}
                inputMode="decimal"
                value={pTl}
                onChange={(e) => setPTl(e.target.value)}
                placeholder="250,00"
                required
              />
            </Field>
            <Field label="Yontem">
              <select
                className={inputCls}
                value={pYontem}
                onChange={(e) => setPYontem(e.target.value as DuesYontem)}
              >
                {YONTEM.map((o) => (
                  <option key={o.value} value={o.value}>
                    {o.label}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Makbuz no (opsiyonel)">
              <input
                className={inputCls}
                value={pMakbuz}
                onChange={(e) => setPMakbuz(e.target.value)}
              />
            </Field>
            <Field label="Tahakkuk (opsiyonel)">
              <select
                className={inputCls}
                value={pAssessment}
                onChange={(e) => setPAssessment(e.target.value)}
              >
                <option value="">— serbest —</option>
                {(dues?.assessments ?? []).map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.donem} · {kurusToTL(a.tutar_kurus)}
                  </option>
                ))}
              </select>
            </Field>
          </div>
          <ErrorBox message={pErr} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={pBusy}>
              {pBusy ? "Kaydediliyor..." : "Tahsil et"}
            </button>
            <button type="button" className={btnGhost} onClick={() => setPOpen(false)}>
              Iptal
            </button>
          </div>
        </form>
      )}

      {/* Tahakkuk + odeme listeleri */}
      <div className="grid gap-4 md:grid-cols-2">
        <div>
          <h3 className="mb-2 font-medium">Tahakkuklar</h3>
          <ul className="space-y-1 text-sm">
            {(dues?.assessments ?? []).map((a) => (
              <li key={a.id} className="flex justify-between rounded border border-slate-100 px-2 py-1">
                <span>
                  {a.donem}
                  {a.aciklama ? ` · ${a.aciklama}` : ""}
                </span>
                <span className="font-medium">{kurusToTL(a.tutar_kurus)}</span>
              </li>
            ))}
            {dues && dues.assessments?.length === 0 && (
              <li className="text-muted">Tahakkuk yok.</li>
            )}
          </ul>
        </div>
        <div>
          <h3 className="mb-2 font-medium">Odemeler</h3>
          <ul className="space-y-1 text-sm">
            {(dues?.payments ?? []).map((p) => (
              <li key={p.id} className="flex justify-between rounded border border-slate-100 px-2 py-1">
                <span>
                  {p.yontem} · {p.durum}
                </span>
                <span className="font-medium">{kurusToTL(p.tutar_kurus)}</span>
              </li>
            ))}
            {dues && dues.payments?.length === 0 && <li className="text-muted">Odeme yok.</li>}
          </ul>
        </div>
      </div>

      {/* Tek daire tahakkuk ekle */}
      <form onSubmit={addAssessment} className="space-y-3 rounded-lg border border-slate-200 p-4">
        <h3 className="font-medium">Tahakkuk ekle (bu daire)</h3>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Donem" hint="Ornek: 2026-07">
            <input
              className={inputCls}
              value={aDonem}
              onChange={(e) => setADonem(e.target.value)}
              placeholder="2026-07"
              required
            />
          </Field>
          <Field label="Tutar (TL)">
            <input
              className={inputCls}
              inputMode="decimal"
              value={aTl}
              onChange={(e) => setATl(e.target.value)}
              placeholder="750,00"
              required
            />
          </Field>
          <Field label="Son odeme tarihi (opsiyonel)">
            <input
              type="date"
              className={inputCls}
              value={aSon}
              onChange={(e) => setASon(e.target.value)}
            />
          </Field>
          <Field label="Aciklama (opsiyonel)">
            <input className={inputCls} value={aDesc} onChange={(e) => setADesc(e.target.value)} />
          </Field>
        </div>
        <ErrorBox message={aErr} />
        {aOk && <p className="text-sm text-emerald-700">{aOk}</p>}
        <button type="submit" className={btnPrimary} disabled={aBusy}>
          {aBusy ? "Ekleniyor..." : "Tahakkuk ekle"}
        </button>
      </form>

      {/* Sakinler */}
      <div className="space-y-3 rounded-lg border border-slate-200 p-4">
        <h3 className="font-medium">Sakinler</h3>
        <ul className="space-y-1 text-sm">
          {aktifSakinler.map((r) => (
            <li key={r.id} className="flex items-center justify-between rounded border border-slate-100 px-2 py-1">
              <span className="font-mono">
                {r.user_id.slice(0, 8)} · {r.rol_tipi ?? "—"}
              </span>
              <button className={btnDanger} onClick={() => removeResident(r.user_id)}>
                Cikar
              </button>
            </li>
          ))}
          {residents && aktifSakinler.length === 0 && (
            <li className="text-muted">Aktif sakin yok.</li>
          )}
        </ul>
        <form onSubmit={addResident} className="flex items-end gap-2">
          <div className="grow">
            <Field label="Sakin ekle" hint="Kullanicilar ekranindan eklenen resident hesaplari">
              <select
                className={inputCls}
                value={rUser}
                onChange={(e) => setRUser(e.target.value)}
                required
              >
                <option value="">— sakin sec —</option>
                {residentChoices.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.ad} ({u.email})
                  </option>
                ))}
              </select>
            </Field>
          </div>
          <div className="w-40">
            <Field label="Rol">
              <select
                className={inputCls}
                value={rRol}
                onChange={(e) => setRRol(e.target.value as ResidentRol | "")}
              >
                <option value="">— sec —</option>
                {ROL.map((o) => (
                  <option key={o.value} value={o.value}>
                    {o.label}
                  </option>
                ))}
              </select>
            </Field>
          </div>
          <button type="submit" className={btnGhost} disabled={rBusy}>
            Ekle
          </button>
        </form>
        <ErrorBox message={rErr} />
      </div>
    </div>
  );
}
