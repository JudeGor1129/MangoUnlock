#import <substrate.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <string.h>
#import <dispatch/dispatch.h>

// 屏蔽弹窗
static void (*orig_show)(id, SEL);
static void hook_show(id self, SEL _cmd) { return; }

// 强制已授权（mango.dylib 验签函数）
static int (*orig_verify)(void);
static int hook_verify(void) { return 1; }

static void* (*orig_dlopen)(const char*, int);
static void* new_dlopen(const char* path, int mode) {
    void* handle = orig_dlopen(path, mode);
    if (handle && path && strstr(path, "mango")) {
        dispatch_async(dispatch_get_main_queue(), ^{
            Class hud = objc_getClass("MGFGHUDView");
            if (hud) MSHookMessageEx(hud, @selector(show), (IMP)hook_show, (IMP *)&orig_show);
            void* v = dlsym(handle, "mgo_internal_verify");
            if (v) MSHookFunction(v, (void*)hook_verify, (void**)&orig_verify);
            void* q = dlsym(handle, "mgo_query_state");
            if (q) MSHookFunction(q, (void*)hook_verify, (void**)&orig_verify);
        });
    }
    return handle;
}

%ctor {
    void* dl = dlsym(RTLD_DEFAULT, "dlopen");
    if (dl) MSHookFunction(dl, (void*)new_dlopen, (void**)&orig_dlopen);
}
