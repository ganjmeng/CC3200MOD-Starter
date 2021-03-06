//
//  BWControlPanelViewController.m
//  BREWise
//
//  Created by Jackson Keating on 7/23/14.
//  Copyright (c) 2014 Brewise. All rights reserved.
//

#import "BWControlPanelViewController.h"
#import "BWDiscovermDNS.h"
#import <sys/socket.h>


@interface BWControlPanelViewController () <UITextFieldDelegate, NSStreamDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@property (nonatomic, weak) IBOutlet UITextField *getTemperatureText;
@property (nonatomic, weak) IBOutlet UITextField *setTemperatureText;
@property (nonatomic, weak) IBOutlet UIButton *getTemperatureButton;
@property (nonatomic, weak) IBOutlet UIButton *setTemperatureButton;
@property (nonatomic, weak) IBOutlet UIButton *orangeButton;

@property (nonatomic, strong) NSString *setTemp;
@property (nonatomic, strong) NSString *getTemp;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSData *received;

@property (strong,atomic) BWDiscovermDNS *brewiseService;

@end

@implementation BWControlPanelViewController

@synthesize getTemperatureText;
@synthesize setTemperatureText;
@synthesize getTemperatureButton;
@synthesize setTemperatureButton;

@synthesize getTemp;
@synthesize setTemp;
@synthesize inputStream;
@synthesize outputStream;
@synthesize received;
uint8_t *buffer;
unsigned int len = 0;

@synthesize brewiseService;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.tabBarItem.title = @"Control Panel";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self findBrewiseService:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)openPort:(id)sender
{
    [self openNewPort];
}

- (IBAction)sendCommand:(id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:@"Error code whoops"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil, nil];
    [alert show];
    
    NSString *info = @"hello";
    NSData *data = [[NSData alloc] initWithData:[info dataUsingEncoding:NSASCIIStringEncoding]];
    
    [outputStream write:[data bytes] maxLength:[data length]];
    
    //[self stopReceiveWithStatus:nil];
    
}

- (IBAction)getTemperature:(id)sender
{
    if(!self.brewiseService.didFind)
    {
        [self findBrewiseService:nil];
        return;
    }
    
    if (self.brewiseService.didFind) {
        self.getTemperatureButton.enabled = NO;
        
        [self openNewPort];
        
        NSString *info = @"getTemperature\0";
        NSData *data = [[NSData alloc] initWithData:[info dataUsingEncoding:NSASCIIStringEncoding]];
        
        [outputStream write:[data bytes] maxLength:[data length]];
    }
}

- (IBAction)setTemperature:(id)sender
{
    self.setTemperatureButton.enabled = NO;
    
    [self openNewPort];
    
    NSString *info = [NSString stringWithFormat:@"setTemperature %@\0", setTemp];
    NSData *data = [[NSData alloc] initWithData:[info dataUsingEncoding:NSASCIIStringEncoding]];
    
    [outputStream write:[data bytes] maxLength:[data length]];
}

