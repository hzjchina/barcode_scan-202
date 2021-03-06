//
// Created by Matthew Smith on 11/7/17.
//

#import "BarcodeScannerViewController.h"
#import <MTBBarcodeScanner/MTBBarcodeScanner.h>
#import "ScannerOverlay.h"


@implementation BarcodeScannerViewController {
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    CGRect bounds = [UIScreen mainScreen].bounds;
    CGRect reversedBounds = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.height, bounds.size.width);
    self.previewView.bounds = reversedBounds;
    self.previewView.frame = reversedBounds;
    [self.scanRect stopAnimating];
    [self.scanRect removeFromSuperview];
    [self setupScanRect:reversedBounds];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)setupScanRect:(CGRect)bounds {
    self.scanRect = [[ScannerOverlay alloc] initWithFrame:bounds];
    self.scanRect.translatesAutoresizingMaskIntoConstraints = NO;
    self.scanRect.backgroundColor = UIColor.clearColor;
    [self.view addSubview:_scanRect];
    [self.view addConstraints:[NSLayoutConstraint
                               constraintsWithVisualFormat:@"V:[scanRect]"
                               options:NSLayoutFormatAlignAllBottom
                               metrics:nil
                               views:@{@"scanRect": _scanRect}]];
    [self.view addConstraints:[NSLayoutConstraint
                               constraintsWithVisualFormat:@"H:[scanRect]"
                               options:NSLayoutFormatAlignAllBottom
                               metrics:nil
                               views:@{@"scanRect": _scanRect}]];
    [_scanRect startAnimating];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.previewView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.previewView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_previewView];
    [self.view addConstraints:[NSLayoutConstraint
            constraintsWithVisualFormat:@"V:[previewView]"
                                options:NSLayoutFormatAlignAllBottom
                                metrics:nil
                                  views:@{@"previewView": _previewView}]];
    [self.view addConstraints:[NSLayoutConstraint
            constraintsWithVisualFormat:@"H:[previewView]"
                                options:NSLayoutFormatAlignAllBottom
                                metrics:nil
                                  views:@{@"previewView": _previewView}]];
    [self setupScanRect:self.view.bounds];
    self.scanner = [[MTBBarcodeScanner alloc] initWithPreviewView:_previewView];
    //self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]].resourcePath stringByAppendingString:@"/barcode_scan.bundle"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"page_back" inBundle:[NSBundle bundleWithPath:bundlePath] compatibleWithTraitCollection:nil ] style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    
  [self updateFlashButton];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.scanner.isScanning) {
        [self.scanner stopScanning];
    }
    [MTBBarcodeScanner requestCameraPermissionWithSuccess:^(BOOL success) {
        if (success) {
            [self startScan];
        } else {
          [self.delegate barcodeScannerViewController:self didFailWithErrorCode:@"PERMISSION_NOT_GRANTED"];
          [self dismissViewControllerAnimated:NO completion:nil];
        }
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.scanner stopScanning];
    [super viewWillDisappear:animated];
    if ([self isFlashOn]) {
        [self toggleFlash:NO];
    }
}

- (void)startScan {
    NSError *error;
    [self.scanner startScanningWithResultBlock:^(NSArray<AVMetadataMachineReadableCodeObject *> *codes) {
        [self.scanner stopScanning];
         AVMetadataMachineReadableCodeObject *code = codes.firstObject;
        if (code) {
            [self.delegate barcodeScannerViewController:self didScanBarcodeWithResult:code.stringValue];
            [self dismissViewControllerAnimated:NO completion:nil];
        }
    } error:&error];
}

- (void)cancel {
    [self.delegate barcodeScannerViewController:self didFailWithErrorCode:@"USER_CANCELED"];
    [self dismissViewControllerAnimated:true completion:nil];
}

- (void)updateFlashButton {
    if (!self.hasTorch) {
        return;
    }
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]].resourcePath stringByAppendingString:@"/barcode_scan.bundle"];
    if (self.isFlashOn) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"flash_off" inBundle:[NSBundle bundleWithPath:bundlePath]
                                                                              compatibleWithTraitCollection:nil ]
                                                                                  style:UIBarButtonItemStylePlain
                                                  
                                                                                 target:self action:@selector(toggle)];
        
        //self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Flash Off"
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"flash_on" inBundle:[NSBundle bundleWithPath:bundlePath]
                                                                              compatibleWithTraitCollection:nil]
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self action:@selector(toggle)];
        
        //self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Flash On"
    }
    
}

- (void)toggle {
    [self toggleFlash:!self.isFlashOn];
    [self updateFlashButton];
}

- (BOOL)isFlashOn {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device) {
        return device.torchMode == AVCaptureFlashModeOn || device.torchMode == AVCaptureTorchModeOn;
    }
    return NO;
}

- (BOOL)hasTorch {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device) {
        return device.hasTorch;
    }
    return false;
}

- (void)toggleFlash:(BOOL)on {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) return;

    NSError *err;
    if (device.hasFlash && device.hasTorch) {
        [device lockForConfiguration:&err];
        if (err != nil) return;
        if (on) {
            device.flashMode = AVCaptureFlashModeOn;
            device.torchMode = AVCaptureTorchModeOn;
        } else {
            device.flashMode = AVCaptureFlashModeOff;
            device.torchMode = AVCaptureTorchModeOff;
        }
        [device unlockForConfiguration];
    }
}


@end
