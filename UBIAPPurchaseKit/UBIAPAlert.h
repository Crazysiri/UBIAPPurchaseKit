//
//  UBIAPAlert.h
//  UBIAPPurchaseKit
//
//  Created by Zero on 2019/1/8.
//  Copyright © 2019年 Zero. All rights reserved.
//

#ifndef UBIAPAlert_h
#define UBIAPAlert_h

#import <UIKit/UIKit.h>

@protocol UBIAPAlert <NSObject>

+ (void)showPersistentAlert:(NSString *)message inView:(UIView *)view;
+ (void)showAlertWithMessage:(NSString *)message inView:(UIView *)view complete:(void(^)(void))completion;

+ (void)hideHUDForView:(UIView *)view animated:(BOOL)animated;
@end
#endif /* UBIAPAlert_h */
