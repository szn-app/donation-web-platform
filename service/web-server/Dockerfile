# syntax=docker/dockerfile:1

# building/compiling stage
FROM node:lts AS build
WORKDIR /app

COPY . /app

RUN npm install -g pnpm
ARG ENV=production
RUN if [ "$ENV" = "development" ]; then pnpm install && pnpm run build-dev; else pnpm install && pnpm run build; fi

# configure run script
COPY script/nginx.sh.template /bin/nginx.sh
RUN chmod +x /bin/nginx.sh

# ---

# image hosting application
FROM nginx:alpine AS final
# ISSUE: github container registry doesn't pick up org.opencontainers.image.source value to associate automatically the image with the repo.
LABEL org.opencontainers.image.source="https://github.com/szn-app/donation-app"
LABEL org.opencontainers.image.description="donation-app microservice"
LABEL org.opencontainers.image.licenses="GPL-3.0"
WORKDIR /usr/share/nginx/html

COPY --from=build /bin/nginx.sh /bin/
COPY --from=build /app/.nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Remove default nginx static assets
RUN rm -rf ./*
# Copy static assets from builder stage
COPY --from=build /app/dist .

# Containers run nginx with global directives and daemon off
ENTRYPOINT ["/bin/nginx.sh"]
