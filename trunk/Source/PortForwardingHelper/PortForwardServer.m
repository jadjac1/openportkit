/*
 Copyright (c) 2006 Emanuel Zephir
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "PortForwardServer.h"
#import "EZPortMapperHelpers.h"
#import "EZPortForwardClient.h"
#import <SystemConfiguration/SystemConfiguration.h>

#include <sys/socket.h>
#include <arpa/inet.h>

#define kPFServerShutdownTime   20.0
#define kPFServerPingInterval	20.0

void EZPortForwardServerCFSocketCallback(CFSocketRef socket, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info);

@implementation EZPortForwardServer

// designated initializer
-(id)init {
	if ((self = [super init])) {
		mClients = [[NSMutableDictionary alloc] init];
		mKillTimer = [[NSTimer timerWithTimeInterval:kPFServerShutdownTime target:self selector:@selector(shutdownServer) userInfo:nil repeats:NO] retain];
		[[NSRunLoop currentRunLoop] addTimer:mKillTimer forMode:NSDefaultRunLoopMode];
	}
	return self;
}

-(void)dealloc {
	[mKillTimer release];
	[mClients release];
	if (mSocket)
		CFRelease(mSocket);
	
	[super dealloc];
}

-(long)registerClient:(EZPortForwardClient *)client {
	if (mKillTimer) {
		[mKillTimer invalidate];
		[mKillTimer release];
		mKillTimer = nil;
	}
	[mClients setObject:client forKey:[NSNumber numberWithLong:(long)client]];
	
	if (!mPingTimer) {
		mPingTimer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:kPFServerPingInterval target:self selector:@selector(removeInactiveClients) userInfo:nil repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:mPingTimer forMode:NSDefaultRunLoopMode];
	}
	return (long)client;
}


- (void)unregisterClient:(long)clientID {
	// clean up any mappings that this client may have
	@try {
		[mClients removeObjectForKey:[NSNumber numberWithLong:clientID]];
	} @catch (NSException *e) { }
}


- (void)removeInactiveClients {
	NSEnumerator *keyEnumerator = [[mClients allKeys] objectEnumerator];
	NSNumber *clientID = nil;
	while ((clientID = [keyEnumerator nextObject])) {
		@try {
			EZPortForwardClient *client = [mClients objectForKey:clientID];
			[client ping];
		}
		@catch (NSException *e) {
			//register removal of mappings for this client
			[mClients removeObjectForKey:clientID];
		}
	}
	
	if ([[mClients allKeys] count] == 0 && !mKillTimer) {
		[mPingTimer invalidate];
		[mPingTimer release];
		mPingTimer = nil;
		
		mKillTimer = [[NSTimer timerWithTimeInterval:kPFServerShutdownTime target:self selector:@selector(shutdownServer) userInfo:nil repeats:NO] retain];
		[[NSRunLoop currentRunLoop] addTimer:mKillTimer forMode:NSDefaultRunLoopMode];
	}
}

- (void)shutdownServer {
	exit(0);
}

@end
