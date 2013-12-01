//
//  SGSViewController.m
//  Homebody
//
//  Created by PJ Gray on 11/24/13.
//  Copyright (c) 2013 Say Goodnight Software. All rights reserved.
//

#import "SGSViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "AFNetworking.h"
#import "SGSAppTokens.h"

// This is the UUID for all Estimote Beacons
#define ESTIMOTE_UUID @"B9407F30-F5F8-466E-AFF9-25556B57FE6D"

// This ID can be anything, it is used only to identify the region the app creates
#define PURPLE_REGION_ID @"com.saygoodnight.homebody.purple.region"
#define LIGHTBLUE_REGION_ID @"com.saygoodnight.homebody.lightblue.region"
#define LIGHTGREEN_REGION_ID @"com.saygoodnight.homebody.lightgreen.region"

// These are the major/minor numbers for my purple Estimote.  This lets me only setup a region around one of
// my Estimotes.  These numbers are editable by using the Estimote Editor app.
#define PURPLE_MAJOR 15204
#define PURPLE_MINOR 7327

#define LIGHTBLUE_MAJOR 2747
#define LIGHTBLUE_MINOR 25868

#define LIGHTGREEN_MAJOR 18709
#define LIGHTGREEN_MINOR 26469

@interface SGSViewController () <CLLocationManagerDelegate> {
    NSTimer* _timer;
    BOOL _currentlyOutsideMultiRegion;
    BOOL _firstUpdate;
}

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (strong, nonatomic) NSDate *timeEnteredMultiRegionLocation;
@property (strong, nonatomic) NSDate *timeExitedMultiRegionLocation;

@property (weak, nonatomic) IBOutlet UILabel *purpleProximityLabel;
@property (weak, nonatomic) IBOutlet UILabel *lightBlueProximityLabel;
@property (weak, nonatomic) IBOutlet UILabel *lightGreenProximityLabel;
@property (weak, nonatomic) IBOutlet UILabel *enteredLabel;
@property (weak, nonatomic) IBOutlet UILabel *exitedLabel;

@property (strong, nonatomic) NSMutableDictionary *regionsAtThisLocation;
@property (strong, nonatomic) NSMutableDictionary *labelsForRegions;
@end

@implementation SGSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _firstUpdate = YES;
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                     target:self
                                   selector:@selector(updateUI)
                                   userInfo:nil
                                    repeats:YES];
    
    
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
    
    [self setupRegionWithUUIDString:ESTIMOTE_UUID
                          withMajor:LIGHTGREEN_MAJOR
                          withMinor:LIGHTGREEN_MINOR
                     withIdentifier:LIGHTGREEN_REGION_ID];
    
    self.regionsAtThisLocation = @{
                                   PURPLE_REGION_ID: @(CLRegionStateUnknown),
                                   LIGHTBLUE_REGION_ID: @(CLRegionStateUnknown),
                                   LIGHTGREEN_REGION_ID: @(CLRegionStateUnknown)
                                   }.mutableCopy;
    
    self.labelsForRegions = @{PURPLE_REGION_ID: self.purpleProximityLabel,
                              LIGHTBLUE_REGION_ID: self.lightBlueProximityLabel,
                              LIGHTGREEN_REGION_ID: self.lightGreenProximityLabel
                              }.mutableCopy;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) updateUI {
    if (self.timeExitedMultiRegionLocation) {
        NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:self.timeExitedMultiRegionLocation];
        self.exitedLabel.text = [NSString stringWithFormat:@"%f", interval/60.0];
    } else {
        self.exitedLabel.text = @"Inside";
    }
    if (self.timeEnteredMultiRegionLocation) {
        NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:self.timeEnteredMultiRegionLocation];
        self.enteredLabel.text = [NSString stringWithFormat:@"%f", interval/60.0];
    } else {
        self.enteredLabel.text = @"Outside";
    }

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
    
    if (_firstUpdate || (outsideMultiRegion != _currentlyOutsideMultiRegion)) {
        _firstUpdate = NO;
        if (outsideMultiRegion){
            [self exitedMultiRegionLocation];
            
            if (self.timeEnteredMultiRegionLocation) {
                NSTimeInterval interval = [self.timeExitedMultiRegionLocation timeIntervalSinceDate:self.timeEnteredMultiRegionLocation];
                
#ifdef kAPPTOKEN_STATHAT
                NSDictionary *parameters = @{
                                             @"ezkey": kAPPTOKEN_STATHAT,
                                             @"stat": @"Minutes Spent At Home",
                                             @"count": @(interval/60.0)
                                             };
                [[AFHTTPRequestOperationManager manager] POST:@"http://api.stathat.com/ez"
                                                   parameters:parameters
                                                      success:nil
                                                      failure:nil];
#endif
                
                [self sendLocalNotificationWithMessage:[NSString stringWithFormat:@"Mins Inside Multiregion: %f", interval/60.0]];
                
                self.timeEnteredMultiRegionLocation = nil;
            }
        } else {
            [self enteredMultiRegionLocation];
            if (self.timeExitedMultiRegionLocation) {
                NSTimeInterval interval = [self.timeEnteredMultiRegionLocation timeIntervalSinceDate:self.timeExitedMultiRegionLocation];
                
#ifdef kAPPTOKEN_STATHAT
                NSDictionary *parameters = @{
                                             @"ezkey": kAPPTOKEN_STATHAT,
                                             @"stat": @"Minutes Spent Away From Home",
                                             @"count": @(interval/60.0)
                                             };
                [[AFHTTPRequestOperationManager manager] POST:@"http://api.stathat.com/ez"
                                                   parameters:parameters
                                                      success:nil
                                                      failure:nil];
#endif
                
                [self sendLocalNotificationWithMessage:[NSString stringWithFormat:@"Mins Outside Multiregion: %f", interval/60.0]];
                
                self.timeExitedMultiRegionLocation = nil;
            }
        }
        _currentlyOutsideMultiRegion = outsideMultiRegion;
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
            
            //TODO: TEST ONLY - doing this leads to incorrect reported times cause it doesn't fully
            // encapsulate a time period spent at or away from the multiregion
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
