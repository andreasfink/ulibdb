//
//  UMDbStorageType.h
//  ulibdb
//
//  Created by Aarno Syvänen on 17.02.14.
//
//

#import <Foundation/Foundation.h>

typedef enum UMDbStorageType
{
	UMDBSTORAGE_NULL = 0,
	UMDBSTORAGE_JSON = 1,
	UMDBSTORAGE_HASH = 2,
    UMDBSTORAGE_END =  3,
} UMDbStorageType;


const char *dbstoragetype_to_string(UMDbStorageType s);
UMDbStorageType   UMStorageTypeFromString(NSString *str);
