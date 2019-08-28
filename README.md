# GPhoto2Framework
libgphoto2/libgphoto2_port wrapped as iOS dynamic framework
* Xcode 10 project, supports iOS 8 and higher
* compiled in ptp/ip iolib-driver and ptp2 camlib-driver
* supports iOS 8 and higher
* port and camera model need to be specified before calling gp_camera_init (no autodection available), Tested with Canon EOS Wifi Cameras
* all external dependencies, which are not useful/supported on iOS, removed (libusb, ltdl)

For any questions/feedback, please contact holtmann@touchbyte.com
