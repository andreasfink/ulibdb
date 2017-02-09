//
//  UMDbQuery.m
//  ulibdb.framework
//
//  Created by Andreas Fink on 26.10.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.

#import "ulib/ulib.h"
#import "ulibdb_defines.h"
#import "UMDbSession.h"
#import "UMDbQuery.h"
#import "UMDbQueryCondition.h"
#import "UMDbRedisSession.h"
#import "UMDbFileSession.h"

@implementation UMDbQuery

static NSMutableDictionary *cachedQueries = NULL;

@synthesize isInCache;
@synthesize storageType;
@synthesize cfile;
@synthesize cline;

- (UMDbQuery *)init
{
    return [self initWithCacheKey:NULL];
}


- (UMDbQuery *)initWithCacheKey:(NSString *)ck
{
    self=[super init];
    if(self)
    {
        type = UMDBQUERYTYPE_UNKNOWN;
        cacheKey = nil;
        table = nil;
        whereCondition = nil;
        grouping = nil;
        sortByFields = nil;
        fields = nil;
        limit = 0; /* means no limit*/
        isInCache = NO;
        cacheKey = ck;
        storageType = UMDBSTORAGE_JSON;
    }
    return self;
}


- (UMDbStorageType)storageType
{
    return storageType;
}

- (void)setStorageType:(UMDbStorageType)xstorageType
{
    UMAssert(!isInCache, @"attempting to modify storageType of cached query");
    storageType= xstorageType;
}


- (NSString *) instance
{
    return instance;
}

- (void)setInstance:(NSString *)xinstance
{
    UMAssert(!isInCache, @"attempting to modify instance of cached query");
    instance= xinstance;
}

- (UMDbQueryType) type
{
    return type;
}

- (void)setType:(UMDbQueryType)xtype
{
    UMAssert(!isInCache, @"attempting to modify type of cached query");
    type= xtype;
}


- (UMDbQueryCondition *)whereCondition
{
    return whereCondition;
}

- (void)setWhereCondition:(UMDbQueryCondition *)xwhereCondition
{
    UMAssert(!isInCache, @"attempting to modify whereCondition of cached query");
    whereCondition = xwhereCondition;
}

- (NSString *)primaryKeyName
{
    return primaryKeyName;
}

- (void)setPrimaryKeyName:(NSString *)xprimaryKeyName
{
    UMAssert(!isInCache, @"attempting to modify primaryKeyName of cached query");
    primaryKeyName = xprimaryKeyName;
}


- (UMDbTable *)table
{
    return table;
}

- (void)setTable:(UMDbTable *)xtable
{
    UMAssert(!isInCache, @"attempting to modify table of cached query");
    table = xtable;
}

- (NSString *)databaseName
{
    return databaseName;
}


- (void)setDatabaseName:(NSString *)xdatabaseName
{
    UMAssert(!isInCache, @"attempting to modify databaseName of cached query");
    databaseName = xdatabaseName;
}



- (NSString *)grouping
{
    return grouping;
}


- (void)setGrouping:(NSString *)xgrouping
{
    UMAssert(!isInCache, @"attempting to modify grouping of cached query");
    grouping = xgrouping;
}

- (NSArray *)sortByFields
{
    return sortByFields;
}


- (void)setSortByFields:(NSArray *)xsortByFields
{
    UMAssert(!isInCache, @"attempting to modify sortByFields of cached query");
    sortByFields = xsortByFields;
}

- (NSArray *)fields
{
    return fields;
}


- (void)setFields:(NSArray *)xfields
{
    UMAssert(!isInCache, @"attempting to modify sortByFields of cached query");
    fields = xfields;
}

- (NSArray *)keys
{
    return keys;
}


- (void)setKeys:(NSArray *)xkeys
{
    UMAssert(!isInCache, @"attempting to modify keys of cached query");
    keys = xkeys;
}

- (int) limit
{
    return limit;
}


- (void)setLimit:(int)xlimit
{
    UMAssert(!isInCache, @"attempting to modify limit of cached query");
    limit = xlimit;
}



+ (UMDbQuery *)queryForFile:(const char *)file
                       line:(const long)line
{
    @autoreleasepool
    {
        NSString *key2 = [NSString stringWithFormat:@"%s:%ld",file,line];
        
        UMDbQuery *query = NULL;
        @synchronized(cachedQueries)
        {
            if(cachedQueries==NULL)
            {
                cachedQueries = [[NSMutableDictionary alloc]init];
            }
            query = cachedQueries[key2];
            if(query)
            {
                return query;
            }
            query = [[UMDbQuery alloc] initWithCacheKey:key2];
            query.cfile = file;
            query.cline = line;
        }
        return query;
    }
}


- (void)addToCache
{
    @synchronized(cachedQueries)
    {
        if(cachedQueries==NULL)
        {
            cachedQueries = [[NSMutableDictionary alloc]init];
        }
        cachedQueries[cacheKey] = self;
        isInCache = YES;
    }
}

-(void)addToCacheWithKey:(NSString *)key2
{
    @synchronized(cachedQueries)
    {
        cacheKey = key2;
        if(cachedQueries==NULL)
        {
            cachedQueries = [[NSMutableDictionary alloc]init];
        }
        isInCache = YES;
        cachedQueries[cacheKey] = self;
    }
}

- (NSString *)selectForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    return [self selectForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue whereCondition:whereCondition];
}

- (NSString *)selectForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue whereCondition:(UMDbQueryCondition *)whereCondition1;
{
    @autoreleasepool
    {
        NSMutableString *sql =[[NSMutableString alloc]initWithString:@"SELECT "];
        BOOL first = YES;
        
        for(NSString *field in fields)
        {
            if(first)
            {
                if ([field length] == 0)
                {
                    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Fields are empty, cannot create query" userInfo:nil];
                }
                else if ([field compare:@"*"] == NSOrderedSame)
                {
                    [sql appendFormat:@"%@",field];
                }
                else
                {
                    if(dbDriverType==UMDBDRIVER_MYSQL)
                        [sql appendFormat:@"`%@`",field];
                    else if(dbDriverType==UMDBDRIVER_PGSQL)
                        [sql appendFormat:@"\"%@\"",field];
                    else
                        [sql appendFormat:@"%@",field];
                }
                first = NO;
            }
            else
            {
                if(dbDriverType==UMDBDRIVER_MYSQL)
                    [sql appendFormat:@",`%@`",field];
                else if(dbDriverType==UMDBDRIVER_PGSQL)
                    [sql appendFormat:@",\"%@\"",field];
                else
                    [sql appendFormat:@", %@",field];
            }
        }
        if (!fields)
        {
            if (dbDriverType==UMDBDRIVER_MYSQL)
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Fields are nil,cannot create MySQL query" userInfo:nil];
            else
                [sql appendString:@"NULL"];
        }
        if (!table || (table && ![table tableName])) 
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Table name is nil, cannot create query" userInfo:nil];
        }
        else if ([[table tableName] length] == 0)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"table name empty, cannot create query" userInfo:nil];
        }
        else
        {
            if(dbDriverType==UMDBDRIVER_PGSQL)
                [sql appendFormat:@" FROM %@",[table tableName]];
            else
                [sql appendFormat:@" FROM %@",[table tableName]];
        }
        if(whereCondition1)
        {
            NSString *where = [whereCondition1 sqlForQuery:self parameters:params dbType:dbDriverType primaryKeyValue:primaryKeyValue];
            [sql appendFormat:@" WHERE %@",where];
        }
        if(grouping)
        {
            [sql appendFormat:@" GROUP BY %@",grouping];
        }
        if(sortByFields)
        {

            BOOL first = YES;
            for (NSString *field in sortByFields)
            {
                if(!first)
                {
                    [sql appendString:@","];
                }
                else
                {
                    [sql appendString:@" ORDER BY "];
                    first = NO;
                }
                if(dbDriverType==UMDBDRIVER_PGSQL)
                {
                    [sql appendFormat:@"\"%@\"",field];
                }
                else if(dbDriverType==UMDBDRIVER_MYSQL)
                {
                    [sql appendFormat:@"`%@`",field];
                }
                else
                {
                    [sql appendFormat:@"%@",field];
                }
            }
        }
        if(limit)
        {
            [sql appendFormat:@" LIMIT %d",limit];
        }
        return sql;
    }
}

