"use client";

import Link from "next/link";
import { useState } from "react";

import { APP_ADRESI } from "@/config/site";
import { HataDurumu } from "./HataDurumu";
import { MagazaDugmeleri } from "./MagazaDugmeleri";
import { SsoDugmeleri } from "./SsoDugmeleri";

/**
 * (P177 §4 + §5) YONETICI KAYDI — UC ADIM, TEK SAYFA.
 *
 * =========================================================================
 * NEDEN UC ADIM VE TESIS NEDEN SONDA ACILIYOR
 * =========================================================================
 * §4 bilgileri ve onaylari topluyor; §5 "yonetici ILK GIRISINDE site
 * adini girer, tesis O ANDA olusur" diyor. Ikisi arasindaki bosluk
 * E-POSTA DOGRULAMASIDIR: dogrulanmamis bir adresle tesis acmak, yanlis
 * yazilmis bir adrese kilitlenmis bir site birakirdi.
 *
 * Adimlar:
 *   1) Bilgiler + onaylar  -> basvuru yazilir, e-postaya 6 haneli kod
 *   2) Kod                 -> basvuru dogrulanir, kurulum jetonu
 *   3) Site adi            -> MEVCUT tesis mekanizmasiyla tesis acilir
 *
 * TESIS ADI ADIMI NEDEN BURADA, calisma alaninda DEGIL: §0 "MEVCUT KIMLIK
 * SISTEMI BOZULMAYACAK" diyor ve Play kapali testi mevcut sistemle
 * yapilacak. Panele yeni bir ilk-giris ekrani eklemek, bugun calisan
 * giris akisina dokunmak olurdu. Yolculuk ayni: yonetici siteyi
 * adlandirir, Tesis ID'sini ekranda gorur, e-postasina da alir ve
 * app.yonetiyor.com'a HAZIR bir tesisle girer. Karar ve gerekcesi
 * docs/P177-kararlar.md'de.
 *
 * =========================================================================
 * ZORUNLU IKI ONAY GONDERIMI ENGELLER — HEM PAROLA HEM SOSYAL YOLDA
 * =========================================================================
 * `dugmeKilitli` tek bir yerden hesaplanir ve hem gonder dugmesine hem
 * `SsoDugmeleri`ne verilir. Iki ayri kontrol yazmak, birinin bir gun
 * gunceIlenip otekinin unutulmasi demekti.
 */
type Adim = "bilgiler" | "kod" | "tesis" | "bitti";

const BOS = {
  ad: "",
  soyad: "",
  eposta: "",
  telefon: "",
  parola: "",
  parolaTekrar: "",
};

