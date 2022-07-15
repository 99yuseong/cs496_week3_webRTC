//
//  WebRtcClient.swift
//  week3
//
//  Created by Chanwoo on 2022/07/14.
//

import Foundation
import WebRTC
import FirebaseFirestore

let kARDMedaiStreamId = "ARDAMS"
let kARDAudioTrackId = "ARDAMSa0"
let kARDVideoTrackId = "ARDAMSv0"
let kARDVideoTrackKind = "video"


// encoding, decoding 하기 위해 새로 codable struct 만듦 (RTCIceCandidate, RTCSdpType, RTCSessionDescription은 decodable)
struct IceCandidate: Codable {
    let candidate: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
    
    init(from iceCandidate: RTCIceCandidate) {
        self.sdpMLineIndex = iceCandidate.sdpMLineIndex
        self.sdpMid = iceCandidate.sdpMid
        self.candidate = iceCandidate.sdp
    }
    
    var rtcIceCandidate: RTCIceCandidate {
        return RTCIceCandidate(sdp: self.candidate, sdpMLineIndex: self.sdpMLineIndex, sdpMid: self.sdpMid)
    }
}

struct SessionDescription: Codable {
    enum SdpType: String, Codable {
        case offer, answer, prAnswer
        
        var rtcSdpType: RTCSdpType {
            switch self {
            case .offer:    return .offer
            case .answer:   return .answer
            case .prAnswer: return .prAnswer
            }
        }
    }

    let sdp: String
    let type: SdpType
    
    init(from rtcSessionDescription: RTCSessionDescription) {
        self.sdp = rtcSessionDescription.sdp
        switch rtcSessionDescription.type {
            case .offer:    self.type = .offer
            case .prAnswer: self.type = .prAnswer
            case .answer:   self.type = .answer
            @unknown default:
                fatalError("Unknown RTCSessionDescription type: \(rtcSessionDescription.type.rawValue)")
        }
    }
    
    var rtcSessionDescription: RTCSessionDescription {
        return RTCSessionDescription(type: self.type.rtcSdpType, sdp: self.sdp)
    }
}

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    
    func webRTCClient(_ client: WebRTCClient, didChangeIceConnection newState: RTCIceConnectionState)
    
    func webRTCClient(_ client: WebRTCClient, didAdd stream: RTCMediaStream)
    
    func webRTCClient(_ client: WebRTCClient, didCreateLocalCapturer capturer: RTCCameraVideoCapturer)
    
    func webRTCClient(_ client: WebRTCClient, didChangeSignaling newState: RTCSignalingState)
}

class WebRTCClient: NSObject {
    
    weak var delegate: WebRTCClientDelegate?
    
    static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    var peerConnection: RTCPeerConnection?
    let rtcAudioSession =  RTCAudioSession.sharedInstance()
    let audioQueue = DispatchQueue(label: "audio")
    let mediaConstrains = [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                           kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]
//    var videoCapturer: RTCVideoCapturer?
    var videoCapturer: RTCCameraVideoCapturer?
    var localVideoTrack: RTCVideoTrack?
    var remoteVideoTrack: RTCVideoTrack?
    var iceServers: [String] = ["stun:stun.l.google.com:19302",
                                "stun:stun1.l.google.com:19302",
                                "stun:stun2.l.google.com:19302",
                                "stun:stun3.l.google.com:19302",
                                "stun:stun4.l.google.com:19302"]
    
    var roomId: String?

