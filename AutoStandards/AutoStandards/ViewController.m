//
//  ViewController.m
//  AutoStandards
//
//  Created by Olof Thorén on 2016-08-17.
//  Copyright © 2016 Aggressive Development AB. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic) UIButton *changeModeButton;
@property (nonatomic) UILabel *startLabel;
@property (nonatomic) BOOL darkMode;

@end

@implementation ViewController
{
    CGRect startLabelRect, changeModeButtonRect;
}

- (void)loadView
{
    [super loadView];
    //define background color for self.view since it was already created.
    [AutoStandards color:AutoColorMainViewBackground forView:self.view method:AutoSetValueBackgroundColor];
    //also set nav bar - to illustrate its problems (it can't be translutient and pink at the same time - TODO: figure out a solution to this!)
    [[AutoStandards sharedInstance] navigationBarAppearance:self.navigationController.navigationBar];
    
    [AutoStandards createViews:self superView:self.view];   //auto-create all views for this ViewController and place them in it's view
    
    //Set initial values
    self.title = @"Navigation bar title is using the same font, but bgcolor need special care";
    self.startLabel.text = @"Click to change modes";
    [self.changeModeButton setTitle:@"Go Dark" forState:UIControlStateNormal];
}

- (void) viewWillLayoutSubviews
{
    //Now we just calculate our views with ordinary simple math and variables.
    
    CGFloat margin = 10;
    CGFloat touchSize = 44;
    CGRect remainder = self.view.frame;
    
    //fix any magic overlays by slicing of the top of our frame
    if ([self respondsToSelector:@selector(topLayoutGuide)])
    {
        CGFloat topBarOffset = self.topLayoutGuide.length;
        AutoSliceRect(&remainder, topBarOffset, CGRectMinYEdge);
    }
    
    startLabelRect = CGRectMake(margin, margin + remainder.origin.y, remainder.size.width, touchSize);
    changeModeButtonRect = CGRectMake(margin, margin + CGRectGetMaxY(startLabelRect), 100, touchSize);
    //for easeir layout instead use: CGRectDivide(remainder, <#CGRect * _Nonnull slice#>, &remainder, <#CGFloat amount#>, <#CGRectEdge edge#>)
    
    //Then we set all rects at the same time with this simple function
    [AutoStandards setFrames:self];
}

- (void) changeModeButtonPressed
{
    if (self.darkMode)
    {
        [self.changeModeButton setTitle:@"Go Dark" forState:UIControlStateNormal];
        [[AutoStandards sharedInstance] switchAppearanceTo:AutoStandardAppearance];
    }
    else
    {
        [self.changeModeButton setTitle:@"Go Bright" forState:UIControlStateNormal];
        [[AutoStandards sharedInstance] switchAppearanceTo:@"DarkMode"];
    }
    
    self.darkMode = !self.darkMode;
}

@end