//
//  BHVideoEditor.m
//  TheBetterHalf
//
//  Created by Max Kuznetsov on 17.08.15.
//  Copyright (c) 2015 InMotionSoft. All rights reserved.
//

#import "BHVideoEditor.h"
#import "BHMiniVideoCompositing.h"

#import "BHBuffer.h"
#import "BHAssetExportSession.h"

#import "UIImage+ImageFromColorAndSize.h"
#import "NSFileManager+BHAddons.h"
#import "UIDevice+BHAddons.h"
#import "NSString+BHLines.h"
#import "AVAsset+BHAddons.h"


CGFloat const kStartImageDuration = 1.0;
CGFloat const kMatchDuration = 2.0;

@interface BHVideoEditor () <BHAssetExportSessionDelegate>

@property (nonatomic, strong) NSURL *outputVideoURL;
@property (nonatomic, strong) NSURL *miniVideoURL;
@property (nonatomic, strong) NSURL *sourceVideoURL;

@property (nonatomic, assign) CMTime sourceVideoDuration;

@property (nonatomic, strong) CALayer *videoLayer;
@property (nonatomic, strong) CALayer *parentLayer;

@property (nonatomic, assign) CGSize sourceVideoResolution;

@property (nonatomic, strong) AVAsset *sourceVideoAsset;
@property (nonatomic, strong) AVAsset *miniVideoAsset;

@end

@implementation BHVideoEditor

- (instancetype)initWithSourceVideoURL:(NSURL *)videoURL miniVideoURL:(NSURL *)miniVideoURL outputVideoURL:(NSURL *)outputVideoURL
{
    self = [super init];
    if (self) {
        self.sourceVideoAsset = [AVAsset assetWithURL:videoURL];
        self.miniVideoAsset   = [AVAsset assetWithURL:miniVideoURL];
        
        self.sourceVideoDuration = [self.sourceVideoAsset duration];
        self.sourceVideoResolution = [((AVAssetTrack *)[[self.sourceVideoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject]) naturalSize];
        
        self.outputVideoURL = outputVideoURL;
        self.miniVideoURL = miniVideoURL;
        self.sourceVideoURL = videoURL;
        [self initializeVideoLayerForSize:self.sourceVideoResolution];
    }
    return self;
}


#pragma mark -
#pragma mark Initializations

- (void)initializeVideoLayerForSize:(CGSize)size
{
    self.parentLayer = [CALayer layer];
    self.parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
    
    self.videoLayer = [CALayer layer];
    self.videoLayer.frame = self.parentLayer.bounds;

    [self.parentLayer addSublayer:self.videoLayer];
}

- (Class<AVVideoCompositing>)customVideoCompositingClass
{
    return [BHMiniVideoCompositing class];
}


#pragma mark -
#pragma mark Compositions

- (AVMutableVideoCompositionLayerInstruction *)createFirstCompositionLayerInstructionForComposition:(AVMutableComposition *)composition
{
    AVAsset *firstAsset = self.miniVideoAsset;
    AVMutableCompositionTrack *firstTrack;
    
    NSError *error = nil;
    firstTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];

    CMTime time = CMTimeMakeWithSeconds(self.miniVideoStartDelay + kStartImageDuration, NSEC_PER_SEC);

    AVAssetTrack *assetTrack = [[firstAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    [firstTrack insertEmptyTimeRange:CMTimeRangeMake(kCMTimeZero, time)];
    [firstTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, firstAsset.duration)
                         ofTrack:assetTrack
                          atTime:time
                           error:&error];

    [self addAudioFromAsset:firstAsset
              toComposition:composition
                     atTime:time
               withDuration:firstAsset.duration];
    
    AVMutableVideoCompositionLayerInstruction *firstlayerInstruction;
    if (firstTrack) {
        firstlayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:firstTrack];
        
        CGAffineTransform t1 = [self transformForMiniVideo:firstTrack asset:firstAsset];
        [firstlayerInstruction setTransform:t1 atTime:kCMTimeZero];
    }
    
    return firstlayerInstruction;
}

