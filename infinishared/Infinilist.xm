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

// #include <substrate.h>

#include "Preferences.h"
// #include "iPhonePrivate.h"

/* }}} */

/* Configuration Macros {{{ */

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

static NSUInteger IFFlagExpandedFrame = 0;
static NSUInteger IFFlagDefaultDimensions = 0;

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

/* }}} */

/* List Management {{{ */

static NSMutableArray *IFListsListViews = nil;
static NSMutableArray *IFListsScrollViews = nil;

__attribute__((constructor)) static void IFListsInitialize() {
    // Non-retaining mutable arrays, since we don't want to own these objects.
    CFArrayCallBacks callbacks = { 0, NULL, NULL, CFCopyDescription, CFEqual };
    IFListsListViews = (NSMutableArray *) CFArrayCreateMutable(NULL, 0, &callbacks);
    IFListsScrollViews = (NSMutableArray *) CFArrayCreateMutable(NULL, 0, &callbacks);
}

__attribute__((unused)) static void IFListsIterateViews(void (^block)(SBIconListView *, UIScrollView *)) {
    for (NSUInteger i = 0; i < IFMinimum([IFListsListViews count], [IFListsScrollViews count]); i++) {
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

#ifndef IFPreferencesClipsToBounds
    #define IFPreferencesClipsToBounds @"ClipsToBounds", YES
#endif

#endif