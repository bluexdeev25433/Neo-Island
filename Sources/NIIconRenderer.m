#import "NIIconRenderer.h"

@implementation NIIconRenderer

+ (UIImage *)imageForSymbol:(NSString *)symbol pointSize:(CGFloat)pointSize {
    if (@available(iOS 13.0, *)) {
        UIImage *systemImage = [UIImage systemImageNamed:symbol
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightSemibold]];
        if (systemImage) return [systemImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    CGSize size = CGSizeMake(pointSize + 8, pointSize + 8);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, UIColor.whiteColor.CGColor);
    CGContextSetFillColorWithColor(context, UIColor.whiteColor.CGColor);
    CGContextSetLineWidth(context, MAX(1.5, pointSize * 0.1));
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);

    if ([symbol containsString:@"battery"]) {
        CGRect body = CGRectMake(3, 6, pointSize, pointSize * 0.62);
        CGContextAddPath(context, [UIBezierPath bezierPathWithRoundedRect:body cornerRadius:3].CGPath);
        CGContextStrokePath(context);
        CGContextFillRect(context, CGRectMake(CGRectGetMaxX(body) + 1, 10, 3, pointSize * 0.3));
        if ([symbol containsString:@"bolt"]) {
            CGContextMoveToPoint(context, pointSize * 0.58, 8);
            CGContextAddLineToPoint(context, pointSize * 0.42, pointSize * 0.53);
            CGContextAddLineToPoint(context, pointSize * 0.6, pointSize * 0.53);
            CGContextAddLineToPoint(context, pointSize * 0.44, pointSize * 0.9);
            CGContextStrokePath(context);
        } else {
            CGContextFillRect(context, CGRectMake(6, 9, pointSize * 0.6, pointSize * 0.45));
        }
    } else if ([symbol containsString:@"music"] || [symbol containsString:@"waveform"]) {
        if ([symbol containsString:@"waveform"]) {
            for (NSInteger index = 0; index < 5; index++) {
                CGFloat x = 5 + index * pointSize * 0.23;
                CGFloat amplitude = pointSize * (index == 2 ? 0.72 : (index % 2 ? 0.48 : 0.32));
                CGContextMoveToPoint(context, x, size.height / 2 - amplitude / 2);
                CGContextAddLineToPoint(context, x, size.height / 2 + amplitude / 2);
            }
            CGContextStrokePath(context);
        } else {
            CGContextAddEllipseInRect(context, CGRectMake(4, pointSize * 0.72, pointSize * 0.3, pointSize * 0.23));
            CGContextFillPath(context);
            CGContextMoveToPoint(context, pointSize * 0.36, pointSize * 0.83);
            CGContextAddLineToPoint(context, pointSize * 0.36, 5);
            CGContextAddLineToPoint(context, pointSize * 0.94, 7);
            CGContextAddLineToPoint(context, pointSize * 0.94, pointSize * 0.68);
            CGContextStrokePath(context);
        }
    } else if ([symbol containsString:@"wifi"] || [symbol containsString:@"antenna"]) {
        CGPoint center = CGPointMake(size.width / 2, size.height - 3);
        for (NSInteger index = 1; index <= 3; index++) {
            CGFloat radius = pointSize * index * 0.2;
            CGContextMoveToPoint(context, center.x + radius * cos(M_PI * 1.2), center.y + radius * sin(M_PI * 1.2));
            CGContextAddArc(context, center.x, center.y, radius, M_PI * 1.2, M_PI * 1.8, 0);
        }
        CGContextStrokePath(context);
        CGContextFillEllipseInRect(context, CGRectMake(center.x - 1.5, center.y - 1.5, 3, 3));
    } else if ([symbol containsString:@"backward"] || [symbol containsString:@"forward"]) {
        BOOL backward = [symbol containsString:@"backward"];
        CGFloat center = size.width / 2;
        CGFloat direction = backward ? -1 : 1;
        for (NSInteger index = 0; index < 2; index++) {
            CGFloat x = center + direction * (index ? 3 : -4);
            CGContextMoveToPoint(context, x + direction * 3, 5);
            CGContextAddLineToPoint(context, x - direction * 3, size.height / 2);
            CGContextAddLineToPoint(context, x + direction * 3, size.height - 5);
            CGContextClosePath(context);
            CGContextFillPath(context);
        }
        CGFloat barX = backward ? size.width - 4 : 4;
        CGContextFillRect(context, CGRectMake(barX, 5, 2, size.height - 10));
    } else if ([symbol containsString:@"play"]) {
        CGContextMoveToPoint(context, 7, 5);
        CGContextAddLineToPoint(context, pointSize, size.height / 2);
        CGContextAddLineToPoint(context, 7, size.height - 5);
        CGContextClosePath(context);
        CGContextFillPath(context);
    } else if ([symbol containsString:@"pause"]) {
        CGContextFillRect(context, CGRectMake(6, 5, pointSize * 0.28, pointSize));
        CGContextFillRect(context, CGRectMake(pointSize * 0.68, 5, pointSize * 0.28, pointSize));
    } else if ([symbol containsString:@"speaker"]) {
        CGContextMoveToPoint(context, 4, pointSize * 0.4);
        CGContextAddLineToPoint(context, pointSize * 0.38, pointSize * 0.4);
        CGContextAddLineToPoint(context, pointSize * 0.7, 5);
        CGContextAddLineToPoint(context, pointSize * 0.7, pointSize + 3);
        CGContextAddLineToPoint(context, pointSize * 0.38, pointSize * 0.6);
        CGContextAddLineToPoint(context, 4, pointSize * 0.6);
        CGContextClosePath(context);
        CGContextStrokePath(context);
    } else if ([symbol containsString:@"timer"] || [symbol containsString:@"clock"]) {
        CGRect clock = CGRectMake(4, 5, pointSize, pointSize);
        CGContextStrokeEllipseInRect(context, clock);
        CGContextMoveToPoint(context, CGRectGetMidX(clock), CGRectGetMidY(clock));
        CGContextAddLineToPoint(context, CGRectGetMidX(clock), CGRectGetMinY(clock) + 4);
        CGContextMoveToPoint(context, CGRectGetMidX(clock), CGRectGetMidY(clock));
        CGContextAddLineToPoint(context, CGRectGetMaxX(clock) - 4, CGRectGetMidY(clock));
        CGContextStrokePath(context);
    } else if ([symbol containsString:@"headphone"] || [symbol containsString:@"airpods"]) {
        CGRect arc = CGRectMake(4, 4, pointSize, pointSize);
        CGContextAddArc(context, CGRectGetMidX(arc), CGRectGetMidY(arc), pointSize / 2, M_PI, 0, 0);
        CGContextMoveToPoint(context, 4, pointSize / 2 + 4);
        CGContextAddLineToPoint(context, 4, pointSize * 0.8);
        CGContextAddLineToPoint(context, 8, pointSize * 0.8);
        CGContextMoveToPoint(context, pointSize + 4, pointSize / 2 + 4);
        CGContextAddLineToPoint(context, pointSize + 4, pointSize * 0.8);
        CGContextAddLineToPoint(context, pointSize, pointSize * 0.8);
        CGContextStrokePath(context);
    } else {
        CGContextStrokeEllipseInRect(context, CGRectMake(4, 4, pointSize, pointSize));
    }

    UIImage *fallback = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [fallback imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@end