"use client";

/**
 * (P162) ETKINLIKLER — YONETIM EKRANI.
 *
 * =========================================================================
 * NEDEN AYRI SAYFA
 * =========================================================================
 * Olculdu (`docs/web-mobil-esitlik.md`): mobilde etkinlik olusturulup
 * duzenlenip silinebiliyordu, webde sayfada HIC yazma cagrisi yoktu.
 * Uclar (`POST/PATCH/DELETE /events`) zaten vardi.
 *
 * `/etkinlikler` SAKIN GORUNUMUDUR (P126.3) ve oyle kalir. Depodaki
 * yerlesik desen bu: `/duyurular` (sakin) ile `/announcements` (yonetim)
 * ayri sayfalardir. Rol kapisi `lib/yuzey.ts`te `["admin", "yonetici"]` —
 * sunucudaki `_MANAGER` ile AYNI kume.
 *
 * =========================================================================
 * TARIH ALANI: YEREL GIRIS, UTC GONDERIM
 * =========================================================================
 * `<input type="datetime-local">` YEREL saat verir ve sunucu ISO8601 UTC
 * bekler. Ham degeri gondermek, etkinligi kullanicinin saat diliminden
 * bagimsiz olarak KAYDIRIRDI (TR'de uc saat). Donusum tek yerde ve iki
 * yonlu: gosterirken yerele, gonderirken UTC'ye.
 */
import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  CokSatir,
  Dugme,
  HataDurumu,
  Iskelet,
  Kart,
  Modal,
  useOnay,
} from "@/components/ui";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

interface Etkinlik {
  id: string;
  baslik: string;
  aciklama: string;
  tarih: string;
  bitis_zamani?: string | null;
  konum: string | null;
}

const UC = "/api/events?limit=100&offset=0";
const BOS_FORM = { baslik: "", aciklama: "", tarih: "", bitis: "", konum: "" };

/**
 * ISO (UTC) -> `datetime-local` degeri.
 *
 * `toISOString().slice(0,16)` KULLANILAMAZ: o UTC dondurur ve alan YEREL
 * saat bekler; kayit her acilista saat dilimi farki kadar kayardi.
 */
