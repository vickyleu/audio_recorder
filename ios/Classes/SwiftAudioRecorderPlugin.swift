import Flutter
import UIKit
import AVFoundation


public class SwiftAudioRecorderPlugin: NSObject, FlutterPlugin, AVAudioRecorderDelegate {
    var isRecording = false
    var hasPermissions = false
    var mExtension = ""
    var mPath = ""
    var startTime: Date!
    var mChannel: FlutterMethodChannel!
    var mCall: FlutterMethodCall!
    var voiceTimer: Timer!
    var audioRecorder: AVAudioRecorder!
    
    private  let encoderQueue = DispatchQueue(label: "com.audio.encoder.queue")
    
    
    init(channel: FlutterMethodChannel) {
        self.mChannel = channel
        super.init()
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "audio_recorder", binaryMessenger: registrar.messenger())
        let instance = SwiftAudioRecorderPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.mCall = call
        switch call.method {
            case "convertMp3":
                let dic = call.arguments as! [String: Any]
                encodeToMp3(inPcmPath: (dic["pcm"] as? String ?? ""), outMp3Path: (dic["path"] as? String ?? "")) { (Float) -> (Void) in
                    
                } onComplete: {
                    result((dic["path"] as? String ?? ""))
                }
            break
            case "start":
                let dic = call.arguments as! [String: Any]
                mExtension = dic["extension"] as? String ?? ""
                mPath = dic["path"] as? String ?? ""
                startTime = Date()
                if mPath == "" {
                    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                    mPath = documentsPath + "/" + String(Int(startTime.timeIntervalSince1970)) + ".m4a"
                }
                let fileManager = FileManager.default
                let exist = fileManager.fileExists(atPath: mPath)
                let url=URL(string: mPath)!
                if exist {
                    try! fileManager.removeItem(at: url)
                }
                
                let settings = [
                    AVSampleRateKey:44100,
                    AVNumberOfChannelsKey:1,
                    AVLinearPCMBitDepthKey:16,
                    AVEncoderBitRateKey:128000,
                    AVLinearPCMIsBigEndianKey:0,
                    AVLinearPCMIsFloatKey:0,
                    AVEncoderAudioQualityKey:AVAudioQuality.max.rawValue,
                    AVFormatIDKey:getOutputFormatFromString(mExtension),
                ]
                
                do {
                    let session = AVAudioSession.sharedInstance()
                    if(session.recordPermission != AVAudioSession.RecordPermission.granted){
                        session.requestRecordPermission({(suc) in
                            
                        })
                        result(FlutterError(code: "", message: "Failed to record,not prepared 33", details: nil))
                        return
                    }
                    try session.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playAndRecord)))
                    try session.overrideOutputAudioPort(.speaker)
                    try session.setActive(true)
                    
                    
                    self.audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                    self.audioRecorder.delegate = self
                    self.audioRecorder.isMeteringEnabled = true
                    
                    let prepared=self.audioRecorder.prepareToRecord()
                    if(prepared){
                        self.audioRecorder.record()
                        self.audioRecorder.updateMeters()
                        self.voiceTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector:#selector(self.updateMicStatus), userInfo: nil, repeats: true)
                        RunLoop.current.add(self.voiceTimer, forMode:RunLoop.Mode.common)
                        self.voiceTimer.fireDate = Date.distantPast
                    }else{
                        result(FlutterError(code: "", message: "Failed to record,not prepared 33", details: nil))
                        return
                    }
                } catch let err{
                    print("fail",err.localizedDescription)
                    result(FlutterError(code: "", message: "Failed to record", details: nil))
                }
                isRecording = true
                result(nil)
                break
            case "stop":
                if(!isRecording){
                    return
                }
                if((audioRecorder) != nil){
                    audioRecorder.pause()
                    try? AVAudioSession.sharedInstance().setActive(false)
                    audioRecorder.stop()
                    audioRecorder = nil
                    let duration = Int(Date().timeIntervalSince(startTime as Date) * 1000)
                    isRecording = false
                    var recordingResult = [String: Any]()
                    recordingResult["duration"] = duration
                    recordingResult["path"] = mPath
                    recordingResult["audioOutputFormat"] = mExtension
                    mPath = "";
                    result(recordingResult)
                    if ((self.voiceTimer) != nil) {
                        self.voiceTimer.fireDate = Date.distantFuture
                        if (self.voiceTimer.isValid) {
                            self.voiceTimer.invalidate()
                        }
                        self.voiceTimer = nil
                    }
            }
                break
            case "isRecording":
                print("isRecording")
                result(isRecording)
                break
            case "hasPermissions":
                print("hasPermissions")
                switch AVAudioSession.sharedInstance().recordPermission{
                    case AVAudioSession.RecordPermission.granted:
                        print("granted")
                        hasPermissions = true
                        break
                    case AVAudioSession.RecordPermission.denied:
                        print("denied")
                        hasPermissions = false
                        break
                    case AVAudioSession.RecordPermission.undetermined:
                        print("undetermined")
                        AVAudioSession.sharedInstance().requestRecordPermission() { [unowned self] allowed in
                            DispatchQueue.main.async {
                                if allowed {
                                    self.hasPermissions = true
                                } else {
                                    self.hasPermissions = false
                                }
                            }
                        }
                        break
                    default:
                        break
                }
                result(hasPermissions)
                break
            default:
                result(FlutterMethodNotImplemented)
                break
        }
    }
    
    func getOutputFormatFromString(_ format: String) -> Int {
        switch format {
            case ".mp4", ".aac", ".m4a":
                return Int(kAudioFormatMPEG4AAC)
            default:
                return Int(kAudioFormatLinearPCM)
        }
    }
    
    @objc func updateMicStatus() {
        if (self.audioRecorder == nil) {
            return
        }
        self.audioRecorder.updateMeters()
        let ratio = pow(10, (0.05 * self.audioRecorder.peakPower(forChannel: 0)));
        var level = 0;
        if (ratio > 0.1 && ratio < 0.2) {
            level=2;
        } else if (ratio > 0.2 && ratio < 0.3) {
            level=3;
        } else if (ratio > 0.3 && ratio < 0.4) {
            level=4;
        } else if (ratio > 0.4 && ratio < 0.5) {
            level=5;
        } else if (ratio > 0.5 && ratio < 0.6) {
            level=6;
        } else if (ratio > 0.6 && ratio < 0.7) {
            level=7;
        } else if (ratio > 0.7) {
            level=7;
        } else {
            level=1;
        }
        let map = ["amplitude": level]
        callFlutter(method: "onAmplitude", map: map)
        let duration = Double(Date().timeIntervalSince(startTime as Date) * 1000)
        let map2 = ["duration": duration]
        callFlutter(method: "onDuration", map: map2)
        
    }
    
    func callFlutter(method:String,map:Dictionary<String,Any>){
        if((self.mChannel) != nil){
            mChannel.invokeMethod(method, arguments: map)
        }
    }
    
    
    func encodeToMp3(
            inPcmPath: String,outMp3Path: String,
            onProgress: @escaping (Float) -> (Void),onComplete: @escaping () -> (Void) ) {
            encoderQueue.async {
                let lame = lame_init()
                lame_set_in_samplerate(lame, 44100)
               // lame_set_out_samplerate(lame, 0)
               // lame_set_brate(lame, 0)
               // lame_set_quality(lame, 4)
                lame_set_VBR(lame, vbr_default)
                lame_init_params(lame)
                lame_set_num_channels(lame,1)

                let pcmFile: UnsafeMutablePointer<FILE> = fopen(inPcmPath, "rb")
                fseek(pcmFile, 0 , SEEK_END)
                let fileSize = ftell(pcmFile)
                // Skip file header.
                let fileHeader = 4 * 1024
                fseek(pcmFile, fileHeader, SEEK_SET)

                let mp3File: UnsafeMutablePointer<FILE> = fopen(outMp3Path, "wb+")

                let pcmSize = 1024 * 8
                let pcmbuffer = UnsafeMutablePointer<Int16>.allocate(capacity: Int(pcmSize * 2))

                let mp3Size: Int32 = 1024 * 8
                let mp3buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(mp3Size))
                var write: Int32 = 0
                var read = 0
                repeat {
                    let size = MemoryLayout<Int16>.size * 2
                    read = fread(pcmbuffer, size, pcmSize, pcmFile)
                    // Progress
                    if read != 0 {
                        let progress = Float(ftell(pcmFile)) / Float(fileSize)
                        DispatchQueue.main.sync { onProgress(progress) }
                    }

                    if read == 0 {
                        write = lame_encode_flush(lame, mp3buffer, mp3Size)
                    } else {
                        write = lame_encode_buffer(lame, pcmbuffer,pcmbuffer, Int32(read), mp3buffer, mp3Size);//***单声道写入
                        //write = lame_encode_buffer_interleaved(lame, pcmbuffer, Int32(read), mp3buffer, mp3Size)
                    }

                    fwrite(mp3buffer, Int(write), 1, mp3File)

                } while read != 0

                // Clean up
                lame_close(lame)
                fclose(mp3File)
                fclose(pcmFile)
                pcmbuffer.deallocate()
                mp3buffer.deallocate()
                DispatchQueue.main.sync { onComplete() }
            }
        }
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
