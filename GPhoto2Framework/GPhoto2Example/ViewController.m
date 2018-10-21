//
//  ViewController.m
//  GPhoto2Example
//
//  Created by Hendrik Holtmann on 21.10.18.
//  Copyright © 2018 Hendrik Holtmann. All rights reserved.
//

#import "ViewController.h"
@import gphoto2;

@interface ViewController ()

@end

@implementation ViewController

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
    indexCamera = gp_abilities_list_lookup_model (abilities, "Canon EOS 6D");
    
    if (indexCamera>=0) {
        gp_abilities_list_get_abilities (abilities, indexCamera, &a);
        gp_camera_set_abilities (camera, a);
    }
    
    gp_port_info_list_new (&portinfolist);
    ret = gp_port_info_list_load (portinfolist);
    ret = gp_port_info_list_count (portinfolist);
    indexPort = gp_port_info_list_lookup_path (portinfolist, "ptpip:192.168.2.101");
    if (indexPort>=0) {
        gp_port_info_list_get_info (portinfolist, indexPort, &pi);
        gp_camera_set_port_info (camera, pi);
    }
    
    ret = gp_camera_init (camera, context);
    
    
    if (ret < GP_OK) {
        printf("No camera auto detected.\n");
        gp_camera_free (camera);
    }
}


@end
