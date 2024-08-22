# nav2_docker

Nav2 distributed docker containers for active ROS 2 distributions for development and deployment. For a guide for using Docker for development, see [our tutorial at docs.nav2.org](https://docs.nav2.org/tutorials/docs/docker_dev.html).

Currently supported distributions:
- Humble
- Iron
- Jazzy
- Rolling

## How to Use Provided Containers

Pull, url, versions TODO

Add link here to the containers so they dont have to search TODO 

## Building for Local Use

Build the docker image via:

```
sudo docker build -t nav2_dev -f Dockerfile .
```

If you do NOT want to build Nav2 for distribution with the container (setup for builds with dependencies only), add `--build-arg BUILD=false`. This will not trigger a build of Nav2 along with the image.

Occasionally, may need to update the base and rebuild when it diverges significantly.

```
sudo docker pull osrf/ros:${ROS_DISTRO}-desktop-full
sudo docker build -t nav2_dev -f Dockerfile .
```

## Local Development

In an example workspace, `jazzy_ws`, execute the following:

```
sudo docker run -it --net=host --privileged -v .:/root/jazzy_ws --volume="${XAUTHORITY}:/root/.Xauthority" --env="DISPLAY=$DISPLAY" -v="/tmp/.gazebo/:/root/.gazebo/" -v /tmp/.X11-unix:/tmp/.X11-unix:rw --shm-size=1000mb nav2_dev
```

This will mount your workspace, `jazzy_ws` along with items needed for gazebo, rviz, and communicating with your development machine outside of Docker. You can now navigate to the workspace and build it. The build artifacts will be put into your external workspace to be used again in later instances of the Docker image so that progress is not lost between containers.
