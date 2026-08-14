"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import useSWR from "swr";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const R_OLUMLU = "olumlu" as const;
const R_UYARI = "uyari" as const;

import {
  Rozet,
  VeriTablosu,
  type Kolon,
  Kart,
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
} from "@/components/ui";
import { KopyaKod } from "@/components/KopyaKod";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { TenantAdminCreate, TenantAdminCreatedOut } from "@/lib/types";
import { ParolaAlani } from "@/components/ParolaAlani";
import { useT } from "@/lib/i18n/kullan";
import { ApiHatasi } from "@/lib/client";
import { tarihSaatUzun } from "@/lib/tarih";
import { telefonGiris, telefonNormalle } from "@/lib/telefon";

interface TenantRow {
  id: string;
  ad: string;
  kayit_kodu: string | null;
  kurulum_tamamlandi: boolean;
  created_at: string;
}
interface TenantListResponse {
  items: TenantRow[];
}

// Formdaki tek yonetici satiri. Parola bos string = "verilmedi" (govdeye hic
// konmaz) -> backend tek seferlik gecici kod uretir.
interface YoneticiForm {
  /** (P68) KARARLI ANAHTAR. Liste `key={i}` kullaniyordu ve ORTADAN satir
   *  SILINEBILIYOR: React o durumda DOM dugumlerini yeniden kullanir ve
   *  imlec/odak, tarayicinin otomatik doldurmasi, parola yoneticisinin
   *  bagi BIR ALT satira kayar. Satirda PAROLA alani var — yanlis satira
   *  baglanan bir parola yoneticisi ciddi bir kusurdur. */
  anahtar: string;
  ad: string;
  phone: string;
  password: string;
}
let _sayac = 0;
function bosYonetici(): YoneticiForm {
  _sayac += 1;
  return { anahtar: `y${_sayac}`, ad: "", phone: "", password: "" };
}
interface FormState {
  ad: string;
  yonetim_email: string;
  yoneticiler: YoneticiForm[];
}
// Ilk satir HER ZAMAN vardir ve BIRINCIL'dir (kaldirilamaz) — backend en az bir
// yonetici bekler ve listenin ilkini birincil isaretler.
const bosForm = (): FormState => ({
  ad: "",
  yonetim_email: "",
  yoneticiler: [bosYonetici()],
});

function fmtDate(iso: string): string {
  try {
    return tarihSaatUzun(iso);
  } catch {
    return iso;
  }
}

