//
// Created by <a href="mailto:wentong@taobao.com">文通</a> on 12-12-8 下午12:30.
//


#import "TBMBMessageProxy.h"
#import "TBMBDefaultNotification.h"
#import "TBMBGlobalFacade.h"
#import "TBMBUtil.h"
#import "TBMBStaticCommand.h"

static char kTBMBNSMethodSignatureNotFoundKey;

@interface NSMethodSignature (TBMB)


@end

@implementation NSMethodSignature (TBMB)
- (BOOL)_$isTBMBNotFound {
    NSNumber *notFound = objc_getAssociatedObject(self, &kTBMBNSMethodSignatureNotFoundKey);
    return notFound ? [notFound boolValue] : NO;
}

- (void)_$setTBMBNotFound:(BOOL)yesOrNO {
    objc_setAssociatedObject(self, &kTBMBNSMethodSignatureNotFoundKey, [NSNumber numberWithBool:yesOrNO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end


@implementation TBMBMessageProxy {
@private
    Class _proxyClass;
    NSUInteger _key;
}

- (id)initWithClass:(Class)proxyClass andKey:(NSUInteger)key; {
    _proxyClass = proxyClass;
    _key = key;
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    NSMethodSignature *sig;
    if (TBMBClassHasProtocol(_proxyClass, @protocol(TBMBStaticCommand))) {
        sig = [_proxyClass methodSignatureForSelector:sel];
    } else {
        sig = [_proxyClass instanceMethodSignatureForSelector:sel];
    }
    if (sig) {
        [sig _$setTBMBNotFound:NO];
        return sig;
    } else {
        NSMethodSignature *signature = [[self class] methodSignatureForSelector:@selector(__$$__NullMethod)];
        [signature _$setTBMBNotFound:YES];
        return signature;
    }
    //return sig ? : [super methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSMethodSignature *signature = invocation.methodSignature;
    if (signature._$isTBMBNotFound) {
        NSLog(@"MBMvc You Invoke a Selector [%@] which is not exist in Class[%@]",
                NSStringFromSelector(invocation.selector),
                _proxyClass
        );
        return;
    }


    NSMutableArray *needReleaseBlocks = [NSMutableArray arrayWithCapacity:2];
    //判断参数有Block 就进行copy
    TBMB_LOG(@"proxy selector[%@]", NSStringFromSelector(invocation.selector));
    for (NSUInteger i = 0; i < signature.numberOfArguments; i++) {
        char const *type = [signature getArgumentTypeAtIndex:i];
        if (strcmp("@?", type) == 0) {
            TBMB_LOG(@"proxy parameter in [%d] is type [%s]", i, type);
            void *block = NULL;
            [invocation getArgument:&block atIndex:i];
            if (block) {
                id blockObj = (__bridge id) block;
                if ([blockObj isKindOfClass:NSClassFromString(@"NSBlock")]) {
                    TBMB_LOG(@"ori block ptr [%p]", block);
                    void *blockCopied = Block_copy(block);
                    TBMB_LOG(@"copy block ptr [%p]", blockCopied);
                    [invocation setArgument:&blockCopied atIndex:i];
                    [needReleaseBlocks addObject:[NSValue valueWithPointer:blockCopied]];
                }
            }
        }
    }

    if (!invocation.argumentsRetained) {
        [invocation retainArguments];
    }

    //对copy的Block 进行release
    if (needReleaseBlocks.count > 0) {
        for (NSValue *value in needReleaseBlocks) {
            void *needReleaseBlock = [value pointerValue];
            TBMB_LOG(@"release block ptr [%p]", needReleaseBlock);
            Block_release(needReleaseBlock);
        }
    }
    TBMBDefaultNotification *notification = [[TBMBDefaultNotification alloc]
                                                                      initWithName:TBMBProxyHandlerName(_key, _proxyClass)
                                                                               key:_key
                                                                              body:invocation];
    TBMBGlobalSendTBMBNotification(notification);
}


+ (void)__$$__NullMethod {
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (TBMBClassHasProtocol(_proxyClass, @protocol(TBMBStaticCommand))) {
        return [_proxyClass respondsToSelector:aSelector];
    } else {
        return [_proxyClass instancesRespondToSelector:aSelector];
    }
}


@end