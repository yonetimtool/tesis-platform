"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";

import { api, hataMetni, jetonAl } from "@/lib/istemci";

/**
 * (DUKKAN F6-ek) BILDIRIM LISTESI + TERCIH — WEB.
 *
 * =========================================================================
 * NEDEN F6'DA YOKTU, SIMDI VAR
 * =========================================================================
 * F6'da bildirim BACKEND'i (satir + push + `hedef_yol`) ve BFF vekilleri
 * yazildi ama iki istemcide de EKRAN yoktu. Yani `bildirim` tablosuna
 * yazilan her satir GORULEMIYORDU: push kacan kullanicinin olayi
 * ogrenmesinin YOLU YOKTU. Bildirim altyapisi ancak okundugu yerde ise
 * yarar.
 *
 * =========================================================================
 * METIN ISTEMCIDE
 * =========================================================================
 * Sunucu `tip` + `veri` doner, metin DONMEZ (7 dil; kaydedilmis metin dil
 * degisince eski dilde kalirdi). Basliklar burada uretiliyor.
 */
type Bildirim = {
  id: string;
  tip: string;
  veri: Record<string, unknown> | null;
  hedef_yol: string | null;
  okundu_at: string | null;
  created_at: string;
};

type Tercih = { bildirim_acik: boolean; bildirim_sesli: boolean };

const BASLIK: Record<string, string> = {
  dukkan_teklif_geldi: "Talebine teklif geldi",
  dukkan_yeni_talep: "Bölgende yeni talep var",
  dukkan_is_verildi: "İş sana verildi",
  dukkan_isletme_onaylandi: "İşletmen onaylandı",
  dukkan_isletme_reddedildi: "İşletme başvurun reddedildi",
  dukkan_isletme_askiya_alindi: "İşletmen askıya alındı",
  dukkan_yorum_yayinlandi: "Değerlendirmen yayınlandı",
};

export default function Bildirimler() {
  const yonlendir = useRouter();
  const [liste, setListe] = useState<Bildirim[] | null>(null);
  const [tercih, setTercih] = useState<Tercih | null>(null);
  const [hata, setHata] = useState<string | null>(null);

  const yukle = useCallback(() => {
    api<{ items: Bildirim[] }>("/bildirim")
      .then((d) => setListe(d.items))
      .catch((h) => setHata(hataMetni(h)));
    api<Tercih>("/bildirim-tercihi")
      .then(setTercih)
      .catch((h) => setHata(hataMetni(h)));
  }, []);

  useEffect(() => {
    if (!jetonAl()) {
      yonlendir.replace("/giris");
      return;
    }
    yukle();
  }, [yonlendir, yukle]);

  async function tercihYaz(govde: Partial<Tercih>) {
    try {
      // SUNUCUDAN DONEN hali yaziliyor, gonderilen degil: "Kaydedildi"
      // deyip hicbir sey yazmayan akis (P217) boyle gorunmez kalmisti.
      setTercih(await api<Tercih>("/bildirim-tercihi", { metot: "PATCH", govde }));
    } catch (h) {
      setHata(hataMetni(h));
    }
  }

  async function okunduIsaretle(id: string, hedef: string | null) {
    try {
      await api(`/bildirim/okundu?bildirim_id=${encodeURIComponent(id)}`, {
        metot: "POST",
      });
    } catch {
      /* okundu isaretlenemese de yonlendirme YAPILIR: kullanicinin isi
         bildirimi okumak degil, olaya gitmek. */
    }
    if (hedef) yonlendir.push(hedef);
    else yukle();
  }

  return (
    <main className="mx-auto max-w-3xl px-4 py-12">
      <h1 className="text-2xl font-bold text-marka-koyu">Bildirimler</h1>

      {tercih && (
        <section className="mt-6 rounded border border-gray-200 p-4">
          <label className="flex items-center gap-3">
            <input
              type="checkbox"
              checked={tercih.bildirim_acik}
              onChange={(e) => tercihYaz({ bildirim_acik: e.target.checked })}
            />
            <span>
              Dükkân bildirimleri
              {/* KAPATMANIN NE YAPMADIGINI da soyluyoruz: kullanici
                  Yonetiyor bildirimlerinin de susacagini sanmamali. */}
              <span className="block text-sm text-gray-600">
                Kapatmak site bildirimlerini etkilemez.
              </span>
            </span>
          </label>
          <label className="mt-3 flex items-center gap-3">
            <input
              type="checkbox"
              checked={tercih.bildirim_sesli}
              disabled={!tercih.bildirim_acik}
              onChange={(e) => tercihYaz({ bildirim_sesli: e.target.checked })}
            />
            <span>Sesli gelsin</span>
          </label>
        </section>
      )}

      {hata && (
        <p role="alert" className="mt-6 text-sm text-red-700">
          {hata}
        </p>
      )}

      {liste && liste.length === 0 && (
        <p className="mt-6 text-gray-600">Henüz bildirim yok.</p>
      )}

      <ul className="mt-6 divide-y divide-gray-200">
        {(liste ?? []).map((b) => (
          <li key={b.id} className="py-3">
            <button
              type="button"
              onClick={() => okunduIsaretle(b.id, b.hedef_yol)}
              className="w-full text-left"
            >
              <span
                className={
                  b.okundu_at ? "text-gray-700" : "font-semibold text-marka-koyu"
                }
              >
                {BASLIK[b.tip] ?? b.tip}
              </span>
              <span className="block text-sm text-gray-500">
                {new Date(b.created_at).toLocaleString("tr-TR")}
              </span>
            </button>
          </li>
        ))}
      </ul>

      <Link href="/panel" className="mt-8 inline-block text-sm text-marka">
        İşletme paneline dön
      </Link>
    </main>
  );
}
