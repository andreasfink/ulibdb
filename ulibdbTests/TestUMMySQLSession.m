//
//  TestUMMySQLSession.m
//  ulib
//
//  Created by Aarno Syvänen on 19.03.12.
//  Copyright (c) 2012 Fink Consulting GmbH. All rights reserved.
//

#import "TestUMMySQLSession.h"

#import <Foundation/Foundation.h>
#import "UMConfigGroup.h"
#import "UMConfig.h"
#import "UMDbQuery.h"
#import "UMDbQueryType.h"
#import "UMDbQueryCondition.h"
#import "UMDbTable.h"
#import "UMDbQueryPlaceholder.h"
#import "UMMySQLSession.h"

#define DEFAULT_MIN_DBSESSIONS      1
#define DEFAULT_MAX_DBSESSIONS      30
#define DEFAULT_MYSQL_PORT 0        /* Use default port */
#define MYSQL_DEBUG 1

@implementation TestUMMySQLSession

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    // Tear-down code here.
    [super tearDown];
}

+ (UMDbSession *)setUpConnectionWithPool:(UMDbPool *)dbPool
{
    NSString *cfgName = @"ulibdbTests/mysql-test.conf";
    
    UMConfig *cfg = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    
    [cfg allowSingleGroup:@"mysql-test-table"];
    [cfg read]; 
    
    NSDictionary *grp = [cfg getSingleGroup:@"mysql-test-table"];
    if (!grp)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must have group myql-test-table" userInfo:nil];
    
    long enable = 1;
    enable = [[grp objectForKey:@"enable"] integerValue];
    
    NSString *pool_name = [grp objectForKey:@"pool-name"];
    if (!pool_name)
        pool_name = @"";
    
    NSString *host = [grp objectForKey:@"host"];
    if (!host)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must contain host name" userInfo:nil];
    
    NSString *database_name = [grp objectForKey:@"database-name"];
    if (!database_name)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must contain database name" userInfo:nil];
    
    NSString *driver = @"mysql";
    
    NSString *user = [grp objectForKey:@"user"];
    if (!user)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must contain user name" userInfo:nil];
    
    NSString *pass = [grp objectForKey:@"pass"];
    if (!pass)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must contain password" userInfo:nil];
    
    long port = -1;
    port = [[grp objectForKey:@"port"] integerValue];
    long min_sessions = -1;
    min_sessions = [[grp objectForKey:@"min-sessions"] integerValue];
    long max_sessions = - 1;
    max_sessions = [[grp objectForKey:@"max-sessions"] integerValue];
    NSString *socket = [grp objectForKey:@"socket"]; /* Thos specifies an *UNIX* socket*/
    
    dbPool.poolName = [NSString stringWithString:pool_name];
    dbPool.hostName = [NSString stringWithString:host];
    dbPool.dbName = [NSString stringWithString:database_name];
    dbPool.dbDriverType = UMDriverTypeFromString([NSString stringWithString:driver]);
    dbPool.user = [NSString stringWithString:user];
    dbPool.pass = [NSString stringWithString:pass];
    
    if (socket)
        dbPool.socket = [NSString stringWithString:socket];
    else
         dbPool.socket = nil;
    
    if(min_sessions > 0)
    {
        dbPool.minSessions = (int)min_sessions;
    }
    else
    {
        dbPool.minSessions = DEFAULT_MIN_DBSESSIONS;
    }
    
    if(max_sessions > 0)
    {
        dbPool.maxSessions = (int)max_sessions;
    }
    else
    {
        dbPool.maxSessions = DEFAULT_MAX_DBSESSIONS;
    }
    
    dbPool.port = (int)port;
    
    BOOL sret = NO;
    UMMySQLSession *session = [[[UMMySQLSession alloc] initWithPool:dbPool] autorelease];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create mysql session to handle connection" userInfo:nil];

    UMLogHandler *handler = [[[UMLogHandler alloc] init] autorelease];
    [session setLogHandler:handler];
    sret = [session connect];
    if (sret == NO)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"mysql connection to the database could not be established" userInfo:nil];
    
    return session;
}

+ (NSString *) selectOneResultWithSession:(UMDbSession *)session
{
    UMDbResult *result = [session queryWithMultipleRowsResult:@"SHOW TABLES" allowFail:NO]; 
    if (!result)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"no result for a selection query for one result" userInfo:nil];
    
    NSArray *row = [result fetchRow];
    NSString *tn2 = [NSString stringWithUTF8String:[[row objectAtIndex:0]UTF8String]];
    if (!tn2)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not fethc a table name of the databasese" userInfo:nil];
    
    return tn2;
}

+ (NSArray *) selectManyResultsWithTable:(NSString *)t withTypes:(NSMutableArray **)types withSession:(UMDbSession *)session
{
    UMDbResult *result = [session queryWithMultipleRowsResult:[NSString stringWithFormat:@"SHOW COLUMNS IN %@", t] allowFail:NO];
    if (!result)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"no result for a selection query with many results" userInfo:nil];
    
    *types = [[[NSMutableArray alloc] init] autorelease];
    NSMutableArray *columns = [[[NSMutableArray alloc] init] autorelease];
    NSString *tn3, *tn4;
    NSArray *row;
    while ((row = [result fetchRow]))
    {
        tn3 = [NSString stringWithUTF8String:[[row objectAtIndex:0]UTF8String]];
        if (!tn3)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"column name row of selection query contains NULL" userInfo:nil];
        [columns addObject:tn3];
        
        tn4 = [NSString stringWithUTF8String:[[row objectAtIndex:1]UTF8String]];
        if (!tn4)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"column type row of selection query contains NULL" userInfo:nil];
        [*types addObject:tn4];
    }
    
    return columns;
}

+ (NSArray *) selectManyResultsWithTable:(NSString *)t withSession:(UMDbSession *)session
{
    UMDbResult *result = [session queryWithMultipleRowsResult:[NSString stringWithFormat:@"SHOW COLUMNS IN %@", t] allowFail:NO];
    if (!result)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"no result for a selection query with many results" userInfo:nil];
    
    NSMutableArray *types = [[[NSMutableArray alloc] init] autorelease];
    NSString *tn4;
    NSArray *row;
    while ((row = [result fetchRow]))
    {
        
        tn4 = [NSString stringWithUTF8String:[[row objectAtIndex:1]UTF8String]];
        if (!tn4)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"column type row of selection query contains NULL" userInfo:nil];
        [types addObject:tn4];
    }
    
    return types;
}

+ (NSArray *) selectRowFromTable:(NSString *)t withWhereLeft:(NSString *)left withWhereOp:(UMDbQueryConditionOperator)wop withWhereRight:(NSString *)right withSession:(UMDbSession *)session withKey:(NSString *)key
{
    UMDbQuery *sql = [[[UMDbQuery alloc] initForKey:key] autorelease];
    if (!sql)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create the query" userInfo:nil];
    
    if (![sql isInCache]) {
        [sql setType:UMDBQUERYTYPE_SELECT];
        [sql setFields:[NSArray arrayWithObject:@"*"]];
        NSString *tn    = [NSString stringWithString:t];
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        if (!table)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create table name for the query" userInfo:nil];
        
        [table setTableName:tn];
        [sql setTable:table];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:[UMDbQueryPlaceholder placeholderField:left]
                                                                             op:wop
                                                                          right:[UMDbQueryPlaceholder placeholderField:right]];
        if (!condition)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create where clause for the query" userInfo:nil];
        
        [sql setWhereCondition:condition];
        [sql setLimit:1];
    }
    
    [sql addToCache];
    
    UMDbResult *result = [session cachedQueryWithMultipleRowsResult:sql];
    if (!result)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"no result for a selection query with row" userInfo:nil];
    
    NSArray *row = [result fetchRow];
    return row;
}

+ (NSArray *) insertSomeIntoTable:(NSString *)tn havingColumns:(NSArray *)columns withTypes:(NSArray * ) types withSession:(UMDbSession *)session withPrimaryKey:(NSArray *)key withCacheKey:(NSString *)cacheKey
{
    NSUInteger uniquezer = 0;
    
    UMDbQuery *query = NULL;
    query = [[UMDbQuery alloc] initForKey:cacheKey];
    if (!query)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create a query" userInfo:nil];
    
    if(![query isInCache])
    {
        [query setType:UMDBQUERYTYPE_INSERT];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        if (!table)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create the tablename for a query" userInfo:nil];
        
        [table setTableName:tn];
        [query setTable:table];
        
        [query setFields:columns];
        [query addToCache];
    }
    
    NSMutableArray *params = [[[NSMutableArray alloc] init] autorelease];
    long numberOfColumns = [columns count];
    long i = 0;
    while (i < numberOfColumns)
    {
        NSString *name = [columns objectAtIndex:i];
        NSString *type = [types objectAtIndex:i];
        
        NSRange typeIsChar = [type rangeOfString:@"char"];
        NSRange typeIsInt = [type rangeOfString:@"int"];
    
        uniquezer = rand();
        
        if ([key indexOfObject:name] == NSNotFound) 
        {
            if (typeIsChar.length > 0)
                [params addObject:@"ad"];
            
            if (typeIsInt.length > 0)
                [params addObject:[NSString stringWithFormat:@"%d", 12345]];
        }
        else
        {
            if (typeIsChar.length > 0)
                [params addObject:[NSString stringWithFormat:@"ad%ld", uniquezer]];
            
            if (typeIsInt.length > 0)
                [params addObject:[NSString stringWithFormat:@"%lu", uniquezer]];
        }
        
        ++i;
    }
    
    BOOL res =  [session cachedQueryWithNoResult:query parameters:params  allowFail:NO];
    if (res == FALSE)
        return nil;
    
    return params;
}

