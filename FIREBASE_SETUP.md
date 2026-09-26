# Firebase Console Setup Instructions

## Prerequisites
- Google account
- Flutter project with Firebase dependencies already added

## Firebase Project Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `village-assistance-app`
4. Click "Continue"
5. Choose your Google Analytics account (optional)
6. Click "Create project"

### 2. Add Android App
1. In Firebase Console, click the Android icon to add Android app
2. Package name: `com.example.villageVerse` (check your `android/app/build.gradle` for exact package name)
3. Download `google-services.json`
4. Place `google-services.json` in `android/app/` directory
5. Add the Google services plugin to your `android/build.gradle`:
   ```gradle
   buildscript {
     dependencies {
       // Add this line
       classpath 'com.google.gms:google-services:4.3.15'
     }
   }
   ```
6. Add the plugin to your `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

### 3. Add iOS App (if needed)
1. In Firebase Console, click "Add app" and choose iOS
2. iOS bundle ID: `com.example.villageVerse` (check your `ios/Runner.xcodeproj` for exact bundle ID)
3. Download `GoogleService-Info.plist`
4. Place `GoogleService-Info.plist` in `ios/Runner/` directory
5. Add the Firebase SDK to your `ios/Podfile`:
   ```ruby
   pod 'FirebaseCore'
   pod 'FirebaseAuth'
   ```

### 4. Enable Google Sign-In
1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Click **Google** under "Sign-in providers"
3. Enable the toggle switch
4. Enter your project support email
5. Click **Save**

### 5. Configure OAuth Consent Screen
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** → **OAuth consent screen**
4. Configure the consent screen with:
   - App name: Village One
   - User support email: your email
   - Developer contact information: your email
5. Add required scopes:
   - `.../auth/userinfo.email`
   - `.../auth/userinfo.profile`
   - `openid`

### 6. Generate SHA-1 Fingerprint (for Android)
1. Open terminal in your project's `android/` directory
2. Run: `./gradlew signingReport`
3. Copy the SHA-1 fingerprint from the output
4. In Firebase Console → Project Settings → General → Your Apps
5. Add the SHA-1 fingerprint to your Android app configuration

## Platform-Specific Configuration

### Android Configuration
1. Update `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <application ...>
     <meta-data android:name="com.google.android.geo.API_KEY"
                android:value="YOUR_API_KEY"/>
   </application>
   ```

### iOS Configuration
1. Update `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>YOUR_REVERSED_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```

## Required Packages
Add these to your `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^4.8.0
  firebase_auth: ^6.5.0
  google_sign_in: ^6.2.1
```

## Testing Steps
1. Run `flutter pub get`
2. Run the app on a physical device or emulator
3. Test the authentication flow:
   - Launch app → Splash screen
   - Navigate to Auth screen
   - Click "Continue with Google"
   - Complete Google Sign-In
   - Navigate to Profile Setup screen

## Troubleshooting

### Common Issues
1. **SHA-1 fingerprint mismatch**: Ensure you've added the correct SHA-1 from `./gradlew signingReport`
2. **OAuth consent screen not configured**: Complete the OAuth consent screen setup in Google Cloud Console
3. **Google Sign-In not enabled**: Enable Google Sign-In in Firebase Authentication settings
4. **Package name mismatch**: Ensure the package name matches exactly between Firebase Console and your app

### Debug Commands
```bash
# Check Firebase connection
flutter run --verbose

# Check Google Sign-In configuration
flutter pub deps

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## Security Notes
- Never expose your API keys in client-side code
- Use environment variables for sensitive configuration
- Enable app verification in Firebase Authentication settings
- Regularly review authorized domains in Firebase Console

## Next Steps
After setting up Firebase, your Village One app will have:
- ✅ Google Sign-In authentication
- ✅ User session management
- ✅ Cross-platform support
- ✅ Secure authentication flow

The app is now ready for further development of village assistance features!
