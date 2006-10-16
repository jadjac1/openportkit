/*
 Copyright (c) 2006 Emanuel Zephir
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import "PortForwardClient.h"
#import "EZPortMapperHelpers.h"

@interface EZPortForwardServer : NSObject {
	NSMutableDictionary	*mClients;
	NSMutableArray		*mRequestQueue;
	
	CFSocketRef			mSocket;
	NSString			*mRouterAddress;
	NSTimeInterval		mRequestTimeout;
	Class				mLastPacketType;
	
	NSTimer				*mPingTimer;
	NSTimer				*mRequestTimer;
	NSTimer				*mKillTimer;
}

#pragma mark NSObject
- (id)init;

#pragma mark Internal Methods
- (void)removeInactiveClients;
- (void)shutdownServer;
- (void)addRequest:(NSDictionary *)request;
- (void)processRequest;
- (void)setRouterAddress:(NSString *)address;

#pragma mark Client Messages
- (long)registerClient:(EZPortForwardClient *)client;
- (void)unregisterClient:(long)clientID;
- (void)requestMappingFromRemotePort:(UInt16)remotePort toLocalPort:(UInt16)localPort withMappingType:(EZMappingType)mappingType forClientID:(long)clientID;
- (void)requestIPAddressForClientID:(long)clientID;
@end