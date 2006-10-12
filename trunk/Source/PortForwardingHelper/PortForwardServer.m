/*
 Copyright (c) 2006 Emanuel Zephir
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "PortForwardServer.h"
#import "EZPortMapperHelpers.h"
#import "PortForwardClient.h"
#import <SystemConfiguration/SystemConfiguration.h>

#include <sys/socket.h>
#include <arpa/inet.h>
@implementation EZPortForwardServer

void EZPortForwardServerCFSocketCallback(CFSocketRef socket, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info);

void EZPortForwardServerCFDynamicStoreCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info);

#define kGlobalIPv4SettingsKey		@"State:/Network/Global/IPv4"
// designated initializer
-(id)init {
	if ((self = [super init])) {
		mClients = [[NSMutableArray alloc] init];
		mRequestQueue = [[NSMutableArray alloc] init];
		mPingTimer = [[NSTimer timerWithTimeInterval:60.0 target:self selector:@selector(removeInactiveClients) userInfo:nil repeats:YES] retain];
		
		CFRunLoopRef runLoopRef = [[NSRunLoop currentRunLoop] getCFRunLoop];
		mSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_DGRAM, IPPROTO_UDP , kCFSocketDataCallBack, EZPortForwardServerCFSocketCallback, NULL);
		if (!mSocket) {
			[self release];
			return nil;
		}
		
		CFRunLoopSourceRef socketSourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, mSocket, 0);
		CFRunLoopAddSource(runLoopRef, socketSourceRef, kCFRunLoopCommonModes);
		CFRelease(socketSourceRef);
		
		struct sockaddr_in addr;
		bzero(&addr,sizeof(struct sockaddr_in));
		addr.sin_family = AF_INET;
		addr.sin_port = htons(0);
		addr.sin_addr.s_addr = INADDR_ANY;
		if(bind(CFSocketGetNative(mSocket), (struct sockaddr *)&addr, sizeof(struct sockaddr)) != 0) {
			[self release];
			return nil;
		}
		
		SCDynamicStoreRef dynamicStore = SCDynamicStoreCreate(kCFAllocatorDefault, (CFStringRef)[[NSProcessInfo processInfo] processName], EZPortForwardServerCFDynamicStoreCallback, NULL);
		
		CFPropertyListRef properties = SCDynamicStoreCopyValue(dynamicStore, (CFStringRef)kGlobalIPv4SettingsKey);
		
		if (properties) {
			mRouterAddress = [[((NSDictionary *)properties)objectForKey:@"Router"] copy];
			struct sockaddr_in routerAddress;
			bzero (&routerAddress, sizeof(struct sockaddr_in));
			routerAddress.sin_family = AF_INET;
			routerAddress.sin_port = htons(5351);
			routerAddress.sin_addr.s_addr = inet_addr([mRouterAddress UTF8String]);
			connect(CFSocketGetNative(mSocket), (struct sockaddr*)&routerAddress, sizeof(struct sockaddr_in));
			
			CFRelease(properties);
			properties = NULL;
		}
		
	}
	return self;
}

-(void)dealloc {
	[mKillTimer release];
	[mClients release];
	[super dealloc];
}

- (void)setRouterAddress:(NSString *)address {
	if (![address isEqualToString:mRouterAddress]) {
		struct sockaddr_in routerAddress;
		bzero (&routerAddress, sizeof(struct sockaddr_in));
		routerAddress.sin_family = AF_INET;
		routerAddress.sin_port = htons(5351);
		routerAddress.sin_addr.s_addr = inet_addr([address UTF8String]);
		connect(CFSocketGetNative(mSocket), (struct sockaddr*)&routerAddress, sizeof(struct sockaddr_in));
		mRouterAddress = [address copy];
		// if connect gave us an error, the network just changed. ignore this for now - BUG.
	}
		
}

-(long)registerClient:(EZPortForwardClient *)client {
	if (mKillTimer) {
		[mKillTimer invalidate];
		[mKillTimer release];
		mKillTimer = nil;
	}
	[mClients setObject:client forKey:[NSNumber numberWithLong:(long)client]];
	return (long)client;
}


- (void)unregisterClient:(long)clientID {
	// clean up any mappings that this client may have
	[mClients removeObjectForKey:[NSNumber numberWithLong:clientID]];
}


#define kPFSClientID	@"kPFSClientID"
#define kPFSPacket		@"kPFSPacket"

- (void)requestMappingFromRemotePort:(UInt16)remotePort toLocalPort:(UInt16)localPort withMappingType:(EZMappingType)mappingType forClientID:(long)clientID {
	
	if (![mClients objectForKey:[NSNumber numberWithLong:clientID]])
		return; // ignore it when the client has not registered properly

	[self addRequest:[NSDictionary dictionaryWithObjectsAndKeys:[[[EZPortMappingRequestPacket alloc] initWithLocalPort:localPort remotePort:remotePort mappingType:mappingType] autorelease], kPFSPacket, [NSNumber numberWithLong:clientID], kPFSClientID, nil]];
}

- (void)requestIPAddressForClientID:(long)clientID {
	if (![mClients objectForKey:[NSNumber numberWithLong:clientID]])
		return; // ignore it when the client has not registered properly
	[self addRequest:[NSDictionary dictionaryWithObjectsAndKeys:[[[EZIPRequestPacket alloc] init] autorelease], kPFSPacket, [NSNumber numberWithLong:clientID], kPFSClientID, nil]];
}

- (void)addRequest:(NSDictionary *)request {
	// set up the request queue if this is the first one
	[mRequestQueue addObject:request];
}

- (void)processRequest {
	[mRequestTimer release];
	mRequestTimer = nil;
	
	if (![mRequestQueue count]) return;
	
	// request timed out
	if (fabs(mRequestTimeout - 64.0) < 0.5) {
		mRequestTimeout = 0.0;
		return;
	}
	
	if (fabs(mRequestTimeout) < 0.1)
		mRequestTimeout = 0.5;
	else
		mRequestTimeout *= mRequestTimeout;
	
	NSDictionary* request = [mRequestQueue objectAtIndex:0];
	id packet = [request objectForKey:kPFSPacket];
	mLastPacketType = [packet class];
	
	CFSocketSendData(mSocket, NULL, (CFDataRef)[packet data], 5.0);
	
	mRequestTimer = [[NSTimer timerWithTimeInterval:mRequestTimeout target:self selector:@selector(processRequest) userInfo:nil repeats:NO] retain];
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
	
	if ([[mClients allKeys] count] == 0)
		mKillTimer = [[NSTimer timerWithTimeInterval:60.0 target:self selector:@selector(shutdownServer) userInfo:nil repeats:NO] retain];
}

- (void)shutdownServer {
	exit(0);
}

#pragma mark CoreFoundation callbacks
void EZPortForwardServerCFSocketCallback(CFSocketRef socket, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info) {
}

void EZPortForwardServerCFDynamicStoreCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
}

@end
