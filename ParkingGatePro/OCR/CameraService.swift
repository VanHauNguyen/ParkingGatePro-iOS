//
//  CameraService.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import AVFoundation
import Vision

final class CameraService: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "parking.camera.session")
    private let frameQueue = DispatchQueue(label: "parking.camera.frames")

    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false

    // Throttle & lock
    private var isRecognizing = false
    private var lastRecognizeAt: CFTimeInterval = 0
    private let recognizeInterval: CFTimeInterval = 0.25

    var onText: ((String) -> Void)?

    func makeSession() -> AVCaptureSession { session }

    func start() {
        checkPermission { [weak self] ok in
            guard ok else { return }
            self?.sessionQueue.async { [weak self] in
                guard let self else { return }
                if !self.isConfigured { self.configure() }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func checkPermission(_ done: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            done(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                done(granted)
            }
        default:
            done(false)
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            session.commitConfiguration()
            return
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let conn = videoOutput.connection(with: .video) {
            conn.videoOrientation = .portrait
        }

        session.commitConfiguration()
        isConfigured = true
    }

    private func recognize(_ pb: CVPixelBuffer) {
        let req = VNRecognizeTextRequest { [weak self] r, _ in
            guard let self else { return }

            let obs = (r.results as? [VNRecognizedTextObservation]) ?? []
            let text = obs
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")

            DispatchQueue.main.async {
                self.onText?(text)
                self.isRecognizing = false
            }
        }

        //  Settings tối ưu hơn cho biển số
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.recognitionLanguages = ["en-US"]    // biển số chủ yếu A-Z 0-9
        req.minimumTextHeight = 0.04            // bỏ chữ nhỏ (background)

        //  ROI: chỉ scan vùng “giữa dưới” (thường biển số nằm đây trong frame)
        // Vision ROI dùng normalized coords, origin ở bottom-left
        req.regionOfInterest = CGRect(x: 0.08, y: 0.25, width: 0.84, height: 0.40)

        let handler = VNImageRequestHandler(cvPixelBuffer: pb, orientation: .up)
        do {
            try handler.perform([req])
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isRecognizing = false
            }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        let now = CACurrentMediaTime()
        guard now - lastRecognizeAt >= recognizeInterval else { return }
        guard !isRecognizing else { return }

        lastRecognizeAt = now
        isRecognizing = true

        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isRecognizing = false
            return
        }

        recognize(pb)
    }
}
