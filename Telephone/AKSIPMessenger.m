//
//  AKSIPMessenger.m
//  Telephone
//
//  Copyright © 2008-2016 Alexey Kuznetsov
//  Copyright © 2016-2022 64 Characters
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

#import "AKSIPMessenger.h"
#import "AKSIPUserAgent.h"

@implementation AKSIPMessenger

- (instancetype)initWithUserAgent:(AKSIPUserAgent *)userAgent {
    self = [super init];
    if (self) {
        _userAgent = userAgent;
    }
    return self;
}

- (pj_status_t)sendMessage:(NSString *)text
                        to:(NSString *)destinationURI
                 accountId:(pjsua_acc_id)accId {
    pj_str_t to = pj_str((char *)[destinationURI UTF8String]);
    pj_str_t mime = pj_str("text/plain");
    pj_str_t content = pj_str((char *)[text UTF8String]);
    pjsua_msg_data msgData;
    pjsua_msg_data_init(&msgData);
    return pjsua_im_send(accId, &to, &mime, &content, &msgData, NULL);
}

@end
