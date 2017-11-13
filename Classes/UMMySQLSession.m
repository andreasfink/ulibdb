//
//  UMMySQLSession.m
//  ulibdb.framework
//
//  Created by Andreas Fink on 24.10.11.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.

//#include "../gw-config.h"
#import "ulib/ulib.h"
#import "ulibdb_defines.h"

#ifdef HAVE_MYSQL

#import "UMMySQLSession.h"
#include <mysql/mysql.h>
#include <mysql/errmsg.h>
#include <mysql/mysqld_error.h>
#import "UMDbResult.h"
#import "UMDbMySqlInProgress.h"

//#define MYSQL_DEBUG 1
@implementation UMMySQLSession

@synthesize type;
@synthesize loghandler;
@synthesize lastInProgress;

- (MYSQL *)connection
{
    return connection;
}

- (UMDbSession *)initWithPool:(UMDbPool *)p
{

    @autoreleasepool
    {
        if (!p)
        {
            return nil;
        }
        self=[super initWithPool:p];
        if(self)
        {
            mysql_init(&mysql);
            connection = NULL;
        }
        return self;
    }
}

- (void)dealloc
{
    [logFeed info:0 withText:[NSString stringWithFormat:@"UMMySQLConnection '%@'is being deallocated\n",name]];
    name = nil;
}

- (void) setLogHandler:(UMLogHandler *)handler
{
	if( loghandler != handler)
	{
		
		logFeed = [[UMLogFeed alloc] initWithHandler:loghandler section:type subsection:@"log"];
		[logFeed setCopyToConsole:1];
		[logFeed setName:name];
	}
}

- (BOOL) connect
{
    @autoreleasepool
    {
        
        MYSQL_RES	*res;
        MYSQL_ROW	row;
        int     state;

        [_sessionLock lock];
        @try
        {
            
            my_bool  my_true = 1;
            if (mysql_options(&mysql, MYSQL_OPT_RECONNECT, &my_true))
            {
                NSLog(@"mysql_options (MYSQL_OPT_RECONNECT) failed");
            }
            connection = mysql_real_connect(&mysql,
                                            (const char *)[[pool hostName]UTF8String],
                                            (const char *)[[pool user]UTF8String],
                                            (const char *)[[pool pass]UTF8String],
                                            (const char *)[[pool dbName]UTF8String],
                                            (unsigned int)[pool port],
                                            (const char *)[[pool socket]UTF8String],
                                            (unsigned long)0);
            if(connection == NULL)
            {
                NSMutableString *reason = [NSMutableString stringWithString:@"Cannot connect to mysql database (mysql_error ["];
                [reason appendFormat:@"%s]) while executing connect", mysql_error(&mysql)];
                @throw [NSException exceptionWithName:@"NSDestinationInvalidException" reason:reason userInfo:nil];
                return NO;
            }
            
            sessionStatus = UMDBSESSION_STATUS_CONNECTED;
            
            const char *query = "show variables like 'version'";
            self.lastInProgress = [[UMDbMySqlInProgress alloc]initWithCString:query previousQuery:lastInProgress];
            state = mysql_query(connection,query);
            [lastInProgress completed];
            
            if(state != 0)
            {
                @throw [NSException exceptionWithName:@"NSObjectNotAvailableException" reason:@"cant use mysql_query" userInfo:nil];
                return NO;
            }
            res = mysql_store_result(connection);
            if(res == 0)
            {
                @throw [NSException exceptionWithName:@"NSObjectNotAvailableException" reason:@"cant use mysql_store_result()" userInfo:nil];
                return NO;
            }
            
            row = mysql_fetch_row(res);
            if(row == 0)
            {
                @throw [NSException exceptionWithName:@"NSObjectNotAvailableException" reason:@"cant use mysql_fetch_row" userInfo:nil];
            }
            versionString = [[NSString alloc]initWithUTF8String:row[1]];
            mysql_free_result(res);
            
            mysqlServerVer =  mysql_get_server_version(connection);
            if(mysqlServerVer < 50619)
            {
                [logFeed warning:0 withText:[NSString stringWithFormat:@"MySQL server version is  %ld which is < 5.6.15",mysqlServerVer]];
            }
            mysqlClientVer = mysql_get_client_version();
            if(mysqlServerVer < 50619)
            {
                [logFeed warning:0 withText:[NSString stringWithFormat:@"MySQL client version is  %ld which is < 5.0.15",mysqlServerVer]];
            }
            
            query = "set autocommit=1";
            self.lastInProgress = [[UMDbMySqlInProgress alloc]initWithCString:query previousQuery:lastInProgress];
            mysql_query(connection,query);
            [lastInProgress completed];
            
            mysql_options(connection, MYSQL_READ_DEFAULT_FILE,"/etc/my.cnf");
            mysql_options(connection, MYSQL_SET_CHARSET_NAME,"UTF8");
            my_bool b = 1;
            mysql_options(connection, MYSQL_OPT_RECONNECT,&b);
            //    mysql_options(connection, MYSQL_OPT_CONNECT_TIMEOUT,"1800"); /* 30 minutes */
            //    mysql_options(connection, MYSQL_OPT_COMPRESS,NULL); /* enable compression */
            //   unsigned int timeout = 1800;
            //   mysql_options(connection, MYSQL_OPT_READ_TIMEOUT,&timeout);

            mysql_query(connection,"SET NAMES utf8");
            mysql_query(connection,"SET CHARACTER SET utf8");
            mysql_query(connection,"SET character_set_server = 'utf8'");
            mysql_query(connection,"SET character_set_connection = 'utf8'");

           
        }
        @finally
        {
            [_sessionLock unlock];
        }
        return YES;
    }
}

