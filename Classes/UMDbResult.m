//
//  UMDbResult.m
//  ulibdb.framework
//
//  Created by Andreas Fink on 24.10.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.

#import <ulib/ulib.h>
#import "ulibdb_defines.h"
#import "UMDbResult.h"

@implementation UMDbResult
@synthesize affectedRows;
@synthesize columNames;
@synthesize resultArray;


- (id)initForFile:(const char *)file line:(long)line
{
    @autoreleasepool
    {
//        NSString *fileName = @(file);
//        fileName = [fileName lastPathComponent];
#pragma unused(file)
        self = [super init];
        if(self)
        {
            resultArray = [[NSMutableArray alloc]init];
            columNames  = [[NSMutableArray alloc]init];
        }
        return self;
    }
}

- (id)init
{
    self = [super init];
    if(self)
    {
        resultArray = [[NSMutableArray alloc]init];
        columNames  = [[NSMutableArray alloc]init];
    }
    return self;
}

- (NSString*) description
{
	NSMutableString *s;
	s = [[NSMutableString alloc] initWithFormat:@"UMDbResult: index pointer: %ld\n",
         indexPointer];
    [s appendFormat:@"affectedRows: %lld\n", affectedRows];
    [s appendFormat:@"result array: %@\n", resultArray];
    [s appendFormat:@"column names: %@\n", columNames];
	return s;
}

- (void)addRow:(NSArray *)arr
{
    [resultArray addObject:arr];
}

- (void)addRow:(id)o columName:(NSString *)name
{
    [resultArray addObject:o];
    [columNames addObject:name];

}

- (void)setRow:(NSArray *)arr forIndex:(long)idx
{
    @autoreleasepool
    {
        if(idx == [resultArray count])
        {
            [resultArray addObject:arr];
        }
        else if(idx < [resultArray count])
        {
            resultArray[idx] = arr;
        }
        else
        {
            while([resultArray count] < (idx-1))
            {
                [resultArray addObject:[NSNull null]];
            }
            [resultArray addObject:arr];
        }
    }
}

- (void)setColumName:(NSString *)n forIndex:(long)idx
{
    @autoreleasepool
    {
        if(idx == [columNames count])
        {
            [columNames addObject:n];
        }
        else if(idx < [columNames count])
        {
            columNames[idx] = n;
        }
        else
        {
            while([columNames count] < (idx-1))
            {
                [columNames addObject:[NSNull null]];
            }
            [columNames addObject:n];
        }
    }

}

- (NSUInteger)rowsCount
{
    return [resultArray count];
}

- (NSUInteger)columsCount
{
    return [columNames count];
}

- (id)getRow:(long)idx
{
    if(idx >= [resultArray count])
    {
        return NULL;
    }
    return (id)resultArray[idx];
}

- (id)fetchRow
{
    return [self getRow:indexPointer++];
}

- (NSDictionary *)fetchRowAsDictionary
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    NSArray *row = [self fetchRow];
    for(NSInteger i=0;i<row.count;i++)
    {
        id value = row[i];
        id name = columNames[i];
        if(value == NULL)
        {
            value = [NSNull null];
        }
        if(name==NULL)
        {
            name = @(i);
        }
        dict[name] = value;
    }
    return dict;
}

- (void)reset
{
    indexPointer = 0;
}

@end
