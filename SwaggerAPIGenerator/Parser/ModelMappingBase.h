//
//  ModelMappingBase.h
//  SwaggerHelperDevelop
//
//  Created by Pan Xiao Ping on 15/9/7.
//  Copyright (c) 2015年 Cimu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ModelMappingBase : NSObject
{
    NSMutableString *_output;
    NSDictionary *_bundleModelMapping;
}

- (void)run;

@end
