"use client";

/**
 * (P161) SITE SAHNESI — izometrik mimari maket.
 *
 * =========================================================================
 * BU DOSYA ANA PAKETE GIRMEZ
 * =========================================================================
 * `three` + R3F + drei birlikte ~600-900 kB. Sarmalayici
 * (`sahne-yukleyici.tsx`) bunu `next/dynamic` + `ssr:false` ile yukler;
 * paket YALNIZ sahneyi gercekten cizen rotada iner. `ssr:false` ZORUNLU:
 * R3F sunucuda `window`/WebGL arar.
 *
 * =========================================================================
 * P160'TAKI SAHNE NEDEN YETMEDI
 * =========================================================================
 * Onceki surum her blogu TEK BIR GRI KUTU ciziyordu: kat cizgisi yok,
 * pencere yok, peyzaj yok, daire kavrami hic yok. "Bina" oldugu ancak
 * etiketinden anlasiliyordu. Bu surumde:
 *
 *   * kutle KAT CIZGILERI, BALKON RITMI ve CATI DETAYI tasir,
 *   * HER PENCERE BIR DAIREDIR — sayisi da yeri de veriden gelir,
 *   * zemin peyzajli: yol, otopark, yaya yolu, havuz, agaclar,
 *   * blok -> kat -> daire acilimi var (kamera yumusak gecer).
 *
 * =========================================================================
 * YUZLERCE DAIRE, BLOK BASINA TEK CIZIM CAGRISI
 * =========================================================================
 * Daireler `instancedMesh` ile cizilir. 400 daireli bir sitede 400 ayri
 * mesh, 400 ayri cizim cagrisi demekti ve orta seviye bir dizustunde
 * kare suresini tek basina ucuruyordu. Instancing ile blok basina TEK
 * cagri kalir; secim `e.instanceId` uzerinden yapilir, renk ise
 * `setColorAt` ile ornek basina yazilir.
 *
 * =========================================================================
 * OLCEK VERIDEN (brief) — GEOMETRI MATEMATIGI AYRI DOSYADA
 * =========================================================================
 * Bkz. `site-yerlesim.ts`: orada `three` yok, bu yuzden kurallar jsdom'da
 * test edilebiliyor. Burada yalniz CIZIM var.
 */
import { Html, OrbitControls, SoftShadows } from "@react-three/drei";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { easing } from "maath";
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { Color, InstancedMesh, Object3D, Vector3 } from "three";

import { durumRenkleri, hoverRengi, sahnePaleti, secimRengi } from "./site-palet";
import {
  KAT_YUKSEKLIGI,
  ORNEK_ONEK,
  daireOlcegi,
  TABAN_PAYI,
  ornekSite,
  kameraUzakligi,
  siteYerlesimi,
  type BlokOlcusu,
  type DaireDurumu,
  type SahneBlogu,
} from "./site-yerlesim";

export type { DaireDurumu, SahneBlogu } from "./site-yerlesim";

// (P184-ek duzeltme §2) KAMERA + BILDIRIM ISARETCILERI KALDIRILDI.
// Maket artik YALNIZ binalari ve zemini gosterir; uzerinde renkli nokta
// (kamera/kacirilan devriye) yok. Bu bilgi zaten kamera listesi, bildirimler
// ve devriye gorunumu ekranlarinda var. `IsaretciTuru`, `SahneIsaretcisi`,
// `TUR_RENGI`, `Etiket` bileseni ve `isaretciler`/`onIsaretciSec` plumbing'i
// tamamen silindi (olu kod). Bina secimi (`SahneSecimi`) DURUYOR.

