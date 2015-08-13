//
//  ViewController.m
//  08102015-CMBufferSample
//
//  Created by apexis on 15/8/10.
//  Copyright (c) 2015年 apexis. All rights reserved.
//

#import "ViewController.h"
@import AVFoundation;
@import MediaPlayer;

// if < 32768, actionAF2lpcm() will memory overflow
#define MAX_BLOCK_SAMPLE_NUM 32768

@interface ViewController ()
{
    MPMoviePlayerController *_player;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

// Read Data from png file and pcm file, write to a mp4
- (IBAction)actionPngPcm2Mp4:(id)sender {
    //------------------------------------------------------------------------------------ open png file
    char pixelArr[4*100*100] = {0};
    CGImageRef cgImg = [[UIImage imageNamed:@"test.png"] CGImage];
    CVPixelBufferRef pixelBR = NULL;
    
    CVPixelBufferCreateWithBytes(NULL, CGImageGetWidth(cgImg), CGImageGetHeight(cgImg), kCVPixelFormatType_32ARGB, pixelArr, 4*CGImageGetWidth(cgImg), NULL, NULL, NULL, &pixelBR);
    NSLog(@"Mark0813: pixelBR %@", pixelBR);
    
    //------------------------------------------------------------------------------------ open pcm file
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Hello" ofType:@"pcm"];
    NSLog(@"Mark0811: filePath %@", filePath);
    
    //------------------------------------------------------------------------------------ read png
    CVPixelBufferLockBaseAddress(pixelBR, 0);
    void *pixelBA = CVPixelBufferGetBaseAddress(pixelBR);
    CGColorSpaceRef colorSR = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextR = CGBitmapContextCreate(pixelBA, 100, 100, 8, 4 * 100, colorSR, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextR, CGRectMake(0, 0, CGImageGetWidth(cgImg), CGImageGetHeight(cgImg)), cgImg);
    CGColorSpaceRelease(colorSR);
    CGContextRelease(contextR);
    NSData *tmpData_png = [NSData dataWithBytes:pixelBA length:4 * 100 * 100];
    NSLog(@"Mark0812: imgData [%lu]%@",(unsigned long)tmpData_png.length, tmpData_png);
    CVPixelBufferUnlockBaseAddress(pixelBR, 0);
    
    size_t pixelBPR = CVPixelBufferGetBytesPerRow(pixelBR);
    size_t pixelSize = CVPixelBufferGetDataSize(pixelBR);
    size_t pixelH = CVPixelBufferGetHeight(pixelBR);
    size_t pixelW = CVPixelBufferGetWidth(pixelBR);
    NSLog(@"Mark0812: Pixel [%zu, %zu, %zu, %zu]", pixelBPR, pixelSize, pixelW, pixelH);
    
//    NSData *tmpData2 = [NSData dataWithBytes:pixelBA length:pixelSize];
//    NSLog(@"Mark0812: imgData2 [%zu]%@", pixelSize, tmpData2);
    
    //------------------------------------------------------------------------------------ read pcm
    NSFileHandle *fileHandler = [NSFileHandle fileHandleForReadingAtPath:filePath];
    
    char *tmpBytes = malloc(MAX_BLOCK_SAMPLE_NUM);
    memset(tmpBytes, 0, MAX_BLOCK_SAMPLE_NUM);
    NSData *tmpData_pcm = [NSData dataWithBytes:tmpBytes length:MAX_BLOCK_SAMPLE_NUM];
    
    //------------------------------------------------------------------------------------ Create Audio CMBlockBufferRef
    CMBlockBufferRef blockBR;
    CMBlockBufferCreateEmpty(NULL, 0, kCMBlockBufferAssureMemoryNowFlag, &blockBR);
    CMBlockBufferCreateWithMemoryBlock(NULL, tmpBytes, tmpData_pcm.length, NULL, NULL, 0, tmpData_pcm.length, kCMBlockBufferAssureMemoryNowFlag, &blockBR);
    NSLog(@"Mark0811: Get block %@", blockBR);
    
    //------------------------------------------------------------------------------------ Gen Out.mp4
    NSError *error;
    NSURL *fileDir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *fileUrl2 = [fileDir URLByAppendingPathComponent:@"test4.mp4"];
    NSLog(@"Mark0810: url2 %@", fileUrl2);
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileUrl2.path]) {
        [[NSFileManager defaultManager] removeItemAtPath:fileUrl2.path error:&error];
        NSLog(@"Mark0810: remove %@", error);
    };
    
    //------------------------------------------------------------------------------------ Create Writer
    error = nil;
    AVAssetWriter *astW = [AVAssetWriter assetWriterWithURL:fileUrl2 fileType:AVFileTypeMPEG4 error:&error];
    if (error) {
        NSLog(@"Mark0810: error %@", error);
        exit(2);
    }
    NSLog(@"Mark0810: astW %@", astW);
    
