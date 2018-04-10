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
@import CoreText;

@interface AutoStandards()
{}

@property (nonatomic) NSMutableDictionary *elementClasses;
@property (nonatomic) NSString *navBarStyle;

@end

@implementation AutoStandards
{
    
}
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
            sharedInstance = [self new];
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
    mainBackgroundIsDark = 2;   //reset cached values
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
	if (settings[@"useWebColors"])
		self.useWebColors = YES;
    NSDictionary *colors = settings[@"AutoColors"];
    NSString *fontName = settings[@"AutoFont"];
    NSDictionary *elementClasses = settings[@"AutoClasses"];
    
    if (settings[@"AlternativeAppearances"])
    {
        NSMutableDictionary *alternativeAppearances = [settings[@"AlternativeAppearances"] mutableCopy];
        alternativeAppearances[AutoStandardAppearance] = colors;
        self.alternativeAppearances = alternativeAppearances;
    }
    
    //we havn't set appearances before or use the same - update those values
    if (!self.currentAppearance || [self.currentAppearance isEqualToString:AutoStandardAppearance])
    {
        self.currentAppearance = AutoStandardAppearance;
    }
    else
    {
        colors = self.alternativeAppearances[self.currentAppearance];
    }
    
    [self setAppearance:colors];
    
    //TODO: these are shared among appearances, but shouldn't be! NO! We should be able to have shared fonts and classes, but also not-shared if we need such.
    if (fontName)
    {
        //if font can't be found or don't exist, we use the standard font.
        self.standardFont = [UIFont fontWithName:fontName size:14];
        if (!self.standardFont)
        {
            NSLog(@"No '%@' font! Available fonts: %@", settings[@"AutoFont"], [UIFont familyNames]);
        }
    }
    if (elementClasses)
    {
        [self parseClasses:elementClasses];
    }
    if (update) [self updateAppearance];
}

