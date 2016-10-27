//
//  UMDbResult.h
//  ulibdb.framework
//
//  Created by Andreas Fink on 24.10.11.
//  Copyright (c) 2011 Andreas Fink

#import "ulib/ulib.h"

@interface UMDbResult : UMObject
{
    long            indexPointer;
    long long       affectedRows;    
    NSMutableArray *resultArray;
    NSMutableArray *columNames;
}

@property (readwrite,assign) long long affectedRows;
@property (readwrite,strong) NSMutableArray *columNames;
@property (readwrite,strong) NSMutableArray *resultArray;

- (id)initForFile:(const char *)file line:(long)line;
- (void)addRow:(NSArray *)arr;
- (void)setRow:(NSArray *)arr forIndex:(long)idx;
- (void)setColumName:(NSString *)name forIndex:(long)idx;
- (id)getRow:(long)idx;
- (id)fetchRow;
- (void) reset;
- (NSUInteger)rowsCount;
- (NSUInteger)columsCount;
@end
