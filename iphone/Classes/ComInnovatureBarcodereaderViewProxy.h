//
//  ComInnovatureBarcodereaderViewProxy.h
//  BarcodeReader
//
//  Created by vinu on 23/05/16.
//
//

#import <Foundation/Foundation.h>
#import "TiViewProxy.h"

@interface ComInnovatureBarcodereaderViewProxy : TiViewProxy {
    
    int cameraFacingPrefValue;
    
@private
    // The JavaScript callbacks (KrollCallback objects)
    KrollCallback *successCallback;
    KrollCallback *cancelCallback;
}

@end
