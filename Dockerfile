ARG USER=rosuser
ARG UID
ARG GID
ARG ROS_DISTRO=jazzy
ARG OS_CODE_NAME=noble


FROM ros:${ROS_DISTRO}-ros-core-${OS_CODE_NAME} AS ros2_builder_packager_base

ARG USER
ARG UID
ARG GID
ARG ROS_DISTRO
ENV ROS_DISTRO=${ROS_DISTRO}
ARG OS_CODE_NAME
ENV OS_CODE_NAME=${OS_CODE_NAME}

RUN if id ubuntu &>/dev/null; then userdel -r ubuntu; fi && \
    if getent group ubuntu &>/dev/null; then groupdel ubuntu; fi || true


ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y tzdata && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

ARG REQUIREMENTS_FILE=requirements.${OS_CODE_NAME}.system
COPY files/${REQUIREMENTS_FILE} .
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    apt-get install --no-install-recommends -y $(sed '/^#/d' ${REQUIREMENTS_FILE} | sed '/^$/d') && \
    rm -rf /var/lib/apt/lists/*

RUN rm -rf /home/ubuntu
RUN useradd --create-home ${USER}
RUN cat /etc/passwd && usermod -u ${UID} ${USER} && groupmod -g ${GID} ${USER}
RUN chown -R ${UID}:${GID} /home/${USER} || true


USER rosuser
WORKDIR /ros2_ws

#ENV ROSDEP_SOURCES_LIST=/ros2_ws/.ros/rosdep/sources.list.d
#ENV ROSDEP_YAML_CACHE=/ros2_ws/.ros/rosdep/rosdep.yaml
#ENV ROS_INDEX_DIR=/ros2_ws/.ros
#ENV ROSDEP_CACHE=/ros2_ws/.ros/rosdep_cache
#ENV ROSDEP_SOURCE_PATH=/ros2_ws/.ros/rosdep_cache
#RUN mkdir -p $ROSDEP_SOURCES_LIST $ROSDEP_CACHE
#RUN curl https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/sources.list.d/20-default.list -o $ROSDEP_SOURCES_LIST/20-default.list


USER root

FROM ros2_builder_packager_base AS ros2_builder_packager

ARG ROS_DISTRO
ENV ROS_DISTRO=${ROS_DISTRO}
ARG OS_CODE_NAME
ENV OS_CODE_NAME=${OS_CODE_NAME}

USER rosuser
COPY --chown=rosuser:rosuser files/Makefile /ros2_ws/Makefile
COPY --chown=rosuser:rosuser files/ros2_debian_packager.sh /ros2_ws/ros2_debian_packager.sh

#RUN rosdep init && rosdep update && rosdep install --from-paths src --ignore-src -r -y

#RUN mkdir -p /ros2_ws/.ros && \
#    curl -o $ROS_INDEX_DIR/index-v4.yaml https://raw.githubusercontent.com/ros/rosdistro/master/index-v4.yaml

#ENV ROS_INDEX_URL=file:///ros2_ws/.ros/index-v4.yaml

#RUN mkdir -p /ros2_ws/log /ros2_ws/build

WORKDIR /ros2_ws

# Set the entrypoint to keep the container running
CMD ["/bin/bash"]