- (NSString *)deleteForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    return [self deleteForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue whereCondition:whereCondition];
}

- (NSString *)deleteForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue whereCondition:(UMDbQueryCondition *)whereCondition1
{
    @autoreleasepool
    {
        NSMutableString *sql;
        
        if (!table || (table && ![table tableName]))
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Delete with table name nil, cannot create query" userInfo:nil];
        if ([[table tableName] length] == 0)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Delete with empty table name, cannot create query" userInfo:nil];
        sql=[[NSMutableString alloc]initWithFormat:@"DELETE FROM %@",[table tableName]];
        if(whereCondition1)
        {
            NSString *where = [whereCondition1 sqlForQuery:self parameters:params dbType:dbDriverType primaryKeyValue:primaryKeyValue];
            [sql appendFormat:@" WHERE %@",where];
        }
        if(limit)
        {
            if(dbDriverType==UMDBDRIVER_MYSQL)
            {
                [sql appendFormat:@" LIMIT %d",limit];
            }
            /*PGSQL does not support LIMIT on delete */
        }
        return sql;
    }
}

- (NSString *)insertForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params  primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        NSMutableString *sql = NULL;
        
        if (!table)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Inserting with nil table, cannot create query" userInfo:nil];
        }
        if (![table tableName])
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Inserting with nil table name, cannot create query" userInfo:nil];
        }
        if ([[table tableName] length] == 0)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Inserting with empty table name, cannot create query" userInfo:nil];
        }
        if(dbDriverType == UMDBDRIVER_PGSQL)
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"INSERT INTO public.%@",[table tableName]];
        }
        else
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"INSERT INTO %@",[table tableName]];
        }
        BOOL first = YES;
        if (!fields)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Inserting with nil fields table, cannot create query" userInfo:nil];
        }
        if ([fields count] == 0)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Inserting with an empty fields table, cannot create query" userInfo:nil];
        }
        for(NSString *field in fields)
        {
            if (!field)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Inserting with nil fields, cannot create query" userInfo:nil];
            }
            if ([field length] == 0)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Inserting with empty fields, cannot create query" userInfo:nil];
            }
            if(dbDriverType == UMDBDRIVER_PGSQL)
            {
                if(first)
                {
                    [sql appendFormat:@"(\"%@\"",field];
                    first = NO;
                }
                else
                {
                    [sql appendFormat:@",\"%@\"",field];
                }
            }
            else
            {
                if(first)
                {
                    [sql appendFormat:@"(`%@`",field];
                    first = NO;
                }
                else
                {
                    [sql appendFormat:@",`%@`",field];
                }
            }
        }
        [sql appendFormat:@") VALUES ("];
        NSUInteger n = [fields count];
        if (!params)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Inserting with nil params table, cannot create query" userInfo:nil];
        }
        if ([params count] == 0)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Inserting with an empty params table, cannot create query" userInfo:nil];
        }
        if ([params count] != n)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"count of fields is not equal to count of parameters" userInfo:nil];
        }
        for(int i=0;i<n;i++)
        {
            if(i!=0)
            {
                [sql appendString:@","];
            }
            id param = params[i];
            if (param==NULL)
            {
                [sql appendString:@"NULL"];
            }
            else if([param isKindOfClass: [NSNull class]])
            {
                [sql appendString:@"NULL"];
            }
            else if([param isKindOfClass: [NSString class]])
            {
                NSString *s = [NSString stringWithString:param];
                NSString *escaped = [s sqlEscaped];
                [sql appendFormat:@"'%@'",escaped];
            }
            else if([param isKindOfClass: [NSNumber class]])
            {
                [sql appendFormat:@"'%@'",param];
            }
            else if([param isKindOfClass: [NSDate class]])
            {
                NSString *s = [NSString stringWithStandardDate:param];
                [sql appendFormat:@"'%@'",s];
            }
            else if([param isKindOfClass: [NSArray class]])
            {
                [sql appendFormat:@"'%@'",[[param componentsJoinedByString:@" "]sqlEscaped]];
            }
            else
            {
                [sql appendString:@"''"];
            }
        }
        [sql appendString:@")"];
        return sql;
    }
}


- (NSString *)updateByKeyLikeForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params  primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        switch(dbDriverType)
        {
            case UMDBDRIVER_MYSQL:
            case UMDBDRIVER_PGSQL:
            case UMDBDRIVER_SQLITE:
            {
                UMDbQueryCondition *whereCondition1 =  [UMDbQueryCondition queryConditionLeft:
                                                        [UMDbQueryPlaceholder placeholderPrimaryKeyName]
                                                                                           op:UMDBQUERY_OPERATOR_LIKE
                                                                                        right:[UMDbQueryPlaceholder placeholderPrimaryKeyValue]];
                return [self updateForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue whereCondition:whereCondition1];
            }
                break;
            case UMDBDRIVER_REDIS:
                return [UMDbRedisSession updateByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_FILE:
                return [UMDbFileSession updateByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            default:
                return NULL;
        }
    }
}

- (NSString *)updateByKeyForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        switch(dbDriverType)
        {
            case UMDBDRIVER_MYSQL:
            case UMDBDRIVER_PGSQL:
            case UMDBDRIVER_SQLITE:
            {
                UMDbQueryCondition *whereCondition1 =
                [UMDbQueryCondition queryConditionLeft:[UMDbQueryPlaceholder placeholderField:primaryKeyName]
                                                    op:UMDBQUERY_OPERATOR_EQUAL
                                                 right:[UMDbQueryPlaceholder placeholderPrimaryKeyValue]];
                
                //return [self updateForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                return [self updateForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue whereCondition:whereCondition1];
            }
                break;
            case UMDBDRIVER_REDIS:
                return [UMDbRedisSession updateByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_FILE:
                return [UMDbFileSession updateByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            default:
                return NULL;
        }
    }
}


