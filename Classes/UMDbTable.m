//
//  UMDbTable.m
//  ulibdb.framework
//
//  Created by Andreas Fink on 15.12.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ulib/ulib.h>
#import "ulibdb_defines.h"
#import "UMDbTable.h"
#import "UMDbQueryType.h"
#import "UMDbQuery.h"
#import "UMDbSession.h"
#import "UMMySQLSession.h"

@implementation UMDbTable

@synthesize tableName;
@synthesize poolName;
@synthesize pools;
@synthesize autoCreate;

@synthesize tcAllQueries;
@synthesize tcSelects;
@synthesize tcInserts;
@synthesize tcUpdates;
@synthesize tcDeletes;
@synthesize tcGets;
@synthesize tcSets;
@synthesize tcRedisUpdates;
@synthesize tcDels;

@synthesize delayAllQueries;
@synthesize delaySelects;
@synthesize delayInserts;
@synthesize delayUpdates;
@synthesize delayDeletes;
@synthesize delayGets;
@synthesize delaySets;
@synthesize delayRedisUpdates;
@synthesize delayDels;


- (UMDbTable *)init
{
    return [self initWithConfig:NULL andPools:NULL];
}


- (UMDbTable *)initWithPool
{
    return [self initWithConfig:NULL andPools:NULL];
}

- (UMDbTable *)initWithConfig:(NSDictionary *)config
                     andPools:(UMSynchronizedDictionary *)newPools
{
    self=[super init];
    if(self)
    {
        self.autoCreate=YES;
        self.pools = newPools;
        if(config!=NULL)
        {
            NSString *enableString = config[@"enable"];
            if(enableString.length > 0)
            {
                if([enableString boolValue]==NO)
                {
                    return NULL;
                }
            }

            NSString *tableNameString = config[@"table-name"];
            if(tableNameString!= NULL)
            {
                self.tableName = tableNameString;
            }

            NSString *autoCreateString = config[@"autocreate"];
            if(autoCreateString!= NULL)
            {
                self.autoCreate = [autoCreateString boolValue];
            }

            NSString *poolNameString = config[@"pool-name"];
            if(poolNameString!= NULL)
            {
                self.poolName = poolNameString;
            }
        }
        tcAllQueries = [[UMThroughputCounter alloc]init];
        tcSelects = [[UMThroughputCounter alloc]init];
        tcInserts = [[UMThroughputCounter alloc]init];
        tcUpdates = [[UMThroughputCounter alloc]init];
        tcDeletes = [[UMThroughputCounter alloc]init];
    }
    return self;
}


- (void) addStatDelay:(double)delay query:(UMDbQueryType)type
{
    NSNumber *nr = @(delay);
    [delayAllQueries appendNumber:nr];
    switch(type)
    {
        case    UMDBQUERYTYPE_SELECT:
        case    UMDBQUERYTYPE_SELECT_BY_KEY:
            [delaySelects appendNumber:nr];
            break;
        case    UMDBQUERYTYPE_INSERT:
        case    UMDBQUERYTYPE_INSERT_BY_KEY:
        case    UMDBQUERYTYPE_INSERT_BY_KEY_TO_LIST:
            [delayInserts appendNumber:nr];
            break;
        case    UMDBQUERYTYPE_UPDATE:
        case    UMDBQUERYTYPE_UPDATE_BY_KEY:
        case    UMDBQUERYTYPE_INCREASE:
        case    UMDBQUERYTYPE_INCREASE_BY_KEY:
            [delayUpdates appendNumber:nr];
            break;
        case    UMDBQUERYTYPE_DELETE:
        case    UMDBQUERYTYPE_DELETE_BY_KEY:
            [delayDeletes appendNumber:nr];
            break;
        case    UMREDISTYPE_GET:
        case    UMREDISTYPE_HGET:
            [delayGets appendNumber:nr];
            break;
        case    UMREDISTYPE_SET:
        case    UMREDISTYPE_HSET:
            [delaySets appendNumber:nr];
            break;
        case    UMREDISTYPE_UPDATE:
            [delayRedisUpdates appendNumber:nr];
            break;
        case    UMREDISTYPE_DEL:
            [delayDels appendNumber:nr];
            break;
        default:
            break;
    }
}

- (void)increaseCountersForType:(UMDbQueryType)type
{
    [tcAllQueries increase];
    switch(type)
    {
        case    UMDBQUERYTYPE_SELECT:
        case    UMDBQUERYTYPE_SELECT_BY_KEY:
            [tcSelects increase];
            break;
        case    UMDBQUERYTYPE_INSERT:
        case    UMDBQUERYTYPE_INSERT_BY_KEY:
        case    UMDBQUERYTYPE_INSERT_BY_KEY_TO_LIST:
        [tcInserts increase];
            break;
        case    UMDBQUERYTYPE_UPDATE:
        case    UMDBQUERYTYPE_UPDATE_BY_KEY:
        case    UMDBQUERYTYPE_INCREASE:
        case UMDBQUERYTYPE_INCREASE_BY_KEY:
            [tcUpdates increase];
            break;
        case    UMDBQUERYTYPE_DELETE:
        case    UMDBQUERYTYPE_DELETE_BY_KEY:
            [tcDeletes increase];
            break;
        case    UMREDISTYPE_GET:
        case    UMREDISTYPE_HGET:
            [tcGets increase];
            break;
        case    UMREDISTYPE_SET:
        case    UMREDISTYPE_HSET:
            [tcSets increase];
            break;
        case    UMREDISTYPE_UPDATE:
            [tcRedisUpdates increase];
            break;
        case    UMREDISTYPE_DEL:
            [tcDels increase];
            break;
        default:
            break;
    }
}

- (UMDbPool *)pool
{
    if(pool == NULL)
    {
        pool = pools[poolName];
    }
    return pool;
}

- (void)setPoolName:(NSString *)pn
{
    poolName = pn;
    
    pool = NULL;
}

- (NSString *)poolName
{
    return poolName;
}

- (void)autoCreate:(dbFieldDef *)fieldDef
           session:(UMDbSession *)session
{
    if(autoCreate==YES)
    {
        UMAssert((self.pool != NULL),@"Pool %@ not found",poolName);
        NSArray *sqlCommands = [UMDbQuery createSql:tableName
                                  withDbType:[pool dbDriverType]
                                     session:session
                            fieldsDefinition:fieldDef];
        
        UMDbSession *session = [pool grabSession:FLF];
        [session queriesWithNoResult:sqlCommands allowFail:YES];

        if(pool.dbDriverType==UMDBDRIVER_MYSQL)
        {
            UMMySQLSession *mySession =(UMMySQLSession *)session;
            NSDictionary *tableDef = [mySession explainTable:tableName];
            if(tableDef == NULL)
            {
                NSLog(@"SQL: %@",sqlCommands);
                NSLog(@"TableDefinition: %@",tableDef);
                UMAssert(tableDef != NULL,@"Autocreation failed!");
            }
        }
        [session.pool returnSession:session file:FLF];
    }
}

@end