export interface SahneSecimi {
  blokId: string | null;
  kat: number | null;
  daireId: string | null;
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DONGU_SUREKLI = "always" as const;
const DONGU_TALEP = "demand" as const;
const YATAY = "nowrap" as const;

/**
 * KAMERA GECIS SURESI. Brief 400-600 ms ister; `damp3` bir SONLANMA
 * suresi degil ZAMAN SABITI alir — 0.32 sn'lik sabit, gozle gorulur
 * hareketin ~%95'ini 0.5 sn'de bitirir. Sabit kare sayisina degil
 * GECEN SUREYE bagli oldugu icin 30 fps'te de 120 fps'te de ayni hizda
 * gorunur.
 */
const GECIS_SABITI = 0.32;

/** Kameranin dikey gorus acisi — kadraj hesabi da bunu kullanir. */
const GORUS_ACISI = 38;

/** Yuzlerce ornegi doldururken tek bir gecici nesne yeter (cop uretme). */
const GECICI = new Object3D();
const GECICI_RENK = new Color();

/** Pencerenin cepheden disa tasma miktari. */
const PENCERE_TASMA = 0.09;
/** Secili olmayan blogun pencerelerinin cektigi notr renk. */
const SOLUK_RENK = new Color("#8a949f");

/* ====================================================================== */
/*  KAMERA                                                                */
/* ====================================================================== */

/**
 * Kamerayi hedefe YUMUSAK goturur.
 *
 * NEDEN `damp3`, NEDEN ELDE YAZILMIS LERP DEGIL: elde yazilan lerp kare
 * basina sabit oran uygular ve dusuk fps'te YAVASLAR — 30 fps'lik bir
 * dizustunde gecis iki katina cikardi. `damp3` gecen sureyi kullanir.
 */
function KameraSurucusu({
  hedefKonum,
  hedefBakis,
  kontrolRef,
  hareketVar,
  ucusAktifRef,
}: {
  hedefKonum: Vector3;
  hedefBakis: Vector3;
  kontrolRef: React.MutableRefObject<{ target: Vector3; update: () => void } | null>;
  hareketVar: boolean;
  // (P181 7.4) SÜRÜŞ YALNIZ UÇUŞ SIRASINDA: yeni bir seçime UÇARKEN true;
  // hedefe varınca ya da kullanıcı kamerayı tutunca false olur. Aksi halde
  // her kare kamerayı hedefe geri çeker ve kullanıcı bırakınca BAŞA DÖNERDİ.
  ucusAktifRef: React.MutableRefObject<boolean>;
}) {
  const { camera, invalidate } = useThree();

  // HAREKET AZALTMADA GECIS YOK: kamera hedefe ANINDA oturur. Brief'in
  // `prefers-reduced-motion` kurali kamerayi da baglar.
  useEffect(() => {
    if (hareketVar) return;
    camera.position.copy(hedefKonum);
    kontrolRef.current?.target.copy(hedefBakis);
    kontrolRef.current?.update();
    ucusAktifRef.current = false;
    invalidate();
  }, [hareketVar, hedefKonum, hedefBakis, camera, kontrolRef, invalidate, ucusAktifRef]);

  useFrame((_, dt) => {
    // Uçuş bitmişse kameraya DOKUNMA — OrbitControls (kullanıcı) sahibidir.
    if (!hareketVar || !ucusAktifRef.current) return;
    easing.damp3(camera.position, hedefKonum, GECIS_SABITI, dt);
    const k = kontrolRef.current;
    if (k) {
      easing.damp3(k.target, hedefBakis, GECIS_SABITI, dt);
      k.update();
    }
    // VARDI MI: hedefe yaklaşınca sürüşü bırak — kullanıcı artık serbestçe
    // döndürür ve BIRAKTIĞI AÇIDA + YAKINLIKTA kalır (kabul kriteri 12).
    if (
      camera.position.distanceTo(hedefKonum) < 0.05 &&
      (!k || k.target.distanceTo(hedefBakis) < 0.05)
    ) {
      ucusAktifRef.current = false;
    }
  });
  return null;
}

/* ====================================================================== */
/*  ZEMIN — platform + peyzaj                                             */
/* ====================================================================== */

/**
 * Peyzaj: cim, cevre yolu, otopark, yaya yolu, havuz, agaclar.
 *
 * Hepsi BASIT GEOMETRI ve hepsi sabit — her cizimde ayni yerde durur.
 * Rastgele konum, sayfayi her acisinda agaclarin yer degistirmesi
 * demekti; maket hissi tam da DEGISMEZLIKTEN geliyor.
 *
 * AGACLAR TEK INSTANCED CIZIM: 24 agac 48 ayri mesh olurdu.
 */
function Zemin({ yaricap, koyu, sade }: { yaricap: number; koyu: boolean; sade: boolean }) {
  const p = sahnePaleti(koyu);
  const govdeRef = useRef<InstancedMesh>(null);
  const tepeRef = useRef<InstancedMesh>(null);

  // Agac yerleri: platform kenarina yakin bir halka uzerinde, kararli.
  const agaclar = useMemo(() => {
    const n = sade ? 10 : 22;
    return Array.from({ length: n }, (_, i) => {
      const a = (i / n) * Math.PI * 2;
      // AGACLAR YOLUN DISINDA. Onceki deger (0.82) tam yol halkasinin
      // (0.72-0.86) uzerine dusuyordu: agaclar asfaltin ortasinda
      // duruyordu.
      const r = yaricap * 0.93;
      return { x: Math.cos(a) * r, z: Math.sin(a) * r, olcek: 0.8 + ((i * 37) % 5) * 0.09 };
    });
  }, [yaricap, sade]);

  useLayoutEffect(() => {
    for (let i = 0; i < agaclar.length; i++) {
      const t = agaclar[i];
      GECICI.position.set(t.x, 0.12 * t.olcek, t.z);
      GECICI.scale.setScalar(t.olcek);
      GECICI.rotation.set(0, 0, 0);
      GECICI.updateMatrix();
      govdeRef.current?.setMatrixAt(i, GECICI.matrix);
      GECICI.position.set(t.x, 0.34 * t.olcek, t.z);
      GECICI.updateMatrix();
      tepeRef.current?.setMatrixAt(i, GECICI.matrix);
    }
    if (govdeRef.current) govdeRef.current.instanceMatrix.needsUpdate = true;
    if (tepeRef.current) tepeRef.current.instanceMatrix.needsUpdate = true;
  }, [agaclar]);

  return (
    <group>
      {/* PLATFORM — maket tablasi. Kenari ayri bir halka: ince bir kalinlik
          maketin "durdugu" hissini veriyor; tek duzlem havada yuzuyordu. */}
      <mesh position={[0, -0.06, 0]} receiveShadow>
        {/* Silindirin ekseni ZATEN Y: dondurmeye gerek yok, dondurmek
            tablayi dikey bir tekere cevirirdi. */}
        <cylinderGeometry args={[yaricap, yaricap, 0.12, 64]} />
        <meshStandardMaterial color={p.platformKenar} roughness={0.9} />
      </mesh>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.001, 0]} receiveShadow>
        <circleGeometry args={[yaricap, 64]} />
        <meshStandardMaterial color={p.cim} roughness={0.95} />
      </mesh>

