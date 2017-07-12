//
//  ulibdb.m
//  ulibdb
//
//  Created by Andreas Fink on 10/05/14.
//
//

#import "ulibdb.h"
#import "../version.h"

@implementation ulibdb

+ (NSString *) ulibdb_version
{
    return @VERSION;
}

+ (NSString *) ulibdb_build
{
    return @BUILD;
}

+ (NSString *) ulibdb_builddate
{
    return @BUILDDATE;
}

+ (NSString *) ulibdb_compiledate
{
    return @COMPILEDATE;
}


@end

void ulibdb_startup()
{
    if (mysql_library_init(0, NULL, NULL))
    {
        fprintf(stderr,"could not initialize MySQL library");
        exit(1);
    }
    if( mysql_thread_safe() == 0)
    {
        @throw ([NSException exceptionWithName:@"ulibdb" reason:@"mysql library is not thread safe" userInfo:NULL]);
    }
}

void ulibdb_shutdown()
{
    mysql_library_end();
}


void ulibdb_thread_init(void)
{
    mysql_thread_init();
}

void ulibdb_thread_exit(void)
{
    mysql_thread_end();
}
