//
//  ParserRegular.h
//  SwaggerAPIGenerator
//
//  Created by Pan Xiao Ping on 15/12/28.
//  Copyright © 2015年 Cimu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ParserRegular : NSObject

+ (NSString *)classNameByPath:(NSString *)path mehtod:(NSString *)method;
+ (NSString *)fixPathComponent:(NSString *)component;
+ (NSString *)fixProperty:(NSString *)string;

@end
