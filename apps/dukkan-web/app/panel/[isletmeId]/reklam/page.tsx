"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";

import { api, hataMetni, jetonAl } from "@/lib/istemci";

/**
 * (DUKKAN F8) REKLAM PANELI — görünürlük satın alma.
 *
 * =========================================================================
 * NEDEN AYRI SAYFA
 * =========================================================================
 * İşletme paneli zaten yoğun (profil, kategori, hizmet alanı, belge,
 * telefon doğrulama, gelen talepler). Reklamı oraya sıkıştırmak, hem o
 * sayfayı okunmaz yapardı hem de bildirimlerin varacağı net bir yer
 * bırakmazdı — `dukkan_reklam_bitiyor` ve `dukkan_odeme_basarisiz`
 * bildirimlerinin hedefi bu sayfa.
 *
 * =========================================================================
 * SATIN ALMADAN ÖNCE SLOT DURUMU GÖSTERİLİYOR
 * =========================================================================
 * "Bu bölge dolu, sıraya girin" demek, parayı alıp sonra "aslında dolu"
 * demekten dürüst. Kullanıcı paketi seçtiği anda o bölgede yer olup
 * olmadığını görüyor.
 *
 * =========================================================================
 * ÖDEME KAPALIYKEN NE OLUYOR
 * =========================================================================
 * Sanal POS sağlayıcısı henüz seçilmedi; uç 503 `odeme_yapilandirilmadi`
 * dönüyor. Bu sayfa bunu **bir hata gibi değil**, ürünün o anki durumu
 * gibi gösteriyor: "Reklam satışı henüz açılmadı." Kullanıcıyı
 * gelmeyecek bir ödeme ekranına sokmuyoruz.
 */
type Paket = {
  id: string;
  ad: string;
  kapsam: "mahalle" | "ilce" | "il";
  gun: number;
  fiyat_kurus: number;
  kdv_orani: string | number;
};

type SlotDurumu = {
  azami: number;
  dolu: number;
  bos: number;
  isletme_sayisi: number;
  oran_tavani_slot: number;
};

type Reklam = {
  id: string;
  kapsam: string;
  durum: string;
  baslangic: string;
  bitis: string;
  kategori: string;
  bolge: string | null;
  paket: string | null;
};

type Detay = {
  ad: string;
  kategoriler: string[];
  hizmet_alanlari: { id: string; ad: string; ilce: string; il: string }[];
};

const KAPSAM_ADI: Record<string, string> = {
  mahalle: "Mahalle",
  ilce: "İlçe",
  il: "İl",
};

const DURUM_ADI: Record<string, string> = {
  yayinda: "Yayında",
  bitti: "Süresi doldu",
  iptal: "İptal",
  beklemede: "Beklemede",
};

