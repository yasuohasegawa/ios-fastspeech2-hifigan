//
//  ContentView.swift
//  ios-fastspeech2-hifigan
//
//  Created by Yasuo Hasegawa on 2025/07/14.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var ojtViewModel: OpenJTalkViewModel
    @StateObject private var fs2HiFiGanViewModel: FastSpeech2HiFiGANViewModel
    
    @State private var inputText:String = """
    伝説の選手たちの足元を支えた"KING"がストリートへ！
    サッカーの歴史を彩ってきた伝説の名手たち。その足元で、常に王者の輝きを放ってきたのが、"PUMA(プーマ)"が誇る名作スパイク、"KING(キング)"。"PELÉ(ペレ)"、"JOHAN CRUYFF(ヨハン・クライフ)"、"DIEGO MARADONA(ディエゴ・マラドーナ)"、神々と称された男たちが愛用したそのスパイクのDNAを受け継ぎ、ストリート仕様へと昇華された"KING INDOOR(キング インドア)"が、クラシックな装いで復活。元々はインドアトレーニング用に開発された"KING INDOOR"だが、その快適な履き心地と、折り返しのシュータンが象徴するクラシックなルックスは、ピッチの外でも支持を集める。フットサルコートから、英国の"テラスカルチャー"まで、そのフィールドを拡大。近年、"ブロークコア"のレトロなスポーツミックススタイルがトレンドとなる中、そのオーセンティックな魅力が再評価され、ファッションシーンでも注目度が高まっている。
    本作は、ヴィンテージ感漂うブラックのレザーアッパーに、ワイドなキルティングステッチを施した、クラシックな佇まい。サイドを駆け抜けるホワイトのフォームストリップのエッジとそして折り返しタンのトリムには、アルゼンチン代表を彷彿とさせる、鮮やかなライトブルーが差し込まれている。ヒールにはプーマキャットと共に、伝説的なプレーヤーたちが背負ったナンバー"10"をプリント。まるでプレイ後の譲土加工を施したミッドソールと、飴色のガムソールがノスタルジックな雰囲気を醸し出す。
    """
    @State private var inputText2:String = "こんにちは"
    @State private var inputTest3:String = "静岡県伊東市の田久保真紀市長が「東洋大卒」と学歴を偽ったと指摘されている問題で、事実関係を調査する市議会の百条委員会は１１日、第１回の会合を開いた。田久保市長が大学の「卒業証書」として市議会議長らに提示した書類について、百条委は１８日までに提出するよう求めた。田久保市長は会合後、「弁護士と相談する」と述べた。"
    @State private var inputTest4:String = "Apple's CoreML framework allows for on-device machine learning. Models can be optimized for the GPU and the Neural Engine, or ANE. The CPU also provides a fallback for unsupported operations. Data formats like FP32 and BFloat16 are common in training frameworks like TensorFlow and PyTorch. On-device inference requires careful management of system resources."
    
    init() {
        let openJTalk = OpenJTalk()
        _ojtViewModel = StateObject(wrappedValue: OpenJTalkViewModel(openJTalk: openJTalk))
        _fs2HiFiGanViewModel = StateObject(wrappedValue: FastSpeech2HiFiGANViewModel(openJTalk: openJTalk))
    }
    
    var body: some View {
        VStack {
            Button(action: {
                ojtViewModel.speakWithOpenJTalk(text: inputText)
            }) {
                Text("Speak with OpenJTalk")
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Button(action: {
                DispatchQueue.main.async {
                    ojtViewModel.extractPhoneme(text: inputText)
                }
            }) {
                Text("Extract the phoneme from text")
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Button(action: {
                DispatchQueue.main.async {
                    fs2HiFiGanViewModel.synthesizeAndPlayLongText(lang: .japanese, text: inputText) { result in
                        
                        if case .failure(let error) = result {
                            print("Final synthesis failed: \(error)")
                        }
                    }
                }
            }) {
                Text("Japanese FastSpeech HiFiGAN synthesize")
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Button(action: {
                DispatchQueue.main.async {
                    fs2HiFiGanViewModel.synthesizeAndPlayLongText(lang: .english, text: inputTest4) { result in
                        
                        if case .failure(let error) = result {
                            print("Final synthesis failed: \(error)")
                        }
                    }
                }
            }) {
                Text("English FastSpeech HiFiGAN synthesize")
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
