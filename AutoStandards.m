//
//  AutoStandards.m
//  Aggressive Writing
//
//  Created by Olof Thorén on 2013-10-25.
//  Copyright (c) 2013 Aggressive Development. All rights reserved.
//

#import "AutoStandards.h"
@import ObjectiveC;
@import QuartzCore;

@implementation AutoStandards

//NS_ASSUME_NULL_BEGIN

static AutoStandards *sharedInstance = nil;
static CGSize standardCellSize;

+ (instancetype) sharedInstance
{
    if (sharedInstance == nil)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            sharedInstance = [AutoStandards new];
        });
    }
    return sharedInstance;
}

- (instancetype) init
{
    self = [super init];
    self.standardColors = [NSMutableDictionary new];
    self.creationCache = [NSCache new];
    
    //TODO: allow for Disallowing this functionality
    self.viewsWithActions = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    [self parseSettings:nil update:NO];
    return self;
}

//parse values if there are a settings file, otherwise (and for missing keys), set defualt values.
- (void) parseSettings:(NSDictionary *)settings update:(BOOL)update
{
    if (!settings)
    {
        NSString *settingsPath = [[NSBundle mainBundle] pathForResource:@"AutoStandardSettings" ofType:@"json"];
        if (settingsPath)
        {
            NSError *error = nil;
            settings = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:settingsPath] options:0 error:&error];
            if (error)
            {
                NSLog(@"Could not read your Standard Settings file: %@", error);
            }
            else
            {
                [self parseSettings:settings update:update];
            }
        }
    }
    if (!settings || settings.count == 0 || !settings[@"AutoColors"] || [settings[@"AutoColors"] isKindOfClass:[NSDictionary class]] == NO)
    {
        return;
    }
    NSDictionary *colors = settings[@"AutoColors"];
    [self setAppearance:colors];
    self.currentAppearance = AutoStandardAppearance;
    
    if (settings[@"AutoFont"])
    {
        //if font can't be found or don't exist, we use the standard font.
        self.standardFont = [UIFont fontWithName:settings[@"AutoFont"] size:14];
        if (!self.standardFont)
        {
            NSLog(@"No '%@' font! Available fonts: %@", settings[@"AutoFont"], [UIFont familyNames]);
        }
    }
    
    if (settings[@"AlternativeAppearances"])
    {
        NSMutableDictionary *alternativeAppearances = [settings[@"AlternativeAppearances"] mutableCopy];
        alternativeAppearances[AutoStandardAppearance] = colors;
        self.alternativeAppearances = alternativeAppearances;
    }
    if (update) [self updateAppearance];
}

- (UIColor*) colorFromDefinition:(NSArray*)colorDefinition
{
    if ([colorDefinition isKindOfClass:[NSString class]])
    {
        colorDefinition = [(NSString*)colorDefinition componentsSeparatedByString:@","];
    }
    if (self.useWebColors)
    {
        return [self colorFromRGBAInts:colorDefinition];
    }
    if ([colorDefinition isKindOfClass:[NSNumber class]] || [colorDefinition isKindOfClass:[NSString class]])
    {
        NSNumber* grayValue = (NSNumber*)colorDefinition;
        return [UIColor colorWithRed:[grayValue floatValue] green:[grayValue floatValue] blue:[grayValue floatValue] alpha:1];
    }
    else if (colorDefinition.count == 1)
    {
        float grayValue = [colorDefinition[0] floatValue];
        return [UIColor colorWithRed:grayValue green:grayValue blue:grayValue alpha:1];
    }
    else if (colorDefinition.count == 2)
    {
        float grayValue = [colorDefinition[0] floatValue];
        return [UIColor colorWithRed:grayValue green:grayValue blue:grayValue alpha:[colorDefinition[1] floatValue]];
    }
    else if (colorDefinition.count == 3)
    {
        return [UIColor colorWithRed:[colorDefinition[0] floatValue] green:[colorDefinition[1] floatValue] blue:[colorDefinition[2] floatValue] alpha:1];
    }
    else if (colorDefinition.count == 4)
    {
        return [UIColor colorWithRed:[colorDefinition[0] floatValue] green:[colorDefinition[1] floatValue] blue:[colorDefinition[2] floatValue] alpha:[colorDefinition[3] floatValue]];
    }
    return nil;
}

//User web-colors instead
- (UIColor*) colorFromRGBAInts:(NSArray*)colorDefinition
{
    if (colorDefinition.count == 3)
    {
        return [UIColor colorWithRed:[colorDefinition[0] floatValue] / 255 green:[colorDefinition[1] floatValue] / 255 blue:[colorDefinition[2] floatValue] / 255 alpha:1];
    }
    else if (colorDefinition.count == 4)
    {
        return [UIColor colorWithRed:[colorDefinition[0] floatValue] / 255 green:[colorDefinition[1] floatValue] / 255 blue:[colorDefinition[2] floatValue] / 255 alpha:[colorDefinition[3] floatValue] / 255];
    }
    return nil;
}