//    //------------------------------------------------------------------------------------ Create Video CMSampleBufferRef
//    
//    CMVideoFormatDescriptionRef videoFDR;
//    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBR, &videoFDR);
//    NSLog(@"Mark0812: videoFDR %@", videoFDR);
    
    //------------------------------------------------------------------------------------ Create WriterInput_V
    NSDictionary *outputSettings_v = [NSDictionary dictionaryWithObjectsAndKeys:
                                    AVVideoCodecH264, AVVideoCodecKey,
                                    [NSNumber numberWithInt:100], AVVideoWidthKey,
                                    [NSNumber numberWithInt:100], AVVideoHeightKey,
                                    nil];
    
    AVAssetWriterInput *astWI_v = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings_v];
    astWI_v.expectsMediaDataInRealTime = NO;
    if ([astW canAddInput:astWI_v]) {
        [astW addInput:astWI_v];
    }else{
        NSLog(@"Mark0812: Err add Input_v");
        exit(7);
    }
    
    //------------------------------------------------------------------------------------ Create WriterInput_PixelAdaptor
    NSDictionary *pixelAttri = @{
                                      (NSString*)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB],
                                      (NSString*)kCVPixelBufferWidthKey : [NSNumber numberWithUnsignedInt:100],
                                      (NSString*)kCVPixelBufferHeightKey : [NSNumber numberWithUnsignedInt:100]
                                      };
    AVAssetWriterInputPixelBufferAdaptor *astWIPBA = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:astWI_v sourcePixelBufferAttributes:pixelAttri];

    //------------------------------------------------------------------------------------ Create WriterInput_A
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    
    NSDictionary *outputSettings_a = @{AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatMPEG4AAC],
                                     AVSampleRateKey : [NSNumber numberWithFloat:44100.0],
                                     AVChannelLayoutKey : [NSData dataWithBytes:&acl length:sizeof(acl)]};
    
    AVAssetWriterInput *astWI_a = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:outputSettings_a];
    astWI_a.expectsMediaDataInRealTime = NO;
    if (![astW canAddInput:astWI_a]) {
        NSLog(@"Mark0813: Err add Input_a");
        exit(4);
    }
    [astW addInput:astWI_a];
    NSLog(@"Mark0810: inputs %@", astW.inputs);
    
    //------------------------------------------------------------------------------------ Start Writing
    [astW startWriting];
    [astW startSessionAtSourceTime:CMTimeMake(0, 44100)];
    
    __block BOOL shouldKeepRunning = YES;
    __block BOOL isEnd_v = NO;
    __block BOOL isEnd_a = NO;
    
    void (^checkEnd)() = ^{
        
        if (isEnd_a) {
            isEnd_v = isEnd_a;
        }
        
        if (isEnd_v && isEnd_a) {
            [astW finishWritingWithCompletionHandler:^{
                shouldKeepRunning = NO;
                NSLog(@"Mark0813: Writing finished");
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // Trigger RunLoop Check
                });
            }];
        }
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        CMTime presentT;
        CMTimeValue presentV = 0;
        NSData *tmpData;
        BOOL appendRst;
        
        //------------------------------------------------------------------------------------ Create Audio CMSampleBufferRef
        CMSampleBufferRef sampleBR_a;
        CMAudioFormatDescriptionRef afdr;
        
        AudioStreamBasicDescription asbd = {0};
        asbd.mSampleRate = 44100;
        asbd.mFormatID = kAudioFormatLinearPCM;
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        asbd.mBytesPerPacket = 4;
        asbd.mFramesPerPacket = 1;
        asbd.mBytesPerFrame = 4;
        asbd.mChannelsPerFrame = 2;
        asbd.mBitsPerChannel = 16;
        
        CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd, 0, NULL, 0, NULL, NULL, &afdr);
        
        //------------------------------------------------------------------------------------ Write A
        while (!isEnd_a) {
            while (astWI_a.isReadyForMoreMediaData) {
                tmpData = [fileHandler readDataOfLength:MAX_BLOCK_SAMPLE_NUM];
                
                if (!tmpData) {
                    [fileHandler closeFile];
                    isEnd_a = YES;
                    checkEnd();
                    break;
                }
                
                CMAudioSampleBufferCreateWithPacketDescriptions(kCFAllocatorDefault,
                                                                blockBR,
                                                                YES,
                                                                NULL,
                                                                NULL,
                                                                afdr,
                                                                MAX_BLOCK_SAMPLE_NUM / 4,
                                                                CMTimeMake(presentV, 44100),
                                                                NULL,
                                                                &sampleBR_a);
                presentT = CMSampleBufferGetPresentationTimeStamp(sampleBR_a);
                presentV += CMSampleBufferGetNumSamples(sampleBR_a);
                CMBlockBufferReplaceDataBytes(tmpData.bytes, blockBR, 0, tmpData.length);
                presentT = CMSampleBufferGetPresentationTimeStamp(sampleBR_a);
                
                appendRst = [astWI_a appendSampleBuffer:sampleBR_a];
                NSLog(@"Mark0811: Loop_a %lld %d", presentT.value,  appendRst);
                
                if (tmpData.length < MAX_BLOCK_SAMPLE_NUM) {
                    [fileHandler closeFile];
                    isEnd_a = YES;
                    checkEnd();
                    break;
                }
                
                usleep(4 * 1000);   // Test on iPhone4s/6, No need this sleep.
                // if usleep(1 * 1000), or no sleep,  simulator will have duplicated audio played;
            }
            
            usleep(100 * 1000);
            NSLog(@"Mark0811: sleep_a");
        }
        
        NSLog(@"End Writing_a");
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
//        CMSampleBufferRef sampleBR_v;
//        CMTime presentT;
        BOOL appendRst;
        
