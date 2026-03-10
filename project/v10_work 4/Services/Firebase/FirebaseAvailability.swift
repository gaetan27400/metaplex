//
//  FirebaseAvailability.swift
//  Journal de trading 2025
//
//  Safe helpers so the project compiles/runs even when Firebase SDK is not installed
//  or when GoogleService-Info.plist is missing.
//

import Foundation

enum FirebaseAvailability {
    /// True when Firebase SDK is present at compile time.
    static var isSDKAvailable: Bool {
        #if canImport(FirebaseCore)
        return true
        #else
        return false
        #endif
    }
    
    /// True when GoogleService-Info.plist exists in the main bundle.
    static var hasGoogleServicePlist: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }
    
    /// True when Firebase is configured (SDK present + configured at runtime).
    static var isConfigured: Bool {
        #if canImport(FirebaseCore)
        return FirebaseCoreAvailability.isConfigured
        #else
        return false
        #endif
    }
}

#if canImport(FirebaseCore)
import FirebaseCore

private enum FirebaseCoreAvailability {
    static var isConfigured: Bool {
        FirebaseApp.app() != nil
    }
}
#endif




