
//
//  VideoCapture.m
//  encodeWithVideoToolBox
//
//  Created by 许伟杰 on 2019/1/25.
//  Copyright © 2019 JackXu. All rights reserved.
//

#import "VideoCapture.h"
#import "VideoEncoder.h"
#import <AVFoundation/AVFoundation.h>

@interface VideoCapture() <AVCaptureVideoDataOutputSampleBufferDelegate>

/** 捕捉会话*/
@property (nonatomic, weak) AVCaptureSession *captureSession;

/** 捕捉画面执行的线程队列 */
@property (nonatomic, strong) dispatch_queue_t captureQueue;

/** 预览图层 */
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *previewLayer;

/** 编码对象 */
@property (nonatomic, strong) VideoEncoder *encoder;

@end

@implementation VideoCapture


- (void)startCapture:(UIView *)preview{
    //1.初始化编码对象
    self.encoder = [[VideoEncoder alloc] init];
    
    //2.创建捕抓对象
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset1280x720;
    self.captureSession = session;
    
    //3.设置输入设备
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    [session addInput:input];
    
    //4.添加输出设备
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    self.captureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [output setSampleBufferDelegate:self queue:self.captureQueue];
    [session addOutput:output];
    
    //5.设置录制视频的方向
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    //6.添加预览图层
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    previewLayer.frame = preview.bounds;
    [preview.layer insertSublayer:previewLayer atIndex:0];
    self.previewLayer = previewLayer;
    
    //7.开始捕捉
    [self.captureSession startRunning];
    
}

- (void)stopCapture{
    [self.captureSession stopRunning];
    [self.previewLayer removeFromSuperlayer];
    [self.encoder endEncode];
}

#pragma mark - 获取到数据
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    [self.encoder encodeSampleBuffer:sampleBuffer];
}


@end
