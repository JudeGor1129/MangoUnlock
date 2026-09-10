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
static long long (*orig_mgo_query_state)(void);
static long long hook_mgo_query_state(void) { return 1; }

static void hook_auth(void) {
    void *handle = dlopen("/var/jb/Library/MobileSubstrate/DynamicLibraries/mango.dylib", RTLD_NOLOAD);
    mlog("hook_auth: dlopen mango.dylib");
    if (!handle) { mlog("  -> dlopen FAILED (not loaded yet)"); return; }
    void *v = dlsym(handle, "mgo_internal_verify");
    mlog(v ? "  -> dlsym mgo_internal_verify OK" : "  -> dlsym mgo_internal_verify FAILED");
    if (v && !orig_mgo_internal_verify) {
        MSHookFunction(v, (void *)&hook_mgo_internal_verify, (void **)&orig_mgo_internal_verify);
        mlog("  -> MSHookFunction verify DONE");
    }
    void *q = dlsym(handle, "mgo_query_state");
    mlog(q ? "  -> dlsym mgo_query_state OK" : "  -> dlsym mgo_query_state FAILED");
    if (q && !orig_mgo_query_state) {
        MSHookFunction(q, (void *)&hook_mgo_query_state, (void **)&orig_mgo_query_state);
        mlog("  -> MSHookFunction query DONE");
    }
}

static void hook_popup(void) {
    Class cls = objc_getClass("MGOHUDView");
    mlog("hook_popup: objc_getClass MGOHUDView");
    if (!cls) { mlog("  -> class NOT found"); return; }
    mlog("  -> class FOUND");
    SEL s1 = sel_registerName("showPopupForTitle:atLocation:sectionIndex:");
    Method m = class_getInstanceMethod(cls, s1);
    mlog(m ? "  -> method showPopupForTitle FOUND" : "  -> method showPopupForTitle NOT found");
    if (m) {
        method_setImplementation(m, imp_implementationWithBlock(^(id self, id title, id loc, long long sec) {
            mlog("  !! showPopupForTitle BLOCKED");
        }));
        mlog("  -> implementation replaced");
    }
    Method m2 = class_getInstanceMethod(cls, sel_registerName("show"));
    if (m2) method_setImplementation(m2, imp_implementationWithBlock(^(id self) {}));
    Method m3 = class_getInstanceMethod(cls, sel_registerName("hidePopup"));
    if (m3) method_setImplementation(m3, imp_implementationWithBlock(^(id self) {}));
}

static void try_apply(void) {
    hook_auth();
    hook_popup();
    void *handle = dlopen("/var/jb/Library/MobileSubstrate/DynamicLibraries/mango.dylib", RTLD_NOLOAD);
    if (!handle || !orig_mgo_internal_verify || !objc_getClass("MGOHUDView")) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            try_apply();
        });
    } else {
        mlog("ALL HOOKS APPLIED");
    }
}

%ctor {
    mlog("=== MangoUnlock loaded ===");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        try_apply();
    });
}
