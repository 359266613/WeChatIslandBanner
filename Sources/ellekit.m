#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// Registers a placeholder Objective-C class with the given runtime name if it
// does not already exist. We fall back to NSObject as the superclass because
// the original Swift base type (_TtCs12_SwiftObject) is not available here.
static void registerPlaceholderClass(const char *className) {
    if (NSClassFromString([NSString stringWithUTF8String:className])) {
        return;
    }

    Class cls = objc_allocateClassPair([NSObject class], className, /*extraBytes*/0);
    if (cls == Nil) {
        return;
    }

    // We do not know the real ivar layout; avoid adding ivars to keep this safe.
    objc_registerClassPair(cls);
}

__attribute__((constructor))
static void registerEllekitPlaceholders(void) {
    const char *classNames[] = {
        "ellekit.add",
        "ellekit.adr",
        "ellekit.adrp",
        "ellekit.b",
        "ellekit.bl",
        "ellekit.blr",
        "ellekit.br",
        "ellekit.bytes",
        "ellekit.cbnz",
        "ellekit.cbz",
        "ellekit.csel",
        "ellekit.ExceptionHandler",
        "ellekit.ldr",
        "ellekit.movk",
        "ellekit.movz",
        "ellekit.nop",
        "ellekit.pacia",
        "ellekit.paciza",
        "ellekit.ret",
        "ellekit.str",
        "ellekit.sub",
        "ellekit.svc",
    };

    for (size_t i = 0; i < sizeof(classNames) / sizeof(classNames[0]); i++) {
        registerPlaceholderClass(classNames[i]);
    }
}