//We can't store platform specific values in the dict, convert those here:
- (void) parseClasses:(NSDictionary*)elementClasses
{
    if (!elementClasses) return;
    if (!self.elementClasses)
		self.elementClasses = [NSMutableDictionary new];
    
    for (NSString *classString in elementClasses)
    {
        NSMutableDictionary *definitions = self.elementClasses[classString];
        if (!definitions)
        {
            definitions = [NSMutableDictionary new];
            self.elementClasses[classString] = definitions;
        }
        
        NSDictionary *ruleList = elementClasses[classString];
        [ruleList enumerateKeysAndObjectsUsingBlock:^(NSString *ruleKey, NSDictionary *rule, BOOL * _Nonnull stop)
        {
            //ruleKey e.g. "title"
			AutoStandardClassDefinition *oldDefinition = definitions[ruleKey];
            AutoStandardClassDefinition *newDefinition = [[AutoStandardClassDefinition alloc] initWithDictionary:rule];
			
			//make sure the new implementation knows about the current views
			newDefinition.implementedViews = oldDefinition.implementedViews;
			definitions[ruleKey] = newDefinition;
        }];
    }
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
     we may also have application specific colors, not suitible for generalization. We put those into our standard colors, so you later can ask for them like this:
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
    
	self.navBarStyle = appearance[@"AutoNavBarStyle"];
	if ([self.navBarStyle isKindOfClass:[NSArray class]])
		self.navBarStyle = ((NSArray*)self.navBarStyle)[0];
	
	//set tint color on all objects
    UIColor *tintColor = [self standardColor:AutoColorTintColor];
	
    Class uiApplication = NSClassFromString(@"UIApplication");
    if (uiApplication)
    {
        //We have access to the uiapplication class (not an extension).
		
		//This is not how you update status bar anyore!
        //[[uiApplication sharedApplication] setStatusBarStyle:newStyle]; was depricated in IOS 9! So don't waste anymore time with this!
		//Look at color:(AutoColor)color forView:(UIView*)view method:(AutoSetValue)method
		//and: AutoSetValueBackgroundColor: - for each individual navBar you need to set the statusBarStyle.
		
        //we set tint color on the main window which will propagate to all views where their superviews tint-color is not set.
		dispatch_async(dispatch_get_main_queue(), ^(void)
		{
			[[uiApplication sharedApplication] keyWindow].tintColor = tintColor;
		});
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

+ (BOOL) mainBackgroundIsDark
{
    if (mainBackgroundIsDark == 2)
        mainBackgroundIsDark = [self colorIsDark:[[self sharedInstance] standardColor:AutoColorMainViewBackground]];
    return mainBackgroundIsDark;
}

#pragma mark - helpers

///Auto add dedicated selectors, callSign is @"Pressed:" or @"Pressed" for buttons
- (SEL) dedicatedSelectorForTarget:(id)target propertyName:(NSString*)propertyName callSign:(NSString*)callSign
{
	if (!propertyName || !callSign)
	{
		return nil;
	}
	NSString *dedicatedSelector = [propertyName stringByAppendingString:callSign];
	SEL selector = NSSelectorFromString(dedicatedSelector);
	if (dedicatedSelector && [target respondsToSelector:selector])
	{
		return selector;
	}
	return nil;
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
            return [self standardFont:24];
            break;
        }
        case AutoFontSubTitle:
        {
            return [self standardFont:20];
            break;
        }
        case AutoFontSmall:
        {
            return [self standardFont:10];
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
	if (amount == 0)
		return;
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

CGRect AutoSafeAreaInset(UIView* view)
{
	CGRect rect = view.bounds;
	if (@available(iOS 11.0, *))
	{
		CGFloat topBarOffset = view.safeAreaInsets.top;
		AutoSliceRect(&rect, topBarOffset, CGRectMinYEdge);
		AutoSliceRect(&rect, view.safeAreaInsets.bottom, CGRectMaxYEdge);
		AutoSliceRect(&rect, view.safeAreaInsets.left, CGRectMinXEdge);
		AutoSliceRect(&rect, view.safeAreaInsets.right, CGRectMaxXEdge);
	}
	return rect;
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
    return CGSizeMake(51, 31);
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
    return [self switchWithName:nil target:target inView:superView];
}

- (UISwitch*) switchWithName:(NSString*)propertyName target:(id)target inView:(UIView*)superView
{
    CGSize size = [self standardSwitchSize];
    UISwitch *ui_switch = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    //ui_switch.translatesAutoresizingMaskIntoConstraints = NO;
    [self switchAppearance:ui_switch];
    
    NSString *dedicatedSelector = nil;
    NSString *dedicatedSelectorColon = nil;
    if (propertyName)
    {
        dedicatedSelector = [propertyName stringByAppendingString:@"Changed"];
        dedicatedSelectorColon = [propertyName stringByAppendingString:@"Changed:"];
    }
    if (dedicatedSelector && [target respondsToSelector:NSSelectorFromString(dedicatedSelector)])
    {
        [ui_switch addTarget:target action:NSSelectorFromString(dedicatedSelector) forControlEvents:UIControlEventValueChanged];
    }
    else if (dedicatedSelectorColon && [target respondsToSelector:NSSelectorFromString(dedicatedSelectorColon)])
    {
        [ui_switch addTarget:target action:NSSelectorFromString(dedicatedSelectorColon) forControlEvents:UIControlEventValueChanged];
    }
    else if ([target respondsToSelector:@selector(valueChanged:)])
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

- (UISegmentedControl*) segmentedControlWithName:(NSString*)propertyName target:(id)target inView:(UIView*)superView
{
    UISegmentedControl *segment = [UISegmentedControl new];
	
	NSString *dedicatedSelector = nil;
	NSString *dedicatedSelectorColon = nil;
	if (propertyName)
	{
		dedicatedSelector = [propertyName stringByAppendingString:@"Changed"];
		dedicatedSelectorColon = [propertyName stringByAppendingString:@"Changed:"];
		
		//check if we have titles for this segment we can use automatically
		NSString *segmentTitleSelector = [propertyName stringByAppendingString:@"Titles"];
		SEL titleSelector = NSSelectorFromString(segmentTitleSelector);
		if ([target respondsToSelector:titleSelector])
		{
			//ARC cannot handle perform selector from string.
			//NSArray *titles = [target performSelector:NSSelectorFromString(segmentTitleSelector)];
			
			IMP imp = [target methodForSelector:titleSelector];
			NSArray* (*function)(id, SEL) = (void *)imp;
			NSArray* titles = target ? function(target, titleSelector) : nil;
			if (titles)
			{
				[titles enumerateObjectsUsingBlock:^(NSString*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
				{
					[segment insertSegmentWithTitle:obj atIndex:idx animated:NO];
				}];
				segment.selectedSegmentIndex = 0;
			}
		}
	}
	if (dedicatedSelector && [target respondsToSelector:NSSelectorFromString(dedicatedSelector)])
	{
		[segment addTarget:target action:NSSelectorFromString(dedicatedSelector) forControlEvents:UIControlEventValueChanged];
	}
	else if (dedicatedSelectorColon && [target respondsToSelector:NSSelectorFromString(dedicatedSelectorColon)])
	{
		[segment addTarget:target action:NSSelectorFromString(dedicatedSelectorColon) forControlEvents:UIControlEventValueChanged];
	}
	else if ([target respondsToSelector:@selector(valueChanged:)])
	{
		[segment addTarget:target action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
	}
	
    [self segmentAppearance:segment];
    [superView addSubview:segment];
    return segment;
}

- (void) segmentAppearance:(UISegmentedControl*)view
{
	[self font:AutoFontBody color:AutoColorNothing extraAttributes:nil forView:view method:AutoSetValueTitleTextAttributesNormalState];
    [self color:AutoColorLighterViewBackground forView:view method:AutoSetValueBackgroundColor];
    [self color:AutoColorTintColor forView:view method:AutoSetValueTintColor];
    [self color:AutoColorTintColor forView:view method:AutoSetValueTitleTextAttributesNormalState];
    //Should we use this? [view setTitleTextAttributes:<#(nullable NSDictionary *)#> forState:<#(UIControlState)#>]
}

+ (void)autoShrinkSegmentLabels:(UISegmentedControl*)segmentedControl
{
	if (segmentedControl.numberOfSegments == 0) return;
	
	CGFloat width = segmentedControl.bounds.size.width;
	NSMutableDictionary *attributes = [[segmentedControl titleTextAttributesForState:UIControlStateNormal] mutableCopy];
	UIFont *font = attributes[NSFontAttributeName];
	if (!font)
	{
		
	}
	
	//How much space have each label? We don't have to care for their margins. Or? it seems that we sometimes need margins but not always... weird! Investigate!
	width = floor(width / segmentedControl.numberOfSegments) - 5;
	CGFloat minFontSize = font.pointSize;
	for (NSInteger index = 0; index < segmentedControl.numberOfSegments; index++)
	{
		NSString *title = [segmentedControl titleForSegmentAtIndex:index];
		CGFloat fontSize = [self actualFontSizeForString:title font:font constrainedToSize:CGSizeMake(width, segmentedControl.bounds.size.height)];
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

- (UIBarButtonItem*) barButtonWithName:(NSString*)propertyName target:(id)target inView:(UIView*)view
{
	//To create a bar button item, we just make a custom view, and add a button to it - so we can get universal look and feel.
	//Note that you need to set widths yourself!
	
	//According to the docs this is the preferable bar button size
	NSUInteger height = 20;
	if ([target isKindOfClass:[UIViewController class]])
	{
		//but nowadays we have no idea what the bar size is, so we need to check it if we can. When rotating our controllers need to handle this themselves.
		height = ((UIViewController*)target).navigationController.navigationBar.frame.size.height - 20;	//Note: we subtract by 20 for margins.
	}
    UIButton *button = [self buttonWithName:propertyName target:target inView:nil];
    button.frame = CGRectMake(0, 0, height, height);
	NSLayoutConstraint * widthConstraint = [NSLayoutConstraint constraintWithItem:button
																		attribute: NSLayoutAttributeWidth
																		relatedBy: NSLayoutRelationEqual
																		   toItem: nil
																		attribute: NSLayoutAttributeNotAnAttribute
																	   multiplier: 1
																		 constant: height];
	NSLayoutConstraint * heightConstraint = [NSLayoutConstraint constraintWithItem:button
																		 attribute: NSLayoutAttributeHeight
																		 relatedBy: NSLayoutRelationEqual
																			toItem: nil
																		 attribute: NSLayoutAttributeNotAnAttribute
																		multiplier: 1
																		  constant: height];
	[button addConstraint:widthConstraint];
	[button addConstraint:heightConstraint];
	
	UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    return barButton;
}

- (UIButton*) buttonWithName:(NSString*)propertyName target:(id)target inView:(UIView*)view
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	
	SEL dedicatedSelector = [self dedicatedSelectorForTarget:target propertyName:propertyName callSign:@"Pressed"];
    if (dedicatedSelector)
    {
        [button addTarget:target action:dedicatedSelector forControlEvents:UIControlEventTouchUpInside];
    }
    else
    {
		SEL dedicatedSelectorColon = [self dedicatedSelectorForTarget:target propertyName:propertyName callSign:@"Pressed:"];
		if (dedicatedSelectorColon)
		{
			[button addTarget:target action:dedicatedSelectorColon forControlEvents:UIControlEventTouchUpInside];
		}
		else if ([target respondsToSelector:@selector(buttonPressed:)])
		{
			[button addTarget:target action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
		}
    }
    
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.font = [self standardFont:18];
    button.showsTouchWhenHighlighted = YES;
	
    button.contentMode = UIViewContentModeScaleAspectFit;
    
    [self setupButton:button target:target propertyName:propertyName];
    
    [view addSubview:button];
    return button;
}

- (void) setupButton:(UIButton*)button target:(id)target propertyName:(NSString*)propertyName
{
    if (propertyName && [target conformsToProtocol:@protocol(AutoStandardDelegate)])
    {
        AutoStandards *welf = self;
        
        //There is no need to delay anything since the block captures any variables.
        AutoButtonSetupBlock setupBlock = ^(UIImage* image, UIImage* highlight, NSString* title, BOOL useTintedHighlight)
        {
            if (image)
            {
                [button setImage:image forState:UIControlStateNormal];
                if (useTintedHighlight) highlight = [welf tintedImage:image];
            }
            
            if (highlight) [button setImage:highlight forState:UIControlStateHighlighted];
            if (title)
            {
                [button setTitle:title forState:UIControlStateNormal];
                //textbuttons need borders
                button.layer.borderWidth = 1.0 / [[UIScreen mainScreen] scale];
                button.layer.cornerRadius = 5;
            }
        };
		SEL dedicatedSelector = [self dedicatedSelectorForTarget:target propertyName:propertyName callSign:@"Setup:"];
        if (dedicatedSelector)
        {
			//arc cannot release setupBlock
            //[target performSelector:dedicatedSelector withObject:setupBlock];
			
			IMP imp = [target methodForSelector:dedicatedSelector];
			void (*func)(id, SEL, AutoButtonSetupBlock) = (void *)imp;
			func(target, dedicatedSelector, setupBlock);
        }
    }
    else
    {
        //textbuttons need borders so remove border if you use images
        button.layer.borderWidth = 1.0 / [[UIScreen mainScreen] scale];
        button.layer.cornerRadius = 5;
    }
    
    //we need to do this last since it cannot set background color if there is an image - that is not sad since we can override appearances in a subclass or after createViews: has been called.
    [self buttonAppearance:button];
}

- (void) buttonAppearance:(UIButton*)view
{
    [self color:AutoColorTintColor forView:view method:AutoSetValueTintColor];
    
    [self color:AutoColorTintColor forView:view method:AutoSetValueTitleNormalColor];
    [self color:AutoColorHighlightColor forView:view method:AutoSetValueTitleHighlightColor];
    [self color:AutoColorTintColor forView:view method:AutoSetValueBorderColor];
    
    if (![view imageForState:UIControlStateNormal])
    {
        [self color:AutoColorLighterViewBackground forView:view method:AutoSetValueBackgroundColor];
    }
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

+ (void) setPlaceholder:(NSString*)placeholder forTextField:(UITextField*)textField
{
	NSMutableDictionary *textAttributes = textField.defaultTextAttributes.mutableCopy;
	UIColor *color = textAttributes[NSForegroundColorAttributeName];
	textAttributes[NSForegroundColorAttributeName] = [color colorWithAlphaComponent:0.7];
	
	textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:textAttributes];
}

- (UITextField*) textField:(id<UITextFieldDelegate>)delegate placeholder:(NSString*)placeholder inView:(UIView*)superView
{
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectZero];
	//textField.translatesAutoresizingMaskIntoConstraints = NO;
    
    //To change the background color in a UITextField you first need to use a different style of text field to the "rounded" style (such as the "no border" style) either in Interface Builder or programmatically.
    textField.borderStyle = UITextBorderStyleNone;
    //then set the border
    textField.layer.cornerRadius = 5.0f;
    textField.layer.masksToBounds = YES;
    textField.layer.borderWidth = 1.0 / [[UIScreen mainScreen] scale];
    
    //it removes margins - add those by using magic views!
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 28)];
    textField.leftView = view;
    textField.leftViewMode = UITextFieldViewModeAlways;
    
    //it only works with whitebackground - add your own clear-button!
    
    textField.delegate = delegate;
    textField.clearButtonMode = UITextFieldViewModeAlways;
    textField.adjustsFontSizeToFitWidth = YES;
    textField.minimumFontSize = 7;
    textField.font = [self standardFont:14];
    
    [self textFieldAppearance:textField];
    //also set the placeholder if such exists - never does...
    if (placeholder)
	{
		NSMutableDictionary *textAttributes = textField.defaultTextAttributes.mutableCopy;
		UIColor *color = textAttributes[NSForegroundColorAttributeName];
		textAttributes[NSForegroundColorAttributeName] = [color colorWithAlphaComponent:0.7];
		textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:textAttributes];
	}
    
    [superView addSubview:textField];
    return textField;
}

- (void) textFieldAppearance:(UITextField*)view
{
    [self color:AutoColorLighterViewBackground forView:view method:AutoSetValueBackgroundColor];
    [self color:AutoColorTintColor forView:view method:AutoSetValueBorderColor];
    [self color:AutoColorBodyText forView:view method:AutoSetValueDefaultTextAttributes];
}

- (UISlider*) sliderWithName:(NSString*)propertyString target:(id)target inView:(UIView*)superView
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
	
	selector = [self dedicatedSelectorForTarget:target propertyName:propertyString callSign:@"ValueChanged"];
	if (!selector)
	{
		selector = [self dedicatedSelectorForTarget:target propertyName:propertyString callSign:@"ValueChanged:"];
	}
	if (!selector)
	{
		selector = @selector(valueChanged:);
		if ([target respondsToSelector:selector])
		{
			[slider addTarget:target action:selector forControlEvents:UIControlEventValueChanged];
		}
	}
	else
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

- (UILabel*) labelWithDelegate:(id)delegate inView:(UIView*)view
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    //label.translatesAutoresizingMaskIntoConstraints = NO;
    
    //default setting
    label.textAlignment = NSTextAlignmentNatural;
    label.adjustsFontSizeToFitWidth = YES;
	label.minimumScaleFactor = 0.1;	//scale factor is horribly stupid - we must know the font-size (and how big the rendered fontsize gets) to know the correct factor. Just ignore it and set it real low. 
    label.numberOfLines = 0;
    [self labelAppearance:label];
    
    [view addSubview:label];
    return label;
}

- (void) labelAppearance:(UILabel*)view
{
    [self font:AutoFontLabel color:AutoColorNothing extraAttributes:nil forView:view method:AutoSetValueFont];
    [self color:AutoColorBodyText forView:view method:AutoSetValueTextColor];
}

+ (CGSize) string:(NSString*)string constrainedToSize:(CGSize)size
{
    return [self string:string constrainedToSize:size fontSize:[[AutoStandards sharedInstance]standardFontSize] font:nil];
}

+ (CGSize) string:(NSString*)string constrainedToSize:(CGSize)size fontSize:(CGFloat)fontSize font:(UIFont *)font
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

//binary search for an optimal "peak" or edge, we can never know when we are inside if it is on the edge (it could be a few steps left) - but by doing a binary search we will come as close to the edge as fast as possible.
+ (NSInteger) binarySearchBottomBound:(NSInteger)bottom upperBound:(NSInteger)upper calculationBlock:(BOOL (^)(NSInteger index))isWithinTarget
{
	NSInteger center = (bottom + upper) / 2;
	if (isWithinTarget(center))
	{
		if (bottom == upper)
			return center;
		
		//we went too low - constrain in the upper region
		NSInteger result = [self binarySearchBottomBound:center + 1 upperBound:upper calculationBlock:isWithinTarget];
		if (result != NSNotFound)
		{
			//we were as close as we could go after all
			return result;
		}
		return center;
	}
	else if (center > bottom)
	{
		//go lower
		return [self binarySearchBottomBound:bottom upperBound:center - 1 calculationBlock:isWithinTarget];
	}
	return NSNotFound;
}

//Docs says: Shrink a font - fix this. It isn't working!
/*
 Note: boundingRectWithSize does not work for strings at all and for attributed strings only when having more than one line. We simply cannot use that and need to implement our own!
 We can't use sizeToFit on a dummy-label since it won't work with numberOfLines = 1
 We must build our own layouter and re-draw the line until it fits.
 TODO: do the commented method for lines > 1.
 */
+ (CGFloat) actualFontSizeForString:(NSString*)string font:(UIFont*)font constrainedToSize:(CGSize)size
{
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 0.001;
    
    //NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    //[style setLineBreakMode:NSLineBreakByWordWrapping];
	NSMutableDictionary *attributes = [NSMutableDictionary new];
	if (font)
	{
		attributes[NSFontAttributeName] = font;
	}
	//, NSParagraphStyleAttributeName : style
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string attributes:attributes];
	
	
	CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributedString);
	__block CGSize bounds = CTLineGetBoundsWithOptions(line, kCTLineBoundsUseGlyphPathBounds).size;
	CFRelease(line);
	
	CGFloat fontSize = font.pointSize;
	if (bounds.height <= size.height && bounds.width <= size.width)
	{
		return fontSize;
	}
	
	NSInteger index = [self binarySearchBottomBound:7 upperBound:fontSize - 1 calculationBlock:^BOOL(NSInteger index) {
		
		
		attributes[NSFontAttributeName] = [font fontWithSize:index];
		[attributedString setAttributes:attributes range:NSMakeRange(0, string.length)];
		CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributedString);
		
		//optical bounds seems to be used in labels
		bounds = CTLineGetBoundsWithOptions(line, kCTLineBoundsUseOpticalBounds | kCTLineBoundsIncludeLanguageExtents ).size;
		CFRelease(line);
		
		return ceil(bounds.height) < size.height && ceil(bounds.width) < size.width;
		
	}];
	
	if (index == NSNotFound)
	{
		return 7;
	}
	return index;
	
	
	/*
	
    NSStringDrawingOptions options = NSStringDrawingUsesDeviceMetrics | NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading;	// | NSStringDrawingTruncatesLastVisibleLine
	
    if (size.height == MAXFLOAT)
    {
        //We can only shrink if this is a single line - or a constrained rectangle. Supplying maxFloat means that we want a single line.
        size.height = (int)[measure boundingRectWithSize:CGSizeMake(MAXFLOAT, MAXFLOAT) options:options context:nil].size.height;
    }
	
    CGRect rect = [measure boundingRectWithSize:size options:options context:context];
	CGSize newSize = size;
	while (rect.size.height > size.height && newSize.height > 4)
	{
		font = [font fontWithSize:font.pointSize * context.actualScaleFactor];
		attributes = @{ NSFontAttributeName : font };
		measure = [[NSAttributedString alloc] initWithString:string attributes:attributes];
		newSize.height--;
		rect = [measure boundingRectWithSize:newSize options:options context:context];
		rect = CGRectIntegral(rect);
		if ([string isEqualToString:@"Regular Regular Regular Regular Regular Regular"])
		{
			NSLog(@"context %f %f - rect %@ bound by: %@ \nnew point size: %f", context.minimumScaleFactor, context.actualScaleFactor, NSStringFromCGSize(rect.size), NSStringFromCGSize(size), font.pointSize * context.actualScaleFactor);
		}
	}
	//rect = [string boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:context];
	
	//NSLog(@"%@ context %f %f - width %@ input: %@", string, context.minimumScaleFactor, context.actualScaleFactor, NSStringFromCGSize(rect.size), NSStringFromCGSize(size));
    return floor(font.pointSize * context.actualScaleFactor);
	 */
}

