import ddf.minim.AudioPlayer;
import processing.core.PApplet;
import processing.video.*;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Scanner;

public class StemPlayerProject extends PApplet {

    /**
     * initializes PApplet Window
     */
    public static void main(String[] args){
        PApplet.main("StemPlayerProject");
    }

    //four types of stems

    Movie m;
    AudioPlayer drumsPlayer;
    AudioPlayer vocalsPlayer;
    AudioPlayer instrusPlayer;
    AudioPlayer bassPlayer;

    //USE OF ARRAY: to easily make changes to all four players, utilized heavily throughout
    AudioPlayer[] stems  = new AudioPlayer[4];

    /**
     * sets size of window to 800 width and 950 length, perfect to fit four wavelengths
     */
    public void settings(){
        size(800,950);
    }

    /**
     * initializes AudioPlayers for all four stems
     */
    public void setup(){
        System.out.println("Out of this World TRACKLIST\n1. True Love (ft. XXXTentacion)\n" +
                "2. Broken Road (ft. Don Toliver)\n" +
                "3. Get Lost\n" +
                "4. Too Easy\n" +
                "5. Flowers\n" +
                "6. Security\n" +
                "7. We Did It Kid (ft. Baby Keem and Migos)\n" +
                "8. Pablo (ft. Travis Scott and Future)\n" +
                "9. Louie Bags (ft. Jack Harlow)\n" +
                "10. Happy (ft. Future)\n" +
                "11. Sci Fi (ft. Sean Leon)\n" +
                "12. Selfish (ft. XXXTentacion)\n" +
                "13. Lord Lift Me Up (performed by Vory)\n" +
                "13. Keep It Burning (ft. Future)\n" +
                "15. City Of Gods (ft. Fivio Foreign and Alicia Keys)\n" +
                "16. First Time In A Long Time (ft. Soulja Boy)\n" + "17. True Love (Stadium Version)");

        System.out.println("CHOOSE DONDA 2 TRACK #:");
        Scanner sc = new Scanner(System.in);
        String songName = sc.nextLine();
        int songNum = Integer.parseInt(songName);//converts user input to int for other classes to read

        List<Integer> twoStemSongs = Arrays.asList(3,9,11,13);
        //USE OF ARRAYLIST: to quickly check if the song is two, three, or four stems
        ArrayList<Integer> twoSongs = new ArrayList<>(twoStemSongs);
        //calls other classes to construct stems of song
        if (twoSongs.contains(songNum)){
            TwoStemSong song = new TwoStemSong(this, songNum);
            vocalsPlayer = song.getVocalsPlayer();
            bassPlayer = song.getBassPlayer();
            drumsPlayer = song.getDrumsPlayer();
            instrusPlayer = song.getInstrusPlayer();
        }
        else if (songNum == 16){
            ThreeStemSong song = new ThreeStemSong(this, songNum);
            vocalsPlayer = song.getVocalsPlayer();
            bassPlayer = song.getBassPlayer();
            drumsPlayer = song.getDrumsPlayer();
            instrusPlayer = song.getInstrusPlayer();
        }
        else {
            FourStemSong song = new FourStemSong(this, songNum);
            vocalsPlayer = song.getVocalsPlayer();
            bassPlayer = song.getBassPlayer();
            drumsPlayer = song.getDrumsPlayer();
            instrusPlayer = song.getInstrusPlayer();
        }
        //sets values of stems array
        stems[0]=drumsPlayer;stems[1]=vocalsPlayer;stems[2]=instrusPlayer;stems[3]=bassPlayer;
        System.out.println("================================================================================");
        System.out.println("================================================================================");
        System.out.println("DONDA 2 TRACK #" + songName + " IS PLAYING");
        System.out.println("================================================================================");
        System.out.println("================================================================================");

//        if (songNum == 4){
//            m = new Movie(this, "C:\\Users\\Amil Agrawal\\OneDrive - Tredyffrin Easttown School District\\" +
//                    "JavaWorkspace\\FinalProj\\songs\\4\\visual.mp4");
//        }
    }