function yereleCevir(iso: string | null | undefined): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** `datetime-local` -> ISO (UTC). Bos deger `null` doner. */
function utcyeCevir(yerel: string): string | null {
  if (!yerel) return null;
  const d = new Date(yerel);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

export default function EtkinlikYonetimPage() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();
  const { data, error, isLoading, mutate } = useSWR<{ items: Etkinlik[] }>(UC, jsonFetcher);
  const etkinlikler = data?.items ?? [];

  const [acik, setAcik] = useState(false);
  const [duzenlenen, setDuzenlenen] = useState<Etkinlik | null>(null);
  const [form, setForm] = useState(BOS_FORM);
  const [formHata, setFormHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  function yeniAc() {
    setDuzenlenen(null);
    setForm(BOS_FORM);
    setFormHata(null);
    setAcik(true);
  }

  function duzenleAc(e: Etkinlik) {
    setDuzenlenen(e);
    setForm({
      baslik: e.baslik,
      aciklama: e.aciklama,
      tarih: yereleCevir(e.tarih),
      bitis: yereleCevir(e.bitis_zamani),
      konum: e.konum ?? "",
    });
    setFormHata(null);
    setAcik(true);
  }

  async function kaydet(ev: React.FormEvent) {
    ev.preventDefault();
    setMesgul(true);
    setFormHata(null);
    try {
      const tarih = utcyeCevir(form.tarih);
      if (!tarih) {
        setFormHata(t("etkinlikTarihGerekli"));
        return;
      }
      const govde = {
        baslik: form.baslik,
        aciklama: form.aciklama,
        tarih,
        // BOS = "bitis yok" (acik null). Alani hic gondermemek
        // "degistirme" demek olurdu ve bitis IPTAL edilemezdi.
        bitis_zamani: utcyeCevir(form.bitis),
        konum: form.konum.trim() || null,
      };
      if (duzenlenen) await apiSend(`/api/events/${duzenlenen.id}`, "PATCH", govde);
      else await apiSend("/api/events", "POST", govde);
      setAcik(false);
      mutate();
      toast.success(t("ortakKaydedildi"));
    } catch (err) {
      setFormHata(alanliHataMetni(err, t("ortakKaydedilemedi")));
    } finally {
      setMesgul(false);
    }
  }

  async function sil(e: Etkinlik) {
    const ok = await onayla({
      baslik: t("ortakSilBaslik"),
      mesaj: t("ortakSilOnay", { ad: e.baslik }),
      onayMetni: t("ortakSil"),
      tehlikeli: true,
    });
    if (!ok) return;
    try {
      await apiSend(`/api/events/${e.id}`, "DELETE");
      mutate();
      toast.success(t("ortakSilindi"));
    } catch (err) {
      toast.error(alanliHataMetni(err, t("ortakSilinemedi")));
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("etkinlikYonetimBaslik")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("etkinlikYonetimAlt")}
          </p>
        </div>
        <Dugme tur="birincil" boy="kucuk" onClick={yeniAc}>
          {t("etkinlikYeni")}
        </Dugme>
      </div>

      <Modal
        acik={acik}
        onKapat={() => setAcik(false)}
        baslik={duzenlenen ? t("etkinlikDuzenle") : t("etkinlikYeni")}
        genislikSinifi="max-w-2xl"
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setAcik(false)} disabled={mesgul}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="etkinlik-form" yukleniyor={mesgul}>
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="etkinlik-form" onSubmit={kaydet} className="space-y-4">
          <AlanSarmal etiket={t("ortakBaslik")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                value={form.baslik}
                onChange={(e) => setForm({ ...form, baslik: e.target.value })}
                maxLength={200}
                required
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("ortakAciklama")} zorunlu>
            {(b) => (
              <CokSatir
                {...b}
                rows={5}
                value={form.aciklama}
                onChange={(e) => setForm({ ...form, aciklama: e.target.value })}
                maxLength={5000}
                required
              />
            )}
          </AlanSarmal>
          <div className="grid gap-4 sm:grid-cols-2">
            <AlanSarmal etiket={t("etkinlikBaslangic")} zorunlu>
              {(b) => (
                <Alan
                  {...b}
                  type="datetime-local"
                  value={form.tarih}
                  onChange={(e) => setForm({ ...form, tarih: e.target.value })}
                  required
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("etkinlikBitis")} ipucu={t("etkinlikBitisIpucu")}>
              {(b) => (
                <Alan
                  {...b}
                  type="datetime-local"
                  value={form.bitis}
                  onChange={(e) => setForm({ ...form, bitis: e.target.value })}
                />
              )}
            </AlanSarmal>
          </div>
          <AlanSarmal etiket={t("etkinlikKonum")}>
            {(b) => (
              <Alan
                {...b}
                value={form.konum}
                onChange={(e) => setForm({ ...form, konum: e.target.value })}
                maxLength={500}
              />
            )}
          </AlanSarmal>
          <HataDurumu mesaj={formHata} />
        </form>
      </Modal>

      {/* HATA VARKEN "kayit yok" DENMEZ (P61). */}
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} onTekrar={() => mutate()} /> : null}
      {isLoading && !data ? <Iskelet className="h-24 w-full" /> : null}
      {!isLoading && !error && etkinlikler.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("etkinlikYonetimBos")} />
        </Kart>
      ) : null}

      <ul className="space-y-3">
        {etkinlikler.map((e) => (
          <li key={e.id}>
            <Kart className="space-y-2">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="min-w-0">
                  <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
                    {e.baslik}
                  </h2>
                  <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                    {tarihSaatUzun(e.tarih)}
                    {e.konum ? ` · ${e.konum}` : ""}
                  </p>
                </div>
                <div className="flex shrink-0 gap-2">
                  <Dugme boy="kucuk" onClick={() => duzenleAc(e)}>
                    {t("ortakDuzenle")}
                  </Dugme>
                  <Dugme boy="kucuk" tur="tehlike" onClick={() => void sil(e)}>
                    {t("ortakSil")}
                  </Dugme>
                </div>
              </div>
              <p
                className="whitespace-pre-line"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
              >
                {e.aciklama}
              </p>
            </Kart>
          </li>
        ))}
      </ul>
      {diyalog}
    </div>
  );
}
