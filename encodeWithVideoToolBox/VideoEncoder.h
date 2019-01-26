//
//  VideoEncoder.h
//  encodeWithVideoToolBox
//
//  Created by 许伟杰 on 2019/1/25.
//  Copyright © 2019 JackXu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoEncoder : NSObject

- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)endEncode;

@end

NS_ASSUME_NONNULL_END
