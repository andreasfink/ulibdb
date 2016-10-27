//
//  TestUmConfig.h
//  ulib
//
//  Created by Aarno Syvänen on 19.03.12.
//  Copyright (c) 2012 Fink Consulting GmbH. All rights reserved.
//

//  Application unit tests contain unit test code that must be injected into an application to run correctly.

#import <SenTestingKit/SenTestingKit.h>

@interface TestUMConfig : SenTestCase

+ (BOOL) assert:(NSDictionary *)a1 equals:(NSDictionary *)a2;

@end