+ (CGSize) attributedString:(NSAttributedString*)string constrainedToSize:(CGSize)size
{
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading | NSStringDrawingTruncatesLastVisibleLine;
    CGRect rect = [string boundingRectWithSize:size options:options context:nil];
    
    if (CGPointEqualToPoint(rect.origin, CGPointZero) == NO)
    {
        NSLog(@"AutoStandards constrainedToSize :: did not get a size with zero origin");
    }
    rect = CGRectIntegral(rect);
    
    return rect.size;
}



#pragma mark - appearance for stuff we don't create

- (void) navigationBarAppearance:(UINavigationBar*)view
{
    [self color:AutoColorMenuText forView:view method:AutoSetValueMenuTextAttributes];
    [self color:AutoColorMenuText forView:view method:AutoSetValueTintColor];
	
	AutoColor barBackgroundColor = AutoColorBarBackground;
	if (self.navBarStyle)	//if we have transparent views, we can decide this automatically.
		barBackgroundColor = AutoColorMainViewBackground;
	[self color:barBackgroundColor forView:view method:AutoSetValueBackgroundColor];
}

- (void) barButtonAppearance:(UIBarItem*)view
{
    [AutoStandards color:AutoColorMenuText forView:(UIView*)view method:AutoSetValueTintColor];
    [AutoStandards color:AutoColorMenuText forView:(UIView*)view method:AutoSetValueTitleTextAttributesNormalState];
    [AutoStandards color:AutoColorHighlightColor forView:(UIView*)view method:AutoSetValueTitleTextAttributesHighligtedState];
}

