// (P177 §9.12) "Ice aktarimi geri al" dugmesi GERCEKTEN geri aliyor mu?
//
// =========================================================================
// NEDEN AYRI BIR TEST — GENEL KAPI BUNU YAKALAMAZDI
// =========================================================================
// P173'te bulundu: dugme ekranda duruyor, basiliyor, HICBIR SEY olmuyordu.
// `POST /api/panel/ice-aktarim/{id}/geri-al` icin BFF rotasi YOKTU — genel
// vekil `[kaynak]/[id]` yalnizca IKI segment eslestiriyor, ucuncu segment
// (`geri-al`) icin hicbir rota tanimli degildi ve istek 404 aliyordu.
// Uc backend'de ve sozlesmede VARDI; kirik olan ARADAKI HALKAYDI.
//
// P173 rotayi ekledi. BU TEST O DUZELTMENIN YERINDE DURDUGUNU KILITLER:
// zincirin DORT halkasi da tek tek olculur. Genel sozlesme kapisi
// (`uc-sozlesme-kapisi.test.ts`) `proxyJson` cagrilarini tarar ama
// ARAYUZUN CAGIRDIGI YOL ile ROTA DOSYASININ VARLIGI arasindaki bagi
// kurmaz — kirilan halka tam olarak oydu.
//
// OLCMEZ: geri almanin VERI uzerindeki etkisi. O backend'in isi ve
// `backend/tests/test_ice_aktarim.py` icinde olculuyor (12 test; ters
// kayit, kismi geri alma yasagi, cift geri alma reddi dahil).
import { describe, expect, it } from "vitest";
import { existsSync, readFileSync } from "node:fs";
import { parse } from "yaml";

const UI = "app/(protected)/ice-aktarim/page.tsx";
const ROTA = "app/api/panel/ice-aktarim/[id]/geri-al/route.ts";
const BACKEND_YOLU = "/ice-aktarim/{aktarim_id}/geri-al";

describe("(P177 §9.12) ice aktarimi geri alma zinciri", () => {
  it("1) ARAYUZ dugmesi var ve bir yola POST atiyor", () => {
    const kaynak = readFileSync(UI, "utf8");
    // Dugmenin KENDISI: `geriAl` cagiran bir `onClick`.
    expect(kaynak).toMatch(/onClick=\{\(\) => void geriAl\(/);
    // Cagrilan yol ve metot.
    expect(kaynak).toContain(
      '`/api/panel/ice-aktarim/${id}/geri-al`',
    );
    expect(kaynak).toMatch(/apiSend\(\s*`\/api\/panel\/ice-aktarim\/\$\{id\}\/geri-al`,\s*"POST"/);
  });

  it("2) O yol icin BIR BFF ROTASI VAR (P173'te yoktu — 404 aliyordu)", () => {
    expect(
      existsSync(ROTA),
      `BFF rotasi yok: ${ROTA} — dugme yine 404 alir`,
    ).toBe(true);
  });

  it("3) Rota POST'u karsiliyor ve DOGRU backend yoluna vekilliyor", () => {
    const kaynak = readFileSync(ROTA, "utf8");
    expect(kaynak).toMatch(/export async function POST/);
    expect(kaynak).toContain('proxyJson(`/ice-aktarim/${id}/geri-al`, "POST")');
  });

  it("4) Backend ucu SOZLESMEDE tanimli (POST)", () => {
    const spec = parse(readFileSync("../contracts/openapi.yaml", "utf8"));
    const op = spec?.paths?.[BACKEND_YOLU];
    expect(op, `sozlesmede yol yok: ${BACKEND_YOLU}`).toBeTruthy();
    expect(Object.keys(op)).toContain("post");
  });
});
