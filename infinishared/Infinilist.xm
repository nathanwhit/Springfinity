/* License {{{ */

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

/* includes {{{ */

#ifndef INFINILIST_XM
#define INFINILIST_XM

#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#include <QuartzCore/QuartzCore.h>
#include <CoreGraphics/CoreGraphics.h>

#include <dlfcn.h>
#include <objc/runtime.h>

#include <substrate.h>

#include "Preferences.h"
// #include "iPhonePrivate.h"

#include <deque>

/* }}} */

@interface SBDockView : UIView
+(CGFloat)defaultHeight;
+(CGFloat)defaultHeightPadding;
@end

/* Configuration Macros {{{ */

#ifndef LOG_MACROS
#define LOG_MACROS
#define log(str) os_log(OS_LOG_DEFAULT, str)
#define logf(fmt, ...) os_log(OS_LOG_DEFAULT, fmt, __VA_ARGS__)
#endif

#define IFMacroQuote_(x) #x
#define IFMacroQuote(x) IFMacroQuote_(x)

#define IFMacroConcat_(x, y) x ## y
#define IFMacroConcat(x, y) IFMacroConcat_(x, y)

#ifndef IFConfigurationTweakIdentifier
    #error "You must define a IFConfigurationTweakIdentifier."
#endif

#ifndef IFConfigurationListClass
    #define IFConfigurationListClass SBIconListView
#endif

#ifndef IFConfigurationListClassObject
    #define IFConfigurationListClassObject NSClassFromString(@IFMacroQuote(IFConfigurationListClass))
#endif

#ifndef IFConfigurationScrollViewClass
    #define IFConfigurationScrollViewClass UIScrollView
#endif

#ifndef IFConfigurationExpandWhenEditing
    #define IFConfigurationExpandWhenEditing YES
#endif

#ifndef IFConfigurationFullPages
    #define IFConfigurationFullPages NO
#endif

#ifndef IFConfigurationExpandHorizontally
    #define IFConfigurationExpandHorizontally NO
#endif

#ifndef IFConfigurationExpandVertically
    #define IFConfigurationExpandVertically YES
#endif

#ifndef IFConfigurationDynamicColumns
    #define IFConfigurationDynamicColumns NO
#endif

#ifndef IFConfigurationExpandedDimension
    // Must be less than sqrt(INT32_MAX).
    #define IFConfigurationExpandedDimension 10000
#endif

/* }}} */

/* Flags {{{ */

// Custom control structure for managing flags safely.
// Usage: IFFlag(IFFlagNamedThis) { /* code with flag enabled */ }
// Do not return out of this structure, or the flag is stuck.
#define IFFlag_(flag, c) \
    if (1) { \
        flag += 1; \
        goto IFMacroConcat(body, c); \
    } else \
        while (1) \
            if (1) { \
                flag -= 1; \
                break; \
            } else \
                IFMacroConcat(body, c):
#define IFFlag(flag) IFFlag_(flag, __COUNTER__)

/* }}} */

/* Preferences {{{ */

typedef enum {
    kIFScrollbarStyleBlack,
    kIFScrollbarStyleWhite,
    kIFScrollbarStyleNone
} IFScrollbarStyle;

typedef enum {
    kIFScrollBounceEnabled,
    kIFScrollBounceExtra,
    kIFScrollBounceDisabled
} IFScrollBounce;

typedef enum {
    kIFHideDock,
    kIFHideDockPC,
    kIFNoHideDock
} IFDockHiding;

typedef enum {
    kIFFullHideSB,
    kIFPartialHideSB,
    kIFNoHideSB
} IFSBHiding;

#ifndef IFPreferencesPagingEnabled
    #define IFPreferencesPagingEnabled @"PagingEnabled", NO
#endif

#ifndef IFPreferencesScrollEnabled
    #define IFPreferencesScrollEnabled @"ScrollEnabled", YES
#endif

#ifndef IFPreferencesScrollBounce
    #define IFPreferencesScrollBounce @"ScrollBounce", kIFScrollBounceEnabled
