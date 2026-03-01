# FreshCheck Backend (Next.js for Railway)

This is a Next.js App Router backend that proxies image analysis to Anthropic.

Flow:

`iOS app -> Next.js backend -> Anthropic`

The Anthropic API key lives only on the backend.

## Endpoints

- `GET /healthz`
- `POST /v1/food/analyze`

Request body for `/v1/food/analyze`:

```json
{
  "imageBase64": "<jpeg base64>",
  "prompt": "..."
}
```

Response body:

```json
{
  "name": "Carrots",
  "category": "produce",
  "expiryDate": "2026-03-10",
  "confidenceSource": "shelfLife",
  "shelfLifeDays": 7
}
```

## Environment variables

- `ANTHROPIC_API_KEY` (required)
- `APP_CLIENT_TOKEN` (optional; if set, clients must send `x-client-token`)
- `ANTHROPIC_MODEL` (optional; default `claude-haiku-4-5-20251001`)

## Local run (optional)

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

## Deploy to Railway

1. Push repo to GitHub.
2. In Railway, create `New Project -> Deploy from GitHub repo`.
3. Set **Root Directory** to `backend`.
4. Railway will use:
   - Build: `npm run build`
   - Start: `npm start`
5. Set Railway Variables:
   - `ANTHROPIC_API_KEY`
   - `APP_CLIENT_TOKEN` (recommended)
   - `ANTHROPIC_MODEL` (optional)
6. Deploy and copy service URL:
   - Example: `https://freshcheck-backend-production.up.railway.app`

## iOS app config

In Xcode `Product > Scheme > Edit Scheme > Run > Environment Variables`:

- `FRESHCHECK_PROXY_URL` = your Railway URL
- `FRESHCHECK_PROXY_TOKEN` = same as backend `APP_CLIENT_TOKEN` (if set)

The iOS app calls:

`POST {FRESHCHECK_PROXY_URL}/v1/food/analyze`

## Production hardening suggestions

- Replace static `APP_CLIENT_TOKEN` with App Attest verification.
- Add per-user auth + quotas.
- Add structured logging and abuse monitoring.