+ (NSArray *) keysForTable:(NSString *)tn2 withSession:(UMDbSession *)session
{
    NSMutableArray *keys;
    
    NSString *sql = [NSString stringWithFormat:@"SHOW COLUMNS IN %@", tn2];
    
    UMDbResult *result = [session queryWithMultipleRowsResult:sql allowFail:NO];
    if (!result)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"no result for a constraint query" userInfo:nil];
    if ([result rowsCount] == 0)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"empty result for a constraint query" userInfo:nil];
    
    keys = [[[NSMutableArray alloc] init] autorelease];
    NSArray *row;
    NSString *constraint;
    
    while ((row = [result fetchRow]))
    {
        constraint = [NSString stringWithUTF8String:[[row objectAtIndex:3]UTF8String]];
        if (!constraint)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"result contained a nil constraints fields" userInfo:nil];
        
        NSRange range = [constraint rangeOfString:@"PRI"];
        if (range.length > 0)
            [keys addObject:[NSString stringWithUTF8String:[[row objectAtIndex:0] UTF8String]]];
    }
    
    return keys;
}

+ (BOOL)deleteFromTable:(NSString *)tn withConditionLeft:(NSString *)li withConditionRight:(NSString *)ri 
        withConditionOp:(UMDbQueryConditionOperator)wop withSession:(UMDbSession *)session withKey:(NSString *)key
{
    UMDbQuery *query = [[UMDbQuery alloc] initForKey:key];
    if (!query)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create a query" userInfo:nil];
    
    if(![query isInCache])
    {
        [query setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        if (!table)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create table name a query" userInfo:nil];
        
        [table setTableName:tn];
        [query setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:li];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:ri];
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:wop
                                                                          right:right];
        if (!condition)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create where clause for the query" userInfo:nil];
        
        [query setWhereCondition:condition];
        
        [query addToCache];
    }
    
    BOOL res =  [session cachedQueryWithNoResult:query parameters:NULL  allowFail:NO];
    return res;
}

+ (NSArray *)insertIntoSomeTable:(NSString **)tn withColumns:(NSArray **)columns withSession:(UMDbSession *)session withKey:(NSString *)key
{
    /* Do SHOW TABLES pick one of tables*/
    *tn =  [TestUMMySQLSession selectOneResultWithSession:session];
    
    /* Do SHOW COLUMNS IN 'table', store cOlumns Field and Type;*/
    NSMutableArray *types;
    *columns =  [TestUMMySQLSession selectManyResultsWithTable:*tn
                                                     withTypes:&types
                                                   withSession:session];
    
    /* Test insert does not contain any useful information,*/
    NSArray *keys = [TestUMMySQLSession keysForTable:*tn withSession:session];
    NSArray *inserted = [TestUMMySQLSession insertSomeIntoTable:*tn 
                                                  havingColumns:*columns 
                                                      withTypes:types 
                                                    withSession:session 
                                                 withPrimaryKey:keys 
                                                   withCacheKey:@"19"];
    return inserted;
}

+ (NSArray *)insertIntoOneTable:(NSString *)tn withColumns:(NSArray *)columns withSession:(UMDbSession *)session withKey:(NSString *)key
{
    
    /* Do SHOW COLUMNS IN 'table', store types;*/
    NSArray *types =  [TestUMMySQLSession selectManyResultsWithTable:tn
                                                         withSession:session];
    
    /* Test insert does not contain any useful information,*/
    NSArray *keys = [TestUMMySQLSession keysForTable:tn withSession:session];
    NSArray *inserted = [TestUMMySQLSession insertSomeIntoTable:tn 
                                                  havingColumns:columns 
                                                      withTypes:types 
                                                    withSession:session 
                                                 withPrimaryKey:keys 
                                                   withCacheKey:@"20"];
    return inserted;
}


+ (BOOL) assert:(NSArray *)a1 equals:(NSArray *)a2
{
    if (!a1)
        return FALSE;
    
    if (!a2)
        return FALSE;
    
    if ([a1 count] == 0)
        return FALSE;
    
    if ([a2 count] == 0)
        return FALSE;
    
    if ([a1 count] != [a2 count])
        return FALSE;
    
    long i = 0;
    long len = [a1 count];
    while (i < len) 
    {
        NSString *item = [a1 objectAtIndex:i];
        if ([item compare:[a2 objectAtIndex:i]] != NSOrderedSame)
            return FALSE;
        ++i;
    }
    
    return TRUE;
}

+ (NSArray *)updateOneTable:(NSString *)tn havingColumns:(NSArray *)columns withTypes:(NSArray *)types 
                    withKey:(NSArray *)keys withConditionLeft:(NSString *)li withConditionRight:(NSString *)ri 
            withConditionOp:(UMDbQueryConditionOperator)wop withSession:(UMDbSession *)session 
               withCacheKey:(NSString *)key
{
    NSMutableArray *updated; 
    NSUInteger uniquezer;
    
    UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
    if (!table)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create table name a query" userInfo:nil];
    
    [table setTableName:tn];
    
    UMDbQuery *query = [UMDbQuery queryForKey:key];
    if(![query isInCache])
    {
        [query setType:UMDBQUERYTYPE_UPDATE];
        [query setTable:table];
        [query setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:li];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:ri];
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:wop
                                                                          right:right];
        [query setWhereCondition:condition];
        
        [query addToCache];
    }
    
    updated = [[[NSMutableArray alloc] init] autorelease];
    long numberOfColumns = [columns count];
    long i = 0;
    while (i < numberOfColumns)
    {
        NSString *name = [columns objectAtIndex:i];
        NSString *type = [types objectAtIndex:i];
        
        NSRange typeIsChar = [type rangeOfString:@"char"];
        NSRange typeIsInt = [type rangeOfString:@"int"];
        
        if ([keys indexOfObject:name] == NSNotFound) 
        {
            if (typeIsChar.length > 0)
                [updated addObject:@"ad"];
            
            if (typeIsInt.length > 0)
                [updated addObject:[NSString stringWithFormat:@"%d", 12345]];
        }
        else
        {
            if (typeIsChar.length > 0)
                [updated addObject:[NSString stringWithFormat:@"ad%ld", uniquezer]];
            
            if (typeIsInt.length > 0)
                [updated addObject:[NSString stringWithFormat:@"%lu", uniquezer]];
        }
        
        ++i;
        uniquezer = rand();
    }
    
    BOOL success = [session cachedQueryWithNoResult:query parameters:updated];
    if (success == FALSE)
        return nil;
    else
        return updated;
}

+ (NSArray *)updateSomeTable:(NSString **)tn withColumns:(NSArray **)columns withConditionLeft:(NSString *)li withConditionRight:(NSString *)ri withConditionOp:(UMDbQueryConditionOperator)wop 
                 withSession:(UMDbSession *)session withKey:(NSString *)key
{
    /* Do SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'; to get tablenames. One is enough */
    *tn =  [TestUMMySQLSession selectOneResultWithSession:session];
    
    /* Do SHOW COLUMNS IN 'table', store cOlumns Field and Type;*/
    NSMutableArray *types;
    *columns =  [TestUMMySQLSession selectManyResultsWithTable:*tn
                                                     withTypes:&types
                                                   withSession:session];
    
    NSArray *keys = [TestUMMySQLSession keysForTable:*tn withSession:session];
    NSArray *updated = [TestUMMySQLSession updateOneTable:*tn 
                                            havingColumns:*columns 
                                                withTypes:types 
                                                  withKey:keys 
                                        withConditionLeft:li 
                                       withConditionRight:ri 
                                          withConditionOp:wop
                                              withSession:session 
                                             withCacheKey:@"24"];
    return updated;
}

- (void)testConnect
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    NSString *cfgName = @"ulibdbTests/mysql-test.conf";
    
    UMConfig *cfg = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    
    [cfg allowSingleGroup:@"mysql-test-table"];
    [cfg read];
    
    STAssertNotNil(cfg, @"could not read the configuration file");
    NSDictionary *grp = [cfg getSingleGroup:@"mysql-test-table"];
    STAssertNotNil(grp, @"could not read group from the configuration");
    
    long enable = 1;
    enable = [[grp objectForKey:@"enable"] integerValue];
    
    NSString *pool_name = [grp objectForKey:@"pool-name"];
    if (!pool_name)
        pool_name = @"";
    
    NSString *host = [grp objectForKey:@"host"];
    STAssertNotNil(host, @"could not read database host from the configuration");
    
    NSString *database_name = [grp objectForKey:@"database-name"];
    STAssertNotNil(database_name, @"could not read database name from the configuration");
    
    NSString *driver = @"mysql";
    
    NSString *user = [grp objectForKey:@"user"];
    STAssertNotNil(user, @"could not read username from the configuration");
    
    NSString *pass = [grp objectForKey:@"pass"];
    STAssertNotNil(pass, @"could not read password from the configuration");
    
    long port = -1;
    port = [[grp objectForKey:@"port"] integerValue];
    long min_sessions = -1;
    min_sessions = [[grp objectForKey:@"min-sessions"] integerValue];
    long max_sessions = - 1;
    max_sessions = [[grp objectForKey:@"max-sessions"] integerValue];
    NSString *socket = [grp objectForKey:@"socket"]; /* This would be *uniX* socket used by the program*/
    
    pool = [[[UMDbPool alloc] init] autorelease];
    pool.poolName = [NSString stringWithString:pool_name];
    pool.hostName = [NSString stringWithString:host];
    pool.dbName = [NSString stringWithString:database_name];
    pool.dbDriverType = UMDriverTypeFromString([NSString stringWithString:driver]);
    pool.user = [NSString stringWithString:user];
    pool.pass = [NSString stringWithString:pass];
    
    if (socket)
        pool.socket = [NSString stringWithString:socket];
    else
        pool.socket = nil;
    
    if(min_sessions > 0)
    {
        pool.minSessions = (int)min_sessions;
    }
    else
    {
        pool.minSessions = DEFAULT_MIN_DBSESSIONS;
    }
    
    if(max_sessions > 0)
    {
        pool.maxSessions = (int)max_sessions;
    }
    else
    {
        pool.maxSessions = DEFAULT_MAX_DBSESSIONS;
    }
    
    if(port > 0)
    {
        pool.port = (int)port;
    }
    else
    {
        pool.port = DEFAULT_MYSQL_PORT;
    }
    
    BOOL sret = NO;
    UMMySQLSession *session = [[[UMMySQLSession alloc] initWithPool:pool] autorelease];
    UMLogHandler *handler = [[[UMLogHandler alloc] init] autorelease];
    [session setLogHandler:handler];
    sret = [session connect];
    STAssertTrue(sret, @"could not connect to database");
    
    sret = [session ping];
    STAssertTrue(sret, @"could not ping the database");
    
    [session disconnect];
    
    [autoPool release];
}

