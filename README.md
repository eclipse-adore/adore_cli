# ADORe CLI

> A three-layer containerized development environment for ROS2-based autonomous driving research and development with registry caching and intelligent layer management.

## Overview

ADORe CLI provides a complete, reproducible development environment with ROS2, debugging tools, visualization capabilities, and cross-platform support. It uses a sophisticated three-layer Docker architecture for maximum build efficiency and caching. The system automatically manages Docker containers, provides intelligent tag tracking, and features GitHub Container Registry integration for shared base layers. Simply drop requirements files anywhere in your project tree and ADORe CLI will automatically discover and install all dependencies during the build process.

## Quick Start

```bash
# Clone and initialize submodules
git submodule update --init --recursive

# Start the development environment (auto-builds if needed)
make cli

# Force rebuild everything
make build

# Check build status
make build_status

# Stop the environment
make stop
```

## Key Features

### Core Features
- **One-command setup**: `make cli` handles everything automatically
- **Smart tag tracking**: Detects environment changes and prompts for action
- **Three-layer architecture**: Maximum caching efficiency with user-agnostic layers
- **Registry integration**: GitHub Container Registry caching for faster builds
- **Cross-platform builds**: Support for ARM64 and x86_64 architectures
- **Auto-discovery**: Recursively finds and combines all requirements files

### Development Features
- **Hot reloading**: Automatically rebuilds when requirements change
- **Multiple display modes**: Native X11, headless, or window manager support
- **Development tools**: Integrated plotting, debugging, and tracing capabilities
- **Interactive shell**: Full zsh with oh-my-zsh, git integration, and colorization
- **Registry caching**: Shared base layers across users and CI/CD pipelines

## Available Commands

### Main User Commands
| Command | Description |
|---------|-------------|
| `make cli` | Start or attach to development environment |
| `make build` | Smart build of all required layers |
| `make clean` | Remove containers and build artifacts |
| `make run cmd="..."` | Execute command in container |
| `make stop` | Stop running containers |
| `make test` | Run CI tests |
| `make info` | Show current configuration |
| `make build_status` | Show status of all build layers |
| `make help` | Show all available make targets |

### Registry Commands
| Command | Description |
|---------|-------------|
| `make try_pull_base_images` | Try to pull base and core images from registry |
| `make push_base_images` | Push base and core images to registry |
| `make registry_status` | Show registry status for base images |
| `make cleanup_registry_images` | Cleanup old images in registry (ros2 branch only) |

### Advanced Commands
| Command | Description |
|---------|-------------|
| `make debug_run` | Launch interactive bash shell in user image |
| `make debug_run_root` | Launch interactive bash shell as root |
| `make rebuild_force` | Force rebuild all layers (ignore existing images) |
| `make rebuild_from_layer LAYER=core` | Rebuild from specific layer |

## Three-Layer Architecture

ADORe CLI uses an intelligent three-layer Docker architecture for maximum efficiency:

### 1. System Base Layer (`adore_cli_system`)
- **Tag**: `${BRANCH}_${SHORT_HASH}_${ARCH}`
- **Contents**: OS packages, ROS2 foundation, basic system tools
- **Sharing**: User-agnostic, highly cacheable across all users
- **Registry**: Shared in GitHub Container Registry for fast CI/CD

### 2. Core Environment Layer (`adore_cli_core`) 
- **Tag**: `${BRANCH}_${SHORT_HASH}_${ARCH}`
- **Contents**: Complete ROS2 environment, development tools, X11 support
- **Sharing**: User-agnostic, shared across all users for same git commit
- **Registry**: Shared in GitHub Container Registry

### 3. User Customization Layer (`adore_cli_user`)
- **Tag**: `${BRANCH}_${SHORT_HASH}_${ARCH}_${USER}`
- **Contents**: User-specific configuration, shell setup, permissions
- **Sharing**: User-specific, thin layer built locally
- **Registry**: Not shared (user-specific)

### 4. Runtime Environment (`adore_cli`)
- **Tag**: Complex tag including parent project info
- **Contents**: Discovered requirements, development tools
- **Sharing**: User and project specific
- **Registry**: Not shared (contains project-specific requirements)

## Build Process Intelligence

### Smart Layer Detection
```bash
# Build only missing layers
make build

# Check what exists
make build_status
System Base     adore_cli_system:ros2_ee6f341_x86_64      ✓ EXISTS
Core Environment adore_cli_core:ros2_ee6f341_x86_64        ✓ EXISTS  
User Layer       adore_cli_user:ros2_ee6f341_x86_64_user   ✗ MISSING
Runtime          adore_cli:ros2_ee6f341_x86_64_...         ✗ MISSING
```

