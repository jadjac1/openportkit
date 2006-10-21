/*
 Copyright (c) 2006 Emanuel Zephir
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Cocoa/Cocoa.h>


//@protocol EZPortForwardClientCallbacks
//- (void)routerMappedRemotePort:(UInt16)remotePort toLocalPort:(UInt16)localPort;
//- (void)routerHasIPAddress:(NSString *)address;
//- (void)routerHadErrorRequestingIPAddress:(int)error;
//- (void)routerHadError:(UInt32)error mappingRemotePort:(UInt16)remotePort toLocalPort:(UInt16)localPort;
//- (void)ping;
//@end

@protocol ServerMessages;
@interface EZPortForwardClient : NSObject {
	NSConnection *mConnection;
	id mDelegate;
	long mClientID;
	id mServer;
}
-(id)initWithDelegate:(id)delegate;
-(void)ping;
@end

@protocol ServerMessages 
- (long)registerClient:(EZPortForwardClient *)client;


//- (void)unregisterClient:(long)clientID;
//- (void)requestMappingFromRemotePort:(UInt16)remotePort toLocalPort:(UInt16)localPort withMappingType:(EZMappingType)mappingType forClientID:(long)clientID;
//- (void)requestIPAddressForClientID:(long)clientID;
@end

//#pragma mark Request Methods
//- (void)mapRemotePort:(UInt16)remotePort toLocalPort:(UInt16)localPort;
//- (void)requestPublicIPAddress;
//
//#pragma mark EZPortForwardClientCallbacks
//- (void)routerMappedRemotePort:(UInt16)remotePort toLocalPort:(UInt16)localPort;
//- (void)routerHasIPAddress:(NSString *)address;
//- (void)routerHadErrorRequestingIPAddress:(int)error;
//- (void)routerHadError:(UInt32)error mappingRemotePort:(UInt16)remotePort toLocalPort:(UInt16)localPort;
//- (void)ping;