#endif

#ifndef IFPreferencesScrollbarStyle
    #define IFPreferencesScrollbarStyle @"ScrollbarStyle", kIFScrollbarStyleBlack
#endif

#ifndef IFPreferencesClipsStatusbar
    #define IFPreferencesClipsStatusbar @"ClipsStatusbar", kIFPartialHideSB
#endif

#ifndef IFPreferencesClipsDock
    #define IFPreferencesClipsDock @"ClipsDock", kIFHideDock
#endif

#define DefaultStatusbarHeight 20

#define DefaultPageControlHeight 37

#define IFInfiniboardIdentifier @"Infiniboard12"

// Utils

static NSUInteger IFFlagExpandedFrame = 0;
static NSUInteger IFFlagDefaultDimensions = 0;
static IFSBHiding hideSB = kIFPartialHideSB;
static NSString *IFTweakIdentifier = @IFMacroQuote(IFConfigurationTweakIdentifier);

static void printSubviews(UIView *v, Class lowestClass = Nil, Class excludedClass = Nil) {
    std::deque<UIView*> viewQueue;
    std::deque<long> levelSizeQueue;
    viewQueue.push_back(v);
    long n = 1;
    log("PARENT");
    while (!viewQueue.empty()) {
        UIView *vw = viewQueue.front();
        viewQueue.pop_front();
        if (n <= 0) {
            log("-----------------------");
            n = levelSizeQueue.front();
            levelSizeQueue.pop_front();
            logf("SUBVIEWS OF : %{public}@", vw.superview);
            log("---");
        }
        n--;

        logf("View : %{public}@", vw);
        if ([vw isKindOfClass:lowestClass]) {
            continue;
        }
        long numSubs = 0;
        for (UIView *sv in vw.subviews) {
            if (![sv isKindOfClass:excludedClass]) {
                viewQueue.push_back(sv);
                numSubs++;
            }
        }
        if (numSubs > 0) {
            levelSizeQueue.push_back([vw.subviews count]);
        }

    }
}

static void printViewHierarchy(UIView *v, Class lowestClass = Nil, Class excludedClass = Nil) {
    UIView *vw = v;
    while (vw.superview) {
        vw = vw.superview;
    }
    printSubviews(vw, lowestClass, excludedClass);
}

/* }}} */

/* Conveniences {{{ */

__attribute__((unused)) static NSUInteger IFMinimum(NSUInteger x, NSUInteger y) {
    return (x < y ? x : y);
}

__attribute__((unused)) static NSUInteger IFMaximum(NSUInteger x, NSUInteger y) {
    return (x > y ? x : y);
}

__attribute__((unused)) static SBIconController *IFIconControllerSharedInstance() {
    return (SBIconController *) [NSClassFromString(@"SBIconController") sharedInstance];
}

__attribute__((unused)) static SBIconView *IFIconViewForIcon(SBIcon *icon) {
    SBIconController *iconController = IFIconControllerSharedInstance();
    if ([iconController respondsToSelector:@selector(homescreenIconViewMap)]) {
        SBIconViewMap *iconViewMap = [iconController homescreenIconViewMap];
        return [iconViewMap iconViewForIcon:icon];
    } else {
        SBIconViewMap *iconViewMap = [NSClassFromString(@"SBIconViewMap") homescreenMap];
        return [iconViewMap iconViewForIcon:icon];
    }
}

__attribute__((unused)) static BOOL IFIconListIsValid(SBIconListView *listView) {
    return [listView isMemberOfClass:IFConfigurationListClassObject];
}

__attribute__((unused)) static BOOL IFDockIconListIsValid(SBIconListView *listView) {
    return [listView isKindOfClass:IFConfigurationListClassObject];
}

/* }}} */

/* List Management {{{ */

static NSMutableArray *IFListsListViews = nil;
static NSMutableArray *IFListsScrollViews = nil;

// Forward declaration
static void IFIconListSizingUpdateIconList(SBIconListView *listView);


