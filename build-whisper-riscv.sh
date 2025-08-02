#!/bin/bash

# RISC-V whisper.cpp CPU-only build script for reCamera
# This script cross-compiles whisper.cpp for RISC-V with CPU-only inference

set -e

# RISC-V cross-compilation environment
export PATH=$HOME/recamera/host-tools/gcc/riscv64-linux-musl-x86_64/bin:$PATH

# SSH configuration for deployment
TARGET_HOST="192.168.42.1"
TARGET_USER="recamera"
TARGET_PASSWORD="${RECAMERA_PASSWORD:-}"

if [ -z "$TARGET_PASSWORD" ]; then
    echo "Please set RECAMERA_PASSWORD environment variable or it will be prompted when needed"
fi

# Function to setup SSH key if it doesn't exist
setup_ssh_key() {
    echo "Setting up SSH key authentication..."
    
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo "Generating SSH key..."
        ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
    fi
    
    if [ -z "$TARGET_PASSWORD" ]; then
        echo "No password set. Please enter password manually when prompted."
        ssh-copy-id -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST"
    elif command -v sshpass >/dev/null 2>&1; then
        echo "Copying SSH key to target device..."
        sshpass -p "$TARGET_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST"
    else
        echo "sshpass not found. Installing..."
        sudo apt-get update && sudo apt-get install -y sshpass
        echo "Copying SSH key to target device..."
        sshpass -p "$TARGET_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST"
    fi
}

# Function to execute SSH commands with key or password fallback
ssh_exec() {
    local cmd="$1"
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "$TARGET_USER@$TARGET_HOST" "$cmd" 2>/dev/null; then
        return 0
    else
        if [ -n "$TARGET_PASSWORD" ] && command -v sshpass >/dev/null 2>&1; then
            sshpass -p "$TARGET_PASSWORD" ssh -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST" "$cmd"
        else
            echo "SSH key auth failed. Please enter password manually:"
            ssh "$TARGET_USER@$TARGET_HOST" "$cmd"
        fi
    fi
}

# Function to execute SCP with key or password fallback
scp_exec() {
    local src="$1"
    local dst="$2"
    if scp -o BatchMode=yes -o ConnectTimeout=5 "$src" "$TARGET_USER@$TARGET_HOST:$dst" 2>/dev/null; then
        return 0
    else
        if [ -n "$TARGET_PASSWORD" ] && command -v sshpass >/dev/null 2>&1; then
            sshpass -p "$TARGET_PASSWORD" scp -o StrictHostKeyChecking=no "$src" "$TARGET_USER@$TARGET_HOST:$dst"
        else
            echo "SSH key auth failed. Please enter password manually:"
            scp "$src" "$TARGET_USER@$TARGET_HOST:$dst"
        fi
    fi
}

echo "Building whisper.cpp for RISC-V (CPU-only)..."

# Verify cross-compiler is available
if ! command -v riscv64-unknown-linux-musl-gcc >/dev/null 2>&1; then
    echo "Error: RISC-V cross-compiler not found in PATH"
    echo "Please ensure the toolchain is installed at:"
    echo "  $HOME/recamera/host-tools/gcc/riscv64-linux-musl-x86_64/"
    exit 1
fi

echo "Using compiler: $(which riscv64-unknown-linux-musl-gcc)"

# Create and enter build directory
BUILD_DIR="build-riscv64-cpu"
if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
fi

cd "$BUILD_DIR"

# Clean previous build
rm -rf CMakeCache.txt CMakeFiles/

echo "Configuring whisper.cpp for RISC-V..."

# Configure with cmake for RISC-V CPU-only build
cmake .. \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
    -DCMAKE_C_COMPILER=riscv64-unknown-linux-musl-gcc \
    -DCMAKE_CXX_COMPILER=riscv64-unknown-linux-musl-g++ \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-O3 -DNDEBUG" \
    -DCMAKE_CXX_FLAGS="-O3 -DNDEBUG" \
    -DGGML_STATIC=ON \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON \
    -DGGML_NATIVE=OFF \
    -DGGML_CPU_ALL_VARIANTS=OFF \
    -DGGML_OPTIMIZE=ON \
    -DGGML_OPENMP=OFF \
    -DGGML_ACCELERATE=OFF \
    -DGGML_BLAS=OFF \
    -DGGML_CUDA=OFF \
    -DGGML_METAL=OFF \
    -DGGML_RPC=OFF

if [ $? -eq 0 ]; then
    echo "Configuration successful, building..."
    
    # Build with parallel jobs
    make -j$(nproc)
    
    if [ $? -eq 0 ]; then
        echo "Build successful!"
        
        # Show built binaries
        echo "Built binaries:"
        file bin/main bin/server bin/stream 2>/dev/null || echo "Some binaries may not have been built"
        
        # Ask user if they want to deploy
        echo ""
        read -p "Deploy to reCamera device? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Preparing for deployment..."
            
            # Check SSH connection
            echo "Testing SSH connection..."
            if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$TARGET_USER@$TARGET_HOST" "echo 'SSH key auth working'" 2>/dev/null; then
                echo "SSH key authentication not working. Setting up..."
                setup_ssh_key
            fi
            
            # Create whisper directory on target
            echo "Creating whisper directory on target..."
            ssh_exec "mkdir -p ~/whisper/models"
            
            # Copy main whisper binary
            if [ -f "bin/main" ]; then
                echo "Copying whisper main binary..."
                scp_exec "bin/main" "~/whisper/whisper-main"
            fi
            
            # Copy server binary if available
            if [ -f "bin/server" ]; then
                echo "Copying whisper server binary..."
                scp_exec "bin/server" "~/whisper/whisper-server"
            fi
            
            # Copy stream binary if available
            if [ -f "bin/stream" ]; then
                echo "Copying whisper stream binary..."
                scp_exec "bin/stream" "~/whisper/whisper-stream"
            fi
            
            echo ""
            echo "Deployment complete!"
            echo ""
            echo "Next steps:"
            echo "1. Download a whisper model (e.g., tiny, base, small)"
            echo "   wget https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
            echo "2. Copy the model to the device:"
            echo "   scp ggml-tiny.bin $TARGET_USER@$TARGET_HOST:~/whisper/models/"
            echo "3. SSH to the device and test:"
            echo "   ssh $TARGET_USER@$TARGET_HOST"
            echo "   cd ~/whisper"
            echo "   ./whisper-main -m models/ggml-tiny.bin -f audio.wav"
            echo ""
            
            # Ask if user wants to SSH to device
            read -p "SSH to device now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Connecting to reCamera..."
                if ssh -o BatchMode=yes -o ConnectTimeout=5 "$TARGET_USER@$TARGET_HOST" 2>/dev/null; then
                    ssh "$TARGET_USER@$TARGET_HOST"
                else
                    if [ -n "$TARGET_PASSWORD" ] && command -v sshpass >/dev/null 2>&1; then
                        sshpass -p "$TARGET_PASSWORD" ssh -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST"
                    else
                        echo "Please enter password when prompted:"
                        ssh "$TARGET_USER@$TARGET_HOST"
                    fi
                fi
            fi
        else
            echo "Build completed. Binaries are in $(pwd)/bin/"
        fi
    else
        echo "Build failed!"
        exit 1
    fi
else
    echo "Configuration failed!"
    exit 1
fi
