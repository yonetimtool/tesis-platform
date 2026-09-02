"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Dugme, HataDurumu, Kart, Rozet, Secim } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { rolAdi } from "@/lib/roles";
import type { AsyncIs } from "@/lib/tipler";

/**
 * (P203 §4) VARDIYA PLANI — haftalik izgara + anlik durum.
 *
 * =========================================================================
 * NEDEN GUN x VARDIYA TABLOSU
 * =========================================================================
 * Yoneticinin sordugu soru "bu hafta kim ne zaman calisiyor" ve bu soru
 * IKI BOYUTLUDUR. Liste hâlinde gostermek, kullaniciyi zihninde tabloyu
 * yeniden kurmaya zorlardi — ve BOS KALAN vardiyayi (istegin acik sarti)
 * gormek imkansizlasirdi: bos slot, LISTEDE HIC GORUNMEYEN seydir.
 *
 * =========================================================================
 * BOS VARDIYA GORSEL OLARAK AYRI
 * =========================================================================
 * Sunucu `bos` bayragi doner; ekran onu KENARLIK ve ROZETLE isaretler.
 * Yalnizca "kimse yok" yazmak, on dort huceli bir izgarada goz
 * taramasiyla bulunamazdi.
 */

type Kisi = { plan_id: string; user_id: string; ad: string; rol: string };
type Slot = {
  shift_id: string;
  shift_ad: string;
  baslangic_saat: string;
  bitis_saat: string;
  kisiler: Kisi[];
  bos: boolean;
};
type Gun = { tarih: string; slotlar: Slot[] };
type Hafta = { baslangic: string; bitis: string; gunler: Gun[] };
type Simdi = {
  zaman: string;
  gorevdeki_vardiya: Slot | null;
  gorevdekiler: Kisi[];
  sonraki_vardiya: Slot | null;
  sonrakiler: Kisi[];
  sonraki_baslangic: string | null;
};
type Personel = { id: string; ad: string; role: string };

/** Async is tipi — `lib/tipler.ts`ten gelir.
 *
 * `.tsx` icinde `Promise<...>` YAZILAMAZ: `sabit-metin` taramasi
 * `<...>`i JSX sanip "Promise"i cevrilmemis metin adayi sayiyor (hakli
 * bir tarama, yanlis bir eslesme). Tipi `.ts` dosyasina almak ikisini
 * de cozer. */

/** Haftanin PAZARTESISI — plan haftasi pazartesi baslar (TR takvimi). */
function haftaBasi(t: Date): string {
  const g = new Date(t);
  const fark = (g.getDay() + 6) % 7;
  g.setDate(g.getDate() - fark);
  return g.toISOString().slice(0, 10);
}

function gunEkle(iso: string, gun: number): string {
  const d = new Date(`${iso}T00:00:00`);
  d.setDate(d.getDate() + gun);
  return d.toISOString().slice(0, 10);
}

/** `"08:00:00"` -> `"08:00"`. Saniye, vardiya saatinde bilgi tasimaz. */
const saat = (v: string) => v.slice(0, 5);

