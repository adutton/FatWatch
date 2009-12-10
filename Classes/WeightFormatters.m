//
//  WeightFormatters.m
//  EatWatch
//
//  Created by Benjamin Ragheb on 7/26/08.
//  Copyright 2008 Benjamin Ragheb. All rights reserved.
//

#import "WeightFormatters.h"
#import "EWGoal.h"
#import "BRMixedNumberFormatter.h"
#import "BRRangeColorFormatter.h"


typedef enum {
	kWeightUnitPounds = 1,
	kWeightUnitKilograms = 2,
	kWeightUnitStones = 3,
} EWWeightUnit;

typedef enum {
	kEnergyUnitCalories = 1,
	kEnergyUnitKilojoules = 2
} EWEnergyUnit;


static const float kKilogramsPerPound = 0.45359237f;
static const float kCaloriesPerPound = 3500;
static const float kKilojoulesPerPound = 7716 / 0.45359237f;


static NSString *kWeightUnitKey = @"WeightUnit";
static NSString *kEnergyUnitKey = @"EnergyUnit";
static NSString *kScaleIncrementKey = @"ScaleIncrement";


static const float kDefaultScaleIncrements[] = { 0.1, 0.5, 1.0 };
static const NSUInteger kDefaultScaleIncrementsCount = 3;


@interface StoneChartFormatter : NSFormatter {
}
@end



@implementation WeightFormatters


#pragma mark Colors


+ (UIColor *)goodColor {
	return [UIColor colorWithRed:0 green:0.8 blue:0 alpha:1];
}


+ (UIColor *)warningColor {
	return [UIColor colorWithRed:0.6 green:0.6 blue:0 alpha:1];
}


+ (UIColor *)badColor {
	return [UIColor colorWithRed:0.8 green:0 blue:0 alpha:1];
}


#pragma mark Setting Defaults


+ (NSArray *)weightUnitNames {
	NSString *pounds = NSLocalizedString(@"Pounds (lb)", @"Pound unit name");
	NSString *kilograms = NSLocalizedString(@"Kilograms (kg)", @"Kilogram unit name");
	NSString *stones = NSLocalizedString(@"Stones (st lb)", @"Stone unit name");
	return [NSArray arrayWithObjects:pounds, kilograms, stones, nil];
}


+ (NSUInteger)selectedWeightUnitIndex {
	return [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey] - 1;
}


+ (void)setSelectedWeightUnitIndex:(NSUInteger)index {
	EWWeightUnit weightUnit = index + 1;
	[[NSUserDefaults standardUserDefaults] setInteger:weightUnit forKey:kWeightUnitKey];
}


+ (NSArray *)energyUnitNames {
	NSString *calories = NSLocalizedString(@"Calories (cal)", @"Calorie unit name");
	NSString *kilojoules = NSLocalizedString(@"Kilojoules (kJ)", @"Kilojoule unit name");
	return [NSArray arrayWithObjects:calories, kilojoules, nil];
}


+ (NSUInteger)selectedEnergyUnitIndex {
	return [[NSUserDefaults standardUserDefaults] integerForKey:kEnergyUnitKey] - 1;
}


+ (void)setSelectedEnergyUnitIndex:(NSUInteger)index {
	EWEnergyUnit energyUnit = index + 1;
	[[NSUserDefaults standardUserDefaults] setInteger:energyUnit forKey:kEnergyUnitKey];
}


