//
//  XSignLiveActivityBundle.swift
//  XSignLiveActivity
//
//  Widget extension that only hosts the install progress Live Activity.
//

import SwiftUI
import WidgetKit

@main
struct XSignLiveActivityBundle: WidgetBundle {
	var body: some Widget {
		InstallLiveActivity()
	}
}