#pragma mark - methods for doing it all at once

/*
 I have an idea:
 create views inside a viewController-like object, where the layout happens in (and the rects are found in) layoutObject - and add them to the superView
 The layoutObject holds frames, viewController holds views. Can be the same object or separated.
 + (void) createViews:(id)viewController layoutObject:(id)layoutObject superView:(UIView*)view
 OR
 If I need to separate them (e.g. using a layout object), I can just put both the views AND the rects into a separate object.
 
 No, this doesn't help at all! What I need is separation from rects and views, so I can switch rects at any time and cache their calculation without needing to cache the views. Think of a table view where all rects are calculated offline, then the cells gets created (or reused) with subviews (connected to the cell's rects). NOW, apply a precalculated array of rects.
 */
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
	//This fetches (and associates views with frames if such exists) or creates views, for properties that have classes that AutoStandards deems as views. Other classes are skipped.
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
					if ([propertyString containsString:@"delegate"] == NO)
					{
						//NSLog(@"delegate error here!");
						//TODO: if we have views that are our delegates, and we set those using properties (which is how its done) - then we will create
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
					}
					else
					{
						NSLog(@"debug: skipping creating of view with class %@ property name '%@' for controllerClass %@", classString, propertyString, [viewController class]);
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
		//it could also mean that we want to re-run a portion of creation then we will just add the view to the same sets and dictionaries again (which is ok).
        if (ivarRectName)
        {
            [self addElement:newView withIvarRectName:ivarRectName toViewsWithFrames:viewsWithFrames];
        }
        
        //Should we include UIResponder or CALayer?
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
            [self addElement:newView withIvarRectName:ivarRectName toViewsWithFrames:viewsWithFrames];
        }
        
        //we also may want to change it's appearance so we set it here
        [allViews addObject:newView];
        return YES;
    }
    return NO;
}

