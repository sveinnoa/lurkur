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

@interface WeatherViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *weatherArtImage;

@property(strong) NSDictionary *weather;
@property(strong) NSMutableDictionary *xmlWeather; //package containing the complete response
@property(strong) NSMutableDictionary *currentDictionary; //current section being parsed
@property(strong) NSString *previousElementName;
@property(strong) NSString *elementName;
@property(strong) NSMutableString *outstring;

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
}
@synthesize weatherArtImage = _weatherArtImage;


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    queue = [[NSOperationQueue alloc] init];
    NSString *const FlickrAPIKey = @"b5daebf7a95fb8c7a57145848dbc127d";
//    NSString *tags = @"iceland landscape";
    NSString *tags = @"reykjavik";
    NSString *escapeTags = [tags stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSString *urlString =
    [NSString stringWithFormat:
     @"http://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=%@&tags=%@&per_page=20&format=json&nojsoncallback=1&group_id=29722852@N00",
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
 
    // hardcode Reykjavik and Holmavik
    NSString *weatherUrlStr = [NSString stringWithFormat:@"%@1;2481",BaseURLString];
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

- (void)parseDictionary:(NSDictionary *)dictionary
{
    NSLog(@"%@", dictionary);
    NSArray *photos = [[dictionary objectForKey:@"photos"] objectForKey:@"photo"];
    NSLog(@"array size: %d", [photos count]);
    NSInteger target = (arc4random() % [photos count]);
    NSLog(@"target: %d", target);
    NSDictionary *p = photos[target];
    NSLog(@"%@", p);
    photoTitle = [p objectForKey:@"title"];
    photoURLString = [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_b.jpg", [p objectForKey:@"farm"], [p objectForKey:@"server"], [p objectForKey:@"id"], [p objectForKey:@"secret"]];
    
    NSLog(@"photoURLString: %@", photoURLString);
    
    [self updateImage];
}


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
    UILabel *textLabel = [[UILabel alloc] init];
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
    textLabel2.text = [NSString stringWithFormat:@"%@\n%@", stationName, observationTime];
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
    [[self view] addSubview:textLabel];
    [[self view] addSubview:textLabel2];
//    [[self view] addSubview:textLabel3];

}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
