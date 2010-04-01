//
//  AppDelegate.h
//  Multicast Ping
//
//  Copyright 2010 bdunagan.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SecurityInterface/SFAuthorizationView.h>

@interface AppDelegate : NSObject {
	// View
	IBOutlet NSTextField *addressField;
	IBOutlet NSTextField *portField;
	IBOutlet NSButton *startButton;
	IBOutlet NSTableView *listView;
	IBOutlet NSProgressIndicator *spinner;
	IBOutlet SFAuthorizationView *authView;
	IBOutlet NSTextField *errorMessage;

	// Controller
	NSFileHandle *helperHandle;
	NSMutableArray *messages;
	NSString *helperPath;
}

#pragma mark -
#pragma mark User Interface

- (IBAction)clickStartButton:(id)sender;
- (void)startProcessing;
- (void)stopProcessing;

#pragma mark -
#pragma mark Controller

- (BOOL)launchHelper;
- (void)handleTaskOutput:(NSNotification *)notification;
- (void)handleToolFailure;

@end
