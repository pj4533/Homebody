//
//  SGSViewController.m
//  Homebody
//
//  Created by PJ Gray on 11/24/13.
//  Copyright (c) 2013 Say Goodnight Software. All rights reserved.
//

#import "SGSViewController.h"
#import <CoreLocation/CoreLocation.h>

// This is the UUID for all Estimote Beacons
#define ESTIMOTE_UUID @"B9407F30-F5F8-466E-AFF9-25556B57FE6D"

// This ID can be anything, it is used only to identify the region the app creates for the beacon
#define MY_BEACON_ID @"com.saygoodnight.homebody.region"

// These are the major/minor numbers for my purple Estimote.  This lets me only setup a region around one of
// my Estimotes.  These numbers are editable by using the Estimote Editor app.
#define PURPLE_MAJOR 15204
#define PURPLE_MINOR 7327

@interface SGSViewController () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (weak, nonatomic) IBOutlet UILabel *proximityLabel;

@end

@implementation SGSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:ESTIMOTE_UUID];
    CLBeaconRegion *purpleRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                           major:PURPLE_MAJOR
                                                                           minor:PURPLE_MINOR
                                                                      identifier:MY_BEACON_ID];
    purpleRegion.notifyOnEntry = YES;
    purpleRegion.notifyOnExit = YES;
    purpleRegion.notifyEntryStateOnDisplay = YES;
    
    [self.locationManager startMonitoringForRegion:purpleRegion];
    [self.locationManager requestStateForRegion:purpleRegion];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)sendLocalNotificationWithMessage:(NSString*) message {
    // present local notification
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = message;
    notification.soundName = UILocalNotificationDefaultSoundName;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
}

- (NSString *)stringForProximity:(CLProximity)proximity {
    switch (proximity) {
        case CLProximityUnknown:    return @"Unknown";
        case CLProximityFar:        return @"Far";
        case CLProximityNear:       return @"Near";
        case CLProximityImmediate:  return @"Immediate";
        default:
            return nil;
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
        if ([beaconRegion.identifier isEqualToString:MY_BEACON_ID]) {
            if (state == CLRegionStateInside) {
                self.proximityLabel.text = @"Inside region: Ranging...";
                CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
                [self.locationManager startRangingBeaconsInRegion:beaconRegion];
            } else {
                self.proximityLabel.text = @"Outside region";
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        
        CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
        if ([beaconRegion.identifier isEqualToString:MY_BEACON_ID]) {
            
            if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                self.proximityLabel.text = @"Inside region";
                [self sendLocalNotificationWithMessage:@"Returned @ XX:YY:ZZ"];
            } else {
                [self.locationManager startRangingBeaconsInRegion:beaconRegion];
                self.proximityLabel.text = @"Inside region: Ranging...";
            }
            
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
        if ([beaconRegion.identifier isEqualToString:MY_BEACON_ID]) {
            
            if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                self.proximityLabel.text = @"Outside region";
                [self sendLocalNotificationWithMessage:@"Left @ XX:YY:ZZ"];
            } else {
                self.proximityLabel.text = @"Outside region";
                [self.locationManager stopRangingBeaconsInRegion:beaconRegion];
            }
            
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    for (CLBeacon *beacon in beacons) {
        self.proximityLabel.text = [self stringForProximity:beacon.proximity];
    }
}

@end
