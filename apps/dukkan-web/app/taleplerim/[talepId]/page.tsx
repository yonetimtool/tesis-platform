"use client";

import { useParams, useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useState } from "react";

import { DogrulamaRozeti, Puan } from "@/components/Rozet";
import { api, hataMetni, jetonAl } from "@/lib/istemci";

type Teklif = {
  id: string;
  tutar_kurus: number | null;
  mesaj: string | null;
  durum: string;
  isletme_ad: string;
  isletme_slug: string;
  isletme_telefon: string;
  whatsapp: string | null;
  dogrulama_seviyesi: number;
  ortalama_puan: number | string | null;
  yorum_sayisi: number;
};

type Talep = {
  id: string;
  aciklama: string;
  durum: string;
  kategori: { ad: string };
  mahalle: { ad: string; ilce: string; il: string };
  teklif_sayisi: number;
  is_id: string | null;
  paylas_ad: boolean;
  paylas_telefon: boolean;
  paylas_adres: boolean;
  acik_adres: string | null;
};

const TL = (kurus: number) =>
  new Intl.NumberFormat("tr-TR", { style: "currency", currency: "TRY" }).format(
    kurus / 100,
  );

/** Ayni gerekce: `useSearchParams()` Suspense sinirI ister (bkz.
 *  talep-olustur/page.tsx). `?yeni=` parametresi talep gonderildikten
 *  sonra "kac isletmeye ulasti" bilgisini tasiyor. */
export default function TalepDetaySayfa() {
  return (
    <Suspense
      fallback={
        <main className="mx-auto max-w-3xl px-4 py-12">Yükleniyor…</main>
      }
    >
      <TalepDetay />
    </Suspense>
  );
}

