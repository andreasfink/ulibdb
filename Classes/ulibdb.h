//
//  ulibdb.h
//  ulibdb.framework
//
//  Created by Andreas Fink on 16.12.11.
//  Copyright (c) 2011 Andreas Fink
//

#import <ulib/ulib.h>

#import "ulibdb_defines.h"

#import "UMDbDriverType.h"
#import "UMDbQueryType.h"
#import "UMDbTable.h"
#import "UMDbPool.h"
#import "UMDbQuery.h"
#import "UMDbQueryCondition.h"
#import "UMDbQueryPlaceholder.h"
#import "UMDbResult.h"
#import "UMDbSession.h"
#import "UMMySQLSession.h"
#import "UMPgSQLSession.h"
#import "UMSqLiteSession.h"
#import "UMDbRedisSession.h"
#import "UMDbMySqlInProgress.h"

@interface ulibdb : UMObject
{
    
}
+ (NSString *) ulibdb_version;
+ (NSString *) ulibdb_build;
+ (NSString *) ulibdb_builddate;
+ (NSString *) ulibdb_compiledate;
@end

void ulibdb_startup(void);
void ulibdb_shutdown(void);

void ulibdb_thread_init(void);
void ulibdb_thread_exit(void);
