//
//  MenuViewController.m
//  iFBA
//
//  Created by Yohann Magnien on 19/02/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>
#import "MenuViewController.h"
#import "EmuViewController.h"
#import "GameBrowserViewController.h"
#import "OptionsViewController.h"
#import "OptDIPSWViewController.h"
#import "OptSaveStateViewController.h"
#import "OptGameInfoViewController.h"

#include "DBHelper.h"
#include "fbaconf.h"
#include "burner.h"

extern int device_retina;

extern char gameInfo[64*1024];

extern int pendingReset;
extern unsigned int nBurnDrvCount;
extern int launchGame;
extern char gameName[64];
extern char tmp_game_name[64];
extern volatile int emuThread_running;
extern int nShouldExit;
extern int device_isIpad;


//iCade & wiimote
#import "iCadeReaderView.h"
#include "wiimote.h"
static int ui_currentIndex_s,ui_currentIndex_r;
static int wiimoteBtnState;
static iCadeReaderView *iCaderv;
static CADisplayLink* m_displayLink;

EmuViewController *emuvc;


@implementation MenuViewController
@synthesize gamebrowservc,optionsvc,dipswvc,statevc;
@synthesize tabView;
@synthesize btn_backToEmu;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title=[NSString stringWithFormat:@"iFBA v%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
        
    }
    return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc{
    [emuvc dealloc];
    [super dealloc];
}

#pragma mark - View lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.    
    
    emuvc = [[EmuViewController alloc] initWithNibName:@"EmuViewController" bundle:nil];
    
    tabView.backgroundView=nil;
    tabView.backgroundView=[[[UIView alloc] init] autorelease];
    
    
    //ICADE & Wiimote
    ui_currentIndex_s=-1;
    iCaderv = [[iCadeReaderView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:iCaderv];
    [iCaderv changeLang:ifba_conf.icade_lang];
    [iCaderv changeControllerType:cur_ifba_conf->joy_iCadeIMpulse];
    iCaderv.active = YES;
    iCaderv.delegate = self;
    [iCaderv release];
    wiimoteBtnState=0;
    
    //
    game_has_options=0;
    
/*    MPVolumeView *volumeView = [ [MPVolumeView alloc] init] ;
    [volumeView setShowsVolumeSlider:NO];
    [volumeView sizeToFit];
    [self.view addSubview:volumeView];*/
}


- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    /* Wiimote check => rely on cadisplaylink*/
    m_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(checkWiimote)];
    m_displayLink.frameInterval = 3; //20fps
	[m_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];    
    
    
    if (emuThread_running) {
        btn_backToEmu.title=[NSString stringWithFormat:@"%s",gameName];
        self.navigationItem.rightBarButtonItem = btn_backToEmu;
    } 
    
    
    [tabView reloadData];
    if (ui_currentIndex_s>=0) {
        [tabView selectRowAtIndexPath:[NSIndexPath indexPathForRow:ui_currentIndex_r inSection:ui_currentIndex_s] animated:YES scrollPosition:UITableViewScrollPositionMiddle];
    }
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    iCaderv.active = YES;
    iCaderv.delegate = self;
    [iCaderv becomeFirstResponder];
    
