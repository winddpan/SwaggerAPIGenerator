//
//  SwaggerJsonDownloader.m
//  SwaggerHelperDevelop
//
//  Created by Pan Xiao Ping on 15/9/2.
//  Copyright (c) 2015年 Cimu. All rights reserved.
//

#import "SwaggerParser.h"
#import "ParserRegular.h"

#define SF(format, ...)  ([NSString stringWithFormat:format, ##__VA_ARGS__])

static const NSString *baseClass = @"ApiBase";
static const NSString *route = @"http://youyu.corp.cimu.com/v2/doc";

@implementation SwaggerParser

- (NSString *)localDirectiory {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
        NSString *desktopPath = [paths objectAtIndex:0];
        path = [[desktopPath stringByAppendingPathComponent:@"SwaggerGenerator"] stringByAppendingPathComponent:@"API"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
        }
    });
    return path;
}

- (void)run {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
    NSString *desktopPath = [paths objectAtIndex:0];
    NSString *path = [[desktopPath stringByAppendingPathComponent:@"SwaggerGenerator"] stringByAppendingPathComponent:@"API"];
    
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    NSLog(@"%@", self.localDirectiory);
    
    self.hHeader = [NSMutableString new];
    [self.hHeader appendString:@"//\n// Api Header\n//\n"];
    
    NSURLRequest *indexRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[route stringByAppendingString:@".json"]]];
    NSData *data = [NSURLConnection sendSynchronousRequest:indexRequest returningResponse:nil error:nil];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *apis;
    if ([(apis = dict[@"apis"]) isKindOfClass:NSArray.class]) {
        [apis enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
            NSString *path = obj[@"path"];
            NSString *desc = obj[@"description"];
            NSString *groupName = [path stringByReplacingOccurrencesOfString:@"/" withString:@""];
            groupName = [groupName stringByReplacingOccurrencesOfString:@".{format}" withString:@""];
            
            path = [path stringByReplacingOccurrencesOfString:@"{format}" withString:@"json"];
            [self.hHeader appendFormat:@"\n// %@\n", desc];
            [self requestAPISwaggerJSON:path];
        }];
    }
    
    NSString *hPath = [self.localDirectiory stringByAppendingPathComponent:@"Api.h"];
    [self.hHeader writeToFile:hPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NSLog(@"Done SwaggerParser!");
}

- (void)requestAPISwaggerJSON:(NSString *)path {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[route stringByAppendingString:path]]];
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    [self parseAPI:dict];
}

- (void)parseAPI:(NSDictionary *)dictionary {
    
    //NSString *group = [dictionary[@"resourcePath"] stringByReplacingOccurrencesOfString:@"/" withString:@""];
    NSArray *apis = dictionary[@"apis"];
    [apis enumerateObjectsUsingBlock:^(NSDictionary *api, NSUInteger idx, BOOL *stop) {
        NSString *path = [api[@"path"] stringByReplacingOccurrencesOfString:@"{format}" withString:@"json"];
        NSArray *operations = api[@"operations"];
        [operations enumerateObjectsUsingBlock:^(NSDictionary *operation, NSUInteger idx, BOOL *stop) {
            NSString *method = operation[@"method"];
            NSArray *parameters = operation[@"parameters"];
            NSString *className = [self createClassFileByPath:path method:method parameters:parameters];
            [self.hHeader appendFormat:@"#import \"%@.h\"\n", className];
        }];
    }];
}


