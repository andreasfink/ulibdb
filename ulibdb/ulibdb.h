//
//  ulibdb.h
//  ulibdb.framework
//
//  Created by Andreas Fink on 16.12.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.
//

#import <ulib/ulib.h>
#import <ulibdb/ulibdb_config.h>

#import <ulibdb/UMDbDriverType.h>
#import <ulibdb/UMDbQueryType.h>
#import <ulibdb/UMDbTable.h>
#import <ulibdb/UMDbPool.h>
#import <ulibdb/UMDbQuery.h>
#import <ulibdb/UMDbQueryCondition.h>
#import <ulibdb/UMDbQueryPlaceholder.h>
#import <ulibdb/UMDbResult.h>
#import <ulibdb/UMDbSession.h>

#import <ulibdb/UMDbTableDefinition.h>
#import <ulibdb/UMDbFieldDefinition.h>
/*
 we dont want to include the requirement of having to find the mysql.h
 into a project which only uses ulibdb directly and doesnt ever call
 mysql directly, So only during compilation of the library this is included.
 a user of ulibdb would only deal with the abstract superclass view
*/

#if defined(ULIBDB_FRAMEWORK_COMPILATION)
#import <ulibdb/UMMySQLSession.h>
#import <ulibdb/UMPgSQLSession.h>
#endif


#import <ulibdb/UMSqLiteSession.h>
#import <ulibdb/UMDbRedisSession.h>
#import <ulibdb/UMDbMySqlInProgress.h>

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
