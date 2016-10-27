//
//  TestUmConfig.m
//  ulib
//
//  Created by Aarno Syvänen on 19.03.12.
//  Copyright (c) Andreas Fink
//

#import "TestUmConfig.h"

#import <Cocoa/Cocoa.h>
#import "UMConfig.h"
#import "UMConfigGroup.h"

@implementation TestUMConfig

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    // Tear-down code here.
    [super tearDown];
}

+ (BOOL) assert:(NSDictionary *)a1 equals:(NSDictionary *)a2
{
    if (!a1)
        return FALSE;
    
    if (!a2)
        return FALSE;
    
    if ([a1 count] == 0)
        return FALSE;
    
    if ([a2 count] == 0)
        return FALSE;
    
    if ([a1 count] != [a2 count])
        return FALSE;
    
    long i = 0;
    NSArray *keys1 = [a1 allKeys];
    NSArray *keys2 = [a2 allKeys];
    long len = [keys1 count];
    while (i < len) 
    {
        NSString *key1 = [keys1 objectAtIndex:i];
        NSString *key2 = [keys2 objectAtIndex:i];
        if ([key1 compare:key2] != NSOrderedSame)
            return FALSE;
        
        NSString *item1 = [a1 objectForKey:key1];
        NSString *item2 = [a2 objectForKey:key2];
        if ([item1 compare:item2] != NSOrderedSame)
            return FALSE;
        
        ++i;
    }
    
    return TRUE;
}