/* Use system tables for pure select. We do not test connection stuff second time */
- (void)testCachedSelect
{
    srand((unsigned int)time(NULL));
    
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    UMDbQuery *sql = [[[UMDbQuery alloc] initForKey:@"16"] autorelease];
    STAssertNotNil(sql, @"could not create a query"); 
    NSString *tn = @"INFORMATION_SCHEMA.COLLATIONS";
    
    if (![sql isInCache]) {
        [sql setType:UMDBQUERYTYPE_SELECT];
        [sql setFields:[NSArray arrayWithObject:@"CHARACTER_SET_NAME"]];
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        STAssertNotNil(table, @"could not create a table name for a query"); 
        
        [table setTableName:tn];
        [sql setTable:table];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:[UMDbQueryPlaceholder placeholderField:@"COLLATION_NAME"]
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:[UMDbQueryPlaceholder placeholderField:@"latin1_german1_ci "]];
        STAssertNotNil(condition, @"could not create where clause for a query"); 
        
        [sql setWhereCondition:condition];
        [sql setLimit:1];
    }
    
    [sql addToCache];
    
    UMDbResult *result = [session cachedQueryWithMultipleRowsResult:sql]; 
    STAssertNotNil(result, @"could not select from the database"); 
    
    [session disconnect];
    
    [autoPool release];
}

/* Find one table name before inserting anything. If there are none, setting is erroneous. Then find column names and typex, and try to insert bogus data. */
- (void)testCachedInsertAndDelete
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    srand((unsigned int)time(NULL));
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    /* Insert something to some table - this is the test*/
    NSString *tn2 = nil;
    NSArray *columns = nil;
    NSArray *inserted = [TestUMMySQLSession insertIntoSomeTable:&tn2 
                                                    withColumns:&columns 
                                                    withSession:session withKey:@"8"];
    STAssertNotNil(inserted, @"could not insert data into database, database error");
    STAssertTrue([inserted count] > 0, @"could not insert data into database, none inserted");
    
    /*delete one just added */
    NSString *li = [columns objectAtIndex:1];
    NSString *ri = [inserted objectAtIndex:1];
    BOOL res = [TestUMMySQLSession deleteFromTable:tn2 
                                 withConditionLeft:li 
                                withConditionRight:ri 
                                   withConditionOp:UMDBQUERY_OPERATOR_EQUAL 
                                       withSession:session 
                                           withKey:@"12"];
    STAssertTrue(res, @"could not delete from the database");
    
    [session disconnect];
    
    [autoPool release];
}

/* Query for primary keyes of the table. This test another select method. */
- (void) testGetKeys
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    NSString *tn2 = [TestUMMySQLSession selectOneResultWithSession:session];
    NSString *sql = [NSString stringWithFormat:@"SHOW COLUMNS IN %@", tn2];
    
    UMDbResult *result = [session queryWithMultipleRowsResult:sql allowFail:NO];
    STAssertNotNil(result, @"could not get result for key constraint query");
    STAssertTrue([result rowsCount] > 0, @"constraint query resulted with an empty result");
    
    [session disconnect];
    
    [autoPool release];
}

- (void)testSelectFromMany
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    srand((unsigned int)time(NULL));
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    /* Insert many random rows to some table - this is the test. However we must honor key uniqueness*/
    NSString *tn2 = nil;
    NSArray *columns1 = nil;
    NSArray *inserted1 = [TestUMMySQLSession insertIntoSomeTable:&tn2 
                                                     withColumns:&columns1 
                                                     withSession:session 
                                                         withKey:@"9"];
    STAssertNotNil(inserted1, @"could not insert data into database");
    NSArray *keys = [TestUMMySQLSession keysForTable:tn2 withSession:session];
    NSArray *types =  [TestUMMySQLSession selectManyResultsWithTable:tn2
                                                         withSession:session];
    NSArray *inserted2 = [TestUMMySQLSession insertSomeIntoTable:tn2 
                                                   havingColumns:columns1 
                                                       withTypes:types
                                                     withSession:session 
                                                  withPrimaryKey:keys
                                                    withCacheKey:@"18"];
    STAssertNotNil(inserted2, @"could not insert data into database");
    NSArray *inserted3 = [TestUMMySQLSession insertSomeIntoTable:tn2 
                                                   havingColumns:columns1 
                                                       withTypes:types
                                                     withSession:session 
                                                  withPrimaryKey:keys
                                                    withCacheKey:@"11"];
    STAssertNotNil(inserted3, @"could not insert data into database");
    
    /* Try to select previously inserted data. Use key in where clase, it quarantees unique results*/
    NSString *li;
    NSString *ri;
    NSString *ri2;
    NSString *ri3;
    if (keys)
    {
        NSString *ki = [keys objectAtIndex:0];
        NSUInteger index = [columns1 indexOfObject:ki];
        li = [columns1 objectAtIndex:index];
        ri = [inserted1 objectAtIndex:index];
        ri2 = [inserted2 objectAtIndex:index];
        ri3 = [inserted3 objectAtIndex:index];
    }
    else
    {
        li = [columns1 objectAtIndex:1];
        ri = [inserted1 objectAtIndex:1];
        ri2 = [inserted2 objectAtIndex:1];
        ri3 = [inserted3 objectAtIndex:1];
    }
    
    NSArray *selected1 = [TestUMMySQLSession selectRowFromTable:tn2
                                                  withWhereLeft:li
                                                    withWhereOp:UMDBQUERY_OPERATOR_EQUAL
                                                 withWhereRight:ri
                                                    withSession:session
                                                        withKey:@"6"];
    STAssertNotNil(selected1, @"could not find previously inserted data from the database, query result points to nil");
    STAssertTrue([selected1 count] > 0, @"could not find previously inserted data from the database, empty result");
    BOOL res = [TestUMMySQLSession assert:inserted1 equals:selected1];
    STAssertTrue(res, @"inserted row differs from a selected one");
    
    NSArray *selected2 = [TestUMMySQLSession selectRowFromTable:tn2
                                                  withWhereLeft:li
                                                    withWhereOp:UMDBQUERY_OPERATOR_EQUAL
                                                 withWhereRight:ri2
                                                    withSession:session
                                                        withKey:@"5"];
    STAssertNotNil(selected2, @"could not find previously inserted data from the database, query result points to nil");
    STAssertTrue([selected2 count] > 0, @"could not find previously inserted data from the database, empty result");
    res = [TestUMMySQLSession assert:inserted2 equals:selected2];
    STAssertTrue(res, @"inserted row differs from a selected one");
    
    NSArray *selected3 = [TestUMMySQLSession selectRowFromTable:tn2
                                                  withWhereLeft:li
                                                    withWhereOp:UMDBQUERY_OPERATOR_EQUAL
                                                 withWhereRight:ri3
                                                    withSession:session
                                                        withKey:@"7"];
    STAssertNotNil(selected3, @"could not find previously inserted data from the database, query result points to nil");
    STAssertTrue([selected3 count] > 0, @"could not find previously inserted data from the database, empty result");
    res = [TestUMMySQLSession assert:inserted3 equals:selected3];
    STAssertTrue(res, @"inserted row differs from a selected one");
    
    /*delete just added omes*/
    res = [TestUMMySQLSession deleteFromTable:tn2 
                            withConditionLeft:li 
                           withConditionRight:ri 
                              withConditionOp:UMDBQUERY_OPERATOR_EQUAL 
                                  withSession:session 
                                      withKey:@"13"];
    STAssertTrue(res, @"could not delete from the database");
    
    res = [TestUMMySQLSession deleteFromTable:tn2 
                            withConditionLeft:li 
                           withConditionRight:ri2 
                              withConditionOp:UMDBQUERY_OPERATOR_EQUAL 
                                  withSession:session 
                                      withKey:@"14"];
    STAssertTrue(res, @"could not delete from the database");
    
    res = [TestUMMySQLSession deleteFromTable:tn2 
                            withConditionLeft:li
                           withConditionRight:ri3 
                              withConditionOp:UMDBQUERY_OPERATOR_EQUAL 
                                  withSession:session 
                                      withKey:@"15"];
    STAssertTrue(res, @"could not delete from the database");
    
    [session disconnect];
    
    [autoPool release];
}

/* Insert three rows, update all these rows and then select values of each updated row. Lastly, delete all
 * rows*/
