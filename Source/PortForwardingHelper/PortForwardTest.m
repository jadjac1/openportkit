/*
 Copyright (c) 2006 Emanuel Zephir
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "PortForwardTest.h"
#import <sys/socket.h>
#import <sys/un.h>


@implementation PortForwardTest
- (id)init {
	if ( (self = [super init]) ) {
		struct sockaddr_un address;
		bzero(&address,sizeof(struct sockaddr_un));
		address.sun_family = AF_UNIX;
		strcpy(address.sun_path,"/tmp/PFSocket");
		NSSocketPort *port = [[NSSocketPort alloc] initRemoteWithProtocolFamily:PF_UNIX socketType:SOCK_STREAM protocol:0 address:[NSData dataWithBytes:&address length:sizeof(struct sockaddr_un)]];
		connection = [[NSConnection alloc] initWithReceivePort:nil sendPort:port];
		[port release];
		[self performSelector:@selector(printHello) withObject:nil afterDelay:1.0];
	}
	return self;
}

-(void)printHello {
	id object = [connection rootProxy];
	NSLog(@"This thing should say hello: %@", [object getHello]);
}
@end

int main(int argc, char** argv) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	PortForwardTest *test = [[PortForwardTest alloc] init];
	while(true)
	[[NSRunLoop currentRunLoop] run];
	[pool release];
	return 2;
}