- (void)testConfig
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];
    
    NSString *cfgName;
    
    UMConfig *cfg1;
    cfgName = nil;
    cfg1 = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    STAssertNil(cfg1, @"Initialising config with nil filename should return nil");
    /* Message to nil are alwayds ignored, sp we need not to test thoar*/
                         
    cfgName = @"ulib/config-test.conf";
    cfg1= [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    
    @try
    {
        [cfg1 read];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        STAssertTrue([reason compare:@"no group definitions are set. populate allowedSingleGroupNames or allowedMultiGroupNames"] == NSOrderedSame, @"Reading configuration with no allowed groups should throw exception");
    }
    
    NSDictionary *allowed = [cfg1 allowedMultiGroupNames];
    STAssertTrue([allowed count] == 0, @"There should be no allowed multigroups when none are allowed");
    [cfg1 allowMultiGroup:@"sip"];
    NSDictionary *test = [NSDictionary dictionaryWithObject:@"allowed" forKey:@"sip"];
    STAssertTrue([TestUMConfig assert:allowed equals:test], @"Allowed multigroup should be seen in the data structure");
    [cfg1 disallowMultiGroup:@"sip"];
    allowed = [cfg1 allowedMultiGroupNames];
    STAssertTrue([allowed count] == 0, @"There should be no allowed multigroups when all are disallowed");
    [cfg1 allowMultiGroup:@"sip"];
    
    @try 
    {
        [cfg1 read];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        NSString *excepted = @"Don't know how to parse group";
        NSRange range = [reason rangeOfString:excepted];
        STAssertTrue(range.length > 0, @"Reading configuration with no allowed groups should throw exception");
    }
    
    allowed = [cfg1 allowedSingleGroupNames];
    STAssertTrue([allowed count] == 0, @"There should be no allowed single groups when none are allowed");
    [cfg1 allowSingleGroup:@"pgsql-test-table"];
    test = [NSDictionary dictionaryWithObject:@"allowed" forKey:@"pgsql-test-table"];
    STAssertTrue([TestUMConfig assert:allowed equals:test], @"Allowed single group should be seen in the data structure");
    [cfg1 disallowSingleGroup:@"pgsql-test-table"];
    allowed = [cfg1 allowedSingleGroupNames];
    STAssertTrue([allowed count] == 0, @"There should be no allowed single groups when all are disallowed");
    [cfg1 allowSingleGroup:@"pgsql-test-table"];
    
    @try 
    {
        [cfg1 read];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        NSString *excepted = @"Don't know how to parse group";
        NSRange range = [reason rangeOfString:excepted];
        STAssertTrue(range.length > 0, @"Reading configuration with a non allowed groups should throw exception");
    }
    
    [cfg1 allowSingleGroup:@"other-test-table"];
    NSDictionary *allowed1 = [cfg1 allowedSingleGroupNames];
    [cfg1 allowSingleGroup:@"other-test-table"];
    NSDictionary *allowed2 = [cfg1 allowedSingleGroupNames];
    STAssertTrue([TestUMConfig assert:allowed1 equals:allowed2], @"Double allowing of a group should be NOOP");
    
    cfgName = @"junky";
    UMConfig *cfg2 = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    [cfg2 allowMultiGroup:@"junky"];          /* to get non-existinng file exception*/
    @try
    {
        [cfg2 read];
    }
    @catch (NSException *exception) {
        NSString *reason = [exception reason];
        NSString *expected = @"Can not read file junky.";
        NSRange range = [reason rangeOfString:expected];
        STAssertTrue(range.length > 0, @"Trying to read a nonexisting file should cause an exception");
    }
    
    cfgName = @"ulib/config-test.conf";
    UMConfig *cfg3 = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    [cfg3 allowMultiGroup:@"sip"];
    [cfg3 allowSingleGroup:@"pgsql-test-table"];
    [cfg3 allowSingleGroup:@"other-test-table"];
    [cfg3 read]; 
    
    NSDictionary *grp = [cfg3 getSingleGroup:@"junky"];
    STAssertNil(grp, @"trying to use non-allowed group name should return a nil group");
    
    grp = [cfg3 getSingleGroup:@"pgsql-test-table"];
    if (!grp)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must have group pgsql-test-table" userInfo:nil];
    
    long enable = 1;
    enable = [[grp objectForKey:@"enable"] integerValue];
    
    NSString *pool_name = [grp objectForKey:@"pool-name"];
    if (!pool_name)
        pool_name = @"";
    
    NSString *host = [grp objectForKey:@"junky"];
    STAssertNil(host, @"trying to fetch variable not found in configuration should retrun nil");
    
    host = [grp objectForKey:@"host"];
    if (!host)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must contain host name" userInfo:nil];
    
    NSString *database_name = [grp objectForKey:@"database-name"];
    if (!database_name)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must contain database name" userInfo:nil];
    
    NSString *user = [grp objectForKey:@"user"];
    if (!user)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must contain user name" userInfo:nil];
    
    NSString *pass = [grp objectForKey:@"pass"];
    if (!pass)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must contain password" userInfo:nil];
    
    long port = -1;
    port = [[grp objectForKey:@"junky"] integerValue];
    STAssertTrue(port == 0, @"values of non existing integer variables should be set -1");
    
    port = [[grp objectForKey:@"port"] integerValue];
    
    long min_sessions = -1;
    min_sessions = [[grp objectForKey:@"min-sessions"] integerValue];
    long max_sessions = - 1;
    max_sessions = [[grp objectForKey:@"max-sessions"] integerValue];
    NSString *socket = [grp objectForKey:@"socket"];
    if (!socket)
        socket = @"";
    
    NSArray *groups = [cfg3 getMultiGroups:@"junky"];
    STAssertNil(groups, @"trying to fetch a non-allowed multigroup should return nil");
    
    groups = [cfg3 getMultiGroups:@"sip"];
    if (!groups)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file must contain value for testing multigroups" userInfo:nil];
    
	NSUInteger n = [groups count];
    STAssertTrue(n == 3, @"test configuration has three sip multigroups");
    long i;
    
	for( i=0;i<n;i++)
	{
		NSDictionary *cfgGrp = [groups objectAtIndex:i];
        
        BOOL globalSipEnabled = [[cfgGrp objectForKey:@"junky"] boolValue];
        STAssertFalse(globalSipEnabled, @"Value of non configured Boolean variable should be FALSE");
		
		NSUInteger sipPort = [[cfgGrp objectForKey:@"junky"] integerValue];
		sipPort = [[cfgGrp objectForKey:@"local-port"] integerValue];
        if (sipPort == 0)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file for testing multigroups must contain SIP port" userInfo:nil];
        
        NSString *smscNumber = [cfgGrp objectForKey:@"smsc-number"];
        if (!smscNumber)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file for testing multigroups must contain SMSC number" userInfo:nil];
        
        NSString *domain = [cfgGrp objectForKey:@"domain"];
        if (!domain)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file for testing multigroups must contain domain name" userInfo:nil];
        
        NSString *realm = [cfgGrp objectForKey:@"realm"];
		if (!realm)
             @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file for testing multigroups must contain realm" userInfo:nil];
        
		NSString *privateKey = [cfgGrp objectForKey:@"private-key"];
        if (!privateKey)
		     @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file for testing multigroups must contain private key" userInfo:nil];
        
	    NSString *unifiedPrefix = [cfgGrp objectForKey:@"unified-prefix"];
        if (!unifiedPrefix)
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file for testing multigroups must contain unified prefix" userInfo:nil];
            
		NSString *deunifiedPrefix = [cfgGrp objectForKey:@"deunified-prefix"];
        if (!deunifiedPrefix)
             @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"configuration file for testing multigroups must contain deunified prefix" userInfo:nil];
	}
    
    [autoPool release];
}

