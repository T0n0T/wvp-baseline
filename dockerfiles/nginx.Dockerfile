FROM node:16-bullseye AS builder
ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

WORKDIR /build
COPY ./web /build
RUN env \
    http_proxy="$http_proxy" \
    https_proxy="$https_proxy" \
    no_proxy="$no_proxy" \
    HTTP_PROXY="$HTTP_PROXY" \
    HTTPS_PROXY="$HTTPS_PROXY" \
    NO_PROXY="$NO_PROXY" \
    npm --registry=https://registry.npmmirror.com install
RUN env \
    http_proxy="$http_proxy" \
    https_proxy="$https_proxy" \
    no_proxy="$no_proxy" \
    HTTP_PROXY="$HTTP_PROXY" \
    HTTPS_PROXY="$HTTPS_PROXY" \
    NO_PROXY="$NO_PROXY" \
    npm run build:prod

FROM nginx:alpine
ARG TZ=Asia/Shanghai
COPY --from=builder /src/main/resources/static /opt/dist
CMD ["nginx","-g","daemon off;"]