- (void) addElement:(id)element withIvarRectName:(NSString*)ivarRectName toViewsWithFrames:(NSMapTable *)viewsWithFrames
{
    //we have started to allow controllers - that is not a very good idea right? Messes up the whole thing! - no, I think we can handle that.
    if ([element respondsToSelector:@selector(setFrame:)])
    {
        [viewsWithFrames setObject:element forKey:ivarRectName];
    }
    else if ([element isKindOfClass:[UIViewController class]])
    {
        UIViewController *controller = (UIViewController*)element;
        [viewsWithFrames setObject:controller.view forKey:ivarRectName];
    }
}

/**
 Find the name of all views who has a corresponding rect having the same name but ending with "Rect"
 Build a dictionary with strings for all Ivars ending with "Rect", such that result becomes: { @"view" : @"viewRect" }. It does not check if "view" actually exist, only that viewRect does.
 No type checking.
 **/
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
            if (CGRectEqualToRect(view.frame, rect))
			{
				//don't modify if equal
				continue;
			}
			
			BOOL shrinkSegmentLabels = view.bounds.size.width != rect.size.width;
            view.frame = rect;
            if (shrinkSegmentLabels && [view isKindOfClass:[UISegmentedControl class]])
            {
                //automatically adjust labels inside a segmented control - if the width has changed!
                [self autoShrinkSegmentLabels:(UISegmentedControl*)view];
            }
        }
    }
}

