//
//  VariedTabbarView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI

struct VariedTabbarView: View {
	@AppStorage(OnboardingView.storageKey) private var _hasSeenOnboarding = false
	@State private var _isOnboardingPresented = false
	
	init() {}
	
	var body: some View {
		Group {
			if #available(iOS 18, *) {
				ExtendedTabbarView()
			} else {
				TabbarView()
			}
		}
		.onAppear {
			if !_hasSeenOnboarding {
				_isOnboardingPresented = true
			}
		}
		.fullScreenCover(isPresented: $_isOnboardingPresented) {
			OnboardingView(isPresented: $_isOnboardingPresented)
		}
	}
}
