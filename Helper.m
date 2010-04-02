//
//  Helper.m
//  Multicast Ping
//
//  Copyright 2010 bdunagan.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <netdb.h>
#include <arpa/inet.h>

#define LOCAL_ADDRESS @"0.0.0.0"

#pragma mark -

@interface SocketHelper : NSObject {
	// Sockets
	NSSocketNativeHandle receiveSocket;
	NSSocketNativeHandle sendSocket;

	// Model information
	NSString *address;
	int port;
	NSString *message;
	int interval;
	int ttl;
	int loop;
	int result;
}

- (void)createMulticastSendSocket;
- (void)sendMulticast:(id)param;

- (void)createMulticastReceiveSocket;
- (void)receiveMulticast:(id)param;

@end

#pragma mark -

@implementation SocketHelper

- (id)initWithAddress:(NSString *)multicastAddress andPort:(int)multicastPort {
	self = [super init];
	if (self != nil) {
		// Setup model information.
		[multicastAddress retain];
		address = multicastAddress;
		port = multicastPort;
		
		// Setup message.
		message = [[NSString alloc] initWithFormat:@"Multicast Ping: %@", NSFullUserName()];

		// Setup multicast.
		ttl = 10;
		loop = 0;
		interval = 5;
		
		// Initialize sockets.
		[self createMulticastReceiveSocket];
		[self createMulticastSendSocket];
	}
	return self;
}

- (void)dealloc {
	[address release];
	[message release];
	[super dealloc];
}

#pragma mark -
#pragma mark Send

- (void)createMulticastSendSocket {
	sendSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	result = setsockopt(sendSocket, IPPROTO_IP, IP_MULTICAST_TTL, &ttl,(socklen_t)sizeof(ttl));
	result = setsockopt(sendSocket, IPPROTO_IP, IP_MULTICAST_LOOP, &loop,(socklen_t)sizeof(loop));
}

- (void)sendMulticast:(id)param {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	int seqno = 0;
	while (sendSocket != 0) {
		// Initialize address.
		struct sockaddr_in serverAddress;
		size_t namelen = sizeof(serverAddress);
		bzero(&serverAddress, namelen);
		serverAddress.sin_family = AF_INET;
		result = inet_aton([address cStringUsingEncoding:NSASCIIStringEncoding], &serverAddress.sin_addr);
		serverAddress.sin_port = htons(port);

		// Send packet.
		result = sendto(sendSocket, [message cStringUsingEncoding:NSASCIIStringEncoding], [message length], seqno, (struct sockaddr *)&serverAddress, namelen);
		seqno++;

		// Sleep for 1s.
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1]];
	}

	[pool drain];
}

#pragma mark -
#pragma mark Receive

- (void)createMulticastReceiveSocket {
	int flag = 1;

	receiveSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	struct sockaddr_in serverAddress;
	size_t namelen = sizeof(serverAddress);
	bzero(&serverAddress, namelen);
	serverAddress.sin_family = AF_INET;
	serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
	serverAddress.sin_port = htons(port);
	result = setsockopt(receiveSocket, SOL_SOCKET, SO_REUSEADDR, &flag,(socklen_t)sizeof(flag));
	result = bind(receiveSocket, (struct sockaddr *)&serverAddress, (socklen_t)namelen);
	if (result != 0) {
		// Couldn't bind. Port probably in use. Let the parent process know then terminate.
		[(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:[@"port in use" dataUsingEncoding:NSUTF8StringEncoding]];
		exit(1);
	}

	struct ip_mreq  theMulti;
	result = inet_aton([address cStringUsingEncoding:NSASCIIStringEncoding], &theMulti.imr_multiaddr );
	result = inet_aton([LOCAL_ADDRESS cStringUsingEncoding:NSASCIIStringEncoding], &theMulti.imr_interface );
	result = setsockopt(receiveSocket, IPPROTO_IP, IP_ADD_MEMBERSHIP, &theMulti,(socklen_t)sizeof(theMulti));
}

- (void)receiveMulticast:(id)param {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	char receivedLine[1000];
	while (receiveSocket != 0) {
		bzero(&receivedLine, 1000);
		struct sockaddr_in receiveAddress;
		socklen_t receiveAddressLen = sizeof(receiveAddress);

		// Receive packet.
		result = recvfrom(receiveSocket, receivedLine, 1000, 0, (struct sockaddr *)&receiveAddress, &receiveAddressLen);
		if(result > 0) {
			// Extract address, port, message.
			UInt16 sentPort = ntohs(receiveAddress.sin_port);
			char addressBuffer[INET_ADDRSTRLEN];
			inet_ntop(AF_INET, &receiveAddress.sin_addr, addressBuffer, sizeof(addressBuffer));
			NSString *sentHost = [NSString stringWithCString:addressBuffer encoding:NSASCIIStringEncoding];
			NSString *receivedMessage = [NSString stringWithCString:receivedLine encoding:NSASCIIStringEncoding];

			// Write out the new message to the pipe.
			NSString *line = [NSString stringWithFormat:@"%@,%d,%@", sentHost, sentPort, receivedMessage];
			[(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
		}
		else {
			NSLog(@"result %d", result);
		}

		// Sleep for 1s.
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1]];
	}

	[pool drain];
}

@end

#pragma mark -
#pragma mark Main Function

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	// Expecting "multicast_test <address> <port>"
	if (argc == 3) {
		// Get the address and port.
		NSString *address = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
		int port = [[NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding] intValue];

		// Spin off helper threads for sending and receiving.
		SocketHelper *helper = [[SocketHelper alloc] initWithAddress:address andPort:port];
		[NSThread detachNewThreadSelector:@selector(sendMulticast:) toTarget:helper withObject:nil];
		[NSThread detachNewThreadSelector:@selector(receiveMulticast:) toTarget:helper withObject:nil];

		// Wait for parent process to close the pipe. That will send the EOF signal.
		[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
	}
    [pool drain];

    return 0;
}
