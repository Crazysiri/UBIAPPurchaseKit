//
//  IPAPurchase.m
//  iOS_Purchase
//  Created by zhanfeng on 2017/6/6.
//  Copyright © 2017年 zhanfeng. All rights reserved.

#import "IPAPurchase.h"
#import <StoreKit/StoreKit.h>
#import <StoreKit/SKPaymentTransaction.h>
#import "NSString+category.h"
#import "NSDate+category.h"
#import "SandBoxHelper.h"

#import "UBIAPAlert.h"

#define __WEAK_SELF __weak typeof(self) weakSelf = self;

static NSString * const receiptKey = @"receipt_key_nyl";

dispatch_queue_t iap_queue(){
    static dispatch_queue_t as_iap_queue;
    static dispatch_once_t onceToken_iap_queue;
    dispatch_once(&onceToken_iap_queue, ^{
        as_iap_queue = dispatch_queue_create("com.iap.queue", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return as_iap_queue;
    
}

@interface IPAPurchase()<SKPaymentTransactionObserver,
SKProductsRequestDelegate>
{
    SKProductsRequest *request;
    
//    NSInteger _sendCount;//发送服务器失败次数
//    NSInteger _checkCount;//检查是否给用户失败次数
}
//购买凭证
@property (nonatomic,copy)NSString      *receipt;//存储base64编码的交易凭证

//产品ID
@property (nonnull,copy)NSString        *profductId;



//内购注册相关
@property (nonatomic,copy)NSString      *order;//系统订单号
@property (nonatomic,copy)NSString      *userid;//用户ID
@property (nonatomic,copy)NSDictionary  *params;

@end

static IPAPurchase * manager = nil;

@implementation IPAPurchase

static Class __iap_progress_hub;

+ (void)registerIAPAlertClass:(Class)alertClass {
    __iap_progress_hub = alertClass;
} //conform to UBIAPAlert


#pragma mark -- 单例方法
+ (instancetype)manager{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        if (!manager) {
            manager = [[IPAPurchase alloc] init];
        }
    });
    
    return manager;
}

#pragma mark - 1
#pragma mark -- 添加内购监听者
-(void)startManager{
    
    dispatch_sync(iap_queue(), ^{
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:manager];

    });

}

#pragma mark -- 移除内购监听者
-(void)stopManager{
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
        
    });
    
}


#pragma mark -- 结束上次未完成的交易
-(void)removeAllUncompleteTransactionsBeforeNewPurchase{
    
    NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
    
    if (transactions.count >= 1) {
        
        for (NSInteger count = transactions.count; count > 0; count--) {
            
            SKPaymentTransaction* transaction = [transactions objectAtIndex:count-1];
            
            if (transaction.transactionState == SKPaymentTransactionStatePurchased||transaction.transactionState == SKPaymentTransactionStateRestored) {
                
                [[SKPaymentQueue defaultQueue]finishTransaction:transaction];
            }
        }
        
    }else{
        
        NSLog(@"没有历史未消耗订单");
    }
    
}



