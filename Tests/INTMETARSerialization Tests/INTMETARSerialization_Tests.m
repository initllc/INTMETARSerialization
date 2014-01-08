//
//  INTMETARSerialization_Tests.m
//  INTMETARSerialization Tests
//
//  Created by Mike on 1/6/14.
//  Copyright (c) 2014 init. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "INTMETARSerialization.h"

@interface INTMETARSerialization_Tests : XCTestCase

@end

@implementation INTMETARSerialization_Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSimple
{
    NSArray *a = @[
                   @"KGFK 032253Z 18013KT 10SM OVC055 M04/M06 A2920 RMK AO2 T10441061"
                   ];
    for (NSString *s in a){
        NSError *e = nil;
        [INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
    }
}

- (void)testWindDirection
{
    NSArray *a = @[
                   @"KGFK 032253Z VRB04KT 10SM OVC055 M04/M06 A2920 RMK AO2 T10441061",
                   @"KGFK 032253Z 18004KT 10SM OVC055 M04/M06 A2920 RMK AO2 T10441061",
                   @"KGFK 032253Z 26510KT 10SM OVC055 M04/M06 A2920 RMK AO2 T10441061"
                   ];
    NSArray *ex = @[@0, @180, @265];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization *m = [INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSNumber *expected = [ex objectAtIndex:idx];
        if (expected.intValue != m.windDirection) {
            XCTFail(@"Expecting wind direction %i, found direction %ld in %@", expected.intValue, (long)m.windDirection, m.metarString);
        }
    }];
}

- (void)testVRB
{
    NSArray *a = @[
                   @"KGFK 032253Z VRB04KT 10SM OVC055 M04/M06 A2920 RMK AO2 T10441061"
                   ];
    NSArray *ex = @[@4];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization *m = [INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSNumber *expected = [ex objectAtIndex:idx];
        if (expected.intValue != m.windSpeed && !m.windVariable) {
            XCTFail(@"Expecting wind speed %i, found speed %ld in %@", expected.intValue, (long)m.windSpeed, m.metarString);
        }
    }];
}

- (void)testGust
{
    NSArray *a = @[
                   @"KGFK 032253Z 35023G29KT 10SM OVC055 M04/M06 A2920 RMK AO2 T10441061"
                   ];
    NSArray *ex = @[@29];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization *m = [INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSNumber *expected = [ex objectAtIndex:idx];
        if (expected.intValue != m.gustSpeed) {
            XCTFail(@"Expecting gust %i, found gust %ld in %@", expected.intValue, (long)m.gustSpeed, m.metarString);
        }
    }];
}

- (void)testVariableWinds
{
    NSArray *a = @[
                   @"KGFK 032253Z 35023G29KT 040V120 5SM OVC055 M04/M06 A2920 RMK AO2 T10441061"
                   ];
    NSArray *ex = @[@"040V120"];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization *m = [INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSString *expected = [ex objectAtIndex:idx];
        if (![expected isEqualToString:m.variableWindGroup]) {
            XCTFail(@"Expecting variable wind group %@, found variable wind group %@ in %@", expected, m.variableWindGroup, m.metarString);
        }
    }];
}

- (void)testRVR
{
    NSArray *a = @[
                   @"KGFK 032253Z 35023KT 040V120 R35L/4500V6000FT 6SM OVC055 M04/M06 A2920 RMK AO2 T10441061",
                   @"KGFK 032253Z 35023KT R35L/1200V2000FT R34L/4500V6000FT 10SM OVC055 M04/M06 A2920 RMK AO2 T10441061",
                   ];
    // We should really have a test that allows for checking multiple RVRs as the property is an array.
    NSArray *ex = @[@"R35L/4500V6000FT", @"R35L/1200V2000FT,R34L/4500V6000FT"];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization *m = [INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSString *expected = [ex objectAtIndex:idx];
        if ([expected isEqualToString:[m.runwayVisualRanges componentsJoinedByString:@","]]) {
            XCTFail(@"Expecting RVR %@, found RVR %@ in %@", expected, [m.runwayVisualRanges componentsJoinedByString:@","], m.metarString);
        }
    }];
}