- (void) disconnect
{
    if(sessionStatus == UMDBSESSION_STATUS_CONNECTED)
    {
        sessionStatus = UMDBSESSION_STATUS_DISCONNECTED;
        mysql_close(connection);
        connection = NULL;
    }
}

- (int)errorCheck:(int) state forSql:(NSString *)sql;
{
	if(state < CR_ERROR_FIRST)
    {
        return state;
    }

    NSString *s = NULL;
    switch(state)
    {
        case CR_UNKNOWN_ERROR:
            s = @"CR_UNKNOWN_ERROR";
            break;
        case CR_SOCKET_CREATE_ERROR:
            s = @"CR_SOCKET_CREATE_ERROR";
            break;
        case CR_CONNECTION_ERROR:
            s = @"CR_CONNECTION_ERROR";
            break;
        case CR_CONN_HOST_ERROR:
            s = @"CR_CONN_HOST_ERROR";
            break;
        case CR_IPSOCK_ERROR:
            s = @"CR_IPSOCK_ERROR";
            break;
        case CR_UNKNOWN_HOST:
            s = @"CR_UNKNOWN_HOST";
            break;
        case CR_SERVER_GONE_ERROR:
            s = @"CR_SERVER_GONE_ERROR";
            break;
        case CR_VERSION_ERROR:
            s = @"CR_VERSION_ERROR";
            break;
        case CR_OUT_OF_MEMORY:
            s = @"CR_OUT_OF_MEMORY";
            break;
        case CR_WRONG_HOST_INFO:
            s = @"CR_WRONG_HOST_INFO";
            break;
        case CR_LOCALHOST_CONNECTION:
            s = @"CR_LOCALHOST_CONNECTION";
            break;
        case CR_TCP_CONNECTION:
            s = @"CR_TCP_CONNECTION";
            break;
        case CR_SERVER_HANDSHAKE_ERR:
            s = @"CR_SERVER_HANDSHAKE_ERR";
            break;
        case CR_SERVER_LOST:
            s = @"CR_SERVER_LOST";
            break;
        case CR_COMMANDS_OUT_OF_SYNC:
            s = @"CR_COMMANDS_OUT_OF_SYNC";
            break;
        case CR_NAMEDPIPE_CONNECTION:
            s = @"CR_NAMEDPIPE_CONNECTION";
            break;
        case CR_NAMEDPIPEWAIT_ERROR:
            s = @"CR_NAMEDPIPEWAIT_ERROR";
            break;
        case CR_NAMEDPIPEOPEN_ERROR:
            s = @"CR_NAMEDPIPEOPEN_ERROR";
            break;
        case CR_NAMEDPIPESETSTATE_ERROR:
            s = @"CR_NAMEDPIPESETSTATE_ERROR";
            break;
        case CR_CANT_READ_CHARSET:
            s = @"CR_CANT_READ_CHARSET";
            break;
        case CR_NET_PACKET_TOO_LARGE:
            s = @"CR_NET_PACKET_TOO_LARGE";
            break;
        case CR_EMBEDDED_CONNECTION:
            s = @"CR_EMBEDDED_CONNECTION";
            break;
        case CR_PROBE_SLAVE_STATUS:
            s = @"CR_PROBE_SLAVE_STATUS";
            break;
        case CR_PROBE_SLAVE_HOSTS:
            s = @"CR_PROBE_SLAVE_HOSTS";
            break;
        case CR_PROBE_SLAVE_CONNECT:
            s = @"CR_PROBE_SLAVE_CONNECT";
            break;
        case CR_PROBE_MASTER_CONNECT:
            s = @"CR_PROBE_MASTER_CONNECT";
            break;
        case CR_SSL_CONNECTION_ERROR:
            s = @"CR_SSL_CONNECTION_ERROR";
            break;
        case CR_MALFORMED_PACKET:
            s = @"CR_MALFORMED_PACKET";
            break;
        case CR_WRONG_LICENSE:
            s = @"CR_WRONG_LICENSE";
            break;
        case CR_NULL_POINTER:
            s = @"CR_NULL_POINTER";
            break;
        case CR_NO_PREPARE_STMT:
            s = @"CR_NO_PREPARE_STMT";
            break;
        case CR_PARAMS_NOT_BOUND:
            s = @"CR_PARAMS_NOT_BOUND";
            break;
        case CR_DATA_TRUNCATED:
            s = @"CR_DATA_TRUNCATED";
            break;
        case CR_NO_PARAMETERS_EXISTS:
            s = @"CR_NO_PARAMETERS_EXISTS";
            break;
        case CR_INVALID_PARAMETER_NO:
            s = @"CR_INVALID_PARAMETER_NO";
            break;
        case CR_INVALID_BUFFER_USE:
            s = @"CR_INVALID_BUFFER_USE";
            break;
        case CR_UNSUPPORTED_PARAM_TYPE:
            s = @"CR_UNSUPPORTED_PARAM_TYPE";
            break;
        case CR_SHARED_MEMORY_CONNECTION:
            s = @"CR_SHARED_MEMORY_CONNECTION";
            break;
        case CR_SHARED_MEMORY_CONNECT_REQUEST_ERROR:
            s = @"CR_SHARED_MEMORY_CONNECT_REQUEST_ERROR";
            break;
        case CR_SHARED_MEMORY_CONNECT_ANSWER_ERROR:
            s = @"CR_SHARED_MEMORY_CONNECT_ANSWER_ERROR";
            break;
        case CR_SHARED_MEMORY_CONNECT_FILE_MAP_ERROR:
            s = @"CR_SHARED_MEMORY_CONNECT_FILE_MAP_ERROR";
            break;
        case CR_SHARED_MEMORY_CONNECT_MAP_ERROR:
            s = @"CR_SHARED_MEMORY_CONNECT_MAP_ERROR";
            break;
        case CR_SHARED_MEMORY_FILE_MAP_ERROR:
            s = @"CR_SHARED_MEMORY_FILE_MAP_ERROR";
            break;
        case CR_SHARED_MEMORY_MAP_ERROR:
            s = @"CR_SHARED_MEMORY_MAP_ERROR";
            break;
        case CR_SHARED_MEMORY_EVENT_ERROR:
            s = @"CR_SHARED_MEMORY_EVENT_ERROR";
            break;
        case CR_SHARED_MEMORY_CONNECT_ABANDONED_ERROR:
            s = @"CR_SHARED_MEMORY_CONNECT_ABANDONED_ERROR";
            break;
        case CR_SHARED_MEMORY_CONNECT_SET_ERROR:
            s = @"CR_SHARED_MEMORY_CONNECT_SET_ERROR";
            break;
        case CR_CONN_UNKNOW_PROTOCOL:
            s = @"CR_CONN_UNKNOW_PROTOCOL";
            break;
        case CR_INVALID_CONN_HANDLE:
            s = @"CR_INVALID_CONN_HANDLE";
            break;
        case CR_SECURE_AUTH:
            s = @"CR_SECURE_AUTH";
            break;
        case CR_FETCH_CANCELED:
            s = @"CR_FETCH_CANCELED";
            break;
        case CR_NO_DATA:
            s = @"CR_NO_DATA";
            break;
        case CR_NO_STMT_METADATA:
            s = @"CR_NO_STMT_METADATA";
            break;
        case CR_NO_RESULT_SET:
            s = @"CR_NO_RESULT_SET";
            break;
        case CR_NOT_IMPLEMENTED:
            s = @"CR_NOT_IMPLEMENTED";
            break;
        case CR_SERVER_LOST_EXTENDED:
            s = @"CR_SERVER_LOST_EXTENDED";
            break;
        case CR_STMT_CLOSED:
            s = @"CR_STMT_CLOSED";
            break;
        case CR_NEW_STMT_METADATA:
            s = @"CR_NEW_STMT_METADATA";
            break;
#ifdef CR_ALREADY_CONNECTED
        case CR_ALREADY_CONNECTED:
            s = @"CR_ALREADY_CONNECTED";
            break;
#endif

#ifdef CR_AUTH_PLUGIN_CANNOT_LOAD
        case CR_AUTH_PLUGIN_CANNOT_LOAD:
            s = @"CR_AUTH_PLUGIN_CANNOT_LOAD";
            break;
#endif
    }
    if(s)
    {
        s = [NSString stringWithFormat:@"MYSQL: %@\n",s];
    }
    else
    {
        s = [NSString stringWithFormat:@"MYSQL: State=%d",state];
    }
    [logFeed debug:0 inSubsection:@"mysql" withText:s];
    NSLog(@"%@",s);
    return state;
}