- (void)testUpdate
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    srand((unsigned int)time(NULL));
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    /* Insert rows to be updated */
    NSString *tn2 = nil;
    NSArray *columns1 = nil;
    NSArray *inserted1 = [TestUMMySQLSession insertIntoSomeTable:&tn2 
                                                     withColumns:&columns1 
                                                     withSession:session 
                                                         withKey:@"26"];
    STAssertNotNil(inserted1, @"could not insert data into database");
    
    NSArray *keys = [TestUMMySQLSession keysForTable:tn2 withSession:session];
    NSArray *types =  [TestUMMySQLSession selectManyResultsWithTable:tn2 
                                                         withSession:session];
    
    NSArray *inserted2 = [TestUMMySQLSession insertSomeIntoTable:tn2 
                                                   havingColumns:columns1 
                                                       withTypes:types
                                                     withSession:session 
                                                  withPrimaryKey:keys
                                                    withCacheKey:@"29"];
    STAssertNotNil(inserted2, @"could not insert data into database");
    
    NSArray *inserted3 = [TestUMMySQLSession insertSomeIntoTable:tn2 
                                                   havingColumns:columns1 
                                                       withTypes:types
                                                     withSession:session 
                                                  withPrimaryKey:keys
                                                    withCacheKey:@"31"];
    STAssertNotNil(inserted3, @"could not insert data into database");
    
    /* Try to update previously inserted data. Use key in where clase, it quarantees unique results*/
    NSString *li;
    NSString *ri;
    NSString *ri2;
    NSString *ri3;
    if (keys)
    {
        NSString *ki = [keys objectAtIndex:0];
        NSUInteger index = [columns1 indexOfObject:ki];
        li = [columns1 objectAtIndex:index];
        ri = [inserted1 objectAtIndex:index];
        ri2 = [inserted2 objectAtIndex:index];
        ri3 = [inserted3 objectAtIndex:index];
    }
    else
    {
        li = [columns1 objectAtIndex:1];
        ri = [inserted1 objectAtIndex:1];
        ri2 = [inserted2 objectAtIndex:1];
        ri3 = [inserted3 objectAtIndex:1];
    }
    
    NSArray *updated1 = [TestUMMySQLSession updateOneTable:tn2
                                             havingColumns:columns1 
                                                 withTypes:types 
                                                   withKey:keys
                                         withConditionLeft:li 
                                        withConditionRight:ri 
                                           withConditionOp:UMDBQUERY_OPERATOR_EQUAL
                                               withSession:session 
                                              withCacheKey:@"24"];
    STAssertNotNil(updated1, @"could not update the database");
    
    NSArray *updated2 = [TestUMMySQLSession updateOneTable:tn2
                                             havingColumns:columns1 
                                                 withTypes:types 
                                                   withKey:keys
                                         withConditionLeft:li 
                                        withConditionRight:ri2 
                                           withConditionOp:UMDBQUERY_OPERATOR_EQUAL
                                               withSession:session 
                                              withCacheKey:@"32"];
    STAssertNotNil(updated2, @"could not update the database");
    
    NSArray *updated3 = [TestUMMySQLSession updateOneTable:tn2
                                             havingColumns:columns1 
                                                 withTypes:types 
                                                   withKey:keys
                                         withConditionLeft:li 
                                        withConditionRight:ri3 
                                           withConditionOp:UMDBQUERY_OPERATOR_EQUAL
                                               withSession:session 
                                              withCacheKey:@"33"];
    STAssertNotNil(updated3, @"could not update the database");
    
    /* Then select the updated data */
    [li release];
    [ri release];
    [ri2 release];
    [ri3 release];
    if (keys)
    {
        NSString *ki = [keys objectAtIndex:0];
        NSUInteger index = [columns1 indexOfObject:ki];
        li = [columns1 objectAtIndex:index];
        ri = [updated1 objectAtIndex:index];
        ri2 = [updated2 objectAtIndex:index];
        ri3 = [updated3 objectAtIndex:index];
    }
    else
    {
        li = [columns1 objectAtIndex:1];
        ri = [updated1 objectAtIndex:1];
        ri2 = [updated2 objectAtIndex:1];
        ri3 = [updated3 objectAtIndex:1];
    }
    
    NSArray *selected1 = [TestUMMySQLSession selectRowFromTable:tn2
                                                  withWhereLeft:li
                                                    withWhereOp:UMDBQUERY_OPERATOR_EQUAL
                                                 withWhereRight:ri
                                                    withSession:session
                                                        withKey:@"28"];
    STAssertNotNil(selected1, @"could not find previously updated data from the database, query result points to nil");
    STAssertTrue([selected1 count] > 0, @"could not find previously updated data from the database, empty result");
    BOOL res = [TestUMMySQLSession assert:updated1 equals:selected1];
    STAssertTrue(res, @"updated row differs from a selected one");
    
    NSArray *selected2 = [TestUMMySQLSession selectRowFromTable:tn2
                                                  withWhereLeft:li
                                                    withWhereOp:UMDBQUERY_OPERATOR_EQUAL
                                                 withWhereRight:ri2
                                                    withSession:session
                                                        withKey:@"34"];
    STAssertNotNil(selected2, @"could not find previously updated data from the database, query result points to nil");
    STAssertTrue([selected2 count] > 0, @"could not find previously updated data from the database, empty result");
    res = [TestUMMySQLSession assert:updated2 equals:selected2];
    STAssertTrue(res, @"updated row differs from a selected one");
    
    NSArray *selected3 = [TestUMMySQLSession selectRowFromTable:tn2
                                                  withWhereLeft:li
                                                    withWhereOp:UMDBQUERY_OPERATOR_EQUAL
                                                 withWhereRight:ri3
                                                    withSession:session
                                                        withKey:@"35"];
    STAssertNotNil(selected3, @"could not find previously updated data from the database, query result points to nil");
    STAssertTrue([selected3 count] > 0, @"could not find previously updated data from the database, empty result");
    res = [TestUMMySQLSession assert:updated3 equals:selected3];
    STAssertTrue(res, @"updated row differs from a selected one");
    
    res = [TestUMMySQLSession deleteFromTable:tn2 
                            withConditionLeft:li
                           withConditionRight:ri 
                              withConditionOp:UMDBQUERY_OPERATOR_EQUAL 
                                  withSession:session 
                                      withKey:@"36"];
    STAssertTrue(res, @"could not delete from the database");
    
    res = [TestUMMySQLSession deleteFromTable:tn2 
                            withConditionLeft:li
                           withConditionRight:ri2 
                              withConditionOp:UMDBQUERY_OPERATOR_EQUAL 
                                  withSession:session 
                                      withKey:@"37"];
    STAssertTrue(res, @"could not delete from the database");
    
    res = [TestUMMySQLSession deleteFromTable:tn2 
                            withConditionLeft:li
                           withConditionRight:ri3 
                              withConditionOp:UMDBQUERY_OPERATOR_EQUAL 
                                  withSession:session 
                                      withKey:@"38"];
    STAssertTrue(res, @"could not delete from the database");
    
    [session disconnect];
    
    [autoPool release];
}

/* Then error cases, First rejection of nil*/
- (void)testConnectErrorNil
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    NSString *cfgName = nil;
    
    UMConfig *cfg = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    STAssertNil(cfg, @"nil file name should be rejected by configuration");
    
    cfgName = @"ulibdbTests/mysql-test.conf";
    
    cfg = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    
    [cfg allowSingleGroup:@"mysql-test-table"];
    [cfg read];
    
    NSDictionary *grp = [cfg getSingleGroup:nil];
    STAssertNil(grp, @"nil group name should be rejected by configuration");
    
    grp = [cfg getSingleGroup:@"mysql-test-table"];
    
    long enable = 1;
    enable = [[grp objectForKey:@"enable"] integerValue];
    
    NSString *pool_name = [grp objectForKey:@"pool-name"];
    if (!pool_name)
        pool_name = @"";
    
    NSString *host = [grp objectForKey:@"host"];
    NSString *database_name = [grp objectForKey:@"database-name"];
    NSString *driver = @"mysql";
    NSString *user = [grp objectForKey:@"user"];
    NSString *pass = [grp objectForKey:@"pass"];
    
    long port = -1;
    port = [[grp objectForKey:@"port"] integerValue];
    long min_sessions = -1;
    min_sessions = [[grp objectForKey:@"min-sessions"] integerValue];
    long max_sessions = - 1;
    max_sessions = [[grp objectForKey:@"max-sessions"] integerValue];
    NSString *socket = [grp objectForKey:@"socket"]; /* This would be *unix* socket used by program */
    
    BOOL sret = NO;
    UMMySQLSession *session = [[[UMMySQLSession alloc] initWithPool:nil] autorelease];
    STAssertNil(session, @"nil pool name should be rejected when trying to create a session");
    UMLogHandler *handler = [[[UMLogHandler alloc] init] autorelease];
    [session setLogHandler:handler];
    
    pool = [[[UMDbPool alloc] init] autorelease];
    
    pool.poolName = [NSString stringWithString:pool_name];
    pool.hostName = [NSString stringWithString:host];
    pool.dbName = [NSString stringWithString:database_name];
    pool.dbDriverType = UMDriverTypeFromString([NSString stringWithString:driver]);
    pool.user = [NSString stringWithString:user];
    pool.pass = [NSString stringWithString:pass];
    
    if (socket)
        pool.socket = [NSString stringWithString:socket];
    else
        pool.socket = nil;
    
    if(min_sessions > 0)
    {
        pool.minSessions = (int)min_sessions;
    }
    else
    {
        pool.minSessions = DEFAULT_MIN_DBSESSIONS;
    }
    
    if(max_sessions > 0)
    {
        pool.maxSessions = (int)max_sessions;
    }
    else
    {
        pool.maxSessions = DEFAULT_MAX_DBSESSIONS;
    }
    
    if(port > 0)
    {
        pool.port = (int)port;
    }
    else
    {
        pool.port = DEFAULT_MYSQL_PORT;
    }
    
    sret = NO;
    session = [[[UMMySQLSession alloc] initWithPool:pool] autorelease];
    handler = [[[UMLogHandler alloc] init] autorelease];
    [session setLogHandler:handler];
    sret = [session connect];
    sret = [session ping];
    [session disconnect];
    
    [autoPool release];
}

