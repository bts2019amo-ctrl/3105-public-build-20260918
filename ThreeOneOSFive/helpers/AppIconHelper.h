#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Returns metadata for the current app bundle only.
NSDictionary<NSString *, NSDictionary *> *installedAppInfo(void);

/// Returns the current app icon when the bundle identifier matches.
UIImage *iconForBundleID(NSString *bundleID);

/// Returns metadata for the current app bundle only.
NSDictionary *appInfoForBundleID(NSString *bundleID);

/// External app launching is unavailable in the normal sandbox.
BOOL openApplicationForBundleID(NSString *bundleID);

NS_ASSUME_NONNULL_END
