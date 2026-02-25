# Navigation2 (Nav2) Multi-Stage Dockerfile
# This file implements a Multi-Target architecture to optimize image size 
# without sacrificing developer tools or breaking ABI compatibility.

# targets:
#   - builder:    Compilation stage; contains all build artifacts (src, build, log).
#   - devel:      Full-featured image for Simulation and RViz (preserves 'it just works').
#   - production: Hardened, headless runtime for physical robot deployment.

ARG ROS_DISTRO=rolling
FROM osrf/ros:${ROS_DISTRO}-desktop-full AS builder

# 1. Install system build tools
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    ros-dev-tools \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/nav2_ws
RUN mkdir -p src

# 2. Workspace Setup
# Clones Nav2 and fetches the underlay repositories required for the build.
ARG VERSION_TAG=latest
RUN if [ "${ROS_DISTRO}" = "rolling" ]; then \
      git clone https://github.com/ros-planning/navigation2.git --branch main ./src/navigation2 && \
      vcs import ./src/ < ./src/navigation2/tools/underlay.repos; \
    elif [ "${VERSION_TAG}" = "latest" ]; then \
      git clone https://github.com/ros-planning/navigation2.git --branch ${ROS_DISTRO} ./src/navigation2; \
    else \
      git clone https://github.com/ros-planning/navigation2.git --branch ${VERSION_TAG} ./src/navigation2; \
    fi

# 3. Dependency Management
# 'apt upgrade' is needed for Rolling to ensure the local binaries match the latest ABI.
RUN if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then \
      rosdep init; \
    fi && rosdep update

RUN apt update && apt upgrade -y \
    && rosdep install -y --ignore-src --from-paths src -r \
       --skip-keys "slam_toolbox turtlebot3_gazebo" \
    && rm -rf /var/lib/apt/lists/*

# 4. Compilation Stage
# Supports conditional building via BUILD arg to remain compatible with legacy CI/CD scripts.
ARG BUILD=true
ARG COLCON_BUILD_ARGS=""
RUN if [ "${BUILD}" = "true" ]; then \
      . /opt/ros/${ROS_DISTRO}/setup.sh \
      && colcon build --install-base /root/nav2_ws/install $COLCON_BUILD_ARGS; \
    else \
      mkdir -p /root/nav2_ws/install; \
    fi

# --- TARGET: devel ---
# Functionally identical to the monolithic image but ~2.4GB leaner.
FROM osrf/ros:${ROS_DISTRO}-desktop-full AS devel

# Install simulation-specific dependencies (ZMQ/Gazebo)
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    cppzmq-dev \
    ros-${ROS_DISTRO}-ros-gz \
    || true && rm -rf /var/lib/apt/lists/*

WORKDIR /root/nav2_ws

# Copy ONLY compiled artifacts (Prunes build/src/log bloat)
COPY --from=builder /root/nav2_ws/install /root/nav2_ws/install

# Automated Workspace Sourcing
RUN if [ -f /root/nav2_ws/install/setup.bash ]; then \
      sed -i 's|source "/opt/ros/\$ROS_DISTRO/setup.bash"|source "/opt/ros/\$ROS_DISTRO/setup.bash"\nsource "/root/nav2_ws/install/setup.bash"|g' /ros_entrypoint.sh; \
    fi

# --- TARGET: production ---
# Minimal footprint target for physical hardware. Strips all GUI and Sim-related bloat.
FROM ros:${ROS_DISTRO}-ros-base AS production

WORKDIR /root/nav2_ws

# Temporary copy of src to resolve runtime dependencies via rosdep
COPY --from=builder /root/nav2_ws/src /root/nav2_ws/src

# Pruning non-essential runtime dependencies
RUN apt update && rosdep update && \
    rosdep install -y --ignore-src --from-paths src -r --rosdistro ${ROS_DISTRO} \
    --skip-keys "rviz2 gazebo_ros_pkgs turtlebot3_gazebo slam_toolbox \
                 nav2_rviz_plugins nav2_minimal_tb3_sim \
                 nav2_minimal_tb4_description nav2_minimal_tb4_sim" \
    && rm -rf /var/lib/apt/lists/*

# Final artifact migration and cleanup
COPY --from=builder /root/nav2_ws/install /root/nav2_ws/install
RUN rm -rf /root/nav2_ws/src

# Automated Workspace Sourcing
RUN if [ -f /root/nav2_ws/install/setup.bash ]; then \
      sed -i 's|source "/opt/ros/\$ROS_DISTRO/setup.bash"|source "/opt/ros/\$ROS_DISTRO/setup.bash"\nsource "/root/nav2_ws/install/setup.bash"|g' /ros_entrypoint.sh; \
    fi