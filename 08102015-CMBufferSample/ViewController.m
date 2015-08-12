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


- (IBAction)actionLpcm2Mp4:(id)sender {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Hello" ofType:@"pcm"];
    NSLog(@"Mark0811: filePath %@", filePath);
    //------------------------------------------------------------------------------------ Read Data
    NSFileHandle *fileHandler = [NSFileHandle fileHandleForReadingAtPath:filePath];
    
    char *tmpBytes = malloc(32768);
    memset(tmpBytes, 0, 32768);
    NSData *tmpData = [NSData dataWithBytes:tmpBytes length:32768];
    
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
    CMAudioSampleBufferCreateWithPacketDescriptions(kCFAllocatorDefault, blockBR, YES, NULL, NULL, afdr, 32768/4, CMTimeMake(0, 44100), NULL, &sampleBR);
    NSLog(@"Mark0811: sampleBR %@", sampleBR);
    
    //------------------------------------------------------------------------------------ Gen Out.mp4
    NSError *error;
    NSURL *fileDir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *fileUrl2 = [fileDir URLByAppendingPathComponent:@"test2.mp4"];
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
    
    NSDictionary *outputSettings = @{AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatMPEG4AAC],
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
    BOOL isEnd = NO;
    CMTime presentT;
    int presentTV = 0;
    while (!isEnd) {
        while (astWI.isReadyForMoreMediaData) {
            tmpData = [fileHandler readDataOfLength:32768];
            
            if (!tmpData) {
                [fileHandler closeFile];
                isEnd = YES;
                break;
            }

            CMBlockBufferReplaceDataBytes(tmpData.bytes, blockBR, 0, tmpData.length);
            presentT = CMSampleBufferGetPresentationTimeStamp(sampleBR);
            presentTV += CMSampleBufferGetNumSamples(sampleBR);
            presentT.value = presentTV;
            CMSampleBufferSetOutputPresentationTimeStamp(sampleBR, presentT);
            [astWI appendSampleBuffer:sampleBR];
            
            NSLog(@"Mark0811: Loop %lu [%lld, %d, %d, %lld]", (unsigned long)tmpData.length, presentT.value, presentT.timescale, presentT.flags, presentT.epoch);
            if (tmpData.length < 32768) {
                [fileHandler closeFile];
                isEnd = YES;
                break;
            }
            
            usleep(2 * 1000);   // Test on iPhone4s/6, No need this sleep.
            // if usleep(1 * 1000), or no sleep,  simulator will have duplicated audio played;
            // Tip: Adding TimeStamp do no favor for it.
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
//        NSData *tmpData = [fh readDataOfLength:32768];
//        NSLog(@"Mark0811: Read Loop %lu", (unsigned long)tmpData.length);
//        
//        //-------------------------------------------------------------------------------- Create CMBlockBufferRef
//        
//        
//        if (!tmpData || tmpData.length < 32768){
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
    char tmp[32768] = {0};
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
                NSLog(@"Mark0810: Loop [%d, %d, %d, %d]", presentT.value, presentT.timescale, presentT.flags, presentT.epoch);
                
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
