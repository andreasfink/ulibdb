//
//  UMDbDriverType.m
//  ulibdb.framework
//
//  Created by Andreas Fink on 21.10.11.
//  Copyright (c) 2011 Andreas Fink

#import <ulib/ulib.h>
#import "ulibdb_defines.h"
#import "UMDbDriverType.h"



const char *dbdrivertype_to_string(UMDbDriverType d)
{
	switch(d)
	{
        case UMDBDRIVER_MYSQL:
            return "mysql";
        case UMDBDRIVER_PGSQL:
            return "pgsql";
        case UMDBDRIVER_SQLITE:
            return "sqlite";
        case UMDBDRIVER_REDIS:
            return "redis";
        case UMDBDRIVER_FILE:
            return "file";
        default:
            return "null";
	}
}

UMDbDriverType   UMDriverTypeFromString(NSString *sql)
{
    if([sql caseInsensitiveCompare:@"mysql"]==0)
        return UMDBDRIVER_MYSQL;
    else if([sql caseInsensitiveCompare:@"pgsql"]==0)
        return UMDBDRIVER_PGSQL;
    else if([sql caseInsensitiveCompare:@"sqlite"]==0)
        return UMDBDRIVER_SQLITE;
    else if([sql caseInsensitiveCompare:@"redis"]==0)
        return UMDBDRIVER_REDIS;
    else if([sql caseInsensitiveCompare:@"file"]==0)
        return UMDBDRIVER_FILE;
    return UMDBDRIVER_NULL;
}

