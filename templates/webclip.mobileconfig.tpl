<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key>
      <string>com.apple.webClip.managed</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>PayloadIdentifier</key>
      <string>dk.deviceit.clip.{{SLUG}}</string>
      <key>PayloadUUID</key>
      <string>{{UUID_CLIP}}</string>
      <key>PayloadDisplayName</key>
      <string>{{NAME}}</string>
      <key>Label</key>
      <string>{{NAME}}</string>
      <key>URL</key>
      <string>{{URL}}</string>
      <key>Icon</key>
      <data>
{{ICON_B64}}
      </data>
      <key>IsRemovable</key>
      <true/>
      <key>FullScreen</key>
      <true/>
      <key>Precomposed</key>
      <true/>
      <key>IgnoreManifestScope</key>
      <false/>
    </dict>
  </array>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
  <key>PayloadIdentifier</key>
  <string>dk.deviceit.{{SLUG}}</string>
  <key>PayloadUUID</key>
  <string>{{UUID_PROFILE}}</string>
  <key>PayloadDisplayName</key>
  <string>{{NAME}} (device-it)</string>
  <key>PayloadDescription</key>
  <string>Installs {{NAME}} on the Home Screen. Managed by device-it.</string>
  <key>PayloadOrganization</key>
  <string>device-it</string>
  <key>PayloadRemovalDisallowed</key>
  <false/>
</dict>
</plist>
