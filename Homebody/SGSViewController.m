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

// This ID can be anything, it is used only to identify the region the app creates
#define PURPLE_REGION_ID @"com.saygoodnight.homebody.purple.region"
#define LIGHTBLUE_REGION_ID @"com.saygoodnight.homebody.lightblue.region"

// These are the major/minor numbers for my purple Estimote.  This lets me only setup a region around one of
// my Estimotes.  These numbers are editable by using the Estimote Editor app.
#define PURPLE_MAJOR 15204
#define PURPLE_MINOR 7327

#define LIGHTBLUE_MAJOR 2747
#define LIGHTBLUE_MINOR 25868

@interface SGSViewController () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (strong, nonatomic) NSDate *timeEnteredMultiRegionLocation;
@property (strong, nonatomic) NSDate *timeExitedMultiRegionLocation;

@property (weak, nonatomic) IBOutlet UILabel *purpleProximityLabel;
@property (weak, nonatomic) IBOutlet UILabel *lightBlueProximityLabel;
@property (weak, nonatomic) IBOutlet UILabel *lightGreenProximityLabel;

@property (strong, nonatomic) NSMutableDictionary *regionsAtThisLocation;
@property (strong, nonatomic) NSMutableDictionary *labelsForRegions;
@end

@implementation SGSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    // Initialize text values;
    self.purpleProximityLabel.text = @"Unused";
    self.lightBlueProximityLabel.text = @"Unused";
    self.lightGreenProximityLabel.text = @"Unused";
    
    //TODO: make a SGSMultiRegionController that gives callbacks on entry/exit of a location monitored by a variable number of regions
    [self setupRegionWithUUIDString:ESTIMOTE_UUID
                          withMajor:PURPLE_MAJOR
                          withMinor:PURPLE_MINOR
                     withIdentifier:PURPLE_REGION_ID];

    [self setupRegionWithUUIDString:ESTIMOTE_UUID
                          withMajor:LIGHTBLUE_MAJOR
                          withMinor:LIGHTBLUE_MINOR
                     withIdentifier:LIGHTBLUE_REGION_ID];
    
    
    self.regionsAtThisLocation = @{
                                   PURPLE_REGION_ID: @(CLRegionStateUnknown),
                                   LIGHTBLUE_REGION_ID: @(CLRegionStateUnknown)
                                   }.mutableCopy;
    
    self.labelsForRegions = @{PURPLE_REGION_ID: self.purpleProximityLabel,
                              LIGHTBLUE_REGION_ID: self.lightBlueProximityLabel
                              }.mutableCopy;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupRegionWithUUIDString:(NSString*) uuidString
                        withMajor:(CLBeaconMajorValue) major
                        withMinor:(CLBeaconMinorValue) minor
                   withIdentifier:(NSString*) identifier {
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                           major:major
                                                                           minor:minor
                                                                      identifier:identifier];
    region.notifyOnEntry = YES;
    region.notifyOnExit = YES;
    region.notifyEntryStateOnDisplay = YES;
    
    UILabel* label = self.labelsForRegions[identifier];
    label.text = [self stringForProximity:CLProximityUnknown];
    [self.locationManager startMonitoringForRegion:region];
    [self.locationManager requestStateForRegion:region];
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

- (void)enteredMultiRegionLocation {
    self.timeEnteredMultiRegionLocation = [NSDate date];
}

- (void)exitedMultiRegionLocation {
    self.timeExitedMultiRegionLocation = [NSDate date];
    
}

- (void) updateMultiRegionStatus {
    BOOL outsideMultiRegion = YES;
    
    for (NSString* identifier in self.regionsAtThisLocation.allKeys) {
        CLRegionState regionstate = [self.regionsAtThisLocation[identifier] integerValue];
        if ((regionstate == CLRegionStateInside) || (regionstate == CLRegionStateUnknown)){
            outsideMultiRegion = NO;
        }
    }
    
    if (outsideMultiRegion) {
        [self exitedMultiRegionLocation];
        
        if (self.timeEnteredMultiRegionLocation) {
            NSTimeInterval interval = [self.timeExitedMultiRegionLocation timeIntervalSinceDate:self.timeEnteredMultiRegionLocation];
            
            
            [self sendLocalNotificationWithMessage:[NSString stringWithFormat:@"Mins Inside Multiregion: %f", interval/60.0]];

            self.timeEnteredMultiRegionLocation = nil;
        }
    } else {
        [self enteredMultiRegionLocation];
        if (self.timeExitedMultiRegionLocation) {
            NSTimeInterval interval = [self.timeEnteredMultiRegionLocation timeIntervalSinceDate:self.timeExitedMultiRegionLocation];
            
            [self sendLocalNotificationWithMessage:[NSString stringWithFormat:@"Mins Outside Multiregion: %f", interval/60.0]];
            
            self.timeExitedMultiRegionLocation = nil;
        }
    }
}
-(BOOL) isPartOfMultiRegionLocationWithIdentifier:(NSString*) identifier {
    for (NSString* regionIdentifier in self.regionsAtThisLocation.allKeys) {
        if ([regionIdentifier isEqualToString:identifier]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
        
        if ([self isPartOfMultiRegionLocationWithIdentifier:beaconRegion.identifier]) {
            self.regionsAtThisLocation[beaconRegion.identifier] = @(state);
            
            UILabel* label = self.labelsForRegions[beaconRegion.identifier];
            if (state == CLRegionStateInside) {
                label.text = @"Inside region: Ranging...";
                CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
                [self.locationManager startRangingBeaconsInRegion:beaconRegion];
            } else {
                label.text = @"Outside region";
            }
            
            //TODO: TEST ONLY
            [self updateMultiRegionStatus];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        
        CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
        if ([self isPartOfMultiRegionLocationWithIdentifier:beaconRegion.identifier]) {
            self.regionsAtThisLocation[beaconRegion.identifier] = @(CLRegionStateInside);
            UILabel* label = self.labelsForRegions[beaconRegion.identifier];
            if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                label.text = @"Inside region";
                [self updateMultiRegionStatus];
            } else {
                [self.locationManager startRangingBeaconsInRegion:beaconRegion];
                label.text = @"Inside region: Ranging...";
                [self updateMultiRegionStatus];
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        
        CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
        if ([self isPartOfMultiRegionLocationWithIdentifier:beaconRegion.identifier]) {
            self.regionsAtThisLocation[beaconRegion.identifier] = @(CLRegionStateOutside);
            UILabel* label = self.labelsForRegions[beaconRegion.identifier];
            if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                label.text = @"Outside region";
                [self updateMultiRegionStatus];
            } else {
                [self.locationManager stopRangingBeaconsInRegion:beaconRegion];
                label.text = @"Outside region";
                [self updateMultiRegionStatus];
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    for (CLBeacon *beacon in beacons) {
        if ([self isPartOfMultiRegionLocationWithIdentifier:region.identifier]) {
            UILabel* label = self.labelsForRegions[region.identifier];
            label.text = [self stringForProximity:beacon.proximity];
        }
    }
}

@end