//        CMSampleTimingInfo sampleTI;
//        sampleTI.presentationTimeStamp = CMTimeMake(0, 44100);
//        sampleTI.decodeTimeStamp = CMTimeMake(0, 44100);
//        sampleTI.duration = CMTimeMake(1764, 44100);
        
        CMTime presentT = CMTimeMake(0, 44100);
        CMTime durationT = CMTimeMake(1764, 44100);
        
        //------------------------------------------------------------------------------------ write V
        while (!isEnd_v) {
            while ([astWI_v isReadyForMoreMediaData]) {
//                CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBR, YES, NULL, NULL, videoFDR, &sampleTI, &sampleBR_v);
//                presentT = CMSampleBufferGetPresentationTimeStamp(sampleBR_v);
//                appendRst = [astWI_v appendSampleBuffer:sampleBR_v];
//                NSLog(@"Mark0813: Loop_v %lld %d", presentT.value, appendRst);
                
                appendRst = [astWIPBA appendPixelBuffer:pixelBR withPresentationTime:presentT];
                NSLog(@"Mark0813: Loop_v %lld %d", presentT.value, appendRst);
                
                presentT = CMTimeAdd(presentT, durationT);
                
                if (isEnd_v) {
                    break;
                }
            }
            
            usleep(200 * 1000);
            NSLog(@"Mark0813: sleep_v");
        }
        
        NSLog(@"Mark0813: End Writing_v");
    });
    
    while (shouldKeepRunning && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    
    NSLog(@"Mark0813: Wait End");
    
    //------------------------------------------------------------------------------------ Test Output file
    _player = [[MPMoviePlayerController alloc] initWithContentURL:fileUrl2];
    [_player prepareToPlay];
    [_player.view setFrame:self.view.bounds];
    [self.view addSubview:_player.view];
    [_player play];
}

// Read Data from png file, write it to a mp4
- (IBAction)actionPng2Mp4:(id)sender {
    //------------------------------------------------------------------------------------ read png
    UIImage *image = [UIImage imageNamed:@"test.png"];
    CGImageRef cgImg = [image CGImage];
    
    //------------------------------------------------------------------------------------ create CVPixelBufferRef
    CVPixelBufferRef pixelBR;
//    CVReturn cvr = CVPixelBufferCreate(kCFAllocatorDefault, 100, 100, kCVPixelFormatType_32ARGB, NULL, &pixelBR);  // this method get wrong bytesPerRow.
    char *pixelTmpBuffer = malloc(4 * 100 * 100);
    CVReturn cvr = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, 100, 100, kCVPixelFormatType_32ARGB, pixelTmpBuffer, 4*100, NULL, NULL, NULL, &pixelBR);
    NSLog(@"Mark0812: cvr %d %@", cvr, pixelBR);
    
    
    //------------------------------------------------------------------------------------ Write data to a frame
    CVPixelBufferLockBaseAddress(pixelBR, 0);
    void *pixelBA = CVPixelBufferGetBaseAddress(pixelBR);
    CGColorSpaceRef colorSR = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextR = CGBitmapContextCreate(pixelBA, 100, 100, 8, 4 * 100, colorSR, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextR, CGRectMake(0, 0, CGImageGetWidth(cgImg), CGImageGetHeight(cgImg)), cgImg);
    CGColorSpaceRelease(colorSR);
    CGContextRelease(contextR);
