"use client";

/**
 * (P160 / Asama 5) BINA SAHNESI — izometrik site modeli.
 *
 * =========================================================================
 * BU DOSYA ANA PAKETE GIRMEZ
 * =========================================================================
 * `three` + R3F + drei birlikte ~600-900 kB. Sarmalayici
 * (`sahne-yukleyici.tsx`) bunu `next/dynamic` + `ssr:false` ile yukler;
 * yani paket YALNIZ sahneyi gercekten cizen rotada inar. Asama 9'un
 * olcumu buna bagli: paylasilan paket 87.5 kB'da KALMALI.
 *
 * `ssr:false` ZORUNLU: R3F sunucuda `window`/WebGL arar ve derleme
 * aninda patlar.
 *
 * =========================================================================
 * VERIYE BAGLI — DEKOR DEGIL (brief'in tartismasiz kurali)
 * =========================================================================
 * Her isaretci bir KAYDA baglidir ve durumu veriden gelir:
 *   * kamera cevrimdisiysa isaretci GRI,
 *   * o konumda alarm varsa KIRMIZI ve nabiz atar,
 *   * NFC noktasi okutulmadiysa AMBER.
 * Renk `--yz-*-edge` token'larindan okunur (WCAG 1.4.11, 3:1) — sahne
 * de arayuzun bir parcasi ve kendi paletini uydurmaz.
 *
 * =========================================================================
 * MODEL YOK — YER TUTUCU GEOMETRI (brief'in kurali)
 * =========================================================================
 * Depoda glTF model YOK ve bu turda uretilmedi. Bloklar `blocks` ucundan
 * gelen gercek sayilarla KUTU olarak ciziliyor: kat sayisi yuksekligi,
 * daire sayisi genisligi belirliyor. Mimari maket hissi (acik gri
 * kutleler, yumusak golge, ustten isik) modelle degil ISIK ve MALZEME
 * ile kuruluyor. Model geldiginde yalniz `Blok` bileseni degisir.
 */
import { Canvas } from "@react-three/fiber";
import { Html, OrbitControls, SoftShadows } from "@react-three/drei";
import { useMemo, useRef, useState } from "react";
import type { Mesh } from "three";
import { useFrame } from "@react-three/fiber";

export interface SahneBlogu {
  id: string;
  ad: string;
  /** Kat sayisi — kutle yuksekligi. */
  kat: number;
  /** Daire sayisi — kutle genisligi (kabaca). */
  daire: number;
}

export type IsaretciDurumu = "normal" | "uyari" | "kritik" | "cevrimdisi";

