#include <gphoto2/gphoto2.h>
#include <gphoto2/gphoto2-camera.h>
#include <gphoto2/gphoto2-list.h>
#include <gphoto2/gphoto2-version.h>
#include <gphoto2/gphoto2-setting.h>
#include <gphoto2/gphoto2-file.h>
#include <gphoto2/gphoto2-filesys.h>
#include <gphoto2/gphoto2-context.h>
#include <gphoto2/gphoto2-abilities-list.h>

#include <gphoto2/gphoto2-port.h>
#include <gphoto2/gphoto2-port-info-list.h>
#include <gphoto2/gphoto2-port-log.h>
#include <gphoto2/gphoto2-port-portability.h>
#include <gphoto2/gphoto2-port-result.h>
#include <gphoto2/gphoto2-port-version.h>

#include <stdio.h>

unsigned long stdc_version = __STDC_VERSION__;

int main()
{
  printf("stdc_version = %lu\n", stdc_version);
  return 0;
}
