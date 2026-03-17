# ADORe CLI - Advanced Development Environment

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![ROS2](https://img.shields.io/badge/ros2-jazzy-blue?style=for-the-badge&logo=ros&logoColor=white)](https://docs.ros.org/en/jazzy/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)

A sophisticated, multi-layer Docker-based development environment for ROS2 
projects with intelligent caching, automated dependency management, 
and seamless developer experience.

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

## ✨ Key Features

### 🏗️ Three-Layer Architecture
- **Base Foundation**: Ubuntu 24.04 + ROS2 Jazzy core (highly cacheable, user-agnostic)
- **Core Environment**: Complete toolchain + all discovered dependencies (shareable across users)  
- **User Layer**: Personal customization + .deb packages + user account (user-specific)

### 🎯 Smart Build System
- **Intelligent Caching**: Only rebuilds changed layers using SHA256 fingerprinting
- **Requirements Discovery**: Automatically finds and installs from `.system`, `.pip3`, `.ppa` files
- **Package Management**: Installs custom `.deb` packages from `vendor/` directory
- **Cross-Platform**: Native ARM64 and x86_64 support with cross-compilation
- **Registry Integration**: Pull/push layer caching for CI/CD optimization

### 🛠️ Developer Experience
- **Interactive CLI**: Seamless container attach/detach with persistent state
- **Hot Reloading**: Live code mounting for immediate development feedback
- **Shell Integration**: zsh with oh-my-zsh and custom ADORe CLI prompt
- **History Persistence**: Command history preserved across sessions
- **Change Detection**: Automatically detects requirement and package changes

## 🏛️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ADORe CLI Architecture                    │
├─────────────────────────────────────────────────────────────┤
│  User Layer (adore_cli:tag)                                 │
│  ├─ User account & shell environment                        │
│  ├─ .deb packages from vendor/                              │
│  ├─ Personal development tools                              │
│  └─ Final development-ready image                           │
├─────────────────────────────────────────────────────────────┤
│  Core Environment (adore_cli_core:tag)                      │
│  ├─ All project requirements (.system, .pip3, .ppa)        │
│  ├─ ROS2 complete toolchain and build tools                 │
│  ├─ Development libraries and dependencies                  │
│  └─ User-agnostic shareable environment                     │
├─────────────────────────────────────────────────────────────┤
│  Base Foundation (adore_cli_base:tag)                       │
│  ├─ Ubuntu 24.04 Noble + ROS2 Jazzy foundation             │
│  ├─ System fundamentals and container runtime              │
│  ├─ Oh-my-zsh and shell configuration                       │
│  └─ Highly cacheable, globally shareable                    │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

- **Docker**: 28.0+ with BuildKit support
- **OS**: Linux (Ubuntu 20.04+ recommended)
- **Memory**: 8GB+ RAM, 20GB+ free disk space
- **Make**: GNU Make for build orchestration
- **Git**: For submodule management

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Make
sudo apt update && sudo apt install make git

# Logout and login to apply Docker group membership
```

## 🎯 Usage

### Essential Commands

| Command | Description | Use Case |
|---------|-------------|----------|
| `make build` | Build complete three-layer environment | First setup, major changes |
| `make cli` | Start/attach to development environment | Daily development |
| `make run cmd="<command>"` | Execute command in container | Running tests, builds |
| `make stop` | Stop running container | End development session |
| `make clean` | Remove all images and artifacts | Complete reset |

### Daily Development Workflow

```bash
# Start development session
make cli

# Inside container - your code is mounted at /tmp/adore
cd /tmp/adore

# Build your ROS2 packages
colcon build

# Run your code
ros2 launch my_package my_launch.py

# Exit (container keeps running)
exit

# Reattach to same session
make cli

# Stop when done
make stop
```

## 🔨 Requirements Management

ADORe CLI automatically discovers and installs dependencies from your project:

### File Types Supported
- **`requirements.system`** or **`*.system`**: APT package requirements
- **`requirements.pip3`** or **`*.pip3`**: Python package requirements  
- **`requirements.ppa`** or **`*.ppa`**: Ubuntu PPA repositories

### Example Files

**requirements.system**:
```
ros-jazzy-rclcpp
vim
git
cmake
build-essential
```

**requirements.pip3**:
```
numpy
matplotlib
rosdep
colcon-common-extensions
```

**requirements.ppa**:
```
ppa:deadsnakes/ppa
```

### Custom .deb Packages
Place `.deb` files in `vendor/` directory for automatic installation:
```
vendor/
├── my-custom-lib_1.0.0_amd64.deb
├── another-package_2.1.0_amd64.deb
└── subdirectory/
    └── nested-package_1.5.0_amd64.deb
```

## 🔧 Advanced Usage

### Build Targets

```bash
# Force complete rebuild (ignores cache)
make rebuild_force

# Rebuild from specific layer
make rebuild_from_layer LAYER=base    # Rebuild all layers
make rebuild_from_layer LAYER=core    # Rebuild core + user
make rebuild_from_layer LAYER=user    # Rebuild user only

# Check build status
make build_status

# Show configuration
make adore_cli_info
```

### Environment Variables

```bash
# Architecture selection
export ARCH=amd64  # or arm64

# ROS Distribution
export ROS_DISTRO=jazzy

# Custom hostname
export HOSTNAME=my-dev-environment
```

### Registry Integration

```bash
# Set repository for registry operations
export GITHUB_REPOSITORY=your-org/your-repo

# Pull base/core images from registry
make try_pull_base_images

# Push base/core images to registry
make push_base_images

# Check registry status
make registry_status
```

## 🌐 CI/CD Integration

ADORe CLI supports automated builds and registry integration:

### GitHub Actions
The project includes reusable workflows:
- **Native x86_64 builds**: `ubuntu-latest` runners
- **Native ARM64 builds**: `ubuntu-24.04-arm` runners
- **Cross-compilation**: x86_64 to ARM64
- **Registry push**: Automatic base/core layer sharing

### Key CI Features
- Runs on all branches and pull requests
- Pushes base images only from origin repository (not forks)
- Intelligent caching using registry layers
- Parallel builds for different architectures
- Comprehensive logging and artifact uploads

## 🔍 Troubleshooting

### Common Issues

**Environment Changes Detected**:
```bash
# Check what changed
make show_changes

# Rebuild affected layers
make rebuild_from_layer LAYER=core  # For requirements changes
make rebuild_from_layer LAYER=user  # For .deb package changes
```

**Build Failures**:
```bash
# Check Docker status
docker info

# Clean Docker cache
docker system prune -f

# Force complete rebuild
make rebuild_force
```

**Container Issues**:
```bash
# Debug container interactively
make debug_run

# Debug as root
make debug_run_root

# Check container logs
docker logs adore_cli_<tag>
```

### Debug Information

```bash
# Show detailed configuration
make adore_cli_info

# Debug requirements processing
cd adore_cli_core && make debug_requirements

# Debug package installation
cd adore_cli && make debug_packages

# Test ROS2 installation
make test_ros2_installation
```

## 📚 Architecture Details

### Intelligent Tagging System

ADORe CLI uses sophisticated tagging based on multiple factors:

- **Base Layer**: `adore_cli_base:<arch>_<branch>_<hash>`
- **Core Layer**: `adore_cli_core:<arch>_<branch>_<hash>_RH<requirements_hash>`
- **User Layer**: `adore_cli:<arch>_<branch>_<hash>_PH<packages_hash>_<user>_UID<uid>GID<gid>`

### Change Detection

The system automatically detects changes and rebuilds only necessary layers:
- **Base**: Rebuilds when ADORe CLI code changes
- **Core**: Rebuilds when requirements files change
- **User**: Rebuilds when .deb packages change

### Registry Strategy

- **Base/Core layers**: Shared across users and environments
- **User layers**: Never pushed (user-specific)
- **CI/CD optimization**: Pull cached layers before building
- **Security**: Only origin repository can push images

## 🤝 Contributing

### Development Setup

```bash
# Clone for development
git clone <adore-cli-repo>
cd adore-cli
git submodule update --init --recursive

# Test changes
make build
make cli
```

### Adding Features

1. **Add Requirements**: Place new `.system`, `.pip3`, or `.ppa` files in your project
2. **Add Packages**: Place `.deb` files in `vendor/` directory  
3. **Test**: Run `make rebuild_from_layer LAYER=core` or `LAYER=user`
4. **Verify**: Use `make cli` to test the new environment

## 📄 License

This project is licensed under the Eclipse Public License - v 2.0 - see the [LICENSE](LICENSE) file for details.

---

**Made with ❤️ for the ROS2 development community**