__attribute__((constructor)) static void IFListsInitialize() {
    // Non-retaining mutable arrays, since we don't want to own these objects.
    // IFListsListViews = [[NSMutableArray alloc] init];
    // IFListsScrollViews =[[NSMutableArray alloc] init];
    CFArrayCallBacks callbacks = { 0, NULL, NULL, CFCopyDescription, CFEqual };
    IFListsListViews = (__bridge NSMutableArray*)CFArrayCreateMutable(NULL, 0, &callbacks);
    IFListsScrollViews = (__bridge NSMutableArray*)CFArrayCreateMutable(NULL, 0, &callbacks);
}

__attribute__((unused)) static void IFListsIterateViews(void (^block)(SBIconListView *, UIScrollView *)) {
    for (NSUInteger i = 0; i < fmin([IFListsListViews count], [IFListsScrollViews count]); i++) {
        block([IFListsListViews objectAtIndex:i], [IFListsScrollViews objectAtIndex:i]);
    }
}

__attribute__((unused)) static SBIconListView *IFListsListViewForScrollView(UIScrollView *scrollView) {
    NSInteger index = [IFListsScrollViews indexOfObject:scrollView];

    if (index == NSNotFound) {
        return nil;
    }

    return [IFListsListViews objectAtIndex:index];
}

__attribute__((unused)) static UIScrollView *IFListsScrollViewForListView(SBIconListView *listView) {
    NSInteger index = [IFListsListViews indexOfObject:listView];

    if (index == NSNotFound) {
        return nil;
    }

    return [IFListsScrollViews objectAtIndex:index];
}

__attribute__((unused)) static void IFListsRegister(SBIconListView *listView, UIScrollView *scrollView) {
    [IFListsListViews addObject:listView];
    [IFListsScrollViews addObject:scrollView];
}

__attribute__((unused)) static void IFListsUnregister(SBIconListView *listView, UIScrollView *scrollView) {
    [IFListsListViews removeObject:listView];
    [IFListsScrollViews removeObject:scrollView];
}
__attribute__((unused)) static UIInterfaceOrientation IFIconListOrientation(SBIconListView *listView) {
    UIInterfaceOrientation orientation = MSHookIvar<UIInterfaceOrientation>(listView, "_orientation");
    return orientation;
}

__attribute__((unused)) static CGSize IFIconDefaultSize() {
    CGSize size = [NSClassFromString(@"SBIconView") defaultIconSize];
    return size;
}

__attribute__((unused)) static SBRootFolder *IFRootFolderSharedInstance() {
    SBIconController *iconController = IFIconControllerSharedInstance();
    SBRootFolder *rootFolder = [iconController rootFolder];
    return rootFolder;
}

__attribute__((unused)) static UIView *IFStatusbarSharedInstance() {
    static __weak UIView *statusBar;
    if (!statusBar) {
        statusBar = [[UIScreen mainScreen] _accessibilityStatusBar];
    }
    return statusBar;
}

__attribute__((unused)) static SpringBoard *IFSpringBoardSharedInstance() {
    static __weak SpringBoard *springboard;
    if (!springboard) {
        UIApplication *app = [UIApplication sharedApplication];
        if ([app isMemberOfClass: NSClassFromString(@"SpringBoard")]) {
            springboard = (SpringBoard*)app;
        }
    }
    return springboard;
}

__attribute__((unused)) static NSUInteger IFIconListLastIconIndex(SBIconListView *listView) {
    NSArray *icons = [listView icons];
    SBIcon *lastIcon = nil;

    for (SBIcon *icon in [icons reverseObjectEnumerator]) {
        if ([icon respondsToSelector:@selector(isPlaceholder)] && ![icon isPlaceholder]) {
            lastIcon = icon;
            break;
        } else if ([icon respondsToSelector:@selector(isNullIcon)] && ![icon isNullIcon]) {
            lastIcon = icon;
            break;
        } else if ([icon respondsToSelector:@selector(isDestinationHole)] && ![icon isDestinationHole]) {
            lastIcon = icon;
            break;
        }
    }

    SBIconListModel *model = [listView model];
    return [model indexForIcon:lastIcon];
}

