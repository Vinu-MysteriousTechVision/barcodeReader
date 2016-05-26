//
//  ComInnovatureBarcodereaderViewProxy.m
//  BarcodeReader
//
//  Created by vinu on 23/05/16.
//
//

#import "ComInnovatureBarcodereaderViewProxy.h"

@interface ComInnovatureBarcodereaderViewProxy () <AVCaptureMetadataOutputObjectsDelegate,
UIImagePickerControllerDelegate> {
    
    AVCaptureSession           *_session;
    AVCaptureDevice            *_defaultDevice;
    AVCaptureDeviceInput       *_defaultDeviceInput;
    AVCaptureDevice            *_frontDevice;
    AVCaptureDeviceInput       *_frontDeviceInput;
    
    AVCaptureMetadataOutput    *_output;
    AVCaptureVideoPreviewLayer *_prevLayer;
    
    UIView                     *_highlightView;
    UIView                     *_borderView;
    UIView                     *cameraPreviewLayer;
    float                       scaninningHotSpot_W;
    float                       scaninningHotSpot_H;
    float                       scaninningHotSpot_X;
    float                       scaninningHotSpot_Y;
    float                       scaninningHotSpot_LW;
    float                       scaninningHotSpot_LH;
}

@property (nonatomic) AVCaptureSession          *session;
@property (nonatomic) dispatch_queue_t          sessionQueue;
@property (nonatomic, assign) BOOL              isRestrictActiveScanningArea;
@property (nonatomic, retain) NSMutableArray    *aryBarCodeTypes;
@property (nonatomic, assign) BOOL              isSessionCreated;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;

@end


@implementation ComInnovatureBarcodereaderViewProxy

@synthesize session = _session;
@synthesize isRestrictActiveScanningArea = _isRestrictActiveScanningArea;
@synthesize aryBarCodeTypes = _aryBarCodeTypes;
@synthesize isSessionCreated = _isSessionCreated;

-(void)_destroy
{
    // Make sure to release the callback objects
    RELEASE_TO_NIL(successCallback);
    RELEASE_TO_NIL(cancelCallback);
    
    [super _destroy];
}

-(id)init
{
    // This is the designated initializer method and will always be called
    // when the view proxy is created.
    NSLog(@"[VIEWPROXY LIFECYCLE EVENT] init");
    
    // create a queue for av fountation
    dispatch_queue_t sessionQueue = dispatch_get_main_queue();
    [self setSessionQueue:sessionQueue];
    
    scaninningHotSpot_W = 0.8f;
    scaninningHotSpot_H = 0.4f;
    scaninningHotSpot_X = 0.05f;
    scaninningHotSpot_Y = 0.5f;
    scaninningHotSpot_LW = 0.6f;
    scaninningHotSpot_LH = 0.4f;
    
    _isSessionCreated = NO;
    _isRestrictActiveScanningArea = YES;
    _aryBarCodeTypes = [[NSMutableArray alloc] initWithArray:[self defaultMetaDataObjectTypes]];
    [self setQRCodePreviewLayer];
    
    return [super init];
}

- (NSArray *)defaultMetaDataObjectTypes {
    NSMutableArray *types = [@[AVMetadataObjectTypeQRCode,
                               AVMetadataObjectTypeUPCECode,
                               AVMetadataObjectTypeCode39Code,
                               AVMetadataObjectTypeCode39Mod43Code,
                               AVMetadataObjectTypeEAN13Code,
                               AVMetadataObjectTypeEAN8Code,
                               AVMetadataObjectTypeCode93Code,
                               AVMetadataObjectTypeCode128Code,
                               AVMetadataObjectTypePDF417Code,
                               AVMetadataObjectTypeAztecCode] mutableCopy];
    
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1) {
        [types addObjectsFromArray:@[AVMetadataObjectTypeInterleaved2of5Code,
                                     AVMetadataObjectTypeITF14Code,
                                     AVMetadataObjectTypeDataMatrixCode
                                     ]];
    }
    
    return types;
}

