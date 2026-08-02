import type { Belge } from "@/lib/hukuki/tipler";

// (P113) Hukuki belge cizici — `/gizlilik` ve `/kosullar` ortak kabugu.
//
// SUNUCU BILESENI ve JS TASIMAZ: App Store denetcisi, arama motoru ve
// JavaScript'i kapali bir tarayici AYNI metni gormeli. Bir gizlilik
// politikasinin istemci tarafinda birlestirilmesi, "sayfa bos geldi"
// ihtimalini bir denetim riskine cevirirdi.
//
// Kalin isaretlemesi burada cozulur: metinleri VERI olarak tutmanin
// bedeli, minik bir bicimlendirmedir. Tam bir markdown kutuphanesi
// eklemek, bu kadarcik is icin ucuncu bir bagimlilik demekti.
function kalinCoz(metin: string, anahtar: string) {
  return metin.split(/(\*\*[^*]+\*\*)/g).map((parca, i) =>
    parca.startsWith("**") && parca.endsWith("**") ? (
      <strong key={`${anahtar}-${i}`}>{parca.slice(2, -2)}</strong>
    ) : (
      <span key={`${anahtar}-${i}`}>{parca}</span>
    ),
  );
}

export function HukukiBelge({ belge }: { belge: Belge }) {
  return (
    <article className="mx-auto max-w-3xl px-6 py-10">
      <h1 className="text-2xl font-semibold tracking-tight">{belge.baslik}</h1>
      <p className="mt-1 text-sm opacity-60">{belge.guncelleme}</p>

      {/* TR disi surumlerde: baglayici metnin hangisi oldugu USTTE yazar.
          Altta bir dipnot olsaydi, okumayi yarida birakan kullanici
          ceviriyi baglayici sanirdi. */}
      {belge.kaynakBaglayici ? (
        <p className="mt-4 rounded-lg border border-slate-300 px-4 py-3 text-sm opacity-80">
          {belge.kaynakBaglayici}
        </p>
      ) : null}

      <p className="mt-6">{belge.giris}</p>

      {belge.bolumler.map((bolum) => (
        <section key={bolum.baslik} className="mt-8">
          <h2 className="text-lg font-semibold">{bolum.baslik}</h2>
          {bolum.paragraflar.map((p, i) => (
            <p key={`${bolum.baslik}-${i}`} className="mt-3 leading-relaxed">
              {kalinCoz(p, `${bolum.baslik}-${i}`)}
            </p>
          ))}
        </section>
      ))}
    </article>
  );
}