- (void)testCachedSelectNil
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    UMDbQuery *sql = [[UMDbQuery alloc] initForKey:nil];
    STAssertNotNil(sql, @"sql creation should accept kil key, though ressult is insane");
    
    sql = [[UMDbQuery alloc] initForKey:@"16"];
    
    if (![sql isInCache])
    {
        [sql setType:UMDBQUERYTYPE_SELECT];
        [sql setFields:[NSArray arrayWithObject:@"CHARACTER_SET_NAME"]];
        
        NSString *tn    = @"NFORMATION_SCHEMA.COLLATIONS";
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn];
        [sql setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:nil];
        STAssertNotNil(left, @"should create placeholder with nil, though ressult will be insane");
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:nil];
        STAssertNotNil(left, @"should create placeholder with nil, though ressult will be insane");
        
        left = [UMDbQueryPlaceholder placeholderField:@"COLLATION_NAME"];
        right = [UMDbQueryPlaceholder placeholderField:@"latin1_german1_ci"];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:nil
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        STAssertNotNil(condition, @"condition should accept nil placeholder, even though result is insane");
        
        condition =  [UMDbQueryCondition queryConditionLeft:left
                                                         op:UMDBQUERY_OPERATOR_EQUAL
                                                      right:nil];
        STAssertNotNil(condition, @"condition should accept nil placeholder, even though result is insane");
        
        condition =  [UMDbQueryCondition queryConditionLeft:left
                                                         op:UMDBQUERY_OPERATOR_EQUAL
                                                      right:right];
        
        [sql setWhereCondition:condition];
        [sql setLimit:1];
    }
    
    UMDbResult *result = [session cachedQueryWithMultipleRowsResult:nil]; 
    STAssertNotNil(result, @"query should accept nil sql, though result would be insane");
    STAssertTrue([result rowsCount] == 0, @"erroneous query should have empty result");
    
    /* Then queries with nil field*/
    UMDbQuery *sql1 = [[UMDbQuery alloc] initForKey:@"40"];
    
    if (![sql1 isInCache])
    {
        [sql1 setType:UMDBQUERYTYPE_SELECT];
        [sql1 setFields:nil];
        
        NSString *tn    = @"INFORMATION_SCHEMA.COLLATIONS";
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn];
        [sql1 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:@"COLLATION_NAME"];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@"latin1_german1_ci"];
        
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql1 setWhereCondition:condition];
        [sql1 setLimit:1];
    }
    
    UMDbResult *result1;
    @try
    {
        result1 = [session cachedQueryWithMultipleRowsResult:sql1]; 
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Fields are nil,cannot create MySQL query"] == NSOrderedSame, @"Mysql query with nil feilds should raise exception");
    }
        
    
    UMDbQuery *sql2 = [[UMDbQuery alloc] initForKey:@"40"];
    
    if (![sql2 isInCache])
    {
        [sql2 setType:UMDBQUERYTYPE_SELECT];
        [sql2 setFields:[NSArray arrayWithObject:@"CHARACTER_SET_NAME"]];
        
        NSString *tn = nil;
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn];
        [sql2 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:@"COLLATION_NAME"];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@"latin1_german1_ci"];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql2 setWhereCondition:condition];
        [sql2 setLimit:1];
    }
    
    UMDbResult *result2;
    @try
    {
        result2 = [session cachedQueryWithMultipleRowsResult:sql2];
    }
    @catch(NSException *exception) {
         NSString *reason = [exception reason];    
         STAssertTrue([reason compare:@"Table name is nil, cannot create query"] == NSOrderedSame, @"querying with table name nil should threw an exception");
    }
    
    UMDbQuery *sql3 = [[UMDbQuery alloc] initForKey:@"41"];
    
    if (![sql3 isInCache])
    {
        [sql3 setType:UMDBQUERYTYPE_SELECT];
        [sql3 setFields:[NSArray arrayWithObject:@"CHARACTER_SET_NAME"]];
        
        [sql3 setTable:nil];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:@"COLLATION_NAME"];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@"latin1_german1_ci"];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql3 setWhereCondition:condition];
        [sql3 setLimit:1];
    }
    
    UMDbResult *result3;
    @try
    {
        result3 = [session cachedQueryWithMultipleRowsResult:sql3];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Table name is nil, cannot create query"] == NSOrderedSame, @"qsing table name nil should generate an exception");
    }
    
    UMDbQuery *sql4 = [[UMDbQuery alloc] initForKey:@"42"];
    
    if (![sql4 isInCache])
    {
        [sql4 setType:UMDBQUERYTYPE_SELECT];
        [sql4 setFields:[NSArray arrayWithObject:@"CHARACTER_SET_NAME"]];
        
        NSString *tn = @"INFORMATION_SCHEMA.COLLATIONS";
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        
        [table setTableName:tn];
        [sql4 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:nil];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@"latin1_german1_ci"];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql4 setWhereCondition:condition];
        [sql4 setLimit:1];
    }
    
    UMDbResult *result4;
    @try
    {
        result4 = [session cachedQueryWithMultipleRowsResult:sql4];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Left condition is nil, cannot create query"] == NSOrderedSame, @"qsing left condition nil should generate an exception");
    }
    
    UMDbQuery *sql5 = [[UMDbQuery alloc] initForKey:@"43"];
    
    if (![sql5 isInCache])
    {
        [sql5 setType:UMDBQUERYTYPE_SELECT];
        [sql5 setFields:[NSArray arrayWithObject:@"CHARACTER_SET_NAME"]];
        
        NSString *tn = @"INFORMATION_SCHEMA.COLLATIONS";
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        
        [table setTableName:tn];
        [sql5 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:@"COLLATION_NAME"];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:nil];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql5 setWhereCondition:condition];
        [sql5 setLimit:1];
    }
    
    
    UMDbResult *result5 = [session cachedQueryWithMultipleRowsResult:sql5];
    STAssertNotNil(result5, @"query should accept with right condition NULL");
    STAssertTrue([result5 rowsCount] == 0, @"system tables does not have any unknown fields");
    
    UMDbQuery *sql6 = [[UMDbQuery alloc] initForKey:@"49"];
    
    if (![sql6 isInCache])
    {
        [sql6 setType:UMDBQUERYTYPE_SELECT];
        [sql6 setFields:[NSArray arrayWithObject:@""]];
        
        NSString *tn = @"INFORMATION_SCHEMA.COLLATIONS";
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn];
        [sql6 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:@"COLLATION_NAME"];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@"latin1_german1_ci"];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql6 setWhereCondition:condition];
        [sql6 setLimit:1];
    }
    
    UMDbResult *result6;
    @try
    {
        result6 = [session cachedQueryWithMultipleRowsResult:sql6];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Fields are empty, cannot create query"] == NSOrderedSame, @"qsing empty fieldsshould generate an exception");
    }
    
    [session disconnect];
    
    [autoPool release];
}


-(void) testCachedSelectEmpty
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    UMDbQuery *sql6A = [[UMDbQuery alloc] initForKey:@"50"];
    
    if (![sql6A isInCache])
    {
        [sql6A setType:UMDBQUERYTYPE_SELECT];
        [sql6A setFields:[NSArray arrayWithObject:@"table_name"]];
        
        NSString *tn = @"";
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn];
        [sql6A setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:@"table_schema"];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@"public"];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql6A setWhereCondition:condition];
        [sql6A setLimit:1];
    }
    
    UMDbResult *result6A;
    @try
    {
        result6A = [session cachedQueryWithMultipleRowsResult:sql6A];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"table name empty, cannot create query"] == NSOrderedSame, @"qsing empty r´table name should generate an exception");
    }
    
    UMDbQuery *sql7 = [[UMDbQuery alloc] initForKey:@"51"];
    
    if (![sql7 isInCache])
    {
        [sql7 setType:UMDBQUERYTYPE_SELECT];
        [sql7 setFields:[NSArray arrayWithObject:@"CHARACTER_SET_NAME"]];
        
        NSString *tn = @"INFORMATION_SCHEMA.COLLATIONS";
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn];
        [sql7 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:@""];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@"latin1_german1_ci"];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql7 setWhereCondition:condition];
        [sql7 setLimit:1];
    }
    
    UMDbResult *result7;
    @try
    {
        result7 = [session cachedQueryWithMultipleRowsResult:sql7];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Left condition is empty, cannot create query"] == NSOrderedSame, @"qsing empty left condition should generate an exception"); 
    }
    
    UMDbQuery *sql8 = [[UMDbQuery alloc] initForKey:@"52"];
    
    if (![sql8 isInCache])
    {
        [sql8 setType:UMDBQUERYTYPE_SELECT];
        [sql8 setFields:[NSArray arrayWithObject:@"CHARACTER_SET_NAME"]];
        
        NSString *tn = @"INFORMATION_SCHEMA.COLLATIONS";
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        
        [table setTableName:tn];
        [sql8 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:@"COLLATION_NAME"];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@""];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql8 setWhereCondition:condition];
        [sql8 setLimit:1];
    }
    
    UMDbResult *result8 = [session cachedQueryWithMultipleRowsResult:sql8];
    STAssertNotNil(result8, @"query should accept empty rigth condition");
    STAssertTrue([result8 rowsCount] == 0, @"system tables does not have any empty fields");
    
    [session disconnect];
    
    [autoPool release];
}

