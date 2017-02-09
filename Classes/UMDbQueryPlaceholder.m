//
//  UMDbQueryPlaceholder.m
//  ulibdb.framework
//
//  Created by Andreas Fink on 27.10.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.

#import "ulib/ulib.h"
#import "ulibdb_defines.h"
#import "UMDbQueryPlaceholder.h"
#import "UMDbQuery.h"
#import "UMDbDriverType.h"

@implementation UMDbQueryPlaceholder

@synthesize type;
@synthesize index;
@synthesize text;

- (UMDbQueryPlaceholder *)initWithInteger:(int)i
{
    self = [super init];
    if(self)
    {
        index = i;
        type = UMDBPLACEHOLDER_TYPE_INTEGER;
        text = nil;
    }
    return self;
}


- (UMDbQueryPlaceholder *)initWithString:(NSString *)string
{
    self = [super init];
    if(self)
    {
        if (string)
        {
            text = string;
            type = UMDBPLACEHOLDER_TYPE_TEXT;
        }
        else
        {
            type = UMDBPLACEHOLDER_TYPE_NULL;
        }
    }
    return self;
}


- (UMDbQueryPlaceholder *)initWithField:(NSString *)string
{
    self = [super init];
    if(self)
    {
        if (string)
        {
            text = string;
            type = UMDBPLACEHOLDER_TYPE_FIELD;
        }
        else
        {
            type = UMDBPLACEHOLDER_TYPE_NULL;
        }
        
    }
    return self;
}


- (UMDbQueryPlaceholder *)initWithParameterIndex:(int)i
{
    self = [super init];
    if(self)
    {
        index = i;
        type = UMDBPLACEHOLDER_TYPE_PARAM;
    }
    return self;
}


- (UMDbQueryPlaceholder *)initWithPrimaryKeyName
{
    self = [super init];
    if(self)
    {
        type = UMDBPLACEHOLDER_TYPE_PRIMARY_KEY_NAME;
        text = nil;
    }
    return self;
}

- (UMDbQueryPlaceholder *)initWithPrimaryKeyValue
{
    self = [super init];
    if(self)
    {
        type = UMDBPLACEHOLDER_TYPE_PRIMARY_KEY_VALUE;
        text = nil;
    }
    return self;
}

+ (UMDbQueryPlaceholder *)placeholderString:(NSString *)string
{
    return [[UMDbQueryPlaceholder alloc]initWithString:string];
}

+ (UMDbQueryPlaceholder *)placeholderInteger:(int) i
{
    return [[UMDbQueryPlaceholder alloc]initWithInteger:i];
}

+ (UMDbQueryPlaceholder *)placeholderField:(NSString *)string
{
    return [[UMDbQueryPlaceholder alloc]initWithField:string];
}

+ (UMDbQueryPlaceholder *)placeholderParameterIndex:(int)i
{
    return [[UMDbQueryPlaceholder alloc]initWithParameterIndex:i];
}

+ (UMDbQueryPlaceholder *)placeholderPrimaryKeyName
{
    return [[UMDbQueryPlaceholder alloc]initWithPrimaryKeyName];
}

+ (UMDbQueryPlaceholder *)placeholderPrimaryKeyValue
{
    return [[UMDbQueryPlaceholder alloc]initWithPrimaryKeyValue];
}


- (NSString *) sqlForQueryLeft:(UMDbQuery *)query parameters:(NSArray *)params dbType:(UMDbDriverType)dbType
{
    return [self sqlForQueryLeft:query parameters:params dbType:dbType primaryKeyValue:NULL];
}

- (NSString *) sqlForQueryLeft:(UMDbQuery *)query parameters:(NSArray *)params dbType:(UMDbDriverType)dbType primaryKeyValue:(id)primaryKeyValue
{
    switch(type)
    {
        case UMDBPLACEHOLDER_TYPE_PARAM:
        {
            if(params == NULL)
                return @"missing-parameter";
            if(index >= [params count])
                return @"not-enough-parameters-provided";

            id param = params[index];
            if([param isKindOfClass: [NSString class]])
            {
                return [NSString stringWithFormat:@"'%@'",[param sqlEscaped]];
            }
            else if([param isKindOfClass: [NSNumber class]])
            {
                return [param stringValue];
            }
        }
        case UMDBPLACEHOLDER_TYPE_PRIMARY_KEY_VALUE:
        {
            if(primaryKeyValue == NULL)
                return @"missing-primary-key-value";
            
            if([primaryKeyValue isKindOfClass: [NSString class]])
            {
                return [NSString stringWithFormat:@"'%@'",[primaryKeyValue sqlEscaped]];
            }
            else if([primaryKeyValue isKindOfClass: [NSNumber class]])
            {
                return @"primary-key-value-is-not-a-string";
            }
        }
        case UMDBPLACEHOLDER_TYPE_FIELD:
        {
            if ([text length] == 0)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Left condition is empty, cannot create query" userInfo:nil];
            }
            else if(dbType==UMDBDRIVER_MYSQL)
            {
                return [NSString stringWithFormat:@"`%@`",text];
            }
            else if(dbType==UMDBDRIVER_PGSQL)
            {
                return [NSString stringWithFormat:@"%@",text];
            }
            else
            {
                return [NSString stringWithFormat:@"%@",text];
            }
        }
        case UMDBPLACEHOLDER_TYPE_PRIMARY_KEY_NAME:
        {
            if ([query.primaryKeyName length] == 0)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Left condition is empty, cannot create query" userInfo:nil];
            }
            else if(dbType==UMDBDRIVER_MYSQL)
            {
                return [NSString stringWithFormat:@"`%@`",query.primaryKeyName];
            }
            else if(dbType==UMDBDRIVER_PGSQL)
            {
                return [NSString stringWithFormat:@"%@",query.primaryKeyName];
            }
            else
            {
                return [NSString stringWithFormat:@"%@",query.primaryKeyName];
            }
        }

        case UMDBPLACEHOLDER_TYPE_INTEGER:
        {
            return [NSString stringWithFormat:@"%d" ,index];
        }
        case UMDBPLACEHOLDER_TYPE_NULL:
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Left condition is nil, cannot create query" userInfo:nil];
        }
        case UMDBPLACEHOLDER_TYPE_TEXT:
        default:
        {
            return [NSString stringWithFormat:@"'%@'" ,[text sqlEscaped]];
        }
    }
}