    func createPeerConnection() {
        print("create peer connection")
        let rtcConfiguration = RTCConfiguration.init()
        rtcConfiguration.iceServers = [RTCIceServer.init(urlStrings: iceServers)]
        rtcConfiguration.sdpSemantics = .unifiedPlan
        rtcConfiguration.continualGatheringPolicy = .gatherContinually
//        rtcConfiguration.iceCandidatePoolSize = 10

        let rtcMediaConstraints = RTCMediaConstraints.init(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement":"true"])
        
        self.peerConnection = WebRTCClient.factory.peerConnection(with: rtcConfiguration, constraints: rtcMediaConstraints, delegate: self)
        
        self.createMediaSenders()
        self.configureAudioSession()
    }
    
    func closePeerConnection() {
        self.peerConnection!.close()
        self.peerConnection = nil
    }
    
    private func createMediaSenders() {
        print("create media senders")
        let audioConstraints = RTCMediaConstraints.init(mandatoryConstraints: [:], optionalConstraints: nil)
        let audioSource = WebRTCClient.factory.audioSource(with: audioConstraints)
        let audioTrack = WebRTCClient.factory.audioTrack(with: audioSource, trackId: kARDAudioTrackId)
        self.peerConnection!.add(audioTrack, streamIds: [kARDMedaiStreamId])
        
        let videoSource = WebRTCClient.factory.videoSource()
        
//        #if TARGET_OS_SIMULATOR
//        self.videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
//        #else
        self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
//        #endif
        
        let localVideoTrack = WebRTCClient.factory.videoTrack(with: videoSource, trackId: kARDVideoTrackId)
        self.localVideoTrack = localVideoTrack
        self.peerConnection!.add(localVideoTrack, streamIds: [kARDMedaiStreamId])
        
        self.delegate?.webRTCClient(self, didCreateLocalCapturer: videoCapturer!)
        
//        var videoTransceiver: WebRTC.RTCRtpTransceiver? = nil
//        for transceiver in self.peerConnection!.transceivers {
//            if (transceiver.mediaType == RTCRtpMediaType.video) {
//                videoTransceiver = transceiver
//                break
//            }
//        }
        self.remoteVideoTrack = self.peerConnection!.transceivers.first { $0.mediaType == .video }?.receiver.track as? RTCVideoTrack
        
    }
    
    func configureAudioSession() {
        print("configure audio session")
        self.rtcAudioSession.lockForConfiguration()
        do {
            try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try self.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        }
        catch let error {
            print("Error changing AVAudioSession category: \(error)")
        }
        self.rtcAudioSession.unlockForConfiguration()
    }
    
    func setAudioEnabled(_ isEnabled: Bool) {
        let audioTracks = self.peerConnection!.transceivers.compactMap { return $0.sender.track as? RTCAudioTrack }
        audioTracks.forEach { $0.isEnabled = isEnabled }
    }
    
    func startCaptureLocalVideo(renderer: RTCVideoRenderer, front: Bool) {
        print("start capture local video")
        
        guard let capturer = self.videoCapturer else {
            return
        }
        
        guard let camera = front ? (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }) : (RTCCameraVideoCapturer.captureDevices().first { $0.position == .back}),
          // choose highest res
          let format = (RTCCameraVideoCapturer.supportedFormats(for: camera).sorted { (f1, f2) -> Bool in
              let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
              let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
              return width1 < width2
          }).last,
          // choose highest fps
          let fps = (format.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else {
              return
          }
        capturer.startCapture(with: camera,
                              format: format,
                              fps: Int(fps.maxFrameRate))
        self.localVideoTrack?.add(renderer)
        
        print("local video track: \(String(describing: self.localVideoTrack))")
    }
  
    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        print("render remote video")
        self.remoteVideoTrack?.add(renderer)
        print(self.remoteVideoTrack!)
    }
    
