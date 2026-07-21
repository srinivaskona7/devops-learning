# ---- build stage ----
FROM node:20-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY server.js ./

# ---- runtime: distroless nodejs ----
FROM gcr.io/distroless/nodejs20-debian12:nonroot

WORKDIR /app

COPY --from=build /app /app

EXPOSE 8080

USER nonroot

CMD ["server.js"]
