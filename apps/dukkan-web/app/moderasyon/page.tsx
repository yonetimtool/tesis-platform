"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";

import { api, hataMetni, jetonAl } from "@/lib/istemci";

/**
 * ==========================================================================
 * MODERASYON — TEK EKRAN
 * ==========================================================================
 * `03-guven-ve-fraud.md` §5.4: "moderasyon kuyrugu — yeni isletme
 * basvurulari + bekleyen yorumlar + sikayetler. GUNDE BIR KEZ, TEK
 * EKRANDAN."
 *
 * Uc ayri sayfa yapmak, gunde 20-30 dakikalik bir isi bir saate
 * cikarirdi. Sekmeler ayni sayfada ve her sekmenin sayaci gorunuyor:
 * moderator neye bakacagini ACMADAN once biliyor.
 *
 * ASKI ADAYLARI DORDUNCU SEKME ve ilk sirada degil: bos oldugunda
 * dikkat cekmemeli, DOLU oldugunda ise sayac kirmizi.
 */
type Basvuru = {
  id: string;
  ad: string;
  telefon: string;
  telefon_dogrulandi_at: string | null;
  vergi_no: string | null;
  kategoriler: string[];
  hizmet_alani_sayisi: number;
  belge_sayisi: number;
  bekleyen_belge: number;
  vergi_levhasi_sayisi: number;
  sahip_telefon: string;
};

type Yorum = {
  id: string;
  kaynak: string;
  puan: number;
  metin: string | null;
  supheli_sebep: string | null;
  dogrulanmis: boolean;
  isletme: string;
  yazan_telefon: string;
  yazan_yorum_sayisi: number;
};

type Sikayet = {
  id: string;
  tip: string;
  metin: string;
  iletisim: string | null;
  isletme: string | null;
  isletme_slug: string | null;
  odeme_sikayet_sayisi: number;
  created_at: string;
};

type Aday = {
  id: string;
  ad: string;
  slug: string;
  acik_odeme_sikayeti: number;
};

type Sekme = "basvuru" | "yorum" | "sikayet" | "aski";

const SUPHE: Record<string, string> = {
  dogrulanmamis_olumsuz: "Doğrulanmamış iş + olumsuz puan",
};