- (void)testVisibility
{
    NSArray *a = @[
                   @"KGFK 032253Z 18010KT 3 OVC055 M04/M06 A2920 RMK AO2 T10441061",
                   @"KGFK 032253Z 18010KT 10SM OVC055 M04/M06 A2920 RMK AO2 T10441061",
                   @"KGFK 032253Z 18010KT M1/4SM OVC055 M04/M06 A2920 RMK AO2 T10441061",
                   @"KGFK 032253Z 18010KT 1 1/2SM OVC055 M04/M06 A2920 RMK AO2 T10441061",
                   @"KGFK 032253Z 18010KT P6SM OVC055 M04/M06 A2920 RMK AO2 T10441061",
                   ];
    NSArray *ex = @[@3, @10.0, @0.25, @1.5, @6.0];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization * m =[INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSNumber *expected = [ex objectAtIndex:idx];
        if (expected.floatValue != m.visibility) {
            XCTFail(@"Expecting visibility %f, found visibility %f in %@", expected.floatValue, m.visibility, m.metarString);
        }
    }];
}

- (void)testWeatherPhenomena
{
    NSArray *a = @[
                   @"KGFK 040907Z AUTO 34020KT 6SM +BLSN BKN035 M13/M17 A2976 RMK AO2 PK WND 34027/0858 UPE02 P0000 TSNO",
                   @"KGFK 040853Z AUTO 35025G32KT 2 1/2SM UP SCT029 BKN035 M13/M17 A2974 RMK AO2 PK WND 35032/0848 UPB53SNE43 PRESRR SLP088 P0000 60000 T11281167 52019 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM -FZFG BKN011 OVC030 M14/M16 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   ];
    NSArray *ex = @[@"+BLSN", @"UP", @"-FZFG"];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization * m =[INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSString *expected = [ex objectAtIndex:idx];
        if (![expected isEqualToString:[m.weatherPhenomena componentsJoinedByString:@","]]) {
            XCTFail(@"Expecting phenomena %@, found phenomena %@ in %@", expected, [m.weatherPhenomena componentsJoinedByString:@","], m.metarString);
        }
    }];
}

- (void)testWeatherPhenomenaHumanReadable
{
    NSArray *a = @[
                   @"KGFK 040907Z AUTO 34020KT 6SM +BLSN BKN035 M13/M17 A2976 RMK AO2 PK WND 34027/0858 UPE02 P0000 TSNO",
                   @"KGFK 040853Z AUTO 35025G32KT 2 1/2SM UP SCT029 BKN035 M13/M17 A2974 RMK AO2 PK WND 35032/0848 UPB53SNE43 PRESRR SLP088 P0000 60000 T11281167 52019 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM -FZFG BKN011 OVC030 M14/M16 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM +TSRA BKN011 OVC030 M14/M16 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM +SHRASN BKN011 OVC030 M14/M16 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM +TSRA +FC BKN011 OVC030 M14/M16 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   ];
    NSArray *ex = @[@"blowing heavy snow",
                    @"unknown precipitation",
                    @"freezing light fog",
                    @"thunderstorm heavy rain",
                    @"showers heavy rain and snow",
                    @"thunderstorm heavy rain,tornado or waterspout",
                    ];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization * m =[INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSString *expected = [ex objectAtIndex:idx];
        if (![expected isEqualToString:[m.weatherPhenomenaHumanReadable componentsJoinedByString:@","]]) {
            XCTFail(@"Expecting phenomena %@, found phenomena %@ in %@", expected, [m.weatherPhenomenaHumanReadable componentsJoinedByString:@","], m.metarString);
        }
    }];
}

- (void)testSkyConditions
{
    NSArray *a = @[
                   @"KGFK 040907Z AUTO 34020KT 6SM BLSN BKN035 M13/M17 A2976 RMK AO2 PK WND 34027/0858 UPE02 P0000 TSNO",
                   @"KGFK 040853Z AUTO 35025G32KT 2 1/2SM UP SCT029 BKN035 M13/M17 A2974 RMK AO2 PK WND 35032/0848 UPB53SNE43 PRESRR SLP088 P0000 60000 T11281167 52019 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM FZFG BKN011 OVC030 M14/M16 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   ];
    NSArray *ex = @[@"BKN035", @"SCT029,BKN035", @"BKN011,OVC030"];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization * m =[INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSString *expected = [ex objectAtIndex:idx];
        if (![expected isEqualToString:[m.skyConditions componentsJoinedByString:@","]]) {
            XCTFail(@"Expecting sky condition %@, found sky condition %@ in %@", expected, [m.skyConditions componentsJoinedByString:@","], m.metarString);
        }
    }];
}

