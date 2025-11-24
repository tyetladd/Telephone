//
//  PJSIPLogBuffer.h
//  Telephone
//
//  Copyright © 2025
//
//  Telephone is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Telephone is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const PJSIPLogBufferDidAppendEntryNotification;
extern NSString * const PJSIPLogBufferMessageUserInfoKey;

@interface PJSIPLogBuffer : NSObject

+ (instancetype)sharedBuffer;

/// Returns a snapshot of buffered log lines (oldest first).
- (NSArray<NSString *> *)messages;

/// Returns the buffered log lines concatenated with new lines.
- (NSString *)combinedLog;

/// Appends a new PJSIP log entry.
- (void)appendLogWithLevel:(int)level message:(NSString *)message;

@end

/// PJSIP log callback configured on pjsua to mirror logs into the buffer.
void AKPJSIPLogCallback(int level, const char *data, int len);

/// Sets the maximum log level that should also be mirrored to the process console.
void AKPJSIPLogBufferSetConsoleOutputLevel(int level);

NS_ASSUME_NONNULL_END
