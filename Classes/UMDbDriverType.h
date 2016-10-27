//
//  UMDbDriverType.h
//  ulibdb.framework
//
//  Created by Andreas Fink on 21.10.2011.
//  Copyright (c) 2011 Andreas Fink

#import <Foundation/Foundation.h>

typedef enum UMDbDriverType
{
	UMDBDRIVER_NULL = 0,
	UMDBDRIVER_MYSQL = 1,
	UMDBDRIVER_PGSQL = 2,
    UMDBDRIVER_SQLITE = 3,
    UMDBDRIVER_REDIS = 4,
    UMDBDRIVER_FILE = 5,
    UMDBDRIVER_END = 6,
} UMDbDriverType;


const char *dbdrivertype_to_string(UMDbDriverType d);
UMDbDriverType   UMDriverTypeFromString(NSString *sql);
