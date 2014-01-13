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

#import <Foundation/Foundation.h>

/** Key in NSError info dictionary that contains the raw metar string that caused the error.*/
extern NSString * const INTMETARErrorInfoMetarKey;

typedef NS_ENUM(NSUInteger, INTMETARParseOption){
    /** Whether or not parsing should fail if wind, visibility, sky conditions, temp / dewpoint, or altimeter are missing.*/
    INTMETARParseOptionStrict      = 1,

    /** Outputs warnings to NSLog.*/
    INTMETARParseOptionLogWarnings = 2,
};


/** Use INTMETARSerialization to parse and convert a METAR string to foundation objects and values.
 
 A METAR string must start with one of the following values:

 * METAR
 * SPECI
 * 4 letter airport identifier

 There is no guarantee that this class will provide complete or accurate results.
 */
 
 @interface INTMETARSerialization : NSObject

#pragma mark - Methods
/**-----------------------------------------------------------------------------
 * @name Methods
 * -----------------------------------------------------------------------------
 */

/** Convert a METAR string to foundation objects and values.

 @param string The METAR string to parse.
 @param options Options for parsing. See INTMETARParseOption enum.
 @param error If an error occurs upon return contains an NSError describing the problem.

 @return INTMETARSerialization object if parsing was successful, nil if an error occured.
 */
+ (instancetype)METARObjectFromString:(NSString *)string options:(INTMETARParseOption)options error:(NSError **)error;


#pragma mark - Identify
/**-----------------------------------------------------------------------------
 * @name Identify
 * -----------------------------------------------------------------------------
 */


/** If the METAR starts with 'SPECI', this property will be YES.*/
@property (readonly, nonatomic) BOOL special;


/** The 4 letter airport identifier from the METAR. Parsing will fail if the
 airport identifier could not be found.
 */
@property (readonly, nonatomic) NSString *airport;


/** The day of the month from the METAR. Parsing will fail if the day cannot
 be found.
 
 @note This value may be deprecated in favour of `date`.*/
@property (readonly, nonatomic) u_int8_t day;


/** The Zulu time of the report. Parsing will fail if the time cannot be found.
 
 @note This value may be deprecated in favour of `date`.*/
@property (readonly, nonatomic) u_int16_t time;

/** The date of the report. Parsing will fail if the date cannot be found.
 
 @warning METARs do not contain month or year data. The NSDate will contain the current month / year. If you are using this class to parse historical data you will need to keep track of month / year values independent of this property.
 */
@property (readonly, nonatomic) NSDate *date;


/** If 'AUTO' is found in the report this property will be YES.*/
@property (readonly, nonatomic) BOOL isAuto;


/** If 'COR' is found in the report this property will be YES.*/
@property (readonly, nonatomic) BOOL isCorrection;


#pragma mark - Wind
/**-----------------------------------------------------------------------------
 * @name Wind
 * -----------------------------------------------------------------------------
 */


/** If wind conditions contain 'VRB' this property will be YES.
 
 This is independent of the variableWindGroup property. windVariable represents
 winds 6 knots or less.
 
 Example: VRB04KT

 */
@property (readonly, nonatomic) BOOL windVariable;


/** Wind direction from which the wind is blowing referenced from true north
 (0 - 360 degrees).

 @note If wind conditions are not found in the report this value will be
 NSNotFound.
 */
@property (readonly, nonatomic) NSInteger windDirection;


/** Wind speed in knots.
 
 @note If wind conditions are not found in the report this value will be
 NSNotFound.
 */
@property (readonly, nonatomic) NSInteger windSpeed;


/** Wind gust speed in knots.

 @note If wind conditions are not found in the report this value will be
 NSNotFound.
*/
@property (readonly, nonatomic) NSInteger gustSpeed;

/** Variable wind group
 
 This is independent of the windVariable property. variableWindGroup represents
 winds variable of 60 degrees or more and speed of 6 knots or greater.
 
 Example: 040V120

 */
@property (readonly, nonatomic) NSString *variableWindGroup;


// TODO: Add peakWindDirection, peakWindSpeed, peakWindTime properties.


#pragma mark - Visibility
/**-----------------------------------------------------------------------------
 * @name Visibility
 * -----------------------------------------------------------------------------
 */


/** If the visibility conditions indicate 'less than' this value will be YES.
 
 Example, 'M1/4SM' will cause this flag to be set to YES.

 @see visibility
 */
@property (readonly, nonatomic) BOOL visibilityLessThan;


/** Visibility in statute miles.

 @note P6SM is not handled correctly at this time.
 
 @note If visibility conditions cannot be determined this value will be
 NSNotFound.
 
 @see visibilityLessThan
 */
@property (readonly, nonatomic) CGFloat visibility;

/** Runway Visual Ranges
 
 Example: R35L/4500V6000FT, R34L/4500V6000FT

 */