- (void)setQRCodePreviewLayer {
    
    cameraPreviewLayer = [self view];
    
    // create a highlight view to show around the scanned code
    _highlightView = [[UIView alloc] init];
    
    // set autoresizing mask for high light view
    _highlightView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleLeftMargin |
    UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleBottomMargin;
    
    // set green color for hightliht view layer
    _highlightView.layer.borderColor = [UIColor greenColor].CGColor;
    
    // set highlight view layer border width
    _highlightView.layer.borderWidth = 6;
    
    // add highlight view as subview to camerapreview layer
    [cameraPreviewLayer addSubview:_highlightView];
    
    // draw scan area in screen
    [self setUILayout];
    
    if (!_isRestrictActiveScanningArea) {
        [_borderView setHidden:YES];
    } else {
        [_borderView setHidden:NO];
    }
}

- (void)setUILayout {
    
    // Setting border to the reader view
    UIColor *borderColor = [UIColor whiteColor];
    
    // create a highlight view to show around the scanned code
    _borderView = [[UIView alloc] init];
    
    // set autoresizing mask for high light view
    _borderView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleLeftMargin |
    UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleBottomMargin;
    
    // set green color for hightliht view layer
    _borderView.layer.borderColor = borderColor.CGColor;
    
    // set highlight view layer border width
    _borderView.layer.borderWidth = 2.0f;
    
    // set highlight view layer border corner
    _borderView.layer.cornerRadius = 10.0f;
    
    // add highlight view as subview to camerapreview layer
    [cameraPreviewLayer addSubview:_borderView];
}

- (void) setScanningLine {
    
    // Adding the red line through the center of the reader view
    CGSize parentSize = _borderView.frame.size;
    CGPoint point = CGPointMake(18, _borderView.frame.size.height / 2.0f);
    UIView  *lineView = [[UIView alloc] initWithFrame:CGRectMake(point.x, point.y, parentSize.width - 36.0f, 1.5f)];
    
    [lineView setBackgroundColor:[UIColor redColor]];
    [_borderView addSubview:lineView];
}

#pragma mark - public methods

#pragma mark - callBackMethod

- (void)setSuccessCallback:(id)args {
    
    NSLog(@"[KROLLDEMO] setRequestData called: %@", args);
    
    successCallback = [args retain];
    
    NSLog(@"[KROLLDEMO] setRequestData registered");
}

- (id)isTorchAvailable {
    return NUMBOOL(_defaultDevice.hasTorch);
}

#pragma mark

- (void)setUPCEEnabled:(id)enabled {
    
    BOOL isEnabled = [enabled boolValue];
    if(!isEnabled) {
        if ([_aryBarCodeTypes containsObject:AVMetadataObjectTypeUPCECode]) {
            [_aryBarCodeTypes removeObject:AVMetadataObjectTypeUPCECode];
        }
    }
}

- (void)setCode39Enabled:(id)enabled {
    
    BOOL isEnabled = [enabled boolValue];
    if(!isEnabled) {
        if ([_aryBarCodeTypes containsObject:AVMetadataObjectTypeCode39Code]) {
            [_aryBarCodeTypes removeObject:AVMetadataObjectTypeCode39Code];
        }
    }
}

- (void)setCode39Mod43Enabled:(id)enabled {
    
    BOOL isEnabled = [enabled boolValue];
    if(!isEnabled) {
        if ([_aryBarCodeTypes containsObject:AVMetadataObjectTypeCode39Mod43Code]) {
            [_aryBarCodeTypes removeObject:AVMetadataObjectTypeCode39Mod43Code];
        }
    }
}

- (void)setCode93Enabled:(id)enabled {
    
    BOOL isEnabled = [enabled boolValue];
    if(!isEnabled) {
        if ([_aryBarCodeTypes containsObject:AVMetadataObjectTypeCode93Code]) {
            [_aryBarCodeTypes removeObject:AVMetadataObjectTypeCode93Code];
        }
    }
}

- (void)setCode128Enabled:(id)enabled {
    
    BOOL isEnabled = [enabled boolValue];
    if(!isEnabled) {
        if ([_aryBarCodeTypes containsObject:AVMetadataObjectTypeCode128Code]) {
            [_aryBarCodeTypes removeObject:AVMetadataObjectTypeCode128Code];
        }
    }
}

- (void)setEAN8Enabled:(id)enabled {
    
    BOOL isEnabled = [enabled boolValue];
    if(!isEnabled) {
        if ([_aryBarCodeTypes containsObject:AVMetadataObjectTypeEAN8Code]) {
            [_aryBarCodeTypes removeObject:AVMetadataObjectTypeEAN8Code];
        }
    }
}
- (void)setEAN13Enabled:(id)enabled {
    BOOL isEnabled = [enabled boolValue];
    if(!isEnabled) {
        if ([_aryBarCodeTypes containsObject:AVMetadataObjectTypeEAN13Code]) {
            [_aryBarCodeTypes removeObject:AVMetadataObjectTypeEAN13Code];
        }
    }
}

