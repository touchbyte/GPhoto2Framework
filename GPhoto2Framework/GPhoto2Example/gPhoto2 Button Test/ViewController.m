//
//  ViewController.m
//  gPhoto2 Button Test
//
//  Created by Hendrik Holtmann on 24.10.18.
//  Copyright © 2018 Hendrik Holtmann. All rights reserved.
//

#import "ViewController.h"
#import "SSDP/SSDPServiceTypes.h"
#import "SSDP/SSDPService.h"
#import "Context.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#import "Config.h"
#import "ptp.h"
#import "ptp-private.h"


@import gphoto2;
@import KissXML;
@import Photos;
@import ObjectiveC.runtime;

@interface SSDPService (Extension)
    @property (nonatomic,copy) NSString *cameraName;
    @property (nonatomic,copy) NSString *cameraIP;

@end


static unsigned int ctx_startProgress_func (GPContext *context,
                                            float target,
                                            const char *text,
                                            void *data)
{
    printf("Start progress func %s Target: %.2f\n",text,target);
    return 0;
}


static void ctx_updateProgress_func (GPContext *context, unsigned int id, float current, void *data)
{
    printf("Update progress func %.2f - ID: %i \n",current,id);
}

static void ctx_stopProgress_func (GPContext *context, unsigned int id, void *data)
{
    printf("Stop progress for ID: %i\n",id);
}

@implementation SSDPService (Extension)

static void * CameraNamePropertyKey = &CameraNamePropertyKey;

-(NSString*)cameraName {
    return objc_getAssociatedObject(self, CameraNamePropertyKey);
}