+ (NSArray *)scaleIncrementNames {
	NSString *incrementNames[kDefaultScaleIncrementsCount];
	int i;
	
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	[formatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[formatter setMinimumFractionDigits:1];
	for (i = 0; i < kDefaultScaleIncrementsCount; i++) {
		NSNumber *n = [NSNumber numberWithFloat:kDefaultScaleIncrements[i]];
		incrementNames[i] = [formatter stringFromNumber:n];
	}
	[formatter release];
	
	return [NSArray arrayWithObjects:incrementNames count:kDefaultScaleIncrementsCount];
}


+ (NSUInteger)selectedScaleIncrementIndex {
	float increment = [[NSUserDefaults standardUserDefaults] floatForKey:kScaleIncrementKey];
	int i;
	for (i = 0; i < kDefaultScaleIncrementsCount; i++) {
		if (kDefaultScaleIncrements[i] == increment) return i;
	}
	return 0;
}


+ (void)setSelectedScaleIncrementIndex:(NSUInteger)index {
	NSAssert(index >= 0 && index < kDefaultScaleIncrementsCount, @"index out of range");
	float increment = kDefaultScaleIncrements[index];
	[[NSUserDefaults standardUserDefaults] setFloat:increment forKey:kScaleIncrementKey];
}


#pragma mark Retrieving Defaults


+ (NSUInteger)fractionDigits {
	float inc = [[NSUserDefaults standardUserDefaults] floatForKey:kScaleIncrementKey];
	return ceilf(-log10f(inc));
}


+ (float)scaleIncrement {
	static float increment = 0;
	
	if (increment == 0) {
		NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
		float incrementLbs = [defs floatForKey:kScaleIncrementKey];
		EWWeightUnit unit = [defs integerForKey:kWeightUnitKey];
		if (unit == kWeightUnitKilograms) {
			increment = incrementLbs / kKilogramsPerPound;
		} else {
			increment = incrementLbs;
		}
	}
	
	return increment;
}


+ (float)goalWeightIncrement {
	static float increment = 0;
	
	if (increment == 0) {
		NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
		EWWeightUnit unit = [defs integerForKey:kWeightUnitKey];
		if (unit == kWeightUnitKilograms) {
			increment = 1.0f / kKilogramsPerPound;
		} else {
			increment = 1.0f;
		}
	}
	
	return increment;
}


+ (float)defaultWeightChange {
	EWWeightUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
	if (unit == kWeightUnitKilograms) {
		return -(0.5 / 7.0) / kKilogramsPerPound; // 0.5 kg/wk
	} else {
		return -1.0 / 7.0; // 1 lb a week
	}
}


+ (NSFormatter *)weightFormatter {
	static NSFormatter *formatter = nil;
	
	if (formatter == nil) {
		EWWeightUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
		if (unit == kWeightUnitStones) {
			NSUInteger d = [self fractionDigits];
			formatter = [BRMixedNumberFormatter poundsAsStonesFormatterWithFractionDigits:d];
			[formatter retain];
		} else {
			NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
			
			[nf setMinimumIntegerDigits:1];
			[nf setMinimumFractionDigits:[self fractionDigits]];
			[nf setMaximumFractionDigits:[self fractionDigits]];
			
			if (unit == kWeightUnitPounds) {
				[nf setPositiveSuffix:NSLocalizedString(@"lb", @"Pound unit suffix")];
			} else {
				[nf setPositiveSuffix:NSLocalizedString(@"kg", @"Kilogram unit suffix")];
				[nf setMultiplier:[NSNumber numberWithFloat:kKilogramsPerPound]];
			}
			formatter = nf;
		}
	}
	
	return formatter;
}


+ (NSFormatter *)goalWeightFormatter {
	static NSFormatter *formatter = nil;
	
	if (formatter == nil) {
		EWWeightUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
		if (unit == kWeightUnitStones) {
			formatter = [BRMixedNumberFormatter poundsAsStonesFormatterWithFractionDigits:0];
			[formatter retain];
		} else {
			NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
			
			[nf setMinimumIntegerDigits:1];

			if (unit == kWeightUnitPounds) {
				[nf setPositiveSuffix:NSLocalizedString(@"lb", @"Pound unit suffix")];
			} else {
				[nf setPositiveSuffix:NSLocalizedString(@"kg", @"Kilogram unit suffix")];
				[nf setMultiplier:[NSNumber numberWithFloat:kKilogramsPerPound]];
			}
			formatter = nf;
		}
	}
	
	return formatter;
}


+ (NSString *)stringForWeight:(float)weightLbs {
	return [[self weightFormatter] stringForObjectValue:[NSNumber numberWithFloat:weightLbs]];
}


+ (NSFormatter *)varianceFormatter {
	static NSNumberFormatter *formatter;
	
	if (formatter == nil) {
		formatter = [[NSNumberFormatter alloc] init];
		[formatter setPositiveFormat:NSLocalizedString(@"+0.0;−#", @"Variance number format")];
		EWWeightUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
		if (unit == kWeightUnitKilograms) {
			[formatter setMultiplier:[NSNumber numberWithFloat:kKilogramsPerPound]];
		}
	}
	
	return formatter;
}


+ (NSString *)stringForVariance:(float)deltaLbs {
	return [[self varianceFormatter] stringForObjectValue:[NSNumber numberWithFloat:deltaLbs]];
}


+ (NSFormatter *)energyChangePerDayFormatter {
	static NSNumberFormatter *formatter;
	
	if (formatter == nil) {
		formatter = [[NSNumberFormatter alloc] init];
		EWEnergyUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kEnergyUnitKey];
		if (unit == kEnergyUnitCalories) {
			[formatter setPositiveFormat:NSLocalizedString(@"+#,##0 cal/day (overeating);−# cal/day (undereating)", @"Calories/day format")];
			[formatter setMultiplier:[NSNumber numberWithFloat:kCaloriesPerPound]];
		} else {
			[formatter setPositiveFormat:NSLocalizedString(@"+#,##0 kJ/day (overeating);−# kJ/day (undereating)", @"Kilojoules/day format")];
			[formatter setMultiplier:[NSNumber numberWithFloat:kKilojoulesPerPound]];
		}
	}
	
	return formatter;
}


