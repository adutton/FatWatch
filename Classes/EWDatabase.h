//
//  EWDatabase.h
//  EatWatch
//
//  Created by Benjamin Ragheb on 12/9/09.
//  Copyright 2009 Benjamin Ragheb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EWDate.h"
#import "EWDBMonth.h"


@class SQLiteDatabase;
@class SQLiteStatement;
@class EWDBIterator;


extern NSString * const EWDatabaseDidChangeNotification;


typedef enum {
	EWDatabaseFilterNone,
	EWDatabaseFilterWeight,
	EWDatabaseFilterWeightAndFat
} EWDatabaseFilter;


@interface EWDatabase : NSObject {
	NSString *dbPath;
	SQLiteDatabase *db;
	NSMutableDictionary *monthCache;
	NSLock *monthCacheLock;
	EWMonthDay earliestChangeMonthDay;
	EWMonth earliestMonth;
	EWMonth latestMonth;
}
@property (nonatomic,readonly) EWMonth earliestMonth;
@property (nonatomic,readonly) EWMonth latestMonth;
@property (nonatomic,readonly,getter=isEmpty) BOOL empty;
// Setup
- (id)initWithFile:(NSString *)path;
- (id)initWithSQLNamed:(NSString *)sqlName;
- (void)close;
- (void)reopen;
- (BOOL)needsUpgrade;
- (void)upgrade;
// Reading
- (float)earliestWeight;
- (float)earliestFatWeight;
- (float)latestWeight;
- (BOOL)didRecordFatBeforeMonth:(EWMonth)month;
- (EWDBMonth *)getDBMonth:(EWMonth)month;
- (void)getWeightMinimum:(float *)minWeight maximum:(float *)maxWeight onlyFat:(BOOL)onlyFat from:(EWMonthDay)beginMonthDay to:(EWMonthDay)endMonthDay;
- (void)getEarliestMonthDay:(EWMonthDay *)beginMonthDay latestMonthDay:(EWMonthDay *)endMonthDay filter:(EWDatabaseFilter)filter;
- (const EWDBDay *)getMonthDay:(EWMonthDay *)mdHead withWeightBefore:(EWMonthDay)mdStart onlyFat:(BOOL)onlyFat;
- (const EWDBDay *)getMonthDay:(EWMonthDay *)mdTail withWeightAfter:(EWMonthDay)mdStop onlyFat:(BOOL)onlyFat;
- (BOOL)hasDataForToday;
- (EWDBIterator *)iterator;
// Writing
- (void)didChangeWeightOnMonthDay:(EWMonthDay)monthday;
- (void)commitChanges;
- (void)deleteAllData;
- (SQLiteStatement *)selectMonthStatement;
- (SQLiteStatement *)insertMonthStatement;
- (SQLiteStatement *)selectDaysStatement;
- (SQLiteStatement *)insertDayStatement;
- (SQLiteStatement *)deleteDayStatement;
// Energy Equivalents
- (NSArray *)loadEnergyEquivalents;
- (void)saveEnergyEquivalents:(NSArray *)dataArray;
@end
