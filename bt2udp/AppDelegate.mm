//
//  AppDelegate.m
//  bt2udp
//
//  Created by Siroberto Scerbo on 4/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"
#include "deque"
#include "algorithm"
// udp
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>

@implementation AppDelegate

@synthesize window = _window;

std::deque <int> bottomLeftData;
std::deque <int> topLeftData;
std::deque <int> bottomRightData;
std::deque <int> topRightData;

int updateCounter = 0;

enum sensors { bottomLeft , topLeft, bottomRight , topRight};

- (void)dealloc {
    [super dealloc];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [serialPortTextField setStringValue:@"/dev/tty.FireFly-CDA6-SPP"];
    [serialInputTextField setStringValue:@"ati"];
    
    [udpAddressTextField setStringValue:@"172.31.137.116"];
    [udpPortTextField setStringValue:@"2500"];
    
    //udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    sending = false;
    completeMsg = @"";
}

- (AMSerialPort *)port {
    return port;
}

- (void)setPort:(AMSerialPort *)newPort {
    id old = nil;
    
    if (newPort != port) {
        old = port;
        port = [newPort retain];
        [old release];
    }
}

- (void)initPort {
	NSString *deviceName = [serialPortTextField stringValue];
	if (![deviceName isEqualToString:[port bsdPath]]) {
		[port close];
        
		[self setPort:[[[AMSerialPort alloc] init:deviceName withName:deviceName type:(NSString*)CFSTR(kIOSerialBSDModemType)] autorelease]];
		
		// register as self as delegate for port
		[port setDelegate:self];
		
		[serialStatus setStringValue:@"Attempting to open port"];
        [serialStatus setTextColor:[NSColor blackColor]];
		
		// open port - may take a few seconds ...
		if ([port open]) {
			
			[serialStatus setStringValue:@"Port opened"];
            [serialStatus setTextColor:[NSColor blackColor]];
            
			// listen for data in a separate thread
			[port readDataInBackground];
			
		} else { // an error occured while creating port
			[serialStatus setStringValue:[NSString stringWithFormat:@"Couldn't open port %@", deviceName]];
            [serialStatus setTextColor:[NSColor redColor]];
			[self setPort:nil];
		}
	}
}

- (bool) slopeUnderValue:(std::deque<int> &) q :(int) value {
    int front = q.front();
    
    int max = front;
    int min = front;
    
    for (int i = 1; i < q.size(); i++) {
        if (q[i] > max)
            max = q[i];
        if (q[i] < min)
            min = q[i];
    }
    
    return ((max - min) > value);
}

- (bool)peakDetection:(NSArray *)dataPoints {
    //NSLog(@"datapoints count: %lu", dataPoints.count);
    bottomLeftData.push_back([[dataPoints objectAtIndex:bottomLeft] intValue]);
    bottomRightData.push_back([[dataPoints objectAtIndex:bottomRight] intValue]);
    topLeftData.push_back([[dataPoints objectAtIndex:topLeft] intValue]);
    topRightData.push_back([[dataPoints objectAtIndex:topRight] intValue]);
    
    if ([self slopeUnderValue:bottomLeftData:100] || [self slopeUnderValue:bottomRightData:100] ||[self slopeUnderValue:topLeftData:100] ||[self slopeUnderValue:topRightData:100]) {
         return true;
     }
    
    if (bottomLeftData.size() > 10) {
        bottomLeftData.pop_front();
        bottomRightData.pop_front();
        topLeftData.pop_front();
        topRightData.pop_front();
    }
    
    return false;
}

- (void)clearQueue:(std::deque<int> &) q{
    std::deque<int> empty;
    std::swap( q, empty );
}

