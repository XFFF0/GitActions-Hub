# GitActions Hub 🚀

تطبيق iOS لإدارة GitHub Actions مباشرة من جهاز iPhone — بدون Mac، بدون شهادة توقيع.

## الميزات

- **مراقبة Actions** — عرض Workflow Runs بشكل مباشر مع التحديث التلقائي كل 30 ثانية
- **سجلات البناء الملونة** — كل سطر مرقم مع تلوين تلقائي للأخطاء والتحذيرات والأوامر
- **اكتشاف الأخطاء** — تصفية الأخطاء تلقائياً مع زر نسخ لكل خطأ ورقم السطر
- **إدارة الملفات** — إضافة/حذف/تعديل/إعادة تسمية الملفات
- **استيراد من Files** — نقل ملفات من تطبيق Files إلى التطبيق
- **Commit & Push** — رفع التغييرات مباشرة لـ GitHub عبر API
- **Liquid Glass UI** — تصميم احترافي بوضع Dark مع تأثيرات زجاجية

## المتطلبات

- iOS 16.0+
- Xcode 15+
- GitHub Personal Access Token بصلاحيات: `repo`, `workflow`, `read:user`

## بناء التطبيق

### عبر GitHub Actions (موصى به)

1. Fork المشروع على GitHub
2. شغّل الـ workflow من Actions tab
3. حمّل الـ IPA من Artifacts
4. ثبّت عبر TrollStore أو AltStore

### محلياً

```bash
git clone https://github.com/yourusername/GitActionsHub
cd GitActionsHub
open GitActionsHub.xcodeproj
# Build & Run على جهازك
```

## هيكل المشروع

```
GitActionsHub/
├── Models/
│   └── Models.swift          # GitHub Models (Repo, WorkflowRun, etc.)
├── Services/
│   ├── GitHubService.swift   # GitHub API calls
│   └── LocalFileManager.swift # File operations + Git ops
├── DesignSystem/
│   └── DesignSystem.swift    # Liquid Glass, colors, components
├── Views/
│   ├── LoginView.swift       # تسجيل الدخول بالتوكن
│   ├── ActionsView.swift     # مراقبة Actions + سجلات البناء
│   ├── ReposView.swift       # قائمة Repositories
│   └── FilesView.swift       # إدارة الملفات + Commit/Push
└── ContentView.swift         # Main app + Tab bar
```

## تصميم الأيقونة

الأيقونة تمثل صاروخ داخل مربع مدوّر بتدرج بنفسجي، رمزاً للنشر السريع وإطلاق البناء.

## ملاحظات

- التطبيق للاستخدام الشخصي
- Token يُحفظ في UserDefaults
- تشغيل Actions يتطلب صلاحية `workflow`
