/*
 * GoalViewController.m
 * Created by Benjamin Ragheb on 7/26/08.
 * Copyright 2015 Heroic Software Inc
 *
 * This file is part of FatWatch.
 *
 * FatWatch is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FatWatch is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with FatWatch.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "BRColorPalette.h"
#import "BRRangeColorFormatter.h"
#import "BRTableButtonRow.h"
#import "BRTableDatePickerRow.h"
#import "BRTableNumberPickerRow.h"
#import "BRTableValueRow.h"
#import "EWDBMonth.h"
#import "EWDatabase.h"
#import "EWDate.h"
#import "EWGoal.h"
#import "EWWeightChangeFormatter.h"
#import "EWWeightFormatter.h"
#import "GoalViewController.h"
#import "NSUserDefaults+EWAdditions.h"


/*Goal screen:
 
 Start
 Date: [pick] [default: first day of data]
 Weight: [retrieved from log]
 
 Goal:
 Date: [pick] [default: computed from others]
 Weight: [pick] [default: -10 lbs]
 
 Plan:
 Energy: [pick] cal/day [default -500]
 Weight: [pick] lbs/week [default -1]
 
 Progress:
 Energy: cal/day (actual from start date to today)
 Weight: lbs/week (actual from start date to today)
 "X days to go"
 "X lbs to go"
 
 Clear Goal (button) [are you sure? prompt]
 
 
 change Start Date, update Goal Date
 change Goal Date, update Plan *
 change Goal Weight, update Goal Date
 change Plan *, update Goal Date
 
 Initially display only a "Set Goal" button, when pressed, display whole form with defaults.
 
 */


@interface EWRatePickerRow : BRTableNumberPickerRow
{
}
@end


@implementation EWRatePickerRow
- (void)didSelect {
	if ([self.value floatValue] < 0) {
		self.minimumValue = -1000 * self.increment;
		self.maximumValue = -self.increment;
	} else {
		self.minimumValue = self.increment;
		self.maximumValue = 1000 * self.increment;
	}
	[super didSelect];
}
@end


@implementation GoalViewController
{
	EWDatabase *database;
	EWGoal *goal;
	BOOL isSetupForGoal, isSetupForBMI;
	BOOL needsReload;
}

@synthesize database;


- (NSNumberFormatter *)makeBMIFormatter {
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	[formatter setPositiveFormat:NSLocalizedString(@"BMI 0.0", @"BMI format")];
	return formatter;
}


- (void)addGoalSection {
	BRTableSection *section = [self addNewSection];
	section.headerTitle = NSLocalizedString(@"Goal", @"Goal end section title");
	
	BRTableNumberPickerRow *weightRow = [[BRTableNumberPickerRow alloc] init];
	weightRow.title = NSLocalizedString(@"Goal Weight", @"Goal end weight");
	weightRow.valueDescription = NSLocalizedString(@"To attain your goal, you must maintain your weight so that the trend line stays close to the weight you select.", @"Goal weight description");
	weightRow.object = goal;
	weightRow.key = @"endWeightNumber";
	weightRow.formatter = [EWWeightFormatter weightFormatterWithStyle:EWWeightFormatterStyleWhole];
	weightRow.increment = [[NSUserDefaults standardUserDefaults] weightWholeIncrement];
	weightRow.minimumValue = 10;
	weightRow.maximumValue = 500;
	weightRow.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	float weight = [database latestWeight];
	if (weight == 0) weight = 150;
	weightRow.defaultValue = @(weight);
	
	[section addRow:weightRow animated:NO];
	
	if ([[NSUserDefaults standardUserDefaults] isBMIEnabled]) {
		float w[3];
		[EWWeightFormatter getBMIWeights:w];
		BRColorPalette *palette = [BRColorPalette sharedPalette];
		NSArray *colorArray = @[[[palette colorNamed:@"BMIUnderweight"] colorWithAlphaComponent:0.4f],
							   [[palette colorNamed:@"BMINormal"] colorWithAlphaComponent:0.4f],
							   [[palette colorNamed:@"BMIOverweight"] colorWithAlphaComponent:0.4f],
							   [[palette colorNamed:@"BMIObese"] colorWithAlphaComponent:0.4f]];
		BRRangeColorFormatter *colorFormatter = [[BRRangeColorFormatter alloc] initWithColors:colorArray forValues:w];
		weightRow.backgroundColorFormatter = colorFormatter;

		NSNumberFormatter *bmiFormatter = [EWWeightFormatter weightFormatterWithStyle:EWWeightFormatterStyleBMILabeled];
		const float bmiMultiplier = [[bmiFormatter multiplier] floatValue];

		BRTableNumberPickerRow *bmiRow = [[BRTableNumberPickerRow alloc] init];
		bmiRow.title = NSLocalizedString(@"Goal BMI", @"Goal end BMI");
		bmiRow.valueDescription = NSLocalizedString(@"Remember that BMI only compares height and weight and does not take individual body composition into account.", @"Goal BMI description");
		bmiRow.object = weightRow.object;
		bmiRow.key = weightRow.key;
		bmiRow.minimumValue = weightRow.minimumValue / bmiMultiplier;
		bmiRow.maximumValue = weightRow.maximumValue / bmiMultiplier;
		bmiRow.formatter = bmiFormatter;
		bmiRow.increment = 0.1f / bmiMultiplier;
		bmiRow.backgroundColorFormatter = weightRow.backgroundColorFormatter;
		bmiRow.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		bmiRow.defaultValue = weightRow.defaultValue;
		[section addRow:bmiRow animated:NO];
	}
}


