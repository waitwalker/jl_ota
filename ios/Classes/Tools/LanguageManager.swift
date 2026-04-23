import DFUnits

//
//  LanguageManager.swift
//  Runner
//
//  Created by 李放 on 2025/9/4.
//

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
        if systemLang.hasPrefix("zh-Hans") {
            setLanguage("zh-Hans")
        } else if systemLang.hasPrefix("ko") {
            setLanguage("ko")
        } else {
            setLanguage("en")
        }
    }
}
