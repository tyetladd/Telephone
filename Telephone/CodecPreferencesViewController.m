//
//  CodecPreferencesViewController.m
//  Telephone
//
//  Copyright © 2008-2016 Alexey Kuznetsov
//  Copyright © 2016-2025 64 Characters
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

#import "CodecPreferencesViewController.h"

#import "AKSIPUserAgent.h"
#import "Telephone-Swift.h"

NS_ASSUME_NONNULL_BEGIN

@interface CodecOption : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *detail;
@end

@implementation CodecOption
@end

@interface CodecPreferencesViewController ()

@property(nonatomic, readonly) AKSIPUserAgent *userAgent;
@property(nonatomic, readonly) NSArray<CodecOption *> *options;
@property(nonatomic) NSMutableOrderedSet<NSString *> *enabledIdentifiers;
@property(nonatomic) NSMutableDictionary<NSString *, NSButton *> *buttons;

@end

@implementation CodecPreferencesViewController

- (instancetype)initWithUserAgent:(AKSIPUserAgent *)userAgent {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _userAgent = userAgent;
        self.title = NSLocalizedString(@"Codecs", @"Codec preferences window title.");
        _options = [self buildCodecOptions];
        _enabledIdentifiers = [[NSMutableOrderedSet alloc] initWithArray:[self initialEnabledCodecs]];
        _buttons = [[NSMutableDictionary alloc] initWithCapacity:_options.count];
    }
    return self;
}

- (void)loadView {
    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, 300)];
    content.translatesAutoresizingMaskIntoConstraints = NO;

    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 12;
    stack.edgeInsets = NSEdgeInsetsMake(20, 20, 20, 20);
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *intro = [NSTextField wrappingLabelWithString:NSLocalizedString(@"Choose which codecs Telephone offers to peers. Order reflects preference from top to bottom; disabled codecs are not advertised.", @"Codecs preferences help text.")];
    intro.preferredMaxLayoutWidth = 460;
    [stack addArrangedSubview:intro];

    for (NSUInteger idx = 0; idx < self.options.count; idx++) {
        CodecOption *option = self.options[idx];

        NSButton *checkbox = [NSButton checkboxWithTitle:option.title target:self action:@selector(toggleCodec:)];
        checkbox.identifier = option.identifier;
        checkbox.state = [self.enabledIdentifiers containsObject:option.identifier] ? NSControlStateValueOn : NSControlStateValueOff;
        self.buttons[option.identifier] = checkbox;

        NSTextField *detail = [NSTextField wrappingLabelWithString:option.detail];
        detail.preferredMaxLayoutWidth = 440;
        detail.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
        detail.textColor = [NSColor secondaryLabelColor];

        NSStackView *optionStack = [NSStackView stackViewWithViews:@[checkbox, detail]];
        optionStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        optionStack.alignment = NSLayoutAttributeLeading;
        optionStack.spacing = 2;
        [stack addArrangedSubview:optionStack];
    }

    NSButton *resetButton = [NSButton buttonWithTitle:NSLocalizedString(@"Reset to Defaults", @"Reset codecs to defaults") target:self action:@selector(resetToDefaults:)];
    [stack addArrangedSubview:resetButton];

    [content addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor],
        [content.widthAnchor constraintGreaterThanOrEqualToConstant:520]
    ]];

    self.view = content;
}

#pragma mark - Actions

- (void)toggleCodec:(NSButton *)sender {
    NSString *identifier = sender.identifier;
    if (sender.state == NSControlStateValueOn) {
        [self.enabledIdentifiers addObject:identifier];
        [self normalizeEnabledOrdering];
    } else {
        if (self.enabledIdentifiers.count <= 1) {
            sender.state = NSControlStateValueOn;
            NSBeep();
            return;
        }
        [self.enabledIdentifiers removeObject:identifier];
    }
    [self persistSelection];
}

- (void)resetToDefaults:(id)sender {
    self.enabledIdentifiers = [[NSMutableOrderedSet alloc] initWithArray:[self defaultEnabledCodecs]];
    for (CodecOption *option in self.options) {
        NSButton *button = self.buttons[option.identifier];
        button.state = [self.enabledIdentifiers containsObject:option.identifier] ? NSControlStateValueOn : NSControlStateValueOff;
    }
    [self persistSelection];
}

#pragma mark - Helpers