- (void) testCachedDeleteNil
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    srand((unsigned int)time(NULL));
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    /* For testing deleetions,add random data to a random table*/
    NSString *tn2 = nil;
    NSArray *columns1 = nil;
    NSArray *inserted1 = [TestUMMySQLSession insertIntoSomeTable:&tn2 
                                                     withColumns:&columns1 
                                                     withSession:session 
                                                         withKey:@"54"];   
    
    UMDbQuery *sql9 = [[UMDbQuery alloc] initForKey:@"53"];
    
    if (![sql9 isInCache])
    {
        [sql9 setType:UMDBQUERYTYPE_DELETE];
        [sql9 setFields:nil];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql9 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns1 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted1 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql9 setWhereCondition:condition];
    }
    
    
    BOOL res = [session cachedQueryWithNoResult:sql9];
    STAssertTrue(res, @"delete query should ignore fields, nil or otherwise");
    
    NSString *tn3 = nil;
    NSArray *columns2 = nil;
    NSArray *inserted2 = [TestUMMySQLSession insertIntoSomeTable:&tn3 
                                                     withColumns:&columns2
                                                     withSession:session 
                                                         withKey:@"55"]; 
    
    UMDbQuery *sql10 = [[UMDbQuery alloc] initForKey:@"56"];
    
    if (![sql10 isInCache])
    {
        [sql10 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql10 setTable:nil];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns1 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted1 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql9 setWhereCondition:condition];
    }
    
    @try 
    {
        res = [session cachedQueryWithNoResult:sql10];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Delete with table name nil, cannot create query"] == NSOrderedSame, @"using nil table name when deleting should generate an exception");
    }
    
    UMDbQuery *sql11 = [[UMDbQuery alloc] initForKey:@"57"];
    
    if (![sql11 isInCache])
    {
        [sql11 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql11 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns2 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted2 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql11 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql11];
    
    NSString *tn4 = nil;
    NSArray *columns3 = nil;
    NSArray *inserted3 = [TestUMMySQLSession insertIntoSomeTable:&tn4 
                                                     withColumns:&columns3
                                                     withSession:session 
                                                         withKey:@"55"]; 
    
    UMDbQuery *sql12 = [[UMDbQuery alloc] initForKey:@"58"];
    
    if (![sql12 isInCache])
    {
        [sql12 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn4];
        [sql12 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:nil];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted1 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql12 setWhereCondition:condition];
    }
    
    @try 
    {
        res = [session cachedQueryWithNoResult:sql12];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Left condition is nil, cannot create query"] == NSOrderedSame, @"using nil left condition when deleting should generate an exception");
    }
    
    UMDbQuery *sql13 = [[UMDbQuery alloc] initForKey:@"59"];
    
    if (![sql13 isInCache])
    {
        [sql13 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql13 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns3 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted3 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql13 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql13];
    
    NSString *tn5 = nil;
    NSArray *columns4 = nil;
    NSArray *inserted4 = [TestUMMySQLSession insertIntoSomeTable:&tn5 
                                                     withColumns:&columns4
                                                     withSession:session 
                                                         withKey:@"55"]; 
    
    UMDbQuery *sql14 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql14 isInCache])
    {
        [sql14 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql14 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns4 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:nil];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql14 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql14];
    STAssertTrue(res, @"query with right condition should be legal");
    
    UMDbQuery *sql15 = [[UMDbQuery alloc] initForKey:@"61"];
    
    if (![sql15 isInCache])
    {
        [sql15 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql15 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns4 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted4 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql15 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql15];
    
    NSString *tn6 = nil;
    NSArray *columns5= nil;
    NSArray *inserted5 = [TestUMMySQLSession insertIntoSomeTable:&tn6
                                                     withColumns:&columns5
                                                     withSession:session 
                                                         withKey:@"62"]; 
    
    UMDbQuery *sql16 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql16 isInCache])
    {
        [sql16 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql16 setTable:table];
        
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted5 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:nil
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql16 setWhereCondition:condition];
    }
    
    @try 
    {
        res = [session cachedQueryWithNoResult:sql16];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Left condition is nil, cannot create query"] == NSOrderedSame, @"using nil left condition when deleting should generate an exception");
    }
    
    UMDbQuery *sql17 = [[UMDbQuery alloc] initForKey:@"63"];
    
    if (![sql17 isInCache])
    {
        [sql17 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql17 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns5 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted5 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql17 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql17];
    
    NSString *tn7 = nil;
    NSArray *columns6= nil;
    NSArray *inserted6 = [TestUMMySQLSession insertIntoSomeTable:&tn7
                                                     withColumns:&columns6
                                                     withSession:session 
                                                         withKey:@"62"]; 
    
    UMDbQuery *sql18 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql18 isInCache])
    {
        [sql18 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql18 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns6 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:nil];
        
        [sql18 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql18];
    STAssertTrue(res, @"delete query with nil right condition is legal");
    
    UMDbQuery *sql19 = [[UMDbQuery alloc] initForKey:@"65"];
    
    if (![sql19 isInCache])
    {
        [sql19 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql19 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns6 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted6 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql19 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql19];
    
    [session disconnect];
    
    [autoPool release];
}

- (void) testCachedDeleteEmpty
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    srand((unsigned int)time(NULL));
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    /* For testing deleetions,add random data to a random table*/
    NSString *tn2 = nil;
    NSArray *columns1 = nil;
    NSArray *inserted1 = [TestUMMySQLSession insertIntoSomeTable:&tn2 
                                                     withColumns:&columns1 
                                                     withSession:session 
                                                         withKey:@"54"];   
    
    UMDbQuery *sql9 = [[UMDbQuery alloc] initForKey:@"53"];
    
    if (![sql9 isInCache])
    {
        [sql9 setType:UMDBQUERYTYPE_DELETE];
        [sql9 setFields:[NSArray arrayWithObject:@""]];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql9 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns1 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted1 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql9 setWhereCondition:condition];
    }
    
    
    BOOL res = [session cachedQueryWithNoResult:sql9];
    STAssertTrue(res, @"delete query should ignore fields, nil or otherwise");
    
    NSString *tn3 = nil;
    NSArray *columns2 = nil;
    NSArray *inserted2 = [TestUMMySQLSession insertIntoSomeTable:&tn3 
                                                     withColumns:&columns2
                                                     withSession:session 
                                                         withKey:@"55"]; 
    
    UMDbQuery *sql10 = [[UMDbQuery alloc] initForKey:@"56"];
    
    if (![sql10 isInCache])
    {
        [sql10 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:@""];
        [sql10 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns1 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted1 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql10 setWhereCondition:condition];
    }
    
    @try 
    {
        res = [session cachedQueryWithNoResult:sql10];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Delete with empty table name, cannot create query"] == NSOrderedSame, @"using empty table name when deleting should generate an exception");
    }
    
    UMDbQuery *sql11 = [[UMDbQuery alloc] initForKey:@"57"];
    
    if (![sql11 isInCache])
    {
        [sql11 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql11 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns2 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted2 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql11 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql11];
    
    NSString *tn4 = nil;
    NSArray *columns3 = nil;
    NSArray *inserted3 = [TestUMMySQLSession insertIntoSomeTable:&tn4 
                                                     withColumns:&columns3
                                                     withSession:session 
                                                         withKey:@"55"]; 
    
    UMDbQuery *sql12 = [[UMDbQuery alloc] initForKey:@"58"];
    
    if (![sql12 isInCache])
    {
        [sql12 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn4];
        [sql12 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:@""];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted1 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql12 setWhereCondition:condition];
    }
    
    @try 
    {
        res = [session cachedQueryWithNoResult:sql12];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Left condition is empty, cannot create query"] == NSOrderedSame, @"using empty left condition when deleting should generate an exception");
    }
    
    UMDbQuery *sql13 = [[UMDbQuery alloc] initForKey:@"59"];
    
    if (![sql13 isInCache])
    {
        [sql13 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql13 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns3 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted3 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql13 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql13];
    
    NSString *tn5 = nil;
    NSArray *columns4 = nil;
    NSArray *inserted4 = [TestUMMySQLSession insertIntoSomeTable:&tn5 
                                                     withColumns:&columns4
                                                     withSession:session 
                                                         withKey:@"55"]; 
    
    UMDbQuery *sql14 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql14 isInCache])
    {
        [sql14 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql14 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns4 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@""];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql14 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql14];
    STAssertTrue(res, @"query with empty right condition should be legal");
    
    UMDbQuery *sql15 = [[UMDbQuery alloc] initForKey:@"61"];
    
    if (![sql15 isInCache])
    {
        [sql15 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql15 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns4 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted4 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql15 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql15];
    
    NSString *tn6 = nil;
    NSArray *columns5= nil;
    NSArray *inserted5 = [TestUMMySQLSession insertIntoSomeTable:&tn6
                                                     withColumns:&columns5
                                                     withSession:session 
                                                         withKey:@"62"]; 
    
    UMDbQuery *sql16 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql16 isInCache])
    {
        [sql16 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql16 setTable:table];
        
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted5 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:@""
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql16 setWhereCondition:condition];
    }
    
    @try 
    {
        res = [session cachedQueryWithNoResult:sql16];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Left condition is empty, cannot create query"] == NSOrderedSame, @"using empty left condition when deleting should generate an exception");
    }
    
    UMDbQuery *sql17 = [[UMDbQuery alloc] initForKey:@"63"];
    
    if (![sql17 isInCache])
    {
        [sql17 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql17 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns5 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted5 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql17 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql17];
    
    NSString *tn7 = nil;
    NSArray *columns6= nil;
    NSArray *inserted6 = [TestUMMySQLSession insertIntoSomeTable:&tn7
                                                     withColumns:&columns6
                                                     withSession:session 
                                                         withKey:@"62"]; 
    
    UMDbQuery *sql18 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql18 isInCache])
    {
        [sql18 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql18 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns6 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@""];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql18 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql18];
    STAssertTrue(res, @"delete query with empty right condition is legal");
    
    UMDbQuery *sql19 = [[UMDbQuery alloc] initForKey:@"65"];
    
    if (![sql19 isInCache])
    {
        [sql19 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn5];
        [sql19 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns6 objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted6 objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql19 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql19];
    
    [session disconnect];
    
    [autoPool release];
}