-(void)setCameraName:(NSString *)cameraName
{
    objc_setAssociatedObject(self, CameraNamePropertyKey, cameraName, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@interface ViewController ()
    @property (nonatomic, strong) SSDPServiceBrowser *browserCanonEOS;
    @property (nonatomic, copy) NSString *cameraIP;
    @property (nonatomic, copy) NSString *cameraName;
    @property (nonatomic, assign) Camera *camera;
    @property (nonatomic, assign) GPContext *context;
    @property (nonatomic, strong) NSTimer *searchTimer;
    @property (nonatomic, strong) NSTimer *keepAliveTimer;

    @property (nonatomic, strong) NSMutableArray <SSDPService*> *services;
@end

@implementation ViewController


static void errordumper(GPLogLevel level, const char *domain, const char *str,
                        void *data) {
    fprintf(stdout, "%s\n", str);
}

static void logdumper(GPLogLevel level, const char *domain, const char *str,
                      void *data) {
    fprintf(stdout, "%s\n", str);
}

-(void)connectToCameraWithIP:(NSString*)ip completionBlock:(void(^)(Camera *camera, GPContext *context))completionBlock pairingRequiredBlock:(void (^)(void))pairingRequiredBlock errorBlock:(void(^)(int errorCode, NSString *errorDescription))errorBlock
{
    __block int hasConnected = 0;
    int ret,indexCamera,indexPort;
    CameraAbilitiesList *abilities;
    CameraAbilities a;
    
    GPPortInfoList *portinfolist = NULL;
    GPPortInfo pi;

    Camera *camera;
    GPContext *context;

 //   gp_log_add_func(GP_LOG_ERROR, errordumper, NULL);
 //   gp_log_add_func(GP_LOG_DEBUG, logdumper, NULL);
    
    context = sample_create_context();
    
    gp_camera_new (&camera);
    
    gp_abilities_list_new (&abilities);
    ret = gp_abilities_list_load (abilities, context);
    if (ret < GP_OK) {
        errorBlock(-1,  @"Could not list camera abilities");
    }
    indexCamera = gp_abilities_list_lookup_model (abilities, "Canon EOS (WLAN)");
    if (indexCamera>=0) {
        gp_abilities_list_get_abilities (abilities, indexCamera, &a);
        gp_camera_set_abilities (camera, a);
    } else {
        errorBlock(-1, @"Could not find camera driver");
    }
    
    gp_port_info_list_new (&portinfolist);
    ret = gp_port_info_list_load (portinfolist);
    ret = gp_port_info_list_count (portinfolist);
    
    NSString *connectStr = [NSString stringWithFormat:@"ptpip:%@",ip];
    
    indexPort = gp_port_info_list_lookup_path (portinfolist, [connectStr UTF8String]);
    if (indexPort>=0) {
        gp_port_info_list_get_info (portinfolist, indexPort, &pi);
        gp_camera_set_port_info (camera, pi);
    } else {
        errorBlock(-1, @"Could not find port driver");
    }
    NSLog(@"Before camera init");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (hasConnected ==  0) {
            pairingRequiredBlock();
        }
    });
    ret = gp_camera_init (camera, context);
    hasConnected = 1;
    NSLog(@"After camera init");
    if (ret < GP_OK) {
        errorBlock(-1, @"Could not intitialize Camera");
    } else {
        completionBlock(camera,context);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.browserCanonEOS = [SSDPServiceBrowser new];
    self.browserCanonEOS.delegate = self;
    self.iPLabel.hidden = YES;
    self.cameraLabel.hidden = YES;
    self.checkFileSystemButton.hidden = YES;
    self.shootSaveButton.hidden = YES;
    self.cameraPropertiesButton.hidden = YES;
    self.setCaptureTargetButton.hidden = YES;
    self.statusLabel.hidden = YES;
    self.activityIndicatorView.hidden = YES;
    self.exitConnectionButton.hidden = YES;
    signal (SIGPIPE, SIG_IGN);
}

-(void)checkForCanonEOSCameras
{
    [self.browserCanonEOS startBrowsingForServices:@[SSDPServiceType_UPnP_CanonEOS,SSDPServiceType_UPnP_CanonMobile,SSDPServiceType_UPnP_CanonWFT]];
}


- (IBAction)discoverCamera:(id)sender {
    self.services = [NSMutableArray new];
    self.activityIndicatorView.hidden = NO;
    [(self.searchTimer = [NSTimer scheduledTimerWithTimeInterval:3.0f target:self selector:@selector(checkForCanonEOSCameras) userInfo:nil repeats:YES]) fire];
}

- (void)ssdpBrowser:(SSDPServiceBrowser *)browser didNotStartBrowsingForServices:(NSError *)error
{
    NSLog(@"Could not browse %@",error);
}

-(BOOL)serviceExists:(SSDPService*)service{
    for (SSDPService *savedService in self.services) {
        if ([savedService.uniqueServiceName isEqualToString:service.uniqueServiceName]) {
            return YES;
        }
    }
    return NO;
}

- (void)ssdpBrowser:(SSDPServiceBrowser *)browser didFindService:(SSDPService *)service
{
    
    NSLog(@"IP of disovered device: %@",[service location].host);
    _iPLabel.hidden = NO;
    _iPLabel.text = [service location].host;
    self.cameraIP = [service location].host;

    if (![self serviceExists:service]) {
        [self.services addObject:service];
        [service loadServiceXMLDataWithSuccessBlock:^(NSData *xmlData) {
            NSError *error;
            DDXMLDocument *document = [[DDXMLDocument alloc] initWithData:xmlData options:0 error:&error];
            NSArray *nodes = [document nodesForXPath:@"//*[local-name()='friendlyName']" error:&error];
            NSLog(@"Model: %@",[nodes[0] stringValue]);
            service.cameraName = [nodes[0] stringValue];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.cameraLabel.hidden = NO;
                self.cameraLabel.text = [nodes[0] stringValue];
           //     [self.searchTimer invalidate];
               // [self.browserCanonEOS stopBrowsingForServices];
                [self.tableView reloadData];
                self.activityIndicatorView.hidden =YES;
            });
            
        
            [self connectToCameraWithIP:self->_cameraIP completionBlock:^(Camera *camera, GPContext *context) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.checkFileSystemButton.hidden = NO;
                    self.shootSaveButton.hidden = NO;
                    self.cameraPropertiesButton.hidden = NO;
                    self.setCaptureTargetButton.hidden = NO;
                    self.statusLabel.hidden = NO;
                    self.exitConnectionButton.hidden = NO;
                    self.statusLabel.text = @"";
                    self.camera = camera;
                    self.context = context;
                    self.keepAliveTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(keepAlive) userInfo:nil repeats:YES];
                });
            } pairingRequiredBlock:^{
                self.statusLabel.hidden = NO;
                self.statusLabel.text = @">> Please confirm the pairing dialog. <<";
            } errorBlock:^(int errorCode, NSString *errorDescription) {
                NSLog(@"Connect to camera failed with error %@",errorDescription);
            }];
            
        } errorBlock:^(NSError *error) {
        }];
    }
}

