#!/usr/bin/env bash

set -euo pipefail
#set -euxo pipefail #debug mode

echoerr (){ printf "%s" "$@" >&2;}
exiterr (){ printf "%s\n" "$@" >&2; exit 1;}

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ -z "$ROS_DISTRO" ]]; then
    exiterr "ERROR: The environmental variable ROS_DISTRO is not set."
fi

if [[ -z "$OS_CODE_NAME" ]]; then
    exiterr "ERROR: The environmental variable OS_CODE_NAME is not set."
fi


ros2_workspace=/ros2_ws

#sudo apt-get update
#sudo apt-get install -y build-essential cmake python3 python3-pip python3-setuptools debhelper dh-make
#pip3 install bloom


setup_local_rosdep() {
    export ROSDEP_PATH=${SCRIPT_DIRECTORY}/.ros/rosdep
    mkdir -p "${ROSDEP_PATH}/sources.list.d"

    if [[ ! -f "${ROSDEP_PATH}/sources.list.d/20-default.list" ]]; then
        wget https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/sources.list.d/20-default.list -P "${ROSDEP_PATH}/sources.list.d"
    else
        echo "20-default.list already exists, skipping download."
    fi

    export ROSDEP_SOURCE_PATH="${ROSDEP_PATH}/sources.list.d"
    export ROSDEP_DATABASE_PATH="${ROSDEP_PATH}/db"

    rosdep update --rosdistro=${ROS_DISTRO}
}


export ROSDEP_DB_PATH=${SCRIPT_DIRECTORY}/.ros/rosdep

build_package(){
    local package_name="${1}"
    local ros2_workspace="${2}"
    cd ${ros2_workspace}
    colcon build --parallel-workers $(nproc) --packages-select ${package_name}
}

generate_debian_control_file(){
    local package_directory="${1}"
    local ros2_workspace="${2}"
    cd "${ros2_workspace}"
    package_directory=$(realpath "${package_directory}")

    if [ ! -f "${package_directory}/LICENSE" ]; then
        touch "${package_directory}/LICENSE"
    fi
cd $package_directory
bloom-generate rosdebian --os-name ubuntu --os-version $OS_CODE_NAME --ros-distro $ROS_DISTRO
cd $package_directory
mkdir -p debian
cat <<EOF > debian/control
Source: ${debian_package_name}
Section: misc
Priority: optional
Maintainer: Your Name <your.email@example.com>
Build-Depends: debhelper (>= 9), cmake, python3, python3-setuptools
Standards-Version: 3.9.6

Package: ${debian_package_name}
Architecture: any
Depends: \${shlibs:Depends}, \${misc:Depends}
Description: ROS 2 package for Hello World example
 This package contains a simple Hello World node for ROS 2 $ROS_DISTRO.
EOF

cat <<EOF > debian/changelog
${debian_package_name} (0.0.0-1) unstable; urgency=low

  * Initial release

 -- Your Name <your.email@example.com>  $(date -R)
EOF

echo "10" > debian/compat

cat <<EOF > debian/rules
#!/usr/bin/make -f

#export DH_VERBOSE=1

%:
	dh \$@

override_dh_auto_configure:
	colcon build --merge-install --install-base debian/$package_name

override_dh_auto_build:
	colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

override_dh_auto_install:
	colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release
	dh_install

override_dh_auto_test:
	echo "No test step needed for this package."
EOF

chmod +x debian/rules
}

generate_debian_package() {

    local package_directory="${1}"
    local ros2_workspace="${2}"

    cd "$package_directory" || exit 1
    generate_debian_control_file "${package_directory}" "${ros2_workspace}"
    
    if [ ! -f debian/rules ]; then
        echo "Error: debian/rules file not found. Exiting."
        exit 1
    fi

    #fakeroot debian/rules binary || { echo "Error: Binary package creation failed"; exit 1; }

    if [ -f "${ROSDEP_DB_PATH}/sources.list.d/20-default.list" ]; then
        rm -rf "${ROSDEP_DB_PATH}/sources.list.d/20-default.list"
    fi
    
    fakeroot rosdep init || true
    # || { echo "Error: rosdep init failed"; exit 1; }

    bloom-generate rosdebian
    fakeroot debian/rules binary

    DEB_PACKAGE=$(ls ../*.deb | head -n 1)

    if [ -z "$DEB_PACKAGE" ]; then
        echo "Error: No .deb package found"
        exit 1
    fi

    BUILD_DIR="$ros2_workspace/build/$package_name"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$output_directory"

    mv "$DEB_PACKAGE" "$output_directory" || { echo "Error: Failed to move .deb package"; exit 1; }

    if [ -f "$output_directory/$(basename "$DEB_PACKAGE")" ]; then
        echo "Package created successfully at $BUILD_DIR/$(basename "$DEB_PACKAGE")"
    else
        echo "Package creation failed"
    fi
    rm -rf "${package_directory}/debian"
}

setup_local_rosdep


for package_xml in $(find src -name "package.xml"); do
    parent_dir=$(dirname "$package_xml")
    package_name=$(basename "$parent_dir")
    #generate_debian_package
    ros_package_name="${package_name}"
    debian_package_name="$(echo "$package_name" | sed 's/_/-/g')"
    debian_package_name=ros-$ROS_DISTRO-$debian_package_name
    debian_package_file="$(echo "$package_name" | sed 's/_/-/g')"
    output_directory="${ros2_workspace}/build"
    package_directory="${parent_dir}"


    echo "  Package name: ${package_name}"
    echo "  ROS package name: ${ros_package_name}"
    echo "  Debian package name: ${debian_package_name}"
    echo "  Package directory: ${package_directory}"
    echo "  ROS2 workspace directory: ${ros2_workspace}"
    echo "  output directoy: ${output_directory}"
    echo "  USER: $(whoami)"
    echo "  user id(UID): $(id -u)"
    echo "  group id(GID): $(id -g)"

    mkdir -p "${output_directory}"
    build_package "${package_name}" "${ros2_workspace}"
    generate_debian_package "${package_directory}" "${ros2_workspace}"
done

