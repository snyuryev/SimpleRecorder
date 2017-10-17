//
//  ContentViewController.swift
//  SimpleRecorder
//
//  Created by Sergey Yuryev on 17/10/2017.
//  Copyright © 2017 syuryev. All rights reserved.
//

import UIKit

class ContentViewController: UIViewController {

    // MARK: - Outlets
    
    /// Allow to select recording type
    @IBOutlet weak var recordType: UISegmentedControl!
    
    /// View with recordings
    @IBOutlet weak var recordingsView: UIView!
    
    /// View with recorder
    @IBOutlet weak var recorderView: UIView!
    
    private var recordingsViewController: RecordingsViewController? {
        get {
            return childViewControllers.flatMap({ $0 as? RecordingsViewController }).first
        }
    }
    
    private var recorderViewController: RecorderViewController? {
        get {
            return childViewControllers.flatMap({ $0 as? RecorderViewController }).first
        }
    }
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setup()
    }

    
    // MARK: - Setup
    
    private func setup() {
        let defaults = UserDefaults.standard
        let selected = defaults.integer(forKey: kSimpleRecordingAutoRecordingKey)
        self.recordType.selectedSegmentIndex = selected
        
        if let recorder = self.recorderViewController {
            recorder.delegate = self
        }
        if let recordings = self.recordingsViewController {
            recordings.delegate = self
        }
    }
    
    
    // MARK: - Actions
    
    @IBAction func recordTypeChanged(_ sender: Any) {
        let selected = self.recordType.selectedSegmentIndex
        let defaults = UserDefaults.standard
        defaults.set(selected, forKey: kSimpleRecordingAutoRecordingKey)
        defaults.synchronize()
    }
}

extension ContentViewController: RecorderViewControllerDelegate {
    func didStartRecording() {
        if let recordings = self.recordingsViewController {
            recordings.fadeView.isHidden = false
            UIView.animate(withDuration: 0.25, animations: {
                recordings.fadeView.alpha = 1
            })
        }
    }
    
    func didFinishRecording() {
        if let recordings = self.recordingsViewController {
            recordings.view.isUserInteractionEnabled = true
            UIView.animate(withDuration: 0.25, animations: {
                recordings.fadeView.alpha = 0
            }, completion: { (finished) in
                if finished {
                    recordings.fadeView.isHidden = true
                    DispatchQueue.main.async {
                        recordings.loadRecordings()
                    }
                }
            })
        }
    }
    
    func didAddRecording() {
        if let recordings = self.recordingsViewController {
            DispatchQueue.main.async {
                recordings.loadRecordings()
            }
        }
    }
}

extension ContentViewController: RecordingsViewControllerDelegate {
    func didStartPlayback() {
        if let recorder = self.recorderViewController {
            recorder.fadeView.isHidden = false
            UIView.animate(withDuration: 0.25, animations: {
                recorder.fadeView.alpha = 1
            })
        }
    }
    
    func didFinishPlayback() {
        if let recorder = self.recorderViewController {
            recorder.view.isUserInteractionEnabled = true
            UIView.animate(withDuration: 0.25, animations: {
                recorder.fadeView.alpha = 0
            }, completion: { (finished) in
                if finished {
                    recorder.fadeView.isHidden = true
                }
            })
        }
    }
}
