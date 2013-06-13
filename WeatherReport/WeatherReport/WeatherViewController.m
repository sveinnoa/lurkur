//
//  WeatherViewController.m
//  WeatherReport
//
//  Created by Otti Hólm Elínarson on 5/15/13.
//  Copyright (c) 2013 Otti Elínarson. All rights reserved.
//

#import "WeatherViewController.h"
#import "AFJSONRequestOperation.h"
#import "AFXMLRequestOperation.h"
#import "UIImageView+AFNetworking.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const BaseURLString = @"http://xmlweather.vedur.is/?op_w=xml&type=obs&lang=en&view=xml&ids=";
//static CGFloat *const floatBarHeight = 40.0;

@interface WeatherViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *weatherArtImage;




@property (nonatomic,strong) UIRefreshControl *refreshControl;
@property(strong) NSMutableDictionary *weather;
@property(strong) NSMutableArray *favoriteStations;
@property(strong) NSMutableDictionary *xmlWeather; //package containing the complete response
@property(strong) NSMutableDictionary *currentDictionary; //current section being parsed
@property(strong) NSString *previousElementName;
@property(strong) NSString *elementName;
@property(strong) NSMutableString *outstring;
@property (nonatomic) CGFloat barHeight;
@property (nonatomic) CGFloat lastOffset;

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict;
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string;
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName;
-(void) parserDidEndDocument:(NSXMLParser *)parser;

@end

@implementation WeatherViewController {
    NSOperationQueue *queue;
    NSURLConnection *connection;
    BOOL isLoading;
    NSString *photoURLString;
    NSString *photoTitle;
    NSInteger numberOfViews;
    NSMutableArray *tmpURLs;
    UIScrollView *scroll;
    //UIImageView *artImageView;
    UIView *containerView;
    CGFloat *lastOffset;
}
@synthesize weatherArtImage = _weatherArtImage;


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    //UINavigationItem* item = [[UINavigationItem alloc] initWithTitle:@"title text"];
    
    //[self.navigationBar pushNavigationItem:item animated:YES];
    
    
    self.barHeight = 20.0;
    // number f views / pages
    numberOfViews = 7;
    
    // array for urls, need to fix name and maybe change to dict
    tmpURLs = [[NSMutableArray alloc] initWithCapacity:7];
    self.favoriteStations = [[NSMutableArray alloc] initWithCapacity:5];
    
    queue = [[NSOperationQueue alloc] init];
    [self updateData];
}
- (void)updateData
{
    NSString *const FlickrAPIKey = @"b5daebf7a95fb8c7a57145848dbc127d";
//    NSString *tags = @"iceland landscape";
    NSString *tags = @"reykjavik";
    NSString *escapeTags = [tags stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSString *urlString =
    [NSString stringWithFormat:
     @"http://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=%@&tags=%@&per_page=25&format=json&nojsoncallback=1&group_id=29722852@N00",
     FlickrAPIKey, escapeTags];
    NSLog(@"%@", urlString);
    // Create NSURL string from formatted string
    NSURL *url = [NSURL URLWithString:urlString];
    
    // Setup and start async download
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL: url];
    //connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation
                                         JSONRequestOperationWithRequest:request
                                         success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                                             
                                             [self parseDictionary:JSON];
                                             //[self parseDictionaryToArray:JSON];
                                             isLoading = NO;
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                 [self.view setNeedsDisplay];
                                             });
                                             
                                             
                                         }
                                         failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                                             
                                             [self showNetworkError];
                                             isLoading = NO;
                                         }];
    
    //operation.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", nil];
    [queue addOperation:operation];
 
    // hardcode Reykjavik and Holmavik and some others
    NSString *weatherUrlStr = [NSString stringWithFormat:@"%@1;2481;2642;422;571;705;798",BaseURLString];
    NSLog(@"%@", weatherUrlStr);
    NSURL *weatherUrl = [NSURL URLWithString:weatherUrlStr];
    NSURLRequest *requestWeather = [NSURLRequest requestWithURL:weatherUrl];

    AFXMLRequestOperation *weatherOperation = [AFXMLRequestOperation
                                               XMLParserRequestOperationWithRequest:requestWeather
                                               success:^(NSURLRequest *requestWeather, NSHTTPURLResponse *response, NSXMLParser *XMLParser) {
                                                   self.xmlWeather = [NSMutableDictionary dictionary];
                                                   XMLParser.delegate = self;
                                                   [XMLParser setShouldProcessNamespaces:YES];
                                                   [XMLParser parse];
                                               }
                                               failure:^(NSURLRequest *requestWeather, NSHTTPURLResponse *response, NSError *error, NSXMLParser *XMLParser) {
                                                   UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Error Retrieving Weather"
                                                                                            message:[NSString stringWithFormat:@"%@",error]
                                                                                            delegate:nil
                                                                                            cancelButtonTitle:@"OK"
                                                                                            otherButtonTitles:nil];
                                                    [av show];
                                                }];
    //operation.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", nil];
    [queue addOperation:weatherOperation];   
    
}

