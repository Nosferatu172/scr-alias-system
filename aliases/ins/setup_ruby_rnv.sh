#!/usr/bin/env bash
# Script Name: setup_ruby_rnv.sh
# ID: SCR-ID-20260412153400-8S3542IDQ6
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: setup_ruby_rnv

set -e

echo "🧠 Ruby Dev Environment Bootstrap"
echo "================================="

# -------------------------------
# FIX SUDO (if broken)
# -------------------------------
if [ -f /usr/bin/sudo ]; then
  echo "🔧 Fixing sudo permissions..."
  if [ "$(id -u)" -ne 0 ]; then
    echo "⚠️  Not running as root. Skipping sudo fix."
    echo "👉 If sudo is broken, run: wsl -u root"
  else
    chown root:root /usr/bin/sudo
    chmod 4755 /usr/bin/sudo
    echo "✅ sudo fixed"
  fi
fi

# -------------------------------
# INSTALL DEPENDENCIES
# -------------------------------
echo "📦 Installing dependencies..."
sudo apt update
sudo apt install -y \
  git curl build-essential \
  libssl-dev libreadline-dev zlib1g-dev \
  libyaml-dev libffi-dev

# -------------------------------
# INSTALL RBENV
# -------------------------------
if [ ! -d "$HOME/.rbenv" ]; then
  echo "📥 Installing rbenv..."
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
  git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
else
  echo "✅ rbenv already installed"
fi

# -------------------------------
# CONFIGURE ZSH
# -------------------------------
echo "⚙️ Configuring Zsh..."

if ! grep -q 'rbenv init' ~/.zshrc 2>/dev/null; then
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
  echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
fi

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(~/.rbenv/bin/rbenv init - bash)"

# -------------------------------
# INSTALL RUBY
# -------------------------------
RUBY_VERSION="3.3.0"

if ! rbenv versions | grep -q "$RUBY_VERSION"; then
  echo "💎 Installing Ruby $RUBY_VERSION..."
  rbenv install $RUBY_VERSION
fi

rbenv global $RUBY_VERSION
rbenv rehash

echo "✅ Ruby set to $(ruby -v)"

# -------------------------------
# GEM LOCK CONFIG
# -------------------------------
echo "🔒 Locking gem behavior..."

mkdir -p ~/.gem
echo 'gem: --no-document' > ~/.gemrc
echo 'install: --user-install' >> ~/.gemrc
echo 'update: --user-install' >> ~/.gemrc

# -------------------------------
# INSTALL BUNDLER
# -------------------------------
echo "📦 Installing bundler..."
gem install bundler
rbenv rehash

# -------------------------------
# CREATE TEMPLATE PROJECT
# -------------------------------
PROJECT_DIR="$HOME/ruby_template"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "📁 Creating template project..."
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"

  cat <<EOF > Gemfile
source "https://rubygems.org"

ruby "$RUBY_VERSION"

gem "bundler"
EOF

  bundle install
  bundle config set --local path 'vendor/bundle'

  echo 'puts "Ruby environment ready 🚀"' > app.rb

  rbenv local $RUBY_VERSION

  echo "✅ Template project created at $PROJECT_DIR"
else
  echo "📁 Template project already exists"
fi

# -------------------------------
# FINAL CHECK
# -------------------------------
echo ""
echo "🎉 DONE"
echo "================================="
echo "Ruby: $(ruby -v)"
echo "Bundler: $(bundle -v)"
echo ""
echo "👉 To use your environment:"
echo "cd ~/ruby_template"
echo "bundle exec ruby app.rb"
echo ""
echo "🚫 Remember: NEVER use sudo with gems"
