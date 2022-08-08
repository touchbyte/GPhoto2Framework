# GPhoto2Framework
## libgphoto2/libgphoto2_port wrapped as iOS dynamic framework
* Xcode 10 project
* compiled in ptp/ip iolib-driver and ptp2 camlib-driver
* supports iOS 8 and higher
* port and camera model need to be specified before calling gp_camera_init (no autodection available), Tested with Canon EOS Wifi Cameras
* all external dependencies, which are not useful/supported on iOS, removed (libusb, ltdl)
* Example project included

## Currently used in:
* [PhotoSync 4.0 and higher for iOS](https://www.photosync-app.com)

For any questions/feedback, please contact holtmann@touchbyte.com

![Screenshot Example](https://download.photosync-app.com/images/example_libgphoto2.png)