      {/* CEVRE YOLU — halka. */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.004, 0]} receiveShadow>
        <ringGeometry args={[yaricap * 0.72, yaricap * 0.86, 64]} />
        <meshStandardMaterial color={p.yol} roughness={1} />
      </mesh>

      {/* YAYA YOLU — bloklarin arasindan gecen ince hac. */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.006, 0]} receiveShadow>
        <planeGeometry args={[yaricap * 1.5, 0.26]} />
        <meshStandardMaterial color={p.patika} roughness={1} />
      </mesh>
      <mesh rotation={[-Math.PI / 2, 0, Math.PI / 2]} position={[0, 0.006, 0]} receiveShadow>
        <planeGeometry args={[yaricap * 1.5, 0.26]} />
        <meshStandardMaterial color={p.patika} roughness={1} />
      </mesh>

      {/* OTOPARK ve HAVUZ — BLOKLARLA YOL ARASINDAKI BOS HALKADA.
          Onceki konumlari (+-0.55 x yaricap) izgaranin ustune dusuyordu
          ve ikisi de kutlelerin altinda kaliyordu; ekranda hic
          gorunmuyorlardi. `yaricap * 0.64` blok kosesi ile yol halkasi
          arasindaki serbest bant. */}
      <mesh
        rotation={[-Math.PI / 2, 0, 0]}
        position={[yaricap * 0.45, 0.007, -yaricap * 0.45]}
        receiveShadow
      >
        <planeGeometry args={[1.7, 1.05]} />
        <meshStandardMaterial color={p.yol} roughness={1} />
      </mesh>

      <mesh
        rotation={[-Math.PI / 2, 0, 0]}
        position={[-yaricap * 0.45, 0.008, yaricap * 0.45]}
        receiveShadow
      >
        <circleGeometry args={[0.66, 32]} />
        <meshStandardMaterial color={p.havuz} roughness={0.2} metalness={0.1} />
      </mesh>

      {/* AGACLAR — iki instanced cizim (govde + tepe). */}
      <instancedMesh ref={govdeRef} args={[undefined, undefined, agaclar.length]} castShadow>
        <cylinderGeometry args={[0.035, 0.045, 0.24, 6]} />
        <meshStandardMaterial color={p.agacGovde} roughness={1} />
      </instancedMesh>
      <instancedMesh ref={tepeRef} args={[undefined, undefined, agaclar.length]} castShadow>
        <icosahedronGeometry args={[0.18, 0]} />
        <meshStandardMaterial color={p.agacTepe} roughness={0.9} flatShading />
      </instancedMesh>
    </group>
  );
}

/* ====================================================================== */
/*  ISIK SERITLERI                                                        */
/* ====================================================================== */

/**
 * AKAN MAVI ISIK SERITLERI — abartisiz (brief'in kelimesi).
 *
 * Cevre yolu uzerinde donen birkac kucuk parlak nokta. Neon bir halka
 * degil: sahne bir MAKET, isik onun uzerinde gezinen bir ipucu.
 * Hareket kapaliysa noktalar SABIT durur (silinmez — silinince koyu
 * temada yol tamamen olu kaliyordu).
 */
