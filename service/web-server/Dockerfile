# syntax=docker/dockerfile:1

# building/compiling stage
FROM node:lts AS build
WORKDIR /app

COPY . /app

RUN npm install -g pnpm
RUN pnpm install && pnpm run build

# configure run script
COPY script/nginx.sh /bin/nginx.sh
RUN chmod +x /bin/nginx.sh

# ---

# image hosting application
FROM nginx:alpine AS final
WORKDIR /usr/share/nginx/html

COPY --from=build /bin/nginx.sh /bin/
COPY --from=build /app/.nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Remove default nginx static assets
RUN rm -rf ./*
# Copy static assets from builder stage
COPY --from=build /app/dist .

# Containers run nginx with global directives and daemon off
ENTRYPOINT ["/bin/nginx.sh"]