export function KayitFormu() {
  const [adim, setAdim] = useState<Adim>("bilgiler");
  const [alanlar, setAlanlar] = useState(BOS);
  const [onaySozlesme, setOnaySozlesme] = useState(false);
  const [onayKvkk, setOnayKvkk] = useState(false);
  const [onayTicari, setOnayTicari] = useState(false);
  const [kod, setKod] = useState("");
  const [tesisAd, setTesisAd] = useState("");
  const [kurulumJetonu, setKurulumJetonu] = useState("");
  const [tesisKodu, setTesisKodu] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiliyor, setGonderiliyor] = useState(false);

  // Zorunlu iki onay — TEK kaynak. Ucuncu onay (ticari ileti) ISTEGE
  // BAGLI ve burada ARANMAZ.
  const onaylarTamam = onaySozlesme && onayKvkk;
  const dugmeKilitli = !onaylarTamam || gonderiliyor;

  function yaz(alan: keyof typeof BOS, deger: string) {
    setAlanlar((o) => ({ ...o, [alan]: deger }));
  }

  /**
   * Ortak gonderim: hata metnini backend'den ALDIGI GIBI gosterir.
   *
   * ZARF TEK BICIM: `{ error: { code, message } }`. Backend'in hata
   * isleyicisi bunu uretiyor ve `message` alani ISTEGIN DILINDE geliyor
   * (`Accept-Language`); BFF kendi hatalarini da ayni zarfla doner
   * (`lib/backend.ts::hataZarfi`).
   *
   * YEDEK METIN YALNIZ ZARF OKUNAMAZSA: sunucu ne dediyse o gosterilir.
   * Genel bir "bir hata olustu" ile ezmek, kullanicinin gordugu metni
   * sunucunun soyledigi seyden koparirdi — P175'te olculen kusur sinifi.
   */
  async function gonder(yol: string, govde: unknown): Promise<Record<string, unknown> | null> {
    setHata(null);
    setGonderiliyor(true);
    try {
      const yanit = await fetch(yol, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(govde),
      });
      const veri = (await yanit.json().catch(() => ({}))) as {
        error?: { message?: string };
      } & Record<string, unknown>;
      if (!yanit.ok) {
        const metin = veri.error?.message;
        setHata(
          typeof metin === "string" && metin.trim() !== ""
            ? metin
            : "İşlem tamamlanamadı. Lütfen bilgileri kontrol edip tekrar deneyin.",
        );
        return null;
      }
      return veri;
    } catch {
      setHata("Sunucuya ulaşılamadı. Lütfen birazdan tekrar deneyin.");
      return null;
    } finally {
      setGonderiliyor(false);
    }
  }

  async function bilgileriGonder(olay: React.FormEvent) {
    olay.preventDefault();
    if (!onaylarTamam) {
      setHata("Devam etmek için Kullanıcı Sözleşmesi ve KVKK Aydınlatma Metni onaylarını işaretleyin.");
      return;
    }
    if (alanlar.parola !== alanlar.parolaTekrar) {
      setHata("İki parola alanı aynı değil.");
      return;
    }
    const veri = await gonder("/api/kayit/basvuru", {
      ad: alanlar.ad,
      soyad: alanlar.soyad,
      eposta: alanlar.eposta,
      telefon: alanlar.telefon,
      parola: alanlar.parola,
      onay_sozlesme: onaySozlesme,
      onay_kvkk: onayKvkk,
      onay_ticari: onayTicari,
    });
    if (veri) setAdim("kod");
  }

  /**
   * Kodu TAZELER. Ayni govdeyi yeniden gonderir — arka uc acik
   * basvuruyu tazeleyip yeni kod uretir (bkz. `yonetici_basvuru_ekle`
   * UPSERT'i). Parola durumda tutuldugu icin kullaniciya tekrar
   * yazdirilmiyor.
   */
  async function kodTekrarGonder() {
    setKod("");
    const veri = await gonder("/api/kayit/basvuru", {
      ad: alanlar.ad,
      soyad: alanlar.soyad,
      eposta: alanlar.eposta,
      telefon: alanlar.telefon,
      parola: alanlar.parola,
      onay_sozlesme: onaySozlesme,
      onay_kvkk: onayKvkk,
      onay_ticari: onayTicari,
    });
    if (veri) setHata(null);
  }

  async function kodGonder(olay: React.FormEvent) {
    olay.preventDefault();
    const veri = await gonder("/api/kayit/dogrula", {
      eposta: alanlar.eposta,
      kod,
    });
    if (veri && typeof veri.kurulum_jetonu === "string") {
      setKurulumJetonu(veri.kurulum_jetonu);
      setAdim("tesis");
    }
  }

  async function tesisGonder(olay: React.FormEvent) {
    olay.preventDefault();
    const veri = await gonder("/api/kayit/tesis", {
      kurulum_jetonu: kurulumJetonu,
      tesis_ad: tesisAd,
    });
    if (veri && typeof veri.tesis_kodu === "string") {
      setTesisKodu(veri.tesis_kodu);
      setAdim("bitti");
    }
  }

  // ---------------------------------------------------------------- 4) bitti
  if (adim === "bitti") {
    return (
      <div className="kart space-y-5 p-6 sm:p-8">
        <p className="etiket">Kayıt tamamlandı</p>
        <h2 className="text-bolum">{tesisAd} hazır.</h2>
        <div className="rounded-kart border border-cizgi bg-zemin p-5">
          <p className="text-kucuk font-semibold text-soluk">Tesis ID</p>
          <p className="mt-1 select-all text-[1.75rem] font-extrabold tracking-[0.04em] text-lacivert">
            {tesisKodu}
          </p>
          <p className="mt-2 text-kucuk text-govde">
            Bu kodu sitenizdeki kişilerle paylaşacaksınız. Aynı kod
            e-posta adresinize de gönderildi.
          </p>
        </div>
        <div className="flex flex-wrap gap-3">
          <a className="dugme-birincil" href={APP_ADRESI} rel="noreferrer noopener">
            Giriş yap
          </a>
        </div>
        <div className="border-t border-cizgi pt-5">
          <p className="mb-3 text-kucuk font-semibold text-baslik">
            Uygulamayı da indirin
          </p>
          <MagazaDugmeleri />
        </div>
      </div>
    );
  }

  // ---------------------------------------------------------------- 3) tesis
  if (adim === "tesis") {
    return (
      <form className="kart space-y-5 p-6 sm:p-8" onSubmit={tesisGonder}>
        <p className="etiket">Adım 3 / 3</p>
        <h2 className="text-bolum">Sitenizin adı nedir?</h2>
        <p className="text-kucuk text-soluk">
          Tesis kaydınız bu adla açılır ve size bir Tesis ID verilir.
        </p>
        <div>
          <label className="alan-etiket" htmlFor="tesis-ad">Site adı</label>
          <input
            id="tesis-ad"
            className="alan"
            required
            maxLength={120}
            autoComplete="organization"
            value={tesisAd}
            onChange={(e) => setTesisAd(e.target.value)}
          />
        </div>
        <HataDurumu mesaj={hata} />
        <button className="dugme-birincil w-full" type="submit" disabled={gonderiliyor}>
          {gonderiliyor ? "Oluşturuluyor…" : "Tesisi oluştur"}
        </button>
      </form>
    );
  }

  // ------------------------------------------------------------------ 2) kod
  if (adim === "kod") {
    return (
      <form className="kart space-y-5 p-6 sm:p-8" onSubmit={kodGonder}>
        <p className="etiket">Adım 2 / 3</p>
        <h2 className="text-bolum">E-postanızı doğrulayın</h2>
        <p className="text-kucuk text-soluk">
          <span className="font-semibold text-govde">{alanlar.eposta}</span>{" "}
          adresine 6 haneli bir kod gönderdik.
        </p>
        <div>
          <label className="alan-etiket" htmlFor="kod">Doğrulama kodu</label>
          <input
            id="kod"
            className="alan text-center text-[1.5rem] font-bold tracking-[0.35em]"
            required
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            value={kod}
            onChange={(e) => setKod(e.target.value.replace(/\D/g, ""))}
          />
        </div>
        <HataDurumu mesaj={hata} />
        <button className="dugme-birincil w-full" type="submit" disabled={gonderiliyor}>
          {gonderiliyor ? "Doğrulanıyor…" : "Doğrula ve devam et"}
        </button>

        {/* KODU TEKRAR GONDER — arka ucta ayri bir uc YOK ve gerekmiyor:
            basvuru ucu ayni adresle ikinci kez cagrildiginda ACIK
            basvuruyu TAZELER (yeni kod, sifirlanan deneme sayaci). Yeni
            bir uc acmak, ayni kurali ikinci kez yazmak olurdu.

            `type="button"`: form icinde `type` yazilmayan bir dugme
            GONDERIM dugmesidir ve kodu dogrulamaya calisirdi. */}
        <button
          type="button"
          disabled={gonderiliyor}
          onClick={() => void kodTekrarGonder()}
          className="w-full text-center text-kucuk font-semibold text-mavi underline disabled:no-underline disabled:opacity-60"
        >
          Kod gelmediyse tekrar gönder
        </button>
      </form>
    );
  }

  // ------------------------------------------------------------- 1) bilgiler
  return (
    <form className="kart space-y-6 p-6 sm:p-8" onSubmit={bilgileriGonder}>
      <div>
        <p className="etiket">Adım 1 / 3</p>
        <h2 className="mt-2 text-bolum">Yönetici hesabı oluşturun</h2>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label className="alan-etiket" htmlFor="ad">Ad</label>
          <input id="ad" className="alan" required autoComplete="given-name"
            value={alanlar.ad} onChange={(e) => yaz("ad", e.target.value)} />
        </div>
        <div>
          <label className="alan-etiket" htmlFor="soyad">Soyad</label>
          <input id="soyad" className="alan" required autoComplete="family-name"
            value={alanlar.soyad} onChange={(e) => yaz("soyad", e.target.value)} />
        </div>
        <div className="sm:col-span-2">
          <label className="alan-etiket" htmlFor="eposta">E-posta</label>
          <input id="eposta" className="alan" required type="email" autoComplete="email"
            value={alanlar.eposta} onChange={(e) => yaz("eposta", e.target.value)} />
          <p className="alan-yardim">Doğrulama kodu ve Tesis ID bu adrese gider.</p>
        </div>
        <div className="sm:col-span-2">
          <label className="alan-etiket" htmlFor="telefon">Telefon</label>
          <input id="telefon" className="alan" required type="tel" autoComplete="tel"
            placeholder="05xx xxx xx xx"
            value={alanlar.telefon} onChange={(e) => yaz("telefon", e.target.value)} />
          {/* SMS GONDERILMEZ (§6). Kullaniciya bunu SOYLEMEK gerekiyor:
              telefon isteyen bir form, dogrulama SMS'i bekletir. */}
          <p className="alan-yardim">
            Yalnızca iletişim için. Bu numaraya SMS gönderilmez.
          </p>
        </div>
        <div>
          <label className="alan-etiket" htmlFor="parola">Parola</label>
          <input id="parola" className="alan" required type="password" minLength={8}
            autoComplete="new-password"
            value={alanlar.parola} onChange={(e) => yaz("parola", e.target.value)} />
          {/* Sunucudaki politika (`validate_password_strength`) ile AYNI.
              Yalniz "8 karakter" yazmak, kullaniciyi sunucunun 422 ile
              reddedecegi bir parolayi yazmaya davet etmek olurdu. */}
          <p className="alan-yardim">
            En az 8 karakter; büyük harf, rakam ve sembol (! ? @ # . -) içermeli.
          </p>
        </div>
        <div>
          <label className="alan-etiket" htmlFor="parola2">Parola (tekrar)</label>
          <input id="parola2" className="alan" required type="password" minLength={8}
            autoComplete="new-password"
            value={alanlar.parolaTekrar} onChange={(e) => yaz("parolaTekrar", e.target.value)} />
        </div>
      </div>

      <fieldset className="space-y-3 border-t border-cizgi pt-6">
        <legend className="gizli-erisilebilir">Onaylar</legend>
        <OnayKutusu
          id="onay-sozlesme"
          isaretli={onaySozlesme}
          degistir={setOnaySozlesme}
          zorunlu
        >
          <Link className="font-semibold text-mavi underline" href="/kullanici-sozlesmesi" target="_blank">
            Kullanıcı Sözleşmesi
          </Link>
          ’ni okudum ve kabul ediyorum.
        </OnayKutusu>
        <OnayKutusu id="onay-kvkk" isaretli={onayKvkk} degistir={setOnayKvkk} zorunlu>
          <Link className="font-semibold text-mavi underline" href="/kvkk-aydinlatma" target="_blank">
            KVKK Aydınlatma Metni
          </Link>
          ’ni okudum.
        </OnayKutusu>
        <OnayKutusu id="onay-ticari" isaretli={onayTicari} degistir={setOnayTicari}>
          Ticari elektronik ileti almayı onaylıyorum.{" "}
          <Link className="font-semibold text-mavi underline" href="/kullanici-sozlesmesi#ticari-ileti" target="_blank">
            Ayrıntılar
          </Link>
        </OnayKutusu>
      </fieldset>

      <HataDurumu mesaj={hata} />

      <button className="dugme-birincil w-full" type="submit" disabled={dugmeKilitli}>
        {gonderiliyor ? "Gönderiliyor…" : "Kayıt Ol"}
      </button>

      <div className="flex items-center gap-3 text-kucuk text-soluk">
        <span className="h-px flex-1 bg-cizgi" />
        veya
        <span className="h-px flex-1 bg-cizgi" />
      </div>

      <SsoDugmeleri
            kilitli={!onaylarTamam}
            onaylar={{ sozlesme: onaySozlesme, kvkk: onayKvkk, ticari: onayTicari }}
          />

      {/* KILIDIN SEBEBI YAZILIYOR. Tiklanamayan bir dugme, sebebi
          soylenmezse bozuk gorunur — kullanici onaylarla dugmeler
          arasindaki bagi kendiliginden kurmaz. */}
      {!onaylarTamam ? (
        <p className="text-center text-kucuk text-soluk">
          Devam etmek için yukarıdaki iki zorunlu onayı işaretleyin.
        </p>
      ) : null}

      <p className="text-center text-kucuk text-soluk">
        Hesabın var mı?{" "}
        <a className="font-semibold text-mavi underline" href={APP_ADRESI} rel="noreferrer noopener">
          Giriş Yap
        </a>
      </p>
    </form>
  );
}

