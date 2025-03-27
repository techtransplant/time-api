FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .

# Build the application (for linux), without C libraries
RUN CGO_ENABLED=0 GOOS=linux go build -o time-api .

FROM alpine:3.21
WORKDIR /app
COPY --from=builder /app/time-api .
EXPOSE 8000
CMD ["./time-api"]
