FROM haskell:9.6 AS build
WORKDIR /app

COPY focusflow.cabal ./
RUN cabal update && cabal build --only-dependencies -j4

COPY . .
RUN cabal build -j4
RUN cp $(cabal list-bin focusflow) /app/focusflow-exe

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    libgmp10 \
    libsqlite3-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/focusflow-exe ./focusflow-exe

EXPOSE 8080
CMD ["./focusflow-exe"]