- (void)testConfigErrors
{
    NSAutoreleasePool *autoPool = [[NSAutoreleasePool alloc] init];

    NSString *cfgName = cfgName = @"ulib/many-singles.conf";
    UMConfig *cfg1 = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    NSString *reason;
    NSString *expected;
    NSRange range;
    
    [cfg1 allowSingleGroup:@"pgsql-test-table"];
    
    @try 
    {
       [cfg1 read];
    }
    @catch (NSException *exception) {
        reason = [exception reason];
        expected = @"There is already a group with that name";
        range = [reason rangeOfString:expected];
        STAssertTrue(range.length > 0, @"Configuration with two single groups with sama name should cause an exception");
    }
    
    cfgName = cfgName = @"ulib/no-group-separator.conf";
    UMConfig *cfg2 = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    [cfg2 allowSingleGroup:@"pgsql-test-table"];
    [cfg2 allowSingleGroup:@"other-test-table"];
    
    @try 
    {
        [cfg2 read];
    }
    @catch (NSException *exception) {
        reason = [exception reason];
        expected = @"Group inside group doesnt make sense";
        range = [reason rangeOfString:expected];
        STAssertTrue(range.length > 0, @"Config file with no group separator should cause an exception");
    }
    
    cfgName = cfgName = @"ulib/no-equal-sign.conf";
    UMConfig *cfg3 = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    [cfg3 allowSingleGroup:@"pgsql-test-table"];
    [cfg3 allowSingleGroup:@"other-test-table"];
    
    @try 
    {
        [cfg3 read];
    }
    @catch (NSException *exception) {
        reason = [exception reason];
        expected = @"No equalsign in line";
        range = [reason rangeOfString:expected];
        STAssertTrue(range.length > 0, @"Config file with a line with no equal sign should causse an exception");
    }
    
    /* There we have a feature: 'host =' is converted to 'host = ""', if host is a variable*/
    cfgName = @"ulib/one-entity-in-line.conf";
    UMConfig *cfg4 = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    [cfg4 allowSingleGroup:@"pgsql-test-table"];
    [cfg4 allowSingleGroup:@"other-test-table"];
    [cfg4 read];
    
    /* Same feature: 'group =' is converted to 'group = ""', which causes a parsing exception*/
    cfgName = @"ulib/no-group-name.conf";
    UMConfig *cfg5 = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    [cfg5 allowSingleGroup:@"pgsql-test-table"];
    [cfg5 allowSingleGroup:@"other-test-table"];
    
    @try 
    {
        [cfg5 read];
    }
    @catch (NSException *exception) {
        reason = [exception reason];
        expected = @"Don't know how to parse group";
        range = [reason rangeOfString:expected];
        STAssertTrue(range.length > 0, @"Config file with a line with no group name should causse an exception");
    }
    
    /* '= somehost' will be converted to '"= somehost". If someone uses that broken config files, he reserves what
     * he gets. At least there are no crash.*/
    cfgName = @"ulib/no-left-in-line.conf";
    UMConfig *cfg6 = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    [cfg6 allowSingleGroup:@"pgsql-test-table"];
    [cfg6 allowSingleGroup:@"other-test-table"];
    [cfg6 read];
    
    /* Group = something introduces a group. If there are no group, this part of config file is ignored*/
    cfgName = @"ulib/no-group-specifier.conf";
    UMConfig *cfg7 = [[[UMConfig alloc] initWithFileName:cfgName] autorelease];
    [cfg7 allowSingleGroup:@"pgsql-test-table"];
    [cfg7 allowSingleGroup:@"other-test-table"];
    [cfg7 read];
    
    [autoPool release];
}

@end
