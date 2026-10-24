# Hawwel - حوّل (Windows)

نسخة ويندوز من تطبيق Hawwel: بتحوّل الكلام المكتوب بالكيبورد الغلط بين الإنجليزي والعربي بضغطة اختصار.

## الاستخدام
- حدد النص واضغط الاختصار (الافتراضي **Ctrl + Alt + K**، تقدر تغيّره من النافذة).
- لو مفيش تحديد، بيحوّل **آخر كلمة** قبل المؤشر.
- التطبيق بيفضل شغال في الـ System Tray. قفل النافذة بيخفيها بس، و"خروج" من الـ Tray بيقفله.

## البناء
### على جهاز ويندوز
1. ثبّت [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) (أو Visual Studio 2022 مع workload ".NET desktop development").
2. من فولدر المشروع:
   ```
   dotnet run
   ```
   أو لملف exe واحد جاهز للتوزيع:
   ```
   dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o out
   ```
   النتيجة: `out\Hawwel.exe`

### من غير جهاز ويندوز
ارفع الفولدر على GitHub، وGitHub Actions (ملف `.github/workflows/build.yml`) هيبني `Hawwel.exe` لوحده، تلاقيه في تبويب Actions > Artifacts.

## مقابلات نسخة الماك
| macOS | Windows |
|---|---|
| MenuBarExtra | NotifyIcon (System Tray) |
| KeyboardShortcuts | RegisterHotKey |
| Accessibility + Cmd+C/V (CGEvent) | SendInput + Ctrl+C/V |
| UCKeyTranslate (US / Arabic-PC) | ToUnicodeEx (US / Arabic 101) |
| UserDefaults | %AppData%\Hawwel\settings.json |
| SMAppService | HKCU\...\Run |

## ملاحظات
- لازم يكون عندك كيبورد **Arabic (101)** مضاف في ويندوز (Settings > Time & language > Language & region).
- البرامج اللي شغّالة "As Administrator" مش هتستقبل الضغطات من تطبيق عادي (قيد من ويندوز).
- في Terminal/CMD/PowerShell التطبيق بيرفض يشتغل، لأن Ctrl+C فيها معناها إيقاف البرنامج.
