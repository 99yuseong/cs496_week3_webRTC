//
//  webrtcTest.swift
//  week3
//
//  Created by Chanwoo on 2022/07/14.
//

import SwiftUI
import FirebaseFirestore

struct webrtcTestView: View {
    struct roomInfo: Identifiable{
        var id = UUID()
        var name: String
        var roomId: String
    }
    
    private var rooms : [String] = []
    
    @State private var selection = Set<UUID>()
    
    var webRTCClient: WebRTCClient = WebRTCClient()
    var myRoom: Room
    @State var roomRef: DocumentReference?
    
    
    init() {
        roomRef = nil
        //            roomRef = myR
        myRoom = Room.init()
        myRoom.updateFromFire(completion: <#T##([String]) -> Void#>)
    }
    
    
    var body: some View {
        
        
        Button {
            roomRef = myRoom.createRoom(webRTCClient: webRTCClient)
            webRTCClient.listenCallee(roomRef: roomRef!)

        } label: {
            Text("create")
        }
        Button {
            myRoom.joinRoom(webRTCClient: webRTCClient)
        } label: {
            Text("join")
        }

        
    }
}

struct webrtcTest_Previews: PreviewProvider {
    static var previews: some View {
        webrtcTestView()
    }
}
