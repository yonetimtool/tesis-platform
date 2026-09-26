"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { TelefonAlani, telefonHataMetni } from "@/components/TelefonAlani";
import { api, hataMetni, jetonYaz } from "@/lib/istemci";
import { telefonNormalle } from "@/lib/telefon";

type KodYanit = { gonderildi: boolean; gonderim: string; dev_kod?: string };
type GirisYanit = { access_token: string; yeni_kayit: boolean };

/**
 * TELEFONLA GIRIS — Dukkan'in TEK kimlik kapisi.
 *
 * Neden telefon: Yonetiyor'da telefon GLOBAL benzersiz, e-posta yalnizca
 * tesis icinde. E-posta bir kisiyi tekillestiremez
 * (docs/dukkan/02-kimlik-ve-yetki.md §2).
 */
export default function Giris() {
  const yonlendir = useRouter();
  const [adim, setAdim] = useState<"telefon" | "kod">("telefon");
  const [telefon, setTelefon] = useState("");
  const [kod, setKod] = useState("");
  const [ad, setAd] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [bilgi, setBilgi] = useState<string | null>(null);
  const [bekle, setBekle] = useState(false);

  async function kodIste(e: React.FormEvent) {
    e.preventDefault();
    setHata(null);
    // (P248 §2) GECERSIZ NUMARA ISTEK ATMADAN DURUR (ulke secilmedi,
    // eksik/fazla hane) — sunucunun 422'si yerine alanin kendi cumlesi.
    const telHata = telefonHataMetni(telefon, true);
    if (telHata) {
      setHata(telHata);
      return;
    }
    setBekle(true);
    try {
      // GONDERILEMEDIYSE UC 503 DONER ve `api` HATA FIRLATIR — yani
      // asagidaki `setAdim("kod")` HIC CALISMAZ. Kullaniciya gelmeyecek
      // bir kodun bekleme ekrani GOSTERILMEZ.
      //
      // Eskiden uc 200 + `gonderildi: false` donduruyordu ve burada
      // "kod adimina" geciliyordu; kullanici olmayan bir SMS'i beklerdi.
      const y = await api<KodYanit>("/auth/telefon/kod", {
        metot: "POST",
        // (P248 §2) E.164 — Yonetiyor kullanici kaydiyla AYNI bicim; SSO
        // koprusu telefonla eslestirdigi icin iki bicim iki hesap demekti.
        govde: { telefon: telefonNormalle(telefon) },
      });
      setAdim("kod");
      if (y.dev_kod) {
        // Yalniz gelistirme: gercek saglayici varken uc bunu DONDURMEZ.
        setBilgi(`Geliştirme kodu: ${y.dev_kod}`);
      }
    } catch (h) {
      setHata(hataMetni(h));
    } finally {
      setBekle(false);
    }
  }

  async function dogrula(e: React.FormEvent) {
    e.preventDefault();
    setHata(null);
    setBekle(true);
    try {
      const y = await api<GirisYanit>("/auth/telefon/dogrula", {
        metot: "POST",
        govde: { telefon: telefonNormalle(telefon), kod, ad_soyad: ad || undefined },
      });
      jetonYaz(y.access_token);
      yonlendir.push("/panel");
    } catch (h) {
      setHata(hataMetni(h));
    } finally {
      setBekle(false);
    }
  }

  return (
    <main className="mx-auto max-w-md px-4 py-16">
      <h1 className="text-2xl font-bold text-marka-koyu">Giriş yap</h1>
      <p className="mt-2 text-sm text-[color:var(--dk-metin-soluk)]">
        Telefon numaranla giriş yap. Hesabın yoksa otomatik oluşturulur.
      </p>

      {adim === "telefon" ? (
        <form onSubmit={kodIste} className="mt-6 space-y-4">
          {/* (P248 §2) ORTAK TELEFON ALANI: ulke kodu secilir, numara
              bicimlenir, uzunluk sinirli (yabanci numara girilebilir). */}
          <TelefonAlani
            etiket="Telefon"
            zorunlu
            deger={telefon}
            onDegisti={setTelefon}
            etiketSinifi="block text-sm font-medium"
            kutuSinifi="mt-1 rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
            yardimSinifi="mt-1 block text-xs"
          />
          <button
            type="submit"
            disabled={bekle}
            className="w-full rounded bg-marka px-4 py-2 font-medium text-white disabled:opacity-60"
          >
            {bekle ? "Gönderiliyor…" : "Kod gönder"}
          </button>
        </form>
      ) : (
        <form onSubmit={dogrula} className="mt-6 space-y-4">
          <label className="block">
            <span className="text-sm font-medium">Doğrulama kodu</span>
            <input
              inputMode="numeric"
              required
              maxLength={6}
              value={kod}
              onChange={(e) => setKod(e.target.value)}
              className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2 tracking-widest"
            />
          </label>
          <label className="block">
            <span className="text-sm font-medium">Adın (isteğe bağlı)</span>
            <input
              value={ad}
              onChange={(e) => setAd(e.target.value)}
              className="mt-1 w-full rounded border border-[color:var(--dk-cizgi)] px-3 py-2"
            />
          </label>
          <button
            type="submit"
            disabled={bekle}
            className="w-full rounded bg-marka px-4 py-2 font-medium text-white disabled:opacity-60"
          >
            {bekle ? "Doğrulanıyor…" : "Giriş yap"}
          </button>
          <button
            type="button"
            onClick={() => setAdim("telefon")}
            className="w-full text-sm text-[color:var(--dk-metin-soluk)] underline"
          >
            Numarayı değiştir
          </button>
        </form>
      )}

      {bilgi && (
        <p className="mt-4 rounded bg-marka-acik px-3 py-2 text-sm text-marka-koyu">
          {bilgi}
        </p>
      )}
      {hata && (
        <p className="mt-4 rounded bg-red-50 px-3 py-2 text-sm text-red-800">
          {hata}
        </p>
      )}
    </main>
  );
}
