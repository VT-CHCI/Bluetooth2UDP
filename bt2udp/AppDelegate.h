//
//  AppDelegate.h
//  bt2udp
//
//  Created by Siroberto Scerbo on 4/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AMSerialPort.h"
#import "GCDAsyncUdpSocket.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSTextField *serialPortTextField;
    IBOutlet NSTextField *serialInputTextField;
    
    IBOutlet NSTextField *udpAddressTextField;
    IBOutlet NSTextField *udpPortTextField;
    
    IBOutlet NSTextField *serialStatus;
    IBOutlet NSTextField *udpStatus;
    
    IBOutlet NSTextView *outputTextView;
    
    BOOL sending;
    long tag;
    NSString *completeMsg;
    
    AMSerialPort *port;
    GCDAsyncUdpSocket *udpSocket;
    
}

@property (assign) IBOutlet NSWindow *window;

- (AMSerialPort *)port;
- (void)setPort:(AMSerialPort *)newPort;

- (IBAction)connect:(id)sender;
- (IBAction)send:(id)sender;

@end

extern "C"
{
  bool sendUDP(const char* address, int port, const char* data);
}