export default function Moderasyon() {
  const yonlendir = useRouter();
  const [sekme, setSekme] = useState<Sekme>("basvuru");
  const [basvurular, setBasvurular] = useState<Basvuru[]>([]);
  const [yorumlar, setYorumlar] = useState<Yorum[]>([]);
  const [sikayetler, setSikayetler] = useState<Sikayet[]>([]);
  const [adaylar, setAdaylar] = useState<Aday[]>([]);
  const [hata, setHata] = useState<string | null>(null);
  const [bilgi, setBilgi] = useState<string | null>(null);

  const yukle = useCallback(async () => {
    const [b, y, s, a] = await Promise.all([
      api<{ items: Basvuru[] }>("/moderasyon/kuyruk"),
      api<{ items: Yorum[] }>("/moderasyon/yorum-kuyrugu"),
      api<{ items: Sikayet[] }>("/moderasyon/sikayet-kuyrugu"),
      api<{ items: Aday[] }>("/moderasyon/aski-adaylari"),
    ]);
    setBasvurular(b.items);
    setYorumlar(y.items);
    setSikayetler(s.items);
    setAdaylar(a.items);
  }, []);

  useEffect(() => {
    if (!jetonAl()) {
      yonlendir.replace("/giris");
      return;
    }
    yukle().catch((h) => setHata(hataMetni(h)));
  }, [yukle, yonlendir]);

  async function calistir(is: () => Promise<unknown>, basari: string) {
    setHata(null);
    setBilgi(null);
    try {
      await is();
      await yukle();
      setBilgi(basari);
    } catch (h) {
      setHata(hataMetni(h));
    }
  }

  /** Gerekce isteyen kararlarda ONCE gerekceyi al. */
  function gerekceIste(baslik: string): string | null {
    const g = window.prompt(baslik);
    return g && g.trim() ? g.trim() : null;
  }

  const sekmeler: [Sekme, string, number][] = [
    ["basvuru", "Başvurular", basvurular.length],
    ["yorum", "Yorumlar", yorumlar.length],
    ["sikayet", "Şikâyetler", sikayetler.length],
    ["aski", "Askı adayları", adaylar.length],
  ];

  return (
    <main className="mx-auto max-w-4xl px-4 py-10">
      <h1 className="text-2xl font-bold text-marka-koyu">Moderasyon</h1>

      <div className="mt-6 flex flex-wrap gap-2 border-b border-[color:var(--dk-cizgi)]">
        {sekmeler.map(([id, ad, n]) => (
          <button
            key={id}
            onClick={() => setSekme(id)}
            className={`-mb-px border-b-2 px-3 py-2 text-sm ${
              sekme === id
                ? "border-marka font-medium text-marka-koyu"
                : "border-transparent text-[color:var(--dk-metin-soluk)]"
            }`}
          >
            {ad}{" "}
            <span
              className={`rounded px-1.5 text-xs ${
                // ASKI ADAYLARI DOLUYSA KIRMIZI: burada bekleyen her gun
                // yeni magdur demek (03-guven §5.4 "acil: ayni gun").
                id === "aski" && n > 0
                  ? "bg-red-100 text-red-900"
                  : "bg-[color:var(--dk-zemin-alt)]"
              }`}
            >
              {n}
            </span>
          </button>
        ))}
      </div>

      {bilgi && (
        <p className="mt-4 rounded bg-emerald-50 px-3 py-2 text-sm text-emerald-900">
          {bilgi}
        </p>
      )}
      {hata && (
        <p className="mt-4 rounded bg-red-50 px-3 py-2 text-sm text-red-800">
          {hata}
        </p>
      )}

      {/* ---------------- BASVURULAR ---------------- */}
      {sekme === "basvuru" && (
        <ul className="mt-6 space-y-3">
          {basvurular.length === 0 && (
            <p className="text-[color:var(--dk-metin-soluk)]">
              Bekleyen başvuru yok.
            </p>
          )}
          {basvurular.map((b) => (
            <li
              key={b.id}
              className="rounded border border-[color:var(--dk-cizgi)] p-4"
            >
              <h2 className="font-medium text-marka-koyu">{b.ad}</h2>
              {/* KARAR ICIN GEREKEN HER SEY TEK SATIRDA — moderator her
                  basvuru icin ayri sayfa acmak zorunda kalmamali. */}
              <dl className="mt-2 grid gap-x-6 gap-y-1 text-sm sm:grid-cols-2">
                <div>
                  <dt className="inline text-[color:var(--dk-metin-soluk)]">
                    Telefon:{" "}
                  </dt>
                  <dd className="inline">
                    {b.telefon}{" "}
                    {b.telefon_dogrulandi_at ? "✔ doğrulandı" : "✗ doğrulanmadı"}
                  </dd>
                </div>
                <div>
                  <dt className="inline text-[color:var(--dk-metin-soluk)]">
                    Vergi levhası:{" "}
                  </dt>
                  <dd className="inline">
                    {b.vergi_levhasi_sayisi > 0
                      ? `yüklendi (${b.bekleyen_belge} incelenmedi)`
                      : "yok"}
                  </dd>
                </div>
                <div>
                  <dt className="inline text-[color:var(--dk-metin-soluk)]">
                    Vergi no:{" "}
                  </dt>
                  <dd className="inline">{b.vergi_no ?? "—"}</dd>
                </div>
                <div>
                  <dt className="inline text-[color:var(--dk-metin-soluk)]">
                    Bölge:{" "}
                  </dt>
                  <dd className="inline">{b.hizmet_alani_sayisi} mahalle</dd>
                </div>
                <div className="sm:col-span-2">
                  <dt className="inline text-[color:var(--dk-metin-soluk)]">
                    Hizmetler:{" "}
                  </dt>
                  <dd className="inline">{b.kategoriler.join(", ") || "—"}</dd>
                </div>
              </dl>
              <div className="mt-3 flex flex-wrap gap-2">
                <button
                  onClick={() =>
                    calistir(
                      () =>
                        api(`/moderasyon/isletme/${b.id}/karar`, {
                          metot: "POST",
                          govde: { karar: "onayla" },
                        }),
                      "İşletme onaylandı.",
                    )
                  }
                  className="rounded bg-marka px-3 py-2 text-sm text-white"
                >
                  Onayla
                </button>
                <button
                  onClick={() => {
                    const g = gerekceIste("Ret gerekçesi (işletmeye gösterilir):");
                    if (!g) return;
                    calistir(
                      () =>
                        api(`/moderasyon/isletme/${b.id}/karar`, {
                          metot: "POST",
                          govde: { karar: "reddet", gerekce: g },
                        }),
                      "Reddedildi.",
                    );
                  }}
                  className="rounded border border-[color:var(--dk-cizgi)] px-3 py-2 text-sm"
                >
                  Reddet
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      {/* ---------------- YORUMLAR ---------------- */}
      {sekme === "yorum" && (
        <ul className="mt-6 space-y-3">
          {yorumlar.length === 0 && (
            <p className="text-[color:var(--dk-metin-soluk)]">
              Bekleyen yorum yok.
            </p>
          )}
          {yorumlar.map((y) => (
            <li
              key={y.id}
              className="rounded border border-[color:var(--dk-cizgi)] p-4"
            >
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="font-medium">{y.isletme}</span>
                <span>{"★".repeat(y.puan)}</span>
              </div>
              {/* SUPHE SEBEBI GORUNUR: moderator NEDEN kuyrukta oldugunu
                  bilmeden karar veremez. */}
              <p className="mt-1 text-xs text-amber-900">
                Kuyruğa düşme sebebi:{" "}
                {SUPHE[y.supheli_sebep ?? ""] ?? y.supheli_sebep ?? "—"}
                {" · "}
                {y.dogrulanmis ? "doğrulanmış iş" : "doğrulanmamış"}
                {" · "}
                yazarın toplam yorumu: {y.yazan_yorum_sayisi}
              </p>
              {y.metin && <p className="mt-2 text-sm">{y.metin}</p>}
              <div className="mt-3 flex flex-wrap gap-2">
                <button
                  onClick={() =>
                    calistir(
                      () =>
                        api(`/moderasyon/yorum/${y.id}/karar`, {
                          metot: "POST",
                          govde: { karar: "yayinla" },
                        }),
                      "Yorum yayınlandı.",
                    )
                  }
                  className="rounded bg-marka px-3 py-2 text-sm text-white"
                >
                  Yayınla
                </button>
                <button
                  onClick={() => {
                    const g = gerekceIste("Ret gerekçesi:");
                    if (!g) return;
                    calistir(
                      () =>
                        api(`/moderasyon/yorum/${y.id}/karar`, {
                          metot: "POST",
                          govde: { karar: "reddet", not_metni: g },
                        }),
                      "Yorum reddedildi.",
                    );
                  }}
                  className="rounded border border-[color:var(--dk-cizgi)] px-3 py-2 text-sm"
                >
                  Reddet
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      {/* ---------------- SIKAYETLER ---------------- */}
      {sekme === "sikayet" && (
        <ul className="mt-6 space-y-3">
          {sikayetler.length === 0 && (
            <p className="text-[color:var(--dk-metin-soluk)]">
              Açık şikâyet yok.
            </p>
          )}
          {sikayetler.map((s) => (
            <li
              key={s.id}
              className="rounded border border-[color:var(--dk-cizgi)] p-4"
            >
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="font-medium">{s.isletme ?? "İşletme yok"}</span>
                <span className="rounded bg-[color:var(--dk-zemin-alt)] px-2 py-0.5 text-xs">
                  {s.tip}
                </span>
              </div>
              {/* ORUNTU: tek sikayete degil, tekrara bakilmali. */}
              {s.odeme_sikayet_sayisi > 1 && (
                <p className="mt-1 text-xs font-medium text-red-900">
                  Bu işletme için {s.odeme_sikayet_sayisi} ödeme şikâyeti var
                </p>
              )}
              <p className="mt-2 text-sm">{s.metin}</p>
              {s.iletisim && (
                <p className="mt-1 text-xs text-[color:var(--dk-metin-soluk)]">
                  İletişim: {s.iletisim}
                </p>
              )}
              <div className="mt-3 flex flex-wrap gap-2">
                <button
                  onClick={() =>
                    calistir(
                      () =>
                        api(`/moderasyon/sikayet/${s.id}/karar`, {
                          metot: "POST",
                          govde: { durum: "incelemede" },
                        }),
                      "İncelemeye alındı.",
                    )
                  }
                  className="rounded border border-[color:var(--dk-cizgi)] px-3 py-2 text-sm"
                >
                  İncelemeye al
                </button>
                <button
                  onClick={() => {
                    const g = gerekceIste("Sonuç (kayda geçer):");
                    if (!g) return;
                    calistir(
                      () =>
                        api(`/moderasyon/sikayet/${s.id}/karar`, {
                          metot: "POST",
                          govde: { durum: "kapandi", sonuc: g },
                        }),
                      "Şikâyet kapatıldı.",
                    );
                  }}
                  className="rounded bg-marka px-3 py-2 text-sm text-white"
                >
                  Kapat
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      {/* ---------------- ASKI ADAYLARI ---------------- */}
      {sekme === "aski" && (
        <div className="mt-6">
          {/* NEDEN OTOMATIK DEGIL — moderator bunu bilmeli. */}
          <p className="rounded bg-[color:var(--dk-zemin-alt)] px-3 py-2 text-sm text-[color:var(--dk-metin-soluk)]">
            Ödeme şikâyeti eşiğini geçen işletmeler. Askı <strong>otomatik
            değil</strong>: şikâyet kimliksiz yapılabildiği için üç sahte
            şikâyetle bir işletmeyi kapatmak ucuz olurdu. Karar sizde — ama
            <strong> aynı gün</strong> bakın.
          </p>
          <ul className="mt-4 space-y-3">
            {adaylar.length === 0 && (
              <p className="text-[color:var(--dk-metin-soluk)]">
                Eşiği geçen işletme yok.
              </p>
            )}
            {adaylar.map((a) => (
              <li
                key={a.id}
                className="rounded border border-red-200 bg-red-50/40 p-4"
              >
                <h2 className="font-medium">{a.ad}</h2>
                <p className="mt-1 text-sm text-red-900">
                  {a.acik_odeme_sikayeti} açık ödeme şikâyeti
                </p>
                <button
                  onClick={() => {
                    const g = gerekceIste("Askı gerekçesi (işletmeye gösterilir):");
                    if (!g) return;
                    calistir(
                      () =>
                        api(`/moderasyon/isletme/${a.id}/karar`, {
                          metot: "POST",
                          govde: { karar: "askiya_al", gerekce: g },
                        }),
                      "İşletme askıya alındı.",
                    );
                  }}
                  className="mt-3 rounded bg-red-700 px-3 py-2 text-sm text-white"
                >
                  Askıya al
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </main>
  );
}
