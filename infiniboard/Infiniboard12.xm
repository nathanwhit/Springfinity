 // License {{{ */

/*
 * Copyright (c) 2010-2014, Xuzz Productions, LLC
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/* }}} */

/* Configuration {{{ */

#include <os/log.h>
#include "InspCWrapper.m"
#define log(str) os_log(OS_LOG_DEFAULT, str)
#define logf(fmt, ...) os_log(OS_LOG_DEFAULT, fmt, __VA_ARGS__)

#define IFConfigurationTweakIdentifier Infiniboard
#define IFConfigurationListClass SBIconListView
#define IFConfigurationListClassObject (%c(SBRootIconListView) ?: %c(SBIconListView))
#define IFConfigurationScrollViewClass IFInfiniboardScrollView
// #define IFConfigurationFullPages (dlopen("/Library/MobileSubstrate/DynamicLibraries/Iconoclasm.dylib", RTLD_LAZY) != NULL)

#define IFPreferencesRestoreEnabled @"RestoreEnabled", NO
#define IFPreferencesFastRestoreEnabled @"FastRestoreEnabled", NO

#include <UIKit/UIKit.h>
#include "infinishared/Infinilist.xm"
#include "infinishared/Preferences.h"
#include <substrate.h>


@interface UIScrollView (iOS12)
@property (nonatomic) UIEdgeInsets safeAreaInsets;
@property (nonatomic) NSUInteger contentInsetAdjustmentBehavior;
- (UIEdgeInsets)adjustedContentInset;
- (void)safeAreaInsetsDidChange;
@end

@interface IFInfiniboardScrollView : UIScrollView
@end

/* }}} */

%group IFInfiniboard
%hook SBIconListView

- (NSUInteger)rowForIcon:(SBIcon *)icon {
    SBIconView *iconView = IFIconViewForIcon(icon);
    NSUInteger ret = %orig;

    if (IFFlagFolderOpening) {
        if (IFPreferencesBoolForKey(IFPreferencesPagingEnabled)) {
            ret %= IFSizingDefaultDimensionsForIconList(self).rows;
        } else {
            CGPoint origin = [iconView frame].origin;

            UIScrollView *scrollView = IFListsScrollViewForListView(self);
            origin.y -= [scrollView contentOffset].y;

            ret = [self rowAtPoint:origin];
        }
    }

    return ret;
}

%new(i@:)
- (int)infiniboardDefaultRows {
	int result;
	IFFlag(IFFlagDefaultDimensions) {
		result = [self iconRowsForCurrentOrientation];
	}
	return result;
}

%end

%hook SBIconController

// - (void)_setOpenFolder:(SBFolder *)folder {
//     log("here");
//     %orig;

//     if (folder != nil) {
//         SBIcon *folderIcon = [[self openFolder] icon];

//         SBIconListView *listView = IFIconListContainingIcon(folderIcon);
//         UIScrollView *scrollView = IFListsScrollViewForListView(listView);

//         if (scrollView != nil) {
//             // We have a scroll view, so this is a list we care about.
//             SBIconView *folderIconView = IFIconViewForIcon(folderIcon);
//             [scrollView scrollRectToVisible:[folderIconView frame] animated:NO];
//         } else {
//             // Get last icon on current page; scroll that icon to visible.
//             // (This fixes visual issues when icons are partially scrolled
//             // between rows and a folder is opened when it's in the dock.)
//             CGPoint point = CGPointMake(0, [listView bounds].size.height);
//             SBIcon *lastIcon = [listView iconAtPoint:point index:NULL];
//             SBIconView *lastIconView = IFIconViewForIcon(lastIcon);

//             if (lastIconView != nil) {
//                 [scrollView scrollRectToVisible:[lastIconView frame] animated:NO];
//             }
//         }
//     }
// }