- (BOOL)queryWithNoResult:(NSString *)sql allowFail:(BOOL)allowFail affectedRows:(unsigned long long *)count
{
    @autoreleasepool
    {
        BOOL success = YES;
        [_sessionLock lock];
        @try
        {
            
            
#ifdef MYSQL_DEBUG
            NSLog(@"SQL: %@",sql);
#endif
            sql = [sql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if([sql length]==0)
            {
                return YES;
            }
            [logFeed debug:0 inSubsection:@"mysql" withText:[NSString stringWithFormat:@"MYSQL_QUERY: *** %s***\n\n",[sql UTF8String]]];
            
            self.lastInProgress = [[UMDbMySqlInProgress alloc]initWithString:sql previousQuery:lastInProgress];
            
            int state = mysql_query(connection,[sql UTF8String]);
            
            MYSQL_RES *r = mysql_store_result(connection);
            if(r)
            {
                mysql_free_result(r);
                NSString *s = [NSString stringWithFormat:@"we are getting a result while we are not expecting one\nQuery: %@",sql];
                fprintf(stderr,"ERROR: %s",s.UTF8String);// [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:s userInfo:nil];
            }
            [lastInProgress completed];
            [self errorCheck:state forSql:sql];
            if(state==0)
            {
                /*success */
                if(count!=NULL)
                {
                    *count = (unsigned long long) mysql_affected_rows(connection);
                }
            }
            [logFeed debug:0 inSubsection:@"mysql" withText:[NSString stringWithFormat:@"STATE: %d\n\n",state]];
            
            if(state != 0)
            {
                success = NO;
                
                if(!allowFail)
                {
                    NSString *reason = [NSString stringWithFormat:@"query failed, sql = %s, error=%s",[sql UTF8String],mysql_error(connection)];
                    @throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:reason userInfo:nil];
                }
                else
                {
#if (ULIBDB_CONFIG==Debug)
                    [logFeed majorError:0 withText:[NSString stringWithFormat:@"query failed, sql = \"%@\", error=%s",sql,mysql_error(connection)]];
#endif
                    ;
                }
            }
#ifdef MYSQL_DEBUG
            if(success)
            {
                [logFeed debug:0 inSubsection:@"mysql" withText:@"==SUCCESS=="];
            }
            else
            {
                [logFeed debug:0 inSubsection:@"mysql" withText:@"==FAILURE=="];
            }
#endif
        }
        @finally
        {
            [_sessionLock unlock];
        }
        return success;
    }
}


