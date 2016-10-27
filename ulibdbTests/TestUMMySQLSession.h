//
//  TestUMMySQLSession.h
//  ulib
//
//  Created by Aarno Syvänen on 19.03.12.
//  Copyright (c) 2012 Fink Consulting GmbH. All rights reserved.
//

//  Application unit tests contain unit test code that must be injected into an application to run correctly.
//  See Also: http://developer.apple.com/iphone/library/documentation/Xcode/Conceptual/iphone_development/135-Unit_Testing_Applications/unit_testing_applications.html

#define HAVE_MYSQL 1

#import <SenTestingKit/SenTestingKit.h>
#import "UMDbPool.h"
#import "UMDbSession.h"

@interface TestUMMySQLSession : SenTestCase
{
     UMDbPool *pool;
}

+ (UMDbSession *)setUpConnectionWithPool:(UMDbPool *)dbPool;
+ (NSString *) selectOneResultWithSession:(UMDbSession *)session;

+ (NSArray *) selectManyResultsWithTable:(NSString *)t 
                               withTypes:(NSMutableArray **)types 
                             withSession:(UMDbSession *)session;

+ (NSArray *) selectManyResultsWithTable:(NSString *)t 
                             withSession:(UMDbSession *)session;

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

+ (BOOL) assert:(NSArray *)a1 equals:(NSArray *)a2;

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
