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
  + [Using a coding agent](#using-a-coding-agent)
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

### Using a coding agent

If you have a coding agent like [Claude Code][claude-code] or [Codex][codex]
installed, you can try a prompt similar to the following one to have it assist
you with the installation process:

```
Help me install and set up https://github.com/mserajnik/lostcityrs-docker.
First, clone the repository and read the README carefully.
Then guide me through the installation process step by step, following the
README closely.
Do as much of the setup yourself as you safely can so that I only have to step
in when a manual action or personal preference is required.
Ask me about my preferences whenever a choice has to be made, explain the
relevant options clearly, and tailor your instructions to the OS I am using.
Assume that I am not familiar with Lost City RS or Docker and that I have not
read the README myself.
For steps that I need to perform manually, give me clear instructions and exact
commands where appropriate.
Do not assume user-facing choices such as the Lost City RS version or
networking-related preferences. Ask me whenever the README presents a
meaningful choice.
For settings that the README or the Docker Compose configuration indicate
should generally be left alone, keep the documented defaults unless I
explicitly ask for something else.
Do not change settings that the README or the Docker Compose configuration
indicate should not be changed.
```

The exact prompt that works best may vary depending on the coding agent and
model you use.

> [!CAUTION]
> You use coding agents at your own risk. You are responsible for the
> permissions and access you give them. The maintainer of this project is not
> liable for any damage or data loss resulting from their use. Take appropriate
> precautions such as sandboxed access and limited permissions, and do not run
> them with `--yolo` or similar options that bypass safety checks.

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

> [!WARNING]
> Switching to a different Lost City RS version by changing the Docker image
> tag is currently not supported. Upstream database migrations differ between
> supported versions and branches, so changing versions may leave your existing
> setup in an unusable state. If you want to move to a different version, treat
> it as a fresh installation and make backups of your persisted data first.

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

[claude-code]: https://www.anthropic.com/product/claude-code
[codex]: https://openai.com/codex
[docker]: https://docs.docker.com/get-docker/
[docker-compose]: https://docs.docker.com/compose/install/
[lostcityrs]: https://github.com/LostCityRS

[issues]: https://github.com/mserajnik/lostcityrs-docker/issues
[maintainer]: https://github.com/mserajnik
[pull-requests]: https://github.com/mserajnik/lostcityrs-docker/pulls
