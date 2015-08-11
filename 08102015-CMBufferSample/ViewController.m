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
    while (!isEnd) {
        while ([astWI isReadyForMoreMediaData]) {
            sampleBR = [astRTO copyNextSampleBuffer];
            if (!sampleBR) {
                isEnd = YES;
                break;
            }else{
                BOOL status = [astWI appendSampleBuffer:sampleBR];
                if (!status) {
                    NSLog(@"Mark0810: appendErr %@", astW.error);
                    sleep(1);
                }
                NSLog(@"Mark: Loop");
            }
        }
        usleep(100*1000);
        NSLog(@"Sleep");
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
