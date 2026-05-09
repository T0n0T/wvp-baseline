FROM node:16-bullseye AS builder

WORKDIR /build
COPY ./web /build
RUN npm --registry=https://registry.npmmirror.com install
RUN npm run build:prod

FROM nginx:alpine
ARG TZ=Asia/Shanghai
COPY --from=builder /src/main/resources/static /opt/dist
CMD ["nginx","-g","daemon off;"]