- (IBAction)orangeLED:(id)sender
{
    if([self.brewiseService didFind])
    {
        self.orangeButton.enabled = NO;
    
        [self openNewPort];
    
        NSString *info = @"orange\0";
        NSData *data = [[NSData alloc] initWithData:[info dataUsingEncoding:NSASCIIStringEncoding]];
    
        [outputStream write:[data bytes] maxLength:[data length]];
    }
    else
    {
        [self findBrewiseService:nil];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == setTemperatureText)
    {
        self.setTemp = textField.text;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

//*********************************************
//
// TCP Stream Functions
//
//*********************************************


- (void)stopReceiveWithStatus:(NSString *)statusString
{
    if (self.inputStream != nil) {
        self.inputStream.delegate = nil;
        [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.inputStream close];
        self.inputStream = nil;
    }
    if (self.outputStream != nil) {
        self.outputStream.delegate = nil;
        [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream close];
        self.outputStream = nil;
    }
}

- (void)openNewPort
{
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)[self.brewiseService ipAddress], [self.brewiseService port], &readStream, &writeStream);
    inputStream = (__bridge_transfer NSInputStream *)readStream;
    outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                           forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                            forMode:NSDefaultRunLoopMode];
    [inputStream open];
    [outputStream open];
}
/*
- (IBAction)openNewPortFromService:(id)sender
{
    NSInputStream *istream = nil;
    NSOutputStream *ostream = nil;
    
    [[services objectAtIndex:0] getInputStream:&istream outputStream:&ostream];
    
    if (istream && ostream)
    {
        NSLog(@"Success!");
        
        NSString *info = @"hello";
        NSData *data = [[NSData alloc] initWithData:[info dataUsingEncoding:NSASCIIStringEncoding]];
        
        [ostream write:[data bytes] maxLength:[data length]];
        
        [ostream close];
    }
    else
    {
        NSLog(@"Failed to acquire valid streams");
    }
}
*/
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch(eventCode) {
        case NSStreamEventOpenCompleted:
        {
            /*
            NSString *info = @"hello";
            NSData *data = [[NSData alloc] initWithData:[info dataUsingEncoding:NSASCIIStringEncoding]];
            
            [outputStream write:[data bytes] maxLength:[data length]];
             */
        }   break;
        case NSStreamEventHasSpaceAvailable:
        {
            /*
            NSString *info = @"hello";
            NSData *data = [[NSData alloc] initWithData:[info dataUsingEncoding:NSASCIIStringEncoding]];
            
            [outputStream write:[data bytes] maxLength:[data length]];
             */
        }   break;
        
        case NSStreamEventHasBytesAvailable:
        {
            NSInteger       bytesRead;
            uint8_t         buffer[1024];
            
            memset(buffer, 0, sizeof(buffer));
            
            bytesRead = [inputStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead == -1) {
                NSLog(@"What does this mean.");
            } else if (bytesRead == 0) {
                [self stopReceiveWithStatus:nil];
                NSLog(@"Closed connection successful.");
                self.getTemperatureButton.enabled = YES;
                self.setTemperatureButton.enabled = YES;
                self.orangeButton.enabled = YES;
            } else {

                [self stopReceiveWithStatus:nil];
                NSLog(@"Received Data");
                NSLog(@"Try to close the connection.");
                self.orangeButton.enabled = YES;
                self.setTemperatureButton.enabled = YES;
                if(!self.getTemperatureButton.enabled)
                {
                    
                    //getTemperatureText.text = [[NSString alloc] initWithCString:buffer
                    //                                                   encoding:NSASCIIStringEncoding];
                    getTemperatureText.text = [NSString stringWithFormat:@"%d", *buffer];
                    self.getTemperatureButton.enabled = YES;
                }
            }
            
        }   break;
            
        case NSStreamEventEndEncountered:
        {
            [self stopReceiveWithStatus:nil];
        }   break;
            
        case NSStreamEventErrorOccurred:
        {
            //NSError *theError = [aStream streamError];
            /*UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"The service did not connect."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil, nil];
            [alert show];*/
            
            [self stopReceiveWithStatus:nil];
            
            [self findBrewiseService:nil];
            
            if(!self.getTemperatureButton.enabled)
            {
                self.getTemperatureButton.enabled = YES;
            }
            else if(!self.setTemperatureButton.enabled)
            {
                self.setTemperatureButton.enabled = YES;
            }
            else if(!self.orangeButton.enabled)
            {
                self.orangeButton.enabled = YES;
            }
            
            
        }   break;
        
        case NSStreamEventNone:
        {
            
        }   break;
    }
}

- (IBAction)findBrewiseService:(id)sender
{
    if (!self.brewiseService) {
        self.brewiseService = [[BWDiscovermDNS alloc] init];
    }
    [self.brewiseService findBrewiseService];
}

@end