-(void)keepAlive
{
    PTPParams *params = &self.camera->pl->params;
    int ret = ptp_generic_no_data(params,PTP_OC_CANON_902F,0);
    if (ret != PTP_RC_OK) {
        NSLog(@"Connection to camera was lost %i",ret);
        [_keepAliveTimer invalidate];
    }
}

- (void)ssdpBrowser:(SSDPServiceBrowser *)browser didRemoveService:(SSDPService *)service
{
    NSLog(@"Did remove %@",service);
    for (SSDPService *savedService in [self.services copy]) {
        if ([savedService.uniqueServiceName isEqualToString:service.uniqueServiceName]) {
            [self.services removeObject:savedService];
        }
    }
    [self.tableView reloadData];
}

static int
_lookup_widget(CameraWidget*widget, const char *key, CameraWidget **child) {
    int ret;
    ret = gp_widget_get_child_by_name (widget, key, child);
    if (ret < GP_OK)
        ret = gp_widget_get_child_by_label (widget, key, child);
    return ret;
}

- (IBAction)checkFileSystem:(id)sender {
    
    int ret;
    CameraList *list;
    /*
    ret = gp_list_new (&list);
    ret = gp_camera_folder_list_folders(self.camera, "/store_00020001/DCIM", list, self.context);
    if (ret<GP_OK) {
        NSLog(@"Could not list folders");
    } else {
        NSLog(@"Found %i folders",gp_list_count (list));
        int i;
        for (i=0; i < gp_list_count(list); i++) {
            const char *name, *value;
            gp_list_get_name (list, i, &name);
            gp_list_get_name (list, i, &value);
            NSLog(@"Folders - Key: %@, Value %@",[NSString stringWithUTF8String:name],[NSString stringWithUTF8String:value]);
            
        }
    }
    
    CameraList *fileslist;
    ret = gp_list_new (&fileslist);
    ret = gp_camera_folder_list_files(self.camera, "/store_00020001/DCIM/100CANON", fileslist, self.context);
    if (ret<GP_OK) {
        NSLog(@"Could not list files");
    } else {
        int i;
        for (i=0; i < gp_list_count(fileslist); i++) {
            const char *fileEntry;
            CameraFileInfo    fileinfo;
            gp_list_get_name (fileslist, i, &fileEntry);
            ret = gp_camera_file_get_info (self.camera, "/store_00020001/DCIM/100CANON", fileEntry, &fileinfo, self.context);
            NSLog(@"File %i - Name: %@, Info %lu Size: %llu",i,[NSString stringWithUTF8String:fileEntry],fileinfo.file.mtime,fileinfo.file.size);
        }
    }
    */

    /*
    CameraFile *file;

    NSString *filename = @"MVI_0129.MP4";
    NSString* path = [NSString stringWithFormat:@"/Users/hendrikh/Desktop/testshoot/%@",filename];
    int fd = open ([path UTF8String], O_CREAT | O_WRONLY, 0644);
    ret = gp_file_new_from_fd(&file, fd);

    ret = gp_camera_file_get(self.camera,"/store_00010001/DCIM/103___11", [filename UTF8String],
                                GP_FILE_TYPE_NORMAL, file, self.context);
    gp_file_free(file);
    */
    
    CameraList *configList;
    ret = gp_list_new (&configList);
    gp_camera_list_config(self.camera, configList, self.context);
    
    if (ret<GP_OK) {
        NSLog(@"Could not get config");
    } else {
        int i;
        CameraWidget *rootconfig; // okay, not really
        gp_camera_get_config(self.camera, &rootconfig, self.context);
        for (i=0; i < gp_list_count(configList); i++) {
            const char *name, *value;
            CameraWidget        *widget = NULL, *child = NULL;
            CameraWidgetType    type;
            int            ret;
            const char   *textVal;
            int  toggleVal = -100;
            float rangeVal = -100;

            gp_list_get_name (configList, i, &name);
           
            ret = _lookup_widget (rootconfig, name, &child);
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
                    ret = gp_widget_get_value (child, &textVal);
                    break;
                case GP_WIDGET_TEXT:
                    ret = gp_widget_get_value (child, &textVal);
                    break;
                case GP_WIDGET_TOGGLE:
                    ret = gp_widget_get_value (child, &toggleVal);
                    break;
                case GP_WIDGET_RANGE:
                    ret = gp_widget_get_value (child, &rangeVal);
                default:
                    fprintf (stderr, "widget has bad type %d\n", type);
                    ret = GP_ERROR_BAD_PARAMETERS;
                    goto out;
            }
            
            if (ret < GP_OK) {
                fprintf (stderr, "could not query widget value: %d\n", ret);
                goto out;
            }
            /* Create a new copy for our caller. */
       //     *str = strdup (val);
            out:
            gp_widget_free (widget);
            
          //  #  gp_list_get_value (configList, i, &value);
            if (textVal != NULL) {
                if (type == GP_WIDGET_RADIO) {
                    NSLog(@" ===== \n");
                }
                NSLog(@"Type: %i Key: %@, Value: %@",type,[NSString stringWithUTF8String:name],[NSString stringWithUTF8String:textVal]);
                if (type == GP_WIDGET_RADIO) {
                    const char *choice;
                    int numChoices = gp_widget_count_choices(child);
                    for (int i=0;i<numChoices;i++) {
                        gp_widget_get_choice(child,i,&choice);
                        NSLog(@"   Num: %i, Choice: %@",i,[NSString stringWithUTF8String:choice]);
                    }
                    NSLog(@" ===== \n");
                }
            } else if (toggleVal != -100) {
                NSLog(@"Type: %i Key: %@, Value: %@",type,[NSString stringWithUTF8String:name],@(toggleVal));
            } else if (rangeVal != -100) {
                NSLog(@"Type %i Key: %@, Value: %@",type,[NSString stringWithUTF8String:name],@(rangeVal));
            } else {
                NSLog(@"Key: %@",[NSString stringWithUTF8String:name]);
            }
        }
    }
    
    PTPParams params = self.camera->pl->params;
    
    if (ptp_operation_issupported(&params, PTP_OC_CANON_EOS_RemoteRelease))
    {
        NSLog(@"Remote Release Is supported");
    } else {
        NSLog(@"Remote Release is not supported");
    }
    
    CameraText    text;
    ret = gp_camera_get_summary (self.camera, &text, self.context);
    if (ret < GP_OK) {
        fprintf (stderr, "Failed to get summary.\n");
    } else {
        NSLog(@"Info %@",[NSString stringWithUTF8String:text.text]);
    }
}