- (NSString *)selectByKeyForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        switch(dbDriverType)
        {
            case UMDBDRIVER_MYSQL:
            case UMDBDRIVER_PGSQL:
            case UMDBDRIVER_SQLITE:
            {
                UMDbQueryCondition *whereCondition1 =  [UMDbQueryCondition queryConditionLeft:[UMDbQueryPlaceholder placeholderField:primaryKeyName]
                                                                                           op:UMDBQUERY_OPERATOR_EQUAL
                                                                                        right:[UMDbQueryPlaceholder placeholderPrimaryKeyValue]];
                return [self selectForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue whereCondition:whereCondition1];
            }
                break;
            case UMDBDRIVER_REDIS:
                return [UMDbRedisSession selectByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_FILE:
                return [UMDbFileSession selectByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            default:
                return NULL;
        }
    }
}


- (NSString *)selectByKeyFromListForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        switch(dbDriverType)
        {
            case UMDBDRIVER_MYSQL:
            case UMDBDRIVER_PGSQL:
            case UMDBDRIVER_SQLITE:
            {
                UMDbQueryCondition *whereCondition1 =  [UMDbQueryCondition queryConditionLeft:[UMDbQueryPlaceholder placeholderField:primaryKeyName]
                                                                                           op:UMDBQUERY_OPERATOR_EQUAL
                                                                                        right:[UMDbQueryPlaceholder placeholderPrimaryKeyValue]];
                return [self selectForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue whereCondition:whereCondition1];
            }
                break;
                break;
            case UMDBDRIVER_REDIS:
                return [UMDbRedisSession selectByKeyLikeForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_FILE:
                return [UMDbFileSession selectByKeyLikeForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            default:
                return NULL;
        }
    }
}


- (NSString *)selectByKeyLikeForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        switch(dbDriverType)
        {
            case UMDBDRIVER_MYSQL:
            case UMDBDRIVER_PGSQL:
            case UMDBDRIVER_SQLITE:
            {
                UMDbQueryCondition *whereCondition1 =  [UMDbQueryCondition queryConditionLeft:[UMDbQueryPlaceholder placeholderField:primaryKeyName]
                                                                                           op:UMDBQUERY_OPERATOR_LIKE
                                                                                        right:[UMDbQueryPlaceholder placeholderPrimaryKeyValue]];
                return [self selectForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue whereCondition:whereCondition1];
            }
                break;
                break;
            case UMDBDRIVER_REDIS:
                return [UMDbRedisSession selectByKeyLikeForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_FILE:
                return [UMDbFileSession selectByKeyLikeForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            default:
                return NULL;
        }
    }
}



- (NSString *)insertByKeyForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        switch(dbDriverType)
        {
            case UMDBDRIVER_MYSQL:
            case UMDBDRIVER_PGSQL:
            case UMDBDRIVER_SQLITE:
                return [self insertForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_REDIS:
                @throw([NSException exceptionWithName:@"do we use this branch ever?"
                                               reason:NULL
                                             userInfo:@{
                                                        @"sysmsg" : @"do we use this branch ever?",
                                                        @"func": @(__func__),
                                                        @"err": @(-1)
                                                        }]);

                return [UMDbRedisSession insertByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_FILE:
                return [UMDbFileSession insertByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            default:
                return NULL;
        }
    }
}

- (NSString *)insertByKeyToListForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        switch(dbDriverType)
        {
            case UMDBDRIVER_MYSQL:
            case UMDBDRIVER_PGSQL:
            case UMDBDRIVER_SQLITE:
                return [self insertForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_REDIS:
                @throw([NSException exceptionWithName:@"do we need this branch ever?"
                                               reason:NULL
                                             userInfo:@{
                                                        @"sysmsg" : @"do we need this branch ever?",
                                                        @"func": @(__func__),
                                                        @"err": @(-1)
                                                        }]);
                return [UMDbRedisSession insertByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_FILE:
                return [UMDbFileSession insertByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            default:
                return NULL;
        }
    }
}

- (NSString *)deleteByKeyForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        switch(dbDriverType)
        {
            case UMDBDRIVER_MYSQL:
            case UMDBDRIVER_PGSQL:
            case UMDBDRIVER_SQLITE:
            {
                UMDbQueryCondition *whereCondition1 =  [UMDbQueryCondition queryConditionLeft:[UMDbQueryPlaceholder placeholderField:primaryKeyName]
                                                                                           op:UMDBQUERY_OPERATOR_EQUAL
                                                                                        right:[UMDbQueryPlaceholder placeholderPrimaryKeyValue]];
                return [self deleteForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue whereCondition:whereCondition1];
            }
                break;
            case UMDBDRIVER_REDIS:
                return [UMDbRedisSession deleteByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_FILE:
                return [UMDbFileSession deleteByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            default:
                return NULL;
        }
    }
}


- (NSString *)deleteByKeyAndValueForType:(UMDbDriverType)dbDriverType
                              parameters:(NSArray *)params
                         primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        switch(dbDriverType)
        {
            case UMDBDRIVER_MYSQL:
            case UMDBDRIVER_PGSQL:
            case UMDBDRIVER_SQLITE:
            {
                UMDbQueryCondition *condition1 =  [UMDbQueryCondition queryConditionLeft:[UMDbQueryPlaceholder placeholderField:primaryKeyName]
                                                                                      op:UMDBQUERY_OPERATOR_EQUAL
                                                                                   right:[UMDbQueryPlaceholder placeholderPrimaryKeyValue]];
                UMDbQueryCondition *condition2 =  [UMDbQueryCondition queryConditionLeft:[UMDbQueryPlaceholder placeholderField:fields[0]]
                                                                                      op:UMDBQUERY_OPERATOR_EQUAL
                                                                                   right:[UMDbQueryPlaceholder placeholderParameterIndex:0]];
                UMDbQueryCondition *whereCondition1 =  [UMDbQueryCondition queryConditionLeft:condition1
                                                                                           op:UMDBQUERY_OPERATOR_AND
                                                                                        right:condition2];
                
                
                return [self deleteForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue whereCondition:whereCondition1];
            }
                break;
            case UMDBDRIVER_REDIS:
                return [UMDbRedisSession deleteByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBDRIVER_FILE:
                return [UMDbFileSession deleteByKeyForQuery:self params:params primaryKeyValue:primaryKeyValue];
                break;
            default:
                return NULL;
        }
    }
}


- (NSString *)updateForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    return [self updateForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue whereCondition:whereCondition];
}