function IsikSeritleri({
  yaricap,
  koyu,
  hareketVar,
  adet,
}: {
  yaricap: number;
  koyu: boolean;
  hareketVar: boolean;
  adet: number;
}) {
  const p = sahnePaleti(koyu);
  const ref = useRef<InstancedMesh>(null);
  const r = yaricap * 0.79;

  useFrame(({ clock }) => {
    const m = ref.current;
    if (!m) return;
    const t = hareketVar ? clock.getElapsedTime() * 0.22 : 0;
    for (let i = 0; i < adet; i++) {
      const a = t + (i / adet) * Math.PI * 2;
      GECICI.position.set(Math.cos(a) * r, 0.03, Math.sin(a) * r);
      // Serit YOLA UZANIR: tegete dondurulmus ince bir cubuk. Kure
      // seklindeki benekler ekranda toz gibi duruyordu.
      GECICI.rotation.set(0, -a, 0);
      GECICI.scale.set(1, 1, 1);
      GECICI.updateMatrix();
      m.setMatrixAt(i, GECICI.matrix);
    }
    m.instanceMatrix.needsUpdate = true;
  });

  return (
    <instancedMesh ref={ref} args={[undefined, undefined, adet]}>
      <boxGeometry args={[0.05, 0.02, 0.9]} />
      <meshStandardMaterial
        color={p.serit}
        emissive={p.serit}
        emissiveIntensity={koyu ? 1.6 : 0.7}
        toneMapped={false}
      />
    </instancedMesh>
  );
}

/* ====================================================================== */
/*  BLOK                                                                  */
/* ====================================================================== */

/**
 * Tek blok: kutle + kat cizgileri + balkon ritmi + cati + DAIRE
 * PENCERELERI.
 *
 * KAT SECILINCE KUTLE IKIYE BOLUNUR: secili katin ALTI opak, USTU yari
 * saydam cizilir. Tek kutuya saydamlik vermek "ustteki katlar
 * saydamlassin" istegini karsilamiyordu — butun bina saydamlasiyordu.
 */
