//
//  AutoStandards.h
//  Aggressive Writing
//
//  Created by Olof Thorén on 2013-10-25.
//  Copyright (c) 2013 Aggressive Development. All rights reserved.
//

@import UIKit;
/**
 Short how-to:
 
 in the .h file we have
 @property (nonatomic) UIButton *startButton;
 @property (nonatomic) UILabel *startLabel;
 
 in the .m file we have this:
 @implementation ADViewController
 {
    CGRect startLabelRect, startButtonRect; //notice that the rects have the same names as the UI elements. This is what links them together without using any code.
 }
 
 - (void)loadView
 {
    [super loadView];
    [AutoStandards createViews:self superView:self.view];   //auto-create all views for this ViewController and place them in it's view
 }
 
 //It is convinient to use viewWillLayoutSubviews for setting the frames, since it will be called whenever the device rotates. But it might also interfere with your animations. Use responsibly!
 - (void) viewWillLayoutSubviews
 {
    //Now we just calculate our views with ordinary simple math and variables.
 
    CGFloat margin = 10;
    CGFloat touchSize = 44;
    startLabelRect = CGRectMake(margin, margin, self.view.bounds.size.width, touchSize);
    startButtonRect = CGRectMake(margin, margin + CGRectGetMaxY(startLabelRect), 100, touchSize);
    
    //Then we set all rects at the same time with this simple function
    [AutoStandards setFrames:self];
 }
 
 To set and change colors:
 Either have a file with all settings in your bundle called "AutoStandardSettings.json", or at startup (before creating views), call parseSettings: with a dictionary of colors and font names.
 Now, your app will have a different look.
 
 If you have downloaded a new dictionary, you need to call updateAppearance, to get the new values.
 
 */

#define AutoStandardsHasUpdatedAppearance @"AutoStandardsHasUpdatedAppearance"
#define AutoStandardAppearance @"AutoStandard"
#define AUTO_NIL_ENDING __attribute__ ((__sentinel__))

#define UIViewAutoresizingMaskAll UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin
#define AUTO_RECTS_ARRAY "AUTO_RECTS_ARRAY"
#define AUTO_MAP_VIEWS "AUTO_MAP_VIEWS"
#define AUTO_MAP_VIEW_ACTIONS "AUTO_MAP_VIEW_ACTIONS"

//AutoColorNothing tells us that we should not auto-handle this color/method.
typedef NS_ENUM(NSUInteger, AutoColor)
{
	AutoColorMainViewBackground = 1,
    AutoColorLighterViewBackground,
    AutoColorOverlayViewBackground,
    AutoColorBarBackground,
	AutoColorUnselectedCell,
    AutoColorSelectedCell,
    AutoColorTintColor,
    AutoColorDeleteColor,
    AutoColorCellSeparator,
    AutoColorMenuText,
    AutoColorBodyText,
    AutoColorError,
    AutoColorOK,
    AutoColorHighlightColor,
    AutoColorSpecific_0,
    AutoColorSpecific_1,
    AutoColorSpecific_2,
    AutoColorSpecific_3,
    AutoColorSpecific_4,
    AutoColorSpecific_5,
    AutoColorSpecific_6,
    AutoColorSpecific_7,
    AutoColorSpecific_8,
    AutoColorSpecific_9,
    AutoColorSpecific_11,
    AutoColorSpecific_12,
    AutoColorSpecific_13,
    AutoColorSpecific_14,
    AutoColorSpecific_15,
    AutoColorSpecific_16,
    AutoColorSpecific_17,
    AutoColorSpecific_18,
    AutoColorSpecific_19,
    AutoColorSpecific_20,
    AutoColorSpecific_21,
    AutoColorSpecific_22,
    AutoColorSpecific_23,
    AutoColorSpecific_24,
    AutoColorSpecific_25,
    AutoColorSpecific_26,
    AutoColorSpecific_27,
    AutoColorSpecific_28,
    AutoColorSpecific_29,
    AutoColorSpecific_30,
    AutoColorNothing,
};

//let everybody know how many defined colors there are
#define AutoDefinedColorAmount AutoColorSpecific_0

typedef NS_ENUM(NSUInteger, AutoFont)
{
    AutoFontTitle,
    AutoFontSubTitle,
    AutoFontBody,
    AutoFontLabel
};

