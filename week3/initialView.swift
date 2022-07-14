//
//  initialView.swift
//  week3
//
//  Created by 남유성 on 2022/07/14.
//

import SwiftUI
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

struct initialView: View {
    
    @AppStorage("isFirst") var isFirst = UserDefaults.standard.bool(forKey: "isFirst")
    @State private var tokenValid = false
    
    var body: some View {
        Group {
            if isFirst {
                IntroView()
            } else if tokenValid {
                MainView1()
            } else {
                LoginView1()
                    .onOpenURL { url in
                        // 커스텀 URL 스킴 처리
                        // 앱으로 돌아오기 위한 url
                        if (AuthApi.isKakaoTalkLoginUrl(url)) {
                            _ = AuthController.handleOpenUrl(url: url)
                        }
                    }
            }
        }
        .onAppear{
            // 발급받은 토큰 여부 확인
            if (AuthApi.hasToken()) {
                // 토큰 유효성 확인
                UserApi.shared.accessTokenInfo { (_, error) in
                    if let error = error {
                        if let sdkError = error as? SdkError, sdkError.isInvalidTokenError() == true  {
                            // 로그인 필요
                            // 로그인 뷰로 이동
                            print("⛔️ token is not valid")
                            tokenValid = false
                        }
                        else {
                            //기타 에러
                            print(error)
                            tokenValid = false
                        }
                    }
                    else {
                        // 토큰 유효성 체크 성공(필요 시 토큰 갱신됨)
                        // 메인 뷰로 이동
                        print("✅ token is valid")
                        tokenValid = true
                    }
                }
                UserDefaults.standard.set(false, forKey: "isFirst")
            } else if (isFirst) {
                // 토큰 없음
                // 로그인 뷰로 이동
                print("⛔️ no tokens")
                tokenValid = false
                UserDefaults.standard.set(false, forKey: "isFirst")
            } else {
                // 첫 접속
                // 소개 뷰로 이동
                print("😀 First Access")
                tokenValid = false
                UserDefaults.standard.set(true, forKey: "isFirst")
            }
        }
    }}

struct initialView_Previews: PreviewProvider {
    static var previews: some View {
        initialView()
    }
}
