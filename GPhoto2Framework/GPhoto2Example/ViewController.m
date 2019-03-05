//
//  ViewController.m
//  GPhoto2Example
//
//  Created by Hendrik Holtmann on 21.10.18.
//  Copyright © 2018 Hendrik Holtmann. All rights reserved.
//

#import "ViewController.h"
#import "ptp.h"
#import "ptp-private.h"
@import gphoto2;

@interface ViewController ()

@end

@implementation ViewController

static int
_lookup_widget(CameraWidget*widget, const char *key, CameraWidget **child) {
    int ret;
    ret = gp_widget_get_child_by_name (widget, key, child);
    if (ret < GP_OK)
        ret = gp_widget_get_child_by_label (widget, key, child);
    return ret;
}

int
get_config_value_string (Camera *camera, const char *key, char **str, GPContext *context) {
    CameraWidget        *widget = NULL, *child = NULL;
    CameraWidgetType    type;
    int            ret;
    char            *val;
    
    ret = gp_camera_get_config (camera, &widget, context);
    if (ret < GP_OK) {
        fprintf (stderr, "camera_get_config failed: %d\n", ret);
        return ret;
    }
    ret = _lookup_widget (widget, key, &child);
    if (ret < GP_OK) {
        fprintf (stderr, "lookup widget failed: %d\n", ret);
        goto out;
    }
    
    /* This type check is optional, if you know what type the label
     * has already. If you are not sure, better check. */
    ret = gp_widget_get_type (child, &type);
    if (ret < GP_OK) {
        fprintf (stderr, "widget get type failed: %d\n", ret);
        goto out;
    }
    switch (type) {
        case GP_WIDGET_MENU:
        case GP_WIDGET_RADIO:
        case GP_WIDGET_TEXT:
            break;
        default:
            fprintf (stderr, "widget has bad type %d\n", type);
            ret = GP_ERROR_BAD_PARAMETERS;
            goto out;
    }
    
    /* This is the actual query call. Note that we just
     * a pointer reference to the string, not a copy... */
    ret = gp_widget_get_value (child, &val);
    if (ret < GP_OK) {
        fprintf (stderr, "could not query widget value: %d\n", ret);
        goto out;
    }
    /* Create a new copy for our caller. */
    *str = strdup (val);
    out:
    gp_widget_free (widget);
    return ret;
}

static void
ctx_error_func (GPContext *context, const char *str, void *data)
{
    fprintf  (stderr, "\n*** Contexterror ***              \n%s\n",str);
    fflush   (stderr);
}

static void
ctx_status_func (GPContext *context, const char *str, void *data)
{
    fprintf  (stderr, "%s\n", str);
    fflush   (stderr);
}

GPContext* sample_create_context() {
    GPContext *context;
    
    /* This is the mandatory part */
    context = gp_context_new();
    
    /* All the parts below are optional! */
    gp_context_set_error_func (context, ctx_error_func, NULL);
    gp_context_set_status_func (context, ctx_status_func, NULL);
    
    /* also:
     gp_context_set_cancel_func    (p->context, ctx_cancel_func,  p);
     gp_context_set_message_func   (p->context, ctx_message_func, p);
     if (isatty (STDOUT_FILENO))
     gp_context_set_progress_funcs (p->context,
     ctx_progress_start_func, ctx_progress_update_func,
     ctx_progress_stop_func, p);
     */
    return context;
}

static void errordumper(GPLogLevel level, const char *domain, const char *str,
                        void *data) {
    fprintf(stdout, "%s\n", str);
}

static void logdumper(GPLogLevel level, const char *domain, const char *str,
                        void *data) {
    fprintf(stdout, "%s\n", str);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self connectCamera];
}
static void
capture_to_memory(Camera *camera, GPContext *context, const char **ptr, unsigned long int *size) {
    int retval;
    CameraFile *file;
    CameraFilePath camera_file_path;
    
    printf("Capturing.\n");
    
    /* NOP: This gets overridden in the library to /capt0000.jpg */
    strcpy(camera_file_path.folder, "/");
    strcpy(camera_file_path.name, "foo.jpg");
    
    retval = gp_camera_capture(camera, GP_CAPTURE_IMAGE, &camera_file_path, context);
    printf("  Retval: %d\n", retval);
    
    printf("Pathname on the camera: %s/%s\n", camera_file_path.folder, camera_file_path.name);
    
    retval = gp_file_new(&file);
    printf("  Retval: %d\n", retval);
    retval = gp_camera_file_get(camera, camera_file_path.folder, camera_file_path.name,
                                GP_FILE_TYPE_NORMAL, file, context);
    printf("  Retval: %d\n", retval);
    
    gp_file_get_data_and_size (file, ptr, size);
    
    printf("Deleting.\n");
    retval = gp_camera_file_delete(camera, camera_file_path.folder, camera_file_path.name,
                                   context);
    printf("  Retval: %d\n", retval);
    /*gp_file_free(file); */
}

-(void)connectCamera
{
    Camera        *camera;
    GPContext *context;
    int        ret,indexCamera,indexPort;
    CameraAbilitiesList    *abilities;
    CameraAbilities    a;
    
    GPPortInfoList        *portinfolist = NULL;
    GPPortInfo    pi;
    
    gp_log_add_func(GP_LOG_ERROR, errordumper, NULL);
    gp_log_add_func(GP_LOG_DEBUG, logdumper, NULL);
    
    context = sample_create_context();
    
    gp_camera_new (&camera);
    
    gp_abilities_list_new (&abilities);
    ret = gp_abilities_list_load (abilities, context);
    indexCamera = gp_abilities_list_lookup_model (abilities, "Canon EOS (WLAN)");
    
    if (indexCamera>=0) {
        gp_abilities_list_get_abilities (abilities, indexCamera, &a);
        gp_camera_set_abilities (camera, a);
    }
    
    
    gp_port_info_list_new (&portinfolist);
    ret = gp_port_info_list_load (portinfolist);
    ret = gp_port_info_list_count (portinfolist);
    indexPort = gp_port_info_list_lookup_path (portinfolist, "ptpip:192.168.2.120");
    if (indexPort>=0) {
        gp_port_info_list_get_info (portinfolist, indexPort, &pi);
        gp_camera_set_port_info (camera, pi);
    }
    
    ret = gp_camera_init (camera, context);
    PTPParams *params = &camera->pl->params;
    params->storageids.Storage = NULL;

    /*
    CameraText    text;
    ret = gp_camera_get_summary (camera, &text, context);
    if (ret < GP_OK) {
        printf("Camera failed retrieving summary.\n");
    }
    printf("Summary:\n%s\n", text.text);
    */
    
  
    return;

    
    char        *owner;
    ret = get_config_value_string (camera, "Artist", &owner, context);
    if (ret < GP_OK) {
        printf ("Could not query owner.\n");
    }
    printf("Current owner: %s\n", owner);
    
    return;

    

    CameraList *list;
     ret = gp_list_new (&list);
    ret = gp_camera_folder_list_folders(camera, "/store_00020001", list, context);

    
    char    *data;
    unsigned long size;
    capture_to_memory(camera, context, (const char**)&data, &size);

    [[NSData dataWithBytes:data length:size] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"canon.jpg"] atomically:NO];
    
    /*
    gp_camera_exit (camera, context);
    gp_camera_free (camera);
*/
    
    if (ret < GP_OK) {
        printf("No camera auto detected.\n");
        gp_camera_free (camera);
    }
    
}


@end
