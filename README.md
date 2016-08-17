# AutoStandards
Automatic GUI creation for iOS by using standards. 

Short how-to:

in the .h file we have

	@property (nonatomic) UIButton *startButton;
	@property (nonatomic) UILabel *startLabel;

in the .m file we have this:

	@implementation ADViewController
	{
		CGRect startLabelRect, startButtonRect;
	}
	
	- (void)loadView
	{
		[super loadView];
		[AutoStandards createViews:self superView:self.view];   //auto-create all views for this ViewController and place them in it's view
	}
	
Notice that the rects have the same names as the UI elements. This is what links them together without using any code.
It is convinient to use viewWillLayoutSubviews for setting the frames, since it will be called whenever the device rotates. But it might also interfere with your animations. Use responsibly!

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

