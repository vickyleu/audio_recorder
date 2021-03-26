package com.vickyleu.audiorecorder;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.media.MediaRecorder;
import android.os.Environment;
import android.os.Handler;
import android.util.Log;

import java.io.File;
import java.io.IOException;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * AudioRecorderPlugin
 */
public class AudioRecorderPlugin implements MethodCallHandler {
    private final Registrar registrar;
    private boolean isRecording = false;
    private static final String LOG_TAG = "AudioRecorder";
    private MediaRecorder mRecorder = null;
    private MethodChannel mChannel = null;
    private MethodCall mCall = null;
    private String mFilePath = null;
    private Date startTime = null;
    private String mExtension = "";
    private WavRecorder wavRecorder;

    private static int BASE = 32678;

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "audio_recorder");
        channel.setMethodCallHandler(new AudioRecorderPlugin(registrar, channel));
    }

    private AudioRecorderPlugin(Registrar registrar, MethodChannel mChannel) {
        this.registrar = registrar;
        this.mChannel = mChannel;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        mCall = call;
        switch (call.method) {
            case "convertMp3":
                String pcm=call.argument("pcm");
                String outPath=call.argument("path");
                encodeToMp3(pcm,outPath,result);
                break;
            case "start":

                Log.d(LOG_TAG, "Start");
                String path = call.argument("path");
                mExtension = call.argument("extension");
                startTime = Calendar.getInstance().getTime();
                if (path != null) {
                    mFilePath = path;
                } else {
                    String fileName = String.valueOf(startTime.getTime());
                    mFilePath = Environment.getExternalStorageDirectory().getAbsolutePath() + "/" + fileName + mExtension;
                }
                Log.d(LOG_TAG, mFilePath);
                Log.e("mFilePath", mFilePath);
                startRecording();

                result.success(null);
                break;
            case "stop":
                Log.d(LOG_TAG, "Stop");
                stopRecording();

                if (mFilePath == null) {
                    Log.e(LOG_TAG, "mFilePath==null");
                    result.success(null);
                    startTime = null;
                    mFilePath = null;
                    return;
                }
                File file = new File(mFilePath);
                if (!file.exists()) {
                    Log.e(LOG_TAG, "!file.exists()");
                    result.success(null);
                    startTime = null;
                    mFilePath = null;
                    return;
                }

                long duration = Calendar.getInstance().getTime().getTime() - startTime.getTime();
                Log.d(LOG_TAG, "Duration : " + String.valueOf(duration));

                HashMap<String, Object> recordingResult = new HashMap<>();
                recordingResult.put("duration", duration);
                recordingResult.put("path", mFilePath);
                recordingResult.put("audioOutputFormat", mExtension);
                result.success(recordingResult);
                startTime = null;
                mFilePath = null;
                break;
            case "isRecording":
                Log.d(LOG_TAG, "Get isRecording");
                result.success(isRecording);
                break;
            case "hasPermissions":
                Log.d(LOG_TAG, "Get hasPermissions");
                Context context = registrar.context();
                PackageManager pm = context.getPackageManager();
                int hasStoragePerm = pm.checkPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, context.getPackageName());
                int hasRecordPerm = pm.checkPermission(Manifest.permission.RECORD_AUDIO, context.getPackageName());
                boolean hasPermissions = hasStoragePerm == PackageManager.PERMISSION_GRANTED && hasRecordPerm == PackageManager.PERMISSION_GRANTED;
                result.success(hasPermissions);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void startRecording() {
        if (isOutputFormatWav()) {
            startWavRecording();
        } else {
            startNormalRecording();
        }
        Log.e("startRecording", "startRecording: " + isRecording);
        if (isRecording) {
            mHandler.postDelayed(mUpdateMicStatusTimer, 50);
        }
    }

    private void startNormalRecording() {
        try {
            mRecorder = new MediaRecorder();
            mRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            mRecorder.setOutputFormat(getOutputFormatFromString(mExtension));
            mRecorder.setOutputFile(mFilePath);
            mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);

            try {
                mRecorder.prepare();
            } catch (IOException e) {
                Log.e(LOG_TAG, "prepare() failed");
            }
            mRecorder.start();
            isRecording = true;
        }catch (Exception e2){

        }
    }

    private void startWavRecording() {
        try {
            wavRecorder = new WavRecorder(registrar.context(), mFilePath);
            wavRecorder.startRecording();
            isRecording = true;
        }catch (Exception e){
        }
    }

    private void stopRecording() {
        mHandler.removeCallbacksAndMessages(null);
        if (isRecording) {
            if (isOutputFormatWav()) {
                stopWavRecording();
            } else {
                stopNormalRecording();
            }
        }

    }

    private void stopNormalRecording() {
        if (mRecorder != null) {
            try {
                if (isRecording) {
                    mRecorder.stop();
                }
            } catch (Exception e) {
            }
            try {
                mRecorder.reset();
            } catch (Exception e) {
            }
            try {
                mRecorder.release();
            } catch (Exception e) {
            }
            mRecorder = null;
        }
        isRecording = false;
    }


    private void encodeToMp3(String inPcmPath,String outPath,Result result){
        File pcm=new File(inPcmPath);
        int flag=0;
        if(pcm.exists()){
            File output=new File(outPath);
            try {
                if(output.exists()){
                    output.delete();
                }
                output.createNewFile();
                flag=MP3Recorder.pcmTomp3(inPcmPath,outPath,44100/2,2,128);
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        if(flag==-1){
            result.success(outPath);
        }else{
            result.error(String.valueOf(flag),"转换失败",null);
        }

    }


    private final Handler mHandler = new Handler();
    private Runnable mUpdateMicStatusTimer = new Runnable() {
        @Override
        public void run() {
            updateMicStatus();
        }
    };

    private void updateMicStatus() {
        Log.e("startRecording", "updateMicStatus: ");
        // int vuSize = 10 * mMediaRecorder.getMaxAmplitude() / 32768;
//        int ratio = mRecorder.getMaxAmplitude() / BASE;
//        int db = 0;// 分贝
//        if (ratio > 1) {
//            db = (int) (20 * Math.log10(ratio));
//        }
        double ratio = ((7.0 * ((double) mRecorder.getMaxAmplitude())) / 32768.0);
        Log.e("updateMicStatus", "" + ratio);
        int level = 0;
        if (ratio > 0.1 && ratio < 0.2) {
            level = 2;
        } else if (ratio > 0.2 && ratio < 0.3) {
            level = 3;
        } else if (ratio > 0.3 && ratio < 0.4) {
            level = 4;
        } else if (ratio > 0.4 && ratio < 0.5) {
            level = 5;
        } else if (ratio > 0.5 && ratio < 0.6) {
            level = 6;
        } else if (ratio > 0.6 && ratio < 0.7) {
            level = 7;
        } else if (ratio > 0.7) {
            level = 7;
        } else {
            level = 1;
        }

        Map<Object, Object> map = new HashMap<Object, Object>();
        map.put("amplitude", level);
        Log.e("amplitude", "" + map.toString());
        callFlutter("onAmplitude", map);
        double duration = (System.currentTimeMillis()) - (startTime != null ? (double) startTime.getTime() : 0);
        Map<Object, Object> map2 = new HashMap<Object, Object>();
        map2.put("duration", duration);
        Log.e("durationduration", "" + map2.toString());
        callFlutter("onDuration", map2);
        if (mChannel != null && registrar != null && registrar.activity() != null) {
            mHandler.postDelayed(mUpdateMicStatusTimer, 50);
        }
        /*
         * if (db > 1) { vuSize = (int) (20 * Math.log10(db)); Log.i("mic_",
         * "麦克风的音量的大小：" + vuSize); } else Log.i("mic_", "麦克风的音量的大小：" + 0);
         */
    }

    private void callFlutter(final String method, final Map map) {
        if (mChannel != null && registrar != null && registrar.activity() != null) {
            registrar.activity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    mChannel.invokeMethod(method, map);
                }
            });
        }
    }


    private void stopWavRecording() {
        try {
            if (wavRecorder != null) {
                wavRecorder.stopRecording();
            }
        } catch (Exception e) {
        }
        isRecording = false;
    }

    private int getOutputFormatFromString(String outputFormat) {
        switch (outputFormat) {
            case ".mp4":
            case ".aac":
            case ".m4a":
                return MediaRecorder.OutputFormat.MPEG_4;
            default:
                return MediaRecorder.OutputFormat.MPEG_4;
        }
    }

    private boolean isOutputFormatWav() {
        return mExtension.equals(".wav");
    }
}