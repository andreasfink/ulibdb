//
//  UMDbPool.m
//  ulibdb.framework
//
//  Created by Andreas Fink on 24.10.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.

#import "ulib/ulib.h"
#import "ulibdb_defines.h"
#import "ulibdb_config.h"
#import "UMDbPool.h"
#import "UMDbSession.h"
#import "UMMySQLSession.h"
#import "UMPgSQLSession.h"
#import "UMSqLiteSession.h"
#import "UMDbRedisSession.h"
#import "UMDbQueryType.h"
#import "UMDbTable.h"

#include <stdlib.h>
#include <unistd.h>

void umdbpool_out_of_sessions(void)
{
    /* break in debugger on this function:  break set -b umdbpool_out_of_sessions */
    //NSLog(@"We run out of sessions, connecting new one");
    
}

void umdbpool_null_session_returned(void)
{
    /* break in debugger on this function:  break set -b umdbpool_out_of_sessions */
    NSLog(@"We return NULL as session");
    
}


@implementation UMDbPool
//@synthesize poolLock;
@synthesize version;
@synthesize poolName;
@synthesize hostName;
@synthesize hostAddr;
@synthesize port;
@synthesize dbName;
@synthesize user;
@synthesize pass;
@synthesize options;
@synthesize dbDriverType;
@synthesize dbStorageType;
@synthesize minSessions;
@synthesize maxSessions;
@synthesize waitTimeout1;
@synthesize waitTimeout2;
@synthesize wait1count;
@synthesize wait2count;
@synthesize socket;

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
@synthesize poolSleeper;

- (UMDbPool *) init
{
    return [self initWithConfig:NULL];
}

- (NSUInteger)sessionsAvailableCount
{
    return [sessionsAvailable count];
}

- (NSUInteger)sessionsInUseCount
{
    return [sessionsInUse count];
}

- (NSUInteger)sessionsDisconnectedCount
{
    return [sessionsDisconnected count];
}