__attribute__((unused)) static SBIconListView *IFIconListContainingIcon(SBIcon *icon) {
    SBIconController *iconController = IFIconControllerSharedInstance();
    SBRootFolder *rootFolder = IFRootFolderSharedInstance();
    NSArray* listModels = [[rootFolder listsContainingIcon:icon] allObjects];
    SBIconListModel *listModel;
    if ([listModels count] > 0) {
        listModel = listModels[0];
    }
    if ([listModel isKindOfClass:NSClassFromString(@"SBDockIconListModel")]) {
        if ([iconController respondsToSelector:@selector(dockListView)]) {
            return [iconController dockListView];
        } else {
            return [iconController dock];
        }
    } else {
        NSUInteger index = [rootFolder indexOfList:listModel];
        return [iconController rootIconListAtIndex:index];
    }
}

static void IFSetDockHiding(BOOL hide);

void (*originalDockZOrdering)(id self, SEL _cmd);

void alteredDockZOrdering(id self, SEL _cmd) {
    SBDockView *dock = [self dockView];
    [dock.superview bringSubviewToFront:dock];
}

static void IFSetDockHiding(BOOL hide) {
    static Class rootFolderViewClass;
    static __weak SBFolderView *folder; 
    static dispatch_once_t dockHidingSetupToken;
    dispatch_once(&dockHidingSetupToken, ^{
        rootFolderViewClass = NSClassFromString(@"SBRootFolderView");
        MSHookMessageEx(rootFolderViewClass, @selector(_updateDockViewZOrdering), (IMP)&alteredDockZOrdering, (IMP*)&originalDockZOrdering);
    });
    
    if (!folder) {
        folder = [[[IFIconControllerSharedInstance() contentView] childFolderContainerView] folderView];
    }
    if (hide) {
        MSHookMessageEx(rootFolderViewClass, @selector(_updateDockViewZOrdering), (IMP)&alteredDockZOrdering, NULL);
    }
    else {
        MSHookMessageEx(rootFolderViewClass, @selector(_updateDockViewZOrdering), (IMP)*originalDockZOrdering, NULL);
    }
    if ([folder isKindOfClass:rootFolderViewClass] && [folder respondsToSelector:@selector(_updateDockViewZOrdering)]) {
        [(SBRootFolderView*)folder _updateDockViewZOrdering];
    }
}

static void IFPreferencesApplyToInfiniboard(SBIconListView *listView, UIScrollView *scrollView) {
    IFSBHiding clipsStatusbar = (IFSBHiding)IFPreferencesIntForKey(IFPreferencesClipsStatusbar);
    IFDockHiding hidesDock = (IFDockHiding)IFPreferencesIntForKey(IFPreferencesClipsDock);
    [scrollView setClipsToBounds:NO];
    [listView setClipsToBounds:NO];

    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    CGFloat dockMaskHeight = 0;
    CGFloat dockMaskPadding = 0;
    CGFloat maskYOffset = DefaultStatusbarHeight+3;
    CGFloat adjustmentAmount = 0;
    CGFloat bottomScrollInset = 0;
    if (clipsStatusbar == kIFFullHideSB) {
        maskYOffset = (DefaultStatusbarHeight/5)-1;
        // bottomScrollInset = -5.5;
    }

    if (hidesDock == kIFHideDock || hidesDock == kIFHideDockPC) {
        IFSetDockHiding(YES);
        Class dockClass = NSClassFromString(@"SBDockView");
        if (hidesDock == kIFHideDockPC) {
            SBFolderView *folder = [[[IFIconControllerSharedInstance() contentView] childFolderContainerView] folderView];
            SpringBoard *springboard = IFSpringBoardSharedInstance();
            if ([springboard homeScreenRotationStyle] != 2 && [springboard activeInterfaceOrientation] < 2) {
                dockMaskHeight = [dockClass defaultHeight];
                dockMaskPadding = [dockClass defaultHeightPadding];
                if ([folder isKindOfClass:NSClassFromString(@"SBRootFolderView")] && [folder respondsToSelector: @selector(effectivePageControlFrame)]) {
                    CGRect pageControlFrame = [(SBRootFolderView*)folder effectivePageControlFrame];
                    adjustmentAmount = -pageControlFrame.size.height*0.6;
                    // bottomScrollInset *= 1.1;
                }
                else {
                    adjustmentAmount = -DefaultPageControlHeight*0.6;
                    // bottomScrollInset *= 1.1;
                }
            }
        }
    }
    else {
        IFSetDockHiding(NO);
    }


    CALayer *maskLayer = [CALayer layer];
    maskLayer.frame = CGRectMake(0, -maskYOffset, screenSize.width, screenSize.height + maskYOffset - (dockMaskHeight + 4*dockMaskPadding) + adjustmentAmount);
    maskLayer.backgroundColor = [UIColor blackColor].CGColor;
    // [scrollView layer].mask = maskLayer;
    [listView layer].mask = maskLayer;
}