//    NSData *tmpData = [NSData dataWithBytes:pixelBA length:4 * 100 * 100];
//    NSLog(@"Mark0812: imgData [%lu]%@",(unsigned long)tmpData.length, tmpData);
    CVPixelBufferUnlockBaseAddress(pixelBR, 0);
    
    size_t pixelBPR = CVPixelBufferGetBytesPerRow(pixelBR);
    size_t pixelSize = CVPixelBufferGetDataSize(pixelBR);
    size_t pixelH = CVPixelBufferGetHeight(pixelBR);
    size_t pixelW = CVPixelBufferGetWidth(pixelBR);
    NSLog(@"Mark0812: Pixel [%zu, %zu, %zu, %zu]", pixelBPR, pixelSize, pixelW, pixelH);
    
//    NSData *tmpData2 = [NSData dataWithBytes:pixelBA length:pixelSize];
//    NSLog(@"Mark0812: imgData2 [%zu]%@", pixelSize, tmpData2);
    
    //------------------------------------------------------------------------------------ Gen Out.mp4
    NSError *error;
    NSURL *fileDir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *fileUrl2 = [fileDir URLByAppendingPathComponent:@"test3.mp4"];
    NSLog(@"Mark0810: path3 %@", fileUrl2.path);
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileUrl2.path]) {
        [[NSFileManager defaultManager] removeItemAtPath:fileUrl2.path error:&error];
        NSLog(@"Mark0810: remove %@", error);
    };
    
    //------------------------------------------------------------------------------------ Create Writer
    error = nil;
    AVAssetWriter *astW = [AVAssetWriter assetWriterWithURL:fileUrl2 fileType:AVFileTypeMPEG4 error:&error];
    if (error) {
        NSLog(@"Mark0810: error %@", error);
        exit(2);
    }
    NSLog(@"Mark0810: astW %@", astW);
    
    //------------------------------------------------------------------------------------ Create CMSampleBufferRef
    
    CMVideoFormatDescriptionRef videoFDR;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBR, &videoFDR);
    NSLog(@"Mark0812: videoFDR %@", videoFDR);
    
    
    CMSampleTimingInfo sampleTI;
    sampleTI.presentationTimeStamp = CMTimeMake(0, 12800);
    sampleTI.decodeTimeStamp = CMTimeMake(0, 12800);
    sampleTI.duration = CMTimeMake(512, 12800);
    
//    CMSampleBufferRef sampleBR;
    
    //------------------------------------------------------------------------------------ Create Writer Input
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:100], AVVideoWidthKey,
                                   [NSNumber numberWithInt:100], AVVideoHeightKey,
                                   nil];
    
    AVAssetWriterInput *astWI = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
    if ([astW canAddInput:astWI]) {
        [astW addInput:astWI];
    }else{
        NSLog(@"Mark0812: Err add Input");
        exit(7);
    }
    
    //-----
    NSDictionary *pixelAttributes = @{
        (NSString*)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB],
        (NSString*)kCVPixelBufferWidthKey : [NSNumber numberWithUnsignedInt:100],
        (NSString*)kCVPixelBufferHeightKey : [NSNumber numberWithUnsignedInt:100]
                                                  };
    AVAssetWriterInputPixelBufferAdaptor *astWIPBA = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:astWI sourcePixelBufferAttributes:pixelAttributes];
    
    [astW startWriting];
    [astW startSessionAtSourceTime:CMTimeMake(0, 12800)];
    
    //------------------------------------------------------------------------------------ Write Process
    
    BOOL isEnd = NO;
    BOOL appendRst;

    while (!isEnd) {
        while ([astWI isReadyForMoreMediaData]) {
///////////////////////////////////////////////// Using appendSampleBuffer, only succeed on simultor. failed on true iphone
//
//            OSStatus createRst;  // define out of Loop
//            CMTime presentT;  // define out of Loop
//            createRst = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBR, YES, NULL, NULL, videoFDR, &sampleTI, &sampleBR);
//            
//            static dispatch_once_t onceToken;
//            dispatch_once(&onceToken, ^{
//                NSLog(@"Mark0812: sampleBuffer %@", sampleBR);
//            });
//            
//            presentT = CMSampleBufferGetPresentationTimeStamp(sampleBR);
//            appendRst = [astWI appendSampleBuffer:sampleBR];
//            NSLog(@"Mark0813: Loop %lld %d", presentT.value, appendRst);
//
///////////////////////////////////////////////// Using appendPixelBuffer, succeed both on simultor or true iphone
            
            appendRst = [astWIPBA appendPixelBuffer:pixelBR withPresentationTime:sampleTI.presentationTimeStamp];
            NSLog(@"Mark0813: Loop %lld %d",sampleTI.presentationTimeStamp.value, appendRst);
            
            sampleTI.presentationTimeStamp = CMTimeAdd(sampleTI.presentationTimeStamp, sampleTI.duration);
            sampleTI.decodeTimeStamp = CMTimeAdd(sampleTI.decodeTimeStamp, sampleTI.duration);
            
            // fps 12800/512, frameCount = 100, mp4 duration = frameCount / fps = 4s
            static int count = 0;
            count++;
            if (count % 100 == 0) {
                isEnd = YES;
                break;
            }
            
            if (!appendRst) {
                NSLog(@"Mark0813: Append Failed %ld", (long)astW.error.code);
                exit(8);
            }
        }
        
        usleep(200 * 1000);
        NSLog(@"Mark0812: Sleep");
    }
    
    __block BOOL shouldKeepRunning = YES;
    [astW finishWritingWithCompletionHandler:^{
        NSLog(@"Mark0812: Writing Finished. [%@]", astW.error);
        shouldKeepRunning = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Trigger RunLoop Check
        });
    }];
    
    while (shouldKeepRunning && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    
    free(pixelTmpBuffer);
    NSLog(@"Mark0812: Wait End");
    
    //------------------------------------------------------------------------------------ Test Output file
    _player = [[MPMoviePlayerController alloc] initWithContentURL:fileUrl2];
    [_player prepareToPlay];
    [_player.view setFrame:self.view.bounds];
    [self.view addSubview:_player.view];
    [_player play];
}

