# nav2_docker

![Build Status](https://img.shields.io/badge/Last%20Build-2026--03--10-blue) ![Workflow Status](https://img.shields.io/badge/CI-Active-success)

Nav2 distributed docker containers for active ROS 2 distributions for development and deployment. For a guide for using Docker for development, see [our tutorial at docs.nav2.org](https://docs.nav2.org/tutorials/docs/docker_dev.html).

Currently supported distributions:
- Humble
- Jazzy
- Kilted
- Rolling

Each distribution has two images that are generated: bleeding edge based on the status of the Nav2 branch associated with the distribution (nightly) and the latest officially released version (ex `1.2.15`).

## Image Tiers

Each distribution generates three distinct image targets to balance size and utility:

| Tier | Tag Suffix | Content | Primary Use Case | Approx. Size |
| :--- | :--- | :--- | :--- | :--- |
| **Development** | `-devel` | Full workspace (`src`, `build`), GUI tools, and Sim. | Active coding and recompiling within the container. | ~9.5GB |
| **Standard** | `-standard` | Compiled binaries (`install`), GUI tools, and Sim. | Testing, CI validation, and Gazebo simulations. | ~7.8GB |
| **Production** | `-production`| Core navigation only, **Headless** (No RViz/Gazebo/Qt). | Deployment on physical robot hardware. | ~4.8GB |

## How to Use Provided Containers

The images can be found in `Packages` on the right-hand side of the repository [or at this link](https://github.com/ros-navigation/nav2_docker/pkgs/container/nav2_docker). 

To optimize for different robotics workflows, we provide three specialized tiers. **You must specify the tier suffix** to ensure you are pulling the correct environment for your needs.

### Pulling an Image
```bash
# For Nav2 Developers (cloned source included)
docker pull ghcr.io/ros-navigation/nav2_docker:jazzy-nightly-devel

# For Simulation and Testing (Desktop-Full tools included)
docker pull ghcr.io/ros-navigation/nav2_docker:jazzy-nightly-standard

# For Robot Deployment (Headless/Smallest footprint)
docker pull ghcr.io/ros-navigation/nav2_docker:jazzy-nightly-production
```

## Local Development

We provide two primary workflows depending on whether you want to mount your own workspace or work with an isolated container environment:

### Option 1: Mounting a Local Workspace

Use the Standard image if you have a local nav2_ws and want to use the container's pre-installed dependencies and GUI tools (RViz/Gazebo).
```
sudo docker run -it --net=host --privileged -v .:/root/nav2_ws --volume="${XAUTHORITY}:/root/.Xauthority" --env="DISPLAY=$DISPLAY" -v="/tmp/.gazebo/:/root/.gazebo/" -v /tmp/.X11-unix:/tmp/.X11-unix:rw --shm-size=1000mb ghcr.io/ros-navigation/nav2_docker:jazzy-nightly-standard
```
This mounts your local workspace into the container. Build artifacts will persist on your host machine so progress is not lost.

### Option 2: Isolated Development

Use the Development image if you wish to work fully isolated within the container using the Nav2 source code already cloned in `nav2_ws` and prepared in the image.

```
sudo docker run -it --net=host --privileged --volume="${XAUTHORITY}:/root/.Xauthority" --env="DISPLAY=$DISPLAY" -v="/tmp/.gazebo/:/root/.gazebo/" -v /tmp/.X11-unix:/tmp/.X11-unix:rw --shm-size=1000mb ghcr.io/ros-navigation/nav2_docker:jazzy-nightly-devel
```
Navigate to /root/nav2_ws within the container to find the complete source, build, and install tree ready for modification.

## Building for Local Use

You can build specific image tiers locally by using the `--target` flag. The Dockerfile uses a dual-builder architecture: `builder-full` compiles all packages (for devel/standard), while `builder-production` compiles only core navigation packages (for production).

### Building Specific Tiers
To build a specific version locally from the root of this repository:

```bash
# Build the lean Production image (Headless - core navigation only)
sudo docker build --target production -t nav2:local-prod .

# Build the full Development image (Includes source code and all packages)
sudo docker build --target devel -t nav2:local-devel .

# Build the Standard image (Includes GUI tools/Sim, no source)
sudo docker build --target standard -t nav2:local-standard .

```

**Note:** The production image excludes visualization and simulation packages (`nav2_rviz_plugins`, `nav2_bringup`, `nav2_system_tests`, TurtleBot simulation packages) to minimize size. All core navigation functionality (controllers, planners, costmaps, localization, etc.) is included.

### Build Arguments

You can customize the build process using the `--build-arg` flag to suit your specific requirements:

* **`ROS_DISTRO`**: Specify the ROS 2 distribution (e.g., `--build-arg ROS_DISTRO=humble`).
* **`BUILD=false`**: Use this if you do **not** want to compile Nav2 (sets up the environment with dependencies only).
* **`COLCON_BUILD_ARGS="..."`**: Pass custom arguments to the colcon build process (e.g., `--build-arg COLCON_BUILD_ARGS="--symlink-install"`).

### Refreshing the Base

If the upstream OSRF images have changed significantly, it is recommended to pull the latest base image before building to ensure you have the latest security patches and core updates:

```bash
# Example for Rolling
sudo docker pull osrf/ros:rolling-desktop-full
sudo docker build -t nav2:local -f Dockerfile .
```
From that point on, the instructions above for local development use may be followed.