//Minimize stringly typing by defining what keys can be used when setting colors on objects
typedef NS_ENUM(NSUInteger, AutoSetValue)
{
    AutoSetValueTitleNormalColor = 1,
    AutoSetValueTitleHighlightColor,
    AutoSetValueBackgroundColor,
    AutoSetValueTextColor,
    AutoSetValueTintColor,
    AutoSetValueOnTintColor,
    AutoSetValueBorderColor,
    AutoSetValueProgressTintColor,
    AutoSetValueMenuTextAttributes,
    
    AutoSetValueTitleTextAttributes,
    AutoSetValueTitleTextAttributesNormalState,
    AutoSetValueTitleTextAttributesHighligtedState,
    AutoSetValueFont,
};

/**
 Color discussion:
 A few standard color types are defined, since these will most likely be the same in every app. They are not ment to describe exactly where to be used, but what they are. If you want to apply the delete color as a table-cell's background you can. If the cell e.g. contains a warning message this is exactly how to think about the color's function. Then, when specifying other colors, you don't need to think about or remember this specific cell - changing the delete color to something apropriate will still make things work for the warning message-cell.
 
 AutoColorMainViewBackground, your main views like your collection views
 AutoColorLighterViewBackground, some views need a lighter background. Could be used for collection view cells.
 AutoColorOverlayViewBackground, overlays like popovers or cells
 AutoColorBarBackground, tabBars and navigation bars
	AutoColorUnselectedCell, some cells can be un/selected
 AutoColorSelectedCell,
 AutoColorTintColor, the main tint color on all your view items.
 AutoColorDeleteColor, usually red, to signal danger
 AutoColorCellSeparator, separators in table views or collection views usually need a different color.
 and so on.
 
 When it comes to appearance, we set colors based on what elements are used for. The defaults may not be prefered, then you can easily override the color settings.
 
 AutoColorArray is a special key in the AutoStandardSettings json file. It contains an array of colors since you most likely will have need for more uses than the limited default set. They will, in order, populate the colors from AutoColorSpecific_0 to AutoColorSpecific_30 (if there are that many). In order to not go crazy with these bizarr names, rename those colors with simple default statements - this will have the added benefit of letting you know which index in the array are taken. Like so:
 
 #define AutoColorUserMessage AutoColorSpecific_0
 #define AutoColorUserMessageText AutoColorSpecific_1
 */

@interface AutoStandards : NSObject

@property (nonatomic) CGFloat standardFontSize;
@property (nonatomic) UIFont* standardFont;
@property (nonatomic) NSMutableDictionary *standardColors;
///Make AutoStandard parse int colors (0-255) instead of floats (0-1).
@property (nonatomic) BOOL useWebColors;
@property (nonatomic) NSHashTable *viewControllers, *viewsWithActions;
@property (nonatomic) NSDictionary *alternativeAppearances;
///The name of the current mode if there are several to choose from.
@property (nonatomic) NSString *currentAppearance;
///When changing appearance both a notification is sent and this block is called (if set). For when a block based event handling is more apropriate.
@property (nonatomic, strong) dispatch_block_t didChangeAppearanceBlock;
///We would like to auto-create tableCells and similar where this code gets too slow, to fix that we need to cache everything (no need to run through the same class 100 times). And also cache those strings!
@property (nonatomic) NSCache *creationCache;

//setup

+ (instancetype) sharedInstance;
- (void) parseSettings:(NSDictionary *)settings update:(BOOL)update;
- (void) updateAppearance;

#pragma mark - colors and font

+ (BOOL) colorIsDark:(UIColor*)color;
- (UIFont*) fontWithType:(AutoFont)fontType;
+ (UIFont*) standardFont:(CGFloat)size;
- (UIColor*) standardColor:(AutoColor)color;
- (UIColor*) colorFromRGBAInts:(NSArray*)colorDefinition;

#pragma mark - working with rects and sizing of views

//get that pesky height of the status bar.
CGFloat standardStatusBarHeight();
///Automatically center a rect inside a master rect, overwrites existing values.
void AutoCenterFrameInFrame(CGRect* frame, CGRect master);
///Automatically center a view's frame inside a master frame, overwrites existing values.
void AutoCenterViewInFrame(UIView* target, CGRect master);
/**
 Remove a slice of a rect, select where to make the cut by specifiting the CGRectEdge. Overwrites existing values.
 */
void AutoSliceRect(CGRect *rect,  CGFloat amount, CGRectEdge edge);

#pragma mark - images

