//
//  VideoEncoder.m
//  encodeWithVideoToolBox
//
//  Created by 许伟杰 on 2019/1/25.
//  Copyright © 2019 JackXu. All rights reserved.
//

#import "VideoEncoder.h"

@interface VideoEncoder()

/** 记录当前的帧数 */
@property (nonatomic, assign) NSInteger frameID;

/** 编码会话 */
@property (nonatomic, assign) VTCompressionSessionRef compressionSession;

/** 文件写入对象 */
@property (nonatomic, strong) NSFileHandle *fileHandle;

@end

@implementation VideoEncoder

-(instancetype)init{
    if(self = [super init]){
        // 1.初始化写入文件的对象(NSFileHandle用于写入二进制文件)
        [self setUpFileHandle];
        // 2.初始化压缩编码的会话
        [self setUpVideoSession];
    }
    return self;
}

-(void)setUpFileHandle{
    //1.获取沙盒路径
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc.h264"];

    //2.如果已有文件则删除后再创建
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    
    //3.创建对象
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
}

-(void)setUpVideoSession{
    //1.用于记录当前是第几帧数据
    self.frameID = 0;
    
    //2.录制视频的宽高
    int width = [UIScreen mainScreen].bounds.size.width;
    int height = [UIScreen mainScreen].bounds.size.height;
    
    //3.创建CompressionSession对象，用于对画面进行编码
    VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self), &_compressionSession);
    
    //4.设置实时编码输出（直播需要实时输出）
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    //5.设置期望帧率为每秒30帧
    int fps = 30;
    CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);

    //6.设置码率
    int biteRate = 800*1024;
    CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &biteRate);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
    NSArray *limit = @[@(biteRate*1.5/8),@(1)];
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    
    //7.设置关键帧间隔为30（GOP长度）
    int frameInterval = 30;
    CFNumberRef frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
    
    //8.准备编码
    VTCompressionSessionPrepareToEncodeFrames(self.compressionSession);
}

- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    //1.将sampleBuffer转成imageBuffer
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    //2.根据当前帧数，创建CMTime
    CMTime presentationTimeStamp = CMTimeMake(self.frameID++, 1000);
    VTEncodeInfoFlags flags;
    
    //3.开始编码该帧数据
    OSStatus statusCode = VTCompressionSessionEncodeFrame(self.compressionSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          kCMTimeInvalid,
                                                          NULL, (__bridge void * _Nullable)(self), &flags);
    if (statusCode == noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    }
}


// 编码完成回调
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    //1.判断状态是否是没有报错
    if (status != noErr) {
        return;
    }
    
    //2.根据传入的参数获取对象
    VideoEncoder* encoder = (__bridge VideoEncoder*)outputCallbackRefCon;

    //3.判断是否是关键帧
    bool isKeyframe = !CFDictionaryContainsKey(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true),0), kCMSampleAttachmentKey_NotSync);
    //判断当前帧是否为关键帧
    //获取sps & pps数据
    if(isKeyframe){
        //获取编码后的信息
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        //获取SPS信息
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );

        // 获取PPS信息
        size_t pparameterSetSize, pparameterSetCount;
        const uint8_t *pparameterSet;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
        
        //装sps/pps转成NSData，以便写入文件
        NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
        NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
        
        //写入文件
        [encoder gotSpsPps:sps pps:pps];
    }
    
    // 获取数据块
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        
        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            // Read the NAL unit length
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder gotEncodedData:data isKeyFrame:isKeyframe];
            
            // 移动到写一个块，转成NALU单元
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    // 1.拼接NALU的header
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    
    // 2.将NALU的头&NALU的体写入文件
    [self.fileHandle writeData:ByteHeader];
    [self.fileHandle writeData:sps];
    [self.fileHandle writeData:ByteHeader];
    [self.fileHandle writeData:pps];
    
}
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"gotEncodedData %d", (int)[data length]);
    if (self.fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [self.fileHandle writeData:ByteHeader];
        [self.fileHandle writeData:data];
    }
}


- (void)endEncode {
    VTCompressionSessionCompleteFrames(self.compressionSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(self.compressionSession);
    CFRelease(self.compressionSession);
    self.compressionSession = NULL;
}


@end
