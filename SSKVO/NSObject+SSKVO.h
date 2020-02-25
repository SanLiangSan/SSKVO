//
//  NSObject+SSKVO.h
//  003---自定义KVO
//
//  Created by xingling xu on 2020/2/21.
//  Copyright © 2020 cooci. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_OPTIONS(NSUInteger, SSKeyValueObservingOptions) {
    SSKeyValueObservingOptionNew = 0x01,
    SSKeyValueObservingOptionOld = 0x02,
};

@interface NSObject (SSKVO)

/** Register an observer of the value at a key path relative to the receiver */
- (void)ss_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(SSKeyValueObservingOptions)options context:(nullable void *)context;

/* deregister as an observer of the value at a key path relative to the receiver*/
- (void)ss_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(nullable void *)context;

/*  Given that the receiver has been registered as an observer of the value at a key path relative to an object, be notified of a change to that value */
- (void)ss_observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context;

+ (BOOL)ss_automaticallyNotifiesObserversForKey:(NSString *)key;

- (void)ss_willChangeValueForKey:(NSString *)key;

- (void)ss_didChangeValueForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
