//
//  BHVideoEditor.h
//  TheBetterHalf
//
//  Created by Max Kuznetsov on 17.08.15.
//  Copyright (c) 2015 InMotionSoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@import AVFoundation;

@class BHVideoEditor;
@protocol BHVideoEditorDelegate <NSObject>

- (void)videoEditor:(BHVideoEditor *)videoEditor didFinishedWorkingWithURL:(NSURL *)outputFileURL;

@optional
- (void)videoEditor:(BHVideoEditor *)videoEditor didReceiveError:(NSError *)error;
- (void)videoEditor:(BHVideoEditor *)videoEditor didUpdateProgress:(CGFloat)currentProgress;

@end


extern CGFloat const kStartImageDuration;
extern CGFloat const kMatchDuration;

@interface BHVideoEditor : NSObject

@property (nonatomic, weak) id<BHVideoEditorDelegate> delegate;
@property (nonatomic, readonly) CGSize sourceVideoResolution;
@property (nonatomic, assign) BOOL shouldAutomaticallyRemoveSourceFiles;

@property (nonatomic, assign) NSUInteger miniVideoStartDelay;
@property (nonatomic, strong) UIImage *thumbnailImage;

@property (nonatomic, assign) BOOL match;
@property (nonatomic, assign) NSTimeInterval matchDelay;
@property (nonatomic, strong) UIColor *matchColor;

@property (nonatomic, readonly) CALayer *videoLayer;
@property (nonatomic, readonly) CALayer *parentLayer;

@property (nonatomic, readonly) CMTime sourceVideoDuration;
@property (nonatomic, assign) UIInterfaceOrientation miniVideoOrientation;


- (instancetype)initWithSourceVideoURL:(NSURL *)videoURL miniVideoURL:(NSURL *)miniVideoURL outputVideoURL:(NSURL *)outputVideoURL;

- (CALayer *)addImage:(UIImage *)image inFrame:(CGRect)frame;
- (void)addTitle:(NSString *)title 
        withFont:(UIFont *)font 
       textColor:(UIColor *)textColor
         inFrame:(CGRect)frame
   alignmentMode:(NSString *)alignmentMode; //kCAAlignment

- (void)startWorking;

- (Class<AVVideoCompositing>)customVideoCompositingClass;


//tools
- (AVMutableVideoCompositionLayerInstruction *)createSecondCompositionLayerInstructionForComposition:(AVMutableComposition *)composition
                                                                                               track:(AVMutableCompositionTrack **)track;

- (BOOL)addAudioFromAsset:(AVAsset *)asset
            toComposition:(AVMutableComposition *)composition
                   atTime:(CMTime)atTime
             withDuration:(CMTime)duration;
- (CGAffineTransform)transformForMainVideo:(AVMutableCompositionTrack *)mainVideo asset:(AVAsset *)asset;

@end