// Read Mp4's Video Sample
- (IBAction)actionReadMp4sVS:(id)sender {
    NSError *error;
    //------------------------------------------------------------------------------------ Get Data
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test3" ofType:@"mp4"];
    NSLog(@"Mark0810: path %@", filePath);
    
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    AVAsset *ast = [AVAsset assetWithURL:fileUrl];
    NSLog(@"Mark0810: ast %@", ast);
    
    AVAssetReader *astR = [AVAssetReader assetReaderWithAsset:ast error:&error];
    if (!astR) {
        NSLog(@"Mark0810: astR %@", error);
        exit(1);
    }
    NSLog(@"Mark0810: astR %@", astR);
    
    //------------------------------------------------------------------------------------  Create Reader
    AVAssetReaderTrackOutput *astRTO;
    __block AVAssetTrack *astT;
    
    NSLog(@"Mark0810: astTs %@", ast.tracks);
    astT = [[ast tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    astRTO = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:astT outputSettings:nil];
    NSLog(@"Mark0810: astRTO %@", astRTO);
    
    if (![astR canAddOutput:astRTO]) {
        exit(3);
    }
    [astR addOutput:astRTO];
    NSLog(@"Mark0810: astRTO %@", astR);
    
    [astR startReading];
    
    //------------------------------------------------------------------------------------ Read Data
    CMSampleBufferRef sampleBR;
    size_t sampleSize = 0;
    CMTime presentT;
    while ((sampleBR = [astRTO copyNextSampleBuffer])) {
        sampleSize = CMSampleBufferGetTotalSampleSize(sampleBR);
        presentT = CMSampleBufferGetPresentationTimeStamp(sampleBR);
        NSLog(@"Mark0812: Loop %zu [%lld %d %d %lld]", sampleSize, presentT.value, presentT.timescale, presentT.flags, presentT.epoch);
        
        if (sampleSize > 0) {
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                NSLog(@"Mark0812: V sampleBR %@", sampleBR);
                
                CVImageBufferRef imageBR = CMSampleBufferGetImageBuffer(sampleBR);
                NSLog(@"Mark0812: V imageBR %@", imageBR);
                
                CMBlockBufferRef blockBR = CMSampleBufferGetDataBuffer(sampleBR);
                NSLog(@"Mark0812: V blockBR %@", blockBR);
            });
        }
    }
    NSLog(@"Mark0812: readEnd");
}

