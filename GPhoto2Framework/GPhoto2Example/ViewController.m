//
//  ViewController.m
//  GPhoto2Example
//
//  Created by Hendrik Holtmann on 21.10.18.
//  Copyright © 2019 Hendrik Holtmann. All rights reserved.
//

#import "ViewController.h"
#import "ptp.h"
#import "ptp-private.h"
@import gphoto2;

@interface ViewController ()
{
    Camera        *camera;
    GPContext *context;

}
    @property(nonatomic, assign) BOOL connected;
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
    context = gp_context_new();
    gp_context_set_error_func (context, ctx_error_func, NULL);
    gp_context_set_status_func (context, ctx_status_func, NULL);
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

-(int)connectCamera:(NSString*)cameraIP
{
    int        ret,indexCamera,indexPort;
    CameraAbilitiesList    *abilities;
    CameraAbilities    a;
    
    GPPortInfoList        *portinfolist = NULL;
    GPPortInfo    pi;
    
    NSString *connectionStr = [NSString stringWithFormat:@"ptpip:%@",cameraIP];
    
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
    indexPort = gp_port_info_list_lookup_path (portinfolist, [connectionStr UTF8String]);
    if (indexPort>=0) {
        gp_port_info_list_get_info (portinfolist, indexPort, &pi);
        gp_camera_set_port_info (camera, pi);
    }
    gp_port_info_list_free(portinfolist);
    gp_abilities_list_free(abilities);

    gp_setting_set("ptpip", "hostname", "gphoto-example");
    ret = gp_camera_init (camera, context);
    return ret;
}

-(int)listAlFiles:(const char*)folder foundfile:(int*)foundfile files:(NSMutableArray*)files
{
    int        i, ret;
    CameraList    *list;
    const char    *newfile;
    
    ret = gp_list_new (&list);
    if (ret < GP_OK) {
        NSLog(@"Could not allocate list.\n");
        return ret;
    }
    ret = gp_camera_folder_list_folders (camera, folder, list, context);
    gp_list_sort (list);
    for (i = 0; i < gp_list_count (list); i++) {
        const char *newfolder;
        char *buf;
        int havefile = 0;
        
        gp_list_get_name (list, i, &newfolder);
        if (!strlen(newfolder)) continue;
        buf = malloc (strlen(folder) + 1 + strlen(newfolder) + 1);
        strcpy(buf, folder);
        if (strcmp(folder,"/"))        /* avoid double / */
            strcat(buf, "/");
        strcat(buf, newfolder);
        fprintf(stderr,"newfolder=%s\n", newfolder);
        ret = [self listAlFiles:buf foundfile:&havefile files:files];
        free (buf);
        if (ret != GP_OK) {
            gp_list_free (list);
            NSLog(@"Failed to recursively list folders.\n");
            return ret;
        }
    }
    gp_list_reset (list);
    ret = gp_camera_folder_list_files (camera, folder, list, context);
    if (ret < GP_OK) {
        gp_list_free (list);
        NSLog(@"Could not list files.\n");
        return ret;
    }
    gp_list_sort (list);
    if (gp_list_count (list) <= 0) {
        gp_list_free (list);
        return GP_OK;
    }
    int j;
    for (j = 0; j < gp_list_count (list); j++) {
        ret = gp_list_get_name (list, j, &newfile); /* only entry 0 needed */
        if (ret != GP_OK) {
            NSLog(@"Could not get file info.\n");
        } else {
            NSString *title = [[NSString alloc] initWithUTF8String:newfile];
            NSString *path = [[NSString alloc] initWithUTF8String:folder];
            [files addObject:[path stringByAppendingPathComponent:title]];
        }
    }
    
    if (foundfile) *foundfile = 1;
    gp_list_free (list);
    return GP_OK;
}

- (IBAction)connectTouched:(id)sender {
    UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;
    NSString *ip = self.ipTextField.text;
    if (ip != nil && ![ip isEqualToString:@""]) {
        if (!_connected) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                int ret = [self connectCamera:ip];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (ret == GP_OK) {
                        self.listButton.enabled = YES;
                        self.connected = YES;
                        self.consoleTextView.text = @"Connection to Camera successful";
                        self.connectButton.enabled = NO;
                    } else {
                        self.consoleTextView.text = @"Failed to connect";
                    }
                    UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
                });
            });
        }
    }
}

- (IBAction)listTouched:(id)sender {
    UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *allfiles = [NSMutableArray new];
        int ret = [self listAlFiles:"/" foundfile:NULL files:allfiles];
        if (ret == GP_OK) {
            NSString *outText = @"";
            for (NSString* item in allfiles) {
                outText = [outText stringByAppendingFormat:@"%@\n",item];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
                self.consoleTextView.text = outText;
            });
        }
    });
}


@end
