#!/usr/bin/env bash
set -euxo pipefail

APP_ROOT="/home/admin/summa"
MISE_SHIMS="/home/admin/.local/share/mise/shims"

cd "$APP_ROOT"

export HOME="/home/admin"
export PATH="$MISE_SHIMS:$PATH"
export RAILS_ENV="production"
export BUNDLE_GEMFILE="$APP_ROOT/Gemfile"
export BUNDLE_PATH="$APP_ROOT/vendor/bundle"

git config core.fileMode false

git fetch origin
git pull --ff-only origin main

bundle config set deployment true
bundle config set without 'development test'
bundle install
bin/rails db:migrate
bin/rails assets:precompile

sudo -n /usr/bin/systemctl restart summa.service
sudo -n /usr/bin/systemctl is-active summa.service
