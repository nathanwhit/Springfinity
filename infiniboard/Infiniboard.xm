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

/* Configuration {{{ */

#include <os/log.h>
#define log(str) os_log(OS_LOG_DEFAULT, str)
#define logf(fmt, str) os_log(OS_LOG_DEFAULT, fmt, str)

#define IFConfigurationTweakIdentifier Infiniboard
#define IFConfigurationListClass SBIconListView
#define IFConfigurationListClassObject (NSClassFromString(@"SBRootIconListView") ?: NSClassFromString(@"SBIconListView"))
#define IFConfigurationScrollViewClass IFInfiniboardScrollView
#define IFConfigurationFullPages (dlopen("/Library/MobileSubstrate/DynamicLibraries/Iconoclasm.dylib", RTLD_LAZY) != NULL)

#define IFPreferencesRestoreEnabled @"RestoreEnabled", NO
#define IFPreferencesFastRestoreEnabled @"FastRestoreEnabled", NO

#include <UIKit/UIKit.h>
#include "infinishared/Infinilist.xm"
#include "infinishared/Preferences.h"
#include <substrate.h>

@interface IFInfiniboardScrollView : UIScrollView
@end

/* }}} */

// Utils
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
    SBRootFolder *rootFolder = MSHookIvar<SBRootFolder *>(iconController, "_rootFolder");
    return rootFolder;
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

    SBIconListModel *listModel = [rootFolder listContainingIcon:icon];

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

