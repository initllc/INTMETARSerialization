/*
 Copyright (c) 2014, Init LLC
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "INTMETARSerialization.h"

#define CELSIUS_TO_FARENHEIT(C) ((C * 9.0) / 5.0) + 32.0

NSString * const INTMETARErrorInfoMetarKey = @"INTMETARErrorInfoMetarKey";

static NSString * const INTMetarSerializationErrorDomain = @"INTMetarSerializationError";

@interface INTMETARSerialization ()

@property BOOL strict;
@property BOOL logWarnings;

@property NSMutableArray *foundWeatherPhenomena;
@property NSMutableArray *foundSkyConditions;
@property NSMutableArray *foundRunwayVisualRanges;

- (NSError *)parse;
+ (NSDictionary *)_weatherPhenomenaDescriptorQualifiers;
+ (NSDictionary *)_weatherPhenomena;
+ (NSDictionary *)_skyConditions;
@end

@implementation INTMETARSerialization

+ (instancetype)METARObjectFromString:(NSString *)string options:(INTMETARParseOption)options error:(NSError *__autoreleasing *)error
{
    INTMETARSerialization *metar = [[INTMETARSerialization alloc] initWithString:string options:options];
    if (error != NULL) {
        *error = [metar parse];
        if (error != NULL) {
            return metar;
        }
        return nil;
    }else{
        [metar parse];
        return metar;
    }
}

- (instancetype)initWithString:(NSString *)string options:(INTMETARParseOption)options
{
    self = [super init];

    _metarString                 = [string uppercaseString];
    self.foundWeatherPhenomena   = [NSMutableArray array];
    self.foundSkyConditions      = [NSMutableArray array];
    self.foundRunwayVisualRanges = [NSMutableArray array];

    _windDirection = NSNotFound;
    _windSpeed     = NSNotFound;
    _gustSpeed     = NSNotFound;
    _visibility    = NSNotFound;
    _temperatureC  = NSNotFound;
    _dewpointC     = NSNotFound;

    self.strict      = (options & INTMETARParseOptionStrict) == INTMETARParseOptionStrict;
    self.logWarnings = (options & INTMETARParseOptionLogWarnings) == INTMETARParseOptionLogWarnings;

    return self;
}

- (NSError *)errorWithDescription:(NSString *)description reason:(NSString *)reason
{
    NSDictionary *info = @{
                           NSLocalizedDescriptionKey: description,
                           NSLocalizedFailureReasonErrorKey: reason,
                           INTMETARErrorInfoMetarKey: self.metarString,
                           };
    return [NSError errorWithDomain:INTMetarSerializationErrorDomain code:1 userInfo:info];
}

- (NSError *)parse
{
    // Parsing is one long procedural operation. The METAR string is split into components by spaces and each component is evaluated in order.
    // We sort of know what to expect in each component so we do our best using regular expressions to determine what we are evaluating.
    // Good luck.
    @try {

        ////////////////////////////////////////////////////////////////////////////////
        // Verify Metar
        // Quick checks to attempt to validate the METAR string. If it doesn't
        // look like a METAR string abort immediately regardless of
        // INTMETARParseOptionStrict option.
        ////////////////////////////////////////////////////////////////////////////////

        NSArray *c = [self.metarString componentsSeparatedByString:@" "];
        if (c.count == 0 || self.metarString.length == 0) {
            return [self errorWithDescription:@"Unable to parse METAR."
                                       reason:@"METAR string does not contain any components."];
        }

        // The first component should be either 'METAR' or 'SPECI'.
        // It is common to not include 'METAR' for automated reports, so we'll
        // allow 'METAR' to be optional.
        NSEnumerator *e = [c objectEnumerator];
        NSString *comp = e.nextObject;
        if ([c.firstObject isEqualToString:@"SPECI"]) {
            _special = YES;
            comp = e.nextObject;
        }else if([c.firstObject isEqualToString:@"METAR"]){
            comp = e.nextObject;
        }else if([c.firstObject length] != 4){
            // We were expecting the first component to be METAR or a 4 character airport identifier.
            return [self errorWithDescription:@"Invalid METAR string."
                                       reason:@"Expected string to start with either METAR, SPECI, or an airport identifier, but it does not."];
        }

        NSError *error = nil;

#pragma mark Airport Identifier
        ////////////////////////////////////////////////////////////////////////////////
        // Airport Identifier
        // It should be safe to assume that the comp contains the airport identifier.
        // If there is no airport identifier abort immediately regardless of
        // INTMETARParseOptionStrict option.
        ////////////////////////////////////////////////////////////////////////////////

        NSRegularExpression *airportExp = [NSRegularExpression regularExpressionWithPattern:@"^[A-Z]{4}$" options:0 error:&error];
        NSArray *airportMatches = [airportExp matchesInString:comp options:0 range:NSMakeRange(0, comp.length)];
        if (airportMatches.count) {
            _airport = [comp substringWithRange:((NSTextCheckingResult *)airportMatches.firstObject).range];
            comp = e.nextObject;
        }else{
            return [self errorWithDescription:@"Invalid METAR string."
                                       reason:@"Did not find airport identifier."];
        }



#pragma mark Date and Time
        ////////////////////////////////////////////////////////////////////////////////
        // Date and Time
        // comp should now contain the date and time. DDHHHHZ
        // Allow a little forgiveness if the Z isn't there. If date and time are not
        // found abort immediately regardless of INTMETARParseOptionStrict option.
        ////////////////////////////////////////////////////////////////////////////////

        NSRegularExpression *dateTimeExp = [NSRegularExpression regularExpressionWithPattern:@"^\\d{6}Z??$" options:0 error:&error];
        NSArray *matches = [dateTimeExp matchesInString:comp options:0 range:NSMakeRange(0, comp.length)];
        if (matches.count) {
            _day = [[comp substringWithRange:NSMakeRange(0, 2)] intValue];
            _time = [[comp substringWithRange:NSMakeRange(2, 4)] intValue];
            comp = e.nextObject;
        }else{
            NSError *error = [self errorWithDescription:@"Invalid METAR string."
                                                 reason:@"Did not find date and time."];
            if (self.logWarnings) {
                NSLog(@"%@", error.description);
            }
            if (self.strict) {
                return error;
            }
        }


        // We may have the text AUTO or COR after date and time.
        if ([comp isEqualToString:@"AUTO"]) {
            _isAuto = YES;
            comp = e.nextObject;
        }else if([comp isEqualToString:@"COR"]){
            // nothing to see here, keep moving.
            _isCorrection = YES;
            comp = e.nextObject;
        }



#pragma mark Wind Conditions
        ////////////////////////////////////////////////////////////////////////////////
        // Wind Conditions
        // comp should now the wind conditions.
        ////////////////////////////////////////////////////////////////////////////////

        error = nil;
        NSRegularExpression *vrbExp = [NSRegularExpression regularExpressionWithPattern:@"^VRB" options:0 error:&error];
        NSArray *vrbMatches = [vrbExp matchesInString:comp options:0 range:NSMakeRange(0, comp.length)];
        if (vrbMatches.count) {
            _windVariable = YES;
        }

        error = nil;
        NSRegularExpression *gstExp = [NSRegularExpression regularExpressionWithPattern:@"G" options:0 error:&error];
        NSArray *gstMatches = [gstExp matchesInString:comp options:0 range:NSMakeRange(0, comp.length)];
        if (gstMatches.count) {
            // if we have gusts, comp should be of length 10 i.e. 35026G35KT
            if (comp.length >= 8) {
                _gustSpeed = [[comp substringWithRange:NSMakeRange(6, 2)] integerValue];
            }else{
                NSError *error = [self errorWithDescription:@"Invalid METAR string."
                                                     reason:@"Unexpected error attempting to parse wind gusts."];
                if (self.logWarnings) {
                    NSLog(@"%@", error.description);
                }
                if (self.strict) {
                    return error;
                }
            }
        }
        // we are expecting the wind component to be at least 7 characters and (should) end in a digit followed by KT
        error = nil;
        NSRegularExpression *windExp = [NSRegularExpression regularExpressionWithPattern:@"\\d?(KT)$" options:0 error:&error];
        NSArray *windMatches = [windExp matchesInString:comp options:0 range:NSMakeRange(0, comp.length)];
        if (windMatches.count && comp.length >= 7) {
            _windDirection = [[comp substringWithRange:NSMakeRange(0, 3)] integerValue];
            _windSpeed = [[comp substringWithRange:NSMakeRange(3, 2)] integerValue];
            comp = e.nextObject;
        }else{
            NSError *error = [self errorWithDescription:@"Invalid METAR string."
                                                 reason:@"Unexpected error attempting to parse wind."];
            if (self.logWarnings) {
                NSLog(@"%@", error.description);
            }
            if (self.strict) {
                return error;
            }
        }




#pragma mark Variable Wind Conditions
        ////////////////////////////////////////////////////////////////////////////////
        // Variable Wind Conditions
        // There is a chance that we might have variable winds such as 040V120 before
        // we get to visibility. For now, we'll skip the variable winds component.
        ////////////////////////////////////////////////////////////////////////////////

        error = nil;
        NSRegularExpression *variableExp = [NSRegularExpression regularExpressionWithPattern:@"^\\d{3}V\\d{3}$" options:0 error:&error];
        NSArray *variableMatches = [variableExp matchesInString:comp options:0 range:NSMakeRange(0, comp.length)];
        if (variableMatches.count) {
            // I think it's safe to assume we'll only have one variable wind group, but cannot find documentation to confirm.
            // For now, use the first match.
            _variableWindGroup = [comp substringWithRange:((NSTextCheckingResult *)variableMatches.firstObject).range];
            comp = e.nextObject;
        }



#pragma mark Runway Visual Range
        ////////////////////////////////////////////////////////////////////////////////
        // Runway Visual Range
        // We might have multiple RVR to handle before we get to visibility.
        // For now, we'll skip RVRs.
        ////////////////////////////////////////////////////////////////////////////////

        error = nil;
        NSRegularExpression *rvrExp = [NSRegularExpression regularExpressionWithPattern:@"^R.*FT$" options:0 error:&error];
        ;
        BOOL lookForMoreRVR = YES;
        while (lookForMoreRVR) {
            NSArray *rvrMatches = [rvrExp matchesInString:comp options:0 range:NSMakeRange(0, comp.length)];
            if (rvrMatches.count) {
                for (NSTextCheckingResult *result in rvrMatches) {
                    NSString *rvr = [comp substringWithRange:result.range];
                    [self.foundRunwayVisualRanges addObject:rvr];
                }
                comp = e.nextObject;
            }else{
                lookForMoreRVR = NO;
            }
        }



#pragma mark Visibility
        ////////////////////////////////////////////////////////////////////////////////
        // Visibility
        // comp should now contain visibility. We need to peak ahead at the next object
        // in the enumerator in order to handle visibilities such as '1 1/4SM'
        ////////////////////////////////////////////////////////////////////////////////

        BOOL enumeratorNeedsAdditionalNext = YES;
        NSString *visComp = [NSString stringWithString:comp];
        if (visComp.length == 1) {
            // if we only have one character for visiblity we want to check the next component. If the next component ends in SM, it should be safe to combine the two and assume that visibility is something like 1 1/4SM.
            // This is more complicated than it should be because NSEnumerator does not have a way to peek ahead.
            comp = e.nextObject;
            enumeratorNeedsAdditionalNext = NO;
            if ([comp hasSuffix:@"SM"]) {
                visComp = [visComp stringByAppendingFormat:@" %@", comp];
                enumeratorNeedsAdditionalNext = YES;
            }
        }
        error = nil;
        NSRegularExpression *minVisRegEx = [NSRegularExpression regularExpressionWithPattern:@"^M\\d/\\dSM$" options:0 error:&error];
        NSArray *minVisMatches = [minVisRegEx matchesInString:visComp options:0 range:NSMakeRange(0, visComp.length)];
        if (minVisMatches.count) {
            _visibilityLessThan = YES;
            visComp = [visComp substringFromIndex:1];
        }
        error = nil;
        NSRegularExpression *visExp = [NSRegularExpression regularExpressionWithPattern:@"(^\\d{1,2}$)|(\\dSM)$" options:0 error:&error];
        NSArray *visExpMatches = [visExp matchesInString:visComp options:0 range:NSMakeRange(0, visComp.length)];
        if (visExpMatches.count){
            visComp = [visComp stringByReplacingOccurrencesOfString:@"SM" withString:@""];
            // comp should now have just the visibility characters, i.e. 10, 1/4, 1 1/4
            u_int8_t a = 0;
            NSRange spaceRange = [visComp rangeOfString:@" "];
            if (spaceRange.location != NSNotFound) {
                a = [[visComp substringToIndex:1] integerValue];
                visComp = [visComp substringWithRange:NSMakeRange(spaceRange.location, visComp.length - spaceRange.length)];
            }
            // comp should now just contain whole numbers or a fraction
            NSRange divRange = [visComp rangeOfString:@"/"];
            if (divRange.location != NSNotFound) {
                // WARNING !!! POTENTIAL DIVISION BY ZERO
                float b = [[visComp substringToIndex:divRange.location] floatValue];
                float c = [[visComp substringFromIndex:divRange.location + 1] floatValue];
                _visibility = a + ( b / c );
            }else{
                _visibility = [visComp integerValue];
            }
            if (_visibility) {
                // See the beginning of visibility parsing to understand why this check is here.
                if (enumeratorNeedsAdditionalNext) {
                    comp = e.nextObject;
                }
            }
        }else{
            NSError *error = [self errorWithDescription:@"Invalid METAR string."
                                                 reason:@"Unexpected error attempting to parse visibility."];
            if (self.logWarnings) {
                NSLog(@"%@", error.description);
            }
            if (self.strict) {
                return error;
            }
        }




#pragma mark Weather Phenomena
        ////////////////////////////////////////////////////////////////////////////////
        // Weather Phenomena
        // comp should now contain weather phenomena. There may be multiple phenomena.
        ////////////////////////////////////////////////////////////////////////////////

        BOOL lookForMorePhenomena = YES;
        NSArray *possibleDescriptors = [INTMETARSerialization _weatherPhenomenaDescriptorQualifiers].allKeys;
        NSArray *possiblePhenomena = [INTMETARSerialization _weatherPhenomena].allKeys;
        NSCharacterSet *intensityQualifiersSet = [NSCharacterSet characterSetWithCharactersInString:@"+-"];
        while (lookForMorePhenomena) {
            // Ignore the intensity for now
            NSString *phenom = [comp stringByTrimmingCharactersInSet:intensityQualifiersSet];

            // If the comp is a phenomena, it should be an even length string regardless of descriptor and phenomena combinations.
            if (phenom.length % 2 == 0) {

                // Each phenom component will be at least 2 characters.
                // Each phenom component must be a recognized possible phenomena descriptor qualifier or weather phenomena.
                BOOL isPhenomena = NO;
                for (int i = 0; i < phenom.length; i = i+2) {
                    NSString *pc = [phenom substringWithRange:NSMakeRange(i, 2)];
                    if ([possibleDescriptors containsObject:pc] || [possiblePhenomena containsObject:pc]) {
                        isPhenomena = YES;
                    }else{
                        isPhenomena = NO;
                        break;
                    }
                }

                if (isPhenomena) {
                    // it should be safe to assume that comp is a phenomena, add it to the array
                    [self.foundWeatherPhenomena addObject:comp];
                    comp = e.nextObject;
                }else{
                    lookForMorePhenomena = NO;
                }
            }else{
                lookForMorePhenomena = NO;
            }
        }


#pragma mark Sky Conditions
        ////////////////////////////////////////////////////////////////////////////////
        // Sky Conditions
        // comp should now contain sky conditions. There may be multiple conditions.
        // This could definitely be optimized.
        ////////////////////////////////////////////////////////////////////////////////

        BOOL lookForMoreSkyConditions = YES;
        NSArray *possibleSkyConditionPrefixes = [INTMETARSerialization _skyConditions].allKeys;
        while (lookForMoreSkyConditions) {
            BOOL isSkyCondition = NO;
            for (NSString *condition in possibleSkyConditionPrefixes) {
                if ([comp hasPrefix:condition]) {
                    isSkyCondition = YES;
                    break;
                }
            }

            if (isSkyCondition) {
                [self.foundSkyConditions addObject:comp];
                comp = e.nextObject;
            }else{
                lookForMoreSkyConditions = NO;
            }
        }


#pragma mark Temperature & Dewpoint
        ////////////////////////////////////////////////////////////////////////////////
        // Temperature & Dewpoint
        // comp should now contain the temperature and dewpoint.
        ////////////////////////////////////////////////////////////////////////////////

        error = nil;
        NSRegularExpression *tempDewExp = [NSRegularExpression regularExpressionWithPattern:@"^(-?M?\\d{1,2})??/(-?M?\\d{1,2})??$" options:0 error:&error];
        NSArray *tempDewMatches = [tempDewExp matchesInString:comp options:0 range:NSMakeRange(0, comp.length)];
        if (tempDewMatches.count) {
            // Split TT/DD into temp and dewpoint. Probably OK to just apply componentsSeparatedByString on comp. Using the regex match range to be safe.
            comp = [comp stringByReplacingOccurrencesOfString:@"M" withString:@"-"];
            NSArray *td = [[comp substringWithRange:((NSTextCheckingResult *)tempDewMatches.firstObject).range] componentsSeparatedByString:@"/"];
            if (td.count == 2) {
                _temperatureC = [td.firstObject integerValue];
                _dewpointC = [td.lastObject integerValue];
            }else{
                NSError *error = [self errorWithDescription:@"Invalid METAR string."
                                                     reason:@"Unexpected error attempting to parse temperature / dewpoint."];
                if (self.logWarnings) {
                    NSLog(@"%@", error.description);
                }
                if (self.strict) {
                    return error;
                }
            }
            comp = e.nextObject;
        }
        
        
        
#pragma mark Altimeter
        ////////////////////////////////////////////////////////////////////////////////
        // Altimeter
        // comp should now contain the altimeter.
        ////////////////////////////////////////////////////////////////////////////////

        error = nil;
        NSRegularExpression *altExp = [NSRegularExpression regularExpressionWithPattern:@"^A??\\d{4}$" options:0 error:&error];
        NSArray *altMatches = [altExp matchesInString:comp options:0 range:NSMakeRange(0, comp.length)];
        if (altMatches.count) {
            // Drop the A and divide by 100 to determine inches in mercury value.
            NSString *altimeter = [comp substringFromIndex:1];
            _altimeter = [altimeter intValue] / 100.0;
            comp = e.nextObject;
        }else{
            NSError *error = [self errorWithDescription:@"Invalid METAR string."
                                                 reason:@"Unexpected error attempting to parse altimeter."];
            if (self.logWarnings) {
                NSLog(@"%@", error.description);
            }
            if (self.strict) {
                return error;
            }
        }


        // Altimeter is the last thing parsed. At this point anything left in the NSEnumerator 'e' should be remarks.

    }
    @catch (NSException *exception) {
        // If something went horribly wrong (usually a NSString index out of bounds exception) return an error regardless of INTMETARParseOptionStrict option.
        if (self.logWarnings) {
            NSLog(@"Unexpected Parse Error: %@", exception);
        }
        return [self errorWithDescription:exception.name reason:exception.reason];
    }

    // Everything is 'good'? If we get here we think that the METAR was parsed as expected.
    return nil;
}

#pragma mark - Weather Phenomena
+ (NSDictionary *)_weatherPhenomenaDescriptorQualifiers
{
    return @{
             @"VC" : @"vicinity",       // Vicinity is not an actual qualifier, but we need to check this somewhere. For now, it is acceptable to place it here.
             @"MI" : @"shallow",
             @"BC" : @"patches",
             @"DR" : @"low drifting",
             @"BL" : @"blowing",
             @"SH" : @"showers",
             @"TS" : @"thunderstorm",
             @"FZ" : @"freezing",
             @"PR" : @"partial",
             };
}

// Weather phenomena is a combination of precipitation, obscuration, and other.
+ (NSDictionary *)_weatherPhenomena
{
    return @{
             // Precipitation
             @"DZ" : @"drizzle",
             @"RA" : @"rain",
             @"SN" : @"snow",
             @"SG" : @"snow grains",
             @"IC" : @"ice crystals",
             @"PL" : @"ice pellets",
             @"GR" : @"hail",
             @"GS" : @"small hail / snow pellets",
             @"UP" : @"unknown precipitation",

             // Obscuration
             @"BR" : @"mist",
             @"FG" : @"fog",
             @"DU" : @"dust",
             @"SA" : @"sand",
             @"HZ" : @"haze",
             @"PY" : @"spray",
             @"VA" : @"volcanic ash",
             @"FU" : @"smoke",

             // Other
             @"PO" : @"dust / sand whirls",
             @"SQ" : @"squalls",
             @"FC" : @"funnel cloud",
             @"+FC": @"tornado or waterspout", // Special condition where we want the + here.
             @"SS" : @"sandstorm",
             @"DS" : @"dust storm",
             };
}

#pragma mark - Sky Conditions
+ (NSDictionary *)_skyConditions
{
    return @{
             @"SKC" : @"clear",
             @"CLR" : @"clear",
             @"FEW" : @"few",
             @"SCT" : @"scattered",
             @"BKN" : @"broken",
             @"OVC" : @"overcast",
             @"VV"  : @"vertical visibility",
             };
}

#pragma mark - Property Accessors
- (NSArray *)weatherPhenomena
{
    return [NSArray arrayWithArray:self.foundWeatherPhenomena];
}

@synthesize weatherPhenomenaHumanReadable = _weatherPhenomenaHumanReadable;
- (NSArray *)weatherPhenomenaHumanReadable
{
    if (_weatherPhenomenaHumanReadable) {
        return _weatherPhenomenaHumanReadable;
    }
    NSDictionary *possibleWeatherPhenomena     = [INTMETARSerialization _weatherPhenomena];
    NSDictionary *possibleDescriptorQualifiers = [INTMETARSerialization _weatherPhenomenaDescriptorQualifiers];
    NSMutableArray *allPhenomena               = [NSMutableArray array];
    for (NSString *phenomena in self.weatherPhenomena) {
        // +FC is a special condition in which the + doesn't represent intensity. Instead, if we see +FC look it up directly from _weatherPhenomena instead of applying human readable logic.
        if ([phenomena isEqualToString:@"+FC"]) {
            NSString *fullPhenomena = [possibleWeatherPhenomena valueForKey:phenomena];
            if (fullPhenomena) {
                [allPhenomena addObject:fullPhenomena];
            }
            continue;
        }

        NSString *lookupKeys     = phenomena;
        NSString *humanIntensity = nil;
        if ([phenomena hasPrefix:@"-"]) {
            humanIntensity = @"light";
            lookupKeys = [phenomena substringFromIndex:1];
        }else if ([phenomena hasPrefix:@"+"]){
            humanIntensity = @"heavy";
            lookupKeys = [phenomena substringFromIndex:1];
        }

        // The lookupKeys length should be an even value. Look at each 2 character string in the lookupKeys and try to find it in either the _weatherPhenomenaDescriptorQualifiers or _weatherPhenomena dictionary.
        // It should be safe to assume that the descriptor will only ever be the first two characters, but we'll let the NSDictionary lookups determine whether or not something is a descriptor or a phenomena.
        // We will only have one descriptor per phenomena, but we might have multiple types of precipitation or obstructions.
        // Example, +SHRASN (heavy rain showers and snow.

        NSString *individualDescriptor = nil;
        NSMutableArray *individualPhenomenas = [NSMutableArray array];
        if (lookupKeys.length % 2 == 0) {
            for (int i = 0; i < lookupKeys.length; i = i+2) {
                NSString *key = [lookupKeys substringWithRange:NSMakeRange(i, 2)];
                NSString *humanPhenomena = [possibleWeatherPhenomena valueForKey:key];
                if (humanPhenomena) {
                    // Intensity applys to first precipitation (phenomena) and not the descriptor.
                    if (humanIntensity && individualPhenomenas.count == 0) {
                        humanPhenomena = [humanIntensity stringByAppendingFormat:@" %@", humanPhenomena];
                    }
                    // If there are no more keys to check, and we have multiple phenomena, prefix 'and' to the last phenomena.
                    else if (i + 2 == lookupKeys.length && individualPhenomenas.count > 0) {
                        humanPhenomena = [@"and " stringByAppendingString:humanPhenomena];
                    }
                    [individualPhenomenas addObject:humanPhenomena];
                }else{
                    individualDescriptor =  [possibleDescriptorQualifiers valueForKey:key];
                }
            }

            NSString *fullHumanPhenomena = nil;
            NSString *fullPhenomenas     = [individualPhenomenas componentsJoinedByString:@" "];
            if (individualDescriptor) {
                fullHumanPhenomena = [individualDescriptor stringByAppendingFormat:@" %@", fullPhenomenas];
            }else{
                fullHumanPhenomena = fullPhenomenas;
            }
            if (fullHumanPhenomena) {
                [allPhenomena addObject:fullHumanPhenomena];
            }
        }
    }
    _weatherPhenomenaHumanReadable = [NSArray arrayWithArray:allPhenomena];
    return _weatherPhenomenaHumanReadable;
}

- (NSArray *)skyConditions
{
    return [NSArray arrayWithArray:self.foundSkyConditions];
}

@synthesize skyConditionsHumanReadable = _skyConditionsHumanReadable;
- (NSArray *)skyConditionsHumanReadable
{
    if (_skyConditionsHumanReadable) {
        return _skyConditionsHumanReadable;
    }

    NSDictionary *possibleSkyConditions = [INTMETARSerialization _skyConditions];
    NSMutableArray *allConditions       = [NSMutableArray array];
    NSNumberFormatter *numberFormatter  = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle         = NSNumberFormatterDecimalStyle;
    for (NSString *condition in self.skyConditions){
        // First two or three characters are the condition, next three characters are the flight level.
        if (condition.length == 5 || condition.length == 6) {
            NSRange conditionRange = NSMakeRange(0, 0);
            NSRange levelRange = NSMakeRange(0, 0);
            if (condition.length == 5) {
                conditionRange = NSMakeRange(0, 2);
                levelRange     = NSMakeRange(2, 3);
            }else if (condition.length == 6){
                conditionRange = NSMakeRange(0, 3);
                levelRange     = NSMakeRange(3, 3);
            }
            NSString *conditionKey         = [condition substringWithRange:conditionRange];
            NSNumber *conditionLevelNumber = [NSNumber numberWithInt:[[condition substringWithRange:levelRange] intValue] * 100];
            NSString *humanCondition       = [possibleSkyConditions valueForKey:conditionKey];
            if (humanCondition) {
                NSString *fullHumanCondition = [NSString stringWithFormat:@"%@ %@", humanCondition, [numberFormatter stringFromNumber:conditionLevelNumber]];
                [allConditions addObject:fullHumanCondition];
            }
        }
        // CLR and SKC are special conditions in which there will be no flight level information.
        else if ([condition isEqualToString:@"CLR"] || [condition isEqualToString:@"SKC"]) {
            NSString *humanCondition = [possibleSkyConditions valueForKey:condition];
            if (humanCondition) {
                [allConditions addObject:humanCondition];
            }
        }
    }
    _skyConditionsHumanReadable = [NSArray arrayWithArray:allConditions];
    return _skyConditionsHumanReadable;
}

- (NSInteger)temperatureF
{
    return self.temperatureC == NSNotFound ? NSNotFound : roundf(CELSIUS_TO_FARENHEIT(self.temperatureC));
}

- (NSInteger)dewpointF
{
    return self.dewpointC == NSNotFound ? NSNotFound : roundf(CELSIUS_TO_FARENHEIT(self.dewpointC));
}

- (NSString *)description
{

    NSString *autoString    = self.isAuto ? @"YES" : @"NO";
    NSString *windDirection = self.windDirection != NSNotFound ? [NSString stringWithFormat:@"%li", (long)self.windDirection] : @"N/A";
    NSString *windSpeed     = self.windSpeed != NSNotFound ? [NSString stringWithFormat:@"%li", (long)self.windSpeed] : @"N/A";
    NSString *windGust      = self.gustSpeed != NSNotFound ? [NSString stringWithFormat:@"%li", (long)self.gustSpeed] : @"N/A";
    NSString *lessThan      = self.visibilityLessThan ? @"less than" : @"";
    NSString *visibility    = self.visibility != NSNotFound ? [NSString stringWithFormat:@"%@%.2f", lessThan, self.visibility] : @"N/A";
    NSString *weather       = self.weatherPhenomena.count > 0 ? [self.weatherPhenomena componentsJoinedByString:@","] : @"N/A";
    NSString *weatherHuman  = self.weatherPhenomenaHumanReadable.count > 0 ? [self.weatherPhenomenaHumanReadable componentsJoinedByString:@","] : @"N/A";
    NSString *sky           = self.skyConditions.count > 0 ? [self.skyConditions componentsJoinedByString:@","] : @"N/A";
    NSString *skyHuman      = self.skyConditionsHumanReadable.count > 0 ? [self.skyConditionsHumanReadable componentsJoinedByString:@","] : @"N/A";
    NSString *temperature   = self.temperatureC != NSNotFound ? [NSString stringWithFormat:@"Celsius %li, Farenheit %li", (long)self.temperatureC, (long)self.temperatureF] : @"N/A";
    NSString *dewpoint      = self.dewpointC != NSNotFound ? [NSString stringWithFormat:@"Celsius %li, Farenheit %li", (long)self.dewpointC, (long)self.dewpointF] : @"N/A";
    NSString *altimeter     = self.altimeter != NSNotFound ? [NSString stringWithFormat:@"%.2f", self.altimeter] : @"N/A";

    NSString *description = [NSString stringWithFormat:@"\n"
                             "Airport: %@\n"
                             "Auto: %@\n"
                             "Wind Direction: %@\n"
                             "Wind Speed: %@\n"
                             "Wind Gust: %@\n"
                             "Visibility: %@\n"
                             "Weather: %@ (%@)\n"
                             "Sky: %@ (%@)\n"
                             "Temperature: %@\n"
                             "Dewpoint: %@\n"
                             "Altimeter: %@\n",
                             self.airport,
                             autoString,
                             windDirection,
                             windSpeed,
                             windGust,
                             visibility,
                             weather,
                             weatherHuman,
                             sky,
                             skyHuman,
                             temperature,
                             dewpoint,
                             altimeter
                             ];
    return description;
}

@end

@implementation NSString (METAR)

- (INTMETARSerialization *)METARObject
{
    return [INTMETARSerialization METARObjectFromString:self options:INTMETARParseOptionStrict error:nil];
}

- (INTMETARSerialization *)METARObjectUsingOptions:(INTMETARParseOption)options error:(NSError *__autoreleasing *)error
{
    return [INTMETARSerialization METARObjectFromString:self options:options error:error];
}

@end