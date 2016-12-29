//
//  BHMiniVideoCompositing.m
//  TheBetterHalf
//
//  Created by Max Kuznetsov on 31.08.15.
//  Copyright (c) 2015 InMotion Soft. All rights reserved.
//

#import "BHMiniVideoCompositing.h"
#import "BHPlayer.h"
#import "BHBuffer.h"
#import "UIColor+BHBGRA.h"
#import "UIImage+BHVideoThumbnail.h"


@implementation BHMiniVideoCompositing

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request
{
    CVPixelBufferRef destination = [request.renderContext newPixelBuffer];
    if (request.sourceTrackIDs.count) {
        CMPersistentTrackID frontTrackID = 0;
        CMPersistentTrackID backTrackID = (CMPersistentTrackID)[[request.sourceTrackIDs lastObject] integerValue];
        
        CVPixelBufferRef front = nil;
        CVPixelBufferRef back = [request sourceFrameByTrackID:backTrackID];
        
        if (request.sourceTrackIDs.count > 1) {
            frontTrackID = (CMPersistentTrackID)[[request.sourceTrackIDs firstObject] integerValue];
            front = [request sourceFrameByTrackID:frontTrackID];
        }

        CVPixelBufferLockBaseAddress(front, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferLockBaseAddress(back, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferLockBaseAddress(destination, 0);
        
        [self renderFrontBuffer:front backBuffer:back toBuffer:destination];
        
        CVPixelBufferUnlockBaseAddress(destination, 0);
        CVPixelBufferUnlockBaseAddress(back, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferUnlockBaseAddress(front, kCVPixelBufferLock_ReadOnly);
    }
    
    [request finishWithComposedVideoFrame:destination];
    CVBufferRelease(destination);
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext
{
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext
{
    return @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[@(kCVPixelFormatType_32BGRA)]};
}

- (NSDictionary *)sourcePixelBufferAttributes
{
    return @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[@(kCVPixelFormatType_32BGRA)]};
}

- (void)renderFrontBuffer:(CVPixelBufferRef)front
               backBuffer:(CVPixelBufferRef)back
                 toBuffer:(CVPixelBufferRef)destination
{
    CGImageRef frontImage = [self createSourceImageFromBuffer:front];
    CGImageRef backImage  = [self createSourceImageFromBuffer:back];
    
    size_t width = CVPixelBufferGetWidth(destination);
    size_t height = CVPixelBufferGetHeight(destination);
    CGRect frame = CGRectMake(0, 0, width, height);
    
    CGFloat strokeLineWidth = 10;
    CGSize frameSize = kMiniVideoSize;

    CGContextRef context = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(destination), width, height, 8, CVPixelBufferGetBytesPerRow(destination), CGImageGetColorSpace(backImage), CGImageGetBitmapInfo(backImage));
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    CGContextSaveGState(context); {
        
        if (orientation == UIInterfaceOrientationLandscapeLeft) {
            CGContextTranslateCTM(context, width, 0);
            CGContextScaleCTM(context, -1.0, 1.0);
        } else if (orientation == UIInterfaceOrientationLandscapeRight) {
            CGContextTranslateCTM(context, 0, height);
            CGContextScaleCTM(context, 1.0, -1.0);
        }
        
        CGContextDrawImage(context, frame, backImage);
    
    } CGContextRestoreGState(context);
 
    frame = CGRectMake(width - (frameSize.width + strokeLineWidth), height - (frameSize.height + strokeLineWidth),
                       frameSize.width, frameSize.height);
    
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRoundedRect:frame
                                                     byRoundingCorners:UIRectCornerTopLeft | UIRectCornerBottomLeft | UIRectCornerTopRight
                                                           cornerRadii:CGSizeMake(42, 42)];
    
    BHPlayer *anotherPlayer = [[BHGameOperator sharedGameOperator] anotherPlayerFromCurrent];
    if (anotherPlayer.color) {
        CGContextSetStrokeColorWithColor(context, [anotherPlayer.color BGRA].CGColor);
        CGContextAddPath(context, [bezierPath CGPath]);
        CGContextSetLineWidth(context, strokeLineWidth);
        CGContextStrokePath(context);
    }
    
    CGContextAddPath(context, [bezierPath CGPath]);
    CGContextClip(context);
    
    orientation = [BHBuffer sharedBuffer].orientation;
    
    if (frontImage) {
        CGContextSaveGState(context); {
            
            if (orientation == UIInterfaceOrientationLandscapeLeft) {
                CGContextTranslateCTM(context, width, 0);
                CGContextScaleCTM(context, -1.0, 1.0);

                frame.origin.x = strokeLineWidth;
                
            } else if (orientation == UIInterfaceOrientationLandscapeRight) {
                CGContextTranslateCTM(context, 0, height);
                CGContextScaleCTM(context, 1.0, -1.0);
                
                frame.origin.y = strokeLineWidth;
            }

            CGContextDrawImage(context, frame, frontImage);
            
        } CGContextRestoreGState(context);
    }
    
    CGImageRelease(frontImage);
    CGImageRelease(backImage);
    CGContextRelease(context);
}

- (CGImageRef)createSourceImageFromBuffer:(CVPixelBufferRef)buffer
{
    if (!buffer) {
        return nil;
    }
    
    size_t width = CVPixelBufferGetWidth(buffer);
    size_t height = CVPixelBufferGetHeight(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    void *data = CVPixelBufferGetBaseAddress(buffer);
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, height * stride, NULL);
    CGImageRef image = CGImageCreate(width, height, 8, 32, stride, rgb, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast, provider, NULL, NO, kCGRenderingIntentDefault);
    
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(rgb);
    return image;
}


@end
