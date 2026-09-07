"use client";

import { useParams, useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";

import { api, hataMetni, jetonAl } from "@/lib/istemci";

type Detay = {
  id: string;
  ad: string;
  durum: string;
  dogrulama_seviyesi: number;
  telefon: string;
  telefon_dogrulandi_at: string | null;
  kategoriler: string[];
  hizmet_alanlari: { id: string; ad: string; ilce: string; il: string }[];
};
type Kategori = { ad: string; slug: string; alt: { ad: string; slug: string }[] };
type Mahalle = { id: string; ad: string; slug: string; tip: string };

export default function IsletmeDetay() {
  const { isletmeId } = useParams<{ isletmeId: string }>();
  const yonlendir = useRouter();
  const [d, setD] = useState<Detay | null>(null);
  const [kategoriler, setKategoriler] = useState<Kategori[]>([]);
  const [secili, setSecili] = useState<Set<string>>(new Set());
  const [hata, setHata] = useState<string | null>(null);
  const [bilgi, setBilgi] = useState<string | null>(null);

  // Hizmet alani secimi
  const [il, setIl] = useState("istanbul");
  const [ilce, setIlce] = useState("");
  const [ilceler, setIlceler] = useState<{ ad: string; slug: string }[]>([]);
  const [mahalleler, setMahalleler] = useState<Mahalle[]>([]);
  const [mahalleArama, setMahalleArama] = useState("");
  const [seciliAlan, setSeciliAlan] = useState<Map<string, string>>(new Map());

  const [kod, setKod] = useState("");

  const yukle = useCallback(async () => {
    const v = await api<Detay>(`/isletme/${isletmeId}`);
    setD(v);
    setSecili(new Set(v.kategoriler));
    // Mevcut hizmet alanlarini secime yukle: kullanici bir mahalle daha
    // eklemek istediginde onceki secimi KAYBETMEMELI. Uc TAM LISTE
    // aliyor (PUT), yani eksik gonderim sessizce silme anlamina gelirdi.
    setSeciliAlan(new Map(v.hizmet_alanlari.map((m) => [m.id, `${m.ad} · ${m.ilce}`])));
  }, [isletmeId]);

  useEffect(() => {
    if (!jetonAl()) {
      yonlendir.replace("/giris");
      return;
    }
    yukle().catch((h) => setHata(hataMetni(h)));
    api<{ items: Kategori[] }>("/kategori")
      .then((x) => setKategoriler(x.items))
      .catch(() => setKategoriler([]));
  }, [yukle, yonlendir]);

  useEffect(() => {
    if (!il) return;
    api<{ items: { ad: string; slug: string }[] }>(`/lokasyon/il/${il}/ilce`)
      .then((x) => setIlceler(x.items))
      .catch(() => setIlceler([]));
  }, [il]);

  useEffect(() => {
    if (!il || !ilce) {
      setMahalleler([]);
      return;
    }
    const q = mahalleArama ? `?q=${encodeURIComponent(mahalleArama)}` : "";
    api<{ items: Mahalle[] }>(`/lokasyon/il/${il}/ilce/${ilce}/mahalle${q}`)
      .then((x) => setMahalleler(x.items))
      .catch(() => setMahalleler([]));
  }, [il, ilce, mahalleArama]);

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

  if (!d) {
    return (
      <main className="mx-auto max-w-3xl px-4 py-12">
        {hata ? (
          <p className="rounded bg-red-50 px-3 py-2 text-sm text-red-800">{hata}</p>
        ) : (
          <p>Yükleniyor…</p>
        )}
      </main>
    );
  }

  const telefonOk = d.telefon_dogrulandi_at !== null;
  const kategoriOk = d.kategoriler.length > 0;
  const alanOk = d.hizmet_alanlari.length > 0;
  const hazir = telefonOk && kategoriOk && alanOk;

  return (
    <main className="mx-auto max-w-3xl px-4 py-12">
      <h1 className="text-2xl font-bold text-marka-koyu">{d.ad}</h1>

      {/* BASVURU HAZIRLIK LISTESI — kullanici NE EKSIK'i tek bakista gorsun.
          Eksikleri yalniz basvuru aninda 422 ile soylemek, kullaniciyi
          dene-yanil dongusune sokardi. */}
      <ol className="mt-6 space-y-2">
        {[
          ["İşletme telefonu doğrulandı", telefonOk],
          ["En az bir hizmet seçildi", kategoriOk],
          ["En az bir bölge seçildi", alanOk],
        ].map(([metin, tamam]) => (
          <li key={metin as string} className="flex items-center gap-2 text-sm">
            <span
              aria-hidden
              className={`inline-block h-4 w-4 rounded-full ${
                tamam ? "bg-emerald-500" : "bg-gray-300"
              }`}
            />
            <span className={tamam ? "" : "text-[color:var(--dk-metin-soluk)]"}>
              {metin as string}
            </span>
          </li>
        ))}
      </ol>

      {/* --- TELEFON --- */}
      {!telefonOk && (
        <section className="mt-8 rounded border border-[color:var(--dk-cizgi)] p-4">
          <h2 className="font-medium">İşletme telefonunu doğrula</h2>
          <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
            {d.telefon} numarasına kod göndereceğiz.
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            <button
              onClick={() =>
                calistir(async () => {
                  const y = await api<{ dev_kod?: string }>(
                    `/isletme/${isletmeId}/telefon/kod`,
                    { metot: "POST" },
                  );
                  if (y.dev_kod) setKod(y.dev_kod);
                }, "Kod gönderildi.")
              }
              className="rounded border border-marka px-3 py-2 text-sm text-marka"
            >
              Kod gönder
            </button>
            <input
              value={kod}
              onChange={(e) => setKod(e.target.value)}
              maxLength={6}
              placeholder="6 haneli kod"
              className="rounded border border-[color:var(--dk-cizgi)] px-3 py-2 text-sm"
            />
            <button
              onClick={() =>
                calistir(
                  () =>
                    api(`/isletme/${isletmeId}/telefon/dogrula`, {
                      metot: "POST",
                      govde: { kod },
                    }),
                  "Telefon doğrulandı.",
                )
              }
              className="rounded bg-marka px-3 py-2 text-sm text-white"
            >
              Doğrula
            </button>
          </div>
        </section>
      )}

      {/* --- KATEGORILER --- */}
      <section className="mt-8 rounded border border-[color:var(--dk-cizgi)] p-4">
        <h2 className="font-medium">Verdiğiniz hizmetler</h2>
        <div className="mt-3 space-y-4">
          {kategoriler.map((k) => (
            <div key={k.slug}>
              <h3 className="text-sm font-medium text-marka-koyu">{k.ad}</h3>
              <div className="mt-1 flex flex-wrap gap-2">
                {k.alt.map((a) => {
                  const isaretli = secili.has(a.slug);
                  return (
                    <button
                      key={a.slug}
                      type="button"
                      onClick={() => {
                        const y = new Set(secili);
                        if (isaretli) y.delete(a.slug);
                        else y.add(a.slug);
                        setSecili(y);
                      }}
                      className={`rounded-full border px-3 py-1 text-sm ${
                        isaretli
                          ? "border-marka bg-marka text-white"
                          : "border-[color:var(--dk-cizgi)]"
                      }`}
                    >
                      {a.ad}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
        <button
          onClick={() =>
            calistir(
              () =>
                api(`/isletme/${isletmeId}/kategoriler`, {
                  metot: "PUT",
                  govde: { slugler: Array.from(secili) },
                }),
              "Hizmetler kaydedildi.",
            )
          }
          className="mt-4 rounded bg-marka px-4 py-2 text-sm text-white"
        >
          Hizmetleri kaydet
        </button>
      </section>

      {/* --- HIZMET ALANLARI --- */}
      <section className="mt-8 rounded border border-[color:var(--dk-cizgi)] p-4">
        <h2 className="font-medium">Hizmet verdiğiniz bölgeler</h2>
        <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
          Seçtiğiniz mahallelerdeki talepler size gösterilir.
        </p>

        <div className="mt-3 grid gap-2 sm:grid-cols-3">
          <select
            value={il}
            onChange={(e) => {
              setIl(e.target.value);
              setIlce("");
            }}
            className="rounded border border-[color:var(--dk-cizgi)] px-3 py-2 text-sm"
          >
            <option value="istanbul">İstanbul</option>
            <option value="ankara">Ankara</option>
            <option value="izmir">İzmir</option>
          </select>
          <select
            value={ilce}
            onChange={(e) => setIlce(e.target.value)}
            className="rounded border border-[color:var(--dk-cizgi)] px-3 py-2 text-sm"
          >
            <option value="">İlçe seçin</option>
            {ilceler.map((x) => (
              <option key={x.slug} value={x.slug}>
                {x.ad}
              </option>
            ))}
          </select>
          <input
            value={mahalleArama}
            onChange={(e) => setMahalleArama(e.target.value)}
            placeholder="Mahalle ara"
            className="rounded border border-[color:var(--dk-cizgi)] px-3 py-2 text-sm"
          />
        </div>

        {ilce && (
          <div className="mt-3 max-h-64 overflow-y-auto rounded border border-[color:var(--dk-cizgi)]">
            {mahalleler.length === 0 ? (
              <p className="px-3 py-4 text-sm text-[color:var(--dk-metin-soluk)]">
                {mahalleArama
                  ? "Aramanla eşleşen mahalle yok."
                  : "Mahalle yükleniyor…"}
              </p>
            ) : (
              <ul>
                {mahalleler.map((m) => {
                  const isaretli = seciliAlan.has(m.id);
                  const ilceAdi =
                    ilceler.find((x) => x.slug === ilce)?.ad ?? "";
                  return (
                    <li key={m.id}>
                      <label className="flex cursor-pointer items-center gap-2 px-3 py-2 text-sm hover:bg-[color:var(--dk-zemin-alt)]">
                        <input
                          type="checkbox"
                          checked={isaretli}
                          onChange={() => {
                            const y = new Map(seciliAlan);
                            if (isaretli) y.delete(m.id);
                            else y.set(m.id, `${m.ad} · ${ilceAdi}`);
                            setSeciliAlan(y);
                          }}
                        />
                        <span>{m.ad}</span>
                        {m.tip !== "mahalle" && (
                          <span className="text-xs text-[color:var(--dk-metin-soluk)]">
                            ({m.tip === "koy" ? "köy" : m.tip})
                          </span>
                        )}
                      </label>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        )}

        {/* SECILENLER HER ZAMAN GORUNUR — baska bir ilceye gecince de.
            Gorunmezse kullanici onceki secimlerini kaybettigini sanir ve
            kaydetmekten cekinir; oysa PUT TAM LISTE gonderiyor. */}
        <div className="mt-4">
          <p className="text-sm font-medium">
            Seçili bölgeler ({seciliAlan.size})
          </p>
          {seciliAlan.size === 0 ? (
            <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
              Henüz bölge seçmediniz. Bölge seçmeden başvuru gönderemezsiniz —
              talepler size mahalle üzerinden ulaşır.
            </p>
          ) : (
            <ul className="mt-2 flex flex-wrap gap-2">
              {Array.from(seciliAlan.entries()).map(([id, etiket]) => (
                <li key={id}>
                  <button
                    type="button"
                    onClick={() => {
                      const y = new Map(seciliAlan);
                      y.delete(id);
                      setSeciliAlan(y);
                    }}
                    className="rounded-full bg-marka-acik px-3 py-1 text-sm text-marka-koyu"
                    aria-label={`${etiket} bölgesini kaldır`}
                  >
                    {etiket} ×
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <button
          onClick={() =>
            calistir(
              () =>
                api(`/isletme/${isletmeId}/hizmet-alanlari`, {
                  metot: "PUT",
                  govde: { mahalle_idler: Array.from(seciliAlan.keys()) },
                }),
              "Bölgeler kaydedildi.",
            )
          }
          className="mt-4 rounded bg-marka px-4 py-2 text-sm text-white"
        >
          Bölgeleri kaydet
        </button>
      </section>

      {/* --- BASVURU --- */}
      <section className="mt-8">
        <button
          disabled={!hazir || d.durum === "onay_bekliyor" || d.durum === "onayli"}
          onClick={() =>
            calistir(
              () => api(`/isletme/${isletmeId}/basvur`, { metot: "POST" }),
              "Başvurunuz alındı. İnceleme genelde 2 iş günü sürer.",
            )
          }
          className="rounded bg-marka-koyu px-5 py-3 font-medium text-white disabled:opacity-50"
        >
          {d.durum === "onay_bekliyor"
            ? "Başvurunuz incelemede"
            : d.durum === "onayli"
              ? "Yayında"
              : "Onaya gönder"}
        </button>
        {!hazir && (
          <p className="mt-2 text-sm text-[color:var(--dk-metin-soluk)]">
            Yukarıdaki adımları tamamlayınca onaya gönderebilirsiniz.
          </p>
        )}
      </section>

      {bilgi && (
        <p className="mt-6 rounded bg-emerald-50 px-3 py-2 text-sm text-emerald-900">
          {bilgi}
        </p>
      )}
      {hata && (
        <p className="mt-6 rounded bg-red-50 px-3 py-2 text-sm text-red-800">
          {hata}
        </p>
      )}
    </main>
  );
}
