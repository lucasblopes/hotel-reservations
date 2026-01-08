# Build Stage
FROM golang:1.15-alpine as builder

WORKDIR /app

# Copy dependencies first to cache layers
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Compiles binary
RUN go build -o bookings cmd/web/*.go

# Final Stage
FROM alpine:latest

WORKDIR /app

# Copy binary to build stage
COPY --from=builder /app/bookings .

# Copy necessary folders
COPY --from=builder /app/templates ./templates
COPY --from=builder /app/email-templates ./email-templates
COPY --from=builder /app/static ./static
COPY --from=builder /app/migrations ./migrations

EXPOSE 8080

CMD ["./bookings"]
