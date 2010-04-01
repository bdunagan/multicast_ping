//
//  main.m
//  Test Multicast
//
//  Copyright 2010 bdunagan.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[]) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	int result = NSApplicationMain(argc,  (const char **) argv);
	[pool drain];
	return result;
}
