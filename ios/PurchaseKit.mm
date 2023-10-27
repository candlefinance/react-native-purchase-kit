#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(PurchaseKit, RCTEventEmitter)

RCT_EXTERN_METHOD(supportedEvents)
RCT_EXTERN_METHOD(initialize)
RCT_EXTERN_METHOD(getRecentTransactions)
RCT_EXTERN_METHOD(getReceipt:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(purchase:(NSDictionary *)input withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(getProducts:(NSArray *)productIDs withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
