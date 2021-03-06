/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AppDelegate.h"
#ifdef PHONEGAP_FRAMEWORK
	#import <PhoneGap/PhoneGapViewController.h>
#else
	#import "PhoneGapViewController.h"
#endif

#import "SFOAuthCredentials.h"


/*
 NOTE These values are provided as usable examples to get you started with OAuth login;
 however, when you create your own app you must create your own Remote Access object
 in your Salesforce org. 
 (When you are logged in as an org administrator, go to Setup -> Develop -> Remote Access -> New )
 */

#warning This value should be overwritten with the Consumer Key from your own Remote Access object
static NSString *const RemoteAccessConsumerKey =
    @"3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa";

#warning This value should be overwritten with the Callback URL from your own Remote Access object
static NSString *const OAuthRedirectURI = 
    @"testsfdc:///mobilesdk/detect/oauth/done";

#warning This value must match the org instance with which you're testing 
static NSString *const OAuthLoginDomain =  
    @"test.salesforce.com"; //Sandbox:  use login.salesforce.com if you're sure you want to test with Production


static NSString * const kSFMobileSDKVersion = @"0.9";
static NSString * const kRestAPIVersion = @"v23.0";

@interface AppDelegate (private)
- (void)login;
- (void)loggedIn;
- (void)logout;
- (void)sendJavascriptLoginEvent:(UIWebView *)webView;
- (NSString *)getUserAgentString;
@end

@implementation AppDelegate

@synthesize invokeString;
@synthesize coordinator=_coordinator;

#pragma mark - init/dealloc

- (id) init
{	
	/** If you need to do any extra app-specific initialization, you can do it here
	 *  -jm
	 **/
    self = [super init];
    if (nil != self) {
        //Replace the app-wide HTTP User-Agent before the first UIWebView is created
        NSString *uaString = [self getUserAgentString];
        NSDictionary *appUserAgent = [[NSDictionary alloc] initWithObjectsAndKeys:uaString, @"UserAgent", nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:appUserAgent];
        [appUserAgent release];
    }
    return self;
}

- (void)dealloc
{
    self.coordinator = nil;
	[ super dealloc ];
}

#pragma mark - App lifecycle

/**
 * This is main kick off after the app inits, the views and Settings are setup here. (preferred - iOS4 and up)
 */
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	
	NSArray *keyArray = [launchOptions allKeys];
	if ([launchOptions objectForKey:[keyArray objectAtIndex:0]]!=nil) 
	{
		NSURL *url = [launchOptions objectForKey:[keyArray objectAtIndex:0]];
		self.invokeString = [url absoluteString];
		NSLog(@"ContactExplorer launchOptions = %@",url);
	}

    // init window
	CGRect screenBounds = [ [ UIScreen mainScreen ] bounds ];
	self.window = [ [ [ UIWindow alloc ] initWithFrame:screenBounds ] autorelease ];
	self.window.autoresizesSubviews = YES;
    
    [self.window makeKeyAndVisible];
    return YES;
}

// this happens while we are running ( in the background, or from within our own app )
// only valid if ContactExplorer.plist specifies a protocol to handle
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url 
{
    // must call super so all plugins will get the notification, and their handlers will be called 
	// super also calls into javascript global function 'handleOpenURL'
    return [super application:application handleOpenURL:url];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    
	// refresh session
	[self login];
}

#pragma mark - PhoneGap helpers

-(id) getCommandInstance:(NSString*)className
{
	/** You can catch your own commands here, if you wanted to extend the gap: protocol, or add your
	 *  own app specific protocol to it. -jm
	 **/
	return [super getCommandInstance:className];
}

- (BOOL) execute:(InvokedUrlCommand*)command
{
	return [ super execute:command];
}

+ (BOOL) isIPad {
#ifdef UI_USER_INTERFACE_IDIOM
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
#else
    return NO;
#endif
}

#pragma mark - UIWebViewDelegate

/**
 Called when the webview finishes loading.  This stops the activity view and closes the imageview
 */
- (void)webViewDidFinishLoad:(UIWebView *)theWebView 
{
	// only valid if ContactExplorer.plist specifies a protocol to handle
	if(self.invokeString)
	{
		// this is passed before the deviceready event is fired, so you can access it in js when you receive deviceready
		NSString* jsString = [NSString stringWithFormat:@"var invokeString = \"%@\";", self.invokeString];
		[theWebView stringByEvaluatingJavaScriptFromString:jsString];
	}
    
    // let's notify the page we are logged in
    [self sendJavascriptLoginEvent:theWebView];

	return [ super webViewDidFinishLoad:theWebView ];
}

- (void)webViewDidStartLoad:(UIWebView *)theWebView 
{
	return [ super webViewDidStartLoad:theWebView ];
}

/**
 * Fail Loading With Error
 * Error - If the webpage failed to load display an error with the reason.
 */
