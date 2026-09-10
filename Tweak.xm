#include <stdio.h>
#import <substrate.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>

static void mlog(const char *msg) {
    FILE *f = fopen("/var/jb/tmp/mangounlock.log", "a");
    if (f) { fprintf(f, "%s\n", msg); fclose(f); }
}

static int (*orig_mgo_internal_verify)(void);
static int hook_mgo_internal_verify(void) { return 1; }
static int attempts = 0;

static void hook_auth(void) {
    dlerror();
    void *handle = dlopen("/var/jb/Library/MobileSubstrate/DynamicLibraries/mango.dylib", RTLD_LAZY);
    const char *err = dlerror();
    if (!handle) {
        mlog("dlopen mango FAILED");
        if (err) { char buf[512]; snprintf(buf, 512, "  dlerror: %s", err); mlog(buf); }
        return;
    }
    mlog("dlopen mango SUCCESS");
    void *v = dlsym(handle, "mgo_internal_verify");
    if (v) {
        MSHookFunction(v, (void *)&hook_mgo_internal_verify, (void **)&orig_mgo_internal_verify);
        mlog("hooked mgo_internal_verify");
    } else mlog("dlsym mgo_internal_verify FAILED");
}

static void hook_popup(void) {
    Class cls = objc_getClass("MGFGHUDView");
    if (!cls) { mlog("MGFGHUDView NOT found"); return; }
    mlog("MGFGHUDView FOUND");
    unsigned int mc = 0;
    Method *methods = class_copyMethodList(cls, &mc);
    char buf[256];
    for (unsigned int i = 0; i < mc; i++) {
        const char *nm = sel_getName(method_getName(methods[i]));
        if (strstr(nm, "show") || strstr(nm, "Popup") || strstr(nm, "present") || strstr(nm, "display")) {
            snprintf(buf, 256, "  method: %s", nm); mlog(buf);
        }
    }
    free(methods);
    SEL s = sel_registerName("show");
    Method m = class_getInstanceMethod(cls, s);
    if (m) {
        method_setImplementation(m, imp_implementationWithBlock(^(id self) { mlog("  !! MGFGHUDView show BLOCKED"); }));
        mlog("hooked MGFGHUDView show");
    }
}

static void try_apply(void) {
    hook_auth();
    hook_popup();
    attempts++;
    if (attempts < 30) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            try_apply();
        });
    } else {
        mlog("=== stopped retrying ===");
    }
}

%ctor {
    mlog("=== MangoUnlock v4 loaded ===");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        try_apply();
    });
}
