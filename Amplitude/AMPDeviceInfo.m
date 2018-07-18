//
//  AMPDeviceInfo.m

#import <Foundation/Foundation.h>
#import "AMPARCMacros.h"
#import "AMPDeviceInfo.h"
#import "AMPUtils.h"

#if (TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE)
#import <UIKit/UIKit.h>
#endif

#import <sys/sysctl.h>

#include <sys/types.h>

@interface AMPDeviceInfo ()
@end

@implementation AMPDeviceInfo {
    NSObject* networkInfo;
}

@synthesize appVersion = _appVersion;
@synthesize osVersion = _osVersion;
@synthesize model = _model;
@synthesize carrier = _carrier;
@synthesize country = _country;
@synthesize language = _language;
@synthesize advertiserID = _advertiserID;
@synthesize vendorID = _vendorID;




-(id) init {
    self = [super init];
    return self;
}

- (void) dealloc {
    SAFE_ARC_RELEASE(_appVersion);
    SAFE_ARC_RELEASE(_osVersion);
    SAFE_ARC_RELEASE(_model);
    SAFE_ARC_RELEASE(_carrier);
    SAFE_ARC_RELEASE(_country);
    SAFE_ARC_RELEASE(_language);
    SAFE_ARC_RELEASE(_advertiserID);
    SAFE_ARC_RELEASE(_vendorID);
    SAFE_ARC_SUPER_DEALLOC();
}

