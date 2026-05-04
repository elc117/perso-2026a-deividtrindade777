# Use an official Haskell image as a base image
# Undergraded to 9.8.4 to avoid issues with newer versions of GHC and Cabal
FROM haskell:9.8.4

# Install necessary tools and SQLite development headers
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    libsqlite3-dev

# Set up the working directory
WORKDIR /workspace