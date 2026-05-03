FROM haskell:9.6 AS build
WORKDIR /app

# Ajustado para FocusFlow.cabal (com F e F maiúsculos)
COPY FocusFlow.cabal ./
RUN cabal update && cabal build --only-dependencies -j4

COPY . .
# Ajustado para usar o nome exato do executável
RUN cabal build -j4
RUN cp $(cabal list-bin FocusFlow) /app/focusflow-exe

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    libgmp10 \
    libsqlite3-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

WORKDIR /app
COPY --from=build /app/focusflow-exe ./focusflow-exe

EXPOSE 8080
CMD ["./focusflow-exe"]