///Redraw an image replacing black with color.
- (UIImage*) tintedImage:(UIImage*)image color:(UIColor*)color;
///Redraw image by replacing black with standard tint color
- (UIImage*) tintedImage:(UIImage*)image;
///Redraw bundle-image by replacing black with standard tint color
- (UIImage*) tintedImageWithName:(NSString*)imageName;

#pragma mark - Standard cell sizes for use in collection views - warning
//highly questionable solutions to make standard cell sizes for collection views - don't use - will be redone,
+ (CGSize) standardCellSize;
+ (CGSize) standardCoverSize;
+ (UIEdgeInsets) standardCollectionViewEdgeInsets;

#pragma mark - standard components

- (UIProgressView*) progressView:(UIView*)superView;
- (void) progressAppearance:(UIProgressView*)progress;
- (UITextField*) textField:(id<UITextFieldDelegate>)delegate placeholder:(NSString*)placeholder inView:(UIView*)superView;
- (UISlider*) slider:(id)target inView:(UIView*)superView;
- (UIView*) viewInView:(UIView*)superView;
- (UIPageControl*) pageControlWithTarget:(id)target inView:(UIView*)superView;
- (UIImageView*) imageViewWithImage:(UIImage*)image inView:(UIView*)superView;
- (UIActivityIndicatorView*) spinnerInView:(UIView*)superView;
- (UITextView*) textViewWithDelegate:(id<UITextViewDelegate>)delegate inView:(UIView*)superView;
- (UILabel*) labelInView:(UIView*)view;
- (UIDatePicker*) datePickerWithMode:(UIDatePickerMode)pickerMode target:(id)target selector:(SEL)selector inView:(UIView*)superView;
- (UIStepper*) stepperWithTarget:(id)target inView:(UIView*)superView;

/**
 Create a basic segmentedControl, you will need to add segments and set selections yourself. Like this:
 [control insertSegmentWithTitle:AutoLocalizedString(@"Admin") atIndex:3 animated:NO];
 [control setSelectedSegmentIndex:0];
 */
- (UISegmentedControl*) segmentedControlWithTarget:(id)target inView:(UIView*)superView;
- (UIButton*) buttonWithName:(NSString*)propertyName target:(id)target inView:(UIView*)view;
- (UIButton*) buttonWithTitle:(NSString*)title target:(id)target inView:(UIView*)view;
- (UIButton*) buttonWithImage:(UIImage*)image highlight:(UIImage*)highlight target:(id)target inView:(UIView*)view;
- (UIButton*) buttonWithImageName:(NSString*)image tint:(BOOL)tint target:(id)target inView:(UIView*)view;

- (UITableView*) tableView:(id)delegate inView:(UIView*)view;
- (void) tableAppearance:(UITableView*)table;

#pragma mark - appearance for stuff we don't create

- (void) navigationBarAppearance:(UINavigationBar*)view;
///You only need to call this if you want a different color than the navigation bars tint color, specified by "AutoColorMenuText" or a different font.
- (void) barButtonAppearance:(UIBarItem*)view;

#pragma mark - sizing of text and labels

///Calculate the bounding box of a string using the standard font
+ (CGSize) string:(NSString*)string constrainedToSize:(CGSize)size;
///Calculate the bounding box of a string, supply no font in order to use the standard font
+ (CGSize) string:(NSString*)string constrainedToSize:(CGSize)size fontSize:(float)fontSize font:(UIFont *)font;

///Shrink a font - fix this. It isn't working!
+ (CGFloat) actualFontSizeForString:(NSString*)string font:(UIFont*)font constrainedToSize:(CGSize)size;

///Shrink all of a segment's labels to fit a width. TODO: have seen it behave badly. Fixme.
+ (void)autoShrinkSegmentLabels:(UISegmentedControl*)segmentedControl;

#pragma mark - Do all at once, create and set values

/**
 Automatically set frames for views that share the same name (i.e segmentView and segmentViewRect)
 If you have iVars ending with "Rect" as in "segmentViewRect" this method will use the automatically associated rects created in "createViews:superView:" to set their frames.
 */
+ (void) setFrames:(id)controller;