- (void)openFolderIcon:(id)arg1 animated:(_Bool)arg2 withCompletion:(id)arg3 {
    %orig;
    if ([arg1 isKindOfClass:%c(SBIcon)]) {
        SBIcon *folderIcon = (SBIcon*)arg1;
        SBIconListView *listView = IFIconListContainingIcon(folderIcon);
        UIScrollView *scrollView = IFListsScrollViewForListView(listView);
        if (scrollView != nil) {
            // We have a scroll view, so this is a list we care about.
            SBIconView *folderIconView = IFIconViewForIcon(folderIcon);
            [scrollView scrollRectToVisible:[folderIconView frame] animated:NO];
        } else {
            // Get last icon on current page; scroll that icon to visible.
            // (This fixes visual issues when icons are partially scrolled
            // between rows and a folder is opened when it's in the dock.)
            CGPoint point = CGPointMake(0, [listView bounds].size.height);
            SBIcon *lastIcon = [listView iconAtPoint:point index:NULL];
            SBIconView *lastIconView = IFIconViewForIcon(lastIcon);

            if (lastIconView != nil) {
                [scrollView scrollRectToVisible:[lastIconView frame] animated:NO];
            }
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    %orig;
    IFFastRestoreIconLists();
}

%end

%hook SBRootFolderView

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    %orig;
    IFFastRestoreIconLists();
}

%end

%hook SBUIController

- (void)restoreIconList:(BOOL)animated {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreIconListAnimated:(BOOL)animated {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreIconListAnimated:(BOOL)animated animateWallpaper:(BOOL)animateWallpaper {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreIconListAnimated:(BOOL)animated animateWallpaper:(BOOL)wallpaper keepSwitcher:(BOOL)switcher {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreIconListAnimated:(BOOL)animated delay:(NSTimeInterval)delay {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreIconListAnimated:(BOOL)animated delay:(NSTimeInterval)delay animateWallpaper:(BOOL)wallpaper keepSwitcher:(BOOL)switcher {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreIconListAnimatedIfNeeded:(BOOL)needed animateWallpaper:(BOOL)wallpaper {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreContent {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreContentAndUnscatterIconsAnimated:(BOOL)animated {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreContentAndUnscatterIconsAnimated:(BOOL)animated withCompletion:(id)completion {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreContentUpdatingStatusBar:(BOOL)updateStatusBar {
    %orig;
    IFRestoreIconLists();
}

- (void)restoreIconListForSuspendGesture {
    %orig;
    IFRestoreIconLists();
}

%end

%end

/* }}} */

static void IFIconListInitialize(SBIconListView *listView) {
    UIScrollView *scrollView = [[IFConfigurationScrollViewClass alloc] initWithFrame:[listView frame]];
    [scrollView setDelegate:(id<UIScrollViewDelegate>) listView];
    [scrollView setDelaysContentTouches:NO];

    IFListsRegister(listView, scrollView);
    [listView addSubview:scrollView];

    IFIconListSizingUpdateIconList(listView);
    IFPreferencesApplyToList(listView);
}

%group IFBasic
%hook SBIconListView

/* View Hierarchy {{{ */

- (id)initWithFrame:(CGRect)frame {
    id ret = %orig;
    if (self == ret) {
        // Avoid hooking a sub-initializer when we hook the base initializer, but otherwise do hook it.
        if (IFIconListIsValid(self) && ![self isKindOfClass:%c(SBDockIconListView)]) {
            IFIconListInitialize(self);
        }
    }

    return ret;
}

- (id)initWithFrame:(CGRect)frame viewMap:(id)viewMap {
    id ret = %orig;
    if (self == ret) {
        if (IFIconListIsValid(self)) {
            IFIconListInitialize(self);
        }
    }

    return ret;
}

- (id)initWithModel:(id)arg1 orientation:(NSUInteger)arg2 viewMap:(id)arg3 {
    id ret = %orig;
    if (self == ret) {
        if (IFIconListIsValid(self)) {
            IFIconListInitialize(self);
        }
    }
    return ret;
}

- (void)dealloc {
    if (IFIconListIsValid(self)) {
        UIScrollView *scrollView = IFListsScrollViewForListView(self);

        IFListsUnregister(self, scrollView);
        IFIconListSizingRemoveInformationForIconList(self);

    }

    %orig;
}

- (void)setFrame:(CGRect)frame {
    if (IFIconListIsValid(self)) {
        UIScrollView *scrollView = IFListsScrollViewForListView(self);

        NSUInteger pagex = 0;
        NSUInteger pagey = 0;

        if (IFPreferencesBoolForKey(IFPreferencesPagingEnabled)) {
            CGPoint offset = [scrollView contentOffset];
            CGRect bounds = [self bounds];

            pagex = (offset.x / bounds.size.width);
            pagey = (offset.y / bounds.size.height);
        }

        %orig;

        [scrollView setFrame:[self bounds]];
        IFIconListSizingUpdateIconList(self);

        [self layoutIconsNow];

        if (IFPreferencesBoolForKey(IFPreferencesPagingEnabled)) {
            CGPoint offset = [scrollView contentOffset];
            CGRect bounds = [self bounds];

            offset.x = (pagex * bounds.size.width);
            offset.y = (pagey * bounds.size.height);
            [scrollView setContentOffset:offset animated:YES];
        }
    } else {
        %orig;
    }
}

- (BOOL)shouldReparentView:(UIView*)view {
    if ([[view superview] isKindOfClass:%c(IFInfiniboardScrollView)]) {
        return NO;
    }
    else {
        return %orig;
    }
}


- (void)addSubview:(UIView *)view {
    static SBIconListView *lastListView;
    static UIScrollView *lastScrollView;
    static __weak SBIconListView *formerLastListView;
    static __weak UIScrollView *formerLastScrollView;
    if (IFIconListIsValid(self)) {
        if (lastListView != self) {
            if (formerLastListView == self) {
                lastListView = formerLastListView;
                lastScrollView = formerLastScrollView;
            }
            else {
                formerLastListView = lastListView;
                formerLastScrollView = lastScrollView;
                lastListView = self;
                lastScrollView = IFListsScrollViewForListView(self);
            }
            
        }

        if (view == lastScrollView) {
            %orig;
        } 
        else {
            [lastScrollView addSubview:view];
            // IFIconListSizingUpdateIconList(self);
        }
    } 
    else {
        %orig;
    }
}

- (void)setOrientation:(UIInterfaceOrientation)orientation {
    %orig;

    if (IFIconListIsValid(self)) {
        IFIconListSizingUpdateIconList(self);
    }
}

- (void)cleanupAfterRotation {
    %orig;

    if (IFIconListIsValid(self)) {
        [self layoutIconsNow];
    }
}

/* }}} */

/* Icon Layout {{{ */
/* Dimensions {{{ */

+ (NSUInteger)maxIcons {
    if (self == IFConfigurationListClassObject) {
        if (IFFlagDefaultDimensions) {
            return %orig;
        } else {
            return IFConfigurationExpandedDimension * IFConfigurationExpandedDimension;
        }
    } else {
        return %orig;
    }
}

+ (NSUInteger)maxVisibleIconRowsInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (self == IFConfigurationListClassObject) {
        NSUInteger rows = 0;

        IFFlag(IFFlagDefaultDimensions) {
            rows = %orig;
        }

        return rows;
    } else {
        return %orig;
    }
}

+ (NSUInteger)iconRowsForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (self == IFConfigurationListClassObject) {
        if (IFFlagDefaultDimensions) {
            return %orig;
        } else {
            IFIconListDimensions dimensions = IFSizingMaximumDimensionsForOrientation(interfaceOrientation);
            return dimensions.rows;
        }
    } else {
        return %orig;
    }
}

+ (NSUInteger)iconColumnsForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (self == IFConfigurationListClassObject) {
        if (IFFlagDefaultDimensions) {
            return %orig;
        } else {
            IFIconListDimensions dimensions = IFSizingMaximumDimensionsForOrientation(interfaceOrientation);
            return dimensions.columns;
        }
    } else {
        return %orig;
    }
}

- (NSUInteger)iconRowsForCurrentOrientation {
    if (IFIconListIsValid(self)) {
        if (IFFlagExpandedFrame) {
            IFIconListDimensions dimensions = [IFIconListSizingInformationForIconList(self) contentDimensions];
            return dimensions.rows;
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}

- (NSUInteger)iconColumnsForCurrentOrientation {
    if (IFIconListIsValid(self)) {
        if (IFFlagExpandedFrame) {
            IFIconListDimensions dimensions = [IFIconListSizingInformationForIconList(self) contentDimensions];
            return dimensions.columns;
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}

- (NSUInteger)rowAtPoint:(CGPoint)point {
    if (IFIconListIsValid(self)) {
        NSUInteger row = 0;

        IFFlag(IFFlagExpandedFrame) {
            UIScrollView *scrollView = IFListsScrollViewForListView(self);
            CGPoint offset = [scrollView contentOffset];
            CGSize size = [scrollView frame].size;

            if (IFPreferencesBoolForKey(IFPreferencesPagingEnabled)) {
                row = %orig;

                NSUInteger page = (offset.y / size.height);
                IFIconListDimensions dimensions = IFSizingDefaultDimensionsForIconList(self);
                row += page * dimensions.rows;
            } else {
                point.x += offset.x;
                point.y += offset.y;

                row = %orig;
            }
        }

        return row;
    } else {
        return %orig;
    }
}

/* }}} */


%end

/* Fixes {{{ */

%hook SBIconView
%property (nonatomic, assign) bool isBeingChecked;
-(id)superview {
    id view = %orig;
    if (![self isBeingChecked]) {
        return view;
    }
    else {
        if ([view isKindOfClass:%c(IFInfiniboardScrollView)]) {
            SBIconListView *listView = IFListsListViewForScrollView((UIScrollView*)view);
            return listView;
        }
        else {
            return view;
        }
    }
}

-(CGPoint)center {
    id view = [self superview];
    CGPoint scrolledCenter = %orig;
    if ([self isBeingChecked] && [view isKindOfClass:%c(SBRootIconListView)]) {
        IFInfiniboardScrollView *infiniboardView = (IFInfiniboardScrollView*)IFListsScrollViewForListView((SBIconListView*)view);
        scrolledCenter.y -= [infiniboardView contentOffset].y;
        [self setIsBeingChecked:false];
    }
    return scrolledCenter;
}

%end

static __weak UIScrollView *frozenScrollView = nil;

%hook SBIconListViewDraggingAppPolicyHandler
static bool dropping = false;
-(id)dropInteraction:(id)arg1 previewForDroppingItem:(id)dropItem withDefault:(id)arg3 {
    dropping = true;
    return %orig;

}
-(id)_iconViewForDragItem:(id)item {
    id view = %orig;
    if (dropping) {
        SBIconView *iconView = nil;
        if ([view isKindOfClass:%c(SBIconView)]) {
            iconView = (SBIconView*)view;
        }
        [iconView setIsBeingChecked:true];
        SBIconListView *listView = IFIconListContainingIcon([iconView icon]);
        UIScrollView *scrollView = IFListsScrollViewForListView(listView);
        [scrollView setScrollEnabled:NO];
        frozenScrollView = scrollView;
    }
    return view;
}
%end

%hook SBIconDragManager
-(void)concludeIconDrop:(id)drop {
    // This fix (disabling scrolling while the icon drop animation completes) is not ideal, but I'm not sure else how to get around this at the moment
    dropping = false;
    if (IFPreferencesBoolForKey(IFPreferencesScrollEnabled)) {
        [frozenScrollView setScrollEnabled:YES];
        frozenScrollView = nil;
    }
    %orig;
}
%end

%end


/* Custom Scroll View {{{ */

@implementation IFInfiniboardScrollView

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    // Allow accessing Spotlight when scrolled to the top on iOS 7.0+.
    if (%c(SBSearchScrollView) != nil) {
        if (gestureRecognizer == [self panGestureRecognizer]) {
            CGPoint offset = [self contentOffset];
            CGPoint velocity = [[self panGestureRecognizer] velocityInView:self];

            if (offset.y <= 0.0 && velocity.y > 0.0) {
                return NO;
            }
        }
    }

    return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

@end

/* }}} */

/* Constructor {{{ */

%ctor {
    IFListsInitialize();
    IFPreferencesInitialize(@"com.nwhit.infiniboard12prefs");
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)IFPreferencesApply, (CFStringRef)@"com.nwhit.infiniboard12prefs.preferences-changed", NULL, 0);
    %init(IFInfiniboard);
    %init(IFBasic);
}

/* }}} 