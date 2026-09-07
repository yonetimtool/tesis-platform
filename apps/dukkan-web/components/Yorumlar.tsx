import { sunucudanAl } from "@/lib/backend";

type Yorum = {
  id: string;
  kaynak: "platform" | "davet";
  puan: number;
  metin: string | null;
  yayinlandi_at: string | null;
  cevap: string | null;
};

type Veri = {
  items: Yorum[];
  ozet: { dogrulanmis: number; davetli: number };
};

const tarih = (s: string | null) =>
  s ? new Date(s).toLocaleDateString("tr-TR") : "";

/**
 * ==========================================================================
 * IKI KATMAN AYRI GOSTERILIR — ROZET FARKI GORUNUR, INCE YAZIYLA DEGIL
 * ==========================================================================
 * Kullanicinin sartı buydu (03-guven-ve-fraud.md §2.2b-a).
 *
 * Ozet iki sayiyi AYRI veriyor ve her yorumda kaynak rozeti var.
 * Kullanici "8 dogrulanmis" ile "0 dogrulanmis, 40 davetli" arasindaki
 * farki KENDI okur — karari gizlemek yerine GORUNUR kiliyoruz.
 *
 * Ayni listeye karistirip sonuna kucuk bir etiket iliskirmek, farki
 * *teknik olarak* gostermek ama *fiilen* gizlemek olurdu.
 */
export async function Yorumlar({ slug }: { slug: string }) {
  const d = await sunucudanAl<Veri>(
    `/dukkan/isletme-profil/${encodeURIComponent(slug)}/yorum`,
    3600,
  );
  if (!d) return null;

  const { dogrulanmis, davetli } = d.ozet;
  if (dogrulanmis + davetli === 0) {
    return (
      <section className="mt-10">
        <h2 className="text-lg font-semibold">Değerlendirmeler</h2>
        <p className="mt-2 text-sm text-[color:var(--dk-metin-soluk)]">
          Bu işletme için henüz değerlendirme yok.
        </p>
      </section>
    );
  }

  const platform = d.items.filter((y) => y.kaynak === "platform");
  const davet = d.items.filter((y) => y.kaynak === "davet");

  return (
    <section className="mt-10">
      <h2 className="text-lg font-semibold">
        Değerlendirmeler ({dogrulanmis + davetli})
      </h2>

      {/* OZET — iki sayi AYRI, ayni satirda toplanmadan. */}
      <ul className="mt-2 space-y-1 text-sm">
        <li className="flex items-center gap-2">
          <span
            aria-hidden
            className="rounded bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-900"
          >
            ✔
          </span>
          <span>
            <strong>{dogrulanmis}</strong> platform üzerinden alınan hizmet
          </span>
        </li>
        <li className="flex items-center gap-2">
          <span
            aria-hidden
            className="rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-700"
          >
            •
          </span>
          <span>
            <strong>{davetli}</strong> davetli değerlendirme
          </span>
        </li>
      </ul>

      {platform.length > 0 && (
        <>
          <h3 className="mt-6 text-sm font-medium text-marka-koyu">
            Platform üzerinden alınan hizmet
          </h3>
          <ul className="mt-2 space-y-3">
            {platform.map((y) => (
              <YorumKarti key={y.id} y={y} dogrulanmis />
            ))}
          </ul>
        </>
      )}

      {davet.length > 0 && (
        <>
          <h3 className="mt-6 text-sm font-medium text-[color:var(--dk-metin-soluk)]">
            Davetli değerlendirmeler
          </h3>
          {/* NE OLDUGUNU SOYLUYORUZ: kullanici bu yorumlarin platform
              disinda yapilan islere ait oldugunu bilmeli. */}
          <p className="mt-1 text-xs text-[color:var(--dk-metin-soluk)]">
            İşletmenin daveti üzerine yazıldı. İş platform üzerinden
            alınmadığı için doğrulanmamıştır.
          </p>
          <ul className="mt-2 space-y-3">
            {davet.map((y) => (
              <YorumKarti key={y.id} y={y} dogrulanmis={false} />
            ))}
          </ul>
        </>
      )}
    </section>
  );
}

function YorumKarti({
  y,
  dogrulanmis,
}: {
  y: Yorum;
  dogrulanmis: boolean;
}) {
  return (
    <li
      className={`rounded border p-4 ${
        dogrulanmis
          ? "border-emerald-200 bg-emerald-50/40"
          : "border-[color:var(--dk-cizgi)]"
      }`}
    >
      <div className="flex items-center justify-between gap-2">
        <span aria-label={`${y.puan} yıldız`}>
          {"★".repeat(y.puan)}
          <span className="text-[color:var(--dk-cizgi)]">
            {"★".repeat(5 - y.puan)}
          </span>
        </span>
        <span className="text-xs text-[color:var(--dk-metin-soluk)]">
          {tarih(y.yayinlandi_at)}
        </span>
      </div>
      {y.metin && <p className="mt-2 text-sm">{y.metin}</p>}
      {y.cevap && (
        <div className="mt-3 rounded bg-[color:var(--dk-zemin-alt)] p-3">
          <p className="text-xs font-medium">İşletmenin cevabı</p>
          <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
            {y.cevap}
          </p>
        </div>
      )}
    </li>
  );
}