//    strcpy(gameName,"varth");
//    launchGame=1;
    
    
#if BENCH_MODE
    strcpy(gameName,"varth");
    launchGame=1;
    //change dir
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:@"/var/mobile/Documents/ROMS/"];    
#endif
    
    if (launchGame==1) {
        //by default, use standard settings. Specific game settings check later (below)
        game_has_options=0;
        memcpy(&ifba_game_conf,&ifba_conf,sizeof(ifba_conf_t));
        
        //update game stats
        int playCount,fav,playTime;
        char lastPlayed[11];
        DBHelper::getGameStats(gameName, &playCount, &fav, lastPlayed,&playTime);
        playCount++;
        time_t cur_time=time(NULL);
        strftime(lastPlayed,sizeof(lastPlayed),"%Y/%m/%d",localtime((const time_t*)&cur_time));
        DBHelper::setGameStats(gameName, playCount, fav, lastPlayed,playTime);
//        NSLog(@"Set Stats: pc:%d, fav:%d, lp:%s, pt:%d",playCount,fav,lastPlayed,playTime);
    }
    
    //check if game settings should be changed
    if (game_has_options) { //settings already loaded, ensure any modification are saved
        [[[UIApplication sharedApplication] delegate] saveSettings:[NSString stringWithFormat:@"%s",gameName]];
    }
    
    if (launchGame) { //a game is selected
        if (game_has_options==0) { //no specific setting loaded yet
            //check if settings exist for current game
            if ([[[UIApplication sharedApplication] delegate] loadSettings:[NSString stringWithFormat:@"%s",gameName]]==0) { //yes, apply settings
                game_has_options=1;
                cur_ifba_conf=(ifba_conf_t*)&ifba_game_conf;
            }
            else {//no, use default settings
                cur_ifba_conf=(ifba_conf_t*)&ifba_conf;
            }
        }
        
        if (m_displayLink) [m_displayLink invalidate];
        m_displayLink=nil;
        //[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
        [self.navigationController pushViewController:emuvc animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
    
    if (m_displayLink) [m_displayLink invalidate];
    m_displayLink=nil;
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    //    [emuvc shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    //    [gamebrowservc shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    return YES;
}

#pragma mark - UI Actions
-(IBAction) backToEmu {        
    if (m_displayLink) [m_displayLink invalidate];
    m_displayLink=nil;
    [self.navigationController pushViewController:emuvc animated:NO];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
	return 5;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    int nbRows=0;
    switch (section) {
        case 0:
            if (emuThread_running) nbRows=7;
            else nbRows=1;
            break;
        case 1:
            nbRows=1;
            break;
        case 2:
            nbRows=2;
            break;
        case 3:
            nbRows=1;
            break;
        case 4:
            nbRows=1;
            break;
    }
	return nbRows;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"";
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        /*cell.backgroundColor=[UIColor colorWithRed:1 green:1 blue:1 alpha:0.75f];
         cell.textLabel.backgroundColor=[UIColor clearColor];*/
    }
    
    
    cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    
	switch (indexPath.section) {
        case 0:
            if (emuThread_running) {
                if (indexPath.row==0) {
                    cell.textLabel.text=[NSString stringWithFormat:NSLocalizedString(@"Back to %s",@""),gameName];
                    //                    cell.backgroundColor=[UIColor colorWithRed:0.95f green:1.0f blue:0.95f alpha:1.0f];
                } else if (indexPath.row==1) cell.textLabel.text=NSLocalizedString(@"Save State",@"");
                else if (indexPath.row==2) cell.textLabel.text=NSLocalizedString(@"DIPSW",@"");
                else if (indexPath.row==3) {
                    //                    if (pendingReset) cell.accessoryType=UITableViewCellAccessoryCheckmark;
                    //                    else 
                    cell.accessoryType=UITableViewCellAccessoryNone;
                    cell.textLabel.text=@"Reset";
                    //                    cell.backgroundColor=[UIColor colorWithRed:1.0f green:0.7f blue:0.7f alpha:1.0f];
                } else if (indexPath.row==4) {
                    cell.textLabel.text=NSLocalizedString(@"Information",@"");
                } else if (indexPath.row==5) cell.textLabel.text=NSLocalizedString(@"Close game",@"");
                else if (indexPath.row==6) {
                    cell.textLabel.text=NSLocalizedString(@"Games",@"");
                    //                    cell.backgroundColor=[UIColor colorWithRed:0.8f green:1.0f blue:0.8f alpha:1.0f];
                }
            } else {
                if (indexPath.row==0) cell.textLabel.text=NSLocalizedString(@"Games",@"");            
            }
            break;
        case 1:
            if (indexPath.row==0) cell.textLabel.text=NSLocalizedString(@"Options",@"");
            break;
        case 2:
            if (indexPath.row==0) {
                cell.textLabel.text=NSLocalizedString(@"About",@"");                
            } else if (indexPath.row==1) {
                cell.textLabel.text=@"Beta info";
            }
            break;
        case 3:
            if (indexPath.row==0) cell.textLabel.text=NSLocalizedString(@"Donate",@"");
            break;
        case 4:
            cell.textLabel.text=NSLocalizedString(@"Exit",@"");
            break;
	}		
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section==0) {//Game browser
        if (emuThread_running) {
            switch (indexPath.row) {
                case 0:
                    //[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
                    [self.navigationController pushViewController:emuvc animated:NO];
                    break;
                case 1: //save state
                    statevc=[[OptSaveStateViewController alloc] initWithNibName:@"OptSaveStateViewController" bundle:nil];
                    ((OptSaveStateViewController*)statevc)->emuvc=emuvc;
                    [self.navigationController pushViewController:statevc animated:YES];
                    [statevc release];
                    break;
                case 2://DIP Switches
                    dipswvc = [[OptDIPSWViewController alloc] initWithNibName:@"OptDIPSWViewController" bundle:nil];
                    ((OptDIPSWViewController*)dipswvc)->emuvc=emuvc;
                    [self.navigationController pushViewController:dipswvc animated:YES];
                    [dipswvc release];
                    break;
                case 3: //reset
                    pendingReset=1;
                    //[tabView reloadData];
                    [self backToEmu];
                    break;
                case 4: //game info
                    DBHelper::getGameInfo(gameName, gameInfo);
                    if (gameInfo[0]) {
                        sprintf(tmp_game_name,"%s",gameName);
                        
                        OptGameInfoViewController *infovc;
                        infovc = [[OptGameInfoViewController alloc] initWithNibName:@"OptGameInfoViewController" bundle:nil];
                        [self.navigationController pushViewController:infovc animated:YES];
                        [infovc release];        
                    }
                    break;
                case 5: //close current game
                    nShouldExit=1;
                    while (emuThread_running) {
                        [NSThread sleepForTimeInterval:0.01]; //10ms        
                    }
                    [NSThread sleepForTimeInterval:0.1]; //100ms
                    nShouldExit=0;
                    ui_currentIndex_s=ui_currentIndex_r= 0;
                    self.navigationItem.rightBarButtonItem = nil;
                    [tableView reloadData];
                    break;
                case 6: //game browser
                    gamebrowservc = [[GameBrowserViewController alloc] initWithNibName:@"GameBrowserViewController" bundle:nil];
                    ((GameBrowserViewController*)gamebrowservc)->emuvc=emuvc;
                    [self.navigationController pushViewController:gamebrowservc animated:YES];
                    [gamebrowservc release];
                    break;
            }
        } else {
            switch (indexPath.row) {
                case 0: //game browser
                    gamebrowservc = [[GameBrowserViewController alloc] initWithNibName:@"GameBrowserViewController" bundle:nil];
                    ((GameBrowserViewController*)gamebrowservc)->emuvc=emuvc;
                    [self.navigationController pushViewController:gamebrowservc animated:YES];
                    [gamebrowservc release];
                    break;
            }
        }
    } else if (indexPath.section==1) { //options
        optionsvc=[[OptionsViewController alloc] initWithNibName:@"OptionsViewController" bundle:nil];
        ((OptionsViewController*)optionsvc)->emuvc=emuvc;
        [self.navigationController pushViewController:optionsvc animated:YES];
        [optionsvc release];
    } else if (indexPath.section==2) { //about & feedback        
        if (indexPath.row==0) {//about
            NSString *msgString=[NSString stringWithFormat:NSLocalizedString(@"About_Msg",@""),[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],nBurnDrvCount];
            UIAlertView *aboutMsg=[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"About",@"") message:msgString delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil] autorelease];
            [aboutMsg show];
        } else if (indexPath.row==1) {//beta test-info
            NSString *msgString=[NSString stringWithFormat:@"'follow-finger' coverage:\n%@\n----------------------------------\nReplay coverage:\n%@",[FFINGER_COVERAGE stringByReplacingOccurrencesOfString:@"," withString:@"\n"],[REPLAY_COVERAGE stringByReplacingOccurrencesOfString:@"," withString:@"\n"]];
            UIAlertView *aboutBetaMsg=[[[UIAlertView alloc] initWithTitle:@"Beta info" message:msgString delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil] autorelease];
            [aboutBetaMsg show];
        }
    } else if (indexPath.section==3) { //Donate
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=GR6NNLLWD62BN"]];
    } else if (indexPath.section==4) { //Exit
        nShouldExit=1;
        while (emuThread_running) {
            [NSThread sleepForTimeInterval:0.01]; //10ms        
        }
        [NSThread sleepForTimeInterval:0.1]; //100ms
        //exit(0);
        [[UIApplication sharedApplication] terminateWithSuccess];
    }
}

