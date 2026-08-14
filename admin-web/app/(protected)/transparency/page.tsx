"use client";

import { useEffect, useState } from "react";
import useSWR from "swr";

import {
  BosDurum,
  AlanSarmal,
  HataDurumu,
  IskeletMetin,
  Secim,
} from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { kurusToTL } from "@/lib/money";
import type { TransparencyBoard, TransparencyList } from "@/lib/types";
import { useI18n } from "@/lib/i18n/kullan";

/// "2026-07" -> aktif dilde "Temmuz 2026" / "July 2026" / "يوليو 2026".
///
/// AY ADLARI SOZLUKTE DEGIL: `Intl` zaten 7 dilin hepsini biliyor; 12 ay x 7
/// dil elle yazmak hem gereksiz hem de yerellestirme kurallarini (Rusca'da
/// tamlayan hali gibi) yeniden uydurmak olurdu.
function ayBaslik(ay: string, dil: string): string {
  const [y, m] = ay.split("-");
  const i = Number(m);
  if (!(i >= 1 && i <= 12)) return ay;
  const ad = new Intl.DateTimeFormat(dil, { month: "long" }).format(
    new Date(Date.UTC(2000, i - 1, 1)),
  );
  return `${ad} ${y}`;
}

// (P48) UCUNCU PARA BICIMLENDIRICISI KALDIRILDI.
//
// Burada `... TL` yazan ozel bir `tl()` vardi; panelin geri kalani
// `kurusToTL` ile `... ₺` yaziyordu — ayni deger iki sayfada iki farkli
// bicimde gorunuyordu. Ayrica bu surum `toLocaleString`in DAR BOSLUKLU
// (U+00A0) ciktisini nokta ile yamiyordu: yama, kucuk-ICU ortamindaki
// asil sorunu (VIRGULLU gruplama) hic cozmuyordu.
//
// Artik tek kaynak `lib/money.ts`tir ve ICU'ya hic bagimli degildir.
const tl = kurusToTL;

