#!/usr/bin/env bash
# Script Name: rbenv_3_3_0.sh
# ID: SCR-ID-20260412153345-G02CGPFFEP
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: rbenv_3_3_0

# install dependencies (this part uses sudo once)
sudo apt update
sudo apt install -y git build-essential libssl-dev libreadline-dev zlib1g-dev

# install rbenv (NO sudo)
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# add to zsh
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc

# reload shell
exec zsh
rbenv --version
# install ruby

#rbenv install 3.0.0
#rbenv global 3.0.0
#rbenv install 3.4.9
#rbenv global 3.4.9

# Version Check
rbenv version
rbenv versions
which ruby
where ruby
ruby -v
gem --version
gem env

rbenv install -l