- (void)webView:(UIWebView *)theWebView didFailLoadWithError:(NSError *)error 
{
	return [ super webView:theWebView didFailLoadWithError:error ];
}

/**
 * Start Loading Request
 * This is where most of the magic happens... We take the request(s) and process the response.
 * From here we can re direct links and other protocalls to different internal methods.
 */
- (BOOL)webView:(UIWebView *)theWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	return [ super webView:theWebView shouldStartLoadWithRequest:request navigationType:navigationType ];
}


#pragma mark - Salesforce.com login helpers

- (void)login {
    
    //create a new coordinator if we don't already have one
    if (nil == self.coordinator) {
        
        //here we use the login domain as part of the identifier
        //to distinguish between eg  sandbox and production credentials
        NSString *acctIdentifier = [NSString stringWithFormat:@"ContactExplorer-Default-%@",OAuthLoginDomain];
        
        //Oauth credentials can have an identifier associated with them,
        //such as an account identifier.  For this app we only support one
        //"account" but you could provide your own means (eg NSUserDefaults) of 
        //storing which account the user last accessed, and using that here.
        
        SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] 
                                           initWithIdentifier:acctIdentifier  
                                           clientId:RemoteAccessConsumerKey];

        
        creds.domain = OAuthLoginDomain;
        creds.redirectUri = OAuthRedirectURI;
        
        SFOAuthCoordinator *coord = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
        self.coordinator = coord;
        self.coordinator.delegate = self;
        [coord release];
    }
    
    //kickoff authentication
    [self.coordinator authenticate];

}

- (void)logout {
    [self.coordinator revokeAuthentication];
    [self.coordinator authenticate];
}

- (void)loggedIn {
    
    if (!self.viewController) {
        // let's kickstart phonegap
        [super application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil];
    }
    else {
        // otherwise, simply notify the webview that we have logged in
        [self sendJavascriptLoginEvent:self.webView];
    }
}


- (void)sendJavascriptLoginEvent:(UIWebView *)webView {
    SFOAuthCredentials *creds = self.coordinator.credentials;
    NSString *accessToken = creds.accessToken;
    NSString *refreshToken = creds.refreshToken;
    NSString *clientId = creds.clientId;
    NSString *userId = creds.userId;
    NSString *orgId = creds.organizationId;
    NSString *instanceUrl = creds.instanceUrl.absoluteString;
    NSString *loginUrl = [NSString stringWithFormat:@"%@://%@", creds.protocol, creds.domain];
    NSString *uaString = [self getUserAgentString];
    
    NSString* jsString = [NSString stringWithFormat:@""
                          "(function() {"
                          "  var e = document.createEvent('Events');"
                          "  e.initEvent('salesforce_oauth_login');"
                          "  e.data = {"
                          "    accessToken: \"%@\","
                          "    refreshToken: \"%@\","
                          "    clientId: \"%@\","
                          "    loginUrl: \"%@\","
                          "    userId: \"%@\","
                          "    orgId: \"%@\","
                          "    instanceUrl: \"%@\","
                          "    userAgent: \"%@\","
                          "    apiVersion: \"%@\","
                          "  };"
                          "  document.dispatchEvent(e);"
                          "})()",
                          accessToken,
                          refreshToken,
                          clientId,
                          loginUrl,
                          userId,
                          orgId,
                          instanceUrl,
                          uaString,
                          kRestAPIVersion
                          ];
    [webView stringByEvaluatingJavaScriptFromString:jsString];
    
}


- (NSString *)getUserAgentString {
    //set a user agent string based on the mobile sdk version
    //We are building a user agent of the form:
    //SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad)
    
    UIDevice *curDevice = [UIDevice currentDevice];
    NSString *myUserAgent = [NSString stringWithFormat:
                             @"SalesforceMobileSDK/%@ %@/%@ (%@)",
                             kSFMobileSDKVersion,
                             [curDevice systemName],
                             [curDevice systemVersion],
                             [curDevice model]
                             ];
    
    
    return myUserAgent;
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:willBeginAuthenticationWithView");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:didBeginAuthenticationWithView");
    [self.window addSubview:view];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator {
    NSLog(@"oauthCoordinatorDidAuthenticate for userId: %@", coordinator.credentials.userId);
    [coordinator.view removeFromSuperview];
    [self loggedIn];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error {
    NSLog(@"oauthCoordinator:didFailWithError: %@", error);
    [coordinator.view removeFromSuperview];
    
    NSInteger errCode = [error code];
    
    if (errCode != kSFOAuthErrorTimeout) {
        NSLog(@"logging out and restarting auth");
        [self logout];
    } else {
        // show alert and allow retry
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Salesforce Error" 
                                                        message:[NSString stringWithFormat:@"Can't connect to salesforce: %@", error]
                                                       delegate:self
                                              cancelButtonTitle:@"Retry"
                                              otherButtonTitles: nil];
        [alert show];
        [alert release];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self.coordinator authenticate];    
}


@end