- (id) standardWidgetNamed:(NSString*)propertyString fromString:(NSString*)classString delegate:(id)delegate superView:(UIView*)view
{
    id newView = nil;
    
    Class viewClass = NSClassFromString(classString);
    if ([viewClass conformsToProtocol:@protocol(AutoStandardElement)])
    {
        newView = [viewClass viewWithDelegate:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UIProgressView class]])
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
        newView = [self switchWithName:propertyString target:delegate inView:view];
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
		newView = [self segmentedControlWithName:propertyString target:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UISlider class]])
    {
		newView = [self sliderWithName:propertyString target:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UIImageView class]])
    {
        newView = [[UIImageView alloc] initWithFrame:CGRectZero];
        ((UIImageView*)newView).contentMode = UIViewContentModeScaleAspectFit;
        [view addSubview:newView];
    }
    else if ([viewClass isSubclassOfClass:[UILabel class]])
    {
        newView = [self labelWithDelegate:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UIButton class]])
    {
        newView = [self buttonWithName:propertyString target:delegate inView:view];
    }
    else if ([viewClass isSubclassOfClass:[UIBarButtonItem class]])
    {
        newView = [self barButtonWithName:propertyString target:delegate inView:view];
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
    
    //override styles
    if (propertyString && [delegate respondsToSelector:@selector(elementClasses)])
    {
        NSString *classKey = [((id<AutoStandardDelegate>)delegate) elementClasses][propertyString];
		if (classKey)
		{
			AutoStandardClassDefinition *definition = self.elementClasses[classString][classKey];
			if (definition)
			{
				//To keep track of this views class, so we can change its appearance when the class changes - the definition saves them to an  weak array.
				[definition implementOn:newView];
			}
		}
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
    //sometimes several attributes are stored in the same property, to handle that we can store previously used attributes in the "extra" item
    NSMutableDictionary *attributes = [extraAttributes mutableCopy];
    if (!attributes)
    {
        attributes = [NSMutableDictionary new];
    }
	
	UIFont *font = [self fontWithType:fontType];
	
	//TODO: document this!
	NSDictionary *autoDescriptor = extraAttributes[@"AutoFontDescriptor"];
	if (autoDescriptor)
	{
		//append stuff to the fonts descriptor, if we want bold we should only need a dict with "bold" in it		
		//a dictionary on the form: UIFontDescriptorAttributeName : id
		UIFontDescriptor *fontDescriptor = [font.fontDescriptor fontDescriptorByAddingAttributes:autoDescriptor];
		font = [UIFont fontWithDescriptor:fontDescriptor size:font.pointSize];
		
	}
    attributes[NSFontAttributeName] = font;
	if (colorType != AutoColorNothing)
	{
		UIColor *color = [self standardColor:colorType];
		attributes[NSForegroundColorAttributeName] = color;
	}
    
    switch (method)
    {
        case AutoSetValueTitleTextAttributesNormalState:
        {
            [((UISegmentedControl*)view) setTitleTextAttributes:attributes forState:UIControlStateNormal];
            break;
        }
        case AutoSetValueTitleTextAttributesHighligtedState:
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
            //we can't set the color at the same time since then we can't replace appearances in a ordered/correct fashion
            break;
        }
        case AutoSetValueMenuTextAttributes:
        {
            ((UINavigationBar*)view).titleTextAttributes = attributes;
            break;
        }
        case AutoSetValueDefaultTextAttributes:
        {
            UITextField *textField = ((UITextField*)view);
            textField.defaultTextAttributes = attributes;
            if ([view isKindOfClass:[UITextField class]] && (textField.placeholder || textField.attributedPlaceholder))
            {
                //if we have a placholder we need to update its color too!
                NSString *text = textField.placeholder;
                if (!text)
                    text = textField.attributedPlaceholder.string;
				UIColor *color = attributes[NSForegroundColorAttributeName];
				if (color)
				{
					NSMutableDictionary *textAttributes = attributes.mutableCopy;
					textAttributes[NSForegroundColorAttributeName] = [color colorWithAlphaComponent:0.7];
					textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:text attributes:textAttributes];
				}
				else
				{
					textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:text attributes:attributes];
				}
            }
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
	if (extraAttributes)
	{
		[appearances setObject:@{ @"color" : @(colorType), @"font" : @(fontType), @"extra" : extraAttributes } forKey:@(method)];
	}
	else
	{
		[appearances setObject:@{ @"color" : @(colorType), @"font" : @(fontType) } forKey:@(method)];
	}
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
            
            [self font:fontType color:colorType extraAttributes:objectAppearances[@"extra"] forView:view method:method];
        }
        else
        {
            //else it is just a color
            [self color:object.integerValue forView:view method:method];
        }
    }];
    
    //TODO: think on this! Perhaps we should build this in a smarter way? - like a method type. YES! Not all scrollviews have mainView bg!
    if ([view isKindOfClass:[UIScrollView class]])
    {
        if ([AutoStandards mainBackgroundIsDark])
        {
            ((UIScrollView*)view).indicatorStyle = UIScrollViewIndicatorStyleWhite;
        }
    }
}

