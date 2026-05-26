#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher

+ (BOOL)tryBlock:(NS_NOESCAPE void (^)(void))block error:(NSError * _Nullable * _Nullable)error {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[NSLocalizedDescriptionKey] = exception.reason ?: exception.name;
            userInfo[@"ExceptionName"] = exception.name;
            if (exception.userInfo) {
                userInfo[@"ExceptionUserInfo"] = exception.userInfo;
            }
            *error = [NSError errorWithDomain:@"com.germanpereyra.meetsvault.ObjCException"
                                         code:0
                                     userInfo:userInfo];
        }
        return NO;
    }
}

@end
