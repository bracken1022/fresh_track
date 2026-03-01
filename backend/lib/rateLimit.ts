type Bucket = {
  count: number;
  resetAt: number;
};

const buckets = new Map<string, Bucket>();

export function isRateLimited(key: string, maxRequests: number, windowMs: number): boolean {
  const now = Date.now();
  const current = buckets.get(key);

  if (!current || now >= current.resetAt) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    cleanupExpired(now);
    return false;
  }

  if (current.count >= maxRequests) {
    return true;
  }

  current.count += 1;
  buckets.set(key, current);
  return false;
}

function cleanupExpired(now: number): void {
  for (const [k, v] of buckets.entries()) {
    if (now >= v.resetAt) {
      buckets.delete(k);
    }
  }
}
