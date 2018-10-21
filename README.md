# GPhoto2Framework
libgphoto2/libgphoto2_port wrapped as iOS dynamic framework
* Xcode 10 project
* compiled in ptp/ip port driver and ptp2 camlib
* port and camera model need to be specified on before gp_camera_init (no autodection)
* all external dependencies, which are not useful on iOS, removed (libusb, ltdl)
* supports iOS 8 and higher