- (void) color:(AutoColor)color forView:(UIView*)view method:(AutoSetValue)method
{
    NSMutableDictionary *appearances = objc_getAssociatedObject(view, AUTO_MAP_VIEW_ACTIONS);
    
    UIColor *colorObject = [self standardColor:color];
    switch (method)
    {
        case AutoSetValueProtocol:
        {
            [((id<AutoStandardDelegate>)view) setAutoColor:color forColor:colorObject];
            break;
        }
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
				BOOL backgroundIsDark = [AutoStandards colorIsDark:colorObject];
				//we either want to have colors on translutient navbars, OR we want this "frosted glass" look. Needs to be set in settings.
				//But we always want to set the bar style.
				if (backgroundIsDark)
				{
					nav.barStyle = UIBarStyleBlack;
				}
				else
				{
					nav.barStyle = UIBarStyleDefault;
				}
				
				//we want a solid color
				if (self.navBarStyle == nil)
				{
					nav.barTintColor = colorObject;
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
        case AutoSetValueDefaultTextAttributes:
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

static int mainBackgroundIsDark = 2;
- (void) switchAppearanceTo:(NSString*)name
{
    mainBackgroundIsDark = 2;
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
    // NOTE: You also have presentedViewController, UITabBarController...
    
    UIViewController *root = [AutoStandards topViewController];
    if ([root isKindOfClass:[UITabBarController class]])
    {
        root = ((UITabBarController*)root).selectedViewController;
    }
	
	UIView *navBar = nil;
    UINavigationController *nav;
    if ([root isKindOfClass:[UINavigationController class]]) nav = (UINavigationController*)root;
    else nav = root.navigationController;
    if (nav)
	{
		navBar = nav.navigationBar;
		[self updateAppearanceForView:navBar];
	}
		
    dispatch_block_t updateBlock = ^(void)
    {
		//dig into the heirarcy to get our definitions' views
		for (NSDictionary *definitions in self.elementClasses.allValues)
		{
			for (AutoStandardClassDefinition *definition in definitions.allValues)
			{
				for (UIView* view in definition.implementedViews.objectEnumerator)
				{
					[definition implementOn:view];
				}
			}
		}
		
		for (UIView *view in self.viewsWithActions)
		{
			if (view != navBar)
				[self updateAppearanceForView:view];
		}
    };
	
    UIViewAnimationOptions standardOptions = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut;
    [UIView animateWithDuration:0.4 delay:0 options: standardOptions animations:updateBlock completion:nil];
	
	NSDictionary *userInfo = @{ @"name" : self.currentAppearance ? self.currentAppearance : @"", @"dark" : @([AutoStandards mainBackgroundIsDark]) };
	[[NSNotificationCenter defaultCenter] postNotificationName:AutoStandardsHasUpdatedAppearance object:nil userInfo:userInfo];
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

#pragma mark Helpers

+ (UIViewController*) topViewController
{
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    //Child is usually nil, really hard to know what is the topViewController, there are so many controlling controllers...
    UIViewController *child = root.childViewControllerForStatusBarStyle;
    if (child)
    {
        //Can we please find a way to test this?
        NSLog(@"topViewController became %@", child);
        return child;
    }
    
    while (root.presentedViewController)
    {
        root = root.presentedViewController;
    }
    
    return root;
}

//NOTE: This is only available after 8.0, should we really put this here then? Yes, nobody but you are using this.

+ (void) displayAlertWithTitle:(NSString*)title message:(NSString*)message cancelBlock:(dispatch_block_t)cancelBlock okBlock:(dispatch_block_t)okBlock
{
    [self displayAlertWithTitle:title message:message cancelTitle:nil okTitle:nil cancelBlock:cancelBlock okBlock:okBlock];
}

+ (void) displayAlertWithTitle:(NSString*)title message:(NSString*)message cancelTitle:(NSString*)cancelTitle okTitle:(NSString*)okTitle cancelBlock:(dispatch_block_t)cancelBlock okBlock:(dispatch_block_t)okBlock
{
    if (!cancelTitle) cancelTitle = NSLocalizedString(@"Cancel", nil);
    if (!okTitle) okTitle = NSLocalizedString(@"OK", nil);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:okTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * action)
    {
        if (okBlock) okBlock();
    }];
    [alert addAction:defaultAction];
    
    if (cancelBlock)
    {
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * action)
        {
            cancelBlock();
        }];
        [alert addAction:cancelAction];
    }
    
    UIViewController *controller = [self topViewController];
    dispatch_block_t presentBlock = ^(void)
    {
        [controller presentViewController:alert animated:YES completion:nil];
    };
    
    autoExecuteOnMainThread(presentBlock);
}

