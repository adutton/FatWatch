//
//  GraphDrawingOperation.h
//  EatWatch
//
//  Created by Benjamin Ragheb on 9/4/08.
//  Copyright 2008 Benjamin Ragheb. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EWDate.h"


@class EWDatabase;


typedef struct {
	float minWeight;
	float maxWeight;
	float scaleX;
	float scaleY;
	float gridMinWeight;
	float gridIncrement;
	CGAffineTransform t;
	NSArray *regions;
	EWMonthDay mdEarliest;
	EWMonthDay mdLatest;
	BOOL shouldDrawNoDataWarning;
	BOOL showFatWeight;
} GraphViewParameters;


typedef struct {
	CGPoint scale;
	CGPoint trend;
} GraphPoint;


typedef struct {
	CGFloat x;
	unsigned char bits;
} FlagPoint;


#define kDayWidth 8.0f


@interface GraphDrawingOperation : NSOperation {
	id delegate;
	int index;
	EWDatabase *database;
	EWMonthDay beginMonthDay;
	EWMonthDay endMonthDay;
	GraphViewParameters *p;
	CGRect bounds;
	CGFloat scale;
	CGImageRef imageRef;
	NSMutableData *pointData;
	NSMutableData *flagData;
	NSUInteger dayCount;
	CGPoint headPoint;
	CGPoint tailPoint;
	BOOL showGoalLine;
	BOOL showTrajectoryLine;
	BOOL showFatWeight;
}
+ (void)prepareGraphViewInfo:(GraphViewParameters *)gp forSize:(CGSize)size numberOfDays:(NSUInteger)numberOfDays database:(EWDatabase *)db;
@property (nonatomic,retain) EWDatabase *database;
@property (nonatomic) EWMonthDay beginMonthDay;
@property (nonatomic) EWMonthDay endMonthDay;
@property (nonatomic,assign) id delegate;
@property (nonatomic) int index;
@property (nonatomic) GraphViewParameters *p;
@property (nonatomic) CGRect bounds;
@property (nonatomic) BOOL showGoalLine;
@property (nonatomic) BOOL showTrajectoryLine;
@property (nonatomic,readonly) CGImageRef imageRef;
+ (void)flushQueue;
- (void)enqueue;
@end


@interface NSObject (GraphDrawingOperationDelegate)
- (void)drawingOperationComplete:(GraphDrawingOperation *)operation;
@end


#if TARGET_IPHONE_SIMULATOR
// 3.0 CFVersion 478.470000
// 3.1 CFVersion 478.520000
#define BugFixRetainImageDataProvider(img) \
	if (kCFCoreFoundationVersionNumber == 478.47) { \
		CGDataProviderRef dp = CGImageGetDataProvider(img); \
		if (dp) CFRetain(dp); \
	}
#else
#define BugFixRetainImageDataProvider(img)
#endif
