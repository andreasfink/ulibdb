//
//  NSString+SQL.m
//  ulibdb
//
//  Created by Andreas Fink on 01.12.17.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.
//

#import "NSString+SQL.h"
#import "UMDbSession.h"

@implementation NSString (SQL)

- (NSString *)sqlEscaped:(UMDbSession *)session
{
    if(session)
    {
        return [session sqlEscapeString:self];
    }
    else
    {
        return [self sqlEscaped];
    }
}

@end