- (AVMutableVideoCompositionLayerInstruction *)createSecondCompositionLayerInstructionForComposition:(AVMutableComposition *)composition
                                                                                               track:(AVMutableCompositionTrack **)track
{
    NSError *error = nil;
    AVAsset *secondAsset = self.sourceVideoAsset;
    
    AVMutableCompositionTrack *secondTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    CMTime time = CMTimeMakeWithSeconds(kStartImageDuration, NSEC_PER_SEC);
    
    AVAssetTrack *assetTrack = [[secondAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    CMTimeRange emptyRange = CMTimeRangeMake(kCMTimeZero, time);
    
    [secondTrack insertEmptyTimeRange:emptyRange];
    [secondTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, secondAsset.duration)
                        ofTrack:assetTrack
                         atTime:time
                          error:&error];
    
    [self addAudioFromAsset:secondAsset
              toComposition:composition
                     atTime:time
               withDuration:secondAsset.duration];
    
    AVMutableVideoCompositionLayerInstruction *secondlayerInstruction;
    if (secondTrack) {
        secondlayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:secondTrack];
        
        CGAffineTransform t2 = [self transformForMainVideo:secondTrack asset:secondAsset];
        [secondlayerInstruction setTransform:t2 atTime:kCMTimeZero];
    }
    
    (*track) = secondTrack;
    
    return secondlayerInstruction;
}


#pragma mark -
#pragma mark Public Methods

- (CALayer *)addImage:(UIImage *)image inFrame:(CGRect)frame
{
    CALayer *imageLayer = [CALayer layer];
    [imageLayer setContents:(id)[image CGImage]];
    imageLayer.frame = frame;
    imageLayer.masksToBounds = YES;
    
    [self.parentLayer addSublayer:imageLayer];
    return imageLayer;
}

- (void)addTitle:(NSString *)title
        withFont:(UIFont *)font
       textColor:(UIColor *)textColor
         inFrame:(CGRect)frame
   alignmentMode:(NSString *)alignmentMode
{
    
    NSMutableArray *lines = [[title linesWithFont:font bounds:frame] mutableCopy];
    NSUInteger lineCount = lines.count;
    
    NSMutableString *newTitle = [[lines firstObject] mutableCopy];
    [lines removeObject:[lines firstObject]];
    
    for (NSString *line in lines) {
        [newTitle appendString:@"\r"];
        [newTitle appendString:line];
    }
    
    UIFont *titleFont = font;
    if (lines.count > 1) {
        titleFont = [UIFont fontWithName:font.fontName size:font.pointSize - 2];
    }
    
    CGRect rect = [title boundingRectWithSize:frame.size
                                      options:NSLineBreakByWordWrapping | NSStringDrawingUsesLineFragmentOrigin
                                   attributes:@{NSFontAttributeName:titleFont}
                                      context:nil];
    
    CGPoint position = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    if (lineCount > 1) {
        rect.size = frame.size;
        position.y += 5;
    }

    CATextLayer *textLayer = [CATextLayer layer];
    textLayer.wrapped = YES;
    textLayer.string = [[NSAttributedString alloc] initWithString:newTitle attributes:@{NSFontAttributeName            : titleFont,
                                                                                        NSForegroundColorAttributeName : textColor}];
    textLayer.frame = rect;
    textLayer.alignmentMode = alignmentMode;
    textLayer.position = position;
    
    [self.parentLayer addSublayer:textLayer];
}