- (void)testSkyConditionsHumanReadable
{
    NSArray *a = @[
                   @"KGFK 040907Z AUTO 34020KT 6SM BLSN BKN035 M13/M17 A2976 RMK AO2 PK WND 34027/0858 UPE02 P0000 TSNO",
                   @"KGFK 040853Z AUTO 35025G32KT 2 1/2SM UP SCT029 BKN035 M13/M17 A2974 RMK AO2 PK WND 35032/0848 UPB53SNE43 PRESRR SLP088 P0000 60000 T11281167 52019 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM FZFG VV007 BKN011 OVC030 M14/M16 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   @"KGFK 071453Z 000000KT 10SM CLR SCT200 M27/M29 A3009 RMK AO2 SLP222 T12671294 53020 $",
                   ];
    NSArray *ex = @[@"broken 3,500", @"scattered 2,900,broken 3,500", @"vertical visibility 700,broken 1,100,overcast 3,000", @"clear,scattered 20,000"];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization * m =[INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSString *expected = [ex objectAtIndex:idx];
        if (![expected isEqualToString:[m.skyConditionsHumanReadable componentsJoinedByString:@","]]) {
            XCTFail(@"Expecting sky condition %@, found sky condition %@ in %@", expected, [m.skyConditionsHumanReadable componentsJoinedByString:@","], m.metarString);
        }
    }];
}


- (void)testTemperatureC
{
    NSArray *a = @[
                   @"KGFK 040907Z AUTO 34020KT 6SM BLSN BKN035 M13/M17 A2976 RMK AO2 PK WND 34027/0858 UPE02 P0000 TSNO",
                   @"KGFK 040853Z AUTO 35025G32KT 2 1/2SM UP SCT029 BKN035 16/M10 A2974 RMK AO2 PK WND 35032/0848 UPB53SNE43 PRESRR SLP088 P0000 60000 T11281167 52019 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM FZFG BKN011 OVC030 25/20 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   ];
    NSArray *ex = @[@-13, @16, @25];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization * m =[INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSNumber *expected = [ex objectAtIndex:idx];
        if (expected.intValue != m.temperatureC) {
            XCTFail(@"Expecting temperature %i, found temperature %li in %@", expected.intValue, (long)m.temperatureC, m.metarString);
        }
    }];
}

- (void)testDewpointC
{
    NSArray *a = @[
                   @"KGFK 040907Z AUTO 34020KT 6SM BLSN BKN035 M13/M17 A2976 RMK AO2 PK WND 34027/0858 UPE02 P0000 TSNO",
                   @"KGFK 040853Z AUTO 35025G32KT 2 1/2SM UP SCT029 BKN035 16/M10 A2974 RMK AO2 PK WND 35032/0848 UPB53SNE43 PRESRR SLP088 P0000 60000 T11281167 52019 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM FZFG BKN011 OVC030 25/20 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   ];
    NSArray *ex = @[@-17, @-10, @20];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization * m =[INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSNumber *expected = [ex objectAtIndex:idx];
        if (expected.intValue != m.dewpointC) {
            XCTFail(@"Expecting dewpoint %i, found dewpoint %li in %@", expected.intValue, (long)m.dewpointC, m.metarString);
        }
    }];
}

- (void)testTemperatureF
{
    NSArray *a = @[
                   @"KGFK 040907Z AUTO 34020KT 6SM BLSN BKN035 M13/M17 A2976 RMK AO2 PK WND 34027/0858 UPE02 P0000 TSNO",
                   @"KGFK 040853Z AUTO 35025G32KT 2 1/2SM UP SCT029 BKN035 16/M10 A2974 RMK AO2 PK WND 35032/0848 UPB53SNE43 PRESRR SLP088 P0000 60000 T11281167 52019 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM FZFG BKN011 OVC030 25/20 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   ];
    NSArray *ex = @[@9, @61, @77];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization * m =[INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSNumber *expected = [ex objectAtIndex:idx];
        if (expected.intValue != m.temperatureF) {
            XCTFail(@"Expecting temperature %i, found temperature %li in %@", expected.intValue, (long)m.temperatureF, m.metarString);
        }
    }];
}

