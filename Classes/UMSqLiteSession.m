//
//  UMSqLiteSession.m
//  ulibdb.framework
//
//  Created by Andreas Fink on 25.10.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.

#import "ulib/ulib.h"
#import "ulibdb_defines.h"

#ifdef HAVE_SQLITE

#import "UMSqLiteSession.h"

@implementation UMSqLiteSession


- (UMSqLiteSession *)initWithPool:(UMDbPool *)dbpool
{
    self=[super initWithPool:dbpool];
    if(self)
    {
        /* FIXME: do some init stuff here */
    }
    return self;
}

@end
#endif
