import { NextResponse } from "next/server";

export const runtime = "nodejs";

export async function GET() {
  return NextResponse.json({
    ok: true,
    model: process.env.ANTHROPIC_MODEL || "claude-haiku-4-5-20251001"
  });
}
