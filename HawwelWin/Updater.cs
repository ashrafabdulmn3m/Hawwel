using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;

namespace Hawwel;

public enum UpdateCheckResult { Failed, UpToDate, Available }

public sealed record UpdateInfo(Version Version, string Tag, string DownloadUrl, long Size);

/// <summary>
/// بيسأل GitHub Releases عن إصدار ويندوز أحدث (tags بتبدأ بـ win-v)،
/// وينزّل Hawwel-Setup.exe ويشغّله صامت فوق النسخة القديمة.
/// </summary>
public static class Updater
{
    private const string Owner = "ashrafabdulmn3m";
    private const string Repo = "Hawwel";
    private const string TagPrefix = "win-v";
    private const string AssetName = "Hawwel-Setup.exe";

    private static readonly HttpClient Http = CreateClient();

    private static HttpClient CreateClient()
    {
        var c = new HttpClient { Timeout = TimeSpan.FromMinutes(10) };
        c.DefaultRequestHeaders.UserAgent.ParseAdd("Hawwel-Updater");
        c.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        return c;
    }

    private static Version Norm(Version v) => new(v.Major, v.Minor, Math.Max(v.Build, 0));

    /// <summary>إصدار التطبيق الحالي (بيتكتب في الـ exe من الـ tag وقت البناء).</summary>
    public static Version Current =>
        Norm(Assembly.GetEntryAssembly()?.GetName().Version ?? new Version(0, 0, 0));

    public static async Task<UpdateInfo?> CheckAsync(CancellationToken ct = default)
    {
        var url = $"https://api.github.com/repos/{Owner}/{Repo}/releases?per_page=30";
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(TimeSpan.FromSeconds(15));

        using var resp = await Http.GetAsync(url, cts.Token);
        resp.EnsureSuccessStatusCode();
        await using var stream = await resp.Content.ReadAsStreamAsync(cts.Token);
        using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: cts.Token);
        return PickLatest(doc.RootElement, Current);
    }

    /// <summary>بيختار أعلى إصدار ويندوز منشور، ويرجّعه بس لو أحدث من الحالي.</summary>
    internal static UpdateInfo? PickLatest(JsonElement releases, Version current)
    {
        UpdateInfo? best = null;
        foreach (var r in releases.EnumerateArray())
        {
            if (r.GetProperty("draft").GetBoolean() || r.GetProperty("prerelease").GetBoolean()) continue;

            var tag = r.GetProperty("tag_name").GetString() ?? "";
            if (!tag.StartsWith(TagPrefix, StringComparison.OrdinalIgnoreCase)) continue;
            if (!Version.TryParse(tag[TagPrefix.Length..], out var parsed)) continue;
            var v = Norm(parsed);
            if (best != null && v <= best.Version) continue;

            foreach (var a in r.GetProperty("assets").EnumerateArray())
            {
                if (!string.Equals(a.GetProperty("name").GetString(), AssetName, StringComparison.OrdinalIgnoreCase)) continue;
                var dl = a.GetProperty("browser_download_url").GetString();
                if (string.IsNullOrEmpty(dl)) continue;
                best = new UpdateInfo(v, tag, dl, a.GetProperty("size").GetInt64());
                break;
            }
        }
        return best != null && best.Version > Norm(current) ? best : null;
    }

    /// <summary>بينزّل الـ installer في مجلد مؤقت ويرجّع مساره. progress من 0 لـ 1.</summary>
    public static async Task<string> DownloadAsync(UpdateInfo info, IProgress<double>? progress = null, CancellationToken ct = default)
    {
        var uri = new Uri(info.DownloadUrl);
        if (uri.Scheme != Uri.UriSchemeHttps || !uri.Host.Equals("github.com", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("رابط التحديث مش موثوق");

        var dir = Path.Combine(Path.GetTempPath(), "HawwelUpdate");
        Directory.CreateDirectory(dir);
        var dest = Path.Combine(dir, $"Hawwel-Setup-{info.Version}.exe");
        var part = dest + ".part";

        using var resp = await Http.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, ct);
        resp.EnsureSuccessStatusCode();
        long total = resp.Content.Headers.ContentLength ?? info.Size;

        {
            await using var src = await resp.Content.ReadAsStreamAsync(ct);
            await using var dst = File.Create(part);
            var buf = new byte[81920];
            long read = 0;
            int n;
            while ((n = await src.ReadAsync(buf, ct)) > 0)
            {
                await dst.WriteAsync(buf.AsMemory(0, n), ct);
                read += n;
                if (total > 0) progress?.Report((double)read / total);
            }
        }

        if (info.Size > 0 && new FileInfo(part).Length != info.Size)
        {
            File.Delete(part);
            throw new IOException("الملف اتنزّل ناقص، جرّب تاني");
        }
        File.Move(part, dest, overwrite: true);
        return dest;
    }

    /// <summary>بيشغّل الـ installer بوضع صامت (بيقفل Hawwel ويحدّثه ويفتحه تاني).</summary>
    public static void LaunchInstaller(string path)
    {
        var psi = new ProcessStartInfo(path, "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART") { UseShellExecute = true };
        if (Process.Start(psi) == null) throw new InvalidOperationException("مقدرتش أشغّل الـ installer");
    }
}