- (void) setAppearance:(NSDictionary*)appearance
{
    NSDictionary *colorKeys =
    @{
      @"AutoColorMainViewBackground" : @1,
      @"AutoColorLighterViewBackground" : @2,
      @"AutoColorOverlayViewBackground" : @3,
      @"AutoColorBarBackground" : @4,
      @"AutoColorUnselectedCell" : @5,
      @"AutoColorSelectedCell" : @6,
      @"AutoColorTintColor" : @7,
      @"AutoColorDeleteColor" : @8,
      @"AutoColorCellSeparator" : @9,
      @"AutoColorMenuText" : @10,
      @"AutoColorBodyText" : @11,
      @"AutoColorError" : @12,
      @"AutoColorOK" : @13,
      @"AutoColorHighlightColor" : @14,
    };
    
    for (NSString *key in colorKeys)
    {
        UIColor *color = [self colorFromDefinition:appearance[key]];
        
        if (color)
        {
            self.standardColors[colorKeys[key]] = color;
        }
        else
        {
            NSLog(@"Error, wrong color format. %@", key);
        }
    }
    
    /**
     we may also haveapplication specific colors, not suitible for generallization. We put those into our standard colors, so you later can ask for them like this:
     [self standardColor:AutoColorSpecific_0];
     Set names by using define, like this:
     
     #define AutoColorImportantSalesPitchLabelBorder AutoColorSpecific_0
     
     Now, everybody will know that the border of the important sales pitch label will have the first color in the array - and can be change at any time just by modifying this array.
     [self standardColor:AutoColorImportantSalesPitchLabelBorder];
     */
    [appearance[@"AutoColorArray"] enumerateObjectsUsingBlock:^(NSArray *colorArray, NSUInteger idx, BOOL * _Nonnull stop)
    {
        UIColor *color = [self colorFromDefinition:colorArray];
        if (color)
        {
            self.standardColors[@(idx + AutoDefinedColorAmount)] = color;
        }
    }];
    
    //set tint color on all objects
    UIColor *tintColor = [self standardColor:AutoColorTintColor];
    
    Class uiApplication = NSClassFromString(@"UIApplication");
    if (uiApplication)
    {
        //NOTE! If you have a navigation-bar, the status bar background will be set by the nav-bars barStyle.
        //SO: in general this has no effect at all!
        
        //We have access to the uiapplication class - TODO: double check that this actually works.
        if ([AutoStandards colorIsDark:[self standardColor:AutoColorBarBackground]])
        {
            [[uiApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
        }
        else
        {
            //The text color in the menu is dark - lets also set the statusBar's text to dark - light content means dark text!
            [[uiApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
        }
        
        //we set tint color on the main window which will propagate to all views where their superviews tint-color is not set.
        [[uiApplication sharedApplication] keyWindow].tintColor = tintColor;
    }
    
    /*
     We can't use this since it overrides some objects own tint-color settings. A UITabBarItem cannot have a different tint color if these are set.
    //also set tint color on all views whose superview's tint color is set.
    for (Class classObject in @[[UITableView class], [UINavigationBar class], [UITabBar class], [UIView class], [UICollectionView class]])
    {
        [[classObject appearance] setTintColor:tintColor];
    }
    */
}

+ (BOOL) colorIsDark:(UIColor*)color
{
    CGFloat red, green, alpha, blue;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    
    // Counting the perceptive luminance - human eye favors green color...
    double perceptiveLuminance = 1 - ( 0.299 * 255 *red + 0.587 * 255 *green + 0.114 * 255 * blue) / 255.0f;
    
    //NSLog(@"red! %f", a);
    
    if (perceptiveLuminance < 0.5)
    {
        return NO; // bright color
    }
    return YES;
}

#pragma mark - setting font

- (CGFloat) standardFontSize
{
    return 18;
}

+ (UIFont*) standardFont:(CGFloat)size
{
    return [[self sharedInstance] standardFont:size];
}

- (UIFont*) fontWithType:(AutoFont)fontType
{
    switch (fontType)
    {
        case AutoFontBody:
        {
            return [self standardFont:14];
            break;
        }
        case AutoFontLabel:
        {
            return [self standardFont];
            break;
        }
        case AutoFontTitle:
        {
            return [self standardFont:22];
            break;
        }
        case AutoFontSubTitle:
        {
            return [self standardFont:20];
            break;
        }
        default:
            break;
    }
    
    return [self standardFont];
}

- (UIFont*) standardFont:(CGFloat)size
{
    if (!_standardFont)
    {
        //Let's switch to SanFran - everybody loves san fran!
        self.standardFont = [UIFont systemFontOfSize:[self standardFontSize]];
        
        if (!_standardFont)
        {
            
            self.standardFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:[self standardFontSize]];
            if (!self.standardFont)
            {
                self.standardFont = [UIFont fontWithName:@"HelveticaNeue" size:[self standardFontSize]];
                if (!self.standardFont)
                {
                    self.standardFont = [UIFont fontWithName:@"Helvetica" size:[self standardFontSize]];
                }
            }
        }
    }
    
    return [self.standardFont fontWithSize:size];
}


#pragma mark - colors

+ (UIColor*) standardColor:(AutoColor)color
{
    return [[self sharedInstance] standardColor:color];
}

- (UIColor*) standardColor:(AutoColor)color
{
    UIColor *standardColor = self.standardColors[@(color)];
    if (standardColor)
    {
        return standardColor;
    }
    switch (color)
    {
        case AutoColorBarBackground:
        case AutoColorOverlayViewBackground:
        case AutoColorUnselectedCell:
        {
            standardColor = [UIColor whiteColor];
            break;
        }
        case AutoColorError:
        case AutoColorDeleteColor:
        {
            standardColor = [UIColor redColor];
            break;
        }
        case AutoColorOK:
        {
            standardColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:1];
            break;
        }
        case AutoColorSelectedCell:
        case AutoColorTintColor:
        {
            standardColor = [UIColor colorWithRed:0.059 green:0.467 blue:0.898 alpha:1.000];
            break;
        }
        case AutoColorMainViewBackground:
        {
            standardColor = [UIColor colorWithWhite:0.89 alpha:1.000];
            break;
        }
        case AutoColorLighterViewBackground:
        {
            standardColor = [UIColor colorWithWhite:0.94 alpha:1.000];
            break;
        }
        case AutoColorCellSeparator:
        {
            standardColor = [UIColor darkGrayColor];
            break;
        }
        case AutoColorBodyText:
        case AutoColorMenuText:
        {
            standardColor = [UIColor blackColor];
            break;
        }
        case AutoColorHighlightColor:
        {
            standardColor = [UIColor whiteColor];
            break;
        }
		case AutoColorNothing:
		{
			standardColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0];
			break;
		}
        default:
        {
            //if we are missing any array colors they will go here
            standardColor = [UIColor whiteColor];
            break;
        }
    }
    
    //UIColor is a class cluster. To make it behave the way you want you must create it with this method: colorWithRed:green:blue:alpha:
    
    //No real point in storing these?
    self.standardColors[@(color)] = standardColor;
    
    return standardColor;
}

#pragma mark - working with strings

///Simple c function to check if a string ends with suffixs, so we don't have to convert back and forth between c strings and NSString.
bool autoCstrEndsWith(const char * str, const char * suffix)
{
    if( str == NULL || suffix == NULL ) return NO;
    
    size_t str_len = strlen(str);
    size_t suffix_len = strlen(suffix);
    
    if(suffix_len > str_len) return YES;
    
    if (0 == strncmp( str + str_len - suffix_len, suffix, suffix_len ))
    {
        return YES;
    }
    return NO;
}

#pragma mark - sizes and sizing

void AutoCenterViewInFrame(UIView* target, CGRect master)
{
    CGRect frame = target.frame;
    frame.origin.x = CGRectGetMidX(master) - ceil(frame.size.width * 0.5);
    frame.origin.y = CGRectGetMidY(master) - ceil(frame.size.height * 0.5);
    target.frame = frame;
}

void AutoCenterFrameInFrame(CGRect* frame, CGRect master)
{
    frame->origin.x = CGRectGetMidX(master) - ceil(frame->size.width * 0.5);
    frame->origin.y = CGRectGetMidY(master) - ceil(frame->size.height * 0.5);
}

void AutoSliceRect(CGRect *in_rect,  CGFloat amount, CGRectEdge edge)
{
    CGRect rect = *in_rect;
    switch (edge)
    {
        case CGRectMinXEdge:
        {
            rect.origin.x += amount;
            rect.size.width -= amount;
            break;
        }
        case CGRectMaxXEdge:
        {
            rect.size.width -= amount;
            break;
        }
        case CGRectMinYEdge:
        {
            rect.origin.y += amount;
            rect.size.height -= amount;
            break;
        }
        case CGRectMaxYEdge:
        default:
        {
            rect.size.height -= amount;
            break;
        }
    }
    in_rect->origin.x = rect.origin.x;
    in_rect->origin.y = rect.origin.y;
    in_rect->size.width = rect.size.width;
    in_rect->size.height = rect.size.height;
}

#pragma mark - images

- (UIImage*) tintedImageWithName:(NSString*)imageName
{
    UIColor *color = [self standardColor:AutoColorTintColor];
    UIImage *image = [UIImage imageNamed:imageName];
    
    return [self tintedImage:image color:color];
}

- (UIImage*) tintedImage:(UIImage*)image
{
    return [self tintedImage:image color:[self standardColor:AutoColorTintColor]];
}

- (UIImage*) tintedImage:(UIImage*)image color:(UIColor*)color
{
    CGRect rect = CGRectZero;
    rect.size = [image size];
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0); // 0.0 for scale means "scale for device's main screen".
    [color setFill];
    CGRect bounds = CGRectMake(0, 0, rect.size.width, rect.size.height);
    UIRectFill(bounds);
    
    [image drawInRect:bounds blendMode:kCGBlendModeDestinationIn alpha:1.0];
    
    UIImage *returnImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return returnImage;
}

#pragma mark - Standard status bar height

///standardStatusBarHeight tries to protect agains the zero bar-height bug by defaulting to 20 - or using the last reported bar height. If landscape and portrait bars are different, and you just rotated, this will be wrong.
CGFloat standardStatusBarHeight()
{
	static CGFloat standardBarHeight = 20;
	CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
	CGFloat barHeight = MIN(statusBarSize.width, statusBarSize.height);
	if (barHeight > 1)
	{
		standardBarHeight = barHeight;
	}
	return standardBarHeight;
}

