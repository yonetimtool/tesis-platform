"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";
import useSWR from "swr";

import {
  Modal,
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  IskeletMetin,
  useOnay,
} from "@/components/ui";
import { KopyaKod } from "@/components/KopyaKod";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { TelefonAlani } from "@/components/TelefonAlani";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";
import { telefonNormalle } from "@/lib/telefon";

interface Yonetici {
  id: string;
  ad: string;
  telefon: string | null;
  is_active: boolean;
  password_set: boolean;
}
interface TenantDetail {
  tenant_id: string;
  ad: string;
  kayit_kodu: string | null;
  kurulum_tamamlandi: boolean;
  created_at: string;
  yonetici: Yonetici | null;
}

/** (P154) Listedeki yonetici. `birincil`, tekil detayda YOKTUR: orasi zaten
 *  yalniz birincili doner. Listede ise hangi satirin silinemeyecegini
 *  kullaniciya soyleyen tek isarettir. */
interface YoneticiSatiri extends Yonetici {
  birincil: boolean;
  created_at: string;
}

function fmtDate(iso: string): string {
  try {
    return tarihSaatUzun(iso);
  } catch {
    return iso;
  }
}

export default function TenantDetailPage() {
  const t = useT();
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { data, error, isLoading, mutate } = useSWR<TenantDetail>(
    id ? `/api/tenants/${id}` : null,
    jsonFetcher,
  );

  const [editing, setEditing] = useState(false);
  const [ad, setAd] = useState("");
  const [telefon, setTelefon] = useState("");
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [busy, setBusy] = useState(false);
  const [confirmAd, setConfirmAd] = useState("");
  const [nameEditing, setNameEditing] = useState(false);
  const [nameInput, setNameInput] = useState("");
  const [nameErr, setNameErr] = useState<string | null>(null);
  const [nameSaving, setNameSaving] = useState(false);

  // (P154) Coklu yonetici. AYRI bir SWR anahtari: tekil detay yalniz
  // birincili doner ve o gorunum degismedi; listeyi oraya sikistirmak
  // mevcut cagiranlarin bekledigi bicimi bozardi.
  const {
    data: yoneticiler,
    error: yonHata,
    mutate: yonYenile,
  } = useSWR<{ items: YoneticiSatiri[] }>(
    id ? `/api/tenants/${id}/yoneticiler` : null,
    jsonFetcher,
  );
  const [ekleAcik, setEkleAcik] = useState(false);
  const [yeniAd, setYeniAd] = useState("");
  const [yeniTel, setYeniTel] = useState("");
  const [yeniHata, setYeniHata] = useState<string | null>(null);
  const [ekliyor, setEkliyor] = useState(false);

  const y = data?.yonetici ?? null;

  async function yoneticiEkle(e: React.FormEvent) {
    e.preventDefault();
    setEkliyor(true);
    setYeniHata(null);
    try {
      const r = await apiSend<{ ad: string; temp_code: string }>(
        `/api/tenants/${id}/yoneticiler`,
        "POST",
        { ad: yeniAd.trim(), phone: telefonNormalle(yeniTel) ?? yeniTel.trim() },
      );
      // Kod BIR KEZ doner; kapanabilen bir bildirim yerine onay gerektiren
      // bir kutu: kullanici kodu kopyalamadan ekrani birakirsa geri
      // getirilemez, yalniz sifirlanabilir.
      window.alert(t("tesisYeniYoneticiKodu", { ad: r.ad, kod: r.temp_code }));
      setEkleAcik(false);
      setYeniAd("");
      setYeniTel("");
      yonYenile();
      mutate();
      toast.success(t("tesisYoneticiEklendi"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setYeniHata(/telefon|zaten kay/i.test(m) ? t("tesisTelefonKayitli") : m);
    } finally {
      setEkliyor(false);
    }
  }

  async function yoneticiSil(satir: YoneticiSatiri) {
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("tesisYoneticiSilOnay", { ad: satir.ad }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    setBusy(true);
    try {
      await apiSend(`/api/tenants/${id}/yoneticiler/${satir.id}`, "DELETE");
      yonYenile();
      mutate();
      toast.success(t("tesisYoneticiSilindi"));
    } catch (err) {
      // Sunucu UC AYRI 409 uretir (son yonetici / birincil / kayitlari var)
      // ve ucunun metni de kullaniciya NE yapacagini soyler. Kendi
      // cumlemizi uydurmak o bilgiyi silerdi.
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    } finally {
      setBusy(false);
    }
  }

  function openNameEdit() {
    if (!data) return;
    setNameInput(data.ad);
    setNameErr(null);
    setNameEditing(true);
  }

  async function saveName(e: React.FormEvent) {
    e.preventDefault();
    setNameSaving(true);
    setNameErr(null);
    try {
      await apiSend(`/api/tenants/${id}`, "PATCH", { ad: nameInput.trim() });
      setNameEditing(false);
      mutate();
      toast.success(t("tesisAdiGuncellendi"));
    } catch (err) {
      setNameErr(err instanceof Error ? err.message : t("ortakKaydedilemedi"));
    } finally {
      setNameSaving(false);
    }
  }

  function openEdit() {
    if (!y) return;
    setAd(y.ad);
    setTelefon(y.telefon ?? "");
    setFormErr(null);
    setEditing(true);
  }

  async function saveEdit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      const body: Record<string, unknown> = { ad };
      if (telefonNormalle(telefon)) body.phone = telefonNormalle(telefon);
      await apiSend(`/api/tenants/${id}/yonetici`, "PATCH", body);
      setEditing(false);
      mutate();
      toast.success(t("tesisYoneticiGuncellendi"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setFormErr(/telefon|zaten kay/i.test(m) ? t("tesisTelefonKayitli") : m);
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive() {
    if (!y) return;
    const next = !y.is_active;
    if (!(await onayla({ baslik: t("ortakOnayBaslik"), mesaj: next ? t("tesisYoneticiAktifOnay") : t("tesisYoneticiPasifOnay"), onayMetni: next ? t("ortakAktiflestir") : t("ortakPasiflestir"), tehlikeli: !next }))) return;
    setBusy(true);
    try {
      await apiSend(`/api/tenants/${id}/yonetici`, "PATCH", { is_active: next });
      mutate();
      toast.success(next ? t("tesisYoneticiAktiflestirildi") : t("tesisYoneticiPasiflestirildi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakGuncellenemedi"));
    } finally {
      setBusy(false);
    }
  }

  async function resetCredential() {
    if (!(await onayla({ baslik: t("ortakOnayBaslik"), mesaj: t("tesisParolaSifirlaOnay"), onayMetni: t("tesisParolaSifirla"), tehlikeli: true }))) return;
    setBusy(true);
    try {
      const r = await apiSend<{ temp_code: string }>(
        `/api/tenants/${id}/yonetici/reset-credential`,
        "POST",
      );
      window.alert(
        t("tesisGeciciKod", { kod: r.temp_code }),
      );
      mutate();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("tesisSifirlanamadi"));
    } finally {
      setBusy(false);
    }
  }

  async function deleteTenant() {
    setBusy(true);
    try {
      await apiSend(`/api/tenants/${id}`, "DELETE");
      router.push("/tenants");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
      setBusy(false);
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3">
        <Link
          href="/tenants"
          className="odak-ic underline"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-accent-ink)" }}
        >
          <span aria-hidden="true">←</span> {t("kabukTesisler")}
        </Link>
      </div>

      {error && <HataDurumu mesaj={error.message} />}
      {isLoading && !data && <IskeletMetin satir={3} />}

      {data && (
        <>
          <div className="">
            {!nameEditing && (
              <>
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div className="min-w-0 flex-1">
                    <h1 className="text-2xl font-semibold break-words">{data.ad}</h1>
                    {/* (P155 §6) Yoneticinin ILETECEGI kod birincil ve
                        kopyalanabilir; teknik UUID altta kucuk kalir. */}
                    {data.kayit_kodu ? (
                      <div className="mt-1">
                        <KopyaKod deger={data.kayit_kodu} etiket={t("tesisKayitKodu")} />
                      </div>
                    ) : null}
                    <p className="mt-1 font-mono text-xs break-all text-metin-muted">
                      {data.tenant_id}
                    </p>
                  </div>
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      data.kurulum_tamamlandi
                        ? "bg-emerald-100 text-emerald-800"
                        : "bg-amber-100 text-amber-800"
                    }`}
                  >
                    {data.kurulum_tamamlandi
                      ? t("tesisKurulumTamamlandi")
                      : t("tesisKurulumBekliyorRozet")}
                  </span>
                </div>
                <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
                  <p className="text-sm text-metin-body">
                    {t("tesisOlusturulmaTarihi", { zaman: fmtDate(data.created_at) })}
                  </p>
                  <Dugme boy="kucuk" onClick={openNameEdit}>
                    {t("tesisAdiDuzenle")}
                  </Dugme>
                </div>
              </>
            )}

            <Modal
              acik={nameEditing}
              onKapat={() => setNameEditing(false)}
              baslik={t("tesisAdiDuzenle")}
              eylemler={
                <>
                  <Dugme tur="sessiz" onClick={() => setNameEditing(false)}>
                    {t("ortakIptal")}
                  </Dugme>
                  <Dugme type="submit" form="tesis-adi" tur="birincil" disabled={nameSaving}>
                    {nameSaving ? t("ortakKaydediliyor") : t("ortakKaydet")}
                  </Dugme>
                </>
              }
            >
              <form id="tesis-adi" onSubmit={saveName} className="space-y-4">
                <AlanSarmal etiket={t("ayarTesisAdi")}>
  {(b) => (
    <Alan {...b} value={nameInput}
                    onChange={(e) => setNameInput(e.target.value)}
                    minLength={2}
                    maxLength={120}
                    required
                    autoFocus />
  )}
</AlanSarmal>
                {nameErr && <HataDurumu mesaj={nameErr} />}
              </form>
            </Modal>
          </div>

          <div className="">
            <h2 className="mb-3 font-medium">{t("rolYonetici")}</h2>
            {!y && <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("tesisYoneticiYok")}</p>}

            {y && !editing && (
              <div className="space-y-3">
                <dl className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm [&>*]:min-w-0 [&>dd]:break-words">
                  <dt className="text-metin-muted">{t("ortakAd")}</dt>
                  <dd>{y.ad}</dd>
                  <dt className="text-metin-muted">{t("tesisTelefonGiris")}</dt>
                  <dd>{y.telefon ?? "—"}</dd>
                  <dt className="text-metin-muted">{t("ortakDurum")}</dt>
                  <dd>
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        y.is_active ? "bg-emerald-100 text-emerald-800" : "bg-slate-200 text-metin-body"
                      }`}
                    >
                      {y.is_active ? t("ortakAktif") : t("ortakPasif")}
                    </span>
                  </dd>
                  <dt className="text-metin-muted">{t("tesisKimlik")}</dt>
                  <dd className="text-metin-body">
                    {y.password_set
                      ? t("tesisParolaBelirlendi")
                      : t("tesisGeciciKodAsamasi")}
                  </dd>
                </dl>
                <div className="flex flex-wrap gap-2 pt-1">
                  <Dugme boy="kucuk" onClick={openEdit} disabled={busy}>
                    {t("tesisAdTelefonDuzenle")}
                  </Dugme>
                  <Dugme boy="kucuk" onClick={resetCredential} disabled={busy}>
                    {t("tesisParolaSifirla")}
                  </Dugme>
                  <Dugme boy="kucuk" onClick={toggleActive} disabled={busy}>
                    {y.is_active ? t("ortakPasiflestir") : t("ortakAktiflestir")}
                  </Dugme>
                </div>
              </div>
            )}

            <Modal
              acik={Boolean(y) && editing}
              onKapat={() => setEditing(false)}
              baslik={t("tesisYoneticiDuzenle")}
              eylemler={
                <>
                  <Dugme tur="sessiz" onClick={() => setEditing(false)}>
                    {t("ortakIptal")}
                  </Dugme>
                  <Dugme type="submit" form="yonetici-duzenle" tur="birincil" disabled={saving}>
                    {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
                  </Dugme>
                </>
              }
            >
              <form id="yonetici-duzenle" onSubmit={saveEdit} className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <AlanSarmal etiket={t("ortakAd")}>
  {(b) => (
    <Alan {...b} value={ad}
                      onChange={(e) => setAd(e.target.value)}
                      required
                      minLength={2} />
  )}
</AlanSarmal>
                  <TelefonAlani
                    etiket={t("kullaniciTelefon")}
                    ipucu={t("tesisGlobalBenzersiz")}
                    deger={telefon}
                    onDegisti={setTelefon}
                  />
                </div>
                <HataDurumu mesaj={formErr} />
              </form>
            </Modal>
          </div>

          {/* (P154) COKLU YONETICI — brief Asama 1'in "EKSIK" maddesi.
              Yukaridaki kart BIRINCIL yoneticinin kimlik islemleridir
              (parola sifirlama, pasiflestirme) ve OLDUGU GIBI durur; burasi
              tesisin yonetici KADROSUDUR. */}
          <div className="">
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
              <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("tesisYoneticilerBaslik")}</h2>
              {!ekleAcik && (
                <Dugme boy="kucuk" onClick={() => {
                    // (P163 §2) Acilista eski hata temizlenir.
                    setYeniHata(null);
                    setEkleAcik(true);
                  }} disabled={busy}>
                  {t("tesisYoneticiEkle")}
                </Dugme>
              )}
            </div>

            {yonHata && <HataDurumu mesaj={yonHata.message} />}

            {yoneticiler && (
              <ul className="divide-y divide-cizgi">
                {yoneticiler.items.map((satir) => (
                  <li key={satir.id} className="flex flex-wrap items-center gap-2 py-2">
                    <div className="min-w-0 flex-1">
                      <p className="flex flex-wrap items-center gap-2 text-sm font-medium">
                        <span className="break-words">{satir.ad}</span>
                        {satir.birincil && (
                          <span className="rounded-full bg-sky-100 px-2 py-0.5 text-xs font-medium text-sky-800">
                            {t("tesisBirincilRozet")}
                          </span>
                        )}
                        {!satir.is_active && (
                          <span className="rounded-full bg-slate-200 px-2 py-0.5 text-xs font-medium text-metin-body">
                            {t("ortakPasif")}
                          </span>
                        )}
                      </p>
                      <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                        {satir.telefon ?? "—"}
                        {" · "}
                        {satir.password_set
                          ? t("tesisParolaBelirlendi")
                          : t("tesisGeciciKodAsamasi")}
                      </p>
                    </div>
                    {/* Birincil satirda dugme CIZILMEZ ama nedeni YAZILIR:
                        pasif bir dugme "neden calismiyor?" sorusunu
                        uretir, hicbir sey gostermemek ise sessiz kalirdi. */}
                    {satir.birincil ? (
                      <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                        {t("tesisBirincilSilinemezIpucu")}
                      </span>
                    ) : (
                      <Dugme
                        boy="kucuk"
                        onClick={() => yoneticiSil(satir)}
                        disabled={busy}
                      >
                        {t("ortakSil")}
                      </Dugme>
                    )}
                  </li>
                ))}
              </ul>
            )}

            <Modal
              acik={ekleAcik}
              onKapat={() => setEkleAcik(false)}
              baslik={t("tesisYoneticiEkleBaslik")}
              eylemler={
                <>
                  <Dugme tur="sessiz" onClick={() => setEkleAcik(false)}>
                    {t("ortakIptal")}
                  </Dugme>
                  <Dugme type="submit" form="yonetici-ekle" tur="birincil" disabled={ekliyor}>
                    {ekliyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
                  </Dugme>
                </>
              }
            >
              <form id="yonetici-ekle" onSubmit={yoneticiEkle} className="space-y-4">
                <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("tesisYoneticiEkleAciklama")}</p>
                <div className="grid grid-cols-2 gap-4">
                  <AlanSarmal etiket={t("ortakAd")}>
  {(b) => (
    <Alan {...b} value={yeniAd}
                      onChange={(e) => setYeniAd(e.target.value)}
                      required
                      minLength={2}
                      maxLength={120}
                      autoFocus />
  )}
</AlanSarmal>
                  <TelefonAlani
                    etiket={t("kullaniciTelefon")}
                    ipucu={t("tesisGlobalBenzersiz")}
                    zorunlu
                    deger={yeniTel}
                    onDegisti={setYeniTel}
                  />
                </div>
                <HataDurumu mesaj={yeniHata} />
              </form>
            </Modal>
          </div>

          <div className="rounded-xl border border-rose-200 bg-rose-50 p-5">
            <h2 className="font-medium text-rose-800">{t("tesisTehlikeliBolge")}</h2>
            <p className="mt-1 text-sm text-rose-700">
              {t("tesisSilUyari", { kelime: t("tesisSilOnayKelimesi") })}
            </p>
            <div className="mt-3 flex flex-wrap items-center gap-2">
              {/* (P63) YER TUTUCU ETIKET DEGILDIR: yazmaya baslayinca
                  KAYBOLUR ve ekran okuyucularin bir kismi hic okumaz.
                  Burasi bir TESISI SILME onayidir — adini duyamayan
                  kullanicinin ne yazdigini bilmeden onaylamasi demekti. */}
              <Alan
                aria-label={t("tesisSilOnayEtiketi")}
                className="max-w-xs"
                value={confirmAd}
                onChange={(e) => setConfirmAd(e.target.value)}
                placeholder={t("tesisSilOnayKelimesi")}
              />
              <button
                className="rounded-lg bg-rose-600 px-3 py-1.5 text-sm font-medium text-white transition hover:bg-rose-700 disabled:opacity-50"
                onClick={deleteTenant}
                disabled={busy || confirmAd.trim().toLocaleUpperCase("tr") !== t("tesisSilOnayKelimesi")}
              >
                {t("tesisKaliciSil")}
              </button>
            </div>
          </div>
        </>
      )}
      {diyalog}
    </div>
  );
}
