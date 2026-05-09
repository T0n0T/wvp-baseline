FROM maven:3.9-eclipse-temurin-21 AS builder

EXPOSE 18978/tcp
EXPOSE 8116/tcp
EXPOSE 8116/udp
EXPOSE 8080/tcp

RUN java -version && javac -version

COPY vendor/wvp-GB28181-pro /build
COPY .git/modules/vendor/wvp-GB28181-pro /tmp/wvp-git
WORKDIR /build
RUN rm -f /build/.git && mkdir -p /build/.git && cp -a /tmp/wvp-git/. /build/.git/ \
    && perl -0pi -e 's#^\s*worktree = .*$#\tworktree = /build#m' /build/.git/config

RUN mvn -Dmaven.repo.local=/root/.m2/repository clean package -Dmaven.test.skip=true
WORKDIR /build/target
RUN mv wvp-pro-*.jar wvp.jar

FROM eclipse-temurin:21-jre

RUN mkdir -p /opt/wvp
WORKDIR /opt/wvp
COPY --from=builder /build/target /opt/wvp
COPY vendor/wvp-GB28181-pro/docker/wvp/wvp /opt/wvp
ENTRYPOINT ["java", "-Xms512m", "-Xmx1024m", "-XX:+HeapDumpOnOutOfMemoryError", "-XX:HeapDumpPath=/opt/ylcx/", "-jar", "wvp.jar", "--spring.config.location=/opt/ylcx/wvp/application.yml"]
