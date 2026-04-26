# ---- build stage ----
FROM golang:1.23-alpine AS build

WORKDIR /src

# Cache modules separately
COPY go.mod ./
RUN go mod download || true

COPY main.go ./

# Static binary, no cgo, stripped
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w" \
    -o /out/app main.go

# ---- runtime stage ----
FROM scratch

# CA certs for HTTPS calls (optional)
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# The binary
COPY --from=build /out/app /app

EXPOSE 8080

ENTRYPOINT ["/app"]
