//
// Created by vicky Leu on 3/26/21.
//
#include <string.h>
#include"stdio.h"
#include"jni.h"
#include"lamemp3/lame.h"
#include"android/log.h"
#define LOG_TAG "lameUtils"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)


static lame_global_flags *lame = NULL;
long nowConvertBytes = 0;

void resetLame() {
    if (lame != NULL) {
        lame_close(lame);
        lame = NULL;
    }
}


unsigned char* convertJByteArrayToChars(JNIEnv *env, jbyteArray bytearray)
{
    unsigned char *chars = NULL;
    jbyte *bytes;
    bytes = env->GetByteArrayElements(bytearray, 0);
    int chars_len = env->GetArrayLength(bytearray);
    chars = new unsigned char[chars_len + 1];
    memset(chars,0,chars_len + 1);
    memcpy(chars, bytes, chars_len);
    chars[chars_len] = 0;
    env->ReleaseByteArrayElements(bytearray, bytes, 0);
    return chars;
}

void lameInit(jint inSampleRate,
              jint channel, jint mode, jint outSampleRate,
              jint outBitRate, jint quality) {
    resetLame();
    lame = lame_init();
    lame_set_in_samplerate(lame, inSampleRate);
    lame_set_out_samplerate(lame, outSampleRate);
    lame_set_brate(lame, outBitRate);
    lame_set_quality(lame, quality);
    lame_set_mode(lame,MONO);
    lame_set_num_channels(lame,channel);
    if(mode == 0) { // use CBR
        lame_set_VBR(lame, vbr_default);
    } else if(mode == 1){ //use VBR
        lame_set_VBR(lame, vbr_abr);
    } else{ // use ABR
        lame_set_VBR(lame, vbr_mtrh);
    }
    lame_set_VBR_quality(lame,2);


    lame_init_params(lame);

}
#define BUFFER_SIZE 1024 * 8
extern "C" JNIEXPORT void JNICALL
Java_com_vickyleu_audiorecorder_MP3Recorder_init(JNIEnv *env, jclass type, jint inSampleRate,
                                                jint channel, jint mode, jint outSampleRate,
                                                jint outBitRate, jint quality) {
    lameInit(inSampleRate, channel, mode, outSampleRate, outBitRate, quality);
}

extern "C" JNIEXPORT
void JNICALL Java_com_vickyleu_audiorecorder_MP3Recorder_convertMp3
        (JNIEnv * env, jclass obj, jstring jInputPath, jstring jMp3Path) {
    const char* cInput = env->GetStringUTFChars(jInputPath, 0);
    const char* cMp3 = env->GetStringUTFChars(jMp3Path, 0);

    //open input file and output file
    FILE* fInput = fopen(cInput,"rb");
    FILE* fMp3 = fopen(cMp3,"wb+");

    fseek(fInput, 0 , SEEK_END);
    int fileSize = ftell(fInput);
    //Skip file header.
    int fileHeader = 4 * 1024;
    fseek(fInput, fileHeader, SEEK_SET);


    short int pcmbuffer[BUFFER_SIZE];
    unsigned char mp3Buffer[fileSize];//You must specified at least 7200
    int read = 0; // number of bytes in pcmbuffer, if in the end return 0
    int write = 0;// number of bytes output in mp3buffer.  can be 0
    long total = 0; // the bytes of reading input file
    nowConvertBytes = 0;
    //if you don't init lame, it will init lame use the default value
    if(lame == NULL){
        lameInit(44100, 2, 0, 44100, 96, 7);
    }

    //convert to mp3
    do{
        read = static_cast<int>(fread(pcmbuffer, sizeof(short int), BUFFER_SIZE, fInput));
        total +=  read * sizeof(short int);
        nowConvertBytes = total;
        if(read != 0){
            write = lame_encode_buffer(lame, pcmbuffer, nullptr, read, mp3Buffer, BUFFER_SIZE);//***单声道写入
            //write = lame_encode_buffer_interleaved(lame, pcmbuffer, read, mp3Buffer, BUFFER_SIZE);
            //write the converted buffer to the file
            fwrite(mp3Buffer, 1, static_cast<size_t>(write), fMp3);
        }
        //if in the end flush
        if(read == 0){
            lame_encode_flush(lame,mp3Buffer, BUFFER_SIZE);
        }
    }while(read != 0);

    //release resources
    resetLame();
    fclose(fInput);
    fclose(fMp3);
    env->ReleaseStringUTFChars(jInputPath, cInput);
    env->ReleaseStringUTFChars(jMp3Path, cMp3);
    nowConvertBytes = -1;
}

extern "C" JNIEXPORT int JNICALL
Java_com_vickyleu_audiorecorder_MP3Recorder_encode(
        JNIEnv * env, jclass cls, jshortArray buffer_l, jshortArray buffer_r,
        jint samples, jbyteArray mp3buf) {
    jshort* j_buffer_l = env->GetShortArrayElements(buffer_l, NULL);

    jshort* j_buffer_r = env->GetShortArrayElements(buffer_r, NULL);

    const jsize mp3buf_size = env->GetArrayLength(mp3buf);
    unsigned char * c_mp3buf = convertJByteArrayToChars(env, mp3buf);
    int result = lame_encode_buffer(lame, j_buffer_l, j_buffer_r,
                                    samples, c_mp3buf, mp3buf_size);

    env-> ReleaseShortArrayElements(buffer_l, j_buffer_l, 0);
    env->ReleaseShortArrayElements(buffer_r, j_buffer_r, 0);
    *c_mp3buf = NULL;
    return result;
}



extern "C" JNIEXPORT int JNICALL
Java_com_vickyleu_audiorecorder_MP3Recorder_flush(
        JNIEnv *env, jclass cls, jbyteArray mp3buf) {
    const jsize mp3buf_size = env->GetArrayLength(mp3buf);
    unsigned char * c_mp3buf = convertJByteArrayToChars(env, mp3buf);

    int result = lame_encode_flush(lame, c_mp3buf, mp3buf_size);

    *c_mp3buf = NULL;
    return result;
}

extern "C" JNIEXPORT void JNICALL
Java_com_vickyleu_audiorecorder_MP3Recorder_close
        (JNIEnv *env, jclass cls) {
    lame_close(lame);
    lame = NULL;
}


extern "C" JNIEXPORT jstring JNICALL
Java_com_vickyleu_audiorecorder_MP3Recorder_getLameVersion(
        JNIEnv *env, jclass clazz) {
    return env->NewStringUTF(get_lame_version());
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_vickyleu_audiorecorder_MP3Recorder_getConvertBytes(JNIEnv *env, jclass type) {
//    LOGD("convert bytes%d", nowConvertBytes);
    return nowConvertBytes;
}