/*#pragma UIAlertView delegate
 - (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
 }
 */

#pragma Wiimote/iCP support
#define WII_BUTTON_UP(A) (wiimoteBtnState&A)&& !(pressedBtn&A)
-(void) checkWiimote {
    if (num_of_joys==0) return;
    int pressedBtn=iOS_wiimote_check(&(joys[0]));
    
    if (WII_BUTTON_UP(WII_JOY_DOWN)) {
        [self buttonUp:iCadeJoystickDown];
    } else if (WII_BUTTON_UP(WII_JOY_UP)) {
        [self buttonUp:iCadeJoystickUp];
    } else if (WII_BUTTON_UP(WII_JOY_LEFT)) {
        [self buttonUp:iCadeJoystickLeft];
    } else if (WII_BUTTON_UP(WII_JOY_RIGHT)) {
        [self buttonUp:iCadeJoystickRight];
    } else if (WII_BUTTON_UP(WII_JOY_A)) {
        [self buttonUp:iCadeButtonA];
    } else if (WII_BUTTON_UP(WII_JOY_B)) {
        [self buttonUp:iCadeButtonB];
    } else if (WII_BUTTON_UP(WII_JOY_C)) {
        [self buttonUp:iCadeButtonC];
    } else if (WII_BUTTON_UP(WII_JOY_D)) {
        [self buttonUp:iCadeButtonD];
    } else if (WII_BUTTON_UP(WII_JOY_E)) {
        [self buttonUp:iCadeButtonE];
    } else if (WII_BUTTON_UP(WII_JOY_F)) {
        [self buttonUp:iCadeButtonF];
    } else if (WII_BUTTON_UP(WII_JOY_G)) {
        [self buttonUp:iCadeButtonG];
    } else if (WII_BUTTON_UP(WII_JOY_H)) {
        [self buttonUp:iCadeButtonH];
    }
    
    
    wiimoteBtnState=pressedBtn;
}


