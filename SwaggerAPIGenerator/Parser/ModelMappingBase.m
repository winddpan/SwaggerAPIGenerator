//
//  ModelMappingBase.m
//  SwaggerHelperDevelop
//
//  Created by Pan Xiao Ping on 15/9/7.
//  Copyright (c) 2015年 Cimu. All rights reserved.
//

#import "ModelMappingBase.h"

static const NSString *route = @"http://youyu.corp.cimu.com/v2/doc";
@implementation ModelMappingBase

- (NSString *)localDirectiory {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
        NSString *desktopPath = [paths objectAtIndex:0];
        path = [desktopPath stringByAppendingPathComponent:@"SwaggerGenerator"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
        }
    });
    return path;
}

- (void)run {
    _output = [NSMutableString string];
    [_output appendString:@"{\n"];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
    NSString *desktopPath = [paths objectAtIndex:0];
    NSString *path = [desktopPath stringByAppendingPathComponent:@"SwaggerGenerator"];
    
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    NSLog(@"%@", self.localDirectiory);
    
    NSString *whiteListPath = [[NSBundle mainBundle] pathForResource:@"WhiteListGroups" ofType:@"json"];
    NSArray *whiteList = [NSJSONSerialization JSONObjectWithData:[[NSData alloc] initWithContentsOfFile:whiteListPath] options:0 error:nil];
    
    NSString *modelMappingPath = [[NSBundle mainBundle] pathForResource:@"ModelMapping" ofType:@"json"];
    NSDictionary *modelMapping = [NSJSONSerialization JSONObjectWithData:[[NSData alloc] initWithContentsOfFile:modelMappingPath] options:0 error:nil];
    _bundleModelMapping = modelMapping;
    
    NSURLRequest *indexRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[route stringByAppendingString:@".json"]]];
    
    NSData *data = [NSURLConnection sendSynchronousRequest:indexRequest returningResponse:nil error:nil];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *apis;
    if ([(apis = dict[@"apis"]) isKindOfClass:NSArray.class]) {
        [apis enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
            NSString *path = obj[@"path"];
            NSString *groupName = [path stringByReplacingOccurrencesOfString:@"/" withString:@""];
            groupName = [groupName stringByReplacingOccurrencesOfString:@".{format}" withString:@""];
            
            if ([whiteList containsObject:groupName]) {
                path = [path stringByReplacingOccurrencesOfString:@"{format}" withString:@"json"];
                [self requestAPISwaggerJSON:path];
            }
        }];
    }
    
    [_output appendString:@"\n}"];
    
    NSString *hPath = [self.localDirectiory stringByAppendingPathComponent:@"ModelMapping.json"];
    [_output writeToFile:hPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NSLog(@"Done!");
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
            [self createLineByPath:path method:method parameters:parameters];
        }];
    }];
    [_output appendString:@"\n"];
}

- (void)createLineByPath:(NSString *)path method:(NSString *)method parameters:(NSArray *)parameters {
    NSMutableString *tPath = [[NSMutableString alloc] initWithString:path];
    [tPath replaceOccurrencesOfString:@".json" withString:@"" options:0 range:NSMakeRange(0, tPath.length)];
    [tPath replaceOccurrencesOfString:@"/v2/" withString:@"" options:0 range:NSMakeRange(0, tPath.length)];
    
    NSMutableString *className = [NSMutableString new];
    [className appendString:@"Api"];
    [className appendString:[method capitalizedString]];
    [className appendString:@"_"];
    
    NSArray *cp =  [tPath componentsSeparatedByString:@"/"];
    [cp enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
        [className appendString:[self fixPathComponent:obj]];
    }];
    
    NSString *bundleValue = _bundleModelMapping[className] ?: @"";
    
    [_output appendFormat:@"\"%@\" : \"%@\",\n", className, bundleValue];
}

- (NSString *)fixProperty:(NSString *)string {
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

- (NSString *)fixPathComponent:(NSString *)component {
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
