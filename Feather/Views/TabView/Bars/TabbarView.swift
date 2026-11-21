//
//  TabbarView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//

import SwiftUI

/// Giao diện tab cho iOS 16/17.
/// - iPhone / màn hình hẹp: TabView thông thường + tab Tìm kiếm.
/// - iPad / màn hình rộng (hoặc chế độ ngang): NavigationSplitView với sidebar bên trái, chi tiết bên phải.
struct TabbarView: View {
	enum SidebarItem: Hashable {
		case tab(TabEnum)
		case search
	}
	
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@State private var selectedItem: SidebarItem? = .tab(.sources)
	
	var body: some View {
		if horizontalSizeClass == .regular {
			_splitView
		} else {
			_tabView
		}
	}
	
	// MARK: Compact
	private var _tabView: some View {
		TabView(selection: Binding(
			get: { selectedItem ?? .tab(.sources) },
			set: { selectedItem = $0 }
		)) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				TabEnum.view(for: tab)
					.tabItem {
						Label(tab.title, systemImage: tab.icon)
					}
					.tag(SidebarItem.tab(tab))
			}
			
			NavigationStack {
				GlobalSearchView()
			}
			.tabItem {
				Label("Tìm kiếm", systemImage: "magnifyingglass")
			}
			.tag(SidebarItem.search)
		}
	}
	
	// MARK: Regular (iPad / landscape)
	private var _splitView: some View {
		NavigationSplitView {
			List(selection: $selectedItem) {
				Section {
					NavigationLink(value: SidebarItem.search) {
						Label("Tìm kiếm", systemImage: "magnifyingglass")
					}
				}
				
				Section {
					ForEach(TabEnum.defaultTabs + TabEnum.customizableTabs, id: \.hashValue) { tab in
						NavigationLink(value: SidebarItem.tab(tab)) {
							Label(tab.title, systemImage: tab.icon)
						}
					}
				}
			}
			.navigationTitle("XSign")
		} detail: {
			switch selectedItem ?? .tab(.sources) {
			case .tab(let tab):
				TabEnum.view(for: tab)
			case .search:
				NavigationStack {
					GlobalSearchView()
				}
			}
		}
	}
}