@property (readonly, nonatomic) NSArray *runwayVisualRanges;

// TODO: Add surfaceVisibility, towerVisibility properties.

#pragma mark - Weather Phenomena
/**-----------------------------------------------------------------------------
 * @name Weather Phenomena
 * -----------------------------------------------------------------------------
 */


/** Array of weather phenomena.
 
 Proximity:

 * VC - Vicinity

 Qualifiers:

 * MI - Shallow
 * BC - Patches
 * DR - Low Drifting
 * BL - Blowing
 * SH - Showers
 * TS - Thunderstorm
 * FZ - Freezing
 * PR - Partial

 Intensity:

 * \-  Light
 * &nbsp;&nbsp;   Moderate
 * \+  Heavy

 Precipitation:

 * DZ - Drizzle
 * RA - Rain
 * SN - Snow
 * SG - Snow Grains
 * IC - Ice Crystals
 * PL - Ice Pellets
 * GR - Hail
 * GS - Small Hail or Snow Pellets
 * UP - Unknown Precipitation

 Obscuration:

 * BR - Mist
 * FG - Fog
 * DU - Dust
 * SA - Sand
 * HZ - Haze
 * PY - Spray
 * VA - Volcanic Ash
 * FU - Smoke

 Other:

 * PO - Dust / Sand Whirls
 * SQ - Squalls
 * FC - Funnel Cloud (+FC) Tornado or Waterspout
 * SS - Sandstorm
 * DS - Dust Storm

 */
@property (readonly, nonatomic) NSArray *weatherPhenomena;



/** Array of weather phenomena in a human readable format.
 
 For example, if weatherPhenomena contains '-SN' then weatherPhenomenaHumanReadable
 would contain 'light snow'.

 */
@property (readonly, nonatomic) NSArray *weatherPhenomenaHumanReadable;

// TODO: Add preciptation began / end properties.


#pragma mark - Sky Conditions
/**-----------------------------------------------------------------------------
 * @name Sky Conditions
 * -----------------------------------------------------------------------------
 */


/** Array of sky conditions.
 
 Contractions:

 * SKC - Clear
 * CLR - Clear
 * FEW - Few
 * SCT - Scattered
 * BKN - Broken
 * OVC - Overcast
 * VV - Vertical Visibility

 */
@property (readonly, nonatomic) NSArray *skyConditions;


/** Array of sky conditions in human readable format.
 
 For example, if skyConditions contains 'OVC020' then
 skyConditionsHumanReadable would contain 'overcast at 2,000'.

 */
@property (readonly, nonatomic) NSArray *skyConditionsHumanReadable;


#pragma mark - Temperature & Dewpoint
/**-----------------------------------------------------------------------------
 * @name Temperature & Dewpoint
 * -----------------------------------------------------------------------------
 */


/** Temperature in degrees Celsius.
 
 @note If temperature cannot be determined this value will be NSNotFound.
 */
@property (readonly, nonatomic) NSInteger temperatureC;


/** Dewpoint in degrees Celsius.
 
 @note If dewpoint cannot be determinied this value will be NSNotFound.
 */
@property (readonly, nonatomic) NSInteger dewpointC;


/** Temperature in degrees Farenhiet (rounded).

 @note If temperature cannot be determined this value will be NSNotFound.
 */
@property (readonly, nonatomic) NSInteger temperatureF;


/** Dewpoint in degrees Farenhiet (rounded).

 @note If dewpoint cannot be determinied this value will be NSNotFound.
 */
@property (readonly, nonatomic) NSInteger dewpointF;


#pragma mark - Altimeter
/**-----------------------------------------------------------------------------
 * @name Altimeter
 * -----------------------------------------------------------------------------
 */


/** Altimeter in inches of mercury.
 
 @note If altimeter cannot be determinied this value will be NSNotFound.
 */
@property (readonly, nonatomic) CGFloat altimeter;


#pragma mark - METAR
/**-----------------------------------------------------------------------------
 * @name Metar
 * -----------------------------------------------------------------------------
 */

/** The full metar string that was parsed.*/
@property (readonly, nonatomic) NSString *metarString;

@end

/** Convenience category that adds METAR parsing to NSString.*/
@interface NSString (METAR)

/** Parse sender string using INTMETARSerialization.

 String is parsed using INTMETARParseOptionStrict option.

 @return Parsed METAR string or nil if an error was encountered.
 */
- (INTMETARSerialization *)METARObject;


/** Parse sender string using INTMETARSerialization.

 @param options Options for parsing. See INTMETARParseOption enum.
 @param error If an error occurs upon return contains an NSError describing the problem.

 @return Parsed METAR string or nil if an error was encountered.
 */
- (INTMETARSerialization *)METARObjectUsingOptions:(INTMETARParseOption)options error:(NSError **)error;

@end