    /**
     * draws waveforms, labels, and volume indicators in PApplet window
     */
    public void draw(){
        background(0);
//        tint(255,20);
//        image(m, 0,0);

        stroke(255);

        //draw waves and text
        int yLevel = 0;
        int color = 0;
        for (AudioPlayer player : stems)
        {
            textSize(50);
            //Text and color set
            if (color == 0){stroke(65, 253, 254);fill(65, 253, 254);text("DRUMS",305,120);}
            if (color == 1){stroke(255, 240, 31);fill(255, 240, 31);text("VOCALS",295,370);}
            if (color == 2){stroke(127, 0, 255);fill(127,0,255);text("INSTRUMENTS",228,620);}
            if (color == 3) {stroke(255,68,204);fill(255,68,204);text("BASS",327,870);}

            //Volume Indicator
            for (int i = 0; i < (int) (Math.floor(player.getGain()/6.026 + .5)+6); i++){
                ellipse(765-35*i, yLevel+102, 35,35);
                ellipse(35+35*i,yLevel+102,35,35);
            }

            color++;

            //Waveforms - code based off of Minim library standard (set code for visualizing a waveform)
            for(int i = 0; i < player.bufferSize() - 1; i++)
            {
                float x1 = map( i, 0, player.bufferSize(), 0, width );
                float x2 = map( i+1, 0, player.bufferSize(), 0, width );
                line( x1, 50 + player.left.get(i)*50+ yLevel, x2, 50 + player.left.get(i+1)*50+ yLevel);
                line( x1, 150 + player.right.get(i)*50+ yLevel, x2, 150 + player.right.get(i+1)*50+ yLevel);
            }

            // draw a line to show where in the song playback is currently located
            float posx = map(player.position(), 0, stems[1].length(), 0, width);
            fill((int)(Math.random()*256),(int)(Math.random()*256),(int)(Math.random()*256));
            noStroke();
            rect(posx, 0, 2, height);
            yLevel+=250;

        }
        //TITLE
        textSize(80);
        fill(255);
        //text("STEM PLAYER DEMO", 8 , 510);
    }

    /**
     * scans 12 different key inputs to control audio output, volumes of certain stems, pause/play, fastforward/rewind
     */
    public void keyPressed(){
        //TRUE SILENCE: if volume is low enough, mute player
        if (bassPlayer.getGain()<-30){bassPlayer.mute();}else{bassPlayer.unmute();}
        if (instrusPlayer.getGain()<-30){instrusPlayer.mute();}else{instrusPlayer.unmute();}
        if (vocalsPlayer.getGain()<-30){vocalsPlayer.mute();}else{vocalsPlayer.unmute();}
        if (drumsPlayer.getGain()<-30){drumsPlayer.mute();}else{drumsPlayer.unmute();}

        //pause/unpause all players + visuals
        if (key == ' ' || key == 'k'){
        if (vocalsPlayer.isPlaying() || drumsPlayer.isPlaying() || bassPlayer.isPlaying() || instrusPlayer.isPlaying()){
            for (AudioPlayer p : stems){
                p.pause();
            }
        }
        else{
            for (AudioPlayer p : stems){
                p.play();
            }
        }
        }

        //fast forward 5 seconds or rewind 5 seconds
        else if (key == 'l'){
            for (AudioPlayer p : stems){
                p.skip(5000);
            }
        }
        else if (key == 'j'){
            for (AudioPlayer p : stems){
                p.skip(-5000);
            }
        }

        //LOWER VOLUME
        else if (key == 'a' || key == 's' || key == 'd' || key == 'f'){
            if (key == 'a' && drumsPlayer.getGain()>-30.12){
                drumsPlayer.setGain((float) (drumsPlayer.getGain()-6.026));
            }
            if (key == 's' && vocalsPlayer.getGain()>-30.12){
                vocalsPlayer.setGain((float) (vocalsPlayer.getGain()-6.026));
            }
            if (key == 'd' && instrusPlayer.getGain()>-30.12){
                instrusPlayer.setGain((float) (instrusPlayer.getGain()-6.026));
            }
            if (key == 'f' && bassPlayer.getGain()>-30.12){
                bassPlayer.setGain((float) (bassPlayer.getGain()-6.026));
            }
        }

        //RAISE VOLUME
        else if (key == 'q' || key == 'w' || key == 'e' || key == 'r'){
            if (key == 'q' && drumsPlayer.getGain() < -1){
                drumsPlayer.setGain((float) (drumsPlayer.getGain()+6.026));
            }
            if (key == 'w' && vocalsPlayer.getGain() < -1){
                vocalsPlayer.setGain((float) (vocalsPlayer.getGain()+6.026));
            }
            if (key == 'e' && instrusPlayer.getGain() < -1){
                instrusPlayer.setGain((float) (instrusPlayer.getGain()+6.026));
            }
            if (key == 'r' && bassPlayer.getGain() < -1){
                bassPlayer.setGain((float) (bassPlayer.getGain()+6.026));
            }
        }
    }

//    public void movieEvent(Movie m){
//        m.read();
//    }
}
