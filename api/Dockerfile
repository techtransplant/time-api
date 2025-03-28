FROM --platform=linux/amd64 golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .

# Build the application (for linux), without C libraries. Use amd64 for Fargate.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o time-api .

FROM --platform=linux/amd64 alpine:3.21
WORKDIR /app
COPY --from=builder /app/time-api .
EXPOSE 8000
CMD ["./time-api"]
