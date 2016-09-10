//  Created by Adam Kaplan on 8/1/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

//compile out any logging for production builds
#ifndef DEBUG

// no-op both YFLog in release mode
#define YMLog_(level, fmt, ...)

#else

// define a logging macro that should be used instead of NSLog
#define YMLOG_ENABLED // use when logging requires non-trivial computation

#define YMLOG_PREFIX(level) "[" level "]"

#define YMLog_(level, fmt, ...) NSLog((@YMLOG_PREFIX(level) " %s " fmt), __PRETTY_FUNCTION__, ##__VA_ARGS__)

#endif


#define YMLog(fmt, ...)     YMLog_("INFO", fmt, ##__VA_ARGS__)
#define YMWarn(fmt, ...)    YMLog_("WARN", fmt, ##__VA_ARGS__)
#define YMError(fmt, ...)   YMLog_("ERROR",fmt, ##__VA_ARGS__)
