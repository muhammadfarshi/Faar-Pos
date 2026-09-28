# FAAR POS — Release Engineering & App Store Publishing Guide

## 1. Android Release (Google Play Store)

### 1.1 Generate Upload Keystore
```powershell
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 1.2 Configure `key.properties`
Create `android/key.properties`:
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=upload
storeFile=upload-keystore.jks
```

### 1.3 Build App Bundle (AAB) & APK
```powershell
# Build Play Store App Bundle
flutter build appbundle --release

# Build standalone test APK
flutter build apk --release
```

---

## 2. iOS Release (Apple App Store)

### 2.1 Build iOS Archive
```bash
flutter build ipa --release
```

### 2.2 App Store Privacy & Export Compliance
* `ITSAppUsesNonExemptEncryption` is pre-configured to `false` in `Info.plist`.
* Privacy descriptions for Camera, Bluetooth, and Local Network are embedded in `Info.plist`.