+ (NSString *)energyStringForWeightPerDay:(float)lbsPerDay {
	return [[self energyChangePerDayFormatter] stringForObjectValue:[NSNumber numberWithFloat:lbsPerDay]];
}


+ (float)energyChangePerDayIncrement {
	EWEnergyUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kEnergyUnitKey];
	if (unit == kEnergyUnitCalories) {
		return 10.0 / kCaloriesPerPound; // 10 cal/day
	} else {
		return 50.0 / kKilojoulesPerPound; // 40 kJ/day
	}
}


+ (NSFormatter *)weightChangePerWeekFormatter {
	static NSNumberFormatter *formatter;
	
	if (formatter == nil) {
		formatter = [[NSNumberFormatter alloc] init];
		EWWeightUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
		if (unit == kWeightUnitKilograms) {
			[formatter setPositiveFormat:NSLocalizedString(@"+#,##0.00 kgs/week;−# kgs/week", @"Kilogram/week format")];
			[formatter setMultiplier:[NSNumber numberWithFloat:7.0f * kKilogramsPerPound]];
		} else {
			[formatter setPositiveFormat:NSLocalizedString(@"+#,##0.00 lbs/week;−# lbs/week", @"Pounds/week format")];
			[formatter setMultiplier:[NSNumber numberWithFloat:7.0f]];
		}
	}
	
	return formatter;
}


+ (NSString *)weightStringForWeightPerDay:(float)lbsPerDay {
	return [[self weightChangePerWeekFormatter] stringForObjectValue:[NSNumber numberWithFloat:lbsPerDay]];
}


+ (float)weightChangePerWeekIncrement {
	EWWeightUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
	if (unit == kWeightUnitKilograms) {
		return 0.01 / kKilogramsPerPound / 7.0; // 0.01 kgs/week / 7 day/week / X kg/lb
	} else {
		return 0.05 / 7.0; // 0.05 lbs/week / 7 days/week
	}
}


+ (NSNumberFormatter *)exportWeightFormatter {
	EWWeightUnit weightUnit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
	
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	[formatter setNumberStyle:NSNumberFormatterDecimalStyle];
	switch (weightUnit) {
		case kWeightUnitKilograms:
			[formatter setMultiplier:[NSNumber numberWithFloat:kKilogramsPerPound]];
			break;
	}
	return [formatter autorelease];
}


+ (NSNumberFormatter *)chartWeightFormatter {
	EWWeightUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
	if (unit == kWeightUnitStones) {
		return [[[StoneChartFormatter alloc] init] autorelease];
	} 
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	if (unit == kWeightUnitKilograms) {
		[formatter setMultiplier:[NSNumber numberWithFloat:kKilogramsPerPound]];
	}
	return [formatter autorelease];
}