- (void)startWorking
{
    if (self.thumbnailImage) {
        [self addThumbnailLayer];
    }
    
    [self addStartImage];
    [self addMatchNoMatchImage];
    
    AVMutableComposition *mixComposition = [AVMutableComposition new];
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    
    CMTime duration = CMTimeAdd(self.sourceVideoDuration, CMTimeMakeWithSeconds(kStartImageDuration, NSEC_PER_SEC));
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, duration);
    
    [BHBuffer sharedBuffer].value = self.thumbnailImage;
    [BHBuffer sharedBuffer].orientation = self.miniVideoOrientation;
    
    AVMutableCompositionTrack *secondTrack = nil;
    AVMutableVideoCompositionLayerInstruction *firstInstruction  = [self createFirstCompositionLayerInstructionForComposition:mixComposition];
    AVMutableVideoCompositionLayerInstruction *secondInstruction = [self createSecondCompositionLayerInstructionForComposition:mixComposition track:&secondTrack];
    
    if (firstInstruction && secondInstruction) {
        mainInstruction.layerInstructions = @[firstInstruction, secondInstruction];
    } else if (secondInstruction) {
        mainInstruction.layerInstructions = @[secondInstruction];
    }
    
    AVMutableVideoComposition *mainComposition = [AVMutableVideoComposition videoComposition];
    mainComposition.instructions = @[mainInstruction];
    mainComposition.frameDuration = CMTimeMakeWithSeconds(1.0 / secondTrack.nominalFrameRate, secondTrack.naturalTimeScale);
    mainComposition.renderSize = secondTrack.naturalSize;
    
    Class<AVVideoCompositing> videoCompositingClass = [self customVideoCompositingClass];
    if (videoCompositingClass) {
        mainComposition.customVideoCompositorClass = videoCompositingClass;
    }

    if (self.videoLayer) {
        mainComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:self.videoLayer inLayer:self.parentLayer];
    }
    
    [[NSFileManager defaultManager] removeItemAtURL:self.outputVideoURL error:nil];
    BHAssetExportSession *exporter = [[BHAssetExportSession alloc] initWithAsset:mixComposition
                                                                      presetName:AVAssetExportPreset960x540];
    exporter.delegate = self;
    
    exporter.outputURL = self.outputVideoURL;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.videoComposition = mainComposition;
    
    __weak BHVideoEditor *weakSelf = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        if (exporter.status == AVAssetExportSessionStatusFailed) {
            [weakSelf notifyError:exporter.error];
        } else {
            if (weakSelf.shouldAutomaticallyRemoveSourceFiles) {
                [[NSFileManager defaultManager] removeItemAtURL:weakSelf.miniVideoURL error:nil];
                [[NSFileManager defaultManager] removeItemAtURL:weakSelf.sourceVideoURL error:nil];
            }
            [weakSelf notifyFinishedWorkingWithURL:weakSelf.outputVideoURL];
        }
    }];
}

- (CGAffineTransform)transformForMiniVideo:(AVMutableCompositionTrack *)miniVideo asset:(AVAsset *)asset
{
    UIInterfaceOrientation orientation = [asset orientation];
    CGAffineTransform transform = asset.preferredTransform;
    
    CGFloat delta = 0.6f;
    
    CGFloat firstTrackHeight = [miniVideo naturalSize].height;
    CGFloat firstTrackWidth = [miniVideo naturalSize].width;
    CGFloat xOffset = firstTrackWidth - (firstTrackWidth * (1 - delta));
    CGFloat xDiff = firstTrackWidth * (1 - delta);
    
    CGFloat rightOffset = xDiff * 0.12;
    
    switch (orientation) {
        case UIInterfaceOrientationLandscapeRight: {
            CGAffineTransform scale = CGAffineTransformMakeScale(delta, delta);
            CGAffineTransform move  = CGAffineTransformMakeTranslation((self.sourceVideoResolution.width - xOffset) - rightOffset / 2, rightOffset / 2);
            transform = CGAffineTransformConcat(scale, move);
        }
            break;

        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationPortrait: {
            
            if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationLandscapeLeft &&
                orientation == UIInterfaceOrientationPortrait && [UIDevice isIpad]) {
                CGAffineTransform scale = CGAffineTransformMakeScale(delta, delta);
                CGAffineTransform move  = CGAffineTransformMakeTranslation((self.sourceVideoResolution.width - xOffset) - rightOffset / 2, rightOffset / 2);
                transform = CGAffineTransformConcat(scale, move);

                break;
            }
            
            transform = CGAffineTransformMake(1, 0, 0, -1, 0, firstTrackWidth);
            transform = CGAffineTransformMakeRotation(RADIANS_FROM_DEGREES(180));
            transform = CGAffineTransformTranslate(transform, -firstTrackWidth * 2, -firstTrackHeight);
            transform = CGAffineTransformScale(transform, 0.8, 0.8);
            transform = CGAffineTransformTranslate(transform, -60, 140);
        }
            break;
            
        default:
            break;
    }
    
    return transform;
}