- (NSString *) sqlForQueryRight:(UMDbQuery *)query parameters:(NSArray *)params dbType:(UMDbDriverType)dbType primaryKeyValue:(id)primaryKeyValue;

{
    switch(type)
    {
        case UMDBPLACEHOLDER_TYPE_PARAM:
        {
            if(params == NULL)
                return @"missing-parameter";
            if(index >= [params count])
                return @"not-enough-parameters-provided";
            
            id param = params[index];
            if([param isKindOfClass: [NSString class]])
            {
                return [NSString stringWithFormat:@"'%@'",[param sqlEscaped]];
            }
            else if([param isKindOfClass: [NSNumber class]])
            {
                return [param stringValue];
            }
        }
        case UMDBPLACEHOLDER_TYPE_FIELD:
        {
            if ([text length] == 0)
                return @"";
            else
                if(dbType==UMDBDRIVER_MYSQL)
                {
                    return [NSString stringWithFormat:@"\"%@\"",text];
                }
                else if(dbType==UMDBDRIVER_PGSQL)
                {
                    return [NSString stringWithFormat:@"'%@'",text];
                }
                else
                {
                    return [NSString stringWithFormat:@"%@",text];
                }
        }
        case UMDBPLACEHOLDER_TYPE_INTEGER:
        {
            return [NSString stringWithFormat:@"%d" ,index];
        }
        case UMDBPLACEHOLDER_TYPE_NULL:
        {
            return @"NULL";
        }
        case UMDBPLACEHOLDER_TYPE_PRIMARY_KEY_NAME:
        {
            {
                if ([text length] == 0)
                    return @"";
                else
                    if(dbType==UMDBDRIVER_MYSQL)
                    {
                        return [NSString stringWithFormat:@"\"%@\"",text];
                    }
                    else if(dbType==UMDBDRIVER_PGSQL)
                    {
                        return [NSString stringWithFormat:@"'%@'",text];
                    }
                    else
                    {
                        return [NSString stringWithFormat:@"%@",text];
                    }
            }
        }
        case UMDBPLACEHOLDER_TYPE_PRIMARY_KEY_VALUE:
        {
            return [NSString stringWithFormat:@"'%@'" ,[primaryKeyValue sqlEscaped]];
        }

        case UMDBPLACEHOLDER_TYPE_TEXT:
        default:
        {
            return [NSString stringWithFormat:@"'%@'" ,[text sqlEscaped]];
        }
    }
}

- (NSString *) description
{
    NSMutableString *s = [[NSMutableString alloc]init];
    switch(type)
    {
        case UMDBPLACEHOLDER_TYPE_PARAM:
        {
            [s appendFormat:@"PARAM(%d)",index];
            break;
        }
        case UMDBPLACEHOLDER_TYPE_FIELD:
        {
            [s appendFormat:@"FIELD(%@)",text];
            break;
        }
        case UMDBPLACEHOLDER_TYPE_TEXT:
        { 
            [s appendFormat:@"TEXT(%@)",text];
            break;
        }
        case UMDBPLACEHOLDER_TYPE_INTEGER:
        { 
            [s appendFormat:@"INT(%d)",index];
            break;
        }
        case UMDBPLACEHOLDER_TYPE_NULL:
        { 
            [s appendFormat:@"NULL"];
            break;
        }
        case UMDBPLACEHOLDER_TYPE_PRIMARY_KEY_NAME:
        {
            [s appendFormat:@"PRIMARY_KEY_NAME"];
            break;
        }
        case UMDBPLACEHOLDER_TYPE_PRIMARY_KEY_VALUE:
        {
            [s appendFormat:@"PRIMARY_KEY_VALUE"];
            break;
        }
        default:
        {
            [s appendFormat:@"BOGOUS"];
        }
    }
    return s;
}   

@end