#pragma mark - Standard cell sizes for use in collection views
//highly questionable solutions to make standard cell sizes for collection views

+ (CGSize) standardCellSize
{
    if (standardCellSize.width == 0)
    {
        /* Build an algorithm to come up with standard sizes
         CGSize viewSize = [[UIScreen mainScreen] bounds].size;
         //First transform to portrait.
         if (viewSize.width > viewSize.height)
         {
         float tmp = viewSize.width;
         viewSize.width = viewSize.height;
         viewSize.height = tmp;
         }
         */
        
        //TODO: We have calculated this by hand. It should be done smarter.
        CGFloat cellSize = 100;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            cellSize = 141;
        }
        
        standardCellSize.width = cellSize;
        standardCellSize.height = round(cellSize * 1.61803);    //use 1.42857 for more magazine-like look.
    }
    return standardCellSize;
}

+ (CGSize) standardCoverSize
{
    //TODO: remove/redo this. it is stupid.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        return CGSizeMake(178, 288);
    }
    return CGSizeMake(145, 210);
}

+ (UIEdgeInsets) standardCollectionViewEdgeInsets
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        return UIEdgeInsetsMake(10, 5, 10, 5);
    }
    return UIEdgeInsetsMake(20, 10, 20, 10);
}


#pragma mark - View creations, depricated

//here we have views that require frames or hard-coded values. These are depricated.

//adjust the rect if we already have a date-picker.
- (void) standardDatePickerRectForDatePicker:(UIDatePicker*)datePicker
{
    CGFloat datePickerWidth = 295;
    CGRect rect = datePicker.frame;
    if (datePicker.datePickerMode == UIDatePickerModeDateAndTime)
    {
        datePickerWidth += 50;  //investigate this!
    }
    
    if (datePickerWidth < rect.size.width)
    {
        rect = CGRectInset(rect, floor(0.5 * (rect.size.width - datePickerWidth)), 0);
    }
    rect.size.width = datePickerWidth;
    rect.size.height = 162;
    datePicker.frame = rect;
}

- (UIDatePicker*) datePickerWithMode:(UIDatePickerMode)pickerMode target:(id)target selector:(SEL)selector inView:(UIView*)superView
{
    UIDatePicker *datePicker = [[UIDatePicker alloc] initWithFrame:CGRectZero];
	//datePicker.translatesAutoresizingMaskIntoConstraints = NO;
    datePicker.datePickerMode = pickerMode;
    
    [self standardDatePickerRectForDatePicker:datePicker];
    if ([target respondsToSelector:selector])
    {
        [datePicker addTarget:target action:selector forControlEvents:UIControlEventValueChanged];
    }
    datePicker.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [superView addSubview:datePicker];
    datePicker.layer.borderWidth = 1.0 / [[UIScreen mainScreen] scale];
    datePicker.layer.borderColor = [[self standardColor:AutoColorMainViewBackground] CGColor];
    return datePicker;
}

- (CGRect) standardStepperRect:(CGPoint)origin
{
    return CGRectMake(origin.x, origin.y, 94, 29);
}

- (CGSize) standardStepperSize
{
    return CGSizeMake(94, 29);
}

- (CGSize) standardSwitchSize
{
    return CGSizeMake(50, 29);
}

