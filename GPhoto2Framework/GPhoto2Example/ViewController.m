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
    @property(nonatomic, assign) PTPDeviceInfo deviceInfo;
    @property(nonatomic, strong) NSString *cameraModel;
    @property(nonatomic, strong) NSString *protocol;
    @property(nonatomic, assign) BOOL fuji_browse_active;

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
    
    NSString *connectionStr = [NSString stringWithFormat:@"%@:%@",self.protocol,cameraIP];
    
    gp_log_add_func(GP_LOG_ERROR, errordumper, NULL);
    gp_log_add_func(GP_LOG_DEBUG, logdumper, NULL);
    context = sample_create_context();
    gp_camera_new (&camera);
    
    gp_abilities_list_new (&abilities);
    ret = gp_abilities_list_load (abilities, context);
    indexCamera = gp_abilities_list_lookup_model (abilities, [self.cameraModel UTF8String]);
    
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
   // gp_setting_set("ptpip", "fuji_mode", "browse");
     gp_setting_set("ptpip", "fuji_mode", "pc_autosave");
  //  gp_setting_set("ptpip", "fuji_mode", "browse_legacy");
  //  gp_setting_set("ptpip", "fuji_mode", "push");
  //    gp_setting_set("ptpip", "fuji_mode", "tethering");

  //  gp_setting_set("ptpip", "fuji_mode", "tethering");
    ret = gp_camera_init (camera, context);
    self.deviceInfo =camera->pl->params.deviceinfo;
    
    PTPParams *params;
    params =&(camera->pl->params);
  

    return ret;
}

-(int)listAlFiles:(const char*)folder foundfile:(int*)foundfile files:(NSMutableArray*)files
{
    int        i, ret;
    CameraList    *list;
    const char    *newfile;
    PTPParams *params;
    params =&(camera->pl->params);
    
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
        CameraFileInfo    fileinfo;
        ret = gp_camera_file_get_info (camera, folder, newfile, &fileinfo, context);
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


-(IBAction)downloadFile:(id)sender
{
  
    NSString *name = @"DSCF7084.RAF";
    static int buffersize = 1*1024*1024;
    long long filesize = 42660112;
    long long offset = 0;
    char* buffer = malloc(buffersize);
    uint64_t readSize = buffersize;
    NSOutputStream *outPutStream = [NSOutputStream outputStreamToFileAtPath:@"/Users/hendrikh/Desktop/test.jpg" append:NO];
    [outPutStream open];
    while (offset < filesize) {
        //store_10000001
        int ret = gp_camera_file_read(camera, "/store_10000001", [name UTF8String], GP_FILE_TYPE_NORMAL, offset, buffer, &readSize, context);
        NSLog(@"Read finished with %i",ret);
        offset = offset + readSize;
        NSLog(@"Download progress %.2lld %.2lld",offset,filesize);
        if ([outPutStream write:(const uint8_t *)buffer maxLength:readSize]<=0 || ret!=GP_OK) {
            NSLog(@"Download aborted");
            break;
        }
    }
    [outPutStream close];
    free(buffer);
}

-(void)doConnect
{
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
                           self.connectButtonPTP.enabled = NO;
                           self.connectButtonLumix.enabled = NO;
                       } else {
                           self.consoleTextView.text = @"Failed to connect";
                       }
                       UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
                   });
               });
           }
       }
}

- (IBAction)connectTouchedPTP:(id)sender {
    self.protocol = @"ptpip";
    self.cameraModel = @"Canon EOS (WLAN)";
    [self doConnect];
}
- (IBAction)connectFujiTouched:(id)sender {
    self.protocol = @"ptpip";
    self.cameraModel = @"Fuji X (WLAN)";
    [self doConnect];
}

- (IBAction)connectLumixTouched:(id)sender {
    self.protocol = @"ip";
    self.cameraModel = @"Panasonic LumixGSeries";
    [self doConnect];
}

-(NSInteger)indexForFileCount:(uint16_t*)events count:(uint16_t)count
{
    NSInteger returnIndex = -1;
    for (NSInteger i=0;i<count;i++) {
        if (events[i]==0xd222) {
            returnIndex = i;
        }
        if (returnIndex==-1 && events[i]==0x220) {
            returnIndex = i;
        }
    }
    return returnIndex;
}


-(void)fuji_terminate
{
    PTPParams *params = &camera->pl->params;
    ptp_closesession(params);
    close(params->cmdfd);
    close(params->evtfd);

}

-(void)displayCount
{
    PTPPropertyValue        propval;

    PTPParams *params;
    
    params =&camera->pl->params;
    params->fuji_nrofobjects = 0;
    
    propval.str = "0/220";
    ptp_setdevicepropvalue(params, 0xD228, &propval, PTP_DTC_STR);
}

-(void)registerListProgress
{
    PTPParams *params;
    params =&camera->pl->params;
    
    params->fuji_list_progress = ^(int progress, int total) {
        NSLog(@"====> List progress %i of %i",progress,total);
    };
}

-(void)deregisterListProgress
{
    PTPParams *params;
    params =&camera->pl->params;
    params->fuji_list_progress = NULL;
}