- (void)testDewpointF
{
    NSArray *a = @[
                   @"KGFK 040907Z AUTO 34020KT 6SM BLSN BKN035 M13/M17 A2976 RMK AO2 PK WND 34027/0858 UPE02 P0000 TSNO",
                   @"KGFK 040853Z AUTO 35025G32KT 2 1/2SM UP SCT029 BKN035 16/M10 A2974 RMK AO2 PK WND 35032/0848 UPB53SNE43 PRESRR SLP088 P0000 60000 T11281167 52019 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM FZFG BKN011 OVC030 25/20 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   ];
    NSArray *ex = @[@1, @14, @68];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization * m =[INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSNumber *expected = [ex objectAtIndex:idx];
        if (expected.intValue != m.dewpointF) {
            XCTFail(@"Expecting dewpoint %i, found dewpoint %li in %@", expected.intValue, (long)m.dewpointF, m.metarString);
        }
    }];
}

- (void)testAltimeter
{
    NSArray *a = @[
                   @"KGFK 040907Z AUTO 34020KT 6SM BLSN BKN035 M13/M17 A2976 RMK AO2 PK WND 34027/0858 UPE02 P0000 TSNO",
                   @"KGFK 040853Z AUTO 35025G32KT 2 1/2SM UP SCT029 BKN035 16/M10 A2974 RMK AO2 PK WND 35032/0848 UPB53SNE43 PRESRR SLP088 P0000 60000 T11281167 52019 TSNO",
                   @"KGFK 040601Z AUTO 34027G35KT 1/2SM FZFG BKN011 OVC030 25/20 A2958 RMK AO2 PK WND 34035/0555 P0000 TSNO",
                   ];
    NSArray *ex = @[@29.76, @29.74, @29.58];
    [a enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
        NSError *e = nil;
        INTMETARSerialization * m =[INTMETARSerialization METARObjectFromString:s options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
        NSNumber *expected = [ex objectAtIndex:idx];
        NSNumber *actual = [NSNumber numberWithDouble:m.altimeter];
        if (![expected isEqualToNumber:actual]) {
            XCTFail(@"Expecting altimeter %.2f, found altimeter %.2f in %@", expected.floatValue, m.altimeter, m.metarString);
        }
    }];
}

- (void)testNSStringCategory
{
    NSArray *a = @[
                   @"KGFK 032253Z 18013KT 10SM OVC055 M04/M06 A2920 RMK AO2 T10441061"
                   ];
    for (NSString *s in a){
        NSError *e = nil;
        [s METARObjectUsingOptions:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
        if (e) {
            XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
        }
    }

}

- (void)testLiveMetars
{
    // Not concerned about error handling. If we get good data we'll test it, if not we'll fail but who cares.
    NSArray *stations = @[
                          @"KGFK",
                          @"KMSP",
                          @"KLAX",
                          @"KJFK",
                          ];
    NSURL *baseURL = [NSURL URLWithString:@"http://weather.noaa.gov/pub/data/observations/metar/stations/"];
    NSUInteger validatedMETARS = 0;
    NSMutableArray *errors = [NSMutableArray array];
    for (NSString *station in stations){
        NSURL *stationURL = [[baseURL URLByAppendingPathComponent:station] URLByAppendingPathExtension:@"TXT"];
        NSURLRequest *request = [NSURLRequest requestWithURL:stationURL];
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (error) {
            [errors addObject:error];
        }
        if (data && !error) {
            // Expecting a 3 line string as a response. Last line is blank.
            /* Example:
             2014/01/06 18:53
             KLAX 061853Z VRB03KT 10SM FEW250 23/M12 A3019 RMK AO2 SLP223 T02281122 $
             
             */
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSArray *responseLines = [responseString componentsSeparatedByString:@"\n"];
            if (responseLines.count == 3) {
                NSString *metarString = (NSString *)[responseLines objectAtIndex:1];
                NSError *e = nil;
                [INTMETARSerialization METARObjectFromString:metarString options:INTMETARParseOptionStrict|INTMETARParseOptionLogWarnings error:&e];
                if (e) {
                    [errors addObject:e];
                    XCTFail(@"%@ %s", e.description, __PRETTY_FUNCTION__);
                }else{
                    validatedMETARS++;
                }
            }
        }
    }
    if (validatedMETARS != stations.count) {
        XCTFail(@"One or more live METARS did not validate. Validated %li out of %li. Errors: %@", validatedMETARS, stations.count, errors);
    }
}


@end
