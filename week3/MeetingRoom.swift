//
//  MeetingRoom.swift
//  week3
//
//  Created by 남유성 on 2022/07/14.
//

import Foundation
import WebRTC
import FirebaseFirestore

let db = Firestore.firestore()

class MeetingRoom: Codable {
    var caller: String?
    var callee: String?
    var isRoomOpened: Bool?
    var roomId: String?
    
    init() {
        self.caller = nil
        self.callee = nil
        self.isRoomOpened = false
        self.roomId = nil
    }
    
    func createRoom(webRTCClient: WebRTCClient) -> DocumentReference {
        print("create room")
        let roomRef = db.collection("rooms").document()
        
        webRTCClient.createPeerConnection()
        
        let callerCandidatesCollection = roomRef.collection("callerCandidates")
        
        webRTCClient.createOffer(roomRef: roomRef){ _ in
            print("create offer success")
        }
        
        self.isRoomOpened = true
        self.roomId = roomRef.documentID
        
        return roomRef
    }
    
    func joinRoom(webRTCClient: WebRTCClient) {
        print("join room")
        if (self.isRoomOpened!) {
            let roomRef = db.collection("rooms").document(self.roomId!)
            
            roomRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    
                    webRTCClient.createPeerConnection()
                    guard let data = document.data() else {
                        print("Document data was empty.")
                        return
                    }
                    
                    do {
                        let offerJSON = try JSONSerialization.data(withJSONObject: data["offer"]!, options: .fragmentsAllowed)
                        let offerSDP = try JSONDecoder().decode(SessionDescription.self, from: offerJSON)
                        
                        print("Got remote description (offerSDP)")
                        webRTCClient.peerConnection?.setRemoteDescription(offerSDP.rtcSessionDescription, completionHandler: {(error) in
                            print("Warning: Could not set remote description: \(String(describing: error))")
                        })
                        
                        webRTCClient.createAnswer(roomRef: roomRef){ _ in
                            print("create answer success")
                            
                        }
                        
                        // listen remote candidate
                        roomRef.collection("callerCandidates").addSnapshotListener { snapshot, error in
                            guard let documents = snapshot?.documents else {
                                print("Error fetching document: \(error!)")
                                return
                            }
                            
                            snapshot!.documentChanges.forEach { diff in
                                if (diff.type == .added) {
                                    do {
                                        let jsonData = try JSONSerialization.data(withJSONObject: documents.first!.data(), options: .prettyPrinted)
                                        let iceCandidate = try JSONDecoder().decode(IceCandidate.self, from: jsonData)
//                                        print("Got new remote ICE candidate: \(iceCandidate)")
                                        print("Got new remote ICE candidate")
                                        webRTCClient.peerConnection!.add(iceCandidate.rtcIceCandidate)
                                    }
                                    catch {
                                        print("Warning: Could not decode candidate data: \(error)")
                                        return
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        print("Warning: Could not decode sdp data: \(error)")
                        return
                    }
                }
                else {
                    print("Document does not exist")
                }
            }
            
            
        }
    }
    
    func hangUp(webRTCClient: WebRTCClient) {
        print("hangup")
        webRTCClient.peerConnection!.close()
        webRTCClient.peerConnection = nil
        
        if self.roomId != nil {
            let roomRef = db.collection("rooms").document(self.roomId!)
            roomRef.updateData(["answer": FieldValue.delete(), "offer": FieldValue.delete()]) { err in
                if let err = err {
                    print("Error updating document (hang up): \(err)")
                } else {
                    print("Document successfully updated (hang up)")
                }
            }
            
            let callerCandidatesCollection = roomRef.collection("callerCandidates")
            callerCandidatesCollection.getDocuments { snapshot, err in
                if let err = err {
                    print("Error getting caller candidates documents: \(err)")
                }
                else {
                    for document in snapshot!.documents {
                        callerCandidatesCollection.document(document.documentID).delete()
                    }
                }
            }
            callerCandidatesCollection.parent?.delete()
            
            let calleeCandidatesCollection = roomRef.collection("calleeCandidates")
            calleeCandidatesCollection.getDocuments { snapshot, err in
                if let err = err {
                    print("Error getting callee candidates documents: \(err)")
                }
                else {
                    for document in snapshot!.documents {
                        calleeCandidatesCollection.document(document.documentID).delete()
                    }
                }
            }
            calleeCandidatesCollection.parent?.delete()
            
            roomRef.delete()
            
            self.roomId = nil
            self.isRoomOpened = false
            self.caller = nil
            self.callee = nil
        }
        
    }
}

