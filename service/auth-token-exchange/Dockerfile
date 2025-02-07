# syntax=docker/dockerfile:1

# building/compiling stage
FROM rust AS build

WORKDIR /app
COPY . /app

RUN cargo build --release --locked

# configure run script
COPY /app/target/release/auth-token-exchange /bin/auth-token-exchange
RUN chmod +x /bin/auth-token-exchange

# ---

# image hosting application
FROM scratch AS final

# ISSUE: github container registry doesn't pick up org.opencontainers.image.source value to associate automatically the image with the repo.
LABEL org.opencontainers.image.source="https://github.com/szn-app/donation-app"
LABEL org.opencontainers.image.description="donation-app auth-token-exchange microservice"
LABEL org.opencontainers.image.licenses="GPL-3.0"

COPY --from=build /bin/auth-token-exchange /bin/
ENTRYPOINT ["/bin/auth-token-exchange"]