function Blok({
  olcu,
  koyu,
  secim,
  soluk,
  onBlokSec,
  onDaireSec,
}: {
  olcu: BlokOlcusu;
  koyu: boolean;
  secim: SahneSecimi;
  /** Baska blok secili — bu blok geri cekilir. */
  soluk: boolean;
  onBlokSec: (id: string) => void;
  onDaireSec: (blokId: string, daireId: string, kat: number) => void;
}) {
  const p = sahnePaleti(koyu);
  const durumlar = durumRenkleri(koyu);
  const secimRenk = secimRengi(koyu);
  const hoverRenk = hoverRengi(koyu);
  const [uzerinde, setUzerinde] = useState(false);
  // (P162 §8.1) HOVER'DAKI DAIRE. `instancedMesh` uzerinde imlecin hangi
  // ornekte oldugu `e.instanceId` ile gelir; ayri bir mesh gerekmez.
  const [uzerindekiDaire, setUzerindekiDaire] = useState<number | null>(null);
  const pencereRef = useRef<InstancedMesh>(null);
  const cizgiRef = useRef<InstancedMesh>(null);
  const balkonRef = useRef<InstancedMesh>(null);

  const seciliBlok = secim.blokId === olcu.blok.id;
  const { genislik, derinlik, yukseklik, katSayisi, daireYerleri } = olcu;
  const katSeciliMi = seciliBlok && secim.kat !== null;
  const bolmeY = katSeciliMi ? TABAN_PAYI + ((secim.kat ?? 0) + 1) * KAT_YUKSEKLIGI : yukseklik;

  // --- pencere (daire) ornekleri ---
  useLayoutEffect(() => {
    const m = pencereRef.current;
    if (!m) return;
    for (let i = 0; i < daireYerleri.length; i++) {
      const y = daireYerleri[i];
      // DISA DOGRU KUCUK BIR TASMA: pencere tam cephe duzleminde olunca
      // kat bantlariyla ayni derinlige dusuyor ve z-savasi (titreme)
      // uretiyordu. Disari 0.09 birim cikinca hem titreme biter hem de
      // pencere duvara TAKILI gorunur.
      const nx = Math.sin(y.yon);
      const nz = Math.cos(y.yon);
      GECICI.position.set(y.x + nx * PENCERE_TASMA, y.y, y.z + nz * PENCERE_TASMA);
      GECICI.rotation.set(0, y.yon, 0);
      // RENK TEK KANAL DEGIL: alarmli daire biraz buyuk cizilir (bkz.
      // `daireOlcegi`). Instancing'de olcek zaten matriste; bedeli yok.
      GECICI.scale.setScalar(daireOlcegi(y.daire.durum));
      GECICI.updateMatrix();
      m.setMatrixAt(i, GECICI.matrix);
    }
    m.instanceMatrix.needsUpdate = true;
  }, [daireYerleri]);

  // --- pencere renkleri: durum + secim ---
  useLayoutEffect(() => {
    const m = pencereRef.current;
    if (!m) return;
    for (let i = 0; i < daireYerleri.length; i++) {
      const d = daireYerleri[i].daire;
      const katVurgusu = katSeciliMi && d.kat === secim.kat;
      const seciliDaire = secim.daireId === d.id;
      const uzerindekiMi = uzerindekiDaire === i;
      // ONCELIK: secili daire > secili kat > durum. Ucunu karistirmak,
      // "tikladigim daire nerede" sorusunu cevapsiz birakirdi.
      // ONCELIK: secim > hover > durum. Hover'i secimin ustune koymak,
      // secili dairenin imlec gecince rengini degistirmesi demekti.
      GECICI_RENK.set(
        seciliDaire ? secimRenk : uzerindekiMi ? hoverRenk : durumlar[d.durum],
      );
      // BASKA BLOK SECILI: bu blogun pencereleri durum rengini BIRAKIR.
      if (soluk) GECICI_RENK.lerp(SOLUK_RENK, 0.78);
      // BU BLOKTA BASKA KAT SECILI: kat disi pencereler kararir.
      else if (katSeciliMi && !katVurgusu && !seciliDaire) GECICI_RENK.multiplyScalar(0.42);
      m.setColorAt(i, GECICI_RENK);
    }
    if (m.instanceColor) m.instanceColor.needsUpdate = true;
  }, [daireYerleri, secim.daireId, secim.kat, katSeciliMi, soluk, durumlar, secimRenk, hoverRenk, uzerindekiDaire]);

  // --- kat cizgileri: her katin tabaninda ince bir seri ---
  useLayoutEffect(() => {
    const m = cizgiRef.current;
    if (!m) return;
    for (let i = 0; i < katSayisi; i++) {
      GECICI.position.set(0, TABAN_PAYI + i * KAT_YUKSEKLIGI, 0);
      GECICI.rotation.set(0, 0, 0);
      GECICI.scale.set(genislik + 0.02, 0.025, derinlik + 0.02);
      GECICI.updateMatrix();
      m.setMatrixAt(i, GECICI.matrix);
    }
    m.instanceMatrix.needsUpdate = true;
  }, [katSayisi, genislik, derinlik]);

  // --- BALKON RITMI: kat asiri, DORT CEPHEDE ince cikma bant ---
  //
  // OLCULEN KUSUR: ilk surumde balkonlar on cepheye konmus iki kutuydu ve
  // ekranda "havada duran beyaz bloklar" gibi duruyordu — pencerelerin
  // ustune biniyor, binaya ait gorunmuyorlardi. Artik her iki katta bir,
  // cephe boyunca uzanan INCE BIR CIKMA var: bina siluetine ritim verir,
  // pencereyi kapatmaz.
  const balkonlar = useMemo(() => {
    const liste: { y: number; enX: number; enZ: number }[] = [];
    for (let k = 1; k < katSayisi; k += 2) {
      liste.push({
        y: TABAN_PAYI + k * KAT_YUKSEKLIGI + KAT_YUKSEKLIGI * 0.12,
        enX: genislik + 0.14,
        enZ: derinlik + 0.14,
      });
    }
    return liste;
  }, [katSayisi, genislik, derinlik]);

  useLayoutEffect(() => {
    const m = balkonRef.current;
    if (!m) return;
    for (let i = 0; i < balkonlar.length; i++) {
      const b = balkonlar[i];
      GECICI.position.set(0, b.y, 0);
      GECICI.rotation.set(0, 0, 0);
      GECICI.scale.set(b.enX, KAT_YUKSEKLIGI * 0.16, b.enZ);
      GECICI.updateMatrix();
      m.setMatrixAt(i, GECICI.matrix);
    }
    m.instanceMatrix.needsUpdate = true;
  }, [balkonlar]);

  const yukselti = seciliBlok ? 0.16 : 0;
  // SOLUKLASTIRMA ALFAYLA YAPILAMAZ — OLCULDU.
  //
  // Ilk iki denemem de ekranda HICBIR SEY degistirmedi:
  //   1. `opacity: 0.28` — acik temada kutle (#e8edf2) da arka plan
  //      (#eef2f6) da acik; acik grinin uzerine acik gri karisinca
  //      sonuc yine acik gri oldu.
  //   2. Rengi arka plana dogru cekmek — ayni sebeple bos: iki renk
  //      zaten neredeyse ayni.
  //
  // SINYALI RENKLI OGEYE TASIDIM. Sahnedeki tek doygun renk PENCERELER
  // (daire durumu). Secili olmayan bloklarin pencereleri durum rengini
  // BIRAKIR ve duvar rengine yaklasir; secili blok tek renkli kalan blok
  // olur. Bu iki temada da anlasilir cunku fark DOYGUNLUKTA, parlaklikta
  // degil. Kutlenin saydamligi olculu kalir: bicim okunur kalsin.
  const saydamlik = soluk ? 0.72 : 1;

  return (
    <group position={[olcu.merkezX, yukselti, olcu.merkezZ]}>
      {/* --- KUTLE: secili katin altinda kalan opak govde --- */}
      <mesh
        castShadow
        receiveShadow
        position={[0, bolmeY / 2, 0]}
        onPointerOver={(e) => {
          e.stopPropagation();
          setUzerinde(true);
        }}
        onPointerOut={() => setUzerinde(false)}
        onClick={(e) => {
          e.stopPropagation();
          onBlokSec(olcu.blok.id);
        }}
      >
        <boxGeometry args={[genislik, bolmeY, derinlik]} />
        <meshStandardMaterial
          color={p.kutle}
          roughness={0.78}
          metalness={0.04}
          transparent={saydamlik < 1}
          opacity={saydamlik}
        />
      </mesh>

      {/* --- USTTEKI KATLAR: kat secilince YARI SAYDAM (brief) --- */}
      {katSeciliMi && bolmeY < yukseklik && (
        <mesh position={[0, bolmeY + (yukseklik - bolmeY) / 2, 0]}>
          <boxGeometry args={[genislik, yukseklik - bolmeY, derinlik]} />
          <meshStandardMaterial color={p.kutle} roughness={0.78} transparent opacity={0.22} />
        </mesh>
      )}

      {/* --- CATI: govdeden hafif tasan bir saçak + ustunde parapet --- */}
      <mesh castShadow position={[0, yukseklik + 0.03, 0]}>
        <boxGeometry args={[genislik + 0.09, 0.06, derinlik + 0.09]} />
        <meshStandardMaterial
          color={p.cati}
          roughness={0.8}
          transparent={saydamlik < 1}
          opacity={saydamlik}
        />
      </mesh>
      <mesh castShadow position={[0, yukseklik + 0.12, 0]}>
        <boxGeometry args={[genislik * 0.34, 0.12, derinlik * 0.34]} />
        <meshStandardMaterial
          color={p.cati}
          roughness={0.8}
          transparent={saydamlik < 1}
          opacity={saydamlik}
        />
      </mesh>

      {/* --- KAT CIZGILERI --- */}
      <instancedMesh ref={cizgiRef} args={[undefined, undefined, katSayisi]}>
        <boxGeometry args={[1, 1, 1]} />
        <meshStandardMaterial
          color={p.katCizgisi}
          roughness={0.9}
          transparent={saydamlik < 1}
          opacity={saydamlik}
        />
      </instancedMesh>

      {/* --- BALKONLAR --- */}
      {balkonlar.length > 0 && (
        <instancedMesh ref={balkonRef} args={[undefined, undefined, balkonlar.length]} castShadow>
          <boxGeometry args={[1, 1, 1]} />
          <meshStandardMaterial
            color={p.balkon}
            roughness={0.7}
            transparent={saydamlik < 1}
            opacity={saydamlik}
          />
        </instancedMesh>
      )}

      {/* --- DAIRELER: TEK CIZIM CAGRISI, ornek basina renk --- */}
      <instancedMesh
        ref={pencereRef}
        args={[undefined, undefined, Math.max(1, daireYerleri.length)]}
        onPointerMove={(e) => {
          e.stopPropagation();
          setUzerindekiDaire(e.instanceId ?? null);
        }}
        onPointerOut={() => setUzerindekiDaire(null)}
        onClick={(e) => {
          e.stopPropagation();
          const i = e.instanceId;
          if (i === undefined) return;
          const y = daireYerleri[i];
          if (!y) return;
          onDaireSec(olcu.blok.id, y.daire.id, y.daire.kat);
        }}
      >
        <boxGeometry args={[0.24, KAT_YUKSEKLIGI * 0.46, 0.03]} />
        <meshStandardMaterial
          roughness={0.35}
          metalness={0.1}
          emissiveIntensity={koyu ? 0.35 : 0.1}
          transparent={saydamlik < 1}
          opacity={saydamlik}
        />
      </instancedMesh>

      {/* --- ETIKET: uzerine gelince ya da seciliyken --- */}
      {(uzerinde || seciliBlok) && (
        // `Html`: 3B konuma bagli ama DOM'da cizilen etiket. Sahne icine
        // doku olarak cizilseydi hicbir yardimci teknoloji okuyamazdi.
        <Html position={[0, yukseklik + 0.42, 0]} center distanceFactor={11}>
          <span
            style={{
              background: "var(--yz-surface-1)",
              color: "var(--yz-text)",
              border: "1px solid var(--yz-border)",
              borderRadius: "var(--yz-radius-chip)",
              boxShadow: "var(--yz-raised)",
              fontSize: "var(--yz-fs-xs)",
              padding: "2px 8px",
              whiteSpace: YATAY,
            }}
          >
            {olcu.blok.ad}
          </span>
        </Html>
      )}
    </group>
  );
}

