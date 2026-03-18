# ADORe CLI

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![ROS2](https://img.shields.io/badge/ros2-jazzy-blue?style=for-the-badge&logo=ros&logoColor=white)](https://docs.ros.org/en/jazzy/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)

A three-layer Docker development environment for ROS2 projects with automatic
dependency gathering, content-addressed image caching, and runtime user creation.

## Quick Start

```bash
git clone <your-repo>
cd <your-repo>
git submodule update --init --recursive
make build
make cli
```

## Layer Architecture

```
ros:jazzy-ros-core-noble
  └── adore_cli_core   — bare ROS2 + rosbridge + zenoh DDS
        └── adore_cli_base   — dev tools, x11, tracing, zsh, ccache
              └── adore_cli  — application .debs + gathered requirements, runtime user
```

| Layer | Image | Tag contains |
|---|---|---|
| `adore_cli_core` | `adore_cli_core:<arch>_<hash>` | arch + adore_cli commit |
| `adore_cli_base` | `adore_cli_base:<arch>_<hash>` | arch + adore_cli commit |
| `adore_cli` | `adore_cli:<arch>_<branch>_<hash>_RH<req_hash>_PH<pkg_hash>` | full state including gathered dependencies |

`adore_cli_core` and `adore_cli_base` are static — they only rebuild when the
adore_cli repo itself changes. `adore_cli` is dynamic — it rebuilds whenever
your project's requirement files or vendor packages change.

## Prerequisites

- Docker 28.0+ with BuildKit
- GNU Make
- Linux (Ubuntu 22.04+)

## Essential Commands

| Command | Description |
|---|---|
| `make build` | Build all three layers |
| `make cli` | Start or attach to the development environment |
| `make run cmd="<command>"` | Execute a one-off command in the container |
| `make stop` | Stop the running container |
| `make clean` | Remove all images and build artifacts |
| `make rebuild_force` | Force rebuild all layers from scratch |
| `make rebuild_from_layer LAYER=core\|base\|user` | Rebuild from a specific layer down |
| `make build_status` | Show which images exist locally |
| `make adore_cli_info` | Show full configuration |
| `make help_cli` | Show all available targets |

## Dependency Management

The `adore_cli` user layer automatically gathers dependencies from your project
before each build. Place requirement files anywhere under your project — they
are discovered recursively.

| File extension | Purpose |
|---|---|
| `*.system` | APT packages |
| `*.pip3` | Python packages |
| `*.ppa` | Ubuntu PPAs |

Place compiled `.deb` packages in `vendor/build/` for automatic installation.

The `RH` (requirements hash) and `PH` (packages hash) in the image tag reflect
the exact state of all gathered dependencies. A change to any requirement file
or vendor package produces a new image tag and triggers a rebuild.

## Runtime User

The container starts as root. The entrypoint creates a user matching the host
`UID`/`GID` passed via environment variables at startup, so all files written
to mounted volumes are owned by your host user. Interactive sessions attach via:

```bash
docker exec --user <uid>:<gid> -it <container> /bin/zsh
```

This is handled automatically by `make cli`.

## Troubleshooting

```bash
# Stale Docker BuildKit cache (GPG errors, random package failures)
docker builder prune -f
make rebuild_from_layer LAYER=core

# Rebuild only what changed
make rebuild_from_layer LAYER=user   # vendor .deb changes
make rebuild_from_layer LAYER=core   # core ROS packages changed

# Debug container as root
make debug_run_root

# Test ROS2 is functional
make test_ros2_installation
```

## License

Eclipse Public License 2.0 — see [LICENSE](LICENSE) for details.