+ (float)chartWeightIncrement {
	return [WeightFormatters goalWeightIncrement];
}


+ (float)chartWeightIncrementAfter:(float)previousIncrement {
	EWWeightUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
	if (unit == kWeightUnitKilograms) {
		return previousIncrement + (1 / kKilogramsPerPound);
	}
	if (unit == kWeightUnitStones) {
		if (previousIncrement == 1) {
			return 7;
		} else {
			return previousIncrement + 7;
		}
	}
	// kWeightUnitPounds
	if (previousIncrement == 1) {
		return 5;
	} else {
		return previousIncrement + 5;
	}
}


+ (float)bodyMassIndexForWeight:(float)weight {
	float meters = [EWGoal height];
	if (meters > 0) {
		return (weight * kKilogramsPerPound) / (meters * meters);
	} else {
		return 0;
	}
}


+ (float)weightForBodyMassIndex:(float)bmi {
	float meters = [EWGoal height];
	return (bmi * (meters * meters)) / kKilogramsPerPound;
}


+ (UIColor *)colorForBodyMassIndex:(float)BMI {
	if (BMI < 18.5f) return [UIColor blueColor]; // Underweight
	if (BMI < 25.0f) return [WeightFormatters goodColor]; // Normal
	if (BMI < 30.0f) return [WeightFormatters warningColor]; // Overweight
	return [WeightFormatters badColor]; // Obese
}


+ (UIColor *)backgroundColorForWeight:(float)weight {
	if ([EWGoal isBMIEnabled]) {
		float BMI = [self bodyMassIndexForWeight:weight];
		if (BMI > 0) {
			UIColor *color = [self colorForBodyMassIndex:BMI];
			return [color colorWithAlphaComponent:0.4f];
		}
	}
	return [UIColor clearColor];
}


+ (NSFormatter *)heightFormatter {
	EWWeightUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
	if (unit == kWeightUnitKilograms) {
		NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
		[nf setPositiveFormat:@"0.00 m"];
		return [nf autorelease];
	} else {
		return [BRMixedNumberFormatter metersAsFeetFormatter];
	}
}


+ (float)heightIncrement {
	EWWeightUnit unit = [[NSUserDefaults standardUserDefaults] integerForKey:kWeightUnitKey];
	if (unit == kWeightUnitKilograms) {
		return 0.01;
	} else {
		return 0.0254;
	}
}


+ (NSArray *)foregroundColorPalette {
	return [NSArray arrayWithObjects:[UIColor blueColor], [WeightFormatters goodColor], [WeightFormatters warningColor], [WeightFormatters badColor], nil];
}


+ (NSArray *)backgroundColorPalette {
	NSMutableArray *palette = [NSMutableArray arrayWithCapacity:4];
	for (UIColor *color in [self foregroundColorPalette]) {
		[palette addObject:[color colorWithAlphaComponent:0.4f]];
	}
	return palette;
}


+ (id <BRColorFormatter>)BMIBackgroundColorFormatter {
	float v[] = {18.5, 25, 30};
	return [[[BRRangeColorFormatter alloc] initWithColors:[self backgroundColorPalette] forValues:v] autorelease];
}


+ (id <BRColorFormatter>)weightBackgroundColorFormatter {
	float v[3];
	v[0] = [self weightForBodyMassIndex:18.5f];
	v[1] = [self weightForBodyMassIndex:25.0f];
	v[2] = [self weightForBodyMassIndex:30.0f];
	return [[[BRRangeColorFormatter alloc] initWithColors:[self backgroundColorPalette] forValues:v] autorelease];
}


@end


@implementation StoneChartFormatter

- (NSString *)stringForObjectValue:(id)anObject {
	int weightLbs = [anObject intValue];
	if (weightLbs % 14 == 0) {
		return [NSString stringWithFormat:@"%d", (weightLbs / 14)];
	} else {
		return @"";
	}
}

@end

