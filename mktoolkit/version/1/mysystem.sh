#!/usr/bin/env bash

set -euo pipefail

CYAN="\e[36m"
GREEN="\e[32m"
RESET="\e[0m"

say() {
    printf "%b%s%b\n" "$CYAN" "$1" "$RESET"
}

ok() {
    printf "%b%s%b\n" "$GREEN" "$1" "$RESET"
}

say "Updating package lists"
sudo apt update

say "Installing base packages"
sudo apt install -y \
    rsync aptitude lftp git wget curl tar xz-utils ca-certificates \
    build-essential autoconf bison pkg-config patch \
    libssl-dev libyaml-dev zlib1g-dev libreadline-dev libffi-dev \
    libgdbm-dev libgdbm-compat-dev libncurses5-dev libncursesw5-dev \
    pdftk libdb-dev uuid-dev \
    libxml2-dev libxslt1-dev \
    libsqlite3-dev sqlite3 libpq-dev \
    libgtk-3-dev \
    python3-pip python3-dev python3.13-venv \
    ruby-full \
	bsdextrautils

say "Running full upgrade"
sudo apt full-upgrade -y

create_dirs() {
    local label="$1"
    shift

    say "Making $label folder(s)"
    mkdir -p "$@"
    ok "Completed Making $label folder(s)"
}

#create_dirs "aliases" \
#    aliases \
#    aliases/lib \
#    aliases/logs \
#    aliases/hold \
#    aliases/rcu \
#    aliases/rcu/lib \
#    aliases/rcu/kep \
#    aliases/wallpaper \
#    aliases/preferences \
#    aliases/preferences/aptitude \
#    aliases/preferences/archives \
#    aliases/preferences/holding \
#    aliases/preferences/bun \
#    aliases/preferences/deno \
#    aliases/preferences/kali \
#    aliases/preferences/keyboard \
#    aliases/preferences/new \
#    aliases/preferences/new009 \
#    aliases/preferences/num \
#    aliases/preferences/ollama \
#    aliases/preferences/phantomjs \
#    aliases/preferences/python \
#    aliases/preferences/ruby \
#    aliases/preferences/ruby-gems \
#    aliases/preferences/sample \
#    aliases/preferences/setup \
#    aliases/preferences/sub \
#    aliases/preferences/swap \
#    aliases/preferences/ubuntu \
#    aliases/preferences/wslfix \
#    aliases/preferences/zsh

create_dirs "bash" \
    bash \
    bash/alsd \
    bash/cdrf \
    bash/clnhash \
    bash/convert \
    bash/dirrep \
    bash/experimental \
    bash/file-ops \
    bash/ftpcontroller \
    bash/logs \
    bash/looper \
    bash/move \
    bash/mvpy \
    bash/net \
    bash/python-envr \
    bash/scaffolding \
    bash/script-finder \
    bash/swap \
    bash/toolsmenu \
    bash/uvpy \
    bash/Video-converter \
    bash/vpy \
    bash/vry \
    bash/wordrep

create_dirs "scripts" \
    scripts \
    scripts/archives \
    scripts/cln \
    scripts/extra \
    scripts/ffmpeg \
    scripts/folders \
    scripts/installs \
    scripts/move \
    scripts/nuker \
    scripts/pdfcrowd \
    scripts/remove \
    scripts/sample \
    scripts/upd \
    scripts/winget

create_dirs "swap" \
    swap

create_dirs "zpy" \
    zpy \
    zpy/aliases \
    zpy/alsc \
    zpy/alsed \
    zpy/automount-config \
    zpy/backup-script \
    zpy/cuda-repair \
    zpy/eve \
    zpy/filehunter \
    zpy/file-ops \
    zpy/instagram \
    zpy/math \
    zpy/netrunner \
    zpy/netweb \
    zpy/ops \
    zpy/pass \
    zpy/scrapping \
    zpy/scrfinder \
    zpy/timer \
    zpy/UI \
    zpy/usernamechanger \
    zpy/yt

create_dirs "zru" \
    zru \
    zru/ai \
    zru/alsup \
    zru/archives \
    zru/bup \
    zru/dupre \
    zru/exp \
    zru/file-ops \
    zru/netrunner \
    zru/pass \
    zru/UI \
    zru/yt

create_dirs "keys" \
    keys \
    keys/cookies \
    keys/hold \
    keys/comb

create_dirs "0" \
    0

ok "Completed Making Your New Folder System"

# ----------------------------------------------------------------
# this part Upates zshrc an bashrc to handle the aliases folder
# ----------------------------------------------------------------
echo "[*] rcu bootstrap starting..."

# Ensure python exists (fresh install safety)
if ! command -v python3 >/dev/null 2>&1; then
    echo "[*] python3 not found — installing..."
    sudo apt update
    sudo apt install -y python3 python3-pip
fi

# Detect WSL vs native
if grep -qi microsoft /proc/version 2>/dev/null; then
    BASE="/mnt/c"
else
    BASE="$HOME"
fi

SCRIPT="$BASE/scr/aliases/swap/rcu.py"

if [[ ! -f "$SCRIPT" ]]; then
    echo "❌ rcu.py missing at $SCRIPT"
    exit 1
fi

exec python3 "$SCRIPT" "$@"

# ----------------------------------------------------------------
# this part sets prefered shell to zshrc
# ----------------------------------------------------------------
chsh -s $(which zsh)
echo "Now for some more updates"
apt-get update -y && apt-get full-upgrade -y
sudo apt install -y aptitude
apt-get install caffeine -y
apt-get install audacious -y
apt-get install vlc -y
apt-get install mpv -y
apt-get install aptitude -y
apt-get install gem -y
apt-get install snap -y
apt-get install wget -y
apt-get install img2pdf -y
apt-get install brasero -y
apt-get install ffmpeg -y
apt-get install mpv -y
apt-get install mystiq -y
apt-get install handbrake -y 
apt-get install gnome-shell-extension-manager -y
apt-get install git -y
apt-get install curl -y
apt-get install john -y
apt-get install wifite -y
apt-get install pdftk -y
apt-get install libdvdcss2 -y
apt-get install thunderbird -y
apt-get install libreoffice -y
apt-get install timeshift -y
apt-get install ruby-full -y
apt-get install pip -y
apt-get install libdvdcss2
sudo dpkg-reconfigure libdvd-pkg
sudo apt-get update -y
