//
//  NSObject+SSKVO.m
//  003---自定义KVO
//
//  Created by xingling xu on 2020/2/21.
//  Copyright © 2020 cooci. All rights reserved.
//

#import "NSObject+SSKVO.h"
#import <objc/message.h>
static NSString * const SSKVOPrefix             = @"SSKVONotifying_";
static NSString * const SSKVOAssiociateKey      = @"SSKVOAssiociateKey";
static NSString * const SSKVO_Old               = @"SSKVO_Old";
static NSString * const SSKVO_New               = @"SSKVO_New";


@interface SSKVOInfo : NSObject {
    @public
    id observer;
    void *context;
    int options;
    NSString *keyPath;
    NSDictionary *changes;
}
@end
@implementation SSKVOInfo
@end



@implementation NSObject (SSKVO)

- (void)ss_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(SSKeyValueObservingOptions)options context:(nullable void *)context {
    // 动态生成子类
    Class replacement = [self replacementClass];
    
    // 添加setter方法
    {
        SEL sel = NSSelectorFromString(setterForGetter(keyPath));
        Method method = class_getInstanceMethod(self.class, sel);
        const char *types = method_getTypeEncoding(method);
        /** 重写setter方法 */
        class_addMethod(replacement , sel, (IMP)ss_setter, types);
    }
    
    SSKVOInfo *kvoInfo = [SSKVOInfo new];
    kvoInfo->context = context;
    kvoInfo->options = options;
    kvoInfo->keyPath = keyPath;
    kvoInfo->observer = observer;
    kvoInfo->changes = @{};
    
    //  添加信息
    [self addKVOInfo:kvoInfo forKey:keyPath];
    
}

- (void)ss_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(nullable void *)context {
    [self removeKVOInfoForKey:keyPath];
}

- (void)ss_observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context {
    
}

#pragma mark -
- (SSKVOInfo *)kvoInfoForKey:(NSString *)key {
    NSMutableDictionary *observerInfo = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(SSKVOAssiociateKey));
    id object = [observerInfo objectForKey:key];
    if (object && [object isKindOfClass:[SSKVOInfo class]]) {
        return object;
    }
    return nil;
}

- (void)addKVOInfo:(SSKVOInfo *)kvoInfo forKey:(NSString *)key {
    NSMutableDictionary *observerInfo = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(SSKVOAssiociateKey));
    if (!observerInfo) {
        observerInfo = [NSMutableDictionary dictionary];
    }
    [observerInfo setObject:kvoInfo forKey:key];
    objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(SSKVOAssiociateKey), observerInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)removeKVOInfoForKey:(NSString *)key {
    NSMutableDictionary *observerInfo = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(SSKVOAssiociateKey));
    [observerInfo removeObjectForKey:key];
    objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(SSKVOAssiociateKey), observerInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (observerInfo.count<=0) {
        // 指回给父类
        Class superClass = [self class];
        object_setClass(self, superClass);
    }
}

#pragma mark - custom method
// 动态生成子类
- (Class)replacementClass {
    // 判断是否已经创建过动态子类
    NSString *className = NSStringFromClass(self.class);
    NSString *kvoClassName = [NSString stringWithFormat:@"%@%@",SSKVOPrefix,className];
    Class kvoClass = NSClassFromString(kvoClassName);
    if (!kvoClass) {
        // 申请类
        kvoClass = objc_allocateClassPair(self.class, kvoClassName.UTF8String, 0);
        objc_registerClassPair(kvoClass);
        
        // 添加class方法
        {
            Method method = class_getInstanceMethod(self.class, @selector(class));
            const char *types = method_getTypeEncoding(method);
            class_addMethod(kvoClass, @selector(class),(IMP)ss_class, types);
        }
        
        // isa 重定向
        object_setClass(self, kvoClass);
    }
    return kvoClass;
}

/** 重写set方法 */
void ss_setter(id self, SEL _cmd, id value)
{
    NSString *v = NSStringFromSelector(_cmd);
    NSString *key = getterForSetter(v);
    Class c = [self class];
    /** 自动观察 */
    if ([c ss_automaticallyNotifiesObserversForKey:key]) {
        [self ss_willChangeValueForKey:key];
        /** 调用父类的set方法 */
        ss_sendSuper(self, _cmd, value);
        [self ss_didChangeValueForKey:key];
    } else {
        ss_sendSuper(self, _cmd, value);
    }
}

/** 调用父类的set方法 */
void ss_sendSuper(id self, SEL _cmd, id value)
{
    void (*ss_msgSendSuper)(void *,SEL , id) = (void *)objc_msgSendSuper;
    // void /* struct objc_super *super, SEL op, ... */
    struct objc_super superStruct = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self)),
    };
    //objc_msgSendSuper(&superStruct,_cmd,newValue)
    ss_msgSendSuper(&superStruct,_cmd,value);
}

- (void)ss_willChangeValueForKey:(NSString *)key {
    [self saveCurrentValueFor:SSKVO_Old keyPath:key];
}

- (void)ss_didChangeValueForKey:(NSString *)key {
    [self saveCurrentValueFor:SSKVO_New keyPath:key];
    [self sendNotification:key];
}

- (void)saveCurrentValueFor:(NSString *)changeKey  keyPath:(NSString *)keyPath {
    id object = [self kvoInfoForKey:keyPath];
    if (!object || ![object isKindOfClass:[SSKVOInfo class]]) {return;}
    SSKVOInfo *kvoInfo = (SSKVOInfo *)object;
    NSMutableDictionary *changes = kvoInfo->changes.mutableCopy;
    id value = [self valueForKey:keyPath]?[self valueForKey:keyPath]:@"";
    [changes setObject:value forKey:changeKey];
    kvoInfo->changes = changes.copy;
}

- (void)sendNotification:(NSString *)keyPath {
    id object = [self kvoInfoForKey:keyPath];
    if (!object || ![object isKindOfClass:[SSKVOInfo class]]) {return;}
    SSKVOInfo *kvoInfo = (SSKVOInfo *)object;
    // send notification
    id observer = kvoInfo->observer;
    // 发送通知
    if (observer && [observer respondsToSelector:@selector(ss_observeValueForKeyPath:ofObject:change:context:)]) {
        int options = kvoInfo->options;
        NSDictionary *changes = kvoInfo->changes;
        NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:2];
        if (options & SSKeyValueObservingOptionNew) {
            [info setObject:changes[SSKVO_New] forKey:SSKVO_New];
        }
        if (options & SSKeyValueObservingOptionOld) {
            [info setObject:changes[SSKVO_Old] forKey:SSKVO_Old];
        }
        [observer ss_observeValueForKeyPath:keyPath ofObject:self change:info context:kvoInfo->context];
    }
}

/** 是否自动观察 */
+ (BOOL)ss_automaticallyNotifiesObserversForKey:(NSString *)key {
    return YES;
}


static NSString *getterForSetter(NSString *setter){
    if (setter.length <= 0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) { return nil;}
    NSRange range = NSMakeRange(3, setter.length-4);
    NSString *getter = [setter substringWithRange:range];
    NSString *firstString = [[getter substringToIndex:1] lowercaseString];
    return  [getter stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:firstString];
}

static NSString *setterForGetter(NSString *getter){
    if (getter.length <= 0) { return nil;}
    NSString *firstString = [[getter substringToIndex:1] uppercaseString];
    NSString *leaveString = [getter substringFromIndex:1];
    return [NSString stringWithFormat:@"set%@%@:",firstString,leaveString];
}

Class ss_class(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}
@end
