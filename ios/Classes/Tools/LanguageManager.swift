import DFUnits

//
//  LanguageManager.swift
//  Runner
//
//  Created by 李放 on 2025/9/4.
//

struct LanguageManagerConstants {
    static let languageChineseSimplified = "zh-Hans"
    static let languageKorean = "ko"
    static let languageEnglish = "en"
}

/// Application Language Manager
enum LanguageManager {
    static var currentLanguage: String {
        return DFUITools.systemLanguage()
    }
    
    static func setLanguage(_ language: String) {
        DFUITools.languageSet(language)
    }
    
    static func setupAppLanguage() {
        let systemLang = currentLanguage
        if systemLang.hasPrefix(LanguageManagerConstants.languageChineseSimplified) {
            setLanguage(LanguageManagerConstants.languageChineseSimplified)
        } else if systemLang.hasPrefix(LanguageManagerConstants.languageKorean) {
            setLanguage(LanguageManagerConstants.languageKorean)
        } else {
            setLanguage(LanguageManagerConstants.languageEnglish)
        }
    }
}
