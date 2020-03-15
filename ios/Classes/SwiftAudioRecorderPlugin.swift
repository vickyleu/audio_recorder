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
        case "start":
            print("start")
            let dic = call.arguments as! [String: Any]
            mExtension = dic["extension"] as? String ?? ""
            mPath = dic["path"] as? String ?? ""
            startTime = Date()
            if mPath == "" {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                mPath = documentsPath + "/" + String(Int(startTime.timeIntervalSince1970)) + ".m4a"
            }
            print("path: " + mPath)
            let settings = [
                AVFormatIDKey: getOutputFormatFromString(mExtension),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
                try AVAudioSession.sharedInstance().setActive(true)
                audioRecorder = try AVAudioRecorder(url: URL(string: mPath)!, settings: settings)
                audioRecorder.delegate = self
                audioRecorder.record()
                self.voiceTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector:#selector(SwiftAudioRecorderPlugin.updateMicStatus), userInfo: nil, repeats: true)
                RunLoop.current.add(self.voiceTimer, forMode: RunLoopMode.commonModes)
                self.voiceTimer.fireDate = Date.distantPast
            } catch {
                print("fail")
                result(FlutterError(code: "", message: "Failed to record", details: nil))
            }
            isRecording = true
            result(nil)
        case "stop":
            print("stop")
            audioRecorder.stop()
            audioRecorder = nil
            let duration = Int(Date().timeIntervalSince(startTime as Date) * 1000)
            isRecording = false
            var recordingResult = [String: Any]()
            recordingResult["duration"] = duration
            recordingResult["path"] = mPath
            recordingResult["audioOutputFormat"] = mExtension
            result(recordingResult)
            if ((self.voiceTimer) != nil) {
                self.voiceTimer.fireDate = Date.distantFuture
                if (self.voiceTimer.isValid) {
                    self.voiceTimer.invalidate()
                }
                self.voiceTimer = nil
            }
            if(mPath != ""){
                let map = ["path":mPath];
                mPath = "";
                callFlutter(method: "onSavingPath", map: map)
            }
        case "isRecording":
            print("isRecording")
            result(isRecording)
        case "hasPermissions":
            print("hasPermissions")
            switch AVAudioSession.sharedInstance().recordPermission(){
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
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func getOutputFormatFromString(_ format: String) -> Int {
        switch format {
        case ".mp4", ".aac", ".m4a":
            return Int(kAudioFormatMPEG4AAC)
        default:
            return Int(kAudioFormatMPEG4AAC)
        }
    }

    @objc func updateMicStatus() {
        if (self.audioRecorder == nil) {
            return
        }
//        let voice = pow(10, (0.05 * self.audioRecorder.peakPower(forChannel: 0)));
//        NSLog(@"voice: %f", voice);
//        // int vuSize = 10 * mMediaRecorder.getMaxAmplitude() / 32768;
        let  ratio = self.audioRecorder.peakPower(forChannel: 0) / 32768
        var db = 0;
        // 分贝
        if (ratio > 1) {
            db = (Int)(20.0 * log10(ratio))
        }
        var level = 0;
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
        let map = ["amplitude": level]
        callFlutter(method: "onAmplitude", map: map)
    }
    
    func callFlutter(method:String,map:Dictionary<String,Any>){
        if((self.mChannel) != nil){
            mChannel.invokeMethod(method, arguments: map)
        }
    }

}