#pragma mark - 2 发起购买（查询，然后购买）
#pragma mark -- 发起购买的方法
-(void)buyProductWithProductID:(NSString *)productID userId:(NSString *)userId order:(NSString *)order params:(NSDictionary *)params payResult:(PayResult)payResult {

    self.userid = userId;
    self.order = order;
    self.params = params;
    
    [self removeAllUncompleteTransactionsBeforeNewPurchase];
    
    self.payResultBlock = payResult;
    
    [__iap_progress_hub showPersistentAlert:@"查询中..." inView:UIApplication.sharedApplication.delegate.window];
    
    self.profductId = productID;
    
    if (!self.profductId.length) {
        
        UIAlertView * alertView = [[UIAlertView alloc]initWithTitle:@"Warm prompt" message:@"There is no corresponding product." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        
        [alertView show];
    }
    
    if ([SKPaymentQueue canMakePayments]) {
        
        [self requestProductInfo:self.profductId];
        
    }else{
        
        [__iap_progress_hub hideHUDForView:UIApplication.sharedApplication.delegate.window animated:NO];
        
    UIAlertView * alertView = [[UIAlertView alloc]initWithTitle:@"Warm prompt" message:@"Please turn on the in-app paid purchase function first." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        
    [alertView show];
        
    }
    
}

#pragma mark - 2.1 查询
#pragma mark -- 发起购买查询商品请求
-(void)requestProductInfo:(NSString *)productID{
    
    NSArray * productArray = [[NSArray alloc]initWithObjects:productID,nil];
    
    NSSet * IDSet = [NSSet setWithArray:productArray];
    
    request = [[SKProductsRequest alloc]initWithProductIdentifiers:IDSet];
    
    request.delegate = self;
    
    [request start];
    
}

#pragma mark -- SKProductsRequestDelegate 查询商品请求成功后的回调
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *myProduct = response.products;
    
    if (myProduct.count == 0) {
        
        [__iap_progress_hub hideHUDForView:UIApplication.sharedApplication.delegate.window animated:NO];
        [__iap_progress_hub showAlertWithMessage:@"No Product" inView:UIApplication.sharedApplication.delegate.window complete:nil];
        
        if (self.payResultBlock) {
            self.payResultBlock(NO, nil, @"无法获取产品信息，购买失败");
        }
        
        return;
    }
    
    SKProduct * product = nil;
    
    for(SKProduct * pro in myProduct){
        
        NSLog(@"SKProduct 描述信息%@", [pro description]);
        NSLog(@"产品标题 %@" , pro.localizedTitle);
        NSLog(@"产品描述信息: %@" , pro.localizedDescription);
        NSLog(@"价格: %@" , pro.price);
        NSLog(@"Product id: %@" , pro.productIdentifier);
        
        if ([pro.productIdentifier isEqualToString:self.profductId]) {
            
            product = pro;
            
            break;
        }
    }
    
    if (product) {
        [__iap_progress_hub showPersistentAlert:@"购买中..." inView:UIApplication.sharedApplication.delegate.window];

#pragma mark - 2.2 购买
        SKMutablePayment * payment = [SKMutablePayment paymentWithProduct:product];
        //使用苹果提供的属性,将平台订单号复制给这个属性作为透传参数
        if (!self.order) {
            self.order = @"服务端生成order id 丢失";
        }
        payment.applicationUsername = self.order;
        
        [[SKPaymentQueue defaultQueue] addPayment:payment];
        
    }else{
        
        NSLog(@"没有此商品信息");
    }
}

//查询失败后的回调
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    [__iap_progress_hub hideHUDForView:UIApplication.sharedApplication.delegate.window animated:NO];
    if (self.payResultBlock) {
        self.payResultBlock(NO, nil, [error localizedDescription]);
    }
}

//如果没有设置监听购买结果将直接跳至反馈结束；
-(void)requestDidFinish:(SKRequest *)request{
    NSLog(@"requestDidFinish line:199");
}


#pragma mark - 2.2 购买监听结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    
    //当用户购买的操作有结果时，就会触发下面的回调函数，
    for (SKPaymentTransaction * transaction in transactions) {
        
        switch (transaction.transactionState) {
                
            case SKPaymentTransactionStatePurchased:{
                
                [self completeTransaction:transaction];
                
            }break;
                
            case SKPaymentTransactionStateFailed:{
                
                [self failedTransaction:transaction];
                
            }break;
                
            case SKPaymentTransactionStateRestored:{//已经购买过该商品
                
                [self restoreTransaction:transaction];
                
            }break;
                
            case SKPaymentTransactionStatePurchasing:{
                
                NSLog(@"正在购买中...");
                
            }break;
                
            case SKPaymentTransactionStateDeferred:{
                
                NSLog(@"最终状态未确定");
                
            }break;
                
            default:
                break;
        }
    }
}

#pragma mark - 2.3 购买监听结果处理（处理交易完成的，处理交易失败，处理已经购买过该商品）
//处理交易完成的
- (void)completeTransaction:(SKPaymentTransaction *)transaction
{
    [self getAndSaveReceipt:transaction]; //获取交易成功后的购买凭证
    
}

//处理交易失败
- (void)failedTransaction:(SKPaymentTransaction *)transaction{
    
    [__iap_progress_hub hideHUDForView:UIApplication.sharedApplication.delegate.window animated:NO];

    NSString * error = nil;

    if(transaction.error.code != SKErrorPaymentCancelled) {
        
        [__iap_progress_hub showAlertWithMessage:@"您的购买失败,请重新购买" inView:UIApplication.sharedApplication.delegate.window complete:nil];

        //error = [NSString stringWithFormat:@"%ld",transaction.error.code];
        error = [NSString stringWithFormat:@"%@",@"购买失败！"];
        
    } else {
        [__iap_progress_hub showAlertWithMessage:@"已取消购买" inView:UIApplication.sharedApplication.delegate.window complete:nil];

        //error = [NSString stringWithFormat:@"%ld",transaction.error.code];
        error = [NSString stringWithFormat:@"%@",@"已取消"];

        }
    
    if (self.payResultBlock) {
        self.payResultBlock(NO, nil, error);
    }
    
    [[SKPaymentQueue defaultQueue]finishTransaction:transaction];
    
}

//处理已经购买过该商品
- (void)restoreTransaction:(SKPaymentTransaction *)transaction{
    
    [__iap_progress_hub hideHUDForView:UIApplication.sharedApplication.delegate.window animated:NO];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}


