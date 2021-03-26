package com.vickyleu.audiorecorder;

public class MP3Recorder {
    static {
        System.loadLibrary("lamemp3");
    }
    public static native String getVersion();
    //初始化lame
    public static native int pcmTomp3(String pcmPath,String mp3Path,int sampleRate, int channel,  int bitRate);
    public static native void destroy();

}
