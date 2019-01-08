//
//  IPAPurchase.h
//  iOS_Purchase
//
//  Created by zhanfeng on 2017/6/6.
//  Copyright © 2017年 zhanfeng. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "UBIAPAlert.h"

/**
 block

 @param isSuccess 是否支付成功
 @param certificate 支付成功得到的凭证（用于在自己服务器验证）
 @param errorMsg 错误信息
 */
typedef void(^PayResult)(BOOL isSuccess,NSString *certificate,NSString *errorMsg);

@interface IPAPurchase : NSObject
@property (nonatomic, copy)PayResult payResultBlock;

+ (void)registerIAPAlertClass:(Class)alertClass; //conform to UBIAPAlert

+ (instancetype)manager;

/**
 启动内购工具
 */
-(void)startManager;


-(void)stopManager;

@property (nonatomic,copy) void (^requestBlock)(NSString *receipt,NSString *userId,NSString *orderId,NSDictionary *params,void(^backBlock)(BOOL success,int httpCode,NSString *message));
;

/**
 内购支付
 @param productID 内购商品ID
 @param userId    用户ID
 @param order     服务端生成的订单id
 @param params    服务端需要的其它参数
 @param payResult 结果
 */
-(void)buyProductWithProductID:(NSString *)productID userId:(NSString *)userId order:(NSString *)order params:(NSDictionary *)params payResult:(PayResult)payResult;


@end
