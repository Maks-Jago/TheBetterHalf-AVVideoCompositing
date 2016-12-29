//
//  BHAssetExportSession.m
//  TheBetterHalf
//
//  Created by Denis Romashov on 17.09.15.
//  Copyright (c) 2015 InMotion Soft. All rights reserved.
//

#import "BHAssetExportSession.h"

@interface BHAssetExportSession ()

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) float previousProgress;

@end

@implementation BHAssetExportSession

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler
{
    self.previousProgress = 0;
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self
                                                selector:@selector(updatedProgress)
                                                userInfo:nil 
                                                 repeats:YES];
    
    __weak BHAssetExportSession *weakSelf = self;
    [super exportAsynchronouslyWithCompletionHandler:^{
        [weakSelf.timer invalidate];
        
        if (handler) {
            handler();
        }
    }];
}

- (void)updatedProgress
{
    if (self.previousProgress < self.progress) {
        [self notifyProgress:self.progress];
    }
    
    self.previousProgress = self.progress;
}

- (void)notifyProgress:(float)progress
{
    if ([self.delegate respondsToSelector:@selector(assetExportSession:didUpdateProgress:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate assetExportSession:self didUpdateProgress:progress];
        });
    }
}

@end
