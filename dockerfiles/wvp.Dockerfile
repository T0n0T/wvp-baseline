FROM maven:3.9-eclipse-temurin-21 AS builder

EXPOSE 18978/tcp
EXPOSE 8116/tcp
EXPOSE 8116/udp
EXPOSE 8080/tcp

ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

RUN java -version && javac -version

COPY . /build
WORKDIR /build
RUN env \
    http_proxy="${http_proxy}" \
    https_proxy="${https_proxy}" \
    no_proxy="${no_proxy}" \
    HTTP_PROXY="${HTTP_PROXY}" \
    HTTPS_PROXY="${HTTPS_PROXY}" \
    NO_PROXY="${NO_PROXY}" \
    mvn -Dmaven.repo.local=/root/.m2/repository clean package -Dmaven.test.skip=true
WORKDIR /build/target
RUN mv wvp-pro-*.jar wvp.jar

FROM eclipse-temurin:21-jre

RUN mkdir -p /opt/wvp
WORKDIR /opt/wvp
COPY --from=builder /build/target /opt/wvp
COPY ./docker/wvp/wvp /opt/wvp
ENTRYPOINT ["java", "-Xms512m", "-Xmx1024m", "-XX:+HeapDumpOnOutOfMemoryError", "-XX:HeapDumpPath=/opt/ylcx/", "-jar", "wvp.jar", "--spring.config.location=/opt/ylcx/wvp/application.yml"]
