# nav2_docker

Nav2 distributed docker containers for active ROS 2 distributions for development and deployment. For a guide for using Docker for development, see [our tutorial at docs.nav2.org](https://docs.nav2.org/tutorials/docs/docker_dev.html).

Currently supported distributions:
- Humble
- Iron
- Jazzy
- Rolling

Each distribution has two images that are generated: bleeding edge based on the status of the Nav2 branch associated with the distribution (nightly) and the latest officially released version (ex `1.2.15`).

## How to Use Provided Containers

The images can be found in `Packages` on the right-hand side of the repository [or at this link](https://github.com/ros-navigation/nav2_docker/pkgs/container/nav2_docker). You'll see the images available, such as `jazzy-1.3.1`, `iron-nightly`, and `rolling-nightly`.

These can be pulled from via the following and used for development directly or as the base image of deployments by making it your base image `FROM ros-navigation/nav2_docker:jazzy-1.3.1`.

```
docker pull ghcr.io/ros-navigation/nav2_docker:jazzy-1.3.1
```

## Local Development

In an example workspace, `nav2_ws`, execute the following:

```
sudo docker run -it --net=host --privileged -v .:/root/nav2_ws --volume="${XAUTHORITY}:/root/.Xauthority" --env="DISPLAY=$DISPLAY" -v="/tmp/.gazebo/:/root/.gazebo/" -v /tmp/.X11-unix:/tmp/.X11-unix:rw --shm-size=1000mb ghcr.io/ros-navigation/nav2_docker:jazzy-nightly
```

This will mount your workspace, `nav2_ws` along with items needed for gazebo, rviz, and communicating with your development machine outside of Docker. You can now navigate to the workspace and build it. The build artifacts will be put into your external workspace to be used again in later instances of the Docker image so that progress is not lost between containers.

If you wish to work fully isolated within the container and use the container's workspace to build from, run the following and navigate to `nav2_ws` to work from:

```
sudo docker run -it --net=host --privileged --volume="${XAUTHORITY}:/root/.Xauthority" --env="DISPLAY=$DISPLAY" -v="/tmp/.gazebo/:/root/.gazebo/" -v /tmp/.X11-unix:/tmp/.X11-unix:rw --shm-size=1000mb ghcr.io/ros-navigation/nav2_docker:jazzy-nightly
```


## Building for Local Use

Build the docker image via:

```
sudo docker build -t ros-navigation/nav2_docker:local -f Dockerfile .
```

If you do NOT want to build Nav2 for distribution with the container (setup for builds with dependencies only), add `--build-arg BUILD=false`. This will not trigger a build of Nav2 along with the image.

Occasionally, may need to update the base and rebuild when it diverges significantly.

```
sudo docker pull osrf/ros:${ROS_DISTRO}-desktop-full
sudo docker build -t ros-navigation/nav2_docker:local -f Dockerfile .
```

From that point on, the instructions above for local development use may be followed.
