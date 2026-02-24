ARG ROS_DISTRO=rolling

# --- STAGE 1: Builder ---
FROM osrf/ros:${ROS_DISTRO}-desktop-full AS builder

# Re-including the ROS 2 key fix comments exactly as per source
# # Fix ROS 2 keys
# RUN rm /etc/apt/sources.list.d/ros2-latest.list \
#   && rm /usr/share/keyrings/ros2-latest-archive-keyring.gpg

# RUN apt-get update \
#   && apt-get install -y ca-certificates curl

# RUN export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') ;\
#     curl -L -s -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" \
#     && apt-get update \
#     && apt-get install /tmp/ros2-apt-source.deb \
#     && rm -f /tmp/ros2-apt-source.deb

RUN apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --no-install-suggests \
  ros-dev-tools \
  wget

# Obtain the Nav2 dependencies to build development or distribution workspace against
WORKDIR /root/nav2_ws
RUN mkdir -p /root/nav2_ws/src

ARG VERSION_TAG=latest
RUN if [ "${ROS_DISTRO}" = "rolling" ]; then \
      git clone https://github.com/ros-planning/navigation2.git --branch main ./src/navigation2 && \
      vcs import ./src/ < ./src/navigation2/tools/underlay.repos; \
    elif [ "${VERSION_TAG}" = "latest" ]; then \
      git clone https://github.com/ros-planning/navigation2.git --branch ${ROS_DISTRO} ./src/navigation2; \
    else \
      git clone https://github.com/ros-planning/navigation2.git --branch ${VERSION_TAG} ./src/navigation2; \
    fi

RUN rm -f /etc/ros/rosdep/sources.list.d/20-default.list && rosdep init

# Note: apt upgrade -y is needed here for Rolling to prevent ABI mismatches
RUN apt update && apt upgrade -y \
    && rosdep update \
    && rosdep install -y --ignore-src --from-paths src -r --skip-keys "slam_toolbox turtlebot3_gazebo" \
    && rm -rf /var/lib/apt/lists/*

# For distribution of Nav2
ARG BUILD=true
ARG COLCON_BUILD_ARGS=""
RUN if [ "${BUILD}" = "true" ]; then \
      . /opt/ros/${ROS_DISTRO}/setup.sh && colcon build $COLCON_BUILD_ARGS; \
    fi

# --- STAGE 2: Runtime ---
FROM osrf/ros:${ROS_DISTRO}-desktop-full

# Re-install runtime-specific dependencies and Gazebo as per source requirements
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --no-install-suggests \
  cppzmq-dev \
  ros-${ROS_DISTRO}-ros-gz \
  || true && rm -rf /var/lib/apt/lists/*

WORKDIR /root/nav2_ws

# Copy ONLY the install directory from the builder
# This removes src/, build/, and log/ while keeping the final artifacts
COPY --from=builder /root/nav2_ws/install /root/nav2_ws/install

# Update entrypoint to source the Nav2 workspace ONLY if the workspace was actually build
RUN if [ -f /root/nav2_ws/install/setup.bash ]; then \
      sed -i 's|source "/opt/ros/\$ROS_DISTRO/setup.bash"|source "/opt/ros/\$ROS_DISTRO/setup.bash"\nsource "/root/nav2_ws/install/setup.bash"|g' /ros_entrypoint.sh; \
    fi

WORKDIR /root/nav2_ws