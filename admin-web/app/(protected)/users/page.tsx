"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, btnGhost, panelCls, panelMotion } from "@/components/form";
import { BosSatir, Tablo, TabloBasligi, TabloKart, Td, Th, Tr } from "@/components/tablo";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { ROLE_OPTIONS as ROLES, ROLE_STYLE, rolAdi } from "@/lib/roles";
import type { UserDetail, UserListResponse, UserRole, UserRow } from "@/lib/types";
import { ParolaAlani } from "@/components/ParolaAlani";
import { useT } from "@/lib/i18n/kullan";
import { telefonGiris, telefonNormalle } from "@/lib/telefon";

const LIMIT = 20;

interface FormState {
  ad: string;
  email: string;
  telefon: string;
  aranabilir: boolean;
  role: UserRole;
  password: string;
  // (P128) Gorev penceresi — YALNIZ `denetci` rolunde gosterilir.
  gorevBaslangic: string;
  gorevBitis: string;
}
const EMPTY: FormState = {
  ad: "",
  email: "",
  telefon: "",
  aranabilir: false,
  role: "security",
  password: "",
  gorevBaslangic: "",
  gorevBitis: "",
};

export default function UsersPage() {
  const t = useT();
  const toast = useToast();
  const [offset, setOffset] = useState(0);
  const [role, setRole] = useState<string>("");
  const [aktif, setAktif] = useState<string>("");
  const [q, setQ] = useState("");

  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
  if (role) qs.set("role", role);
  if (aktif) qs.set("is_active", aktif);
  if (q.trim()) qs.set("q", q.trim());
  const { data, error, isLoading, mutate } = useSWR<UserListResponse>(
    `/api/users?${qs.toString()}`,
    jsonFetcher,
  );

  // (P130) ACILIR LISTE SUNUCUDAN. Eskiden `ROLE_OPTIONS`in tamami
  // cizilirdi: bir site yoneticisi "Platform Admin"i SECEBILIYOR ve
  // kaydedince 403 aliyordu — sunucu dogru davraniyordu, arayuz yanlis soz
  // veriyordu. Liste artik cagiranin GERCEKTEN acabildigi kumedir.
  const { data: acilabilir } = useSWR<{ roller: UserRole[] }>(
    "/api/users/acilabilir-roller",
    jsonFetcher,
  );
  // `undefined` = HENUZ BILINMIYOR (bos kumeyle ayni sey degil): liste
  // gelene kadar secenek cizmek, gelince degisen bir form demek olurdu.
  const acilabilirRoller = acilabilir?.roller;
  const formRolleri = acilabilirRoller
    ? ROLES.filter((r) => acilabilirRoller.includes(r.value))
    : [];

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // DUZENLENEN KAYDIN ROLU LISTEDE YOKSA YINE GORUNUR. Aksi halde select
  // sessizce ilk secenege duser ve kaydet, kullanicinin DOKUNMADIGI bir
  // alani degistirmek isterdi (sunucu 403 verirdi ama sebep gorunmezdi).
  const mevcutRol = ROLES.find((r) => r.value === form.role);
  const rolSecenekleri =
    mevcutRol && !formRolleri.some((r) => r.value === form.role)
      ? [mevcutRol, ...formRolleri]
      : formRolleri;

  function resetFilters(next: { role?: string; aktif?: string; q?: string }) {
    if (next.role !== undefined) setRole(next.role);
    if (next.aktif !== undefined) setAktif(next.aktif);
    if (next.q !== undefined) setQ(next.q);
    setOffset(0);
  }

  function openNew() {
    setEditingId(null);
    // Varsayilan rol de acilabilir kumeden secilir; sabit "security"
    // birakmak, o rolu acamayan bir cagirana pesinen gecersiz bir form
    // vermek olurdu.
    setForm({ ...EMPTY, role: formRolleri[0]?.value ?? EMPTY.role });
    setFormErr(null);
    setOpen(true);
  }
  async function openEdit(u: UserRow) {
    setEditingId(u.id);
    // Numara listede DONMEZ (KVKK); tek-kayit detayindan cekilir.
    setForm({
      ad: u.ad,
      email: u.email,
      telefon: "",
      aranabilir: u.aranabilir ?? false,
      role: (u.role as UserRole) ?? "security",
      password: "",
      gorevBaslangic: u.gorev_baslangic ?? "",
      gorevBitis: u.gorev_bitis ?? "",
    });
    setFormErr(null);
    setOpen(true);
    try {
      const d = await jsonFetcher<UserDetail>(`/api/users/${u.id}`);
      setForm((f) => ({
        ...f,
        telefon: d.telefon ?? "",
        aranabilir: d.aranabilir ?? false,
      }));
    } catch {
      // Detay cekilemezse form yine acik kalir (telefon bos); kaydetmeye engel yok.
    }
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      if (editingId) {
        // PATCH: parola yalniz doluysa gonderilir (bossa degismez).
        const body: Record<string, unknown> = {
          ad: form.ad,
          email: form.email || null,
          telefon: telefonNormalle(form.telefon) || null,
          aranabilir: form.aranabilir,
          role: form.role,
          // BOS = "pencere yok" (acik null); alani hic gondermemek
          // "degistirme" demek olurdu ve gorev IPTALI yapilamazdi.
          gorev_baslangic: form.gorevBaslangic || null,
          gorev_bitis: form.gorevBitis || null,
        };
        if (form.password) body.password = form.password;
        await apiSend(`/api/users/${editingId}`, "PATCH", body);
      } else {
        // Telefon = global benzersiz giris anahtari (zorunlu). E-posta opsiyonel.
        // Parola bossa backend TEK SEFERLIK gecici kod uretir (temp_code).
        const body: Record<string, unknown> = {
          ad: form.ad,
          telefon: telefonNormalle(form.telefon),
          aranabilir: form.aranabilir,
          role: form.role,
        };
        if (form.gorevBaslangic) body.gorev_baslangic = form.gorevBaslangic;
        if (form.gorevBitis) body.gorev_bitis = form.gorevBitis;
        if (form.email) body.email = form.email;
        if (form.password) body.password = form.password;
        const created = await apiSend<{ temp_code?: string | null }>(
          "/api/users",
          "POST",
          body,
        );
        if (created?.temp_code) {
          window.alert(
            t("kullaniciGeciciKod", { kod: created.temp_code }),
          );
        }
      }
      setOpen(false);
      mutate();
      toast.success(editingId ? t("kullaniciGuncellendi") : t("kullaniciOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setFormErr(
        /email|e-posta|telefon|zaten kayitli|conflict/i.test(m)
          ? t("kullaniciZatenKayitli")
          : m,
      );
    } finally {
      setSaving(false);
    }
  }

  async function setActive(u: UserRow, active: boolean) {
    try {
      await apiSend(`/api/users/${u.id}`, "PATCH", { is_active: active });
      mutate();
      toast.success(active ? t("kullaniciAktiflestirildi") : t("kullaniciPasiflestirildi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakGuncellenemedi"));
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader
        title={t("kabukKullanicilar")}
        action={
          <button className={btnPrimary} onClick={openNew}>{t("kullaniciYeni")}</button>
        }
      />

      <div className="flex flex-wrap items-end gap-3">
        <div className="w-44">
          <Field label={t("ortakRol")}>
            <select className={inputCls} value={role} onChange={(e) => resetFilters({ role: e.target.value })}>
              <option value="">{t("ortakTumu")}</option>
              {ROLES.map((r) => (
                <option key={r.value} value={r.value}>
                  {t(r.anahtar)}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="w-44">
          <Field label={t("ortakDurum")}>
            <select className={inputCls} value={aktif} onChange={(e) => resetFilters({ aktif: e.target.value })}>
              <option value="">{t("ortakTumu")}</option>
              <option value="true">{t("ortakAktif")}</option>
              <option value="false">{t("ortakPasif")}</option>
            </select>
          </Field>
        </div>
        <div className="grow">
          <Field label={t("kullaniciArama")}>
            <input
              className={inputCls}
              value={q}
              onChange={(e) => resetFilters({ q: e.target.value })}
              placeholder={t("kullaniciAramaIpucu")}
            />
          </Field>
        </div>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>}

      {open && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">{editingId ? t("kullaniciDuzenle") : t("kullaniciYeni")}</h2>
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("ortakAd")}>
              <input
                className={inputCls}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            </Field>
            <Field label={t("kullaniciEpostaOpsiyonel")} hint={t("kullaniciEpostaIpucu")}>
              <input
                type="email"
                className={inputCls}
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
              />
            </Field>
            <Field
              label={t("kullaniciTelefon")}
              hint={t("kullaniciTelefonIpucu")}
            >
              <input
                className={inputCls}
                value={telefonGiris(form.telefon)}
                // (P123) TEK bicimlendirici — bkz. lib/telefon.ts.
                onChange={(e) => setForm({ ...form, telefon: telefonGiris(e.target.value) })}
                placeholder={t("kullaniciTelefonOrnek")}
                required
              />
            </Field>
            <Field label={t("kullaniciAranabilir")} hint={t("kullaniciAranabilirIpucu")}>
              <label className="flex h-10 items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={form.aranabilir}
                  onChange={(e) => setForm({ ...form, aranabilir: e.target.checked })}
                />
                {t("kullaniciAranabilirOnay")}
              </label>
            </Field>
            <Field label={t("ortakRol")}>
              <select
                className={inputCls}
                value={form.role}
                disabled={acilabilirRoller === undefined}
                onChange={(e) => setForm({ ...form, role: e.target.value as UserRole })}
              >
                {rolSecenekleri.map((r) => (
                  <option key={r.value} value={r.value}>
                    {t(r.anahtar)}
                  </option>
                ))}
              </select>
            </Field>
            {form.role === "denetci" ? (
              // (P128) YALNIZ DENETCIDE GORUNUR: gorev penceresi bugun
              // baska bir rolde anlam tasimiyor ve her role gostermek,
              // doldurulunca hicbir sey yapmayan bir alan demekti.
              <>
                <Field
                  label={t("kullaniciGorevBaslangic")}
                  hint={t("kullaniciGorevIpucu")}
                >
                  <input
                    type="date"
                    className={inputCls}
                    value={form.gorevBaslangic}
                    onChange={(e) =>
                      setForm({ ...form, gorevBaslangic: e.target.value })
                    }
                  />
                </Field>
                <Field label={t("kullaniciGorevBitis")}>
                  <input
                    type="date"
                    className={inputCls}
                    value={form.gorevBitis}
                    onChange={(e) =>
                      setForm({ ...form, gorevBitis: e.target.value })
                    }
                  />
                </Field>
              </>
            ) : null}
            <Field
              label={
                editingId
                  ? t("kullaniciYeniParola")
                  : t("kullaniciParolaOpsiyonel")
              }
              hint={
                editingId
                  ? t("kullaniciEnAz8")
                  : t("kullaniciParolaBosYeni")
              }
            >
              <ParolaAlani
                className={inputCls}
                value={form.password}
                onChange={(v) => setForm({ ...form, password: v })}
                minLength={8}
                placeholder={
                  editingId ? t("kullaniciParolaBosDuzenle") : t("kullaniciParolaBosKisa")
                }
              />
            </Field>
          </div>
          <ErrorBox message={formErr} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </button>
            <button type="button" className={btnGhost} onClick={() => setOpen(false)}>
              {t("ortakIptal")}
            </button>
          </div>
        </motion.form>
      )}

      <div className="overflow-hidden rounded-kart border kart-kenar bg-white">
        <div className="odak-ic overflow-x-auto" tabIndex={0}>
          <Tablo>
            <TabloBasligi>
                <Th>{t("ortakAd")}</Th>
                <Th>{t("girisEposta")}</Th>
                <Th>{t("kullaniciAranabilir")}</Th>
                <Th>{t("ortakRol")}</Th>
                <Th>{t("ortakDurum")}</Th>
                <Th />
              </TabloBasligi>
            <tbody>
              {(data?.items ?? []).map((u) => (
                <tr key={u.id} className={`border-t border-yuzey-divider transition-colors hover:bg-yuzey-bg ${u.is_active ? "" : "bg-yuzey-bg"}`}>
                  <Td>{u.ad}</Td>
                  <Td className="text-metin-body">{u.email}</Td>
                  <Td className="text-metin-body">
                    {u.aranabilir ? t("ortakEvet") : "—"}
                  </Td>
                  <Td>
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${ROLE_STYLE[u.role] ?? "bg-slate-100 text-metin-body"}`}
                    >
                      {rolAdi(t, u.role)}
                    </span>
                  </Td>
                  <Td>
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        u.is_active ? "bg-emerald-100 text-emerald-800" : "bg-slate-200 text-metin-body"
                      }`}
                    >
                      {u.is_active ? t("ortakAktif") : t("ortakPasif")}
                    </span>
                  </Td>
                  <Td hizala="end">
                    <div className="flex justify-end gap-2">
                      <button className={btnGhost} onClick={() => openEdit(u)}>
                        {t("ortakDuzenle")}
                      </button>
                      {u.is_active ? (
                        <button className={btnGhost} onClick={() => setActive(u, false)}>{t("ortakPasiflestir")}</button>
                      ) : (
                        <button className={btnGhost} onClick={() => setActive(u, true)}>{t("ortakAktiflestir")}</button>
                      )}
                    </div>
                  </Td>
                </tr>
              ))}
              {data && data.items.length === 0 && (
                <tr>
                  <Td colSpan={6}>
                    <EmptyState title={t("kullaniciYok")} description={t("kullaniciYokAlt")} />
                  </Td>
                </tr>
              )}
            </tbody>
          </Tablo>
        </div>
      </div>

      {data && (
        <Pager
          offset={offset}
          limit={LIMIT}
          total={data.meta.total}
          onPrev={() => setOffset(Math.max(0, offset - LIMIT))}
          onNext={() => setOffset(offset + LIMIT)}
        />
      )}
    </div>
  );
}
