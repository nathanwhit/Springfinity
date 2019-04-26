#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface IFBRootListController : PSListController
- (id)readPreferenceValue:(PSSpecifier*)specifier;
- (NSArray *)specifiers;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier;
@end
