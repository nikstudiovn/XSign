//
//  VariedTabbarView.swift
//  XSign
//
//  Created by samara on 11.04.2025.
//

import SwiftUI

struct VariedTabbarView: View {
	init() {}
	
	var body: some View {
		Group {
			if #available(iOS 18, *) {
				ExtendedTabbarView()
			} else {
				TabbarView()
			}
		}
	}
}
struct XSignAmbientBackground: View {
	@Environment(\.colorScheme) private var colorScheme
	var body: some View {
		ZStack {
			Color(uiColor: .systemGroupedBackground)
			LinearGradient(colors: [.clear, Color(red: 0x84 / 255.0, green: 0x8E / 255.0, blue: 0xF9 / 255.0).opacity(colorScheme == .dark ? 0.14 : 0.10), .clear], startPoint: .top, endPoint: .bottom)
			.frame(width: 900, height: 220).rotationEffect(.degrees(-28)).offset(y: -120).blur(radius: 26)
			LinearGradient(colors: [.clear, Color(red: 0.35, green: 0.85, blue: 0.96).opacity(colorScheme == .dark ? 0.11 : 0.08), .clear], startPoint: .top, endPoint: .bottom)
			.frame(width: 900, height: 200).rotationEffect(.degrees(-28)).offset(y: 120).blur(radius: 28)
		}
		.ignoresSafeArea().allowsHitTesting(false)
	}
}
