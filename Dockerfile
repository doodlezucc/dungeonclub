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

# FROM scratch
FROM ubuntu
WORKDIR /app

# RUN apt update
# RUN apt install -y yt-dlp ffmpeg
# RUN rm -rf /var/lib/apt/lists/*
# RUN apt clean

COPY --from=builder /runtime/ ./app
COPY --from=builder /app/build/latest /app

CMD ["/app/server", "--music"]

EXPOSE 7070

HEALTHCHECK --interval=1m --start-period=15s CMD wget --no-verbose --tries=3 --spider http://localhost:7070 || exit 1

VOLUME /app/ambience
VOLUME /app/database
VOLUME /app/database_backup
VOLUME /app/logs
VOLUME /app/mail
VOLUME /app/web