- (UMDbResult *)queryWithMultipleRowsResult:(NSString *)sql allowFail:(BOOL)failPermission
{
    return [self queryWithMultipleRowsResult:sql allowFail:failPermission file:NULL line:0];
}

- (UMDbResult *)queryWithMultipleRowsResult:(NSString *)sql
                                  allowFail:(BOOL)failPermission
                                       file:(const char *)file
                                       line:(long)line
{
    @autoreleasepool
    {
        
        UMDbResult* result = NULL;
        [_sessionLock lock];
        @try
        {
            MYSQL_RES *r = NULL;
#ifdef MYSQL_DEBUG
            NSLog(@"SQL: %@",sql);
#endif
            if([sql length]==0)
            {
                return NULL;
            }
            
            self.lastInProgress = [[UMDbMySqlInProgress alloc]initWithString:sql previousQuery:lastInProgress];
            int state = mysql_query(connection,[sql UTF8String]);
            r = mysql_store_result(connection);
            
            [lastInProgress completed];
            [self errorCheck:state forSql:sql];
            if(state != 0)
            {
                if(failPermission)
                {
#if (ULIBDB_CONFIG==Debug)
                    [logFeed minorError:0 withText:[NSString stringWithFormat:@"query failed, sql = %s, error=%s",[sql UTF8String],mysql_error(connection)]]
#endif
                    ;
                }
                else
                {
                    NSString *reason = [NSString stringWithFormat:@"query failed, sql = %s, error=%s",[sql UTF8String],mysql_error(connection)];
                    @throw [NSException exceptionWithName:@"NSObjectNotAvailableException" reason:reason userInfo:nil];
                }
                return NULL;
            }
            
            
            if(r==NULL)
            {
                NSString *reason = [NSString stringWithFormat:@"mysql_store_result() failed, sql = %s, error=%s",[sql UTF8String],mysql_error(connection)];
                @throw [NSException exceptionWithName:@"NSObjectNotAvailableException" reason:reason userInfo:nil];
            }
            my_ulonglong affected = mysql_affected_rows(connection);
            if(file)
            {
                result = [[UMDbResult alloc]initForFile:file line:line];
            }
            else
            {
                result = [[UMDbResult alloc]init];
            }
            [result setAffectedRows: affected];
            if(r && affected > 0)
            {
                long columnsCount = mysql_num_fields(r);
                MYSQL_ROW row;
                while((row = mysql_fetch_row(r)))
                {
                    NSMutableArray *arr = [[NSMutableArray alloc]init];
                    for(long i=0;i<columnsCount;i++)
                    {
                        char *cstr = row[i];
                        NSString *value = cstr ? @(cstr) : @"NULL";
                        if(value)
                        {
                            [arr addObject:value];
                        }
                        else
                        {
                            [arr addObject:@""];
                        }
                    }
                    [result addRow:arr];
                }
                
                MYSQL_FIELD *field;
                long i = 0;
                while((field = mysql_fetch_field(r)))
                {
                    NSString *ourName = @(field->name);
                    [result setColumName:ourName forIndex:i];
                    ++i;
                }
            }
            if(r)
            {
                mysql_free_result(r);
            }
        }
        @finally
        {
            [_sessionLock unlock];
        }
        return result;
    }
}

