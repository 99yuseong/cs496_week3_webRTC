//
//  IntroView.swift
//  week3
//
//  Created by 남유성 on 2022/07/14.
//

import SwiftUI
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

struct IntroView: View {
    
    @State private var endIntro = false
    
    var body: some View {
            if (endIntro) {
                LoginView1()
                    .onOpenURL { url in // 커스텀 URL 스킴 처리 // 앱으로 돌아오기 위한 url
                        if (AuthApi.isKakaoTalkLoginUrl(url)) {
                            _ = AuthController.handleOpenUrl(url: url)
                        }
                    }
            } else {
                VStack {
                    Spacer()
                    Text("Intro")
                    Spacer()
                    Button {
                        endIntro = true
                    } label: {
                        Text("Go Login")
                    }
                    Spacer()
                }
            }
    }
}

struct IntroView_Previews: PreviewProvider {
    static var previews: some View {
        IntroView()
    }
}