static void IFPreferencesApplyToList(SBIconListView *listView) {
    UIScrollView *scrollView = IFListsScrollViewForListView(listView);

    BOOL scroll = IFPreferencesBoolForKey(IFPreferencesScrollEnabled);
    IFScrollBounce bounce = (IFScrollBounce) IFPreferencesIntForKey(IFPreferencesScrollBounce);
    IFScrollbarStyle bar = (IFScrollbarStyle) IFPreferencesIntForKey(IFPreferencesScrollbarStyle);
    BOOL page = IFPreferencesBoolForKey(IFPreferencesPagingEnabled);
    [scrollView setShowsVerticalScrollIndicator:YES];
    [scrollView setShowsHorizontalScrollIndicator:YES];
    if (bar == kIFScrollbarStyleBlack) {
        [scrollView setIndicatorStyle:UIScrollViewIndicatorStyleBlack];
    } else if (bar == kIFScrollbarStyleWhite) {
        [scrollView setIndicatorStyle:UIScrollViewIndicatorStyleWhite];
    } else if (bar == kIFScrollbarStyleNone) {
        [scrollView setShowsVerticalScrollIndicator:NO];
        [scrollView setShowsHorizontalScrollIndicator:NO];
    }

    [scrollView setAlwaysBounceVertical:IFConfigurationExpandVertically && (bounce == kIFScrollBounceEnabled)];
    [scrollView setAlwaysBounceHorizontal:IFConfigurationExpandHorizontally && (bounce == kIFScrollBounceEnabled)];
    [scrollView setBounces:(bounce != kIFScrollBounceDisabled)];

    [scrollView setScrollEnabled:scroll];
    [scrollView setPagingEnabled:page];

    if (![listView isKindOfClass:NSClassFromString(@"SBDockIconListView")]) {
        IFPreferencesApplyToInfiniboard(listView, scrollView);
    }

    if (bounce == kIFScrollBounceExtra) {
        NSUInteger idx = 0;
        NSUInteger max = 0;

        IFFlag(IFFlagDefaultDimensions) {
            idx = IFIconListLastIconIndex(listView);
            max = [listView iconRowsForCurrentOrientation] * [listView iconColumnsForCurrentOrientation];
        }

        [scrollView setAlwaysBounceVertical:IFConfigurationExpandVertically && (idx > max)];
        [scrollView setAlwaysBounceHorizontal:IFConfigurationExpandHorizontally && (idx > max)];
    }
}

static void IFPreferencesApply() {
    IFPreferencesLoad();
    IFListsIterateViews(^(SBIconListView *listView, UIScrollView *scrollView) {
        IFPreferencesApplyToList(listView);
        IFIconListSizingUpdateIconList(listView);
    });
    if ([IFTweakIdentifier isEqualToString: IFInfiniboardIdentifier]) {
        hideSB = (IFSBHiding)IFPreferencesIntForKey(IFPreferencesClipsStatusbar);
        if (hideSB != kIFPartialHideSB) {
            static dispatch_once_t statusBarFind;
            static UIView *statusBar;
            dispatch_once(&statusBarFind, ^{
                statusBar = [[UIScreen mainScreen] _accessibilityStatusBar];
            });
            statusBar.backgroundColor = nil;
        }
    }
}