#pragma mark - just here to remove "undeclared selector" clang warnings - you must implement these methods in your code.

- (void) valueChanged:(id)value
{}

- (void) buttonPressed:(id)button
{}

- (void) touchUpInside:(id)value
{}

- (void) touchUpOutside:(id)value
{}

@end

@implementation AutoStandardClassDefinition

- (instancetype) initWithDictionary:(NSDictionary*)rule
{
    self = [super init];
	
    //E.g. "textAlignment" : "center", or "fontSize" : 24
    NSString *textAlignment = @"textAlignment", *fontStyle = @"fontStyle";
    if (rule[textAlignment])
    {
        static NSDictionary *textAlignmentDict = nil;
        if (!textAlignmentDict)
        {
            textAlignmentDict = @{ @"center": @(NSTextAlignmentCenter), @"left" : @(NSTextAlignmentLeft), @"right" : @(NSTextAlignmentRight), @"natural" : @(NSTextAlignmentNatural), @"justified" : @(NSTextAlignmentJustified) };
        }
        _textAlignment = [textAlignmentDict[rule[textAlignment]] integerValue];
        _definedKeys |= AutoClassDefinitionTextAlignment;
    }
    if (rule[fontStyle])
    {
        static NSDictionary *textStyles = nil;
        if (!textStyles)
        {
            textStyles = @{ @"title": @(AutoFontTitle), @"subTitle" : @(AutoFontSubTitle), @"body" : @(AutoFontBody), @"label": @(AutoFontLabel) };
        }
        _fontStyle = [textStyles[rule[fontStyle]] integerValue];
        _definedKeys |= AutoClassDefinitionFontStyle;
    }
	
    return self;
}

- (void) implementOn:(UIView*)view
{
	//we store a weak list of all our implementedViews
	if (!self.implementedViews)
		self.implementedViews = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
	
    UILabel *label = nil;
    UIButton *button = nil;
    if ([view isKindOfClass:[UILabel class]])
    {
        label = (UILabel*)view;
    }
    else if ([view isKindOfClass:[UIButton class]])
    {
        button = (UIButton*)view;
        label = button.titleLabel;
    }
    
    if (label && _definedKeys & AutoClassDefinitionTextAlignment)
    {
        label.textAlignment = _textAlignment;
    }
    if (_definedKeys & AutoClassDefinitionFontStyle && label)
    {
        label.font = [[AutoStandards sharedInstance] fontWithType:_fontStyle];
    }
    else if (_definedKeys & AutoClassDefinitionFontSize && label)
    {
        label.font = [AutoStandards standardFont:_fontSize];
    }
	
	//Keep track of active views that will remove themselves (since they are weak) when unloaded.
	[self.implementedViews addObject:view];
}

@end
