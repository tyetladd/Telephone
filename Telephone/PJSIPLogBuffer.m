//
//  PJSIPLogBuffer.m
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

#import "PJSIPLogBuffer.h"

#import <pj/log.h>

NSNotificationName const PJSIPLogBufferDidAppendEntryNotification = @"PJSIPLogBufferDidAppendEntryNotification";
NSString * const PJSIPLogBufferMessageUserInfoKey = @"message";

static int gConsoleOutputLevel = 0;

@interface PJSIPLogBuffer ()

@property(nonatomic) dispatch_queue_t queue;
@property(nonatomic) NSMutableArray<NSString *> *mutableMessages;

@end

@implementation PJSIPLogBuffer

+ (instancetype)sharedBuffer {
    static PJSIPLogBuffer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initPrivate];
    });
    return sharedInstance;
}

- (instancetype)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"Use +[PJSIPLogBuffer sharedBuffer]"
                                 userInfo:nil];
}

- (instancetype)initPrivate {
    self = [super init];
    if (self != nil) {
        _queue = dispatch_queue_create("com.telephone.pjsip.logs", DISPATCH_QUEUE_SERIAL);
        _mutableMessages = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray<NSString *> *)messages {
    __block NSArray<NSString *> *snapshot = nil;
    dispatch_sync(self.queue, ^{
        snapshot = [self.mutableMessages copy];
    });
    return snapshot;
}

- (NSString *)combinedLog {
    __block NSString *text = nil;
    dispatch_sync(self.queue, ^{
        text = [self.mutableMessages componentsJoinedByString:@"\n"];
    });
    return text ?: @"";
}

- (void)appendLogWithLevel:(int)level message:(NSString *)message {
    if (message.length == 0) {
        return;
    }
    dispatch_async(self.queue, ^{
        NSString *normalized = [self normalizedMessageWithLevel:level message:message];

        const NSUInteger kMaxEntries = 2000;
        if (self.mutableMessages.count >= kMaxEntries) {
            NSUInteger overflow = self.mutableMessages.count - kMaxEntries + 1;
            [self.mutableMessages removeObjectsInRange:NSMakeRange(0, overflow)];
        }

        [self.mutableMessages addObject:normalized];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
             postNotificationName:PJSIPLogBufferDidAppendEntryNotification
             object:self
             userInfo:@{PJSIPLogBufferMessageUserInfoKey: normalized}];
        });
    });
}

#pragma mark - Private

- (NSString *)normalizedMessageWithLevel:(int)level message:(NSString *)message {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss.SSS";
    });

    NSString *trimmed = [message stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];

    return [NSString stringWithFormat:@"%@ [%d] %@", timestamp, level, trimmed];
}

@end

void AKPJSIPLogBufferSetConsoleOutputLevel(int level) {
    gConsoleOutputLevel = level;
}

void AKPJSIPLogCallback(int level, const char *data, int len) {
    if (level <= gConsoleOutputLevel) {
        pj_log_write(level, data, len);
    }

    NSString *message = [[NSString alloc] initWithBytes:data length:(NSUInteger)len encoding:NSUTF8StringEncoding];
    if (message == nil) {
        message = [[NSString alloc] initWithBytes:data length:(NSUInteger)len encoding:NSISOLatin1StringEncoding];
    }
    if (message == nil) {
        message = @"<unprintable log entry>";
    }

    [[PJSIPLogBuffer sharedBuffer] appendLogWithLevel:level message:message];
}
