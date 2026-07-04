<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key>
      <string>com.apple.security.pkcs12</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>PayloadIdentifier</key>
      <string>dk.deviceit.mdm.identity</string>
      <key>PayloadUUID</key>
      <string>{{UUID_IDENTITY}}</string>
      <key>PayloadDisplayName</key>
      <string>device-it device identity</string>
      <key>Password</key>
      <string>{{P12_PASSWORD}}</string>
      <key>PayloadContent</key>
      <data>
{{P12_B64}}
      </data>
    </dict>
    <dict>
      <key>PayloadType</key>
      <string>com.apple.mdm</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>PayloadIdentifier</key>
      <string>dk.deviceit.mdm</string>
      <key>PayloadUUID</key>
      <string>{{UUID_MDM}}</string>
      <key>PayloadDisplayName</key>
      <string>device-it MDM</string>
      <key>ServerURL</key>
      <string>{{SERVER_URL}}/mdm</string>
      <key>Topic</key>
      <string>{{PUSH_TOPIC}}</string>
      <key>IdentityCertificateUUID</key>
      <string>{{UUID_IDENTITY}}</string>
      <key>AccessRights</key>
      <integer>8191</integer>
      <key>SignMessage</key>
      <true/>
      <key>CheckOutWhenRemoved</key>
      <true/>
    </dict>
  </array>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
  <key>PayloadIdentifier</key>
  <string>dk.deviceit.enrollment</string>
  <key>PayloadUUID</key>
  <string>{{UUID_PROFILE}}</string>
  <key>PayloadDisplayName</key>
  <string>device-it (this Mac manages Home Screen apps)</string>
  <key>PayloadDescription</key>
  <string>Enrolls this iPad with the pocket MDM on {{HOSTNAME}} so device-it can install Home Screen apps automatically. Remove any time in Settings.</string>
  <key>PayloadOrganization</key>
  <string>device-it</string>
  <key>PayloadRemovalDisallowed</key>
  <false/>
</dict>
</plist>
