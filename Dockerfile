# Navigation2 Multi-Stage Dockerfile
#
# This Dockerfile implements a dual-builder, multi-target architecture to provide
# optimized images for different use cases while maintaining full functionality.
#
# Available Targets:
#   - devel:      Development image with full workspace (src/build/log/install)
#                 Includes RViz, Gazebo, and all Nav2 packages for active development
#
#   - standard:   Testing and simulation image with compiled binaries only (install/)
#                 Includes RViz, Gazebo, and all Nav2 packages without build artifacts
#
#   - production: Headless runtime image for robot deployment
#                 Excludes GUI/simulation packages, includes only core navigation
#
# Build Examples:
#   docker build --target devel -t nav2:devel .
#   docker build --target standard -t nav2:standard .
#   docker build --target production -t nav2:production .

ARG ROS_DISTRO=rolling

# ==============================================================================
# BUILDER STAGE: Full Build (for devel and standard targets)
# ==============================================================================
# Compiles all Nav2 packages including GUI and simulation tools
FROM osrf/ros:${ROS_DISTRO}-desktop-full AS builder-full
ARG ROS_DISTRO
ARG VERSION_TAG=latest

# Install build dependencies
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    ros-dev-tools \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/nav2_ws
RUN mkdir -p src

# Clone Navigation2 source code
RUN if [ "${ROS_DISTRO}" = "rolling" ]; then \
      git clone https://github.com/ros-planning/navigation2.git --branch main ./src/navigation2 && \
      vcs import ./src/ < ./src/navigation2/tools/underlay.repos; \
    elif [ "${VERSION_TAG}" = "latest" ]; then \
      git clone https://github.com/ros-planning/navigation2.git --branch ${ROS_DISTRO} ./src/navigation2; \
    else \
      git clone https://github.com/ros-planning/navigation2.git --branch ${VERSION_TAG} ./src/navigation2; \
    fi

# Install build dependencies via rosdep
RUN if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then \
      rosdep init; \
    fi && rosdep update