- (void)updateImage
{
    [self.weatherArtImage setImageWithURL:[NSURL URLWithString:photoURLString] ];
}

- (void)setup
{
    
    scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    
    [scroll setScrollEnabled:YES];
    scroll.pagingEnabled = YES;
    
    
    
    
    //[filtersScrollView setShowsVerticalScrollIndicator:NO];
    scroll.showsVerticalScrollIndicator = NO;
    scroll.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:scroll];
    for (int i= 0; i < numberOfViews; i++) {


        
        CGFloat xOrigin = i * self.view.frame.size.width;
        NSDictionary *weather = [self.favoriteStations objectAtIndex:i];
        NSString *stationName = [weather objectForKey:@"name"];
        // get date
        NSString *observationTime = [weather objectForKey:@"time"];
        // get temp
        NSString *tempature = [weather objectForKey:@"tempature"];
         
        
        //UIView *
        containerView = [[UIView alloc] initWithFrame:CGRectMake(xOrigin+10, 10, self.view.frame.size.width-10, self.view.frame.size.height-10)];
        containerView.clipsToBounds = YES;
        
        
        //UIImageView *artImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        UIImageView *artImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        artImageView.contentMode = UIViewContentModeScaleAspectFill;
        containerView.clipsToBounds = YES;
        [artImageView setImageWithURL:[NSURL URLWithString:tmpURLs[i]]];
        [artImageView.layer setBorderColor:[[UIColor blackColor] CGColor]];
        [artImageView.layer setBorderWidth:1.0];
        [artImageView.layer setCornerRadius:2.0];
        
        [containerView addSubview:artImageView];
        
        //Experiment Zero
        UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0 , self.view.frame.size.width, self.barHeight)];
        bar.backgroundColor = [UIColor clearColor];
        //bar.backgroundColor = [UIColor blackColor];
        //bar.clipsToBounds = YES;
        bar.tag = i+200;
        UILabel *barTextLabel = [[UILabel alloc] init];
        barTextLabel.tag = i+300;
        [barTextLabel setFrame:CGRectMake(self.view.frame.size.width/2 - 80, 2, bar.frame.size.width/2 + 40, 16)];
        barTextLabel.textColor = [UIColor whiteColor];
        barTextLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:(14.0)];
        barTextLabel.textAlignment = NSTextAlignmentCenter;
        barTextLabel.backgroundColor = [UIColor clearColor];
        barTextLabel.layer.shadowOpacity = 1.0;
        barTextLabel.layer.shadowRadius = 0.0;
        barTextLabel.layer.shadowColor = [UIColor blackColor].CGColor;
        barTextLabel.layer.shadowOffset = CGSizeMake(0.0, -1.0);
        barTextLabel.text = [NSString stringWithFormat:@"%@\n%@", stationName, observationTime]; //@"Place and timestamp";
        
        [bar addSubview:barTextLabel];

        
        
                    // trying second scrollview
        UIScrollView *scroll1 = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        
        scroll1.tag = i;
        artImageView.tag = i+100;
        
        [scroll1 setScrollEnabled:YES];
        //scroll1.pagingEnabled = YES;
        
        //[filtersScrollView setShowsVerticalScrollIndicator:NO];
        scroll1.showsVerticalScrollIndicator = NO;
        scroll1.showsHorizontalScrollIndicator = NO;
        scroll1.delegate = self;
        //UILabel *tmpLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 300, scroll1.frame.size.width, 80)];
        
        
        //    NSString *observationTempature = [NSString stringWithFormat:@"%1.0f°", [tempature doubleValue]];
        UILabel *textLabel = [[UILabel alloc] init];
        [textLabel setFrame:CGRectMake(20, 310, 280, 72)];
        textLabel.textColor = [UIColor whiteColor];
