# Android Manifest Setup

✅ Ye permissions ab `android/app/src/main/AndroidManifest.xml` mein already
add ki ja chuki hain — is file ko dobara edit karne ki zaroorat nahi.
Neeche sirf reference ke liye rakha gaya hai:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Ye permissions HC-05/HC-06 ke saath paired-device list dekhne aur connect
karne ke liye zaroori hain (Android 12+ pe naye Bluetooth runtime permissions
hain, isliye BLUETOOTH_CONNECT/SCAN dono chahiye; purane devices ke liye
classic BLUETOOTH/BLUETOOTH_ADMIN bhi rakhe hain).

`minSdkVersion` ko `android/app/build.gradle` me kam se kam **21** rakhna
(flutter_bluetooth_serial ki requirement).