### Registry Integration
```bash
# Try registry first, build locally if needed
make build
=== ADORe CLI Core Build Process ===
Attempting to pull from registry...
✓ Pulled system base from registry
✓ Pulled core environment from registry  
Building user customization layer locally
```

### CI/CD Integration
- **Automatic push**: Base and core layers pushed to GitHub Container Registry
- **Smart caching**: Only builds what's missing from registry
- **Storage management**: Keeps last 2 commits for ros2 branch
- **Cross-architecture**: Separate images for ARM64 and x86_64

## Display Modes and Graphical Applications

ADORe CLI supports multiple display configurations for running graphical applications like RViz2, PlotJuggler, and custom visualization tools:

### Native Display Mode (Default)
Directly forwards X11 display to host system:
```bash
# Uses host display (default)
make cli
```
- **Pros**: Best performance, native look and feel
- **Cons**: Requires X11 server on host
- **Use case**: Local development with GUI applications

### Headless Mode
Runs without any display server for server/CI environments:
```bash
# Start in headless mode
DISPLAY_MODE=headless make cli
```
- **Pros**: Minimal resource usage, works anywhere
- **Cons**: No graphical applications
- **Use case**: CI/CD, remote servers, command-line only workflows

### Window Manager Mode
Provides isolated display environment:
```bash
# Start with window manager
DISPLAY_MODE=window_manager make cli
```
- **Pros**: Isolated from host display, consistent environment
- **Cons**: Additional overhead
- **Use case**: Reproducible GUI testing, multiple concurrent sessions

### Graphical Application Support

ADORe CLI includes pre-installed graphical tools:
- **RViz2**: 3D visualization for robot data
- **PlotJuggler**: Real-time plotting and data analysis
- **Foxglove Bridge**: Real-time visualization and debugging
- **X11 apps**: xterm, xclock for testing display connectivity

### Testing Display Setup
```bash
# Inside ADORe CLI, test X11 forwarding
xclock

# Test ROS2 visualization
rviz2

# Launch PlotJuggler
ros2 run plotjuggler plotjuggler
```

### Troubleshooting Display Issues
```bash
# Check display environment
echo $DISPLAY

# Test basic X11 connectivity
xeyes

# For permission issues on Linux hosts
xhost +local:docker
```

## Automatic Requirements Discovery

ADORe CLI automatically discovers and combines requirements files from your entire project tree:

### Supported File Types
- **`*.system`**: APT/system packages (one per line, supports `${ROS_DISTRO}` and `${OS_CODE_NAME}` variables)
- **`*.pip3`**: Python packages (one per line, supports variable substitution)
- **`*.ppa`**: Ubuntu PPAs (ppa:repository/name format)
- **`*.deb`**: Direct .deb package files

### Variable Substitution
Requirements files support environment variable substitution:
```bash
# In any .system file
ros-${ROS_DISTRO}-nav2-bringup
ros-${ROS_DISTRO}-tracetools

# Automatically expands to:
ros-jazzy-nav2-bringup  
ros-jazzy-tracetools
```

### How It Works
1. **Recursive Search**: Scans entire source directory tree for requirements files
2. **Variable Expansion**: Uses `envsubst` to expand `${ROS_DISTRO}` and other variables
3. **Smart Filtering**: Excludes `/ros_translator/*` paths and removes comments/empty lines
4. **Deduplication**: Combines and sorts all found dependencies
5. **Layer-Aware Install**: Installs in appropriate Docker layer for maximum caching

### File Locations
Place requirements files anywhere in your project:
```
project/
├── requirements.system                    # Root level
├── module_a/
│   └── requirements.module_a.pip3         # Module specific
├── drivers/
│   ├── camera/
│   │   └── camera_driver.system           # Deep nesting
│   └── requirements.ppa                   # PPAs
└── vendor/
    └── my_package.deb                     # Direct .deb files
```

## Registry Features

### GitHub Container Registry Integration
ADORe CLI integrates with GitHub Container Registry (ghcr.io) for sharing base layers:

```bash
# Check what's available in registry
make registry_status
=== Registry Status ===
Registry: ghcr.io/dlr-ts/
Checking system base: ghcr.io/dlr-ts/adore_cli_system:ros2_ee6f341_x86_64
  ✓ Available in registry
Checking core environment: ghcr.io/dlr-ts/adore_cli_core:ros2_ee6f341_x86_64  
  ✓ Available in registry
```