/**
 Auto-create views by using their standard create method and automatically add them to the superView and set delegates/targets if apropriate. It does not have to be a UIViewController subclass, but may destroy your app if it's not a direct UIViewController, UIVIew, or NSObject subclass (e.g. subclassing UINavigationController may fuck shit up).
 
 It takes all UIView-like properties from this class and auto-creates them for you.
 
 To exclude a view, create it before calling this method or don't have it as a property (it only looks for views that are properties).
 
  If you have iVars ending with "Rect" as in "mainLabelRect" with a UILabel property called "mainLabel", this method will automatically associate those rects with the views so you can call setFrames: to automatically set those frames. To be used with setFrames:
 
 **/
+ (void) createViews:(id)viewController superView:(UIView*)view;

/**Set values of a dictionary, using the views keypaths, [view setValue: forKeyPath:]. To be used when you have e.g. several buttons and you want all to adjust image when disabled. This way you can define uniform behaviours of your views once, and have all views act accordingly.
 
 @param values The keys and values for the keypaths to be set for the views. On the form { key_path : value } where value can be a single value (to assign every view the same value) or an array (to assign different values for all views).
 @param views The views to assign values. Remember, it uses setValue:forKeyPath: so it works with everything that supports the NSKeyValueCoding setValue:forKeyPath: keyPaths (it does not have to be UIViews). Ex, @"layer.borderWidth" : @1 works fine for every view, @"adjustsImageWhenDisabled": @0, works for all buttons.
 **/
+ (void) setValues:(NSDictionary*)lists forViews:(UIView*)firstPointer, ... AUTO_NIL_ENDING;
///set images or names(titles) on several buttons at once.
+ (void) setButtons:(NSArray*)buttons imagesOrNames:(NSArray*)imageArray tint:(BOOL)tint orColor:(UIColor*)color;

#pragma mark - define appearance

 //Let our interfaces define colors and fonts so we can automatically change them when appearance changes.

/**
 Use this function to let the views remember why they got the corresponding color. When appearance changes, we can just loop over all remaining views and set their new colors and fonts.
 */
- (void) color:(AutoColor)color forView:(UIView*)view method:(AutoSetValue)method;
//shorthand for setting colors
+ (void) color:(AutoColor)color forView:(UIView*)view method:(AutoSetValue)method;

/**
 Set more complex Appearances that have both font and color. If you use the standard font, you may use the regular function (color:forView:method:) instead.
 To only set the font, specify method = AutoSetValueFont. For use with simple labels that don't have attributed text.
 */
- (void) font:(AutoFont)fontType color:(AutoColor)colorType extraAttributes:(NSDictionary*)extraAttributes forView:(UIView*)view method:(AutoSetValue)method;

///Shorthand for setting complex Appearances
+ (void) font:(AutoFont)fontType color:(AutoColor)colorType extraAttributes:(NSDictionary*)extraAttributes forView:(UIView*)view method:(AutoSetValue)method;

#pragma mark - switch appearance

///Switch to another set of colors defined in your AutoStandardSettings.json file. To switch back, use AutoStandardAppearance.
- (void) switchAppearanceTo:(NSString*)name;

#pragma mark - methods to subclass

/**
Creates and sets widgets (UIViews, BarButtonItems, and any other GUI object). Overload this method in your subclass if you want it to handle more classes, (should not be needed).
 
 AutoStandards takes the classString from your property in order to know what class to instansiate. 
 */
- (id) standardWidgetNamed:(NSString*)propertyString fromString:(NSString*)classString delegate:(id)delegate superView:(UIView*)view;

#pragma mark - standard components - Depricated or refactor before use

/*
 The main problem here is hard-coded values. We can use these methods if we like, but then we need to find those values at runtime.
 */

///Create a standard stepper. The problem is it requires a known size, which might change in the future. Or does it really? Can't we just ask the size after creation?
- (CGRect) standardStepperRect:(CGPoint)origin;

- (UIStepper*) standardStepper:(CGPoint)origin target:(id)target inView:(UIView*)superView;

///a standard stepper centered in a frame, if you don't want the stepper centered just set its width and height to standardStepperSize
- (UIStepper*) standardStepperInFrame:(CGRect)frame target:(id)target inView:(UIView*)superView;

///adjust the rect if we already have a date-picker. This was ment as a workaround when creating datePickers in frames of unknown sizes. This is a bad way of handling the problem. Instead you should figure out the size in runtime, and just use that. It is possible.
- (void) standardDatePickerRectForDatePicker:(UIDatePicker*)datePicker;

///Uses hard-coded values for steppers, should not exist.
- (CGSize) standardStepperSize;

///Uses hard-coded values, should not exist.
- (CGSize) standardSwitchSize;

@end