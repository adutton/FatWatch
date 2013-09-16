//
//  EWWiFiAccessViewController.h
//  EatWatch
//
//  Created by Benjamin Ragheb on 6/21/09.
//  Copyright 2009 Benjamin Ragheb. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MicroWebServer.h"
#import "EWImporter.h"


@class BRReachability;
@class MicroWebServer;
@class EWDatabase;


#define kEWReadyAddressTag 101
#define kEWReadyNameTag 102

@interface EWWiFiAccessViewController : UIViewController <MicroWebServerDelegate> {
	EWDatabase *database;
	UILabel *statusLabel;
	UIActivityIndicatorView *activityView;
	UIView *detailView;
	UIView *inactiveDetailView;
	UIView *activeDetailView;
	UILabel *lastImportLabel;
	UILabel *lastExportLabel;
	// Not NIB Stuff
	BRReachability *reachability;
	MicroWebServer *webServer;
	NSDictionary *webResources;
	NSMutableDictionary *exportDefaults;
	// Import State
	EWImporter *importer;
}
@property (nonatomic,strong) EWDatabase *database;
@property (nonatomic,strong) IBOutlet UILabel *statusLabel;
@property (nonatomic,strong) IBOutlet UIActivityIndicatorView *activityView;
@property (nonatomic,strong) IBOutlet UIView *detailView;
@property (nonatomic,strong) IBOutlet UIView *inactiveDetailView;
@property (nonatomic,strong) IBOutlet UIView *activeDetailView;
@property (nonatomic,strong) IBOutlet UILabel *lastImportLabel;
@property (nonatomic,strong) IBOutlet UILabel *lastExportLabel;
@end
