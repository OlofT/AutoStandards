# AutoStandards
Automatic GUI creation for iOS by using standards. Instead of having some GUI-code in xib or storyboard files, and some in code - have everything in one place. If you want to change the font for every label and button? Change it once for all your application. Instead of going through every view in every xib to change the background color, define a standard for "background color" and change it once - everything that use "background color" will be updated. Confused by what I mean with "a standard"? Just read on! (for more on this see [my blog post about this](http://aggressive.se/blog/#removing-storyboards-and-xib-files-to-save-time-and-money)).

Bonus: Also supports multiple standards, so you can switch between e.g. "dark mode" and "light mode" in one go.

Short how-to:

Include the AutoStandards.m and AutoStandards.h into your project. Then copy AutoStandardSettings.json into your project. We have defined properties for a controller:

	@property (nonatomic) UIButton *changeModeButton;
	@property (nonatomic) UILabel *startLabel;

in the .m file we have this:

	@implementation ViewController
	{
		CGRect startLabelRect, changeModeButtonRect;
	}
	
	- (void)loadView
	{
		[super loadView];
		
		//define background color for self.view since it was already created.
	    [AutoStandards color:AutoColorMainViewBackground forView:self.view method:AutoSetValueBackgroundColor];
			
		[AutoStandards createViews:self superView:self.view];   //auto-create all views for this ViewController and place them in it's view
	}
	

Notice that the rects have the same names as the UI elements. This is what links them together without using any code.

It is convenient to use viewWillLayoutSubviews for setting the frames, but it is usually better to do it once in viewWillAppear: and willTransitionToSize: (depending on how you want/need to control things).

	- (void) viewWillLayoutSubviews
	{
		//Now we just calculate our views with ordinary simple math and variables.
		
		CGFloat margin = 10;
		CGFloat touchSize = 44;
		
	    //fix any magic overlays in iOS >= 7, by slicing of the top of our frame
	    if ([self respondsToSelector:@selector(topLayoutGuide)])
	    {
	        CGFloat topBarOffset = self.topLayoutGuide.length;
	        AutoSliceRect(&remainder, topBarOffset, CGRectMinYEdge);
	    }
    	
	    startLabelRect = CGRectMake(margin, margin + remainder.origin.y, remainder.size.width, touchSize);
		changeModeButtonRect = CGRectMake(margin, margin + CGRectGetMaxY(startLabelRect), 100, touchSize);
	
		//Then we set all rects at the same time with this simple function
		[AutoStandards setFrames:self];
	}


We also want to listen to button clicks. But instead of declaring stuff in the .h file and than dragging lines back and fourth from interface builder - we just add the method:

	
	- (void) changeModeButtonPressed
	{
	    if (self.darkMode)
	    {
	        [self.changeModeButton setTitle:@"Go Bright" forState:UIControlStateNormal];
	        [[AutoStandards sharedInstance] switchAppearanceTo:AutoStandardAppearance];
	    }
	    else
	    {
	        [self.changeModeButton setTitle:@"Go Dark" forState:UIControlStateNormal];
	        [[AutoStandards sharedInstance] switchAppearanceTo:@"DarkMode"];
	    }
    
	    self.darkMode = !self.darkMode;
	}

Now just build and run, and if everything looks pink and crazy you know it worked!

You can now remove or modify AutoStandardSettings.json and start defining your own colors. A better way is to download colors at startup, so you can modify everything on your server and have it automatically apply those.

##Why are storyboards/xib/nibs bad?

They are not always bad, it depends a lot on your situation. If you are working with people that won't read code (which does not have to be a bad thing - everyone shouldn't need to be a coder), then this is not for you. Also, if someone else are paying you by the hour, why automate in the first place? I like to see my interfaces before building them, so I usually draw them on paper first and then implement them in code. But it must be said: it is harder to not see the interface when creating it.

Using nibs (I will from here on call all storyboards/xibs for nibs) are bad in a couple of ways:

1. It creates duplication of code when you want to switch between two modes. You will define your first mode in your nib, then both modes in code to allow switching back and forth.
2. It creates duplication of code when you want to change your nib. E.g. if you want to use a different font, you will need to go through each and every label/button etc on every nib-file you have. Your code is sprinkled all over.
3. Creating apps takes much more of your time. 
3. Compiles take much longer.
4. Version control becomes a special type of hell.
6. Code reuse for nibs are more or less impossible (at least impractical). Even copying stuff from a nib usually goes wrong or isn't worth the trouble.
7. Everything you can do with nibs can also be done in code, but the reverse is not always true.
8. Nibs are not automatic.

##Swift?

There will be support for Swift in the future, I am still waiting for NS\_ASSUME\_NULL (at the moment we only have NS\_ASSUME\_NONNULL). I would like to do a complete rewrite in Swift, but I don't have much time, and can't let it go to waste.

##Auto Layout

AutoStandards should work well with auto layout, I'm not using that myself but it should work fine, as long as you define your constraints in code. You also need to set translatesAutoresizingMaskIntoConstraints = NO for every view, which can easily be done by subclassing AutoStandards.

#Details

Now you have tested it and realized that it will save you tons of time. Remember that it will also save the compiler tons of time - those nibs are nothing more than code wrapped in xml, that also need to be compiled (which was a huge time-hog in my projects). Nibs are also using dynamism a lot, if you e.g. rename an IBAction things will compile fine, but crash when the action get triggered.

##Memory / CPU usage
AutoStandards uses NSCache in order to only process each controller class once and save the result. If the system is low on RAM those are automatically discarded. All other GUI-elements are tracked with weak references, making insignificant overhead and will automatically go away when not used. It is at least insignificant compared to heavier tools like AutoLayout.

It works fine for automatically creating table cells, which is one of the heaviest operation AutoStandards performs.

##Color definitions (standards)

When starting out I was thinking a lot about CSS, where everything has a style and if you want an element to look a certain way - you apply that style to the element. I wanted something easier and more functional-oriented. Instead of styles which defined colors for different looks, I wanted to have colors defined for different purposes. The functionality of a warning label is to tell the user something important (if you delete this item, it will be gone forever). Both the warning label and "affirmative" button could use the same color scheme. All controllers have a main view, and those have the same background color - the purpose of that color is to be a background color of main views. It seemed to me that for iOS apps we didn't need to do things the CSS way but instead could have a more direct, functional approach (what are the color ment for). Today I'm not so sure anymore. I sometimes want to use both methods, and perhaps I will build support for that in the future. It is however very easy to work with, just follow this simple steps:

1. Define your color scheme in the json or in a dictionary (more dynamically defined colors below). Set e.g. AutoColorMainViewBackground to a bright color, so your main views like your collection views get a bright background.
2. For your own views, or classes unknown to AutoStandards, call [AutoStandards color:AutoColorMainViewBackground forView:theView method:AutoSetValueBackgroundColor];
3. There is no step 3. Now AutoStandards know that the AutoColorMainViewBackground color should be set using the AutoSetValueBackgroundColor method. If you change the AutoColorMainViewBackground color, the view will also the this new color.

The colors defined by AutoStandards are usually not enough, and to avoid too much "stringly typing" there is a color array you can define for those purposes. Let's say you are building a messages app and your user's messages should get a specific color:

1. Define the color by supplying a AutoColorArray.
1. Add #define AutoColorUserMessage AutoColorSpecific_0 to make your code readable
2. For the user's messages set [AutoStandards color:AutoColorUserMessage forView:messageBubble method:AutoSetValueBackgroundColor];

Think of it as defining a standard for your views and then applying that standard.

##Dynamically defined colors - no Appearance Proxy

AutoStandards is built for easy updating of colors and fonts, just feed it new definitions by calling [[AutoStandards sharedInstance] parseSettings:settingsDictionary update:YES];

This settings can be a JSON you download from the web, or defined by the user. A major difference from Appearance Proxy, and why that isn't used, is that everything is changed at once. Even already created views get new values. Another drawback of Appearance Proxy is that it only deals with classes. If you have a cancel button, or warning label, that should look different from "ok" buttons or regular labels - it simply cannot be done with Appearance Proxy. You will then need to build extra code just to set appearances of these elements.

##Controllers / Containers

AutoStandard can handle everything that is a "container" of views, that is most controllers and views with subviews. Since "Containers" sounds a bit confusing I choose to use the word "controller" instead, and I hope you will understand anyway. This means that everything that have views can be considered a controller in the eyes of AutoStandards. A view with subviews, e.g. a table view, or even a tableView cell can be used as a controller. "Superview" is also a bad word since actual controllers aren't views. 

##ARC

This project uses ARC