// LinearPCM convert to Mp4
- (IBAction)actionLpcm2Mp4:(id)sender {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Hello" ofType:@"pcm"];
    NSLog(@"Mark0811: filePath %@", filePath);
    //------------------------------------------------------------------------------------ Read Data
    NSFileHandle *fileHandler = [NSFileHandle fileHandleForReadingAtPath:filePath];
    
    char *tmpBytes = malloc(MAX_BLOCK_SAMPLE_NUM);
    memset(tmpBytes, 0, MAX_BLOCK_SAMPLE_NUM);
    NSData *tmpData = [NSData dataWithBytes:tmpBytes length:MAX_BLOCK_SAMPLE_NUM];
    
    //------------------------------------------------------------------------------------ Create CMBlockBufferRef
    CMBlockBufferRef blockBR;
    CMBlockBufferCreateEmpty(NULL, 0, kCMBlockBufferAssureMemoryNowFlag, &blockBR);
    CMBlockBufferCreateWithMemoryBlock(NULL, tmpBytes, tmpData.length, NULL, NULL, 0, tmpData.length, kCMBlockBufferAssureMemoryNowFlag, &blockBR);
    NSLog(@"Mark0811: Get block %@", blockBR);
    
    //------------------------------------------------------------------------------------ Create CMSampleBufferRef
    CMSampleBufferRef sampleBR;
    CMAudioFormatDescriptionRef afdr;
    
    AudioStreamBasicDescription asbd = {0};
    asbd.mSampleRate = 44100;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbd.mBytesPerPacket = 4;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = 4;
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel = 16;
    
    CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd, 0, NULL, 0, NULL, NULL, &afdr);
    
    CMAudioSampleBufferCreateWithPacketDescriptions(kCFAllocatorDefault,
                                                    blockBR,
                                                    YES,
                                                    NULL,
                                                    NULL,
                                                    afdr,
                                                    MAX_BLOCK_SAMPLE_NUM / 4,
                                                    CMTimeMake(0, 44100),
                                                    NULL,
                                                    &sampleBR);
    
    //------------------------------------------------------------------------------------ Gen Out.mp4
    NSError *error;
    NSURL *fileDir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *fileUrl2 = [fileDir URLByAppendingPathComponent:@"test2.mp4"];
    NSLog(@"Mark0810: url2 %@", fileUrl2);
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileUrl2.path]) {
        [[NSFileManager defaultManager] removeItemAtPath:fileUrl2.path error:&error];
        NSLog(@"Mark0810: remove %@", error);
    };
    
    //------------------------------------------------------------------------------------ Create Writer
    error = nil;
    AVAssetWriter *astW = [AVAssetWriter assetWriterWithURL:fileUrl2 fileType:AVFileTypeMPEG4 error:&error];
    if (error) {
        NSLog(@"Mark0810: error %@", error);
        exit(2);
    }
    NSLog(@"Mark0810: astW %@", astW);
    
    //------------------------------------------------------------------------------------ Create WriterInput
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    
    NSDictionary *outputSettings = @{AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatMPEG4AAC],
                       AVSampleRateKey : [NSNumber numberWithFloat:44100.0],
                       AVChannelLayoutKey : [NSData dataWithBytes:&acl length:sizeof(acl)]};
    
    AVAssetWriterInput *astWI = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:outputSettings];
    if (![astW canAddInput:astWI]) {
        exit(4);
    }
    [astW addInput:astWI];
    NSLog(@"Mark0810: inputs %@", astW.inputs);
    
    [astW startWriting];
    [astW startSessionAtSourceTime:CMTimeMake(0, 44100)];
    
    //------------------------------------------------------------------------------------ Write process
    BOOL isEnd = NO;
    while (!isEnd) {
        while (astWI.isReadyForMoreMediaData) {
            tmpData = [fileHandler readDataOfLength:MAX_BLOCK_SAMPLE_NUM];
            
            if (!tmpData) {
                [fileHandler closeFile];
                isEnd = YES;
                break;
            }
            
            CMBlockBufferReplaceDataBytes(tmpData.bytes, blockBR, 0, tmpData.length);
            
///////////// Beta1: Audio TimeStamp is invalid to edit directly/////////////////////////////////////////////////
//
//            OSStatus ost;
//            presentT = CMSampleBufferGetPresentationTimeStamp(sampleBR);
//            presentT_v += CMSampleBufferGetNumSamples(sampleBR);
//            presentT.value = presentT_v;
//            ost = CMSampleBufferSetOutputPresentationTimeStamp(sampleBR, presentT);
//            presentT = CMSampleBufferGetPresentationTimeStamp(sampleBR);
//            // Log Print Rst: presentT no change
//
///////////// Beta2: Using Create SampleBuffer instead///////////////////////////////////////////////////////////
//
//            // define out of Loop
//            CMTime presentT;
//            int presentT_v = 0; // if set 44100 * 5, audio will start play at fifth second.
//
//            // Loop process
//            CMAudioSampleBufferCreateWithPacketDescriptions(kCFAllocatorDefault,
//                                                            blockBR,
//                                                            YES,
//                                                            NULL,
//                                                            NULL,
//                                                            afdr,
//                                                            MAX_BLOCK_SAMPLE_NUM / 4,
//                                                            CMTimeMake(presentT_v, 44100),
//                                                            NULL,
//                                                            &sampleBR);
//            presentT_v += CMSampleBufferGetNumSamples(sampleBR);
//            presentT = CMSampleBufferGetPresentationTimeStamp(sampleBR);
//
////////////// Beta3: Can Print timestamp rightly, but if change Time.value in middle, play time still not change.
            
            NSLog(@"Mark0811: Loop %lu", (unsigned long)tmpData.length);
            
            [astWI appendSampleBuffer:sampleBR];
            
            if (tmpData.length < MAX_BLOCK_SAMPLE_NUM) {
                [fileHandler closeFile];
                isEnd = YES;
                break;
            }
            
            usleep(2 * 1000);   // Test on iPhone4s/6, No need this sleep.
            // if usleep(1 * 1000), or no sleep,  simulator will have duplicated audio played;
        }
        
        usleep(100 * 1000);
        NSLog(@"Mark0811: sleep");
    }
    
    [astW finishWritingWithCompletionHandler:^{
        NSLog(@"Mark0811: write finished.");
    }];
    
    free(tmpBytes);
    
    //------------------------------------------------------------------------------------ Test Output file
    _player = [[MPMoviePlayerController alloc] initWithContentURL:fileUrl2];
    [_player prepareToPlay];
    [_player.view setFrame:self.view.bounds];
    [self.view addSubview:_player.view];
    [_player play];
    
