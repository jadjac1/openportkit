/*
 Copyright (c) 2006 Emanuel Zephir
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "EZPortForwardClient.h"
#include <sys/un.h>
#include <sys/socket.h>

#define kUNIXSOCKETLOCATION "/tmp/OpenPortKitHelper.sock"
@implementation EZPortForwardClient

-(id)initWithDelegate:(id)delegate {
	if ((self = [super init])) {
		mDelegate = delegate;
		
		struct sockaddr_un remoteSocketAddress;
		bzero(&remoteSocketAddress,sizeof(struct sockaddr_un));
		//remoteSocketAddress.sun_len = sizeof(struct sockaddr_un);
		remoteSocketAddress.sun_family = AF_UNIX;
		strcpy(remoteSocketAddress.sun_path, kUNIXSOCKETLOCATION);
		
		NSSocketPort *remoteSocketPort = [[NSSocketPort alloc] initRemoteWithProtocolFamily:PF_UNIX socketType:SOCK_STREAM protocol:0 address:[NSData dataWithBytes:&remoteSocketAddress length:sizeof(struct sockaddr_un)]];
		if (!remoteSocketPort) {
			[self release];
			return nil;
		}
		mConnection = [[NSConnection alloc] initWithReceivePort:nil sendPort:remoteSocketPort];
		if (!mConnection) {
			[remoteSocketPort release];
			[self release];
			return nil;
		}
		[remoteSocketPort release];
		remoteSocketPort = nil;
		
		mServer = (id)[mConnection rootProxy];
		mClientID = [mServer registerClient:self];
		NSLog(@"Client ID: %dl", mClientID);
	}
	return self;
}

-(void)ping {
	// intentionally empty. Called by the server to verify continued connection.
}
@end
