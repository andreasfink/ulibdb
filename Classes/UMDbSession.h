//
//  UMDbSession.h
//  ulibdb.framework
//
//  Created by Andreas Fink on 24.10.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.

#import "ulib/ulib.h"
#import "UMDbPool.h"
#import "UMDbResult.h"
#import "UMDbQuery.h"
#import "UMDbDriverType.h"


#define DEFAULT_MIN_DBSESSIONS      1
#define DEFAULT_MAX_DBSESSIONS      30

typedef enum UMDbSessionStatus 
{
    UMDBSESSION_STATUS_DISCONNECTED = 0,
    UMDBSESSION_STATUS_CONNECTED    = 2,
} UMDbSessionStatus;

@interface UMDbSession : UMObject
{
    UMDbPool            *pool;
    NSMutableDictionary *storedQueries;
    time_t              grabTime;
    time_t              returnTime;
    UMDbSessionStatus   sessionStatus;
    NSString            *versionString;
    NSString            *usedFile;
    long                usedLine;
    NSString            *usedFunction;
    NSString            *usedQuery;

    NSString            *lastUsedFile;
    long                lastUusedLine;
    NSString            *lastUsedFunction;
    NSString            *lastUsedQuery;
    NSString            *name;
    UMMutex             *_sessionLock;
}

@property (readwrite,strong)    UMDbPool    *pool;
@property (readwrite,strong)    NSString    *usedFile;
@property (readwrite,assign)    long        usedLine;
@property (readwrite,strong)    NSString    *usedFunction;
@property (readwrite,strong)    NSString    *usedQuery;

@property (readwrite,strong)    NSString    *lastUsedFile;
@property (readwrite,assign)    long        lastUsedLine;
@property (readwrite,strong)    NSString    *lastUsedFunction;
@property (readwrite,strong)    NSString    *lastUsedQuery;

@property (readwrite,strong)    NSString    *name;
@property (readwrite,assign)    UMDbSessionStatus   sessionStatus;

- (char)fieldQuoteChar;
- (UMDbSession *)initWithPool:(UMDbPool *)pool;
- (void) dealloc;
- (BOOL) isConnected;
- (NSString *)sessionStatusToString;
- (NSString *)description;

/* ***** those functions should be overloaded */
- (BOOL) connect; /* returns YES on success */
- (BOOL) reconnect; /* ditto */
- (void) disconnect;

- (UMDbResult *)queryWithMultipleRowsResult:(NSString *)sql;
- (UMDbResult *)queryWithMultipleRowsResult:(NSString *)sql allowFail:(BOOL)failPermission;

- (BOOL)queriesWithNoResult:(NSArray *)sqlCommands allowFail:(BOOL)failPermission;
- (BOOL)queryWithNoResult:(NSString *)sql allowFail:(BOOL)allowFail affectedRows:(unsigned long long *)count;

- (BOOL) ping;  /* returns YES on success */

- (UMDbResult *)cachedQueryWithMultipleRowsResult:(UMDbQuery *)query parameters:(NSArray *)arr allowFail:(BOOL)failPermission primaryKeyValue:(id)primaryKeyValue;
- (UMDbResult *)cachedQueryWithMultipleRowsResult:(UMDbQuery *)query parameters:(NSArray *)arr allowFail:(BOOL)failPermission;
- (UMDbResult *)cachedQueryWithMultipleRowsResult:(UMDbQuery *)query parameters:(NSArray *)arr;
- (UMDbResult *)cachedQueryWithMultipleRowsResult:(UMDbQuery *)query;

- (BOOL)cachedQueryWithNoResult:(UMDbQuery *)query parameters:(NSArray *)params allowFail:(BOOL)failPermission primaryKeyValue:(id)primaryKeyValue affectedRows:(unsigned long long *)count;
- (BOOL)cachedQueryWithNoResult:(UMDbQuery *)query parameters:(NSArray *)params allowFail:(BOOL)failPermission primaryKeyValue:(id)primaryKeyValue;
- (BOOL)cachedQueryWithNoResult:(UMDbQuery *)query parameters:(NSArray *)array allowFail:(BOOL)failPermission;
- (BOOL)cachedQueryWithNoResult:(UMDbQuery *)query parameters:(NSArray *)arr;
- (BOOL)cachedQueryWithNoResult:(UMDbQuery *)query;

/* These are specific to statistics*/
- (NSMutableArray *)currentStat;
- (BOOL)deleteCurrent;

/* These are specific to redis*/
- (int) hexistField:(NSString *)field ofKey:(NSString *)key  allowFail:(BOOL)failPermission;
- (NSNumber *) hincrFields:(NSArray *)arr ofKey:(NSString *)key by:(NSNumber *)incr incrementIsInteger:(BOOL)flag allowFail:(BOOL)failPermission withId:(NSString *)qid;

/* ***** */
- (void) touchGrabTimer;
- (void) touchReturnTimer;
- (UMDbPool *)pool;

+ (NSString *)prefixFields:(NSString *)fields withTableName:(NSString *)tableName;
- (void)setUsedFrom:(const char *)file line:(long)line func:(const char *)func;

- (NSString *)inUseDescription;
- (NSString *)sqlEscapeString:(NSString *)in;
@end
