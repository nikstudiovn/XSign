//
//  XSignWidgetBundle.swift
//  XSignWidget
//

import WidgetKit
import SwiftUI

@main
struct XSignWidgetBundle: WidgetBundle {
	var body: some Widget {
		XSignHomeWidget()
		XSignLiveActivityWidget()
	}
}