- (IBAction)shootAndSave:(id)sender {
    
    [self.keepAliveTimer invalidate];
    UIApplication* app = [UIApplication sharedApplication];
    UIBackgroundTaskIdentifier getBackgroundTimeIdentifier = [app beginBackgroundTaskWithExpirationHandler: ^{
    }];

    self->_statusLabel.text = @"Shoot & Save";
    PTPParams params = self.camera->pl->params;
    ptp_canon_eos_setuilock(&params);
    
    int ret;
    ret = set_config_value_string (self.camera, "capturetarget", "Memory card", self.context);
    if (ret < GP_OK) {
        printf ("Could not set property.\n");
    }
    ptp_canon_eos_resetuilock(&params);                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){

        int fd, retval;
        CameraFile *file;
        CameraEventType  evttype;
        CameraFilePath    *path;
        void    *evtdata;
        NSLog(@"Teathering");
        while (1) {
            retval = gp_camera_wait_for_event (self.camera, 1000, &evttype, &evtdata, self.context);
            if (retval != GP_OK) {
                NSLog(@"Connection to camera was lost %i",retval);
                break;
            }
            switch (evttype) {
                case GP_EVENT_FILE_ADDED: {
                    path = (CameraFilePath*)evtdata;
                    printf("File added on the camera: %s/%s\n", path->folder, path->name);
                    
                    NSString* filename = [NSString stringWithFormat:@"%@/%@",NSTemporaryDirectory(),[NSString stringWithUTF8String:path->name]];
                    fd = open ([filename UTF8String], O_CREAT | O_WRONLY, 0644);
                    retval = gp_file_new_from_fd(&file, fd);
                    printf("  Downloading %s...\n", path->name);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.activityIndicatorView.hidden =NO;
                        self->_statusLabel.text = [NSString stringWithFormat:@"Downloading: %@",[[NSString alloc] initWithUTF8String:path->name]];
                    });
                    CameraFileInfo info;
                    gp_context_set_progress_funcs(self.context, ctx_startProgress_func, ctx_updateProgress_func, ctx_stopProgress_func, NULL);
                    retval = gp_camera_file_get_info(self.camera, path->folder, path->name, &info, self.context);
                    uint64_t fileSize = info.file.size;
                    NSLog(@"Got info: Filesize: %llu Width: %i Height: %i",fileSize,info.file.width,info.file.height);
                    gp_context_set_progress_funcs(self.context, ctx_startProgress_func, ctx_updateProgress_func, ctx_stopProgress_func, NULL);

                    retval = gp_camera_file_get(self.camera, path->folder, path->name,
                                                GP_FILE_TYPE_NORMAL, file, self.context);
                    
                    gp_file_free(file);
                    gp_context_set_progress_funcs(self.context, NULL, NULL, NULL, NULL);


                    dispatch_async(dispatch_get_main_queue(), ^{
                        self->_statusLabel.text = @"Shoot & Save";
                        self.activityIndicatorView.hidden =YES;
                    });

                    /*
                    printf("  Deleting %s on camera...\n", path->name);
                    retval = gp_camera_file_delete(self.camera, path->folder, path->name, self.context);
                    */
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                        PHAssetResourceCreationOptions *options = [PHAssetResourceCreationOptions new];
                        [request addResourceWithType:PHAssetResourceTypePhoto fileURL:[NSURL URLWithString:filename] options:options];
                    } completionHandler:^(BOOL success, NSError * _Nullable error) {
                        NSLog(@"Imported successfull");
                    }];
                
                    free(evtdata);
                    break;
                }
                case GP_EVENT_FOLDER_ADDED:
                    path = (CameraFilePath*)evtdata;
                    printf("Folder added on camera: %s / %s\n", path->folder, path->name);
                    free(evtdata);
                    break;
                case GP_EVENT_FILE_CHANGED:
                    path = (CameraFilePath*)evtdata;
                    printf("File changed on camera: %s / %s\n", path->folder, path->name);
                    free(evtdata);
                    break;
                case GP_EVENT_CAPTURE_COMPLETE:
                    printf("Capture Complete.\n");
                    break;
                case GP_EVENT_TIMEOUT:
                 //   printf("Timeout.\n");
                    break;
                case GP_EVENT_UNKNOWN:
                    if (evtdata) {
                   //     printf("Unknown event: %s.\n", (char*)evtdata);
                    } else {
                   //     printf("Unknown event.\n");
                    }
                    break;
                default:
                    printf("Type %d?\n", evttype);
                    break;
            }
        }
    });
}

