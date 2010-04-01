//
//  AppDelegate.m
//  Test Multicast
//
//  Copyright 2010 bdunagan.com. All rights reserved.
//

#import "AppDelegate.h"
#import "Message.h"
#import <Security/AuthorizationTags.h>

@implementation AppDelegate

#pragma mark -
#pragma mark User Interface

- (void)awakeFromNib {
	// Setup model storage.
	messages = [[NSMutableArray alloc] init];

	// Setup interface.
	[self stopProcessing];

	// Setup security.
	AuthorizationItem items = {kAuthorizationRightExecute, 0, NULL, 0};
	AuthorizationRights rights = {1, &items};
	[authView setAuthorizationRights:&rights];
	authView.delegate = self;
	[authView updateStatus:nil];
	helperPath = [[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"multicast_tester"] retain];
}

- (IBAction)clickStartButton:(id)sender {
	if (helperHandle == nil) {
		BOOL didLaunch = [self launchHelper];
		if (didLaunch) {
			[self startProcessing];
		}
		else {
			[self stopProcessing];
		}
	}
	else {
		[self stopProcessing];
	}
}

- (void)startProcessing {
	// Hide any error message.
	[errorMessage setHidden:YES];
	// Update button title.
	[startButton setTitle:@"Stop"];
	// Hide spinner.
	[spinner startAnimation:nil];
	[spinner setHidden:NO];
}

- (void)stopProcessing {
	// Update button title.
	[startButton setTitle:@"Start"];
	// Hide spinner.
	[spinner setHidden:YES];
	[spinner stopAnimation:nil];
	// Close pipe to terminate the helper tool.
	[helperHandle closeFile];
	helperHandle = nil;
}

#pragma mark -
#pragma mark NSTableView Data Source

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [messages count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	if ([[aTableColumn identifier] isEqual:@"Name"]) {
		return [[messages objectAtIndex:rowIndex] name];
	}
	else if ([[aTableColumn identifier] isEqual:@"Message"]) {
		return [[messages objectAtIndex:rowIndex] message];
	}
	else {
		return nil;
	}
}

#pragma mark -
#pragma mark Controller

- (void)applicationWillTerminate:(NSNotification *)notification {
	if (helperHandle != nil) {
		[self stopProcessing];
	}
}

- (void)dealloc {
	[self stopProcessing];
	[helperPath release];
	[messages release];
	[super dealloc];
}

- (BOOL)launchHelper {
	// Get address and port.
	NSString *address = [addressField stringValue];
	NSString *port = [portField stringValue];

	// Collect arguments into an array.
	NSMutableArray *args = [NSMutableArray array];
	[args addObject:[NSString stringWithFormat:@"%@", address]];
	[args addObject:[NSString stringWithFormat:@"%@", port]];

	// Convert array into void-* array.
	const char **argv = (const char **)malloc(sizeof(char *) * [args count] + 1);
	int currentIndex = 0;
	for (currentIndex = 0; currentIndex < [args count]; currentIndex++) {
		argv[currentIndex] = [[args objectAtIndex:currentIndex] UTF8String];
	}
	argv[currentIndex] = nil;

	// Execute the command with privileges from SFAuthorizationView.
	FILE *handle;
	OSErr processError = AuthorizationExecuteWithPrivileges([[authView authorization] authorizationRef], [helperPath UTF8String], 
															kAuthorizationFlagDefaults, (char *const *)argv, &handle);
	free(argv);
	if (processError != 0) {
		NSLog(@"helper tool failed (%d)", processError);
		return NO;
	}

	// Setup the two-way pipe.
	helperHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileno(handle)];
	[helperHandle waitForDataInBackgroundAndNotify];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTaskOutput:) name:NSFileHandleDataAvailableNotification object:helperHandle];

	return YES;
}

- (void)handleTaskOutput:(NSNotification *)notification {
	// Get the new data.
	NSFileHandle *handle = (NSFileHandle *)[notification object];
	NSData *data = [handle availableData];
	if ([data length] > 0) {
		// Convert the data into a string.
		NSString *dataString = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
		if ([dataString isEqual:@"port in use"]) {
			// Tool failed.
			[self handleToolFailure];
			[dataString release];
			return;
		}

		// Process the string, expecting "address,port,message".
		NSArray *array = [dataString componentsSeparatedByString:@","];
		[dataString release];
		if ([array count] == 3) {
			// Get attributes.
			NSString *address = [array objectAtIndex:0];
			int port = [[array objectAtIndex:1] intValue];
			NSString *message = [array objectAtIndex:2];

			// Create new message.
			Message *newMessage = [[Message alloc] initWithAddress:address andPort:port andMessage:message];
			[messages addObject:newMessage];
			[newMessage release];
			
			// Update view.
			[listView reloadData];
		}
		
		// Prepare for more data.
		[handle waitForDataInBackgroundAndNotify];
	}
	else {
		// No data means tool failed.
		[self handleToolFailure];
	}
}

- (void)handleToolFailure {
	[self stopProcessing];
	[errorMessage setHidden:NO];
}

@end