### CI/CD Optimization
- **Automatic caching**: CI builds push base/core layers to registry
- **Fast rebuilds**: Subsequent builds pull from registry instead of building
- **Storage management**: Cleanup keeps only last 2 commits for ros2 branch
- **Multi-architecture**: Separate cache for ARM64 and x86_64

### Local Registry Usage
```bash
# Set repository for local testing
export GITHUB_REPOSITORY=your-org/your-repo

# Try pulling base images
make try_pull_base_images

# Push your built images (requires write access)
make push_base_images
```

## Cross-Platform Development

Build for different architectures with automatic dependency management:

```bash
# ARM64 (automatically sets up cross-compilation)
ARCH=arm64 make build

# x86_64 (default)
ARCH=x86_64 make build

# Check current architecture
echo $ARCH
```

**Cross-compilation features:**
- **Automatic setup**: Installs qemu-user-static and buildx if needed (Ubuntu only)
- **Registry awareness**: Separate images for each architecture
- **Fallback support**: Graceful fallback to native build if cross-compilation fails

## Tag Memory System

ADORe CLI intelligently tracks container states and handles environment changes:

### Smart Change Detection
```bash
make cli
Warning: ADORE_CLI tag has changed
  Previous: adore_cli:ros2_abc123_x86_64_main_def456_user
  Current:  adore_cli:ros2_ee6f341_x86_64_feature_new_857bf02_user

Choose action: (r)ebuild with new tag, (a)ttach to old container, or (q)abort? [r/a/q]:
```

### Intelligent Options
- **Rebuild (r)**: Build with new environment configuration
- **Attach (a)**: Continue using existing container (preserves work)
- **Quit (q)**: Abort and make no changes

### History Management
- **Automatic tracking**: Remembers last used container configuration
- **Cross-session**: Works across terminal sessions
- **Auto-cleanup**: Clears history on intentional rebuilds

## Customization

### Adding System Packages
Create `*.system` files anywhere in your project:
```bash
# Example: my_module/requirements.system
ros-${ROS_DISTRO}-nav2-bringup
ros-${ROS_DISTRO}-plotjuggler-ros
gdb
htop
vim
```

### Adding Python Packages
Create `*.pip3` files anywhere in your project:
```bash
# Example: algorithms/requirements.pip3
numpy>=1.20.0
matplotlib
scipy
pandas
```

### Adding PPAs
Create `requirements.ppa` files anywhere in your project:
```bash
# Example: tools/requirements.ppa
ppa:deadsnakes/ppa
ppa:graphics-drivers/ppa
```

## Debian Package Integration

ADORe CLI automatically discovers and installs Debian (.deb) packages from your project tree during the build process. This allows you to include custom packages, proprietary software, or specific versions that aren't available through standard repositories.

### Automatic .deb Discovery

#### File Placement
Place `.deb` files anywhere in your project tree. The build system will automatically find and install them:

```
project/
├── vendor/
│   ├── custom_driver.deb              # Vendor packages
│   └── proprietary_lib.deb            # Proprietary software
├── modules/
│   └── camera/
│       └── camera_firmware.deb       # Module-specific packages
└── tools/
    └── debug_tools.deb               # Development tools
```

#### Discovery Process
1. **Recursive Scan**: Searches entire project tree for `*.deb` files
2. **Gathering**: Copies all found .deb files to build context
3. **Installation**: Installs packages in runtime layer using `dpkg`
4. **Dependency Resolution**: Handles dependencies automatically

### Installation Layer

**.deb files are installed in the Runtime Layer:**
- **When**: During runtime image build (final layer)
- **Why**: Allows project-specific packages without affecting shared base layers
- **User-specific**: Each user/project combination gets their own .deb packages
- **No caching**: Runtime layer is rebuilt when .deb files change

### Installation Process

The build system handles .deb installation automatically:

```bash
# During build process
Copying .tmp/packages/. /tmp/
Workdir /tmp
RUN find . -maxdepth 1 -type f -name "*.deb" -print0 | \
    xargs -0 sudo dpkg -i --force-all 2>/dev/null || true
```

### Supported Package Types

- **Architecture-specific**: Packages built for specific architectures (amd64, arm64)
- **Multi-architecture**: Packages that work across architectures
- **Custom builds**: Locally built packages from your development
- **Vendor packages**: Third-party proprietary software
- **Firmware packages**: Hardware-specific drivers and firmware