- (void)setPDF417Enabled:(id)enabled {
    
    BOOL isEnabled = [enabled boolValue];
    if(!isEnabled) {
        if ([_aryBarCodeTypes containsObject:AVMetadataObjectTypePDF417Code]) {
            [_aryBarCodeTypes removeObject:AVMetadataObjectTypePDF417Code];
        }
    }
}

- (void)setQRCodeEnabled:(id)enabled {
    
    BOOL isEnabled = [enabled boolValue];
    if(!isEnabled) {
        if ([_aryBarCodeTypes containsObject:AVMetadataObjectTypeQRCode]) {
            [_aryBarCodeTypes removeObject:AVMetadataObjectTypeQRCode];
        }
    }
}

- (void)setAztecEnabled:(id)enabled {
    
    BOOL isEnabled = [enabled boolValue];
    if(!isEnabled) {
        if ([_aryBarCodeTypes containsObject:AVMetadataObjectTypeAztecCode]) {
            [_aryBarCodeTypes removeObject:AVMetadataObjectTypeAztecCode];
        }
    }
}

#pragma mark

/**
 * @brief Prevents the camera from entering a standby state after the barcode picker object is deallocated.
 *
 * This will free up resources (power, memory) after each scan that are used by the camera in standby mode,
 * but also increases the startup time and time to successful scan for subsequent scans. We recommend disabling
 * the standby state only when your app is typically in the foreground for a long time and barcodes are
 * scanned very infrequently.
 */
- (void)disableStandbyState:(id)value {
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

#pragma mark - scanning functionalities

- (void)reset:(id)value {
    
    dispatch_async([self sessionQueue], ^{
        // reset hightlight view frame
        _highlightView.frame = CGRectZero;
    });
}

- (void)startScanning:(id)value {
    if (_isSessionCreated) {
        [self resumeScanning];
        return;
    }
    
    //Check whether the camera is available or not
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        NSString *mediaType = AVMediaTypeVideo;
        
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
            if (granted) {
                // create views for detecting qr and bar code
                [self AVFoundationStartSession];
            } else {
                
                // sendCallBack, camera access denied
                [cancelCallback call:@[@{@"error" : @"Access denied"}] thisObject:nil];
            }
        }];
    } else {
        
        // sendCallBack, camera not avaiable
        [cancelCallback call:@[@{@"error" : @"Camera not available"}] thisObject:nil];
    }
}

- (void)stopScanning:(id)value {
    
    [self pauseScanning];
}

/*
 @method switchTorch
 
 @abstract
 ON or OFF the flash light for all devices/cameras that support a torch.
 
 @discussion
 By default it is OFF.
 */
- (void)switchTorchOn:(id)value {
    
    BOOL bSwitchTorchOn = [[value firstObject] boolValue];//[TiUtils boolValue:[value firstObject] def:NO];
    if (bSwitchTorchOn) {
        NSLog(@"[info] bSwitchTorch ON");
    } else {
        NSLog(@"[info] bSwitchTorch OFF");
        
    }
    
    [self toggleTorch];
}

#pragma mark - Audio Video methods

