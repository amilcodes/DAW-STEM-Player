import ddf.minim.AudioPlayer;
public interface StemSongInterface {

    float defaultVol = .5f;

    AudioPlayer getDrumsPlayer();
    AudioPlayer getVocalsPlayer();
    AudioPlayer getBassPlayer();
    AudioPlayer getInstrusPlayer();
}
