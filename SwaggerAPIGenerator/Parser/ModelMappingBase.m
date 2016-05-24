//
//  ModelMappingBase.m
//  SwaggerHelperDevelop
//
//  Created by Pan Xiao Ping on 15/9/7.
//  Copyright (c) 2015年 Cimu. All rights reserved.
//

#import "ModelMappingBase.h"
#import "ParserRegular.h"

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
    
    NSString *modelMappingPath = [[NSBundle mainBundle] pathForResource:@"ApiModelReflect" ofType:@"plist"];
    _bundleModelMapping = [[NSDictionary alloc] initWithContentsOfFile:modelMappingPath];
    
    NSURLRequest *indexRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[route stringByAppendingString:@".json"]]];
    
    NSData *data = [NSURLConnection sendSynchronousRequest:indexRequest returningResponse:nil error:nil];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *apis;
    if ([(apis = dict[@"apis"]) isKindOfClass:NSArray.class]) {
        [apis enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
            NSString *path = obj[@"path"];
            NSString *groupName = [path stringByReplacingOccurrencesOfString:@"/" withString:@""];
            groupName = [groupName stringByReplacingOccurrencesOfString:@".{format}" withString:@""];
            
            path = [path stringByReplacingOccurrencesOfString:@"{format}" withString:@"json"];
            [self requestAPISwaggerJSON:path];
        }];
    }
    
    [_output appendString:@"\n}"];
    
    NSString *hPath = [self.localDirectiory stringByAppendingPathComponent:@"ApiModelReflect.plist"];
    NSDictionary *ApiModelReflect = [NSJSONSerialization JSONObjectWithData:[_output dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    [ApiModelReflect writeToFile:hPath atomically:YES];
    
    NSLog(@"Done ModelMappingBase!");
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
    NSString *className = [ParserRegular classNameByPath:path mehtod:method];
    
    NSString *bundleValue = _bundleModelMapping[className] ?: @"";
    [_output appendFormat:@"\"%@\" : \"%@\",\n", className, bundleValue];
}


@end
