import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  const baslangic = sp.get("baslangic");
  if (baslangic) qs.set("baslangic", baslangic);
  const bitis = sp.get("bitis");
  if (bitis) qs.set("bitis", bitis);
  const tip = sp.get("tip");
  if (tip) qs.set("tip", tip);
  const taskId = sp.get("task_id");
  if (taskId) qs.set("task_id", taskId);
  const tamamlayan = sp.get("tamamlayan_user_id");
  if (tamamlayan) qs.set("tamamlayan_user_id", tamamlayan);
  return proxyJson(`/task-completions?${qs.toString()}`, "GET");
}