- (IBAction)cameraProperties:(id)sender {
    /*
    PTPParams params = self.camera->pl->params;
    
    if (ptp_operation_issupported(&params, PTP_OC_CANON_EOS_RemoteRelease))
    {
        self.statusLabel.text = @"Remote shooting supported.";
        NSLog(@"Is supported");
    } else {
        self.statusLabel.text = @"Remote shooting NOT supported.";
    }
     */
    PTPParams params = self.camera->pl->params;
    ptp_canon_eos_setuilock(&params);

/*
    char        *propStr;
    int ret;
    ret = get_config_value_string (self.camera, "capturetarget", &propStr, self.context);
    if (ret < GP_OK) {
        printf ("Could not query property.\n");
    }
    printf("Aperture: %s\n", propStr);
*/
    ptp_canon_eos_resetuilock(&params);

}


- (IBAction)setCaptureTarget:(id)sender {
    
    PTPParams params = self.camera->pl->params;
    ptp_canon_eos_setuilock(&params);

    int ret;
    ret = set_config_value_string (self.camera, "capturetarget", "Memory card", self.context);
    if (ret < GP_OK) {
        printf ("Could not set property.\n");
    }
    ptp_canon_eos_resetuilock(&params);

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.services.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"CameraCell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    cell.textLabel.text = self.services[indexPath.row].cameraName;
    return cell;
}



- (IBAction)exitConnectionButtonPressed:(id)sender {
   [self.keepAliveTimer invalidate];
    PTPParams *params = &self.camera->pl->params;
    unsigned char startup9110[12];
    startup9110[0] = 0x0c;
    startup9110[1] = 0x00;
    startup9110[2] = 0x00;
    startup9110[3] = 0x00;
    startup9110[4] = 0x75;
    startup9110[5] = 0xd1;
    startup9110[6] = 0x00;
    startup9110[7] = 0x00;
    startup9110[8] = 0x00;
    startup9110[9] = 0x00;
    startup9110[10] = 0x00;
    startup9110[11] = 0x00;
    ptp_canon_eos_setdevicepropvalueex(params,startup9110,12);
}

@end
