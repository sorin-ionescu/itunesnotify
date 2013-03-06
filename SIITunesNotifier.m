// The MIT License
//
// Copyright (c) 2013 Sorin Ionescu.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <ScriptingBridge/ScriptingBridge.h>
#import "SIITunesNotifier.h"

@implementation SIITunesNotifier

- (id)init {
    self = [super init];

    if (!self) {
        return nil;
    }

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(playerStateDidChange:)
                                                            name:@"com.apple.iTunes.playerInfo"
                                                          object:nil];

    return self;
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

- (void)applicationDidFinishLaunching:(id)sender {
    if ([self applicationIsRunning]) {
        [NSApp terminate:self];
    }

    [GrowlApplicationBridge setGrowlDelegate:self];
}

- (BOOL)applicationIsRunning {
    NSString *processName = [[NSProcessInfo processInfo] processName];
    NSPredicate *duplicatesPredicate = [NSPredicate predicateWithFormat:@"localizedName==%@", processName];
    NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];
    NSArray *runningApplications = [sharedWorkspace runningApplications];
    NSArray *duplicateApplications = [runningApplications filteredArrayUsingPredicate:duplicatesPredicate];

    if ([duplicateApplications count] > 1) {
        return YES;
    }

    return NO;
}

- (NSDictionary *)registrationDictionaryForGrowl {
    NSArray *notifications = @[@"Playing"];

    return @{
        GROWL_TICKET_VERSION        : @1,
        GROWL_APP_ID                : @"itunesnotify",
        GROWL_NOTIFICATIONS_ALL     : notifications,
        GROWL_NOTIFICATIONS_DEFAULT : notifications
    };
}

- (NSData *)applicationIconDataForGrowl {
    NSString *iTunesPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.iTunes"];

    if (iTunesPath) {
      return [[[NSWorkspace sharedWorkspace] iconForFile:iTunesPath] TIFFRepresentation];
    }

    return nil;
}

- (void)playerStateDidChange:(NSNotification *)notification {
    if (!notification) {
      return;
    }

    if (![[notification name] isEqual:@"com.apple.iTunes.playerInfo"]) {
      return;
    }

    NSDictionary *userInfo = [notification userInfo];
    if (!userInfo) {
        return;
    }

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    SIITunesApplication *iTunes = (SIITunesApplication *)[SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];

    if (![iTunes isRunning]) {
        [pool drain];
        return;
    }

    NSString *playerState = [userInfo objectForKey:@"Player State"];
    if (![playerState isEqual:@"Playing"]) {
        [pool drain];
        return;
    }

    NSString *title = [userInfo objectForKey:@"Name"];
    if (!title) {
        title = @"";
    }

    NSString *artist = [userInfo objectForKey:@"Artist"];
    if (!artist) {
        artist = @"";
    }

    NSString *album = [userInfo objectForKey:@"Album"];
    if (!album) {
        album = @"";
    }

    NSString *description = [NSString stringWithFormat:@"%@\n%@", artist, album];
    SIITunesTrack *track = [iTunes currentTrack];
    NSArray *artworks = [[track artworks] get];
    SIITunesArtwork *artwork = [artworks lastObject];
    NSData *artworkData = [artwork rawData];

    if (!artworkData) {
        artworkData = [self applicationIconDataForGrowl];
    }

    [GrowlApplicationBridge notifyWithTitle:title
                                description:description
                           notificationName:@"Playing"
                                   iconData:artworkData
                                   priority:0
                                   isSticky:NO
                               clickContext:nil
                                 identifier:@"Playing"];

    [pool drain];
}

@end
