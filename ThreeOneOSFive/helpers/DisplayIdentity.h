#pragma once
#import <Foundation/Foundation.h>
// Display identity / attestation — used by AppInfo.
// Removing this breaks launch attestation; the app will refuse to start.
NSString *DisplayIdentityAttestationToken(void);
NSURL *DisplayIdentityAttributionURL(void);
