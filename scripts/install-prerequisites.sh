#!/bin/bash
set -e

echo "Installing prerequisites..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"
    exit 1
fi

# Install unzip and curl
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq unzip curl
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "fedora" ]; then
    yum install -y unzip curl
elif [ "$OS" = "arch" ]; then
    pacman -Sy --noconfirm unzip curl
else
    echo "Unsupported OS: $OS"
    exit 1
fi

echo "Prerequisites installed successfully"
unzip -v | head -1
curl --version | head -1
