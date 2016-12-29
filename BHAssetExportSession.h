//
//  BHAssetExportSession.h
//  TheBetterHalf
//
//  Created by Denis Romashov on 17.09.15.
//  Copyright (c) 2015 InMotion Soft. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>


@class BHAssetExportSession;
@protocol BHAssetExportSessionDelegate <NSObject>

@optional
- (void)assetExportSession:(BHAssetExportSession *)session didUpdateProgress:(float)progress;

@end


@interface BHAssetExportSession : AVAssetExportSession

@property (nonatomic, weak) id<BHAssetExportSessionDelegate> delegate;

@end