//////////////////////////////////////////////////////////////////////////////////////////   Just Read Code : For Beta Test
//
//    __block BOOL shouldKeepRunning = YES;
//    [fileHandler setReadabilityHandler:^(NSFileHandle *fh) {
//        NSData *tmpData = [fh readDataOfLength:MAX_BLOCK_SAMPLE_NUM];
//        NSLog(@"Mark0811: Read Loop %lu", (unsigned long)tmpData.length);
//        
//        //-------------------------------------------------------------------------------- Create CMBlockBufferRef
//        
//        
//        if (!tmpData || tmpData.length < MAX_BLOCK_SAMPLE_NUM){
//            [fh closeFile];
//            shouldKeepRunning = NO;
//            NSLog(@"Mark0811: Read End");
//        }
//        
//    }];
//    while (shouldKeepRunning && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
//    NSLog(@"Mark0811: action End");
//
///////////////////////////////////////////////////////////////////////////////////////////
}

// Audio File convert to LinearPCM file
- (IBAction)actionAF2Lpcm:(id)sender {
    NSError *error;
    //------------------------------------------------------------------------------------ Gen Data
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Hello" ofType:@"m4r"];
    NSLog(@"Mark0810: path %@", filePath);
    
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    AVAsset *ast = [AVAsset assetWithURL:fileUrl];
    NSLog(@"Mark0810: ast %@", ast);
    
    AVAssetReader *astR = [AVAssetReader assetReaderWithAsset:ast error:&error];
    if (!astR) {
        NSLog(@"Mark0810: astR %@", error);
        exit(1);
    }
    NSLog(@"Mark0810: astR %@", astR);
    
    //------------------------------------------------------------------------------------  Create Reader
    AVAssetReaderTrackOutput *astRTO;
    __block AVAssetTrack *astT;
    NSDictionary *outputSettings;
    
    NSLog(@"Mark0810: astTs %@", ast.tracks);
    astT = [[ast tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    outputSettings = @{AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatLinearPCM]};
    
    astRTO = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:astT outputSettings:outputSettings];
    NSLog(@"Mark0810: astRTO %@", astRTO);
    
    if (![astR canAddOutput:astRTO]) {
        exit(3);
    }
    [astR addOutput:astRTO];
    NSLog(@"Mark0810: astRTO %@", astR);
    
    [astR startReading];
    
    //------------------------------------------------------------------------------------ Read Data
    CMSampleBufferRef sampleBR;
    CMBlockBufferRef blockBR;
    char tmp[MAX_BLOCK_SAMPLE_NUM] = {0};
    NSData *tmpData = nil;
    size_t tmpLength = 0;
    NSURL *fileDir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *fileUrl2 = [fileDir URLByAppendingPathComponent:@"test.pcm"];
    
    NSLog(@"Mark0810: url2 %@", fileUrl2);
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileUrl2.path]) {
        [[NSFileManager defaultManager] removeItemAtPath:fileUrl2.path error:&error];
        NSLog(@"Mark0810: remove %@", error);
    };
    [[NSFileManager defaultManager] createFileAtPath:fileUrl2.path contents:nil attributes:nil];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:fileUrl2.path];
    
    while ((sampleBR = [astRTO copyNextSampleBuffer])) {
        blockBR = CMSampleBufferGetDataBuffer(sampleBR);
        tmpLength = CMBlockBufferGetDataLength(blockBR);
        NSLog(@"Mark0811: Loop %zu", tmpLength);
        CMBlockBufferCopyDataBytes(blockBR, 0, tmpLength, tmp);
        tmpData = [NSData dataWithBytes:tmp length:tmpLength];
        [fileHandle writeData:tmpData];
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"Mark0811: sample %@", tmpData);
        });
    }
    [fileHandle closeFile];
    NSLog(@"Mark0811: Read End");
    
    return;
}