// call method below from viewWilAppear
- (void)AVFoundationStartSession {
    
    dispatch_async([self sessionQueue], ^{
        
        if (_session == nil) {
            // create session
            _session = [[AVCaptureSession alloc] init];
            _session.sessionPreset = AVCaptureSessionPresetHigh;
        }
        
        NSError *error = nil;
        // get device
        _defaultDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        // Locks the configuration
        BOOL success = [_defaultDevice lockForConfiguration:&error];
        if (success) {
            
            float zoomFactor = _defaultDevice.activeFormat.videoZoomFactorUpscaleThreshold;
            [_defaultDevice setVideoZoomFactor:zoomFactor];
            
            // set auto focus
            if ([_defaultDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                _defaultDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            }
            
            if ([_defaultDevice isAutoFocusRangeRestrictionSupported]) {
                // Restricts the autofocus to near range (new in iOS 7)
                [_defaultDevice setAutoFocusRangeRestriction:AVCaptureAutoFocusRangeRestrictionNear];
            }
            
            if ([_defaultDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
                [_defaultDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            
            [self configureCameraForHighestFrameRate:_defaultDevice];
        }
        // unlocks the configuration
        [_defaultDevice unlockForConfiguration];
        
        // create input device
        _defaultDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_defaultDevice error:&error];
        
        if (_defaultDeviceInput) {
            if (![_session.inputs containsObject:_defaultDeviceInput]) {
                for (AVCaptureInput *input in _session.inputs) {
                    [_session removeInput:input];
                }
                // add input to session
                [_session addInput:_defaultDeviceInput];
            }
        }
        else {
            NSLog(@"Error: %@", error);
        }
        
        for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
            if (device.position == AVCaptureDevicePositionFront) {
                _frontDevice = device;
            }
        }
        
        if (_frontDevice) {
            _frontDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_frontDevice error:nil];
        }
        
        if (_output == nil) {
            // create output
            _output = [[AVCaptureMetadataOutput alloc] init];
        }
        // set properties to input
        [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        
        if (![_session.outputs containsObject:_output]) {
            // add output to session
            [_session addOutput:_output];
        }
        
        // Still image capture configuration
        self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        self.stillImageOutput.outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG};
        
        if ([self.stillImageOutput isStillImageStabilizationSupported]) {
            self.stillImageOutput.automaticallyEnablesStillImageStabilizationWhenAvailable = YES;
        }
        
        if ([self.stillImageOutput respondsToSelector:@selector(isHighResolutionStillImageOutputEnabled)]) {
            self.stillImageOutput.highResolutionStillImageOutputEnabled = YES;
        }
        [_session addOutput:self.stillImageOutput];
        
        
        _output.metadataObjectTypes = [_output availableMetadataObjectTypes];
        // get preview layer
        _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
        // set frame for preview layer
        _prevLayer.frame = cameraPreviewLayer.bounds;
        // set property video gravity for preview layer
        _prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        if ([_prevLayer.connection isVideoOrientationSupported]) {
            _prevLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
        
        // get center point
        CGPoint point = CGPointMake(cameraPreviewLayer.frame.size.width * scaninningHotSpot_X, cameraPreviewLayer.frame.size.height * scaninningHotSpot_Y);
        
        // set borderView frame for showing scan area
        _borderView.frame = CGRectMake(point.x, point.y - 100.0f, cameraPreviewLayer.frame.size.width - (point.x * 2), 200.0f);
        if([_defaultDevice isFocusPointOfInterestSupported] &&
           [_defaultDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            CGRect screenRect = [cameraPreviewLayer.layer bounds];
            double screenWidth = screenRect.size.width;
            double screenHeight = screenRect.size.height;
            double focus_x = point.x/screenWidth;
            double focus_y = point.y/screenHeight;
            if([_defaultDevice lockForConfiguration:nil]) {
                [_defaultDevice setFocusPointOfInterest:CGPointMake(focus_x, focus_y)];
                if ([_defaultDevice isLowLightBoostSupported]) {
                    [_defaultDevice setAutomaticallyEnablesLowLightBoostWhenAvailable:YES];
                }
                [_defaultDevice unlockForConfiguration];
            }
        }
        
        // This method will show a line at the center of the scan area
        // [self setScanningLine];
        
        if (!_isRestrictActiveScanningArea) {
            // convert scan area rect to that needed by AV foundation
            CGRect visibleMetadataOutputRect = [_prevLayer metadataOutputRectOfInterestForRect:cameraPreviewLayer.frame];
            // set area of interest
            _output.rectOfInterest = visibleMetadataOutputRect;
        } else {
            // convert scan area rect to that needed by AV foundation
            CGRect visibleMetadataOutputRect = [_prevLayer metadataOutputRectOfInterestForRect:_borderView.frame];
            // set area of interest
            _output.rectOfInterest = visibleMetadataOutputRect;
        }
        
        // add preview layer as sub layer
        [cameraPreviewLayer.layer addSublayer:_prevLayer];
        // start running session
        [_session startRunning];
        // bring highlight view to front
        [cameraPreviewLayer bringSubviewToFront:_highlightView];
        // bring borderview to front
        [cameraPreviewLayer bringSubviewToFront:_borderView];
        
        _isSessionCreated = YES;
        
        [_session commitConfiguration];
    });
}

// call method below from viewDidDisappear
- (void)AVFoundationStopSession {
    
    dispatch_async([self sessionQueue], ^{
        _isSessionCreated = NO;
        [self reset:NULL];
        [[self session] stopRunning];
        _session = nil;
        _output = nil;
        _defaultDeviceInput = nil;

    });
}

- (void)pauseScanning {
    
    dispatch_async([self sessionQueue], ^{
        [[self session] stopRunning];
        // reset hightlight view frame
        _highlightView.frame = CGRectZero;
    });
}

- (void)resumeScanning {
    
    dispatch_async([self sessionQueue], ^{
        [_session startRunning];
    });
}

- (void)configureCameraForHighestFrameRate:(AVCaptureDevice *)device
{
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    for ( AVCaptureDeviceFormat *format in [device formats] ) {
        for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            if ( range.maxFrameRate > bestFrameRateRange.maxFrameRate ) {
                bestFormat = format;
                bestFrameRateRange = range;
            }
        }
    }
    if ( bestFormat ) {
        if ( [device lockForConfiguration:NULL] == YES ) {
            device.activeFormat = bestFormat;
            device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration;
            device.activeVideoMaxFrameDuration = bestFrameRateRange.minFrameDuration;
            [device unlockForConfiguration];
        }
    }
}

#pragma mark - delegate methods

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    CGRect highlightViewRect = CGRectZero;
    AVMetadataMachineReadableCodeObject *barCodeObject;
    NSString                            *detectionString = nil;
    NSArray                             *barCodeTypes = _aryBarCodeTypes;
    
    for (AVMetadataObject *metadata in metadataObjects) {
        for (NSString *type in barCodeTypes) {
            if ([metadata.type isEqualToString:type]) {
                
                barCodeObject = (AVMetadataMachineReadableCodeObject*)[_prevLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject*)metadata];
                highlightViewRect = barCodeObject.bounds;
                // set highlight view frame
                _highlightView.frame = highlightViewRect;
                detectionString = [(AVMetadataMachineReadableCodeObject*)metadata stringValue];
                break;
            }
        }
        
        if ([detectionString isKindOfClass:[NSString class]]) {
            
            if ([self _hasListeners:@"resultValue"]) {
                
                [self fireEvent:@"resultValue" withObject:@{@"barcode" : detectionString}];
            }
            [successCallback call:@[@{@"barcode" : detectionString}] thisObject:nil];
            
            break;
        }
        else {
            /* detetct other the string*/
            break;
        }
    }
    // set highlight view frame
    _highlightView.frame = highlightViewRect;
}

