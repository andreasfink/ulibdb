//
//  UMDbQueryCondition.h
//  ulibdb.framework
//
//  Created by Andreas Fink on 27.10.11.
//  Copyright (c) 2011 Andreas Fink

#import "ulib/ulib.h"
#import "UMDbDriverType.h"
@class UMDbQuery;

typedef enum UMDbQueryConditionOperator
{
    UMDBQUERY_OPERATOR_NONE,
    UMDBQUERY_OPERATOR_AND,
    UMDBQUERY_OPERATOR_OR,
    UMDBQUERY_OPERATOR_NOT,
    UMDBQUERY_OPERATOR_EQUAL,
    UMDBQUERY_OPERATOR_NOT_EQUAL,
    UMDBQUERY_OPERATOR_LIKE,
    UMDBQUERY_OPERATOR_NOT_LIKE,
    UMDBQUERY_OPERATOR_GREATER_THAN,
    UMDBQUERY_OPERATOR_LESS_THAN
} UMDbQueryConditionOperator;


@interface UMDbQueryCondition : UMObject
{
    id  leftSideOperator;
    UMDbQueryConditionOperator      operator;
    id  rightSideOperator;
}

@property(readwrite,strong) id leftSideOperator;
@property(readwrite,strong) id rightSideOperator;

- (NSString *) sqlForQuery:(UMDbQuery *)query parameters:(NSArray *)params dbType:(UMDbDriverType)dbType primaryKeyValue:(id)primaryKeyValue;
- (UMDbQueryCondition *) initWithLeft:(id)left op:(UMDbQueryConditionOperator)op right:(id)right;
+ (UMDbQueryCondition *) queryConditionLeft:(id)left op:(UMDbQueryConditionOperator)op right:(id)right;

@end
