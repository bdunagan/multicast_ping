//
//  Message.h
//  Multicast Ping
//
//  Copyright 2010 bdunagan.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Message : NSObject {
	NSString *address;
	int port;
	NSString *message;
}

- (id)initWithAddress:(NSString *)newAddress andPort:(int)newPort andMessage:(NSString *)newMessage;
- (NSString *)name;
- (NSString *)message;

@end
