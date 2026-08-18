import ddf.minim.AudioPlayer;
import ddf.minim.Minim;
import processing.core.PApplet;

public class TwoStemSong implements StemSongInterface {

    AudioPlayer drumsPlayer;
    AudioPlayer vocalsPlayer;
    AudioPlayer instrusPlayer;
    AudioPlayer bassPlayer;

    public TwoStemSong(PApplet p, int SongVol){
        Minim drums = new Minim(p);

        drumsPlayer = drums.loadFile("C:\\Users\\Amil Agrawal\\OneDrive - Tredyffrin Easttown School District\\" +
                "JavaWorkspace\\FinalProj\\songs\\null_stem.mp3");

        //Vocals:
        Minim vocals = new Minim(p);
        vocalsPlayer = vocals.loadFile("C:\\Users\\Amil Agrawal\\OneDrive - Tredyffrin Easttown School District\\" +
                "JavaWorkspace\\FinalProj\\songs\\"+ SongVol +"\\Vocals.mp3");

        //Bass:
        Minim bass = new Minim(p);
        bassPlayer = bass.loadFile("C:\\Users\\Amil Agrawal\\OneDrive - Tredyffrin Easttown School District\\" +
                "JavaWorkspace\\FinalProj\\songs\\null_stem.mp3");

        //Instruments:
        Minim instrus = new Minim(p);
        instrusPlayer = instrus.loadFile("C:\\Users\\Amil Agrawal\\OneDrive - Tredyffrin Easttown School District\\" +
                "JavaWorkspace\\FinalProj\\songs\\"+  SongVol +"\\Instrumental.mp3");

        vocalsPlayer.setVolume(defaultVol);
        bassPlayer.setVolume(defaultVol);
        drumsPlayer.setVolume(defaultVol);
        instrusPlayer.setVolume(defaultVol);
    }

    public AudioPlayer getDrumsPlayer(){
        return drumsPlayer;
    }

    public AudioPlayer getVocalsPlayer(){
        return vocalsPlayer;
    }

    public AudioPlayer getBassPlayer(){
        return bassPlayer;
    }

    public AudioPlayer getInstrusPlayer(){
        return instrusPlayer;
    }
}
