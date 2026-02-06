# --- Build stage ---
FROM --platform=$BUILDPLATFORM rust:1.84-bookworm AS build
ARG TARGETARCH

# Install cross-compilation toolchains
RUN apt-get update && apt-get install -y \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    gcc-x86-64-linux-gnu g++-x86-64-linux-gnu \
    && rm -rf /var/lib/apt/lists/*

# Add Rust targets
RUN rustup target add aarch64-unknown-linux-gnu x86_64-unknown-linux-gnu

WORKDIR /app
COPY Cargo.toml Cargo.lock* ./
# Create dummy main for dependency caching
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc && \
      cargo build --release --target aarch64-unknown-linux-gnu; \
    else \
      cargo build --release --target x86_64-unknown-linux-gnu; \
    fi

# Copy real source and rebuild
COPY src ./src
RUN touch src/main.rs
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc && \
      cargo build --release --target aarch64-unknown-linux-gnu && \
      cp target/aarch64-unknown-linux-gnu/release/backend /app/backend; \
    else \
      cargo build --release --target x86_64-unknown-linux-gnu && \
      cp target/x86_64-unknown-linux-gnu/release/backend /app/backend; \
    fi

# --- Runtime stage ---
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
RUN groupadd -r appuser && useradd -r -g appuser appuser
COPY --from=build /app/backend /usr/local/bin/backend
USER appuser
EXPOSE 8080
CMD ["backend"]
