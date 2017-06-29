//
//  ulibdb.h
//  ulibdb.framework
//
//  Created by Andreas Fink on 16.12.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.
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

/*
 we dont want to include the requirement of having to find the mysql.h
 into a project which only uses ulibdb directly and doesnt ever call
 mysql directly, So only during compilation of the library this is included.
 a user of ulibdb would only deal with the abstract superclass view
*/

#if defined(ULIBDB_FRAMEWORK_COMPILATION)
#import "UMMySQLSession.h"
#import "UMPgSQLSession.h"
#endif


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