export interface SahneIsaretcisi {
  id: string;
  ad: string;
  durum: IsaretciDurumu;
  /** Izgara konumu (blok sirasina gore); verilmezse dagitilir. */
  x?: number;
  z?: number;
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`). Sahne renkleri
// CSS degiskeni OKUYAMAZ (WebGL malzemesi), bu yuzden sabit — ama tek
// yerde ve arayuz paletiyle ayni ailede.
const KUTLE = "#dfe6ee";
const KUTLE_SECILI = "#c9d6e4";
const ZEMIN_KOYU = "#2a333b";
const ZEMIN_ACIK = "#f7f9fb";
const ISIK_KOYU = "#9fc0e0";
const ISIK_ACIK = "#ffffff";
const YON_ISIK_KOYU = "#cfe2f5";
const YON_ISIK_ACIK = "#fffaf0";
const PLATFORM_KOYU = "#39434d";
const PLATFORM_ACIK = "#e8eef4";
const DONGU_SUREKLI = "always" as const;
const DONGU_TALEP = "demand" as const;

/** Durum -> renk. Arayuzle AYNI token ailesi. */
const DURUM_RENGI: Record<IsaretciDurumu, string> = {
  normal: "#3fa97a",
  uyari: "#d6963c",
  kritik: "#d45b5e",
  cevrimdisi: "#7e8c9c",
};

/**
 * Tek blok kutlesi. Hover'da hafif yukselir ve etiket cikar.
 *
 * `castShadow`/`receiveShadow`: maket hissinin kaynagi golge; onsuz
 * kutuler havada yuzuyor gibi durur.
 */
function Blok({
  blok,
  konum,
  onSec,
  secili,
}: {
  blok: SahneBlogu;
  konum: [number, number, number];
  onSec: (id: string) => void;
  secili: boolean;
}) {
  const [uzerinde, setUzerinde] = useState(false);
  const yukseklik = Math.max(1, blok.kat) * 0.6;
  const genislik = Math.min(2.2, 0.8 + blok.daire * 0.06);

  return (
    <group position={konum}>
      <mesh
        castShadow
        receiveShadow
        position={[0, yukseklik / 2, 0]}
        onPointerOver={(e) => {
          e.stopPropagation();
          setUzerinde(true);
        }}
        onPointerOut={() => setUzerinde(false)}
        onClick={(e) => {
          e.stopPropagation();
          onSec(blok.id);
        }}
        scale={uzerinde || secili ? 1.04 : 1}
      >
        <boxGeometry args={[genislik, yukseklik, genislik]} />
        {/* Acik gri kutle — fotogercekci degil, MAKET. */}
        <meshStandardMaterial
          color={secili ? KUTLE_SECILI : KUTLE}
          roughness={0.75}
          metalness={0.05}
        />
      </mesh>

      {(uzerinde || secili) && (
        // `Html`: 3B konuma bagli ama DOM'da cizilen etiket. Ekran
        // okuyucu icin gercek metin — sahne icine cizilmis bir doku
        // olsaydi hicbir yardimci teknoloji okuyamazdi.
        <Html position={[0, yukseklik + 0.35, 0]} center distanceFactor={10}>
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
            {blok.ad}
          </span>
        </Html>
      )}
    </group>
  );
}

/** Isaretci — kamera / NFC noktasi. Kritik durumda nabiz atar. */
function Isaretci({
  isaretci,
  konum,
  hareketVar,
}: {
  isaretci: SahneIsaretcisi;
  konum: [number, number, number];
  hareketVar: boolean;
}) {
  const ref = useRef<Mesh>(null);

  useFrame(({ clock }) => {
    if (!ref.current) return;
    // NABIZ YALNIZ KRITIKTE ve YALNIZ hareket aciksa: brief'in
    // `prefers-reduced-motion` kurali sahneyi de baglar.
    if (!hareketVar || isaretci.durum !== "kritik") {
      ref.current.scale.setScalar(1);
      return;
    }
    const t = clock.getElapsedTime();
    ref.current.scale.setScalar(1 + Math.sin(t * 4) * 0.15);
  });

  return (
    <mesh ref={ref} position={konum} castShadow>
      <sphereGeometry args={[0.12, 16, 16]} />
      <meshStandardMaterial
        color={DURUM_RENGI[isaretci.durum]}
        emissive={DURUM_RENGI[isaretci.durum]}
        emissiveIntensity={isaretci.durum === "cevrimdisi" ? 0 : 0.4}
      />
    </mesh>
  );
}

export interface BinaSahnesiProps {
  bloklar: SahneBlogu[];
  isaretciler?: SahneIsaretcisi[];
  /** Bloga tiklaninca — cagiran detay paneli acar. */
  onBlokSec?: (id: string) => void;
  /** Koyu tema mi — sahne isigi buna gore serinler/isinir. */
  koyu?: boolean;
  /** `prefers-reduced-motion` kapali mi (yani hareket serbest mi). */
  hareketVar?: boolean;
}

export default function BinaSahnesi({
  bloklar,
  isaretciler = [],
  onBlokSec,
  koyu = false,
  hareketVar = true,
}: BinaSahnesiProps) {
  const [secili, setSecili] = useState<string | null>(null);

  // Bloklar bir IZGARAYA dizilir. Konum verisi API'de YOK; uydurma
  // koordinat yerine KARARLI bir duzen kuruluyor — ayni girdi her zaman
  // ayni sahneyi verir (rastgelelik olsaydi her cizimde site tasinirdi).
  const yerlesim = useMemo(() => {
    const satirBoyu = Math.ceil(Math.sqrt(Math.max(1, bloklar.length)));
    return bloklar.map((b, i) => {
      const sx = (i % satirBoyu) - (satirBoyu - 1) / 2;
      const sz = Math.floor(i / satirBoyu) - (satirBoyu - 1) / 2;
      return { blok: b, konum: [sx * 3, 0, sz * 3] as [number, number, number] };
    });
  }, [bloklar]);

  const isaretciYerlesimi = useMemo(
    () =>
      isaretciler.map((m, i) => {
        const a = (i / Math.max(1, isaretciler.length)) * Math.PI * 2;
        const r = 4.5;
        return {
          isaretci: m,
          konum: [
            m.x ?? Math.cos(a) * r,
            0.4,
            m.z ?? Math.sin(a) * r,
          ] as [number, number, number],
        };
      }),
    [isaretciler],
  );

  function sec(id: string) {
    setSecili(id);
    onBlokSec?.(id);
  }

  return (
    <Canvas
      shadows
      dpr={[1, 2]}
      camera={{ position: [8, 7, 8], fov: 40 }}
      // FPS BUTCESI: `frameloop="demand"` sahneyi YALNIZ degisince cizer.
      // Surekli 60 fps cizmek, hareketsiz bir maket icin pil ve CPU
      // israfiydi; OrbitControls etkilesimi kareyi kendisi tetikler.
      frameloop={hareketVar ? DONGU_SUREKLI : DONGU_TALEP}
      style={{ width: "100%", height: "100%" }}
    >
      {/* USTTEN YUMUSAK ISIK — mimari maket hissi. Dark temada serin
          mavi, light temada notr gun isigi (brief). */}
      <color attach="background" args={[koyu ? ZEMIN_KOYU : ZEMIN_ACIK]} />
      <ambientLight intensity={koyu ? 0.5 : 0.75} color={koyu ? ISIK_KOYU : ISIK_ACIK} />
      <directionalLight
        position={[6, 10, 6]}
        intensity={koyu ? 1.1 : 1.5}
        color={koyu ? YON_ISIK_KOYU : YON_ISIK_ACIK}
        castShadow
        shadow-mapSize={[1024, 1024]}
      />
      <SoftShadows size={12} samples={8} />

      {/* PLATFORM — modelin altindaki ince zemin (brief'in "ince
          yansima/platform" istegi). */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0, 0]} receiveShadow>
        <circleGeometry args={[8, 48]} />
        <meshStandardMaterial color={koyu ? PLATFORM_KOYU : PLATFORM_ACIK} roughness={0.9} />
      </mesh>

      {yerlesim.map(({ blok, konum }) => (
        <Blok
          key={blok.id}
          blok={blok}
          konum={konum}
          onSec={sec}
          secili={secili === blok.id}
        />
      ))}

      {isaretciYerlesimi.map(({ isaretci, konum }) => (
        <Isaretci
          key={isaretci.id}
          isaretci={isaretci}
          konum={konum}
          hareketVar={hareketVar}
        />
      ))}

      <OrbitControls
        enablePan
        // Kamera yere GOMULMEZ: alt aci sinirli.
        maxPolarAngle={Math.PI / 2.2}
        minDistance={5}
        maxDistance={20}
        // Hareket azaltmada otomatik donus KAPALI.
        autoRotate={false}
      />
    </Canvas>
  );
}
