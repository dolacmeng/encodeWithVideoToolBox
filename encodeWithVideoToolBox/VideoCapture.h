//
//  VideoCapture.h
//  encodeWithVideoToolBox
//
//  Created by 许伟杰 on 2019/1/25.
//  Copyright © 2019 JackXu. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoCapture : NSObject

- (void)startCapture:(UIView *)preview;

- (void)stopCapture;

@end

NS_ASSUME_NONNULL_END
