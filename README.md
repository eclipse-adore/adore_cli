# ADORe CLI - Advanced Development Environment

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![ROS2](https://img.shields.io/badge/ros2-jazzy-blue?style=for-the-badge&logo=ros&logoColor=white)](https://docs.ros.org/en/jazzy/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)

A sophisticated, multi-layer Docker-based development environment for ROS2 projects with intelligent caching, dependency management, and seamless developer experience.

## 🚀 Quick Start

```bash
# Clone and setup
git clone <your-repo>
cd <your-repo>
git submodule update --init --recursive

# Build the complete environment
make build

# Start developing
make cli
```

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Usage](#-usage)
- [Build System](#-build-system)
- [Registry Integration](#-registry-integration)
- [Troubleshooting](#-troubleshooting)
- [Advanced Usage](#-advanced-usage)
- [Configuration](#-configuration)
- [Development Workflow](#-development-workflow)
- [Contributing](#-contributing)

## ✨ Features

### 🏗️ Three-Layer Architecture
- **Base Foundation**: OS + ROS2 core (highly cacheable, user-agnostic)
- **Core Environment**: Complete toolchain + dependencies (shareable across users)  
- **User Layer**: Personal customization + .deb packages (user-specific)

### 🎯 Smart Build System
- **Intelligent Caching**: Only rebuilds changed layers
- **Requirements Tracking**: Automatic detection of dependency changes
- **Manifest-Based Builds**: SHA256 fingerprinting for precise change detection
- **Cross-Platform Support**: ARM64 and x86_64 architectures
- **Registry Integration**: Pull/push layer caching for CI/CD

### 🛠️ Developer Experience
- **Interactive CLI**: Seamless container attach/detach
- **Persistent Development**: Container state preservation
- **Hot Reloading**: Live code mounting
- **Shell Integration**: zsh with oh-my-zsh and custom prompt
- **History Persistence**: Command history across sessions

### 📦 Package Management
- **Multi-Format Support**: APT packages, Python packages, PPAs, .deb files
- **Automatic Discovery**: Scans project tree for requirements files
- **Vendor Integration**: Custom .deb package installation
- **Dependency Validation**: Runtime verification of installed packages

### 🔧 Advanced Features
- **Tag Management**: Intelligent container versioning
- **Force Rebuilds**: Complete environment reset capability
- **Selective Rebuilds**: Layer-specific rebuild options
- **Debug Tools**: Container inspection and troubleshooting
- **Status Monitoring**: Build and runtime status reporting

## 🏛️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ADORe CLI Architecture                    │
├─────────────────────────────────────────────────────────────┤
│  User Layer (adore_cli)                                     │
│  ├─ User account & permissions                              │
│  ├─ .deb packages from vendor/                              │
│  ├─ Personal shell configuration                            │
│  └─ Development tools                                       │
├─────────────────────────────────────────────────────────────┤
│  Core Environment (adore_cli_core)                          │
│  ├─ All project requirements (.system, .pip3, .ppa)        │
│  ├─ ROS2 complete toolchain                                 │
│  ├─ Development libraries                                   │
│  └─ Build dependencies                                      │
├─────────────────────────────────────────────────────────────┤
│  Base Foundation (adore_cli_base)                           │
│  ├─ Ubuntu 22.04 (Noble)                                   │
│  ├─ ROS2 Jazzy core                                         │
│  ├─ System fundamentals                                     │
│  └─ Container runtime                                       │
└─────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Purpose | Rebuild Triggers | Sharing Level |
|-------|---------|------------------|---------------|
| **Base** | OS + ROS2 foundation | ADORe CLI code changes | Global (all users) |
| **Core** | Project dependencies | Requirements file changes | Project-wide |
| **User** | User customization | .deb package changes | User-specific |

## 📋 Prerequisites

### System Requirements
- **OS**: Linux (Ubuntu 20.04+ recommended)
- **Docker**: 28.0+ with BuildKit support
- **Memory**: 8GB+ RAM recommended
- **Storage**: 20GB+ free space
- **Network**: Internet access for package downloads

### Software Dependencies
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Make
sudo apt update
sudo apt install make git

# Logout and login to apply Docker group membership
```

## 🚀 Installation

### 1. Clone Repository
```bash
git clone <your-adore-cli-repo>
cd <repo-directory>
git submodule update --init --recursive
```

### 2. Verify Installation
```bash
# Check Docker version
docker --version

# Check make availability
make --version

# Verify submodules
ls -la make_gadgets/
```

### 3. Initial Build
```bash
# Build complete environment (first time)
make build

# Verify build success
make build_status
```

## 🎯 Usage

### Basic Commands

| Command | Description | Use Case |
|---------|-------------|----------|
| `make build` | Build complete environment | First setup, major changes |
| `make cli` | Start/attach to development environment | Daily development |
| `make start` | Start container in background | Background services |
| `make stop` | Stop container | End development session |
| `make clean` | Remove all images and artifacts | Complete reset |

### Development Workflow

```bash
# Start development session
make cli

# Inside container - your code is mounted at /tmp/adore
cd /tmp/adore

# Build your ROS2 packages
colcon build

# Run tests
colcon test

# Exit container (keeps running)
exit

# Reattach to same session
make cli

# Stop when done
make stop
```

### Running Commands
```bash
# Execute single command
make run cmd="colcon build"

# Execute with complex commands
make run cmd="source install/setup.bash && ros2 launch my_package my_launch.py"

# Execute tests
make run cmd="colcon test --packages-select my_package"
```

## 🔨 Build System

### Build Targets

#### Primary Targets
```bash
# Complete build (recommended)
make build

# Build only ADORe CLI layers
make build_adore_cli

# Force complete rebuild (ignores cache)
make rebuild_force

# Rebuild from specific layer
make rebuild_from_layer LAYER=base    # Rebuild all layers
make rebuild_from_layer LAYER=core    # Rebuild core + user
make rebuild_from_layer LAYER=user    # Rebuild user only
```

#### Debug and Status
```bash
# Check build status
make build_status

# Show configuration
make adore_cli_info

# Debug interactive shell
make debug_run

# Debug as root
make debug_run_root
```

### Build Strategy

The build system uses intelligent layer detection:

1. **Base Layer**: Rebuilds when ADORe CLI code changes
2. **Core Layer**: Rebuilds when requirements files change
3. **User Layer**: Rebuilds when .deb packages change

### Requirements Management

#### File Types
- **`.system`**: APT package requirements
- **`.pip3`**: Python package requirements  
- **`.ppa`**: Ubuntu PPA repositories

#### Example Files

**requirements.system**:
```
ros-jazzy-rclcpp
vim
git
cmake
```

**requirements.pip3**:
```
numpy
matplotlib
rosdep
```

**requirements.ppa**:
```
ppa:deadsnakes/ppa
```

#### Automatic Discovery
The system automatically finds requirements files in your project:
```bash
# Files are discovered recursively, excluding:
# - .git/, .log/, build/, ros_translator/, .tmp/

find . -name "*.system" -o -name "*.pip3" -o -name "*.ppa"
```

### Package Installation

#### .deb Packages
Place `.deb` files in `vendor/` directory:
```
vendor/
├── my-custom-lib_1.0.0_amd64.deb
├── another-package_2.1.0_amd64.deb
└── subdirectory/
    └── nested-package_1.5.0_amd64.deb
```

Packages are automatically discovered and installed in the user layer.

## 🌐 Registry Integration

### Container Registry Support
ADORe CLI supports pulling/pushing base and core layers to container registries for faster CI/CD builds.

#### Setup
```bash
# Set repository for registry operations
export GITHUB_REPOSITORY=your-org/your-repo

# Check registry status
make registry_status
```

#### Pull from Registry
```bash
# Attempt to pull base and core images
make try_pull_base_images

# Build will automatically try registry first
make build
```

#### Push to Registry
```bash
# Push base and core layers (requires push permissions)
make push_base_images
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: Build ADORe CLI
  run: |
    export GITHUB_REPOSITORY=${{ github.repository }}
    make build

- name: Push to registry
  if: github.ref == 'refs/heads/main'
  run: make push_base_images
```

## 🐛 Troubleshooting

### Common Issues

#### Build Failures
```bash
# Check Docker status
docker info

# Check disk space
df -h

# Clean Docker cache
docker system prune -f

# Force complete rebuild
make rebuild_force
```

#### Container Issues
```bash
# Check container status
docker ps -a

# Check container logs
docker logs adore_cli_<tag>

# Debug container
make debug_run
```

#### Requirements Issues
```bash
# Check requirements detection
make adore_cli_info

# Debug requirements gathering
cd adore_cli_core && make debug_requirements

# Rebuild from core layer
make rebuild_from_layer LAYER=core
```

#### Permission Issues
```bash
# Check user ID mapping
id

# Verify Docker group membership
groups | grep docker

# Fix Docker permissions
sudo usermod -aG docker $USER
# Logout and login
```

### Build Error Recovery

#### Base Layer Failures
```bash
# Check Docker daemon
sudo systemctl status docker

# Manually build base layer
cd adore_cli_base && make build

# Check disk space and clean
df -h
docker system prune -f
```

#### Core Layer Failures
```bash
# Check requirements syntax
find . -name "*.system" -exec cat {} \;

# Manually build core layer
cd adore_cli_core && make build

# Debug requirements gathering
make debug_requirements
```

#### User Layer Failures
```bash
# Check .deb packages
find vendor/ -name "*.deb" -ls

# Manually build user layer
cd adore_cli && make build

# Debug package installation
make debug_packages
```

### Performance Issues

#### Slow Builds
```bash
# Enable parallel builds
export DOCKER_BUILDKIT=1

# Use registry for base layers
make try_pull_base_images

# Check available resources
free -h
df -h
```

#### Large Images
```bash
# Check image sizes
docker images | grep adore_cli

# Clean unused images
docker image prune -f

# Optimize requirements
# Remove unnecessary packages from requirements files
```

## 🔧 Advanced Usage

### Custom Configuration

#### Environment Variables
```bash
# Architecture selection
export ARCH=amd64  # or arm64

# ROS Distribution
export ROS_DISTRO=jazzy

# Custom hostname
export HOSTNAME=my-dev-environment

# Build configuration
export DOCKER_BUILDKIT=1
export COMPOSE_BAKE=true
```

#### Custom Docker Compose
Create `docker-compose.override.yaml`:
```yaml
services:
  adore_cli:
    volumes:
      - ./my-custom-config:/opt/custom
    environment:
      - CUSTOM_VAR=value
    ports:
      - "8080:8080"
```

### Cross-Platform Builds

#### ARM64 on x86_64
```bash
# Enable cross-compilation
export ARCH=arm64
export CROSS_COMPILE=true

# Build for ARM64
make build

# The system will automatically install qemu and configure buildx
```

### Multiple Environments

#### Project-Specific Environments
```bash
# Each project gets its own environment based on:
# - Project branch and commit
# - Requirements hash
# - ADORe CLI version

# Switch between projects
cd /path/to/project1
make cli  # Gets project1-specific environment

cd /path/to/project2  
make cli  # Gets project2-specific environment
```

#### Branch-Specific Environments
```bash
# Different branches get different containers
git checkout feature-branch
make cli  # New container for feature-branch

git checkout main
make cli  # Different container for main
```

### Development Tools Integration

#### VS Code Integration
```json
// .devcontainer/devcontainer.json
{
  "name": "ADORe CLI",
  "dockerComposeFile": "../docker-compose.yaml",
  "service": "adore_cli",
  "workspaceFolder": "/tmp/adore",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode.cpptools",
        "ms-iot.vscode-ros"
      ]
    }
  }
}
```

#### Git Integration
```bash
# Inside container, git credentials are inherited
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# SSH keys are mounted from host
ls ~/.ssh/
```

## ⚙️ Configuration

### Directory Structure
```
your-project/
├── adore_cli/                 # ADORe CLI submodule
│   ├── adore_cli_base/        # Base layer Dockerfiles
│   ├── adore_cli_core/        # Core layer Dockerfiles
│   ├── adore_cli/             # User layer Dockerfiles
│   ├── tools/                 # Helper scripts
│   ├── adore_cli.mk           # Main makefile
│   └── docker-compose.yaml    # Container orchestration
├── vendor/                    # .deb packages
│   └── *.deb
├── requirements.system        # APT packages
├── requirements.pip3          # Python packages
├── requirements.ppa           # Ubuntu PPAs
├── .log/                      # Build artifacts
│   └── .adore_cli/
│       ├── built_tags         # Image tag cache
│       ├── requirements/      # Discovered requirements
│       └── packages/          # Package cache
└── Makefile                   # Project makefile
```

### Configuration Files

#### Main Makefile
```makefile
# Include ADORe CLI
ROOT_DIR := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")
SOURCE_DIRECTORY := ${ROOT_DIR}
ADORE_CLI_WORKING_DIRECTORY := ${ROOT_DIR}

include ${ROOT_DIR}/adore_cli.mk

# Your project targets
.PHONY: my_build
my_build:
    make run cmd="colcon build"
```

#### Environment Configuration
```bash
# .env file (optional)
DOCKER_BUILDKIT=1
ROS_DISTRO=jazzy
HOSTNAME=my-adore-cli
```

### Advanced Configuration

#### Custom Base Images
Modify `adore_cli_base/Dockerfile.adore_cli_base`:
```dockerfile
# Use custom base image
FROM my-custom-ros:jazzy AS adore_cli_base

# Add custom configuration
COPY my-custom-config.sh /opt/
RUN bash /opt/my-custom-config.sh
```

#### Custom Requirements Processing
Override `adore_cli_core/gather_requirements_files.sh`:
```bash
#!/bin/bash
# Custom requirements gathering logic
# Your custom implementation
```

## 🔄 Development Workflow

### Daily Development

```bash
# Morning routine
cd ~/my-ros-project
make cli

# Inside container
cd /tmp/adore
source install/setup.bash  # If you have existing builds

# Development cycle
# 1. Edit code (in host editor or container)
# 2. Build
colcon build --packages-select my_package

# 3. Test
colcon test --packages-select my_package

# 4. Run
ros2 launch my_package my_launch.py

# End of day
exit  # Detach but keep container running
make stop  # Or keep running for tomorrow
```

### Adding Dependencies

```bash
# Add APT package
echo "new-package-name" >> requirements.system

# Add Python package
echo "new-python-package" >> requirements.pip3

# Rebuild core layer (includes new dependencies)
make rebuild_from_layer LAYER=core

# Restart with new dependencies
make cli
```

### Package Development

```bash
# Create .deb package
# (your package build process)

# Copy to vendor directory
cp my-package_1.0.0_amd64.deb vendor/

# Rebuild user layer (includes new package)
make rebuild_from_layer LAYER=user

# Start with new package installed
make cli
```

### Team Development

#### Sharing Environments
```bash
# Push base/core layers to registry
make push_base_images

# Team members can pull
make try_pull_base_images
make build  # Will use pulled layers
```

#### Consistent Environments
```bash
# All team members get same environment based on:
# 1. ADORe CLI commit hash
# 2. Project requirements hash
# 3. .deb package manifest

# Just run these commands:
git pull
git submodule update
make build
make cli
```

### CI/CD Integration

#### GitHub Actions
```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive
      
      - name: Build environment
        run: |
          export GITHUB_REPOSITORY=${{ github.repository }}
          make build
      
      - name: Run tests
        run: make run cmd="colcon test"
      
      - name: Push layers
        if: github.ref == 'refs/heads/main'
        run: make push_base_images
```

#### GitLab CI
```yaml
stages:
  - build
  - test

build:
  stage: build
  script:
    - git submodule update --init --recursive
    - make build
  cache:
    paths:
      - .log/

test:
  stage: test
  script:
    - make run cmd="colcon build"
    - make run cmd="colcon test"
```

## 🏷️ Tagging and Versioning

### Image Tagging Strategy

ADORe CLI uses intelligent tagging based on multiple factors:

#### Base Layer Tags
```
Format: adore_cli_base:<arch>_<adore_cli_branch>_<adore_cli_hash>[_dirty]
Example: adore_cli_base:x86_64_main_abc1234_dirty
```

#### Core Layer Tags
```
# When used in ADORe CLI repo:
adore_cli_core:<arch>_<adore_cli_branch>_<adore_cli_hash>

# When used in parent project:
adore_cli_core:<arch>_<adore_cli_branch>_<adore_cli_hash>_<parent_branch>_<parent_hash>_rh<requirements_hash>

Example: adore_cli_core:x86_64_main_abc1234_feature_def5678_rh9876543
```

#### User Layer Tags
```
# When used in ADORe CLI repo:
adore_cli:<arch>_<adore_cli_branch>_<adore_cli_hash>

# When used in parent project:
adore_cli:<arch>_<adore_cli_branch>_<adore_cli_hash>_<parent_branch>_<parent_hash>

Example: adore_cli:x86_64_main_abc1234_feature_def5678
```

### Tag Management

#### View Current Tags
```bash
# Show all current image names
make images_adore_cli

# Show current configuration
make adore_cli_info

# Show container name
make container_name_adore_cli
```

#### Tag History
ADORe CLI maintains a history of used tags to enable seamless environment switching:

```bash
# History is stored in:
.log/.adore_cli/adore_cli_tag_history

# When tags change, you get prompted:
# "Tag changed from X to Y. (r)ebuild, (a)ttach to old, (q)abort?"
```

## 📊 Monitoring and Debugging

### Build Monitoring

```bash
# Check build status
make build_status

# Show detailed configuration
make adore_cli_info

# Monitor Docker resource usage
docker stats

# Check disk usage
docker system df
```

### Runtime Monitoring

```bash
# Check container status
docker ps

# View container logs
docker logs adore_cli_<tag>

# Monitor resource usage
docker stats adore_cli_<tag>

# Inspect container
docker inspect adore_cli_<tag>
```

### Debug Information

#### Requirements Debug
```bash
# Debug requirements gathering
cd adore_cli_core && make debug_requirements

# Show requirements manifest
cat .log/.adore_cli/requirements_manifest.sha256

# Check requirements changes
tools/requirements_file_change_status.sh
```

#### Package Debug
```bash
# Debug package gathering
cd adore_cli && make debug_packages

# Show package manifest
cat .log/.adore_cli/packages_manifest.sha256

# Test package installation
make test_package_installation
```

#### Container Debug
```bash
# Interactive shell in user image
make debug_run

# Interactive shell as root
make debug_run_root

# Test ROS2 installation
make test_ros2_installation
```

## 🔐 Security Considerations

### Container Security

#### Privileged Mode
ADORe CLI runs containers in privileged mode for:
- Hardware access (cameras, sensors)
- Docker-in-Docker support
- Advanced debugging capabilities

#### Host Access
The container has access to:
- Docker socket (for container management)
- X11 display (for GUI applications)
- Host networking (for ROS2 communication)
- Source code directories

#### Security Best Practices
```bash
# Use separate development machine
# Don't run on production systems
# Regular security updates
sudo apt update && sudo apt upgrade

# Keep Docker updated
sudo apt update docker-ce

# Monitor container activity
docker logs adore_cli_<tag>
```

### Data Protection

#### Persistent Data
```bash
# Code changes persist (mounted from host)
# Build artifacts persist in .log/
# Container-specific changes are ephemeral

# Backup important data
cp -r .log/ backup/
```

#### Secrets Management
```bash
# SSH keys are mounted read-only
# Don't store secrets in requirements files
# Use environment variables for sensitive config
```

## 🤝 Contributing

### Development Setup

```bash
# Clone ADORe CLI for development
git clone <adore-cli-repo>
cd adore-cli
git submodule update --init --recursive

# Make changes to ADORe CLI itself
# Test changes
make build
make cli

# Run in parent project
cd ../my-project
# Update submodule to your branch
cd adore_cli
git checkout your-feature-branch
cd ..
make build
```

### Testing Changes

```bash
# Test base layer changes
cd adore_cli_base && make build

# Test core layer changes  
cd adore_cli_core && make build

# Test user layer changes
cd adore_cli && make build

# Test complete integration
make rebuild_force
make cli
```

### Code Style

#### Makefile Style
- Use tabs for indentation
- Add help comments with `##`
- Group related targets
- Use `.PHONY` for non-file targets

#### Bash Style
- Use `set -euo pipefail`
- Quote variables: `"${VAR}"`
- Use functions for complex logic
- Add error handling

#### Docker Style
- Multi-stage builds
- Minimize layers
- Use BuildKit features
- Add meaningful labels

### Submitting Changes

1. **Fork** the repository
2. **Create** feature branch
3. **Make** changes with tests
4. **Verify** all targets work
5. **Submit** pull request with description

### Issue Reporting

Include this information:
```bash
# System information
uname -a
docker --version
make --version

# ADORe CLI information
make adore_cli_info
make build_status

# Error reproduction steps
# Expected vs actual behavior
# Relevant log output
```

## 📚 Additional Resources

### Documentation
- [ROS2 Documentation](https://docs.ros.org/en/jazzy/)
- [Docker Documentation](https://docs.docker.com/)
- [Ubuntu Packages](https://packages.ubuntu.com/)

### Related Projects
- [ROS2 Development Containers](https://github.com/athackst/vscode_ros2_workspace)
- [Docker ROS](https://github.com/osrf/docker_images)

### Community
- [ROS Discourse](https://discourse.ros.org/)
- [Docker Community](https://forums.docker.com/)

## 📄 License

This project is licensed under the Eclipse Public License - v 2.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- ROS2 community for the excellent robotics framework
- Docker team for containerization technology
- Ubuntu team for the stable base system
- All contributors and testers

---

**Made with ❤️ for the ROS2 development community**
