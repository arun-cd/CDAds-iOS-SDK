Pod::Spec.new do |s|

  s.name             = 'CDAds'
  s.version          = '4.0.0'
  s.summary          = 'Chalk Digital Ad SDK for iOS'
  s.description      = <<-DESC
    CDAds is the Chalk Digital advertising SDK for iOS.
    Supports Banner, MREC, MRAID, Interstitial, Rewarded Video, and Native ads.
    Includes background location tracking and GDPR/ATT consent helpers.
  DESC

  s.homepage         = 'https://www.chalkdigital.com'
  s.license          = { :type => 'Commercial', :file => 'LICENSE' }
  s.author           = { 'Chalk Digital' => 'sdk@chalkdigital.com' }

  s.platform         = :ios, '14.0'
  s.swift_versions   = ['5.9']

  s.source           = {
    :git => 'https://github.com/chalkdigital/cdads-ios-sdk.git',
    :tag => s.version.to_s
  }

  # ── Source files ────────────────────────────────────────────────────────────
  s.source_files = 'Sources/CDAds/**/*.swift'

  # ── Resource bundles ────────────────────────────────────────────────────────
  s.resource_bundles = {
    'CDAds_MRAID'     => ['Sources/CDAds/Internal/MRAID/Resources/**/*'],
    'CDAds_Storage'   => ['Sources/CDAds/Internal/Storage/Resources/**/*'],
    'CDAds_Resources' => ['Sources/CDAds/Public/Resources/**/*'],
  }

  # ── Frameworks ──────────────────────────────────────────────────────────────
  s.frameworks = [
    'UIKit',
    'WebKit',
    'AVFoundation',
    'AVKit',
    'CoreLocation',
    'SystemConfiguration',
    'AppTrackingTransparency',
    'AdSupport',
    'BackgroundTasks',
    'Network',
  ]

  # ── Build settings ──────────────────────────────────────────────────────────
  s.pod_target_xcconfig = {
    'SWIFT_VERSION'                => '5.9',
    'IPHONEOS_DEPLOYMENT_TARGET'   => '14.0',
    # Suppress SPM-only Bundle.module usage inside CocoaPods builds
    'OTHER_SWIFT_FLAGS'            => '$(inherited) -DCOCOAPODS',
  }

  # ── Privacy manifest ─────────────────────────────────────────────────────────
  # Xcode 15+ picks this up automatically when placed in the bundle root.
  s.resource  = 'Sources/CDAds/PrivacyInfo.xcprivacy'

  # ── Minimum requirements ─────────────────────────────────────────────────────
  s.requires_arc = true

end
