# Installation Guide

This guide covers installing Vite on macOS and Linux systems.

## Requirements

- **Swift**: 5.9 or later
- **Operating System**: macOS 13+ or Linux (any distro with Swift support)
- **Terminal**: Any terminal emulator with ANSI escape sequence support

### Checking Swift Version

```sh
swift --version
```

If you don't have Swift installed:
- **macOS**: Install Xcode from the App Store, or download Swift from [swift.org](https://swift.org/download/)
- **Linux**: Follow instructions at [swift.org/download/](https://swift.org/download/)

## Installation from Source

### 1. Clone the Repository

```sh
git clone https://github.com/euxaristia/Vite.git
cd Vite
```

### 2. Build with Swift Package Manager

**Debug build** (faster compilation, includes debug symbols):

```sh
swift build
```

**Release build** (optimized for performance):

```sh
swift build -c release
```

### 3. Run the Editor

**Debug build:**

```sh
swift run ViEditor myfile.txt
# or
.build/debug/ViEditor myfile.txt
```

**Release build:**

```sh
.build/release/ViEditor myfile.txt
```

## Installing to PATH

To use Vite as your default `vi` command, copy or symlink the binary:

### Option 1: Copy Binary

```sh
swift build -c release
sudo cp .build/release/ViEditor /usr/local/bin/vi
```

### Option 2: Symlink (recommended for development)

```sh
swift build -c release
sudo ln -sf "$(pwd)/.build/release/ViEditor" /usr/local/bin/vi
```

### Option 3: Add to PATH Without Root

```sh
swift build -c release
mkdir -p ~/.local/bin
cp .build/release/ViEditor ~/.local/bin/vi

# Add to your shell config (~/.bashrc, ~/.zshrc):
export PATH="$HOME/.local/bin:$PATH"
```

## Verifying Installation

Check that Vite is installed correctly:

```sh
vi --version  # Should show Swift/system info
which vi      # Should point to ViEditor binary
```

## Platform-Specific Notes

### macOS

- Xcode Command Line Tools include Swift
- Works with Terminal.app, iTerm2, Alacritty, kitty, etc.
- For best UI experience, use a terminal with full ANSI support

### Linux

**Debian/Ubuntu:**

```sh
# Install Swift dependencies
sudo apt-get update
sudo apt-get install binutils git gnupg2 libc6-dev libcurl4-openssl-dev \
  libedit2 libgcc-9-dev libpython3.8 libsqlite3-0 libstdc++-9-dev \
  libxml2-dev libz3-dev pkg-config tzdata unzip zlib1g-dev

# Download and install Swift from swift.org
```

**Fedora/RHEL:**

```sh
sudo dnf install swift-lang
```

**Arch Linux:**

```sh
sudo pacman -S swift
```

## Troubleshooting

### "Command not found: swift"

Swift is not in your PATH. Install Swift from [swift.org](https://swift.org/download/) or your package manager.

### Build Errors

Ensure you're using Swift 5.9+:

```sh
swift --version
```

Update Swift if necessary.

### "Permission denied" When Installing to /usr/local/bin

Use `sudo` when copying:

```sh
sudo cp .build/release/ViEditor /usr/local/bin/vi
```

### Terminal Rendering Issues

If line numbers aren't faint or colors look wrong:
- Try a modern terminal emulator (iTerm2, Alacritty, kitty, GNOME Terminal)
- Check that your `TERM` environment variable is set correctly:
  ```sh
  echo $TERM  # Should be xterm-256color or similar
  ```

## Next Steps

- [Quick Start Tutorial](Quick-Start) - Learn basic editing
- [Keybindings](Keybindings) - Full command reference
- [Configuration](Configuration) - Customize Vite
