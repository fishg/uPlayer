//
//  windowController.m
//  uPlayer
//
//  Created by liaogang on 15/1/28.
//  Copyright (c) 2015年 liaogang. All rights reserved.
//

#import "windowController.h"
#import "TracklistViewController.h"
#import "UPlayer.h"
#import "PlayerMessage.h"
#import "AppDelegate.h"
#import "PlaylistViewController.h"

#define uPlayerWinPos @"uPlayerWinPos"
#define PlaylistWinPos @"PlaylistWinPos"


@interface NSSliderCellHideThumbWhenDisable : NSSliderCell
-(void)drawKnob:(NSRect)knobRect;
@end

@implementation NSSliderCellHideThumbWhenDisable
-(void)drawKnob:(NSRect)knobRect
{
    if (self.enabled)
        [super drawKnob:knobRect];
}
@end



@interface WindowController () <NSTextFieldDelegate>
@property (weak) IBOutlet NSPopUpButton *playOrderBtn;
@property (weak) IBOutlet NSSlider *progressSlider;
@property (weak) IBOutlet NSSlider *volumnSlider;
@property (weak) IBOutlet NSSearchField *searchField;

@property (weak) IBOutlet NSButton *btnPlayPause;
@property (weak) IBOutlet NSButton *btnNextTrack;
@property (weak) IBOutlet NSButton *btnPlayRandom;

@property (strong,nonatomic) PlaylistViewController* playlistManager;
@end

@implementation WindowController

-(void)awakeFromNib
{
    self.window.title=player().document.windowName;
    
    [self.playOrderBtn addItemsWithTitles:  kPlayOrder];
    
    addObserverForEvent(self , @selector(updateUI), EventID_track_state_changed);
    
    addObserverForEvent(self , @selector(trackStarted:), EventID_track_started);
    
    addObserverForEvent(self, @selector(updateProgressInfo:), EventID_track_progress_changed);
    
    addObserverForEvent(self, @selector(initCtrls), EventID_player_document_loaded);
    
    addObserverForEvent(self, @selector(showPlaylistManager), EventID_to_show_playlist);
    

}



-(void)showPlaylistManager
{
    NSWindow *wnd;
    
    if (!_playlistManager)
    {
        NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
        
       self.playlistManager = [storyboard instantiateControllerWithIdentifier:@"IDPlaylistViewController"];
    }
    
    wnd = _playlistManager.view.window;
    if (!wnd)
    {
        wnd = [NSWindow windowWithContentViewController:_playlistManager];
        
        [wnd setFrameUsingName:PlaylistWinPos ];
        [wnd setFrameAutosaveName:PlaylistWinPos];
    }
    
    if (wnd.parentWindow)
        [wnd makeKeyWindow];
    else
        [self.window addChildWindow:wnd ordered:NSWindowAbove];
    
}

- (IBAction)actionOrderChanged:(id)sender
{
    player().document.playOrder = (PlayOrder)self.playOrderBtn.indexOfSelectedItem;
}


- (IBAction)actionSearch:(id)sender
{
    TracklistViewController *vc = (TracklistViewController *) self.contentViewController;
    
    NSSearchField *sf = (NSSearchField *)sender;
    
    [vc filterTable:sf.stringValue];
}


- (IBAction)actionProgressSlider:(id)sender
{
    [player().engine seekToTime:[sender floatValue]];
}

- (IBAction)actionVolumnSlider:(id)sender
{
    [player().engine setVolume:[sender floatValue]];
}

-(void)updateProgressInfo:(NSNotification*)n
{
    if (!self.progressSlider.highlighted)
    {
        ProgressInfo *info = n.object;
        
        NSAssert([info isKindOfClass:[ProgressInfo class]], nil);
        [self.progressSlider setMaxValue:info.total];
        [self.progressSlider setDoubleValue:info.current];
    }
    
}

-(void)trackStarted:(NSNotification*)n
{
    ProgressInfo *info = n.object;
    NSAssert([info isKindOfClass:[ProgressInfo class]], nil);
    [self.progressSlider setMaxValue:info.total];
    [self.progressSlider setDoubleValue:0];
}

-(void)updateUI
{
    PlayerTrack *track = player().playing;
    
    BOOL stopped = [player().engine isStopped];
    BOOL paused = [player().engine isPaused];
    
    if (paused || stopped)
        _btnPlayPause.image = [NSImage imageNamed:@"Play_Button"];
    else
        _btnPlayPause.image = [NSImage imageNamed:@"Pause_Button"];

    
    
    if (stopped)
    {
        self.window.title = player().document.windowName;
        self.progressSlider.enabled = false;
    }
    else
    {
        if (track)
        {
            NSString *title = compressTitle(track.info);
            NSString *wTitle;
            if ( paused )
            {
                wTitle = [title stringByAppendingFormat:@"  (%@)", NSLocalizedString(@"Paused" ,nil) ];
            }
            else
            {
                wTitle = title;
            }
            
            self.window.title = wTitle;
            
        }
        self.progressSlider.enabled = true;
    }
    
}


-(void)dealloc
{
    removeObserver(self);
}


-(void)initCtrls
{
    [self.playOrderBtn selectItemAtIndex: player().document.playOrder ];
    
    self.progressSlider.enabled = player().document.playState != playstate_stopped;
    
    self.volumnSlider.doubleValue = player().document.volume;
}

-(void)windowDidLoad
{
    [super windowDidLoad];
    
    [self.window setFrameUsingName: uPlayerWinPos];
    [self.window setFrameAutosaveName:uPlayerWinPos];
}

-(void)keyDown:(NSEvent *)theEvent
{
#ifdef DEBUG
    printf("key pressed: %s\n", [[theEvent description] UTF8String]);
#endif
}


#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    _searchField.stringValue = @"";
    return YES;
}

#pragma mark - 

-(void)activeSearchControl
{
    [self.window makeFirstResponder:_searchField];
}

- (IBAction)cmdPlayPause:(id)sender
{
    PlayerEngine *e = player().engine;
    
    if( [ e isStopped])
        postEvent(EventID_to_play_selected_track, nil);
    else
        postEvent(EventID_to_play_pause_resume, nil);
}

- (IBAction)cmdNextTrack:(id)sender {
    postEvent(EventID_to_play_next, nil);
    postEvent(EventID_to_reload_tracklist, nil);
}

- (IBAction)cmdPlayRandom:(id)sender {
    postEvent(EventID_to_play_random, nil);
    postEvent(EventID_to_reload_tracklist, nil);
}

-(void)mouseDown:(NSEvent *)theEvent
{
    // Active the current song if double clicked on the bottom bar.
    if (theEvent.clickCount == 2) {
        NSRect rc = NSMakeRect(0, 0, self.window.frame.size.width, [self.window contentBorderThicknessForEdge: CGRectMinYEdge] );
        if ( NSPointInRect( theEvent.locationInWindow, rc )) {
            postEvent(EventID_to_reload_tracklist, player().playing );
        }
    }
    
}

@end