//        textLabel.font = [UIFont fontWithName:@"Avenir-Light" size:(72.0)];
        textLabel.font = [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:(72.0)];
        textLabel.textAlignment = NSTextAlignmentLeft;
        textLabel.backgroundColor = [UIColor clearColor];
        textLabel.layer.shadowOpacity = 1.0;
        textLabel.layer.shadowRadius = 0.0;
        textLabel.layer.shadowColor = [UIColor blackColor].CGColor;
        textLabel.layer.shadowOffset = CGSizeMake(0.0, -1.0);
        textLabel.text = tempature;
        
        UILabel *textLabel2 = [[UILabel alloc] init];
        [textLabel2 setFrame:CGRectMake(20, 390, 280, 50)];
        textLabel2.textColor = [UIColor whiteColor];
//        textLabel2.font = [UIFont fontWithName:@"Avenir-Light" size:(18.0)];
        textLabel2.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:(18.0)];
        textLabel2.textAlignment = NSTextAlignmentLeft;
        textLabel2.numberOfLines = 0;
        textLabel2.backgroundColor = [UIColor clearColor];
        textLabel2.layer.shadowOpacity = 1.0;
        textLabel2.layer.shadowRadius = 0.0;
        textLabel2.layer.shadowColor = [UIColor blackColor].CGColor;
        textLabel2.layer.shadowOffset = CGSizeMake(0.0, -1.0);
        textLabel2.text = [NSString stringWithFormat:@"%@\n%@", stationName, observationTime];
        
        //make refresh
        //UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        self.refreshControl = [[UIRefreshControl alloc] init];
        [self.refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
        //[self.scrollView addSubview:refreshControl];
        [scroll1 addSubview:self.refreshControl];

        [scroll1 addSubview:textLabel];
        [scroll1 addSubview:textLabel2];
        
        [containerView addSubview:bar];
        [containerView addSubview:scroll1];
        scroll1.contentSize = CGSizeMake(scroll1.frame.size.width, scroll1.frame.size.height * 2);
        [scroll addSubview:containerView];
    }
    
    //[scroll setContentSize:CGSizeMake(400, 900)];
    scroll.contentSize = CGSizeMake(self.view.frame.size.width * numberOfViews, self.view.frame.size.height);
}
        
- (void)handleRefresh:(UIRefreshControl *)sender
{
    NSLog(@"Need to do something, refresh");
    // TODO : updateData calls setup of UI instead of refresh/replace
    [self updateData];
    [sender endRefreshing];
}

