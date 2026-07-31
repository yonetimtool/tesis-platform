// P39 — TEKIL UC olcumu: darbogazin CERCEVEDE mi SORGUDA mi oldugunu
// ayirmak icin. `/me` en yalin kimlikli uctur (tek satir okur); yavaslik
// burada da varsa sorun sorguda DEGIL istek yolundadir.
import http from 'k6/http';
import { check } from 'k6';

const TABAN = __ENV.API_BASE || 'http://api:8000';
const SLUG = __ENV.TENANT_SLUG || 'acme-plaza';
const YOL = __ENV.YOL || '/me';

export const options = {
  scenarios: {
    sabit: {
      executor: 'constant-vus',
      vus: Number(__ENV.VUS || 20),
      duration: __ENV.SURE || '20s',
    },
  },
};

export function setup() {
  const r = http.post(
    `${TABAN}/auth/login`,
    JSON.stringify({
      tenant_slug: SLUG,
      email: __ENV.EMAIL || 'yonetici@acme.com',
      password: __ENV.PW || 'Yonetici123!',
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  return { token: r.json('access_token') };
}

export default function (data) {
  const r = http.get(`${TABAN}${YOL}`, {
    headers: { Authorization: `Bearer ${data.token}` },
  });
  check(r, { '2xx': (x) => x.status < 300 });
}
