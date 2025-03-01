FROM lukemathwalker/cargo-chef:latest-rust-1.81.0 as chef
WORKDIR /app
RUN apt update && apt install lld clang -y

FROM chef as planner
COPY . .

# Compute a lock-like file for our project
RUN cargo chef prepare --recipe-path recipe.json
FROM chef as builder
COPY --from=planner /app/recipe.json recipe.json

# Build our project dependencies, not our application!
RUN cargo chef cook --release --recipe-path recipe.json

# Up to this point, if our dependency tree stays the same,
# all layers should be cached.
COPY . .
ENV SQLX_OFFLINE true

# Build our project
RUN cargo build --release --bin zero2prod
FROM debian:bookworm-slim AS runtime
WORKDIR /app
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    # Add PostgreSQL client tools for health checks and scripts
    postgresql-client \
    # Add AWS CLI for backup scripts (optional)
    curl unzip \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI (uncomment if needed for S3 backups)
# RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
#     && unzip awscliv2.zip \
#     && ./aws/install \
#     && rm -rf aws awscliv2.zip

# Copy our compiled binary
COPY --from=builder /app/target/release/zero2prod zero2prod

# Copy configuration
COPY configuration configuration

# Copy database migration files
COPY migrations migrations

# Copy our scripts
COPY container-scripts/init-db-connection.sh .
COPY container-scripts/postgres-backup.sh .
COPY container-scripts/postgres-restore.sh .
COPY container-scripts/postgres-init.sh .

# Ensure scripts are executable
RUN chmod +x *.sh

# Create directory for potential backups
RUN mkdir -p /var/lib/postgresql/backups

ENV APP_ENVIRONMENT production

# Use our initialization script as the entrypoint
ENTRYPOINT ["./init-db-connection.sh"]
CMD ["./zero2prod"]