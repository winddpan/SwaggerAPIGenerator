//
//  main.m
//  SwaggerAPIGenerator
//
//  Created by Pan Xiao Ping on 15/12/25.
//  Copyright © 2015年 Cimu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SwaggerParser.h"
#import "ModelMappingBase.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        [[ModelMappingBase new] run];
        [[SwaggerParser new] run];
    }
    return 0;
}
