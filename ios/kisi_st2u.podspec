Pod::Spec.new do |s|
  s.name             = 'kisi_st2u'
  s.version          = '0.1.0'
  s.summary          = 'Flutter wrapper for Kisi Straight-to-Unlock (ST2U) iOS SDK.'
  s.description      = <<-DESC
    Flutter plugin wrapping the Kisi SecureAccess XCFramework for NFC tap-to-unlock
    and BLE beacon proximity detection on iOS.
  DESC
  s.homepage         = 'https://forge.bookingboard.io/booking-board/kisi-flutter-st2u.git'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Kisi' => 'sdks@kisi.io' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # ── SecureAccess XCFramework ─────────────────────────────────────────────
  # The XCFramework is downloaded by the setup script (scripts/setup.sh).
  # Run `dart run kisi_st2u:setup` (or `sh scripts/setup.sh`) before building.
  s.vendored_frameworks = 'Frameworks/SecureAccess.xcframework'

  # ── Build settings ────────────────────────────────────────────────────────
  s.swift_version = '5.9'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Allow the XCFramework (which is a binary target) to be embedded.
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES',
  }
end
