//
//  ContentView.swift
//  week3
//
//  Created by 남유성 on 2022/07/13.
//

import AVFoundation
import SwiftUI
import UIKit
import WebRTC

let bounds: CGRect = UIScreen.main.bounds
var centerX: CGFloat = bounds.width / 2
var videoWidth: CGFloat = centerX
var videoHeight: CGFloat = centerX

let webRTCClient: WebRTCClient = WebRTCClient()
let localRenderer = RTCMTLVideoView()
let remoteRenderer = RTCMTLVideoView()

struct MainView1: View {
    var body: some View {
        HStack {
            localVideoView()
                .frame(width: videoWidth, height: videoHeight)
            Spacer()
            remoteVideoView()
                .frame(width: videoWidth, height: videoHeight)
        }.onAppear {
            webRTCClient.createPeerConnection()
            webRTCClient.startCaptureLocalVideo(renderer: remoteRenderer, front: true)
            webRTCClient.startCaptureLocalVideo(renderer: localRenderer, front: true)
        }
        Spacer()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainView1()
    }
}

struct localVideoView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        return localRenderer
    }
    
    func updateUIView(_ view: UIView, context: Context) {
    }
}

struct remoteVideoView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        return remoteRenderer
    }
    
    func updateUIView(_ view: UIView, context: Context) {
    }
}

