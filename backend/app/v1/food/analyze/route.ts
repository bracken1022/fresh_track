import crypto from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import {
  extractJSONObjectText,
  foodAnalysisSchema,
  safeJsonParse
} from "../../../../lib/foodAnalysis";
import { isRateLimited } from "../../../../lib/rateLimit";

export const runtime = "nodejs";

const reqSchema = z
  .object({
    imageBase64: z
      .string()
      .trim()
      .min(1)
      .max(8_000_000)
      .refine((value) => {
        try {
          const bytes = Buffer.from(value, "base64");
          return bytes.length > 0 && bytes.length <= 2_500_000;
        } catch {
          return false;
        }
      }, "imageBase64 is invalid or too large"),
    prompt: z.string().trim().min(1).max(20_000),
    language: z.enum(["en", "zh"]).optional()
  })
  .strict();

export async function POST(req: NextRequest) {
  try {
    const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
    if (isRateLimited(clientIp, 30, 60_000)) {
      return NextResponse.json({ error: "rate_limited" }, { status: 429 });
    }

    if (!hasValidClientToken(req)) {
      return NextResponse.json(
        { error: "unauthorized", message: "Invalid x-client-token" },
        { status: 401 }
      );
    }

    const body = await req.json();
    const parsedReq = reqSchema.safeParse(body);
    if (!parsedReq.success) {
      return NextResponse.json(
        { error: "bad_request", message: parsedReq.error.issues[0]?.message || "Invalid payload" },
        { status: 400 }
      );
    }

    const apiKey = normalizeEnv(process.env.ANTHROPIC_API_KEY);
    if (!apiKey.startsWith("sk-ant-")) {
      return NextResponse.json(
        { error: "server_misconfigured", message: "Missing or invalid ANTHROPIC_API_KEY" },
        { status: 500 }
      );
    }

    const model = (process.env.ANTHROPIC_MODEL || "claude-haiku-4-5-20251001").trim();
    const prompt = localizedPrompt(parsedReq.data.prompt, parsedReq.data.language || "en");
    const upstreamResp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
      },
      body: JSON.stringify({
        model,
        max_tokens: 256,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: "image/jpeg",
                  data: parsedReq.data.imageBase64
                }
              },
              { type: "text", text: prompt }
            ]
          }
        ]
      })
    });

    const upstreamText = await upstreamResp.text();
    if (!upstreamResp.ok) {
      return NextResponse.json(
        {
          error: "upstream_error",
          message: "Anthropic request failed",
          details: upstreamText
        },
        { status: 502 }
      );
    }

    const upstream = safeJsonParse<{
      content?: Array<{ type?: string; text?: string }>;
    }>(upstreamText);
    if (!upstream || !Array.isArray(upstream.content)) {
      return NextResponse.json(
        { error: "upstream_error", message: "Unexpected Anthropic response shape" },
        { status: 502 }
      );
    }

    const textBlock = upstream.content.find((entry) => entry?.type === "text");
    const text = String(textBlock?.text || "").trim();
    if (!text) {
      return NextResponse.json(
        { error: "upstream_error", message: "Anthropic returned no text content" },
        { status: 502 }
      );
    }

    const cleaned = extractJSONObjectText(text);
    const maybeObj = safeJsonParse(cleaned);
    if (!maybeObj) {
      return NextResponse.json(
        { error: "upstream_error", message: "Claude returned invalid JSON content" },
        { status: 502 }
      );
    }

    const normalized = foodAnalysisSchema.safeParse(maybeObj);
    if (!normalized.success) {
      return NextResponse.json(
        { error: "upstream_error", message: "Claude output schema mismatch" },
        { status: 502 }
      );
    }

    return NextResponse.json(normalized.data);
  } catch (error) {
    console.error("analyze_error", error);
    return NextResponse.json({ error: "internal_error" }, { status: 500 });
  }
}

function hasValidClientToken(req: NextRequest): boolean {
  const expected = normalizeEnv(process.env.APP_CLIENT_TOKEN);
  if (!expected) return true;

  const incoming = (req.headers.get("x-client-token") || "").trim();
  if (!incoming) return false;

  const left = Buffer.from(incoming);
  const right = Buffer.from(expected);
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function normalizeEnv(value: string | undefined): string {
  return String(value || "")
    .trim()
    .replace(/^['"]+|['"]+$/g, "");
}

function localizedPrompt(basePrompt: string, language: "en" | "zh"): string {
  if (language === "zh") {
    return `${basePrompt}

Additional output rules:
- Use Simplified Chinese for natural language values (for example "name").
- Keep JSON keys exactly as required.
- Keep enum values in English exactly:
  category: produce | meat | dairy | packaged | other
  confidenceSource: ocr | shelfLife`;
  }

  return `${basePrompt}

Additional output rules:
- Use English for natural language values.
- Keep JSON keys exactly as required.
- Keep enum values exactly:
  category: produce | meat | dairy | packaged | other
  confidenceSource: ocr | shelfLife`;
}