-(void)fuji_switchToBrowse
{
    PTPPropertyValue        propval;

    PTPParams *params;
    
    params =&camera->pl->params;
    params->fuji_nrofobjects = 0;
    

    uint16_t count = 0;
    uint16_t *events = NULL;
    uint32_t * values = NULL;
    
    char mode[100];
    gp_setting_get("ptpip", "fuji_mode", mode);
    
    CameraEventType  evttype;
    void    *evtdata;
    
    if (strcmp(mode, "tethering") == 0 || strcmp(mode, "push") == 0 ) {
        while (1) {
            int retval = gp_camera_wait_for_event (camera, 1000, &evttype, &evtdata, context);
            if (retval != GP_OK) break;
            switch (evttype) {
                case GP_EVENT_UNKNOWN: {
                    NSLog(@"Event unknown");
                    break;
                }
                case GP_EVENT_TIMEOUT: {
                    NSLog(@"Event timeout");
                    break;
                }
                case GP_EVENT_FILE_ADDED: {
                    NSLog(@"File added");
                    CameraFilePath *cameraFilePath = (CameraFilePath*)evtdata;
                    CameraFileInfo info;
                    retval = gp_camera_file_get_info (camera, cameraFilePath->folder, cameraFilePath->name, &info, context);
                    NSLog(@"Info %@:%@",[[NSString alloc] initWithUTF8String:cameraFilePath->folder],[[NSString alloc] initWithUTF8String:cameraFilePath->name]);
                    NSString *savePath = [@"/Users/hendrikh/Desktop/fuji_save/" stringByAppendingString:[[NSString alloc] initWithUTF8String:cameraFilePath->name]];
                    CameraFile *file;
                    int fd = open ([savePath UTF8String], O_CREAT | O_WRONLY, 0644);
                    retval = gp_file_new_from_fd(&file, fd);
                    if (retval == GP_OK) {
                        params->fuji_tether_progress = ^(long long bytesWritten, long long totalBytes) {
                            NSLog(@"Progress called %.2lld of %.2lld",bytesWritten, totalBytes);
                        };
                        retval = gp_camera_file_get(camera, cameraFilePath->folder, cameraFilePath->name,
                                                    GP_FILE_TYPE_NORMAL, file, context);
                        params->fuji_tether_progress = NULL;
                        NSLog(@"saved %@",[[NSString alloc] initWithUTF8String:cameraFilePath->name]);
                    }
                }case GP_EVENT_FOLDER_ADDED: {
                    NSLog(@"Folder added");

                    break;
                }
                case GP_EVENT_CAPTURE_COMPLETE: {
                    NSLog(@"Capture completed");
                    break;
                }
                case GP_EVENT_FILE_CHANGED: {
                    NSLog(@"File changed");
                    break;
                }
                    
            }
        }

    } else if (strcmp(mode, "pc_autosave") == 0) {
        ptp_fuji_getevents (params, &events, &values, &count);
        NSInteger fileIndex = [self indexForFileCount:events count:count];
        if (fileIndex!=-1) {
            params->fuji_nrofobjects = values[fileIndex];
        }
        propval.u16 = 0x0001;
        ptp_setdevicepropvalue(params, 0xD227, &propval, PTP_DTC_UINT16);
        ptp_fuji_getevents (params, &events, &values, &count);
    } else {
        
        if (strcmp(mode, "browse_legacy") != 0) {
            ptp_fuji_getevents (params, &events, &values, &count);
            ptp_terminateopencapture(params,params->opencapture_transid);
            ptp_fuji_getevents (params, &events, &values, &count);
        }
        
        propval.u16 = 0x0006;
        ptp_setdevicepropvalue(params, 0xDF00, &propval, PTP_DTC_UINT16);
        ptp_fuji_getevents (params, &events, &values, &count);

        NSInteger fileIndex = [self indexForFileCount:events count:count];
        if (fileIndex!=-1) {
            params->fuji_nrofobjects = values[fileIndex];
        }

        ptp_getdevicepropvalue(params, 0xDF25, &propval, PTP_DTC_UINT32);
        ptp_fuji_getevents (params, &events, &values, &count);

        propval.u16 = 0x000B;
        ptp_setdevicepropvalue(params, 0xDF01, &propval, PTP_DTC_UINT16);

        propval.u32 = 0x00020004;
        ptp_setdevicepropvalue(params, 0xDF25, &propval, PTP_DTC_UINT32);
        ptp_fuji_getevents (params, &events, &values, &count);
        
        propval.u16 = 0x0001;
        ptp_setdevicepropvalue(params, 0xD227, &propval, PTP_DTC_UINT16);
        ptp_fuji_getevents (params, &events, &values, &count);

        self.fuji_browse_active = YES;
    }
}

- (IBAction)listTouched:(id)sender {
    
    if (!self.fuji_browse_active) {
        [self fuji_switchToBrowse];
    }
    
    char mode[100];
    gp_setting_get("ptpip", "fuji_mode", mode);
    
    if (strcmp(mode, "tethering") == 0 || strcmp(mode, "push") == 0) {
        return;
    }
    [self registerListProgress];
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
                [self deregisterListProgress];

                [self displayCount];
                UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
                self.consoleTextView.text = outText;
            });
        }
    });
}


@end
