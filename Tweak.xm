#include <stdio.h>
#import <substrate.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>

static void mlog(const char *msg) {
    FILE *f = fopen("/var/jb/tmp/mangounlock.log", "a");
    if (f) { fprintf(f, "%s\n", msg); fclose(f); }
}

static void *(*orig_70a24)(void);
static void *hook_70a24(void) { return (void *)1; }

static void (*orig_75630)(void *);
static void hook_75630(void *a0) { mlog("!! popup fn 0x75630 BLOCKED"); }

static void hook_mangoos(void) {
    dlerror();
    void *h = dlopen("/var/jb/Library/MobileSubstrate/DynamicLibraries/mangoos.dylib", RTLD_NOLOAD);
    const char *err = dlerror();
    if (!h) {
        mlog("dlopen mangoos FAILED");
        if (err) { char b[256]; snprintf(b, 256, "  %s", err); mlog(b); }
        return;
    }
    mlog("dlopen mangoos OK");
    uintptr_t base = (uintptr_t)h;
    MSHookFunction((void *)(base + 0x70a24), (void *)&hook_70a24, (void **)&orig_70a24);
    mlog("hooked 0x70a24 (auth verify)");
    MSHookFunction((void *)(base + 0x75630), (void *)&hook_75630, (void **)&orig_75630);
    mlog("hooked 0x75630 (popup)");
}

%ctor {
    mlog("=== MangoUnlock v5 loaded ===");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        hook_mangoos();
    });
}
