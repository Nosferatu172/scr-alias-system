#!/usr/bin/env bash
# Script Name: ruby_dep.sh
# ID: SCR-ID-20260329094524-626MJ8RFY3
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: ruby_dep

apt update

apt install -y \
  build-essential \
  autoconf \
  bison \
  libssl-dev \
  libyaml-dev \
  libreadline-dev \
  zlib1g-dev \
  libgmp-dev \
  libncurses-dev \
  libffi-dev \
  libgdbm-dev \
  libdb-dev \
  uuid-dev \
  libtool \
  pkg-config \
  git \
  curl

apt install -y \
  libssl-dev \
  zlib1g-dev \
  libyaml-dev \
  libgmp-dev

apt install -y \
  libreadline-dev \
  libncurses-dev \
  libffi-dev \
  libgdbm-dev \
  libdb-dev

apt install -y \
  autoconf \
  bison \
  libtool \
  pkg-config

apt install -y \
  tzdata \
  ca-certificates