#pragma Icade support
/****************************************************/
/****************************************************/
/*        ICADE                                     */
/****************************************************/
/****************************************************/
- (void)buttonDown:(iCadeState)button {
}
- (void)buttonUp:(iCadeState)button {
    if (ui_currentIndex_s==-1) {
        ui_currentIndex_s=ui_currentIndex_r=0;
    }
    else {
        if (button&iCadeJoystickDown) {            
            if (ui_currentIndex_r<[tabView numberOfRowsInSection:ui_currentIndex_s]-1) ui_currentIndex_r++; //next row
            else { //next section
                if (ui_currentIndex_s<[tabView numberOfSections]-1) {
                    ui_currentIndex_s++;ui_currentIndex_r=0; //next section
                } else {
                    ui_currentIndex_s=ui_currentIndex_r=0; //loop to 1st section
                }
            }             
        } else if (button&iCadeJoystickUp) {
            if (ui_currentIndex_r>0) ui_currentIndex_r--; //prev row            
            else { //prev section
                if (ui_currentIndex_s>0) {
                    ui_currentIndex_s--;ui_currentIndex_r=[tabView numberOfRowsInSection:ui_currentIndex_s]-1; //next section
                } else {
                    ui_currentIndex_s=[tabView numberOfSections]-1;ui_currentIndex_r=[tabView numberOfRowsInSection:ui_currentIndex_s]-1; //loop to 1st section
                }
            }
        } else if (button&iCadeButtonA) { //validate            
            [self tableView:tabView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:ui_currentIndex_r inSection:ui_currentIndex_s]];
            
        } else if (button&iCadeButtonB) { //back
            if (emuThread_running) {
                [self backToEmu];
            } 
        }
    }
    [tabView selectRowAtIndexPath:[NSIndexPath indexPathForRow:ui_currentIndex_r inSection:ui_currentIndex_s] animated:YES scrollPosition:UITableViewScrollPositionMiddle];
}



@end
