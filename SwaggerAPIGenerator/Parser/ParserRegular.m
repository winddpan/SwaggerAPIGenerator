//
//  ParserRegular.m
//  SwaggerAPIGenerator
//
//  Created by Pan Xiao Ping on 15/12/28.
//  Copyright © 2015年 Cimu. All rights reserved.
//

#import "ParserRegular.h"

@implementation ParserRegular

+ (NSString *)classNameByPath:(NSString *)path mehtod:(NSString *)method {
    NSMutableString *tPath = [[NSMutableString alloc] initWithString:path];
    [tPath replaceOccurrencesOfString:@".json" withString:@"" options:0 range:NSMakeRange(0, tPath.length)];
    [tPath replaceOccurrencesOfString:@"/v2/" withString:@"" options:0 range:NSMakeRange(0, tPath.length)];
    
    NSMutableString *className = [NSMutableString new];
    [className appendString:@"Api"];
    [className appendString:[method capitalizedString]];
    [className appendString:@"_"];
    
    NSArray *cp =  [tPath componentsSeparatedByString:@"/"];
    NSString *lasIdPathRegex = @"\\{.*id.*\\}";
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", lasIdPathRegex];
    
    [cp enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
        [className appendString:[ParserRegular fixPathComponent:obj]];
    }];
    
    // /v2/account/courses/{course_id}.{format} 转换为 accountCourse
    __block NSString *toReplaceCompent;
    NSString *lastCompent = [cp lastObject];
    
    if (cp.count > 1 && [[cp objectAtIndex:cp.count - 2] hasSuffix:@"s"] && [pred evaluateWithObject:lastCompent]) {
        toReplaceCompent = [cp objectAtIndex:cp.count - 2];
    } else if ([[method uppercaseString] isEqualToString:@"POST"] && [lastCompent hasSuffix:@"s"]) {
        toReplaceCompent = lastCompent;
    }
    
    NSArray *noESsuffix = @[@"courses", @"cycles", @"nodes"];
    
    if ([toReplaceCompent hasSuffix:@"ies"]) {
        [className replaceCharactersInRange:NSMakeRange(className.length - 3, 3) withString:@"y"];
    } else if ([toReplaceCompent hasSuffix:@"es"]) {
        __block BOOL shouldFix = YES;
        [noESsuffix enumerateObjectsUsingBlock:^(NSString * _Nonnull suffix, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([[toReplaceCompent lowercaseString] hasSuffix:suffix]) {
                shouldFix = NO;
                *stop = YES;
            }
        }];
        if (shouldFix) {
            [className deleteCharactersInRange:NSMakeRange(className.length - 2, 2)];
        } else {
            [className deleteCharactersInRange:NSMakeRange(className.length - 1, 1)];
        }
    } else if ([toReplaceCompent hasSuffix:@"s"]) {
        [className deleteCharactersInRange:NSMakeRange(className.length - 1, 1)];
    }
    
    return className;
}

+ (NSString *)fixProperty:(NSString *)string {
    __block NSString *new = @"";
    NSArray *con = [string componentsSeparatedByString:@"_"];
    [con enumerateObjectsUsingBlock:^(NSString *component, NSUInteger idx, BOOL *stop) {
        if (idx == 0) {
            new = component;
        }else if (component.length > 0) {
            NSString *firstChar = [component substringToIndex:1];
            NSString *leftChars = [component substringFromIndex:1];
            NSString *pre = [NSString stringWithFormat:@"%@%@", [firstChar uppercaseString], leftChars];
            new = [new stringByAppendingString:pre];
        }
    }];
    if ([new isEqualToString:@"id"]) {
        new = @"Id";
    }
    if ([new isEqualToString:@"description"]) {
        new = @"desc";
    }
    return new;
}

+ (NSString *)fixPathComponent:(NSString *)component {
    if ([component hasPrefix:@"{"] && [component hasSuffix:@"}"]) {
        return @"";
    }
    if (component.length > 0) {
        NSString *firstChar = [component substringToIndex:1];
        NSString *leftChars = [component substringFromIndex:1];
        NSString *new = [NSString stringWithFormat:@"%@%@", [firstChar uppercaseString], leftChars];
        new = [new stringByReplacingOccurrencesOfString:@"_" withString:@""];
        return new;
    }
    return @"";
}

@end
