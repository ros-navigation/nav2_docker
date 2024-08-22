ARG ROS_DISTRO=rolling
FROM osrf/ros:${ROS_DISTRO}-desktop-full

RUN apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --no-install-suggests \
  ros-dev-tools \
  wget

# Obtain the Nav2 dependencies to build development or distribution workspace against
WORKDIR /root/nav2_ws
RUN mkdir -p ~/nav2_ws/src
ARG VERSION_TAG=latest
RUN if [ "${ROS_DISTRO}" = "rolling" ]; then \
      git clone https://github.com/ros-planning/navigation2.git --branch main ./src/navigation2; \
    elif [ "${VERSION_TAG}" = "latest" ]; then \
      git clone https://github.com/ros-planning/navigation2.git --branch ${ROS_DISTRO} ./src/navigation2; \
    else \
      git clone https://github.com/ros-planning/navigation2.git --branch ${VERSION_TAG} ./src/navigation2; \
    fi

RUN rm /etc/ros/rosdep/sources.list.d/20-default.list && rosdep init
RUN apt update && apt upgrade -y \
    && rosdep update \
    && rosdep install -y --ignore-src --from-paths src -r --skip-keys "slam_toolbox turtlebot3_gazebo"

# Get Gazebo Simulator
RUN apt install cppzmq-dev ros-${ROS_DISTRO}-ros-gz -y --no-install-recommends --no-install-suggests || true

# For distribution of Nav2
ARG BUILD=true
RUN if [ "${BUILD}" = "true" ]; then \
      . /opt/ros/${ROS_DISTRO}/setup.sh && colcon build; \
    fi

WORKDIR /root/nav2_ws
