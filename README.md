# ROS2 Packager
This is a packaging tool for ROS2 that accepts arbitrary ROS2 packages and 
outputs a debian .deb archive for each package.

## Background
The ROS2 Packager is a Docker project for compiling ROS2 nodes and generating
debian `.deb` APT packages for the nodes.


## Prerequisites
The following tools are required to use the ROS2 Packager:
- GNU Make
- Docker

## Getting Started: Building the demo hello world package
1. Clone the repository
2. invoke make:
```
make
```
This will build the build the base docker context/images, compile the 
`ros2_hello_world` ROS package, package the artifacts into a debian package
management system "APT" package for x86_64 and arm64 architectures.
The output will be in `./build`

## Getting Started: Building custom packages
1. Clone the project
2. Place ROS packages that you wish to generate `.deb` archives/packages for in 
`src`
3. Add a `requirements.system` file to the package directory (see: 
[requirements.system](src/ros2_hello_world/requirements.system) for an example).
4. invoke make on the project:
```
make
```