#pragma mark - 2.4 购买监听结果处理（处理交易完成的）->获取购买凭证
-(void)getAndSaveReceipt:(SKPaymentTransaction *)transaction{
    
    //获取交易凭证
    NSURL * receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData * receiptData = [NSData dataWithContentsOfURL:receiptUrl];
    NSString * base64String = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    //初始化字典
    NSMutableDictionary * dic = [[NSMutableDictionary alloc]init];
    
    NSString * order = transaction.payment.applicationUsername;
    
    //如果这个返回为nil
    
    NSLog(@"后台订单号为订单号为%@",order);
    
    NSString * userId;
    
    if (self.userid) {
        
        userId = self.userid;
        [[NSUserDefaults standardUserDefaults]setObject:userId forKey:@"unlock_iap_userId"];
        
    }else{
        
        userId = [[NSUserDefaults standardUserDefaults]
                  objectForKey:@"unlock_iap_userId"];
    }
    
    if (userId == nil||[userId length] == 0) {
        
        userId = @"走漏单流程未传入userId";
    }
    
    if (order == nil||[order length] == 0) {
        order = self.order; //这一步 直接用该次的orderId，降低漏单概率
        //防止 异常情况 self.order 也为空，但一般应该没有
        if (order == nil || [order length] == 0) {
            order = @"苹果返回透传参数为nil";
        }
    }

    NSString *fileName = [NSString UUID];
    
    NSString *savedPath = [NSString stringWithFormat:@"%@/%@.plist", [SandBoxHelper iapReceiptPath], fileName];
    
    [dic setValue: base64String forKey:receiptKey];
    [dic setValue: order forKey:@"order"];
    [dic setValue:[self getCurrentZoneTime] forKey:@"time"];
    [dic setValue: userId forKey:@"user_id"];

    //这个存储成功与否其实无关紧要
    BOOL ifWriteSuccess = [dic writeToFile:savedPath atomically:YES];

    if (ifWriteSuccess){

        NSLog(@"购买凭据存储成功!");

    }else{
        
        NSLog(@"购买凭据存储失败");
    }
#pragma mark - 3 去服务器验证购买
    [self sendAppStoreRequestBuy:[NSMutableDictionary
                                  dictionaryWithDictionary:@{@"userId":userId,
                                                              @"order":order,
                                                            @"receipt":base64String?base64String:@"没有收据",
                                                        @"transaction":transaction,
                                                              @"count":@(2)
                                                                                 }]];
    
}



#pragma mark -- 存储成功订单
-(void)SaveIapSuccessReceiptDataWithReceipt:(NSString *)receipt Order:(NSString *)order UserId:(NSString *)userId{
    
    NSMutableDictionary * mdic = [[NSMutableDictionary alloc]init];
    [mdic setValue:[self getCurrentZoneTime] forKey:@"time"];
    [mdic setValue: order forKey:@"order"];
    [mdic setValue: userId forKey:@"userid"];
    [mdic setValue: receipt forKey:receiptKey];
    NSString *fileName = [NSString UUID];
    NSString * successReceiptPath = [NSString stringWithFormat:@"%@/%@.plist", [SandBoxHelper SuccessIapPath], fileName];
    //存储购买成功的凭证
    [self insertReceiptWithReceiptByReceipt:receipt withDic:mdic  inReceiptPath:successReceiptPath];
}



-(void)insertReceiptWithReceiptByReceipt:(NSString *)receipt withDic:(NSDictionary *)dic inReceiptPath:(NSString *)receiptfilePath{
    
    BOOL isContain = NO;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError * error;
    NSArray * cacheFileNameArray = [fileManager contentsOfDirectoryAtPath:[SandBoxHelper SuccessIapPath] error:&error];
    
    if (cacheFileNameArray.count == 0) {
        
        [dic writeToFile:receiptfilePath atomically:YES];
        
        if ([dic writeToFile:receiptfilePath atomically:YES]) {
            
            NSLog(@"写入购买凭据成功");
            
        }
        
    }else{
       
        if (error == nil) {
         
            for (NSString * name in cacheFileNameArray) {

                NSString * filePath = [NSString stringWithFormat:@"%@/%@", [SandBoxHelper SuccessIapPath], name];
                NSMutableDictionary *localdic = [NSMutableDictionary dictionaryWithContentsOfFile:filePath];
                
                if ([localdic.allValues containsObject:receipt]) {
                    
                    isContain = YES;
                    
                }else{
                    
                    continue;
                }
            }
            
        }else{
            
            NSLog(@"读取本文存储凭据失败");
        }
        
    }
    
    if (isContain == NO) {
        
    BOOL  results = [dic writeToFile:receiptfilePath atomically:YES];
        
    if (results) {
        
        NSLog(@"写入凭证成功");
    }else{
        
        NSLog(@"写入凭证失败");
    }
        
    }else{
        
        NSLog(@"已经存在凭证请勿重复写入");
    }
}


