#!/bin/bash
set -e

echo "Building whisper.cpp for RISC-V (basic CPU, no vector optimizations)..."

# Set up variables
WHISPER_DIR="/home/toastee/recamera/whisper.cpp"
TOOLCHAIN_ROOT="/home/toastee/recamera/host-tools/gcc/riscv64-linux-musl-x86_64"
CROSS_COMPILE="${TOOLCHAIN_ROOT}/bin/riscv64-unknown-linux-musl-"
BUILD_DIR="${WHISPER_DIR}/build-riscv64-basic"

export CC="${CROSS_COMPILE}gcc"
export CXX="${CROSS_COMPILE}g++"

echo "Using compiler: $CC"

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "Configuring whisper.cpp for RISC-V (basic CPU, no optimizations)..."

# Configure with minimal CPU support, disable all vector optimizations
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=../cmake/riscv64-linux-musl.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="-march=rv64g -mabi=lp64d -O2 -static" \
    -DCMAKE_CXX_FLAGS="-march=rv64g -mabi=lp64d -O2 -static" \
    -DGGML_STATIC=ON \
    -DGGML_NATIVE=OFF \
    -DGGML_CPU_ALL_VARIANTS=OFF \
    -DGGML_AVX=OFF \
    -DGGML_AVX2=OFF \
    -DGGML_AVX512=OFF \
    -DGGML_FMA=OFF \
    -DGGML_F16C=OFF \
    -DGGML_OPENMP=OFF \
    -DGGML_CUDA=OFF \
    -DGGML_METAL=OFF \
    -DGGML_VULKAN=OFF \
    -DGGML_ACCELERATE=OFF \
    -DGGML_OPENBLAS=OFF \
    -DGGML_BLAS=OFF \
    -DGGML_RPC=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON \
    -DWHISPER_BUILD_SERVER=ON

echo "Configuration successful, building..."

# Build with basic optimizations only
make -j$(nproc) main server

echo "Build completed!"
echo "Binaries are in: $BUILD_DIR/bin/"

echo ""
echo "To test the build:"
echo "file $BUILD_DIR/bin/main"
echo "file $BUILD_DIR/bin/server"

# Optional: Deploy to reCamera (if password is set)
if [ -n "$RECAMERA_PASSWORD" ]; then
    echo ""
    echo "Deploying to reCamera..."
    sshpass -p "$RECAMERA_PASSWORD" scp "$BUILD_DIR/bin/main" root@192.168.42.1:/tmp/whisper-main
    sshpass -p "$RECAMERA_PASSWORD" scp "$BUILD_DIR/bin/server" root@192.168.42.1:/tmp/whisper-server
    echo "Deployed whisper binaries to /tmp/ on reCamera"
    echo ""
    echo "To download models on reCamera, run:"
    echo "wget -O /tmp/ggml-tiny.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
    echo ""
    echo "To test:"
    echo "/tmp/whisper-main -m /tmp/ggml-tiny.bin -f /path/to/audio.wav"
    echo "/tmp/whisper-server -m /tmp/ggml-tiny.bin --port 8080"
else
    echo ""
    echo "Set RECAMERA_PASSWORD environment variable to auto-deploy to reCamera"
fi
