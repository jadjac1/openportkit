/*
 Copyright (c) 2006 Emanuel Zephir
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <launch.h>

#import "PortForwardServer.h"

EZPortForwardServer *pfs=nil;
int main(int argc, char **argv) {
	//sleep(500);
	launch_data_t message = launch_data_new_string(LAUNCH_KEY_CHECKIN);
	launch_data_t response = launch_msg(message);
	launch_data_free(message);
	
	if (launch_data_get_type(response) == LAUNCH_DATA_ERRNO) {
		//bail?
	}
	launch_data_t socketsDictionary = launch_data_dict_lookup(response, LAUNCH_JOBKEY_SOCKETS);
	launch_data_t unixSocketArray = launch_data_dict_lookup(socketsDictionary, "UNIX");
	
	if (launch_data_array_get_count(unixSocketArray) == 0) {
		sleep(10);
		return 1;
	}
	
	launch_data_t socketData = launch_data_array_get_index(unixSocketArray,0);
	
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	NSSocketPort *connectionPort = [[NSSocketPort alloc] initWithProtocolFamily:PF_UNIX socketType:SOCK_STREAM protocol:0 socket:launch_data_get_fd(socketData)];
	
	launch_data_free(response);
	
	NSConnection *connection = [[NSConnection alloc] initWithReceivePort:connectionPort sendPort:nil];
	pfs = [[EZPortForwardServer alloc] init];
	[connection setRootObject:pfs];
	[[NSRunLoop currentRunLoop] run];
	[autoreleasePool release];
	
	return 0;
}