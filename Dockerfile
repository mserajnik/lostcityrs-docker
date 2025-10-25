# lostcityrs-docker
# Copyright (C) 2025  Michael Serajnik  https://github.com/mserajnik

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

ARG DEBIAN_FRONTEND=noninteractive
ARG LOST_CITY_RS_VERSION=245.2
ARG LOST_CITY_RS_ENGINE_REPOSITORY=https://github.com/LostCityRS/Engine-TS.git
ARG LOST_CITY_RS_CONTENT_REPOSITORY=https://github.com/LostCityRS/Content.git

FROM oven/bun:debian

ARG DEBIAN_FRONTEND
ARG TARGETARCH
ARG LOST_CITY_RS_VERSION
ARG LOST_CITY_RS_ENGINE_REPOSITORY
ARG LOST_CITY_RS_CONTENT_REPOSITORY

# The Docker setup that this Dockerfile is part of is limited to the following
# scope:
# - A single world
# - SQLite as the database backend
# - Usage of the web client (it is not intended to expose ports other than the
#   web client port)
# - Accounts can be directly created through the web client (this means that to
#   disable public access, the web client has to be access-protected by other
#   means, e.g., a reverse proxy with HTTP basic authentication)
#
# Other configurations are probably possible, but not tested and unsupported.
# As such, we ony set a limited set of environment variables here to ensure
# that the setup works out of the box (and rely on the defaults for everything
# else).
ENV WEB_PORT=8888
ENV NODE_PRODUCTION=true
ENV NODE_DEBUG=false
ENV DB_BACKEND=sqlite
ENV WEBSITE_REGISTRATION=false
ENV LOGIN_SERVER=true
ENV LOGIN_HOST=localhost
ENV LOGIN_PORT=43500
ENV FRIEND_SERVER=true
ENV FRIEND_HOST=localhost
ENV FRIEND_PORT=45099
ENV LOGGER_SERVER=true
ENV LOGGER_HOST=localhost
ENV LOGGER_PORT=43501
ENV EASY_STARTUP=true

# Husky is not needed here since it is only used for pre-commit hooks
ENV HUSKY=0

COPY ./docker-cmd-start.sh /usr/local/bin/start

RUN \
  apt update -y && \
  apt install -y \
    curl \
    git \
    openjdk-17-jdk && \
  mkdir -p /opt/lostcityrs && \
  git clone "${LOST_CITY_RS_ENGINE_REPOSITORY}" --single-branch --depth=1 -b ${LOST_CITY_RS_VERSION} /opt/lostcityrs/engine && \
  git clone "${LOST_CITY_RS_CONTENT_REPOSITORY}" --single-branch --depth=1 -b ${LOST_CITY_RS_VERSION} /opt/lostcityrs/content && \
  chown -R bun:bun /opt/lostcityrs && \
  chmod +x /usr/local/bin/start && \
  # See https://github.com/boxboat/fixuid
  curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-${TARGETARCH}.tar.gz | tar -C /usr/local/bin -xzf - && \
  chown root:root /usr/local/bin/fixuid && \
  chmod 4755 /usr/local/bin/fixuid && \
  mkdir -p /etc/fixuid && \
  printf "user: bun\ngroup: bun\n" > /etc/fixuid/config.yml && \
  apt remove -y curl && \
  apt autoremove -y && \
  apt clean -y && \
  rm -rf /var/lib/apt/lists/*

USER bun

RUN \
  mkdir /opt/lostcityrs/database && \
  touch /opt/lostcityrs/database/db.sqlite && \
  touch /opt/lostcityrs/database/db.sqlite-journal && \
  cd /opt/lostcityrs/engine && \
  ln -s /opt/lostcityrs/database/db.sqlite ./db.sqlite && \
  ln -s /opt/lostcityrs/database/db.sqlite-journal ./db.sqlite-journal && \
  bun install

CMD ["start"]
