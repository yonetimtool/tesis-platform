"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";

import { api, hataMetni, jetonAl } from "@/lib/istemci";

type Kategori = { ad: string; slug: string; alt: { ad: string; slug: string }[] };
type Yer = { ad: string; slug: string };
type Mahalle = { id: string; ad: string; slug: string };

/**
 * ==========================================================================
 * TALEP OLUSTURMA — KVKK PAYLASIM TERCIHLERI BU EKRANIN MERKEZI
 * ==========================================================================
 * Kullanici NE PAYLASTIGINI GORMELI ve SECMELI. Uc onay kutusu da KAPALI
 * baslar (sunucuda da `DEFAULT false`): formu dikkatsiz dolduran birinin
 * basina gelen sey "veri paylasilmadi" olmali.
 *
 * Onay kutulari formun SONUNA degil, gonder dugmesinin HEMEN USTUNE
 * kondu ve bir cerceve icinde: en son okunan sey "isletmeler ne gorecek"
 * olsun. Sayfanin basina koymak, kullanicinin daha ne yazacagini
 * bilmeden karar vermesi demekti.
 */
/**
 * `useSearchParams()` Next 14'te statik on-uretimde SUSPENSE SINIRI ister;
 * yoksa derleme "prerender-error" ile duser (olculdu). Sinir en dista,
 * cunku bu sayfa SEO sayfalarindan parametreyle geliyor
 * (?kategori=&il=&ilce=&mahalle=) ve o baglami KAYBETMEMELI — kullanici
 * "Ucretsiz teklif al" dedikten sonra bolgeyi yeniden secmek zorunda
 * kalmamali.
 */
export default function TalepOlusturSayfa() {
  return (
    <Suspense
      fallback={
        <main className="mx-auto max-w-lg px-4 py-12">Yükleniyor…</main>
      }
    >
      <TalepOlustur />
    </Suspense>
  );
}