/* ====================================================================== */
/*  SAHNE                                                                 */
/* ====================================================================== */

export interface BinaSahnesiProps {
  bloklar: SahneBlogu[];
  /** Secim degisince — cagiran yan paneli acar. */
  onSecim?: (secim: SahneSecimi) => void;
  /** Disaridan surulen secim (yan panel kapatilinca sifirlanir). */
  secim?: SahneSecimi;
  koyu?: boolean;
  hareketVar?: boolean;
  /** Mobil/dusuk guc: yansima, yumusak golge ve serit kapanir. */
  sade?: boolean;
}

const BOS_SECIM: SahneSecimi = { blokId: null, kat: null, daireId: null };

export default function BinaSahnesi({
  bloklar,
  onSecim,
  secim: disSecim,
  koyu = false,
  hareketVar = true,
  sade = false,
}: BinaSahnesiProps) {
  const p = sahnePaleti(koyu);
  const kontrolRef = useRef<{ target: Vector3; update: () => void } | null>(null);
  // (P181 7.4) Kamera "uçuşu" yalnız seçim değişince aktif; varınca/kullanıcı
  // tutunca kapanır. Böylece bırakılan açı KORUNUR (render'lar arası sıfırlanmaz).
  const ucusAktifRef = useRef(false);
  const [icSecim, setIcSecim] = useState<SahneSecimi>(BOS_SECIM);
  const secim = disSecim ?? icSecim;

  // VERI YOKSA BOS EKRAN YOK (brief): makul bir ornek site cizilir.
  const ornekMi = bloklar.length === 0;
  const cizilecek = useMemo(() => (ornekMi ? ornekSite() : bloklar), [ornekMi, bloklar]);
  const yerlesim = useMemo(() => siteYerlesimi(cizilecek), [cizilecek]);

  const seciliOlcu = yerlesim.bloklar.find((b) => b.blok.id === secim.blokId) ?? null;
  // Golge kamerasinin kapsamasi gereken yari genislik.
  const golgeAlani = yerlesim.yaricap * 1.35;

  // --- kamera hedefi: genel -> blok -> kat -> daire ---
  const genelUzaklik = useMemo(
    () => kameraUzakligi(yerlesim.yaricap, yerlesim.enYuksek, GORUS_ACISI),
    [yerlesim.yaricap, yerlesim.enYuksek],
  );

  const { hedefKonum, hedefBakis } = useMemo(() => {
    // BAKIS YONU sabit izometrik: (1, 0.8, 1). Uzaklik degisir, ACI DEGIL
    // — aci da degisseydi her secim kullaniciyi baska bir yone dondururdu.
    const yon = new Vector3(1, 0.8, 1).normalize();
    if (!seciliOlcu) {
      const merkez = new Vector3(0, yerlesim.enYuksek * 0.42, 0);
      return {
        hedefKonum: merkez.clone().addScaledVector(yon, genelUzaklik),
        hedefBakis: merkez,
      };
    }
    const katY =
      secim.kat !== null
        ? TABAN_PAYI + secim.kat * KAT_YUKSEKLIGI + KAT_YUKSEKLIGI / 2
        : seciliOlcu.yukseklik * 0.5;
    // Blok seciliyken cerceve BLOGUN KENDISINE gore kurulur; site olcegi
    // orada bilgi tasimiyor. Daireye inince en yakin kadraj.
    const uzaklik = secim.daireId
      ? Math.max(1.8, seciliOlcu.genislik * 1.5)
      : secim.kat !== null
        ? Math.max(2.6, seciliOlcu.genislik * 2.4)
        : kameraUzakligi(
            Math.max(seciliOlcu.genislik, seciliOlcu.derinlik),
            seciliOlcu.yukseklik,
            GORUS_ACISI,
          );
    const merkez = new Vector3(seciliOlcu.merkezX, katY, seciliOlcu.merkezZ);
    return {
      hedefKonum: merkez.clone().addScaledVector(yon, uzaklik),
      hedefBakis: merkez,
    };
  }, [seciliOlcu, secim.kat, secim.daireId, yerlesim.enYuksek, genelUzaklik]);

  // (P181 7.4) Seçim değişince (hedef değişir) UÇUŞU başlat: driver kamerayı
  // götürür, varınca kendini kapatır. İlk mount'ta hedef = başlangıç konumu,
  // uçuş anında biter (görünür etki yok). Kullanıcı serbest döndürmesi bundan
  // ETKİLENMEZ — o sırada uçuş aktif değildir.
  useEffect(() => {
    ucusAktifRef.current = true;
  }, [hedefKonum, hedefBakis]);

  function uygula(yeni: SahneSecimi) {
    if (!disSecim) setIcSecim(yeni);
    onSecim?.(yeni);
  }

  function blokSec(id: string) {
    // ORNEK SITE TIKLANMAZ: olmayan bir bloga acilim yapmak, kullaniciyi
    // var sanip veri arayacagi bir panele goturmekti.
    if (id.startsWith(ORNEK_ONEK)) return;
    if (secim.blokId !== id) {
      uygula({ blokId: id, kat: null, daireId: null });
      return;
    }
    // ZATEN SECILI BLOGA TIKLAMAK BIR KADEME GERI ALIR (daire -> kat ->
    // blok -> site). Onceki davranis dogrudan en disa firlatiyordu:
    // yakinlasmis kullanici duvara denk gelen bir tiklamayla butun
    // baglamini kaybediyordu.
    if (secim.daireId) uygula({ blokId: id, kat: secim.kat, daireId: null });
    else if (secim.kat !== null) uygula({ blokId: id, kat: null, daireId: null });
    else uygula(BOS_SECIM);
  }

  function daireSec(blokId: string, daireId: string, kat: number) {
    if (blokId.startsWith(ORNEK_ONEK)) return;
    uygula({ blokId, kat, daireId: secim.daireId === daireId ? null : daireId });
  }

  return (
    <Canvas
      shadows={!sade}
      // DPR TAVANI SADE KIPTE DUSER: retina bir tablette 2x cizmek, ayni
      // sahne icin dort kat piksel demekti.
      dpr={sade ? [1, 1.5] : [1, 2]}
      // ILK KARE ZATEN DOGRU YERDE: baslangic konumu da kadraj
      // hesabindan gelir, yoksa sahne acilirken kamera iceriden disariya
      // dogru bir sicrama yapiyordu.
      camera={{
        position: [genelUzaklik * 0.585, genelUzaklik * 0.468, genelUzaklik * 0.585],
        fov: GORUS_ACISI,
      }}
      // FPS BUTCESI: hareket kapaliyken sahne YALNIZ degisince cizilir.
      frameloop={hareketVar ? DONGU_SUREKLI : DONGU_TALEP}
      style={{ width: "100%", height: "100%" }}
    >
      <color attach="background" args={[p.arkaPlan]} />

      {/* ISIK: koyu temada serin mavi anahtar + dusuk ortam; acikta notr
          gun isigi + yuksek ortam (brief §4 — sahne isigi AYRI tanimli). */}
      <ambientLight intensity={p.ortamGuc} color={p.ortamIsik} />
      <directionalLight
        position={[6, 11, 5]}
        intensity={p.anahtarGuc}
        color={p.anahtarIsik}
        castShadow={!sade}
        shadow-mapSize={[2048, 2048]}
        shadow-camera-near={1}
        shadow-camera-far={60}
        // GOLGE KAMERASI SITEYE OTURUR: varsayilan +-5'lik kutu buyuk bir
        // siteyi kapsamiyordu ve golge kenarda kesiliyordu.
        shadow-camera-left={-golgeAlani}
        shadow-camera-right={golgeAlani}
        shadow-camera-top={golgeAlani}
        shadow-camera-bottom={-golgeAlani}
        // AKNE: yuzeyin kendi kendini golgelemesi (ekranda kirli benek
        // olarak gorunuyordu). `normalBias` yuzeyi normali boyunca kucuk
        // bir miktar kaydirir; `bias`tan farki, egik yuzeylerde Peter-Pan
        // etkisi uretmemesi.
        shadow-normalBias={0.035}
        shadow-bias={-0.0005}
      />
      {/* DOLGU ISIGI: golgeli yuzler tamamen kararmasin — maket
          fotografciliginda "ikinci isik". Golge URETMEZ (bedava). */}
      <directionalLight position={[-7, 4, -6]} intensity={p.dolguGuc} color={p.dolguIsik} />
      {!sade && <SoftShadows size={14} samples={8} focus={0.8} />}

      <Zemin yaricap={yerlesim.yaricap} koyu={koyu} sade={sade} />
      {!sade && (
        <IsikSeritleri
          yaricap={yerlesim.yaricap}
          koyu={koyu}
          hareketVar={hareketVar}
          adet={5}
        />
      )}

      {yerlesim.bloklar.map((o) => (
        <Blok
          key={o.blok.id}
          olcu={o}
          koyu={koyu}
          secim={secim}
          soluk={secim.blokId !== null && secim.blokId !== o.blok.id}
          onBlokSec={blokSec}
          onDaireSec={daireSec}
        />
      ))}

      <KameraSurucusu
        hedefKonum={hedefKonum}
        hedefBakis={hedefBakis}
        kontrolRef={kontrolRef}
        hareketVar={hareketVar}
        ucusAktifRef={ucusAktifRef}
      />
      <OrbitControls
        ref={kontrolRef as never}
        enablePan={false}
        // (P181 7.4) Kullanıcı kamerayı tuttuğu an sürüşü İPTAL et: bu olmadan
        // driver ile kullanıcı çekişir ve bırakınca kamera hedefe geri kayardı.
        onStart={() => {
          ucusAktifRef.current = false;
        }}
        // Kamera yere GOMULMEZ.
        maxPolarAngle={Math.PI / 2.15}
        minDistance={2}
        maxDistance={genelUzaklik * 1.8}
        autoRotate={false}
      />
    </Canvas>
  );
}
