// P39 — YUK PROFILI: gercek kullanimin agirlik dagilimi.
//
// Neden BU BES AKIS: olcum, "en cok cagrilan uc"lari degil KULLANICININ
// GUNUNU temsil etmeli. Bir sakin gunde bir kez giris yapar, ana ekrani
// birkac kez acar, akisi kaydirir; bir gorevli ise gun boyunca okutma
// gonderir. Agirliklar buna gore secildi ve `k6/x/…` gibi ozel eklenti
// GEREKTIRMEZ (saf k6 — CI'da da kosar).
//
// Kosum:
//   docker compose -f infra/docker-compose.yml -f infra/docker-compose.load.yml \
//     run --rm k6 run /load/senaryo.js
import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const TABAN = __ENV.API_BASE || 'http://api:8000';
const SLUG = __ENV.TENANT_SLUG || 'acme-plaza';

// Uc BAZINDA gecikme: toplam p95 tek bir yavas ucu gizler.
const t_login = new Trend('sure_login', true);
const t_home = new Trend('sure_home', true);
const t_activity = new Trend('sure_activity', true);
const t_dues = new Trend('sure_dues', true);
const t_scan = new Trend('sure_scan', true);

export const options = {
  scenarios: {
    // Kademeli yukselis: es zamanlilik ARTARKEN gecikmenin nerede
    // bozuldugunu gormek, tek bir sabit yukten daha bilgilendirici.
    kademeli: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: __ENV.RAMP || '20s', target: Number(__ENV.VUS || 10) },
        { duration: __ENV.SURE || '40s', target: Number(__ENV.VUS || 10) },
        { duration: '10s', target: 0 },
      ],
      gracefulRampDown: '5s',
    },
  },
  thresholds: {
    // Esikler HEDEF DEGIL TABAN: bunlarin altina duserse regresyon vardir.
    http_req_failed: ['rate<0.01'],
    sure_home: ['p(95)<1500'],
    sure_activity: ['p(95)<1500'],
  },
};

function giris(email, parola) {
  const r = http.post(
    `${TABAN}/auth/login`,
    JSON.stringify({ tenant_slug: SLUG, email, password: parola }),
    { headers: { 'Content-Type': 'application/json' }, tags: { ad: 'login' } },
  );
  t_login.add(r.timings.duration);
  check(r, { 'login 200': (x) => x.status === 200 });
  return r.status === 200 ? r.json('access_token') : null;
}

export function setup() {
  // Token'lar BIR KEZ alinir: her yinelemede giris yapmak, olcumu
  // parola hash'leme (bcrypt) maliyetiyle doldururdu — gercek kullanimda
  // giris gunde bir kezdir.
  return {
    sakin: giris('resident@acme.com', __ENV.PW_RESIDENT || 'Resident123!'),
    gorevli: giris('guard@acme.com', __ENV.PW_GUARD || 'Guard123!'),
    yonetici: giris('yonetici@acme.com', __ENV.PW_YONETICI || 'Yonetici123!'),
  };
}

export default function (data) {
  const sakin = { headers: { Authorization: `Bearer ${data.sakin}` } };
  const gorevli = { headers: { Authorization: `Bearer ${data.gorevli}` } };
  const yonetici = { headers: { Authorization: `Bearer ${data.yonetici}` } };

  group('ana ekran demeti', () => {
    // Ana ekran TEK istek degil: uygulama acilista birkac ucu birlikte
    // cagirir; olcum de birlikte olmali.
    const yanitlar = http.batch([
      ['GET', `${TABAN}/me`, null, sakin],
      ['GET', `${TABAN}/announcements?limit=5`, null, sakin],
      ['GET', `${TABAN}/dashboard/live`, null, yonetici],
    ]);
    t_home.add(yanitlar.reduce((a, r) => a + r.timings.duration, 0));
    check(yanitlar[0], { 'me 200': (x) => x.status === 200 });
  });

  group('akis', () => {
    const r = http.get(`${TABAN}/activity?limit=20`, yonetici);
    t_activity.add(r.timings.duration);
    check(r, { 'activity 200': (x) => x.status === 200 });
  });

  group('aidat', () => {
    const r = http.get(`${TABAN}/me/dues`, sakin);
    t_dues.add(r.timings.duration);
    check(r, { 'dues 2xx': (x) => x.status === 200 });
  });

  group('okutma', () => {
    // Idempotency-Key HER YINELEMEDE FARKLI: ayni anahtari tekrar
    // gondermek 200 idempotent yolu olcerdi, YAZMA yolunu degil.
    const anahtar = `${__VU}-${__ITER}-${Date.now()}`;
    const r = http.post(
      `${TABAN}/scans`,
      JSON.stringify({
        nfc_tag_uid: __ENV.NFC || '04:A3:B2:C1:90:01',
        okutma_zamani: new Date().toISOString(),
        konum_durumu: 'bilinmiyor',
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': anahtar,
          Authorization: `Bearer ${data.gorevli}`,
        },
        tags: { ad: 'scan' },
      },
    );
    t_scan.add(r.timings.duration);
    // 404 = seed NFC etiketi yok; olcum yine anlamli (yazma yolu degil,
    // cozumleme yolu olculur) — bu yuzden 201/200/404 kabul.
    check(r, { 'scan beklenen': (x) => [200, 201, 404].includes(x.status) });
  });

  sleep(Number(__ENV.BEKLEME || 1));
}
