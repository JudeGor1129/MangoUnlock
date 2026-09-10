#import <substrate.h>
#import <dlfcn.h>
#import <objc/runtime.h>

// ===== 授权解锁 =====
static int (*orig_mgo_internal_verify)(void);
static int hook_mgo_internal_verify(void) {
    return 1;
}
static long long (*orig_mgo_query_state)(void);
static long long hook_mgo_query_state(void) {
    return 1;
}

static void hook_auth(void) {
    void *handle = dlopen("/var/jb/Library/MobileSubstrate/DynamicLibraries/mango.dylib", RTLD_NOLOAD);
    if (!handle) return;
    void *v = dlsym(handle, "mgo_internal_verify");
    if (v && !orig_mgo_internal_verify)
        MSHookFunction(v, (void *)&hook_mgo_internal_verify, (void **)&orig_mgo_internal_verify);
    void *q = dlsym(handle, "mgo_query_state");
    if (q && !orig_mgo_query_state)
        MSHookFunction(q, (void *)&hook_mgo_query_state, (void **)&orig_mgo_query_state);
}

// ===== 屏蔽弹窗（MGOHUDView） =====
static void hook_popup(void) {
    Class cls = objc_getClass("MGOHUDView");
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, sel_registerName("showPopupForTitle:atLocation:sectionIndex:"));
    if (m)
        method_setImplementation(m, imp_implementationWithBlock(^(id self, id title, id loc, long long sec) {}));
    Method m2 = class_getInstanceMethod(cls, sel_registerName("show"));
    if (m2)
        method_setImplementation(m2, imp_implementationWithBlock(^(id self) {}));
}

// ===== 轮询：等 mango.dylib 加载后再 hook =====
static void try_apply(void) {
    hook_auth();
    hook_popup();
    void *handle = dlopen("/var/jb/Library/MobileSubstrate/DynamicLibraries/mango.dylib", RTLD_NOLOAD);
    if (!handle || !orig_mgo_internal_verify || !objc_getClass("MGOHUDView")) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            try_apply();
        });
    }
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        try_apply();
    });
}