- (UMDbPool *)initWithConfig:(NSDictionary *)config
{
    self=[super init];
    if(self)
    {
        sessionsAvailable       = [[UMQueue alloc]init];
        sessionsInUse           = [[UMQueue alloc]init];
        sessionsDisconnected    = [[UMQueue alloc]init];
        waitTimeout1            = 2;
        idleTaskStatus          = idleStatus_stopped;
        _poolLock = [[UMMutex alloc]init];

        self.tcAllQueries = [[UMThroughputCounter alloc]init];
        self.tcSelects = [[UMThroughputCounter alloc]init];
        self.tcInserts = [[UMThroughputCounter alloc]init];
        self.tcUpdates = [[UMThroughputCounter alloc]init];
        self.tcDeletes = [[UMThroughputCounter alloc]init];
        self.tcGets    = [[UMThroughputCounter alloc]init];
        self.tcSets    = [[UMThroughputCounter alloc]init];
        self.tcRedisUpdates = [[UMThroughputCounter alloc]init];
        self.tcDels = [[UMThroughputCounter alloc]init];
        
        self.delayAllQueries = [[UMAverageDelay alloc]init];
        self.delaySelects = [[UMAverageDelay alloc]init];
        self.delayInserts = [[UMAverageDelay alloc]init];
        self.delayUpdates = [[UMAverageDelay alloc]init];
        self.delayDeletes = [[UMAverageDelay alloc]init];
        self.delayGets = [[UMAverageDelay alloc]init];
        self.delaySets = [[UMAverageDelay alloc]init];
        self.delayRedisUpdates = [[UMAverageDelay alloc]init];
        self.delayDels = [[UMAverageDelay alloc]init];
        self.poolSleeper =[[UMSleeper alloc]initFromFile:__FILE__ line:__LINE__ function:__func__];
        [self.poolSleeper prepare];
        self.waitTimeout2 = 30;
        self.waitTimeout1 = 3;
        self.minSessions = 3;
        self.maxSessions = 20;

        if(config!=NULL)
        {
            NSString *enableString = config[@"enable"];
            if(enableString!= NULL)
            {
                if([enableString boolValue]==NO)
                {
                    return NULL;
                }
            }
            
            NSString *versionString = config[@"version"];
            if(versionString!= NULL)
            {
                self.version = versionString;
            }
            
            NSString *poolNameString = config[@"pool-name"];
            if(poolNameString!= NULL)
            {
                self.poolName = poolNameString;
            }
            
            NSString *hostNameNameString = config[@"host"];
            if(hostNameNameString!= NULL)
            {
                self.hostName = hostNameNameString;
            }
            
            NSString *dbNameString = config[@"database-name"];
            if(dbNameString!= NULL)
            {
                self.dbName = dbNameString;
            }
            
            NSString *driverTypeString = config[@"driver"];
            if([driverTypeString caseInsensitiveCompare:@"mysql"]==NSOrderedSame)
            {
                self.dbDriverType = UMDBDRIVER_MYSQL;
            }
            else  if([driverTypeString caseInsensitiveCompare:@"pgsql"]==NSOrderedSame)
            {
                self.dbDriverType = UMDBDRIVER_PGSQL;
            }
            else  if([driverTypeString caseInsensitiveCompare:@"sqlite"]==NSOrderedSame)
            {
                self.dbDriverType = UMDBDRIVER_SQLITE;
            }
            else  if([driverTypeString caseInsensitiveCompare:@"redis"]==NSOrderedSame)
            {
                self.dbDriverType = UMDBDRIVER_REDIS;
            }
            else  if([driverTypeString caseInsensitiveCompare:@"file"]==NSOrderedSame)
            {
                self.dbDriverType = UMDBDRIVER_FILE;
            }
            else
            {
                UMAssert(0,@"Unknown driver type %@",driverTypeString);
            }
            
            NSString *storageTypeString = config[@"storage-type"];
            if([storageTypeString isEqualToString:@"json"])
            {
                self.dbStorageType = UMDBSTORAGE_JSON;
            }
            else  if([storageTypeString isEqualToString:@"hash"])
            {
                self.dbStorageType = UMDBSTORAGE_HASH;
            }
            else
            {
                self.dbStorageType = UMDBSTORAGE_JSON;
            }
            
            NSString *u = config[@"user"];
            if(u!= NULL)
            {
                self.user = u;
            }
            
            NSString *p = config[@"pass"];
            if(p!= NULL)
            {
                self.pass = p;
            }
            NSString *portString = config[@"port"];
            if(portString !=NULL)
            {
                self.port = (int)[portString integerValue];
            }
            NSString *minString = config[@"min-sessions"];
            if(minString !=NULL)
            {
                self.minSessions = (int)[minString integerValue];
            }
            NSString *maxString = config[@"max-sessions"];
            if([maxString length]>0)
            {
                self.maxSessions = (int)[maxString integerValue];
            }
            NSString *s = config[@"socket"];
            if(s!= NULL)
            {
                self.socket = s;
            }
            NSString *pingString = config[@"ping-interval"];
            if([pingString length]>0)
            {
                self.waitTimeout2 = (int)[pingString integerValue];
                if(self.waitTimeout2 < 15)
                {
                    self.waitTimeout2 = 15;
                }
            }
            else
            {
                self.waitTimeout2 = 30;
            }
            [self startSessions];
            [self startIdler];
        }
    }
    return self;
}

- (void)dealloc
{
    dbDriverType = UMDBDRIVER_NULL;
    [self stopIdler];
    poolSleeper = NULL;
}

- (void)startIdler
{
    if(idleTaskStatus == idleStatus_stopped)
    {
        idleTaskStatus = idleStatus_starting;
        [self performSelectorInBackground:@selector(idler:) withObject:self];
        int i=0;
        while((idleTaskStatus != idleStatus_running) && (i++ <2000))
        {
            usleep(1000);
        }
        if(i>=2000)
        {
            idleTaskStatus = idleStatus_stopped;
        }
    }
}


- (void)stopIdler
{
    if(idleTaskStatus != idleStatus_stopped)
    {
        idleTaskStatus = idleStatus_terminating;
        int i = 0;
        [poolSleeper wakeUp];
        while ((idleTaskStatus != idleStatus_stopped) && (i++ <2000))
        {
            usleep(1000);
        }
        idleTaskStatus = idleStatus_stopped;
    }
}


- (void)idler:(id)unused
{
    @autoreleasepool
    {
        NSString *msg = [NSString stringWithFormat:@"starting idle task for database pool %@", poolName];
        [logFeed info:0 inSubsection:@"database" withText:msg];
        idleTaskStatus = idleStatus_running;
        
        while(idleTaskStatus==idleStatus_running)
        {
            int ret = [poolSleeper sleep:(1000000 * self.waitTimeout2)];
            if(ret == 0)
            {
                [self idleTask];
            }
        }
        msg = [NSString stringWithFormat:@"terminating idle task for database pool %@", poolName];
        [logFeed info:0 inSubsection:@"database" withText:msg];
        idleTaskStatus = idleStatus_stopped;
    }
}

