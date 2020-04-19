#include <jni.h>
#include <stdio.h>
#include <gphoto2/gphoto2.h>
#include <android/log.h> 


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

static void errordumper(GPLogLevel level, const char *domain, const char *str, void *data) {
    __android_log_print(ANDROID_LOG_ERROR,"GPhoto2Error","%s\n", str);
//    fprintf(stdout, "%s\n", str);
}

static void logdumper(GPLogLevel level, const char *domain, const char *str, void *data) {
    __android_log_print(ANDROID_LOG_INFO,"GPhoto2Info","%s\n", str);
//    fprintf(stdout, "%s\n", str);
}

 GPContext* sample_create_context() {        
    GPContext *context;
    context = gp_context_new();
    gp_context_set_error_func (context, ctx_error_func, NULL);
    gp_context_set_status_func (context, ctx_status_func, NULL);
    return context;
}

JNIEXPORT jstring JNICALL Java_com_example_gphototest_MainActivity_gphoto2CameraInit( JNIEnv* env,jobject thiz ){
    Camera  *camera;
    GPContext *context;
    int   ret,indexCamera,indexPort;
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
    gp_port_info_list_free(portinfolist);
    gp_abilities_list_free(abilities);

    gp_setting_set("ptpip", "hostname", "gphoto-example");
    ret = gp_camera_init (camera, context);

    if (ret == GP_OK) {
        return (*env)->NewStringUTF(env, "Camera init success.");   
    } else {
        GP_LOG_E ("Camera init fail %i",ret);
        return (*env)->NewStringUTF(env, "Camera init failed.");   
    }                         
}