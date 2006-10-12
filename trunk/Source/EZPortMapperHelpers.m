/*
 Copyright (c) 2006 Emanuel Zephir
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "EZPortMapperHelpers.h"
#include <arpa/inet.h>

#pragma mark IP Request Packet Classes

@implementation EZIPRequestPacket
- (NSData *)data {
	return [NSMutableData dataWithLength:2];
}
@end

@implementation EZIPResponsePacket
- (id)initWithData:(NSData *)data {
	if (self = [super init]) {
		NSLog(@"Data: %@", data);
		if ([data length] != 12) {
			NSLog(@"Data for IPResponse wrong size: %u", [data length]);
			[self release];
			return nil;
		}
		
		const UInt8* bytes = [data bytes];
		if (*bytes != 0) {
			NSLog(@"Wrong protocol version. Was %d, but should be 0.", *bytes);
			[self release];
			return nil;
		}
		
		bytes += 2;
		resultCode = ntohs(*((UInt16*)bytes));
		bytes += 2;
		secondsSinceEpoch = ntohl(*((UInt32*)bytes));
		bytes += 4;
		struct in_addr inAddr;
		inAddr.s_addr = *((UInt32*)bytes);
		ipAddr = [[NSString alloc] initWithUTF8String:inet_ntoa(inAddr)];
	}
	return self;
}
- (UInt16)resultCode {
	return resultCode;
}

- (unsigned)secondsSinceEpoch {
	return secondsSinceEpoch;
}
- (NSString *)IPAddress {
	return ipAddr;
}

- (void)dealloc {
	[ipAddr release];
	[super dealloc];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"ResultCode: %d, IP: %@, SecondsSinceEpoch %d", resultCode, ipAddr, secondsSinceEpoch];
}
@end

#pragma mark Port Map Request Packets

@implementation EZPortMappingRequestPacket

- (id)initWithLocalPort:(UInt16)aLocalPort remotePort:(UInt16)aRemotePort mappingType:(EZMappingType)aMappingType {
	if ((self = [super init])) {
		localPort = aLocalPort;
		remotePort = aRemotePort;
		mappingType = aMappingType;
	}
	return self;
}
- (UInt16)localPort {
	return localPort;
}
- (UInt16)remotePort {
	return remotePort;
}
- (EZMappingType)mappingType {
	return mappingType;
}
- (NSData *)data {
	NSMutableData *data = [NSMutableData dataWithCapacity:12];
	UInt8 version;
	[data appendBytes:&version length:sizeof(version)];
	
	UInt8 opcodeType = (mappingType == EZUDPMapping) ? 1 : 2;
	[data appendBytes:&opcodeType length:sizeof(opcodeType)];
	
	UInt16 reserved = 0;
	[data appendBytes:&reserved length:sizeof(reserved)];
	
	[data appendBytes:&localPort length:sizeof(localPort)];
	[data appendBytes:&remotePort length:sizeof(remotePort)];
	
	// recommended length by spec
	UInt32 portMappingLength = 3200;
	[data appendBytes:&portMappingLength length:sizeof(portMappingLength)];
	return data;
}
@end

@implementation EZPortMappingResponsePacket
- (id)initWithData:(NSData *)data {
	if ((self = [super init])) {
		const UInt8 *bytes = [data bytes];
		
		//skip version and opcode
		bytes += 2;
		
		resultCode = ntohs(*((UInt16*)bytes));
		bytes += 2;
		secondsSinceEpoch = ntohl(*((UInt32*)bytes));
		bytes += 4;
		localPort = ntohs(*((UInt16*)bytes));
		bytes += 2;
		remotePort = ntohs(*((UInt16*)bytes));
		bytes += 2;
		mappingLifetime = ntohl(*((UInt32*)bytes));
	}
	return self;
}
- (UInt16)localPort {
	return localPort;
}
- (UInt16)remotePort {
	return remotePort;
}
- (UInt16)resultCode {
	return resultCode;
}
- (EZMappingType)mappingType {
	return mappingType;
}
- (UInt32)secondsSinceEpoch {
	return secondsSinceEpoch;
}
- (UInt32)mappingLifetime {
	return mappingLifetime;
}
@end