- (NSString *)createClassFileByPath:(NSString *)path method:(NSString *)method parameters:(NSArray *)parameters {
    NSString *className = [ParserRegular classNameByPath:path mehtod:method];
    
    // .h文件
    NSString *hPath = [self.localDirectiory stringByAppendingPathComponent:[className stringByAppendingString:@".h"]];
    NSMutableString *hContent = [NSMutableString new];
    [hContent appendString:@"//\n"];
    [hContent appendString:SF(@"// %@\n", className)];
    [hContent appendString:@"//\n\n"];
    [hContent appendString:SF(@"#import \"%@.h\"", baseClass)];
    [hContent appendString:@"\n\n"];
    [hContent appendString:SF(@"@interface %@ : %@\n", className, baseClass)];
    [hContent appendString:[self traversingPropertyByParameters:parameters]];
    [hContent appendString:@"\n"];
    [hContent appendString:SF(@"@end")];
    [hContent writeToFile:hPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    // 去除 reflectClassName， 使用外部字典管理映射，不再写入类里
    //NSString *reflectClassName = [self reflectClassNameByClassName:className];
    
    // .m文件
    NSString *mPath = [self.localDirectiory stringByAppendingPathComponent:[className stringByAppendingString:@".m"]];
    NSMutableString *mContent = [NSMutableString new];
    [mContent appendString:@"//\n"];
    [hContent appendString:@"\n\n"];
    [mContent appendString:SF(@"// %@\n", className)];
    [mContent appendString:@"//\n\n"];
    [mContent appendString:SF(@"#import \"%@\"", [className stringByAppendingString:@".h"])];
    [mContent appendString:@"\n\n"];
    [mContent appendString:SF(@"@implementation %@\n", className)];
    [mContent appendString:SF(@"\n- (NSString *)path {\n    return [NSString stringWithFormat:%@];\n}\n", [self pathFormatter:path parameters:parameters])];
    [mContent appendString:SF(@"\n- (NSString *)method {\n    return @\"%@\";\n}\n", method)];
    //[mContent appendString:SF(@"\n- (Class)reflectClass {\n    return %@;\n}\n", reflectClassName.length ? [NSString stringWithFormat:@"NSClassFromString(@\"%@\")", reflectClassName] : @"nil")];
    [mContent appendString:SF(@"\n+ (NSDictionary *)parametersMap \n{\n    return %@;\n}\n", [self traversingParamListByParameters:parameters])];
    [mContent appendString:SF(@"\n@end")];
    [mContent writeToFile:mPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    return className;
}

- (NSString *)pathFormatter:(NSString *)path parameters:(NSArray *)parameters {
    
    NSString *(^ArgFix)(NSString*) = ^NSString *(NSString *arg) {
        arg = [arg stringByReplacingOccurrencesOfString:@"{" withString:@""];
        arg = [arg stringByReplacingOccurrencesOfString:@"}" withString:@""];
        __block NSString *fixedArg = arg;
        [parameters enumerateObjectsUsingBlock:^(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
            NSString *type = dict[@"type"];
            NSString *name = dict[@"name"];
            
            if ([name isEqualToString:arg]) {
                fixedArg = [ParserRegular fixProperty:arg];
                fixedArg = SF(@"_%@", fixedArg);
                if (![type isEqualToString:@"string"]) {
                    fixedArg = SF(@"@(%@)", fixedArg);
                }
            }
        }];
        return fixedArg;
    };
    
    
    __block NSString *result = [path copy];
    __block NSMutableArray *argArray = [NSMutableArray array];
    NSString *pattern = @"\\{[^\\}]+\\}";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
    NSArray *matches = [regex matchesInString:path options:0 range:NSMakeRange(0, path.length)];
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult *match, NSUInteger idx, BOOL *stop) {
        NSRange matchRange = [match range];
        NSString *matchString = [path substringWithRange:matchRange];
        result = [result stringByReplacingOccurrencesOfString:matchString withString:@"%@"];
        NSString *arg = ArgFix(matchString);
        [argArray addObject:arg];
    }];
    
    NSString *pathStr = SF(@"@\"%@\"", result);
    if (argArray.count) {
        pathStr = [pathStr stringByAppendingString:@", "];
        pathStr = [pathStr stringByAppendingString:[argArray componentsJoinedByString:@", "]];
    }
    NSLog(@"%@", pathStr);
    
    return pathStr;
}

- (NSString *)traversingParamListByParameters:(NSArray *)parameters {
    NSMutableString *result = [NSMutableString new];
    [result appendString:@"@{"];
    
    parameters = [parameters sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        if ([obj1[@"paramType"] isEqualToString:@"path"]) {
            return NSOrderedDescending;
        }
        return NSOrderedAscending;
    }];
    [parameters enumerateObjectsUsingBlock:^(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
        NSString *type = dict[@"type"];
        NSString *name = dict[@"name"];
        NSString *paramType = dict[@"paramType"];
        NSString *description = dict[@"description"];
        NSString *fixedName = [ParserRegular fixProperty:name];
        if (![[fixedName lowercaseString] hasPrefix:@"since"] && ![name isEqualToString:@"account_token"]) {
            [result appendFormat:@"@\"%@\" : @\"%@\",\n             ", fixedName, name];
        }
    }];
    [result appendString:@"}"];
    
    return result;
}

- (NSString *)traversingPropertyByParameters:(NSArray *)parameters {
    NSMutableString *result = [NSMutableString new];
    
    parameters = [parameters sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        if ([obj1[@"paramType"] isEqualToString:@"path"]) {
            return NSOrderedDescending;
        }
        return NSOrderedAscending;
    }];
    [parameters enumerateObjectsUsingBlock:^(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
        NSString *type = dict[@"type"];
        NSString *srcName = dict[@"name"];
        NSString *paramType = dict[@"paramType"];
        NSString *description = dict[@"description"];
        NSString *name = [ParserRegular fixProperty:srcName];
        
        if (![[name lowercaseString] hasPrefix:@"since"] && ![srcName isEqualToString:@"account_token"]) {
            [result appendString:@"\n"];
            if ([description isKindOfClass:[NSString class]] && description.length) {
                [result appendString:SF(@"/**\n *  %@ \n */\n", description)];
            }
            if ([type isEqualToString:@"string"]) {
                [result appendString:SF(@"@property (nonatomic, strong) NSString *%@;\n", name)];
            } else if ([type isEqualToString:@"integer"]) {
                [result appendString:SF(@"@property (nonatomic, assign) NSInteger %@;\n", name)];
            } else if ([type isEqualToString:@"boolean"]) {
                [result appendString:SF(@"@property (nonatomic, assign) BOOL %@;\n", name)];
            }
        }
        
    }];
    return result;
}

- (NSString *)reflectClassNameByClassName:(NSString *)className {
    static NSDictionary *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error;
        NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ModelMapping" ofType:@"json"]];
        map = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            NSLog(@"%@", error);
        }
    });
    
    return [map objectForKey:className];
}

@end
