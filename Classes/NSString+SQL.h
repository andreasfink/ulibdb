//
//  NSString+SQL.h
//  ulibdb
//
//  Created by Andreas Fink on 01.12.17.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.
//

#import <ulib/ulib.h>

@class UMDbSession;

@interface NSString (SQL)
- (NSString *)sqlEscaped:(UMDbSession *)session;   /*!< escape characters for SQL */
@end
