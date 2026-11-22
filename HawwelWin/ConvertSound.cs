using System.Media;

namespace Hawwel;

/// <summary>صوت التحويل: نغمتين ناعمتين وقصيرين (نفس صوت نسخة الماك)، بصوت واطي.</summary>
public static class ConvertSound
{
    private static SoundPlayer? _player;

    public static void Play()
    {
        try
        {
            if (_player == null)
            {
                var s = typeof(ConvertSound).Assembly.GetManifestResourceStream("Hawwel.Assets.convert-sound.wav");
                if (s == null) return;
                _player = new SoundPlayer(s);
                _player.Load();
            }
            _player.Play(); // async، ولو اتنادى تاني بيبدأ من الأول
        }
        catch { }
    }
}
