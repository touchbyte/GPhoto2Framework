//
//  Context.c
//  gPhoto2 Button Test
//
//  Created by Hendrik Holtmann on 25.10.18.
//  Copyright © 2018 Hendrik Holtmann. All rights reserved.
//

#include "Context.h"

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

//Progress
/*
static unsigned int ctx_startProgress_func (GPContext *context,
                                    float target,
                                    const char *text,
                                    void *data)
{
    printf("Start progress func %s Target: %.2f",text,target);
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
*/

GPContext* sample_create_context() {
    GPContext *context;
    
    /* This is the mandatory part */
    context = gp_context_new();
    
    /* All the parts below are optional! */
    gp_context_set_error_func (context, ctx_error_func, NULL);
    gp_context_set_status_func (context, ctx_status_func, NULL);
 //   gp_context_set_progress_funcs(context, ctx_startProgress_func, ctx_updateProgress_func, ctx_stopProgress_func, NULL);
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

