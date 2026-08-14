"use client";

/**
 * (P160 / Asama 5) ROTA SAHNESI — devriye rotasi ve nokta durumu.
 *
 * Tasarimi `docs/3d-yol-haritasi.md` §4'te bir tur once yazilmisti;
 * bu dosya onu uyguluyor.
 *
 * =========================================================================
 * GERCEK KOORDINAT YOK VE UYDURULMUYOR
 * =========================================================================
 * NFC noktalarinin `gps_lat/gps_lng` alanlari OPSIYONELDIR ve sahada
 * cogu bos. Bir kismi dolu bir kismi bos olan veriyle harita cizmek,
 * "bu nokta gercekten burada" iddiasini yarisi yanlis olacak sekilde
 * kurmakti. Elimizde KESIN olan tek mekansal bilgi SIRADIR (plan
 * noktalari `sira` ile tutuluyor) — sahne de yalniz onu kullanir:
 * noktalar bir egri uzerine SIRAYLA dizilir.
 *
 * Yani bu sahne bir HARITA DEGIL, bir AKIS SEMASIDIR ve oyle
 * etiketlenir.
 *
 * =========================================================================
 * VERIYE BAGLI — DEKOR DEGIL
 * =========================================================================
 * Her nokta bir KAYDA baglidir ve durumu SUNUCUDAN turetilir:
 *   * okutuldu -> yesil   (`GET /scans` — bugun okutulmus)
 *   * gecikti  -> amber   (pano alarmi `gecikmis_okutma`)
 *   * atlandi  -> kirmizi (pano alarmi `eksik_checkpoint`)
 *   * bekliyor -> notr
 * Cizgi ILERLEMEYE gore iki renge bolunur: tamamlanan kisim yesil,
 * kalan kisim notr.
 *
 * SIRASIZ KULLANIM: `/checkpoints` sayfasinda bir ROTA YOKTUR (noktalar
 * bir plana bagli degil). Orada `rotaCizgisi={false}` verilir ve sahne
 * cizgiyi HIC cizmez — olmayan bir sirayi cizmek, kullaniciya var
 * olmayan bir devriye yolu gostermek olurdu.
 */
import { Canvas, useFrame } from "@react-three/fiber";
import { Html, OrbitControls } from "@react-three/drei";
import { useMemo, useRef, useState } from "react";
import { CatmullRomCurve3, Vector3, type Mesh } from "three";

export type RotaNoktaDurumu = "okutuldu" | "gecikti" | "atlandi" | "bekliyor";