- (CGAffineTransform)transformForMainVideo:(AVMutableCompositionTrack *)mainVideo asset:(AVAsset *)asset
{
    UIInterfaceOrientation orientation = [asset orientation];
    CGAffineTransform transform = asset.preferredTransform;
    
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationPortrait: {
            
            if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationLandscapeLeft &&
                orientation == UIInterfaceOrientationPortrait) {
                break;
            }
            
            transform = CGAffineTransformMakeRotation(RADIANS_FROM_DEGREES(180));
            transform = CGAffineTransformTranslate(transform, -[mainVideo naturalSize].width, -[mainVideo naturalSize].height);
            transform = CGAffineTransformConcat(transform, CGAffineTransformMake(-1, 0, 0, 1, [mainVideo naturalSize].width, 0));
        }
            break;
            
        default:
            break;
    }
    
    return transform;
}


#pragma mark -
#pragma mark Notify Methods

- (void)notifyError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(videoEditor:didReceiveError:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate videoEditor:self didReceiveError:error];
        });
    }
}

- (void)notifyFinishedWorkingWithURL:(NSURL *)fileURL
{
    if ([self.delegate respondsToSelector:@selector(videoEditor:didFinishedWorkingWithURL:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate videoEditor:self didFinishedWorkingWithURL:fileURL];
        });
    }
}

- (void)notifyProgress:(CGFloat)progress
{
    if ([self.delegate respondsToSelector:@selector(videoEditor:didUpdateProgress:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate videoEditor:self didUpdateProgress:progress];
        });
    }
}


#pragma mark -
#pragma mark BHAssetExportSessionDelegate

- (void)assetExportSession:(BHAssetExportSession *)session didUpdateProgress:(float)progress
{
    [self notifyProgress:progress];
}


#pragma mark -
#pragma mark Help Methods

- (void)addMatchNoMatchImage
{
    CABasicAnimation *appearAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [appearAnimation setDuration:kDefaultAnimationDuration];
    [appearAnimation setToValue:@(1)];
    [appearAnimation setBeginTime:MAX(0, (self.matchDelay + kStartImageDuration) - kDefaultAnimationDuration * 2)];
    
    [appearAnimation setRemovedOnCompletion:NO];
    appearAnimation.fillMode = kCAFillModeForwards;
    
    CABasicAnimation *disappearAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [disappearAnimation setDuration:kDefaultAnimationDuration];
    [disappearAnimation setToValue:@(0)];
    [disappearAnimation setBeginTime:(appearAnimation.beginTime + kMatchDuration) - kDefaultAnimationDuration * 2];
    [disappearAnimation setRemovedOnCompletion:NO];
    disappearAnimation.fillMode = kCAFillModeForwards;

    UIImage *mathNoMathImage = (self.match) ? [UIImage imageNamed:@"videoMatch"] : [UIImage imageNamed:@"videoNoMatch"];
    if (self.match) {
        mathNoMathImage = [mathNoMathImage imageWithOverlayColor:self.matchColor];
    }
    
    CALayer *imageLayer = [CALayer layer];
    [imageLayer setContents:(id)[mathNoMathImage CGImage]];
    imageLayer.frame = CGRectMake(0, 0, mathNoMathImage.size.width, mathNoMathImage.size.height);
    imageLayer.masksToBounds = YES;
    imageLayer.position = CGPointMake(self.sourceVideoResolution.width / 2, self.sourceVideoResolution.height / 2);

    CALayer *layer = [CALayer layer];
    layer.frame = CGRectMake(0, 0, self.sourceVideoResolution.width, self.sourceVideoResolution.height);
    [layer addSublayer:imageLayer];
    [self.parentLayer addSublayer:layer];

    layer.backgroundColor = RGBA(0, 0, 0, 0.35).CGColor;
    layer.opacity = 0;
    
    [layer addAnimation:appearAnimation forKey:@"appear"];
    [layer addAnimation:disappearAnimation forKey:@"disappear"];
}

