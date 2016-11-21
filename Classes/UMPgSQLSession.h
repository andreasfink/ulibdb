//
//  UMPgSQLSession.h
//  ulibdb.framework
//
//  Created by Andreas Fink on 21.10.11.
//  Copyright (c) 2011 Andreas Fink

#import "UMDbSession.h"

#ifdef HAVE_PGSQL

#import <postgresql/libpq-fe.h>

#define DEFAULT_PGSQL_PORT 5432
//#define PGSQL_DEBUG 1

@interface UMPgSQLSession : UMDbSession
{
    NSString        *pgtty;
    PGconn          *pgconn;
}


- (UMPgSQLSession *)initWithPool:(UMDbPool *)dbpool;
- (void) dealloc;

- (BOOL) connect;
- (void) disconnect;
- (BOOL)queryWithNoResult:(NSString *)sql allowFail:(BOOL)failPermission affectedRows:(unsigned long long *)count;
- (UMDbResult *)queryWithMultipleRowsResult:(NSString *)sql allowFail:(BOOL)failPermission;
- (UMDbResult *)queryWithMultipleRowsResult:(NSString *)sql
                                  allowFail:(BOOL)failPermission
                                       file:(const char *)file
                                       line:(long)line;
- (BOOL)ping;

@end

#endif /* HAVE PGSQL */