- (void) idleTask
{
    [_poolLock lock];
    [self addConnectedSessions];
    [self removeDisconnectedSessions];
    [self pingAllUnusedSessions];
    [self pingAllDisconnectedSessions];
    [_poolLock unlock];
}

// Move connected sessions to list of available sessions

- (void) addConnectedSessions
{
    [_poolLock lock];
    @try
    {
        UMDbSession *result = nil;
        BOOL isConnected = NO;
        
        long len = [sessionsDisconnected count];
        while(len--)
        {
            result = [sessionsDisconnected getFirst];
            isConnected = [result isConnected];
            if (isConnected)
            {
                [sessionsInUse append:result];
            }
            else
            {
                [sessionsDisconnected append:result];
            }
        }
    }
    @finally
    {
        [_poolLock unlock];
    }
 }

// Drop disconnected sessions from available connections
- (void) removeDisconnectedSessions
{
    [_poolLock lock];
    @try
    {
        UMDbSession *result = nil;
        BOOL isConnected = NO;
        
        long len = [sessionsAvailable count];
        
        while (len--)
        {
            result = [sessionsAvailable getFirst];
            if(result)
            {
                isConnected = [result isConnected];
                if (!isConnected)
                {
                    [sessionsDisconnected append:result];
                }
                else
                {
                    [sessionsAvailable append:result];
                }
            }
        }
    }
    @finally
    {
        [_poolLock unlock];
    }
}

// Ping all unused sessions and mark discoonected, if ping did not work
- (void) pingAllUnusedSessions
{
    [_poolLock lock];
    @try
    {
        UMDbSession *s = nil;

        long len = [sessionsAvailable count];
        while (len-- > 0)
        {
            s = [sessionsAvailable getFirst];
            BOOL success = [s ping];
            if (!success)
            {
                [sessionsDisconnected append:s];
            }
            else
            {
                [sessionsAvailable append:s];
            }
        }
    }
    @finally
    {
        [_poolLock unlock];
    }
}

/* Return disconnect session to available pool, if ping successes and if there are no queries to redone.
 * Session returns into available pool only when all required resends are done.*/
- (void) pingAllDisconnectedSessions
{
    [_poolLock lock];
    @try
    {
        
        UMDbSession *s = nil;
        long len = [sessionsDisconnected count];
        
        while (len-- > 0)
        {
            s = [sessionsDisconnected getFirst];
            BOOL success = [s ping];
            if (success)
            {
                [sessionsAvailable append:s];
            }
            else
            {
                [sessionsDisconnected append:s];
            }
        }
    }
    @finally
    {
        [_poolLock unlock];
    }
}


- (UMDbSession *)newSession
{
    [_poolLock lock];
    @try
    {
        UMDbSession *session = NULL;
        switch (dbDriverType)
        {
#ifdef HAVE_MYSQL
            case UMDBDRIVER_MYSQL:
                session = (UMDbSession *)[[UMMySQLSession alloc]initWithPool:self];
                break;
#endif
#ifdef HAVE_PGSQL
            case UMDBDRIVER_PGSQL:
                session = (UMDbSession *)[[UMPgSQLSession alloc]initWithPool:self];
                break;
#endif
#ifdef HAVE_SQLITE
            case UMDBDRIVER_SQLITE:
                session = (UMDbSession *)[[UMSqLiteSession alloc]initWithPool:self];
                break;
#endif
            case UMDBDRIVER_REDIS:
                session = (UMDbSession *)[[UMDbRedisSession alloc]initWithPool:self];
                break;
            default:
                session = [[UMDbSession alloc]initWithPool:self];
                break;
        }
        NSAssert(session.pool==self,@"New session without proper assigned pool");
        session.pool = self;
        [session connect];
        return session;
    }
    @finally
    {
        [_poolLock unlock];
    }
}

