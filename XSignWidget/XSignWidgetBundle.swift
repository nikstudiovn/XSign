//
//  XSignWidgetBundle.swift
//  XSignWidget
//
//  Chỉ chứa Live Activity / Dynamic Island. Home Screen Widget đã được gỡ bỏ.
//

import WidgetKit
import SwiftUI

@main
struct XSignWidgetBundle: WidgetBundle {
	var body: some Widget {
		XSignLiveActivityWidget()
	}
}
