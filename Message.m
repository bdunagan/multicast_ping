//
//  Message.m
//  Test Multicast
//
//  Copyright 2010 bdunagan.com. All rights reserved.
//

#import "Message.h"

@implementation Message

- (id)initWithAddress:(NSString *)newAddress andPort:(int)newPort andMessage:(NSString *)newMessage {
	self = [super init];
	if (self != nil) {
		[newAddress retain];
		address = newAddress;
		port = newPort;
		[newMessage retain];
		message = newMessage;
	}
	return self;
}

- (NSString *)name {
	return [NSString stringWithFormat:@"%@:%d", address, port];
}

- (NSString *)message {
	return message;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [self name], [self message]];
}

@end
