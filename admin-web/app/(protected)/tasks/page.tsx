"use client";

import { motion } from "framer-motion";
import { useMemo, useState } from "react";

import { EksikVeriUyarisi } from "@/components/form";
import useSWR from "swr";

import { BagimlilikUyarisi } from "@/components/BagimlilikUyarisi";
import { Ekler } from "@/components/Ekler";
import { useToast } from "@/components/Toast";
import {
  IskeletMetin,
  BosDurum,
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  Kart,
  Rozet,
  Modal,
  Secim,
  Sekmeler,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
  useOnay,
} from "@/components/ui";
import { Tablo, TabloBasligi, Td, Th, Tr } from "@/components/tablo";
import { kisaKimlik } from "@/lib/kimlik";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { SAHA_ROLLERI, rolAdi } from "@/lib/roles";
import { tamsayiCoz } from "@/lib/sayi";
import { useI18n, useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import type {
  Task,
  TaskCategoryList,
  TaskCompletionList,
  TaskList,
  UserListResponse,
} from "@/lib/types";

/**
 * (P160 / Asama 6) OLU `tip` ZINCIRI KALDIRILDI — olculdu.
 *
 * Bu sayfa sabit bir TIP listesi (temizlik/kontrol/.../peyzaj) tutuyor,
 * onu forma koyuyor, `?tip=` ile suzuyor ve tabloda bir sutun ciziyordu.
 * UCUNUN DE KARSILIGI YOKTU:
 *   * `TaskCreate`/`TaskUpdate` sozlesmesinde `tip` ALANI YOK — Pydantic
 *     `extra="forbid"` kullanmadigi icin gonderilen deger SESSIZCE
 *     ATILIYORDU. Kullanici "Temizlik" seciyor, hicbir sey olmuyordu.
 *   * `GET /tasks` `tip` SORGU PARAMETRESI ALMIYOR — suzgec hicbir sey
 *     yapmiyordu (FastAPI bilinmeyen parametreyi yok sayar).
 *   * `TaskOut` `tip` DONDURMUYOR — tablodaki sutun `undefined` ciziyordu.
 *
 * Sebep: gorev tipi 087f33f'te DINAMIK KATEGORIYE (`task_category`)
 * cevrildi ve sabit enum kaldirildi; bu sayfa guncellenmemis. Yerine
 * gecen alan (`kategori_id`) ZATEN bu sayfada vardi — yani ozellik
 * kaybi degil, YALAN SOYLEYEN bir denetimin kaldirilmasi.
 *
 * SUZGEC ARTIK GERCEK: `kategori_id` backend'de destekleniyor ("diger"
 * = kategorisiz) ve suzgec bu tur CALISIYOR.
 */
const LIMIT = 20;

/** Kategorisiz gorevlerin sutun/suzgec kimligi — backend "diger" bekliyor. */
const KATEGORISIZ = "diger";

type Gorunum = "liste" | "kanban" | "takvim";
const GORUNUM_LISTE = "liste" as const;
const GORUNUM_KANBAN = "kanban" as const;
const GORUNUM_TAKVIM = "takvim" as const;

function toIso(local: string): string | null {
  if (!local) return null;
  const d = new Date(local);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}
function isoToLocalInput(iso?: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

interface FormState {
  ad: string;
  aciklama: string;
  atanan_user_id: string;
  kategori_id: string;
  periyot_dakika: string;
  sonraki_planlanan: string;
  foto_zorunlu: boolean;
  aktif: boolean;
}
const EMPTY: FormState = {
  ad: "",
  aciklama: "",
  atanan_user_id: "",
  kategori_id: "",
  periyot_dakika: "",
  sonraki_planlanan: "",
  foto_zorunlu: false,
  aktif: true,
};

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DURUM_OLUMLU = "olumlu" as const;
const DURUM_NOTR = "notr" as const;

export default function TasksPage() {
  const t = useT();
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 25,
    siraKolon: null,
    siraYonu: "artan",
  });
  const [kategoriFiltre, setKategoriFiltre] = useState("");
  const [aktif, setAktif] = useState("");
  const [atananFiltre, setAtananFiltre] = useState("");

  // (P160) SAYFALAMA TEK KAYNAKTAN: `offset` artik tablo durumundan
  // TURETILIR. Iki ayri sayac tutuldugunda tabloda "2. sayfa" yazarken
  // istek hala ILK sayfayi cekiyordu — kullanici ayni kayitlari
  // sayfa degistirmis gibi goruyordu.
  const qs = new URLSearchParams({
    limit: String(tabloDurumu.boy),
    offset: String((tabloDurumu.sayfa - 1) * tabloDurumu.boy),
  });
  if (kategoriFiltre) qs.set("kategori_id", kategoriFiltre);
  if (aktif) qs.set("aktif", aktif);
  if (atananFiltre) qs.set("atanan_user_id", atananFiltre);
  const { data, error, isLoading, mutate } = useSWR<TaskList>(
    `/api/tasks?${qs.toString()}`,
    jsonFetcher,
  );
  // Atanan picker: saha personeli (security + tesis_gorevlisi — lib/roles SAHA_ROLLERI).
  const { data: users, error: usersErr } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);
  // Kategori picker: yonetici-tanimli aktif kategoriler (A6).
  const { data: kategoriler, error: kategorilerErr } = useSWR<TaskCategoryList>("/api/task-categories", jsonFetcher);
  function kategoriAd(id?: string | null): string {
    if (!id) return "—";
    return kategoriler?.items.find((k) => k.id === id)?.ad ?? kisaKimlik(id);
  }
  const personel = (users?.items ?? []).filter(
    (u) => u.is_active && (SAHA_ROLLERI as string[]).includes(u.role),
  );
  function userName(id?: string | null): string {
    if (!id) return "—";
    return users?.items.find((u) => u.id === id)?.ad ?? kisaKimlik(id);
  }

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [detail, setDetail] = useState<Task | null>(null);

  const { data: completions } = useSWR<TaskCompletionList>(
    detail ? `/api/tasks/${detail.id}/completions?limit=50&offset=0` : null,
    jsonFetcher,
  );

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(t: Task) {
    setEditingId(t.id);
    setForm({
      ad: t.ad,
      aciklama: t.aciklama ?? "",
      atanan_user_id: t.atanan_user_id ?? "",
      kategori_id: t.kategori_id ?? "",
      periyot_dakika: t.periyot_dakika != null ? String(t.periyot_dakika) : "",
      sonraki_planlanan: isoToLocalInput(t.sonraki_planlanan),
      foto_zorunlu: t.foto_zorunlu,
      aktif: t.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    // (P56) `Number(per)` NaN uretebiliyordu ve `JSON.stringify(NaN)`
    // **null**dur: gecersiz periyot sessizce "periyot yok"a donusuyordu.
    const per = tamsayiCoz(form.periyot_dakika);
    if (per.tur === "gecersiz") {
      setFormErr(t("gorevPeriyotGecersiz"));
      return;
    }
    const body = {
      ad: form.ad,
      aciklama: form.aciklama || null,
      atanan_user_id: form.atanan_user_id || null,
      kategori_id: form.kategori_id || null,
      periyot_dakika: per.tur === "sayi" ? per.deger : null,
      sonraki_planlanan: toIso(form.sonraki_planlanan),
      foto_zorunlu: form.foto_zorunlu,
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/tasks/${editingId}`, "PATCH", body);
      else await apiSend("/api/tasks", "POST", body);
      setOpen(false);
      mutate();
      toast.success(editingId ? t("gorevGuncellendi") : t("gorevOlusturuldu"));
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : t("ortakKaydedilemedi"));
    } finally {
      setSaving(false);
    }
  }

  async function remove(gorev: Task) {
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("gorevSilOnay", { ad: gorev.ad }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/tasks/${gorev.id}`, "DELETE");
      if (detail?.id === gorev.id) setDetail(null);
      mutate();
      toast.success(t("gorevSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  const [gorunum, setGorunum] = useState<Gorunum>(GORUNUM_LISTE);
  const gorevler = data?.items ?? [];

  /**
   * Kanban surukleme/secim sonucu: gorevin KATEGORISINI degistirir.
   *
   * IYIMSER GUNCELLEME YOK: istek dusersse kart eski sutununa "geri
   * ziplamaz", cunku hic tasinmamis olur. Iyimser tasima, basarisiz
   * istekte kullaniciya YANLIS bir dunya gosterirdi.
   */
  async function kategoriTasi(gorev: Task, kategoriId: string | null) {
    try {
      await apiSend(`/api/tasks/${gorev.id}`, "PATCH", { kategori_id: kategoriId });
      await mutate();
      const ad =
        kategoriId === null
          ? t("gorevKategorisiz")
          : ((kategoriler?.items ?? []).find((k) => k.id === kategoriId)?.ad ?? "");
      toast.success(t("gorevKategoriDegisti", { ad }));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakGuncellenemedi"));
    }
  }

  const kolonlar: Kolon<Task>[] = useMemo(
    () => [
      {
        id: "ad",
        baslik: t("ortakBaslik"),
        gizlenebilir: false,
        hucre: (g) => (
          <span className="flex items-center gap-2">
            {g.ad}
            {g.foto_zorunlu && (
              <Rozet durum="bilgi">{t("gorevFotoZorunluRozet")}</Rozet>
            )}
          </span>
        ),
      },
      {
        id: "kategori",
        baslik: t("gorevKategoriAlan"),
        hucre: (g) => kategoriAd(g.kategori_id),
      },
      {
        id: "atanan",
        baslik: t("gorevAtanan"),
        hucre: (g) => userName(g.atanan_user_id),
        darEkrandaGizle: true,
      },
      {
        id: "sonraki",
        baslik: t("gorevSonraki"),
        hucre: (g) =>
          g.sonraki_planlanan ? formatDateTime(g.sonraki_planlanan) : "—",
        darEkrandaGizle: true,
      },
      {
        id: "aktif",
        baslik: t("ortakDurum"),
        hucre: (g) => (
          <Rozet durum={g.aktif ? DURUM_OLUMLU : DURUM_NOTR}>
            {g.aktif ? t("ortakAktif") : t("ortakPasif")}
          </Rozet>
        ),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (g) => (
          <div className="flex justify-end gap-2">
            <Dugme
              boy="kucuk"
              onClick={() => setDetail(detail?.id === g.id ? null : g)}
            >
              {detail?.id === g.id ? t("ortakKapat") : t("gorevKayitlar")}
            </Dugme>
            <Dugme boy="kucuk" onClick={() => openEdit(g)}>
              {t("ortakDuzenle")}
            </Dugme>
            <Dugme boy="kucuk" tur="tehlike" onClick={() => void remove(g)}>
              {t("ortakSil")}
            </Dugme>
          </div>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, detail, kategoriler, users],
  );

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kabukGorevler")}
        </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
          {t("gorevYeni")}
        </Dugme>
      </div>

      <EksikVeriUyarisi
        mesaj={usersErr || kategorilerErr ? t("ortakSecenekYuklenemedi") : null}
      />

      <div className="flex flex-wrap items-end gap-3">
        {/* SUZGEC ARTIK GERCEK: `kategori_id` backend'de destekleniyor
            ("diger" = kategorisiz). Eski `tip` suzgeci hicbir sey
            yapmiyordu (bkz. dosya basi). */}
        <div className="w-52">
          <AlanSarmal etiket={t("gorevKategoriAlan")}>
            {(b) => (
              <Secim
                {...b}
                value={kategoriFiltre}
                onChange={(e) => {
                  setKategoriFiltre(e.target.value);
                  setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
                }}
              >
                <option value="">{t("ortakTumu")}</option>
                <option value={KATEGORISIZ}>{t("gorevKategorisiz")}</option>
                {(kategoriler?.items ?? []).map((k) => (
                  <option key={k.id} value={k.id}>
                    {k.ad}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
        </div>
        <div className="w-44">
          <AlanSarmal etiket={t("ortakDurum")}>
  {(b) => (
    <Secim {...b} value={aktif}
              onChange={(e) => {
                setAktif(e.target.value);
                setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
              }}
            >
              <option value="">{t("ortakTumu")}</option>
              <option value="true">{t("ortakAktif")}</option>
              <option value="false">{t("ortakPasif")}</option></Secim>
  )}
</AlanSarmal>
        </div>
        <div className="w-56">
          <AlanSarmal etiket={t("gorevAtanan")}>
  {(b) => (
    <Secim {...b} value={atananFiltre}
              onChange={(e) => {
                setAtananFiltre(e.target.value);
                setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
              }}
            >
              <option value="">{t("ortakTumu")}</option>
              {personel.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.ad} ({rolAdi(t, u.role)})
                </option>
              ))}</Secim>
  )}
</AlanSarmal>
        </div>
      </div>

      {/* (P154 / Asama 7.4) Kategori yoksa gorev acilamaz: sunucu
          `422 butce_kategori_bulunamadi` doner ve kullanici nereye
          gidecegini bilmez (olculdu, envanter §0.4). */}
      <BagimlilikUyarisi
        kod="gorevKategorisi"
        eksik={(kategoriler?.items?.length ?? 1) === 0}
      />
      {/* Liste cekilemezse BOS TABLO degil, sebep + "Tekrar dene".
          Yukleme durumu artik `VeriTablosu`nun ISKELETI. */}
      {isLoading && !data && <IskeletMetin satir={3} />}

      {/* FORM ARTIK MODALDA (brief: "sayfa ustunde alan acma deseni
          kaldirilacak"). Odak tuzagi, ESC ve kapanista odagin geri
          donmesi `Modal`dan geliyor. */}
      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("gorevDuzenle") : t("gorevYeni")}
        genislikSinifi="max-w-2xl"
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="gorev-form" yukleniyor={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="gorev-form" onSubmit={save} className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">

            <AlanSarmal etiket={t("ortakBaslik")}>
  {(b) => (
    <Alan {...b} value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("ortakAciklamaOpsiyonel")}>
  {(b) => (
    <Alan {...b} value={form.aciklama}
                onChange={(e) => setForm({ ...form, aciklama: e.target.value })} />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("gorevAtananOpsiyonel")}>
  {(b) => (
    <Secim {...b} value={form.atanan_user_id}
                onChange={(e) => setForm({ ...form, atanan_user_id: e.target.value })}
              >
                <option value="">{t("ortakSecimYok")}</option>
                {personel.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.ad} ({rolAdi(t, u.role)})
                  </option>
                ))}</Secim>
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("demirbasKategoriOpsiyonel")} ipucu={t("gorevKategoriIpucu")}>
  {(b) => (
    <Secim {...b} value={form.kategori_id}
                onChange={(e) => setForm({ ...form, kategori_id: e.target.value })}
              >
                <option value="">{t("ortakSecimYok")}</option>
                {(kategoriler?.items ?? []).map((k) => (
                  <option key={k.id} value={k.id}>
                    {k.ad}
                  </option>
                ))}</Secim>
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("gorevPeriyotDakikaOpsiyonel")} ipucu={t("gorevPeriyodikIpucu")}>
  {(b) => (
    <Alan {...b} type="number"
                min={1}value={form.periyot_dakika}
                onChange={(e) => setForm({ ...form, periyot_dakika: e.target.value })} />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("gorevSonrakiPlanlananOpsiyonel")} ipucu={t("gorevPeriyodikSaatIpucu")}>
  {(b) => (
    <Alan {...b} type="datetime-local"value={form.sonraki_planlanan}
                onChange={(e) => setForm({ ...form, sonraki_planlanan: e.target.value })} />
  )}
</AlanSarmal>
          </div>
          <div className="flex gap-6">
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={form.foto_zorunlu}
                onChange={(e) => setForm({ ...form, foto_zorunlu: e.target.checked })}
              />
              {t("gorevFotoZorunlu")}
            </label>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={form.aktif}
                onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
              />{t("ortakAktif")}</label>
          </div>
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

      {/* --- UC GORUNUM (brief: "Kanban + liste + takvim") ------------ */}
      <Sekmeler
        aktifId={gorunum}
        onDegis={(id) => setGorunum(id as Gorunum)}
        sekmeler={[
          {
            id: GORUNUM_LISTE,
            baslik: t("gorevGorunumListe"),
            icerik: (
              <VeriTablosu<Task>
                kolonlar={kolonlar}
                satirlar={gorevler}
                satirId={(g) => g.id}
                hata={error ? error.message : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
                bosBaslik={t("gorevYok")}
                bosAciklama={t("gorevYokAlt")}
                sunucuTarafli
                toplam={data?.meta.total ?? 0}
                durum={tabloDurumu}
                onDurumDegisti={setTabloDurumu}
              />
            ),
          },
          {
            id: GORUNUM_KANBAN,
            baslik: t("gorevGorunumKanban"),
            icerik: (
              <Kanban
                gorevler={gorevler}
                kategoriler={kategoriler?.items ?? []}
                onTasi={(g, kategoriId) => void kategoriTasi(g, kategoriId)}
              />
            ),
          },
          {
            id: GORUNUM_TAKVIM,
            baslik: t("gorevGorunumTakvim"),
            icerik: <Takvim gorevler={gorevler} onSec={(g) => openEdit(g)} />,
          },
        ]}
      />

      {detail && (
        <Kart className="space-y-3">
          <h2 className="text-lg font-medium">
            {t("gorevTamamlamaKayitlari", { ad: detail.ad })}
          </h2>
          <div className="overflow-hidden rounded-lg border kart-kenar">
            <div className="odak-ic overflow-x-auto" tabIndex={0}>
              <Tablo>
              <TabloBasligi>
                  <Th>{t("raporTabloZaman")}</Th>
                  <Th>{t("raporTabloTamamlayan")}</Th>
                  <Th>{t("raporTabloFoto")}</Th>
                  <Th>{t("raporNot")}</Th>
                </TabloBasligi>
              <tbody>
                {(completions?.items ?? []).map((c) => (
                  <Tr key={c.id}>
                    <Td className="text-metin-body">{formatDateTime(c.tamamlanma_zamani)}</Td>
                    <Td>{userName(c.tamamlayan_user_id)}</Td>
                    <Td>
                      {c.foto_url ? (
                        // (P131) FOTOGRAFIN KENDISI GOSTERILIR.
                        // Eskiden yalnizca "foto var" rozeti cizilirdi ve
                        // kanita ULASMANIN YOLU YOKTU — cunku sunucu
                        // `foto_url`i hic doldurmuyordu (olculdu: alan
                        // semada vardi, deger null geliyordu). Rozet o
                        // eksigi gizliyordu.
                        <a href={c.foto_url} target="_blank" rel="noreferrer">
                          {/* eslint-disable-next-line @next/next/no-img-element */}
                          <img
                            src={c.foto_url}
                            alt={t("gorevFotoVarRozet")}
                            className="h-12 w-16 rounded object-cover"
                          />
                        </a>
                      ) : c.foto_key ? (
                        // Anahtar var ama adres yok: presign uretilememis.
                        // Rozet BURADA dogru — "kanit var, gosterilemiyor".
                        <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-800">
                          {t("gorevFotoVarRozet")}
                        </span>
                      ) : (
                        <span className="text-metin-muted">{t("raporYok")}</span>
                      )}
                    </Td>
                    <Td className="text-metin-body">{c.notlar ?? "—"}</Td>
                  </Tr>
                ))}
                {completions && completions.items.length === 0 && (
                  <tr>
                    <Td colSpan={4}>
                      <BosDurum baslik={t("denetimKayitYok")} />
                    </Td>
                  </tr>
                )}
              </tbody>
              </Tablo>
            </div>
          </div>

          {/* (P154 / Asama 6.4) Ortak not/ek yuzeyi. Goreve ozel bir ek
              tablosu ve yukleme akisi YAZILMADI: `Ekler` bileseni
              `varlikTipi` alir ve sekiz varlikta ayni sekilde calisir. */}
          <Ekler varlikTipi="task" varlikId={detail.id} />
        </Kart>
      )}

      {diyalog}
    </div>
  );
}


/* ======================================================================
   KANBAN — KATEGORIYE gore, SURUKLE-BIRAK ile kategori degistirir.
   ======================================================================
   NEDEN KATEGORI, NEDEN "DURUM" DEGIL: `Task` semasinda DURUM ALANI YOK
   (todo/yapiliyor/bitti). Uydurmak arka uc degisikligi gerektirirdi ve
   kilitli kural 1 buna kapali. Kategori ise GERCEK ve `PATCH
   kategori_id` ile degistirilebiliyor — yani surukleme gercek bir
   mutasyon yapiyor, dekor degil.

   SURUKLEME ICIN KUTUPHANE EKLENMEDI: HTML5 `dragstart`/`drop` yeterli.
   ERISILEBILIR YEDEK ZORUNLU — surukleme klavyeyle yapilamaz; her kartta
   kategoriyi degistiren bir SECIM de var. Yalniz surukleme sunmak,
   klavye ve ekran okuyucu kullanicisini bu gorunumden tamamen dislardi.
   ====================================================================== */

function Kanban({
  gorevler,
  kategoriler,
  onTasi,
}: {
  gorevler: Task[];
  kategoriler: { id: string; ad: string }[];
  onTasi: (gorev: Task, kategoriId: string | null) => void;
}) {
  const t = useT();
  const [uzerinde, setUzerinde] = useState<string | null>(null);

  // Kategorisiz sutun HER ZAMAN var: kategorisi olmayan gorevler bir
  // yere dusmeli, yoksa panoda GORUNMEZ olurlardi.
  const sutunlar = [
    { id: KATEGORISIZ, ad: t("gorevKategorisiz") },
    ...kategoriler.map((k) => ({ id: k.id, ad: k.ad })),
  ];

  return (
    <div>
      <p
        className="mb-3"
        style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
      >
        {t("gorevSuruklemeIpucu")}
      </p>
      <div className="flex gap-3 overflow-x-auto pb-2">
        {sutunlar.map((sutun) => {
          const icerik = gorevler.filter(
            (g) => (g.kategori_id ?? KATEGORISIZ) === sutun.id,
          );
          return (
            <section
              key={sutun.id}
              aria-label={sutun.ad}
              onDragOver={(e) => {
                e.preventDefault();
                setUzerinde(sutun.id);
              }}
              onDragLeave={() => setUzerinde((u) => (u === sutun.id ? null : u))}
              onDrop={(e) => {
                e.preventDefault();
                setUzerinde(null);
                const id = e.dataTransfer.getData("text/plain");
                const gorev = gorevler.find((g) => g.id === id);
                if (!gorev) return;
                const hedef = sutun.id === KATEGORISIZ ? null : sutun.id;
                if ((gorev.kategori_id ?? null) === hedef) return;
                onTasi(gorev, hedef);
              }}
              className="w-64 shrink-0 p-2"
              style={{
                borderRadius: "var(--yz-radius-card)",
                background:
                  uzerinde === sutun.id
                    ? "var(--yz-surface-2)"
                    : "var(--yz-surface-sunken)",
                boxShadow: "var(--yz-sunken)",
              }}
            >
              <h3
                className="mb-2 flex items-center justify-between px-1"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
              >
                {sutun.ad}
                <span style={{ color: "var(--yz-text-3)" }}>{icerik.length}</span>
              </h3>
              <div className="space-y-2">
                {icerik.map((g) => (
                  <Kart
                    key={g.id}
                    ton="yukseltilmis"
                    className="cursor-grab p-3"
                    {...{
                      draggable: true,
                      onDragStart: (e: React.DragEvent) =>
                        e.dataTransfer.setData("text/plain", g.id),
                    }}
                  >
                    <p style={{ fontSize: "var(--yz-fs-body)" }}>{g.ad}</p>
                    {g.sonraki_planlanan && (
                      <p
                        className="mt-1"
                        style={{
                          fontSize: "var(--yz-fs-xs)",
                          color: "var(--yz-text-3)",
                        }}
                      >
                        {formatDateTime(g.sonraki_planlanan)}
                      </p>
                    )}
                    {/* KLAVYE YEDEGI — surukleme tek yol OLAMAZ. */}
                    <label className="mt-2 block">
                      <span className="sr-only">
                        {t("gorevTasi", { gorev: g.ad })}
                      </span>
                      <Secim
                        value={g.kategori_id ?? KATEGORISIZ}
                        onChange={(e) =>
                          onTasi(
                            g,
                            e.target.value === KATEGORISIZ ? null : e.target.value,
                          )
                        }
                        className="!h-9"
                      >
                        {sutunlar.map((sc) => (
                          <option key={sc.id} value={sc.id}>
                            {sc.ad}
                          </option>
                        ))}
                      </Secim>
                    </label>
                  </Kart>
                ))}
              </div>
            </section>
          );
        })}
      </div>
    </div>
  );
}

/* ======================================================================
   TAKVIM — `sonraki_planlanan` uzerinden AY IZGARASI.
   ======================================================================
   SALT OKUNUR ve bu bilincli: surukleyerek tarih degistirmek `PATCH
   sonraki_planlanan` ile mumkun ama periyodik gorevlerde o alan
   TAMAMLANINCA KENDILIGINDEN ILERLIYOR (bkz. sozlesme notu). Elle
   surukleme, periyodun bir sonraki adimini sessizce ezerdi; once o
   etkilesimin ne anlama geldigine karar verilmeli.

   Ay adi `Intl` ile AKTIF DILDEN gelir — sozluge on iki ay adi yazmak,
   tarayicinin zaten bildigi seyi yedi kez kopyalamak olurdu.
   ====================================================================== */

function Takvim({
  gorevler,
  onSec,
}: {
  gorevler: Task[];
  onSec: (gorev: Task) => void;
}) {
  const t = useT();
  const { dil } = useI18n();
  const [ay, setAy] = useState(() => {
    const d = new Date();
    return new Date(d.getFullYear(), d.getMonth(), 1);
  });

  const baslik = useMemo(
    () =>
      new Intl.DateTimeFormat(dil, { month: "long", year: "numeric" }).format(ay),
    [dil, ay],
  );

  const gunler = useMemo(() => {
    const ilk = new Date(ay.getFullYear(), ay.getMonth(), 1);
    const sonGun = new Date(ay.getFullYear(), ay.getMonth() + 1, 0).getDate();
    // Pazartesi = 0 olacak sekilde kaydir (TR/AB haftasi).
    const bosluk = (ilk.getDay() + 6) % 7;
    return { bosluk, sonGun };
  }, [ay]);

  /** Gun -> o gune planlanmis gorevler. */
  const gunGorevleri = useMemo(() => {
    const harita = new Map<number, Task[]>();
    for (const g of gorevler) {
      if (!g.sonraki_planlanan) continue;
      const d = new Date(g.sonraki_planlanan);
      if (Number.isNaN(d.getTime())) continue;
      if (d.getFullYear() !== ay.getFullYear() || d.getMonth() !== ay.getMonth()) {
        continue;
      }
      const liste = harita.get(d.getDate()) ?? [];
      liste.push(g);
      harita.set(d.getDate(), liste);
    }
    return harita;
  }, [gorevler, ay]);

  const plansiz = gorevler.filter((g) => !g.sonraki_planlanan);

  return (
    <div>
      <div className="mb-3 flex items-center justify-between gap-2">
        <Dugme
          boy="kucuk"
          onClick={() => setAy(new Date(ay.getFullYear(), ay.getMonth() - 1, 1))}
          aria-label={t("ortakOnceki")}
        >
          {t("ortakOnceki")}
        </Dugme>
        <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {baslik}
        </h3>
        <Dugme
          boy="kucuk"
          onClick={() => setAy(new Date(ay.getFullYear(), ay.getMonth() + 1, 1))}
          aria-label={t("ortakSonraki")}
        >
          {t("ortakSonraki")}
        </Dugme>
      </div>

      <div className="grid grid-cols-7 gap-1">
        {Array.from({ length: gunler.bosluk }).map((_, i) => (
          <div key={`bos-${i}`} />
        ))}
        {Array.from({ length: gunler.sonGun }).map((_, i) => {
          const gun = i + 1;
          const liste = gunGorevleri.get(gun) ?? [];
          return (
            <div
              key={gun}
              className="min-h-[76px] p-1.5"
              style={{
                borderRadius: "var(--yz-radius-btn)",
                background: "var(--yz-surface-sunken)",
                boxShadow: "var(--yz-sunken)",
              }}
            >
              <span
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
              >
                {gun}
              </span>
              <div className="mt-1 space-y-1">
                {liste.map((g) => (
                  <button
                    key={g.id}
                    type="button"
                    onClick={() => onSec(g)}
                    className="odak-ic block w-full truncate px-1 py-0.5 text-start"
                    style={{
                      borderRadius: "var(--yz-radius-btn)",
                      background: "var(--yz-metal-2)",
                      boxShadow: "var(--yz-raised)",
                      fontSize: "var(--yz-fs-xs)",
                      color: "var(--yz-text)",
                    }}
                  >
                    {g.ad}
                  </button>
                ))}
              </div>
            </div>
          );
        })}
      </div>

      {/* PLANSIZ GOREVLER GIZLENMEZ: takvimde yeri yok ama VARLAR.
          Gostermemek, kullaniciya "gorev kalmadi" demek olurdu. */}
      {plansiz.length > 0 && (
        <section className="mt-4">
          <h3
            className="mb-2"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            {t("gorevPlansiz")} ({plansiz.length})
          </h3>
          <div className="flex flex-wrap gap-2">
            {plansiz.map((g) => (
              <Dugme key={g.id} boy="kucuk" onClick={() => onSec(g)}>
                {g.ad}
              </Dugme>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