/* }}} */

/* List Sizing {{{ */

typedef struct {
    NSUInteger rows;
    NSUInteger columns;
} IFIconListDimensions;

static IFIconListDimensions IFIconListDimensionsZero = { 0, 0 };

/* Defaults {{{ */

static IFIconListDimensions _IFSizingDefaultDimensionsForOrientation(UIInterfaceOrientation orientation) {
    IFIconListDimensions dimensions = IFIconListDimensionsZero;

    IFFlag(IFFlagDefaultDimensions) {
        dimensions.rows = [IFConfigurationListClassObject iconRowsForInterfaceOrientation:orientation];
        dimensions.columns = [IFConfigurationListClassObject iconColumnsForInterfaceOrientation:orientation];
    }

    return dimensions;
}

static IFIconListDimensions _IFSizingDefaultDimensions(SBIconListView *listView) {
    return _IFSizingDefaultDimensionsForOrientation(IFIconListOrientation(listView));
}

static CGSize _IFSizingDefaultPadding(SBIconListView *listView) {
    CGSize padding = CGSizeZero;

    IFFlag(IFFlagDefaultDimensions) {
        padding.width = [listView horizontalIconPadding];
        padding.height = [listView verticalIconPadding];
    }

    return padding;
}

static UIEdgeInsets _IFSizingDefaultInsets(SBIconListView *listView) {
    UIEdgeInsets insets = UIEdgeInsetsZero;

    IFFlag(IFFlagDefaultDimensions) {
        insets.top = [listView topIconInset];
        insets.bottom = [listView bottomIconInset];
        insets.left = [listView sideIconInset];
        insets.right = [listView sideIconInset];
    }

    return insets;
}

/* }}} */

/* Dimensions {{{ */

static IFIconListDimensions IFSizingMaximumDimensionsForOrientation(UIInterfaceOrientation orientation) {
    IFIconListDimensions dimensions = _IFSizingDefaultDimensionsForOrientation(orientation);

    if (IFConfigurationExpandVertically) {
        dimensions.rows = IFConfigurationExpandedDimension;
    }

    if (IFConfigurationExpandHorizontally) {
        dimensions.columns = IFConfigurationExpandedDimension;
    }

    return dimensions;
}

static IFIconListDimensions IFSizingContentDimensions(SBIconListView *listView) {
    IFIconListDimensions dimensions = IFIconListDimensionsZero;
    UIInterfaceOrientation orientation = IFIconListOrientation(listView);

    if ([[listView icons] count] > 0) {
        NSUInteger idx = IFIconListLastIconIndex(listView);

        if (IFConfigurationExpandWhenEditing && [IFIconControllerSharedInstance() isEditing]) {
            // Add room to drop the icon into.
            idx += 1;
        }

        IFIconListDimensions maximumDimensions = IFSizingMaximumDimensionsForOrientation(orientation);
        dimensions.columns = (idx % maximumDimensions.columns);
        dimensions.rows = (idx / maximumDimensions.columns);

        // Convert from index to sizing information.
        dimensions.rows += 1;
        dimensions.columns += 1;

        if (!IFConfigurationDynamicColumns) {
            // If we have more than one row, we necessarily have the
            // maximum number of columns at some point above the bottom.
            dimensions.columns = maximumDimensions.columns;
        }
    } else {
        dimensions = _IFSizingDefaultDimensionsForOrientation(orientation);
    }

    IFIconListDimensions defaultDimensions = _IFSizingDefaultDimensions(listView);

    if (IFPreferencesBoolForKey(IFPreferencesPagingEnabled)) {
        // This is ugly, but we need to round up here.
        dimensions.rows = ((dimensions.rows / defaultDimensions.rows) + ((dimensions.rows % defaultDimensions.rows) ? 1 : 0)) * defaultDimensions.rows;
        dimensions.columns = ((dimensions.columns / defaultDimensions.columns) + ((dimensions.columns % defaultDimensions.columns) ? 1 : 0)) * defaultDimensions.columns;
    }

    // Make sure we have at least the default number of icons.
    dimensions.rows = (dimensions.rows > defaultDimensions.rows) ? dimensions.rows : defaultDimensions.rows;
    dimensions.columns = (dimensions.columns > defaultDimensions.columns) ? dimensions.columns : defaultDimensions.columns;

    return dimensions;
}

