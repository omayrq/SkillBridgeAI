# Multi-stage production Dockerfile for EIRS API on AWS App Runner
# Using Amazon ECR Public to prevent Docker Hub 429 Too Many Requests
FROM public.ecr.aws/docker/library/node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev
COPY . .

FROM public.ecr.aws/docker/library/node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=8080

RUN addgroup -S nodejs && adduser -S apprunner -G nodejs
COPY --from=builder --chown=apprunner:nodejs /app /app

USER apprunner
EXPOSE 8080

CMD ["node", "server.js"]
