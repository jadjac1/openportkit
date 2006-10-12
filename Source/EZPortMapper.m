/*
 Copyright (c) 2006 Emanuel Zephir
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "EZPortMapper.h"
#import "EZPortMapperHelpers.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <limits.h>

void EZPortMapperCFSocketCallback(CFSocketRef socket, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info);
void EZPortMapperCFDynamicStoreCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info);


#define kGlobalIPv4SettingsKey		@"State:/Network/Global/IPv4"

#define kWaitingForIPPacket		@"kWaitingForIPPacket"

static NSString *state = nil;
static EZPortMapper *sharedInstance = nil;

@implementation EZPortMapper

+ (id)sharedPortMapper {
	if (!sharedInstance)
		sharedInstance = [[[self class] alloc] init];
	return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
	@synchronized(self) {
		if (sharedInstance)
			return nil;
		sharedInstance = [super allocWithZone:zone];
		return sharedInstance;
	}
	return nil;
}

-(BOOL)isPrivateIPAddress:(NSString *)address {
	// dunno how to handle error checking here
	struct in_addr internetAddress;
	inet_aton([address UTF8String], &internetAddress);
	
	unsigned int intAddress = ntohl(internetAddress.s_addr);
	return (((intAddress & 0xFF000000) == 0x0A000000) || ((intAddress & 0xFFF00000) == 0xAC100000) || ((intAddress & 0xFFFF0000) == 0xC0A80000));
}

-(BOOL)determinePublicIPAddress {
	if (![self defaultGatewayAddress])
		return NO;
	
	struct in_addr internetAddress;
	inet_aton([[self defaultGatewayAddress] UTF8String], &internetAddress);
	return YES;
}

-(id)init {
	if (self = [super init]) {
		CFRunLoopRef runLoopRef = [[NSRunLoop currentRunLoop] getCFRunLoop];
		socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_DGRAM, IPPROTO_UDP , kCFSocketDataCallBack, EZPortMapperCFSocketCallback, NULL);
		CFRunLoopSourceRef socketSourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0);
		CFRunLoopAddSource(runLoopRef, socketSourceRef, kCFRunLoopCommonModes);
		
		dynamicStore = SCDynamicStoreCreate(kCFAllocatorDefault, (CFStringRef)[[NSProcessInfo processInfo] processName], EZPortMapperCFDynamicStoreCallback, NULL);
		
		CFRunLoopSourceRef runLoopSourceRef = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, dynamicStore, 0);
		CFRunLoopAddSource(runLoopRef, runLoopSourceRef,kCFRunLoopCommonModes);
		CFRelease(runLoopSourceRef);
		
		if (!SCDynamicStoreSetNotificationKeys(dynamicStore, (CFArrayRef)[NSArray arrayWithObject:kGlobalIPv4SettingsKey],NULL)) {
			NSLog(@"Watching the key failed!");
			[self release];
			return nil;
		}
		
		CFPropertyListRef properties = SCDynamicStoreCopyValue(dynamicStore, (CFStringRef)kGlobalIPv4SettingsKey);
		if (properties) {
			privateRouterIPAddress = [[((NSDictionary *)properties)objectForKey:@"Router"] copy];
			//NSLog(@"Starting router IP address is %@", privateRouterIPAddress);
			CFRelease(properties);
			properties = NULL;
		}
		
		struct sockaddr_in addr;
		bzero(&addr,sizeof(struct sockaddr_in));
		addr.sin_family = AF_INET;
		addr.sin_port = htons(0);
		addr.sin_addr.s_addr = INADDR_ANY;
		int error = bind(CFSocketGetNative(socket), (struct sockaddr *)&addr, sizeof(struct sockaddr));
		
		struct sockaddr_in routerAddress;
		bzero (&routerAddress, sizeof(struct sockaddr_in));
		routerAddress.sin_family = AF_INET;
		routerAddress.sin_port = htons(5351);
		routerAddress.sin_addr.s_addr = inet_addr([[self defaultGatewayAddress] UTF8String]);
		
		EZIPRequestPacket *packet = [[EZIPRequestPacket alloc] init];
		int error1 = sendto(CFSocketGetNative(socket),[[packet data] bytes],[[packet data] length],0,(struct sockaddr*)&routerAddress,sizeof(struct sockaddr));
		NSLog(@"Error %d", error1);
	}   
	return self;
}

-(id)retain {
	return self;
}

-(void)release {
}

-(unsigned)retainCount {
	return UINT_MAX;
}

-(void)_setDefaultGatewayAddress:(NSString *)routerAddress {
	if (privateRouterIPAddress != routerAddress && (!routerAddress || ![privateRouterIPAddress isEqualToString:routerAddress])) {
		[privateRouterIPAddress release];
		privateRouterIPAddress = [routerAddress copy];
		NSLog(@"New Router Address: %@", privateRouterIPAddress);
	}
}

-(NSString *)defaultGatewayAddress {
	return [[privateRouterIPAddress retain] autorelease];
}

void EZPortMapperCFSocketCallback(CFSocketRef socket, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info) {
	EZIPResponsePacket *packet = [[EZIPResponsePacket alloc] initWithData:(NSData *)data];
	NSLog(@"Response From Router :%@", packet);
}

void EZPortMapperCFDynamicStoreCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
	NSEnumerator *enumerator = [((NSArray*)changedKeys) objectEnumerator];
	NSString *key;
	while ((key = [enumerator nextObject])) {
		if (![key isEqualToString:kGlobalIPv4SettingsKey])
			continue;
		
		CFPropertyListRef plist = SCDynamicStoreCopyValue(store, (CFStringRef)key);
		if (plist) {
			[sharedInstance _setDefaultGatewayAddress:[((NSDictionary *)plist) objectForKey:@"Router"]];
			CFRelease(plist);
		} else {
			[sharedInstance _setDefaultGatewayAddress:nil];
		}
	}
}
@end
