FROM dart:stable as builder

LABEL build_version="dungeonclub 0.5"
#version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thembeat"
LABEL description="Dungeon Club"

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .

RUN dart pub get --offline
RUN dart bin/build.dart

#debian:bookworm-slim
FROM ubuntu 
WORKDIR /app_tmp

ENV ENABLE_MUSIC_PLAYER="true"

RUN apt-get update && apt-get upgrade -y \
    # Install prerequisites
    && apt-get install -q -y --no-install-recommends \
    # apt-utils \
    # ca-certificates \
    # cifs-utils \
    # locales \
    # tar \
    # tzdata \
    rsync \
    wget \
    unzip \
    # Clean up installation cache
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && apt-get autoclean -y \
    && apt-get autoremove \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/* /root/.cache/* /root/.npm/* /var/lib/apt/lists/*

COPY --from=builder /runtime/ ./runtime
COPY --from=builder /app/build/latest /app_tmp
COPY --from=builder /app/scripts /scripts

RUN chmod +x /scripts/entrypoint.sh

CMD ["/bin/bash", "/scripts/entrypoint.sh"]

EXPOSE 7070

HEALTHCHECK --interval=1m --start-period=15s CMD wget --no-verbose --tries=3 --spider http://localhost:7070 || exit 1

VOLUME /app