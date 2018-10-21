# GPhoto2Framework
libgphoto2/libgphoto2_port wrapped as iOS dynamic framework
* Xcode 10 project
* compiled in ptp/ip iolib-driver and ptp2 camlib-driver
* port and camera model need to be specified before calling gp_camera_init (no autodection available)
* all external dependencies, which are not useful on iOS, removed (libusb, ltdl)
* supports iOS 8 and higher