#pragma mark - Checking the Reader Availabilities

- (BOOL)isAvailable
{
    @autoreleasepool {
        AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        if (!captureDevice) {
            return NO;
        }
        
        NSError *error;
        AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
        
        if (!deviceInput || error) {
            return NO;
        }
        
        return YES;
    }
}

- (BOOL)supportsMetadataObjectTypes:(NSArray *)metadataObjectTypes
{
    if (![self isAvailable]) {
        return NO;
    }
    
    @autoreleasepool {
        // Setup components
        AVCaptureDevice *captureDevice    = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
        AVCaptureMetadataOutput *output   = [[AVCaptureMetadataOutput alloc] init];
        AVCaptureSession *session         = [[AVCaptureSession alloc] init];
        
        [session addInput:deviceInput];
        [session addOutput:output];
        
        if (metadataObjectTypes == nil || metadataObjectTypes.count == 0) {
            // Check the QRCode metadata object type by default
            metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
        }
        
        for (NSString *metadataObjectType in metadataObjectTypes) {
            if (![output.availableMetadataObjectTypes containsObject:metadataObjectType]) {
                return NO;
            }
        }
        
        return YES;
    }
}

- (void)toggleTorch {
    
    AVCaptureInput* currentCameraInput = [_session.inputs objectAtIndex:0];
    
    //Get new input
    if(((AVCaptureDeviceInput*)currentCameraInput).device.position == AVCaptureDevicePositionBack) {
        NSError *error = nil;
        
        [_session beginConfiguration];
        [_defaultDevice lockForConfiguration:&error];
        
        if (error == nil) {
            AVCaptureTorchMode mode = _defaultDevice.torchMode;
            
            _defaultDevice.torchMode = mode == AVCaptureTorchModeOn ? AVCaptureTorchModeOff : AVCaptureTorchModeOn;
        }
        
        [_defaultDevice unlockForConfiguration];
        [_session commitConfiguration];
    }
}

@end