- (UIStepper*) standardStepper:(CGPoint)origin target:(id)target inView:(UIView*)superView
{
    UIStepper *stepper = [[UIStepper alloc] initWithFrame:CGRectMake(origin.x, origin.y, 94, 29)];
	//stepper.translatesAutoresizingMaskIntoConstraints = NO;
    stepper.autorepeat = YES;
    stepper.wraps = YES;
    if ([target respondsToSelector:@selector(valueChanged:)])
    {
        [stepper addTarget:target action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    [superView addSubview:stepper];
    return stepper;
}

- (UIStepper*) standardStepperInFrame:(CGRect)frame target:(id)target inView:(UIView*)superView
{
    CGSize size = [self standardStepperSize];
    frame.origin.y += floor( (CGRectGetHeight(frame) - size.height) / 2 );
    frame.origin.x += floor( (CGRectGetWidth(frame) - size.width) / 2 );
    frame.size = size;
    UIStepper *stepper = [[UIStepper alloc] initWithFrame:frame];
	//stepper.translatesAutoresizingMaskIntoConstraints = NO;
    stepper.autorepeat = YES;
    stepper.wraps = YES;
    if ([target respondsToSelector:@selector(valueChanged:)])
    {
        [stepper addTarget:target action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    [superView addSubview:stepper];
    return stepper;
}


//Standard components should all have names on the form [componentWith[Delegate/Target]:delegate/target(if such exists) (component specific standard atributes goes here) selector:selector inView:superView]

- (UISwitch*) switchWithTarget:(id)target inView:(UIView*)superView
{
    CGSize size = [self standardSwitchSize];
    UISwitch *ui_switch = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    //ui_switch.translatesAutoresizingMaskIntoConstraints = NO;
    [self switchAppearance:ui_switch];
    if ([target respondsToSelector:@selector(valueChanged:)])
    {
        [ui_switch addTarget:target action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    [superView addSubview:ui_switch];
    return ui_switch;
}

- (void) switchAppearance:(UISwitch *)ui_switch
{
    [self color:AutoColorTintColor forView:ui_switch method:AutoSetValueTintColor];
    [self color:AutoColorTintColor forView:ui_switch method:AutoSetValueOnTintColor];
}

#pragma mark - standard components

- (UIStepper*) stepperWithTarget:(id)target inView:(UIView*)superView
{
    UIStepper *stepper = [[UIStepper alloc] initWithFrame:CGRectMake(0, 0, 94, 29)];
	//stepper.translatesAutoresizingMaskIntoConstraints = NO;
    stepper.autorepeat = YES;
    stepper.wraps = YES;
    if ([target respondsToSelector:@selector(valueChanged:)])
    {
        [stepper addTarget:target action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    [self stepperAppearance:stepper];
    [superView addSubview:stepper];
    return stepper;
}

- (void) stepperAppearance:(UIStepper*)view
{
    [self color:AutoColorTintColor forView:view method:AutoSetValueTintColor];
}

- (UISegmentedControl*) segmentedControlWithTarget:(id)target inView:(UIView*)superView
{
    UISegmentedControl *segment = [UISegmentedControl new];
    
    if ([target respondsToSelector:@selector(valueChanged:)])
    {
        [segment addTarget:target action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    [self segmentAppearance:segment];
    [superView addSubview:segment];
    return segment;
}

- (void) segmentAppearance:(UISegmentedControl*)view
{
    [self color:AutoColorLighterViewBackground forView:view method:AutoSetValueBackgroundColor];
    [self color:AutoColorTintColor forView:view method:AutoSetValueTintColor];
    [self color:AutoColorTintColor forView:view method:AutoSetValueTitleTextAttributesNormalState];
    //Should we use this? [view setTitleTextAttributes:<#(nullable NSDictionary *)#> forState:<#(UIControlState)#>]
}

- (UIActivityIndicatorView*) spinnerInView:(UIView*)superView;
{
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	//spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.hidesWhenStopped = YES;
    [superView addSubview:spinner];
    //Why would you ever want to start spinning when creating views? [spinner startAnimating];
    return spinner;
}

- (UITextView*) textViewWithDelegate:(id<UITextViewDelegate>)delegate inView:(UIView*)superView
{
    UITextView *view = [[UITextView alloc] initWithFrame:CGRectZero];
	//view.translatesAutoresizingMaskIntoConstraints = NO;
    view.delegate = delegate;
    view.layer.borderWidth = 1.0 / [[UIScreen mainScreen] scale];
    [self textViewAppearance:view];
    [superView addSubview:view];
    return view;
}

- (void) textViewAppearance:(UITextView *)view
{
    [self font:AutoFontBody color:AutoColorBodyText extraAttributes:nil forView:view method:AutoSetValueFont];
    [self color:AutoColorTintColor forView:view method:AutoSetValueBorderColor];
    [self color:AutoColorBodyText forView:view method:AutoSetValueTextColor];
    [self color:AutoColorLighterViewBackground forView:view method:AutoSetValueBackgroundColor];
}

- (UIImageView*) imageViewWithImage:(UIImage*)image inView:(UIView*)superView
{
    UIImageView *view = [[UIImageView alloc] initWithImage:image];
	//view.translatesAutoresizingMaskIntoConstraints = NO;
    view.contentMode = UIViewContentModeScaleAspectFit;
    [superView addSubview:view];
    return view;
}

- (UIPageControl*) pageControlWithTarget:(id)target inView:(UIView*)superView
{
    //standard height is 37, center in frame?
    UIPageControl *pageControl = [[UIPageControl alloc] initWithFrame:CGRectZero];
	//pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    pageControl.hidesForSinglePage = YES;
    [self pageControlAppearance:pageControl];
    if (target)
    {
        [pageControl addTarget:target action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    [superView addSubview:pageControl];
    return pageControl;
}

- (void) pageControlAppearance:(UIPageControl*)pageControl
{
    //TODO: Make a selector for this color
    pageControl.pageIndicatorTintColor = [UIColor blackColor];
    pageControl.currentPageIndicatorTintColor = [self standardColor:AutoColorTintColor];
}

//- (UIButton*) buttonWithTarget:(id)target inView:(UIView*)view
- (UIButton*) buttonWithName:(NSString*)propertyName target:(id)target inView:(UIView*)view
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    
    NSString *dedicatedSelector = nil;
    NSString *dedicatedSelectorColon = nil;
    if (propertyName)
    {
        dedicatedSelector = [propertyName stringByAppendingString:@"Pressed"];
        dedicatedSelectorColon = [propertyName stringByAppendingString:@"Pressed:"];
    }
    if (dedicatedSelector && [target respondsToSelector:NSSelectorFromString(dedicatedSelector)])
    {
        [button addTarget:target action:NSSelectorFromString(dedicatedSelector) forControlEvents:UIControlEventTouchUpInside];
    }
    else if (dedicatedSelectorColon && [target respondsToSelector:NSSelectorFromString(dedicatedSelectorColon)])
    {
        [button addTarget:target action:NSSelectorFromString(dedicatedSelectorColon) forControlEvents:UIControlEventTouchUpInside];
    }
    else if ([target respondsToSelector:@selector(buttonPressed:)])
    {
        [button addTarget:target action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.font = [self standardFont:18];
    button.showsTouchWhenHighlighted = YES;
    button.contentMode = UIViewContentModeScaleAspectFit;
    
    //textbuttons need borders so remove border if you use images
    button.layer.borderWidth = 1.0 / [[UIScreen mainScreen] scale];
    button.layer.cornerRadius = 5;
    
    [self buttonAppearance:button];
    [view addSubview:button];
    
    return button;
}

- (void) buttonAppearance:(UIButton*)view
{
    [self color:AutoColorTintColor forView:view method:AutoSetValueTintColor];
    
    [self color:AutoColorTintColor forView:view method:AutoSetValueTitleNormalColor];
    [self color:AutoColorHighlightColor forView:view method:AutoSetValueTitleHighlightColor];
    [self color:AutoColorLighterViewBackground forView:view method:AutoSetValueBackgroundColor];
    [self color:AutoColorTintColor forView:view method:AutoSetValueBorderColor];
}

- (UITableView*) tableView:(id)delegate inView:(UIView*)view
{
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    
    table.delegate = delegate;
    table.dataSource = delegate;
    table.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    //auto-register cell-classes? No, it's easy enough to do yourself.
    
    [self tableAppearance:table];
    [view addSubview:table];
    
    return table;
}

- (void) tableAppearance:(UITableView*)view
{
    //table background will only be shown where there are no cells, or if your cells are transparent
    [self color:AutoColorMainViewBackground forView:view method:AutoSetValueBackgroundColor];
}

- (UIProgressView*) progressView:(UIView*)superView
{
    UIProgressView *progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
	//progress.translatesAutoresizingMaskIntoConstraints = NO;
    [self progressAppearance:progress];
    [superView addSubview:progress];
    return progress;
}

- (void) progressAppearance:(UIProgressView*)view
{
    [self color:AutoColorTintColor forView:view method:AutoSetValueProgressTintColor];
}

- (UITextField*) textField:(id<UITextFieldDelegate>)delegate placeholder:(NSString*)placeholder inView:(UIView*)superView
{
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectZero];
	//textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.delegate = delegate;
    textField.placeholder = placeholder;
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.clearButtonMode = UITextFieldViewModeAlways;
    textField.adjustsFontSizeToFitWidth = YES;
    textField.minimumFontSize = 7;
    textField.font = [self standardFont:14];
    
    [superView addSubview:textField];
    return textField;
}

- (void) textFieldAppearance:(UITextField*)view
{
    [self color:AutoColorBodyText forView:view method:AutoSetValueTextColor];
    [self color:AutoColorLighterViewBackground forView:view method:AutoSetValueBackgroundColor];
}

- (UISlider*) slider:(id)target inView:(UIView*)superView
{
    UISlider *slider = [[UISlider alloc] init];
	//slider.translatesAutoresizingMaskIntoConstraints = NO;
    SEL selector = @selector(touchUpInside:);
    if ([target respondsToSelector:selector])
    {
        [slider addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];
    }
    
    selector = @selector(touchUpOutside:);
    if ([target respondsToSelector:selector])
    {
        [slider addTarget:target action:selector forControlEvents:UIControlEventTouchUpOutside];
    }
    
    selector = @selector(valueChanged:);
    if ([target respondsToSelector:selector])
    {
        [slider addTarget:target action:selector forControlEvents:UIControlEventValueChanged];
    }
    
    [self sliderAppearance:slider];
    [superView addSubview:slider];
    return slider;
}

- (void) sliderAppearance:(UISlider*)view
{
    //Should we really set tint color?
}

- (UIView*) viewInView:(UIView*)superView
{
    UIView *view = [UIView new];
    [superView addSubview:view];
    return view;
}

- (UILabel*) labelInView:(UIView*)view
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    //label.translatesAutoresizingMaskIntoConstraints = NO;
    
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 12.0 / 18.0;
    label.numberOfLines = 0;
    
    [self labelAppearance:label];
    
    [view addSubview:label];
    return label;
}

- (void) labelAppearance:(UILabel*)view
{
    [self font:AutoFontLabel color:AutoColorBodyText extraAttributes:nil forView:view method:AutoSetValueFont];
    [self color:AutoColorBodyText forView:view method:AutoSetValueTextColor];
}

+ (CGSize) string:(NSString*)string constrainedToSize:(CGSize)size
{
    return [self string:string constrainedToSize:size fontSize:[[AutoStandards sharedInstance]standardFontSize] font:nil];
}

+ (CGSize) string:(NSString*)string constrainedToSize:(CGSize)size fontSize:(float)fontSize font:(UIFont *)font
{
    AutoStandards *standards = [self sharedInstance];
    if (!font) font = [standards standardFont:fontSize];
    
    /*
     NSStringDrawingUsesLineFragmentOrigin - uses the top left corner as origin rather than the baseline (which usually is center)
     NSStringDrawingUsesFontLeading - font leading basically means line spacing. This flag indicates the call to make use of default line spacing specified by the font.
     */
    NSDictionary *attributes = @{ NSFontAttributeName : font };
    CGRect rect = [string boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:attributes context:nil];
    if (CGPointEqualToPoint(rect.origin, CGPointZero) == NO)
    {
        NSLog(@"AutoStandards constrainedToSize :: did not get a size with zero origin");
    }
    rect = CGRectIntegral(rect);
    
    //CGRect rect2 = [string boundingRectWithSize:size options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName : font } context:nil];
    
    /*
     We can also build this to get the actual font-size:
     
     NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
     context.minimumScaleFactor = 0.7;
     CGRect rect = [string boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName : font } context:context];
     CGFloat actualFontSize = font.pointSize * context.actualScaleFactor;
     */
    
    return rect.size;
}

+ (CGFloat) actualFontSizeForString:(NSString*)string font:(UIFont*)font constrainedToSize:(CGSize)size
{
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 0.1;
    
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *attributes = @{ NSFontAttributeName : font }; //, NSParagraphStyleAttributeName : style
    NSAttributedString *measure = [[NSAttributedString alloc] initWithString:string attributes:attributes];
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading | NSStringDrawingTruncatesLastVisibleLine;
    
    if (size.height == MAXFLOAT)
    {
        //We can only shrink if this is a single line - or a constrained rectangle. Supplying maxFloat means that we want a single line.
        CGFloat lineHeight = [measure boundingRectWithSize:CGSizeMake(MAXFLOAT, MAXFLOAT) options:options context:nil].size.height;
        size.height = lineHeight;
    }
    
    CGRect rect = [measure boundingRectWithSize:size options:options context:context];
    rect = CGRectIntegral(rect);
    //NSLog(@"%@ context %f %f - width %@ input: %@", string, context.minimumScaleFactor, context.actualScaleFactor, NSStringFromCGSize(rect.size), NSStringFromCGSize(size));
    
    return font.pointSize * context.actualScaleFactor;
}


+ (void)autoShrinkSegmentLabels:(UISegmentedControl*)segmentedControl
{
    CGFloat width = segmentedControl.bounds.size.width;
    NSMutableDictionary *attributes = [[segmentedControl titleTextAttributesForState:UIControlStateNormal] mutableCopy];
    UIFont *font = attributes[NSFontAttributeName];
    
    //How much space have each label? We don't have to care for their margins. Or? it seems that we sometimes need margins but not always... weird! Investigate!
    width = floor(width / segmentedControl.numberOfSegments) - 5;
    CGFloat minFontSize = font.pointSize;
    for (NSInteger index = 0; index < segmentedControl.numberOfSegments; index++)
    {
        NSString *title = [segmentedControl titleForSegmentAtIndex:index];
        CGFloat fontSize = [self actualFontSizeForString:title font:font constrainedToSize:CGSizeMake(width, MAXFLOAT)];
        if (fontSize < minFontSize)
        {
            minFontSize = fontSize;
        }
    }
    if (minFontSize < font.pointSize)
    {
        attributes[NSFontAttributeName] = [font fontWithSize:minFontSize];
        [segmentedControl setTitleTextAttributes:attributes forState:UIControlStateNormal];
    }
}

- (UIButton*) buttonWithImage:(UIImage*)image highlight:(UIImage*)highlight target:(id)target inView:(UIView*)view
{
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectZero];
	//button.translatesAutoresizingMaskIntoConstraints = NO;
    button.showsTouchWhenHighlighted = YES;
    [button setImage:image forState:UIControlStateNormal];
    [button setImage:highlight forState:UIControlStateHighlighted];
    button.contentMode = UIViewContentModeScaleAspectFit;
    if ([target respondsToSelector:@selector(buttonPressed:)])
    {
        [button addTarget:target action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    [view addSubview:button];
    return button;
}

- (UIButton*) buttonWithImageName:(NSString*)image tint:(BOOL)tint target:(id)target inView:(UIView*)view
{
    UIButton *button = [self buttonWithName:nil target:target inView:view];
    
    UIImage *buttonImage;
    if (tint)
    {
        buttonImage = [self tintedImageWithName:image];
        [button setImage:[UIImage imageNamed:image] forState:UIControlStateHighlighted];
        [button setImage:[UIImage imageNamed:image] forState:UIControlStateSelected];
    }
    else
    {
        buttonImage = [UIImage imageNamed:image];
    }
    [button setImage:buttonImage forState:UIControlStateNormal];
    button.contentMode = UIViewContentModeScaleAspectFit;
    
    //images don't need borders
    button.layer.borderWidth = 0;
    [view addSubview:button];
    
    return button;
}

- (UIButton*) buttonWithTitle:(NSString*)title target:(id)target inView:(UIView*)view
{
    UIButton *button = [self buttonWithName:nil target:target inView:view];
    
    [button setTitle:title forState:UIControlStateNormal];
    
    return button;
}

#pragma mark - appearance for stuff we don't create

- (void) navigationBarAppearance:(UINavigationBar*)view
{
    [AutoStandards color:AutoColorMenuText forView:view method:AutoSetValueMenuTextAttributes];
    [AutoStandards color:AutoColorMenuText forView:view method:AutoSetValueTintColor];
    [AutoStandards color:AutoColorBarBackground forView:view method:AutoSetValueBackgroundColor];
}

- (void) barButtonAppearance:(UIBarItem*)view
{
    [AutoStandards color:AutoColorMenuText forView:(UIView*)view method:AutoSetValueTintColor];
    [AutoStandards color:AutoColorMenuText forView:(UIView*)view method:AutoSetValueTitleTextAttributesNormalState];
    [AutoStandards color:AutoColorHighlightColor forView:(UIView*)view method:AutoSetValueTitleTextAttributesHighligtedState];
}

#pragma mark - methods for doing it all at once

+ (void) createViews:(id)viewController superView:(UIView*)view
{
    //We want to create views and store them in a dictionary like { view : viewRect }
    NSMapTable *viewsWithFrames = [NSMapTable strongToWeakObjectsMapTable];
    NSHashTable *allViews = nil;
    AutoStandards* instance = [self sharedInstance];
    
    //We need a better way to protect from instanciating UIKit's standard objects, like those found inside a UICollectionViewCell (calling this with a cell as the controller). Perhaps we should only allow UIViewController subclasses here? - OR should we just list all those classes?
    Class subclass = [viewController class];
    NSString *viewControllerClassString = NSStringFromClass(subclass);
    NSMutableDictionary *controllerCache = [instance.creationCache objectForKey:viewControllerClassString];
    if (!controllerCache)
    {
        controllerCache = [NSMutableDictionary new];
        [instance.creationCache setObject:controllerCache forKey:viewControllerClassString];
    }
    //get frames from cache, or build it!
    NSDictionary *frames = [self associateFramesUsingCache:controllerCache forController:viewController];
    
    //if we already have done this for this class, just reuse the info.
    NSMutableArray *cachedViewProperties = [controllerCache objectForKey:@"cachedViewProperties"];
    if (cachedViewProperties)
    {
        //use cached values instead of looping through the whole class heirarcy again
        for (NSDictionary *cacheDict in cachedViewProperties)
        {
            //NSString *controllerClass = cacheDict[@"controllerClass"];
            NSString *backingIvarString = cacheDict[@"backingIvarString"];
            NSString *ivarRectName = cacheDict[@"ivarRectName"];
            NSString *classString = cacheDict[@"viewClass"];
            NSString *propertyName = cacheDict[@"propertyName"];
            
            Ivar ivar = class_getInstanceVariable(subclass, [backingIvarString cStringUsingEncoding:NSUTF8StringEncoding]);
            
            BOOL validView = [instance associateIvar:ivar forPropertyName:propertyName withIvarRectName:ivarRectName subViewClass:classString superView:view allViews:allViews viewsWithFrames:viewsWithFrames forController:viewController];
            if (!validView)
            {
                NSLog(@"ERROR! Could not recreate cached views!");
                cachedViewProperties = nil;
                break;
            }
        }
    }
    
    //if it failed or we need to gather the data the first time
    if (cachedViewProperties == nil)
    {
        cachedViewProperties = [NSMutableArray new];
        [controllerCache setObject:cachedViewProperties forKey:@"cachedViewProperties"];
        
        while (subclass != [NSObject class] && subclass != [UIViewController class] && subclass != [UIView class] && subclass != [UICollectionViewCell class] && subclass != [UITableViewCell class])
        {
            unsigned int propertyCount;
            objc_property_t *propertyList = class_copyPropertyList(subclass, &propertyCount);
            for (unsigned int i = 0; i < propertyCount; i++)
            {
                //get property name
                objc_property_t property = propertyList[i];
                
                //NSLog(@"looking at properties %s has %s", property_getName(property), property_getAttributes(property));
                
                char *typeEncoding = property_copyAttributeValue(property, "T");    //T means (likely) type of property.
                if (typeEncoding[0] == '@' && strlen(typeEncoding) >= 3)
                {
                    char *className = strndup(typeEncoding + 2, strlen(typeEncoding) - 3);
                    __autoreleasing NSString *classString = @(className);
                    NSRange range = [classString rangeOfString:@"<"];
                    if (range.location != NSNotFound)
                    {
                        classString = [classString substringToIndex:range.location];
                    }
                    free(className);
                    
                    char *backingIvar = property_copyAttributeValue(property, "V"); //V = iVar
                    if (backingIvar == nil)
                    {
                        //NSLog(@"Backing ivar did not exist");
                        continue;
                    }
                    Ivar ivar = class_getInstanceVariable(subclass, backingIvar);
                    if (ivar == nil)
                    {
                        //NSLog(@"Did not find ivar at property lookup");
                        free(backingIvar);
                        continue;
                    }
                    NSString *propertyString = [NSString stringWithUTF8String:property_getName(property)];
                    NSString *ivarRectName = frames[propertyString];
                    BOOL validView = [instance associateIvar:ivar forPropertyName:propertyString withIvarRectName:ivarRectName subViewClass:classString superView:view allViews:allViews viewsWithFrames:viewsWithFrames forController:viewController];
                    
                    //we do this for all properties, but should only care for views
                    if (validView)
                    {
                        NSString *backingIvarString = [NSString stringWithUTF8String:backingIvar];
                        NSDictionary *cacheDict;
                        if (ivarRectName)
                        {
                            cacheDict = @{@"propertyName" : propertyString, @"backingIvarString" : backingIvarString, @"viewClass" : classString, @"ivarRectName" : ivarRectName};
                        }
                        else
                        {
                            cacheDict = @{@"propertyName" : propertyString, @"backingIvarString" : backingIvarString, @"viewClass" : classString};
                        }
                        [cachedViewProperties addObject:cacheDict];
                    }
                    
                    free(backingIvar);
                }
                free(typeEncoding);
            }
            free(propertyList);
            subclass = [subclass superclass];
        }
    }
    
    if (viewsWithFrames.count)
    {
        objc_setAssociatedObject(viewController, AUTO_RECTS_ARRAY, viewsWithFrames, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (allViews)
    {
        //To keep track of all views to modify their appearance, we link them inside a hashmap (a set).
        objc_setAssociatedObject(viewController, AUTO_MAP_VIEWS, allViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (BOOL) associateIvar:(Ivar)ivar forPropertyName:(NSString*)propertyString withIvarRectName:(NSString*)ivarRectName subViewClass:(NSString *)classString superView:(UIView*)view allViews:(NSHashTable*)allViews viewsWithFrames:(NSMapTable *)viewsWithFrames forController:(id)viewController
{
    id newView = object_getIvar(viewController, ivar);
    if (newView)
    {
        //this ivar is already set, that means we want to exclude the views from auto-creation, but we may want to set its frames
        if (ivarRectName)
        {
            [viewsWithFrames setObject:newView forKey:ivarRectName];
        }
        
        //Should we inclode UIResponder or CALayer?
        if ([newView isKindOfClass:[UIView class]] || [newView isKindOfClass:[UIBarItem class]])
        {
            //we also may want to change it's appearance so we set it here
            [allViews addObject:newView];
            return YES;
        }
        
        return NO;
    }
    
    newView = [self standardWidgetNamed:propertyString fromString:classString delegate:viewController superView:view];
    if (newView)
    {
        object_setIvar(viewController, ivar, newView);
        
        //also asosiate the frame with this view.
        if (ivarRectName)
        {
            [viewsWithFrames setObject:newView forKey:ivarRectName];
        }
        
        //we also may want to change it's appearance so we set it here
        [allViews addObject:newView];
        return YES;
    }
    return NO;
}

///Find the name of all views who has a corresponding rect having the same name but ending with "Rect"
+ (NSDictionary*) associateFramesUsingCache:(NSMutableDictionary*)controllerCache forController:(id)viewController
{
    Class subclass = [viewController class];
    NSMutableDictionary* frames = controllerCache[@"frames"];
    if (frames)
    {
        return frames;
    }
    frames = [NSMutableDictionary new];
    controllerCache[@"frames"] = frames;
    
    //check if there are iVars for these frames in all subclasses
    unsigned int outCount = 0;
    while (subclass != [NSObject class] && subclass != [UIViewController class] && subclass != [UIView class] && subclass != [UICollectionViewCell class] && subclass != [UITableViewCell class])
    {
        Ivar * ivars = class_copyIvarList(subclass, &outCount);
        if (ivars)
        {
            //add all possible Rects to the dict
            for (unsigned int index = 0; index < outCount; index++)
            {
                Ivar ivar = ivars[index];
                const char* ivarName = ivar_getName(ivar);
                if (autoCstrEndsWith(ivarName, "Rect"))
                {
                    NSString *ivarNameString = @(ivarName);
                    NSString *propertyName = [ivarNameString substringToIndex:ivarNameString.length - 4];
                    frames[propertyName] = ivarNameString;
                    
                    //frames becomes a dictionary like: { @"view" : @"viewRect" }, to later match the actual view with its property name.
                }
            }
            free(ivars);
        }
        subclass = [subclass superclass];
    }
    return frames;
}

+ (void) setFrames:(id)viewController
{
    NSMapTable *viewsWithFrames = objc_getAssociatedObject(viewController, AUTO_RECTS_ARRAY);
    if (!viewsWithFrames)
    {
        NSLog(@"You must first use the associated function createViews:superView: (%@)", viewController);
        return;
    }
    
    //loop through the viewsWithFrames we already got - find their rects within the class heirarchy
    unsigned char *memoryPointer = (unsigned char *)(__bridge void *)viewController;
    //Since we are looking into instances and not classes, all superclasses will have all instance-variables.
    Class viewControllerSubclass = [viewController class];
    
    NSEnumerator *enumerator = [viewsWithFrames keyEnumerator];
    NSString *ivarNameString;
    while (ivarNameString = [enumerator nextObject])
    {
        UIView *view = [viewsWithFrames objectForKey:ivarNameString];
        Ivar ivar = class_getInstanceVariable(viewControllerSubclass, [ivarNameString cStringUsingEncoding:NSUTF8StringEncoding]);
        if (ivar)
        {
            //Pointer magic for ARC
            ptrdiff_t offset = ivar_getOffset(ivar);
            CGRect rect = * ((CGRect *)(memoryPointer + offset));
            
            BOOL shrinkSegmentLabels = [view isKindOfClass:[UISegmentedControl class]] && view.bounds.size.width != rect.size.width;
            view.frame = rect;
            
            if (shrinkSegmentLabels)
            {
                //automatically adjust labels inside a segmented control - if the width has changed!
                [self autoShrinkSegmentLabels:(UISegmentedControl*)view];
            }
        }
    }
    
    /*
    unsigned int outCount = 0;
    Class subclass = [viewController class];
    while (subclass != [NSObject class] && subclass != [UIViewController class] && subclass != [UIView class] && subclass != [UICollectionViewCell class] && subclass != [UITableViewCell class])
    {
        Ivar * ivars = class_copyIvarList(subclass, &outCount);
        
        if (ivars)
        {
            unsigned char *memoryPointer = (unsigned char *)(__bridge void *)viewController;
            
            //add all possible Rects to the dict
            for (unsigned int index = 0; index < outCount; index++)
            {
                Ivar ivar = ivars[index];
                
                const char* ivarName = ivar_getName(ivar);
                NSString *ivarNameString = [NSString stringWithUTF8String:ivarName];
                
                UIView *view = [viewsWithFrames objectForKey:ivarNameString];
                if (view)
                {
                    //Pointer magic for ARC
                    ptrdiff_t offset = ivar_getOffset(ivar);
                    CGRect rect = * ((CGRect *)(memoryPointer + offset));
                    view.frame = rect;
                }
            }
            free(ivars);
        }
        subclass = [subclass superclass];
    }
     */
}

- (id) standardWidgetNamed:(NSString*)propertyString fromString:(NSString*)classString delegate:(id)delegate superView:(UIView*)view
{
    id newView = nil;
    
    Class viewClass = NSClassFromString(classString);
    if ([viewClass isSubclassOfClass:[UIProgressView class]])
    {
        newView = [self progressView:view];
    }
    else if ([viewClass isSubclassOfClass:[UITextField class]])
    {
        newView = [self textField:delegate placeholder:nil inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UITextView class]])
    {
        newView = [self textViewWithDelegate:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UITableView class]])
    {
        newView = [self tableView:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UISwitch class]])
    {
        newView = [self switchWithTarget:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UIStepper class]])
    {
        newView = [self stepperWithTarget:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UIActivityIndicatorView class]])
    {
        newView = [self spinnerInView:view];
    }
    else if ([viewClass isSubclassOfClass:[UISegmentedControl class]])
    {
        newView = [self segmentedControlWithTarget:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UISlider class]])
    {
        newView = [self slider:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UIImageView class]])
    {
        newView = [[UIImageView alloc] initWithFrame:CGRectZero];
        ((UIImageView*)newView).contentMode = UIViewContentModeScaleAspectFit;
        [view addSubview:newView];
    }
    else if ([viewClass isSubclassOfClass:[UILabel class]])
    {
        newView = [self labelInView:view];
    }
    else if ([viewClass isSubclassOfClass:[UIButton class]])
    {
        newView = [self buttonWithName:propertyString target:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UIView class]])
    {
        //any other view that we don't have an implementation for, use use the default init method.
        UIView* uiView = [viewClass new];
		//uiView.translatesAutoresizingMaskIntoConstraints = NO;
		newView = uiView;
        [view addSubview:newView];
        
        //Should we log these views?
    }
    return newView;
}

+ (void) setValues:(NSDictionary*)lists forViews:(UIView*)firstPointer, ...
{
    for (NSString *key in lists)
	{
		NSArray *values = lists[key];
        id value = nil;
        
        //allow lists to contain arrays or a single value (if everyone should have the same value).
        if ([values isKindOfClass:[NSArray class]] == NO)
        {
            value = values; //use the same value for all views
        }
        
        va_list arguments;
        va_start(arguments, firstPointer);
        NSInteger counter = 0;
        
        for (UIView * view = firstPointer; view != nil; view = va_arg(arguments, UIView *))
        {
            if (value == nil)
            {
                value = values[counter];
                counter++;
            }
            if (value)
            {
                [view setValue:value forKeyPath:key];
            }
        }
        va_end(arguments);
	}
}

+ (void) setButtons:(NSArray*)buttons imagesOrNames:(NSArray*)imageArray tint:(BOOL)tint orColor:(UIColor*)color
{
    if (buttons.count != imageArray.count)
    {
        return;
    }
    
    for (NSInteger index = 0; index < buttons.count; index++)
    {
        UIButton *button = buttons[index];

        UIImage* image = imageArray[index];
        if ([image isKindOfClass:[NSString class]])
        {
            image = [UIImage imageNamed:(NSString*)image];
        }
        
        UIImage *buttonImage = nil;
        if (tint || color)
        {
            if (tint)
            {
                buttonImage = [[AutoStandards sharedInstance] tintedImage:image];
            }
            else
            {
                buttonImage = [[AutoStandards sharedInstance] tintedImage:image color:color];
            }
            [button setImage:image forState:UIControlStateHighlighted];
            [button setImage:image forState:UIControlStateSelected];
        }
        else
        {
            buttonImage = image;
        }
        [button setImage:buttonImage forState:UIControlStateNormal];
    }
}

#pragma mark - define appearance

+ (void) color:(AutoColor)color forView:(UIView*)view method:(AutoSetValue)method
{
    [[self sharedInstance] color:color forView:view method:method];
}

+ (void) font:(AutoFont)fontType color:(AutoColor)colorType extraAttributes:(NSDictionary*)extraAttributes forView:(UIView*)view method:(AutoSetValue)method
{
    [[self sharedInstance] font:fontType color:colorType extraAttributes:extraAttributes forView:view method:method];
}

- (void) font:(AutoFont)fontType color:(AutoColor)colorType extraAttributes:(NSDictionary*)extraAttributes forView:(UIView*)view method:(AutoSetValue)method
{
    NSMutableDictionary *attributes = [extraAttributes mutableCopy];
    if (!attributes)
    {
        attributes = [NSMutableDictionary new];
    }
    
    UIFont *font = [self fontWithType:fontType];
    attributes[NSFontAttributeName] = font;
    UIColor *color = [self standardColor:colorType];
    attributes[NSForegroundColorAttributeName] = color;
    
    switch (method)
    {
        case AutoSetValueTitleTextAttributesNormalState:
        {
            [((UISegmentedControl*)view) setTitleTextAttributes:attributes forState:UIControlStateNormal];
            break;
        }
        case AutoSetValueTitleHighlightColor:
        {
            [((UISegmentedControl*)view) setTitleTextAttributes:attributes forState:UIControlStateHighlighted];
            break;
        }
        case AutoSetValueTitleTextAttributes:
        {
            ((UINavigationBar*)view).titleTextAttributes = attributes;
            break;
        }
        case AutoSetValueFont:
        {
            ((UILabel*)view).font = font;
            break;
        }
        case AutoSetValueMenuTextAttributes:
        {
            ((UINavigationBar*)view).titleTextAttributes = attributes;
            break;
        }
        default:
            break;
    }
    
    
    NSMutableDictionary *appearances = objc_getAssociatedObject(view, AUTO_MAP_VIEW_ACTIONS);
    if (!appearances)
    {
        appearances = [NSMutableDictionary new];
        
        //To keep track of all views to modify their appearance, we link them inside a mapTable (a dictionary).
        objc_setAssociatedObject(view, AUTO_MAP_VIEW_ACTIONS, appearances, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        [self.viewsWithActions addObject:view];
    }
    [appearances setObject:@{ @"color" : @(colorType), @"font" : @(fontType) } forKey:@(method)];
}

- (void) updateAppearanceForView:(UIView*)view
{
    //For all views that are still in memory, loop over their registered methods.
    NSMutableDictionary *appearances = objc_getAssociatedObject(view, AUTO_MAP_VIEW_ACTIONS);
    [appearances enumerateKeysAndObjectsUsingBlock:^(NSNumber *methodNumber, NSNumber * object, BOOL * _Nonnull stop)
    {
        AutoSetValue method = methodNumber.integerValue;
        
        //if the method is a dictionary, we know it is a complex type - so we need to go through the font:color: setter.
        if ([object isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *objectAppearances = (NSDictionary*)object;
            AutoFont fontType = ((NSNumber*)objectAppearances[@"font"]).integerValue;
            AutoColor colorType = ((NSNumber*)objectAppearances[@"color"]).integerValue;
            
            [self font:fontType color:colorType extraAttributes:appearances forView:view method:method];
        }
        else
        {
            //else it is just a color
            [self color:object.integerValue forView:view method:method];
        }
    }];
}

- (void) color:(AutoColor)color forView:(UIView*)view method:(AutoSetValue)method
{
    NSMutableDictionary *appearances = objc_getAssociatedObject(view, AUTO_MAP_VIEW_ACTIONS);
    
    UIColor *colorObject = [self standardColor:color];
    switch (method)
    {
        case AutoSetValueProgressTintColor:
        {
            ((UIProgressView*)view).progressTintColor = colorObject;
            break;
        }
        case AutoSetValueBackgroundColor:
        {
            view.backgroundColor = colorObject;
            if ([view isKindOfClass:[UINavigationBar class]])
            {
                UINavigationBar *nav = ((UINavigationBar*)view);
                if ([AutoStandards colorIsDark:colorObject])
                {
                    //We must set the style to black in order to change the menuBar (above the nav-bar).
                    //AND set the tint color (otherwise it will just be 100% black).
                    //BUT this will remove any transparency. 
                    nav.barStyle = UIBarStyleBlack;
                    nav.barTintColor = colorObject;
                }
                else
                {
                    nav.barTintColor = nil;
                    nav.barStyle = UIBarStyleDefault;
                    nav.translucent = YES;
                }
            }
            break;
        }
        case AutoSetValueBorderColor:
        {
            view.layer.borderColor = colorObject.CGColor;
            break;
        }
        case AutoSetValueTextColor:
        {
            ((UILabel*)view).textColor = colorObject;
            break;
        }
        case AutoSetValueTintColor:
        {
            view.tintColor = colorObject;
            break;
        }
        case AutoSetValueTitleNormalColor:
        {
            [((UIButton*)view) setTitleColor:colorObject forState:UIControlStateNormal];
            break;
        }
        case AutoSetValueTitleHighlightColor:
        {
            [((UIButton*)view) setTitleColor:colorObject forState:UIControlStateHighlighted];
            break;
        }
        case AutoSetValueOnTintColor:
        {
            ((UISwitch*)view).onTintColor = colorObject;
            break;
        }
            
        //we can also add shorthands for textAttributes:
        case AutoSetValueTitleTextAttributesHighligtedState:
        case AutoSetValueFont:
        case AutoSetValueTitleTextAttributes:
        case AutoSetValueMenuTextAttributes:
        case AutoSetValueTitleTextAttributesNormalState:
        {
            [self font:AutoFontLabel color:color extraAttributes:nil forView:view method:method];
            //remember to return here!
            return;
        }
        
        default:
            break;
    }
    
    if (!appearances)
    {
        appearances = [NSMutableDictionary new];
        
        //To keep track of all views to modify their appearance, we link them inside a mapTable (a dictionary).
        //This means that all subviews in the entire application will be added to a weak-list.
        objc_setAssociatedObject(view, AUTO_MAP_VIEW_ACTIONS, appearances, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        [self.viewsWithActions addObject:view];
    }
	
	if (color == AutoColorNothing)
	{
		[appearances removeObjectForKey:@(method)];
	}
	else
	{
		[appearances setObject:@(color) forKey:@(method)];
	}
}

#pragma mark - switch appearance

- (void) switchAppearanceTo:(NSString*)name
{
    NSDictionary *appearance = self.alternativeAppearances[name];
    if (!appearance)
    {
        NSLog(@"Could not find appearance %@", name);
        return;
    }
    if ([self.currentAppearance isEqualToString:name])
    {
        return;
    }
    self.currentAppearance = name;
    [self setAppearance:appearance];
    [self updateAppearance];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AutoStandardsHasUpdatedAppearance object:nil userInfo:nil];
    if (self.didChangeAppearanceBlock)
    {
        self.didChangeAppearanceBlock();
    }
}

- (void) updateAppearance
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{ [self updateAppearance]; });
        return;
    }
    
    //in order to animate nav-bars we must hide it and display it - only necessary to fiddle with the root view controllers nav-controller, likely the root-controller is the nav-controller.
    
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    UINavigationController *nav;
    if ([root isKindOfClass:[UINavigationController class]]) nav = (UINavigationController*)root;
    else nav = root.navigationController;
    [nav setNavigationBarHidden:YES animated: NO];
    
    dispatch_block_t updateBlock = ^(void)
    {
        for (UIView *view in self.viewsWithActions)
        {
            [self updateAppearanceForView:view];
        }
    };
    
    UIViewAnimationOptions standardOptions = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut;
    [UIView animateWithDuration:0.4 delay:0 options: standardOptions animations:updateBlock completion:^(BOOL finished)
    {
        [nav setNavigationBarHidden:NO animated: NO];
    }];
}

///Change colors and other appearance elements for each view in the controller
- (void) updateAppearanceForController:(id)viewController
{
    NSHashTable *allViews = objc_getAssociatedObject(viewController, AUTO_MAP_VIEWS);
    if (!allViews)
    {
        NSLog(@"You must first use the associated function createViews:superView: (%@)", viewController);
        return;
    }
    for (id object in allViews)
    {
        [self standardAppearanceUpdate:object];
    }
}

- (void) standardAppearanceUpdate:(id)view
{
    Class viewClass = [view class];
    if ([viewClass isSubclassOfClass:[UIProgressView class]])
    {
        [self progressAppearance:(UIProgressView*)view];
    }
    else if ([viewClass isSubclassOfClass:[UITextField class]])
    {
        [self textFieldAppearance:(UITextField*)view];
    }
    else if ([viewClass isSubclassOfClass:[UITableView class]])
    {
        [self tableAppearance:(UITableView*)view];
    }
    else if ([viewClass isSubclassOfClass:[UISwitch class]])
    {
        [self switchAppearance:(UISwitch*)view];
    }
    else if ([viewClass isSubclassOfClass:[UIStepper class]])
    {
        [self stepperAppearance:(UIStepper*)view];
    }
    else if ([viewClass isSubclassOfClass:[UISegmentedControl class]])
    {
        [self segmentAppearance:(UISegmentedControl*)view];
    }
    else if ([viewClass isSubclassOfClass:[UISlider class]])
    {
        [self sliderAppearance:(UISlider*)view];
    }
    /*
     No appearance for UIImageView
    else if ([viewClass isSubclassOfClass:[UIImageView class]])
    {
        UIImageView *newView = (UIImageView*)view;
    }
    else if ([viewClass isSubclassOfClass:[UIActivityIndicatorView class]]) 
    {
        //UIActivityIndicatorView has no colors
    }
    */
    else if ([viewClass isSubclassOfClass:[UILabel class]])
    {
        [self labelAppearance:(UILabel*)view];
    }
    else if ([viewClass isSubclassOfClass:[UIButton class]])
    {
        [self buttonAppearance:(UIButton*)view];
    }
    //any other view that we don't have an implementation for, we cannot do much about.
}

#pragma mark - remove "undeclared selector" clang warnings - you must implement these methods in your code.

- (void) valueChanged:(id)value
{}

- (void) buttonPressed:(id)button
{}

- (void) touchUpInside:(id)value
{}

- (void) touchUpOutside:(id)value
{}

@end
