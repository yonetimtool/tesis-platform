"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { EksikVeriUyarisi } from "@/components/form";
import {
  Alan,
  AlanSarmal,
  Dugme,
  TarihAraligi,
  aralikGecerli,
  Kart,
  Kpi,
  Rozet,
  Secim,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
} from "@/components/ui";
import { ReportsTabs } from "@/components/ReportsTabs";
import { kisaKimlik } from "@/lib/kimlik";
import { fetchAllPaged } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type {
  TaskCategoryList,
  TaskCompletionHistoryResponse,
  TaskCompletionRow,
  UserListResponse,
} from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";


// GOREV TIPI = DINAMIK KATEGORI. Sabit dort tip (temizlik/kontrol/ilaclama/
// peyzaj) backend'den kaldirilmisti; panel eski alanlari okumaya devam
// ediyordu ve rapor ozet kartlari ekrana "undefined" yaziyordu (tur 41).
// Kategori adlari SUNUCU VERISIDIR — cevrilmez, oldugu gibi gosterilir.
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const D_OLUMLU = "olumlu" as const;
const D_NOTR = "notr" as const;
const D_BILGI = "bilgi" as const;
// Ozet halkalarinin renk dongusu — kategori sayisi degiskendir.
const HALKA_DONGUSU = [D_BILGI, D_OLUMLU, D_NOTR] as const;

function toIso(local: string): string {
  if (!local) return "";
  const d = new Date(local);
  return Number.isNaN(d.getTime()) ? "" : d.toISOString();
}

