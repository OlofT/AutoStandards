//
//  ___FILENAME___
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  Copyright ___YEAR___ ___ORGANIZATIONNAME___. All rights reserved.
//

#import "___FILEBASENAME___.h"

@interface ___FILEBASENAMEASIDENTIFIER___ ()
{
    CGRect tempButtonRect;
}

@property (nonatomic) UIButton *tempButton;

@end

@implementation ___FILEBASENAMEASIDENTIFIER___

- (void)viewDidLoad
{
    [super viewDidLoad];
    [AutoStandards color:AutoColorMainViewBackground forView:self.view method:AutoSetValueBackgroundColor];
    [AutoStandards createViews:self superView:self.view];
}

- (void) tempButtonSetup:(AutoButtonSetupBlock)setupBlock
{
    /*
    here is an example of how you can auto-create highlighted images
     
    UIImage *image = [UIImage imageNamed:@"close"];
    AutoStandards *standards = [AutoStandards sharedInstance];
    UIImage *highlight = [standards tintedImage:image color:[standards standardColor:AutoColorHighlightColor]];
    image = [standards tintedImage:image];
    setupBlock(image, highlight, nil, NO);
    */
    
    setupBlock(nil, nil, @"Click me!", NO);
}

- (void)viewWillLayoutSubviews
{
    int margin = 5;
    int buttonHeight = 44;
    
    CGRect remainder = self.view.bounds;
	CGFloat topBarOffset = 0;
	if (@available(iOS 11.0, *))
	{
		topBarOffset = self.safeAreaInsets.top;
	}
	else if ([self respondsToSelector:@selector(topLayoutGuide)])
    {
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			
        topBarOffset = self.topLayoutGuide.length;
			
		#pragma clang diagnostic pop
    }
	if (topBarOffset)
		AutoSliceRect(&remainder, topBarOffset, CGRectMinYEdge);
    
    CGRectDivide(remainder, &tempButtonRect, &remainder, buttonHeight, CGRectMinYEdge);
    tempButtonRect = CGRectInset(tempButtonRect, margin, margin);
    
    [AutoStandards setFrames:self];
}

- (void) tempButtonPressed
{
    NSLog(@"clicking the temp button!");
}

@end