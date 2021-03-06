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

#define IFConfigurationTweakIdentifier Springfinity
#define IFConfigurationListClass SBRootIconListView
#define IFConfigurationListClassObject (%c(SBRootIconListView) ?: %c(SBIconListView))
#define IFConfigurationScrollViewClass IFInfiniboardScrollView
// #define IFConfigurationFullPages (dlopen("/Library/MobileSubstrate/DynamicLibraries/Iconoclasm.dylib", RTLD_LAZY) != NULL)

#define IFPreferencesRestoreEnabled @"RestoreEnabled", YES
#define IFPreferencesFastRestoreEnabled @"FastRestoreEnabled", NO
#define IFPreferencesTopOnTap @"TopOnTap", YES

#include <UIKit/UIKit.h>
#include "shared/Infinilist.xm"
#include "shared/Preferences.h"
#include <substrate.h>
#include <math.h>


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
%hook SBRootIconListView

- (NSUInteger)rowForIcon:(SBIcon *)icon {
    if (IFIconListIsValid(self)) {
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
    return %orig;
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

%hook SBRootFolderView

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    %orig;
    IFFastRestoreIconLists();
}

%end

%end

/* }}} */

static void IFIconListInitialize(SBIconListView *listView) {
    UIScrollView *scrollView = [[IFConfigurationScrollViewClass alloc] initWithFrame:[listView bounds]];
    [scrollView setDelegate:(id<UIScrollViewDelegate>) listView];
    [scrollView setDelaysContentTouches:NO];

    IFListsRegister(listView, scrollView);
    [listView addSubview:scrollView];

    IFIconListSizingUpdateIconList(listView);
    IFPreferencesApplyToList(listView);
    [NSLayoutConstraint activateConstraints: @[
        [scrollView.topAnchor constraintEqualToAnchor:listView.topAnchor],
        [scrollView.leftAnchor constraintEqualToAnchor:listView.leftAnchor],
        [scrollView.rightAnchor constraintEqualToAnchor:listView.rightAnchor]
    ]];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    // listView.translatesAutoresizingMaskIntoConstraints = NO;
}

%group IFBasic

%hook SBRootIconListView

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

- (id)initWithModel:(id)arg1 orientation:(NSUInteger)arg2 viewMap:(id)arg3 {
    id ret = %orig;
    if (self == ret) {
        if (IFIconListIsValid(ret)  && ![self isKindOfClass:%c(SBDockIconListView)]) {
            IFIconListInitialize(ret);
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

// - (void)setFrame:(CGRect)frame {
//     if (IFIconListIsValid(self)) {
//         %orig;
//         if (!IFListsScrollViewForListView(self)) {
//             IFIconListInitialize(self);
//         }
//     }
//     else {
//         %orig;
//     }
// }

// - (void)setFrame:(CGRect)frame {
    // if (frame.size.width == 0) {
    //     %orig;
    //     return;
    // }
    // if (IFIconListIsValid(self)) {
        // UIScrollView *scrollView = IFListsScrollViewForListView(self);
        // %orig;
        // if (!scrollView) {
        //     IFIconListInitialize(self);
        // }
        // if (scrollView.bounds.size.width == 0 || scrollView.bounds.size.height == 0) {
            // log("Scrollview was invisible");
            // [scrollView setFrame:self.bounds];
        // }
        // [self layoutIconsNow];
        // IFIconListSizingUpdateIconList(self);

        // NSUInteger pagex = 0;
        // NSUInteger pagey = 0;
        // CGFloat pagingAdjustmentHeight = 0;
        // bool pages = IFPreferencesBoolForKey(IFPreferencesPagingEnabled);

        // if (pages) {
        //     CGPoint offset = [scrollView contentOffset];
        //     CGRect bounds = [self bounds];

        //     pagex = (offset.x / bounds.size.width);
        //     pagey = (offset.y / bounds.size.height);
        // }

        // %orig;
        // if (pages) {
        //     IFIconListSizingInformation *info = IFIconListSizingInformationForIconList(self);
        //     pagingAdjustmentHeight = fabs(info.defaultPadding.height - info.defaultInsets.top - info.defaultInsets.bottom);
        //     if (scrollView.frame.origin.y != self.frame.origin.y || scrollView.frame.size.height+pagingAdjustmentHeight != self.frame.size.height || scrollView.frame.size.width != self.frame.size.width) {
        //         CGRect bounds = self.bounds;
        //         bounds.size.height = bounds.size.height - pagingAdjustmentHeight;
        //         static dispatch_once_t getInitialTouchInsetsToken;
        //         static UIEdgeInsets touchInsets;
        //         dispatch_once(&getInitialTouchInsetsToken, ^{
        //             touchInsets = [scrollView _autoScrollTouchInsets];
        //         });
        //         [scrollView _setAutoScrollTouchInsets:UIEdgeInsetsMake(touchInsets.top / 4, touchInsets.left, touchInsets.bottom / 4, touchInsets.right)];
        //         [scrollView setFrame: bounds];
        //         [self layoutIconsNow];
        //         IFIconListSizingUpdateIconList(self);
        //     }
        //     return;
        // }
        // else if (self.frame.size.height != scrollView.frame.size.height || self.frame.size.width != self.frame.size.width) {
        // // else {
        //     [scrollView setFrame:self.bounds];
        //     [self layoutIconsNow];
        //     IFIconListSizingUpdateIconList(self);
        //     return;
        // }
        // else {
        //     [scrollView setFrame:self.bounds];
        //     return;
        // }
    // } else {
    //     %orig;
    // }
// }
    // (
- (void)setFrame:(CGRect)fr {
    CGSize currentSize = self.frame.size;
    if (IFIconListIsValid(self) && !CGSizeEqualToSize(currentSize, fr.size)) {
    %orig;
        IFIconListSizingUpdateIconList(self);
        if (IFListsScrollViewForListView(self)) {
            IFPreferencesApplyToList(self);
    }
}
    else {
    %orig;
    }
}
// - (void)setBounds:(CGRect)b {
//     log("SETTING BOUNDS");
//     %orig;
//     if (IFIconListIsValid(self)) {
//         IFIconListSizingUpdateIconList(self);
//     }
// }

- (BOOL)shouldReparentView:(UIView*)view {
    if ([[view superview] isKindOfClass:%c(IFInfiniboardScrollView)] && view.superview.superview == self) {
        return NO;
    }
    else {
        return %orig;
    }
}


- (void)addSubview:(UIView *)view {
    if (IFIconListIsValid(self)) {
        if ([view isMemberOfClass: [IFInfiniboardScrollView class]]) {
            %orig;
        } 
        else {
            [IFListsScrollViewForListView(self) addSubview:view];
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
    // if (self == IFConfigurationListClassObject) {
    //     if (IFFlagDefaultDimensions) {
    //         return %orig;
    //     } else {
    //         return IFConfigurationExpandedDimension * IFConfigurationExpandedDimension;
    //     }
    // } else {
        return %orig;
    // }
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

- (void)prepareToRotateToInterfaceOrientation:(NSInteger)orient {
    %orig;
    IFPreferencesApply();
}

/* }}} */

-(BOOL)allowsAddingIconCount:(NSUInteger)count {
    if (IFPreferencesBoolForKey(IFPreferencesScrollEnabled)) {
        return YES;
    }
    return %orig;
}

%end

/* Fixes {{{ */

static void IFSetSuperviewImp(IMP implem);

UIView *(*realSuperview)(id self, SEL _cmd);

UIView *fakeSuperview(id self, SEL _cmd) {
    UIView *view = (*realSuperview)(self, _cmd);
    if ([view isKindOfClass:[IFInfiniboardScrollView class]]) {
        IFSetSuperviewImp((IMP)*realSuperview);
        return IFListsListViewForScrollView((UIScrollView*)view);
    }
    return view;
}

static __weak SBIconView *recipientIcon;

static void IFSetSuperviewImp(IMP implem) {
    static dispatch_once_t lookupIconViewClassToken;
    static Class iconViewClass;

    dispatch_once(&lookupIconViewClassToken, ^{
        iconViewClass = %c(SBIconView);
        MSHookMessageEx(iconViewClass, @selector(superview), (IMP)&fakeSuperview, (IMP*)&realSuperview);
    });
    MSHookMessageEx(iconViewClass, @selector(superview), implem, NULL);
}

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
        IFSetSuperviewImp((IMP)&fakeSuperview);
        dropping = false;
    }
    return view;
}
%end

%hook SBIconDragContext
- (void)setDestinationFolderIconView:(id)destination forIconWithIdentifier:(id)arg2 {
    if (destination)
    {
        recipientIcon = destination;
    }
    %orig;
}
%end
%hook SBIconDragManager
- (void)iconListView:(SBIconListView*)listView concludeIconDrop:(id)drop {
    %orig;
    recipientIcon = nil;
    if (IFPreferencesBoolForKey(IFPreferencesScrollEnabled) && IFIconListIsValid(listView)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            IFIconListSizingUpdateIconList(listView);
        });
    }
    [self compactAndLayoutRootIconLists];
}

- (void)iconListView:(id)arg1 iconDropSessionDidEnd:(id)arg2 {
    %orig;
    [self compactAndLayoutRootIconLists];
}

%end

%hook UIDragPreviewTarget
- (id)initWithContainer:(UIView*)view center:(CGPoint)targetCenter transform:(CGAffineTransform)arg {
    if ([view isMemberOfClass:IFConfigurationListClassObject]) {
        UIScrollView *scrollView = IFListsScrollViewForListView((SBIconListView*)view);
        if (recipientIcon) {
            return %orig;
        }
        return %orig(scrollView, targetCenter, arg);
    }
    return %orig;
}
%end

%hook SBIconListViewDraggingDestinationDelegate

- (id)targetItemForSpringLoadingInteractionInView:(id)arg1 atLocation:(CGPoint)arg2 forDropSession:(id)arg3 {
    if ([arg1 isMemberOfClass:IFConfigurationListClassObject]) {
        if ([self respondsToSelector: @selector(updateSpringLoadedPolicyHandlerForDropSession:)]) {
            [self updateSpringLoadedPolicyHandlerForDropSession:arg3];
        }
        else if ([self respondsToSelector: @selector(updateCurrentPolicyHandlerForDropSession:)]) {
            [self updateCurrentPolicyHandlerForDropSession:arg3];
        }
        else {
            return %orig;
        }
        SBIcon *newIcon = [arg1 iconAtPoint:arg2 index:nil];
        SBIconView *newTarget = [[arg1 viewMap] mappedIconViewForIcon:newIcon];
        return newTarget;
    }
    return %orig;
}
%end

%hook SBRootIconListView
- (id)iconAtPoint:(struct CGPoint)arg1 index:(NSUInteger *)arg2 {
    if (IFIconListIsValid(self)) {
        NSUInteger row = [self rowAtPoint:arg1]+1;
        NSUInteger col = [self columnAtPoint:arg1]+1;
        NSUInteger numCols = [self iconColumnsForCurrentOrientation];
        NSUInteger index = ((row-1) * numCols) + col - 1;
        arg2 = &index;
        return [[self model] iconAtIndex: index];
    }
    return %orig;
}
%end
%hook SBIconController
- (void)_performInitialLayoutWithOrientation:(NSInteger)orient {
    %orig;
    IFPreferencesApply();
    IFDockHiding dockHide = (IFDockHiding)IFPreferencesIntForKey(IFPreferencesClipsDock);
    if (dockHide == kIFHideDock || dockHide == kIFHideDockPC) {
        IFSetDockHiding(YES);
    }
}

- (void)_lockScreenUIWillLock:(id)arg1 {
    %orig;
    if (hideSB == kIFPartialHideSB) {
        UIView *statusBar = IFStatusbarSharedInstance();
        statusBar.backgroundColor = nil;
    }
}
%end

%hook SBUIController
- (void)_willRevealOrHideContentView {
    %orig;
    IFRestoreIconLists();
}

%end

%hook SBRootFolderWithDock
- (id)indexPathForFirstFreeSlotAvoidingFirstList:(BOOL)avoid {
    id path = %orig(NO);
    // IFListsIterateViews(^(SBIconListView *listView, UIScrollView *scrollView) {
    //     IFIconListSizingUpdateIconList(listView);
    // });
    return path;
}
%end
%hook SBRootIconListView
%new
- (void)scrollViewDidScroll:(UIScrollView*)scrollView {
    if (hideSB == kIFPartialHideSB) {
        CGPoint offset = scrollView.contentOffset;
        static bool dimmed;
        static __weak UIView *statusBar;
        if (offset.y <= 50) {
            if (!statusBar) {
                statusBar = IFStatusbarSharedInstance();  
            }
            [statusBar setBackgroundColor: [UIColor colorWithWhite:0 alpha:0.6*fmin(offset.y/50, 1)]];
            dimmed = false;
        }
        else if (!dimmed) {
            if (!statusBar) {
                statusBar = IFStatusbarSharedInstance();  
            }
            [statusBar setBackgroundColor: [UIColor colorWithWhite:0 alpha:0.6]];
            dimmed = true;
        }
    }
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

- (void)setFrame:(CGRect)f {
    [super setFrame:CGRectMake(0,0,f.size.width, f.size.height)];
}
@end

/* }}} */

/* Constructor {{{ */

%ctor {
    IFListsInitialize();
    IFPreferencesInitialize(@"com.nwhit.springfinityprefs");
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)IFPreferencesApply, (CFStringRef)@"com.nwhit.springfinityprefs.preferences-changed", NULL, 0);
    dlopen("/Library/MobileSubstrate/DynamicLibraries/IconSupport.dylib", RTLD_LAZY);
    [[objc_getClass("ISIconSupport") sharedInstance] addExtension:@"springfinity"];
    %init(IFInfiniboard);
    %init(IFBasic);
}

/* }}} */