- (NSString *)updateForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue whereCondition:(UMDbQueryCondition *)whereCondition1
{
    @autoreleasepool
    {
        NSMutableString *sql;
        
        if (!table)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Updating with nil table, cannot create query" userInfo:nil];
        }
        if (![table tableName])
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Updating with nil table name, cannot create query" userInfo:nil];
        }
        if ([[table tableName] length] == 0)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Updating with empty table name, cannot create query" userInfo:nil];
        }
        
        if(dbDriverType == UMDBDRIVER_PGSQL)
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"UPDATE %@",[table tableName]];
        }
        else if(dbDriverType == UMDBDRIVER_MYSQL)
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"UPDATE `%@`",[table tableName]];
        }
        else
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"UPDATE %@",[table tableName]];
        }
        BOOL first = YES;
        int i = 0;
        if (!fields)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Updating with nil fields table, cannot create query" userInfo:nil];
        }
        if ([fields count] == 0)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Updating with an empty fields table, cannot create query" userInfo:nil];
        }
        if (!params)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Updating with nil params table, cannot create query" userInfo:nil];
        }
        if ([params count] == 0)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Updating with an empty params table, cannot create query" userInfo:nil];
        }
        for(NSString *field in fields)
        {
            if (!field)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Updating with nil fields, cannot create query" userInfo:nil];
            }
            if ([field length] == 0)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Updating with empty fields, cannot create query" userInfo:nil];
            }
            id param = params[i++];
            if(dbDriverType == UMDBDRIVER_PGSQL)
            {
                if(first)
                {
                    [sql appendFormat:@" SET \"%@\"=",field];
                    first = NO;
                }
                else
                {
                    [sql appendFormat:@", \"%@\"=",field];
                }
            }
            else
            {
                if(first)
                {
                    [sql appendFormat:@" SET `%@`=",field];
                    first = NO;
                }
                else
                {
                    [sql appendFormat:@", `%@`=",field];
                }
            }
            if(param == NULL)
            {
                [sql appendString:@"NULL"];
            }
            else if([param isKindOfClass: [NSNull class]])
            {
                [sql appendString:@"NULL"];
            }
            else if([param isKindOfClass: [NSString class]])
            {
                NSString *s = (NSString *)param;
                [sql appendFormat:@"'%@'",[s sqlEscaped]];
            }
            else if([param isKindOfClass: [NSNumber class]])
            {
                [sql appendFormat:@"'%@'",[param stringValue]];
            }
            else if([param isKindOfClass: [NSArray class]])
            {
                [sql appendFormat:@"'%@'",[[param componentsJoinedByString:@" "]sqlEscaped]];
            }
            else if([param isKindOfClass: [NSDate class]])
            {
                NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                NSString *s = [dateFormatter stringFromDate:param];
                [sql appendFormat:@"'%@'",[s sqlEscaped]];
            }
        }
        
        if(whereCondition1)
        {
            NSString *where = [whereCondition1 sqlForQuery:self parameters:params dbType:dbDriverType primaryKeyValue:primaryKeyValue];
            [sql appendFormat:@" WHERE %@",where];
        }
        else
        {
            NSLog(@"PANIC: UPDATE without WHERE condition");
            __builtin_trap();
        }
        return sql;
    }
}

- (NSString *)increaseByKeyForType:(UMDbDriverType)dbDriverType
                        parameters:(NSArray *)params
                   primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        
        NSMutableString *sql=NULL;
        
        if(dbDriverType == UMDBDRIVER_PGSQL)
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"UPDATE public.%@",[table tableName]];
        }
        else if(dbDriverType == UMDBDRIVER_MYSQL)
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"UPDATE `%@`",[table tableName]];
        }
        else
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"UPDATE %@",[table tableName]];
        }
        BOOL first = YES;
        int i = 0;
        for(NSString *field in fields)
        {
            double increase = [params[i++]doubleValue];
            char op;
            if((increase > -0.00000001) & (increase < 0.00000001))
                continue;
            if(increase >= 0)
            {
                op = '+';
            }
            else
            {
                op = '-';
                increase = -increase;
            }
            if(dbDriverType == UMDBDRIVER_PGSQL)
            {
                if(first)
                {
                    [sql appendFormat:@" SET \"%@\"=\"%@\"%c%lf",field,field,op,increase];
                    first = NO;
                }
                else
                {
                    [sql appendFormat:@", \"%@\"=\"%@\"%c%lf",field,field,op,increase];
                }
            }
            else
            {
                if(first)
                {
                    [sql appendFormat:@" SET `%@`=`%@`%c%lf",field,field,op,increase];
                    first = NO;
                }
                else
                {
                    [sql appendFormat:@", `%@`=`%@`%c%lf",field,field,op,increase];
                }
            }
        }
        if(first)
        {
            return NULL; /* nothing to update */
        }
        if(primaryKeyName)
        {
            NSString *where = [whereCondition sqlForQuery:self parameters:params dbType:dbDriverType primaryKeyValue:primaryKeyValue];
            [sql appendFormat:@" WHERE %@",where];
        }
        else
        {
            NSLog(@"PANIC: INCREASE BY KEY without primaryKeyName set");
            __builtin_trap();
        }
        return sql;
    }
}

- (NSString *)increaseForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    @autoreleasepool
    {
        NSMutableString *sql=NULL;
        
        if(dbDriverType == UMDBDRIVER_PGSQL)
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"UPDATE public.%@",[table tableName]];
        }
        else if(dbDriverType == UMDBDRIVER_MYSQL)
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"UPDATE `%@`",[table tableName]];
        }
        else
        {
            sql  =[[NSMutableString alloc]initWithFormat:@"UPDATE %@",[table tableName]];
        }
        BOOL first = YES;
        int i = 0;
        for(NSString *field in fields)
        {
            double increase = [params[i++]doubleValue];
            char op;
            if((increase > -0.00000001) & (increase < 0.00000001))
                continue;
            if(increase >= 0)
            {
                op = '+';
            }
            else
            {
                op = '-';
                increase = -increase;
            }
            if(dbDriverType == UMDBDRIVER_PGSQL)
            {
                if(first)
                {
                    [sql appendFormat:@" SET \"%@\"=\"%@\"%c%lf",field,field,op,increase];
                    first = NO;
                }
                else
                {
                    [sql appendFormat:@", \"%@\"=\"%@\"%c%lf",field,field,op,increase];
                }
            }
            else
            {
                if(first)
                {
                    [sql appendFormat:@" SET `%@`=`%@`%c%lf",field,field,op,increase];
                    first = NO;
                }
                else
                {
                    [sql appendFormat:@", `%@`=`%@`%c%lf",field,field,op,increase];
                }
            }
        }
        if(first)
        {
            return NULL; /* nothing to update */
        }
        if(whereCondition)
        {
            NSString *where = [whereCondition sqlForQuery:self parameters:params dbType:dbDriverType primaryKeyValue:primaryKeyValue];
            [sql appendFormat:@" WHERE %@",where];
        }
        else
        {
            NSLog(@"PANIC: INCREASE without WHERE");
            __builtin_trap();
        }
        return sql;
    }
}

- (NSString *)showForType:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:primaryKeyValue
{
    return @"";
}