- (void) testCachedInsertNil
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    srand((unsigned int)time(NULL));
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    /* For testing insert data to specific table*/
    NSString *tn2 = [TestUMMySQLSession selectOneResultWithSession:session];
    
    /* Do SHOW COLUMNS IN 'table', store columns Field and Type;*/
    NSMutableArray *types;
    NSArray *columns =  [TestUMMySQLSession selectManyResultsWithTable:tn2
                                                             withTypes:&types
                                                           withSession:session];
    
    /* Test insert does not contain any useful information,*/
    NSArray *keys = [TestUMMySQLSession keysForTable:tn2 withSession:session];
    
    UMDbQuery *sql9 = [[UMDbQuery alloc] initForKey:@"69"];
    
    if (![sql9 isInCache])
    {
        [sql9 setType:UMDBQUERYTYPE_INSERT];
        [sql9 setFields:nil];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql9 setTable:table];
    }
    
    long uniquezer;
    NSMutableArray *params = [[[NSMutableArray alloc] init] autorelease];
    long numberOfColumns = [columns count];
    long i = 0;
    while (i < numberOfColumns)
    {
        NSString *name = [columns objectAtIndex:i];
        NSString *type = [types objectAtIndex:i];
        
        NSRange typeIsChar = [type rangeOfString:@"char"];
        NSRange typeIsInt = [type rangeOfString:@"int"];
        
        if ([keys indexOfObject:name] == NSNotFound) 
        {
            if (typeIsChar.length > 0)
                [params addObject:@"ad"];
            
            if (typeIsInt.length > 0)
                [params addObject:[NSString stringWithFormat:@"%d", 12345]];
        }
        else
        {
            if (typeIsChar.length > 0)
                [params addObject:[NSString stringWithFormat:@"ad%ld", uniquezer]];
            
            if (typeIsInt.length > 0)
                [params addObject:[NSString stringWithFormat:@"%ld", uniquezer]];
        }
        
        ++i;
        uniquezer = rand();
    }
    
    BOOL res;
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql9 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Inserting with nil fields table, cannot create query"] == NSOrderedSame, @"using nil table name when inserting should generate an exception");
    }
    
    UMDbQuery *sql10 = [[UMDbQuery alloc] initForKey:@"69"];
    
    if (![sql10 isInCache])
    {
        [sql10 setType:UMDBQUERYTYPE_INSERT];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql10 setTable:nil];
        [sql10 setFields:columns];
    }
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql10 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Inserting with nil table, cannot create query"] == NSOrderedSame, @"using nil table when inserting should generate an exception");
    }
    
    
    UMDbQuery *sql11 = [[UMDbQuery alloc] initForKey:@"70"];
    
    if (![sql11 isInCache])
    {
        [sql11 setType:UMDBQUERYTYPE_INSERT];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql11 setTable:table];
        [sql11 setFields:columns];
    }    
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql11 parameters:nil  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Inserting with nil params table, cannot create query"] == NSOrderedSame, @"using nil table name when inserting should generate an exception");
    }
    
    [session disconnect];
    
    [autoPool release];
}

- (void) testCachedInsertEmpty
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    srand((unsigned int)time(NULL));
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    
    /* For testing insert data to specific table*/
    NSString *tn2 = [TestUMMySQLSession selectOneResultWithSession:session];
    
    /* Do SHOW COLUMNS IN 'table', store cOlumns Field and Type;*/
    NSMutableArray *types;
    NSArray *columns =  [TestUMMySQLSession selectManyResultsWithTable:tn2
                                                             withTypes:&types
                                                           withSession:session];
    
    /* Test insert does not contain any useful information,*/
    NSArray *keys = [TestUMMySQLSession keysForTable:tn2 withSession:session];
    
    UMDbQuery *sql9 = [[UMDbQuery alloc] initForKey:@"72"];
    
    if (![sql9 isInCache])
    {
        [sql9 setType:UMDBQUERYTYPE_INSERT];
        [sql9 setFields:[NSArray arrayWithObject:@""]];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql9 setTable:table];
        [sql9 setFields:[NSArray arrayWithObject:@""]];
    }
    
    long uniquezer;
    NSMutableArray *params = [[[NSMutableArray alloc] init] autorelease];
    long numberOfColumns = [columns count];
    long i = 0;
    while (i < numberOfColumns)
    {
        NSString *name = [columns objectAtIndex:i];
        NSString *type = [types objectAtIndex:i];
        
        NSRange typeIsChar = [type rangeOfString:@"char"];
        NSRange typeIsInt = [type rangeOfString:@"int"];
        
        if ([keys indexOfObject:name] == NSNotFound) 
        {
            if (typeIsChar.length > 0)
                [params addObject:@"ad"];
            
            if (typeIsInt.length > 0)
                [params addObject:[NSString stringWithFormat:@"%d", 12345]];
        }
        else
        {
            if (typeIsChar.length > 0)
                [params addObject:[NSString stringWithFormat:@"ad%ld", uniquezer]];
            
            if (typeIsInt.length > 0)
                [params addObject:[NSString stringWithFormat:@"%ld", uniquezer]];
        }
        
        ++i;
        uniquezer = rand();
    }
    
    BOOL res;
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql9 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Inserting with empty fields, cannot create query"] == NSOrderedSame, @"using empty fuelds when inserting should generate an exception");
    }
    
    UMDbQuery *sql10 = [[UMDbQuery alloc] initForKey:@"73"];
    
    if (![sql10 isInCache])
    {
        [sql10 setType:UMDBQUERYTYPE_INSERT];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:@""];
        [sql10 setTable:table];
        [sql10 setFields:columns];
    }
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql10 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Inserting with empty table name, cannot create query"] == NSOrderedSame, @"using empty table name when inserting should generate an exception");
    }
    
    UMDbQuery *sql11 = [[UMDbQuery alloc] initForKey:@"74"];
    
    if (![sql11 isInCache])
    {
        [sql11 setType:UMDBQUERYTYPE_INSERT];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql11 setTable:table];
        [sql11 setFields:columns];
    }    
    
    @try
    {
        res =  [session cachedQueryWithNoResult:sql11 parameters:[NSArray arrayWithObject:@""]  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Inserting with empty parameter, cannot create query"] == NSOrderedSame, @"using empty table name when inserting should generate an exception");
    }
    
    [session disconnect];
    
    [autoPool release];
}

