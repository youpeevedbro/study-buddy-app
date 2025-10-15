//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import auth0_flutter
import cloud_firestore
import firebase_core
import flutter_secure_storage_macos
import package_info_plus
import path_provider_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  Auth0FlutterPlugin.register(with: registry.registrar(forPlugin: "Auth0FlutterPlugin"))
  FLTFirebaseFirestorePlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseFirestorePlugin"))
  FLTFirebaseCorePlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseCorePlugin"))
  FlutterSecureStoragePlugin.register(with: registry.registrar(forPlugin: "FlutterSecureStoragePlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
}
