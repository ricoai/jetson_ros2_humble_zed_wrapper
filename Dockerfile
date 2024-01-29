ARG IMAGE_NAME=dustynv/ros:humble-ros-base-l4t-r32.7.1

FROM ${IMAGE_NAME}

ARG ZED_SDK_MAJOR=4
ARG ZED_SDK_MINOR=0
ARG ZED_SDK_PATCH=7
ARG JETPACK_MAJOR=4
ARG JETPACK_MINOR=6
ARG L4T_MAJOR=32
ARG L4T_MINOR=7

ARG ROS2_DIST=humble       # ROS2 distribution

# ZED ROS2 Wrapper dependencies version
ARG XACRO_VERSION=2.0.8
ARG DIAGNOSTICS_VERSION=3.1.2
ARG AMENT_LINT_VERSION=0.12.4
ARG GEOGRAPHIC_INFO_VERSION=1.0.4
ARG ROBOT_LOCALIZATION_VERSION=3.5.1

ENV DEBIAN_FRONTEND noninteractive


# Disable apt-get warnings
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 42D5A192B819C5DA || true && \
  apt-get update || true && apt-get install -y --no-install-recommends apt-utils dialog && \
  rm -rf /var/lib/apt/lists/*

ENV TZ=Europe/Paris

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \ 
  apt-get update && \
  apt-get install --yes lsb-release wget less udev sudo build-essential cmake python3 python3-dev python3-pip python3-wheel git jq libpq-dev zstd usbutils && \    
  rm -rf /var/lib/apt/lists/*

# Change from GCC 7 to GCC 11
RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
apt install gcc-11 g++-11 -y && \
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 7 \
&& update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 7 \
&& update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 11 \
&& update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 11 \
&& update-alternatives --set gcc "/usr/bin/gcc-11" \
&& update-alternatives --set g++ "/usr/bin/g++-11"

# Install the ZED SDK
#This environment variable is needed to use the streaming features on Jetson inside a container
ENV LOGNAME root
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update -y || true ; apt-get install --no-install-recommends lsb-release wget less zstd udev sudo apt-transport-https -y && \
    echo "# R${L4T_MAJOR_VERSION} (release), REVISION: ${L4T_MINOR_VERSION}.${L4T_PATCH_VERSION}" > /etc/nv_tegra_release ; \
    wget -q --no-check-certificate -O ZED_SDK_Linux.run https://download.stereolabs.com/zedsdk/${ZED_SDK_MAJOR}.${ZED_SDK_MINOR}/l4t${L4T_MAJOR}.${L4T_MINOR}/jetsons && \
    chmod +x ZED_SDK_Linux.run ; ./ZED_SDK_Linux.run silent skip_drivers && \
    rm -rf /usr/local/zed/resources/* \
    rm -rf ZED_SDK_Linux.run && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# ZED Python API
RUN apt-get update -y || true ; apt-get install --no-install-recommends python3 python3-pip python3-dev python3-setuptools build-essential -y && \ 
    wget download.stereolabs.com/zedsdk/pyzed -O /usr/local/zed/get_python_api.py && \
    python3 /usr/local/zed/get_python_api.py && \
    python3 -m pip install cython wheel && \
    python3 -m pip install --upgrade setuptools && \
    python3 -m pip install numpy pyopengl *.whl && \
    rm *.whl ; rm -rf /var/lib/apt/lists/* && apt-get clean

# Install the ZED ROS2 Wrapper
ENV ROS_DISTRO ${ROS2_DIST}

# Copy the sources in the Docker image
WORKDIR /root/ros2_ws/src

# Install missing dependencies
WORKDIR /root/ros2_ws/src
RUN wget https://github.com/ros/xacro/archive/refs/tags/${XACRO_VERSION}.tar.gz -O - | tar -xvz && mv xacro-${XACRO_VERSION} xacro && \
  wget https://github.com/ros/diagnostics/archive/refs/tags/${DIAGNOSTICS_VERSION}.tar.gz -O - | tar -xvz && mv diagnostics-${DIAGNOSTICS_VERSION} diagnostics && \
  wget https://github.com/ament/ament_lint/archive/refs/tags/${AMENT_LINT_VERSION}.tar.gz -O - | tar -xvz && mv ament_lint-${AMENT_LINT_VERSION} ament-lint && \
  wget https://github.com/cra-ros-pkg/robot_localization/archive/refs/tags/${ROBOT_LOCALIZATION_VERSION}.tar.gz -O - | tar -xvz && mv robot_localization-${ROBOT_LOCALIZATION_VERSION} robot-localization && \
  wget https://github.com/ros-geographic-info/geographic_info/archive/refs/tags/${GEOGRAPHIC_INFO_VERSION}.tar.gz -O - | tar -xvz && mv geographic_info-${GEOGRAPHIC_INFO_VERSION} geographic-info && \
  cp -r geographic-info/geographic_msgs/ . && \
  rm -rf geographic-info && \
  git clone https://github.com/ros-drivers/nmea_msgs.git --branch ros2 && \  
  git clone https://github.com/ros/angles.git --branch humble-devel

# Get the ZED ROS2 Wrapper
WORKDIR /root/ros2_ws/src
RUN git clone  --recursive https://github.com/stereolabs/zed-ros2-wrapper.git

# Change to Python 3.8
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
apt-get install python3.8 python3-pip python3.8-dev libpython3.8-dev libpython3.8-dev:arm64 -y && \
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1 && \
python3 -m pip install --upgrade pip && \
python3 -m pip install --upgrade distro pytest argcomplete cmake numpy cython

ENV OPENBLAS_CORETYPE=ARMV8

# Check that all the dependencies are satisfied
WORKDIR /root/ros2_ws
RUN apt-get update -y || true && rosdep update && \
  rosdep install --from-paths src --ignore-src -r -y && \
  rm -rf /var/lib/apt/lists/*

# Install cython
RUN python3 -m pip install --upgrade cython

# Build the dependencies and the ZED ROS2 Wrapper
RUN /bin/bash -c "source /opt/ros/$ROS_DISTRO/install/setup.bash && \
  colcon build --parallel-workers $(nproc) --symlink-install \
  --event-handlers console_direct+ --base-paths src \
  --cmake-args ' -DCMAKE_BUILD_TYPE=Release' \
  ' -DCMAKE_LIBRARY_PATH=/usr/local/cuda/lib64/stubs' \
  ' -DCUDA_CUDART_LIBRARY=/usr/local/cuda/lib64/stubs' \
  ' -DCMAKE_CXX_FLAGS="-Wl,--allow-shlib-undefined"' \
  ' --no-warn-unused-cli' '-Wno-dev' "

WORKDIR /root/ros2_ws

# Move back to Python3.6 since that is what ROS2 Humble was built with
# Last parameter is 2 which is higher than python3.8 earlier
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 2


# Setup environment variables 
COPY ros_entrypoint_jetson.sh /sbin/ros_entrypoint.sh
RUN sudo chmod 755 /sbin/ros_entrypoint.sh

# This symbolic link is needed to use the streaming features on Jetson inside a container
RUN ln -sf /usr/lib/aarch64-linux-gnu/tegra/libv4l2.so.0 /usr/lib/aarch64-linux-gnu/libv4l2.so

ENTRYPOINT ["/sbin/ros_entrypoint.sh"]
CMD ["bash"]