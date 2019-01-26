//
//  ViewController.m
//  encodeWithVideoToolBox
//
//  Created by 许伟杰 on 2019/1/25.
//  Copyright © 2019 JackXu. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "VideoCapture.h"

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

/** 视频捕捉对象 */
@property (nonatomic, strong) VideoCapture *videoCapture;

@end

@implementation ViewController

- (IBAction)startCapture {
    [self.videoCapture startCapture:self.view];
}

- (IBAction)stopCapture {
    [self.videoCapture stopCapture];
}

- (VideoCapture *)videoCapture {
    if (_videoCapture == nil) {
        _videoCapture = [[VideoCapture alloc] init];
    }
    
    return _videoCapture;
}


@end