function lira(kurus: number): string {
  return (kurus / 100).toLocaleString("tr-TR", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

export default function ReklamPaneli() {
  const { isletmeId } = useParams<{ isletmeId: string }>();
  const yonlendir = useRouter();

  const [detay, setDetay] = useState<Detay | null>(null);
  const [paketler, setPaketler] = useState<Paket[]>([]);
  const [reklamlar, setReklamlar] = useState<Reklam[]>([]);
  const [hata, setHata] = useState<string | null>(null);
  const [bilgi, setBilgi] = useState<string | null>(null);

  const [paketId, setPaketId] = useState("");
  const [kategoriSlug, setKategoriSlug] = useState("");
  const [bolgeId, setBolgeId] = useState("");
  const [slot, setSlot] = useState<SlotDurumu | null>(null);
  const [islemde, setIslemde] = useState(false);

  const yukle = useCallback(() => {
    api<{ items: Paket[] }>("/reklam/paketler")
      .then((d) => setPaketler(d.items))
      .catch((h) => setHata(hataMetni(h)));
    api<{ items: Reklam[] }>(`/reklam/benim?isletme_id=${isletmeId}`)
      .then((d) => setReklamlar(d.items))
      .catch((h) => setHata(hataMetni(h)));
    api<Detay>(`/isletme/${isletmeId}`)
      .then(setDetay)
      .catch((h) => setHata(hataMetni(h)));
  }, [isletmeId]);

  useEffect(() => {
    if (!jetonAl()) {
      yonlendir.replace("/giris");
      return;
    }
    yukle();
  }, [yonlendir, yukle]);

  const paket = paketler.find((p) => p.id === paketId);

  // SLOT DURUMU PAKET + BÖLGE + KATEGORİ SEÇİLİNCE SORULUR.
  // Satın alma düğmesine basılınca sormak, kullanıcıyı formu doldurup
  // sonunda "dolu" duymaya mahkûm ederdi.
  useEffect(() => {
    if (!paket || !bolgeId || !kategoriSlug) {
      setSlot(null);
      return;
    }
    api<SlotDurumu>(
      `/reklam/slot-durumu?kapsam=${paket.kapsam}` +
        `&bolge_id=${encodeURIComponent(bolgeId)}` +
        `&kategori_slug=${encodeURIComponent(kategoriSlug)}`,
    )
      .then(setSlot)
      .catch(() => setSlot(null));
  }, [paket, bolgeId, kategoriSlug]);

  async function satinAl() {
    if (!paket) return;
    setIslemde(true);
    setHata(null);
    setBilgi(null);
    try {
      // FATURA ALANLARI ZORUNLU: satın alma anında dondurulur, işletme
      // tablosuna JOIN atılmaz (fatura kesildiği andaki bilgilerle
      // kesilir — F8c-kararlar §6).
      const fatura = {
        unvan: (document.getElementById("f-unvan") as HTMLInputElement).value,
        vkn: (document.getElementById("f-vkn") as HTMLInputElement).value,
        vergi_dairesi: (document.getElementById("f-vd") as HTMLInputElement)
          .value,
        adres: (document.getElementById("f-adres") as HTMLTextAreaElement)
          .value,
      };
      const govde: Record<string, unknown> = {
        paket_id: paket.id,
        kategori_slug: kategoriSlug,
        fatura,
      };
      govde[`${paket.kapsam}_id`] = bolgeId;

      const d = await api<{ durum: string; yonlendirme_url: string | null }>(
        `/reklam/satin-al?isletme_id=${isletmeId}`,
        { metot: "POST", govde },
      );
      // 3DS: işlem BİTMEDİ, kullanıcı yönlendirilecek.
      if (d.yonlendirme_url) {
        window.location.href = d.yonlendirme_url;
        return;
      }
      setBilgi("Reklamın yayına alındı.");
      yukle();
    } catch (h) {
      setHata(hataMetni(h));
    } finally {
      setIslemde(false);
    }
  }

  async function beklemeyeGir() {
    if (!paket) return;
    setIslemde(true);
    setHata(null);
    try {
      const govde: Record<string, unknown> = {
        paket_id: paket.id,
        kategori_slug: kategoriSlug,
      };
      govde[`${paket.kapsam}_id`] = bolgeId;
      const d = await api<{ sira: number }>(
        `/reklam/bekleme?isletme_id=${isletmeId}`,
        { metot: "POST", govde },
      );
      setBilgi(`Sıraya girdin — ${d.sira}. sıradasın. Yer açıldığında haber vereceğiz.`);
    } catch (h) {
      setHata(hataMetni(h));
    } finally {
      setIslemde(false);
    }
  }

  return (
    <main className="mx-auto max-w-3xl px-4 py-12">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-marka-koyu">
          Reklam {detay ? `— ${detay.ad}` : ""}
        </h1>
        <Link
          href={`/panel/${isletmeId}`}
          className="text-sm text-marka hover:underline"
        >
          İşletme paneline dön
        </Link>
      </div>

      <p className="mt-2 text-sm text-[color:var(--dk-metin-soluk)]">
        Reklam, arama sonuçlarında <strong>&ldquo;Sponsorlu&rdquo;</strong>{" "}
        etiketiyle ve organik listeden ayrı bir blokta gösterilir. Organik
        sıralamanı <strong>değiştirmez</strong> — puanın yorumlardan ve
        doğrulamadan gelir.
      </p>

      {hata && (
        <p role="alert" className="mt-6 text-sm text-red-700">
          {hata}
        </p>
      )}
      {bilgi && (
        <p role="status" className="mt-6 text-sm text-green-700">
          {bilgi}
        </p>
      )}

      {/* ÖDEME KAPALI: paket listesi boş gelir. Bunu bir hata gibi
          değil, ürünün o anki durumu gibi söylüyoruz. */}
      {paketler.length === 0 && (
        <section className="mt-8 rounded border border-gray-200 bg-gray-50 p-4">
          <h2 className="font-medium">Reklam satışı henüz açılmadı</h2>
          <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
            Paketler ve ödeme altyapısı hazırlanıyor. Açıldığında bu
            sayfadan satın alabileceksin.
          </p>
        </section>
      )}

      {paketler.length > 0 && (
        <section className="mt-8 rounded border border-[color:var(--dk-cizgi)] p-4">
          <h2 className="font-medium">Yeni reklam</h2>

          <label className="mt-4 block text-sm">
            Paket
            <select
              className="mt-1 w-full rounded border border-gray-300 p-2"
              value={paketId}
              onChange={(e) => {
                setPaketId(e.target.value);
                setBolgeId("");
              }}
            >
              <option value="">Seçin</option>
              {paketler.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.ad} — {KAPSAM_ADI[p.kapsam]} · {p.gun} gün ·{" "}
                  {lira(p.fiyat_kurus)} ₺ + KDV
                </option>
              ))}
            </select>
          </label>

          <label className="mt-3 block text-sm">
            Kategori
            <select
              className="mt-1 w-full rounded border border-gray-300 p-2"
              value={kategoriSlug}
              onChange={(e) => setKategoriSlug(e.target.value)}
            >
              <option value="">Seçin</option>
              {(detay?.kategoriler ?? []).map((k) => (
                <option key={k} value={k}>
                  {k}
                </option>
              ))}
            </select>
            <span className="mt-1 block text-xs text-[color:var(--dk-metin-soluk)]">
              Reklam bir kategoriye bağlıdır: &ldquo;bölgede öne çık&rdquo;
              değil, &ldquo;bu hizmet aranırken öne çık&rdquo;.
            </span>
          </label>

          {/* Mahalle kapsamında hizmet alanlarından seçtiriyoruz: işletme
              zaten hizmet vermediği bir mahallede reklam almamalı. */}
          {paket?.kapsam === "mahalle" && (
            <label className="mt-3 block text-sm">
              Mahalle
              <select
                className="mt-1 w-full rounded border border-gray-300 p-2"
                value={bolgeId}
                onChange={(e) => setBolgeId(e.target.value)}
              >
                <option value="">Seçin</option>
                {(detay?.hizmet_alanlari ?? []).map((m) => (
                  <option key={m.id} value={m.id}>
                    {m.ad} — {m.ilce} / {m.il}
                  </option>
                ))}
              </select>
            </label>
          )}
          {paket && paket.kapsam !== "mahalle" && (
            <label className="mt-3 block text-sm">
              {KAPSAM_ADI[paket.kapsam]} kimliği
              <input
                className="mt-1 w-full rounded border border-gray-300 p-2"
                value={bolgeId}
                onChange={(e) => setBolgeId(e.target.value)}
                placeholder="Bölge seçimi"
              />
            </label>
          )}

          {slot && (
            <div className="mt-4 rounded bg-gray-50 p-3 text-sm">
              {slot.bos > 0 ? (
                <p>
                  Bu bölgede <strong>{slot.bos}</strong> reklam yeri boş
                  (toplam {slot.azami}).
                </p>
              ) : (
                <p>
                  <strong>Bu bölge dolu.</strong> Sıraya girebilirsin; yer
                  açıldığında haber veririz.
                  {slot.azami === 0 && (
                    <span className="mt-1 block text-xs text-[color:var(--dk-metin-soluk)]">
                      Bu bölgede {slot.isletme_sayisi} işletme var; reklam
                      yeri, listenin okunabilir kalması için işletme
                      sayısına göre sınırlı.
                    </span>
                  )}
                </p>
              )}
            </div>
          )}

          <fieldset className="mt-4 rounded border border-gray-200 p-3">
            <legend className="px-1 text-sm font-medium">Fatura bilgileri</legend>
            <input id="f-unvan" className="mt-1 w-full rounded border border-gray-300 p-2" placeholder="Unvan" />
            <input id="f-vkn" className="mt-2 w-full rounded border border-gray-300 p-2" placeholder="VKN / TCKN" />
            <input id="f-vd" className="mt-2 w-full rounded border border-gray-300 p-2" placeholder="Vergi dairesi" />
            <textarea id="f-adres" rows={2} className="mt-2 w-full rounded border border-gray-300 p-2" placeholder="Fatura adresi" />
          </fieldset>

          <div className="mt-4 flex gap-2">
            <button
              type="button"
              disabled={islemde || !paket || !bolgeId || !kategoriSlug || slot?.bos === 0}
              onClick={satinAl}
              className="rounded bg-marka px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
            >
              Satın al
            </button>
            {slot?.bos === 0 && (
              <button
                type="button"
                disabled={islemde}
                onClick={beklemeyeGir}
                className="rounded border border-marka px-4 py-2 text-sm font-medium text-marka disabled:opacity-50"
              >
                Sıraya gir
              </button>
            )}
          </div>

          {/* OTOMATİK YENİLEME YOK — ve bunu SÖYLÜYORUZ. Sessizce kart
              çekmemek bir karar; kullanıcının bunu bilmesi o kararın
              yarısı. */}
          <p className="mt-3 text-xs text-[color:var(--dk-metin-soluk)]">
            Reklam <strong>otomatik yenilenmez</strong>. Süre bitmeden 7 gün
            ve 1 gün kala hatırlatırız; yenilemek istersen buradan tekrar
            satın alırsın.
          </p>
        </section>
      )}

      <section className="mt-8">
        <h2 className="font-medium">Reklamların</h2>
        {reklamlar.length === 0 ? (
          <p className="mt-2 text-sm text-[color:var(--dk-metin-soluk)]">
            Henüz reklam almadın.
          </p>
        ) : (
          <ul className="mt-3 space-y-2">
            {reklamlar.map((r) => (
              <li
                key={r.id}
                className="rounded border border-[color:var(--dk-cizgi)] p-3 text-sm"
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <span className="font-medium">
                    {r.kategori} — {r.bolge ?? "—"} ({KAPSAM_ADI[r.kapsam]})
                  </span>
                  <span className="text-[color:var(--dk-metin-soluk)]">
                    {DURUM_ADI[r.durum] ?? r.durum}
                  </span>
                </div>
                <p className="mt-1 text-[color:var(--dk-metin-soluk)]">
                  {new Date(r.baslangic).toLocaleDateString("tr-TR")} –{" "}
                  {new Date(r.bitis).toLocaleDateString("tr-TR")}
                  {r.paket ? ` · ${r.paket}` : ""}
                </p>
              </li>
            ))}
          </ul>
        )}
      </section>
    </main>
  );
}
