#import <UIKit/UIKit.h>
#import <opencv2/opencv2.hpp>

@interface UIImage (OpenCVWrapper)
- (void)convertToMat:(cv::Mat *)pMat alphaExists:(bool)alphaExists;
@end
