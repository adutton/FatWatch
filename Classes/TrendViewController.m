//
//  TrendViewController.m
//  EatWatch
//
//  Created by Benjamin Ragheb on 3/29/08.
//  Copyright 2008 Benjamin Ragheb. All rights reserved.
//

#import "TrendViewController.h"
#import "Database.h"
#import "SlopeComputer.h"
#import "MonthData.h"

#define kCaloriesPerPound 3500
#define kKilojoulesPerKilogram 7716

#define kPoundsPerKilogram 0.45359237f

#define kCaloriesPerKilogram (kCaloriesPerPound * kPoundsPerKilogram)
#define kKilojoulesPerPound (kKilojoulesPerKilogram / kPoundsPerKilogram)

@implementation TrendViewController

- (void)recompute
{
	[array removeAllObjects];

	NSString *labels[] = {@"Week", @"Fortnight", @"Month", @"Quarter", @"Six Months", @"Year"};
	int stops[] = {7, 14, 30, 90, 182, 365};
	
	EWEnergyUnit energyUnit = [[NSUserDefaults standardUserDefaults] integerForKey:@"EnergyUnit"];
	EWWeightUnit weightUnit = [database weightUnit];
	printf("energy %d; weight %d;", energyUnit, weightUnit);
	
	NSString *weightUnitAbbr = (weightUnit == kWeightUnitPounds) ? @"lbs" : @"kgs";
	NSString *energyUnitAbbr = (energyUnit == kEnergyUnitCalories) ? @"cal" : @"kJ";

	float energyPerWeight;
	if (weightUnit == kWeightUnitPounds) {
		energyPerWeight = (energyUnit == kEnergyUnitCalories) ? kCaloriesPerPound : kKilojoulesPerPound;
	} else {
		energyPerWeight = (energyUnit == kEnergyUnitCalories) ? kCaloriesPerKilogram : kKilojoulesPerKilogram;
	}
	
	SlopeComputer *computer = [[SlopeComputer alloc] init];
	EWMonth curMonth = EWMonthFromDate([NSDate date]);
	EWDay curDay = EWDayFromDate([NSDate date]);
	MonthData *data = [database dataForMonth:curMonth];
	EWMonth earliestMonth = [database earliestMonth];
	
	int i;
	float x = 0;
	for (i = 0; (i < 6) && (curMonth >= earliestMonth); i++) {
		while ((x < stops[i]) && (curMonth >= earliestMonth)) {
			float y = [data measuredWeightOnDay:curDay];
			if (y > 0) [computer addPointAtX:x y:y];
			x++;
			curDay--;
			if (curDay < 1) {
				curMonth--;
				curDay = EWDaysInMonth(curMonth);
				data = [database dataForMonth:curMonth];
			}
		}
		float weightPerDay = [computer computeSlope];
		if (! isnan(weightPerDay)) {
			[array addObject:[NSArray arrayWithObjects:
							  [NSString stringWithFormat:@"Past %@", labels[i]],
							  [NSString stringWithFormat:@"%+.2f %@/week", (7.0f * weightPerDay), weightUnitAbbr], 
							  [NSString stringWithFormat:@"%+.2f %@/day", (energyPerWeight * weightPerDay), energyUnitAbbr], 
							  nil]];
		}
	}
	[computer release];
	
	UITableView *tableView = (UITableView *)self.view;
	[tableView reloadData];
}

- (id)initWithDatabase:(Database *)db
{
	if (self = [super init]) {
		// Initialize your view controller.
		self.title = @"Trend";
		
		database = db;
		
		array = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)loadView
{
	// Create a custom view hierarchy.
	UITableView *tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStyleGrouped];
	tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
	
	tableView.delegate = self;
	tableView.dataSource = self;
	tableView.sectionIndexMinimumDisplayRowCount = NSIntegerMax;
	
	self.view = tableView;
	[tableView release];
}

- (void)viewWillAppear:(BOOL)animated
{
	[self recompute];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations.
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview.
	// Release anything that's not essential, such as cached data.
}

- (void)dealloc
{
	[array release];
	[super dealloc];
}

#pragma mark UITableViewDataSource (Required)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [array count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 2;
}

#pragma mark UITableViewDataSource (Optional)

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [[array objectAtIndex:section] objectAtIndex:0];
}

#pragma mark UITableViewDelegate (Required)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell;
	
	id availableCell = [tableView dequeueReusableCellWithIdentifier:@"Foo"];
	if (availableCell != nil) {
		cell = (UITableViewCell *)availableCell;
	} else {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"Foo"] autorelease];
	}
	
	cell.text = [[array objectAtIndex:[indexPath section]] objectAtIndex:([indexPath row] + 1)];
	return cell;
}

#pragma mark UITableViewDelegate (Optional)

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	return nil; // table is for display only, don't allow selection
}

@end
