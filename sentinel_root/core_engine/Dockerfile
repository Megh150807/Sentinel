FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    libxgboost-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY CMakeLists.txt .
COPY src/ ./src/
COPY include/ ./include/

RUN mkdir build && cd build && cmake .. && make -j$(nproc)

EXPOSE 8080

# Cloud Run Entrypoint
CMD ["./build/sentinel_core"]