    func createOffer(roomRef: DocumentReference, completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        print("create offer")
        
        self.peerConnection!.offer(for: RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains, optionalConstraints: nil),
                                      completionHandler: { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            self.peerConnection!.setLocalDescription(sdp, completionHandler: {
                (error) in completion(sdp)
            })
            
            let roomWithOffer = ["offer": ["type": "offer", "sdp": sdp.sdp]]
            
            roomRef.setData(roomWithOffer, completion: {
                (err) in
                    if let err = err {
                        print("Error send offer sdp: \(err)")
                    }
                    else {
                        print("New room created with SDP offer. Room ID: \(roomRef.documentID)")
                        self.roomId = roomRef.documentID
                    }
            })
        })
    }
    
    func createAnswer(roomRef: DocumentReference, completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        
        self.peerConnection!.answer(for: RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains, optionalConstraints: nil),
                                       completionHandler: { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            self.peerConnection!.setLocalDescription(sdp, completionHandler: {
                (error) in completion(sdp)
            })
            
            let roomWithAnswer = ["answer": ["type": "answer", "sdp": sdp.sdp]]
            roomRef.updateData(roomWithAnswer) { (err) in
                if let err = err {
                    print("Error send answer sdp: \(err)")
                }
                else {
                    print("Joined room with SDP answer. Room ID: \(roomRef.documentID)")
                    self.roomId = roomRef.documentID
                }
            }
        })
    }
    
    func sendCandidate(candidate: RTCIceCandidate) {
        if (self.roomId == nil) {
            print("roomRef nil이라서 send candidate fail")
            return
        }
        let roomRef = db.collection("rooms").document(self.roomId!)
        
        let candidatesCollection = roomRef.collection("calleeCandidates")
        print(candidatesCollection.collectionID)

        
        do {
            let dataMessage = try JSONEncoder().encode(IceCandidate(from: candidate))
            let dict = try JSONSerialization.jsonObject(with: dataMessage, options: .allowFragments) as! [String: Any]
            candidatesCollection.addDocument(data: dict) { (err) in
                if let err = err {
                    print("Error send candidate: \(err)")
                }
                else {
                    print("Candidate sent!")
                }
            }
        }
        catch {
            print("JSONSericalization caller candidate fail")
        }
    }
    
    func listenCallee(roomRef: DocumentReference) {
        // listen remote sdp
        roomRef.addSnapshotListener { snapshot, error in
            print("remote sdp snapshot")
            guard let document = snapshot else {
                print("Error fetching document: \(error!)")
                return
            }
            guard let data = document.data() else {
                print("Document data was empty.")
                return
            }
            if (self.peerConnection?.remoteDescription == nil && data["answer"] != nil) {
                do {
                    let answerJSON = try JSONSerialization.data(withJSONObject: data["answer"]!, options: .fragmentsAllowed)
                    let answerSDP = try JSONDecoder().decode(SessionDescription.self, from: answerJSON)
                    print("Got remote description (answerSDP)")
                    self.peerConnection!.setRemoteDescription(answerSDP.rtcSessionDescription,
                                                                      completionHandler: {(error) in
                        print("Warning: Could not set remote description: \(String(describing: error))")}
                    )
                }
                catch {
                    print("Warning: Could not decode sdp data: \(error)")
                    return
                }
            }
        }
        
        // listen remote candidate
        roomRef.collection("calleeCandidates").addSnapshotListener { snapshot, error in
            print("callee candidate snapshot")
            guard let documents = snapshot?.documents else {
                print("Error fetching document: \(error!)")
                return
            }
            
            snapshot!.documentChanges.forEach { diff in
                if (diff.type == .added) {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: diff.document.data(), options: .prettyPrinted)
                        let iceCandidate = try JSONDecoder().decode(IceCandidate.self, from: jsonData)
                        print("Got new remote ICE candidate: \(iceCandidate)")
                        self.peerConnection!.add(iceCandidate.rtcIceCandidate)
                    }
                    catch {
                        print("Warning: Could not decode candidate data: \(error)")
                        return
                    }
                }
            }
        }
    }
    
}


// MARK: - Peer Connection
extension WebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("peerConnection didChange signalingState: \(stateChanged.rawValue)")
        self.delegate?.webRTCClient(self, didChangeSignaling: stateChanged)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("peerConnection didAdd stream")
//        DispatchQueue.main.async(execute: { () -> Void in
//            if (stream.videoTracks.count > 0) {
//                self.remoteVideoTrack = stream.videoTracks[0]
//            }
//        })
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("peerConnection didRemove stream")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("peerConnection shouldNegotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("peerConnection didChange iceConnectionState: \(newState.rawValue)")
        self.delegate?.webRTCClient(self, didChangeIceConnection: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("peerConnection didChange iceGatheringState: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("peerConnection didGenerate candidate")
        
        // candidate를 db로 보냄
        self.delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("peerConnection didRemove candidates")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("peerConnection didOpen dataChannel")
    }
    
}