/* }}} */

/* Information {{{ */

// Prevent conflicts between multiple users of Infinilist.
#define IFIconListSizingInformation IFMacroConcat(IFIconListSizingInformation, IFConfigurationTweakIdentifier)

@interface IFIconListSizingInformation : NSObject {
    IFIconListDimensions defaultDimensions;
    CGSize defaultPadding;
    UIEdgeInsets defaultInsets;
    IFIconListDimensions contentDimensions;
}

@property (nonatomic, assign) IFIconListDimensions defaultDimensions;
@property (nonatomic, assign) CGSize defaultPadding;
@property (nonatomic, assign) UIEdgeInsets defaultInsets;
@property (nonatomic, assign) IFIconListDimensions contentDimensions;

@end

@implementation IFIconListSizingInformation

@synthesize defaultDimensions;
@synthesize defaultPadding;
@synthesize defaultInsets;
@synthesize contentDimensions;

- (NSString *)description {
    return [NSString stringWithFormat:@"<IFIconListSizingInformation:%p defaultDimensions = {%ld, %ld} defaultPadding = %@ defaultInsets = %@ contentDimensions = {%ld, %ld}>", self, (unsigned long)defaultDimensions.rows, (unsigned long)defaultDimensions.columns, NSStringFromCGSize(defaultPadding), NSStringFromUIEdgeInsets(defaultInsets), (unsigned long)contentDimensions.rows, (unsigned long)contentDimensions.columns];
}

@end

static NSMutableDictionary *IFIconListSizingStore = nil;

__attribute__((constructor)) static void IFIconListSizingInitialize() {
    IFIconListSizingStore = [[NSMutableDictionary alloc] init];
}

static IFIconListSizingInformation *IFIconListSizingInformationForIconList(SBIconListView *listView) {
    IFIconListSizingInformation *information = [IFIconListSizingStore objectForKey:[NSValue valueWithNonretainedObject:listView]];
    return information;
}

static IFIconListDimensions IFSizingDefaultDimensionsForIconList(SBIconListView *listView) {
    return [IFIconListSizingInformationForIconList(listView) defaultDimensions];
}

static void IFIconListSizingSetInformationForIconList(IFIconListSizingInformation *information, SBIconListView *listView) {
    [IFIconListSizingStore setObject:information forKey:[NSValue valueWithNonretainedObject:listView]];
}

static void IFIconListSizingRemoveInformationForIconList(SBIconListView *listView) {
    [IFIconListSizingStore removeObjectForKey:[NSValue valueWithNonretainedObject:listView]];
}

static IFIconListSizingInformation *IFIconListSizingComputeInformationForIconList(SBIconListView *listView) {
    IFIconListSizingInformation *info = [[IFIconListSizingInformation alloc] init];
    [info setDefaultDimensions:_IFSizingDefaultDimensions(listView)];
    [info setDefaultPadding:_IFSizingDefaultPadding(listView)];
    [info setDefaultInsets:_IFSizingDefaultInsets(listView)];
    [info setContentDimensions:IFSizingContentDimensions(listView)];
    return info;
}

/* }}} */

/* Content Size {{{ */