export default function TenantsPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<TenantListResponse>(
    "/api/tenants",
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<FormState>(bosForm);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function openNew() {
    setForm(bosForm());
    setFormErr(null);
    setOpen(true);
  }

  async function removeTenant(tesis: TenantRow) {
    // Tesisi + TUM verisini kalici siler (geri alinamaz). Tek adimli net onay
    // (yeni tesisin adi "(Kurulum bekliyor)" yer tutucu oldugundan ad-yazdirma
    // pratik degil).
    const ok = window.confirm(
      t("tesisSilOnayMetni", { ad: tesis.ad }),
    );
    if (!ok) return;
    try {
      await apiSend(`/api/tenants/${tesis.id}`, "DELETE");
      mutate();
      toast.success(t("tesisSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  function setYonetici(i: number, patch: Partial<YoneticiForm>) {
    setForm({
      ...form,
      yoneticiler: form.yoneticiler.map((y, j) => (j === i ? { ...y, ...patch } : y)),
    });
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      const body: TenantAdminCreate = {
        yoneticiler: form.yoneticiler.map((y) => ({
          ad: y.ad,
          // Sunucuya NORMALLESTIRILMIS gider (telefon GLOBAL BENZERSIZ).
          phone: telefonNormalle(y.phone),
          ...(y.password ? { password: y.password } : {}),
        })),
      };
      if (form.ad.trim()) body.ad = form.ad.trim();
      if (form.yonetim_email.trim()) body.yonetim_email = form.yonetim_email.trim();

      const created = await apiSend<TenantAdminCreatedOut>("/api/tenants", "POST", body);

      // Gecici kod YALNIZ parolasiz acilan yonetici icin ve BIR KEZ doner —
      // her kod kendi yoneticisinin adiyla listelenir ki yanlis kisiye gitmesin.
      const kodlar = (created?.yoneticiler ?? []).filter((y) => y.temp_code);
      if (kodlar.length) {
        window.alert(
          t("tesisKodlarBaslik") +
            kodlar
              .map((y) => `• ${y.ad}${y.birincil ? t("tesisYoneticiBirincilEki") : ""}: ${y.temp_code}`)
              .join("\n") +
            t("tesisKodlarNot"),
        );
      } else {
        window.alert(
          t("tesisParolaIleGiris"),
        );
      }
      setOpen(false);
      mutate();
    } catch (err) {
      // KOD ile karar (tur 22): sunucu metni artik 7 dilde geldigi icin
      // metinde arama yapmak Turkce disi her dilde sessizce bozulurdu.
      const cakisma =
        err instanceof ApiHatasi &&
        (err.code === "conflict" || err.status === 409);
      setFormErr(
        cakisma
          ? t("tesisTelefonKayitli")
          : err instanceof Error
            ? err.message
            : t("ortakHataOlustu"),
      );
    } finally {
      setSaving(false);
    }
  }

  const kolonlar: Kolon<TenantRow>[] = useMemo(
    () => [
      {
        id: "ad",
        baslik: t("ayarTesisAdi"),
        gizlenebilir: false,
        deger: (x) => x.ad,
        hucre: (x) => (
          <Link
            href={`/tenants/${x.id}`}
            className="odak-ic underline"
            style={{ fontWeight: 600, color: "var(--yz-accent-ink)" }}
          >
            {x.ad}
          </Link>
        ),
      },
      {
        // (P155 §6) Yoneticinin ILETECEGI kod birincil; teknik UUID
        // `title` icinde erisilebilir kalir.
        id: "kod",
        baslik: t("tesisKayitKodu"),
        hucre: (x) =>
          x.kayit_kodu ? (
            <KopyaKod deger={x.kayit_kodu} etiket={t("tesisKayitKodu")} />
          ) : (
            <span
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              title={x.id}
            >
              —
            </span>
          ),
      },
      {
        id: "kurulum",
        baslik: t("tesisKurulum"),
        hucre: (x) => (
          <Rozet durum={x.kurulum_tamamlandi ? R_OLUMLU : R_UYARI}>
            {x.kurulum_tamamlandi ? t("tesisTamamlandi") : t("tesisBekliyor")}
          </Rozet>
        ),
      },
      {
        id: "olusturma",
        baslik: t("tesisOlusturulma"),
        darEkrandaGizle: true,
        hucre: (x) => fmtDate(x.created_at),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (x) => (
          <div className="flex justify-end gap-2">
            <Link
              href={`/tenants/${x.id}`}
              className="odak-ic yz-lift inline-flex items-center px-3 py-2"
              style={{
                borderRadius: "var(--yz-radius-btn)",
                border: "var(--yz-border-w) solid var(--yz-border)",
                fontSize: "var(--yz-fs-sm)",
                color: "var(--yz-text)",
                background: "var(--yz-metal-1)",
              }}
            >
              {t("tesisYonet")}
            </Link>
            <Dugme tur="tehlike" boy="kucuk" onClick={() => void removeTenant(x)}>
              {t("ortakSil")}
            </Dugme>
          </div>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t],
  );

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("kabukTesisler")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("tesisListeAciklama")}
          </p>
        </div>
        <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
          {t("tesisYeni")}
        </Dugme>
      </div>

      {error && <HataDurumu mesaj={error.message} />}
      {isLoading && !data && <IskeletMetin satir={3} />}

      {open && (
        <Kart>
          <form onSubmit={save} className="space-y-4">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("tesisYeni")}</h2>
          <div className="grid grid-cols-2 gap-4">
            <AlanSarmal etiket={t("tesisAdiOpsiyonel")} ipucu={t("tesisAdiBosIpucu")}>
              {(b) => (
                <Alan {...b}
                                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                minLength={2}
                placeholder={t("tesisAdiOrnek")}
              />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("tesisYonetimMaili")} ipucu={t("tesisYonetimMailiIpucu")}>
              {(b) => (
                <Alan {...b}
                type="email"
                                value={form.yonetim_email}
                onChange={(e) => setForm({ ...form, yonetim_email: e.target.value })}
                placeholder={t("tesisYonetimMailiOrnek")}
              />
              )}
            </AlanSarmal>
          </div>

          <div className="space-y-4">
            {form.yoneticiler.map((y, i) => (
              <div key={y.anahtar} className="rounded-lg border kart-kenar p-4">
                <div className="mb-3 flex items-start justify-between gap-3">
                  <div>
                    <h3 className="text-sm font-medium">
                      {i === 0
                        ? t("tesisBirincilYonetici")
                        : t("tesisYoneticiSira", { n: i + 1 })}
                    </h3>
                    {i === 0 && (
                      <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("tesisIlkGirisAdlandirir")}</p>
                    )}
                  </div>
                  {i > 0 && (
                    <button
                      type="button"
                      className="rounded-lg px-3 py-1.5 text-sm font-medium text-rose-700 transition hover:bg-rose-50"
                      onClick={() =>
                        setForm({
                          ...form,
                          yoneticiler: form.yoneticiler.filter((_, j) => j !== i),
                        })
                      }
                    >
                      {t("tesisKaldir")}
                    </button>
                  )}
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <AlanSarmal etiket={t("tesisAdSoyad")}>
  {(b) => (
    <Alan {...b} value={y.ad}
                      onChange={(e) => setYonetici(i, { ad: e.target.value })}
                      required
                      minLength={2} />
  )}
</AlanSarmal>
                  <AlanSarmal etiket={t("kullaniciTelefon")} ipucu={t("tesisTelefonIpucu")}>
              {(b) => (
                <Alan {...b}
                                      value={telefonGiris(y.phone)}
                      // (P123) TEK bicimlendirici — bkz. lib/telefon.ts.
                      onChange={(e) => setYonetici(i, { phone: telefonGiris(e.target.value) })}
                      placeholder={t("kullaniciTelefonOrnek")}
                      required
              />
              )}
            </AlanSarmal>
                  <AlanSarmal
                    etiket={t("tesisParolaOpsiyonel")}
                    ipucu={t("kullaniciParolaBosYeni")}
                  >
                    {(b) => (
                      <ParolaAlani
                        // Etiket kimligi BAGLANMALI: `AlanSarmal` `htmlFor`
                        // ile bu kimlige isaret ediyor.
                        id={b.id}
                        value={y.password}
                        onChange={(v) => setYonetici(i, { password: v })}
                        minLength={8}
                        placeholder={t("kullaniciParolaBosKisa")}
                      />
                    )}
                  </AlanSarmal>
                </div>
              </div>
            ))}
            <Dugme
              type="button"
              boy="kucuk"
              onClick={() =>
                setForm({ ...form, yoneticiler: [...form.yoneticiler, bosYonetici()] })
              }
            >
              {t("tesisYoneticiEkle")}
            </Dugme>
          </div>

          <HataDurumu mesaj={formErr} />
          <div className="flex gap-2">
            <Dugme type="submit" tur="birincil" disabled={saving}>
              {saving ? t("tesisOlusturuluyor") : t("tesisOlustur")}
            </Dugme>
            <Dugme type="button" boy="kucuk" onClick={() => setOpen(false)}>
              {t("ortakIptal")}
            </Dugme>
          </div>
          </form>
        </Kart>
      )}

      <VeriTablosu<TenantRow>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(x) => x.id}
        hata={error ? error.message : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        bosBaslik={t("tesisYok")}
        bosAciklama={t("tesisYokAlt")}
      />
    </div>
  );
}