// Audio File to Mp4
- (IBAction)actionAF2Mp4:(id)sender {
    NSError *error;
    //------------------------------------------------------------------------------------ Gen Data
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Hello" ofType:@"m4r"];
    NSLog(@"Mark0810: path %@", filePath);
    
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    AVAsset *ast = [AVAsset assetWithURL:fileUrl];
    NSLog(@"Mark0810: ast %@", ast);
    
    AVAssetReader *astR = [AVAssetReader assetReaderWithAsset:ast error:&error];
    if (!astR) {
        NSLog(@"Mark0810: astR %@", error);
        exit(1);
    }
    NSLog(@"Mark0810: astR %@", astR);
    
    //------------------------------------------------------------------------------------  Create Reader
    AVAssetReaderTrackOutput *astRTO;
    __block AVAssetTrack *astT;
    NSDictionary *outputSettings;
    
    NSLog(@"Mark0810: astTs %@", ast.tracks);
    astT = [[ast tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    outputSettings = @{AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatLinearPCM]};
    
    astRTO = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:astT outputSettings:outputSettings];
    NSLog(@"Mark0810: astRTO %@", astRTO);
    
    if (![astR canAddOutput:astRTO]) {
        exit(3);
    }
    [astR addOutput:astRTO];
    NSLog(@"Mark0810: astRTO %@", astR);
    
    [astR startReading];
    
    //------------------------------------------------------------------------------------ Read Data
    CMSampleBufferRef sampleBR;
    //    sampleBR = [astRTO copyNextSampleBuffer];
    //    NSLog(@"Mark0810: sampleBR %@", sampleBR);
    
    //------------------------------------------------------------------------------------ Gen Out.mp4
    NSURL *fileDir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *fileUrl2 = [fileDir URLByAppendingPathComponent:@"test.mp4"];
    NSLog(@"Mark0810: url2 %@", fileUrl2);
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileUrl2.path]) {
        [[NSFileManager defaultManager] removeItemAtPath:fileUrl2.path error:&error];
        NSLog(@"Mark0810: remove %@", error);
    };
    
    error = nil;
    AVAssetWriter *astW = [AVAssetWriter assetWriterWithURL:fileUrl2 fileType:AVFileTypeMPEG4 error:&error];
    if (error) {
        NSLog(@"Mark0810: error %@", error);
        exit(2);
    }
    NSLog(@"Mark0810: astW %@", astW);
    //------------------------------------------------------------------------------------ Create Writer
    
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    
    outputSettings = @{AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatMPEG4AAC],
                       AVSampleRateKey : [NSNumber numberWithFloat:44100.0],
                       AVChannelLayoutKey : [NSData dataWithBytes:&acl length:sizeof(acl)]};
    
    AVAssetWriterInput *astWI = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:outputSettings];
    if (![astW canAddInput:astWI]) {
        exit(4);
    }
    [astW addInput:astWI];
    NSLog(@"Mark0810: inputs %@", astW.inputs);
    
    astWI.expectsMediaDataInRealTime = NO;
    [astW startWriting];
    [astW startSessionAtSourceTime:CMTimeMake(0, 44100)];
    //------------------------------------------------------------------------------------ Write process
    
    __block BOOL isEnd = NO;
    CMTime presentT;
    BOOL isOk;
    while (!isEnd) {
        while ([astWI isReadyForMoreMediaData]) {
            sampleBR = [astRTO copyNextSampleBuffer];
            if (!sampleBR) {
                isEnd = YES;
                break;
            }else{
                presentT = CMSampleBufferGetPresentationTimeStamp(sampleBR);
                isOk = [astWI appendSampleBuffer:sampleBR];
                if (!isOk) {
                    NSLog(@"Mark0810: appendErr %@", astW.error);
                    sleep(1);
                }
                NSLog(@"Mark0810: Loop [%lld, %d, %d, %lld]", presentT.value, presentT.timescale, presentT.flags, presentT.epoch);
                
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    NSLog(@"Mark0811: sampleBR %@", sampleBR);
                });
            }
        }
        usleep(100*1000);
        NSLog(@"Mark0810: Sleep");
    }
    
    [astW finishWritingWithCompletionHandler:^{
        NSLog(@"Mark0810: Writing Finished.");
    }];
    
    //------------------------------------------------------------------------------------ Test Output file
    _player = [[MPMoviePlayerController alloc] initWithContentURL:fileUrl2];
    [_player prepareToPlay];
    [_player.view setFrame:self.view.bounds];
    [self.view addSubview:_player.view];
    [_player play];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