#pragma mark -- 去服务器验证购买

- (void)checkBuy:(NSDictionary *)params {
//
//    if (_checkCount == 0) {
//        return;
//    }
//    _checkCount --;
    
//    NSString *userId = params[@"userId"];
//    NSString *order = params[@"order"];
//    __WEAK_SELF
//    [XDJHttpClient checkBuyIfSuccessWithUserid:userId Order:order completion:^(BOOL success, id responseObject, NSString *message) {
//        if (success) {
//
//        } else {
//            [weakSelf performSelector:@selector(checkBuy:) withObject:params afterDelay:1.0];
//        }
//    }];
}

-(void)sendAppStoreRequestBuy:(NSMutableDictionary *)params {
//    if (_sendCount == 0) {
//        return;
//    }
//    _sendCount --;
    NSString *receipt = params[@"receipt"];
    NSString *userId = params[@"userId"];
    NSString *order = params[@"order"];
    SKPaymentTransaction *transaction = params[@"transaction"];
    NSNumber *countNumber = params[@"count"];
    NSInteger count = countNumber.integerValue;

    params[@"count"] = @(count - 1);
    if (count == 0) {
        return;
    }
    __WEAK_SELF
    //这里将收据存储起来
    [weakSelf SaveIapSuccessReceiptDataWithReceipt:receipt Order:order UserId:userId];
    void(^backBlock)(BOOL success,int httpCode,NSString *message) = ^(BOOL success,int httpCode,NSString *message) {
        [__iap_progress_hub hideHUDForView:UIApplication.sharedApplication.delegate.window animated:NO];
        [__iap_progress_hub showAlertWithMessage:message inView:UIApplication.sharedApplication.delegate.window complete:nil
         ];
        if (success) {
            
            
            NSData * data = [NSData dataWithContentsOfFile:[[[NSBundle mainBundle] appStoreReceiptURL] path]];
            NSString *result = [data base64EncodedStringWithOptions:0];
            
            if (weakSelf.payResultBlock) {
                weakSelf.payResultBlock(YES, result, nil);
            }
            
            [weakSelf checkBuy:@{@"userId":userId,@"order":order}];
        } else {
            [weakSelf performSelector:@selector(sendAppStoreRequestBuy:) withObject:params afterDelay:3.0];
        }
        
        if (httpCode == 200) {
            //结束交易方法
            [weakSelf successConsumptionOfGoodsWithReceipt:receipt];
            [[SKPaymentQueue defaultQueue]finishTransaction:transaction];
            
        }
    };
    if (self.requestBlock) {
    self.requestBlock(receipt,userId,order,@{@"serial_no":transaction.transactionIdentifier?transaction.transactionIdentifier:@"苹果未返回transactionIdentifier"},backBlock);
    }
}
    
   
#pragma mark -- 根据订单号来移除本地凭证的方法
-(void)successConsumptionOfGoodsWithReceipt:(NSString * )receipt{
    __WEAK_SELF
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError * error;
    if ([fileManager fileExistsAtPath:[SandBoxHelper iapReceiptPath]]) {
        
        NSArray * cacheFileNameArray = [fileManager contentsOfDirectoryAtPath:[SandBoxHelper iapReceiptPath] error:&error];
        
        if (error == nil) {
            
            for (NSString * name in cacheFileNameArray) {
                
                NSString * filePath = [NSString stringWithFormat:@"%@/%@", [SandBoxHelper iapReceiptPath], name];
                
                [weakSelf removeReceiptWithPlistPath:filePath ByReceipt:receipt];
                
            }
        }
    }
}

#pragma mark -- 根据订单号来删除 存储的凭证
-(void)removeReceiptWithPlistPath:(NSString *)plistPath ByReceipt:(NSString *)receipt{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError * error;
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
    NSString * localReceipt = [dic objectForKey:receiptKey];
    //通过凭证进行对比
    if ([receipt isEqualToString:localReceipt]) {
      
        BOOL ifRemove = [fileManager removeItemAtPath:plistPath error:&error];
        
        if (ifRemove) {
            
            NSLog(@"成功订单移除成功");
            
        }else{
            
            NSLog(@"成功订单移除失败");
        }
        
    }else{
        
        NSLog(@"本地无与之匹配的订单");
    }
}



#pragma mark -- 获取系统时间的方法
-(NSString *)getCurrentZoneTime{
    
    NSDate * date = [NSDate date];
    NSDateFormatter*formatter = [[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString*dateTime = [formatter stringFromDate:date];
    return dateTime;
    
}
@end
