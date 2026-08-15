/**
 * (P162) GIRIS EKRANI KARE OLCUMU — sartname §34 "60 FPS hedefi".
 *
 * NE OLCULUR: kare suresi ve kare basina GERCEK cizim cagrisi sayisi
 * degil (burada WebGL yok) — bunun yerine ANA IS PARCACIGI mesguliyeti.
 * Sahnenin tamami CSS animasyonu oldugu icin beklenen sonuc: JS'te
 * neredeyse hicbir is yok, kare suresi vsync tavaninda.
 *
 * Bu makinede GPU YOK (SwiftShader); yine de CSS bilesimi yazilim
 * rasterlayicida bile ucuzdur, cunku her karede yeniden boyama yoktur.
 */
import { chromium } from "playwright";
const TABAN = process.env.OLCUM_URL ?? "http://localhost:3001";
const HAZ = `window.__k=[];let o=performance.now();const t=(x)=>{window.__k.push(x-o);o=x;requestAnimationFrame(t)};requestAnimationFrame(t);`;
const br = await chromium.launch({ args: ["--use-gl=swiftshader","--enable-unsafe-swiftshader"] });
const out = [];
for (const [ad,w,h] of [["masaustu 1920",1920,1080],["masaustu 1440",1440,900],["mobil 390",390,844]]) {
  const p = await br.newPage({ viewport: { width: w, height: h } });
  await p.addInitScript(HAZ);
  await p.goto(`${TABAN}/login`, { waitUntil: "networkidle" });
  await p.waitForTimeout(2500);
  await p.evaluate(() => (window.__k.length = 0));
  if (w > 500) { for (let i=0;i<40;i++){ await p.mouse.move(300+i*20, 200+(i%10)*30); await p.waitForTimeout(25);} }
  await p.waitForTimeout(4000);
  const k = await p.evaluate(() => window.__k);
  const ms = k.reduce((a,b)=>a+b,0)/Math.max(1,k.length);
  const s = [...k].sort((a,b)=>a-b);
  out.push({ gorunum: ad, "ort ms": +ms.toFixed(2), "p95 ms": +s[Math.floor(s.length*0.95)].toFixed(2), "ort fps": +(1000/ms).toFixed(1) });
  await p.close();
}
console.table(out);
await br.close();
