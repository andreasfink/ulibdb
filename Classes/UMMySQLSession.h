//
//  UMMySQLSession.h
//  ulibdb.framework
//
//  Created by Andreas Fink on 24.10.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.

#import "UMDbSession.h"
#import "ulib/ulib.h"
#import "ulibdb_defines.h"

#ifdef HAVE_MYSQL
#include <mysql/mysql.h>
@class UMDbMySqlInProgress;

@interface UMMySQLSession : UMDbSession
{
    MYSQL             mysql;
    MYSQL             *connection;
    unsigned long     mysqlServerVer;
    unsigned long     mysqlClientVer;
	NSString		  *type;
    UMLogHandler	  *loghandler;
    UMDbMySqlInProgress *lastInProgress;
}

@property(readwrite,strong)		NSString			*type;
@property(readwrite,strong)		UMLogHandler		*loghandler;
@property(readwrite,strong)     UMDbMySqlInProgress *lastInProgress;

- (MYSQL *)connection;
- (char)fieldQuoteChar;
- (UMDbSession *)initWithPool:(UMDbPool *)pool;
- (void)dealloc;
- (BOOL) connect;
- (void) disconnect;
- (BOOL)queryWithNoResult:(NSString *)sql allowFail:(BOOL)allowFail affectedRows:(unsigned long long *)count;
- (UMDbResult *)queryWithMultipleRowsResult:(NSString *)sql allowFail:(BOOL)failPermission;
- (UMDbResult *)queryWithMultipleRowsResult:(NSString *)sql allowFail:(BOOL)failPermission file:(const char *)file line:(long)line;

- (BOOL)ping;

- (void) setLogHandler: (UMLogHandler *)handler;

- (int)errorCheck:(int) state forSql:(NSString *)sql;
- (NSDictionary *)explainTable:(NSString *)table;

@end

#endif
