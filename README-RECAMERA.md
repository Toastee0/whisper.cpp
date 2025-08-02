# reCamera RISC-V Build Scripts

This directory contains specialized build scripts for cross-compiling whisper.cpp to the Seeed Studio reCamera platform (SG2002 RISC-V).

## Scripts Overview

### `build-whisper-basic.sh` (Recommended)
- **Purpose**: Basic CPU-only build with minimal optimizations
- **Compatibility**: Works with all RISC-V toolchains
- **Architecture**: `rv64g` (no vector extensions)
- **Use Case**: Maximum compatibility, stable builds

### `build-whisper-simple.sh`
- **Purpose**: Simple optimizations with CPU focus
- **Compatibility**: Most RISC-V toolchains
- **Architecture**: `rv64gc` (compressed instructions)
- **Use Case**: Balanced performance and compatibility

### `build-whisper-riscv.sh`
- **Purpose**: Advanced RISC-V optimizations including vector extensions
- **Compatibility**: Requires toolchain with RISC-V vector support
- **Architecture**: `rv64gcv` (full vector extensions)
- **Use Case**: Maximum performance (if supported by toolchain)

## Requirements

1. **reCamera Development Environment**
   - Follow [Seeed Studio reCamera setup guide](https://wiki.seeedstudio.com/reCamera/)
   - RISC-V toolchain in: `/home/toastee/recamera/host-tools/gcc/riscv64-linux-musl-x86_64/`

2. **Network Configuration**
   - reCamera accessible at `192.168.42.1`
   - SSH access configured (user: `recamera` or `root`)

3. **Optional: Environment Variables**
   ```bash
   export RECAMERA_PASSWORD="your_device_password"
   ```

## Usage

1. **Choose appropriate script** based on your needs:
   ```bash
   # For maximum compatibility (recommended first try)
   ./build-whisper-basic.sh
   
   # For better performance
   ./build-whisper-simple.sh
   
   # For advanced features (may fail on older toolchains)
   ./build-whisper-riscv.sh
   ```

2. **Scripts automatically**:
   - Configure cmake for cross-compilation
   - Build whisper.cpp main and server binaries
   - Deploy to reCamera device (if password set)
   - Provide usage instructions

## Troubleshooting

### Vector Extension Errors
If you see errors like `__riscv_vle32_v_f32m8 not declared`:
- Your toolchain lacks RISC-V vector extension support
- Use `build-whisper-basic.sh` instead

### Build Configuration Issues
- Ensure reCamera development environment is properly set up
- Check toolchain path: `/home/toastee/recamera/host-tools/gcc/riscv64-linux-musl-x86_64/bin/`
- Verify CMake version >= 3.15

### Deployment Issues
- Verify reCamera network connectivity (`ping 192.168.42.1`)
- Check SSH access and credentials
- Ensure sufficient storage space on reCamera

## Performance Notes

### Memory Usage on SG2002
- **tiny model**: ~273MB (recommended for testing)
- **base model**: ~388MB (good balance)
- **small model**: ~852MB (requires sufficient RAM)

### Expected Performance
- **Real-time transcription**: Possible with tiny/base models
- **Server mode**: Recommended for continuous operation
- **Batch processing**: Efficient for multiple files

## Integration

Works with reCamera ecosystem:
- [ncurses 6.4 for reCamera](https://github.com/Toastee0/ncurses)
- [nano editor for reCamera](https://github.com/Toastee0/nano)
- Standard reCamera development workflow

## Model Downloads

Download models directly on reCamera:
```bash
# Tiny model (fastest, lowest quality)
wget -O /tmp/ggml-tiny.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin

# Base model (balanced)
wget -O /tmp/ggml-base.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin

# Small model (highest quality that fits in memory)
wget -O /tmp/ggml-small.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin
```

## Example Usage on reCamera

```bash
# Basic transcription
/tmp/whisper-main -m /tmp/ggml-tiny.bin -f audio.wav

# HTTP server for web interface
/tmp/whisper-server -m /tmp/ggml-base.bin --port 8080 --host 0.0.0.0

# Real-time transcription with microphone
arecord -D hw:0,0 -f S16_LE -r 16000 -c 1 | /tmp/whisper-main -m /tmp/ggml-tiny.bin --stdin
```
