# lostcityrs-docker

[![GitHub Actions status][badge-actions-status]][badge-actions-status-url]

> A Docker setup for Lost City RS

This is a simple, Docker-based solution for running [Lost City RS][lostcityrs].
It offers:

+ __Prebuilt Docker images for both `x86_64` and `aarch64`, leveraging GitHub__
  __Actions:__ simply pull the provided image for your architecture and get
  started
+ __The ability to run Lost City RS configured for any of its supported__
  __versions:__ prebuilt images for all fully playable versions ranging from
  `225` to `254` are provided
+ __Seamless, automated database migrations:__ when pulling the latest Docker
  image and re-creating the container, migrations are applied automatically to
  keep your database up-to-date at all times

The setup was created for personal use and its scope is limited to the
following:

+ A single world
+ SQLite as the database backend
+ Usage of the web client (it is not intended to expose ports other than the
  web client port)
+ Accounts can be directly created through the web client (this means that to
  disable public access, the web client has to be access-protected by other
  means, e.g., a reverse proxy with HTTP basic authentication)

Other configurations are probably possible, but not tested and unsupported.

> [!NOTE]
> The Docker images are built on a daily schedule, unless there have been no
> new commits to Lost City RS since the last build. Additionally, every Monday,
> the latest images are rebuilt to ensure software and dependencies are
> up-to-date, even if there have been no updates to Lost City RS itself.

## Table of contents

+ [Install](#install)
  + [Dependencies](#dependencies)
  + [Instructions](#instructions)
+ [Usage](#usage)
  + [Starting](#starting)
  + [Stopping](#stopping)
  + [Updating](#updating)
    + [Breaking changes](#breaking-changes)
+ [Maintainer](#maintainer)
+ [Contribute](#contribute)
+ [License](#license)

## Install

### Dependencies

+ [Docker][docker] (including [Compose V2][docker-compose])

### Instructions

First, clone the repository and create a copy of the Docker Compose example
configuration:

```sh
git clone https://github.com/mserajnik/lostcityrs-docker.git
cd lostcityrs-docker
cp ./compose.yaml.example ./compose.yaml
```

Next, adjust your `compose.yaml`. The first thing to decide on is which Docker
image you want to use based on the version of Lost City RS you want to run.
You can currently choose from the following versions:

| Supported version | Image                                |
| ----------------- | ------------------------------------ |
| `254`             | `ghcr.io/mserajnik/lostcityrs:254`   |
| `245.2`           | `ghcr.io/mserajnik/lostcityrs:245.2` |
| `244`             | `ghcr.io/mserajnik/lostcityrs:244`   |
| `225`             | `ghcr.io/mserajnik/lostcityrs:225`   |

> [!NOTE]
> As new Lost City RS versions become fully playable, further images will be
> added accordingly.

Aside from this, take a look at the `environment` section of the `app` service
and make any adjustments necessary for your desired setup.

## Usage

### Starting

Once you are happy with the configuration, you can start the Lost City RS for
the first time by running:

```sh
docker compose up -d
```

This pulls the Docker image first and afterwards automatically creates and
starts the container.

Afterwards, you can open your browser and navigate to
`http://localhost:8080/rs2.cgi` to access the Lost City RS web client.

From here, feel free to forward the port to the outside world or set up a
reverse proxy as you see fit.

### Stopping

To stop Lost City RS, simply run:

```sh
docker compose down
```

### Updating

To update, pull the latest image:

```sh
docker compose pull
```

Afterwards, re-create the container:

```sh
docker compose up -d
```

#### Breaking changes

It is recommended to regularly check this repository (either manually or by
updating your local repository via `git pull`). Usually, the commits here will
just consist of maintenance and potentially new Lost City RS configuration
options (that you may want to incorporate into your configuration).

Sometimes, there may be new features or changes that require manual
intervention. Such breaking changes will be listed here (and removed again once
they become irrelevant).

## Maintainer

[Michael Serajnik][maintainer]

## Contribute

You are welcome to help out!

[Open an issue][issues] or [make a pull request][pull-requests].

## License

[AGPL-3.0-or-later](LICENSE) © Michael Serajnik

[badge-actions-status]: https://github.com/mserajnik/lostcityrs-docker/actions/workflows/build-docker-images.yaml/badge.svg
[badge-actions-status-url]: https://github.com/mserajnik/lostcityrs-docker/actions/workflows/build-docker-images.yaml

[docker]: https://docs.docker.com/get-docker/
[docker-compose]: https://docs.docker.com/compose/install/
[lostcityrs]: https://github.com/LostCityRS

[issues]: https://github.com/mserajnik/lostcityrs-docker/issues
[maintainer]: https://github.com/mserajnik
[pull-requests]: https://github.com/mserajnik/lostcityrs-docker/pulls