- (void)parseDictionary:(NSDictionary *)dictionary
{
    //NSLog(@"%@", dictionary);
    NSArray *photos = [[dictionary objectForKey:@"photos"] objectForKey:@"photo"];
    //NSLog(@"array size: %d", [photos count]);
    NSInteger target = (arc4random() % [photos count]);
    //NSLog(@"target: %d", target);
    NSDictionary *p = photos[target];
    //NSLog(@"%@", p);
    photoTitle = [p objectForKey:@"title"];
    photoURLString = [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_b.jpg", [p objectForKey:@"farm"], [p objectForKey:@"server"], [p objectForKey:@"id"], [p objectForKey:@"secret"]];
    
    //NSLog(@"photoURLString: %@", photoURLString);
    
    //[self updateImage];
    
    NSArray *photos2 = [[dictionary objectForKey:@"photos"] objectForKey:@"photo"];
    for (NSInteger i = 0; i < numberOfViews; i++) {
        NSDictionary *p = photos2[i+10];
        NSString *tmpStr;
        tmpStr = [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_b.jpg", [p objectForKey:@"farm"], [p objectForKey:@"server"], [p objectForKey:@"id"], [p objectForKey:@"secret"]];
        NSLog(@"url: %@", tmpStr);
        [tmpURLs addObject:tmpStr];
    }
    
    [self setup];
}
/*
- (void)parseDictionaryToArray:(NSDictionary *)dictionary
{
    NSArray *photos = [[dictionary objectForKey:@"photos"] objectForKey:@"photo"];
    for (NSInteger i = 0; i < numberOfViews; i++) {
        NSDictionary *p = photos[i+15];
        NSString *tmpStr;
        tmpStr = [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_b.jpg", [p objectForKey:@"farm"], [p objectForKey:@"server"], [p objectForKey:@"id"], [p objectForKey:@"secret"]];
        [tmpURLs addObject:tmpStr];
    }
    
    //[self setup];
}*/


- (void)showNetworkError
{
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:@"Whoops..."
                              message:@"There was an error reading data.Please try again."
                              delegate:nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
    
    [alertView show];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict  {
    self.previousElementName = self.elementName;
    
    if (qName) {
        self.elementName = qName;
    }
    
    // start a new dictionary item for each station item
    if([qName isEqualToString:@"station"]){
        self.currentDictionary = [NSMutableDictionary dictionary];
    }
    
    self.outstring = [NSMutableString string];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (!self.elementName){
        return;
    }
    
    [self.outstring appendFormat:@"%@", string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    if([qName isEqualToString:@"station"]){
        
        // Initalise the list of station items if it dosnt exist
        NSMutableArray *array = [self.xmlWeather objectForKey:@"station"];
        if(!array)
            array = [NSMutableArray array];
        
        [array addObject:self.currentDictionary];
        [self.xmlWeather setObject:array forKey:@"station"];
        
        self.currentDictionary = nil;
    }
    else {
        [self.currentDictionary setObject:self.outstring forKey:qName];
    }
    
	self.elementName = nil;
}

-(void) parserDidEndDocument:(NSXMLParser *)parser {
    NSLog(@"Station observations: %@", self.xmlWeather);
    NSMutableArray *observations = [self.xmlWeather objectForKey:@"station"];
    NSDictionary *observation = [observations objectAtIndex:0];
    NSLog(@"Reykjavik obs: %@", [observation objectForKey:@"name"]);
    
    // get name of station
    NSString *stationName = [observation objectForKey:@"name"];
    // get date
    NSString *observationTime = [observation objectForKey:@"time"];
    // get temp
    NSString *tempature = [observation objectForKey:@"T"];
//    NSString *observationTempature = [NSString stringWithFormat:@"%1.0f°", [tempature doubleValue]];
    NSString *observationTempature = [NSString stringWithFormat:@"%d°", [tempature integerValue]];
  
    // add some text for testing transparant label on top of image view
    /*UILabel *textLabel = [[UILabel alloc] init];
    [textLabel setFrame:CGRectMake(20, 310, 280, 72)];
    textLabel.textColor = [UIColor whiteColor];
    textLabel.font = [UIFont fontWithName:@"Avenir-Light" size:(72.0)];
    textLabel.textAlignment = NSTextAlignmentLeft;
    textLabel.backgroundColor = [UIColor clearColor];
    textLabel.layer.shadowOpacity = 1.0;
    textLabel.layer.shadowRadius = 0.0;
    textLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    textLabel.layer.shadowOffset = CGSizeMake(0.0, -1.0);
    textLabel.text = observationTempature;
    
    UILabel *textLabel2 = [[UILabel alloc] init];
    [textLabel2 setFrame:CGRectMake(20, 390, 280, 50)];
    textLabel2.textColor = [UIColor whiteColor];
    textLabel2.font = [UIFont fontWithName:@"Avenir-Light" size:(18.0)];
    textLabel2.textAlignment = NSTextAlignmentLeft;
    textLabel2.numberOfLines = 0;
    textLabel2.backgroundColor = [UIColor clearColor];
    textLabel2.layer.shadowOpacity = 1.0;
    textLabel2.layer.shadowRadius = 0.0;
    textLabel2.layer.shadowColor = [UIColor blackColor].CGColor;
    textLabel2.layer.shadowOffset = CGSizeMake(0.0, -1.0);
    textLabel2.text = [NSString stringWithFormat:@"%@\n%@", stationName, observationTime];*/
/*
    UILabel *textLabel3 = [[UILabel alloc] init];
    [textLabel3 setFrame:CGRectMake(20, 20, 280, 6)];
    textLabel3.textColor = [UIColor whiteColor];
    textLabel3.font = [UIFont fontWithName:@"Avenir-Light" size:(16.0)];
    textLabel3.textAlignment = NSTextAlignmentRight;
    textLabel3.backgroundColor = [UIColor clearColor];
    textLabel3.layer.shadowOpacity = 1.0;
    textLabel3.layer.shadowRadius = 0.0;
    textLabel3.layer.shadowColor = [UIColor blackColor].CGColor;
    textLabel3.layer.shadowOffset = CGSizeMake(0.0, -1.0);
    textLabel3.text = photoTitle;
*/
    //[[self view] addSubview:textLabel];
    //[[self view] addSubview:textLabel2];
//    [[self view] addSubview:textLabel3];
    
    // adding to weather dictionary
    for (NSInteger i = 0; i < [observations count]; i++)
    {
        NSDictionary *observation = [observations objectAtIndex:i];
        NSString *stationName = [observation objectForKey:@"name"];
        // get date
        NSString *observationTime = [observation objectForKey:@"time"];
        // get temp
        NSString *tempature = [observation objectForKey:@"T"];
        //    NSString *observationTempature = [NSString stringWithFormat:@"%1.0f°", [tempature doubleValue]];
        NSString *observationTempature = [NSString stringWithFormat:@"%d°", [tempature integerValue]];
        NSMutableDictionary *weather = [[NSMutableDictionary alloc] init];
        [weather setObject:stationName forKey:@"name"];
        [weather setObject:observationTime forKey:@"time"];
        [weather setObject:observationTempature forKey:@"tempature"];
        [self.favoriteStations addObject:weather];
    }
    NSLog(@"Done with parserDidEndDocument");
    //[self setup];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{

    if (scrollView != scroll) {
       NSInteger tag = scrollView.tag;
        //Experiment 2
        UIView *bar = (UIView *)[scrollView viewWithTag:tag+200];
        
        CGFloat offsetChange = self.lastOffset - scrollView.contentOffset.y;
        CGRect f = bar.frame;
        f.origin.y += offsetChange;
        if (f.origin.y < -self.barHeight) f.origin.y = -self.barHeight;
        if (f.origin.y > 0) f.origin.y = 0;
        //if (scrollView.contentOffset.y <= 0) f.origin.y = 0;
        //if (scrollView.contentOffset.y + scrollView.bounds.size.height >= scrollView.contentSize.height) f.origin.y = -self.barHeight;
        bar.frame = f;
        
        self.lastOffset = scrollView.contentOffset.y;
        
        // Working
        //NSLog(@"scrollViewDidScroll: is this correct scroll?");
        //NSLog(@"%f", scrollView.contentOffset.y);
        //if (!((int)scrollView.contentOffset.y % 10)) {
        
        UIImageView *artImageView = (UIImageView *)[scrollView viewWithTag:tag+100];
        
        if (scrollView.contentOffset.y > 140) {
            NSLog(@"into control if: %f", scrollView.contentOffset.y);
            scrollView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8f];
            artImageView.layer.opacity = 0.2;
        } else if (scrollView.contentOffset.y > 130) {
            NSLog(@"into control if: %f", scrollView.contentOffset.y);
            scrollView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7f];
            artImageView.layer.opacity = 0.3;
        } else if (scrollView.contentOffset.y > 120) {
            NSLog(@"into control if: %f", scrollView.contentOffset.y);
            scrollView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6f];
            artImageView.layer.opacity = 0.4;
        } else if (scrollView.contentOffset.y > 110) {
            NSLog(@"into control if: %f", scrollView.contentOffset.y);
            scrollView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5f];
            artImageView.layer.opacity = 0.5;
        } else if (scrollView.contentOffset.y > 100) {
            NSLog(@"into control if: %f", scrollView.contentOffset.y);
            scrollView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4f];
            artImageView.layer.opacity = 0.6;
        } else if (scrollView.contentOffset.y > 90) {
            NSLog(@"into control if: %f", scrollView.contentOffset.y);
            scrollView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3f];
            artImageView.layer.opacity = 0.7;
        } else if (scrollView.contentOffset.y > 80) {
            NSLog(@"into control if: %f", scrollView.contentOffset.y);
            scrollView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.2f];
            artImageView.layer.opacity = 0.8;
        } else if (scrollView.contentOffset.y > 70) {
            NSLog(@"into control if: %f", scrollView.contentOffset.y);
            scrollView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.1f];
            artImageView.layer.opacity = 0.9;
        } else if (scrollView.contentOffset.y > 60) {
            NSLog(@"into control if: %f", scrollView.contentOffset.y);
            
            scrollView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.0f];
            
            artImageView.layer.opacity = 1.0;
        }
            /*CIImage *imageToBlur = [CIImage imageWithCGImage:artImageView.image.CGImage];
            CIFilter *blurEffect = [CIFilter filterWithName:@"CIGaussianBlur" keysAndValues:kCIInputImageKey,imageToBlur,@"inputRadius",[NSNumber numberWithFloat:0.5],nil];
            CIImage *resultImage = [blurEffect valueForKey:@"outputImage"];
            UIImage *endImage = [[UIImage alloc] initWithCIImage:resultImage];
            [artImageView setImage:endImage];
            */
            //[artImageView setNeedsDisplay];
            
            //Blur the UIImage
            //CIImage *imageToBlur = [CIImage imageWithCGImage:viewImage.CGImage];
            //CIFilter *gaussianBlurFilter = [CIFilter filterWithName: @"CIGaussianBlur"];
            //[gaussianBlurFilter setValue:imageToBlur forKey: @"inputImage"];
            //[gaussianBlurFilter setValue:[NSNumber numberWithFloat: 10] forKey: @"inputRadius"];
            //CIImage *resultImage = [gaussianBlurFilter valueForKey: @"outputImage"];
            //UIImage *endImage = [[UIImage alloc] initWithCIImage:resultImage];
        //}
    } 
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
