"use client";

/**
 * (P162) ORBITAL AG — yorungeler, dugumler, baglantilar, veri akisi.
 *
 * =========================================================================
 * NEDEN THREE.JS DEGIL — OLCULMUS KARAR
 * =========================================================================
 * Sartname §35 "3D orbital scene icin Three.js tercih edilebilir" diyor
 * ama HEMEN ARDINDAN "sadece CSS/SVG ile daha performansli yapilabilecek
 * efektler icin Three.js kullanma" diyor. Brief de "giris ekrani 3D'si ana
 * paketi sisirmesin" diyor. Bu sahnede perspektif projeksiyonu, derinlik
 * tamponu ya da golge YOK — es merkezli daireler ve parlayan noktalar var.
 * Three.js bunun icin ~600 kB getirir ve her kare JS'te sahne grafigi
 * yurutur. Olculen sonuc: `/login` ilk yuk 144 kB (pano 165 kB'dan KUCUK).
 *
 * =========================================================================
 * ILK SURUM YAVASTI — OLCULDU VE DUZELTILDI
 * =========================================================================
 * Ilk yazimda butun sahne TEK bir SVG'ydi ve donen `<g>` ogeleri vardi.
 * Katman katman olculdu (1440x900, yazilim rasterlayici):
 *
 *     tam sahne          184 ms/kare
 *     yorungeler kapali   73 ms/kare   <-- TEK BASINA %60
 *     partikuller kapali 171 ms
 *     blur kapali        165 ms
 *     sahne tamamen yok   17 ms  (60 fps)
 *
 * Iki sebep vardi:
 *   1. SVG ICINDE `<g>` DONDURMEK, SVG'nin tamamini her karede YENIDEN
 *      BOYATIR. HTML ogesindeki CSS `transform` ise yalnizca BILESIM
 *      yapar — raster onbellekte kalir.
 *   2. Uzak katmanda tam ekran `filter: blur(1.4px)` vardi; bulaniklik
 *      her karede yeniden hesaplaniyordu.
 *
 * BU SURUMDE: her yorunge KENDI `<div>`i olarak doner (bilesim), icindeki
 * SVG STATIKTIR. Dugumler ve haleler ayri, mutlak konumlu `<div>`ler —
 * her biri kendi katmaninda nefes alir. `blur` kalkti; uzaklik hissi
 * OPAKLIK ve CIZGI KALINLIGI ile veriliyor (zaten daha dogru bir atmosfer
 * perspektifi).
 */