### Best Practices

#### Package Naming
```bash
# Good: descriptive names
vendor/
├── nvidia_driver_535.54_amd64.deb
├── custom_ros2_node_v1.2.3_arm64.deb
└── proprietary_algorithm_20231215.deb

# Avoid: generic names
├── package.deb                    # Too generic
├── temp.deb                       # Unclear purpose
```

#### Architecture Handling
```bash
# Organize by architecture if needed
vendor/
├── amd64/
│   └── x86_specific_driver.deb
├── arm64/
│   └── arm_specific_firmware.deb
└── universal/
    └── arch_independent_tool.deb
```

#### Documentation
Document your .deb packages in your project:
```bash
# vendor/README.md
## Custom Packages

- `nvidia_driver_535.54_amd64.deb`: NVIDIA GPU driver v535.54
- `custom_sensor_driver.deb`: Proprietary sensor interface
- `firmware_update_tool.deb`: Hardware firmware updater
```

### Debugging .deb Installation

#### Check Installation Status
```bash
# Inside ADORe CLI container
dpkg -l | grep -i custom           # List installed custom packages
dpkg -s package_name               # Check specific package status
apt list --installed | grep local  # Show locally installed packages
```

#### Installation Logs
```bash
# Check build logs for .deb installation
make build 2>&1 | grep -A5 -B5 "\.deb"

# Debug specific package
docker run -it --rm adore_cli_image dpkg -l | grep package_name
```

#### Common Issues

**Dependency conflicts:**
```bash
# Fix: Install dependencies first via requirements.system
# my_module/requirements.system
libdependency1
libdependency2

# Then place .deb file
# my_module/custom_package.deb
```

**Architecture mismatches:**
```bash
# Fix: Use architecture-specific organization
vendor/
├── amd64/package_amd64.deb
└── arm64/package_arm64.deb

# Or use multi-arch packages
vendor/package_all.deb
```

**Installation order:**
```bash
# .deb packages are installed AFTER system packages
# 1. System packages (requirements.system)
# 2. Python packages (requirements.pip3)  
# 3. Debian packages (.deb files)
# 4. ADORe CLI specific packages
```

### Example Workflow

#### Adding a Custom Package
```bash
# 1. Place .deb file in project
cp ~/Downloads/custom_driver.deb vendor/

# 2. Rebuild to install
make build

# 3. Verify installation
make cli
dpkg -l | grep custom_driver
```

#### Building and Including Custom Packages
```bash
# 1. Build your custom package
dpkg-buildpackage -us -uc

# 2. Copy to vendor directory
cp ../my-package_1.0_amd64.deb vendor/

# 3. Rebuild ADORe CLI
make build

# 4. Test package functionality
make run cmd="my-custom-command --version"
```

### Integration with Requirements System

.deb packages work seamlessly with other requirements:

```
project/
├── requirements.system              # System dependencies
│   ├── libcustom-dev               # Dependencies for .deb
│   └── build-essential             # Build tools
├── requirements.pip3               # Python packages
│   └── custom-python-wrapper       # Python interface
└── vendor/
    └── custom_native_lib.deb       # Native library .deb
```

**Installation order ensures dependencies are satisfied:**
1. System packages installed first (provides dependencies)
2. Python packages installed second  
3. .deb packages installed third (can use system dependencies)
4. ADORe CLI packages installed last

### Limitations and Considerations

- **No automatic updates**: .deb packages are installed once during build
- **Dependency management**: Must manually ensure dependencies via requirements.system
- **Architecture awareness**: Ensure .deb matches target architecture
- **Size impact**: Large .deb files increase image size and build time
- **Security**: Only include trusted .deb packages from verified sources
- **Licensing**: Ensure .deb package licenses are compatible with your project

---

**Note**: .deb packages are installed in the runtime layer and do not benefit from the shared base layer caching. For packages that could benefit multiple users, consider requesting them as system packages instead.

### Advanced Customization
```bash
# Check current configuration
make info
=== ADORe CLI Configuration ===
ROS_DISTRO: jazzy
OS_CODE_NAME: noble
ARCH: x86_64
BRANCH: feature/new-feature
SHORT_HASH: ee6f341
```

## Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `ROS_DISTRO` | ROS2 distribution | `jazzy` | `humble`, `iron` |
| `OS_CODE_NAME` | Ubuntu codename | `noble` | `jammy`, `focal` |
| `ARCH` | Target architecture | Host arch | `x86_64`, `arm64` |
| `SOURCE_DIRECTORY` | Host source directory | Current directory | `/home/user/workspace` |
| `DISPLAY_MODE` | Display mode | `native` | `headless`, `window_manager` |
| `GITHUB_REPOSITORY` | GitHub repo for registry | None | `org/repo` |
| `DOCKER_BUILDKIT` | Enable BuildKit | `1` | `0`, `1` |

## Requirements

### System Requirements
- **Docker**: Version 28+ with BuildKit support
- **Make**: GNU Make for build orchestration
- **Git**: For repository management and submodules
- **Base OS**: Ubuntu 20.04+ (for cross-compilation features)

### Optional Requirements
- **qemu-user-static**: For cross-compilation (auto-installed on Ubuntu)
- **binfmt-support**: For cross-compilation (auto-installed on Ubuntu)
- **X11 server**: For native display mode on Linux hosts

### Resource Requirements
- **RAM**: 4GB minimum, 8GB recommended
- **Disk**: 10GB for base images, additional space for builds
- **Network**: Internet access for package installation and registry operations

## Development Workflow

### Standard Workflow
1. **Initialize**: `git submodule update --init --recursive`
2. **Start environment**: `make cli` (auto-builds and caches), **does not compile nodes, libraries or vendor libraries**
3. **Develop**: Edit code in mounted source directory
4. **Add dependencies**: Create requirements files anywhere in project
5. **Update environment**: `make build` (discovers new requirements)
6. **Test**: `make test` for validation
7. **Iterate**: Continue development with automatic layer caching

### Multi-User Workflow
```bash
# User A builds and pushes base layers
USER=alice make build
make push_base_images

# User B pulls cached layers (much faster)
USER=bob make build
✓ Pulled system base from registry
✓ Pulled core environment from registry
Building user layer locally...
```

### CI/CD Integration
- **GitHub Actions**: Automatic base layer building and caching
- **Registry cleanup**: Automatic cleanup of old images
- **Multi-architecture**: Parallel builds for ARM64 and x86_64
- **Test integration**: Comprehensive test suite with layer validation

## Included Tools and Packages

### ROS2 Environment
- **ROS2 Jazzy**: Complete ROS2 development stack
- **Build tools**: colcon, rosdep, ros2 CLI tools
- **Navigation**: nav2 stack for autonomous navigation
- **Tracing**: ROS2 tracing tools for performance analysis

### Visualization and Debugging
- **PlotJuggler**: Real-time data plotting and analysis
- **Foxglove Bridge**: Modern visualization and debugging
- **RViz2**: 3D visualization for robot data
- **GDB/GDBServer**: Full debugging support
- **Network tools**: telnet, netcat, traceroute, nmap

### Development Environment
- **Shell**: zsh with oh-my-zsh, git integration, colorization
- **Editors**: vim with development-friendly configuration
- **Build optimization**: ccache for faster compilation
- **Version control**: git with full CLI integration
- **System tools**: htop, fzf, cowsay for enhanced productivity

### Language Support
- **Python**: Python 3 with development packages
- **C++**: Full C++ development stack with debugging
- **CMake**: Modern CMake for cross-platform builds
- **Clang**: clang-format for code formatting

## Troubleshooting

### Common Issues

**Build failures:**
```bash
# Check layer status
make build_status

# Force clean rebuild
make clean
make build


# Force clean rebuild without using registry cache
make rebuild_force

# Check Docker version
docker version
```

**Registry issues:**
```bash
# Check registry status
make registry_status

# Set repository manually
export GITHUB_REPOSITORY=git@github.com:eclipse-adore/adore_cli.git
make registry_status
```

**Display problems:**
```bash
# Test X11 forwarding
make cli
xclock  # Should open a clock window

# Check permissions (Linux)
xhost +local:docker
```

**Permission issues:**
```bash
# Check user/group IDs
make info | grep -E "(UID|GID)"

# Rebuild with correct IDs
make clean
UID=$(id -u) GID=$(id -g) make build
```

### Debug Commands
```bash
# Interactive debug session
make debug_run

# Root access for system debugging
make debug_run_root

# Check container logs
docker logs adore_cli_container_name

# Inspect built images
docker images | grep adore_cli
```

### Getting Help
```bash
# Inside ADORe CLI
help

# Show all make targets
make help

# Show current configuration
make info
```

---