- (UMDbSession *)grabSession:(const char *)file line:(int)line func:(const char *)func
{
#ifdef POOL_DEBUG
    NSLog(@"UMDbPool grabSession called from %s:%ld %s()",file,line,func);
#endif
    UMDbSession *result = NULL;
    time_t   start;
    time_t   now;
    BOOL wait1hit = NO;
    bool wait2hit = NO;

    time(&now);
    start = now;
    
    BOOL endNow=NO;
    BOOL noSessionAvailable=NO;
    while(endNow==NO)
    {
        noSessionAvailable=NO;

        [_poolLock lock];
        if(self.sessionsAvailableCount>0)
        {
            result = [sessionsAvailable getFirst];
            [sessionsInUse append:result];
            endNow = YES;
        }
        else
        {
            umdbpool_out_of_sessions();
            if(self.sessionsInUseCount < self.maxSessions)
            {
                result = [self newSession];
                if(result)
                {
                    NSAssert(result.pool==self,@"Ouch session without proper assigned pool");
                    [sessionsInUse append:result];
                    endNow = YES;
                }
            }
            else
            {
                noSessionAvailable=YES;
            }
        }
        [_poolLock unlock];

        
        if(noSessionAvailable)
        {
            time(&now);
            /* waitTimeout2 is abslute timeout */
            if( (now - start) > waitTimeout2)
            {
                wait2hit=YES;
                endNow = YES;
            }
            else
            {
                UMSleeper   *sleeper = [[UMSleeper alloc]initFromFile:__FILE__ line:__LINE__ function:__func__];
                [sleeper prepare];
                if((now - start) <= waitTimeout1)
                {
                    long long msdelay = random() % 50000 + 100000;/* sleep something like 100ms */
                    [sleeper sleep:msdelay];
                }
                else
                {
                    long long msdelay = random() % 100000 + 500000; /* sleep something like 0.5s */
                    [sleeper sleep:msdelay];
                    wait1hit=YES;
                }
                sleeper = NULL;
            }
        }
    }
    
    if(result==NULL)
    {
        [self timeoutWaitingForSessions];
        if(wait2hit)
        {
            wait2count++;
        }
        else if(wait1hit)
        {
            wait1count++;
        }
        umdbpool_null_session_returned();
    }
    else
    {
        UMAssert([result.pool isEqualTo:self]==YES,@"got an entry from another pool %@. Last used at %@:%ld" ,
                 result.pool.poolName,
                 result.lastUsedFile,
                 result.lastUsedLine);

        [result touchGrabTimer];
        [result setUsedFrom:file line:line func:func];
    }
    return result;
}

- (void)timeoutWaitingForSessions;
{
    NSLog(@"Timeout waiting for DB sessions");
}

- (void)returnSession:(UMDbSession *)session file:(const char *)file line:(long)line func:(const char *)func
{
#ifdef POOL_DEBUG
    NSLog(@"UMDbPool returnSession called from %s:%ld %s()",file,line,func);
#endif

    if(session)
    {
        [_poolLock lock];
        [sessionsInUse removeObject:session];
        [session setUsedFrom:file line:line func:func];
        [sessionsAvailable append:session];
        [_poolLock unlock];

    }
    else
    {
        NSLog(@"We can't return a NULL session");
    }
}


/* Do both disconnected and in use sessions, because this could called before session is marked disconnected*/

- (void)returnSession:(UMDbSession *)session
{
    return [self returnSession:session file:__FILE__ line:__LINE__ func:__func__];
}

- (void) startSessions
{
    [_poolLock lock];
    for (int i=0;i<minSessions;i++)
    {
        UMDbSession *session = [self newSession];
        [sessionsAvailable append:session];
    }


    [_poolLock unlock];
}

- (void) stopSessions
{
    [_poolLock lock];
    UMDbSession *session = [sessionsInUse getFirst];
    while(session)
    {
        [session disconnect];
        session = [sessionsInUse getFirst];
    }

    session = [sessionsAvailable getFirst];
    while(session)
    {
        [session disconnect];
        session = [sessionsAvailable getFirst];
    }
    [_poolLock unlock];
}

- (void) removeSessions
{
    sessionsInUse = [[UMQueue alloc]init];
    sessionsAvailable = [[UMQueue alloc]init];
}


- (NSUInteger)inUseSessionsCount
{
    return [sessionsInUse count];
}

- (NSUInteger)availableSessionsCount
{
    return  [sessionsAvailable count];
}

- (NSUInteger)disconnectedSessionsCount
{
    return [sessionsDisconnected count];
}