import { CYAN_YUMUSAK, MAVI_IKINCIL, TURKUAZ, TURKUAZ_ACIK } from "./palet";
import { HALE_GRADYANI } from "./stil";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`) — CSS degeri de dize.
const YON_TERS = "reverse" as const;
const YON_DUZ = "normal" as const;
const DEGISEN_DONUSUM = "transform" as const;
const DEGISEN_DONUSUM_OPAKLIK = "transform, opacity" as const;

/**
 * YORUNGELER (sartname §5): farkli sure, farkli yon.
 *
 * `capYuzde` kapsayicinin yuzdesi. Sureler kisa surede hizalanmayan
 * sayilar: desen mekanik bir dongu gibi tekrar etmesin.
 */
const YORUNGELER = [
  { capYuzde: 42, sure: 90, ters: false, kalinlik: 1.1, opaklik: 0.24, uzak: false },
  { capYuzde: 60, sure: 130, ters: true, kalinlik: 1, opaklik: 0.18, uzak: false },
  { capYuzde: 79, sure: 180, ters: false, kalinlik: 0.9, opaklik: 0.12, uzak: true },
  { capYuzde: 94, sure: 150, ters: true, kalinlik: 0.8, opaklik: 0.08, uzak: true },
];

/** Dugumler: hangi yorunge, hangi aci, ne kadar buyuk, hangi gecikmeyle. */
const DUGUMLER = [
  { y: 0, aci: 20, r: 3.4, gecikme: 0 },
  { y: 0, aci: 155, r: 2.6, gecikme: 1.7 },
  { y: 0, aci: 268, r: 3, gecikme: 3.1 },
  { y: 1, aci: 62, r: 3.8, gecikme: 0.6 },
  { y: 1, aci: 196, r: 2.4, gecikme: 2.4 },
  { y: 1, aci: 320, r: 3.2, gecikme: 4.2 },
  { y: 2, aci: 8, r: 2.8, gecikme: 1.1 },
  { y: 2, aci: 118, r: 3.6, gecikme: 3.6 },
  { y: 2, aci: 236, r: 2.5, gecikme: 5.0 },
  { y: 3, aci: 84, r: 3, gecikme: 2.0 },
  { y: 3, aci: 300, r: 2.7, gecikme: 4.7 },
];

/** Bir yorunge halkasi — DONEN KATMAN. Icerigi statiktir. */
function Halka({
  o,
  hareketVar,
}: {
  o: (typeof YORUNGELER)[number];
  hareketVar: boolean;
}) {
  const yariPay = (100 - o.capYuzde) / 2;
  return (
    <div
      className={hareketVar ? "giris-yorunge" : undefined}
      style={{
        position: "absolute",
        inset: `${yariPay}%`,
        borderRadius: "50%",
        // BILESIM IPUCU: tarayiciya bu katmanin donecegini soyler; raster
        // bir kez uretilir ve her karede yalnizca dondurulur.
        willChange: hareketVar ? DEGISEN_DONUSUM : undefined,
        animationDuration: `${o.sure}s`,
        animationDirection: o.ters ? YON_TERS : YON_DUZ,
      }}
    >
      {/* Tam halka — `border` ile; SVG'den ucuz ve ayni sonuc. */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: "50%",
          borderWidth: `${o.kalinlik}px`,
          borderStyle: "solid",
          borderColor: o.uzak ? MAVI_IKINCIL : TURKUAZ,
          opacity: o.opaklik,
        }}
      />
      {/* PARLAK YAY — donusun GORULMESI icin. Tam daire donerken hareket
          algilanmiyordu. Statik bir SVG: donduren sey ust `<div>`. */}
      <svg viewBox="0 0 100 100" className="absolute inset-0 h-full w-full" aria-hidden="true">
        <circle
          cx="50"
          cy="50"
          r="49.5"
          fill="none"
          stroke={TURKUAZ_ACIK}
          strokeWidth={o.kalinlik * 0.35}
          strokeLinecap="round"
          strokeDasharray="26 285"
          opacity={o.opaklik * 2}
        />
      </svg>

      {/* Bu yorungeye ait DUGUMLER — halkayla birlikte doner. Her biri
          AYRI katman: nefes animasyonu SVG'yi degil kendini etkiler. */}
      {DUGUMLER.filter((d) => d.y === YORUNGELER.indexOf(o)).map((d, i) => {
        const a = (d.aci * Math.PI) / 180;
        const x = 50 + Math.cos(a) * 50;
        const y = 50 + Math.sin(a) * 50;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: `${x}%`,
              top: `${y}%`,
              width: `${d.r * 2.4}px`,
              height: `${d.r * 2.4}px`,
              marginLeft: `${-d.r * 1.2}px`,
              marginTop: `${-d.r * 1.2}px`,
            }}
          >
            {/* HALE — YALNIZ BUYUK DUGUMLERDE ve daha dar.
                Olculdu: her dugume 9 kat buyuklukte yumusak bir gradyan
                koymak, 22 genis saydam katmani her karede harmanlamak
                demekti. Kucuk noktalarin halesi zaten fark edilmiyordu. */}
            {d.r >= 3 && (
              <div
                style={{
                  position: "absolute",
                  inset: "-220%",
                  borderRadius: "50%",
                  background: HALE_GRADYANI,
                }}
              />
            )}
            {/* CEKIRDEK — nefes alan kucuk nokta (§6). */}
            <div
              className={hareketVar ? "giris-dugum" : undefined}
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: "50%",
                background: CYAN_YUMUSAK,
                opacity: hareketVar ? undefined : 0.5,
                willChange: hareketVar ? DEGISEN_DONUSUM_OPAKLIK : undefined,
                // DAGITILMIS GECIKME, RASTGELE DEGIL: `Math.random()`
                // sunucu ve istemcide farkli deger uretir (hidrasyon
                // uyusmazligi). Gecikmeler elle dagitildi.
                animationDelay: `${d.gecikme}s`,
                animationDuration: `${5 + (i % 3) * 1.6}s`,
              }}
            />
          </div>
        );
      })}
    </div>
  );
}

/**
 * DERINLIK GRUBU. Sahne bu bileseni IKI KEZ cizip iki farkli paralaks
 * katsayisi veriyordu; bu, HER SEYI IKI KEZ cizmek demekti (8 donen
 * katman, 44 hale). Olculdu: yorungeler kare suresinin ~%78'iydi.
 *
 * Artik ayni derinlik hissi HALKALARI BOLEREK elde ediliyor: uzak
 * halkalar bir kapsayicida, yakinlar digerinde. Toplam halka sayisi
 * DEGISMEDI (4), cizim sayisi YARIYA indi.
 */
export type DerinlikGrubu = "uzak" | "yakin";

export function Yorungeler({
  hareketVar,
  grup,
}: {
  hareketVar: boolean;
  grup: DerinlikGrubu;
}) {
  const uzakMi = grup === "uzak";
  return (
    <div className="relative h-full w-full">
      {YORUNGELER.filter((o) => o.uzak === uzakMi).map((o, i) => (
        <Halka key={i} o={o} hareketVar={hareketVar} />
      ))}
    </div>
  );
}