- (NSArray<NSString *> *)initialEnabledCodecs {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSArray *stored = [defaults arrayForKey:UserDefaultsKeys.enabledCodecs];
    if ([stored count] > 0) {
        return stored;
    }
    if ([defaults boolForKey:UserDefaultsKeys.useG711Only]) {
        return @[ @"PCMA/8000/1", @"PCMU/8000/1" ];
    }
    return [self defaultEnabledCodecs];
}

- (NSArray<NSString *> *)defaultEnabledCodecs {
    return [AKSIPUserAgent defaultEnabledCodecs];
}

- (NSArray<CodecOption *> *)buildCodecOptions {
    NSMutableArray<CodecOption *> *result = [[NSMutableArray alloc] init];

    [result addObject:[self optionWithIdentifier:@"opus/48000/2"
                                           title:NSLocalizedString(@"Opus (wideband)", @"Opus codec title")
                                          detail:NSLocalizedString(@"48 kHz stereo; best quality, higher bandwidth.", @"Opus codec detail")]];

    [result addObject:[self optionWithIdentifier:@"G722/16000/1"
                                           title:NSLocalizedString(@"G.722", @"G.722 codec title")
                                          detail:NSLocalizedString(@"16 kHz; wideband, good quality.", @"G.722 codec detail")]];

    [result addObject:[self optionWithIdentifier:@"G729/8000/1"
                                           title:NSLocalizedString(@"G.729", @"G.729 codec title")
                                          detail:NSLocalizedString(@"8 kHz; low bitrate (8 kbps), good for constrained links.", @"G.729 codec detail")]];

    [result addObject:[self optionWithIdentifier:@"PCMA/8000/1"
                                           title:NSLocalizedString(@"G.711 A-law (PCMA)", @"G.711 A-law codec title")
                                          detail:NSLocalizedString(@"8 kHz; legacy PSTN quality.", @"G.711 A-law codec detail")]];

    [result addObject:[self optionWithIdentifier:@"PCMU/8000/1"
                                           title:NSLocalizedString(@"G.711 µ-law (PCMU)", @"G.711 µ-law codec title")
                                          detail:NSLocalizedString(@"8 kHz; legacy PSTN quality.", @"G.711 µ-law codec detail")]];

    [result addObject:[self optionWithIdentifier:@"GSM/8000/1"
                                           title:NSLocalizedString(@"GSM", @"GSM codec title")
                                          detail:NSLocalizedString(@"8 kHz; very low bandwidth, fallback quality.", @"GSM codec detail")]];

    [result addObject:[self optionWithIdentifier:@"iLBC/8000/1"
                                           title:NSLocalizedString(@"iLBC", @"iLBC codec title")
                                          detail:NSLocalizedString(@"8 kHz; packet-loss resilient.", @"iLBC codec detail")]];

    [result addObject:[self optionWithIdentifier:@"speex/32000/1"
                                           title:NSLocalizedString(@"Speex WB", @"Speex wideband codec title")
                                          detail:NSLocalizedString(@"32 kHz; legacy wideband.", @"Speex wideband codec detail")]];

    [result addObject:[self optionWithIdentifier:@"speex/16000/1"
                                           title:NSLocalizedString(@"Speex NB", @"Speex narrowband codec title")
                                          detail:NSLocalizedString(@"16 kHz; legacy.", @"Speex narrowband codec detail")]];

    [result addObject:[self optionWithIdentifier:@"speex/8000/1"
                                           title:NSLocalizedString(@"Speex 8 kHz", @"Speex 8k codec title")
                                          detail:NSLocalizedString(@"8 kHz; legacy.", @"Speex 8k codec detail")]];

    return result;
}

- (CodecOption *)optionWithIdentifier:(NSString *)identifier title:(NSString *)title detail:(NSString *)detail {
    CodecOption *option = [[CodecOption alloc] init];
    option.identifier = identifier;
    option.title = title;
    option.detail = detail;
    return option;
}

- (void)persistSelection {
    NSArray<NSString *> *enabled = [self.enabledIdentifiers array];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:enabled forKey:UserDefaultsKeys.enabledCodecs];
    [defaults setBool:NO forKey:UserDefaultsKeys.useG711Only];
    self.userAgent.enabledCodecs = enabled;
}

- (void)normalizeEnabledOrdering {
    NSMutableOrderedSet<NSString *> *ordered = [[NSMutableOrderedSet alloc] init];
    for (CodecOption *option in self.options) {
        if ([self.enabledIdentifiers containsObject:option.identifier]) {
            [ordered addObject:option.identifier];
        }
    }
    self.enabledIdentifiers = ordered;
}

@end

NS_ASSUME_NONNULL_END
