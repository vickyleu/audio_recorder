package com.jordanalcaraz.audiorecorder.audiorecorder;

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
                startRecording();
                isRecording = true;
                result.success(null);
                break;
            case "stop":
                Log.d(LOG_TAG, "Stop");
                stopRecording();
                long duration = Calendar.getInstance().getTime().getTime() - startTime.getTime();
                Log.d(LOG_TAG, "Duration : " + String.valueOf(duration));
                isRecording = false;
                HashMap<String, Object> recordingResult = new HashMap<>();
                recordingResult.put("duration", duration);
                recordingResult.put("path", mFilePath);
                recordingResult.put("audioOutputFormat", mExtension);
                result.success(recordingResult);
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
        if (isRecording) {
            mHandler.sendEmptyMessage(0);
        }
    }

    private void startNormalRecording() {
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
    }

    private void startWavRecording() {
        wavRecorder = new WavRecorder(registrar.context(), mFilePath);
        wavRecorder.startRecording();
    }

    private void stopRecording() {
        mHandler.removeCallbacksAndMessages(null);
        if (isOutputFormatWav()) {
            stopWavRecording();
        } else {
            stopNormalRecording();
        }
        if (mFilePath == null) {
            return;
        }
        File file = new File(mFilePath);
        if (!file.exists()) {
            return;
        }
        HashMap<String, String> map = new HashMap<String, String>();
        map.put("path", mFilePath);
        mFilePath = null;
        callFlutter("onSavingPath", map);
    }

    private void stopNormalRecording() {
        if (mRecorder != null) {
            mRecorder.stop();
            mRecorder.reset();
            mRecorder.release();
            mRecorder = null;
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

        // int vuSize = 10 * mMediaRecorder.getMaxAmplitude() / 32768;
        int ratio = mRecorder.getMaxAmplitude() / BASE;
        int db = 0;// 分贝
        if (ratio > 1) {
            db = (int) (20 * Math.log10(ratio));
        }
        int level = 0;
        switch (db / 4) {
            case 0:
                level = 0;
                break;
            case 1:
                level = 1;
                break;
            case 2:
                level = 2;
                break;
            case 3:
                level = 3;
                break;
            case 4:
                level = 4;
                break;
            case 5:
                level = 5;
                break;
            default:
                level = 5;
                break;
        }
        HashMap<String, Integer> map = new HashMap<String, Integer>();
        map.put("amplitude", level);
        callFlutter("onAmplitude", map);
        if (mChannel != null && registrar != null && registrar.activity() != null) {
            mHandler.postDelayed(mUpdateMicStatusTimer, 100);
        }
        /*
         * if (db > 1) { vuSize = (int) (20 * Math.log10(db)); Log.i("mic_",
         * "麦克风的音量的大小：" + vuSize); } else Log.i("mic_", "麦克风的音量的大小：" + 0);
         */
    }

    private void callFlutter(String method, Map map) {
        if (mChannel != null && registrar != null && registrar.activity() != null) {
            registrar.activity().runOnUiThread(() -> {
                mChannel.invokeMethod(method, map);
            });
        }
    }


    private void stopWavRecording() {
        wavRecorder.stopRecording();
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