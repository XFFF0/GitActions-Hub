# 🎬 سينمانا — Cinemana iOS App

تطبيق iOS لمنصة سينمانا (Shabakaty) مبني بـ SwiftUI مع بناء IPA تلقائي عبر GitHub Actions.

---

## 🗂 هيكل المشروع

```
CinemanaApp/
├── CinemanaApp.xcodeproj/
│   └── project.pbxproj
├── CinemanaApp/
│   ├── CinemanaApp.swift       ← نقطة بداية التطبيق
│   ├── ContentView.swift       ← كل الواجهات (Home, Search, Categories, Profile)
│   ├── Info.plist
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/ ← أيقونة سينمانا (كل الأحجام)
│       └── AccentColor.colorset/
└── .github/
    └── workflows/
        ├── build.yml           ← بناء IPA رسمي (يتطلب Apple cert)
        └── build-zsign.yml     ← بناء IPA بدون cert (للـ TrollStore/Sideloadly)
```

---

## 🚀 طريقة الاستخدام

### الطريقة 1: بدون Apple Developer Account (الأسهل)

استخدم workflow الـ `build-zsign.yml` — يبني IPA بدون توقيع رسمي يمكن تثبيته عبر:
- **TrollStore** (مباشرة)
- **Sideloadly** أو **ESign** (يحتاج resign)
- **AltStore**

```bash
# فقط ادفع الكود وشغّل الـ workflow
git push origin main
# ثم من GitHub Actions → Run workflow
```

### الطريقة 2: Apple Developer Account

أضف هذه الـ Secrets في `Settings → Secrets → Actions`:

| Secret | الشرح |
|--------|-------|
| `CERTIFICATE_BASE64` | شهادة .p12 مشفرة بـ base64 |
| `CERTIFICATE_PASSWORD` | كلمة مرور الشهادة |
| `PROVISIONING_PROFILE_BASE64` | ملف .mobileprovision مشفر بـ base64 |
| `PROVISIONING_PROFILE_NAME` | اسم الـ profile |
| `TEAM_ID` | Team ID من Apple Developer |

#### كيفية تشفير الملفات:
```bash
# تشفير الشهادة
base64 -i MyCert.p12 | pbcopy

# تشفير الـ Provisioning Profile
base64 -i MyProfile.mobileprovision | pbcopy
```

---

## 📱 مميزات التطبيق

| الواجهة | المميزات |
|---------|---------|
| **الرئيسية** | مجموعات الفيديو من API سينمانا الحقيقي |
| **البحث** | بحث مباشر في قاعدة بيانات سينمانا |
| **الأصناف** | تصفح بالتصنيفات |
| **الحساب** | تسجيل دخول عبر Identity Server الرسمي |
| **تفاصيل الفيديو** | روابط تشغيل بجودات مختلفة |

---

## 🔑 API المستخدمة

```
Base:     https://cinemana.shabakaty.cc/api/android/
Auth:     https://account.shabakaty.cc/core/connect/token
clientId: cTnj9bUcDmr08B586K7pGFHy
```

---

## ⚙️ متطلبات البناء المحلي

- macOS 13+
- Xcode 15+
- iOS Deployment Target: 15.0

```bash
open CinemanaApp.xcodeproj
# ثم اختر جهازك واضغط Run
```
