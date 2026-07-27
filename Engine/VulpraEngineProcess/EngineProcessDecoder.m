#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static IMP VEPOriginalDecodeObjectOfClasses;

static id VEPDecodeObjectOfClasses(NSCoder *coder, SEL selector,
                                   NSSet<Class> *classes, NSString *key) {
  if (![classes containsObject:NSExtensionItem.class]) {
    return ((id (*)(id, SEL, NSSet<Class> *, NSString *))
                VEPOriginalDecodeObjectOfClasses)(coder, selector, classes, key);
  }

  NSMutableSet<Class> *allowed = [classes mutableCopy];
  [allowed addObject:NSXPCListenerEndpoint.class];
  return ((id (*)(id, SEL, NSSet<Class> *, NSString *))
              VEPOriginalDecodeObjectOfClasses)(coder, selector, allowed, key);
}

@interface VEPDecoderInstaller : NSObject
@end

@implementation VEPDecoderInstaller
+ (void)load {
  Class decoder = NSClassFromString(@"NSXPCDecoder");
  Method method = class_getInstanceMethod(
      decoder, @selector(decodeObjectOfClasses:forKey:));
  if (!method) {
    return;
  }
  VEPOriginalDecodeObjectOfClasses =
      method_setImplementation(method, (IMP)VEPDecodeObjectOfClasses);
}
@end