- (NSString *)sqlForType:(UMDbQueryType)dbQueryType forDriver:(UMDbDriverType)dbDriverType parameters:(NSArray *)params  primaryKeyValue:(id)primaryKeyValue;
{
    @autoreleasepool
    {
        NSString *sql = @"";
        switch (dbQueryType)
        {
            case UMDBQUERYTYPE_SELECT:
                sql = [self selectForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_SELECT_BY_KEY:
                sql = [self selectByKeyForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_SELECT_BY_KEY_LIKE:
            case UMDBQUERYTYPE_SELECT_LIST_BY_KEY_LIKE:
                sql = [self selectByKeyLikeForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_SELECT_BY_KEY_FROM_LIST:
                sql = [self selectByKeyFromListForType:dbDriverType parameters:params  primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_DELETE:
                sql = [self deleteForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_DELETE_BY_KEY:
                sql = [self deleteByKeyForType:dbDriverType parameters:params  primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_DELETE_IN_LIST_BY_KEY_AND_VALUE:
                sql = [self deleteByKeyAndValueForType:dbDriverType parameters:params  primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_INSERT:
                sql = [self insertForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_INSERT_BY_KEY:
                sql = [self insertByKeyForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_INSERT_BY_KEY_TO_LIST:
                sql = [self insertByKeyToListForType:dbDriverType parameters:params  primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_UPDATE:
                sql = [self updateForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_UPDATE_BY_KEY:
                sql = [self updateByKeyForType:dbDriverType parameters:params  primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_INCREASE:
            case UMDBQUERYTYPE_INCREASE_BY_KEY:
                sql = [self increaseForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            case UMDBQUERYTYPE_SHOW:
                sql = [self showForType:dbDriverType parameters:params primaryKeyValue:primaryKeyValue];
                break;
            default:
                break;
        }
        //    cachedSql[dbDriverType] = sql;
        return sql;
    }
}

- (NSString *)keyForParameters:(NSArray *)params
{
    @autoreleasepool
    {
        NSMutableString *redisKey =[[NSMutableString alloc]initWithString:@""];
        [redisKey appendFormat:@"%@", table.pool.dbName];
        [redisKey appendFormat:@":%@", table.tableName];
        return redisKey;
    }
}

- (NSString *)getForKeyAndParameters:(NSArray *)params
{
    @autoreleasepool
    {
        NSMutableString *redisKey =[[NSMutableString alloc]initWithString:@""];
        [redisKey appendFormat:@"%@", instance];
        [redisKey appendFormat:@".%@", table.pool.dbName];
        [redisKey appendFormat:@".%@", table.tableName];
        [redisKey appendFormat:@".%@", primaryKeyName];
        return redisKey;
    }
}


- (NSString *)getForParameters:(NSArray *)params
{
    @autoreleasepool
    {
        NSMutableString *redisKey =[[NSMutableString alloc]initWithString:@""];
        [redisKey appendFormat:@"%@.", instance];
        [redisKey appendFormat:@"%@.", databaseName];
        [redisKey appendFormat:@"%@", table.tableName];
        for(NSString *field in keys)
        {
            if ([field length] == 0)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Fields are empty, cannot create query" userInfo:nil];
            }
            else
            {
                [redisKey appendFormat:@".%@", field];
            }
        }
        return redisKey;
    }
}

- (NSString *)setForParameters:(NSArray *)params
{
    @autoreleasepool
    {
        NSMutableString *redisKey =[[NSMutableString alloc]initWithString:@""];
        [redisKey appendFormat:@"%@.", instance];
        [redisKey appendFormat:@"%@.", databaseName];
        [redisKey appendFormat:@"%@", table.tableName];
        for(NSString *field in keys)
        {
            if ([field length] == 0)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Fields are empty, cannot create query" userInfo:nil];
            }
            else
            {
                [redisKey appendFormat:@".%@", field];
            }
        }
        

        NSMutableString *redisValue =[[NSMutableString alloc]initWithString:@""];
        long i = 0;
        long count = [fields count];
        for(; i < [fields count]; ++i)
        {
            NSString *field = fields[i];
            if ([field length] == 0)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Fields are empty, cannot create query" userInfo:nil];
            }
            else
            {
                NSString *param = params[i];
                if (!param)
                    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"param is nil, cannot create query" userInfo:nil];
                else
                {
                    [redisValue appendFormat:@"\"%@\": \"%@\"", field, param];
                    if (i < count - 1)
                        [redisValue appendString:@", "];
                }
            }
        }
        
        NSMutableString *redis =[[NSMutableString alloc]initWithString:@""];
        [redis appendString:redisKey];
        [redis appendFormat:@" {%@", redisValue];
        [redis appendString:@"}"];
        
        return redis;
    }
}

- (NSString *)setForKeyAndParameters:(NSArray *)params
{
    @autoreleasepool
    {
        NSMutableString *redisKey =[[NSMutableString alloc]initWithString:@""];
        [redisKey appendFormat:@"%@", instance];
        [redisKey appendFormat:@".%@.", databaseName];
        [redisKey appendFormat:@".%@", table.tableName];
        [redisKey appendFormat:@".%@", primaryKeyName];
        
        NSMutableString *redisValue =[[NSMutableString alloc]initWithString:@""];
        long i = 0;
        long count = [fields count];
        for(; i < [fields count]; ++i)
        {
            NSString *field = fields[i];
            if ([field length] == 0)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Fields are empty, cannot create query" userInfo:nil];
            }
            else
            {
                NSString *param = params[i];
                if (!param)
                    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"param is nil, cannot create query" userInfo:nil];
                else
                {
                    [redisValue appendFormat:@"\"%@\": \"%@\"", field, param];
                    if (i < count - 1)
                    {
                        [redisValue appendString:@", "];
                    }
                }
            }
        }
        
        NSMutableString *redis =[[NSMutableString alloc]initWithString:@""];
        [redis appendString:redisKey];
        [redis appendFormat:@" {%@", redisValue];
        [redis appendString:@"}"];
        return redis;
    }
}

- (NSString *)delForParameters:(NSArray *)params
{
    @autoreleasepool
    {
        NSMutableString *redisKey =[[NSMutableString alloc]initWithString:@""];
        [redisKey appendFormat:@"%@.", instance];
        [redisKey appendFormat:@"%@.", databaseName];
        [redisKey appendFormat:@"%@", table];
        for(NSString *field in keys)
        {
            if ([field length] == 0)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Fields are empty, cannot create query" userInfo:nil];
            }
            else
                [redisKey appendFormat:@".%@", field];
        }
        
        return redisKey;
    }
}

/* This is not part pf the protocol, bur used to make our interface more similsr than databases*/
- (NSString *)redisUpdateForParameters:(NSArray *)params
{
    @autoreleasepool
    {
        NSMutableString *redisKey =[[NSMutableString alloc]initWithString:@""];
        [redisKey appendFormat:@"%@.", instance];
        [redisKey appendFormat:@"%@.", databaseName];
        [redisKey appendFormat:@"%@", table];
        for(NSString *field in keys)
        {
            if ([field length] == 0)
            {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Fields are empty, cannot create query" userInfo:nil];
            }
            else
                [redisKey appendFormat:@".%@", field];
        }
        
        return redisKey;
    }
}


- (NSString *)redisForType:(UMDbQueryType)dbQueryType forDriver:(UMDbDriverType)dbDriverType parameters:(NSArray *)params primaryKeyValue:(id)primaryKeyValue
{
    NSString *redis = [self keyForParameters:params];
    return redis;
/*
    break;

    switch (dbQueryType)
    {
        case UMDBQUERYTYPE_INSERT_BY_KEY:
        case UMDBQUERYTYPE_UPDATE_BY_KEY:
        case UMDBQUERYTYPE_SELECT_BY_KEY:
        case UMDBQUERYTYPE_DELETE_BY_KEY:

            redis = [self keyForParameters:params];
            break;
            
        case UMDBQUERYTYPE_SELECT_BY_KEY_LIKE:
            redis = [self keyForParameters:params];
            break;
            
        case UMDBQUERYTYPE_DELETE_BY_KEY_AND_VALUE:
            redis = [self keyForParameters:params];
            break;

        case UMREDISTYPE_GET:
            redis = [self getForParameters:params];
            break;
        case UMREDISTYPE_DEL:
            redis = [self delForParameters:params];
            break;
        case UMREDISTYPE_SET:
            redis = [self setForParameters:params];
            break;
        case UMREDISTYPE_UPDATE:
            redis = [self redisUpdateForParameters:params];
            break;
        default:
            break;
    }
    //cachedSql[dbDriverType] = redis;
    return redis;
*/
}

- (NSString *)description
{
    @autoreleasepool
    {
        NSMutableString *txt = [[NSMutableString alloc]init];
        [txt appendFormat:@"%@\n",[super description]];
        
        if (instance)
        {
            [txt appendFormat:@"instance name %@\n", instance];
        }
        switch(type)
        {
            case UMDBQUERYTYPE_SELECT:
                [txt appendString:@"Type: SELECT\n"];
                break;
            case UMDBQUERYTYPE_INSERT:
                [txt appendString:@"Type: INSERT\n"];
                break;
            case UMDBQUERYTYPE_UPDATE:
                [txt appendString:@"Type: UPDATE\n"];
                break;
            case UMDBQUERYTYPE_INCREASE:
                [txt appendString:@"Type: INCREASE\n"];
                break;
            case UMDBQUERYTYPE_INCREASE_BY_KEY:
                [txt appendString:@"Type: INCREASE BY KEY\n"];
                break;
            case UMDBQUERYTYPE_DELETE:
                [txt appendString:@"Type: DELETE\n"];
                break;
            case UMDBQUERYTYPE_INSERT_BY_KEY:
                [txt appendString:@"Type: INSERT BY KEY\n"];
                break;
            case UMDBQUERYTYPE_INSERT_BY_KEY_TO_LIST:
                [txt appendString:@"Type: INSER BY KEY TO LIST\n"];
                break;
            case UMDBQUERYTYPE_UPDATE_BY_KEY:
                [txt appendString:@"Type: UPDATE BY KEY\n"];
                break;
            case UMDBQUERYTYPE_SELECT_BY_KEY:
                [txt appendString:@"Type: SELECT BY KEY\n"];
                break;
            case UMDBQUERYTYPE_SELECT_BY_KEY_LIKE:
                [txt appendString:@"Type: SELECT BY KEY LIKE\n"];
                break;
            case UMDBQUERYTYPE_SELECT_BY_KEY_FROM_LIST:
                [txt appendString:@"Type: SELECT BY KEY FROM LIST\n"];
                break;
            case UMDBQUERYTYPE_SELECT_LIST_BY_KEY_LIKE:
                [txt appendString:@"Type: SELECT LIST BY KEY\n"];
                break;
            case UMDBQUERYTYPE_DELETE_BY_KEY:
                [txt appendString:@"Type: DELETE BY KEY\n"];
                break;
            case UMDBQUERYTYPE_DELETE_IN_LIST_BY_KEY_AND_VALUE:
                [txt appendString:@"Type: DELETE IN LIST BY KEY AND VALUE\n"];
                break;
            case UMDBQUERYTYPE_EXPIRE_KEY:
                [txt appendString:@"Type: EXPIRE KEY\n"];
                break;
            case UMDBQUERYTYPE_SHOW:
                [txt appendString:@"Type: SHOW\n"];
                break;
            case UMREDISTYPE_GET:
                [txt appendString:@"Type: GET\n"];
                break;
            case UMREDISTYPE_SET:
                [txt appendString:@"Type: SET\n"];
                break;
            case UMREDISTYPE_DEL:
                [txt appendString:@"Type: DEL\n"];
                break;
            case UMREDISTYPE_UPDATE:
                [txt appendString:@"Type: REDIS UPDATE\n"];
                break;
            default:
                break;
        }
        if(cacheKey)
        {
            [txt appendFormat:@"Key: %@\n",cacheKey];
        }
        if(table)
        {
            [txt appendFormat:@"TableName: %@\n",[table tableName]];
        }
        if(fields)
        {
            [txt appendString:@"Fields:"];
            for (NSString *field in fields)
                [txt appendFormat:@" %@",field];
            [txt appendString:@"\n"];
        }
        if(keys)
        {
            [txt appendString:@"Keys:"];
            for (NSString *field in keys)
            {
                [txt appendFormat:@" %@",field];
            }
            [txt appendString:@"\n"];
        }
        if(whereCondition)
        {
            [txt appendFormat:@"WhereCondition: %@\n",[whereCondition description]];
        }
        if(grouping)
        {
            [txt appendFormat:@"Grouping: %@\n",grouping];
        }
        if(sortByFields)
        {
            [txt appendFormat:@"SortByFields: %@\n",[sortByFields componentsJoinedByString:@","]];
        }
        /*
         if(cachedSql[UMDBDRIVER_MYSQL])
         {
         [txt appendFormat:@"CachedSql[MYSQL]: %@\n",cachedSql[UMDBDRIVER_MYSQL]];
         }
         if(cachedSql[UMDBDRIVER_PGSQL])
         {
         [txt appendFormat:@"CachedSql[PGSQL]: %@\n",cachedSql[UMDBDRIVER_PGSQL]];
         }
         if(cachedSql[UMDBDRIVER_SQLITE])
         {
         [txt appendFormat:@"CachedSql[SQLITE]: %@\n",cachedSql[UMDBDRIVER_SQLITE]];
         }
         if(cachedSql[UMDBDRIVER_REDIS])
         {
         [txt appendFormat:@"CachedRedis[REDIS]: %@\n",cachedSql[UMDBDRIVER_REDIS]];
         }
         */
        return txt;
    }
}

+ (NSArray *)createSql:(NSString *)tn withDbType:(UMDbDriverType)dbType fieldsDefinition:(dbFieldDef *)fieldDef
{
    return [UMDbQuery createSql:tn withDbType:dbType fieldsDefinition:fieldDef forArchive:NO];
}

+ (NSArray *)createSql:(NSString *) tn withDbType:(UMDbDriverType)dbType tableDefinition:(UMDbTableDefinition *)tableDef;
{
    return [UMDbQuery createSql:tn withDbType:dbType tableDefinition:tableDef forArchive:NO];
}

+ (NSArray *)createArchiveSql:(NSString *)tn withDbType:(UMDbDriverType)dbType fieldsDefinition:(dbFieldDef *)fieldDef;
{
    return [UMDbQuery createSql:tn withDbType:dbType fieldsDefinition:fieldDef forArchive:YES];
}

+ (NSArray *)createArchiveSql:(NSString *)tn withDbType:(UMDbDriverType)dbType tableDefinition:(UMDbTableDefinition *)tableDef;
{
    return [UMDbQuery createSql:tn withDbType:dbType tableDefinition:tableDef forArchive:YES];
}

+ (NSArray *)createSql:(NSString *)tn withDbType:(UMDbDriverType)dbType fieldsDefinition:(dbFieldDef *)fieldDef forArchive:(BOOL)arch
{
    @autoreleasepool
    {
        dbFieldDef *f = NULL;
        NSMutableArray *sqlArray = [[NSMutableArray alloc]init];
        int i=0;
        NSMutableString *sqlStr = [[NSMutableString alloc]init];
        char quoteChar=' ';
        
        BOOL hasPrimaryKey = NO;
        
        if(dbType==UMDBDRIVER_MYSQL)
        {
            quoteChar='`';
        }
        else if(dbType==UMDBDRIVER_PGSQL)
        {
            quoteChar='\"';
        }
        [sqlStr appendFormat:@"CREATE TABLE %c%@%c (\n",quoteChar,tn,quoteChar];
        
        i=0;
        f = &fieldDef[i];
        while(f->name && f->name[0] && (f->fieldType != DB_FIELD_TYPE_END))
        {
            if(f->indexed==DB_PRIMARY_INDEX)
            {
                hasPrimaryKey=YES;
            }
            [sqlStr appendFormat:@"\t%c%s%c",quoteChar,f->name,quoteChar];
            switch(f->fieldType)
            {
                case DB_FIELD_TYPE_STRING:
                    [sqlStr appendFormat:@" CHAR(%d)",f->fieldSize];
                    break;
                case DB_FIELD_TYPE_SMALL_INTEGER:
                    [sqlStr appendFormat:@" SMALLINT"];
                    break;
                case DB_FIELD_TYPE_INTEGER:
                    [sqlStr appendFormat:@" INTEGER"];
                    break;
                case DB_FIELD_TYPE_BIG_INTEGER:
                    [sqlStr appendFormat:@" BIGINT"];
                    break;
                case DB_FIELD_TYPE_TEXT:
                    [sqlStr appendFormat:@" TEXT"];
                    break;
                case DB_FIELD_TYPE_TIMESTAMP_AS_STRING:
                    [sqlStr appendFormat:@" CHAR(%d)",f->fieldSize ? f->fieldSize : 26];
                    break;
                case DB_FIELD_TYPE_NUMERIC:
                    if((f->fieldSize==0) && (f->fieldDecimals==0))
                    {
                        f->fieldSize = 16;
                        f->fieldDecimals =8;
                    }
                    [sqlStr appendFormat:@" NUMERIC(%d,%d)",f->fieldSize,f->fieldDecimals];
                    break;
                default:
                    break;
            }
            
            if(f->canBeNull==NO)
            {
                [sqlStr appendString:@" NOT NULL"];
            }
            if(f->defaultValue)
            {
                if(strcasecmp(f->defaultValue,"AUTO_INCREMENT")==0)
                {
                    [sqlStr appendFormat:@" AUTO_INCREMENT"];
                }
                else
                {
                    [sqlStr appendFormat:@" DEFAULT '%s'",f->defaultValue];
                }
            }
            else if(f->fieldType == DB_FIELD_TYPE_TIMESTAMP_AS_STRING)
            {
                [sqlStr appendFormat:@" DEFAULT '%@'", [NSDate zeroDateString]];
            }
            else if(f->fieldType == DB_FIELD_TYPE_STRING)
            {
                [sqlStr appendString:@" DEFAULT ''"];
            }
            else if(f->fieldType == DB_FIELD_TYPE_SMALL_INTEGER)
            {
                [sqlStr appendString:@" DEFAULT '0'"];
            }
            else if(f->fieldType == DB_FIELD_TYPE_SMALL_INTEGER)
            {
                [sqlStr appendString:@" DEFAULT '0'"];
            }
            else if(f->fieldType == DB_FIELD_TYPE_INTEGER)
            {
                [sqlStr appendString:@" DEFAULT '0'"];
            }
            else if(f->fieldType == DB_FIELD_TYPE_BIG_INTEGER)
            {
                [sqlStr appendString:@" DEFAULT '0'"];
            }
            else if(f->fieldType == DB_FIELD_TYPE_TEXT)
            {
                [sqlStr appendString:@""]; /* BLOB AND TEXT CAN NOT HAVE DEFAULT */
            }
            else if(f->fieldType == DB_FIELD_TYPE_NUMERIC)
            {
                [sqlStr appendString:@" DEFAULT '0.00000000'"];
            }
            i++;
            f = &fieldDef[i];
            if((f->name==NULL) || (f->name[0]=='\0') || (f->fieldType == DB_FIELD_TYPE_END))
            {
                /* the last entry. If there is no primary key following we have to skip the comma here */
                if(hasPrimaryKey)
                {
                    [sqlStr appendFormat:@",\n"];
                }
            }
            else
            {
                [sqlStr appendFormat:@",\n"];
            }
        }
        
        i=0;
        f = &fieldDef[i];
        if(f)
        {
            while((f->name) && (f->fieldType != DB_FIELD_TYPE_END))
            {
                if(f->indexed==DB_PRIMARY_INDEX)
                {
                    [sqlStr appendFormat:@"\tPRIMARY KEY (%c%s%c)\n",quoteChar,f->name,quoteChar];
                    break;
                }
                i++;
                f = &fieldDef[i];
            }
        }
        
        if(dbType==UMDBDRIVER_MYSQL)
        {
            [sqlStr appendFormat:@") DEFAULT CHARSET=utf8 COLLATE=utf8_bin;\n"];
        }
        else
        {
            [sqlStr appendString:@");\n"];
        }
        
        [sqlArray addObject:sqlStr];
        
        i=0;
        f = &fieldDef[i];
        while((f->name) && (f->name[0]) && (f->fieldType != DB_FIELD_TYPE_END))
        {
            if( (f->indexed==DB_INDEXED) ||
               ((f->indexed == DB_INDEXED_BUT_NOT_FOR_ARCHIVE)  && (arch==NO)))
            {
                [sqlArray addObject: [NSString stringWithFormat:@"CREATE INDEX %c%s_idx%c ON %c%@%c(%c%s%c);\n",quoteChar,f->name,quoteChar,quoteChar,tn,quoteChar,quoteChar,f->name,quoteChar]];
            }
            i++;
            f = &fieldDef[i];
        }	
        return sqlArray;
    }
}

+ (NSArray *)createSql:(NSString *) tn withDbType:(UMDbDriverType)dbType tableDefinition:(UMDbTableDefinition *)tableDef forArchive:(BOOL)arch
{
    @autoreleasepool
    {
        
        NSMutableArray *sqlArray = [[NSMutableArray alloc]init];
        int i=0;
        NSMutableString *sqlStr = [[NSMutableString alloc]init];
        char quoteChar=' ';
        
        if(dbType==UMDBDRIVER_MYSQL)
        {
            quoteChar='`';
        }
        else if(dbType==UMDBDRIVER_PGSQL)
        {
            quoteChar='\"';
        }
        [sqlStr appendFormat:@"CREATE TABLE %c%@%c (\n",quoteChar,tn,quoteChar];
        
        i=0;
        
        UMDbFieldDefinition *f = [tableDef getFieldDef:i];
        while((f.fieldName!=nil) && (f.fieldType != UMDB_FIELD_TYPE_END))
        {
            [sqlStr appendFormat:@"\t%c%@%c",quoteChar,f.fieldName,quoteChar];
            switch(f.fieldType)
            {
                case UMDB_FIELD_TYPE_STRING:
                    [sqlStr appendFormat:@" CHAR(%d)",(int)f.fieldSize];
                    break;
                case UMDB_FIELD_TYPE_SMALL_INTEGER:
                    [sqlStr appendFormat:@" SMALLINT"];
                    break;
                case UMDB_FIELD_TYPE_INTEGER:
                    [sqlStr appendFormat:@" INTEGER"];
                    break;
                case UMDB_FIELD_TYPE_BIG_INTEGER:
                    [sqlStr appendFormat:@" BIGINT"];
                    break;
                case UMDB_FIELD_TYPE_TEXT:
                    [sqlStr appendFormat:@" TEXT"];
                    break;
                case UMDB_FIELD_TYPE_TIMESTAMP_AS_STRING:
                    [sqlStr appendFormat:@" CHAR(%d)",(int)(f.fieldSize ? f.fieldSize : 26)];
                    break;
                case UMDB_FIELD_TYPE_NUMERIC:
                    if((f.fieldSize==0) && (f.fieldDecimals==0))
                    {
                        f.fieldSize = 12;
                        f.fieldDecimals = 6;
                    }
                    [sqlStr appendFormat:@" NUMERIC(%d,%d)",(int)f.fieldSize,(int)f.fieldDecimals];
                    break;
                default:
                    break;
            }
            
            if(f.canBeNull==NO)
            {
                [sqlStr appendString:@" NOT NULL"];
            }
            if(f.defaultValue)
            {
                [sqlStr appendFormat:@" DEFAULT '%@'",f.defaultValue];
            }
            else if(f.fieldType == UMDB_FIELD_TYPE_TIMESTAMP_AS_STRING)
            {
                [sqlStr appendFormat:@" DEFAULT '%@'",[NSDate zeroDateString]];
            }
            else if(f.fieldType == UMDB_FIELD_TYPE_STRING)
            {
                [sqlStr appendString:@" DEFAULT ''"];
            }
            else if(f.fieldType == UMDB_FIELD_TYPE_SMALL_INTEGER)
            {
                [sqlStr appendString:@" DEFAULT '0'"];
            }
            else if(f.fieldType == UMDB_FIELD_TYPE_SMALL_INTEGER)
            {
                [sqlStr appendString:@" DEFAULT '0'"];
            }
            else if(f.fieldType == UMDB_FIELD_TYPE_INTEGER)
            {
                [sqlStr appendString:@" DEFAULT '0'"];
            }
            else if(f.fieldType == UMDB_FIELD_TYPE_BIG_INTEGER)
            {
                [sqlStr appendString:@" DEFAULT '0'"];
            }
            else if(f.fieldType == UMDB_FIELD_TYPE_TEXT)
            {
                [sqlStr appendString:@""]; /* BLOB AND TEXT CAN NOT HAVE DEFAULT */
            }
            else if(f.fieldType == UMDB_FIELD_TYPE_NUMERIC)
            {
                [sqlStr appendString:@" DEFAULT '0.00000000'"];
            }
            i++;
            f = [tableDef getFieldDef:i];
            [sqlStr appendFormat:@",\n"];
        }
        
        i=0;
        f = [tableDef getFieldDef:i];
        if(f)
        {
            while((f.fieldName!=nil) && (f.fieldType != UMDB_FIELD_TYPE_END))
            {
                if(f.isPrimaryIndex)
                {
                    [sqlStr appendFormat:@"PRIMARY KEY (%c%@%c)\n",quoteChar,f.fieldName,quoteChar];
                    break;
                }
                i++;
                f = [tableDef getFieldDef:i];
            }
        }
        
        if(dbType==UMDBDRIVER_MYSQL)
        {
            [sqlStr appendFormat:@") DEFAULT CHARSET=utf8 COLLATE=utf8_bin;\n"];
        }
        else
        {
            [sqlStr appendString:@");\n"];
        }
        
        [sqlArray addObject:sqlStr];
        
        i=0;
        f = [tableDef getFieldDef:i];
        while((f.fieldName!=nil) && (f.fieldType != UMDB_FIELD_TYPE_END))
        {
            if( (f.isIndexedInArchive) ||
               ((f.isIndexed)  && (arch==NO)))
            {
                [sqlArray addObject: [NSString stringWithFormat:@"CREATE INDEX %c%@_idx%c ON %c%@%c(%c%@%c);\n",quoteChar,f.fieldName,quoteChar,quoteChar,tn,quoteChar,quoteChar,f.fieldName,quoteChar]];
            }
            i++;
            f = [tableDef getFieldDef:i];
        }
        return sqlArray;
    }
}
    
+ (NSArray *)fieldNamesArrayFromFieldsDefinition:(dbFieldDef *)fieldDef
{
    @autoreleasepool
    {
        
        NSMutableArray *array = [[NSMutableArray alloc]init];
        
        int i=0;
        dbFieldDef *f = &fieldDef[i];
        while((f->name) &&  (f->name[0]!='\0')  && (f->fieldType!= DB_FIELD_TYPE_END))
        {
            [array addObject:@(f->name)];
            i++;
            f = &fieldDef[i];
        }
        return array;
    }
}

+ (NSArray *)fieldNamesArrayFromTableDefinition:(UMDbTableDefinition *)fieldDef
{
    return [fieldDef fieldNames];
}


+ (void)initStatics
{
    if(cachedQueries==NULL)
    {
        cachedQueries = [[NSMutableDictionary alloc]init];
    }
}

- (BOOL) returnsResult
{
    switch(type)
    {
        case UMDBQUERYTYPE_INSERT:
        case UMDBQUERYTYPE_UPDATE:
        case UMDBQUERYTYPE_INCREASE:
        case UMDBQUERYTYPE_INCREASE_BY_KEY:
        case UMDBQUERYTYPE_DELETE:
        case UMDBQUERYTYPE_INSERT_BY_KEY:
        case UMDBQUERYTYPE_INSERT_BY_KEY_TO_LIST:
        case UMDBQUERYTYPE_UPDATE_BY_KEY:
        case UMDBQUERYTYPE_DELETE_BY_KEY:
        case UMDBQUERYTYPE_DELETE_IN_LIST_BY_KEY_AND_VALUE:
        case UMDBQUERYTYPE_EXPIRE_KEY:
        case UMREDISTYPE_SET:
        case UMREDISTYPE_DEL:
        case UMREDISTYPE_UPDATE:
        case UMREDISTYPE_HSET:
            return NO;
        case UMDBQUERYTYPE_SELECT:
        case UMDBQUERYTYPE_SHOW:
        case UMDBQUERYTYPE_SELECT_BY_KEY:
        case UMDBQUERYTYPE_SELECT_BY_KEY_LIKE:
        case UMDBQUERYTYPE_SELECT_BY_KEY_FROM_LIST:
        case UMDBQUERYTYPE_SELECT_LIST_BY_KEY_LIKE:
        case UMREDISTYPE_GET:
        case UMREDISTYPE_HGET:
            return YES;
        default:
            UMAssert(0,@"Unknown query type %d",type);
            break;
    }
    return NO;
}


@end
