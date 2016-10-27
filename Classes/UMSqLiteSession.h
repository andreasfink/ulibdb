//
//  UMSqLiteSession.h
//  ulibdb.framework
//
//  Created by Andreas Fink on 25.10.11.
//  Copyright (c) 2011 Andreas Fink

#import "UMDbSession.h"

#ifdef HAVE_SQLITE

@interface UMSqLiteSession : UMDbSession
{
    int i; 
}

- (UMSqLiteSession *)initWithPool:(UMDbPool *)dbpool;
@end

#endif