export default function TransparencyPage() {
  const { t, dil } = useI18n();
  const list = useSWR<TransparencyList>("/api/transparency", jsonFetcher);
  const [ay, setAy] = useState<string>("");

  const months = list.data?.items ?? [];
  useEffect(() => {
    const items = list.data?.items ?? [];
    if (!ay && items.length > 0) setAy(items[0].ay);
  }, [ay, list.data]);

  const board = useSWR<TransparencyBoard>(
    ay ? `/api/transparency/${ay}` : null,
    jsonFetcher,
  );
  const b = board.data;

  return (
    <div className="space-y-5">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("seffafPano")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("seffafAciklama")}</p>
      </div>

      {list.error && <HataDurumu mesaj={t("seffafAylarYuklenemedi")} />}
      {list.isLoading && !list.data && (
        <IskeletMetin satir={3} />
      )}

      {list.data && months.length === 0 && (
        <BosDurum baslik={t("seffafVeriYok")} aciklama={t("seffafVeriYokAlt")} />
      )}

      {months.length > 0 && (
        <>
          <div className="w-full sm:w-64">
            <AlanSarmal etiket={t("ortakDonem")}>
  {(b) => (
    <Secim {...b} value={ay}
                onChange={(e) => setAy(e.target.value)}
              >
                {months.map((m) => (
                  <option key={m.ay} value={m.ay}>
                    {ayBaslik(m.ay, dil)}
                    {m.yayinlandi ? "" : ` • ${t("seffafTaslak")}`}
                  </option>
                ))}</Secim>
  )}
</AlanSarmal>
          </div>

          {board.error && <HataDurumu mesaj={t("seffafOzetYuklenemedi")} />}
          {b && (
            <div className="grid gap-4 lg:grid-cols-2 [&>*]:min-w-0">
              {/* Özet */}
              <div className="rounded-kart border kart-kenar bg-white p-5">
                <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                  <h2 className="min-w-0 font-medium break-words">
                    {t("seffafOzetBasligi", { ay: ayBaslik(b.ay, dil) })}
                  </h2>
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      b.yayinlandi
                        ? "bg-emerald-100 text-emerald-800"
                        : "bg-slate-100 text-metin-body"
                    }`}
                  >
                    {b.yayinlandi ? t("seffafYayinda") : t("seffafTaslak")}
                  </span>
                </div>
                <dl className="space-y-1.5 text-sm">
                  <Row k={t("seffafToplamGelir")} v={tl(b.toplam_gelir_kurus)} cls="text-emerald-700" />
                  <Row k={t("seffafToplamGider")} v={tl(b.toplam_gider_kurus)} cls="text-red-700" />
                  {/* `dl` yalniz `dt`/`dd` (ve onlari saran `div`) icerir;
                      ciplak ayrac `div`i axe'in `definition-list` kuralini
                      kiriyordu (tur 30). Ayirici gorsel — `dd`ye tasindi. */}
                  <Row
                    ayrac
                    k={t("seffafNet")}
                    v={tl(b.net_kurus)}
                    cls={b.net_kurus >= 0 ? "text-emerald-700 font-semibold" : "text-red-700 font-semibold"}
                  />
                </dl>
                {/* NOT `dl` DISINDA: `dl` yalniz dt/dd ciftleri (ve onlari
                    saran div) icerebilir — dt/dd tasimayan CIPLAK bir div de
                    gecersizdir. Ilk denemede `p`yi `div` yapmak yetmemisti;
                    ogeyi listenin DISINA almak gerekti (tur 30/31). */}
                {b.onceki_ay_net_kurus != null && (
                  <p className="pt-1 text-xs text-metin-muted">
                    {t("seffafOncekiAyNet", { tutar: tl(b.onceki_ay_net_kurus) })}
                  </p>
                )}
              </div>

              {/* Aidat */}
              <div className="rounded-kart border kart-kenar bg-white p-5">
                <h2 className="mb-3 font-medium">{t("seffafAidatToplama")}</h2>
                {b.aidat.daire_orani_yuzde == null ? (
                  <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("seffafTahakkukYok")}</p>
                ) : (
                  <>
                    <div className="mb-1 flex justify-between text-sm">
                      <span>
                        {t("seffafOdeyenDaire", { odeyen: b.aidat.odeyen_daire, toplam: b.aidat.toplam_daire })}
                      </span>
                      <span className="font-semibold">%{b.aidat.daire_orani_yuzde}</span>
                    </div>
                    <Bar value={b.aidat.daire_orani_yuzde} />
                    <p className="mt-2 text-xs text-metin-muted">
                      {t("seffafTahsilatOrani", {
                        tahsil: tl(b.aidat.tahsilat_kurus),
                        tahakkuk: tl(b.aidat.tahakkuk_kurus),
                        oran: b.aidat.tutar_orani_yuzde ?? 0,
                      })}
                    </p>
                  </>
                )}
                <p className="mt-3 text-sm">
                  {t("seffafGecikenDaire", { sayi: b.aidat.geciken_daire_sayisi })}
                </p>
              </div>

              {/* Gider dağılımı */}
              <div className="rounded-kart border kart-kenar bg-white p-5 lg:col-span-2">
                <h2 className="mb-3 font-medium">{t("seffafGiderDagilimi")}</h2>
                {b.gider_dagilimi.length === 0 ? (
                  <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("seffafGiderYok")}</p>
                ) : (
                  <div className="space-y-3">
                    {b.gider_dagilimi.map((k) => (
                      <div key={k.ad}>
                        <div className="mb-1 flex justify-between text-sm">
                          <span>{k.ad}</span>
                          <span className="text-metin-muted">
                            %{k.yuzde} · {tl(k.toplam_kurus)}
                          </span>
                        </div>
                        <Bar value={k.yuzde} indigo />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function Row({
  k,
  v,
  cls,
  ayrac,
}: {
  k: string;
  v: string;
  cls?: string;
  ayrac?: boolean;
}) {
  return (
    <div
      className={`flex justify-between${ayrac ? " mt-2 border-t border-yuzey-divider pt-2" : ""}`}
    >
      <dt className="text-metin-body">{k}</dt>
      <dd className={cls}>{v}</dd>
    </div>
  );
}

function Bar({ value, indigo }: { value: number; indigo?: boolean }) {
  const pct = Math.max(0, Math.min(100, value));
  const color = indigo ? "bg-indigo-500" : pct >= 80 ? "bg-emerald-500" : "bg-amber-500";
  return (
    <div className="h-1.5 w-full overflow-hidden rounded bg-slate-100">
      <div className={`h-full ${color}`} style={{ width: `${pct}%` }} />
    </div>
  );
}