-(NSString*) appVersion {
    if (!_appVersion) {
        _appVersion = SAFE_ARC_RETAIN([[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"]);
    }
    return _appVersion;
}

-(NSString*) osName {
#if TARGET_OS_IPHONE
    return @"ios";
#else
    return @"macos";
#endif
}

-(NSString*) osVersion {
#if (TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE)
        return [[UIDevice currentDevice] systemVersion];
#else
        const NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
        return [NSString stringWithFormat:@"%@.%@.%@", @(version.majorVersion), @(version.minorVersion), @(version.patchVersion)];
#endif
}

-(NSString*) manufacturer {
    return @"Apple";
}

-(NSString*) model {
    if (!_model) {
        _model = SAFE_ARC_RETAIN([AMPDeviceInfo deviceModel]);
    }
    return _model;
}

-(NSString*) carrier {
    if (!_carrier) {
        Class CTTelephonyNetworkInfo = NSClassFromString(@"CTTelephonyNetworkInfo");
        SEL subscriberCellularProvider = NSSelectorFromString(@"subscriberCellularProvider");
        SEL carrierName = NSSelectorFromString(@"carrierName");
        if (CTTelephonyNetworkInfo && subscriberCellularProvider && carrierName) {
            networkInfo = SAFE_ARC_RETAIN([[NSClassFromString(@"CTTelephonyNetworkInfo") alloc] init]);
            id carrier = nil;
            id (*imp1)(id, SEL) = (id (*)(id, SEL))[networkInfo methodForSelector:subscriberCellularProvider];
            if (imp1) {
                carrier = imp1(networkInfo, subscriberCellularProvider);
            }
            NSString* (*imp2)(id, SEL) = (NSString* (*)(id, SEL))[carrier methodForSelector:carrierName];
            if (imp2) {
                _carrier = SAFE_ARC_RETAIN(imp2(carrier, carrierName));
            }
        }
        else {
            return @"Unknown";
        }
    }
    return _carrier;
}

-(NSString*) country {
    if (!_country) {
        _country = SAFE_ARC_RETAIN([[NSLocale localeWithLocaleIdentifier:@"en_US"] displayNameForKey:
            NSLocaleCountryCode value:
            [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]]);
    }
    return _country;
}

-(NSString*) language {
    if (!_language) {
        _language = SAFE_ARC_RETAIN([[NSLocale localeWithLocaleIdentifier:@"en_US"] displayNameForKey:
            NSLocaleLanguageCode value:[[NSLocale preferredLanguages] objectAtIndex:0]]);
    }
    return _language;
}

-(NSString*) advertiserID {
    if (!_advertiserID) {
        if ([[self osVersion] floatValue] >= (float) 6.0) {
            NSString *advertiserId = [AMPDeviceInfo getAdvertiserID:5];
            if (advertiserId != nil &&
                ![advertiserId isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
                _advertiserID = SAFE_ARC_RETAIN(advertiserId);
            }
        }
    }
    return _advertiserID;
}

-(NSString*) vendorID {
    if (!_vendorID) {
        if ([[self osVersion] floatValue] >= (float) 6.0) {
            NSString *identifierForVendor = [AMPDeviceInfo getVendorID:5];
            if (identifierForVendor != nil &&
                ![identifierForVendor isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
                _vendorID = SAFE_ARC_RETAIN(identifierForVendor);
            }
        }
    }
    return _vendorID;
}

+ (NSString*)getAdvertiserID:(int) maxAttempts
{
    Class ASIdentifierManager = NSClassFromString(@"ASIdentifierManager");
    SEL sharedManager = NSSelectorFromString(@"sharedManager");
    SEL advertisingIdentifier = NSSelectorFromString(@"advertisingIdentifier");
    if (ASIdentifierManager && sharedManager && advertisingIdentifier) {
        id (*imp1)(id, SEL) = (id (*)(id, SEL))[ASIdentifierManager methodForSelector:sharedManager];
        id manager = nil;
        NSUUID *adid = nil;
        NSString *identifier = nil;
        if (imp1) {
            manager = imp1(ASIdentifierManager, sharedManager);
        }
        NSUUID* (*imp2)(id, SEL) = (NSUUID* (*)(id, SEL))[manager methodForSelector:advertisingIdentifier];
        if (imp2) {
            adid = imp2(manager, advertisingIdentifier);
        }
        if (adid) {
            identifier = [adid UUIDString];
        }
        if (identifier == nil && maxAttempts > 0) {
            // Try again every 5 seconds
            [NSThread sleepForTimeInterval:5.0];
            return [AMPDeviceInfo getAdvertiserID:maxAttempts - 1];
        } else {
            return identifier;
        }
    } else {
        return nil;
    }
}

+ (NSString*)getVendorID:(int) maxAttempts
{
#if (TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE)
    NSString *identifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (identifier == nil && maxAttempts > 0) {
        // Try again every 5 seconds
        [NSThread sleepForTimeInterval:5.0];
        return [AMPDeviceInfo getVendorID:maxAttempts - 1];
    } else {
        return identifier;
    }
#else
    io_registry_entry_t ioRegistryRootEntry = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/");
    CFStringRef cfstrUuid = (CFStringRef)IORegistryEntryCreateCFProperty(ioRegistryRootEntry, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);
    IOObjectRelease(ioRegistryRootEntry);
    NSString *uuid = (__bridge_transfer NSString *)cfstrUuid;
    
    return uuid;
#endif
}

- (NSString*)generateUUID
{
    // Add "R" at the end of the ID to distinguish it from advertiserId
    NSString *result = [[AMPUtils generateUUID] stringByAppendingString:@"R"];
    return result;
}

#pragma mark - Platform string

+ (NSString *)getPlatformString {
#if TARGET_OS_IPHONE
    return [AMPDeviceInfo iOSPlatformString];
#else
    return [AMPDeviceInfo macOSPlatformString];
#endif
}

+ (NSString *)iOSPlatformString {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}

+ (NSString *)macOSPlatformString {
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        char *model = malloc(len * sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
        NSString *model_ns = [NSString stringWithUTF8String:model];
        free(model);
        return model_ns;
    }
    return @"Unknown Mac Computer";
}

#pragma mark - Device model

+ (NSString *)deviceModel {
#if TARGET_OS_IPHONE
    return [AMPDeviceInfo iOSDeviceModel];
#else
    return [AMPDeviceInfo macOSDeviceModel];
#endif
}

+ (NSString *)iOSDeviceModel {
    NSString *platform = [self getPlatformString];
    if ([platform isEqualToString:@"iPhone1,1"])    return @"iPhone 1";
    if ([platform isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([platform isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([platform isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,3"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([platform isEqualToString:@"iPhone5,1"])    return @"iPhone 5";
    if ([platform isEqualToString:@"iPhone5,2"])    return @"iPhone 5";
    if ([platform isEqualToString:@"iPhone6,1"])    return @"iPhone 5s";
    if ([platform isEqualToString:@"iPhone6,2"])    return @"iPhone 5s";
    if ([platform isEqualToString:@"iPhone7,1"])    return @"iPhone 6 Plus";
    if ([platform isEqualToString:@"iPhone7,2"])    return @"iPhone 6";
    if ([platform isEqualToString:@"iPhone8,1"])    return @"iPhone 6s";
    if ([platform isEqualToString:@"iPhone8,2"])    return @"iPhone 6s Plus";
    if ([platform isEqualToString:@"iPhone8,4"])    return @"iPhone SE";
    if ([platform isEqualToString:@"iPhone9,1"])    return @"iPhone 7";
    if ([platform isEqualToString:@"iPhone9,3"])    return @"iPhone 7";
    if ([platform isEqualToString:@"iPhone9,2"])    return @"iPhone 7+";
    if ([platform isEqualToString:@"iPhone9,4"])    return @"iPhone 7+";
    if ([platform isEqualToString:@"iPhone10,1"])   return @"iPhone 8";
    if ([platform isEqualToString:@"iPhone10,4"])   return @"iPhone 8";
    if ([platform isEqualToString:@"iPhone10,2"])   return @"iPhone 8+";
    if ([platform isEqualToString:@"iPhone10,5"])   return @"iPhone 8+";
    if ([platform isEqualToString:@"iPhone10,3"])   return @"iPhone X";
    if ([platform isEqualToString:@"iPhone10,6"])   return @"iPhone X";
    
    if ([platform isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([platform isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([platform isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([platform isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([platform isEqualToString:@"iPod5,1"])      return @"iPod Touch 5G";
    if ([platform isEqualToString:@"iPod7,1"])      return @"iPod Touch 6G";
    
    if ([platform isEqualToString:@"iPad1,1"])      return @"iPad 1";
    if ([platform isEqualToString:@"iPad2,1"])      return @"iPad 2";
    if ([platform isEqualToString:@"iPad2,2"])      return @"iPad 2";
    if ([platform isEqualToString:@"iPad2,3"])      return @"iPad 2";
    if ([platform isEqualToString:@"iPad2,4"])      return @"iPad 2";
    if ([platform isEqualToString:@"iPad2,5"])      return @"iPad Mini";
    if ([platform isEqualToString:@"iPad2,6"])      return @"iPad Mini";
    if ([platform isEqualToString:@"iPad2,7"])      return @"iPad Mini";
    if ([platform isEqualToString:@"iPad4,4"])      return @"iPad Mini 2";
    if ([platform isEqualToString:@"iPad4,5"])      return @"iPad Mini 2";
    if ([platform isEqualToString:@"iPad4,6"])      return @"iPad Mini 2";
    if ([platform isEqualToString:@"iPad4,7"])      return @"iPad Mini 3";
    if ([platform isEqualToString:@"iPad4,8"])      return @"iPad Mini 3";
    if ([platform isEqualToString:@"iPad4,9"])      return @"iPad Mini 3";
    if ([platform isEqualToString:@"iPad5,1"])      return @"iPad Mini 4";
    if ([platform isEqualToString:@"iPad5,2"])      return @"iPad Mini 4";
    if ([platform isEqualToString:@"iPad3,1"])      return @"iPad 3";
    if ([platform isEqualToString:@"iPad3,2"])      return @"iPad 3";
    if ([platform isEqualToString:@"iPad3,3"])      return @"iPad 3";
    if ([platform isEqualToString:@"iPad3,4"])      return @"iPad 4";
    if ([platform isEqualToString:@"iPad3,5"])      return @"iPad 4";
    if ([platform isEqualToString:@"iPad3,6"])      return @"iPad 4";
    if ([platform isEqualToString:@"iPad4,1"])      return @"iPad Air";
    if ([platform isEqualToString:@"iPad4,2"])      return @"iPad Air";
    if ([platform isEqualToString:@"iPad4,3"])      return @"iPad Air";
    if ([platform isEqualToString:@"iPad5,3"])      return @"iPad Air 2";
    if ([platform isEqualToString:@"iPad5,4"])      return @"iPad Air 2";
    if ([platform isEqualToString:@"iPad6,3"])      return @"iPad Pro";
    if ([platform isEqualToString:@"iPad6,4"])      return @"iPad Pro";
    if ([platform isEqualToString:@"iPad6,7"])      return @"iPad Pro";
    if ([platform isEqualToString:@"iPad6,8"])      return @"iPad Pro";
    if ([platform isEqualToString:@"iPad6,11"])     return @"iPad 9.7\" Wi-Fi"; // 5th Gen
    if ([platform isEqualToString:@"iPad6,12"])     return @"iPad 9.7\" 3G";    // 5th Gen
    if ([platform isEqualToString:@"iPad7,1"])      return @"iPad Pro 12.9\" Wi-Fi";
    if ([platform isEqualToString:@"iPad7,2"])      return @"iPad Pro 12.9\" 3G";
    if ([platform isEqualToString:@"iPad7,3"])      return @"iPad Pro 10.5\" Wi-Fi";
    if ([platform isEqualToString:@"iPad7,4"])      return @"iPad Pro 10.5\" 3G";
    if ([platform isEqualToString:@"iPad7,5"])      return @"iPad 9.7\" Wi-Fi"; // 6th Gen
    if ([platform isEqualToString:@"iPad7,6"])      return @"iPad 9.7\" 3G";    // 6th Gen
    
    if ([platform isEqualToString:@"i386"])         return @"Simulator";
    if ([platform isEqualToString:@"x86_64"])       return @"Simulator";
    return platform;
}

+ (NSString *)macOSDeviceModel {
    NSString *platform = [self getPlatformString];
    
    // Mac mini
    if ([platform isEqualToString:@"Macmini4,1"])         return @"Mac mini (Mid 2010)";
    if ([platform isEqualToString:@"Macmini5,1"])         return @"Mac mini (Mid 2011)";
    if ([platform isEqualToString:@"Macmini5,2"])         return @"Mac mini (Mid 2011)";
    if ([platform isEqualToString:@"Macmini5,3"])         return @"Mac mini (Mid 2011/Server)";
    if ([platform isEqualToString:@"Macmini6,1"])         return @"Mac mini (Late 2012)";
    if ([platform isEqualToString:@"Macmini6,2"])         return @"Mac mini (Late 2012)";
    if ([platform isEqualToString:@"Macmini7,1"])         return @"Mac mini (Late 2014)";
    
    // iMac
    if ([platform isEqualToString:@"iMac10,1"])           return @"iMac 21.5\" (Late 2009)";
    if ([platform isEqualToString:@"iMac11,1"])           return @"iMac 27\" (Late 2009)";
    if ([platform isEqualToString:@"iMac11,2"])           return @"iMac 21.5\" (Mid 2010)";
    if ([platform isEqualToString:@"iMac11,3"])           return @"iMac 27\" (Mid 2010)";
    if ([platform isEqualToString:@"iMac12,1"])           return @"iMac 21.5\" (Mid 2011, Late 2011)";
    if ([platform isEqualToString:@"iMac12,2"])           return @"iMac 27\" (Mid 2011)";
    if ([platform isEqualToString:@"iMac13,1"])           return @"iMac 21.5\" (Late 2012, Early 2013)";
    if ([platform isEqualToString:@"iMac13,2"])           return @"iMac 27\" (Late 2012)";
    if ([platform isEqualToString:@"iMac14,1"])           return @"iMac 21.5\" (Late 2013)";
    if ([platform isEqualToString:@"iMac14,2"])           return @"iMac 27\" (Late 2013)";
    if ([platform isEqualToString:@"iMac14,3"])           return @"iMac 21.5\" (Late 2013)";
    if ([platform isEqualToString:@"iMac14,4"])           return @"iMac 21.5\" (Mid-2014)";
    if ([platform isEqualToString:@"iMac15,1"])           return @"iMac 27\" (Late 2014)";
    if ([platform isEqualToString:@"iMac16,1"])           return @"iMac 21.5\" (Late 2015)";
    if ([platform isEqualToString:@"iMac16,2"])           return @"iMac 21.5\" (Late 2015)";
    if ([platform isEqualToString:@"iMac17,1"])           return @"iMac 27\" (Late 2015)";
    if ([platform isEqualToString:@"iMac18,1"])           return @"iMac 21.5\" (Mid 2017)";
    if ([platform isEqualToString:@"iMac18,2"])           return @"iMac 21.5\" (Mid 2017)";
    if ([platform isEqualToString:@"iMac18,3"])           return @"iMac 27\" (Mid 2017)";
    if ([platform isEqualToString:@"iMacPro1,1"])         return @"iMac Pro 27\" (Late 2017)";
    
    // Mac Pro
    if ([platform isEqualToString:@"MacPro5,1"])          return @"Mac Pro (2010-2012)";
    if ([platform isEqualToString:@"MacPro6,1"])          return @"Mac Pro (Late 2013)";
    
    // MacBook
    if ([platform isEqualToString:@"MacBook6,1"])         return @"MacBook 13\" (Late 2009)";
    if ([platform isEqualToString:@"MacBook7,1"])         return @"MacBook 13\" (Mid 2010)";
    if ([platform isEqualToString:@"MacBook8,1"])         return @"MacBook 12\" (Early 2015)";
    if ([platform isEqualToString:@"MacBook9,1"])         return @"MacBook 12\" (Early 2016)";
    if ([platform isEqualToString:@"MacBook10,1"])        return @"MacBook 12\" (Mid 2017)";
    
    // MacBook Pro
    if ([platform isEqualToString:@"MacBookPro7,1"])       return @"MacBook Pro 13\" (Mid 2010)";
    if ([platform isEqualToString:@"MacBookPro6,2"])       return @"MacBook Pro 15\" (Mid 2010)";
    if ([platform isEqualToString:@"MacBookPro6,1"])       return @"MacBook Pro 17\" (Mid 2010)";
    if ([platform isEqualToString:@"MacBookPro8,1"])       return @"MacBook Pro 13\" (Early 2011)";
    if ([platform isEqualToString:@"MacBookPro8,2"])       return @"MacBook Pro 15\" (Early 2011)";
    if ([platform isEqualToString:@"MacBookPro8,3"])       return @"MacBook Pro 17\" (Early 2011)";
    if ([platform isEqualToString:@"MacBookPro9,2"])       return @"MacBook Pro 13\" (Mid 2012)";
    if ([platform isEqualToString:@"MacBookPro9,1"])       return @"MacBook Pro 15\" (Mid 2012)";
    if ([platform isEqualToString:@"MacBookPro10,1"])      return @"MacBook Pro 15\" (Mid 2012)"; // Retina
    if ([platform isEqualToString:@"MacBookPro10,2"])      return @"MacBook Pro 13\" (Mid 2012)"; // Retina
    if ([platform isEqualToString:@"MacBookPro11,1"])      return @"MacBook Pro 13\" (Late 2013)";
    if ([platform isEqualToString:@"MacBookPro11,2"])      return @"MacBook Pro 15\" (Late 2013)"; // Integrated Graphics
    if ([platform isEqualToString:@"MacBookPro11,3"])      return @"MacBook Pro 15\" (Late 2013)"; // Discrete Graphics
    if ([platform isEqualToString:@"MacBookPro11,4"])      return @"MacBook Pro 15\" (Mid 2015)"; // Integrated Graphics
    if ([platform isEqualToString:@"MacBookPro11,5"])      return @"MacBook Pro 15\" (Mid 2015)"; // Discrete Graphics
    if ([platform isEqualToString:@"MacBookPro12,1"])      return @"MacBook Pro 13\" (Early 2015)";
    if ([platform isEqualToString:@"MacBookPro13,1"])      return @"MacBook Pro 13\" (Late 2016)";
    if ([platform isEqualToString:@"MacBookPro13,2"])      return @"MacBook Pro 13\" (Late 2016)"; // Touch Bar
    if ([platform isEqualToString:@"MacBookPro13,3"])      return @"MacBook Pro 15\" (Late 2016)"; // Touch Bar
    if ([platform isEqualToString:@"MacBookPro14,1"])      return @"MacBook Pro 13\" (Mid 2017)";
    if ([platform isEqualToString:@"MacBookPro14,2"])      return @"MacBook Pro 13\" (Mid 2017)"; // Touch Bar
    if ([platform isEqualToString:@"MacBookPro14,3"])      return @"MacBook Pro 15\" (Mid 2017)"; // Touch Bar
    
    // MacBook Air
    if ([platform isEqualToString:@"MacBookAir3,1"])       return @"MacBook Air 11\" (Late 2010)";
    if ([platform isEqualToString:@"MacBookAir3,2"])       return @"MacBook Air 13\" (Late 2010)";
    if ([platform isEqualToString:@"MacBookAir3,2"])       return @"MacBook Air 13\" (Late 2010)";
    if ([platform isEqualToString:@"MacBookAir4,1"])       return @"MacBook Air 11\" (Mid 2011)";
    if ([platform isEqualToString:@"MacBookAir4,2"])       return @"MacBook Air 13\" (Mid 2011)";
    if ([platform isEqualToString:@"MacBookAir5,1"])       return @"MacBook Air 11\" (Mid 2012)";
    if ([platform isEqualToString:@"MacBookAir5,2"])       return @"MacBook Air 13\" (Edu Only)";
    if ([platform isEqualToString:@"MacBookAir6,1"])       return @"MacBook Air 11\" (Mid 2013, Early 2014)";
    if ([platform isEqualToString:@"MacBookAir6,2"])       return @"MacBook Air 13\" (Mid 2013, Early 2014)";
    if ([platform isEqualToString:@"MacBookAir7,1"])       return @"MacBook Air 11\" (Early 2015)";
    if ([platform isEqualToString:@"MacBookAir7,2"])       return @"MacBook Air 13\" (Early 2015)";
    
    return platform;
}

@end
