//
//  week3App.swift
//  week3
//
//  Created by 남유성 on 2022/07/13.
//

import SwiftUI
import KakaoSDKCommon
import KakaoSDKAuth


@main
struct week3App: App {
    init() {
        KakaoSDK.initSDK(appKey:"066a9764b9693059a659e13349024e74")
    }
    var body: some Scene {
        WindowGroup {
            // onOpenURL() URL 스킴 처리
            // 특정 스킴 값을 호출하면 특정앱이 오픈된다. 리스너 설치하는 느낌
            initialView()
        }
    }
}
