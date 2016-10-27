//
//  UMSqLiteSession.m
//  ulibdb.framework
//
//  Created by Andreas Fink on 25.10.11.
//  Copyright (c) 2011 Andreas Fink

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