function csvDownload(filename: string, rows: string[][]): void {
  const esc = (c: string) => (/[",\n]/.test(c) ? `"${c.replace(/"/g, '""')}"` : c);
  const csv = rows.map((r) => r.map(esc).join(",")).join("\n");
  const blob = new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export default function TaskReportPage() {
  const t = useT();
  const [bas, setBas] = useState("");
  const [bit, setBit] = useState("");
  const [tamamlayan, setTamamlayan] = useState("");
  const [committed, setCommitted] = useState<string | null>(null);
  /** (P65) Cekim ust sinira takildi mi — rapor EKSIKTIR. */
  const [kesildi, setKesildi] = useState(false);
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 25,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;

  const { data: users, error: usersErr } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);
  // Suzgec KATEGORI uzerinden (sunucu `kategori_id` bekler). Eskiden sabit
  // `tip` degeri gonderiliyordu — sunucu o parametreyi hic okumuyordu, yani
  // suzgec SESSIZCE ETKISIZDI (tur 41).
  const { data: kategoriler, error: kategorilerErr } = useSWR<TaskCategoryList>("/api/task-categories", jsonFetcher);
  const [kategoriId, setKategoriId] = useState("");
  function userName(id: string): string {
    return users?.items.find((u) => u.id === id)?.ad ?? kisaKimlik(id);
  }

  function buildFilters(): string {
    const qs = new URLSearchParams();
    const b = toIso(bas);
    if (b) qs.set("baslangic", b);
    const e = toIso(bit);
    if (e) qs.set("bitis", e);
    if (kategoriId) qs.set("kategori_id", kategoriId);
    if (tamamlayan) qs.set("tamamlayan_user_id", tamamlayan);
    return qs.toString();
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setCommitted(buildFilters());
    setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
  }

  const key =
    committed !== null
      ? `/api/task-completions?${[committed, `limit=${tabloDurumu.boy}`, `offset=${offset}`]
          .filter(Boolean)
          .join("&")}`
      : null;
  const { data, error, isLoading } = useSWR<TaskCompletionHistoryResponse>(key, jsonFetcher);

  async function exportCsv() {
    if (committed === null) return;
    const cekim = await fetchAllPaged<TaskCompletionRow>(
      `/api/task-completions?${committed}`,
    );
    setKesildi(cekim.kesildi);
    const items = cekim.items;
    const rows: string[][] = [
      ["Gorev", "Tip", "Tamamlayan", "Zaman", "Foto", "NFC", t("raporNot")],
    ];
    for (const c of items) {
      rows.push([
        c.task_adi ?? "",
        c.kategori_ad,
        userName(c.tamamlayan_user_id),
        c.tamamlanma_zamani,
        c.foto_var ? t("raporVar") : t("raporYok"),
        c.nfc_dogrulandi ? t("ortakEvet") : t("ortakHayir"),
        c.notlar ?? "",
      ]);
    }
    csvDownload("gorev-gecmisi.csv", rows);
  }

  const kategoriSecenekleri = (kategoriler?.items ?? []).map((k) => (
    <option key={k.id} value={k.id}>
      {k.ad}
    </option>
  ));
  const kisiSecenekleri = (users?.items ?? []).map((u) => (
    <option key={u.id} value={u.id}>
      {u.ad}
    </option>
  ));

  const kolonlar: Kolon<TaskCompletionRow>[] = useMemo(
    () => [
      {
        id: "gorev",
        baslik: t("raporGorev"),
        gizlenebilir: false,
        hucre: (c) => c.task_adi ?? "—",
      },
      {
        id: "tip",
        baslik: t("raporTabloTip"),
        // Kategori adlari SUNUCU VERISIDIR — cevrilmez, oldugu gibi.
        hucre: (c) => <Rozet durum={D_NOTR}>{c.kategori_ad}</Rozet>,
      },
      {
        id: "tamamlayan",
        baslik: t("raporTabloTamamlayan"),
        hucre: (c) => userName(c.tamamlayan_user_id),
      },
      {
        id: "zaman",
        baslik: t("raporTabloZaman"),
        hucre: (c) => formatDateTime(c.tamamlanma_zamani),
      },
      {
        id: "foto",
        baslik: t("raporTabloFoto"),
        darEkrandaGizle: true,
        hucre: (c) =>
          c.foto_var ? <Rozet durum={D_OLUMLU}>{t("raporVar")}</Rozet> : t("raporYok"),
      },
      {
        id: "nfc",
        baslik: t("raporTabloNfc"),
        darEkrandaGizle: true,
        // (P160) EskiDEN yalniz bir "✓" isareti vardi: ekran okuyucu
        // "onay isareti" der ya da hic okumaz, ve olumsuz durum "—" ile
        // anlatiliyordu. Ikisi de METIN degildi. Artik Evet/Hayir.
        hucre: (c) =>
          c.nfc_dogrulandi ? (
            <Rozet durum={D_OLUMLU}>{t("ortakEvet")}</Rozet>
          ) : (
            t("ortakHayir")
          ),
      },
      {
        id: "not",
        baslik: t("raporNot"),
        darEkrandaGizle: true,
        hucre: (c) => c.notlar ?? "—",
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, users],
  );

  return (
    <div className="space-y-6">
      <ReportsTabs />
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("raporGorevGecmisiBaslik")}
      </h1>

      <EksikVeriUyarisi
        mesaj={usersErr || kategorilerErr ? t("ortakSecenekYuklenemedi") : null}
      />

      <Kart>
        <form onSubmit={submit} className="flex flex-wrap items-end gap-3">
          {/* (P160) TEK BILESEN + TUTARLILIK KURALI. Iki alan ayri
              dururken bitisi baslangictan once secen kullanici BOS bir
              rapor aliyor ve sebebini goremiyordu. */}
          <TarihAraligi
            tip="datetime-local"
            ipucu={t("ortakYerelSaatOpsiyonel")}
            baslangic={bas}
            bitis={bit}
            onBaslangic={setBas}
            onBitis={setBit}
          />
          <div className="w-full sm:w-52">
            <AlanSarmal etiket={t("gorevKategoriAlan")}>
              {(b) => (
                <Secim
                  {...b}
                  value={kategoriId}
                  onChange={(e) => setKategoriId(e.target.value)}
                >
                  <option value="">{t("ortakTumu")}</option>
                  {kategoriSecenekleri}
                </Secim>
              )}
            </AlanSarmal>
          </div>
          <div className="w-full sm:w-52">
            <AlanSarmal etiket={t("raporTamamlayanOpsiyonel")}>
              {(b) => (
                <Secim
                  {...b}
                  value={tamamlayan}
                  onChange={(e) => setTamamlayan(e.target.value)}
                >
                  <option value="">{t("ortakTumu")}</option>
                  {kisiSecenekleri}
                </Secim>
              )}
            </AlanSarmal>
          </div>
          {/* Aralik TERSKEN istek ATILMAZ: bos bir rapor gostermek,
              kullaniciya "kayit yok" demek olurdu. */}
          <Dugme tur="birincil" type="submit" disabled={!aralikGecerli(bas, bit)}>
            {t("raporGetir")}
          </Dugme>
        </form>
      </Kart>

      {/* (P65) Cekim ust sinira takildi: rapor EKSIKTIR. */}
      {kesildi && (
        <p role="status" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}>
          {t("raporKesildi")}
        </p>
      )}
      {committed === null && (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("raporFiltreSecin")}
        </p>
      )}

      {committed !== null && (
        <>
          {data && (
            <div className="grid gap-3 md:grid-cols-5">
              <Kpi deger={data.ozet.toplam} etiket={t("raporToplamTamamlama")} />
              {data.ozet.kalemler.map((k, i) => (
                <Kpi
                  key={k.kategori_ad}
                  deger={k.sayi}
                  etiket={k.kategori_ad}
                  durum={HALKA_DONGUSU[i % HALKA_DONGUSU.length]}
                />
              ))}
            </div>
          )}

          <section className="space-y-2">
            <div className="flex items-center justify-between">
              <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
                {t("raporTamamlamalar")}
              </h2>
              <Dugme
                boy="kucuk"
                onClick={() => void exportCsv()}
                disabled={(data?.items.length ?? 0) === 0}
              >
                {t("raporCsvIndir")}
              </Dugme>
            </div>
            <VeriTablosu<TaskCompletionRow>
              kolonlar={kolonlar}
              satirlar={data?.items ?? []}
              satirId={(c) => c.id}
              hata={error ? error.message : null}
              yukleniyor={isLoading && !data}
              bosBaslik={t("raporTamamlamaYok")}
              bosAciklama={t("raporSonucYok")}
              sunucuTarafli
              toplam={data?.meta?.total ?? 0}
              durum={tabloDurumu}
              onDurumDegisti={setTabloDurumu}
            />
          </section>
        </>
      )}
    </div>
  );
}
