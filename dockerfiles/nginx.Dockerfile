FROM nginx:alpine

ARG TZ=Asia/Shanghai

COPY ./src/main/resources/static /opt/dist

CMD ["nginx","-g","daemon off;"]