- (void) testCachedUpdateNil
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    srand((unsigned int)time(NULL));
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    /* Insert something to some table - this is the test*/
    NSString *tn2 = nil;
    NSArray *columns = nil;
    NSArray *inserted = [TestUMMySQLSession insertIntoSomeTable:&tn2 
                                                    withColumns:&columns 
                                                    withSession:session 
                                                        withKey:@"8"];
    
    /* Do SHOW COLUMNS IN 'table', return types*/
    NSArray *types =  [TestUMMySQLSession selectManyResultsWithTable:tn2
                                                         withSession:session];
    
    /* Test insert does not contain any useful information,*/
    NSArray *keys = [TestUMMySQLSession keysForTable:tn2 withSession:session];
    
    long uniquezer;
    NSMutableArray *params = [[[NSMutableArray alloc] init] autorelease];
    long numberOfColumns = [columns count];
    long i = 0;
    while (i < numberOfColumns)
    {
        NSString *name = [columns objectAtIndex:i];
        NSString *type = [types objectAtIndex:i];
        
        NSRange typeIsChar = [type rangeOfString:@"char"];
        NSRange typeIsInt = [type rangeOfString:@"int"];
        
        if ([keys indexOfObject:name] == NSNotFound) 
        {
            if (typeIsChar.length > 0)
                [params addObject:@"ad"];
            
            if (typeIsInt.length > 0)
                [params addObject:[NSString stringWithFormat:@"%d", 12345]];
        }
        else
        {
            if (typeIsChar.length > 0)
                [params addObject:[NSString stringWithFormat:@"ad%ld", uniquezer]];
            
            if (typeIsInt.length > 0)
                [params addObject:[NSString stringWithFormat:@"%ld", uniquezer]];
        }
        
        ++i;
        uniquezer = rand();
    }
    
    /* Update without where is legal, accordingf to sql standard. However, db library does nor accept it*/
    UMDbQuery *sql9 = [[UMDbQuery alloc] initForKey:@"73"];
    
    if (![sql9 isInCache])
    {
        [sql9 setType:UMDBQUERYTYPE_UPDATE];
        
        [sql9 setTable:nil];
        [sql9 setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql9 setWhereCondition:condition];
    }
    
    BOOL res;
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql9 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Updating with nil table, cannot create query"] == NSOrderedSame, @"using nil fields when        updating should generate an exception");
    }
    
    UMDbQuery *sql8 = [[UMDbQuery alloc] initForKey:@"73"];
    
    if (![sql8 isInCache])
    {
        [sql8 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql8 setTable:table];
        [sql8 setFields:nil];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql8 setWhereCondition:condition];
    }
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql8 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Updating with nil fields table, cannot create query"] == NSOrderedSame, @"using nil fields when        updating should generate an exception");
    }
    
    UMDbQuery *sql11 = [[UMDbQuery alloc] initForKey:@"70"];
    
    if (![sql11 isInCache])
    {
        [sql11 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql11 setTable:table];
        [sql11 setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql11 setWhereCondition:condition];
    }    
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql11 parameters:nil  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Updating with nil params table, cannot create query"] == NSOrderedSame, @"using nil table name when updating should generate an exception");
    }
    
    UMDbQuery *sql10 = [[UMDbQuery alloc] initForKey:@"70"];
    
    if (![sql10 isInCache])
    {
        [sql10 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql10 setTable:table];
        [sql10 setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql9 setWhereCondition:condition];
    }    
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql10 parameters:nil  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Updating with nil params table, cannot create query"] == NSOrderedSame, @"using nil params when updating should generate an exception");
    }
    
    UMDbQuery *sql12 = [[UMDbQuery alloc] initForKey:@"58"];
    
    if (![sql12 isInCache])
    {
        [sql12 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql12 setTable:table];
        [sql12 setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:nil];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql12 setWhereCondition:condition];
    }
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql12 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Left condition is nil, cannot create query"] == NSOrderedSame, @"using nil left condition when updating should generate an exception");
    }
    
    UMDbQuery *sql14 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql14 isInCache])
    {
        [sql14 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql14 setTable:table];
        [sql14 setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:nil];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql14 setWhereCondition:condition];
    }
    
    res =  [session cachedQueryWithNoResult:sql14 parameters:params  allowFail:NO];
    STAssertTrue(res, @"query with right condition nil should be legal");
    /* It does update in this case however, we do not have NULL value*/
    
    UMDbQuery *sql16 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql16 isInCache])
    {
        [sql16 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql16 setTable:table];
        [sql16 setFields:columns];
        
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:nil
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql16 setWhereCondition:condition];
    }
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql16 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Left condition is nil, cannot create query"] == NSOrderedSame, @"using nil left condition when updating should generate an exception");
    }
    
    UMDbQuery *sql18 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql18 isInCache])
    {
        [sql18 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql18 setTable:table];
        [sql18 setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:nil];
        
        [sql18 setWhereCondition:condition];
    }
    
    res =  [session cachedQueryWithNoResult:sql18 parameters:params  allowFail:NO];
    STAssertTrue(res, @"update query with nil right condition is legal");
    
    UMDbQuery *sql19 = [[UMDbQuery alloc] initForKey:@"65"];
    
    if (![sql19 isInCache])
    {
        [sql19 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql19 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql19 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql19];
    
    [session disconnect];
    
    [autoPool release];
}

- (void) testCachedUpdateEmpty
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    // Set-up code here.
    
    srand((unsigned int)time(NULL));
    
    pool = [[UMDbPool alloc] init];
    UMDbSession *session = [TestUMMySQLSession setUpConnectionWithPool:pool];
    if (!session)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"could not create session to handle connection" userInfo:nil];
    
    NSString *tn2;
    NSArray *columns;
    NSArray *inserted = [TestUMMySQLSession insertIntoSomeTable:&tn2 
                                                    withColumns:&columns 
                                                    withSession:session 
                                                        withKey:@"8"];
    
    /* Do SHOW COLUMNS IN 'table', get types*/
    NSArray *types =  [TestUMMySQLSession selectManyResultsWithTable:tn2 
                                                         withSession:session];
    
    /* Test insert does not contain any useful information,*/
    NSArray *keys = [TestUMMySQLSession keysForTable:tn2 withSession:session];
    
    
    UMDbQuery *sql9 = [[UMDbQuery alloc] initForKey:@"72"];
    
    if (![sql9 isInCache])
    {
        [sql9 setType:UMDBQUERYTYPE_UPDATE];
        [sql9 setFields:[NSArray arrayWithObject:@""]];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql9 setTable:table];
    }
    
    long uniquezer;
    NSMutableArray *params = [[[NSMutableArray alloc] init] autorelease];
    long numberOfColumns = [columns count];
    long i = 0;
    while (i < numberOfColumns)
    {
        NSString *name = [columns objectAtIndex:i];
        NSString *type = [types objectAtIndex:i];
        
        NSRange typeIsChar = [type rangeOfString:@"char"];
        NSRange typeIsInt = [type rangeOfString:@"int"];
        
        if ([keys indexOfObject:name] == NSNotFound) 
        {
            if (typeIsChar.length > 0)
                [params addObject:@"ad"];
            
            if (typeIsInt.length > 0)
                [params addObject:[NSString stringWithFormat:@"%d", 12345]];
        }
        else
        {
            if (typeIsChar.length > 0)
                [params addObject:[NSString stringWithFormat:@"ad%ld", uniquezer]];
            
            if (typeIsInt.length > 0)
                [params addObject:[NSString stringWithFormat:@"%ld", uniquezer]];
        }
        
        ++i;
        uniquezer = rand();
    }
    
    BOOL res;
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql9 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Updating with empty fields, cannot create query"] == NSOrderedSame, @"using nil fields when inserting should generate an exception");
    }
    
    UMDbQuery *sql10 = [[UMDbQuery alloc] initForKey:@"73"];
    
    if (![sql10 isInCache])
    {
        [sql10 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:@""];
        [sql10 setTable:table];
        [sql10 setFields:columns];
    }
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql10 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Updating with empty table name, cannot create query"] == NSOrderedSame, @"using empty table name when inserting should generate an exception");
    }
    
    UMDbQuery *sql11 = [[UMDbQuery alloc] initForKey:@"74"];
    
    if (![sql11 isInCache])
    {
        [sql11 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql11 setTable:table];
        [sql11 setFields:columns];
    }    
    
    @try
    {
        res =  [session cachedQueryWithNoResult:sql11 parameters:[NSArray arrayWithObject:@""]  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Updating with empty parameter, cannot create query"] == NSOrderedSame, @"using empty table name when inserting should generate an exception");
    }
    
    UMDbQuery *sql20 = [[UMDbQuery alloc] initForKey:@"70"];
    
    if (![sql20 isInCache])
    {
        [sql20 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql20 setTable:table];
        [sql20 setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql20 setWhereCondition:condition];
    }    
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql20 parameters:nil  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Updating with nil params table, cannot create query"] == NSOrderedSame, @"using nil params when updating should generate an exception");
    }
    
    UMDbQuery *sql12 = [[UMDbQuery alloc] initForKey:@"58"];
    
    if (![sql12 isInCache])
    {
        [sql12 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql12 setTable:table];
        [sql12 setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:@""];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql12 setWhereCondition:condition];
    }
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql12 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Left condition is empty, cannot create query"] == NSOrderedSame, @"using empty left condition when updating should generate an exception");
    }
    
    UMDbQuery *sql14 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql14 isInCache])
    {
        [sql14 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql14 setTable:table];
        [sql14 setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:@""];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql14 setWhereCondition:condition];
    }
    
    res =  [session cachedQueryWithNoResult:sql14 parameters:params  allowFail:NO];
    STAssertTrue(res, @"query with emptyright condition nil should be legal");
    /* It does update in this case however, we do not have NULL value*/
    
    UMDbQuery *sql16 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql16 isInCache])
    {
        [sql16 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql16 setTable:table];
        [sql16 setFields:columns];
        
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:@""
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql16 setWhereCondition:condition];
    }
    
    @try 
    {
        res =  [session cachedQueryWithNoResult:sql16 parameters:params  allowFail:NO];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"Left condition is empty, cannot create query"] == NSOrderedSame, @"using nil left condition when updating should generate an exception");
    }
    
    UMDbQuery *sql18 = [[UMDbQuery alloc] initForKey:@"60"];
    
    if (![sql18 isInCache])
    {
        [sql18 setType:UMDBQUERYTYPE_UPDATE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql18 setTable:table];
        [sql18 setFields:columns];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:@""];
        
        [sql18 setWhereCondition:condition];
    }
    
    res =  [session cachedQueryWithNoResult:sql18 parameters:params  allowFail:NO];
    STAssertTrue(res, @"update query with empty right condition is legal");
    
    UMDbQuery *sql19 = [[UMDbQuery alloc] initForKey:@"65"];
    
    if (![sql19 isInCache])
    {
        [sql19 setType:UMDBQUERYTYPE_DELETE];
        
        UMDbTable *table = [[[UMDbTable alloc] init] autorelease];
        [table setTableName:tn2];
        [sql19 setTable:table];
        
        UMDbQueryPlaceholder *left = [UMDbQueryPlaceholder placeholderField:[columns objectAtIndex:0]];
        UMDbQueryPlaceholder *right = [UMDbQueryPlaceholder placeholderField:[inserted objectAtIndex:0]];
        
        UMDbQueryCondition *condition =  [UMDbQueryCondition queryConditionLeft:left
                                                                             op:UMDBQUERY_OPERATOR_EQUAL
                                                                          right:right];
        
        [sql19 setWhereCondition:condition];
    }
    
    res = [session cachedQueryWithNoResult:sql19];
    
    [session disconnect];
    
    [autoPool release];
}

@end
