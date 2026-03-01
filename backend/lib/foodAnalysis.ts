import { z } from "zod";

export const foodAnalysisSchema = z.object({
  name: z.string().min(1),
  category: z.enum(["produce", "meat", "dairy", "packaged", "other"]),
  expiryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  confidenceSource: z.enum(["ocr", "shelfLife"]),
  shelfLifeDays: z.number().int().nonnegative().nullable()
});

export type FoodAnalysisPayload = z.infer<typeof foodAnalysisSchema>;

export function extractJSONObjectText(raw: string): string {
  let text = raw.trim();
  if (text.startsWith("```")) {
    const lines = text.split(/\r?\n/);
    const withoutFirst = lines.slice(1);
    const withoutLast =
      withoutFirst[withoutFirst.length - 1]?.trim().startsWith("```")
        ? withoutFirst.slice(0, -1)
        : withoutFirst;
    text = withoutLast.join("\n").trim();
  }

  const first = text.indexOf("{");
  const last = text.lastIndexOf("}");
  if (first >= 0 && last >= first) {
    return text.slice(first, last + 1);
  }
  return text;
}

export function safeJsonParse<T = unknown>(text: string): T | null {
  try {
    return JSON.parse(text) as T;
  } catch {
    return null;
  }
}
