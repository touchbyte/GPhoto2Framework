cmake_minimum_required(VERSION 3.10)
project(gphoto2)

add_definitions(-D_C99_SOURCE)
add_definitions(-D_XOPEN_SOURCE=600)
add_definitions(-D_GPHOTO2_INTERNAL_CODE)
add_definitions(-DIOS_BUILD)
add_definitions(-DCAMLIBS)
add_definitions(-DIOLIBS)
add_definitions(-DHAVE_REGEX)

#NDK specific
add_definitions(-DANDROID_BUILD)
add_definitions(-DHAVE_SYS_USER_H=1)
add_definitions(-DHAVE_SYS_VFS_H=1)
add_definitions(-DHAVE_SYS_STATFS_H)
add_definitions(-DHAVE_INET_ATON=1)
add_definitions(-DHAVE_INTTYPES_H=1)
add_definitions(-DHAVE_LANGINFO_H=1)
add_definitions(-DHAVE_MEMORY_H=1)


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
            jni/gphoto-jni.c

)

set( DEPENDENCIES
     android
     log
)

add_library(gphoto2 SHARED ${SOURCES})

target_link_libraries( gphoto2
${DEPENDENCIES}
)