static void IFPreferencesApplyToList(SBIconListView *listView) {
    UIScrollView *scrollView = IFListsScrollViewForListView(listView);

    BOOL scroll = IFPreferencesBoolForKey(IFPreferencesScrollEnabled);
    IFScrollBounce bounce = (IFScrollBounce) IFPreferencesIntForKey(IFPreferencesScrollBounce);
    IFScrollbarStyle bar = (IFScrollbarStyle) IFPreferencesIntForKey(IFPreferencesScrollbarStyle);
    BOOL page = IFPreferencesBoolForKey(IFPreferencesPagingEnabled);
    BOOL clips = IFPreferencesBoolForKey(IFPreferencesClipsToBounds);

    [scrollView setShowsVerticalScrollIndicator:YES];
    [scrollView setShowsHorizontalScrollIndicator:YES];
    if (bar == kIFScrollbarStyleBlack) {
        [scrollView setIndicatorStyle:UIScrollViewIndicatorStyleDefault];
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
    [scrollView setClipsToBounds:clips];
    [listView setClipsToBounds:clips];

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
    IFListsIterateViews(^(SBIconListView *listView, UIScrollView *scrollView) {
        IFPreferencesApplyToList(listView);
    });
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

    if (IFConfigurationFullPages || IFPreferencesBoolForKey(IFPreferencesPagingEnabled)) {
        // This is ugly, but we need to round up here.
        dimensions.rows = ceilf((float) dimensions.rows / (float) defaultDimensions.rows) * defaultDimensions.rows;
        dimensions.columns = ceilf((float) dimensions.columns / (float) defaultDimensions.columns) * defaultDimensions.columns;
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
    return [info autorelease];
}

/* }}} */

/* Content Size {{{ */

static CGSize IFIconListSizingEffectiveContentSize(SBIconListView *listView) {
    IFIconListSizingInformation *info = IFIconListSizingInformationForIconList(listView);

    IFIconListDimensions effectiveDimensions = [info contentDimensions];
    CGSize contentSize = CGSizeZero;

    if (IFConfigurationFullPages || IFPreferencesBoolForKey(IFPreferencesPagingEnabled)) {
        IFIconListDimensions defaultDimensions = [info defaultDimensions];
        CGSize size = [listView frame].size;

        IFIconListDimensions result = IFIconListDimensionsZero;
        result.columns = (effectiveDimensions.columns / defaultDimensions.columns);
        result.rows = (effectiveDimensions.rows / defaultDimensions.rows);

        contentSize = CGSizeMake(size.width * result.columns, size.height * result.rows);
    } else {
        CGSize padding = [info defaultPadding];
        UIEdgeInsets insets = [info defaultInsets];
        CGSize iconSize = IFIconDefaultSize();

        contentSize.width = insets.left + effectiveDimensions.columns * (iconSize.width + padding.width) - padding.width + insets.right;
        contentSize.height = insets.top + effectiveDimensions.rows * (iconSize.height + padding.height) - padding.height + insets.bottom;
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

        // Make sure the content offset is never outside the scroll view.
        if (offset.y + scrollSize.height > newSize.height) {
            // But not if the scroll view is only a few rows.
            if (newSize.height >= scrollSize.height) {
                offset.y = newSize.height - scrollSize.height;
            }
        }
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

%group IFInfiniboard

static void IFRestoreIconLists(void) {
    IFPreferencesApply();

    IFListsIterateViews(^(SBIconListView *listView, UIScrollView *scrollView) {
        if (IFPreferencesBoolForKey(IFPreferencesRestoreEnabled)) {
            [scrollView setContentOffset:CGPointZero animated:NO];
        }

        if (IFPreferencesIntForKey(IFPreferencesScrollbarStyle) != kIFScrollbarStyleNone) {
            [scrollView flashScrollIndicators];
        }
    });
}

static void IFFastRestoreIconLists(void) {
    if (IFPreferencesBoolForKey(IFPreferencesFastRestoreEnabled)) {
        IFListsIterateViews(^(SBIconListView *listView, UIScrollView *scrollView) {
            [scrollView setContentOffset:CGPointZero animated:NO];
        });
    }
}

static NSUInteger IFFlagFolderOpening = 0;

%hook IFConfigurationListClass

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

- (void)setOpenFolder:(SBFolder *)folder {
    log("here");
    %orig;

    if (folder != nil) {
        SBIcon *folderIcon = [[self openFolder] icon];

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

- (CGRect)_contentViewRelativeFrameForIcon:(SBIcon *)icon {
    SBIconListView *listView = IFIconListContainingIcon(icon);
    UIScrollView *scrollView = IFListsScrollViewForListView(listView);

    if (IFIconListIsValid(listView) && IFFlagFolderOpening && IFPreferencesBoolForKey(IFPreferencesClipsToBounds)) {
        SBIconView *iconView = IFIconViewForIcon(icon);
        CGRect iconRect = [iconView frame];

        CGRect scrollVisibleFrame = [scrollView frame];
        scrollVisibleFrame.origin = [scrollView contentOffset];

        if (CGRectIntersectsRect(iconRect, scrollVisibleFrame)) {
            return %orig;
        } else {
            CGRect frame = %orig;
            return CGRectMake(-1000, -1000, frame.size.width, frame.size.height);
        }
    } else {
        return %orig;
    }
}

- (void)openFolder:(SBFolder *)folder animated:(BOOL)animated fromSwitcher:(BOOL)fromSwitcher {
    log("HERE");
    // Let -iconAtPoint: know that it can slide SpringBoard "upwards" if necessary.
    IFFlag(IFFlagFolderOpening) {
        IFFlag(IFFlagDefaultDimensions) {
            %orig;
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

%group IFBasic

%hook IFConfigurationListClass

/* View Hierarchy {{{ */

static void IFIconListInitialize(SBIconListView *listView) {
    UIScrollView *scrollView = [[IFConfigurationScrollViewClass alloc] initWithFrame:[listView frame]];
    [scrollView setDelegate:(id<UIScrollViewDelegate>) listView];
    [scrollView setDelaysContentTouches:NO];

    IFListsRegister(listView, scrollView);
    [listView addSubview:scrollView];

    IFIconListSizingUpdateIconList(listView);
    IFPreferencesApplyToList(listView);
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = %orig)) {
        // Avoid hooking a sub-initializer when we hook the base initializer, but otherwise do hook it.
        if (IFIconListIsValid(self) && ![self respondsToSelector:@selector(initWithFrame:viewMap:)]) {
            IFIconListInitialize(self);
        }
    }

    return self;
}

- (id)initWithFrame:(CGRect)frame viewMap:(id)viewMap {
    if ((self = %orig)) {
        if (IFIconListIsValid(self)) {
            IFIconListInitialize(self);
        }
    }

    return self;
}

- (void)dealloc {
    if (IFIconListIsValid(self)) {
        UIScrollView *scrollView = IFListsScrollViewForListView(self);

        IFListsUnregister(self, scrollView);
        IFIconListSizingRemoveInformationForIconList(self);

        [scrollView release];
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
            [scrollView setContentOffset:offset animated:NO];
        }
    } else {
        %orig;
    }
}

- (void)addSubview:(UIView *)view {
    if (IFIconListIsValid(self)) {
        UIScrollView *scrollView = IFListsScrollViewForListView(self);

        if (view == scrollView) {
            %orig;
        } else {
            [scrollView addSubview:view];

            IFIconListSizingUpdateIconList(self);
        }
    } else {
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

- (CGRect)bounds {
    if (IFIconListIsValid(self)) {
        // This check breaks icon positions on iOS 7.0+, but is needed on iOS 5.x and 6.x.
        if (kCFCoreFoundationVersionNumber < 800.0 && IFFlagExpandedFrame) {
            CGRect bounds = %orig;
            bounds.size = IFIconListSizingEffectiveContentSize(self);
            return bounds;
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}

/* }}} */

/* Positioning {{{ */

static CGPoint IFIconListOriginForIconAtXY(SBIconListView *self, NSUInteger x, NSUInteger y, CGPoint (^orig)(NSUInteger, NSUInteger)) {
    CGPoint origin = CGPointZero;

    IFFlag(IFFlagExpandedFrame) {
        UIScrollView *scrollView = IFListsScrollViewForListView(self);

        if (IFPreferencesBoolForKey(IFPreferencesPagingEnabled)) {
            IFIconListDimensions dimensions = IFSizingDefaultDimensionsForIconList(self);

            NSUInteger px = (x / dimensions.columns), py = (y / dimensions.rows);
            NSUInteger ix = (x % dimensions.columns), iy = (y % dimensions.rows);

            origin = orig(ix, iy);

            CGSize size = [scrollView frame].size;
            origin.x += (size.width) * px;
            origin.y += (size.height) * py;
        } else {
            origin = orig(x, y);
        }
    }

    return origin;
}

- (CGPoint)originForIconAtCoordinate:(SBIconCoordinate)coordinate {
    if (IFIconListIsValid(self)) {
        return IFIconListOriginForIconAtXY(self, coordinate.col - 1, coordinate.row - 1, ^(NSUInteger x, NSUInteger y) {
            SBIconCoordinate innerCoordinate = { .row = y + 1, .col = x + 1 };
            return %orig(innerCoordinate);
        });
    } else {
        return %orig;
    }
}

- (CGPoint)originForIconAtX:(NSUInteger)x Y:(NSUInteger)y {
    if (IFIconListIsValid(self)) {
        return IFIconListOriginForIconAtXY(self, x, y, ^(NSUInteger x, NSUInteger y) {
            return %orig(x, y);
        });
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

- (NSUInteger)columnAtPoint:(CGPoint)point {
    if (IFIconListIsValid(self)) {
        NSUInteger column = 0;

        IFFlag(IFFlagExpandedFrame) {
            UIScrollView *scrollView = IFListsScrollViewForListView(self);
            CGPoint offset = [scrollView contentOffset];
            CGSize size = [scrollView frame].size;

            if (IFPreferencesBoolForKey(IFPreferencesPagingEnabled)) {
                column = %orig;

                NSUInteger page = (offset.x / size.width);
                IFIconListDimensions dimensions = IFSizingDefaultDimensionsForIconList(self);
                column += page * dimensions.columns;
            } else {
                point.x += offset.x;
                point.y += offset.y;

                column = %orig;
            }
        }

        return column;
    } else {
        return %orig;
    }
}

/* }}} */
/* }}} */

%end

/* Fixes {{{ */

%hook UIScrollView

// FIXME: this is an ugly hack
static id grabbedIcon = nil;
- (void)setContentOffset:(CGPoint)offset {
    if (grabbedIcon != nil && [IFListsScrollViews containsObject:self]) {
        // Prevent weird auto-scrolling behavior while dragging icons.
        return;
    } else {
        %orig;
    }
}

%end

%hook SBIconController

- (CGRect)_contentViewRelativeFrameForIcon:(SBIcon *)icon {
    SBIconListView *listView = IFIconListContainingIcon(icon);
    UIScrollView *scrollView = IFListsScrollViewForListView(listView);

    CGRect ret = %orig;

    // The list could, in theory, be in another list that
    // we don't care about. If it is, we won't have a scroll
    // view for it, and can safely ignore moving the icon.
    if (scrollView != nil) {
        ret.origin.x -= [scrollView contentOffset].x;
        ret.origin.y -= [scrollView contentOffset].y;
    }

    return ret;
}

- (void)moveIconFromWindow:(SBIcon *)icon toIconList:(SBIconListView *)listView {
    %orig;

    if (IFIconListIsValid(listView)) {
        UIScrollView *scrollView = IFListsScrollViewForListView(listView);
        SBIconView *iconView = IFIconViewForIcon(icon);

        CGRect frame = [iconView frame];
        frame.origin.x += [scrollView contentOffset].x;
        frame.origin.y += [scrollView contentOffset].y;
        [iconView setFrame:frame];
    }
}

- (void)_dropIconIntoOpenFolder:(SBIcon *)icon withInsertionPath:(NSIndexPath *)path {
    %orig;

    SBFolderIconListView *listView = [self currentFolderIconList];

    if (IFIconListIsValid(listView)) {
        UIScrollView *scrollView = IFListsScrollViewForListView(listView);
        SBIconView *iconView = IFIconViewForIcon(icon);

        CGRect frame = [iconView frame];
        frame.origin.x -= [scrollView contentOffset].x;
        frame.origin.y -= [scrollView contentOffset].y;
        [iconView setFrame:frame];
    }
}

- (void)setGrabbedIcon:(id)icon {
    IFListsIterateViews(^(SBIconListView *listView, UIScrollView *scrollView) {
        [scrollView setScrollEnabled:(icon == nil)];
    });

    %orig;

    if (icon != nil) {
        grabbedIcon = icon;
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            grabbedIcon = nil;
        });
    }
}

- (void)setIsEditing:(BOOL)editing {
    %orig;

    dispatch_async(dispatch_get_main_queue(), ^{
        IFListsIterateViews(^(SBIconListView *listView, UIScrollView *scrollView) {
            IFIconListSizingUpdateIconList(listView);
        });
    });
}

%end

/* }}} */

%end



/* Custom Scroll View {{{ */

@implementation IFInfiniboardScrollView

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    // Allow accessing Spotlight when scrolled to the top on iOS 7.0+.
    if (NSClassFromString(@"SBSearchScrollView") != nil) {
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

__attribute__((constructor)) static void infiniboard_init() {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // dlopen("/Library/MobileSubstrate/DynamicLibraries/_iPhoneRotator.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/SixRows.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/7x7SpringBoard.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/CategoriesSB.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/FCSB.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/Iconoclasm.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/FiveIRows.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/FiveIRowsPart1.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/FiveIRowsPart2.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/FiveIRowsPart3.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/OverBoard.dylib", RTLD_LAZY);
    // dlopen("/Library/MobileSubstrate/DynamicLibraries/LockInfo.dylib", RTLD_LAZY);

    IFPreferencesInitialize(@"com.chpwn.infiniboard", IFPreferencesApply);

    dlopen("/Library/MobileSubstrate/DynamicLibraries/IconSupport.dylib", RTLD_LAZY);
    [[objc_getClass("ISIconSupport") sharedInstance] addExtension:@"infiniboard"];

    %init(IFInfiniboard);
    %init(IFBasic);

    [pool release];
}

/* }}} */