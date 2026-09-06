import { chromium, firefox, webkit } from "playwright";
const KODEKLER = {
  "H265 (fMP4, MediaMTX'in urettigi)": 'video/mp4; codecs="hvc1.4.10.L63.9e.8"',
  "H265 (genel hvc1)": 'video/mp4; codecs="hvc1"',
  "H264 (fMP4)": 'video/mp4; codecs="avc1.f40016"',
  "H264 (MPEG-TS)": 'video/mp2t; codecs="avc1.42E01E"',
};
for (const [ad, motor, sec] of [["chromium(acik kaynak)", chromium, {}], ["chrome(gercek)", chromium, { channel: "chrome" }], ["firefox", firefox, {}], ["webkit", webkit, {}]]) {
  let t;
  try { t = await motor.launch(sec); } catch (e) { console.log(`${ad}: KURULU DEGIL (${String(e).slice(0,60)})`); continue; }
  const s = await (await t.newContext()).newPage();
  await s.goto("about:blank");
  const sonuc = await s.evaluate((k) => {
    const cikti = {};
    for (const [etiket, tip] of Object.entries(k)) {
      cikti[etiket] = {
        mse: typeof MediaSource !== "undefined" && MediaSource.isTypeSupported ? MediaSource.isTypeSupported(tip) : null,
        video: document.createElement("video").canPlayType(tip) || "(bos)",
      };
    }
    return cikti;
  }, KODEKLER);
  console.log(`\n=== ${ad} ===`);
  for (const [etiket, d] of Object.entries(sonuc)) {
    console.log(`  ${etiket.padEnd(38)} MSE=${String(d.mse).padEnd(5)} canPlayType=${d.video}`);
  }
  await t.close();
}
