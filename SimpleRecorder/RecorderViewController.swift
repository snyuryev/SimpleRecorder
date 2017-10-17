//
//  RecorderViewController.swift
//  SimpleRecorder
//
//  Created by Sergey Yuryev on 12/10/2017.
//  Copyright © 2017 syuryev. All rights reserved.
//

import UIKit
import AVFoundation
import Accelerate

enum RecorderState {
    case recording
    case stopped
    case denied
}

let kSimpleRecordingAutoRecordingKey = "kSimpleRecordingAutoRecordingKey"

protocol RecorderViewControllerDelegate: class {
    func didStartRecording()
    func didAddRecording()
    func didFinishRecording()
}

class RecorderViewController: UIViewController {

    // MARK: - Vars
    
    /// Recording format
    let settings = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: true,
        AVSampleRateKey: Float64(44100),
        AVNumberOfChannelsKey: 1
        ] as [String : Any]

    /// Audio engine for recording
    let audioEngine = AVAudioEngine()
    
    /// Render timestamp
    private var renderTs: Double = 0
    
    /// Recording timestamp
    private var recordingTs: Double = 0
    
    /// Silence timestamp
    private var silenceTs: Double = 0
    
    /// File to write recording audio
    private var audioFile: AVAudioFile?
    
    /// Recorder delegate
    weak var delegate: RecorderViewControllerDelegate?
    
    // MARK: - Outlets
    
    /// Fade view
    @IBOutlet weak var fadeView: UIView!
    
    /// Info about recording
    @IBOutlet weak var infoLabel: UILabel!
    
    /// Time of recording
    @IBOutlet weak var timeLabel: UILabel!
    
    /// Audio plot
    @IBOutlet weak var recorderPlot: AudioPlotView!
    
    /// Start/stop recording button
    @IBOutlet weak var recordButton: UIButton!
    
    /// Display settings message
    @IBOutlet weak var settingsLabel: UILabel!
    
    /// Opens settings
    @IBOutlet weak var settingsButton: UIButton!
    
    /// Buttons to show results
    @IBOutlet weak var resultsButton: UIButton!
    
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let name = Notification.Name.AVAudioSessionInterruption
        NotificationCenter.default.addObserver(self, selector: #selector(self.interruption(notification:)), name: name, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.checkAutoAndRecord()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewWillDisappear(animated)
    }
    
    
    // MARK: - Actions
    
    @IBAction func settingsButtonTap(_ sender: Any) {
        let url = URL(string: UIApplicationOpenSettingsURLString)!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    @IBAction func recordButtonTap(_ sender: Any) {
        if self.isRecording() {
            self.stopRecording()
        }
        else {
            self.checkPermissionAndRecord()
        }
    }
    
    
    // MARK: - UI stuff
    
    private func updateUI(_ recorderState: RecorderState) {
        switch recorderState {
        case .recording:
            UIApplication.shared.isIdleTimerDisabled = true
            self.recordButton.setImage(UIImage(named:"stop.png"), for: .normal)
            self.recordButton.isHidden = false
            self.settingsLabel.isHidden = true
            self.settingsButton.isHidden = true
            self.recorderPlot.isHidden = false
            self.timeLabel.isHidden = false
            self.infoLabel.isHidden = true
            self.resultsButton.isHidden = true
            break
        case .stopped:
            UIApplication.shared.isIdleTimerDisabled = false
            self.recordButton.setImage(UIImage(named:"start.png"), for: .normal)
            self.recordButton.isHidden = false
            self.settingsLabel.isHidden = true
            self.settingsButton.isHidden = true
            self.recorderPlot.isHidden = true
            self.timeLabel.isHidden = true
            self.infoLabel.isHidden = false
            self.resultsButton.isHidden = false
            break
        case .denied:
            UIApplication.shared.isIdleTimerDisabled = false
            self.recordButton.isHidden = true
            self.settingsLabel.isHidden = false
            self.settingsButton.isHidden = false
            self.recorderPlot.isHidden = true
            self.timeLabel.isHidden = true
            self.infoLabel.isHidden = true
            self.resultsButton.isHidden = true
            break
        }
    }
    
    
    // MARK: - Recording
    
    private func startRecording() {
        if let d = self.delegate {
            d.didStartRecording()
        }
        
        self.recordingTs = NSDate().timeIntervalSince1970
        self.silenceTs = 0 
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch let error as NSError {
            print(error.localizedDescription)
            return
        }
        
        let inputNode = self.audioEngine.inputNode
        guard let format = self.format() else {
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, time) in
            let level: Float = -50
            let length: UInt32 = 1024
            buffer.frameLength = length
            let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
            var value: Float = 0
            vDSP_meamgv(channels[0], 1, &value, vDSP_Length(length))
            var average: Float = ((value == 0) ? -100 : 20.0 * log10f(value))
            if average > 0 {
                average = 0
            }
            else if average < -100 {
                average = -100
            }
            let silent = average < level
            let ts = NSDate().timeIntervalSince1970
            if ts - self.renderTs > 0.1 {
                let floats = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
                let frame = floats.map({ (f) -> Int in
                    return Int(f * Float(Int16.max))
                })
                DispatchQueue.main.async {
                    let seconds = (ts - self.recordingTs)
                    self.timeLabel.text = seconds.toTimeString
                    self.renderTs = ts
                    let len = self.recorderPlot.waveforms.count
                    for i in 0 ..< len {
                        let idx = ((frame.count - 1) * i) / len
                        let f: Float = sqrt(1.5 * abs(Float(frame[idx])) / Float(Int16.max))
                        self.recorderPlot.waveforms[i] = min(49, Int(f * 50))
                    }
                    self.recorderPlot.active = !silent
                    self.recorderPlot.setNeedsDisplay()
                }
            }
            
            var write = false
            if silent {
                if ts - self.silenceTs < 0.25 && self.silenceTs > 0 {
                    write = true
                }
                else {
                    self.audioFile = nil
                    if let d = self.delegate {
                        d.didAddRecording()
                    }
                }
            }
            else {
                write = true
                self.silenceTs = ts
            }
            
            if write {
                if self.audioFile == nil {
                    self.audioFile = self.createAudioRecordFile()
                }
                if let f = self.audioFile {
                    do {
                        try f.write(from: buffer)
                    }
                    catch let error as NSError {
                        print(error.localizedDescription)
                    }
                }
            }
        }
        do {
            self.audioEngine.prepare()
            try self.audioEngine.start()
        } catch let error as NSError {
            print(error.localizedDescription)
            return
        }
        self.updateUI(.recording)
    }
    
    private func stopRecording() {
        if let d = self.delegate {
            d.didFinishRecording()
        }
        
        self.audioFile = nil
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.audioEngine.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch  let error as NSError {
            print(error.localizedDescription)
            return
        }
        self.updateUI(.stopped)
    }
    
    private func checkAutoAndRecord() {
        let defaults = UserDefaults.standard
        let selected = defaults.integer(forKey: kSimpleRecordingAutoRecordingKey)
        if selected > 0 {
            self.checkPermissionAndRecord()
        }
    }
    
    private func checkPermissionAndRecord() {
        let permission = AVAudioSession.sharedInstance().recordPermission()
        switch permission {
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ (result) in
                DispatchQueue.main.async {
                    if result {
                        self.startRecording()
                    }
                    else {
                        self.updateUI(.denied)
                    }
                }
            })
            break
        case .granted:
            self.startRecording()
            break
        case .denied:
            self.updateUI(.denied)
            break
        }
    }
    
    private func isRecording() -> Bool {
        if self.audioEngine.isRunning {
            return true
        }
        return false
    }
    
    private func format() -> AVAudioFormat? {
        let format = AVAudioFormat(settings: self.settings)
        return format
    }
    
    
    // MARK: - Paths and files
    
    private func createAudioRecordPath() -> URL? {
        let format = DateFormatter()
        format.dateFormat="yyyy-MM-dd-HH-mm-ss-SSS"
        let currentFileName = "recording-\(format.string(from: Date()))" + ".wav"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentsDirectory.appendingPathComponent(currentFileName)
        return url
    }
    
    private func createAudioRecordFile() -> AVAudioFile? {
        guard let path = self.createAudioRecordPath() else {
            return nil
        }
        do {
            let file = try AVAudioFile(forWriting: path, settings: self.settings, commonFormat: .pcmFormatFloat32, interleaved: true)
            return file
        }
        catch let error as NSError {
            print(error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Interruption
    
    @objc func interruption(notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        guard let key = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber else {
            return
        }
        if key.intValue == 1 {
            DispatchQueue.main.async {
                if self.isRecording() {
                    self.stopRecording()
                }
            }
        }
    }


}

