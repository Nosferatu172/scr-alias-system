#!/usr/bin/env bash
# Script Name: msys2-ruby-4.0.1.sh
# ID: SCR-ID-20260412153242-P6UN5ASNGB
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: msys2-ruby-4.0.1

set -e

# ===============================
# Ruby version config
# ===============================
RUBY_VERSION="4.0.1"
RUBY_MAJOR="4.0"
RUBY_TAR="ruby-${RUBY_VERSION}.tar.gz"
RUBY_URL="https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR}/${RUBY_TAR}"

# ===============================
# Install dependencies
# ===============================
#echo "[*] Installing build dependencies..."
#sudo apt update
#sudo apt install -y \
#  build-essential \
#  libssl-dev \
#  libreadline-dev \
#  zlib1g-dev \
#  libyaml-dev \
#  libffi-dev

# ===============================
# Download Ruby
# ===============================
echo "[*] Downloading Ruby ${RUBY_VERSION}..."
wget -q "${RUBY_URL}" -O "${RUBY_TAR}"

# ===============================
# Extract
# ===============================
echo "[*] Extracting..."
tar -xzf "${RUBY_TAR}"
cd "ruby-${RUBY_VERSION}"

# ===============================
# Configure and build
# ===============================
echo "[*] Configuring..."
./configure --disable-install-doc

echo "[*] Building (this may take a while)..."
make -j"$(nproc)"

# ===============================
# Install
# ===============================
echo "[*] Installing..."
sudo make install

# ===============================
# Verify
# ===============================
echo "[*] Ruby installed!"
ruby -v