export interface RotaNoktasi {
  id: string;
  ad: string;
  durum: RotaNoktaDurumu;
  /** Plandaki sira; sirasiz kullanimda liste sirasi kullanilir. */
  sira?: number;
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`). WebGL malzemesi CSS
// degiskeni okuyamaz; renkler sabit ama arayuzun `--yz-*-edge` ailesiyle
// AYNI degerler (bina sahnesindeki tabloyla da ayni).
const RENK_OKUTULDU = "#3fa97a";
const RENK_GECIKTI = "#d6963c";
const RENK_ATLANDI = "#d45b5e";
const RENK_BEKLIYOR = "#7e8c9c";
const CIZGI_KALAN_KOYU = "#4a5560";
const CIZGI_KALAN_ACIK = "#c3ccd6";
const ZEMIN_KOYU = "#2a333b";
const ZEMIN_ACIK = "#f7f9fb";
const ISIK_KOYU = "#9fc0e0";
const ISIK_ACIK = "#ffffff";
const PLATFORM_KOYU = "#39434d";
const PLATFORM_ACIK = "#e8eef4";
const DONGU_SUREKLI = "always" as const;
const DONGU_TALEP = "demand" as const;

const DURUM_RENGI: Record<RotaNoktaDurumu, string> = {
  okutuldu: RENK_OKUTULDU,
  gecikti: RENK_GECIKTI,
  atlandi: RENK_ATLANDI,
  bekliyor: RENK_BEKLIYOR,
};

/** Egri uzerinde `n` nokta icin KARARLI konumlar.
 *
 * Rastgelelik YOK: ayni girdi her zaman ayni sahneyi verir. Aksi halde
 * her cizimde rota yer degistirir ve kullanici "bir sey mi degisti?"
 * diye bakardi.
 */
function egriKur(n: number): CatmullRomCurve3 {
  if (n <= 1) return new CatmullRomCurve3([new Vector3(0, 0.35, 0), new Vector3(0, 0.35, 0)]);
  // Yumusak bir "S" — noktalar birbirini gormeyecek kadar acik dizilir.
  const genislik = Math.max(4, n * 1.05);
  const kontrol: Vector3[] = [];
  for (let i = 0; i < n; i++) {
    const o = n === 1 ? 0 : i / (n - 1);
    kontrol.push(
      new Vector3(
        (o - 0.5) * genislik,
        0.35,
        Math.sin(o * Math.PI * 1.5) * 1.6,
      ),
    );
  }
  return new CatmullRomCurve3(kontrol, false, "catmullrom", 0.35);
}

/** Tek nokta — atlanmis nokta nabiz atar (dikkat ister). */
function Nokta({
  nokta,
  konum,
  sira,
  hareketVar,
}: {
  nokta: RotaNoktasi;
  konum: [number, number, number];
  sira: number;
  hareketVar: boolean;
}) {
  const ref = useRef<Mesh>(null);
  const [uzerinde, setUzerinde] = useState(false);

  useFrame(({ clock }) => {
    if (!ref.current) return;
    // NABIZ YALNIZ ATLANMIS NOKTADA ve YALNIZ hareket aciksa:
    // `prefers-reduced-motion` sahneyi de baglar.
    if (!hareketVar || nokta.durum !== "atlandi") {
      ref.current.scale.setScalar(1);
      return;
    }
    ref.current.scale.setScalar(1 + Math.sin(clock.getElapsedTime() * 4) * 0.18);
  });

  return (
    <group position={konum}>
      <mesh
        ref={ref}
        castShadow
        onPointerOver={(e) => {
          e.stopPropagation();
          setUzerinde(true);
        }}
        onPointerOut={() => setUzerinde(false)}
      >
        <sphereGeometry args={[0.22, 20, 20]} />
        <meshStandardMaterial
          color={DURUM_RENGI[nokta.durum]}
          emissive={DURUM_RENGI[nokta.durum]}
          emissiveIntensity={nokta.durum === "bekliyor" ? 0 : 0.45}
          roughness={0.4}
        />
      </mesh>

      {uzerinde && (
        // `Html`: 3B konuma bagli ama DOM'da cizilen ETIKET — sahne
        // icine cizilmis bir doku olsaydi hicbir yardimci teknoloji
        // okuyamazdi.
        <Html position={[0, 0.5, 0]} center distanceFactor={10}>
          <span
            style={{
              background: "var(--yz-surface-1)",
              color: "var(--yz-text)",
              border: "1px solid var(--yz-border)",
              borderRadius: "var(--yz-radius-chip)",
              boxShadow: "var(--yz-raised)",
              fontSize: "var(--yz-fs-xs)",
              padding: "2px 8px",
              whiteSpace: "nowrap",
            }}
          >
            {sira}. {nokta.ad}
          </span>
        </Html>
      )}
    </group>
  );
}

/** Rota cizgisi — ILERLEMEYE gore iki parca. */
function RotaCizgisi({
  egri,
  ilerleme,
  koyu,
}: {
  egri: CatmullRomCurve3;
  ilerleme: number;
  koyu: boolean;
}) {
  // Tek bir cizgiyi renk gecisiyle bolmek yerine IKI cizgi: WebGL'de
  // parcali renk bir shader isi ve bu sahnenin tasidigi bilgi icin
  // fazla makine.
  const { tamam, kalan } = useMemo(() => {
    const adim = 64;
    const hepsi = egri.getPoints(adim);
    const kesim = Math.max(1, Math.round(adim * Math.min(1, Math.max(0, ilerleme))));
    return { tamam: hepsi.slice(0, kesim + 1), kalan: hepsi.slice(kesim) };
  }, [egri, ilerleme]);

  return (
    <group>
      {tamam.length > 1 && (
        <line>
          <bufferGeometry>
            <bufferAttribute
              attach="attributes-position"
              args={[new Float32Array(tamam.flatMap((p) => [p.x, p.y, p.z])), 3]}
            />
          </bufferGeometry>
          <lineBasicMaterial color={RENK_OKUTULDU} linewidth={2} />
        </line>
      )}
      {kalan.length > 1 && (
        <line>
          <bufferGeometry>
            <bufferAttribute
              attach="attributes-position"
              args={[new Float32Array(kalan.flatMap((p) => [p.x, p.y, p.z])), 3]}
            />
          </bufferGeometry>
          <lineBasicMaterial color={koyu ? CIZGI_KALAN_KOYU : CIZGI_KALAN_ACIK} />
        </line>
      )}
    </group>
  );
}

export interface RotaSahnesiProps {
  noktalar: RotaNoktasi[];
  /**
   * Rota cizgisi cizilsin mi. `/checkpoints`te SIRA YOKTUR ve cizgi
   * cizmek olmayan bir devriye yolu gostermek olurdu.
   */
  rotaCizgisi?: boolean;
  koyu?: boolean;
  hareketVar?: boolean;
}

export default function RotaSahnesi({
  noktalar,
  rotaCizgisi = true,
  koyu = false,
  hareketVar = true,
}: RotaSahnesiProps) {
  // Siralama: plan `sira` verdiyse ona gore, vermediyse liste sirasi
  // korunur (kararli olmasi yeter).
  const sirali = useMemo(
    () => [...noktalar].sort((a, b) => (a.sira ?? 0) - (b.sira ?? 0)),
    [noktalar],
  );
  const egri = useMemo(() => egriKur(sirali.length), [sirali.length]);
  const konumlar = useMemo(
    () =>
      sirali.map((_, i) => {
        const o = sirali.length <= 1 ? 0 : i / (sirali.length - 1);
        const v = egri.getPointAt(o);
        return [v.x, v.y, v.z] as [number, number, number];
      }),
    [egri, sirali],
  );

  // ILERLEME OKUTULANDAN TURETILIR, disaridan alinmaz: iki kaynak
  // olsaydi cizgi ile noktalar birbirini yalanlayabilirdi.
  const ilerleme =
    sirali.length === 0
      ? 0
      : sirali.filter((n) => n.durum === "okutuldu").length / sirali.length;

  // Kamera uzakligi nokta sayisina gore: 3 noktali bir plan ile 15
  // noktali bir plan ayni cerceveye sigmaz.
  const uzaklik = Math.max(7, sirali.length * 0.9);

  return (
    <Canvas
      shadows
      dpr={[1, 2]}
      camera={{ position: [0, uzaklik * 0.55, uzaklik], fov: 40 }}
      // FPS BUTCESI: hareketsiz sahne KARE CIZMEZ.
      frameloop={hareketVar ? DONGU_SUREKLI : DONGU_TALEP}
      style={{ width: "100%", height: "100%" }}
    >
      <color attach="background" args={[koyu ? ZEMIN_KOYU : ZEMIN_ACIK]} />
      <ambientLight intensity={koyu ? 0.55 : 0.8} color={koyu ? ISIK_KOYU : ISIK_ACIK} />
      <directionalLight position={[4, 8, 5]} intensity={koyu ? 1 : 1.3} castShadow />

      {/* Ince platform — noktalar havada yuzmesin. */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <circleGeometry args={[Math.max(5, sirali.length * 0.75), 48]} />
        <meshStandardMaterial color={koyu ? PLATFORM_KOYU : PLATFORM_ACIK} roughness={0.9} />
      </mesh>

      {rotaCizgisi && sirali.length > 1 && (
        <RotaCizgisi egri={egri} ilerleme={ilerleme} koyu={koyu} />
      )}

      {sirali.map((n, i) => (
        <Nokta
          key={n.id}
          nokta={n}
          konum={konumlar[i]}
          sira={i + 1}
          hareketVar={hareketVar}
        />
      ))}

      <OrbitControls
        enablePan
        maxPolarAngle={Math.PI / 2.2}
        minDistance={4}
        maxDistance={uzaklik * 2.5}
        autoRotate={false}
      />
    </Canvas>
  );
}