- (double) queriesPerSec:(int)timespan
{
    return [tcAllQueries getSpeedForSeconds:timespan];
}

- (double) selectQueriesPerSec:(int)timespan
{
    return [tcSelects getSpeedForSeconds:timespan];
}

- (double) insertQueriesPerSec:(int)timespan
{
    return [tcInserts getSpeedForSeconds:timespan];
}

- (double) updateQueriesPerSec:(int)timespan
{
    return [tcUpdates getSpeedForSeconds:timespan];
}

- (double) deleteQueriesPerSec:(int)timespan
{
    return [tcDeletes getSpeedForSeconds:timespan];
}

- (void) addStatDelay:(double)delay query:(UMDbQueryType)type table:(UMDbTable *)table
{
    NSNumber *nr = @(delay);
    [delayAllQueries appendNumber:nr];
    switch(type)
    {
        case    UMDBQUERYTYPE_SELECT:
        case    UMDBQUERYTYPE_SELECT_BY_KEY:
        case    UMDBQUERYTYPE_SELECT_BY_KEY_LIKE:
        case    UMDBQUERYTYPE_SELECT_BY_KEY_FROM_LIST:
        case    UMDBQUERYTYPE_SELECT_LIST_BY_KEY_LIKE:
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
        case    UMDBQUERYTYPE_DELETE_IN_LIST_BY_KEY_AND_VALUE:
        case    UMDBQUERYTYPE_EXPIRE_KEY:
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
    if (table)
    {
        [table addStatDelay:delay query:type];
    }
   
}

- (void)increaseCountersForType:(UMDbQueryType)type table:(UMDbTable *)table
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
        case    UMDBQUERYTYPE_INCREASE_BY_KEY:
            [tcUpdates increase];
            break;
        case    UMDBQUERYTYPE_DELETE:
        case    UMDBQUERYTYPE_DELETE_BY_KEY:
        case    UMDBQUERYTYPE_DELETE_IN_LIST_BY_KEY_AND_VALUE:
        case    UMDBQUERYTYPE_EXPIRE_KEY:
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
    if (table)
    {
        [table increaseCountersForType:type];
    }
}

- (NSString *)description
{
    NSMutableString *s = [NSMutableString stringWithString:[super description]];
    if (version)
        [s appendFormat:@"server version for redis hash: %@\n",version];
    [s appendFormat:@"PoolName: %@\n",poolName];
    [s appendFormat:@" dbName: %@\n",dbName];
    [s appendFormat:@" host: %@\n",hostName];
    [s appendFormat:@" addr: %@\n",hostAddr];
    [s appendFormat:@" port: %d\n",port];
    [s appendFormat:@" minSessions: %d\n",minSessions];
    [s appendFormat:@" maxSessions: %d\n",maxSessions];
    [s appendFormat:@" waitTimeout1: %d\n",waitTimeout1];
    [s appendFormat:@" waitTimeout2: %d\n",waitTimeout2];
    [s appendFormat:@" options: %@\n",options];
    [s appendFormat:@" socket: %@\n",socket];
    [s appendFormat:@" driverType: %s\n",dbdrivertype_to_string(dbDriverType)];
    [s appendFormat:@" storageType: %s\n",dbstoragetype_to_string(dbStorageType)];
    
    if(sessionsAvailable)
    {
        [s appendFormat:@" sessionsAvailable: %d items\n",(int)[sessionsAvailable count]];
    }
    else
    {
        [s appendFormat:@" sessionsAvailable: NULL\n"];
    }
    
    if(sessionsInUse)
    {
        [s appendFormat:@" sessionsInUse: %d items\n",(int)[sessionsInUse count]];
    }
    else
    {
        [s appendFormat:@" sessionsInUse: NULL\n"];
    }
    
    if(sessionsDisconnected)
    {
        [s appendFormat:@" sessionsDisconnected: %d items\n",(int)[sessionsDisconnected count]];
    }
    else
    {
        [s appendFormat:@" sessionsDisconnected: NULL\n"];
    }
    return s;
}

- (NSString *)inUseDescription
{
    NSMutableString *s = [NSMutableString stringWithString:[super description]];
    [_poolLock lock];
    UMDbSession *session = [sessionsInUse getFirst];
    while(session)
    {
        [s appendFormat:@"%@\n",[session inUseDescription]];
        [sessionsInUse append:session];
    }
    [_poolLock unlock];
    return s;
}
@end
