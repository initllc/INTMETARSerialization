## Description

Use INTMETARSerialization to parse and convert a METAR string to foundation objects and values.

There is no guarantee that this class will provide complete or accurate results.

####Features
* Wind
* Visibility
* Weather Phenomena
* Sky Conditions
* Temperature / Dewpoint
* Altimeter

####Limitations
* Remarks are not handled at this time.

####Use

```
NSString *metarString = @"KGFK 282303Z 36031G41KT 1/2SM -SN BLSN VV010 M21/M23 A3021 RMK AO2 PK WND 36041/2258 TWR VIS 3/4 P0000 $";
INTMETARSerialization *metar = [INTMETARSerialization METARObjectFromString:metarString options:INTMETARParseOptionStrict error:&error];
NSLog(@"%@", metar.description);
```

The output from the example above is:

```
Airport: KGFK
Auto: NO
Wind Direction: 360
Wind Speed: 31
Wind Gust: 41
Visibility: 0.50
Weather: -SN,BLSN
Sky: VV010
Temperature: Celsius -21, Farenheit -6
Dewpoint: Celsius -23, Farenheit -9
Altimeter: 30.21

```

####TODO
* Support for remarks such as tower visibility, surface visibility, precipitation began / ended times.

####License
```
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
```