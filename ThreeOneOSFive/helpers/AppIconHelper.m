#import "AppIconHelper.h"

static NSDictionary *ownAppInfo(void) {
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *bundleID = bundle.bundleIdentifier ?: @"com.external.system";
    NSString *name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: @"EXTERNAL SYSTEM";
    NSString *version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithDictionary:@{ @"name": name, @"version": version }];
    NSString *container = NSHomeDirectory();
    if (container.length > 0) entry[@"container"] = container;
    return @{ bundleID: entry };
}

NSDictionary<NSString *, NSDictionary *> *installedAppInfo(void) {
    return ownAppInfo();
}

UIImage *iconForBundleID(NSString *bundleID) {
    if (![bundleID isEqualToString:NSBundle.mainBundle.bundleIdentifier]) return nil;
    return [UIImage imageNamed:@"AppIcon"];
}

NSDictionary *appInfoForBundleID(NSString *bundleID) {
    if (![bundleID isEqualToString:NSBundle.mainBundle.bundleIdentifier]) return @{ @"name": bundleID ?: @"" };
    return ownAppInfo()[bundleID] ?: @{ @"name": bundleID ?: @"" };
}

BOOL openApplicationForBundleID(NSString *bundleID) {
    return NO;
}