RUN apt update && apt upgrade -y \
    && rosdep install -y --ignore-src --from-paths src -r \
       --skip-keys "slam_toolbox turtlebot3_gazebo" \
    && rm -rf /var/lib/apt/lists/*

# Build all Nav2 packages
ARG BUILD=true
ARG COLCON_BUILD_ARGS=""
RUN if [ "${BUILD}" = "true" ]; then \
      . /opt/ros/${ROS_DISTRO}/setup.sh \
      && colcon build $COLCON_BUILD_ARGS; \
    else \
      mkdir -p /root/nav2_ws/install; \
    fi


# ==============================================================================
# BUILDER STAGE: Production Build (for production target)
# ==============================================================================
# Compiles only core Nav2 packages, excludes GUI and simulation tools
FROM ros:${ROS_DISTRO}-ros-base AS builder-production
ARG ROS_DISTRO
ARG VERSION_TAG=latest

# Install build dependencies
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    ros-dev-tools \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/nav2_ws
RUN mkdir -p src

# Clone Navigation2 source code (same as builder-full)
RUN if [ "${ROS_DISTRO}" = "rolling" ]; then \
      git clone https://github.com/ros-planning/navigation2.git --branch main ./src/navigation2 && \
      vcs import ./src/ < ./src/navigation2/tools/underlay.repos; \
    elif [ "${VERSION_TAG}" = "latest" ]; then \
      git clone https://github.com/ros-planning/navigation2.git --branch ${ROS_DISTRO} ./src/navigation2; \
    else \
      git clone https://github.com/ros-planning/navigation2.git --branch ${VERSION_TAG} ./src/navigation2; \
    fi

# Install build dependencies, excluding GUI/simulation packages
RUN if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then \
      rosdep init; \
    fi && rosdep update

RUN apt update && apt upgrade -y \
    && rosdep install -y --ignore-src --from-paths src -r \
       --skip-keys "slam_toolbox \
                    turtlebot3_gazebo \
                    rviz2 \
                    gazebo_ros_pkgs \
                    nav2_rviz_plugins \
                    nav2_bringup \
                    nav2_system_tests \
                    nav2_minimal_tb3_sim \
                    nav2_minimal_tb4_description \
                    nav2_minimal_tb4_sim" \
    && rm -rf /var/lib/apt/lists/*

# Build core Nav2 packages only, skip GUI/simulation packages
# Note: navigation2 metapackage is skipped as it depends on all packages including those we're excluding
ARG BUILD=true
ARG COLCON_BUILD_ARGS=""
RUN if [ "${BUILD}" = "true" ]; then \
      . /opt/ros/${ROS_DISTRO}/setup.sh \
      && colcon build \
         --packages-skip nav2_rviz_plugins \
                         nav2_bringup \
                         nav2_system_tests \
                         nav2_minimal_tb3_sim \
                         nav2_minimal_tb4_description \
                         nav2_minimal_tb4_sim \
                         navigation2 \
         $COLCON_BUILD_ARGS; \
    else \
      mkdir -p /root/nav2_ws/install; \
    fi


# ==============================================================================
# TARGET: devel
# ==============================================================================
# Development image with full workspace for active Nav2 development
# Includes: src/, build/, log/, install/ directories
FROM osrf/ros:${ROS_DISTRO}-desktop-full AS devel
ARG ROS_DISTRO

# Copy ROS dependencies from builder to ensure ABI compatibility
COPY --from=builder-full /opt/ros/${ROS_DISTRO} /opt/ros/${ROS_DISTRO}

WORKDIR /root/nav2_ws
COPY --from=builder-full /root/nav2_ws /root/nav2_ws

# Configure workspace to auto-source on container start
RUN echo 'source "/root/nav2_ws/install/setup.bash"' >> /ros_entrypoint.sh


# ==============================================================================
# TARGET: standard
# ==============================================================================
# Testing and simulation image with compiled binaries only
# Includes: install/ directory (no src/build/log)
FROM osrf/ros:${ROS_DISTRO}-desktop-full AS standard
ARG ROS_DISTRO

# Copy ROS dependencies from builder to ensure ABI compatibility
COPY --from=builder-full /opt/ros/${ROS_DISTRO} /opt/ros/${ROS_DISTRO}

WORKDIR /root/nav2_ws
COPY --from=builder-full /root/nav2_ws/install /root/nav2_ws/install

# Configure workspace to auto-source on container start
RUN echo 'source "/root/nav2_ws/install/setup.bash"' >> /ros_entrypoint.sh


# ==============================================================================
# TARGET: production
# ==============================================================================
# Headless runtime image for robot deployment
# Includes: Core navigation packages only (no GUI/simulation)
FROM ros:${ROS_DISTRO}-ros-base AS production
ARG ROS_DISTRO

WORKDIR /root/nav2_ws

# Copy compiled core navigation packages from production builder
COPY --from=builder-production /root/nav2_ws/install /root/nav2_ws/install

# Copy source temporarily for rosdep dependency resolution
COPY --from=builder-production /root/nav2_ws/src /root/nav2_ws/src

# Remove skipped packages from source to prevent installing their dependencies
RUN cd /root/nav2_ws/src/navigation2 && \
    rm -rf nav2_rviz_plugins nav2_bringup nav2_system_tests \
           nav2_minimal_tb3_sim nav2_minimal_tb4_description nav2_minimal_tb4_sim navigation2

# Install runtime dependencies for core navigation packages only
# Explicitly skip GUI, Gazebo, and simulation dependencies
RUN apt update && \
    if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then \
      rosdep init; \
    fi && rosdep update && \
    rosdep install -y --ignore-src --from-paths src -r --rosdistro ${ROS_DISTRO} \
    --skip-keys "rviz2 \
                 gazebo_ros_pkgs \
                 ros_gz \
                 ros_gz_sim \
                 ros_gz_bridge \
                 turtlebot3_gazebo \
                 slam_toolbox \
                 nav2_rviz_plugins \
                 nav2_bringup \
                 nav2_system_tests \
                 nav2_minimal_tb3_sim \
                 nav2_minimal_tb4_description \
                 nav2_minimal_tb4_sim \
                 libqt5-core libqt5gui5 libqt5widgets5 \
                 libgl1-mesa-dri mesa-utils x11-common" \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/doc /usr/share/man /root/.ros \
    && rm -rf /root/nav2_ws/src

# Configure workspace to auto-source on container start
RUN echo 'source "/root/nav2_ws/install/setup.bash"' >> /ros_entrypoint.sh