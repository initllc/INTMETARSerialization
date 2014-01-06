//
//  main.m
//  INTMETARSerialization
//
//  Created by Mike on 1/6/14.
//  Copyright (c) 2014 init. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INTMETARSerialization.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {

        NSError *error = nil;
//        NSString *metarString = @"KGFK 061153Z 29011KT 10SM FEW100 M32/M36 A3034 RMK AO2 SLP311 4/006 T13171361 11300 21317 55003";
        NSString *metarString = @"KGFK 282303Z 36031G41KT 1/2SM -SN BLSN VV010 M21/M23 A3021 RMK AO2 PK WND 36041/2258 TWR VIS 3/4 P0000 $";
        INTMETARSerialization *metar = [INTMETARSerialization METARObjectFromString:metarString options:INTMETARParseOptionStrict error:&error];
        NSLog(@"%@", metar.description);
        
    }
    return 0;
}