- (BOOL) ping
{
    @autoreleasepool
    {
        if(sessionStatus != UMDBSESSION_STATUS_CONNECTED)
        {
            return YES;
        }
    
        long state;
        [_sessionLock lock];
        @try
        {
            self.lastInProgress = [[UMDbMySqlInProgress alloc]initWithCString:"ping" previousQuery:lastInProgress];
            state = mysql_ping(connection);
            [lastInProgress completed];
            if (state)
            {
                [logFeed debug:0 inSubsection:@"mysql" withText:[NSString stringWithFormat:@"mysql_error [%s] while executing ping",mysql_error(connection)]];
                return NO;
            }
        }
        @finally
        {
            [_sessionLock unlock];
        }
        return YES;
    }
}

- (char)fieldQuoteChar
{
    return '`';
}

- (NSDictionary *)explainTable:(NSString *)table
{
    @autoreleasepool
    {
        NSString *sql = [NSString stringWithFormat:@"explain `%@`",table];
        UMDbResult *result = [self queryWithMultipleRowsResult:sql allowFail:YES];

        NSArray *fieldNames = [result columNames];
        int rownum = 0;
        NSArray *row = [result fetchRow];
        rownum++;
        NSMutableDictionary *fieldDefinitions = [[NSMutableDictionary alloc]init];
        while(row)
        {
            NSMutableDictionary *entry = [[NSMutableDictionary alloc]init];
            entry[@"pos"]=[NSNumber numberWithInt:rownum];
            for(int i=0;i< result.columsCount;i++)
            {
                NSString *n = fieldNames[i];
                NSString *v = row[i];
                if([n isEqualToString:@"Field"])
                {
                    fieldDefinitions[v]=entry;
                }
                entry[n]=v;
            }
            row = [result fetchRow];
            rownum++;
        }
        return fieldDefinitions;
    }
}

@end

#endif