function TalepDetay() {
  const { talepId } = useParams<{ talepId: string }>();
  const yeni = useSearchParams().get("yeni");
  const [t, setT] = useState<Talep | null>(null);
  const [teklifler, setTeklifler] = useState<Teklif[]>([]);
  const [hata, setHata] = useState<string | null>(null);
  const [bilgi, setBilgi] = useState<string | null>(null);

  const yukle = useCallback(async () => {
    setT(await api<Talep>(`/talep/${talepId}`));
    const d = await api<{ items: Teklif[] }>(`/talep/${talepId}/teklifler`);
    setTeklifler(d.items);
  }, [talepId]);

  useEffect(() => {
    if (!jetonAl()) return;
    yukle().catch((h) => setHata(hataMetni(h)));
  }, [yukle]);

  async function kabulEt(teklifId: string) {
    setHata(null);
    try {
      await api(`/teklif/${teklifId}/kabul`, { metot: "POST" });
      await yukle();
      setBilgi(
        "İletişim bilgilerin yalnızca seçtiğin işletmeye açıldı. Anlaşma ve ödeme doğrudan aranızda.",
      );
    } catch (h) {
      setHata(hataMetni(h));
    }
  }

  if (!t) {
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

  return (
    <main className="mx-auto max-w-3xl px-4 py-12">
      <h1 className="text-2xl font-bold text-marka-koyu">{t.kategori.ad}</h1>
      <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
        {t.mahalle.ad} · {t.mahalle.ilce} / {t.mahalle.il}
      </p>

      {/* TALEP KIMSEYE ULASMADIYSA BUNU SOYLUYORUZ.
          Sessizce "gönderildi" deyip 0 işletmeye giden bir talep,
          kullanıcıyı boş yere bekletirdi (P217 dersi). */}
      {yeni !== null && Number(yeni) === 0 && (
        <p className="mt-4 rounded bg-amber-50 px-3 py-2 text-sm text-amber-900">
          Bu bölgede ve kategoride henüz kayıtlı işletme yok, bu yüzden talebin
          şu an kimseye ulaşmadı. Bölgeni genişletip yeni bir talep açabilirsin.
        </p>
      )}
      {yeni !== null && Number(yeni) > 0 && (
        <p className="mt-4 rounded bg-emerald-50 px-3 py-2 text-sm text-emerald-900">
          Talebin {yeni} işletmeye ulaştı. Teklifler burada görünecek.
        </p>
      )}

      <p className="mt-4 whitespace-pre-line">{t.aciklama}</p>

      {/* KULLANICI NE PAYLASTIGINI SONRADAN DA GORMELI. */}
      <section className="mt-6 rounded border border-[color:var(--dk-cizgi)] p-4 text-sm">
        <h2 className="font-medium">İşletmelerin gördükleri</h2>
        <ul className="mt-2 space-y-1 text-[color:var(--dk-metin-soluk)]">
          <li>✓ Mahallen ve ihtiyacının açıklaması</li>
          <li>{t.paylas_ad ? "✓" : "✗"} Adın</li>
          <li>{t.paylas_telefon ? "✓" : "✗"} Telefonun</li>
          <li>
            {t.paylas_adres ? "✓" : "✗"} Açık adresin
            {t.paylas_adres && (
              <span className="block text-xs">
                {t.is_id
                  ? "Devam ettiğin işletmeye açıldı."
                  : "Henüz kimseye açılmadı — bir işletmeyle devam edince açılır."}
              </span>
            )}
          </li>
        </ul>
      </section>

      <h2 className="mt-8 text-lg font-semibold">
        Teklifler ({teklifler.length})
      </h2>
      {teklifler.length === 0 ? (
        <p className="mt-2 text-sm text-[color:var(--dk-metin-soluk)]">
          Henüz teklif gelmedi.
        </p>
      ) : (
        <>
          {/* (F8a) ARACI DEGILIZ — TEKLIF LISTESININ USTUNDE, DIPNOT DEGIL.
              Butonun adi degisti ("Isi ver" -> "Bu isletmeyle devam et")
              ama ad tek basina yetmez: kullanici bir dugmeye basip
              "platform uzerinden anlastim" sanabilir. */}
          <p className="mt-4 rounded border border-gray-200 bg-gray-50 p-3 text-sm text-[color:var(--dk-metin-soluk)]">
            Dükkan bir ilan ve eşleştirme hizmetidir. Anlaşma ve ödeme
            doğrudan işletmeyle senin arandadır; Dükkan taraf değildir.
          </p>
          <ul className="mt-4 space-y-3">
          {teklifler.map((tk) => (
            <li
              key={tk.id}
              className={`rounded border p-4 ${
                tk.durum === "kabul"
                  ? "border-emerald-400 bg-emerald-50"
                  : "border-[color:var(--dk-cizgi)]"
              }`}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h3 className="font-medium text-marka-koyu">{tk.isletme_ad}</h3>
                  <div className="mt-1 flex flex-wrap items-center gap-2">
                    <Puan puan={tk.ortalama_puan} sayi={tk.yorum_sayisi} />
                    <DogrulamaRozeti seviye={tk.dogrulama_seviyesi} />
                  </div>
                  <p className="mt-2 text-sm">
                    {tk.tutar_kurus === null ? (
                      // NULL = "yerinde görmem gerek". Zorunlu yapmak ustayı
                      // uydurma rakam yazmaya iterdi.
                      <span className="text-[color:var(--dk-metin-soluk)]">
                        Fiyat için yerinde görmek istiyor
                      </span>
                    ) : (
                      <strong>{TL(tk.tutar_kurus)}</strong>
                    )}
                  </p>
                  {tk.mesaj && (
                    <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
                      {tk.mesaj}
                    </p>
                  )}
                </div>
                <div className="shrink-0">
                  {tk.durum === "kabul" ? (
                    <div className="text-right">
                      <span className="text-sm font-medium text-emerald-900">
                        Devam ediliyor
                      </span>
                      <a
                        href={`tel:${tk.isletme_telefon}`}
                        className="mt-2 block rounded bg-marka px-3 py-2 text-sm text-white"
                      >
                        {tk.isletme_telefon}
                      </a>
                    </div>
                  ) : tk.durum === "red" ? (
                    <span className="text-sm text-[color:var(--dk-metin-soluk)]">
                      Kapandı
                    </span>
                  ) : (
                    <button
                      onClick={() => kabulEt(tk.id)}
                      className="rounded bg-marka-koyu px-4 py-2 text-sm font-medium text-white"
                    >
                      Bu işletmeyle devam et
                    </button>
                  )}
                </div>
              </div>
            </li>
          ))}
          </ul>
        </>
      )}

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