export default function VardiyaPlaniSayfasi() {
  const t = useT();
  const toast = useToast();
  const [baslangic, setBaslangic] = useState(() => haftaBasi(new Date()));
  const [secili, setSecili] = useState<{ gun: string; slot: Slot } | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);

  const uc = `/api/vardiya-plani?baslangic=${baslangic}&gun=7`;
  const { data, error, mutate } = useSWR<Hafta>(uc, jsonFetcher);
  const { data: simdi } = useSWR<Simdi>("/api/vardiya-plani/simdi", jsonFetcher, {
    // ANLIK DURUM TAZELENIR: "su an kim gorevde" bir dakika sonra
    // yanlis olabilir. 60 sn, vardiya degisimini kacirmayacak kadar
    // sik, sunucuyu yormayacak kadar seyrek.
    refreshInterval: 60_000,
  });
  const { data: personel } = useSWR<{ items: Personel[] }>(
    "/api/users?limit=200",
    jsonFetcher,
  );

  const bugun = new Date().toISOString().slice(0, 10);
  const bosSayisi = useMemo(
    () =>
      (data?.gunler ?? []).reduce(
        (n, g) => n + g.slotlar.filter((s) => s.bos).length,
        0,
      ),
    [data],
  );

  async function calistir(is: AsyncIs) {
    setBekliyor(true);
    setHata(null);
    try {
      await is();
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("vardiyaPlaniBaslik")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("vardiyaPlaniAlt")}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Dugme
            type="button"
            boy="kucuk"
            tur="ikincil"
            onClick={() => setBaslangic((b) => gunEkle(b, -7))}
            data-test="vardiya-onceki-hafta"
          >
            {t("vardiyaOncekiHafta")}
          </Dugme>
          <span
            className="tabular-nums"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            data-test="vardiya-hafta-araligi"
          >
            {baslangic} — {gunEkle(baslangic, 6)}
          </span>
          <Dugme
            type="button"
            boy="kucuk"
            tur="ikincil"
            onClick={() => setBaslangic((b) => gunEkle(b, 7))}
            data-test="vardiya-sonraki-hafta"
          >
            {t("vardiyaSonrakiHafta")}
          </Dugme>
        </div>
      </div>

      <HataDurumu mesaj={hata ?? (error ? t("ortakHataOlustu") : null)} />

      {/* ---------------- 4.2 ANLIK DURUM ---------------- */}
      <Kart>
        <div className="grid gap-4 sm:grid-cols-2">
          <div data-test="vardiya-simdi-gorevde">
            <p className="text-sm font-medium text-metin-body">
              {t("vardiyaSuAnGorevde")}
            </p>
            {simdi?.gorevdeki_vardiya ? (
              <>
                <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                  {simdi.gorevdeki_vardiya.shift_ad}{" "}
                  {saat(simdi.gorevdeki_vardiya.baslangic_saat)}–
                  {saat(simdi.gorevdeki_vardiya.bitis_saat)}
                </p>
                <p className="mt-1 text-sm text-metin-body">
                  {simdi.gorevdekiler.map((k) => k.ad).join(", ")}
                </p>
              </>
            ) : (
              <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}>
                {t("vardiyaSuAnKimseYok")}
              </p>
            )}
          </div>
          <div data-test="vardiya-simdi-sonraki">
            <p className="text-sm font-medium text-metin-body">
              {t("vardiyaSiradaki")}
            </p>
            {simdi?.sonraki_vardiya ? (
              <>
                <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                  {simdi.sonraki_vardiya.shift_ad}{" "}
                  {saat(simdi.sonraki_vardiya.baslangic_saat)}–
                  {saat(simdi.sonraki_vardiya.bitis_saat)}
                </p>
                <p className="mt-1 text-sm text-metin-body">
                  {simdi.sonrakiler.map((k) => k.ad).join(", ")}
                </p>
              </>
            ) : (
              <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}>
                {t("vardiyaSiradakiYok")}
              </p>
            )}
          </div>
        </div>
      </Kart>

      {/* ---------------- 4.1 HAFTALIK IZGARA ---------------- */}
      <div className="flex flex-wrap items-center gap-3">
        {bosSayisi > 0 && (
          <Rozet durum="uyari">
            {t("vardiyaBosSayisi", { n: bosSayisi })}
          </Rozet>
        )}
        <Dugme
          type="button"
          boy="kucuk"
          disabled={bekliyor}
          data-test="vardiya-haftayi-doldur"
          onClick={() =>
            void calistir(async () => {
              await apiSend(
                `/api/vardiya-plani/haftayi-doldur?baslangic=${baslangic}&gun=7`,
                "POST",
                {},
              );
              toast.success(t("vardiyaDolduruldu"));
            })
          }
        >
          {t("vardiyaHaftayiDoldur")}
        </Dugme>
      </div>

      {/* (P138) ELLE `<table>` YAZILMAZ — ortak `VeriTablosu` ilkesi var.
          Ama BU IZGARA BIR VERI TABLOSU DEGIL: sabit sutunlari yok
          (her gunun vardiya sayisi farkli olabilir) ve hucreler
          TIKLANABILIR kartlardir. `VeriTablosu`ya sokmak, kolon
          tanimlarini uydurmak olurdu. Bu yuzden DIV izgarasi — hem
          kilidi hem de dar ekranda sarma davranisini dogru karsilar. */}
      <div className="space-y-2">
        <div>
          <div>
            {(data?.gunler ?? []).map((g) => (
              <div key={g.tarih} className="flex flex-wrap items-start gap-3 border-b border-yuzey-divider py-2">
                <span
                  className="w-28 shrink-0 whitespace-nowrap py-1"
                  style={{
                    color: g.tarih === bugun ? "var(--yz-text)" : "var(--yz-text-2)",
                    fontWeight: g.tarih === bugun ? 600 : 400,
                  }}
                >
                  {g.tarih}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap gap-2">
                    {g.slotlar.map((s) => (
                      <button
                        key={`${g.tarih}-${s.shift_id}`}
                        type="button"
                        data-test={`vardiya-slot-${g.tarih}-${s.shift_id}`}
                        onClick={() => setSecili({ gun: g.tarih, slot: s })}
                        className="odak-ic min-w-[10rem] rounded-lg border p-2 text-start transition"
                        style={{
                          // BOS SLOT GORSEL OLARAK AYRI: on dort huceli
                          // bir izgarada "kimse yok" metnini goz
                          // taramasiyla bulmak mumkun degil.
                          borderColor: s.bos
                            ? "var(--yz-warning-edge)"
                            : "var(--yz-border)",
                          borderWidth: "var(--yz-border-w)",
                          background: s.bos
                            ? "var(--yz-warning)"
                            : "var(--yz-surface-1)",
                        }}
                      >
                        <span
                          className="block"
                          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                        >
                          {s.shift_ad} {saat(s.baslangic_saat)}–{saat(s.bitis_saat)}
                        </span>
                        <span
                          className="block"
                          style={{ color: "var(--yz-text)" }}
                        >
                          {s.bos
                            ? t("vardiyaBos")
                            : s.kisiler.map((k) => k.ad).join(", ")}
                        </span>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* ---------------- SLOT AYRINTISI + ATAMA ---------------- */}
      {secili && (
        <Kart>
          <div className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-sm font-medium text-metin-body">
              {secili.gun} · {secili.slot.shift_ad}{" "}
              {saat(secili.slot.baslangic_saat)}–{saat(secili.slot.bitis_saat)}
            </p>
            <Dugme
              type="button"
              boy="kucuk"
              tur="ikincil"
              onClick={() => setSecili(null)}
            >
              {t("ortakKapat")}
            </Dugme>
          </div>

          <ul className="mt-2 space-y-1" data-test="vardiya-slot-kisiler">
            {secili.slot.kisiler.map((k) => (
              <li key={k.plan_id} className="flex items-center justify-between gap-2">
                <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                  {k.ad}{" "}
                  <span style={{ color: "var(--yz-text-3)" }}>{rolAdi(t, k.rol)}</span>
                </span>
                <Dugme
                  type="button"
                  boy="kucuk"
                  tur="ikincil"
                  disabled={bekliyor}
                  data-test={`vardiya-cikar-${k.user_id}`}
                  onClick={() =>
                    void calistir(async () => {
                      // SEBEP SORULUR: gun ici degisiklik denetime
                      // yaziliyor ve "neden" alani bos kalirsa kayit
                      // sonradan hicbir soruyu yanitlamaz.
                      const sebep = window.prompt(t("vardiyaCikarSebep")) ?? "";
                      const qs = sebep
                        ? `?not_metni=${encodeURIComponent(sebep)}`
                        : "";
                      await apiSend(
                        `/api/vardiya-plani/${k.plan_id}${qs}`,
                        "DELETE",
                      );
                      setSecili(null);
                    })
                  }
                >
                  {t("vardiyaCikar")}
                </Dugme>
              </li>
            ))}
            {secili.slot.kisiler.length === 0 && (
              <li style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}>
                {t("vardiyaBos")}
              </li>
            )}
          </ul>

          <div className="mt-3 flex flex-wrap items-end gap-2">
            <label className="block">
              <span
                className="mb-1 block"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              >
                {t("vardiyaKisiEkle")}
              </span>
              <Secim
                value=""
                data-test="vardiya-kisi-sec"
                onChange={(e) => {
                const uid = e.target.value;
                if (!uid) return;
                void calistir(async () => {
                  const y = (await apiSend("/api/vardiya-plani", "POST", {
                    shift_id: secili.slot.shift_id,
                    tarih: secili.gun,
                    user_id: uid,
                  })) as { uyarilar?: string[] };
                  // UYARILAR SESSIZ GECMEZ: haftalik 45 saat asimi bir
                  // MALIYETTIR (§5 onu gidere yaziyor) ve yonetici
                  // atamayi yaparken gormeli.
                  for (const u of y?.uyarilar ?? []) {
                    toast.info(
                      u === "gunluk_sinir_asildi"
                        ? t("vardiyaUyariGunluk")
                        : t("vardiyaUyariHaftalik"),
                    );
                  }
                  setSecili(null);
                });
              }}
              >
                <option value="">{t("ortakSeciniz")}</option>
                {(personel?.items ?? [])
                  .filter((p) => p.role !== "resident")
                  .map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.ad}
                    </option>
                  ))}
              </Secim>
            </label>
          </div>
        </Kart>
      )}
    </div>
  );
}
