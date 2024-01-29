# Intro
Load the standard ISO from Nvidia to the Jetson Nano board.  Then 
use the Dockerfile to create a docker image that installs all
the necessary dependencies to run ROS2 ZED Wrapper.  

I found that ROS2 ZED Wrapper needs Humble but the only Jetson Nano
container I could find would be Ubuntu 18 with ROS2 Humble installed.
From there I was given a hint to use C++11 where the default is C++7.

I also needed to use Python 3.8 to compile ZED ROS2 Wrapper, but I needed
Python 3.6 to build ZED SDK.  So I switch between them.  At the end to run 
the wrapper, because ROS2 used Python 3.6, I have to switch back to Python 3.6 to load the ZED ROS2 Wrapper.

# Build Docker
## Build
```bash
docker build -f Dockerfile .
```

## Rebuild
`--no-cache` will rebuild the Docker image from the beginning.  If you do not include this, it will only build modified or new sections in the docker file.
```bash
docker build -f Dockerfile . --no-cache
```

# Launch Docker
```bash
docker run --runtime nvidia -it --privileged --ipc=host --pid=host --net=host  --gpus all <docker image>
```

`--net=host` allows the ROS2 topics to be seen on the network.
`--gpus all` allows the docker file have access to the GPU.
`-it` runs the docker container in the terminal
`-e ZED_CAMERA_MODEL="<camera_model>` will set the camera model to use to automatically run the wrapper.  Options are `'zed'`, `'zedm'`, `'zed2'`, `'zed2i'`, `'zedx'`, `'zedxm'`.  


# Launch ZED ROS2 Wrapper
```bash
ros2 launch zed_wrapper zed_camera.launch.py camera_model:=<camera_model>
ros2 launch zed_wrapper zed_camera.launch.py camera_model:=zed
ros2 launch zed_wrapper zed_camera.launch.py camera_model:=zedm
```


# Build Error
I assume we can ignore these errors.  The wrapper loads fine.
```bash
--- stderr: zed_wrapper
In file included from /root/ros2_ws/install/zed_components/include/zed_components/zed_camera_component.hpp:19,
                 from /root/ros2_ws/src/zed-ros2-wrapper/zed_wrapper/src/zed_wrapper.cpp:17:
/usr/local/zed/include/sl/Fusion.hpp:68:64: note: ‘#pragma message: ~ FUSION SDK is distributed in Early Access ~’
   68 | #pragma message("~ FUSION SDK is distributed in Early Access ~")
      |                                                                ^
---
...

Summary: 45 packages finished [24min 49s]
  2 packages had stderr output: zed_components zed_wrapper
```

