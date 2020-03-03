cmake_minimum_required(VERSION 3.13)
project(gphoto2)

add_compile_definitions(_C99_SOURCE)
add_compile_definitions(_XOPEN_SOURCE=600)
add_compile_definitions(_GPHOTO2_INTERNAL_CODE)
add_compile_definitions(IOS_BUILD)
add_compile_definitions(CAMLIBS)
add_compile_definitions(IOLIBS)
add_compile_definitions(HAVE_REGEX)

##Replace with syspath
include_directories(/usr/include)

include_directories(libgphoto2_port)
include_directories(libgphoto2)
include_directories(.)

set(SOURCES libgphoto2_port/ptpip/ptpip.c 
            libgphoto2/gphoto2-result.c
       #     camlibs/ptp2/olympus-wrap.c
            libgphoto2/gphoto2-setting.c
            libgphoto2/gphoto2-list.c
            libgphoto2/bayer.c
            libgphoto2/gphoto2-widget.c
            camlibs/ptp2/library.c
            libgphoto2_port/libgphoto2_port/gphoto2-port-result.c
            libgphoto2/gphoto2-file.c   
            libgphoto2_port/libgphoto2_port/gphoto2-port-portability.c
            libgphoto2_port/libgphoto2_port/gphoto2-port.c
            libgphoto2/gphoto2-context.c
            camlibs/ptp2/ptpip.c
            libgphoto2/jpeg.c
            libgphoto2/gamma.c
            camlibs/ptp2/ptp.c
            libgphoto2/gphoto2-filesys.c
            camlibs/ptp2/chdk.c
            libgphoto2_port/libgphoto2_port/gphoto2-port-info-list.c
            libgphoto2/exif.c
            libgphoto2_port/libgphoto2_port/gphoto2-port-log.c
            libgphoto2_port/libgphoto2_port/gphoto2-port-version.c
            libgphoto2/gphoto2-camera.c
            camlibs/ptp2/config.c
            libgphoto2/gphoto2-version.c
            libgphoto2/gphoto2-abilities-list.c

)

add_library(gphoto2 SHARED ${SOURCES})