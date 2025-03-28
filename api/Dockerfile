FROM --platform=${BUILDPLATFORM} golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o time-api .

FROM --platform=${BUILDPLATFORM} alpine:3.21
WORKDIR /app
COPY --from=builder /app/time-api .
EXPOSE 8000
CMD ["./time-api"]
