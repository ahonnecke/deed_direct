# ---------- Base image ----------
# MAINTAINER Ashton Honnecke <ashton@pixelstub.com>
FROM node:20-alpine AS base
ENV PNPM_HOME="/pnpm" \
    NEXT_TELEMETRY_DISABLED=1
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && apk add --no-cache libc6-compat

WORKDIR /app

# ---------- Dependencies layer ----------
# Copy only files needed to resolve workspace deps (best cache hit)
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml turbo.json tsconfig.base.json ./
# App & packages manifests
COPY apps/web/package.json apps/web/package.json
COPY packages/ui/package.json packages/ui/package.json
COPY packages/shared/package.json packages/shared/package.json
COPY packages/supabase/package.json packages/supabase/package.json

FROM base AS deps
RUN pnpm install --frozen-lockfile

# ---------- Builder ----------
FROM deps AS builder

# Required build-time arguments with no defaults
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY

# Validate required build args
RUN test -n "$NEXT_PUBLIC_SUPABASE_URL" || (echo "Error: NEXT_PUBLIC_SUPABASE_URL is required" && exit 1)
RUN test -n "$NEXT_PUBLIC_SUPABASE_ANON_KEY" || (echo "Error: NEXT_PUBLIC_SUPABASE_ANON_KEY is required" && exit 1)

# Set as environment variables for the build process
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY

# Bring source after deps to maximize cache
COPY . .

# Build only the web app (Next.js)
RUN pnpm --filter web build

# ---------- Runner (small, prod-only) ----------
FROM node:20-alpine AS runner

# Required runtime environment variables (must be passed at runtime)
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY

# Validate required runtime args
RUN test -n "$NEXT_PUBLIC_SUPABASE_URL" || (echo "Error: NEXT_PUBLIC_SUPABASE_URL is required" && exit 1)
RUN test -n "$NEXT_PUBLIC_SUPABASE_ANON_KEY" || (echo "Error: NEXT_PUBLIC_SUPABASE_ANON_KEY is required" && exit 1)

# Set environment variables for runtime
ENV NODE_ENV=production \
    PORT=3000 \
    NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL \
    NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY

WORKDIR /app

# Copy Next standalone output and statics
# The standalone output includes a minimal Node server.js and required node_modules
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder /app/apps/web/public ./apps/web/public

# If you serve from a basePath, also set: ENV NEXT_PUBLIC_BASE_PATH=/your-base
EXPOSE 3000

# For monorepos, Next puts server.js under apps/web in the standalone tree
CMD ["node", "apps/web/server.js"]