- (void)addStartImage
{
    CABasicAnimation *hideAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [hideAnimation setDuration:kDefaultAnimationDuration];
    [hideAnimation setFromValue:@(1)];
    [hideAnimation setToValue:@(0)];
    [hideAnimation setBeginTime:kStartImageDuration];
    [hideAnimation setRemovedOnCompletion:NO];
    hideAnimation.fillMode = kCAFillModeForwards;
    
    UIImage *imageForInsert = [UIImage imageNamed:@"imageForInsert"];
    CALayer *layer = [self addImage:imageForInsert inFrame:CGRectMake(0, 0, self.sourceVideoResolution.width, self.sourceVideoResolution.height)];
    layer.contentsGravity = kCAGravityCenter;
    [layer addAnimation:hideAnimation forKey:@"opacity"];
}

- (void)addThumbnailLayer
{
    CABasicAnimation *hideAnimation = [CABasicAnimation animationWithKeyPath:@"hidden"];
    [hideAnimation setDuration:0];
    [hideAnimation setFromValue:[NSNumber numberWithBool:NO]];
    [hideAnimation setToValue:[NSNumber numberWithBool:YES]];
    [hideAnimation setBeginTime:(CGFloat)self.miniVideoStartDelay + kStartImageDuration];
    [hideAnimation setRemovedOnCompletion:NO];
    hideAnimation.fillMode = kCAFillModeForwards;
    
    CALayer *thumbLayer = [self addImage:self.thumbnailImage inFrame:CGRectMake(self.sourceVideoResolution.width  - (kMiniVideoSize.width + 10),
                                                                                self.sourceVideoResolution.height - (kMiniVideoSize.height + 10),
                                                                                kMiniVideoSize.width, kMiniVideoSize.height)];
    
    CGSize size = CGSizeMake(42, 42);
    UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:thumbLayer.bounds
                                                  byRoundingCorners:UIRectCornerTopLeft | UIRectCornerBottomLeft | UIRectCornerTopRight
                                                        cornerRadii:size];
    
    CAShapeLayer *shape = [[CAShapeLayer alloc] init];
    [shape setPath:rounded.CGPath];
    thumbLayer.mask = shape;
    
    [thumbLayer addAnimation:hideAnimation forKey:@"hide"];
}

- (BOOL)addAudioFromAsset:(AVAsset *)asset
            toComposition:(AVMutableComposition *)composition
                   atTime:(CMTime)atTime
             withDuration:(CMTime)duration
{
    NSError *error = nil;
    AVMutableCompositionTrack *compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                                preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration)
                                   ofTrack:track
                                    atTime:atTime
                                     error:&error];
    
    
    if ([self tryNotifyError:error]) {
        return NO;
    }
    
    return YES;
}

- (BOOL)tryNotifyError:(NSError *)error
{
    if (error) {
        [self notifyError:error];
        return YES;
    }
    return NO;
}

@end