- (void)addPlanSection {
	BRTableSection *planSection = [self addNewSection];
	planSection.headerTitle = NSLocalizedString(@"Plan", @"Goal plan section title");
	planSection.footerTitle = NSLocalizedString(@"Unlocked values are updated as your weight changes. Edit a value to lock it.", @"Goal plan section footer");
	
	BRTableDatePickerRow *dateRow = [[BRTableDatePickerRow alloc] init];
	dateRow.title = NSLocalizedString(@"Goal Date", @"Goal end date");
	dateRow.valueDescription = NSLocalizedString(@"Select the date you want to reach your goal by.\n\nThe energy and weight rates will be updated to match.", @"Goal end date description");
	dateRow.object = goal;
	dateRow.key = @"endDate";
	dateRow.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	dateRow.minimumDate = EWDateFromMonthDay(EWMonthDayNext(EWMonthDayToday()));
	[planSection addRow:dateRow animated:NO];

	BRTableNumberPickerRow *energyRow = [[EWRatePickerRow alloc] init];
	energyRow.title = NSLocalizedString(@"Energy Plan", @"Goal plan energy");
	energyRow.valueDescription = NSLocalizedString(@"Select the daily energy deficit or surplus you plan to keep.\n\nThe goal date and weight rate will be updated to match.", @"Goal plan energy description");
	energyRow.object = goal;
	energyRow.key = @"weightChangePerDay";
	energyRow.formatter = [[EWWeightChangeFormatter alloc] initWithStyle:EWWeightChangeFormatterStyleEnergyPerDay];
	energyRow.increment = [EWWeightChangeFormatter energyChangePerDayIncrement];
	energyRow.minimumValue = -1000 * energyRow.increment;
	energyRow.maximumValue = 1000 * energyRow.increment;
	energyRow.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	[planSection addRow:energyRow animated:NO];
	
	BRTableNumberPickerRow *weightRow = [[EWRatePickerRow alloc] init];
	weightRow.title = NSLocalizedString(@"Weight Plan", @"Goal plan weight");
	weightRow.valueDescription = NSLocalizedString(@"Select the weekly weight loss or gain you want to keep.\n\nThe goal date and energy rate will be updated to match.", @"Goal plan weight description");
	weightRow.object = goal;
	weightRow.key = @"weightChangePerDay";
	weightRow.formatter = [[EWWeightChangeFormatter alloc] initWithStyle:EWWeightChangeFormatterStyleWeightPerWeek];
	weightRow.increment = [EWWeightChangeFormatter weightChangePerWeekIncrement];
	weightRow.minimumValue = -1000 * weightRow.increment;
	weightRow.maximumValue = 1000 * weightRow.increment;
	weightRow.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	[planSection addRow:weightRow animated:NO];
}


- (void)databaseDidChange:(NSNotification *)notification {
	needsReload = YES;
}


#pragma mark View Crap


- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(databaseDidChange:) name:EWDatabaseDidChangeNotification object:nil];
	self.tableView.scrollEnabled = NO;
}


- (void)updateTableSections {
	// no goal set: 1 sections (goal)
	// goal set: 2 sections (goal, plan)
	
	NSAssert(goal, @"goal not initialized");

	BOOL goalDefined = [goal isDefined];
	BOOL bmiEnabled = [[NSUserDefaults standardUserDefaults] isBMIEnabled];
	BOOL needsUpdate = ((goalDefined != isSetupForGoal) || 
						(bmiEnabled != isSetupForBMI) ||
						[self numberOfSections] < 1);
	
	if (needsUpdate) {
		[self removeAllSections];
		[self addGoalSection];
		if (goalDefined) {
			[self addPlanSection];
		}
		needsReload = YES;
		isSetupForGoal = goalDefined;
		isSetupForBMI = bmiEnabled;
	}
	
	self.navigationItem.leftBarButtonItem.enabled = goalDefined;
	
	if (needsReload) {
		[self.tableView reloadData];
		needsReload = NO;
	}
}


- (void)viewWillAppear:(BOOL)animated {
	if (goal == nil) {
		NSAssert(database, @"no database set!");
		goal = [[EWGoal alloc] initWithDatabase:database];
	}
	
	[self updateTableSections];
	
	if ([self numberOfSections] >= 2) {
		BRTableSection *planSection = [self sectionAtIndex:1];
		BRTableRow *dateRow = [planSection rowAtIndex:0];
		BRTableRow *rateRow1 = [planSection rowAtIndex:1];
		BRTableRow *rateRow2 = [planSection rowAtIndex:2];
		UIImage *lock0Image = [UIImage imageNamed:@"Lock0"];
		UIImage *lock1Image = [UIImage imageNamed:@"Lock1"];
		switch ([goal state]) {
			case EWGoalStateFixedDate:
				dateRow.image = lock1Image;
				rateRow1.image = lock0Image;
				rateRow2.image = lock0Image;
				break;
			case EWGoalStateFixedRate:
				dateRow.image = lock0Image;
				rateRow1.image = lock1Image;
				rateRow2.image = lock1Image;
			default:
				break;
		}
		[dateRow configureCell:[dateRow cell]];
		[rateRow1 configureCell:[rateRow1 cell]];
		[rateRow2 configureCell:[rateRow2 cell]];
	}
}


- (void)viewDidAppear:(BOOL)animated {
	for (UITableViewCell *cell in [self.tableView visibleCells]) {
		[cell setHighlighted:NO animated:animated];
	}
}


#pragma mark Clearing


- (IBAction)clearGoal:(id)sender {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	sheet.destructiveButtonIndex = 
	[sheet addButtonWithTitle:NSLocalizedString(@"Clear Goal", @"Clear goal button")];
	
	sheet.cancelButtonIndex =
	[sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button")];

	[sheet showInView:self.view.window];
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == actionSheet.destructiveButtonIndex) {
		[EWGoal deleteGoal];
		[self updateTableSections];
	}
}


@end