- (void)serialPortReadData:(NSDictionary *)dataDictionary {
	// this method is called if data arrives 
	// @"data" is the actual data, @"serialPort" is the sending port
	AMSerialPort *sendPort = [dataDictionary objectForKey:@"serialPort"];
	NSData *data = [dataDictionary objectForKey:@"data"];
	if ([data length] > 0) {
		NSString *text = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        //NSLog(@"Text: %@", text);
        completeMsg = [completeMsg stringByAppendingString:text];
        
        NSArray *substrings = [completeMsg componentsSeparatedByString:@";\n"];
        //NSLog(@"substrings count: %lu",substrings.count);
        NSString *outputString;
        for (int i = 0; i < [substrings count]-1; i++) {
            //Write to vectors for peak analysis
            NSArray *dataPoints = [[substrings objectAtIndex:i] componentsSeparatedByString:@","];
            if ([dataPoints count] < 4)
                continue;
            bool peak = false;
            if ([self peakDetection:dataPoints]) {
                outputString = [[NSString alloc] initWithFormat:@"LTK,%i,%i,%i,%i", (int)bottomLeftData.front(), (int)topLeftData.front(), (int)bottomRightData.front(), (int)topRightData.front()];
                
                [self clearQueue:bottomLeftData];
                [self clearQueue:topLeftData];
                [self clearQueue:bottomRightData];
                [self clearQueue:topRightData];
                
                [outputTextView insertText:[outputString stringByAppendingString:@"\n"]];
                peak = true;
            }
            else 
            outputString = [[NSString alloc] initWithString:[substrings objectAtIndex:i]];
            
            updateCounter++;
            //Send if connected to server       
            if (sending && (peak || updateCounter%30 == 0)) {
                const char *data = [outputString cStringUsingEncoding:NSUTF8StringEncoding];
                
                //[udpSocket sendData:data toHost:[udpAddressTextField stringValue] port:[udpPortTextField intValue] withTimeout:-1 tag:tag];
                const char* cStringAddress = [[udpAddressTextField stringValue] cStringUsingEncoding:NSUTF8StringEncoding];
                sendUDP(cStringAddress, [udpPortTextField intValue], data);
                [udpStatus setStringValue:[NSString stringWithFormat:@"Sent (%i)", (int)tag, text]];
                [udpStatus setTextColor:[NSColor blackColor]];
                tag++;
                updateCounter = 0;
            }
        }
        completeMsg = [[substrings lastObject] copy];
                                
        [text release];
		// continue listening
		[sendPort readDataInBackground];
        
        
	} else { // port closed
		[serialStatus setStringValue:@"port closed"];
	}
	[outputTextView setNeedsDisplay:YES];
	[outputTextView displayIfNeeded];
}

- (IBAction)connect:(id)sender {
    if ([[sender title] isEqualToString:@"Connect"]) {
        NSString *sendString = [[serialInputTextField stringValue] stringByAppendingString:@"\r"];
    
        if(!port) {
            // open a new port if we don't already have one
            [self initPort];
        }
        
        if([port isOpen]) { // in case an error occured while opening the port
            [port writeString:sendString usingEncoding:NSUTF8StringEncoding error:NULL];
        }
        
        if ([port open]) {
            [serialPortTextField setEnabled:NO];
            [serialInputTextField setEnabled:NO];
            [sender setTitle:@"Disconnect"];
        }
        
    }
    else {
        [port close];
        [serialStatus setTextColor:[NSColor blackColor]];
        [sender setTitle:@"Connect"];
        [serialPortTextField setEnabled:YES];
        [serialInputTextField setEnabled:YES];
    }
}

- (IBAction)send:(id)sender {
    if (sending) {
        //Stop sending data

        [udpStatus setStringValue:@"Stopped sending data"];
        [udpStatus setTextColor:[NSColor blackColor]];
        sending = false;
        
        [udpAddressTextField setEnabled:YES];
        [udpPortTextField setEnabled:YES];
        [sender setTitle:@"Start Sending"];
    }
    else {
        //Start sending data
        
        NSString *udpHost = [udpAddressTextField stringValue];
        if ([udpHost length] == 0) {
            [udpStatus setStringValue:@"Address required"];
            [udpStatus setTextColor:[NSColor redColor]];
            return;
        }
        
        int udpPort = [udpPortTextField intValue];
        if (udpPort <= 0 || udpPort > 65535) {
            [udpStatus setStringValue:@"Valid port required"];
            [udpStatus setTextColor:[NSColor redColor]]; 
            return;
        }
        
        sending = true;
		
        [udpAddressTextField setEnabled:NO];
		[udpPortTextField setEnabled:NO];
		[sender setTitle:@"Stop Sending"];
    }
}

@end

extern "C"
{
  bool sendUDP(const char* address, int port, const char* data)
  {
    int s;
    int ret;
    struct sockaddr_in addr;
    
    addr.sin_family = AF_INET;
    ret = inet_aton(address, &addr.sin_addr);
    if (ret == 0) { return false; }
    addr.sin_port = htons(port);
    
    s = socket(PF_INET, SOCK_DGRAM, 0);
    if (s == -1) { return false; }
    
    ret = sendto(s, data, strlen(data), 0, (struct sockaddr *)&addr, sizeof(addr));
    if (ret == -1) { return false; }
    
    return true;
  }
}
