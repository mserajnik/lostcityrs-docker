#!/bin/sh

# SPDX-FileCopyrightText: 2025-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Container command wrapper that drops privileges via `fixuid`, runs the SQLite
# migrations, and starts Lost City RS.

set -eu

eval "$(fixuid -q)"

cd /opt/lostcityrs/engine

bun sqlite:migrate

exec bun start
