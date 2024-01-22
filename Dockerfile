FROM dart:stable as builder
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .

RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

FROM scratch
COPY --from=builder /runtime/ /
COPY --from=builder /app/bin/server /app/bin/

CMD ["/app/bin/server"]