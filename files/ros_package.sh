#!/bin/bash

set -e

if [ ! -d "/ros2_ws" ]; then
    echo "ROS 2 workspace directory /ros2_ws does not exist. Exiting."
    exit 1
fi

source /opt/ros/iron/setup.bash

cd /ros2_ws

echo "Getting a list of installed packages..."
packages=$(colcon list | cut -f1)

if [ -z "$packages" ]; then
    echo "No installed ROS 2 packages found."
    exit 1
fi

for pkg in $packages; do
    pkg_path="/ros2_ws/install/share/$pkg"
    
    if [ -d "$pkg_path" ]; then
        echo "Generating Debian package for $pkg..."
        bloom-generate rosdebian --os-name ubuntu --ros-distro iron "$pkg_path"
    else
        echo "Package directory for $pkg not found in $pkg_path."
    fi
done

echo "Generating Debian packages..."
for pkg in $packages; do
    echo "Generating Debian package for $pkg..."
    bloom-generate rosdebian --os-name ubuntu --ros-distro iron "$pkg"
done

echo "Moving generated Debian packages..."
mkdir -p debian_packages
mv *.deb debian_packages/ || echo "No .deb files generated."

echo "All operations completed successfully."