/**
 * Onay kutusu. `<label>` kutuyu SARMALAR — tiklama alani tum satirdir;
 * kucuk bir kareye nisan almak dokunmatikte gercek bir engel.
 *
 * Icerideki baglantilar `stopPropagation` GEREKTIRMEZ: `<a>` tiklamasi
 * label'in varsayilan davranisini zaten tetiklemez (tarayici etkilesimli
 * bir soyu label hedefi saymaz). Buna guvenmek yerine baglantilar
 * `target="_blank"` ile ayri sekmede aciliyor — kullanici formu
 * kaybetmeden belgeyi okuyabilsin.
 */
function OnayKutusu({
  id,
  isaretli,
  degistir,
  zorunlu = false,
  children,
}: {
  id: string;
  isaretli: boolean;
  degistir: (d: boolean) => void;
  zorunlu?: boolean;
  children: React.ReactNode;
}) {
  return (
    <label htmlFor={id} className="flex cursor-pointer items-start gap-3 text-kucuk text-govde">
      <input
        id={id}
        type="checkbox"
        checked={isaretli}
        required={zorunlu}
        onChange={(e) => degistir(e.target.checked)}
        className="mt-0.5 h-5 w-5 shrink-0 accent-mavi"
      />
      <span>
        {children}
        {zorunlu ? (
          <span className="ml-1 font-bold text-hata" aria-hidden="true">*</span>
        ) : (
          <span className="ml-1 text-soluk">(isteğe bağlı)</span>
        )}
      </span>
    </label>
  );
}
