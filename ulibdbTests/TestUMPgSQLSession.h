//
//  TestUMPgSQLSession.h
//  ulibdbtests
//
//  Created by Aarno Syväen on 22.12.11.
//  Copyright (c) 2011 Fink Consulting GmbH. All rights reserved.
//

#define HAVE_PGSQL 1

#import <SenTestingKit/SenTestingKit.h>
#import "UMDbPool.h"
#import "UMDbSession.h"
#import "UMPgSQLSession.h"

@interface TestUMPgSQLSession : SenTestCase
{
    UMDbPool *pool;
}

+ (UMDbSession *)setUpConnectionWithPool:(UMDbPool *)dbPool;
+ (NSString *) selectOneResultWithField:(NSString *)field 
                               withTable:(NSString *)t 
                           withWhereLeft:(NSString *)left 
                             withWhereOp:(UMDbQueryConditionOperator)wop
                          withWhereRight:(NSString *)right 
                             withSession:(UMDbSession *)session
                                 withKey:(NSString *)key;

+ (NSArray *) selectManyResultsWithField:(NSString *)field 
                               withTable:(NSString *)t 
                           withWhereLeft:(NSString *)left 
                             withWhereOp:(UMDbQueryConditionOperator)wop
                          withWhereRight:(NSString *)right 
                             withSession:(UMDbSession *)session 
                                 withKey:(NSString *)key;

+ (NSArray *) selectRowFromTable:(NSString *)t 
                           withWhereLeft:(NSString *)left 
                             withWhereOp:(UMDbQueryConditionOperator)wop
                          withWhereRight:(NSString *)right 
                             withSession:(UMDbSession *)session 
                                 withKey:(NSString *)key;

+ (NSArray *) insertSomeIntoTable:(NSString *)tn 
               havingColumns:(NSArray *)columns 
                   withTypes:(NSArray * ) types 
                 withSession:(UMDbSession *)session 
              withPrimaryKey:(NSArray *)key 
                withCacheKey:(NSString *)cacheKey;

+ (NSArray *) keysForTable:(NSString *)tn2 withSession:(UMDbSession *)session;

+ (BOOL)deleteFromTable:(NSString *)tn 
      withConditionLeft:(NSString *)li 
     withConditionRight:(NSString *)ri 
        withConditionOp:(UMDbQueryConditionOperator)wop 
            withSession:(UMDbSession *)session 
                withKey:(NSString *)key;

/* Picks a random table for testing purposes*/
+ (NSArray *)insertIntoSomeTable:(NSString **)tn 
                     withColumns:(NSArray **)columns 
                     withSession:(UMDbSession *)session 
                         withKey:(NSString *)key;

/* Selects a specific table for inserting*/
+ (NSArray *)insertIntoOneTable:(NSString *)tn 
                     withColumns:(NSArray *)columns 
                    withSession:(UMDbSession *)session 
                        withKey:(NSString *)key;

+ (BOOL) assert:(NSArray *)a1 equalsReverse:(NSArray *)a2;

+ (NSArray *)updateSomeTable:(NSString **)tn 
                 withColumns:(NSArray **)columns 
           withConditionLeft:(NSString *)li 
          withConditionRight:(NSString *)ri 
             withConditionOp:(UMDbQueryConditionOperator)wop
                 withSession:(UMDbSession *)session 
                     withKey:(NSString *)key;

+ (NSArray *)updateOneTable:(NSString *)tn
              havingColumns:(NSArray *)columns
                  withTypes:(NSArray *)types 
                    withKey:(NSArray *)key
          withConditionLeft:(NSString *)li 
         withConditionRight:(NSString *)ri 
            withConditionOp:(UMDbQueryConditionOperator)wop
                withSession:(UMDbSession *)session 
                withCacheKey:(NSString *)key;

@end