function TalepOlustur() {
  const yonlendir = useRouter();
  const sorgu = useSearchParams();

  const [kategoriler, setKategoriler] = useState<Kategori[]>([]);
  const [kategori, setKategori] = useState(sorgu.get("kategori") ?? "");
  const [il, setIl] = useState(sorgu.get("il") ?? "");
  const [ilce, setIlce] = useState(sorgu.get("ilce") ?? "");
  const [mahalle, setMahalle] = useState(sorgu.get("mahalle") ?? "");
  const [iller, setIller] = useState<Yer[]>([]);
  const [ilceler, setIlceler] = useState<Yer[]>([]);
  const [mahalleler, setMahalleler] = useState<Mahalle[]>([]);

  const [aciklama, setAciklama] = useState("");
  const [paylasAd, setPaylasAd] = useState(false);
  const [paylasTelefon, setPaylasTelefon] = useState(false);
  const [paylasAdres, setPaylasAdres] = useState(false);
  const [acikAdres, setAcikAdres] = useState("");

  const [hata, setHata] = useState<string | null>(null);
  const [bekle, setBekle] = useState(false);

  useEffect(() => {
    if (!jetonAl()) {
      // Talep olusturmak jeton ister; kullaniciyi giris ekranina alip
      // GERI DONECEGI yolu tasiyoruz — form doldurup giris ekranina
      // dusmek ve her seyi kaybetmek en kotu deneyim olurdu.
      yonlendir.replace(`/giris?donus=${encodeURIComponent("/talep-olustur")}`);
      return;
    }
    api<{ items: Kategori[] }>("/kategori")
      .then((d) => setKategoriler(d.items))
      .catch(() => setKategoriler([]));
    api<{ items: Yer[] }>("/lokasyon/il")
      .then((d) => setIller(d.items))
      .catch(() => setIller([]));
  }, [yonlendir]);

  useEffect(() => {
    if (!il) return;
    api<{ items: Yer[] }>(`/lokasyon/il/${il}/ilce`)
      .then((d) => setIlceler(d.items))
      .catch(() => setIlceler([]));
  }, [il]);

  useEffect(() => {
    if (!il || !ilce) return;
    api<{ items: Mahalle[] }>(`/lokasyon/il/${il}/ilce/${ilce}/mahalle`)
      .then((d) => setMahalleler(d.items))
      .catch(() => setMahalleler([]));
  }, [il, ilce]);

  async function gonder(e: React.FormEvent) {
    e.preventDefault();
    setHata(null);
    setBekle(true);
    try {
      const y = await api<{ id: string; eslesen_isletme: number }>("/talep", {
        metot: "POST",
        govde: {
          kategori_slug: kategori,
          il_slug: il,
          ilce_slug: ilce,
          mahalle_slug: mahalle,
          aciklama,
          paylas_ad: paylasAd,
          paylas_telefon: paylasTelefon,
          paylas_adres: paylasAdres,
          acik_adres: paylasAdres ? acikAdres : undefined,
        },
      });
      yonlendir.push(`/taleplerim/${y.id}?yeni=${y.eslesen_isletme}`);
    } catch (h) {
      setHata(hataMetni(h));
    } finally {
      setBekle(false);
    }
  }

  const secilenMahalle = mahalleler.find((m) => m.slug === mahalle);

  return (
    <main className="mx-auto max-w-lg px-4 py-12">
      <h1 className="text-2xl font-bold text-marka-koyu">Ücretsiz teklif al</h1>
      <p className="mt-2 text-sm text-[color:var(--dk-metin-soluk)]">
        İhtiyacını anlat, bölgendeki işletmeler sana dönsün.
      </p>

      <form onSubmit={gonder} className="mt-6 space-y-4">
        <label className="block">
          <span className="text-sm font-medium">Hizmet *</span>
          <select
            required
            value={kategori}
            onChange={(e) => setKategori(e.target.value)}
            className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
          >
            <option value="">Seçin</option>
            {kategoriler.map((k) => (
              <optgroup key={k.slug} label={k.ad}>
                {k.alt.map((a) => (
                  <option key={a.slug} value={a.slug}>
                    {a.ad}
                  </option>
                ))}
              </optgroup>
            ))}
          </select>
        </label>

        <div className="grid gap-3 sm:grid-cols-3">
          <label className="block">
            <span className="text-sm font-medium">İl *</span>
            <select
              required
              value={il}
              onChange={(e) => {
                setIl(e.target.value);
                setIlce("");
                setMahalle("");
              }}
              className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
            >
              <option value="">Seçin</option>
              {iller.map((x) => (
                <option key={x.slug} value={x.slug}>
                  {x.ad}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="text-sm font-medium">İlçe *</span>
            <select
              required
              value={ilce}
              onChange={(e) => {
                setIlce(e.target.value);
                setMahalle("");
              }}
              className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
            >
              <option value="">Seçin</option>
              {ilceler.map((x) => (
                <option key={x.slug} value={x.slug}>
                  {x.ad}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="text-sm font-medium">Mahalle *</span>
            <select
              required
              value={mahalle}
              onChange={(e) => setMahalle(e.target.value)}
              className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
            >
              <option value="">Seçin</option>
              {mahalleler.map((x) => (
                <option key={x.slug} value={x.slug}>
                  {x.ad}
                </option>
              ))}
            </select>
          </label>
        </div>

        <label className="block">
          <span className="text-sm font-medium">İhtiyacın *</span>
          <textarea
            required
            minLength={10}
            rows={5}
            value={aciklama}
            onChange={(e) => setAciklama(e.target.value)}
            placeholder="Ne yaptırmak istediğini kısaca anlat."
            className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
          />
        </label>

        {/* ================================================================
            PAYLASIM TERCIHLERI — GONDER DUGMESININ HEMEN USTUNDE
            ================================================================
            En son okunan sey "isletmeler ne gorecek" olsun. Sayfanin
            basina koymak, kullanicinin daha ne yazacagini bilmeden karar
            vermesi demekti. */}
        <fieldset className="rounded border border-[color:var(--dk-cizgi)] p-4">
          <legend className="px-1 text-sm font-medium">
            Bu talebi gönderdiğinde işletmeler ne görecek?
          </legend>

          <p className="mt-1 flex items-start gap-2 text-sm">
            <span aria-hidden className="text-emerald-600">
              ✓
            </span>
            <span>
              <strong>Mahallen</strong>
              {secilenMahalle ? `: ${secilenMahalle.ad}` : ""} — teklif
              verebilmeleri için her zaman görünür
            </span>
          </p>
          <p className="mt-1 flex items-start gap-2 text-sm">
            <span aria-hidden className="text-emerald-600">
              ✓
            </span>
            <span>İhtiyacının açıklaması</span>
          </p>

          <div className="mt-3 space-y-2 border-t border-[color:var(--dk-cizgi)] pt-3">
            <label className="flex items-start gap-2 text-sm">
              <input
                type="checkbox"
                checked={paylasAd}
                onChange={(e) => setPaylasAd(e.target.checked)}
                className="mt-0.5"
              />
              <span>Adım</span>
            </label>
            <label className="flex items-start gap-2 text-sm">
              <input
                type="checkbox"
                checked={paylasTelefon}
                onChange={(e) => setPaylasTelefon(e.target.checked)}
                className="mt-0.5"
              />
              <span>
                Telefon numaram
                <span className="block text-xs text-[color:var(--dk-metin-soluk)]">
                  İşaretlemezsen işletmeler seni platform üzerinden bulur.
                </span>
              </span>
            </label>
            <label className="flex items-start gap-2 text-sm">
              <input
                type="checkbox"
                checked={paylasAdres}
                onChange={(e) => setPaylasAdres(e.target.checked)}
                className="mt-0.5"
              />
              <span>
                Açık adresim
                <span className="block text-xs text-[color:var(--dk-metin-soluk)]">
                  <strong>Devam ettiğin işletmeye açılır.</strong>{" "}
                  Teklif aşamasında kimse göremez.
                </span>
              </span>
            </label>
          </div>

          {paylasAdres && (
            <label className="mt-3 block">
              <span className="text-sm font-medium">Açık adres</span>
              <input
                value={acikAdres}
                onChange={(e) => setAcikAdres(e.target.value)}
                placeholder="Sokak, bina, daire"
                className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
              />
            </label>
          )}

          {/* IZIN VERILMEDIYSE ADRESIN HIC SAKLANMADIGINI SOYLUYORUZ.
              Kullanicinin "yazdim ama isaretlemedim, duruyor mu?" sorusu
              cevapsiz kalmamali. */}
          {!paylasAdres && (
            <p className="mt-3 text-xs text-[color:var(--dk-metin-soluk)]">
              Açık adresini paylaşmayı seçmediğin için adres bilgisi
              kaydedilmez.
            </p>
          )}
        </fieldset>

        <button
          type="submit"
          disabled={bekle}
          className="w-full rounded bg-marka px-4 py-3 font-medium text-white disabled:opacity-60"
        >
          {bekle ? "Gönderiliyor…" : "Talebi gönder"}
        </button>
      </form>

      {hata && (
        <p className="mt-4 rounded bg-red-50 px-3 py-2 text-sm text-red-800">
          {hata}
        </p>
      )}
    </main>
  );
}
