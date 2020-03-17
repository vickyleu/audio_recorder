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
                    AVLinearPCMBitDepthKey:32,
                    AVEncoderBitRateKey:128000,
                    AVEncoderAudioQualityKey:AVAudioQuality.max.rawValue,
                    AVFormatIDKey:getOutputFormatFromString(mExtension),
                ]
                
                do {
                    let session = AVAudioSession.sharedInstance()
                    if(session.recordPermission != .granted){
                        session.requestRecordPermission({(suc) in
                            
                        })
                        result(FlutterError(code: "", message: "Failed to record,not prepared 33", details: nil))
                        return
                    }
                    try session.setCategory(.playAndRecord)
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
                        RunLoop.current.add(self.voiceTimer, forMode: RunLoop.Mode.common)
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
            
            case "isRecording":
                print("isRecording")
                result(isRecording)
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
    
}
