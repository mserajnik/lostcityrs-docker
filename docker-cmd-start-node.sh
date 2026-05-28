#!/bin/sh

# SPDX-FileCopyrightText: 2025-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Container command wrapper that drops privileges via `fixuid`, regenerates the
# world configuration from environment variables, runs the SQLite migrations,
# and starts Lost City RS (Node.js variant for version `274` and onwards).
#
# Lost City RS version `274` reads its runtime configuration from
# `data/config/world.json` rather than from environment variables (the engine
# has no `dotenv` dependency and does not read the process environment at
# runtime). To keep the environment variables in the Compose configuration as
# the single source of truth, we write a `.env` file from them and remove any
# existing `world.json` on every startup; the engine then regenerates
# `world.json` from the `.env` when it loads. The file is therefore disposable
# and does not need to be persisted.

set -eu

eval "$(fixuid -q)"

cd /opt/lostcityrs/engine

echo "[lostcityrs-docker]: Generating world configuration from environment variables."

rm -f data/config/world.json

cat >.env <<EOF
EASY_STARTUP=${EASY_STARTUP}
WEBSITE_REGISTRATION=${WEBSITE_REGISTRATION}
WEB_PORT=${WEB_PORT}
NODE_MEMBERS=${NODE_MEMBERS:-true}
NODE_XPRATE=${NODE_XPRATE:-1}
NODE_PRODUCTION=${NODE_PRODUCTION}
NODE_DEBUG=${NODE_DEBUG}
LOGIN_SERVER=${LOGIN_SERVER}
LOGIN_HOST=${LOGIN_HOST}
LOGIN_PORT=${LOGIN_PORT}
FRIEND_SERVER=${FRIEND_SERVER}
FRIEND_HOST=${FRIEND_HOST}
FRIEND_PORT=${FRIEND_PORT}
LOGGER_SERVER=${LOGGER_SERVER}
LOGGER_HOST=${LOGGER_HOST}
LOGGER_PORT=${LOGGER_PORT}
DB_BACKEND=${DB_BACKEND}
EOF

npm run sqlite:migrate

exec node_modules/.bin/tsx src/app.ts