static CGSize IFIconListSizingEffectiveContentSize(SBIconListView *listView) {
    IFIconListSizingInformation *info = IFIconListSizingInformationForIconList(listView);

    IFIconListDimensions effectiveDimensions = [info contentDimensions];
    CGSize contentSize = CGSizeZero;
    CGSize padding = [info defaultPadding];
    UIEdgeInsets insets = [info defaultInsets];

    if (IFPreferencesBoolForKey(IFPreferencesPagingEnabled)) {
        IFIconListDimensions defaultDimensions = [info defaultDimensions];
        CGSize size = [listView frame].size;
        CGFloat pageAdjustmentHeight = fabs(padding.height - insets.top - insets.bottom);

        IFIconListDimensions result = IFIconListDimensionsZero;
        result.columns = (effectiveDimensions.columns / defaultDimensions.columns);
        result.rows = (effectiveDimensions.rows / defaultDimensions.rows);
        contentSize = CGSizeMake(size.width * result.columns, (size.height-pageAdjustmentHeight) * result.rows);
    } 
    else {
        CGSize iconSize = IFIconDefaultSize();

        contentSize.width = insets.left + effectiveDimensions.columns * (iconSize.width + padding.width) - padding.width + insets.right;
        contentSize.height = insets.top + (effectiveDimensions.rows * (iconSize.height + padding.height)) - padding.height + insets.bottom;
    }

    return contentSize;
}

static void IFIconListSizingUpdateContentSize(SBIconListView *listView, UIScrollView *scrollView) {
    CGPoint offset = [scrollView contentOffset];
    CGSize scrollSize = [scrollView bounds].size;
    CGSize oldSize = [scrollView contentSize];
    CGSize newSize = IFIconListSizingEffectiveContentSize(listView);


    if (IFConfigurationExpandHorizontally) {
        // Be sure not to have two-dimensional scrolling.
        if (newSize.height > scrollSize.height) {
            newSize.height = scrollSize.height;
        }

        // Make sure the content offset is never outside the scroll view.
        if (offset.x + scrollSize.width > newSize.width) {
            // But not if the scroll view is only a few columns.
            if (newSize.width >= scrollSize.width) {
                offset.x = newSize.width - scrollSize.width;
            }
        }
    } else if (IFConfigurationExpandVertically) {
        // Be sure not to have two-dimensional scrolling.
        if (newSize.width > scrollSize.width) {
            newSize.width = scrollSize.width;
        }

        // // Make sure the content offset is never outside the scroll view.
        // if (offset.y + scrollSize.height > newSize.height) {
        //     // But not if the scroll view is only a few rows.
        //     if (newSize.height >= scrollSize.height) {
        //         offset.y = newSize.height - scrollSize.height;
        //     }
        // }
    }

    if (!CGSizeEqualToSize(oldSize, newSize)) {
        [UIView animateWithDuration:0.3f animations:^{
            [scrollView setContentSize:newSize];
            [scrollView setContentOffset:offset animated:NO];
        }];
    }
}

/* }}} */

static void IFIconListSizingUpdateIconList(SBIconListView *listView) {
    UIScrollView *scrollView = IFListsScrollViewForListView(listView);

    IFIconListSizingSetInformationForIconList(IFIconListSizingComputeInformationForIconList(listView), listView);
    IFIconListSizingUpdateContentSize(listView, scrollView);
}

/* }}} */

/* Fixes and Restore Implementation {{{ */


#ifdef IFPreferencesRestoreEnabled
static void IFRestoreIconLists(void) {

    IFListsIterateViews(^(SBIconListView *listView, UIScrollView *scrollView) {
        if (IFPreferencesBoolForKey(IFPreferencesRestoreEnabled)) {
            [scrollView setContentOffset:CGPointZero animated:NO];
        }

        if (IFPreferencesIntForKey(IFPreferencesScrollbarStyle) != kIFScrollbarStyleNone) {
            [scrollView flashScrollIndicators];
        }
    });
}
#endif

#ifdef IFPreferencesFastRestoreEnabled
static void IFFastRestoreIconLists(void) {
    if (IFPreferencesBoolForKey(IFPreferencesFastRestoreEnabled)) {
        IFListsIterateViews(^(SBIconListView *listView, UIScrollView *scrollView) {
            [scrollView setContentOffset:CGPointZero animated:NO];
        });
    }
}
#endif

static NSUInteger IFFlagFolderOpening = 0;

#endif